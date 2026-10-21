extends SceneTree
## @static-doc
## 作用：阶段 4.5.1 新手剧情框架的真实渲染截图工具（窗口模式）。开一局教程局
## （`run.start tutorial=true`，seed 20260421），挂出真实的剧情卡，再推进剧情展示
## 非阻塞目标条 / 功能门禁后的补给页入口，抓两张 1440×900 截图。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_tutorial.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/story/`）：
##   tutorial_card.png       开局剧情卡：标题 / 多段正文 / 继续 / 跳过教程（导航仅总览）
##   tutorial_objective.png  收起剧情卡后的非阻塞目标条 + 补给页入口（门禁仍锁海图）
##
## ## 契约与约束
## - 用真实 Shell / 真实 `story.view` / `story.advance` 推进，不伪造渲染数据。
## - 截图前强制 zh_CN、窗口 1440×900、`shell._settings_applied = true`，避免设置
##   异步覆盖语言 / 分辨率导致两张图不一致。
## - 只保存非空且尺寸正确的视口纹理；失败返回非零退出码。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/story"
const WINDOW := Vector2i(1440, 900)
const SEED := 20260421
const STEADY_BUILD := "core:starting_build/steady"
const WATCHDOG_SECONDS := 120.0

const SHOTS := [
	{"file": "tutorial_card.png", "label": "开局剧情卡（继续 / 跳过教程 / 全部功能锁定）"},
	{"file": "tutorial_objective.png", "label": "非阻塞目标条 + 补给入口（海图仍锁定）"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_story_tutorial: timed out (%d s)" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · story tutorial 4.5.1")
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
	if scene == null:
		_fail("cannot load " + MAIN_SCENE)
		_finish()
		return
	var shell: Control = scene.instantiate()
	root.add_child(shell)
	shell._settings_applied = true
	await _settle(10, 0.5)
	if String(shell._story_vm.get("stage_id", "")) != "opening":
		_fail("the shell did not mount the opening story stage: %s" % str(shell._story_vm))
		_finish()
		return
	await _capture("tutorial_card.png", "开局剧情卡")
	shell._run_command(&"story.advance", {})
	await _settle(6, 0.3)
	if String(shell._story_vm.get("stage_id", "")) != "supply_brief":
		_fail("continue did not reach the supply briefing: %s" % str(shell._story_vm))
		_finish()
		return
	var dismiss := _node_named(shell, "ContinueButton") as Button
	if dismiss == null:
		_fail("the supply briefing has no continue button to dismiss the card")
		_finish()
		return
	dismiss.pressed.emit()
	await _settle(6, 0.4)
	if shell._story_card != null:
		_fail("the briefing card is still open; the objective would stay hidden")
		_finish()
		return
	await _capture("tutorial_objective.png", "非阻塞目标条")
	_finish()


func _bootstrap() -> AppContext:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://capture_saves/story_tutorial",
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


func _nodes_with_script(root_node: Node, script: Script, out: Array = []) -> Array:
	if script == null:
		return out
	for child in root_node.get_children():
		if child.get_script() == script:
			out.append(child)
		_nodes_with_script(child, script, out)
	return out


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
	push_error("capture_story_tutorial: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== story tutorial capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
