extends SceneTree
## Real-render screenshots of the 2.5D `PortStage` skeleton (windowed, 1440x900).
##
## Usage:
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_port_stage.gd
##
## Output:
##   docs/design/screenshots/port_stage/port_stage_preview.png
##   docs/design/screenshots/port_stage/port_stage_sparse.png
##
## Must run windowed (no `--headless`): the viewport texture is empty under the
## headless display server. The script waits for the stage to settle (water
## shader + ship bob) before capturing; any failure exits with code 1.

const PREVIEW_SCENE := "res://dev_scenes/port_stage/port_stage_preview.tscn"
const OUT_DIR := "res://docs/design/screenshots/port_stage"
const WINDOW := Vector2i(1440, 900)
const SETTLE_FRAMES := 90
const SETTLE_SECONDS := 1.0
const SWITCH_FRAMES := 30
const SWITCH_SECONDS := 0.5
const WATCHDOG_SECONDS := 120.0

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_port_stage: screenshot flow timed out (%d s)" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · port stage")
	await process_frame
	await process_frame

	var packed := load(PREVIEW_SCENE) as PackedScene
	if packed == null:
		_fail("scene load failed: " + PREVIEW_SCENE)
		_finish()
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await _settle(SETTLE_FRAMES, SETTLE_SECONDS)
	await _capture("port_stage_preview.png")

	if scene.has_method("set_variant"):
		scene.set_variant("sparse")
		await _settle(SWITCH_FRAMES, SWITCH_SECONDS)
		await _capture("port_stage_sparse.png")
	else:
		_fail("preview scene has no set_variant(); cannot capture the sparse variant")

	scene.queue_free()
	await process_frame
	_finish()


func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	await create_timer(seconds).timeout
	for i in 3:
		await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport texture: " + file_name)
		return
	var absolute := ProjectSettings.globalize_path(OUT_DIR.path_join(file_name))
	var dir := absolute.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(dir)
	if dir_error != OK and not DirAccess.dir_exists_absolute(dir):
		_fail("cannot create directory %s (error=%d)" % [dir, dir_error])
		return
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("cannot save PNG %s (error=%d)" % [absolute, save_error])
		return
	_saved.append(absolute)
	print("[PASS] saved %s (%dx%d)" % [absolute, image.get_width(), image.get_height()])


func _fail(message: String) -> void:
	_failures += 1
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== port stage capture: %d failures, %d image(s) ===" % [_failures, _saved.size()])
	quit(0 if _failures == 0 and _saved.size() == 2 else 1)
