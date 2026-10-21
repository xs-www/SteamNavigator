extends SceneTree
## @static-doc
## 作用：四台起重机 GLB 在 Godot 侧的导入验收（只读）：尺寸 / 三角面 / 材质 / 贴地。
##
## 用法：
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/godot/verify_cranes.gd
##
## 判定口径：
## - glTF 由 Blender 的 Z-up 转为 Y-up，因此 Godot 尺寸 = (Blender X, Blender Z, Blender Y)；
## - 尺寸与工单误差 <= 0.05 m；
## - 三角面数必须与 Blender 场景 / GLB 自检完全相等：专门用来抓
##   「改了 .blend 却忘了重导 GLB」或「Godot 读到旧导入缓存」；
## - 包围盒底面 y 必须贴 0（起重机轴心在轨道面 / 地面中心）；
## - 至少 1 个网格节点、1 个材质。
## @end-static-doc

const TOL := 0.05

## 对象名 -> [期望 Godot 尺寸(x,y,z), 期望三角面]
const EXPECTED := {
	"SN_Harbor_Crane": [Vector3(26.50, 21.47, 6.30), 3912],
	"SN_Mega_Gantry": [Vector3(39.60, 29.65, 14.80), 9420],
	"SN_Wooden_Mast_Crane": [Vector3(14.77, 14.25, 7.00), 1932],
	"SN_Hand_Jib_Crane": [Vector3(4.60, 5.17, 1.70), 896],
}


func _init() -> void:
	print("=== 起重机 GLB 导入验收 ===")
	var failed := 0
	var names := EXPECTED.keys()
	names.sort()
	for name in names:
		failed += _check(name)
	print("=== 结果：%d 件，失败 %d 件 ===" % [names.size(), failed])
	quit(0 if failed == 0 else 1)


func _check(name: String) -> int:
	var path := "res://assets/models/props/%s.glb" % name
	var expected: Array = EXPECTED[name]
	var packed := load(path) as PackedScene
	if packed == null:
		print("[FAIL] %s 加载失败：%s" % [name, path])
		return 1

	var root: Node = packed.instantiate()
	var acc := {"meshes": 0, "tris": 0, "mats": {}, "nodes": []}
	for child in root.get_children():
		_walk(child, Transform3D.IDENTITY, acc)
	root.free()

	var ok := true
	var notes: Array[String] = []

	if int(acc["meshes"]) == 0:
		ok = false
		notes.append("没有网格节点")

	var size := Vector3.ZERO
	if acc.has("aabb"):
		size = (acc["aabb"] as AABB).size

	var want: Vector3 = expected[0]
	var delta := (size - want).abs()
	if delta.x > TOL or delta.y > TOL or delta.z > TOL:
		ok = false
		notes.append("尺寸偏差超 %.2f m" % TOL)

	var mat_names: Array = acc["mats"].keys()
	if mat_names.is_empty():
		ok = false
		notes.append("没有材质")

	if int(acc["tris"]) != int(expected[1]):
		ok = false
		notes.append("三角面 %d != 期望 %d" % [int(acc["tris"]), int(expected[1])])

	if (acc["aabb"] as AABB).position.y < -TOL:
		notes.append("底部未贴 y=0（min.y=%.3f）" % (acc["aabb"] as AABB).position.y)

	print("[%s] %s  size=%s  expect=%s  tris=%d  meshes=%d  mats=%s%s" % [
		"PASS" if ok else "FAIL",
		name,
		_fmt(size),
		_fmt(want),
		int(acc["tris"]),
		int(acc["meshes"]),
		",".join(mat_names),
		"" if notes.is_empty() else "  <- " + "；".join(notes),
	])
	return 0 if ok else 1


func _walk(node: Node, parent_xform: Transform3D, acc: Dictionary) -> void:
	var t := parent_xform
	if node is Node3D:
		t = parent_xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var box: AABB = t * mi.mesh.get_aabb()
			if acc.has("aabb"):
				acc["aabb"] = (acc["aabb"] as AABB).merge(box)
			else:
				acc["aabb"] = box
			acc["meshes"] = int(acc["meshes"]) + 1
			acc["tris"] = int(acc["tris"]) + _tri_count(mi.mesh)
			var mats: Dictionary = acc["mats"]
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat != null:
					mats[mat.resource_name if mat.resource_name != "" else mat.get_class()] = true
			(acc["nodes"] as Array).append(String(node.name))
	for child in node.get_children():
		_walk(child, t, acc)


func _tri_count(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null:
			total += idx.size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _fmt(v: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [v.x, v.y, v.z]
