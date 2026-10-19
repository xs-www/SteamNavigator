extends SceneTree
## 港口样片真实渲染截图（窗口模式，1440×900）。
##
## 用法：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_harbor_diorama.gd
##
## 输出：
##   docs/design/screenshots/harbor_diorama_schooner.png        固定 3/4 港口机位
##   docs/design/screenshots/harbor_diorama_schooner_detail.png  纵帆船近景机位
##
## 必须窗口模式（不能加 --headless），否则视口纹理为空。脚本会等待水面/浮船
## 动画稳定后抓取 root 视口；任一截图失败以退出码 1 结束。

const SCENE_PATH := "res://dev_scenes/harbor/harbor_diorama.tscn"
const OUT_DIR := "res://docs/design/screenshots"
const WINDOW := Vector2i(1440, 900)
const SETTLE_FRAMES := 90
const SETTLE_SECONDS := 1.0
const DETAIL_FRAMES := 20
const DETAIL_SECONDS := 0.35
const WATCHDOG_SECONDS := 120.0

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_harbor_diorama: 截图流程超时（%d 秒）" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("必须以窗口模式运行（去掉 --headless），否则渲染纹理为空")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · harbor diorama")
	await process_frame
	await process_frame

	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("场景加载失败：" + SCENE_PATH)
		_finish()
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await _settle(SETTLE_FRAMES, SETTLE_SECONDS)

	await _capture("harbor_diorama_schooner.png")

	# 近景机位：把固定相机挪到船艏右前方，整体拉近约 1.4×，看新纵帆船的桅/帆/艉廊。
	var cam := scene.find_child("Camera3D", true, false) as Camera3D
	if cam == null:
		_fail("港口场景里找不到 Camera3D")
	else:
		cam.position = Vector3(30.0, 11.0, 34.0)
		cam.fov = 40.0
		cam.look_at(Vector3(2.0, 12.0, -5.5), Vector3.UP)
		await _settle(DETAIL_FRAMES, DETAIL_SECONDS)
		await _capture("harbor_diorama_schooner_detail.png")

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
		_fail("视口纹理为空：" + file_name)
		return
	var absolute := ProjectSettings.globalize_path(OUT_DIR.path_join(file_name))
	var dir := absolute.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(dir)
	if dir_error != OK and not DirAccess.dir_exists_absolute(dir):
		_fail("创建目录失败 %s（error=%d）" % [dir, dir_error])
		return
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("保存 PNG 失败 %s（error=%d）" % [absolute, save_error])
		return
	_saved.append(absolute)
	print("[PASS] 已保存 %s（%dx%d）" % [absolute, image.get_width(), image.get_height()])


func _fail(message: String) -> void:
	_failures += 1
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== 港口样片截图：失败 %d 项，产出 %d 张 ===" % [_failures, _saved.size()])
	quit(0 if _failures == 0 and _saved.size() == 2 else 1)
