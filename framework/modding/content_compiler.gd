class_name ContentCompiler
extends RefCounted
## Parses, schema-validates and registers content declarations, then applies
## explicit patches before the registry is frozen.

const MAX_CONTENT_FILE_BYTES := 8 * 1024 * 1024
const MAX_PATCHES := 256

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []

var _validator: SchemaValidator
var _hub: RegistryHub
var _localization: LocalizationService
var _assets: AssetService
var _logger: AppLogger
var _packages: Dictionary = {}
var _patches: Array[Dictionary] = []
var _patched_pointers: Dictionary = {}


func _init(
	hub: RegistryHub,
	localization: LocalizationService,
	assets: AssetService,
	logger: AppLogger = null,
	validator: SchemaValidator = null
) -> void:
	_hub = hub
	_localization = localization
	_assets = assets
	_logger = logger
	_validator = validator if validator != null else SchemaValidator.new()


func compile(packages: Dictionary, order: Array[String]) -> Dictionary:
	errors.clear()
	warnings.clear()
	_patches.clear()
	_patched_pointers.clear()
	_packages = packages
	for mod_id in order:
		if not packages.has(mod_id):
			continue
		var package: ModPackage = packages[mod_id]
		_load_localization(package)
		_register_assets(package)
		for content_file in package.manifest.content_files:
			_load_content_file(package, content_file)
	_apply_patches()
	_check_localization_keys()
	for duplicate in _localization.duplicates:
		warnings.append({
			"code": "localization_override",
			"message": "localization key '%s' (%s) overridden by mod '%s'" % [
				duplicate["key"], duplicate["locale"], duplicate["new_mod"]
			],
		})
	return {
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
		"counts": _hub.counts(),
		"patches": _patches.size(),
	}


func _load_localization(package: ModPackage) -> void:
	for relative_path in package.manifest.localization_files:
		var load_result := _localization.load_file(package.source, relative_path, package.id)
		if not bool(load_result["ok"]):
			_add_error(
				"localization_error",
				String(load_result["message"]),
				package.id,
				relative_path
			)


func _register_assets(package: ModPackage) -> void:
	for key in package.manifest.assets.keys():
		_assets.register(
			package.id,
			String(key),
			String(package.manifest.assets[key]),
			package.source.get_asset_prefix()
		)


func _load_content_file(package: ModPackage, relative_path: String) -> void:
	var bytes := package.source.read_bytes(relative_path)
	if bytes.size() > MAX_CONTENT_FILE_BYTES:
		_add_error("content_too_large", "content file exceeds %d bytes" % MAX_CONTENT_FILE_BYTES, package.id, relative_path)
		return
	var parsed := JsonUtils.parse(bytes.get_string_from_utf8())
	if not parsed["ok"]:
		_add_error(
			"content_parse_error",
			"line %d: %s" % [int(parsed["line"]), String(parsed["error"])],
			package.id,
			relative_path
		)
		return
	if not (parsed["value"] is Dictionary):
		_add_error("content_not_object", "content file root must be an object", package.id, relative_path)
		return
	var envelope: Dictionary = parsed["value"]
	if String(envelope.get("schema_version", "")) != FrameworkInfo.CONTENT_SCHEMA:
		_add_error(
			"unsupported_schema",
			"schema_version must be '%s'" % FrameworkInfo.CONTENT_SCHEMA,
			package.id,
			relative_path,
			"/schema_version"
		)
		return
	var content_type_name := String(envelope.get("content_type", ""))
	var content_type := StringName(content_type_name)
	if not ContentTypes.is_known(content_type):
		_add_error("unknown_content_type", "unknown content_type '%s'" % content_type_name, package.id, relative_path, "/content_type")
		return
	var schema_errors := _validator.validate_file(envelope, ContentTypes.schema_path(content_type))
	if not schema_errors.is_empty():
		for schema_error in schema_errors:
			_add_error(
				"schema_error",
				String(schema_error["message"]),
				package.id,
				relative_path,
				String(schema_error["path"])
			)
		return

	var definitions: Variant = envelope.get("definitions", [])
	if not (definitions is Array):
		_add_error("invalid_definitions", "definitions must be an array", package.id, relative_path, "/definitions")
		return
	for index in definitions.size():
		var raw_definition: Variant = definitions[index]
		var pointer := "/definitions/%d" % index
		if not (raw_definition is Dictionary):
			_add_error("invalid_definition", "definition must be an object", package.id, relative_path, pointer)
			continue
		if ContentTypes.is_patch(content_type):
			_collect_patch(package, relative_path, raw_definition, pointer)
			continue
		_register_definition(package, content_type, raw_definition, relative_path, pointer)


func _register_definition(package: ModPackage, content_type: StringName, raw_definition: Dictionary, relative_path: String, pointer: String) -> void:
	var definition_id := String(raw_definition.get("id", ""))
	var parsed_id := _parse_definition_id(definition_id)
	if parsed_id.is_empty():
		_add_error("invalid_definition_id", "invalid definition id '%s'" % definition_id, package.id, relative_path, pointer + "/id")
		return
	if String(parsed_id["mod_id"]) != package.id:
		_add_error(
			"cross_namespace_definition",
			"definition '%s' must use the source mod namespace '%s'" % [definition_id, package.id],
			package.id,
			relative_path,
			pointer + "/id"
		)
		return
	var expected_singular := ContentTypes.singular(content_type)
	if String(parsed_id["singular"]) != expected_singular:
		_add_error(
			"id_type_mismatch",
			"definition '%s' must use '%s' in its id, not '%s'" % [definition_id, expected_singular, parsed_id["singular"]],
			package.id,
			relative_path,
			pointer + "/id"
		)
		return
	if not bool(raw_definition.get("enabled", true)):
		return
	var definition := ContentDefinition.from_raw(raw_definition, content_type, package.id, relative_path)
	var register_result := _hub.register(definition, package.id)
	if not bool(register_result["ok"]):
		_add_error(
			String(register_result["error_code"]),
			String(register_result["message"]),
			package.id,
			relative_path,
			pointer
		)
		return
	if _logger != null:
		_logger.debug("content definition registered", {"id": definition_id, "type": String(content_type), "mod": package.id})


func _collect_patch(package: ModPackage, relative_path: String, raw_patch: Dictionary, pointer: String) -> void:
	if _patches.size() >= MAX_PATCHES:
		_add_error("too_many_patches", "more than %d patches in one load" % MAX_PATCHES, package.id, relative_path, pointer)
		return
	_patches.append({
		"mod_id": package.id,
		"file": relative_path,
		"pointer": pointer,
		"patch": raw_patch.duplicate(true),
	})


func _apply_patches() -> void:
	for entry in _patches:
		_apply_patch(entry)


func _apply_patch(entry: Dictionary) -> void:
	var mod_id := String(entry["mod_id"])
	var file := String(entry["file"])
	var pointer := String(entry["pointer"])
	var patch: Dictionary = entry["patch"]
	var target_id := String(patch.get("target", ""))
	var parsed_id := _parse_definition_id(target_id)
	if parsed_id.is_empty():
		_add_error("invalid_patch_target", "invalid patch target '%s'" % target_id, mod_id, file, pointer + "/target")
		return
	var target_type := ContentTypes.from_singular(String(parsed_id["singular"]))
	if target_type == &"":
		_add_error("invalid_patch_target", "unknown patch target type in '%s'" % target_id, mod_id, file, pointer + "/target")
		return
	var definition := _hub.get_by_id(target_type, target_id)
	if definition == null:
		_add_error("patch_target_missing", "patch target does not exist: %s" % target_id, mod_id, file, pointer + "/target")
		return
	if patch.get("requires", null) is Dictionary:
		var requires: Dictionary = patch["requires"]
		var required_mod := String(requires.get("mod", ""))
		var required_version := String(requires.get("version", "*"))
		var required_package: Variant = _packages.get(required_mod, null)
		if not (required_package is ModPackage):
			_add_error("patch_requires_missing", "patch requires missing mod '%s'" % required_mod, mod_id, file, pointer)
			return
		var range := VersionRange.parse(required_version)
		if not range.matches(required_package.manifest.version):
			_add_error(
				"patch_requires_version",
				"patch requires %s %s, installed %s" % [required_mod, required_version, required_package.manifest.version_text],
				mod_id,
				file,
				pointer
			)
			return
	var working := definition.to_raw()
	var operations: Variant = patch.get("operations", [])
	if not (operations is Array):
		_add_error("invalid_patch", "patch operations must be an array", mod_id, file, pointer + "/operations")
		return
	for index in operations.size():
		var operation: Variant = operations[index]
		var operation_pointer := "%s/operations/%d" % [pointer, index]
		if not (operation is Dictionary):
			_add_error("invalid_patch_operation", "patch operation must be an object", mod_id, file, operation_pointer)
			return
		var pointer_path := String(operation.get("path", ""))
		if pointer_path == "/id" or pointer_path.begins_with("/id/"):
			_add_error("patch_id_forbidden", "patches may not change definition ids", mod_id, file, operation_pointer + "/path")
			return
		var conflict_key := "%s|%s" % [target_id, pointer_path]
		if _patched_pointers.has(conflict_key) and String(_patched_pointers[conflict_key]) != mod_id:
			_add_error(
				"patch_conflict",
				"mods '%s' and '%s' patch the same pointer %s on %s" % [
					String(_patched_pointers[conflict_key]), mod_id, pointer_path, target_id
				],
				mod_id,
				file,
				operation_pointer
			)
			return
		_patched_pointers[conflict_key] = mod_id
		var apply_result := JsonUtils.pointer_apply(
			working,
			pointer_path,
			String(operation.get("op", "replace")),
			operation.get("value", null)
		)
		if not bool(apply_result["ok"]):
			_add_error(
				"patch_apply_failed",
				"cannot apply %s %s: %s" % [String(operation.get("op", "")), pointer_path, apply_result["error"]],
				mod_id,
				file,
				operation_pointer
			)
			return
	if String(working.get("id", "")) != target_id:
		_add_error("patch_id_forbidden", "patch changed the target id", mod_id, file, pointer)
		return
	var validation_errors := _validate_definition(target_type, working)
	if not validation_errors.is_empty():
		for schema_error in validation_errors:
			_add_error(
				"patch_schema_error",
				String(schema_error["message"]),
				mod_id,
				file,
				pointer + String(schema_error["path"])
			)
		return
	var previous_source := definition.source_mod
	definition.name_key = String(working.get("name_key", definition.name_key))
	definition.description_key = String(working.get("description_key", definition.description_key))
	definition.tags = PackedStringArray(working.get("tags", []))
	definition.enabled = bool(working.get("enabled", definition.enabled))
	definition.data = working.get("data", {})
	definition.raw = working
	definition.source_mod = previous_source
	definition.patched_by.append(mod_id)
	if _logger != null:
		_logger.info("content patch applied", {"target": target_id, "mod": mod_id, "file": file})


func _validate_definition(content_type: StringName, raw_definition: Dictionary) -> Array[Dictionary]:
	var envelope := {
		"schema_version": FrameworkInfo.CONTENT_SCHEMA,
		"content_type": String(content_type),
		"definitions": [raw_definition],
	}
	return _validator.validate_file(envelope, ContentTypes.schema_path(content_type))


func _check_localization_keys() -> void:
	for content_type in ContentTypes.all():
		var registry := _hub.registry(content_type)
		if registry == null:
			continue
		for definition in registry.get_all():
			if not definition.name_key.is_empty() and not _localization.has_key(definition.name_key):
				warnings.append({
					"code": "missing_localization",
					"message": "missing localization key '%s' for '%s'" % [definition.name_key, definition.id],
				})
			if not definition.description_key.is_empty() and not _localization.has_key(definition.description_key):
				warnings.append({
					"code": "missing_localization",
					"message": "missing localization key '%s' for '%s'" % [definition.description_key, definition.id],
				})


func _parse_definition_id(definition_id: String) -> Dictionary:
	var regex := RegEx.new()
	if regex.compile("^([a-z][a-z0-9_]{2,31}):([a-z_]+)/([a-z0-9_]+)$") != OK:
		return {}
	var match_result := regex.search(definition_id)
	if match_result == null:
		return {}
	return {
		"mod_id": match_result.get_string(1),
		"singular": match_result.get_string(2),
		"local_id": match_result.get_string(3),
	}


func _add_error(code: String, message: String, mod_id: String, file: String = "", pointer: String = "") -> void:
	var entry := {
		"code": code,
		"message": message,
		"mod_id": mod_id,
		"file": file,
		"pointer": pointer,
	}
	errors.append(entry)
	if _logger != null:
		_logger.error("content load error", entry)
