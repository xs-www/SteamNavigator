extends SceneTree
## 港口样片验收（只读）：场景能加载、水面用自定义着色器、船会随波浪动。
##
## 用法：
##   godot --headless --path . --script res://tools/godot/verify_harbor_diorama.gd
##
## 判定口径：
## - 场景实例化不报错，包含 Camera3D / DirectionalLight3D / WorldEnvironment；
## - Water 节点使用 harbor_water.gdshader 的 ShaderMaterial；
## - 船体挂载 bobbing_boat.gd；手动推进 2 秒 _process 后位置与旋转都发生变化；
## - 场景不属于主场景（project.godot 的 run/main_scene 不应指向它）。

const SCENE_PATH := "res://dev_scenes/harbor/harbor_diorama.tscn"
const BOAT_SCRIPT := "res://dev_scenes/harbor/bobbing_boat.gd"
const WATER_SHADER := "res://assets/shaders/water/harbor_water.gdshader"

var _failed := 0


func _init() -> void:
	_run()


func _run() -> void:
	# 先等一帧，让场景 _ready 执行完，再手动推进船体动画。
	await process_frame
	print("=== 港口样片验收 ===")
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("场景加载失败：" + SCENE_PATH)
		_finish()
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)

	_check_nodes(scene)
	_check_water(scene)
	_check_boat(scene)
	_check_main_scene_untouched()

	scene.queue_free()
	_finish()


func _check_nodes(scene: Node) -> void:
	_expect(scene.find_child("Camera3D", true, false) != null, "有 Camera3D")
	_expect(scene.find_child("Sun", true, false) != null, "有主方向光 Sun")
	_expect(scene.find_child("WorldEnvironment", true, false) != null, "有 WorldEnvironment")
	var instances := 0
	for node in scene.find_children("*", "Node3D", true, false):
		if node.scene_file_path.ends_with(".glb") or node.scene_file_path.ends_with(".tscn"):
			instances += 1
	print("[INFO] 场景内嵌场景实例：%d" % instances)
	_expect(instances >= 20, "至少复用 20 个已有模型实例")

	# 浮船已从旧 SN_Ship_Prototype 换成 1795 双桅纵帆船 SN_Schooner_Fame。
	var ship := scene.find_child("SN_Schooner_Fame", true, false)
	_expect(ship != null, "有 SN_Schooner_Fame 纵帆船实例")
	_expect(scene.find_child("SN_Ship_Prototype", true, false) == null,
		"旧 SN_Ship_Prototype 已不在港口场景")
	if ship != null:
		var meshes := ship.find_children("*", "MeshInstance3D", true, false)
		print("[INFO] SN_Schooner_Fame 网格实例：%d" % meshes.size())
		_expect(meshes.size() >= 20, "纵帆船网格实例 >= 20")
		var has_flag := false
		for node in meshes:
			if String(node.name).contains("Flag"):
				has_flag = true
		_expect(not has_flag, "纵帆船不含星条旗 / Flag 网格")


func _check_water(scene: Node) -> void:
	var water := scene.find_child("Water", true, false) as MeshInstance3D
	_expect(water != null, "有水面节点 Water")
	if water == null:
		return
	var material := water.material_override as ShaderMaterial
	_expect(material != null, "水面使用 ShaderMaterial")
	if material == null:
		return
	_expect(material.shader != null and material.shader.resource_path == WATER_SHADER, "水面使用 " + WATER_SHADER)
	_expect(material.shader.code.contains("swell"), "水面着色器含波浪函数 swell()")
	_expect(material.shader.code.contains("EMISSION"), "水面着色器含菲涅耳反射项")


func _check_boat(scene: Node) -> void:
	var boat := scene.find_child("ShipBob", true, false) as Node3D
	_expect(boat != null, "有浮船节点 ShipBob")
	if boat == null:
		return
	_expect(boat.get_script() != null and boat.get_script().resource_path == BOAT_SCRIPT, "船体挂载 " + BOAT_SCRIPT)
	_expect(boat.get_child_count() > 0, "船体实例已挂到 ShipBob")
	var start_position := boat.position
	var start_rotation := boat.rotation
	for i in 60:
		boat._process(1.0 / 30.0)
	var moved := boat.position.distance_to(start_position)
	var turned := (boat.rotation - start_rotation).length()
	print("[INFO] 2 秒后：升沉位移 %.4f m，姿态变化 %.4f rad" % [moved, turned])
	_expect(moved > 0.001, "船体会随波升沉")
	_expect(turned > 0.001, "船体会随波摇晃")


func _check_main_scene_untouched() -> void:
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	print("[INFO] 主场景：%s" % main_scene)
	_expect(main_scene != SCENE_PATH, "港口样片没有接入主场景")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failed += 1
	print("[FAIL] " + message)


func _finish() -> void:
	print("=== 结果：失败 %d 项 ===" % _failed)
	quit(0 if _failed == 0 else 1)
