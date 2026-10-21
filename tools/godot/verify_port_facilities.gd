extends SceneTree
## 港口设施锚点 GLB 导入验收（只读）：尺度 / 轴心 / 材质 / 三角面。
##
## 用法：
##   godot --headless --path . --script res://tools/godot/verify_port_facilities.gd
##
## 判定口径：
## - glTF 由 Blender 的 Z-up 转为 Y-up，因此 Godot 尺寸 = (Blender X, Blender Z, Blender Y)；
## - 尺寸与工单 items.size 的误差 <= 0.1 m（龙门吊 Y 含爬梯外凸 14 mm，期望值取实测 4.014）；
## - 包围盒最低点贴地 y=0（原点在底面中心）；
## - 三角面数必须与 EXPECTED 精确相等：抓"改了 .blend 却忘了重导 GLB"或旧导入缓存；
## - 材质名必须全部在调色板内。

const TOL := 0.1

## 对象名 -> [期望 Godot 尺寸(x,y,z), 期望三角面]
const EXPECTED := {
	"SN_Market_Stall": [Vector3(5.0, 3.2, 3.0), 768],
	"SN_Notice_Board": [Vector3(2.8, 2.6, 0.5), 272],
	"SN_Water_Tank": [Vector3(4.0, 5.2, 4.0), 1324],
	"SN_Signal_Tower": [Vector3(3.2, 8.5, 2.4), 1052],
	"SN_Shipyard_Gantry": [Vector3(14.0, 10.0, 4.014), 1064],
	"SN_Dry_Dock": [Vector3(18.0, 2.6, 8.0), 516],
}

const PALETTE := [
	"SN_Tex_Wood", "SN_Tex_Wood_Dark", "SN_Tex_Wood_Deck", "SN_Tex_Metal",
	"SN_Tex_Iron", "SN_Tex_Brass", "SN_Tex_Stone", "SN_Tex_Canvas_Shade",
]


func _init() -> void:
	print("=== 港口设施锚点 GLB 导入验收 ===")
	var failed := 0
	var names := EXPECTED.keys()
	names.sort()
	for name in names:
		failed += _check(name)
	print("=== 结果：%d 件，失败 %d 件 ===" % [names.size(), failed])
	quit(0 if failed == 0 else 1)


func _check(name: String) -> int:
	var path := "res://assets/models/port/%s.glb" % name
	var expected: Array = EXPECTED[name]
	var packed := load(path) as PackedScene
	if packed == null:
		print("[FAIL] %s 加载失败：%s" % [name, path])
		return 1

	var root: Node = packed.instantiate()
	var acc := {"meshes": 0, "tris": 0, "mats": {}}
	_walk(root, Transform3D.IDENTITY, acc)
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
	for m in mat_names:
		if not PALETTE.has(m):
			ok = false
			notes.append("材质不在调色板：%s" % m)

	if int(acc["tris"]) != int(expected[1]):
		ok = false
		notes.append("三角面 %d != 期望 %d" % [int(acc["tris"]), int(expected[1])])

	if (acc["aabb"] as AABB).position.y < -TOL or (acc["aabb"] as AABB).position.y > TOL:
		ok = false
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
