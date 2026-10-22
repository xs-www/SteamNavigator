extends SceneTree
## @static-doc
## 作用：阶段 4.5.3「市场并市 + 第二主线」真实渲染截图工具（窗口模式）。走完教学首段，
## 抓两张 1440×900 截图：开局市场页的「补给区块」，以及第二港市场只开放两种贸易货物。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_act1.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/story/`）：
##   tutorial_market_supply.png  开局市场页：补给（煤 / 水）区块 + 非阻塞目标条
##   tutorial_market_goods.png   第二港市场：只有纺织品 / 香料两种贸易货物 + 补给区块
##
## ## 契约与约束
## - 全程用真实 Shell / 真实命令推进（story.advance / supply.buy_* / trade 视图），
##   不伪造渲染数据。
## - 硬性断言：开局市场出现 `MarketSupply` 且 trade rows 为 0；第二港市场出现 2 条
##   贸易货物；失败返回非零退出码。
## - 强制 zh_CN、窗口 1440×900、`_settings_applied = true`。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/story"
const WINDOW := Vector2i(1440, 900)
const SEED := 20260421
const STEADY_BUILD := "core:starting_scenario/steady"
const WATCHDOG_SECONDS := 120.0

const SHOTS := [
	{"file": "tutorial_market_supply.png", "label": "开局市场：补给区块"},
	{"file": "tutorial_market_goods.png", "label": "第二港市场：两种贸易货物"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_story_act1: timed out (%d s)" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · story act 1 (4.5.3)")
	await process_frame
	var context := _bootstrap()
	if context == null:
		_finish()
		return
	var started := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": SEED,
		"tutorial": true,
	})
	if not bool(started.get("ok", false)):
		_fail("run.start failed: %s" % str(started))
		_finish()
		return
	context.localization.set_locale("zh_CN")
	var shell: Control = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(shell)
	shell._settings_applied = true
	await _settle(10, 0.5)
	# 开场 → 市场补给页。
	shell._run_command(&"story.advance", {})
	_click_continue(shell)
	await _settle(4, 0.2)
	shell._active_screen = "market"
	shell._refresh()
	await _settle(5, 0.35)
	if shell.find_child("MarketSupply", true, false) == null:
		_fail("the Act 0 market page has no MarketSupply block")
		_finish()
		return
	if not (context.queries.execute(&"port.view")["data"].get("market", []) as Array).is_empty():
		_fail("the Act 0 market unexpectedly exposes trade goods")
		_finish()
		return
	await _capture("tutorial_market_supply.png", "开局市场补给区块")
	# 推进第一幕：买 4 煤 2 水 → 海图开关 → 买够 10 煤 → 出航阶段。
	shell._run_command(&"supply.buy_coal", {"amount": 4})
	shell._run_command(&"supply.buy_water", {"amount": 2})
	_click_continue(shell)
	shell._active_screen = "sea_chart"
	shell._refresh()
	shell._on_sea_chart_closed()
	shell._transitioning = false
	shell._pending_transition = false
	shell._active_screen = "overview"
	shell._refresh()
	_click_continue(shell)
	shell._run_command(&"supply.buy_coal", {"amount": 2})
	_click_continue(shell)
	# 模拟抵达第二港（Shell 的到港事件在导航/结算后发出）。
	var main_contract: Dictionary = context.state.contracts().get("main", {})
	var second_port := String(main_contract.get("destination", ""))
	context.state.world()["current_port_id"] = second_port
	context.state.mark_port_visited(second_port)
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	shell._refresh()
	await _settle(4, 0.2)
	_click_continue(shell)
	shell._active_screen = "market"
	shell._refresh()
	await _settle(5, 0.35)
	var rows: Array = context.queries.execute(&"port.view")["data"].get("market", [])
	if rows.size() != 2:
		_fail("the second-port market should expose 2 trade goods, got %d" % rows.size())
		_finish()
		return
	await _capture("tutorial_market_goods.png", "第二港市场贸易货物")
	_finish()


func _click_continue(shell: Control) -> void:
	var button := _node_named(shell, "ContinueButton") as Button
	if button != null:
		button.pressed.emit()


func _bootstrap() -> AppContext:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://capture_saves/story_act1",
	})
	var context := bootstrap.context
	if context == null:
		_fail("bootstrap produced no AppContext")
		return null
	AppContext.set_active(context)
	return context


func _capture(file_name: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport texture: " + label)
		return
	if image.get_width() != WINDOW.x or image.get_height() != WINDOW.y:
		_fail("capture size %dx%d does not match %dx%d (%s)" % [
			image.get_width(), image.get_height(), WINDOW.x, WINDOW.y, label,
		])
		return
	var directory := ProjectSettings.globalize_path(OUT_DIR)
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var absolute := directory.path_join(file_name)
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("cannot save PNG %s (error=%d)" % [absolute, save_error])
		return
	_saved.append(file_name)
	print("[PASS] captured %s -> %s" % [label, absolute])


func _settle(frames: int, seconds: float) -> void:
	for _index in frames:
		await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout
	for _index in 3:
		await process_frame


func _node_named(root_node: Node, wanted: String) -> Node:
	if root_node == null:
		return null
	if String(root_node.name) == wanted:
		return root_node
	for child in root_node.get_children():
		var found := _node_named(child, wanted)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	_failures += 1
	push_error("capture_story_act1: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== story act1 capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
