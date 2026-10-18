class_name StartupReport
extends RefCounted
## Result of one bootstrap attempt. The UI never needs to parse raw logs.

enum Status { OK, DEGRADED, FATAL }

const STATUS_NAMES := ["ok", "degraded", "fatal"]

var status: int = Status.FATAL
var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []
var disabled_mods: Dictionary = {}
var mods: Array[Dictionary] = []
var content_counts: Dictionary = {}
var scanned_roots: PackedStringArray = PackedStringArray()
var timings_ms: Dictionary = {}
var registry_frozen: bool = false
var created_at: String = ""
var framework_version: String = FrameworkInfo.VERSION
var api_version: String = FrameworkInfo.API_VERSION
var content_schema: String = FrameworkInfo.CONTENT_SCHEMA


func add_error(code: String, message: String, fields: Dictionary = {}) -> void:
	var entry := {
		"code": code,
		"message": message,
		"severity": String(fields.get("severity", "error")),
	}
	for key in fields.keys():
		entry[String(key)] = fields[key]
	errors.append(entry)


func add_warning(code: String, message: String, fields: Dictionary = {}) -> void:
	var entry := {"code": code, "message": message}
	for key in fields.keys():
		entry[String(key)] = fields[key]
	warnings.append(entry)


func add_fatal(code: String, message: String, fields: Dictionary = {}) -> void:
	var enriched := fields.duplicate(true)
	enriched["severity"] = "fatal"
	add_error(code, message, enriched)


func has_fatal() -> bool:
	for entry in errors:
		if String(entry.get("severity", "error")) == "fatal":
			return true
	return false


func fatal_errors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in errors:
		if String(entry.get("severity", "error")) == "fatal":
			result.append(entry)
	return result


func finalize() -> void:
	if has_fatal():
		status = Status.FATAL
	elif not errors.is_empty() or not warnings.is_empty() or not disabled_mods.is_empty():
		status = Status.DEGRADED
	else:
		status = Status.OK
	if created_at.is_empty():
		created_at = Time.get_datetime_string_from_system(true)


func status_name() -> String:
	return STATUS_NAMES[status]


func status_key() -> String:
	return "ui.status.%s" % status_name()


func is_ok() -> bool:
	return status == Status.OK


func content_total() -> int:
	var total := 0
	for key in content_counts.keys():
		total += int(content_counts[key])
	return total


func to_dict() -> Dictionary:
	return {
		"status": status_name(),
		"framework_version": framework_version,
		"api_version": api_version,
		"content_schema": content_schema,
		"created_at": created_at,
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
		"disabled_mods": disabled_mods.duplicate(true),
		"mods": mods.duplicate(true),
		"content_counts": content_counts.duplicate(true),
		"scanned_roots": Array(scanned_roots),
		"timings_ms": timings_ms.duplicate(true),
		"registry_frozen": registry_frozen,
	}


func format_text() -> String:
	var lines := PackedStringArray()
	lines.append("Steam Navigator framework %s (mod API %s)" % [framework_version, api_version])
	lines.append("status: %s" % status_name())
	lines.append("registry frozen: %s" % str(registry_frozen))
	lines.append("content definitions: %d" % content_total())
	for key in content_counts.keys():
		lines.append("  %-22s %d" % [key, int(content_counts[key])])
	if not mods.is_empty():
		lines.append("mods:")
		for mod in mods:
			lines.append("  %s %s (%s)" % [mod.get("id", "?"), mod.get("version", "?"), mod.get("source", "?")])
	if not disabled_mods.is_empty():
		lines.append("disabled mods:")
		for mod_id in disabled_mods.keys():
			lines.append("  %s: %s" % [mod_id, disabled_mods[mod_id]])
	if not errors.is_empty():
		lines.append("errors:")
		for entry in errors:
			lines.append("  [%s] %s" % [entry.get("severity", "error"), entry.get("message", "")])
	if not warnings.is_empty():
		lines.append("warnings:")
		for entry in warnings:
			lines.append("  %s" % entry.get("message", ""))
	if not timings_ms.is_empty():
		var parts := PackedStringArray()
		for key in timings_ms.keys():
			parts.append("%s=%dms" % [key, int(timings_ms[key])])
		lines.append("timings: " + ", ".join(parts))
	return "\n".join(lines)
