extends SceneTree
## Real-render screenshots of the 2.5D `PortStage` skeleton (windowed, 1440x900).
##
## Usage:
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_port_stage.gd
##
## Output (all 1440x900):
##   docs/design/screenshots/port_stage/port_stage_preview.png    preview / harbor / stage
##   docs/design/screenshots/port_stage/port_stage_sparse.png     sparse variant (harbor / stage)
##   docs/design/screenshots/port_stage/port_stage_market.png     preview / market / stage
##   docs/design/screenshots/port_stage/port_stage_supply.png     preview / supply / stage
##   docs/design/screenshots/port_stage/port_stage_harbor_page.png preview / harbor / panel
##
## The port stage is a single continuous harbour with three adjacent berths
## (market / harbor / supply) on the world X axis. This tool mounts
## `dev_scenes/port_stage/port_stage_preview.tscn` once, then drives
## `set_variant()` + `set_station()` in the same process and waits for
## `PortStage.is_station_transitioning()` to clear and the camera to reach
## `station_camera_pose()` before each shot (a settle pass covers the water
## shader + ship bob). With a 620 px page panel on the right, the "panel"
## framing keeps the berth in the visible left area.
##
## Must run windowed (no `--headless`): the viewport texture is empty under the
## headless display server. Screenshots are first written to `res://tmp_port_stage_*`
## and only moved into `docs/` after every shot succeeded; any failure exits with
## code 1 and leaves no temp files behind.

const PREVIEW_SCENE := "res://dev_scenes/port_stage/port_stage_preview.tscn"
const OUT_DIR := "res://docs/design/screenshots/port_stage"
const WINDOW := Vector2i(1440, 900)
const SETTLE_FRAMES := 90
const SETTLE_SECONDS := 1.0
const SWITCH_FRAMES := 30
const SWITCH_SECONDS := 0.5
const STATION_TIMEOUT_SECONDS := 8.0
## Camera position tolerance while waiting for the station pose (the transition
## flag is authoritative; this catches a pose that was accepted but never applied).
const CAMERA_POSE_EPSILON := 0.75
## If the transition is done but the camera differs from `station_camera_pose()`
## (e.g. the stage adds a procedural sway), accept after this grace period and
## warn instead of failing the shot.
const CAMERA_POSE_GRACE_SECONDS := 1.0
const TMP_PREFIX := "res://tmp_"
const SHOTS := [
	{"file": "port_stage_preview.png", "variant": "preview", "station": "harbor", "framing": "stage"},
	{"file": "port_stage_sparse.png", "variant": "sparse", "station": "harbor", "framing": "stage"},
	{"file": "port_stage_market.png", "variant": "preview", "station": "market", "framing": "stage"},
	{"file": "port_stage_supply.png", "variant": "preview", "station": "supply", "framing": "stage"},
	{"file": "port_stage_harbor_page.png", "variant": "preview", "station": "harbor", "framing": "panel"},
]
const WATCHDOG_SECONDS := 180.0

var _failures := 0
var _saved: Array[String] = []
## Captures waiting in `res://tmp_*` until the whole set succeeded.
var _pending: Array[Dictionary] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_port_stage: screenshot flow timed out (%d s)" % int(WATCHDOG_SECONDS))
	_cleanup_tmp()
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
	if not scene.has_method("set_variant"):
		_fail("preview scene has no set_variant(); cannot capture the sample variants")
		_finish()
		return
	if not scene.has_method("set_station"):
		_fail("preview scene has no set_station(); the station screenshots need the new preview API")
		_finish()
		return
	await _settle(SETTLE_FRAMES, SETTLE_SECONDS)

	for shot in SHOTS:
		var file_name := String(shot["file"])
		var variant := String(shot["variant"])
		var station := String(shot["station"])
		var framing := String(shot["framing"])
		var variant_now := String(scene.current_variant()) if scene.has_method("current_variant") else ""
		if variant_now != variant:
			scene.set_variant(variant)
			await _settle(SWITCH_FRAMES, SWITCH_SECONDS)
		print("[INFO] shot %s: variant=%s station=%s framing=%s" % [file_name, variant, station, framing])
		var ready := await _ready_for_station(scene, station, framing, file_name)
		if not ready:
			continue
		var tmp_name := file_name
		var captured := await _capture_to_tmp(tmp_name, file_name)
		if captured:
			_pending.append({"tmp": tmp_name, "file": file_name})

	_commit_shots()
	scene.queue_free()
	await process_frame
	_finish()


## Polls the stage until the station transition is done and the camera sits on
## `station_camera_pose(station, framing)`, then lets one settle pass run.
func _ready_for_station(scene: Node, station_id: String, framing: String, label: String) -> bool:
	if not scene.has_method("current_stage"):
		_fail("preview scene has no current_stage(); cannot verify the station before " + label)
		return false
	var stage: Variant = scene.current_stage()
	if stage == null:
		_fail("PortStage is not mounted; cannot focus station %s (%s)" % [station_id, label])
		return false
	if not stage.has_method("focus_station"):
		_fail("PortStage station API is missing (focus_station) — Lead change pending (%s)" % label)
		return false
	var accepted := false
	if scene.has_method("set_station"):
		# Preferred path: the preview scene forwards to focus_station() and prints
		# the station / camera / ship / anchor state into the capture log.
		accepted = bool(scene.set_station(station_id, framing))
	else:
		accepted = bool(stage.focus_station(station_id, framing, true))
	if not accepted:
		_fail("station=%s framing=%s was rejected by the stage (%s)" % [station_id, framing, label])
		return false

	var pose_supported: bool = stage.has_method("station_camera_pose")
	var deadline := Time.get_ticks_msec() + int(STATION_TIMEOUT_SECONDS * 1000.0)
	var grace_ms := int(CAMERA_POSE_GRACE_SECONDS * 1000.0)
	var settled_since := -1
	var settled := false
	while Time.get_ticks_msec() < deadline:
		var transitioning := bool(stage.is_station_transitioning()) if stage.has_method("is_station_transitioning") else false
		if transitioning:
			settled_since = -1
			await process_frame
			continue
		if not pose_supported or _camera_at_pose(stage, station_id, framing):
			settled = true
			break
		if settled_since < 0:
			settled_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - settled_since >= grace_ms:
			print("[WARN] %s: camera differs from station_camera_pose() but the transition already finished; continuing" % label)
			settled = true
			break
		await process_frame
	if not settled:
		_fail("station=%s framing=%s did not settle within %.1fs (%s)" % [
			station_id, framing, STATION_TIMEOUT_SECONDS, label,
		])
		return false

	# Let the water shader, ship bob and any one-frame stage smoothing finish.
	await _settle(SETTLE_FRAMES, SETTLE_SECONDS)
	if stage.has_method("is_station_transitioning") and bool(stage.is_station_transitioning()):
		_fail("station=%s restarting a transition while settling (%s)" % [station_id, label])
		return false
	if stage.has_method("current_station"):
		var current := String(stage.current_station())
		if current != station_id:
			_fail("station=%s but PortStage.current_station()=%s (%s)" % [station_id, current, label])
			return false
	print("[INFO] station settled: %s framing=%s (%s)" % [station_id, framing, label])
	return true


## True when the live StageCamera is at `station_camera_pose(station, framing)`
## (position + forward direction); missing camera node is treated as "cannot
## verify, trust the transition flag".
func _camera_at_pose(stage: Node, station_id: String, framing: String) -> bool:
	var raw: Variant = stage.station_camera_pose(station_id, framing)
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return false
	var pose: Dictionary = raw
	var target_position: Variant = pose.get("position", null)
	if not (target_position is Vector3):
		return true
	var camera := stage.get_node_or_null("StageCamera") as Camera3D
	if camera == null:
		return true
	if camera.global_position.distance_to(target_position as Vector3) > CAMERA_POSE_EPSILON:
		return false
	var target: Variant = pose.get("target", null)
	if target is Vector3:
		var desired := (target as Vector3) - (target_position as Vector3)
		if desired.length() > 0.001:
			return (-camera.global_transform.basis.z).dot(desired.normalized()) > 0.999
	return true


func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	await create_timer(seconds).timeout
	for i in 3:
		await process_frame


## Writes the capture to `res://tmp_<file>`; only `_commit_shots()` moves the
## finished set into `docs/` so a failed run never leaves half-new screenshots.
func _capture_to_tmp(tmp_name: String, label: String) -> bool:
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
	var absolute := ProjectSettings.globalize_path(TMP_PREFIX + tmp_name)
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("cannot save temp PNG %s (error=%d)" % [absolute, save_error])
		return false
	print("[PASS] captured %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), absolute])
	return true


## Moves every pending temp capture into the docs folder. Only called once all
## requested shots were captured, so the docs baseline is never half-updated.
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
	print("=== port stage capture: %d failures, %d/%d image(s) ===" % [_failures, _saved.size(), SHOTS.size()])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
