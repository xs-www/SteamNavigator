## @static-doc
## 作用：CPU 侧性能取证探针（headless）：启动链路分阶段耗时、`run.start` worldgen
## 分布、命令/查询 p50/p95 与 GameState 深拷贝成本、存档/自动存档开销、每页
## `_rebuild_ui` 成本与查询次数、交互端到端卡顿（命令 + 整页重建）、空闲
## steady-state 每帧 CPU / 对象数增长，以及 `.snavmod.zip`（release 路径）与
## loose `dev_mods` 的启动/首屏对比。
##
## - 关键依赖：`Bootstrap`、`AppContext`、`CommandBus`/`QueryBus`、`CampaignFactory`、
##   `SaveService`、`framework/ui/shell/main.tscn`、`Performance`
##
## ## 契约与约束
## - 只读：不修改 `framework/` / `project.godot` / `dev_mods`；存档写 `user://perf_saves`。
## - 不抢 GPU：必须 `--headless`；draw calls / GPU 时间不在本工具口径内。
## - 不改源码做计数：查询/命令的**处理器**耗时用运行时 `register()` 包一层 Callable 统计
##   （`QueryBus`/`CommandBus` 的 `_handlers` 是普通字典）。`execute()` 里的
##   `GameState.clone()` 不在 handler 计时内，因此每页另外用 `state.clone()` 实测值补上。
## - 每帧 CPU 用 `await process_frame` 的墙钟间隔做口径：headless 没有 vsync/渲染，
##   这个间隔就是整帧 CPU。`Performance.TIME_PROCESS` 在 headless + `--fixed-fps 60`
##   下会返回一个不随帧变化的陈旧值（原样写进 JSON 但不作结论依据）。
## - zip 模式必须最后跑：`ProjectSettings.load_resource_pack` 挂了就卸不掉。
## - 输出：stdout 摘要 + `res://.design/perf/cpu_probe_loose.json`（`--mode=zip` 时
##   `cpu_probe_zip.json`）。任何阶段异常都不静默：写进 `notes` 并继续下一阶段。
## - 复现命令（仓库根目录）：
##   `godot --headless --path . --fixed-fps 60 --script res://tools/godot/perf_cpu_probe.gd -- --mode=all`
##   `godot --headless --path . --script res://tools/godot/perf_cpu_probe.gd -- --mode=boot`
##   `godot --headless --path . --script res://tools/godot/perf_cpu_probe.gd -- --mode=zip --zip=release/SteamNavigator/mods`
## @end-static-doc

extends SceneTree

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const SEA_CHART_VIEW_SCRIPT := "res://framework/ui/components/sn_sea_chart_view.gd"
const STEADY := "core:starting_scenario/steady"
const STANDARD_STRATEGY := "core:boiler_strategy/standard"
const ZIP_SCAN_ROOT := "res://dist/mods"
const SAVE_SUBDIR := "user://perf_saves"
const OUTPUT_LOOSE := "res://.design/perf/cpu_probe_loose.json"
const OUTPUT_ZIP := "res://.design/perf/cpu_probe_zip.json"
const WATCHDOG_SECONDS := 1200.0

## Fixed seeds so the run is reproducible; 8 seeds expose the worldgen retry tail.
const SEEDS := [5201, 12345, 777, 4242, 20260601, 31, 6161, 990001]
const BOOT_RUNS := 5
const ZIP_BOOT_RUNS := 3
const QUERY_ITERS := 24
const COMMAND_ITERS := 20
const SAVE_ITERS := 6
const PAGE_ITERS := 5
const STEADY_FRAMES := 3600
const PAGE_STEADY_FRAMES := 600
const PRESENTATION_STEADY_FRAMES := 600

var _mode := "all"
var _zip_dir := ZIP_SCAN_ROOT
var _out := {}
var _notes: Array[String] = []
var _finished := false
var _script_start_msec := 0
var _query_stats: Dictionary = {}
var _command_stats: Dictionary = {}
var _context: AppContext = null
var _shell: Control = null


func _init() -> void:
	_script_start_msec = Time.get_ticks_msec()
	_parse_args()
	_watchdog()
	_run()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--mode="):
			_mode = text.trim_prefix("--mode=")
		elif text == "--mode=boot":
			_mode = "boot"
		elif text.begins_with("--zip="):
			_zip_dir = text.trim_prefix("--zip=")
	_print_probe("mode=%s zip_dir=%s engine_ready_ms=%d" % [_mode, _zip_dir, _script_start_msec])


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	_notes.append("WATCHDOG timeout after %ds; dumping partial results" % int(WATCHDOG_SECONDS))
	_dump()
	push_error("perf_cpu_probe: watchdog timeout")
	quit(2)


func _run() -> void:
	await process_frame
	await process_frame
	_out["meta"] = _meta()
	if _mode == "boot":
		var boot := await _measure_boot(_boot_cfg(false), 3)
		_out["boot_only"] = _strip_context(boot)
		_print_boot("loose", boot)
		_finish()
		return
	if _mode == "zip":
		await _phase_zip()
		_finish()
		return
	if _mode == "zipsteps":
		await _phase_zipsteps()
		_finish()
		return
	if _mode == "interactions":
		await _phase_interactions_only()
		_finish()
		return
	await _phase_all()
	_finish()


## Short mode: only the one-player-action end-to-end latency (command + full rebuild),
## with the command/query/autosave decomposition of a single shell interaction.
func _phase_interactions_only() -> void:
	var boot := await _measure_boot(_boot_cfg(false), 1)
	_context = boot["context"]
	AppContext.set_active(_context)
	_install_bus_instrumentation()
	_fresh_run()
	_shell = _mount_shell()
	if _shell == null:
		return
	await _settle_frames(5)
	_out["interactions_autosave_enabled"] = bool(_context.autosave_enabled)
	await _phase_interactions()
	_out["notes"] = _notes


## Isolation of the zip path: raw read/open/list, scan, mount and compile for both the
## HEAD content pack (dist/mods) and the v0.2.0-dev.3-era pack (release/.../mods).
## Used to explain why the packed path boots slower than loose dev_mods.
func _phase_zipsteps() -> void:
	var dirs := [
		{"label": "dist_head_content", "dir": ZIP_SCAN_ROOT},
		{"label": "release_dev3_content", "dir": "release/SteamNavigator/mods"},
	]
	for entry in dirs:
		var dir := String(entry["dir"])
		var zip_path := dir.path_join("core-1.0.0.snavmod.zip")
		var steps: Dictionary = {}
		if not FileAccess.file_exists(zip_path):
			_notes.append("zipsteps: missing " + zip_path)
			continue
		var t := Time.get_ticks_usec()
		var raw := FileAccess.get_file_as_bytes(zip_path)
		steps["read_all_bytes_ms"] = _ms_since(t)
		steps["zip_bytes"] = raw.size()
		raw = PackedByteArray()
		t = Time.get_ticks_usec()
		var reader := ZIPReader.new()
		var opened := reader.open(zip_path)
		var entries := reader.get_files()
		steps["zipreader_open+list_ms"] = _ms_since(t)
		steps["entries"] = entries.size()
		reader.close()
		var config := {
			"scan_roots": PackedStringArray([dir]),
			"allow_loose": false,
			"mount_packs": true,
			"autosave": false,
			"log_to_console": false,
			"save_directory": SAVE_SUBDIR,
		}
		var pipeline := _measure_mod_pipeline(config)
		steps["pipeline_steps_ms"] = pipeline.get("steps_summary", {})
		steps["content_total"] = pipeline["rounds"][0].get("content_total", 0) if not pipeline["rounds"].is_empty() else 0
		steps["mount_opened"] = opened
		_out["zipsteps_" + String(entry["label"])] = steps
		var summary: Dictionary = steps["pipeline_steps_ms"]
		var parts: Array[String] = []
		for key in ["scan", "mount", "compile"]:
			if summary.has(key):
				parts.append("%s=%.1f" % [key, float(summary[key]["p50"])])
		_print_probe("ZIPSTEPS %-22s read_all=%.1fms open+list=%.1fms entries=%d | %s" % [
			String(entry["label"]), float(steps["read_all_bytes_ms"]),
			float(steps["zipreader_open+list_ms"]), int(steps["entries"]), ", ".join(parts),
		])
		AppContext.set_active(null)
	_out["notes"] = _notes


# ---------------------------------------------------------------------------
# Phase: boot
# ---------------------------------------------------------------------------

## Bootstrap config: loose dev_mods (editor/dev path) or the packed zip (release path).
func _boot_cfg(use_zip: bool) -> Dictionary:
	if use_zip:
		return {
			"scan_roots": PackedStringArray([_zip_dir]),
			"allow_loose": false,
			"mount_packs": true,
			"autosave": false,
			"log_to_console": false,
			"save_directory": SAVE_SUBDIR,
		}
	return {
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"autosave": false,
		"log_to_console": false,
		"save_directory": SAVE_SUBDIR,
	}


## Runs `Bootstrap.run` `runs` times, collecting its own `timings_ms` plus my wall clock.
func _measure_boot(config: Dictionary, runs: int) -> Dictionary:
	var rows: Array = []
	var last_context: AppContext = null
	for i in runs:
		var started := Time.get_ticks_usec()
		var bootstrap := Bootstrap.new()
		var report: StartupReport = bootstrap.run(config)
		var wall_ms := float(Time.get_ticks_usec() - started) / 1000.0
		AppContext.set_active(bootstrap.context)
		last_context = bootstrap.context
		var timings: Dictionary = {}
		for key in report.timings_ms.keys():
			timings[String(key)] = int(report.timings_ms[key])
		rows.append({
			"run": i,
			"wall_ms": wall_ms,
			"timings_ms": timings,
			"content_total": report.content_total(),
			"report_status": report.status_name(),
			"fatal": report.has_fatal(),
		})
	var per_key := {}
	for key in ["scan", "resolve", "mount", "compile", "validate", "total", "bootstrap"]:
		var values: Array = []
		for row in rows:
			if row["timings_ms"].has(key):
				values.append(float(row["timings_ms"][key]))
		per_key[key] = _summarize(values)
	var walls: Array = []
	for row in rows:
		walls.append(float(row["wall_ms"]))
	return {
		"runs": rows,
		"per_key": per_key,
		"wall": _summarize(walls),
		"context": last_context,
	}


func _print_boot(label: String, boot: Dictionary) -> void:
	var per: Dictionary = boot["per_key"]
	var parts: Array[String] = []
	for key in ["scan", "resolve", "mount", "compile", "validate", "total", "bootstrap"]:
		var entry: Dictionary = per.get(key, {})
		if int(entry.get("n", 0)) > 0:
			parts.append("%s p50=%.1f max=%.1f" % [key, float(entry["p50"]), float(entry["max"])])
	_print_probe("BOOT %s: %s | wall(p50/max)=%.1f/%.1f ms" % [
		label, "; ".join(parts),
		float(boot["wall"].get("p50", 0.0)), float(boot["wall"].get("max", 0.0)),
	])


# ---------------------------------------------------------------------------
# Phase: all
# ---------------------------------------------------------------------------

func _phase_all() -> void:
	# 1) Startup chain (loose) + an independent re-measure of the mod pipeline steps.
	var loose_boot := await _measure_boot(_boot_cfg(false), BOOT_RUNS)
	_out["boot_loose"] = _strip_context(loose_boot)
	_print_boot("loose", loose_boot)
	_out["mod_pipeline_loose"] = await _measure_mod_pipeline(_boot_cfg(false))
	_out["mod_scan_repeat"] = _measure_scan_repeat()

	# A dedicated context for every stateful phase below.
	var main_boot := await _measure_boot(_boot_cfg(false), 1)
	_context = main_boot["context"]
	AppContext.set_active(_context)
	if _context == null or _context.report == null or _context.report.has_fatal():
		_notes.append("bootstrap reported fatal errors; later phases may be meaningless")
	_install_bus_instrumentation()

	# 2) worldgen / run.start distribution
	_out["run_start"] = _measure_run_start()
	_context.reset_state()
	var start := _context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": 5201})
	if not bool(start.get("ok", false)):
		_notes.append("run.start failed: %s" % str(start))
	_out["state_start"] = _measure_state_bytes()

	# 3) queries + commands
	_out["queries"] = _measure_queries()
	_out["commands"] = _measure_commands()
	_out["state_after"] = _measure_state_bytes()

	# 4) save / autosave
	_out["save"] = _measure_save()

	# 5) UI shell: per-page rebuild + query counts, then interaction latency
	await _phase_ui()
	_out["micro_bench"] = await _micro_bench_sea_chart()
	await _phase_interactions()
	await _phase_at_sea()
	# 6) idle steady-state sampling per page
	await _phase_steady()
	# 7) menu pages (needs an empty state; done last so it cannot disturb the game)
	await _phase_menu_pages()

	await _teardown_shell()
	_context = null

	# 8) release path (zip) — must be last, the mounted pack cannot be unloaded.
	await _phase_zip()
	_out["notes"] = _notes


# ---------------------------------------------------------------------------
# Mod pipeline re-measure (independent from StartupReport.timings_ms)
# ---------------------------------------------------------------------------

## Replays `ModLoader.load_mods` step by step on a throw-away AppContext so each
## stage gets my own `Time.get_ticks_usec()` numbers (cross-check of the report keys).
func _measure_mod_pipeline(config: Dictionary) -> Dictionary:
	var result := {"rounds": []}
	for round_index in 3:
		var steps: Dictionary = {}
		var t := Time.get_ticks_usec()
		var ctx := AppContext.new(config)
		AppContext.set_active(ctx)
		ctx.localization.load_base_tables()
		steps["app_context+locale"] = _ms_since(t)

		var validator := SchemaValidator.new()
		t = Time.get_ticks_usec()
		var scan := ModScanner.new(validator).scan(config["scan_roots"], bool(config["allow_loose"]))
		steps["scan"] = _ms_since(t)

		var packages: Array[ModPackage] = []
		for package in scan["packages"]:
			packages.append(package)

		t = Time.get_ticks_usec()
		var resolution := DependencyResolver.new().resolve(packages, FrameworkInfo.CAPABILITIES)
		steps["resolve"] = _ms_since(t)

		var packages_by_id: Dictionary = {}
		var order := PackedStringArray()
		for mod_id in resolution["order"]:
			for package in packages:
				if package.id == String(mod_id):
					packages_by_id[package.id] = package
					order.append(package.id)
					break

		t = Time.get_ticks_usec()
		var mount_failures := 0
		if bool(config["mount_packs"]):
			for mod_id in order:
				var package: ModPackage = packages_by_id[mod_id]
				if not package.source.is_pack():
					continue
				if not ProjectSettings.load_resource_pack(package.source.get_pack_path(), false):
					mount_failures += 1
		steps["mount"] = _ms_since(t)

		t = Time.get_ticks_usec()
		var compiler := ContentCompiler.new(ctx.registries, ctx.localization, ctx.assets, ctx.logger, validator)
		var compiled: Dictionary = compiler.compile(packages_by_id, order)
		steps["compile"] = _ms_since(t)

		t = Time.get_ticks_usec()
		var cross: Dictionary = CrossReferenceValidator.new().validate(ctx.registries)
		var completeness: Dictionary = CoreCompletenessChecker.check(ctx.registries, packages_by_id, order)
		steps["cross_validate+completeness"] = _ms_since(t)

		t = Time.get_ticks_usec()
		ctx.registries.freeze_all()
		steps["freeze"] = _ms_since(t)

		t = Time.get_ticks_usec()
		FrameworkApi.register(ctx)
		steps["framework_api_register"] = _ms_since(t)

		result["rounds"].append({
			"round": round_index,
			"steps_ms": steps,
			"content_total": ctx.registries.total_count(),
			"errors": Array(compiled.get("errors", [])).size() + Array(cross.get("errors", [])).size() + Array(completeness.get("errors", [])).size(),
			"mount_failures": mount_failures,
		})
	var step_values: Dictionary = {}
	for round_entry in result["rounds"]:
		for key in round_entry["steps_ms"].keys():
			if not step_values.has(key):
				step_values[key] = []
			step_values[key].append(float(round_entry["steps_ms"][key]))
	var summary := {}
	for key in step_values.keys():
		summary[key] = _summarize(step_values[key])
	result["steps_summary"] = summary
	var parts: Array[String] = []
	for key in ["app_context+locale", "scan", "resolve", "mount", "compile", "cross_validate+completeness", "freeze", "framework_api_register"]:
		if summary.has(key):
			parts.append("%s=%.1f" % [key, float(summary[key]["p50"])])
	_print_probe("MOD PIPELINE (median of 3): " + ", ".join(parts))
	return result


func _measure_scan_repeat() -> Dictionary:
	var scanner := ModScanner.new(SchemaValidator.new())
	var roots := PackedStringArray(["res://dev_mods"])
	var samples: Array = []
	for i in 4:
		var t := Time.get_ticks_usec()
		scanner.scan(roots, true)
		samples.append(_ms_since(t))
	return {"loose_scan_ms": samples, "summary": _summarize(samples)}


# ---------------------------------------------------------------------------
# Deep copy / state size
# ---------------------------------------------------------------------------

func _measure_state_bytes() -> Dictionary:
	if _context == null or not _context.has_run():
		return {}
	var clone_samples: Array = []
	var dict_samples: Array = []
	var replace_samples: Array = []
	var data := _context.state.to_dict()
	var json_bytes := JsonUtils.canonical_stringify(data).to_utf8_buffer().size()
	var var_bytes := var_to_bytes(data).size()
	for i in 8:
		var t := Time.get_ticks_usec()
		var clone := _context.state.clone()
		clone_samples.append(_ms_since(t))
		t = Time.get_ticks_usec()
		clone.to_dict()
		dict_samples.append(_ms_since(t))
		t = Time.get_ticks_usec()
		_context.state.replace_with(clone)
		replace_samples.append(_ms_since(t))
	return {
		"json_bytes": json_bytes,
		"var_bytes": var_bytes,
		"clone_ms": _summarize(clone_samples),
		"to_dict_ms": _summarize(dict_samples),
		"replace_with_ms": _summarize(replace_samples),
		"note": "clone+replace_with = one successful command; one query = clone only",
	}


# ---------------------------------------------------------------------------
# run.start worldgen
# ---------------------------------------------------------------------------

func _measure_run_start() -> Dictionary:
	var rows: Array = []
	for seed_value in SEEDS:
		_context.reset_state()
		var t := Time.get_ticks_usec()
		var created: Dictionary = CampaignFactory.create_default_campaign(_context, STEADY, int(seed_value), false)
		var create_ms := _ms_since(t)
		var ok := bool(created.get("ok", false))
		var state_bytes := 0
		if ok:
			var state: GameState = created["data"]["state"]
			state_bytes = JsonUtils.canonical_stringify(state.to_dict()).to_utf8_buffer().size()
		_context.reset_state()
		t = Time.get_ticks_usec()
		var command := _context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": int(seed_value)})
		var command_ms := _ms_since(t)
		rows.append({
			"seed": int(seed_value),
			"create_ms": create_ms,
			"command_ms": command_ms,
			"ok": ok and bool(command.get("ok", false)),
			"state_json_bytes": state_bytes,
		})
	var creates: Array = []
	var commands: Array = []
	for row in rows:
		creates.append(float(row["create_ms"]))
		commands.append(float(row["command_ms"]))
	var summary := {"create_ms": _summarize(creates), "command_ms": _summarize(commands), "seeds": rows}
	_print_probe("RUN.START worldgen create p50=%.1f max=%.1f | command p50=%.1f max=%.1f | state=%dB" % [
		float(summary["create_ms"]["p50"]), float(summary["create_ms"]["max"]),
		float(summary["command_ms"]["p50"]), float(summary["command_ms"]["max"]),
		int(rows[0]["state_json_bytes"]) if not rows.is_empty() else 0,
	])
	return summary


# ---------------------------------------------------------------------------
# Bus instrumentation (runtime wrapper, no source edits)
# ---------------------------------------------------------------------------

func _install_bus_instrumentation() -> void:
	_query_stats = {"total_calls": 0, "total_us": 0, "handlers": {}}
	for name in _context.queries.names():
		var key := StringName(name)
		var original: Callable = _context.queries._handlers[key]
		_query_stats["handlers"][key] = {"calls": 0, "us": 0}
		_context.queries.register(key, _query_wrapper(key, original))
	_command_stats = {"total_calls": 0, "total_us": 0, "handlers": {}}
	for name in _context.commands.names():
		var key := StringName(name)
		var original: Callable = _context.commands._handlers[key]
		_command_stats["handlers"][key] = {"calls": 0, "us": 0}
		_context.commands.register(key, _command_wrapper(key, original))


func _query_wrapper(key: StringName, original: Callable) -> Callable:
	return func(params: Dictionary, ctx) -> Variant:
		var t := Time.get_ticks_usec()
		var result: Variant = original.call(params, ctx)
		var elapsed := Time.get_ticks_usec() - t
		_query_stats["total_calls"] = int(_query_stats["total_calls"]) + 1
		_query_stats["total_us"] = int(_query_stats["total_us"]) + elapsed
		var handler: Dictionary = _query_stats["handlers"][key]
		handler["calls"] = int(handler["calls"]) + 1
		handler["us"] = int(handler["us"]) + elapsed
		return result


func _command_wrapper(key: StringName, original: Callable) -> Callable:
	return func(params: Dictionary, ctx) -> Variant:
		var t := Time.get_ticks_usec()
		var result: Variant = original.call(params, ctx)
		var elapsed := Time.get_ticks_usec() - t
		_command_stats["total_calls"] = int(_command_stats["total_calls"]) + 1
		_command_stats["total_us"] = int(_command_stats["total_us"]) + elapsed
		var handler: Dictionary = _command_stats["handlers"][key]
		handler["calls"] = int(handler["calls"]) + 1
		handler["us"] = int(handler["us"]) + elapsed
		return result


func _reset_query_stats() -> void:
	_query_stats["total_calls"] = 0
	_query_stats["total_us"] = 0
	for key in _query_stats["handlers"].keys():
		_query_stats["handlers"][key] = {"calls": 0, "us": 0}


func _reset_command_stats() -> void:
	_command_stats["total_calls"] = 0
	_command_stats["total_us"] = 0
	for key in _command_stats["handlers"].keys():
		_command_stats["handlers"][key] = {"calls": 0, "us": 0}


func _query_calls_snapshot() -> Dictionary:
	var per_query := {}
	for key in _query_stats["handlers"].keys():
		var handler: Dictionary = _query_stats["handlers"][key]
		if int(handler["calls"]) > 0:
			per_query[String(key)] = {"calls": int(handler["calls"]), "handler_ms": float(handler["us"]) / 1000.0}
	return per_query


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func _measure_queries() -> Dictionary:
	var clone_ms := float(_out.get("state_start", {}).get("clone_ms", {}).get("p50", 0.0))
	var state_bytes := int(_out.get("state_start", {}).get("json_bytes", 0))
	var plans := [
		&"app.view", &"port.view", &"market.view", &"sea_chart.view", &"task.view",
		&"story.view", &"victory.view", &"shipyard.view", &"map.view", &"intel.view",
	]
	var rows := {}
	for name in plans:
		var samples: Array = []
		var handler_samples: Array = []
		var ok_count := 0
		var data_bytes := 0
		var probe_result := _context.queries.execute(name, {})
		if bool(probe_result.get("ok", false)):
			data_bytes = JsonUtils.canonical_stringify(probe_result.get("data", {})).to_utf8_buffer().size()
		for i in QUERY_ITERS:
			_reset_query_stats()
			var t := Time.get_ticks_usec()
			var result := _context.queries.execute(name, {})
			samples.append(_ms_since(t))
			if bool(result.get("ok", false)):
				ok_count += 1
			handler_samples.append(float(_query_stats["total_us"]) / 1000.0)
		rows[String(name)] = {
			"n": samples.size(),
			"ok": ok_count,
			"execute_ms": _summarize(samples),
			"handler_ms": _summarize(handler_samples),
			"clone_ms_reference": clone_ms,
			"deep_copies_per_call": 1,
			"state_json_bytes": state_bytes,
			"result_json_bytes": data_bytes,
		}
	var parts: Array[String] = []
	for name in plans:
		parts.append("%s p50=%.1f" % [String(name), float(rows[String(name)]["execute_ms"]["p50"])])
	_print_probe("QUERIES execute p50: " + ", ".join(parts))
	return rows


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

## Each sample runs on a freshly started run so the command is actually feasible and
## every sample sees the same state size (reproducible; run.start itself is not timed).
func _fresh_run() -> void:
	_context.reset_state()
	_context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": 5201})
	_context.state.set_money(5000)


func _measure_commands() -> Dictionary:
	_context.autosave_enabled = false
	var rows := {}
	rows["trade.buy"] = _bench_command(&"trade.buy", COMMAND_ITERS, _gen_trade_buy, Callable())
	rows["trade.sell"] = _bench_command(&"trade.sell", COMMAND_ITERS, _gen_trade_sell, Callable())
	rows["voyage.start"] = _bench_command(&"voyage.start", COMMAND_ITERS, _gen_voyage_start, Callable())
	rows["ship.install_module"] = _bench_command(&"ship.install_module", COMMAND_ITERS, _gen_install, Callable())
	rows["ship.uninstall_module"] = _bench_command(&"ship.uninstall_module", COMMAND_ITERS, _gen_uninstall, Callable())
	rows["port.wait"] = _bench_command(&"port.wait", COMMAND_ITERS, _gen_port_wait, Callable())
	var parts: Array[String] = []
	for key in rows.keys():
		parts.append("%s ok=%d/%d p50=%.1f p95=%.1f" % [
			key, int(rows[key]["ok"]), int(rows[key]["n"]),
			float(rows[key]["execute_ms"]["p50"]), float(rows[key]["execute_ms"]["p95"]),
		])
	_print_probe("COMMANDS: " + ", ".join(parts))
	return rows


func _gen_trade_buy() -> Dictionary:
	for row in _market_rows():
		if int(row.get("stock", 0)) > 2 and bool(row.get("buyable", true)):
			return {"item_id": String(row["item_id"]), "amount": 1, "destination": "cargo"}
	return {"item_id": "", "amount": 1, "destination": "cargo"}


func _gen_trade_sell() -> Dictionary:
	# Buy one first so the sell has something to move (not part of the sample).
	_context.commands.execute(&"trade.buy", _gen_trade_buy())
	for row in _market_rows():
		if int(row.get("cargo_amount", 0)) > 0:
			return {"item_id": String(row["item_id"]), "amount": 1, "source": "cargo"}
	return {"item_id": "", "amount": 1, "source": "cargo"}


func _gen_voyage_start() -> Dictionary:
	var neighbors := MapOps.neighbors(_context.state.world(), _context.state.current_port_id())
	var destination := String(neighbors[0]) if not neighbors.is_empty() else ""
	return {"destination_id": destination, "strategy_id": STANDARD_STRATEGY}


func _gen_install() -> Dictionary:
	return {"module_id": "core:module/chart_room", "source": "purchase"}


func _gen_uninstall() -> Dictionary:
	# Install one first so the uninstall has work to do (not part of the sample).
	_context.commands.execute(&"ship.install_module", {"module_id": "core:module/chart_room", "source": "purchase"})
	return {"module_id": "core:module/chart_room"}


func _gen_port_wait() -> Dictionary:
	return {"hours": 12}


func _market_rows() -> Array:
	var view := _context.queries.execute(&"port.view")
	if bool(view.get("ok", false)):
		var data: Dictionary = view.get("data", {})
		return Array(data.get("market", []))
	return []


func _bench_command(name: StringName, iterations: int, params_fn: Callable, _unused: Callable) -> Dictionary:
	var samples: Array = []
	var handler_samples: Array = []
	var ok_count := 0
	var codes := {}
	for i in iterations:
		_fresh_run()
		var params: Dictionary = params_fn.call()
		_reset_command_stats()
		var t := Time.get_ticks_usec()
		var result := _context.commands.execute(name, params)
		samples.append(_ms_since(t))
		handler_samples.append(float(_command_stats["total_us"]) / 1000.0)
		var ok := bool(result.get("ok", false))
		if ok:
			ok_count += 1
		else:
			var code := String(result.get("error_code", "?"))
			codes[code] = int(codes.get(code, 0)) + 1
		# A voyage may stop at an event; pick a safe option so the arrival completes.
		if name == &"voyage.start":
			var data: Dictionary = result.get("data", {})
			if data.get("event", null) is Dictionary and not bool(data.get("failed", false)):
				var options: Array = (data["event"] as Dictionary).get("option_ids", [])
				if not options.is_empty():
					_context.commands.execute(&"event.choose_option", {"option_id": String(options[0])})
	var clone_ms := float(_out.get("state_start", {}).get("clone_ms", {}).get("p50", 0.0))
	var replace_ms := float(_out.get("state_start", {}).get("replace_with_ms", {}).get("p50", 0.0))
	return {
		"n": samples.size(),
		"ok": ok_count,
		"error_codes": codes,
		"execute_ms": _summarize(samples),
		"handler_ms": _summarize(handler_samples),
		"deep_copies": 2,
		"copy_overhead_ms_estimate": clone_ms + replace_ms,
		"deep_copy_json_bytes": int(_out.get("state_start", {}).get("json_bytes", 0)),
	}


# ---------------------------------------------------------------------------
# Save / autosave
# ---------------------------------------------------------------------------

func _measure_save() -> Dictionary:
	var result := {}
	var save_samples: Array = []
	var load_samples: Array = []
	for i in SAVE_ITERS:
		var t := Time.get_ticks_usec()
		var saved := _context.save.save_slot("perf_probe", _context.state, _context.save_meta())
		save_samples.append(_ms_since(t))
		if not bool(saved.get("ok", false)):
			_notes.append("save_slot failed: %s" % str(saved))
		t = Time.get_ticks_usec()
		var loaded := _context.save.load_slot("perf_probe")
		load_samples.append(_ms_since(t))
		if not bool(loaded.get("ok", false)):
			_notes.append("load_slot failed: %s" % str(loaded))
	var path := ProjectSettings.globalize_path("%s/perf_probe.json" % SAVE_SUBDIR)
	var file_bytes := 0
	if FileAccess.file_exists(path):
		file_bytes = FileAccess.get_file_as_bytes(path).size()
	result["save_slot_ms"] = _summarize(save_samples)
	result["load_slot_ms"] = _summarize(load_samples)
	result["file_bytes"] = file_bytes

	# Breakdown of one save write: clone + stringify + write + verification re-parse.
	var breakdown := {}
	var payload := {
		"save_schema": "2.0",
		"state": _context.state.to_dict(),
		"mods": _context.save_meta().get("mods", []),
		"meta": _context.save_meta(),
	}
	var t2 := Time.get_ticks_usec()
	var text := JsonUtils.canonical_stringify(payload, "\t")
	breakdown["stringify_ms"] = _ms_since(t2)
	breakdown["text_bytes"] = text.to_utf8_buffer().size()
	var tmp_path := "%s/perf_breakdown.json" % SAVE_SUBDIR
	t2 = Time.get_ticks_usec()
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.flush()
		file.close()
	breakdown["write_ms"] = _ms_since(t2)
	t2 = Time.get_ticks_usec()
	var parsed := JsonUtils.parse_file(tmp_path)
	breakdown["verify_reparse_ms"] = _ms_since(t2)
	breakdown["verify_ok"] = bool(parsed.get("ok", false))
	result["write_breakdown"] = breakdown

	# Autosave through AppContext (meta building + same write path).
	_context.autosave_enabled = true
	var autosave_samples: Array = []
	for i in SAVE_ITERS:
		var t3 := Time.get_ticks_usec()
		var auto := _context.autosave({"trigger": "probe"})
		autosave_samples.append(_ms_since(t3))
		if not bool(auto.get("ok", false)):
			_notes.append("autosave failed: %s" % str(auto))
	_context.autosave_enabled = false
	result["autosave_ms"] = _summarize(autosave_samples)
	result["autosave_frequency"] = _autosave_frequency_audit()
	_print_probe("SAVE: save_slot p50=%.1f load p50=%.1f autosave p50=%.1f file=%.1fKB stringify=%.1f write=%.1f verify=%.1f" % [
		float(result["save_slot_ms"]["p50"]), float(result["load_slot_ms"]["p50"]),
		float(result["autosave_ms"]["p50"]), float(file_bytes) / 1024.0,
		float(breakdown["stringify_ms"]), float(breakdown["write_ms"]),
		float(breakdown["verify_reparse_ms"]),
	])
	return result


## Static part of the audit: which commands request `autosave: true`.
func _autosave_frequency_audit() -> Dictionary:
	return {
		"trigger": "CommandBus.execute: if result.autosave and context.autosave_enabled → context.autosave()",
		"known_triggers": [
			"run.start",
			"voyage.start (VoyageService arrival / event resolution)",
			"event.choose_option / explore.settle / explore.decide",
			"story.advance / story.skip / story.observe (every tutorial step)",
			"quest.start / quest.complete / quest.observe",
			"combat.resolve",
		],
		"thread": "main thread (synchronous canonical_stringify + FileAccess write + verification re-parse)",
	}


# ---------------------------------------------------------------------------
# UI shell
# ---------------------------------------------------------------------------

func _mount_shell() -> Control:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_notes.append("cannot load main.tscn")
		return null
	var shell: Control = packed.instantiate()
	root.add_child(shell)
	return shell


func _phase_ui() -> void:
	_print_probe("UI: mounting shell")
	_fresh_run()
	_out["query_recheck_before_ui"] = _query_recheck()
	_shell = _mount_shell()
	if _shell == null:
		return
	await _settle_frames(3)
	_out["ui_first_overview"] = _measure_ui_page("overview", 1)
	_out["ui_first_overview"]["stage"] = _port_stage_report()
	_print_probe("UI first overview rebuild (includes stage mount): %.1fms stage=%s" % [
		float(_out["ui_first_overview"]["rebuild_ms"]["p50"]), str(_out["ui_first_overview"]["stage"]),
	])

	var pages := ["overview", "market", "shipyard", "sea_chart", "contracts", "tavern", "base", "auto_trade", "ruins", "clue_log"]
	var page_rows := {}
	for page in pages:
		var row := await _measure_ui_page_async(String(page), PAGE_ITERS)
		page_rows[String(page)] = row
		_print_probe("UI page %-10s rebuild p50=%.1f max=%.1f | frame_after p50=%.1f | queries=%d handler=%.1fms | nodes=%d" % [
			String(page),
			float(row["rebuild_ms"]["p50"]), float(row["rebuild_ms"]["max"]),
			float(row["frame_after_ms"]["p50"]),
			int(row["query_calls"]), float(row["query_handler_ms"]),
			int(row["nodes"]),
		])
		await _settle_frames(2)
	_out["ui_pages"] = page_rows
	_out["query_recheck_after_pages"] = _query_recheck()


## Direct query timings taken at a known state, used to cross-check the numbers the
## page rebuild reports (attribution of where the rebuild time goes).
func _query_recheck() -> Dictionary:
	var result := {"state_json_bytes": JsonUtils.canonical_stringify(_context.state.to_dict()).to_utf8_buffer().size()}
	for name in [&"app.view", &"port.view", &"market.view", &"sea_chart.view", &"shipyard.view", &"task.view"]:
		var samples: Array = []
		var handler_samples: Array = []
		for i in 5:
			_reset_query_stats()
			var t := Time.get_ticks_usec()
			_context.queries.execute(name, {})
			samples.append(_ms_since(t))
			handler_samples.append(float(_query_stats["total_us"]) / 1000.0)
		result[String(name)] = {
			"execute_ms": _summarize(samples),
			"handler_ms": _summarize(handler_samples),
		}
	return result


func _measure_ui_page(page: String, iterations: int) -> Dictionary:
	var samples: Array = []
	for i in iterations:
		_shell._active_screen = page
		_reset_query_stats()
		var t := Time.get_ticks_usec()
		_shell._refresh()
		samples.append(_ms_since(t))
	return {
		"rebuild_ms": _summarize(samples),
		"query_calls": int(_query_stats["total_calls"]),
		"queries": _query_calls_snapshot(),
		"nodes": _count_nodes(_shell),
	}


func _measure_ui_page_async(page: String, iterations: int) -> Dictionary:
	var samples: Array = []
	var frame_samples: Array = []
	var query_calls := 0
	var query_us := 0
	var queries := {}
	var nodes := 0
	for i in iterations:
		_shell._active_screen = page
		_reset_query_stats()
		var t := Time.get_ticks_usec()
		_shell._refresh()
		samples.append(_ms_since(t))
		query_calls = int(_query_stats["total_calls"])
		query_us = int(_query_stats["total_us"])
		queries = _query_calls_snapshot()
		# Layout / draw-command generation lands in the following frames.
		var f0 := Time.get_ticks_usec()
		await process_frame
		frame_samples.append(_ms_since(f0))
		await process_frame
		nodes = _count_nodes(_shell)
	return {
		"rebuild_ms": _summarize(samples),
		"frame_after_ms": _summarize(frame_samples),
		"query_calls": query_calls,
		"query_handler_ms": float(query_us) / 1000.0,
		"queries": queries,
		"nodes": nodes,
	}


## Micro-bench of the sea chart page's biggest single piece: `SNSeaChartView.bind()`
## builds the fog texture (per-pixel GDScript loop) before the view is even laid out.
func _micro_bench_sea_chart() -> Dictionary:
	var script := load(SEA_CHART_VIEW_SCRIPT) as Script
	if script == null:
		return {"error": "cannot load sea chart view script"}
	var view_model := _context.queries.execute(&"sea_chart.view")
	if not bool(view_model.get("ok", false)):
		return {"error": "sea_chart.view failed"}
	var data: Dictionary = view_model.get("data", {})
	var fog: Variant = data.get("fog", {})
	var fog_dims := Vector2i(0, 0)
	if fog is Dictionary:
		fog_dims = Vector2i(int((fog as Dictionary).get("width", 0)), int((fog as Dictionary).get("height", 0)))
	var holder := Control.new()
	root.add_child(holder)
	holder.size = Vector2(1200, 700)
	var bind_samples: Array = []
	for i in 5:
		var view: Control = script.new()
		holder.add_child(view)
		var t := Time.get_ticks_usec()
		view.bind(data, Callable())
		bind_samples.append(_ms_since(t))
		holder.remove_child(view)
		view.free()
	holder.queue_free()
	await process_frame
	var result := {
		"bind_ms": _summarize(bind_samples),
		"fog_grid": {"w": fog_dims.x, "h": fog_dims.y, "cells": fog_dims.x * fog_dims.y},
		"chart_ports": Array(data.get("ports", [])).size(),
		"chart_routes": Array(data.get("routes", [])).size(),
		"chart_landmasses": Array(data.get("landmasses", [])).size(),
		"chart_json_bytes": JsonUtils.canonical_stringify(data).to_utf8_buffer().size(),
	}
	_print_probe("MICRO sea chart bind p50=%.1fms fog=%dx%d ports=%d routes=%d landmasses=%d vm=%.1fKB" % [
		float(result["bind_ms"]["p50"]), fog_dims.x, fog_dims.y,
		int(result["chart_ports"]), int(result["chart_routes"]), int(result["chart_landmasses"]),
		float(result["chart_json_bytes"]) / 1024.0,
	])
	return result


# ---------------------------------------------------------------------------
# Interaction latency: one player action = command + full-page rebuild
# ---------------------------------------------------------------------------

func _phase_interactions() -> void:
	if _shell == null:
		return
	_out["interactions"] = {}
	# market.buy / sell on the market page (the most frequent player action).
	_shell._active_screen = "market"
	_shell._refresh()
	await _settle_frames(2)
	_out["interactions"]["market_trade_buy"] = await _bench_shell_command(
		&"trade.buy", _gen_trade_buy, 8
	)
	_out["interactions"]["market_trade_sell"] = await _bench_shell_command(
		&"trade.sell", _gen_trade_sell, 8
	)
	# shipyard.install_module through the shipyard page.
	_shell._active_screen = "shipyard"
	_shell._refresh()
	await _settle_frames(2)
	_out["interactions"]["shipyard_install"] = await _bench_shell_command(
		&"ship.install_module", _gen_install, 6
	)
	# Navigation: overview → sea chart (page rebuild only, no command).
	var nav_samples: Array = []
	for i in 6:
		var t := Time.get_ticks_usec()
		_shell._active_screen = "sea_chart"
		_shell._refresh()
		nav_samples.append(_ms_since(t))
		await process_frame
		_shell._active_screen = "overview"
		_shell._refresh()
		await process_frame
	_out["interactions"]["navigate_to_sea_chart"] = {"navigate_ms": _summarize(nav_samples)}
	# `_port_name()` executes `map.view` (a full state clone) on every call.
	var port_ids: Array = []
	var port_view := _context.queries.execute(&"port.view")
	if bool(port_view.get("ok", false)):
		for destination in Array(port_view["data"].get("destinations", [])):
			port_ids.append(String(destination.get("port_id", "")))
	var port_name_samples: Array = []
	for i in 20:
		var target := String(port_ids[i % maxi(1, port_ids.size())]) if not port_ids.is_empty() else "unknown"
		var t := Time.get_ticks_usec()
		_shell._port_name(target)
		port_name_samples.append(_ms_since(t))
	_out["interactions"]["port_name_lookup"] = {
		"lookup_ms": _summarize(port_name_samples),
		"note": "each call executes map.view => one full GameState.clone()",
	}
	_print_probe("INTERACTION market trade.buy end-to-end p50=%.1fms | navigation to sea chart p50=%.1fms | _port_name p50=%.1fms" % [
		float(_out["interactions"]["market_trade_buy"]["total_ms"]["p50"]),
		float(_out["interactions"]["navigate_to_sea_chart"]["navigate_ms"]["p50"]),
		float(_out["interactions"]["port_name_lookup"]["lookup_ms"]["p50"]),
	])


func _bench_shell_command(name: StringName, params_fn: Callable, iterations: int) -> Dictionary:
	var total_samples: Array = []
	var command_samples: Array = []
	var query_samples: Array = []
	var commands_seen := {}
	var queries_seen := {}
	var autosave_hits := 0
	var mobile_path := ProjectSettings.globalize_path("%s/autosave.json" % SAVE_SUBDIR)
	for i in iterations:
		_fresh_run()
		var params: Dictionary = params_fn.call()
		# The shell re-enables autosave from SettingsService on its first rebuild, so a
		# shell command can autosave even when the probe bootstrapped with autosave=false.
		if FileAccess.file_exists(mobile_path):
			DirAccess.remove_absolute(mobile_path)
		_reset_command_stats()
		_reset_query_stats()
		var t := Time.get_ticks_usec()
		_shell._run_command(name, params)
		total_samples.append(_ms_since(t))
		command_samples.append(float(_command_stats["total_us"]) / 1000.0)
		query_samples.append(float(_query_stats["total_us"]) / 1000.0)
		for key in _command_stats["handlers"].keys():
			var handler: Dictionary = _command_stats["handlers"][key]
			if int(handler["calls"]) > 0:
				commands_seen[String(key)] = int(commands_seen.get(String(key), 0)) + int(handler["calls"])
		for key in _query_stats["handlers"].keys():
			var handler: Dictionary = _query_stats["handlers"][key]
			if int(handler["calls"]) > 0:
				queries_seen[String(key)] = int(queries_seen.get(String(key), 0)) + int(handler["calls"])
		if FileAccess.file_exists(mobile_path):
			autosave_hits += 1
		await _settle_frames(2)
	return {
		"total_ms": _summarize(total_samples),
		"command_handler_ms": _summarize(command_samples),
		"query_handler_ms": _summarize(query_samples),
		"commands_seen": commands_seen,
		"queries_seen": queries_seen,
		"autosave_count": autosave_hits,
		"note": "shell._run_command = CommandBus.execute (+ story/quest observe) + _refresh() full page rebuild; fresh run before each sample",
	}


# ---------------------------------------------------------------------------
# at_sea page + voyage presentation per-frame cost
# ---------------------------------------------------------------------------

func _phase_at_sea() -> void:
	if _shell == null or _context == null:
		return
	# Fresh run so the voyage is feasible.
	_context.reset_state()
	_context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": 4242})
	_shell._active_screen = "overview"
	_shell._refresh()
	await _settle_frames(2)
	var neighbors := MapOps.neighbors(_context.state.world(), _context.state.current_port_id())
	if neighbors.is_empty():
		_notes.append("at_sea page not measured: no neighbour port")
		return
	var destination := String(neighbors[0])
	var voyage := _context.commands.execute(&"voyage.start", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})
	_print_probe("AT_SEA voyage.start ok=%s code=%s" % [str(voyage.get("ok", false)), str(voyage.get("error_code", ""))])
	# The command already ran; ask the shell to mount the presentation for it the way
	# `_run_command` would (it needs the presentation payload from the command result).
	_shell._handle_success(&"voyage.start", voyage)
	_shell._refresh()
	var reached := false
	for step in 1200:
		if _shell._at_sea_screen != null:
			reached = true
			break
		_shell._process(0.1)
	if not reached:
		_notes.append("at_sea page not reached: presentation=%s status=%s" % [
			str(_shell._presentation != null), str(_shell._status_message),
		])
		return
	var rebuild_samples: Array = []
	var frame_samples: Array = []
	var query_calls := 0
	var query_us := 0
	for i in PAGE_ITERS:
		_shell._active_screen = "sea_chart"
		_reset_query_stats()
		var t := Time.get_ticks_usec()
		_shell._refresh()
		rebuild_samples.append(_ms_since(t))
		query_calls = int(_query_stats["total_calls"])
		query_us = int(_query_stats["total_us"])
		var f0 := Time.get_ticks_usec()
		await process_frame
		frame_samples.append(_ms_since(f0))
		await process_frame
	var chart := _sea_chart_data_volume()
	_out["ui_at_sea"] = {
		"rebuild_ms": _summarize(rebuild_samples),
		"frame_after_ms": _summarize(frame_samples),
		"query_calls": query_calls,
		"query_handler_ms": float(query_us) / 1000.0,
		"chart_data": chart,
	}
	# Per-frame cost while the VoyagePresentation state machine drives the chart.
	var presentation_steady := await _sample_frames(PRESENTATION_STEADY_FRAMES, "presentation_at_sea")
	_out["steady_presentation"] = presentation_steady
	# Let the presentation finish so the shell returns to a normal page.
	for step in 1200:
		if _shell._presentation == null:
			break
		_shell._process(0.1)
	_print_probe("AT_SEA rebuild p50=%.1fms chart ports=%d routes=%d landmasses=%d fog=%d" % [
		float(_out["ui_at_sea"]["rebuild_ms"]["p50"]),
		int(chart.get("ports", 0)), int(chart.get("routes", 0)),
		int(chart.get("landmasses", 0)), int(chart.get("fog_cells", 0)),
	])


func _sea_chart_data_volume() -> Dictionary:
	var result := {"ports": 0, "routes": 0, "landmasses": 0, "land_points": 0, "fog_cells": 0, "json_bytes": 0}
	var view := _context.queries.execute(&"sea_chart.view")
	if not bool(view.get("ok", false)):
		return result
	var data: Dictionary = view.get("data", {})
	result["json_bytes"] = JsonUtils.canonical_stringify(data).to_utf8_buffer().size()
	result["ports"] = Array(data.get("ports", [])).size()
	result["routes"] = Array(data.get("routes", [])).size()
	var landmasses: Array = Array(data.get("landmasses", []))
	result["landmasses"] = landmasses.size()
	var points := 0
	for landmass in landmasses:
		if landmass is Dictionary:
			points += Array((landmass as Dictionary).get("points", [])).size()
		elif landmass is Array:
			points += landmass.size()
	result["land_points"] = points
	var fog: Variant = data.get("fog", null)
	if fog is Dictionary:
		result["fog_cells"] = int((fog as Dictionary).get("width", 0)) * int((fog as Dictionary).get("height", 0))
	return result


# ---------------------------------------------------------------------------
# Steady state per page (idle CPU per frame / allocation growth / draw count)
# ---------------------------------------------------------------------------

func _phase_steady() -> void:
	if _shell == null or _context == null:
		return
	_context.reset_state()
	_context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": 5201})
	_shell._active_screen = "overview"
	_shell._refresh()
	await _settle_frames(30)
	_out["steady_overview"] = await _sample_frames(STEADY_FRAMES, "steady_overview")
	var pages := [
		{"page": "market", "frames": PAGE_STEADY_FRAMES},
		{"page": "shipyard", "frames": PAGE_STEADY_FRAMES},
		{"page": "sea_chart", "frames": PAGE_STEADY_FRAMES},
		{"page": "contracts", "frames": PAGE_STEADY_FRAMES},
	]
	for entry in pages:
		_shell._active_screen = String(entry["page"])
		_shell._refresh()
		await _settle_frames(10)
		_out["steady_" + String(entry["page"])] = await _sample_frames(int(entry["frames"]), "steady_" + String(entry["page"]))
	_shell._active_screen = "overview"
	_shell._refresh()
	await _settle_frames(10)


## Samples per-frame CPU for `frames` frames. Per-frame CPU = wall clock between
## `process_frame` boundaries (headless: no vsync, no rendering work).
func _sample_frames(frames: int, label: String) -> Dictionary:
	var process_ms: Array = []
	var physics_ms: Array = []
	var frame_ms: Array = []
	var objects_start := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory_start := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var objects_max := objects_start
	var memory_max := memory_start
	var total := 0.0
	var draw_counter := {"n": 0}
	var view := _find_sea_chart_view(_shell)
	if view != null and view.has_signal("draw"):
		view.connect("draw", func() -> void: draw_counter["n"] = int(draw_counter["n"]) + 1)
	var last := Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
		# Kept for reference only: unreliable under headless + --fixed-fps.
		process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)))
		total += float(Performance.get_monitor(Performance.TIME_PROCESS))
		physics_ms.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
		if i % 30 == 0:
			objects_max = maxi(objects_max, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
			memory_max = maxi(memory_max, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	var objects_end := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory_end := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var result := {
		"label": label,
		"frames": frames,
		"frame_cpu_ms": _summarize(frame_ms),
		"frame_cpu_total_ms": _sum_total(frame_ms),
		"time_process_raw": _summarize(process_ms),
		"time_physics_process_raw": _summarize(physics_ms),
		"draw_signal_events": int(draw_counter["n"]),
		"draws_per_frame": float(draw_counter["n"]) / float(maxi(1, frames)),
		"objects": {"start": objects_start, "end": objects_end, "max": objects_max, "delta": objects_end - objects_start},
		"memory_static": {"start": memory_start, "end": memory_end, "max": memory_max, "delta": memory_end - memory_start},
	}
	_print_probe("STEADY %s: frames=%d frame_cpu p50=%.3f p95=%.3f max=%.3f ms | draws/frame=%.2f | objects %+d | mem %+d B" % [
		label, frames,
		float(result["frame_cpu_ms"].get("p50", 0.0)),
		float(result["frame_cpu_ms"].get("p95", 0.0)),
		float(result["frame_cpu_ms"].get("max", 0.0)),
		float(result["draws_per_frame"]),
		objects_end - objects_start, memory_end - memory_start,
	])
	return result


func _find_sea_chart_view(node: Node) -> Node:
	if node.get_script() != null and String((node.get_script() as Script).resource_path) == SEA_CHART_VIEW_SCRIPT:
		return node
	for child in node.get_children():
		var found := _find_sea_chart_view(child)
		if found != null:
			return found
	return null


func _phase_menu_pages() -> void:
	if _shell == null or _context == null:
		return
	_context.reset_state()
	var menu_rows := {}
	for entry in [["main", "main_menu"], ["new_game", "new_game"], ["mods", "mods"], ["settings", "settings"]]:
		var menu_id := String(entry[0])
		var label := String(entry[1])
		var samples: Array = []
		var query_calls := 0
		for i in PAGE_ITERS:
			_shell._active_screen = "overview"
			_shell._menu_screen = menu_id
			_reset_query_stats()
			var t := Time.get_ticks_usec()
			_shell._refresh()
			samples.append(_ms_since(t))
			query_calls = int(_query_stats["total_calls"])
			await process_frame
		menu_rows[label] = {
			"rebuild_ms": _summarize(samples),
			"query_calls": query_calls,
			"nodes": _count_nodes(_shell),
		}
		_print_probe("UI menu %-10s rebuild p50=%.1fms queries=%d" % [
			label, float(menu_rows[label]["rebuild_ms"]["p50"]), int(menu_rows[label]["query_calls"]),
		])
	_out["ui_menus"] = menu_rows


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total


# ---------------------------------------------------------------------------
# Release (zip) path
# ---------------------------------------------------------------------------

func _phase_zip() -> void:
	var zip_path := _zip_dir.path_join("core-1.0.0.snavmod.zip")
	if not FileAccess.file_exists(zip_path):
		_notes.append("zip path missing: %s" % zip_path)
		return
	_out["zip_file"] = {"path": zip_path, "bytes": FileAccess.get_file_as_bytes(zip_path).size()}
	var zip_boot := await _measure_boot(_boot_cfg(true), ZIP_BOOT_RUNS)
	_out["boot_zip"] = _strip_context(zip_boot)
	_print_boot("zip", zip_boot)
	_out["mod_pipeline_zip"] = await _measure_mod_pipeline(_boot_cfg(true))

	# The manual pipeline above left its own AppContext active: restore the boot one.
	var context: AppContext = zip_boot["context"]
	AppContext.set_active(context)
	_context = context
	if context == null:
		return
	_install_bus_instrumentation()
	context.reset_state()
	var start := context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": 5201})
	if not bool(start.get("ok", false)):
		_notes.append("zip run.start failed: %s" % str(start))
	_out["zip_state_start"] = _measure_state_bytes()
	_out["zip_queries"] = _measure_queries()
	# First overview rebuild loads PortStage + facility/town assets through the zip:
	# this is the asset-loading difference between loose dev resources and a release pack.
	_shell = _mount_shell()
	if _shell == null:
		return
	await _settle_frames(3)
	var first := _measure_ui_page("overview", 1)
	_out["zip_first_overview"] = {
		"rebuild_ms": first["rebuild_ms"],
		"query_calls": first["query_calls"],
		"nodes": _count_nodes(_shell),
		"stage": _port_stage_report(),
	}
	_print_probe("ZIP first overview rebuild: %.1fms nodes=%d stage=%s" % [
		float(first["rebuild_ms"]["p50"]), int(_count_nodes(_shell)), str(_out["zip_first_overview"]["stage"]),
	])
	_out["notes"] = _notes


func _port_stage_report() -> Dictionary:
	if _shell == null:
		return {}
	var host: Variant = _shell.get("_port_stage_host")
	if host == null or not is_instance_valid(host):
		return {"mounted": false, "reason": "no stage host"}
	var stage: Variant = host.current_stage() if host.has_method("current_stage") else null
	if stage == null:
		return {"mounted": false, "reason": "stage not loaded"}
	var report := {"mounted": true}
	if stage.has_method("facility_count"):
		report["facilities"] = int(stage.facility_count())
	if stage.has_method("facility_visual_kind"):
		var kinds := {}
		for facility in ["market", "harbor", "shipyard", "supply", "tavern"]:
			kinds[facility] = String(stage.facility_visual_kind(facility))
		report["facility_kinds"] = kinds
	if stage.has_method("town_prop_count"):
		report["town_props"] = int(stage.town_prop_count())
	if stage.has_method("atmosphere_particle_systems"):
		report["particle_systems"] = int(stage.atmosphere_particle_systems())
	if stage.has_method("batch_stats"):
		var batch: Dictionary = stage.batch_stats()
		report["batches"] = {
			"batches": int(batch.get("batches", 0)),
			"meshes_before": int(batch.get("meshes_before", 0)),
			"meshes_after": int(batch.get("meshes_after", 0)),
			"surfaces_before": int(batch.get("surfaces_before", 0)),
			"surfaces_after": int(batch.get("surfaces_after", 0)),
		}
	return report


func _teardown_shell() -> void:
	if _shell == null:
		return
	if _shell.get_parent() != null:
		_shell.get_parent().remove_child(_shell)
	_shell.free()
	_shell = null
	await process_frame


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _meta() -> Dictionary:
	var version := Engine.get_version_info()
	return {
		"probe": "perf_cpu_probe",
		"mode": _mode,
		"engine": String(version.get("string", "")),
		"headless": DisplayServer.get_name() == "headless",
		"display_server": DisplayServer.get_name(),
		"processor_count": OS.get_processor_count(),
		"engine_ready_ms": _script_start_msec,
		"os": OS.get_name(),
		"cmdline_args": OS.get_cmdline_args(),
		"cmdline_user_args": OS.get_cmdline_user_args(),
		"timestamp_unix": int(Time.get_unix_time_from_system()),
	}


func _ms_since(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _summarize(values: Array) -> Dictionary:
	var n := values.size()
	if n == 0:
		return {"n": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in sorted:
		sum += float(value)
	return {
		"n": n,
		"mean": sum / float(n),
		"min": float(sorted[0]),
		"p50": _percentile(sorted, 0.50),
		"p90": _percentile(sorted, 0.90),
		"p95": _percentile(sorted, 0.95),
		"max": float(sorted[n - 1]),
	}


func _sum_total(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total


func _percentile(sorted_values: Array, ratio: float) -> float:
	var n := sorted_values.size()
	if n == 0:
		return 0.0
	var index := int(round(ratio * float(n - 1)))
	index = clampi(index, 0, n - 1)
	return float(sorted_values[index])


func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame


func _strip_context(boot: Dictionary) -> Dictionary:
	var copy := {}
	for key in boot.keys():
		if key == "context":
			continue
		copy[key] = boot[key]
	return copy


func _print_probe(message: String) -> void:
	print("[probe] " + message)


func _dump() -> void:
	_out["engine_ready_ms"] = _script_start_msec
	_out["notes"] = _notes
	var path := OUTPUT_LOOSE
	if _mode == "zip":
		path = OUTPUT_ZIP
	elif _mode != "all" and _mode != "boot":
		path = "res://.design/perf/cpu_probe_%s.json" % _mode
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("cannot write " + absolute)
		return
	file.store_string(JSON.stringify(_out, "  "))
	file.close()
	_print_probe("JSON written: " + absolute)


func _finish() -> void:
	_finished = true
	_dump()
	if not _notes.is_empty():
		_print_probe("NOTES (%d):" % _notes.size())
		for note in _notes:
			_print_probe("  - " + note)
	_print_probe("DONE")
	FrameworkRuntime.shutdown()
	quit(0)
