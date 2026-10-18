class_name ModManifest
extends RefCounted
## Parsed and semantically checked mod manifest.

const MANIFEST_SCHEMA_PATH := "res://schemas/manifest.schema.json"

var id: String = ""
var name: String = ""
var version_text: String = ""
var version: SemVer = null
var api_version_text: String = ""
var api_major: int = 0
var api_minor: int = 0
var type: String = "content"
var load_priority: int = 0
var required: bool = false
var dependencies: Array[Dictionary] = []
var optional_dependencies: Array[Dictionary] = []
var conflicts: PackedStringArray = PackedStringArray()
var content_files: PackedStringArray = PackedStringArray()
var localization_files: PackedStringArray = PackedStringArray()
var assets: Dictionary = {}
var capabilities: PackedStringArray = PackedStringArray()
var checksum: String = ""
var authors: PackedStringArray = PackedStringArray()
var license: String = ""
var description: String = ""
var raw: Dictionary = {}
var source_label: String = ""
var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []


static func from_dict(raw_manifest: Dictionary, source_label_value: String = "") -> ModManifest:
	var manifest := ModManifest.new()
	manifest.raw = raw_manifest.duplicate(true)
	manifest.source_label = source_label_value
	manifest.id = String(raw_manifest.get("id", ""))
	manifest.name = String(raw_manifest.get("name", manifest.id))
	manifest.version_text = String(raw_manifest.get("version", ""))
	manifest.api_version_text = String(raw_manifest.get("api_version", ""))
	manifest.type = String(raw_manifest.get("type", "content"))
	manifest.load_priority = int(raw_manifest.get("load_priority", 0))
	manifest.required = bool(raw_manifest.get("required", false))
	manifest.checksum = String(raw_manifest.get("checksum", ""))
	manifest.license = String(raw_manifest.get("license", ""))
	manifest.description = String(raw_manifest.get("description", ""))
	manifest.conflicts = PackedStringArray(raw_manifest.get("conflicts", []))
	manifest.capabilities = PackedStringArray(raw_manifest.get("capabilities", []))
	manifest.authors = PackedStringArray(raw_manifest.get("authors", []))

	manifest._parse_version()
	manifest._parse_api_version()
	manifest._parse_content_files(raw_manifest)
	manifest._parse_localization_files(raw_manifest)
	manifest._parse_dependencies(raw_manifest)
	manifest._parse_assets(raw_manifest)

	if manifest.id.is_empty():
		manifest._error("missing_id", "manifest is missing id", "id")
	elif not _is_valid_mod_id(manifest.id):
		manifest._error("invalid_id", "invalid mod id '%s'" % manifest.id, "id")
	if manifest.required and manifest.id != "core":
		manifest._error("required_not_allowed", "only the official 'core' mod may declare required=true", "required")
	if manifest.type != "content":
		manifest._error("invalid_type", "MVP only supports type=content", "type")
	return manifest


func _parse_version() -> void:
	version = SemVer.parse(version_text)
	if version == null:
		_error("invalid_version", "version is not SemVer 2.0: '%s'" % version_text, "version")


func _parse_api_version() -> void:
	var parts := api_version_text.split(".")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		_error("invalid_api_version", "api_version must look like '1.0'", "api_version")
		return
	api_major = int(parts[0])
	api_minor = int(parts[1])


func _parse_content_files(raw_manifest: Dictionary) -> void:
	var values: Variant = raw_manifest.get("content", [])
	if not (values is Array) or values.is_empty():
		_error("missing_content", "manifest must declare at least one content file", "content")
		return
	var seen := PackedStringArray()
	for value in values:
		var path := String(value)
		if seen.has(path):
			_error("duplicate_content_file", "duplicate content file: %s" % path, "content")
			continue
		seen.append(path)
		if not PathGuard.is_allowed_content(path):
			_error("invalid_content_path", "illegal content path: %s" % path, "content")
			continue
		content_files.append(path)


func _parse_localization_files(raw_manifest: Dictionary) -> void:
	var values: Variant = raw_manifest.get("localization", [])
	if values is Array:
		for value in values:
			var path := String(value)
			if not PathGuard.is_allowed_localization(path):
				_error("invalid_localization_path", "illegal localization path: %s" % path, "localization")
				continue
			localization_files.append(path)


func _parse_dependencies(raw_manifest: Dictionary) -> void:
	dependencies = _parse_dependency_list(raw_manifest.get("dependencies", []), "dependencies")
	optional_dependencies = _parse_dependency_list(raw_manifest.get("optional_dependencies", []), "optional_dependencies")


func _parse_dependency_list(values: Variant, field: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if values == null:
		return result
	if not (values is Array):
		_error("invalid_dependencies", "%s must be an array" % field, field)
		return result
	var seen := PackedStringArray()
	for value in values:
		if not (value is Dictionary):
			_error("invalid_dependency", "%s entries must be objects" % field, field)
			continue
		var dependency_id := String(value.get("id", ""))
		if dependency_id.is_empty() or not _is_valid_mod_id(dependency_id):
			_error("invalid_dependency_id", "invalid dependency id '%s'" % dependency_id, field)
			continue
		if seen.has(dependency_id):
			_error("duplicate_dependency", "duplicate dependency id '%s'" % dependency_id, field)
			continue
		seen.append(dependency_id)
		var range_text := String(value.get("version", "*"))
		var range := VersionRange.parse(range_text)
		if not range.error.is_empty():
			_error("invalid_version_range", "invalid version range '%s' for dependency '%s'" % [range_text, dependency_id], field)
			continue
		result.append({
			"id": dependency_id,
			"range_text": range_text,
			"range": range,
		})
	return result


func _parse_assets(raw_manifest: Dictionary) -> void:
	var values: Variant = raw_manifest.get("assets", {})
	if not (values is Dictionary):
		_error("invalid_assets", "assets must be an object", "assets")
		return
	var key_regex := RegEx.new()
	key_regex.compile("^[a-z][a-z0-9_.-]*$")
	for key in values.keys():
		var key_text := String(key)
		var path := String(values[key])
		if key_regex.search(key_text) == null:
			_error("invalid_asset_key", "invalid asset key '%s'" % key_text, "assets")
			continue
		if not PathGuard.is_allowed_asset(path):
			_error("invalid_asset_path", "illegal asset path for '%s': %s" % [key_text, path], "assets")
			continue
		assets[key_text] = path


func accepts_api(framework_major: int, framework_minor: int) -> bool:
	return api_major == framework_major and api_minor <= framework_minor


func has_capabilities(known: PackedStringArray) -> Array[String]:
	var missing: Array[String] = []
	for capability in capabilities:
		if not known.has(capability):
			missing.append(capability)
	return missing


func to_summary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"version": version_text,
		"api_version": api_version_text,
		"required": required,
		"load_priority": load_priority,
		"dependencies": dependencies.map(func(dependency): return dependency["id"]),
		"source": source_label,
		"checksum": checksum,
		"content_files": Array(content_files),
	}


func _error(code: String, message: String, field: String = "") -> void:
	errors.append({"code": code, "message": message, "field": field})


static func _is_valid_mod_id(value: String) -> bool:
	var regex := RegEx.new()
	if regex.compile("^[a-z][a-z0-9_]{2,31}$") != OK:
		return false
	return regex.search(value) != null
