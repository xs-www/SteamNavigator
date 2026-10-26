extends SceneTree
## @static-doc
## 作用：渲染侧性能测量工具（真实窗口渲染，非 headless）。加载 Core → 实例化真实 shell → 逐页导航并采样帧时间/Performance 监视器，输出 JSON + 控制台表格到 `.design/perf/`，用于量化「像素数 / MSAA / 3D 舞台 vs 2D UI」各自的成本结构。
##
## ## 用法
## ```powershell
## $godot = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
## & $godot --path . --resolution 1440x900 --script res://tools/godot/perf_probe.gd -- `
##     --out=.design/perf/render_A.json --resolution=1440x900 --msaa=2
## ```
## 必须窗口模式（不能加 `--headless`），否则 SubViewport/3D 不渲染、帧时间没有意义。
## 默认关闭 vsync 且 `Engine.max_fps = 0`：只有不锁帧才能量到「每帧真实成本」
## （强机上锁 60fps 会让所有页面都显示 16.7ms，无法归因）。
##
## ## CLI（放在 `--` 之后）
## - `--out=<path>`：输出 JSON（默认 `.design/perf/render_probe.json`；相对路径按项目根解析）
## - `--resolution=1440x900`：窗口尺寸（同时决定像素数）
## - `--msaa=0|1|2|3`：运行时覆盖 `rendering/anti_aliasing/quality/msaa_3d` 与所有
##   SubViewport 的 `msaa_3d`（0=关，1=2x，2=4x，3=8x；项目默认 2 = 4x）。`-1`（默认）不覆盖。
## - `--stage-msaa=0|1|2|3`：只覆盖 3D 舞台 SubViewport 的 MSAA（隔离舞台 MSAA 成本）
## - `--no-stage`：页面稳定后隐藏所有 `SNStageHost`（SubViewport 转 UPDATE_DISABLED），
##   隔离 3D 舞台成本，只留 2D UI
## - `--screens=overview,market`：采样页子集；默认
##   `main_menu,overview,market,shipyard,sea_chart,at_sea`
## - `--sample-seconds=3.0`：每页稳态采样时长（默认 3s，且至少 120 帧）
## - `--seed=5201`：固定种子（与 `tools/ui_snapshot.gd` / 测试一致）
## - `--tag=A`：日志标签
## - `--vsync=on|off`：默认 off（不锁帧量真实每帧成本）。on 用于观察真实 exe 的
##   刷新率行为（默认 vsync enabled：错过一帧就是 33ms）
## - `--debug`：逐帧打印 Performance 监视器原始值
## - `--shots=<dir>`：每页稳态采样后抓一张 root 视口截图（验收 2D 布局是否随窗口变）
## - `--isolate=overview,market`：同进程「舞台显示 N 帧 → 隐藏 N 帧」交替采样，
##   用配对帧时间差隔离 3D 舞台成本（同进程内漂移抵消），配合 `--isolate-cycles` / `--isolate-frames`
## - `--no-teardown`：跳过收尾（不拆 shell / 不 shutdown），直接 quit；
##   用于复现「真实 exe 退出时 GLES3 清理阶段 0xc0000005」
## - `--mount-zip=<path>`：模拟发布版（挂载 mod pack zip，从 zip 读原始 PNG/GLB）
##
## ## 采样口径
## - 「hitch 窗口」：切页后立刻连续采样 120 帧，捕捉 UI 全量重建 / shader 编译 / 舞台装配
##   的卡顿（每个页面 `_refresh()` 都会重建整棵页面树，见 main.gd `_rebuild_ui`）。
## - 「稳态样本」：等舞台站位过渡结束 + 布局稳定后采样 `--sample-seconds` 且 ≥120 帧，
##   记录帧时间分布 min/median/p95/p99/max、>16.7/>33.3/>100ms 帧数与 Performance 监视器。
## - `at_sea` 页是航行演出页：`voyage.start` → 手动推进 `VoyagePresentation` 到云幕散开，
##   再在演出继续播放的状态下采样；若演出提前结束（页面被卸载）则记录 `stopped_early`。
## - 每页同时记录 SubViewport（尺寸 / MSAA / update_mode）、`SNStageHost` 状态、
##   节点/Control 数量，用于审计「隐藏页面是否仍渲染 / 几个 SubViewport」。
##
## ## 退出码
## 0 = 请求的页面全部完成且有 ≥120 帧样本；1 = 有页面失败 / 样本不足 / 超时。
## watchdog 默认 170 秒，防脚本协程中断导致窗口挂死。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const STEADY_BUILD := "core:starting_scenario/steady"
const DEFAULT_SEED := 5201
const DEFAULT_OUT := ".design/perf/render_probe.json"
const DEFAULT_SCREENS := "main_menu,overview,market,shipyard,sea_chart,at_sea"
const DEFAULT_RESOLUTION := Vector2i(1440, 900)
## 每页稳态采样：至少 120 帧（约 2 秒 @60fps）且至少 --sample-seconds。
const MIN_SAMPLE_FRAMES := 120
const DEFAULT_SAMPLE_SECONDS := 3.0
const MAX_SAMPLE_FRAMES := 4000
## 切页后立即采样的 hitch 窗口（UI 重建 / shader 编译 / 舞台装配）。
const HITCH_FRAMES := 120
## 布局稳定帧数 + 真实等待（窗口模式帧率由显示与负载决定，不能只数帧）。
const LAYOUT_FRAMES := 24
const LAYOUT_SETTLE_SECONDS := 0.35
const STAGE_WAIT_SECONDS := 8.0
## 航行演出推进（与 tools/ui_snapshot.gd / test_voyage_flow 同一手法）。
const STANDARD_STRATEGY := "core:boiler_strategy/standard"
const FLOW_DRIVE_STEP := 0.1
const FLOW_DRIVE_MAX_SECONDS := 90.0
## 与 shell 的 STAGE_SCREENS 对应的舞台站位（overview 站在 harbor）。
const STAGE_STATIONS := {
	"overview": "harbor",
	"market": "market",
	"shipyard": "shipyard",
}
## 页面 id → 页面脚本路径。用运行时 `load()` 而不是 `preload()`：同一份探针要能在
## dev.3 worktree（没有皮肤管线 / 部分脚本可能改名）里直接跑，缺文件时只让该页失败。
const PAGE_SCRIPT_PATHS := {
	"main_menu": "res://framework/ui/screens/menu/main_menu_screen.gd",
	"overview": "res://framework/ui/screens/port/overview_screen.gd",
	"market": "res://framework/ui/screens/port/market_screen.gd",
	"shipyard": "res://framework/ui/screens/port/shipyard_screen.gd",
	"sea_chart": "res://framework/ui/screens/flow/sea_chart_screen.gd",
}
const SHIP_STAGE_3D_PATH := "res://framework/ui/components/sn_ship_stage_3d.gd"
const SHIP_VIEW_PATH := "res://framework/ui/components/sn_ship_view.gd"
const SKIN_PATH := "res://framework/ui/skin/sn_skin.gd"
const THEME_PATH := "res://assets/ui/theme/steam_navigator_theme.tres"
## Performance 监视器 key → 枚举（渲染侧成本结构 + 内存/对象数）。
const MONITOR_DEFS := {
	"time_process": Performance.TIME_PROCESS,
	"time_physics_process": Performance.TIME_PHYSICS_PROCESS,
	"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"video_mem": Performance.RENDER_VIDEO_MEM_USED,
	"texture_mem": Performance.RENDER_TEXTURE_MEM_USED,
	"memory_static": Performance.MEMORY_STATIC,
	"object_count": Performance.OBJECT_COUNT,
	"object_resource_count": Performance.OBJECT_RESOURCE_COUNT,
}
## 帧时间阈值（ms）：60fps 预算 / 30fps 预算 / 明显卡顿。
const BUDGET_60_MS := 1000.0 / 60.0
const BUDGET_30_MS := 1000.0 / 30.0
const HITCH_MS := 100.0

var _failures: Array[String] = []
var _notes: Array[String] = []
var _seed := DEFAULT_SEED
var _out_path := DEFAULT_OUT
var _window := DEFAULT_RESOLUTION
var _msaa := -1
var _stage_msaa := -1
var _no_stage := false
var _vsync_enabled := false
## `--no-teardown`：跳过 _teardown（不拆 shell / 不 shutdown FrameworkRuntime），
## 直接 quit。用来复现「真实 exe 退出时场景还活着 → GLES3 清理阶段 0xc0000005」的路径。
var _no_teardown := false
var _screens: Array[String] = []
## `--mount-zip=<path>`：模拟发布版运行时——挂载 mod pack zip，从 zip 内读原始 PNG/GLB
## （ContentAssetLoader → ImageTexture），用于复现「zip 资产 + 舞台已加载 → quit」退出路径。
var _mount_zip := ""
var _sample_seconds := DEFAULT_SAMPLE_SECONDS
var _tag := "probe"
var _debug := false
## `--shots=<dir>`：每页稳态采样后抓一张 root 视口截图（验收 2D 布局是否随窗口变化）。
var _shots_dir := ""
## `--isolate=overview,market`：同进程内「舞台显示 → 舞台隐藏」交替采样（各 N 帧 × 3 轮），
## 用同一进程的配对差值隔离 3D 舞台成本，避免跨运行漂移。
var _isolate_screens: Array[String] = []
var _isolate_cycles := 3
var _isolate_frames := 90
var _page_results: Array = []
var _script_cache := {}
var _watchdog_fired := false


func _init() -> void:
	_parse_args()
	_watchdog()
	_run()


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------

func _run() -> void:
	print("=== Steam Navigator 渲染性能取样（tag=%s，%dx%d，seed=%d）===" % [
		_tag, _window.x, _window.y, _seed,
	])
	if DisplayServer.get_name() == "headless":
		_expect(false, "必须以窗口模式运行（去掉 --headless），否则 3D/SubViewport 不渲染")
		_finish()
		return
	# 不锁帧：只有不锁帧才能量到每帧真实成本（锁 60fps 会让强机上所有页面都显示 16.7ms）。
	# `--vsync=on` 保留真实 exe 的刷新率行为，用来观察切页 hitch 在 60Hz 下丢几帧。
	DisplayServer.window_set_size(_window)
	DisplayServer.window_set_title("Steam Navigator · perf probe (%s)" % _tag)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = 0
	await process_frame
	await _wait_window_size(_window)
	_apply_root_msaa()
	print("[INFO] 窗口：%s，根视口：%s，stretch=%s，vsync=%s，max_fps=0" % [
		str(DisplayServer.window_get_size()), str(root.size),
		String(ProjectSettings.get_setting("display/window/stretch/mode", "?")),
		"on" if _vsync_enabled else "off",
	])
	print("[INFO] 渲染后端：%s / %s（API %s）；MSAA 覆盖：root=%s stage=%s；no_stage=%s" % [
		RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(),
		str(_msaa), str(_stage_msaa), str(_no_stage),
	])

	var boot := _bootstrap_core()
	var context: AppContext = boot["context"]
	if context == null or not context.is_ready():
		var boot_report: Variant = boot.get("report")
		var boot_text := ""
		if boot_report != null and boot_report.has_method("format_text"):
			boot_text = String(boot_report.call("format_text"))
		print("[FAIL] Core 启动失败：%s" % (boot_text if not boot_text.is_empty() else str(boot_report)))
		_expect(false, "Core 启动失败")
		_finish()
		return
	print("[INFO] Core 就绪：mod=%s，内容条目=%d" % [str(context.mod_order), context.content_total()])

	# 一个 shell 贯穿全部页面：先测无对局的菜单态，再 run.start 测游戏内页面。
	# （中途不要 FrameworkRuntime.shutdown，否则 AppContext/注册表会被清掉。）
	var shell := _mount_shell()
	if shell == null:
		_finish()
		return
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)

	# 主菜单要在 run.start 之前采样（无对局 = 菜单态），否则只能靠 reset_state 回退。
	if _screens.has("main_menu"):
		var menu_result := await _measure_page(shell, "main_menu")
		_page_results.append(menu_result)

	var gameplay := _gameplay_screens()
	if not gameplay.is_empty() or not _isolate_screens.is_empty():
		var started: Dictionary = context.commands.execute(&"run.start", {
			"starting_scenario": STEADY_BUILD,
			"seed": _seed,
		})
		_expect(bool(started.get("ok", false)), "run.start 成功：%s" % str(started.get("error", "")))
		if not bool(started.get("ok", false)):
			_finish()
			return
		for page_id in gameplay:
			if not _isolate_screens.is_empty():
				continue
			var page_result := await _measure_page(shell, page_id)
			_page_results.append(page_result)
		# 同进程配对隔离：舞台显示/隐藏交替采样，漂移在同一次进程内抵消。
		for page_id in _isolate_screens:
			var iso_result := await _isolate_page(shell, page_id)
			_page_results.append(iso_result)
	if _no_teardown:
		print("[INFO] --no-teardown：保留场景树直接 quit（复现真实 exe 的退出清理路径）")
	else:
		await _teardown(shell)

	_write_json()
	_print_table()
	_finish()


func _watchdog() -> void:
	await process_frame
	await create_timer(170.0).timeout
	_watchdog_fired = true
	push_error("perf_probe: 取样超时（170 秒），强制退出")
	quit(1)


func _finish() -> void:
	var complete := not _screens.is_empty()
	for page_result in _page_results:
		if not bool(page_result.get("ok", false)):
			complete = false
	if _page_results.is_empty():
		complete = false
	if _failures.is_empty() and complete and not _watchdog_fired:
		print("=== 结果：全部页面取样完成（%d 页）→ %s ===" % [_page_results.size(), _out_path])
		quit(0)
	else:
		print("=== 结果：失败 %d 项，页面样本 %d 个 ===" % [_failures.size(), _page_results.size()])
		for failure in _failures:
			print("  ! " + failure)
		quit(1)


# ---------------------------------------------------------------------------
# 页面测量
# ---------------------------------------------------------------------------

func _gameplay_screens() -> Array[String]:
	var result: Array[String] = []
	for page_id in _screens:
		if page_id != "main_menu":
			result.append(page_id)
	return result


## 切页 → hitch 窗口 → 等舞台/布局稳定 → 稳态采样 → 记录视图状态。
## 每页 `_refresh()` 都重建整棵页面树，hitch 窗口就是从 rebuild 调用后立刻开始数帧。
func _measure_page(shell: Control, page_id: String) -> Dictionary:
	print("[PAGE] %s" % page_id)
	var result := {
		"id": page_id,
		"ok": false,
		"notes": [],
	}
	var prepare_started := Time.get_ticks_usec()
	var prepared: bool = await _prepare_page(shell, page_id)
	result["prepare_ms"] = snappedf(float(Time.get_ticks_usec() - prepare_started) / 1000.0, 0.1)
	if not prepared:
		result["notes"].append("页面准备失败")
		_expect(false, "%s：页面准备失败" % page_id)
		return result
	_apply_page_msaa()

	# hitch 窗口：切页/rebuild 之后立刻连续取 HITCH_FRAMES 帧。
	var hitch_started := Time.get_ticks_usec()
	var hitch := await _collect_frames(HITCH_FRAMES, HITCH_FRAMES, 0.0, _stop_when_gone(shell, page_id))
	hitch["start_offset_ms"] = snappedf(float(hitch_started - prepare_started) / 1000.0, 0.1)
	result["hitch"] = hitch

	await _wait_page_ready(shell, page_id)
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	_apply_page_msaa()
	if _no_stage:
		_apply_no_stage()
		await _settle(2, 0.05)
	result["page_valid"] = _page_valid(shell, page_id)
	result["viewports"] = _viewport_report()
	result["stage_hosts"] = _stage_host_report()
	result["counts"] = _tree_counts()
	result["ui_assets"] = _ui_asset_report()
	result["extra"] = _page_extra(shell, page_id)

	var steady := await _collect_frames(
		MIN_SAMPLE_FRAMES, MAX_SAMPLE_FRAMES, _sample_seconds, _stop_when_gone(shell, page_id)
	)
	result["sample"] = steady
	result["page_valid_after"] = _page_valid(shell, page_id)
	if bool(steady.get("stopped_early", false)):
		result["notes"].append("页面在采样结束前卸载（演出结束/页面切换）")
	result["ok"] = bool(result["page_valid"]) and int(steady["frames"]) >= MIN_SAMPLE_FRAMES
	if not _shots_dir.is_empty():
		result["screenshot"] = await _capture_screenshot("%s_%s.png" % [_tag, page_id])
	if not bool(result["page_valid"]):
		_expect(false, "%s：采样时页面未挂载" % page_id)
	elif int(steady["frames"]) < MIN_SAMPLE_FRAMES:
		_expect(false, "%s：有效样本仅 %d 帧（< %d）" % [page_id, int(steady["frames"]), MIN_SAMPLE_FRAMES])
	print("[PAGE] %s 完成：frames=%d，median=%.2fms，p95=%.2fms，draws=%.0f，prims=%.0f" % [
		page_id, int(steady["frames"]), float(steady["stats"]["median_ms"]),
		float(steady["stats"]["p95_ms"]), float(steady["monitors"]["draw_calls"]["median"]),
		float(steady["monitors"]["primitives"]["median"]),
	])
	return result


## 同进程配对隔离：同一页面上「舞台显示 N 帧 → 舞台隐藏 N 帧」交替 `_isolate_cycles` 轮，
## 用每轮配对的帧时间中位差（on − off）估计 3D 舞台成本。跨运行漂移在同一次进程内抵消。
func _isolate_page(shell: Control, page_id: String) -> Dictionary:
	print("[ISO] %s（%d 轮 × %d 帧 on/off 交替）" % [page_id, _isolate_cycles, _isolate_frames])
	var result := {"id": page_id, "mode": "isolate_3d", "ok": false, "cycles": [], "notes": []}
	var prepared: bool = await _prepare_page(shell, page_id)
	if not prepared:
		_expect(false, "%s：隔离采样页面准备失败" % page_id)
		return result
	_apply_page_msaa()
	await _wait_page_ready(shell, page_id)
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	_apply_page_msaa()
	var host := _first_stage_host()
	if host == null:
		_expect(false, "%s：找不到可切换的 SNStageHost" % page_id)
		return result
	result["page_valid"] = _page_valid(shell, page_id)
	result["viewports"] = _viewport_report()
	result["counts"] = _tree_counts()
	result["extra"] = _page_extra(shell, page_id)
	var on_medians: Array[float] = []
	var off_medians: Array[float] = []
	var deltas: Array[float] = []
	for cycle in _isolate_cycles:
		host.set_stage_visible(true)
		await _settle(12, 0.12)
		var on_sample := await _collect_frames(_isolate_frames, _isolate_frames, 0.0, Callable())
		host.set_stage_visible(false)
		await _settle(12, 0.12)
		var off_sample := await _collect_frames(_isolate_frames, _isolate_frames, 0.0, Callable())
		var on_median := float(on_sample["stats"]["median_ms"])
		var off_median := float(off_sample["stats"]["median_ms"])
		on_medians.append(on_median)
		off_medians.append(off_median)
		deltas.append(snappedf(on_median - off_median, 0.001))
		result["cycles"].append({
			"on": on_sample,
			"off": off_sample,
			"on_median_ms": on_median,
			"off_median_ms": off_median,
			"delta_median_ms": snappedf(on_median - off_median, 0.001),
		})
	host.set_stage_visible(true)
	result["on_median_ms"] = _median(on_medians)
	result["off_median_ms"] = _median(off_medians)
	result["delta_median_ms"] = _median(deltas)
	result["delta_all_ms"] = deltas
	result["ok"] = bool(result["page_valid"])
	print("[ISO] %s：on=%.2fms off=%.2fms 配对差值中位=%.2fms（各轮 %s）" % [
		page_id, float(result["on_median_ms"]), float(result["off_median_ms"]),
		float(result["delta_median_ms"]), str(deltas),
	])
	return result


## 找当前可见的 3D 舞台宿主（overview/market 是 PortStageHost，船厂是 SNShipStage3D）。
func _first_stage_host() -> SNStageHost:
	for node in _all_nodes(root):
		if node is SNStageHost and (node as SNStageHost).has_stage() and (node as SNStageHost).is_stage_visible():
			return node as SNStageHost
	return null


## 进入页面：菜单/港口页直接走 shell 导航状态，at_sea 走真实 voyage.start + 演出推进。
func _prepare_page(shell: Control, page_id: String) -> bool:
	match page_id:
		"main_menu":
			shell._menu_screen = "main"
			shell._active_screen = "overview"
			shell._refresh()
			await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
			return _page_valid(shell, page_id)
		"overview", "market", "shipyard", "sea_chart":
			shell._active_screen = page_id
			shell._refresh()
			return true
		"at_sea":
			return await _prepare_at_sea(shell)
		_:
			_expect(false, "未知页面 id：%s" % page_id)
			return false


## 等页面进入可测状态：舞台站位过渡结束（port stage）、船厂 3D 舞台装配完成。
func _wait_page_ready(shell: Control, page_id: String) -> void:
	match page_id:
		"overview", "market":
			var station := String(STAGE_STATIONS.get(page_id, "harbor"))
			var settled := await _wait_port_station(shell, station, STAGE_WAIT_SECONDS)
			if not settled:
				_failures.append("%s：港口舞台在 %.0f 秒内未就位（station=%s）" % [
					page_id, STAGE_WAIT_SECONDS, station,
				])
				print("[WARN] %s：港口舞台未就位，继续采样" % page_id)
			await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		"shipyard":
			var stage_ready := await _wait_shipyard_stage(shell, STAGE_WAIT_SECONDS)
			if not stage_ready:
				_notes.append("shipyard：3D 舞台未在时限内就绪（可能回退 2D 占位）")
			await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		_:
			await _settle(4, 0.15)


# ---------------------------------------------------------------------------
# 采样核心
# ---------------------------------------------------------------------------

## 连续采样帧时间 + Performance 监视器。
## 每帧：`await process_frame` 的进程帧间隔即上一帧的完整帧时间（含渲染）。
## 退出条件：达到 min_frames 且 elapsed >= min_seconds；或 stop 谓词为真（页面卸载）；或达到 max_frames。
func _collect_frames(min_frames: int, max_frames: int, min_seconds: float, stop: Callable) -> Dictionary:
	var frame_ms: Array[float] = []
	var monitor_values := {}
	for key in MONITOR_DEFS.keys():
		var empty_values: Array[float] = []
		monitor_values[String(key)] = empty_values
	var fps_values: Array[float] = []
	var started := Time.get_ticks_usec()
	var last := started
	var stopped_early := false
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var delta_ms := float(now - last) / 1000.0
		last = now
		frame_ms.append(delta_ms)
		fps_values.append(Engine.get_frames_per_second())
		for key in MONITOR_DEFS.keys():
			var monitor_id: int = MONITOR_DEFS[key]
			var monitor_value := Performance.get_monitor(monitor_id)
			monitor_values[String(key)].append(monitor_value)
			if _debug and frame_ms.size() <= 6:
				print("[MON] frame=%d key=%s value=%.6f" % [frame_ms.size(), String(key), monitor_value])
		var elapsed := float(now - started) / 1000000.0
		var enough := frame_ms.size() >= min_frames and elapsed >= min_seconds
		if enough:
			break
		if frame_ms.size() >= max_frames:
			break
		if stop.is_valid() and bool(stop.call()):
			stopped_early = true
			break
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var stats := _frame_stats(frame_ms)
	stats["elapsed_ms"] = snappedf(elapsed_ms, 0.1)
	stats["fps_avg"] = snappedf(float(frame_ms.size()) / maxf(0.001, elapsed_ms / 1000.0), 0.1)
	return {
		"frames": frame_ms.size(),
		"stopped_early": stopped_early,
		"frame_ms": _rounded(frame_ms, 0.001),
		"fps_engine_median": _median(fps_values),
		"stats": stats,
		"monitors": _monitor_stats(monitor_values),
	}


## 帧时间分布：min / median / p95 / p99 / max / mean + 超预算帧数。
func _frame_stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var total := 0.0
	for value in sorted_values:
		total += value
	var over_60 := 0
	var over_30 := 0
	var over_100 := 0
	for value in sorted_values:
		if value > BUDGET_60_MS:
			over_60 += 1
		if value > BUDGET_30_MS:
			over_30 += 1
		if value > HITCH_MS:
			over_100 += 1
	return {
		"min_ms": snappedf(sorted_values[0], 0.001),
		"median_ms": snappedf(_percentile(sorted_values, 50.0), 0.001),
		"p95_ms": snappedf(_percentile(sorted_values, 95.0), 0.001),
		"p99_ms": snappedf(_percentile(sorted_values, 99.0), 0.001),
		"max_ms": snappedf(sorted_values[sorted_values.size() - 1], 0.001),
		"mean_ms": snappedf(total / float(sorted_values.size()), 0.001),
		"over_16_7_ms_frames": over_60,
		"over_33_3_ms_frames": over_30,
		"over_100_ms_frames": over_100,
	}


func _monitor_stats(monitor_values: Dictionary) -> Dictionary:
	var result := {}
	for key in monitor_values.keys():
		var values: Array = monitor_values[key]
		if values.is_empty():
			continue
		var sorted_values := values.duplicate()
		sorted_values.sort()
		var total := 0.0
		for value in values:
			total += value
		# 时间类监视器默认只有毫秒级精度，这里保留到 10µs 以便看出帧间差异。
		var key_name := String(key)
		var step := 0.00001 if key_name.begins_with("time_") else 0.001
		result[key_name] = {
			"median": snappedf(_percentile(sorted_values, 50.0), step),
			"mean": snappedf(total / float(values.size()), step),
			"max": snappedf(sorted_values[sorted_values.size() - 1], step),
		}
	return result


func _percentile(sorted_values: Array, p: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := int(round(p / 100.0 * float(sorted_values.size() - 1)))
	return sorted_values[clampi(index, 0, sorted_values.size() - 1)]


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return snappedf(_percentile(sorted_values, 50.0), 0.1)


func _rounded(values: Array, step: float) -> Array:
	var result := []
	for value in values:
		result.append(snappedf(value, step))
	return result


# ---------------------------------------------------------------------------
# 页面就绪 / 有效性
# ---------------------------------------------------------------------------

func _stop_when_gone(shell: Control, page_id: String) -> Callable:
	return func() -> bool: return not _page_valid(shell, page_id)


func _page_script(page_id: String) -> Script:
	if not PAGE_SCRIPT_PATHS.has(page_id):
		return null
	if not _script_cache.has(page_id):
		_script_cache[page_id] = load(String(PAGE_SCRIPT_PATHS[page_id]))
	return _script_cache[page_id] as Script


func _page_valid(shell: Control, page_id: String) -> bool:
	if page_id == "at_sea":
		var screen: Variant = shell.get("_at_sea_screen")
		return screen != null and is_instance_valid(screen)
	var script := _page_script(page_id)
	return script != null and _find_script_node(shell, script) != null


## 等港口舞台宿主可见、站位已就位且过渡结束（PortStage 连续港区镜头平移）。
func _wait_port_station(shell: Control, station: String, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var host := shell.get("_port_stage_host") as SNStageHost
		if host != null and is_instance_valid(host) and host.has_stage() and host.is_stage_visible():
			var stage: Node = host.current_stage()
			if stage != null:
				var current := station
				var transitioning := false
				if stage.has_method("current_station"):
					current = String(stage.current_station())
				if stage.has_method("is_station_transitioning"):
					transitioning = bool(stage.is_station_transitioning())
				if current == station and not transitioning:
					return true
		await process_frame
	return false


## 等船厂正常态面板内的 3D 船体舞台（SNShipStage3D）挂载可见。
func _wait_shipyard_stage(shell: Control, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	var ship_stage_script := load(SHIP_STAGE_3D_PATH) as Script
	while Time.get_ticks_msec() < deadline:
		var host := _find_script_node(shell, ship_stage_script) as SNStageHost
		if host != null and is_instance_valid(host) and host.has_stage() and host.is_stage_visible():
			return true
		await process_frame
	return false


# ---------------------------------------------------------------------------
# 视图 / 节点审计
# ---------------------------------------------------------------------------

## 所有 SubViewport 的尺寸 / MSAA / update_mode：审计「舞台是否在隐藏时仍渲染」。
func _viewport_report() -> Array:
	var rows: Array = []
	for node in root.find_children("*", "SubViewport", true, false):
		var viewport := node as SubViewport
		if viewport == null:
			continue
		var parent := viewport.get_parent()
		var visible := true
		if parent is CanvasItem:
			visible = (parent as CanvasItem).is_visible_in_tree()
		rows.append({
			"name": String(viewport.name),
			"parent": String(parent.name) if parent != null else "",
			"parent_class": parent.get_class() if parent != null else "",
			"size": [viewport.size.x, viewport.size.y],
			"msaa_3d": int(viewport.msaa_3d),
			"update_mode": int(viewport.render_target_update_mode),
			"own_world_3d": bool(viewport.own_world_3d),
			"transparent_bg": bool(viewport.transparent_bg),
			"visible_in_tree": visible,
		})
	return rows


## 每个 SNStageHost（= 一个 3D 舞台 SubViewport）的状态。
func _stage_host_report() -> Array:
	var rows: Array = []
	for node in _all_nodes(root):
		if not (node is SNStageHost):
			continue
		var host := node as SNStageHost
		var stage: Node = host.current_stage()
		var viewport: SubViewport = host.stage_viewport()
		var shrink: Variant = host.get("render_shrink")
		rows.append({
			"node": String(host.name),
			"stage_id": String(host.stage_id()),
			"has_stage": host.has_stage(),
			"stage_visible_flag": host.is_stage_visible(),
			"visible_in_tree": host.is_visible_in_tree(),
			"stage_process_mode": int(stage.process_mode) if stage != null else -1,
			"viewport_size": [viewport.size.x, viewport.size.y] if viewport != null else [],
			"viewport_msaa_3d": int(viewport.msaa_3d) if viewport != null else -1,
			"viewport_update_mode": int(viewport.render_target_update_mode) if viewport != null else -1,
			"render_shrink": int(shrink) if shrink != null else -1,
			"stage_class": stage.get_class() if stage != null else "",
		})
	return rows


## 全树节点 / Control 统计（每页重建后页面数量差异）。
func _tree_counts() -> Dictionary:
	var counts := {
		"tree_nodes": get_node_count(),
		"nodes": 0,
		"controls": 0,
		"controls_visible": 0,
		"buttons": 0,
		"labels": 0,
		"texture_rects": 0,
		"containers": 0,
		"mesh_instances_3d": 0,
		"multimesh_instances_3d": 0,
		"subviewports": 0,
		"processing_nodes": 0,
		"process_nodes_3d_visible": 0,
	}
	for node in _all_nodes(root):
		counts["nodes"] += 1
		if node is Control:
			counts["controls"] += 1
			if (node as Control).is_visible_in_tree():
				counts["controls_visible"] += 1
		if node is Button:
			counts["buttons"] += 1
		elif node is Label:
			counts["labels"] += 1
		elif node is TextureRect:
			counts["texture_rects"] += 1
		elif node is Container:
			counts["containers"] += 1
		elif node is MeshInstance3D:
			counts["mesh_instances_3d"] += 1
		elif node is MultiMeshInstance3D:
			counts["multimesh_instances_3d"] += 1
		elif node is SubViewport:
			counts["subviewports"] += 1
		if node.is_processing():
			counts["processing_nodes"] += 1
			if node is Node3D and (node as Node3D).is_visible_in_tree():
				counts["process_nodes_3d_visible"] += 1
	return counts


## UI 素材数量（外部贴图皮肤管线的九宫格 / 图标数）与 Theme 里的 StyleBoxTexture 数。
func _ui_asset_report() -> Dictionary:
	var report := {
		"skin_available": false,
		"skin_style_ids": 0,
		"skin_icon_ids": 0,
		"theme_styleboxtextures": 0,
		"theme_styleboxtextures_unique": 0,
		"theme_types": 0,
	}
	# 外部贴图皮肤管线是 dev.3 之后才有的：dev.3 worktree 里没有 SNSkin，保持 0。
	var skin_script := load(SKIN_PATH) as Script
	if skin_script != null:
		var skin: Variant = skin_script.new()
		if skin != null and skin.has_method("style_ids"):
			report["skin_available"] = bool(skin.call("is_available")) if skin.has_method("is_available") else true
			report["skin_style_ids"] = Array(skin.call("style_ids")).size()
			report["skin_icon_ids"] = Array(skin.call("icon_ids")).size()
	var theme := load(THEME_PATH) as Theme
	if theme != null:
		var types := theme.get_type_list()
		report["theme_types"] = types.size()
		var textures := 0
		var unique := {}
		for type_name in types:
			for item in theme.get_stylebox_list(type_name):
				var box := theme.get_stylebox(item, type_name)
				if box is StyleBoxTexture:
					textures += 1
					var texture := (box as StyleBoxTexture).texture
					if texture != null:
						unique[texture.resource_path] = true
		report["theme_styleboxtextures"] = textures
		report["theme_styleboxtextures_unique"] = unique.size()
	return report


## 每页的关键运行时状态（舞台站位 / 船厂模式 / 演出相位）。
func _page_extra(shell: Control, page_id: String) -> Dictionary:
	var extra := {"active_screen": String(shell.get("_active_screen"))}
	match page_id:
		"overview", "market", "shipyard":
			var host := shell.get("_port_stage_host") as SNStageHost
			if host != null and is_instance_valid(host) and host.has_stage():
				var stage: Node = host.current_stage()
				var shift: Variant = stage.get("_camera_shift_x")
				var minimal: Variant = stage.get("_minimal_stage")
				extra["port_stage"] = {
					"station": String(stage.current_station()) if stage.has_method("current_station") else "",
					"transitioning": bool(stage.is_station_transitioning()) if stage.has_method("is_station_transitioning") else false,
					"facility_count": int(stage.facility_count()) if stage.has_method("facility_count") else 0,
					"has_ship": bool(stage.has_ship()) if stage.has_method("has_ship") else false,
					"minimal_stage": bool(minimal) if minimal != null else false,
					"camera_shift_x": float(shift) if shift != null else 0.0,
					"skyline_buildings": int(stage.skyline_building_count()) if stage.has_method("skyline_building_count") else 0,
					"skyline_cranes": int(stage.skyline_crane_count()) if stage.has_method("skyline_crane_count") else 0,
				}
			if page_id == "shipyard":
				var screen := _find_script_node(shell, _page_script("shipyard"))
				if screen != null:
					var view := _find_script_node(screen, load(SHIP_VIEW_PATH) as Script)
					if view != null:
						var mode_value: Variant = view.get("mode")
						extra["ship_view"] = {
							"has_renderer": bool(view.has_renderer()) if view.has_method("has_renderer") else false,
							"mode": int(mode_value) if mode_value != null else -1,
						}
					extra["shipyard_refit"] = bool(screen.get("_refit"))
		"at_sea":
			var presentation: Variant = shell.get("_presentation")
			if presentation != null and is_instance_valid(presentation):
				var progress_value: Variant = presentation.get("progress")
				extra["presentation"] = {
					"phase": String(presentation.phase_name()),
					"veil": snappedf(float(presentation.veil), 0.0001),
					"progress": snappedf(float(progress_value), 0.0001) if progress_value != null else 0.0,
				}
		"sea_chart":
			extra["port_stage_visible"] = _port_stage_visible(shell)
	return extra


func _port_stage_visible(shell: Control) -> bool:
	var host := shell.get("_port_stage_host") as SNStageHost
	if host == null or not is_instance_valid(host):
		return false
	return host.is_stage_visible() and host.is_visible_in_tree()


# ---------------------------------------------------------------------------
# at_sea：真实 voyage.start + VoyagePresentation 推进
# ---------------------------------------------------------------------------

func _prepare_at_sea(shell: Control) -> bool:
	var context := _context_from_shell(shell)
	if context == null:
		_expect(false, "at_sea：拿不到 AppContext")
		return false
	_bot_ensure_liquidity(context, 300)
	var destination := _first_destination(context)
	if destination.is_empty():
		_expect(false, "at_sea：没有目的地（主线委托 / 相邻港口）")
		return false
	_bot_prepare_voyage(context, destination)
	shell._run_command(&"voyage.start", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})
	if shell.get("_presentation") == null:
		_expect(false, "at_sea：voyage.start 没有交接到航行演出")
		return false
	var reached := _drive_shell_until(shell, func() -> bool:
		var screen: Variant = shell.get("_at_sea_screen")
		return screen != null and is_instance_valid(screen), FLOW_DRIVE_MAX_SECONDS)
	if not bool(reached):
		_expect(false, "at_sea：演出未推进到海图航行页")
		return false
	# 等离港云幕散开（演出继续播放，采样时船在动）。
	_drive_shell_until(shell, func() -> bool:
		var presentation: Variant = shell.get("_presentation")
		return presentation == null or float(presentation.veil) <= 0.0001, 8.0)
	await process_frame
	return _page_valid(shell, "at_sea")


func _first_destination(context: AppContext) -> String:
	var contracts: Dictionary = context.state.contracts()
	var main_contract: Variant = contracts.get("main", null)
	if main_contract is Dictionary:
		return String((main_contract as Dictionary).get("destination", ""))
	var main_offer: Variant = contracts.get("main_offer", null)
	if main_offer is Dictionary:
		return String((main_offer as Dictionary).get("destination", ""))
	var neighbors := MapOps.neighbors(context.state.world(), context.state.current_port_id())
	return String(neighbors[0]) if not neighbors.is_empty() else ""


## 推进 shell 的 VoyagePresentation 状态机（与 ui_snapshot / test_voyage_flow 同法）。
func _drive_shell_until(shell: Control, predicate: Callable, max_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < max_seconds:
		if bool(predicate.call()):
			return true
		shell._process(FLOW_DRIVE_STEP)
		elapsed += FLOW_DRIVE_STEP
	return bool(predicate.call())


func _bot_ensure_liquidity(context: AppContext, floor: int = 700) -> void:
	if context.state.money() >= floor:
		return
	if context.state.player().get("debt", null) == null:
		context.commands.execute(&"debt.borrow", {"amount": 400})


func _bot_prepare_voyage(context: AppContext, destination: String) -> void:
	var preview: Dictionary = context.commands.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	if not bool(preview.get("ok", false)):
		return
	var data: Dictionary = preview.get("data", {})
	_bot_buy_supply(context, "coal", float(data.get("coal_required", 0.0)) + 4.0)
	_bot_buy_supply(context, "water", float(data.get("water_required", 0.0)) + 4.0)
	if float(context.state.ship().get("durability", 0.0)) < float(context.state.ship().get("max_durability", 1.0)) * 0.35:
		context.commands.execute(&"supply.repair", {})


func _bot_buy_supply(context: AppContext, kind: String, wanted: float) -> void:
	var current := float(context.state.ship().get(kind, 0.0))
	if current >= wanted:
		return
	var amount := int(ceil(wanted - current))
	var command := &"supply.buy_coal" if kind == "coal" else &"supply.buy_water"
	var result: Dictionary = context.commands.execute(command, {"amount": amount})
	if bool(result.get("ok", false)):
		return
	var port := context.state.current_port_id()
	var price := 4.0
	var market: Dictionary = context.state.market().get(port, {})
	var item: Variant = market.get("core:item/%s" % kind, null)
	if item is Dictionary:
		price = maxf(1.0, float((item as Dictionary).get("price", 4.0)))
	var affordable := int(floor(float(context.state.money()) / price))
	if affordable > 0:
		context.commands.execute(command, {"amount": mini(affordable, amount)})


# ---------------------------------------------------------------------------
# 环境 / 配置
# ---------------------------------------------------------------------------

## 运行时 MSAA 覆盖（不写 project.godot）。项目值 2 = 4x；子视口默认被
## SNStageHost 硬编码成 MSAA_4X，所以这里必须单独覆盖 SubViewport，否则
## 改项目设置对 3D 舞台完全没有效果。
func _apply_root_msaa() -> void:
	if _msaa >= 0:
		ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", _msaa)
		root.msaa_3d = _msaa


func _apply_page_msaa() -> void:
	var stage_value := _stage_msaa if _stage_msaa >= 0 else _msaa
	if stage_value < 0:
		return
	for node in root.find_children("*", "SubViewport", true, false):
		var viewport := node as SubViewport
		if viewport != null:
			viewport.msaa_3d = stage_value


## --no-stage：把所有 3D 舞台宿主隐藏（SubViewport 转 UPDATE_DISABLED，舞台 PROCESS_MODE_DISABLED）。
func _apply_no_stage() -> void:
	for node in _all_nodes(root):
		if node is SNStageHost:
			(node as SNStageHost).set_stage_visible(false)


func _bootstrap_core() -> Dictionary:
	var config := {
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://perf_probe_saves/%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()],
	}
	if not _mount_zip.is_empty():
		# 不走 ProjectSettings.load_resource_pack（那会把 zip 目录当松散目录）：
		# 把 pack 拷进 user:// 扫描根，让 ModScanner 按 `.snavmod.zip` 走 ZipModSource，
		# 再由 ModLoader 的 mount_packs 挂载 —— 与发布版读 zip 资产的链路一致。
		var source := _absolute_path(_mount_zip)
		var pack_dir := "user://perf_probe_packs"
		var pack_dir_absolute := ProjectSettings.globalize_path(pack_dir)
		DirAccess.make_dir_recursive_absolute(pack_dir_absolute)
		var target := pack_dir_absolute.path_join(source.get_file())
		var copy_error := DirAccess.copy_absolute(source, target)
		_notes.append("mount_zip=%s -> %s (copy_error=%d)" % [source, target, copy_error])
		print("[INFO] mount zip：%s -> %s（copy_error=%d）" % [source, target, copy_error])
		# 发布版路径：不扫 dev_mods、不跑松散目录，只从挂载的 pack 里读 mods/。
		config["scan_roots"] = PackedStringArray([pack_dir])
		config["allow_loose"] = false
		config["mount_packs"] = true
	var bootstrap := Bootstrap.new()
	var report: StartupReport = bootstrap.run(config)
	AppContext.set_active(bootstrap.context)
	return {
		"bootstrap": bootstrap,
		"context": bootstrap.context,
		"report": report,
	}


func _mount_shell() -> Control:
	var scene := load(MAIN_SCENE) as PackedScene
	if scene == null:
		_expect(false, "加载不了 %s" % MAIN_SCENE)
		return null
	var shell: Control = scene.instantiate()
	root.add_child(shell)
	if not shell.is_inside_tree():
		_expect(false, "Shell 没有进入场景树")
		return null
	return shell


func _teardown(shell: Control) -> void:
	if shell != null:
		if shell.get_parent() != null:
			shell.get_parent().remove_child(shell)
		shell.free()
	FrameworkRuntime.shutdown()
	await process_frame


# ---------------------------------------------------------------------------
# 输出
# ---------------------------------------------------------------------------

func _write_json() -> void:
	var data := {
		"tool": "tools/godot/perf_probe.gd",
		"tag": _tag,
		"generated_at": Time.get_datetime_string_from_system(),
		"env": _env_report(),
		"config": {
			"seed": _seed,
			"screens": _screens,
			"sample_seconds": _sample_seconds,
			"min_frames": MIN_SAMPLE_FRAMES,
			"hitch_frames": HITCH_FRAMES,
			"msaa": _msaa,
			"stage_msaa": _stage_msaa,
			"no_stage": _no_stage,
			"vsync": "on" if _vsync_enabled else "off",
			"no_teardown": _no_teardown,
			"mount_zip": _mount_zip,
		},
		"pages": _page_results,
		"notes": _notes,
		"failures": _failures,
	}
	var absolute := _absolute_path(_out_path)
	var directory := absolute.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and not DirAccess.dir_exists_absolute(directory):
		_failures.append("创建输出目录失败：%s" % directory)
		return
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		_failures.append("输出 JSON 打不开：%s" % absolute)
		return
	file.store_string(JSON.stringify(data, "  ", false, true))
	file.close()
	print("[INFO] JSON → %s" % absolute)


func _env_report() -> Dictionary:
	var display_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	return {
		"godot_version": String(Engine.get_version_info().get("string", "")),
		"os": OS.get_name(),
		"cpu_count": OS.get_processor_count(),
		"video_adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"video_adapter_name": RenderingServer.get_video_adapter_name(),
		"video_adapter_api": RenderingServer.get_video_adapter_api_version(),
		"rendering_method": String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")),
		"project_msaa_3d": int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", -1)),
		"window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"root_size": [root.size.x, root.size.y],
		"screen_size": [display_size.x, display_size.y],
		"stretch_mode": String(ProjectSettings.get_setting("display/window/stretch/mode", "?")),
		"stretch_aspect": String(ProjectSettings.get_setting("display/window/stretch/aspect", "?")),
		"content_scale_size": [root.content_scale_size.x, root.content_scale_size.y],
		"project_vsync_mode": int(ProjectSettings.get_setting("display/window/vsync/vsync_mode", -1)),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
	}


func _print_table() -> void:
	print("")
	print("page            fps(avg) frame_ms(med)   p95    p99    max   draws  prims    vmem(MB) nodes ctrl  subvp 3d-meshes")
	print("---------------- -------- ------------- ------ ------ ------ ------ ------ --------- ----- ---- ----- ---------")
	for page_result in _page_results:
		if String(page_result.get("mode", "")) == "isolate_3d":
			print("%-16s [isolate] on=%.2fms off=%.2fms 配对差值=%.2fms（各轮 %s）" % [
				String(page_result.get("id", "?")),
				float(page_result.get("on_median_ms", 0.0)),
				float(page_result.get("off_median_ms", 0.0)),
				float(page_result.get("delta_median_ms", 0.0)),
				str(page_result.get("delta_all_ms", [])),
			])
			continue
		if not page_result.has("sample"):
			print("%-16s  (failed: %s)" % [String(page_result.get("id", "?")), str(page_result.get("notes", []))])
			continue
		var page_id := String(page_result.get("id", "?"))
		var sample: Dictionary = page_result.get("sample", {})
		var stats: Dictionary = sample.get("stats", {})
		var monitors: Dictionary = sample.get("monitors", {})
		var counts: Dictionary = page_result.get("counts", {})
		var draw_calls := float((monitors.get("draw_calls", {}) as Dictionary).get("median", 0.0))
		var primitives := float((monitors.get("primitives", {}) as Dictionary).get("median", 0.0))
		var video_mem := float((monitors.get("video_mem", {}) as Dictionary).get("median", 0.0))
		print("%-16s %8.1f %13.2f %6.2f %6.2f %6.2f %6.0f %6.0f %9.1f %5d %4d %5d %5d" % [
			page_id,
			float(stats.get("fps_avg", 0.0)),
			float(stats.get("median_ms", 0.0)),
			float(stats.get("p95_ms", 0.0)),
			float(stats.get("p99_ms", 0.0)),
			float(stats.get("max_ms", 0.0)),
			draw_calls,
			primitives,
			video_mem / (1024.0 * 1024.0),
			int(counts.get("nodes", 0)),
			int(counts.get("controls", 0)),
			int(counts.get("subviewports", 0)),
			int(counts.get("mesh_instances_3d", 0)),
		])
	print("")
	print("hitch（切页后首 %d 帧）:" % HITCH_FRAMES)
	for page_result in _page_results:
		var hitch: Dictionary = page_result.get("hitch", {})
		if hitch.is_empty():
			continue
		var stats: Dictionary = hitch.get("stats", {})
		print("  %-16s frames=%4d median=%6.2fms p95=%7.2fms max=%7.2fms >33ms=%3d >100ms=%2d%s" % [
			String(page_result.get("id", "?")),
			int(hitch.get("frames", 0)),
			float(stats.get("median_ms", 0.0)),
			float(stats.get("p95_ms", 0.0)),
			float(stats.get("max_ms", 0.0)),
			int(stats.get("over_33_3_ms_frames", 0)),
			int(stats.get("over_100_ms_frames", 0)),
			"  (stopped early)" if bool(hitch.get("stopped_early", false)) else "",
		])
	print("")
	for page_result in _page_results:
		var viewports: Array = page_result.get("viewports", [])
		var hosts: Array = page_result.get("stage_hosts", [])
		if viewports.is_empty() and hosts.is_empty():
			continue
		print("  [views] %s：subviewports=%d stage_hosts=%d" % [
			String(page_result.get("id", "?")), viewports.size(), hosts.size(),
		])
		for row in viewports:
			print("    - vp %-18s %s msaa=%d update=%d visible=%s" % [
				String(row.get("name", "")), str(row.get("size", [])),
				int(row.get("msaa_3d", -1)), int(row.get("update_mode", -1)),
				str(row.get("visible_in_tree", false)),
			])
		for row in hosts:
			print("    - host %-16s stage=%s visible_flag=%s in_tree=%s process=%d" % [
				String(row.get("node", "")), String(row.get("stage_id", "")),
				str(row.get("stage_visible_flag", false)), str(row.get("visible_in_tree", false)),
				int(row.get("stage_process_mode", -1)),
			])


## 抓 root 视口（= 主窗口）当前画面：用于核对 2D 布局/舞台窗口在不同分辨率下的实际形态。
func _capture_screenshot(file_name: String) -> String:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return ""
	var path := _absolute_path(_shots_dir.path_join(file_name))
	var directory := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and not DirAccess.dir_exists_absolute(directory):
		return ""
	if image.save_png(path) != OK:
		return ""
	return path


func _absolute_path(path_value: String) -> String:
	if path_value.begins_with("res://") or path_value.begins_with("user://"):
		return ProjectSettings.globalize_path(path_value)
	if path_value.is_absolute_path():
		return path_value
	return ProjectSettings.globalize_path("res://").path_join(path_value)


# ---------------------------------------------------------------------------
# 通用工具
# ---------------------------------------------------------------------------

func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout
	for i in 2:
		await process_frame


func _wait_window_size(size: Vector2i) -> void:
	for i in 240:
		if absi(root.size.x - size.x) <= 2 and absi(root.size.y - size.y) <= 2:
			break
		await process_frame
	if not (absi(root.size.x - size.x) <= 2 and absi(root.size.y - size.y) <= 2):
		_notes.append("窗口尺寸 %s 与请求 %s 不一致（显示缩放？）" % [str(root.size), str(size)])
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)


func _all_nodes(from: Node) -> Array:
	var result: Array = []
	var stack: Array = [from]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		result.append(node)
		for child in node.get_children():
			stack.append(child)
	return result


func _find_script_node(from: Node, script: Script) -> Node:
	if script == null:
		return null
	for child in from.get_children():
		if child.get_script() == script:
			return child
		var found := _find_script_node(child, script)
		if found != null:
			return found
	return null


func _context_from_shell(shell: Control) -> AppContext:
	var context: Variant = shell.get("_context")
	if context is AppContext:
		return context as AppContext
	return AppContext.get_active()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--out="):
			_out_path = text.get_slice("=", 1)
		elif text.begins_with("--resolution="):
			var parts := text.get_slice("=", 1).split("x")
			if parts.size() == 2:
				_window = Vector2i(int(parts[0]), int(parts[1]))
		elif text.begins_with("--msaa="):
			_msaa = int(text.get_slice("=", 1))
		elif text.begins_with("--stage-msaa="):
			_stage_msaa = int(text.get_slice("=", 1))
		elif text == "--no-stage":
			_no_stage = true
		elif text == "--no-teardown":
			_no_teardown = true
		elif text.begins_with("--vsync="):
			_vsync_enabled = text.get_slice("=", 1) == "on"
		elif text.begins_with("--screens="):
			_screens.clear()
			for part in text.get_slice("=", 1).split(",", false):
				var page_id := String(part).strip_edges()
				if not page_id.is_empty():
					_screens.append(page_id)
		elif text.begins_with("--sample-seconds="):
			_sample_seconds = float(text.get_slice("=", 1))
		elif text.begins_with("--seed="):
			_seed = int(text.get_slice("=", 1))
		elif text.begins_with("--tag="):
			_tag = text.get_slice("=", 1)
		elif text.begins_with("--shots="):
			_shots_dir = text.get_slice("=", 1)
		elif text.begins_with("--mount-zip="):
			_mount_zip = text.get_slice("=", 1)
		elif text.begins_with("--isolate="):
			_isolate_screens.clear()
			for part in text.get_slice("=", 1).split(",", false):
				var page_id := String(part).strip_edges()
				if not page_id.is_empty():
					_isolate_screens.append(page_id)
		elif text.begins_with("--isolate-cycles="):
			_isolate_cycles = maxi(1, int(text.get_slice("=", 1)))
		elif text.begins_with("--isolate-frames="):
			_isolate_frames = maxi(12, int(text.get_slice("=", 1)))
		elif text == "--debug":
			_debug = true
	if _screens.is_empty():
		for part in DEFAULT_SCREENS.split(",", false):
			_screens.append(String(part).strip_edges())


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] " + message)
	else:
		_failures.append(message)
		print("[FAIL] " + message)
