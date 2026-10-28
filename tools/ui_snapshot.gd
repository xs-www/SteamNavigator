extends SceneTree
## 船厂 UI 截图验收工具（真实渲染，窗口 1440×900）。
##
## 用法（必须窗口模式，不能加 --headless，否则视口纹理是空图）：
##   godot --path . --resolution 1440x900 --script res://tools/ui_snapshot.gd -- --seed=5201
## 或直接用包装脚本：
##   pwsh ./tools/capture_ui.ps1
##
## 流程与框架测试的 bootstrap_core 完全一致：
##   Bootstrap.run(scan res://dev_mods, allow_loose, 不挂 pack, 不自动存档)
##   → AppContext.set_active → run.start {core:starting_scenario/steady, seed}
##   → 实例化 res://framework/ui/shell/main.tscn 并挂到 root
##   → 等待布局 → 切到 shipyard → 截图 shipyard_normal.png
##   → 进入改装态（点「改装」按钮）→ 截图 shipyard_refit.png → 干净退出
##
## 输出默认写入 res://docs/design/screenshots/。脚本通过
## ProjectSettings.globalize_path 落盘，避免 res:// 在某些启动方式下不可写。
## 额外参数（放在 `--` 之后）：
##   --seed=5201                     固定种子
##   --out-dir=res://docs/design/screenshots
##   --window=1440x900               窗口/截图尺寸
##   --category=cargo,misc           改装态额外按分类各截一张（hulls/boiler/cargo/utility/cabin/misc）
##   --tabs=buy,craft                改装态额外按操作坞页签各截一张
##                                   （shipyard_refit_buy.png / shipyard_refit_craft.png；
##                                   页签与装配分离，用于验收购买 / 打造独立列表）
##   --damage=boiler:0.5[,cargo:0.4] 先损坏指定模块实例，再额外截取受损状态的
##                                   船厂正常态 / 改装态 / 补给维修页
##   --overview-stage                额外切到总览页并截取主界面（3D 港口舞台 +
##                                   紧凑顶部 HUD + 两侧招牌 + 底部状态条）：
##                                   overview_port_stage.png
##   --overview-detail               在 --overview-stage 的基础上打开「详细总览」
##                                   抽屉，截取 overview_detail.png（隐含
##                                   --overview-stage）
##   --station-shots                 额外切到市场 / 补给页，截取常驻 3D 港口舞台的
##                                   泊位画面（连续港区 + 三个相邻站位）：market_station.png
##                                   / supply_station.png（1440×900），再把窗口缩到
##                                   960×540 补一张 market_station_960.png。截图前
##                                   轮询 shell._port_stage_host 的 PortStage
##                                   current_station() / is_station_transitioning()，
##                                   等舞台可见且泊位过渡结束。
##   --skip-refit                    只截正常态
##
## ## 全页面皮肤截图（-AllScreens / -Screens）
## 由 `tools/capture_ui.ps1 -AllScreens` / `-Screens "..."` 调用：
##   godot --path . --resolution 1440x900 --window=1440x900 --script res://tools/ui_snapshot.gd -- \
##     --out-dir=res://docs/design/screenshots/skin/1440x900 --all-screens
##   godot --path . --resolution 960x540 --window=960x540 --script res://tools/ui_snapshot.gd -- \
##     --out-dir=res://docs/design/screenshots/skin/960x540 --screens=overview,market,victory
## 逐页截图（每张输出 `<out-dir>/<screen>.png`）：main_menu / new_game / mods / settings /
## overview / overview_2d / overview_detail / market / supply / contracts / tavern / base /
## auto_trade / ruins / shipyard_normal / shipyard_refit / shipyard_buy / shipyard_craft /
## shipyard_misc / sea_chart / clue_log / at_sea / event / settlement / victory / ui_kit。
##
## 特殊状态的进入方式（不造假数据）：
##   - at_sea / event / settlement：在真实 shell 里执行 `voyage.start`，再用
##     `shell._process()` 推进 `VoyagePresentation` 状态机到目标相位；event 用
##     VoyageService 的确定性事件采样选出会触发事件的 seed（与 test_voyage_flow 同一手法）。
##   - victory：用真实 CommandBus 脚本通关（主线 5 章 + 大型船体），再由 shell 的
##     victory 视图挂载胜利页。
##   - supply：4.5.3 起补给页已合并进 market（main.gd 把 `supply` 重定向到 `market`），
##     这里按真实导航路径进入并把页面滚到 MarketSupply 区块后截图，报告里同样注明。
##   - main_menu / new_game / mods / settings：真实 `reset_state()` 后由 shell 的
##     `_menu_screen` 切换，走与玩家点击相同的菜单构建路径。
##   - ui_kit：挂载 `framework/ui/showcase/ui_kit_showcase.tscn` 独立展示页。
## 运行开始时逐张打印 `[EXPECT] <绝对路径>`，包装脚本据此校验每张截图存在且新鲜；
## 任一截图失败、画面为空或目标页面进不去时以退出码 1 结束。


const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const SHIPYARD_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/shipyard_screen.gd")
const OVERVIEW_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/overview_screen.gd")
const SN_SHIP_VIEW_SCRIPT := preload("res://framework/ui/components/sn_ship_view.gd")
const STEADY_BUILD := "core:starting_scenario/steady"
const DEFAULT_SEED := 5201
const DEFAULT_OUT_DIR := "res://docs/design/screenshots"
const DEFAULT_WINDOW := Vector2i(1440, 900)
## ~0.5 秒 / 60fps 的布局稳定帧数；真实窗口没有固定帧率，所以再配一段等待。
const LAYOUT_FRAMES := 30
const LAYOUT_SETTLE_SECONDS := 0.35
const REFIT_FRAMES := 20
const REFIT_SETTLE_SECONDS := 0.2
## --station-shots：市场 / 补给页的常驻 3D 港口舞台（连续港区 + 三站位）。
## 站点 id 与主界面页面一一对应，另补一张 960×540 的 market 泊位。
const STATION_SCREENS := [
	{"screen": "market", "station": "market", "file": "market_station.png"},
	{"screen": "supply", "station": "supply", "file": "supply_station.png"},
]
const STATION_SMALL_WINDOW := Vector2i(960, 540)
const STATION_TIMEOUT_SECONDS := 10.0
## 兜底：脚本错误会让协程中断而不退出，窗口就会挂住，这里强制收尾。
const WATCHDOG_SECONDS := 120

## ---------------------------------------------------------------------------
## 全页面皮肤截图（--all-screens / --screens=）：逐页 id = 输出文件名（不含 .png）
## ---------------------------------------------------------------------------
const VICTORY_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/victory_screen.gd")
const EVENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/event_screen.gd")
const UI_KIT_SCENE := "res://framework/ui/showcase/ui_kit_showcase.tscn"
## 与 test_voyage_flow / test_full_clear 使用同一套公开 API 与策略 id。
const STANDARD_STRATEGY := "core:boiler_strategy/standard"
## 皮肤模式逐页截图的清单（顺序即执行顺序）；菜单/流程页由后面的阶段单独处理。
const SKIN_PORT_SCREENS := [
	"overview", "overview_2d", "overview_detail",
	"market", "supply", "contracts", "tavern", "base", "auto_trade", "ruins",
	"shipyard_normal", "shipyard_refit", "shipyard_buy", "shipyard_craft", "shipyard_misc",
	"sea_chart", "clue_log",
]
const SKIN_FLOW_SCREENS := ["at_sea", "event", "settlement"]
const SKIN_MENU_SCREENS := ["main_menu", "new_game", "mods", "settings"]
const SKIN_ALL_SCREENS := [
	"main_menu", "new_game", "mods", "settings",
	"overview", "overview_2d", "overview_detail",
	"market", "supply", "contracts", "tavern", "base", "auto_trade", "ruins",
	"shipyard_normal", "shipyard_refit", "shipyard_buy", "shipyard_craft", "shipyard_misc",
	"sea_chart", "clue_log", "ui_kit",
	"at_sea", "event", "settlement", "victory",
]
## 推进 VoyagePresentation 状态机时每步模拟的秒数（与 test_voyage_flow 的 STEP_SECONDS 一致）。
const FLOW_DRIVE_STEP := 0.1
const FLOW_DRIVE_MAX_SECONDS := 90.0
## 事件采样：在 1..N 里找会触发事件的确定性 seed（与 test_voyage_flow 同一手法）。
const EVENT_SEED_SEARCH := 400

var _failures: Array[String] = []
var _seed := DEFAULT_SEED
var _out_dir := DEFAULT_OUT_DIR
var _window := DEFAULT_WINDOW
## 额外截图的分类（--category=cargo,misc；C1 分类：hulls/boiler/cargo/utility/cabin/misc）。
var _categories: Array[String] = ["cargo", "misc"]
## Optional operations-dock tabs to capture in the refit page (`--tabs=buy,craft`).
## Each tab is captured once under the first category (`shipyard_refit_<tab>.png`).
var _tabs: Array[String] = []
var _skip_refit := false
## 是否额外截取总览页的 3D 港口舞台。
var _overview_stage := false
## 是否在总览主界面基础上再截取「详细总览」抽屉。
var _overview_detail := false
## 是否额外截取市场 / 补给页的常驻 3D 港口舞台（连续港区 + 三个相邻站位）。
var _station_shots := false
## 截图前要损坏的模块实例：{"slot": "boiler", "index": 0, "ratio": 0.5}。
var _damage_targets: Array = []
var _saved: Array[String] = []
## 全页面皮肤截图：--all-screens 或 --screens=<id,id>（为空时走旧的船厂/总览流程）。
var _all_screens := false
var _screens: Array[String] = []


func _init() -> void:
	_parse_args()
	_watchdog()
	_run()


func _watchdog() -> void:
	var seconds := WATCHDOG_SECONDS + (45 if _station_shots else 0) + (180 if _skin_battery_enabled() else 0)
	await process_frame
	await create_timer(seconds).timeout
	push_error("ui_snapshot: 截图流程超时（%d 秒），强制退出" % seconds)
	quit(1)


func _run() -> void:
	print("=== 船厂 UI 截图验收（%dx%d，seed=%d）===" % [_window.x, _window.y, _seed])
	if DisplayServer.get_name() == "headless":
		_expect(false, "必须以窗口模式运行（去掉 --headless），否则渲染纹理为空")
		_finish()
		return
	DisplayServer.window_set_size(_window)
	DisplayServer.window_set_title("Steam Navigator · UI snapshot")
	# 先等一帧，确保 SceneTree / 窗口 / 主题字体都已就绪。
	await process_frame
	if not _window_matches():
		_expect(false, "窗口尺寸是 %s，期望 %s（可用 --window=1440x900 覆盖）" % [str(root.size), str(_window)])
		_finish()
		return
	print("[INFO] 窗口尺寸：%s，视口可见区域：%s" % [str(root.size), str(root.get_visible_rect().size)])

	var boot := _bootstrap_core()
	var context: AppContext = boot["context"]
	if context == null or not context.is_ready():
		_expect(false, "Core 启动失败，无法截图：%s" % str(boot.get("report")))
		_finish()
		return
	print("[INFO] Core 就绪：mod=%s，内容条目=%d" % [str(context.mod_order), context.content_total()])
	var started: Dictionary = context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": _seed,
	})
	_expect(bool(started.get("ok", false)), "run.start 成功：%s" % str(started))
	if not bool(started.get("ok", false)):
		_finish()
		return
	for target in _damage_targets:
		var outcome := ShipModules.damage(context.state.ship(), String(target["slot"]), int(target["index"]), float(target["ratio"]))
		_expect(bool(outcome.get("ok", false)), "损坏部件 %s[%d] %.0f%%" % [String(target["slot"]), int(target["index"]), float(target["ratio"]) * 100.0])
	var damaged := not _damage_targets.is_empty()

	var shell := _mount_shell()
	if shell == null:
		_finish()
		return
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	print("[INFO] 起始页面：%s（菜单遮罩可见=%s）" % [String(shell._active_screen), str(shell._menu_background.visible)])

	# 新入口：全页面皮肤截图（-AllScreens / -Screens）。旧的船厂/总览流程完全保留，
	# 只有显式传入皮肤参数时才走这里，参数与输出路径向后兼容。
	if _skin_battery_enabled():
		_announce_skin_expectations()
		await _capture_skin_battery(shell, context)
		await _teardown(shell)
		_finish()
		return

	# 正常态：船厂页船体侧视。
	shell._active_screen = "shipyard"
	shell._refresh()
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	var screen := _find_shipyard(shell)
	if screen == null:
		_expect(false, "在 Shell 的 _root_box 里找不到 ShipyardScreen")
		_finish()
		return
	var stage: Variant = screen.get("_stage")
	if stage != null and int(stage.mode) == 0:
		print("[PASS] 正常态为船体侧视（SNShipView.Mode.EXTERIOR）")
	elif stage != null:
		_expect(false, "正常态不是船体侧视，mode=%s" % str(stage.mode))
	if bool(screen.get("_refit")):
		_expect(false, "正常态不应处于改装态")
	await _capture(_path("shipyard_normal.png"))
	if damaged:
		await _capture(_path("shipyard_normal_damaged.png"))

	if _skip_refit:
		print("[INFO] 跳过改装态截图（--skip-refit）")
	else:
		# 改装态：真实点击页面上的「改装」按钮（与玩家操作同一条路径）。
		var pressed := _enter_refit(shell, screen)
		_expect(pressed, "找到并点击了「改装」按钮")
		await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
		await _wait_port_stage_settled(shell)
		_expect(bool(screen.get("_refit")), "点击后页面进入改装态")
		_expect(bool(shell._shipyard_refit), "Shell 记住了改装态（_shipyard_refit）")
		stage = screen.get("_stage")
		if stage != null:
			_expect(int(stage.mode) == SN_SHIP_VIEW_SCRIPT.Mode.CUTAWAY, "改装态显示纵剖图（SNShipView.Mode.CUTAWAY）")
		await _capture(_path("shipyard_refit.png"))
		# 购买 / 打造与装配是独立页签（`--tabs=buy,craft` 时各截一张）。
		for tab in _tabs:
			screen.set_tab(tab)
			await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
			_expect(String(screen.get("_tab")) == tab, "改装页签切换到 %s" % tab)
			await _capture(_path("shipyard_refit_%s.png" % tab))
		if not _tabs.is_empty():
			screen.set_tab("install")
			await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
		# 每个额外分类各截一张，用于对照参考布局的中间操作区 / 右侧竖排 tab。
		for category in _categories:
			if category == "hulls":
				continue
			screen.set_category(category)
			await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
			_expect(String(screen.get("_category")) == category, "分类切换到 %s" % category)
			_expect(String(shell._shipyard_category) == category, "Shell 记住分类 %s" % category)
			if _is_visible_category(shell, screen, category):
				await _capture(_path("shipyard_refit_%s.png" % _category_short(category)))
			else:
				_expect(false, "分类 %s 的中间操作面板没有渲染出来" % category)

	if damaged:
		if not _skip_refit:
			screen.set_category("boiler")
			await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
			await _capture(_path("shipyard_refit_damaged.png"))
		shell._active_screen = "supply"
		shell._refresh()
		await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		await _capture(_path("supply_damaged.png"))

	if _overview_stage:
		shell._active_screen = "overview"
		shell._refresh()
		await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		var overview := _node_with_script(shell._root_box, OVERVIEW_SCREEN_SCRIPT)
		_expect(overview != null, "总览页已挂载")
		_expect(bool(shell._port_stage_available()), "港口舞台场景存在")
		# The 3D stage is the default main view; only toggle it on if a prior
		# step left the shell in the 2D fallback.
		if not bool(shell._overview_stage_mode):
			shell._on_overview_stage_toggle()
			await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		_expect(bool(shell._overview_stage_mode), "总览默认进入 3D 港口舞台模式")
		var port_host: SNStageHost = shell._port_stage_host
		_expect(port_host != null and port_host.is_stage_visible(), "PortStage 宿主可见")
		var port_stage: Variant = port_host.current_stage() if port_host != null else null
		_expect(port_stage is PortStage, "挂载的是 PortStage 场景")
		if port_stage is PortStage:
			_expect(int(port_stage.facility_count()) > 0, "港口舞台装配了设施")
			_expect(bool(port_stage.has_ship()), "港口舞台挂载了玩家船")
		var sign_buttons := 0
		if shell._port_hotspot_layer != null:
			for child in shell._port_hotspot_layer.get_children():
				if child is Button:
					sign_buttons += 1
		var facility_count := 0
		if port_stage is PortStage:
			facility_count = int((port_stage as PortStage).facility_count())
		# 4.5.3 起 supply 并入 market，PortStage 仍计 supply 设施但没有独立招牌，
		# 因此招牌数 = 设施数（有 supply）或设施数 + 1（无 supply，海图招牌常驻）。
		_expect(
			sign_buttons == facility_count or sign_buttons == facility_count + 1,
			"总览舞台生成了设施招牌 + 出航招牌（%d 个 / 设施 %d）" % [sign_buttons, facility_count]
		)
		_expect(shell._top_chrome != null, "紧凑顶部 HUD 已挂载")
		if shell._top_chrome != null:
			var chrome_height := (shell._top_chrome as Control).get_combined_minimum_size().y
			_expect(chrome_height <= 130.0, "顶部 HUD 高度 %.1f px（预算 ≤130）" % chrome_height)
		_expect(shell.find_child("PortStatusBar", true, false) == null,
			"底部状态条已移除（2026-10-28 UI 轮）")
		await _capture(_path("overview_port_stage.png"))
		if _overview_detail:
			# 2026-10-28：底部状态条与「详细总览」抽屉移除；详细总览就是 2D 总览页
			# （顶部「2D 总览」开关切过去），这里直接切换后截图。
			if bool(shell._overview_stage_mode):
				shell._on_overview_stage_toggle()
				await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
			_expect(not bool(shell._overview_stage_mode), "详细总览切到 2D 总览页")
			_expect(_node_with_script(shell._root_box, OVERVIEW_SCREEN_SCRIPT) != null, "2D 总览页已挂载")
			await _capture(_path("overview_detail.png"))

	if _station_shots:
		await _snapshot_station_pages(shell)

	await _teardown(shell)
	_finish()


## ---------------------------------------------------------------------------
## --station-shots：市场 / 补给页的常驻 3D 港口舞台（连续港区 + 三站位）
## ---------------------------------------------------------------------------

## 先回总览页确保舞台宿主已建并可见，再依次切到 market / supply 页：每次刷新后
## 轮询宿主可见、`PortStage.current_station()` 已切到对应泊位且
## `is_station_transitioning()` 为 false，然后截图。最后把窗口缩到 960×540，
## 在 market 页补一张 market_station_960.png。任何一个等待失败都会记为失败项。
func _snapshot_station_pages(shell: Control) -> void:
	print("[INFO] station shots：市场 / 补给页 3D 港口舞台")
	if not bool(shell._port_stage_available()):
		_expect(false, "3D 港口舞台场景可用（--station-shots 前置）")
		return
	if not bool(shell._overview_stage_mode):
		if shell.has_method("_on_overview_stage_toggle"):
			shell._on_overview_stage_toggle()
		else:
			shell._overview_stage_mode = true
			shell._refresh()
		await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	shell._active_screen = "overview"
	shell._refresh()
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	_expect(await _wait_port_stage(shell, "总览页"), "总览页港口舞台可见（--station-shots 前置）")

	for entry in STATION_SCREENS:
		var screen_id := String(entry["screen"])
		var station_id := String(entry["station"])
		var file_name := String(entry["file"])
		shell._active_screen = screen_id
		shell._refresh()
		await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		var page_stage_visible := await _wait_port_stage(shell, "%s 页" % screen_id)
		_expect(page_stage_visible, "%s 页港口舞台可见" % screen_id)
		var settled := await _wait_station(shell, station_id, "%s 页" % screen_id)
		_expect(settled, "%s 页泊位 %s 过渡结束" % [screen_id, station_id])
		if page_stage_visible and settled:
			await _capture(_path(file_name))

	# 960×540：窗口缩放后重新等布局与站位，再补一张 market 泊位。
	shell._active_screen = "market"
	shell._refresh()
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	DisplayServer.window_set_size(STATION_SMALL_WINDOW)
	_window = STATION_SMALL_WINDOW
	await _wait_window_size(STATION_SMALL_WINDOW)
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	var small_stage_visible := await _wait_port_stage(shell, "market 页 960×540")
	_expect(small_stage_visible, "960×540 market 页港口舞台可见")
	var small_settled := await _wait_station(shell, "market", "market 页 960×540")
	_expect(small_settled, "960×540 market 页泊位 market 过渡结束")
	if small_stage_visible and small_settled:
		await _capture(_path("market_station_960.png"))


## 轮询 shell 的 PortStage 宿主：已挂载场景且可见即为就绪。宿主由主界面在进入
## 舞台模式时惰性创建，轮询期间一旦出现就继续等它可见。
func _wait_port_stage(shell: Control, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(STATION_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var host: SNStageHost = shell._port_stage_host
		if host != null and is_instance_valid(host) and host.has_stage() and host.is_stage_visible():
			return true
		await process_frame
	print("[FAIL] %s：港口舞台宿主在 %.0f 秒内不可见" % [label, STATION_TIMEOUT_SECONDS])
	return false


## 轮询站位：`current_station()` 等于目标 id 且 `is_station_transitioning()` 为
## false 才算就位。缺少站位 API 时立即失败并说明是 Lead 改动尚未落地。
func _wait_station(shell: Control, station_id: String, label: String) -> bool:
	var host: SNStageHost = shell._port_stage_host
	var stage: Variant = host.current_stage() if host != null and is_instance_valid(host) else null
	if stage == null:
		print("[FAIL] %s：PortStage 未挂载，无法等待泊位 %s" % [label, station_id])
		return false
	if not stage.has_method("is_station_transitioning"):
		print("[FAIL] %s：PortStage 尚未提供站位 API（is_station_transitioning）——等待 Lead 的连续港区改动" % label)
		return false
	var deadline := Time.get_ticks_msec() + int(STATION_TIMEOUT_SECONDS * 1000.0)
	var current := "?"
	while Time.get_ticks_msec() < deadline:
		host = shell._port_stage_host
		stage = host.current_stage() if host != null and is_instance_valid(host) else null
		if stage != null and stage.has_method("is_station_transitioning"):
			current = String(stage.current_station()) if stage.has_method("current_station") else "?"
			if not bool(stage.is_station_transitioning()) and current == station_id:
				print("[PASS] %s：泊位 %s 已就位" % [label, station_id])
				return true
		await process_frame
	print("[FAIL] %s：泊位 %s 在 %.0f 秒内未就位（current_station=%s）" % [
		label, station_id, STATION_TIMEOUT_SECONDS, current,
	])
	return false


## 窗口 resize 是异步的（DisplayServer → Window → Viewport），这里等 root.size
## 真的匹配后再让布局稳定一轮。
func _wait_window_size(size: Vector2i) -> void:
	for i in 180:
		if absi(root.size.x - size.x) <= 2 and absi(root.size.y - size.y) <= 2:
			break
		await process_frame
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)


## 与 framework/tests/test_case.gd 的 bootstrap_core 逐项一致。
func _bootstrap_core() -> Dictionary:
	var config := {
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://ui_snapshot_saves/%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()],
	}
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


## 进入改装态：优先点页面自己的改装按钮，其次调用页面的切枪方法，
## 最后按按钮文案（「改装」/Refit）兜底，保证页面小改版后工具仍可用。
func _enter_refit(shell: Control, screen: Control) -> bool:
	var button: Variant = screen.get("_refit_button")
	if button is Button and (button as Button).is_visible_in_tree():
		(button as Button).emit_signal("pressed")
		return true
	if screen.has_method("_on_toggle_refit"):
		screen._on_toggle_refit()
		return true
	var refit_key: String = String(shell._tr("ui.label.refit", ""))
	for candidate in _buttons(shell._root_box):
		var text := String(candidate.text)
		if (not refit_key.is_empty() and text == refit_key) or text.contains("改装") or text.to_lower().contains("refit"):
			candidate.emit_signal("pressed")
			return true
	return false


## 分类操作面板是否真的渲染出来了（中间列有对应标题 / 杂项有在港等待）。
func _is_visible_category(shell: Control, screen: Control, category: String) -> bool:
	if screen.get("_body") == null:
		return false
	var texts := _labels(screen)
	if category == "misc":
		var wait_text: String = String(shell._tr("ui.button.wait", ""))
		return texts.has(wait_text) or texts.has("在港等待")
	var title: String = String(shell._tr("ui.category.%s" % category, ""))
	return title.is_empty() or texts.has(title)


## 截图文件名用的分类短名。
func _category_short(category: String) -> String:
	# C1 categories (hulls/boiler/cargo/utility/cabin/misc) are already the short names.
	return category


func _labels(root: Node, out: Array = []) -> Array:
	for child in root.get_children():
		if child is Label:
			out.append(String((child as Label).text))
		_labels(child, out)
	return out


func _buttons(from: Node, out: Array[Button] = []) -> Array[Button]:
	for child in from.get_children():
		if child is Button:
			out.append(child)
		_buttons(child, out)
	return out


## First button (depth-first) whose text matches exactly.
func _button_with_text(from: Node, text: String) -> Button:
	for button in _buttons(from):
		if String(button.text) == text:
			return button
	return null


func _find_shipyard(shell: Control) -> Control:
	var found := _node_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	if found == null:
		# _root_box 引用可能还没绑定（极端时序），退回整棵树查找。
		found = _node_with_script(shell, SHIPYARD_SCREEN_SCRIPT)
	return found


func _node_with_script(from: Node, script: Script) -> Control:
	for child in from.get_children():
		if child.get_script() == script:
			return child
		var found := _node_with_script(child, script)
		if found != null:
			return found
	return null


## 等待若干帧 + 一小段真实时间（窗口模式帧率由显示器决定，不能只数帧）。
func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	await create_timer(seconds).timeout
	for i in 2:
		await process_frame


## 改装态画在 3D 港区舞台的船厂站位上：等镜头平移与玩家船靠泊结束再截图，
## 否则截到的是过渡中的半张画面。舞台没显示或没有站位 API 时立即返回。
func _wait_port_stage_settled(shell: Control) -> void:
	var host: Variant = shell.get("_port_stage_host")
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if host == null or not is_instance_valid(host) or not bool(host.is_stage_visible()):
			return
		var stage: Node = host.current_stage() if host.has_method("current_stage") else null
		if stage == null or not stage.has_method("is_station_transitioning"):
			return
		if not bool(stage.is_station_transitioning()):
			return
		await process_frame


## 抓 root（即主 Window 视口）的当前渲染结果并存 PNG。
func _capture(path_value: String) -> void:
	# get_texture().get_image() 只在绘制完成后有效。
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_expect(false, "视口纹理为空：%s" % path_value)
		return
	_expect(image.get_width() == _window.x and image.get_height() == _window.y,
		"截图尺寸 %dx%d 与窗口一致（%s）" % [image.get_width(), image.get_height(), path_value])
	if _is_flat(image):
		_expect(false, "截图是纯色空画面（没有渲染出 UI）：%s" % path_value)
		return
	var absolute := _global_path(path_value)
	var dir := absolute.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(dir)
	if dir_error != OK and not DirAccess.dir_exists_absolute(dir):
		_expect(false, "创建目录失败 %s（error=%d）" % [dir, dir_error])
		return
	var error := image.save_png(absolute)
	if error != OK:
		_expect(false, "保存 PNG 失败 %s（error=%d）" % [absolute, error])
		return
	_saved.append(absolute)
	print("[PASS] 已保存 %s（%dx%d，%d 字节）" % [
		absolute, image.get_width(), image.get_height(),
		FileAccess.get_file_as_bytes(absolute).size(),
	])


## 纯色/近纯色画面说明读到了未绘制的纹理。
func _is_flat(image: Image) -> bool:
	var colors := {}
	var step_x := maxi(1, image.get_width() / 24)
	var step_y := maxi(1, image.get_height() / 15)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			colors[image.get_pixel(x, y).to_rgba32()] = true
			if colors.size() > 8:
				return false
	return true


func _window_matches() -> bool:
	var size := root.size
	return absi(size.x - _window.x) <= 2 and absi(size.y - _window.y) <= 2


func _path(file_name: String) -> String:
	return _out_dir.path_join(file_name)


func _global_path(path_value: String) -> String:
	if path_value.begins_with("res://") or path_value.begins_with("user://"):
		return ProjectSettings.globalize_path(path_value)
	return path_value


func _teardown(shell: Control) -> void:
	if shell != null:
		if shell.get_parent() != null:
			shell.get_parent().remove_child(shell)
		shell.free()
	# 清掉静态注册表 / AppContext.active，尽量让退出码干净。
	FrameworkRuntime.shutdown()
	await process_frame


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("--seed="):
			_seed = int(text.get_slice("=", 1))
		elif text.begins_with("--out-dir="):
			_out_dir = text.get_slice("=", 1)
		elif text.begins_with("--window="):
			var parts := text.get_slice("=", 1).split("x")
			if parts.size() == 2:
				_window = Vector2i(int(parts[0]), int(parts[1]))
		elif text.begins_with("--category="):
			_categories.clear()
			for part in text.get_slice("=", 1).split(",", false):
				var category := String(part).strip_edges()
				if not category.is_empty():
					_categories.append(category)
		elif text.begins_with("--tabs="):
			_tabs.clear()
			for part in text.get_slice("=", 1).split(",", false):
				var tab := String(part).strip_edges()
				if not tab.is_empty():
					_tabs.append(tab)
		elif text == "--skip-refit":
			_skip_refit = true
		elif text == "--overview-stage":
			_overview_stage = true
		elif text == "--overview-detail":
			_overview_detail = true
			_overview_stage = true
		elif text == "--station-shots":
			_station_shots = true
		elif text == "--all-screens":
			_all_screens = true
		elif text.begins_with("--screens="):
			_screens.clear()
			for part in text.get_slice("=", 1).split(",", false):
				var screen_id := String(part).strip_edges()
				if not screen_id.is_empty():
					_screens.append(screen_id)
		elif text.begins_with("--damage="):
			for part in text.get_slice("=", 1).split(",", false):
				var pieces := String(part).strip_edges().split(":", false)
				if pieces.is_empty() or String(pieces[0]).strip_edges().is_empty():
					continue
				var target := {
					"slot": String(pieces[0]).strip_edges(),
					"index": 0,
					"ratio": 0.5,
				}
				if pieces.size() == 2:
					if String(pieces[1]).contains("."):
						target["ratio"] = float(pieces[1])
					else:
						target["index"] = int(pieces[1])
				elif pieces.size() >= 3:
					target["index"] = int(pieces[1])
					target["ratio"] = float(pieces[2])
				_damage_targets.append(target)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] " + message)
	else:
		_failures.append(message)
		print("[FAIL] " + message)


func _finish() -> void:
	if _saved.is_empty():
		print("=== 结果：失败 %d 项，未产出截图 ===" % _failures.size())
		quit(1)
		return
	print("[INFO] 截图：")
	for path_value in _saved:
		print("  - " + path_value)
	if _failures.is_empty():
		print("=== 结果：通过（%d 张截图）===" % _saved.size())
		quit(0)
	else:
		print("=== 结果：失败 %d 项 ===" % _failures.size())
		for failure in _failures:
			print("  ! " + failure)
		quit(1)


## ---------------------------------------------------------------------------
## 全页面皮肤截图（--all-screens / --screens=）
## ---------------------------------------------------------------------------

## 页面 id → 该页脚本（用于确认页面真的挂载了，而不是只截到空壳）。
const SKIN_SCREEN_SCRIPTS := {
	"overview": preload("res://framework/ui/screens/port/overview_screen.gd"),
	"market": preload("res://framework/ui/screens/port/market_screen.gd"),
	"contracts": preload("res://framework/ui/screens/port/contracts_screen.gd"),
	"tavern": preload("res://framework/ui/screens/port/tavern_screen.gd"),
	"base": preload("res://framework/ui/screens/port/base_screen.gd"),
	"auto_trade": preload("res://framework/ui/screens/port/auto_trade_screen.gd"),
	"ruins": preload("res://framework/ui/screens/port/ruins_screen.gd"),
	"sea_chart": preload("res://framework/ui/screens/flow/sea_chart_screen.gd"),
	"clue_log": preload("res://framework/ui/screens/flow/clue_log_screen.gd"),
	"event": preload("res://framework/ui/screens/flow/event_screen.gd"),
	"settlement": preload("res://framework/ui/screens/flow/settlement_screen.gd"),
	"victory": preload("res://framework/ui/screens/flow/victory_screen.gd"),
	"main_menu": preload("res://framework/ui/screens/menu/main_menu_screen.gd"),
	"new_game": preload("res://framework/ui/screens/menu/new_game_screen.gd"),
	"mods": preload("res://framework/ui/screens/menu/mods_screen.gd"),
	"settings": preload("res://framework/ui/screens/menu/settings_screen.gd"),
}
const AUTO_TRADE_SCREEN_ID := "trade"
const FULL_CLEAR_MEDIUM_HULL := "core:hull/medium_standard"
const FULL_CLEAR_LARGE_HULL := "core:hull/large_efficient"
const FULL_CLEAR_CABIN := "core:module/passenger_cabin"


func _skin_battery_enabled() -> bool:
	return _all_screens or not _screens.is_empty()


func _wants(screen_id: String) -> bool:
	if _skip_refit and screen_id in ["shipyard_refit", "shipyard_buy", "shipyard_craft", "shipyard_misc"]:
		return false
	return _all_screens or _screens.has(screen_id)


func _requested_skin_screens() -> Array[String]:
	var ids: Array[String] = []
	for screen_id in SKIN_ALL_SCREENS:
		if _wants(String(screen_id)):
			ids.append(String(screen_id))
	return ids


func _skin_filename(screen_id: String) -> String:
	return "%s.png" % screen_id


## 运行开始时打印每张期望截图的绝对路径；包装脚本据此判断"缺失 / 不新鲜"。
func _announce_skin_expectations() -> void:
	for screen_id in _screens:
		if not SKIN_ALL_SCREENS.has(screen_id):
			_expect(false, "未知截图页 id：%s" % screen_id)
	var ids := _requested_skin_screens()
	for screen_id in ids:
		print("[EXPECT] " + _global_path(_path(_skin_filename(screen_id))))
	print("[INFO] 期望截图 %d 张 → %s" % [ids.size(), _out_dir])


func _capture_skin_battery(shell: Control, context: AppContext) -> void:
	print("=== 全页面皮肤截图（%dx%d，%d 张）===" % [_window.x, _window.y, _requested_skin_screens().size()])
	await _capture_skin_port_pages(shell, context)
	if _wants("ui_kit"):
		await _capture_skin_ui_kit()
	if _wants("at_sea") or _wants("event") or _wants("settlement"):
		await _capture_skin_flow_pages(shell, context)
	if _wants("victory"):
		await _capture_skin_victory(shell, context)
	if _wants("main_menu") or _wants("new_game") or _wants("mods") or _wants("settings"):
		await _capture_skin_menus(shell, context)


## 切页并等待布局稳定（走 shell 的真实导航状态，不直接替换页面节点）。
func _goto_screen(shell: Control, screen_id: String) -> void:
	shell._active_screen = screen_id
	shell._refresh()
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)


func _capture_skin(screen_id: String) -> void:
	print("[SHOT] %s" % screen_id)
	await _capture(_path(_skin_filename(screen_id)))


func _screen_mounted(shell: Control, screen_id: String) -> bool:
	if not SKIN_SCREEN_SCRIPTS.has(screen_id):
		return false
	return _node_with_script(shell._root_box, SKIN_SCREEN_SCRIPTS[screen_id]) != null


## ---------------------------------------------------------------------------
## 阶段 1：港口 / 功能页
## ---------------------------------------------------------------------------

func _capture_skin_port_pages(shell: Control, context: AppContext) -> void:
	var any_port := false
	for screen_id in SKIN_PORT_SCREENS:
		if _wants(String(screen_id)):
			any_port = true
			break
	if not any_port:
		return
	print("[INFO] 港口 / 功能页")

	# 总览：3D 舞台、详细总览抽屉、2D 回退各一张。
	if _wants("overview") or _wants("overview_detail") or _wants("overview_2d"):
		await _goto_screen(shell, "overview")
		var stage_available := bool(shell._port_stage_available())
		if _wants("overview") or _wants("overview_detail"):
			_expect(stage_available, "3D 港口舞台场景可用（overview）")
			if not bool(shell._overview_stage_mode):
				shell._on_overview_stage_toggle()
				await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
			_expect(bool(shell._overview_stage_mode), "总览进入 3D 港口舞台模式")
			var stage_visible := await _wait_port_stage(shell, "总览页")
			_expect(stage_visible, "总览页 3D 港口舞台可见")
			if _wants("overview"):
				_expect(_screen_mounted(shell, "overview"), "总览页已挂载")
				await _capture_skin("overview")
			if _wants("overview_detail"):
				# 2026-10-28：抽屉移除后详细总览 = 2D 总览页；切过去截图再切回舞台。
				if bool(shell._overview_stage_mode):
					shell._on_overview_stage_toggle()
					await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
				_expect(not bool(shell._overview_stage_mode), "详细总览切到 2D 总览页")
				_expect(_screen_mounted(shell, "overview"), "2D 总览页已挂载")
				await _capture_skin("overview_detail")
				if stage_available:
					shell._on_overview_stage_toggle()
					await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		if _wants("overview_2d"):
			if bool(shell._overview_stage_mode):
				shell._on_overview_stage_toggle()
				await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
			_expect(not bool(shell._overview_stage_mode), "总览切到 2D 回退视图")
			var detail_back := _node_with_script(shell._root_box, OVERVIEW_SCREEN_SCRIPT)
			_expect(detail_back != null, "2D 总览页已挂载")
			await _capture_skin("overview_2d")
			if stage_available and not bool(shell._overview_stage_mode):
				shell._on_overview_stage_toggle()
				await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)

	# 市场 / 补给（4.5.3 起 supply 被重定向到 market，补给区块在 market 页内）。
	if _wants("market") or _wants("supply"):
		await _goto_screen(shell, "market")
		await _wait_port_stage(shell, "market 页")
		await _wait_station(shell, "market", "market 页")
		if _wants("market"):
			_expect(_screen_mounted(shell, "market"), "市场页已挂载")
			await _capture_skin("market")
		if _wants("supply"):
			await _goto_screen(shell, "supply")
			_expect(String(shell._active_screen) == "market", "supply 导航按 4.5.3 重定向到 market")
			await _wait_port_stage(shell, "supply→market 页")
			await _wait_station(shell, "market", "supply→market 页")
			var supply_block: Node = shell._root_box.find_child("MarketSupply", true, false)
			if supply_block == null:
				_expect(false, "supply：market 页里找不到补给区块 MarketSupply")
			else:
				var page_scroll := shell.get_node_or_null("PageMargin/PageScroll") as ScrollContainer
				if page_scroll != null:
					page_scroll.ensure_control_visible(supply_block)
				await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
				print("[INFO] supply：页已合并进 market，截图为页面滚动到补给区块后的真实状态")
				await _capture_skin("supply")

	# 其余功能页：market 之外的 port 页 + 海图 / 线索。
	for screen_id in ["contracts", "tavern", "base", "auto_trade", "ruins", "sea_chart", "clue_log"]:
		if not _wants(screen_id):
			continue
		var target: String = AUTO_TRADE_SCREEN_ID if screen_id == "auto_trade" else String(screen_id)
		if screen_id == "clue_log" and ClueService.active(context.state).is_empty():
			# 用真实 clue.buy 命令先拿一条线索，否则线索页只有空态。
			shell._run_command(&"clue.buy", {})
			await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS * 0.5)
		await _goto_screen(shell, target)
		_expect(_screen_mounted(shell, screen_id), "%s 页已挂载" % screen_id)
		await _capture_skin(screen_id)

	# 船厂：正常态 + 改装态（默认装配页签）+ 购买 / 打造 / 杂项。
	if _wants("shipyard_normal") or _wants("shipyard_refit") or _wants("shipyard_buy") \
			or _wants("shipyard_craft") or _wants("shipyard_misc"):
		await _goto_screen(shell, "shipyard")
		var screen := _find_shipyard(shell)
		_expect(screen != null, "船厂页已挂载")
		if screen == null:
			return
		if _wants("shipyard_normal"):
			await _capture_skin("shipyard_normal")
		if _wants("shipyard_refit") or _wants("shipyard_buy") or _wants("shipyard_craft") or _wants("shipyard_misc"):
			var pressed := _enter_refit(shell, screen)
			_expect(pressed, "找到并点击了「改装」按钮")
			await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
			await _wait_port_stage_settled(shell)
			_expect(bool(screen.get("_refit")), "船厂页进入改装态")
			if _wants("shipyard_refit"):
				await _capture_skin("shipyard_refit")
			for tab in ["buy", "craft"]:
				if not _wants("shipyard_%s" % tab):
					continue
				screen.set_tab(tab)
				await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
				_expect(String(screen.get("_tab")) == tab, "改装页签切换到 %s" % tab)
				await _capture_skin("shipyard_%s" % tab)
			if _wants("shipyard_misc"):
				screen.set_tab("install")
				screen.set_category("misc")
				await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
				_expect(String(screen.get("_category")) == "misc", "改装分类切换到 misc")
				await _capture_skin("shipyard_misc")


## ---------------------------------------------------------------------------
## 阶段 2：UI Kit 展示页
## ---------------------------------------------------------------------------

func _capture_skin_ui_kit() -> void:
	print("[INFO] UI Kit 展示页")
	var scene := load(UI_KIT_SCENE) as PackedScene
	_expect(scene != null, "UI Kit 展示场景可加载：%s" % UI_KIT_SCENE)
	if scene == null:
		return
	var kit: Control = scene.instantiate()
	root.add_child(kit)
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	await _capture_skin("ui_kit")
	if kit.get_parent() != null:
		kit.get_parent().remove_child(kit)
	kit.free()
	await _settle(4, 0.1)


## ---------------------------------------------------------------------------
## 阶段 3：航行流程页（at_sea / event / settlement）
## ---------------------------------------------------------------------------

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


## 与 test_voyage_flow._force_event_context 相同：在 1..N 里找一个会触发事件的确定性
## seed，并在返回前把 context.rng 复位到该 seed，让紧随其后的 voyage.start 抽到同一事件。
func _force_event_context(context: AppContext, destination: String) -> Dictionary:
	var preview := context.commands.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	if not bool(preview.get("ok", false)):
		return {}
	var preview_data: Dictionary = preview.get("data", {})
	for seed_value in range(1, EVENT_SEED_SEARCH):
		context.rng = RngService.new(seed_value)
		var picked := VoyageService._pick_event(context, preview_data, destination)
		if picked.is_empty():
			continue
		context.rng = RngService.new(seed_value)
		return picked
	return {}


func _safe_event_option(offered: Array) -> String:
	var preferred := ["decline", "stop_repair", "water_cooling", "force_continue", "jettison_cargo", "paid_repair", "buy_intel"]
	for option_id in preferred:
		if offered.has(option_id):
			return String(option_id)
	return String(offered[0]) if not offered.is_empty() else ""


## 推进 shell 的 VoyagePresentation 状态机（与 test_voyage_flow 的 _drive_until 同法），
## 不依赖真实等待，截图前再统一 settle 让布局与渲染追上。
func _drive_shell_until(shell: Control, predicate: Callable, max_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < max_seconds:
		if bool(predicate.call()):
			return true
		shell._process(FLOW_DRIVE_STEP)
		elapsed += FLOW_DRIVE_STEP
	return bool(predicate.call())


func _capture_skin_flow_pages(shell: Control, context: AppContext) -> void:
	print("[INFO] 航行流程页：at_sea / event / settlement")
	_bot_ensure_liquidity(context, 300)
	var destination := _first_destination(context)
	_expect(not destination.is_empty(), "找到出航目的地（主线委托 / 相邻港口）")
	if destination.is_empty():
		return
	# 先备货（真实 supply 命令），再采样事件 seed，最后立刻 voyage.start，rng 不被别的
	# 命令消耗，保证抽到的事件与采样一致。
	_bot_prepare_voyage(context, destination)
	var forced := _force_event_context(context, destination)
	if forced.is_empty():
		print("[WARN] 该目的地没有采样到风险事件；event 页按实际航程结果取证")
	shell._run_command(&"voyage.start", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})
	_expect(shell._presentation != null, "voyage.start 交接到航行演出")
	if shell._presentation == null:
		return
	var reached_at_sea := _drive_shell_until(shell, func() -> bool: return shell._at_sea_screen != null, FLOW_DRIVE_MAX_SECONDS)
	_expect(reached_at_sea, "演出推进到海图航行页")
	if reached_at_sea:
		_drive_shell_until(shell, func() -> bool: return float(shell._presentation.veil) <= 0.001, 20.0)
		await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		if _wants("at_sea"):
			await _capture_skin("at_sea")

	var has_event := bool(shell._presentation.has_event)
	var reached_event := false
	if has_event:
		# 无论是否要截 event 页，都必须把演出开到决策点并作出选择，否则剩余航段
		# 永远停在 event_wait，结算页也到不了（-Screens at_sea 子集运行曾因此失败）。
		reached_event = _drive_shell_until(shell, func() -> bool:
			return shell._presentation != null and String(shell._presentation.phase_name()) == "event_wait",
			FLOW_DRIVE_MAX_SECONDS)
		_expect(reached_event, "演出停在事件决策点")
		if reached_event and _wants("event"):
			await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
			_expect(_node_with_script(shell._root_box, EVENT_SCREEN_SCRIPT) != null, "事件页已挂载")
			await _capture_skin("event")
	elif _wants("event"):
		_expect(false, "event：本次航程没有触发风险事件，事件页无法稳定进入")

	# 处理事件（若有）并让剩余航段播完，抵达结算页。
	if reached_event:
		var offered: Array = forced.get("option_ids", []) if not forced.is_empty() else []
		if offered.is_empty():
			var voyage: Variant = context.state.data.get("voyage", null)
			if voyage is Dictionary and (voyage as Dictionary).get("event", null) is Dictionary:
				offered = ((voyage as Dictionary)["event"] as Dictionary).get("option_ids", [])
		var option_id := _safe_event_option(offered)
		_expect(not option_id.is_empty(), "事件提供了可处理的选项")
		if not option_id.is_empty():
			shell._run_command(&"event.choose_option", {"option_id": option_id})
			await _settle(4, 0.05)
	var finished := _drive_shell_until(shell, func() -> bool: return shell._presentation == null, FLOW_DRIVE_MAX_SECONDS)
	_expect(finished, "航行演出结束")
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	_expect(String(shell._active_screen) == "settlement", "抵达后进入结算页")
	if String(shell._active_screen) == "settlement" and _wants("settlement"):
		_expect(_screen_mounted(shell, "settlement"), "结算页已挂载")
		await _capture_skin("settlement")


## ---------------------------------------------------------------------------
## 阶段 4：通关页（真实 CommandBus 脚本通关，与 test_full_clear 同一路径）
## ---------------------------------------------------------------------------

func _capture_skin_victory(shell: Control, context: AppContext) -> void:
	print("[INFO] 通关页：脚本化真实通关（主线 5 章 + 大型船体）")
	# 独立重开一局，避免航行流程页的损耗影响通关脚本；仍然全程走公开 CommandBus。
	context.reset_state()
	var started: Dictionary = context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": _seed,
	})
	_expect(bool(started.get("ok", false)), "通关脚本 run.start 成功：%s" % str(started))
	if not bool(started.get("ok", false)):
		return
	var cleared := _play_to_victory(context)
	_expect(cleared, "脚本化通关成功（victory.view.achieved）")
	if not cleared:
		return
	shell._victory_dismissed = false
	shell._refresh()
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	_expect(_screen_mounted(shell, "victory"), "胜利页已挂载")
	await _capture_skin("victory")


func _play_to_victory(context: AppContext) -> bool:
	# 第 1-3 章只用主线委托攒第一次升级资金。
	for sequence in [1, 2, 3]:
		if not _bot_complete_main_step(context, sequence):
			return false
	var unlocks: Array = context.state.player().get("unlocks", [])
	if not unlocks.has(FULL_CLEAR_MEDIUM_HULL):
		print("[WARN] 主线 3 未解锁中型船体（unlocks=%s）" % str(unlocks))
	_bot_navigate_to_facility(context, "shipyard")
	if not _bot_earn_until(context, 2150):
		return false
	if not _bot_install(context, FULL_CLEAR_MEDIUM_HULL):
		return false
	_bot_ensure_liquidity(context, 500)
	if not _bot_install(context, FULL_CLEAR_CABIN):
		return false
	for sequence in [4, 5]:
		if not _bot_complete_main_step(context, sequence):
			return false
	_bot_navigate_to_facility(context, "shipyard")
	if not _bot_earn_until(context, 3000):
		return false
	_bot_navigate_to_facility(context, "shipyard")
	if not _bot_install(context, FULL_CLEAR_LARGE_HULL):
		return false
	var victory: Variant = context.state.data.get("victory", null)
	return victory is Dictionary and bool((victory as Dictionary).get("achieved", false))


func _bot_complete_main_step(context: AppContext, expected_sequence: int) -> bool:
	_bot_accept_main_offer_if_needed(context)
	var contracts: Dictionary = context.state.contracts()
	var main: Variant = contracts.get("main", null)
	if not (main is Dictionary):
		_expect(false, "通关脚本：主线第 %d 章未接取" % expected_sequence)
		return false
	var destination := String((main as Dictionary).get("destination", ""))
	if context.state.current_port_id() == destination:
		var neighbors := MapOps.neighbors(context.state.world(), destination)
		if neighbors.is_empty():
			_expect(false, "通关脚本：目的港没有出港航线")
			return false
		if not _bot_sail(context, String(neighbors[0])):
			return false
	if not _bot_navigate_to(context, destination):
		return false
	var settled: Variant = context.state.contracts().get("main", null)
	if settled != null:
		_expect(false, "通关脚本：主线第 %d 章未在抵达时结算" % expected_sequence)
		return false
	return true


func _bot_accept_main_offer_if_needed(context: AppContext) -> void:
	var contracts: Dictionary = context.state.contracts()
	if contracts.get("main", null) is Dictionary:
		return
	var offer: Variant = contracts.get("main_offer", null)
	if not (offer is Dictionary):
		return
	context.commands.execute(&"contract.accept", {"instance_id": String((offer as Dictionary).get("instance_id", ""))})


func _bot_earn_until(context: AppContext, target_money: int) -> bool:
	var guard := 0
	while context.state.money() < target_money and guard < 12:
		guard += 1
		_bot_ensure_liquidity(context, target_money)
		if context.state.money() >= target_money:
			return true
		if not _bot_complete_one_normal_contract(context):
			_bot_ensure_liquidity(context, target_money)
			if context.state.money() >= target_money:
				return true
	if context.state.money() < target_money:
		_expect(false, "通关脚本：资金未达到 %d（当前 %d）" % [target_money, context.state.money()])
		return false
	return true


func _bot_ensure_liquidity(context: AppContext, floor: int = 700) -> void:
	if context.state.money() >= floor:
		return
	if context.state.player().get("debt", null) == null:
		context.commands.execute(&"debt.borrow", {"amount": 400})
		return
	_bot_complete_one_normal_contract(context)


func _bot_complete_one_normal_contract(context: AppContext) -> bool:
	var offers: Array = context.state.contracts().get("offers", [])
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var accept: Dictionary = context.commands.execute(&"contract.accept", {
			"instance_id": String((offer as Dictionary).get("instance_id", "")),
		})
		if not bool(accept.get("ok", false)):
			continue
		var destination := String((offer as Dictionary).get("destination", ""))
		if _bot_navigate_to(context, destination):
			return true
	return false


func _bot_navigate_to_facility(context: AppContext, facility: String) -> void:
	var state: GameState = context.state
	if MapOps.has_facility(MapOps.port(state.world(), state.current_port_id()), facility):
		return
	for port_id in state.world().get("ports", {}).keys():
		if MapOps.has_facility(MapOps.port(state.world(), String(port_id)), facility):
			_bot_navigate_to(context, String(port_id))
			return
	_expect(false, "通关脚本：地图上没有 %s 设施" % facility)


func _bot_navigate_to(context: AppContext, target_port: String) -> bool:
	var guard := 0
	while context.state.current_port_id() != target_port and guard < 10:
		guard += 1
		var path := _bot_path_to(context.state.world(), context.state.current_port_id(), target_port)
		if path.size() < 2:
			_expect(false, "通关脚本：到 %s 没有航线" % target_port)
			return false
		if not _bot_sail(context, path[1]):
			return false
	return context.state.current_port_id() == target_port


func _bot_path_to(world: Dictionary, from_port: String, to_port: String) -> Array[String]:
	var result: Array[String] = []
	if from_port == to_port:
		result.append(from_port)
		return result
	var previous := {from_port: ""}
	var queue: Array[String] = [from_port]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for neighbor in MapOps.neighbors(world, current):
			var neighbor_id := String(neighbor)
			if previous.has(neighbor_id):
				continue
			previous[neighbor_id] = current
			if neighbor_id == to_port:
				var cursor := to_port
				var reversed: Array[String] = []
				while cursor != from_port:
					reversed.append(cursor)
					cursor = String(previous[cursor])
				reversed.append(from_port)
				reversed.reverse()
				result.assign(reversed)
				return result
			queue.append(neighbor_id)
	return result


func _bot_sail(context: AppContext, destination: String) -> bool:
	if context.state.money() < 250 and context.state.player().get("debt", null) == null:
		context.commands.execute(&"debt.borrow", {"amount": 400})
	_bot_prepare_voyage(context, destination)
	var voyage: Dictionary = context.commands.execute(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	if not bool(voyage.get("ok", false)):
		_expect(false, "通关脚本：出航 %s 失败：%s" % [destination, str(voyage)])
		return false
	if not bool((voyage.get("data", {}) as Dictionary).get("arrived", false)):
		if not _bot_resolve_event(context):
			return false
	if context.state.current_port_id() != destination:
		_expect(false, "通关脚本：未抵达 %s" % destination)
		return false
	return true


func _bot_resolve_event(context: AppContext) -> bool:
	var voyage: Variant = context.state.data.get("voyage", null)
	if not (voyage is Dictionary):
		_expect(false, "通关脚本：事件航程缺少 voyage 记录")
		return false
	var event: Variant = (voyage as Dictionary).get("event", null)
	if not (event is Dictionary):
		_expect(false, "通关脚本：事件航程缺少 event 数据")
		return false
	var offered: Array = (event as Dictionary).get("option_ids", [])
	var order := _safe_event_option(offered)
	if order.is_empty():
		_expect(false, "通关脚本：事件没有可用选项")
		return false
	var chosen: Dictionary = context.commands.execute(&"event.choose_option", {"option_id": order})
	return bool(chosen.get("ok", false)) and not bool((chosen.get("data", {}) as Dictionary).get("failed", false))


func _bot_prepare_voyage(context: AppContext, destination: String) -> void:
	var preview: Dictionary = context.commands.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	if not bool(preview.get("ok", false)):
		return
	var p: Dictionary = preview.get("data", {})
	_bot_buy_supply(context, "coal", float(p.get("coal_required", 0.0)) + 4.0)
	_bot_buy_supply(context, "water", float(p.get("water_required", 0.0)) + 4.0)
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


func _bot_install(context: AppContext, module_id: String) -> bool:
	var result: Dictionary = context.commands.execute(&"ship.install_module", {"module_id": module_id})
	_expect(bool(result.get("ok", false)), "通关脚本：安装 %s：%s" % [module_id, str(result)])
	return bool(result.get("ok", false))


## ---------------------------------------------------------------------------
## 阶段 5：菜单页（真实 reset_state + shell 菜单切换）
## ---------------------------------------------------------------------------

func _capture_skin_menus(shell: Control, context: AppContext) -> void:
	print("[INFO] 菜单页：main_menu / new_game / mods / settings")
	context.reset_state()
	shell._victory_dismissed = false
	shell._settlement_summary = {}
	shell._menu_screen = "main"
	shell._active_screen = "overview"
	shell._refresh()
	await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
	_expect(_screen_mounted(shell, "main_menu"), "主菜单已挂载")
	if _wants("main_menu"):
		await _capture_skin("main_menu")
	for pair in [["new_game", "new_game"], ["mods", "mods"], ["settings", "settings"]]:
		var menu_id := String(pair[0])
		if not _wants(menu_id):
			continue
		shell._menu_screen = menu_id
		shell._refresh()
		await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		_expect(_screen_mounted(shell, menu_id), "%s 菜单页已挂载" % menu_id)
		await _capture_skin(menu_id)
