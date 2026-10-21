extends SceneTree
## @static-doc
## 作用：阶段 4.5.2「开局幕」真实渲染截图工具（窗口模式）。走完整教学首段：
## 获船叙事 → 买 4 煤 2 水 → 补给受限 / 解锁海图 → 看海图并关闭 → 买够 10 煤 →
## 海图出航确认（默认极速）。抓「补给受限」与「首航确认」两张 1440×900 截图。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_act0.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/story/`）：
##   tutorial_supply_hold.png  补给页 + 非阻塞目标条 + 补给限购状态（海图已解锁）
##   tutorial_depart_fast.png  首航出航确认弹窗，锅炉策略默认「极速」
##
## ## 契约与约束
## - 全程用真实 Shell / 真实命令推进（`story.advance`、`supply.buy_*`、海图开关、
##   出航确认模型），不伪造渲染数据。
## - 硬性断言：补给页确实被限购（煤舱不变）、目标阶段为 supply_hold / depart_brief、
##   出航确认策略为 `core:strategy/fast`；失败返回非零退出码。
## - 强制 zh_CN、窗口 1440×900、`_settings_applied = true`，避免设置异步覆盖。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/story"
const WINDOW := Vector2i(1440, 900)
const SEED := 20260421
const STEADY_BUILD := "core:starting_build/steady"
const WATCHDOG_SECONDS := 120.0

const SHOTS := [
	{"file": "tutorial_supply_hold.png", "label": "补给受限 + 目标条（海图已解锁）"},
	{"file": "tutorial_supply_remaining.png", "label": "关图后：煤舱 8/10，还差 2"},
	{"file": "tutorial_depart_fast.png", "label": "首航出航确认（默认极速）"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_story_act0: timed out (%d s)" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · story act 0 (4.5.2)")
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
	var scene: PackedScene = load(MAIN_SCENE)
	var shell: Control = scene.instantiate()
	root.add_child(shell)
	shell._settings_applied = true
	await _settle(10, 0.5)
	# 开场剧情卡 → 补给简报。
	shell._run_command(&"story.advance", {})
	_shell_click_continue(shell)
	await _settle(4, 0.2)
	shell._run_command(&"supply.buy_coal", {"amount": 4})
	shell._run_command(&"supply.buy_water", {"amount": 2})
	if String(shell._story_vm.get("stage_id", "")) != "supply_hold":
		_fail("expected supply_hold, got %s" % str(shell._story_vm))
		_finish()
		return
	_shell_click_continue(shell)
	await _settle(4, 0.2)
	# 补给页 + 限购状态。
	shell._active_screen = "supply"
	shell._refresh()
	var coal_before := float(context.state.ship().get("coal", 0.0))
	shell._run_command(&"supply.buy_coal", {"amount": 1})
	if not is_equal_approx(float(context.state.ship().get("coal", 0.0)), coal_before):
		_fail("the supply hold did not block buying")
		_finish()
		return
	await _settle(5, 0.3)
	await _capture("tutorial_supply_hold.png", "补给受限")
	# 打开 / 关闭海图 → 恢复补给 → 买够 10 煤 → 出航阶段。
	shell._active_screen = "sea_chart"
	shell._refresh()
	shell._on_sea_chart_closed()
	shell._transitioning = false
	shell._pending_transition = false
	shell._active_screen = "overview"
	shell._refresh()
	_shell_click_continue(shell)
	await _settle(4, 0.2)
	var finish_label := shell.find_child("ObjectiveLabel", true, false) as Label
	if finish_label == null or not finish_label.text.contains("还差 2"):
		_fail("the supply objective should show the remaining 2 coal, got: %s" % (
			finish_label.text if finish_label != null else "<none>"
		))
	await _capture("tutorial_supply_remaining.png", "关图后煤舱进度与还差数量")
	shell._run_command(&"supply.buy_coal", {"amount": 2})
	if String(shell._story_vm.get("stage_id", "")) != "depart_brief":
		_fail("expected depart_brief, got %s" % str(shell._story_vm))
		_finish()
		return
	_shell_click_continue(shell)
	await _settle(4, 0.2)
	# 海图出航确认：默认策略应为剧情指定的 fast。
	var destination := String(context.state.contracts().get("main", {}).get("destination", ""))
	shell._active_screen = "sea_chart"
	shell._refresh()
	shell._on_chart_departure_requested("voyage", destination)
	if String(shell._chart_departure.get("strategy_id", "")) != "core:strategy/fast":
		_fail("departure dialog did not default to Fast: %s" % str(shell._chart_departure))
		_finish()
		return
	await _settle(5, 0.3)
	await _capture("tutorial_depart_fast.png", "出航确认默认极速")
	_finish()


func _shell_click_continue(shell: Control) -> void:
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
		"save_directory": "user://capture_saves/story_act0",
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
	push_error("capture_story_act0: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== story act0 capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
