extends SceneTree
## @static-doc
## 作用：海图系统（阶段 2）的真实渲染截图工具，窗口 1440×900 挂载
## `dev_scenes/sea_chart/sea_chart_preview.tscn`，依次切换三种预览变体并落盘 PNG。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_sea_chart.gd
##
## 输出（全部 1440×900，写入 `docs/design/screenshots/sea_chart/`）：
##   sea_chart_fresh.png     仅起点港已发现：大片黑雾 + 港口揭示光斑
##   sea_chart_explored.png  两跳探索：多港口 + 贝塞尔航线 + 海岸灰雾
##   sea_chart_voyage.png    在航 + 选中目的港：右侧面板显示距离/风险/启航
##
## ## 契约与约束
## - 每张图先写 `res://tmp_sea_chart_*`，全部成功后才移入 `docs/`；失败则以退出码 1
##   结束且不留半套新截图。
## - 纯色/近纯色画面视为"读到未绘制纹理"，判为失败（说明绘制逻辑没跑起来）。
## - 90 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。
## - 从预览场景读取 `get_chart().view_model` 非空后再截图，避免拍到空海图。
## @end-static-doc

const PREVIEW_SCENE := "res://dev_scenes/sea_chart/sea_chart_preview.tscn"
const OUT_DIR := "res://docs/design/screenshots/sea_chart"
const WINDOW := Vector2i(1440, 900)
const SETTLE_FRAMES := 8
const SETTLE_SECONDS := 0.25
const READY_TIMEOUT_SECONDS := 20.0
const WATCHDOG_SECONDS := 90.0
const TMP_PREFIX := "res://tmp_sea_chart_"
const SHOTS := [
	{"file": "sea_chart_fresh.png", "variant": "fresh"},
	{"file": "sea_chart_bare.png", "variant": "bare"},
	{"file": "sea_chart_explored.png", "variant": "explored"},
	{"file": "sea_chart_voyage.png", "variant": "voyage"},
]

var _failures := 0
var _saved: Array[String] = []
var _pending: Array[Dictionary] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_sea_chart: screenshot flow timed out (%d s)" % int(WATCHDOG_SECONDS))
	_cleanup_tmp()
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · sea chart")
	await process_frame
	await process_frame

	var scene: PackedScene = load(PREVIEW_SCENE)
	if scene == null:
		_fail("cannot load preview scene " + PREVIEW_SCENE)
		_finish()
		return
	var preview: Control = scene.instantiate()
	root.add_child(preview)
	await process_frame

	if not await _wait_for_chart(preview):
		_finish()
		return

	for shot in SHOTS:
		var variant := String(shot["variant"])
		var file := String(shot["file"])
		preview.set_variant(variant)
		await _settle(SETTLE_FRAMES, SETTLE_SECONDS)
		var chart: Control = preview.get_chart()
		if chart == null or (chart.get("view_model") as Dictionary).is_empty():
			_fail("variant=%s produced an empty view model" % variant)
			continue
		await _capture_to_tmp(file, variant)

	_commit_shots()
	_finish()


## The preview builds its world synchronously in `_ready` but binds the chart after a
## few frames, so poll until `view_model` is populated instead of guessing a frame count.
func _wait_for_chart(preview: Control) -> bool:
	var deadline := Time.get_ticks_msec() + int(READY_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var chart: Variant = preview.get_chart()
		if chart == null:
			continue
		var vm: Variant = chart.get("view_model")
		if vm is Dictionary and not (vm as Dictionary).is_empty():
			print("[INFO] chart ready: %d port(s), %d route(s)" % [
				(vm as Dictionary).get("ports", []).size(),
				(vm as Dictionary).get("routes", []).size(),
			])
			return true
	_fail("preview never bound a view model within %.0f s" % READY_TIMEOUT_SECONDS)
	return false


func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	await create_timer(seconds).timeout
	for i in 3:
		await process_frame


func _capture_to_tmp(file_name: String, label: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport texture: " + label)
		return false
	if image.get_width() != WINDOW.x or image.get_height() != WINDOW.y:
		_fail("capture size %dx%d does not match %dx%d (%s)" % [
			image.get_width(), image.get_height(), WINDOW.x, WINDOW.y, label,
		])
		return false
	if _is_flat(image):
		_fail("flat image (nothing was drawn): " + label)
		return false
	var absolute := ProjectSettings.globalize_path(TMP_PREFIX + file_name)
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("cannot save temp PNG %s (error=%d)" % [absolute, save_error])
		return false
	_pending.append({"tmp": file_name, "file": file_name})
	print("[PASS] captured %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), absolute])
	return true


## Pure/near-pure colour means we read an undrawn texture.
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


func _commit_shots() -> void:
	if _pending.size() != SHOTS.size():
		print("[INFO] not committing: %d/%d shot(s) captured" % [_pending.size(), SHOTS.size()])
		_cleanup_tmp()
		return
	var absolute_dir := ProjectSettings.globalize_path(OUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		_fail("cannot create output directory %s (error=%d)" % [absolute_dir, dir_error])
		_cleanup_tmp()
		return
	for entry in _pending:
		var tmp_abs := ProjectSettings.globalize_path(TMP_PREFIX + String(entry["tmp"]))
		var final_abs := absolute_dir.path_join(String(entry["file"]))
		if not FileAccess.file_exists(tmp_abs):
			_fail("temp capture missing: " + tmp_abs)
			continue
		var move_error := DirAccess.rename_absolute(tmp_abs, final_abs)
		if move_error != OK:
			_fail("cannot move %s -> %s (error=%d)" % [tmp_abs, final_abs, move_error])
			continue
		_saved.append(final_abs)
		print("[PASS] saved %s" % final_abs)
	_cleanup_tmp()


func _cleanup_tmp() -> void:
	for shot in SHOTS:
		var tmp_abs := ProjectSettings.globalize_path(TMP_PREFIX + String(shot["file"]))
		if FileAccess.file_exists(tmp_abs):
			DirAccess.remove_absolute(tmp_abs)


func _fail(message: String) -> void:
	_failures += 1
	print("[FAIL] " + message)


func _finish() -> void:
	_cleanup_tmp()
	print("=== sea chart capture: %d failures, %d/%d image(s) ===" % [_failures, _saved.size(), SHOTS.size()])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
