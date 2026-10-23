extends SceneTree
## @static-doc
## 作用：无头测试入口：按 `SUITE_PATHS` 声明顺序加载测试套件、逐个执行 `test_*` 方法并打印 PASS/FAIL，退出码由失败数决定（0 = 全绿）。
##
## 支持单套件过滤、显式套件列表与分片，供 `tools/test.ps1` 多进程并行调度；套件在首帧
## 而非 `_initialize` 执行，SceneTree 已就绪，UI 套件可真实挂载 shell 场景。
##
## ## 用法
## ```text
## godot --headless --path . --script res://framework/tests/test_runner.gd
## godot --headless --path . --script res://framework/tests/test_runner.gd -- --suite=ui_shell
## godot --headless --path . --script res://framework/tests/test_runner.gd -- --suites=a,b --timings=C:/abs/timings.json
## ```
##
## ## CLI 参数（`-- --key=value`）
## - `--suite=<片段>`：只跑文件名包含该片段的套件（沿用旧行为，开发时缩小范围）。
## - `--suites=a,b,c`：只跑显式列出的套件（文件名去掉 `.gd`）；`tools/test.ps1` 用它
##   给每个分片派发均衡后的套件列表。列出的套件不存在时直接报错退出，避免静默漏跑。
## - `--shard=i/n`：手工分片，按声明顺序轮转把套件分给第 i 片（0-based）。
## - `--timings=<路径>`：把本次每个套件的耗时写入 JSON（绝对路径或 `res://`），
##   `tools/test.ps1` 用上一轮的耗时做下一轮的负载均衡（首次运行无缓存时退化为轮转）。
## - `--list`：只打印套件名列表后退出，供 `tools/test.ps1` 获取分片清单，不执行测试。
##
## ## 契约
## - 每片结束仍打印 `Tests: %d passed, %d failed, %d total in %dms`，与旧版输出兼容。
## - 额外打印 `[SUITE] 名称: 通过/总数 in 耗时`，方便定位慢套件。
## - 分片是进程级隔离：每个分片独立 `Bootstrap`，套件 fixture 用各自唯一 `user://` 目录，
##   分片之间不共享内存状态；因此同一套件只能出现在一个分片里。
## @end-static-doc

const SUITE_PATHS := [
	"res://framework/tests/cases/test_semver_range.gd",
	"res://framework/tests/cases/test_schema_validator.gd",
	"res://framework/tests/cases/test_content_types_manifest.gd",
	"res://framework/tests/cases/test_module_categories.gd",
	"res://framework/tests/cases/test_schema_v2_drafts.gd",
	"res://framework/tests/cases/test_schema_v2_weapons.gd",
	"res://framework/tests/cases/test_registry.gd",
	"res://framework/tests/cases/test_mod_loading.gd",
	"res://framework/tests/cases/test_patches.gd",
	"res://framework/tests/cases/test_content_versions.gd",
	"res://framework/tests/cases/test_sdk_validation.gd",
	"res://framework/tests/cases/test_item_categories.gd",
	"res://framework/tests/cases/test_world_schema_refs.gd",
	"res://framework/tests/cases/test_world_completeness.gd",
	"res://framework/tests/cases/test_campaign_assembly.gd",
	"res://framework/tests/cases/test_campaign_start.gd",
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
	"res://framework/tests/cases/test_simulation.gd",
	"res://framework/tests/cases/test_combat.gd",
	"res://framework/tests/cases/test_fleet.gd",
	"res://framework/tests/cases/test_base.gd",
	"res://framework/tests/cases/test_auto_trade.gd",
	"res://framework/tests/cases/test_zip_pack.gd",
	"res://framework/tests/cases/test_content_asset_loader.gd",
	"res://framework/tests/cases/test_legacy_uv_assets.gd",
	"res://framework/tests/cases/test_legacy_uv_assets_b.gd",
	"res://framework/tests/cases/test_lod1_assets.gd",
	"res://framework/tests/cases/test_architecture_extension_assets.gd",
	"res://framework/tests/cases/test_base_kit_assets.gd",
	"res://framework/tests/cases/test_combat_kit_assets.gd",
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
	"res://framework/tests/cases/test_quest_service.gd",
	"res://framework/tests/cases/test_story_ui.gd",
]

var _started := false
var _unknown_suites: Array[String] = []


func _user_arg(prefix: String) -> String:
	## 读取 `--key=value` 形式的用户参数；未提供时返回空串。
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with(prefix):
			return text.substr(prefix.length())
	return ""


func _has_arg(flag: String) -> bool:
	## 判断是否提供了无值开关（如 `--list`）。
	for arg in OS.get_cmdline_user_args():
		if String(arg) == flag:
			return true
	return false


func _parse_shard() -> Array:
	## `--shard=i/n`：返回 [i, n]；未提供或格式非法时退化为单分片 [0, 1]。
	var raw := _user_arg("--shard=")
	if raw.is_empty() or not raw.contains("/"):
		return [0, 1]
	var parts := raw.split("/", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return [0, 1]
	return [maxi(0, int(parts[0])), maxi(1, int(parts[1]))]


func _selected_suites() -> Array[String]:
	## 依次应用 `--suites` / `--suite` / `--shard` 过滤，返回要执行的套件路径。
	var filter := _user_arg("--suite=")
	var explicit_raw := _user_arg("--suites=")
	var shard := _parse_shard()
	var shard_index: int = shard[0]
	var shard_count: int = shard[1]

	var explicit := {}
	if not explicit_raw.is_empty():
		for entry in explicit_raw.split(",", false):
			var name := entry.strip_edges()
			if not name.is_empty():
				explicit[name] = true

	var selected: Array[String] = []
	for index in SUITE_PATHS.size():
		var suite_path := String(SUITE_PATHS[index])
		var suite_name := suite_path.get_file().get_basename()
		if not filter.is_empty() and not suite_name.contains(filter):
			continue
		if not explicit.is_empty() and not explicit.has(suite_name):
			continue
		if shard_count > 1 and index % shard_count != shard_index:
			continue
		selected.append(suite_path)

	for name in explicit.keys():
		var found := false
		for suite_path in SUITE_PATHS:
			if String(suite_path).get_file().get_basename() == String(name):
				found = true
				break
		if not found:
			_unknown_suites.append(String(name))
	return selected


func _write_timings(path: String, suite_ms: Dictionary) -> void:
	## 把套件耗时写到磁盘；路径由调用方（test.ps1）给出，写失败不阻断测试。
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("cannot write timings file: %s" % path)
		return
	file.store_string(JSON.stringify({
		"suites": suite_ms,
		"generated_at": Time.get_unix_time_from_system(),
	}, "  "))
	file.close()


func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	if _has_arg("--list"):
		for suite_path in SUITE_PATHS:
			print(String(suite_path).get_file().get_basename())
		quit(0)
		return true
	var total := 0
	var failed := 0
	var suite_ms := {}
	var selected := _selected_suites()
	if not _unknown_suites.is_empty():
		printerr("unknown suites in --suites: %s" % ", ".join(_unknown_suites))
		quit(1)
		return true
	var shard := _parse_shard()
	var started_at := Time.get_ticks_msec()
	if shard[1] > 1:
		print("[SHARD] %d/%d: %d suites" % [shard[0] + 1, shard[1], selected.size()])
	for suite_path in selected:
		var suite_started := Time.get_ticks_msec()
		var suite_name := String(suite_path).get_file().get_basename()
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
		var suite_failed_before := failed
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
		var suite_elapsed := Time.get_ticks_msec() - suite_started
		suite_ms[suite_name] = suite_elapsed
		print("[SUITE] %s: %d/%d in %dms" % [
			suite_name, method_names.size() - (failed - suite_failed_before), method_names.size(), suite_elapsed
		])
	var elapsed_total := Time.get_ticks_msec() - started_at
	print("")
	print("Tests: %d passed, %d failed, %d total in %dms" % [
		total - failed, failed, total, elapsed_total
	])
	_write_timings(_user_arg("--timings="), suite_ms)
	FrameworkRuntime.shutdown()
	quit(0 if failed == 0 else 1)
	return true
