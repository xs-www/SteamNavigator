extends SceneTree
## Headless test runner.
##
## Usage:
##   godot --headless --path . --script res://framework/tests/test_runner.gd

const SUITE_PATHS := [
	"res://framework/tests/cases/test_semver_range.gd",
	"res://framework/tests/cases/test_schema_validator.gd",
	"res://framework/tests/cases/test_registry.gd",
	"res://framework/tests/cases/test_mod_loading.gd",
	"res://framework/tests/cases/test_patches.gd",
	"res://framework/tests/cases/test_rng.gd",
	"res://framework/tests/cases/test_market_trade.gd",
	"res://framework/tests/cases/test_market_memory.gd",
	"res://framework/tests/cases/test_run_pipeline.gd",
	"res://framework/tests/cases/test_ui_views.gd",
	"res://framework/tests/cases/test_contract_flow.gd",
	"res://framework/tests/cases/test_map_constraints.gd",
	"res://framework/tests/cases/test_ship_upgrade.gd",
	"res://framework/tests/cases/test_events_effects.gd",
	"res://framework/tests/cases/test_save_load.gd",
	"res://framework/tests/cases/test_zip_pack.gd",
	"res://framework/tests/cases/test_no_core_ids.gd",
]


func _initialize() -> void:
	var total := 0
	var failed := 0
	var started_at := Time.get_ticks_msec()
	for suite_path in SUITE_PATHS:
		var script: Script = load(suite_path)
		if script == null or not script.can_instantiate():
			printerr("cannot load suite: %s" % suite_path)
			failed += 1
			continue
		var suite: TestCase = script.new()
		var method_names: Array[String] = []
		for method in suite.get_method_list():
			var method_name := String(method["name"])
			if method_name.begins_with("test_") and not method_names.has(method_name):
				method_names.append(method_name)
		method_names.sort()
		var suite_name: String = String(suite_path).get_file().get_basename()
		for method_name in method_names:
			total += 1
			suite.reset()
			var test_started := Time.get_ticks_usec()
			suite.call(method_name)
			var elapsed_ms := (Time.get_ticks_usec() - test_started) / 1000.0
			if suite.failures.is_empty():
				print("[PASS] %s::%s (%.1fms)" % [suite_name, method_name, elapsed_ms])
			else:
				failed += 1
				print("[FAIL] %s::%s" % [suite_name, method_name])
				for failure in suite.failures:
					print("       %s" % failure)
	print("")
	print("Tests: %d passed, %d failed, %d total in %dms" % [
		total - failed, failed, total, Time.get_ticks_msec() - started_at
	])
	FrameworkRuntime.shutdown()
	quit(0 if failed == 0 else 1)
