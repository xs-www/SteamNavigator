class_name SaveService
extends RefCounted
## JSON save slots with a mod/framework header and atomic-ish replacement.
##
## Windows cannot atomically replace an existing file with rename, so the save
## is written to `.tmp`, re-parsed for integrity, then the target is replaced.

const SAVE_SCHEMA := "1.0"
const SAVE_SCHEMA_MAJOR := 1
const AUTOSAVE_SLOT := "autosave"
const PRE_VOYAGE_SLOT := "pre_voyage"

var directory: String = "user://saves"

var _logger: AppLogger = null


func _init(logger: AppLogger = null, save_directory: String = "user://saves") -> void:
	_logger = logger
	directory = save_directory.trim_suffix("/")
	ensure_directory()


func ensure_directory() -> bool:
	if DirAccess.dir_exists_absolute(directory):
		return true
	var status := DirAccess.make_dir_recursive_absolute(directory)
	return status == OK


func save_slot(slot: String, state: GameState, meta: Dictionary = {}) -> Dictionary:
	if not _is_valid_slot(slot):
		return {"ok": false, "error": "invalid save slot name: %s" % slot, "path": ""}
	if state.is_empty():
		return {"ok": false, "error": "cannot save an empty state", "path": ""}
	if not ensure_directory():
		return {"ok": false, "error": "cannot create save directory: %s" % directory, "path": ""}
	var payload := {
		"save_schema": SAVE_SCHEMA,
		"framework_version": FrameworkInfo.VERSION,
		"mod_api_version": "%d.%d" % [FrameworkInfo.API_MAJOR, FrameworkInfo.API_MINOR],
		"content_schema": GameState.SCHEMA_VERSION,
		"created_at": Time.get_datetime_string_from_system(true),
		"seed": state.seed(),
		"mods": meta.get("mods", []),
		"meta": meta.duplicate(true),
		"state": state.to_dict(),
	}
	var text := JsonUtils.canonical_stringify(payload, "\t")
	var path := _slot_path(slot)
	var result := _write_atomic(path, text)
	if result["ok"] and _logger != null:
		_logger.debug("save written", {"slot": slot, "path": path})
	return result


func load_slot(slot: String) -> Dictionary:
	if not _is_valid_slot(slot):
		return {"ok": false, "error": "invalid save slot name: %s" % slot, "state": null, "header": {}}
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "save not found: %s" % slot, "state": null, "header": {}}
	var parsed := JsonUtils.parse_file(path)
	if not parsed["ok"]:
		return {
			"ok": false,
			"error": "save parse error line %d: %s" % [int(parsed["line"]), parsed["error"]],
			"state": null,
			"header": {},
		}
	if not (parsed["value"] is Dictionary):
		return {"ok": false, "error": "save root is not an object", "state": null, "header": {}}
	var payload: Dictionary = parsed["value"]
	var schema_text := String(payload.get("save_schema", ""))
	if not schema_text.begins_with("1."):
		return {
			"ok": false,
			"error": "unsupported save schema: %s" % schema_text,
			"state": null,
			"header": payload,
		}
	if not (payload.get("state", null) is Dictionary):
		return {"ok": false, "error": "save is missing state", "state": null, "header": payload}
	var header := {
		"save_schema": schema_text,
		"framework_version": String(payload.get("framework_version", "")),
		"mod_api_version": String(payload.get("mod_api_version", "")),
		"content_schema": String(payload.get("content_schema", "")),
		"created_at": String(payload.get("created_at", "")),
		"seed": int(payload.get("seed", 0)),
		"mods": payload.get("mods", []),
	}
	return {
		"ok": true,
		"error": "",
		"state": GameState.from_dict(payload["state"]),
		"header": header,
		"meta": payload.get("meta", {}),
	}


func autosave(state: GameState, meta: Dictionary = {}) -> Dictionary:
	return save_slot(AUTOSAVE_SLOT, state, meta)


func save_pre_voyage(state: GameState, meta: Dictionary = {}) -> Dictionary:
	return save_slot(PRE_VOYAGE_SLOT, state, meta)


func load_autosave() -> Dictionary:
	return load_slot(AUTOSAVE_SLOT)


func load_pre_voyage() -> Dictionary:
	return load_slot(PRE_VOYAGE_SLOT)


func has_slot(slot: String) -> bool:
	return _is_valid_slot(slot) and FileAccess.file_exists(_slot_path(slot))


func delete_slot(slot: String) -> bool:
	if not has_slot(slot):
		return false
	return DirAccess.remove_absolute(_slot_path(slot)) == OK


func list_slots() -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			result.append(file_name.trim_suffix(".json"))
	result.sort()
	return result


func read_header(slot: String) -> Dictionary:
	var loaded := load_slot(slot)
	return loaded.get("header", {}) if loaded["ok"] else {}


## Checks the save header against the currently enabled mods.
## Missing mods are a hard failure; version/checksum drift is a warning.
func validate_mods(header: Dictionary, current_mods: Array) -> Dictionary:
	var current := {}
	for mod in current_mods:
		if mod is Dictionary:
			current[String(mod.get("id", ""))] = mod
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var saved_mods: Variant = header.get("mods", [])
	if not (saved_mods is Array):
		return {"ok": true, "errors": errors, "warnings": warnings}
	for saved in saved_mods:
		if not (saved is Dictionary):
			continue
		var mod_id := String(saved.get("id", ""))
		if mod_id.is_empty():
			continue
		if not current.has(mod_id):
			errors.append("save requires missing mod '%s'" % mod_id)
			continue
		var active: Dictionary = current[mod_id]
		var saved_version := String(saved.get("version", ""))
		var active_version := String(active.get("version", ""))
		if not saved_version.is_empty() and saved_version != active_version:
			warnings.append(
				"mod '%s' version differs: save=%s current=%s" % [mod_id, saved_version, active_version]
			)
		var saved_checksum := String(saved.get("checksum", ""))
		var active_checksum := String(active.get("checksum", ""))
		if not saved_checksum.is_empty() and not active_checksum.is_empty() and saved_checksum != active_checksum:
			warnings.append("mod '%s' checksum differs from save header" % mod_id)
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}


func _write_atomic(path: String, text: String) -> Dictionary:
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "cannot open temporary save file", "path": path}
	file.store_string(text)
	file.flush()
	file.close()
	var verify := JsonUtils.parse_file(temporary_path)
	if not verify["ok"]:
		DirAccess.remove_absolute(temporary_path)
		return {"ok": false, "error": "written save failed verification: %s" % verify["error"], "path": path}
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			DirAccess.remove_absolute(temporary_path)
			return {"ok": false, "error": "cannot replace previous save (error %d)" % remove_error, "path": path}
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK:
		return {"ok": false, "error": "cannot rename temporary save (error %d)" % rename_error, "path": path}
	return {"ok": true, "error": "", "path": path}


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [directory, slot]


func _is_valid_slot(slot: String) -> bool:
	var regex := RegEx.new()
	if regex.compile("^[a-z][a-z0-9_]{1,31}$") != OK:
		return false
	return regex.search(slot) != null
