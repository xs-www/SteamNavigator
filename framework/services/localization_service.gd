class_name LocalizationService
extends RefCounted
## Locale tables merged from framework base files and content mods.
##
## Keys are global (`item.core.coal.name`) and later mods override earlier
## values for the same locale with a warning. Missing keys fall back to the
## fallback locale and finally to the key itself, so UI never crashes.

const FALLBACK_LOCALE := "en"
const BASE_LOCALES := ["zh_CN", "en"]

var active_locale: String = "zh_CN"
var duplicates: Array[Dictionary] = []

var _logger: AppLogger = null
var _locales: Dictionary = {}  # locale -> {key: text}
var _sources: Dictionary = {}  # "locale::key" -> mod id


func _init(locale: String = "zh_CN", logger: AppLogger = null) -> void:
	active_locale = locale
	_logger = logger


func load_base_tables() -> void:
	for locale in BASE_LOCALES:
		var path := "res://framework/localization/%s.json" % locale
		var parsed := JsonUtils.parse_file(path)
		if not parsed["ok"]:
			if _logger != null:
				_logger.warn("framework localization file missing or invalid", {"file": path, "error": parsed["error"]})
			continue
		if parsed["value"] is Dictionary:
			add_table(parsed["value"], "framework", locale)


func load_file(source: ModSource, relative_path: String, mod_id: String) -> Dictionary:
	if relative_path.to_lower().ends_with(".csv"):
		return {
			"ok": false,
			"code": "csv_not_supported",
			"message": "CSV localization must be converted to JSON before packaging: %s" % relative_path,
		}
	var text := source.read_text(relative_path)
	if text.is_empty():
		return {"ok": false, "code": "empty_file", "message": "localization file is empty: %s" % relative_path}
	var parsed := JsonUtils.parse(text)
	if not parsed["ok"]:
		return {
			"ok": false,
			"code": "parse_error",
			"message": "localization %s line %d: %s" % [relative_path, int(parsed["line"]), parsed["error"]],
		}
	if not (parsed["value"] is Dictionary):
		return {"ok": false, "code": "not_object", "message": "localization must be an object: %s" % relative_path}
	var locale := relative_path.get_file().get_basename()
	if locale.is_empty():
		return {"ok": false, "code": "missing_locale", "message": "cannot infer locale from %s" % relative_path}
	add_table(parsed["value"], mod_id, locale)
	return {"ok": true, "code": "", "message": ""}


func add_table(table: Dictionary, mod_id: String, locale: String) -> void:
	if not _locales.has(locale):
		_locales[locale] = {}
	var target: Dictionary = _locales[locale]
	for raw_key in table.keys():
		var key := String(raw_key)
		var value: Variant = table[raw_key]
		if not (value is String):
			if _logger != null:
				_logger.warn("localization value is not a string", {"mod": mod_id, "locale": locale, "key": key})
			continue
		var source_key := "%s::%s" % [locale, key]
		if target.has(key) and _sources.get(source_key, "") != mod_id:
			var previous := String(_sources.get(source_key, ""))
			duplicates.append({
				"locale": locale,
				"key": key,
				"previous_mod": previous,
				"new_mod": mod_id,
			})
			if _logger != null:
				_logger.warn(
					"localization key overridden",
					{"locale": locale, "key": key, "previous": previous, "new": mod_id}
				)
		target[key] = value
		_sources[source_key] = mod_id


func set_locale(locale: String) -> void:
	active_locale = locale


func tr_key(key: String, fallback: String = "") -> String:
	if _locales.has(active_locale):
		var table: Dictionary = _locales[active_locale]
		if table.has(key):
			return String(table[key])
	if active_locale != FALLBACK_LOCALE and _locales.has(FALLBACK_LOCALE):
		var fallback_table: Dictionary = _locales[FALLBACK_LOCALE]
		if fallback_table.has(key):
			return String(fallback_table[key])
	return fallback if not fallback.is_empty() else key


func tr_format(key: String, args: Array, fallback: String = "") -> String:
	var text := tr_key(key, fallback)
	if args.is_empty():
		return text
	return text % args


func has_key(key: String, locale: String = "") -> bool:
	var target_locale := active_locale if locale.is_empty() else locale
	return _locales.has(target_locale) and _locales[target_locale].has(key)


func count(locale: String = "") -> int:
	var target_locale := active_locale if locale.is_empty() else locale
	return _locales[target_locale].size() if _locales.has(target_locale) else 0


func available_locales() -> PackedStringArray:
	var result := PackedStringArray()
	for locale in _locales.keys():
		result.append(String(locale))
	result.sort()
	return result


func missing_keys(keys: Array, locale: String = "") -> Array[String]:
	var result: Array[String] = []
	for key in keys:
		if not has_key(String(key), locale):
			result.append(String(key))
	return result


func source_of(key: String, locale: String = "") -> String:
	var target_locale := active_locale if locale.is_empty() else locale
	return String(_sources.get("%s::%s" % [target_locale, key], ""))
