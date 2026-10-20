extends SceneTree
## @static-doc
## 作用：航行演出（海图系统阶段 3）的真实渲染截图工具。窗口模式挂载真正的
## `main.tscn`，用真实命令开一局、真实发出 `voyage.start`，然后按演出里程碑抓
## 三张图：云层盖住 3D 港口、海图上船只航行、抵达结算。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_voyage_presentation.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/voyage_presentation/`）：
##   voyage_departure_3d.png    出航：船驶离泊位、镜头升到高位（还没盖云层）
##   voyage_departure_clouds.png 云层盖住高位镜头（云层盖住 → 切海图的那一帧）
##   voyage_at_sea.png          航行中：海图 + 航行船只 + 底部航程条
##   voyage_arrival_3d.png      入港：目的港 3D 场景，镜头下降、船驶入泊位
##   voyage_arrival.png         抵达结算页
##
## ## 契约与约束
## - 不想猜帧数：按演出自身的状态（阶段名 / `_cloud_veil.cover` / 舞台
##   `voyage_progress()`）轮询里程碑，拿不到就以退出码 1 结束。
## - 先写 `res://tmp_voyage_*`，全部成功后才移入 `docs/`，失败不留半套。
## - 纯色/近纯色画面视为"读到未绘制纹理"，判失败。
## - 90 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/voyage_presentation"
const WINDOW := Vector2i(1440, 900)
const SEED := 4321
const WATCHDOG_SECONDS := 120.0
const READY_TIMEOUT_SECONDS := 20.0
const TMP_PREFIX := "res://tmp_voyage_"
const SHOTS := [
	{"file": "voyage_departure_3d.png", "label": "3D 离港（船驶离 + 镜头上升）"},
	{"file": "voyage_departure_clouds.png", "label": "出航云层"},
	{"file": "voyage_at_sea.png", "label": "海图航行"},
	{"file": "voyage_arrival_3d.png", "label": "3D 入港（镜头下降 + 船驶入）"},
	{"file": "voyage_arrival.png", "label": "抵达结算"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_voyage_presentation: timed out (%d s)" % int(WATCHDOG_SECONDS))
	_cleanup_tmp()
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · voyage presentation")
	await process_frame

	var context := _bootstrap()
	if context == null:
		_finish()
		return
	var started := context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": SEED})
	if not bool(started.get("ok", false)):
		_fail("run.start failed: %s" % str(started))
		_finish()
		return
	var main_contact: Variant = context.state.contracts().get("main", null)
	if not (main_contact is Dictionary):
		_fail("the run has no main contract to sail on")
		_finish()
		return
	var destination := String((main_contact as Dictionary).get("destination", ""))

	var scene: PackedScene = load(MAIN_SCENE)
	var shell: Control = scene.instantiate()
	root.add_child(shell)
	await _settle(6, 0.3)

	shell._run_command(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": "core:strategy/standard",
	})

	# Shot 1 — the 3D departure beat: hull sailing out, camera climbing, no clouds.
	if await _wait_until(func() -> bool:
			return _phase(shell) == "departure_3d" and _stage_progress(shell) >= 0.45,
			READY_TIMEOUT_SECONDS, "3D departure beat"):
		await _settle(2, 0.0)
		await _capture(String(SHOTS[0]["file"]), String(SHOTS[0]["label"]))

	# Shot 2 — clouds covering that high shot, halfway through the veil.
	if await _wait_until(func() -> bool:
			return shell._cloud_veil != null and float(shell._cloud_veil.cover) >= 0.45,
			READY_TIMEOUT_SECONDS, "departure veil"):
		await _settle(2, 0.0)
		await _capture(String(SHOTS[1]["file"]), String(SHOTS[1]["label"]))

	# Shot 3 — chart visible, ship partway along the route.
	if await _wait_until(func() -> bool:
			return shell._at_sea_screen != null \
				and shell._presentation != null \
				and float(shell._presentation.progress) >= 0.35,
			READY_TIMEOUT_SECONDS, "at-sea progress"):
		await _settle(2, 0.0)
		await _capture(String(SHOTS[2]["file"]), String(SHOTS[2]["label"]))

	# Shot 4 — the 3D arrival beat: destination harbour, camera coming down, hull
	# sailing in from the sea handoff.
	if await _wait_until(func() -> bool:
			return _phase(shell) == "arrival_harbor" and _stage_progress(shell) >= 0.45,
			READY_TIMEOUT_SECONDS * 2.0, "3D arrival beat"):
		await _settle(2, 0.0)
		await _capture(String(SHOTS[3]["file"]), String(SHOTS[3]["label"]))

	# Shot 5 — arrival settled, veil gone.
	if await _wait_until(func() -> bool:
			return shell._presentation == null and String(shell._active_screen) == "settlement",
			READY_TIMEOUT_SECONDS * 2.0, "arrival settlement"):
		await _settle(2, 0.0)
		await _capture(String(SHOTS[4]["file"]), String(SHOTS[4]["label"]))

	_commit_shots()
	_finish()


func _phase(shell: Control) -> String:
	if shell._presentation == null:
		return ""
	return String(shell._presentation.phase_name())


func _stage_progress(shell: Control) -> float:
	var stage: PortStage = shell._port_stage()
	return 0.0 if stage == null else float(stage.voyage_progress())


func _bootstrap() -> AppContext:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://preview_saves/voyage_presentation",
	})
	var context := bootstrap.context
	if context == null:
		_fail("bootstrap produced no AppContext")
		return null
	AppContext.set_active(context)
	return context


func _wait_until(predicate: Callable, timeout_seconds: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			print("[INFO] reached milestone: %s" % label)
			return true
		await process_frame
	_fail("milestone '%s' was never reached within %.0f s" % [label, timeout_seconds])
	return false


func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout
	for i in 3:
		await process_frame


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
	if _is_flat(image):
		_fail("flat image (nothing was drawn): " + label)
		return
	var absolute := ProjectSettings.globalize_path(TMP_PREFIX + file_name)
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("cannot save temp PNG %s (error=%d)" % [absolute, save_error])
		return
	_saved.append(file_name)
	print("[PASS] captured %s -> %s" % [label, absolute])


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
	if _saved.size() != SHOTS.size():
		_cleanup_tmp()
		return
	var absolute_dir := ProjectSettings.globalize_path(OUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		_fail("cannot create output directory %s (error=%d)" % [absolute_dir, dir_error])
		_cleanup_tmp()
		return
	for file_name in _saved:
		var tmp_abs := ProjectSettings.globalize_path(TMP_PREFIX + file_name)
		var final_abs := absolute_dir.path_join(file_name)
		if FileAccess.file_exists(final_abs):
			DirAccess.remove_absolute(final_abs)
		var move_error := DirAccess.rename_absolute(tmp_abs, final_abs)
		if move_error != OK:
			_fail("cannot move %s -> %s (error=%d)" % [tmp_abs, final_abs, move_error])
		else:
			print("[PASS] saved %s" % final_abs)


func _cleanup_tmp() -> void:
	for shot in SHOTS:
		var tmp_abs := ProjectSettings.globalize_path(TMP_PREFIX + String(shot["file"]))
		if FileAccess.file_exists(tmp_abs):
			DirAccess.remove_absolute(tmp_abs)


func _fail(message: String) -> void:
	_failures += 1
	push_error("capture_voyage_presentation: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	if _failures > 0:
		_cleanup_tmp()
	print("=== voyage presentation capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
