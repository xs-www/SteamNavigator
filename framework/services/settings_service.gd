class_name SettingsService
extends RefCounted
## Persistent UI settings.
##
## The repository ships `config/config.json` as the default. At runtime the
## service writes `user://config/config.json`, which works in exported builds
## where `res://` is read-only.

const DEFAULT_PATH := "res://config/config.json"
const USER_PATH := "user://config/config.json"
const VALID_LOCALES := ["zh_CN", "en"]

var default_path: String = DEFAULT_PATH
var user_path: String = USER_PATH
var data: Dictionary = {}
var last_error: String = ""


func _init(user_path_override: String = USER_PATH, default_path_override: String = DEFAULT_PATH) -> void:
	user_path = user_path_override
	default_path = default_path_override


static func load_settings(user_path_override: String = USER_PATH, default_path_override: String = DEFAULT_PATH) -> SettingsService:
	var service := SettingsService.new(user_path_override, default_path_override)
	service.load()
	return service


func load() -> void:
	last_error = ""
	var parsed := JsonUtils.parse_file(user_path)
	if not bool(parsed.get("ok", false)):
		parsed = JsonUtils.parse_file(default_path)
	if bool(parsed.get("ok", false)) and parsed.get("value") is Dictionary:
		data = (parsed["value"] as Dictionary).duplicate(true)
	else:
		last_error = "settings file missing or invalid"
	_normalize()
	if not FileAccess.file_exists(user_path):
		var saved := save()
		if not bool(saved.get("ok", false)):
			last_error = String(saved.get("error", "settings save failed"))


func _normalize() -> void:
	var locale := String(data.get("locale", "zh_CN"))
	if not VALID_LOCALES.has(locale):
		locale = "zh_CN"
	data["locale"] = locale
	data["autosave"] = bool(data.get("autosave", true))


func locale() -> String:
	return String(data.get("locale", "zh_CN"))


func autosave() -> bool:
	return bool(data.get("autosave", true))


func set_locale(value: String) -> void:
	if VALID_LOCALES.has(value):
		data["locale"] = value


func set_autosave(value: bool) -> void:
	data["autosave"] = value


func save() -> Dictionary:
	var directory := user_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var made := DirAccess.make_dir_recursive_absolute(directory)
		if made != OK:
			return Result.fail("settings_directory_failed", "ui.error.settings_save_failed", {"path": directory})
	var file := FileAccess.open(user_path, FileAccess.WRITE)
	if file == null:
		return Result.fail("settings_write_failed", "ui.error.settings_save_failed", {"path": user_path})
	file.store_string(JsonUtils.canonical_stringify(data, "\t") + "\n")
	return Result.ok({"path": user_path})
