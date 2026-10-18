class_name TestCase
extends RefCounted
## Tiny assertion harness. Each test method starts with `test_`.

var failures: Array[String] = []
var assertions: int = 0


func reset() -> void:
	failures.clear()
	assertions = 0


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if not _values_equal(actual, expected):
		fail("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String) -> void:
	assertions += 1
	if _values_equal(actual, unexpected):
		fail("%s (value unexpectedly equals %s)" % [message, str(unexpected)])


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		fail("%s (expected %f +/- %f, got %f)" % [message, expected, tolerance, actual])


func assert_not_null(value: Variant, message: String) -> void:
	assertions += 1
	if value == null:
		fail(message)


func assert_empty(value: Variant, message: String) -> void:
	assertions += 1
	var size := 0
	if value is Array:
		size = value.size()
	elif value is Dictionary:
		size = value.size()
	elif value is String:
		size = value.length()
	elif value is PackedStringArray:
		size = value.size()
	if size != 0:
		fail("%s (expected empty, got %d entries)" % [message, size])


func assert_contains(value: Variant, needle: Variant, message: String) -> void:
	assertions += 1
	var found := false
	if value is Array:
		found = value.has(needle)
	elif value is Dictionary:
		found = value.has(needle)
	elif value is String:
		found = String(value).contains(String(needle))
	elif value is PackedStringArray:
		found = value.has(String(needle))
	if not found:
		fail("%s (missing %s)" % [message, str(needle)])


func bootstrap_core(extra: Dictionary = {}) -> Dictionary:
	var config := {
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://test_saves/%s" % _unique_suffix(),
	}
	for key in extra.keys():
		config[String(key)] = extra[key]
	var bootstrap := Bootstrap.new()
	var report := bootstrap.run(config)
	AppContext.set_active(bootstrap.context)
	return {
		"bootstrap": bootstrap,
		"context": bootstrap.context,
		"report": report,
	}


func run_core(extra: Dictionary = {}) -> Dictionary:
	var boot := bootstrap_core(extra)
	return boot


func _unique_suffix() -> String:
	return "%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]


func _values_equal(left: Variant, right: Variant) -> bool:
	var left_is_number := typeof(left) == TYPE_INT or typeof(left) == TYPE_FLOAT
	var right_is_number := typeof(right) == TYPE_INT or typeof(right) == TYPE_FLOAT
	if left_is_number and right_is_number:
		return is_equal_approx(float(left), float(right))
	return left == right
