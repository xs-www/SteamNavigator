extends SceneTree
## Headless test runner.
##
## Usage:
##   godot --headless --path . --script res://framework/tests/test_runner.gd
##
## Suites run on the first frame rather than in `_initialize`, so the SceneTree
## is already set up. UI suites can then parent the shell scene for real, which
## makes engine notifications (`_ready`, viewport, audio) behave as they do in
## the game instead of silently staying undelivered.

const SUITE_PATHS := [
	"res://framework/tests/cases/test_semver_range.gd",
	"res://framework/tests/cases/test_schema_validator.gd",
	"res://framework/tests/cases/test_content_types_manifest.gd",
	"res://framework/tests/cases/test_schema_v2_drafts.gd",
	"res://framework/tests/cases/test_schema_v2_weapons.gd",
	"res://framework/tests/cases/test_registry.gd",
	"res://framework/tests/cases/test_mod_loading.gd",
	"res://framework/tests/cases/test_patches.gd",
	"res://framework/tests/cases/test_content_versions.gd",
	"res://framework/tests/cases/test_rng.gd",
	"res://framework/tests/cases/test_market_trade.gd",
	"res://framework/tests/cases/test_market_memory.gd",
	"res://framework/tests/cases/test_supply.gd",
	"res://framework/tests/cases/test_run_pipeline.gd",
	"res://framework/tests/cases/test_ui_views.gd",
	"res://framework/tests/cases/test_ui_shell.gd",
	"res://framework/tests/cases/test_shipyard_refit.gd",
	"res://framework/tests/cases/test_ship_modules.gd",
	"res://framework/tests/cases/test_settings.gd",
	"res://framework/tests/cases/test_contract_flow.gd",
	"res://framework/tests/cases/test_contract_refresh.gd",
	"res://framework/tests/cases/test_map_constraints.gd",
	"res://framework/tests/cases/test_ship_upgrade.gd",
	"res://framework/tests/cases/test_warehouse_craft.gd",
	"res://framework/tests/cases/test_craft_wait.gd",
	"res://framework/tests/cases/test_victory.gd",
	"res://framework/tests/cases/test_full_clear.gd",
	"res://framework/tests/cases/test_events_effects.gd",
	"res://framework/tests/cases/test_save_load.gd",
	"res://framework/tests/cases/test_save_migration.gd",
	"res://framework/tests/cases/test_campaign_state.gd",
	"res://framework/tests/cases/test_zip_pack.gd",
	"res://framework/tests/cases/test_content_asset_loader.gd",
	"res://framework/tests/cases/test_legacy_uv_assets.gd",
	"res://framework/tests/cases/test_legacy_uv_assets_b.gd",
	"res://framework/tests/cases/test_lod1_assets.gd",
	"res://framework/tests/cases/test_ship_weapon_sockets.gd",
	"res://framework/tests/cases/test_ship_gun_ports.gd",
	"res://framework/tests/cases/test_rig_kit.gd",
	"res://framework/tests/cases/test_ship_weapon_assembly.gd",
	"res://framework/tests/cases/test_ship_visual_assembler.gd",
	"res://framework/tests/cases/test_no_core_ids.gd",
	"res://framework/tests/cases/test_stage_host.gd",
	"res://framework/tests/cases/test_world_generator.gd",
	"res://framework/tests/cases/test_fog_system.gd",
	"res://framework/tests/cases/test_sea_chart.gd",
	"res://framework/tests/cases/test_voyage_presentation.gd",
	"res://framework/tests/cases/test_voyage_flow.gd",
	"res://framework/tests/cases/test_exploration.gd",
	"res://framework/tests/cases/test_story.gd",
	"res://framework/tests/cases/test_task_view.gd",
	"res://framework/tests/cases/test_story_ui.gd",
]

var _started := false


func _suite_filter() -> String:
	## 可选单套件过滤：`-- --suite=<名字片段>`（用于只跑资产 / 单一子系统套件）。
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			return arg.split("=", 1)[1]
	return ""


func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	var total := 0
	var failed := 0
	var filter := _suite_filter()
	var started_at := Time.get_ticks_msec()
	for suite_path in SUITE_PATHS:
		if filter != "" and not String(suite_path).get_file().get_basename().contains(filter):
			continue
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
	return true