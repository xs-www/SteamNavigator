extends SceneTree
## 道具 GLB 导入验收（只读）：尺度 / 朝向 / 材质 / 三角面。
##
## 用法：
##   godot --headless --path . --script res://tools/godot/verify_props.gd
##
## 判定口径：
## - glTF 由 Blender 的 Z-up 转为 Y-up，因此 Godot 尺寸 = (Blender X, Blender Z, Blender Y)；
## - 尺寸与 brief 的误差 <= 0.05 m；
## - 每件至少 1 个网格节点、1 个材质；
## - 三角面数必须与 EXPECTED 精确相等：这条专门用来抓"改了 .blend 却忘了重导 GLB"
##   或"Godot 读到旧导入缓存"。改版资产时同步更新 EXPECTED。

const TOL := 0.05

## 对象名 -> [期望 Godot 尺寸(x,y,z), 期望三角面(0=不校验)]
const EXPECTED := {
	# 第一批（P0 整改后）
	"SN_Dock_Wall": [Vector3(6.0, 3.5, 3.0), 588],
	"SN_Dock_Fender": [Vector3(0.3, 2.5, 0.3), 46],
	"SN_Mooring_Bollard": [Vector3(0.62, 0.70, 0.62), 288],
	"SN_Crate": [Vector3(1.2, 1.2, 1.2), 120],
	"SN_Barrel": [Vector3(0.9, 1.1, 0.9), 168],
	"SN_Ore_Pile": [Vector3(4.0, 1.5, 3.0), 150],
	# 第二批
	"SN_Gas_Lamp": [Vector3(0.35, 3.5, 0.314), 194],
	"SN_Gangway": [Vector3(6.0, 0.52, 1.2), 252],
	"SN_Grab_Bucket": [Vector3(1.494, 1.46, 1.5), 228],
	"SN_Coal_Pile": [Vector3(3.0, 1.17, 2.5), 240],
	"SN_Dock_Ladder": [Vector3(0.608, 3.2, 0.275), 156],
	"SN_Plate_Stack": [Vector3(2.994, 0.55, 2.0), 144],
	# 第三批
	"SN_Timber_Stack": [Vector3(4.0, 1.222, 1.51), 240],
	"SN_Sack_Pile": [Vector3(1.45, 0.795, 0.95), 160],
	"SN_Steam_Pipe": [Vector3(2.04, 0.414, 0.268), 108],
	"SN_Mooring_Rope": [Vector3(0.88, 0.44, 0.9), 172],
	"SN_Cargo_Net": [Vector3(3.0, 0.104, 3.0), 248],
	"SN_Pallet": [Vector3(1.2, 0.135, 1.0), 96],
	# 第四批
	"SN_Buoy": [Vector3(1.141, 1.8, 1.2), 260],
	"SN_Chain_Coil": [Vector3(1.043, 0.266, 0.941), 352],
	"SN_Capstan": [Vector3(1.2, 1.1, 1.2), 292],
	"SN_Handcart": [Vector3(2.02, 1.0, 1.06), 228],
	"SN_Fender_Ball": [Vector3(0.824, 0.9, 0.8), 120],
	"SN_Gear_Crate": [Vector3(0.82, 0.818, 0.858), 200],
	# 第五批
	"SN_Dock_Stairs": [Vector3(3.0, 3.0, 2.0), 120],
	"SN_Port_Sign": [Vector3(2.04, 1.6, 0.25), 120],
	"SN_Bell": [Vector3(0.68, 0.88, 0.536), 176],
	"SN_Flag_Pole": [Vector3(1.424, 6.0, 0.259), 116],
	"SN_Coal_Chute": [Vector3(2.5, 1.5, 1.5), 128],
	"SN_Boiler_Unit": [Vector3(3.0, 2.5, 2.0), 476],
	"SN_Keel_Block": [Vector3(1.2, 0.6, 0.811), 96],
}


func _init() -> void:
	print("=== 道具 GLB 导入验收 ===")
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
	for m in mat_names:
		if not String(m).begins_with("SN_Tex_"):
			ok = false
			notes.append("材质不是 SN_Tex_*：%s" % m)

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
