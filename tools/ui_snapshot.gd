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
##   → AppContext.set_active → run.start {core:starting_build/steady, seed}
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
##   --category=cargo_modules,misc   改装态额外按分类各截一张
##   --damage=boiler:0.5[,cargo:0.4] 先损坏指定模块实例，再额外截取受损状态的
##                                   船厂正常态 / 改装态 / 补给维修页
##   --skip-refit                    只截正常态
## 任一截图失败或画面为空（纯色）时以退出码 1 结束，方便 CI/验收脚本判断。

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const SHIPYARD_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/shipyard_screen.gd")
const SN_SHIP_VIEW_SCRIPT := preload("res://framework/ui/components/sn_ship_view.gd")
const STEADY_BUILD := "core:starting_build/steady"
const DEFAULT_SEED := 5201
const DEFAULT_OUT_DIR := "res://docs/design/screenshots"
const DEFAULT_WINDOW := Vector2i(1440, 900)
## ~0.5 秒 / 60fps 的布局稳定帧数；真实窗口没有固定帧率，所以再配一段等待。
const LAYOUT_FRAMES := 30
const LAYOUT_SETTLE_SECONDS := 0.35
const REFIT_FRAMES := 20
const REFIT_SETTLE_SECONDS := 0.2
## 兜底：脚本错误会让协程中断而不退出，窗口就会挂住，这里强制收尾。
const WATCHDOG_SECONDS := 120

var _failures: Array[String] = []
var _seed := DEFAULT_SEED
var _out_dir := DEFAULT_OUT_DIR
var _window := DEFAULT_WINDOW
## 额外截图的分类（--category=cargo_modules,misc）。
var _categories: Array[String] = ["cargo_modules", "misc"]
var _skip_refit := false
## 截图前要损坏的模块实例：{"slot": "boiler", "index": 0, "ratio": 0.5}。
var _damage_targets: Array = []
var _saved: Array[String] = []


func _init() -> void:
	_parse_args()
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("ui_snapshot: 截图流程超时（%d 秒），强制退出" % WATCHDOG_SECONDS)
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
		"build_id": STEADY_BUILD,
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
		_expect(bool(screen.get("_refit")), "点击后页面进入改装态")
		_expect(bool(shell._shipyard_refit), "Shell 记住了改装态（_shipyard_refit）")
		stage = screen.get("_stage")
		if stage != null:
			_expect(int(stage.mode) == SN_SHIP_VIEW_SCRIPT.Mode.CUTAWAY, "改装态显示纵剖图（SNShipView.Mode.CUTAWAY）")
		await _capture(_path("shipyard_refit.png"))
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
			screen.set_category("boilers")
			await _settle(REFIT_FRAMES, REFIT_SETTLE_SECONDS)
			await _capture(_path("shipyard_refit_damaged.png"))
		shell._active_screen = "supply"
		shell._refresh()
		await _settle(LAYOUT_FRAMES, LAYOUT_SETTLE_SECONDS)
		await _capture(_path("supply_damaged.png"))

	await _teardown(shell)
	_finish()


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
	match category:
		"cargo_modules":
			return "cargo"
		"navigation_modules":
			return "navigation"
		"safety_modules":
			return "safety"
		_:
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
		elif text == "--skip-refit":
			_skip_refit = true
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
