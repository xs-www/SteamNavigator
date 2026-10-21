extends SceneTree
## @static-doc
## 作用：阶段 4.5.4「酒馆 / 线索 / 保底探索」真实渲染截图工具（窗口模式）。走完教学
## 第二幕，抓三张 1440×900 截图：酒馆页（物价情报 + 港口线索）、第三种货上架后的
## 起始港市场、以及第二条 L3 线索在海图上的搜索圈。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_act2.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/story/`）：
##   tutorial_tavern.png              酒馆：物价情报矩阵 + 港口线索列表
##   tutorial_market_third_good.png   起始港市场：纺织品 / 香料 / 木材三种货
##   tutorial_sea_chart_clue.png      海图：第二条 L3 线索的方向与搜索圈
##
## ## 契约与约束
## - 全程用真实 Shell / 真实命令推进（story.advance / trade / intel.refresh），
##   只把「抵达」事件按 Shell 的真实时序喂给 `story.observe`，不伪造渲染数据。
## - 硬性断言：酒馆页出现物价情报表与线索购买入口、活跃线索 = 1 且等级 1；
##   第三件货上架后市场 = 3 条贸易货物；第二条线索等级 3、带搜索圈。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/story"
const WINDOW := Vector2i(1440, 900)
const SEED := 20260421
const STEADY_BUILD := "core:starting_build/steady"
const WATCHDOG_SECONDS := 180.0

const SHOTS := [
	{"file": "tutorial_tavern.png", "label": "酒馆：物价情报与港口线索"},
	{"file": "tutorial_tavern_clues.png", "label": "酒馆：港口线索列表"},
	{"file": "tutorial_market_third_good.png", "label": "市场：第三种货"},
	{"file": "tutorial_clue_list.png", "label": "线索列表：L1 + L3 第二条线索"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_story_act2: timed out (%d s)" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · story act 2 (4.5.4)")
	await process_frame
	var context := _bootstrap()
	if context == null:
		_finish()
		return
	var started := context.commands.execute(&"run.start", {
		"build_id": STEADY_BUILD,
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
	await _walk_to_tavern(context, shell)
	# 酒馆开门卡 → 第二张说明卡（收下）→ 刷新物价情报（推进到第三种货）。
	_click_continue(shell)
	_click_continue(shell)
	await _settle(3, 0.2)
	shell._run_command(&"intel.refresh", {})
	_click_continue(shell)
	await _settle(3, 0.2)
	shell._active_screen = "tavern"
	shell._refresh()
	await _settle(6, 0.4)
	if shell.find_child("BuyClueButton", true, false) == null:
		_fail("the tavern page has no buy-clue entry")
	var clues := ClueService.active(context.state)
	if clues.size() != 1 or int(clues[0].get("level", 0)) != 1:
		_fail("the tavern should grant exactly one level-1 story clue, got %s" % str(clues))
	var tavern: Dictionary = context.queries.execute(&"tavern.view")["data"]
	if (tavern.get("clues", []) as Array).is_empty():
		_fail("the tavern view model carries no port clues")
	if not bool((tavern.get("intel", {}) as Dictionary).get("has_report", false)):
		_fail("the tavern page has no price-intel report after the refresh")
	await _capture("tutorial_tavern.png", "酒馆：物价情报与港口线索")
	# 酒馆下半部分的港口线索列表（滚动到底部）。
	var scroll := shell.get_node_or_null("PageMargin/PageScroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _settle(4, 0.25)
		await _capture("tutorial_tavern_clues.png", "酒馆：港口线索列表")
		scroll.scroll_vertical = 0
	# 第三种货上架后的市场（起始港现在双向交易纺织品 / 香料，并新增木材）。
	_click_continue(shell)
	await _settle(3, 0.2)
	shell._active_screen = "market"
	shell._refresh()
	await _settle(6, 0.4)
	var market_rows: Array = context.queries.execute(&"port.view")["data"].get("market", [])
	if market_rows.size() != 3:
		_fail("the home market should expose 3 trade goods after the unlock, got %d" % market_rows.size())
	await _capture("tutorial_market_third_good.png", "市场：第三种货")
	# 跑一个来回 → 第二条 L3 线索；打开线索列表确认两条线索的等级。
	context.commands.execute(&"story.observe", {"event": "cmd:voyage.start", "data": {}})
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	shell._refresh()
	_click_continue(shell)
	shell._refresh()
	_click_continue(shell)
	await _settle(3, 0.2)
	var all_clues := ClueService.active(context.state)
	if all_clues.size() != 2:
		_fail("the second story clue should be granted after the round trip, got %d" % all_clues.size())
	elif int(all_clues[1].get("level", 0)) != 3:
		_fail("the second story clue should be level 3, got %d" % int(all_clues[1].get("level", 0)))
	shell._active_screen = "clue_log"
	shell._refresh()
	await _settle(8, 0.5)
	await _capture("tutorial_clue_list.png", "线索列表：L1 + L3 第二条线索")
	_finish()


## 走完前两幕并停在 tavern_intro（酒馆页可用、酒馆已给第一条线索）。
func _walk_to_tavern(context: AppContext, shell: Control) -> void:
	_click_continue(shell)
	_click_continue(shell)
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
	# 第二港：抵达后购买 8 件纺织品。
	var main_contract: Dictionary = context.state.contracts().get("main", {})
	var second_port := String(main_contract.get("destination", ""))
	context.state.world()["current_port_id"] = second_port
	context.state.mark_port_visited(second_port)
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	shell._refresh()
	await _settle(3, 0.2)
	_click_continue(shell)
	shell._run_command(&"trade.buy", {"item_id": "core:good/textiles", "amount": 8})
	_click_continue(shell)
	# 回起始港：交付 6 件、卖出 2 件、收尾进酒馆。
	var home := String(context.state.story().get("home_port_id", ""))
	context.state.world()["current_port_id"] = home
	context.state.mark_port_visited(home)
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	shell._refresh()
	await _settle(3, 0.2)
	_click_continue(shell)
	shell._run_command(&"trade.sell", {"item_id": "core:good/textiles", "amount": 2})
	_click_continue(shell)
	await _settle(3, 0.2)


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
		"save_directory": "user://capture_saves/story_act2",
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
	push_error("capture_story_act2: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== story act2 capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
