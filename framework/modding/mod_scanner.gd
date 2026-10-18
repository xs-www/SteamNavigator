class_name ModScanner
extends RefCounted
## Discovers loose mod directories and `.snavmod.zip` packs, performs the
## structural security checks, and parses/validates each manifest.

const MAX_FILES := 2000
const MAX_PACK_BYTES := 64 * 1024 * 1024
const MAX_MANIFEST_BYTES := 1024 * 1024
const MAX_CONTENT_FILE_BYTES := 8 * 1024 * 1024

var _validator: SchemaValidator = null


func _init(schema_validator: SchemaValidator = null) -> void:
	_validator = schema_validator if schema_validator != null else SchemaValidator.new()


func scan(roots: PackedStringArray, allow_loose: bool = true) -> Dictionary:
	var packages: Array[ModPackage] = []
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var scanned_roots: PackedStringArray = PackedStringArray()

	for root in roots:
		if root.is_empty():
			continue
		var directory := DirAccess.open(root)
		if directory == null:
			continue
		scanned_roots.append(root)
		var directories := directory.get_directories()
		directories.sort()
		for directory_name in directories:
			var mod_dir := root.rstrip("/") + "/" + directory_name
			if not FileAccess.file_exists(mod_dir + "/manifest.json"):
				continue
			if not allow_loose:
				warnings.append({
					"code": "loose_mod_ignored",
					"message": "loose mod directory ignored outside debug builds: %s" % mod_dir,
				})
				continue
			packages.append(_load_loose(mod_dir))
		var files := directory.get_files()
		files.sort()
		for file_name in files:
			if not file_name.to_lower().ends_with(".zip"):
				continue
			packages.append(_load_zip(root.rstrip("/") + "/" + file_name))

	var filtered: Array[ModPackage] = []
	var loose_ids: Dictionary = {}
	for package in packages:
		if package.source != null and not package.source.is_pack() and not package.id.is_empty() and package.errors.is_empty():
			loose_ids[package.id] = true
	for package in packages:
		if package.source != null and package.source.is_pack() and loose_ids.has(package.id):
			# The core zip under dist/mods is a build artifact; in a dev
			# checkout the loose core is authoritative. Other duplicate ids
			# still produce a visible warning.
			if package.id != DependencyResolver.CORE_ID:
				warnings.append({
					"code": "loose_mod_shadows_pack",
					"message": "loose mod '%s' shadows packed copy %s" % [package.id, package.source.get_display_name()],
					"mod_id": package.id,
					"path": package.source.get_display_name(),
				})
			continue
		filtered.append(package)

	return {
		"packages": filtered,
		"errors": errors,
		"warnings": warnings,
		"scanned_roots": scanned_roots,
	}


func _load_loose(mod_dir: String) -> ModPackage:
	var package := ModPackage.new()
	var source := DirModSource.new(mod_dir)
	package.source = source
	_scan_source(package, source, false)
	return package


func _load_zip(pack_path: String) -> ModPackage:
	var package := ModPackage.new()
	var pack_size := FileAccess.get_file_as_bytes(pack_path).size()
	if pack_size > MAX_PACK_BYTES:
		package.add_error(
			"pack_too_large",
			"zip pack is %d bytes; limit is %d" % [pack_size, MAX_PACK_BYTES],
			pack_path
		)
		return package
	var source := ZipModSource.new(pack_path)
	package.source = source
	if not source.error.is_empty():
		package.add_error("invalid_pack", source.error, pack_path)
		return package
	_scan_source(package, source, true)
	return package


func _scan_source(package: ModPackage, source: ModSource, require_zip_namespace: bool) -> void:
	var files := source.list_files()
	if files.size() > MAX_FILES:
		package.add_error(
			"too_many_files",
			"mod contains %d files; limit is %d" % [files.size(), MAX_FILES],
			source.get_display_name()
		)
		return
	if not files.has("manifest.json"):
		package.add_error("missing_manifest", "mod root must contain manifest.json", source.get_display_name())
		return

	for relative_path in files:
		if not require_zip_namespace and _is_godot_metadata(relative_path):
			continue
		if not PathGuard.is_safe_relative(relative_path):
			package.add_error("unsafe_path", "illegal path inside mod: %s" % relative_path, source.get_display_name())
			continue
		var extension := "." + relative_path.get_extension().to_lower()
		if extension == ".json":
			continue
		if extension == ".csv" and relative_path.begins_with("localization/"):
			continue
		if PathGuard.ASSET_EXTENSIONS.has(extension) and relative_path.begins_with("assets/"):
			continue
		package.add_error(
			"forbidden_file",
			"file type is not allowed in a content mod: %s" % relative_path,
			source.get_display_name()
		)

	if require_zip_namespace and source.mod_id.is_empty():
		package.add_error("invalid_namespace", "zip pack does not expose a mods/<id>/ namespace", source.get_display_name())
		return

	var manifest_bytes := source.read_bytes("manifest.json")
	if manifest_bytes.size() > MAX_MANIFEST_BYTES:
		package.add_error(
			"manifest_too_large",
			"manifest.json exceeds %d bytes" % MAX_MANIFEST_BYTES,
			source.get_display_name()
		)
		return
	var parsed := JsonUtils.parse(manifest_bytes.get_string_from_utf8())
	if not parsed["ok"]:
		package.add_error(
			"manifest_parse_error",
			"manifest.json line %d: %s" % [int(parsed["line"]), String(parsed["error"])],
			"manifest.json"
		)
		return
	if not (parsed["value"] is Dictionary):
		package.add_error("manifest_not_object", "manifest.json must contain an object", "manifest.json")
		return
	package.manifest_raw = parsed["value"]

	var schema_errors := _validator.validate_file(parsed["value"], ModManifest.MANIFEST_SCHEMA_PATH)
	for schema_error in schema_errors:
		package.add_error(
			"manifest_schema",
			"%s: %s" % [schema_error["message"], schema_error["path"]],
			"manifest.json",
			String(schema_error["path"])
		)

	var manifest := ModManifest.from_dict(parsed["value"], source.get_display_name())
	package.manifest = manifest
	package.id = manifest.id
	if source.mod_id.is_empty():
		source.mod_id = manifest.id
	elif not manifest.id.is_empty() and source.mod_id != manifest.id:
		package.add_error(
			"manifest_id_mismatch",
			"zip namespace '%s' does not match manifest id '%s'" % [source.mod_id, manifest.id],
			"manifest.json",
			"/id"
		)
	for manifest_error in manifest.errors:
		package.add_error(
			"manifest_%s" % String(manifest_error["code"]),
			String(manifest_error["message"]),
			"manifest.json",
			"/%s" % String(manifest_error["field"])
		)
	for manifest_warning in manifest.warnings:
		package.add_warning(
			"manifest_%s" % String(manifest_warning["code"]),
			String(manifest_warning["message"]),
			"manifest.json"
		)

	if manifest.errors.is_empty() and manifest.id.is_empty():
		package.add_error("missing_id", "manifest is missing id", "manifest.json", "/id")

	_verify_declared_files(package, source, manifest)


func _verify_declared_files(package: ModPackage, source: ModSource, manifest: ModManifest) -> void:
	for content_file in manifest.content_files:
		if not source.exists(content_file):
			package.add_error("missing_content_file", "declared content file is missing: %s" % content_file, content_file)
			continue
		var bytes := source.read_bytes(content_file)
		if bytes.size() > MAX_CONTENT_FILE_BYTES:
			package.add_error(
				"content_file_too_large",
				"content file exceeds %d bytes: %s" % [MAX_CONTENT_FILE_BYTES, content_file],
				content_file
			)
	for localization_file in manifest.localization_files:
		if not source.exists(localization_file):
			package.add_error(
				"missing_localization_file",
				"declared localization file is missing: %s" % localization_file,
				localization_file
			)
	for key in manifest.assets.keys():
		var relative_path := String(manifest.assets[key])
		if not source.exists(relative_path):
			package.add_error(
				"missing_asset",
				"declared asset '%s' is missing: %s" % [key, relative_path],
				relative_path
			)


func _is_godot_metadata(relative_path: String) -> bool:
	if relative_path.ends_with(".import") or relative_path.ends_with(".uid"):
		return true
	var file_name := relative_path.get_file()
	return file_name == ".DS_Store" or file_name == "Thumbs.db" or file_name == ".gdignore"
