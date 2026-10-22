extends SceneTree
## @static-doc
## 作用：阶段 4.5.5「船厂 / 客舱 / 旅客」真实渲染截图工具（窗口模式）。走完教学前
## 三段，在第三港抓三张 1440×900 截图：只上架 1 人客舱的船厂、卸货舱并装好客舱后的
## 船厂、以及自动接取的第三主线旅客委托。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_act3.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/story/`）：
##   tutorial_shipyard_cabin.png       第三港船厂：候选只剩小型客舱
##   tutorial_shipyard_refit.png       卸下货舱、装好客舱后的船厂
##   tutorial_passenger_contract.png   第三主线：送 1 名旅客
##
## ## 契约与约束
## - 全程用真实 Shell / 真实命令推进；探索出航 / 结算用领域命令并补发 Shell 的
##   `cmd:explore.start` / `ui:arrival_settled` 观测，不伪造渲染数据。
## - 硬性断言：第三港船厂候选只有 `core:cabin/small_cabin`；客舱安装后
##   `passenger_capacity = 1`；第三主线 `main_03` 含 1 名旅客且无货箱。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/story"
const WINDOW := Vector2i(1440, 900)
const SEED := 20260421
const STEADY_BUILD := "core:starting_build/steady"
const WATCHDOG_SECONDS := 240.0
const CARGO_HOLD := "core:cargo_module/small_hold"
const SMALL_CABIN := "core:cabin/small_cabin"

const SHOTS := [
	{"file": "tutorial_shipyard_cabin.png", "label": "第三港船厂：只上架小型客舱"},
	{"file": "tutorial_shipyard_refit.png", "label": "船厂：卸货舱 + 装客舱"},
	{"file": "tutorial_passenger_contract.png", "label": "第三主线：送 1 名旅客"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_story_act3: timed out (%d s)" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · story act 3 (4.5.5)")
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
	# 酒馆 → 第三种货 → 一个来回 → 第二条 L3 线索。
	_click_continue(shell)
	_click_continue(shell)
	await _settle(3, 0.2)
	shell._run_command(&"intel.refresh", {})
	_click_continue(shell)
	await _settle(3, 0.2)
	context.commands.execute(&"story.observe", {"event": "cmd:voyage.start", "data": {}})
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	shell._refresh()
	_click_continue(shell)
	shell._refresh()
	_click_continue(shell)
	await _settle(3, 0.2)
	var clues := ClueService.active(context.state)
	var second_clue: Dictionary = clues[1] if clues.size() > 1 else {}
	if second_clue.is_empty():
		_fail("the second story clue is missing")
		_finish()
		return
	# 真实探索：备足补给、循第二条线索出航；把 outcome roll 固定成失败值以证明保底。
	context.state.set_money(5000)
	context.commands.execute(&"supply.buy_coal", {"amount": 30})
	context.commands.execute(&"supply.buy_water", {"amount": 10})
	var explore_started := context.commands.execute(&"explore.start", {
		"clue_id": String(second_clue.get("id", "")),
		"strategy_id": "core:strategy/standard",
	})
	if not bool(explore_started.get("ok", false)):
		_fail("explore.start failed: %s" % str(explore_started))
		_finish()
		return
	context.commands.execute(&"story.observe", {
		"event": "cmd:explore.start", "data": explore_started.get("data", {}),
	})
	var voyage: Variant = context.state.explore_voyage()
	if voyage is Dictionary:
		(voyage as Dictionary)["outcome_roll"] = 1.0
	var settled := context.commands.execute(&"explore.settle", {})
	if String(settled.get("data", {}).get("result", "")) != "discovered":
		_fail("the guaranteed exploration did not discover the third port: %s" % str(settled))
		_finish()
		return
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	shell._refresh()
	await _settle(4, 0.25)
	if String(shell._story_vm.get("stage_id", "")) != "third_port":
		_fail("story did not reach third_port, got %s" % String(shell._story_vm.get("stage_id", "")))
	# third_port 卡 → 卸货舱步骤。
	_click_continue(shell)
	await _settle(3, 0.2)
	_click_continue(shell)
	shell._active_screen = "shipyard"
	shell._refresh()
	await _settle(8, 0.5)
	_select_shipyard_category(shell, "cabins")
	await _settle(6, 0.35)
	var yard: Dictionary = context.queries.execute(&"shipyard.view")["data"]
	var candidates: Array = yard.get("candidates", [])
	if candidates.size() != 1 or String((candidates[0] as Dictionary).get("module_id", "")) != SMALL_CABIN:
		_fail("the tutorial shipyard should only list the small cabin, got %s" % str(candidates))
	await _capture("tutorial_shipyard_cabin.png", "第三港船厂：只上架小型客舱")
	# 卸下货舱 → 装上客舱。
	shell._run_command(&"ship.uninstall_module", {"module_id": CARGO_HOLD})
	await _settle(3, 0.2)
	_click_continue(shell)
	shell._run_command(&"ship.install_module", {"module_id": SMALL_CABIN, "source": "purchase"})
	await _settle(3, 0.2)
	_click_continue(shell)
	shell._active_screen = "shipyard"
	shell._refresh()
	await _settle(8, 0.5)
	_select_shipyard_category(shell, "cabins")
	await _settle(6, 0.35)
	if String(context.state.ship().get("passenger_cabin_id", "")) != SMALL_CABIN:
		_fail("the small cabin is not installed")
	if int(ShipOps.passenger_capacity(context.registries, context.state.ship())) != 1:
		_fail("the installed cabin should seat exactly one passenger")
	await _capture("tutorial_shipyard_refit.png", "船厂：卸货舱 + 装客舱")
	# 第三主线自动接取：送 1 名旅客。
	var main_contract: Variant = context.state.contracts().get("main", null)
	if not (main_contract is Dictionary):
		_fail("the third mainline passenger contract was not granted")
	elif String((main_contract as Dictionary).get("template_id", "")) != "core:contract/main_03" \
			or int((main_contract as Dictionary).get("passengers", 0)) != 1:
		_fail("the third mainline should be main_03 with one passenger: %s" % str(main_contract))
	shell._active_screen = "contracts"
	shell._refresh()
	await _settle(8, 0.5)
	var page_scroll := shell.get_node_or_null("PageMargin/PageScroll") as ScrollContainer
	if page_scroll != null:
		page_scroll.scroll_vertical = 520
		await _settle(4, 0.25)
	await _capture("tutorial_passenger_contract.png", "第三主线：送 1 名旅客")
	_finish()


func _select_shipyard_category(shell: Control, category: String) -> void:
	var screen := _node_named(shell, "ShipyardScreen")
	if screen != null and screen.has_method("set_category"):
		screen.set_category(category)


## 走完前两幕并停在 tavern_open（酒馆已给第一条线索、解锁酒馆页）。
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
	var main_contract: Dictionary = context.state.contracts().get("main", {})
	var second_port := String(main_contract.get("destination", ""))
	context.state.world()["current_port_id"] = second_port
	context.state.mark_port_visited(second_port)
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	shell._refresh()
	await _settle(3, 0.2)
	_click_continue(shell)
	shell._run_command(&"trade.buy", {"item_id": "core:item/textiles", "amount": 8})
	_click_continue(shell)
	var home := String(context.state.story().get("home_port_id", ""))
	context.state.world()["current_port_id"] = home
	context.state.mark_port_visited(home)
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	shell._refresh()
	await _settle(3, 0.2)
	_click_continue(shell)
	shell._run_command(&"trade.sell", {"item_id": "core:item/textiles", "amount": 2})
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
		"save_directory": "user://capture_saves/story_act3",
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
	push_error("capture_story_act3: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== story act3 capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
