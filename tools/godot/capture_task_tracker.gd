extends SceneTree
## @static-doc
## 作用：阶段 4.6 Phase A「任务追踪聚合」真实渲染截图工具（窗口模式）。用普通
## 非教程新局抓两张 1440×900 截图：HUD 任务追踪条（主线委托当前步骤），以及委托页
## 顶部的完整任务追踪面板（任务 + 步骤）。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_task_tracker.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/task/`）：
##   task_tracker_hud.png        HUD 任务追踪：主线委托 + 当前步骤
##   task_tracker_contracts.png  委托页任务追踪面板：任务与全部步骤
##
## ## 契约与约束
## - 全程真实 Shell / 真实 `run.start`；不伪造 task.view 数据。
## - 硬性断言：HUD 出现 `TaskTracker` 且当前步骤含「前往」；委托页含任务追踪面板。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/task"
const WINDOW := Vector2i(1440, 900)
const SEED := 20260421
const STEADY_BUILD := "core:starting_scenario/steady"
const WATCHDOG_SECONDS := 120.0

const SHOTS := [
	{"file": "task_tracker_hud.png", "label": "HUD 任务追踪"},
	{"file": "task_tracker_contracts.png", "label": "委托页任务追踪面板"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_task_tracker: timed out (%d s)" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · task tracker (4.6A)")
	await process_frame
	var context := _bootstrap()
	if context == null:
		_finish()
		return
	var started := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": SEED,
	})
	if not bool(started.get("ok", false)):
		_fail("run.start failed: %s" % str(started))
		_finish()
		return
	context.localization.set_locale("zh_CN")
	var shell: Control = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(shell)
	shell._settings_applied = true
	await _settle(12, 0.5)
	var tasks: Dictionary = context.queries.execute(&"task.view")["data"]
	if int(tasks.get("task_count", 0)) < 1:
		_fail("the run has no tracked task")
		_finish()
		return
	var tracker := _node_named(shell, "TaskTracker")
	if tracker == null:
		_fail("the shell did not mount the HUD task tracker")
		_finish()
		return
	var step := _node_named(shell, "TaskStep") as Label
	if step == null or not (step.text.contains("前往") or step.text.contains("Sail")):
		_fail("the HUD tracker does not show the sail step: %s" % (
			step.text if step != null else "<none>"
		))
	await _capture("task_tracker_hud.png", "HUD 任务追踪")
	shell._transitioning = false
	shell._pending_transition = false
	shell._active_screen = "contracts"
	shell._refresh()
	await _settle(8, 0.5)
	if not _has_label_text(shell, "任务追踪"):
		_fail("the contracts page has no task tracker panel")
	await _capture("task_tracker_contracts.png", "委托页任务追踪面板")
	_finish()


func _has_label_text(root_node: Node, needle: String) -> bool:
	if root_node is Label and String((root_node as Label).text).contains(needle):
		return true
	for child in root_node.get_children():
		if _has_label_text(child, needle):
			return true
	return false


func _bootstrap() -> AppContext:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://capture_saves/task_tracker",
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
	push_error("capture_task_tracker: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== task tracker capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
