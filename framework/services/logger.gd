class_name AppLogger
extends RefCounted
## Structured, bounded in-memory logger with mod attribution.

enum Level { DEBUG, INFO, WARN, ERROR, FATAL }

const LEVEL_NAMES := ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
const MAX_ENTRIES := 1000

var minimum_level: int = Level.INFO
var echo_to_console: bool = true

var _entries: Array[Dictionary] = []
var _sequence: int = 0


func _init(minimum: int = Level.INFO, echo: bool = true) -> void:
	minimum_level = minimum
	echo_to_console = echo


func debug(message: String, fields: Dictionary = {}) -> void:
	_log(Level.DEBUG, message, fields)


func info(message: String, fields: Dictionary = {}) -> void:
	_log(Level.INFO, message, fields)


func warn(message: String, fields: Dictionary = {}) -> void:
	_log(Level.WARN, message, fields)


func error(message: String, fields: Dictionary = {}) -> void:
	_log(Level.ERROR, message, fields)


func fatal(message: String, fields: Dictionary = {}) -> void:
	_log(Level.FATAL, message, fields)


func _log(level: int, message: String, fields: Dictionary) -> void:
	if level < minimum_level:
		return
	_sequence += 1
	var entry := {
		"seq": _sequence,
		"time": Time.get_datetime_string_from_system(true),
		"level": LEVEL_NAMES[level],
		"level_value": level,
		"message": message,
		"fields": fields.duplicate(true),
	}
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	if echo_to_console:
		var suffix := ""
		if not fields.is_empty():
			suffix = " " + JsonUtils.canonical_stringify(fields)
		print("[%s] %s%s" % [LEVEL_NAMES[level], message, suffix])


func get_entries(minimum: int = Level.DEBUG, limit: int = 200) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := maxi(0, _entries.size() - limit)
	for index in range(start, _entries.size()):
		if int(_entries[index]["level_value"]) >= minimum:
			result.append(_entries[index].duplicate(true))
	return result


func to_text() -> String:
	var lines := PackedStringArray()
	for entry in _entries:
		lines.append("[%s] %s %s" % [entry["level"], entry["time"], entry["message"]])
	return "\n".join(lines)


func clear() -> void:
	_entries.clear()
	_sequence = 0


func count() -> int:
	return _entries.size()
