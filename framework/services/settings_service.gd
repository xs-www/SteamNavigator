class_name SettingsService
extends RefCounted
## Persistent UI settings.
##
## Editor builds read the repository default `res://config/config.json` and
## write `user://config/config.json`. Exported builds ship an editable
## `config/config.json` next to the executable; that file is used as the live
## settings file so a release folder stays portable. If it is not writable
## (for example the game lives under Program Files), saving falls back to
## `user://config/config.json`.

const DEFAULT_PATH := "res://config/config.json"
const USER_PATH := "user://config/config.json"
const EXE_CONFIG_PATH := "config/config.json"
const VALID_LOCALES := ["zh_CN", "en"]

var default_path: String = DEFAULT_PATH
var user_path: String = USER_PATH
var data: Dictionary = {}
var last_error: String = ""


func _init(user_path_override: String = "", default_path_override: String = "") -> void:
	user_path = user_path_override if not user_path_override.is_empty() else _release_user_path()
	default_path = default_path_override if not default_path_override.is_empty() else _release_config_path(DEFAULT_PATH)


static func load_settings(user_path_override: String = "", default_path_override: String = "") -> SettingsService:
	var service := SettingsService.new(user_path_override, default_path_override)
	service.load()
	return service


## Prefer an existing `user://` config (also written when the install directory
## is read-only), then the shipped executable-side config.
static func _release_user_path() -> String:
	if not OS.has_feature("template"):
		return USER_PATH
	if FileAccess.file_exists(USER_PATH):
		return USER_PATH
	var external := OS.get_executable_path().get_base_dir().path_join(EXE_CONFIG_PATH)
	if FileAccess.file_exists(external):
		return external
	return USER_PATH


## The shipped executable-side config is the release default; editor builds
## and missing files keep using `fallback` (the embedded `res://` copy).
static func _release_config_path(fallback: String) -> String:
	if not OS.has_feature("template"):
		return fallback
	var external := OS.get_executable_path().get_base_dir().path_join(EXE_CONFIG_PATH)
	if FileAccess.file_exists(external):
		return external
	return fallback


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
	var saved := _write(user_path)
	if bool(saved.get("ok", false)):
		return saved
	# A read-only install directory must not lose the settings change.
	if OS.has_feature("template") and user_path != USER_PATH:
		var fallback := _write(USER_PATH)
		if bool(fallback.get("ok", false)):
			user_path = USER_PATH
			return fallback
	return saved


func _write(path: String) -> Dictionary:
	var directory := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var made := DirAccess.make_dir_recursive_absolute(directory)
		if made != OK:
			return Result.fail("settings_directory_failed", "ui.error.settings_save_failed", {"path": directory})
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return Result.fail("settings_write_failed", "ui.error.settings_save_failed", {"path": path})
	file.store_string(JsonUtils.canonical_stringify(data, "\t") + "\n")
	return Result.ok({"path": path})
