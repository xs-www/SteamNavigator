extends SceneTree
## @static-doc
## 作用：LOD1 基础套件（M0-5）的 Godot 运行时验收探针（只读、无头可跑）：把 30 个
## `dev_mods/core/assets/models/<category>/SN_*_LOD1.glb` 走 `ContentAssetLoader.load_scene()`
## 真实加载，核对「单 mesh / 每个 surface 有 UV / 材质全是 `SN_Tex_*` 且绑定 albedo
## 贴图 / 外部 `shared_materials/<texture>.png` 都存在 / 三角面等于验收表」，并汇总
## kit 10 824 tri、船 9 026 tri 两组总量。
##
## 用法：
##   godot --headless --path . --script res://tools/godot/verify_lod1_kit_ships.gd
##
## 判定口径：任何一件缺文件 / 加载失败 / 多 mesh / 缺 UV / 缺贴图 / tri 不等于验收表
## 都记 failure 并以退出码 1 结束；该脚本只验证资产可加载，不验证运行时 LOD 切换。
## @end-static-doc

const CORE_ROOT := "res://dev_mods/core/assets/models"
const SHARED_URI := "shared_materials/"
const CAP_RATIO := {"kit": 0.35, "ship": 0.30}
const EXPECTED_TOTAL := {"kit": 10824, "ship": 9026}
const ASSETS := [
	{"asset": "SN_Weapon_Cannon", "kind": "kit", "category": "weapons", "lod0": 1156, "lod1": 336},
	{"asset": "SN_Weapon_GunCarriage", "kind": "kit", "category": "weapons", "lod0": 2256, "lod1": 596},
	{"asset": "SN_Weapon_Turret", "kind": "kit", "category": "weapons", "lod0": 1904, "lod1": 482},
	{"asset": "SN_Weapon_Pedestal", "kind": "kit", "category": "weapons", "lod0": 940, "lod1": 246},
	{"asset": "SN_ShipPart_Deck", "kind": "kit", "category": "ship_parts", "lod0": 576, "lod1": 142},
	{"asset": "SN_ShipPart_Mast", "kind": "kit", "category": "ship_parts", "lod0": 2764, "lod1": 780},
	{"asset": "SN_ShipPart_Funnel", "kind": "kit", "category": "ship_parts", "lod0": 1528, "lod1": 392},
	{"asset": "SN_ShipPart_HatchCover", "kind": "kit", "category": "ship_parts", "lod0": 840, "lod1": 210},
	{"asset": "SN_Machinery_GearSet", "kind": "kit", "category": "machinery", "lod0": 2020, "lod1": 494},
	{"asset": "SN_Machinery_Winch", "kind": "kit", "category": "machinery", "lod0": 1776, "lod1": 498},
	{"asset": "SN_Machinery_PowerUnit", "kind": "kit", "category": "machinery", "lod0": 2260, "lod1": 618},
	{"asset": "SN_Cargo_Crate", "kind": "kit", "category": "cargo", "lod0": 672, "lod1": 150},
	{"asset": "SN_Cargo_CoalScuttle", "kind": "kit", "category": "cargo", "lod0": 588, "lod1": 146},
	{"asset": "SN_Cargo_Tank", "kind": "kit", "category": "cargo", "lod0": 1820, "lod1": 462},
	{"asset": "SN_Cargo_Pallet", "kind": "kit", "category": "cargo", "lod0": 316, "lod1": 84},
	{"asset": "SN_Dock_Structure", "kind": "kit", "category": "dock", "lod0": 1628, "lod1": 434},
	{"asset": "SN_Dock_Jetty", "kind": "kit", "category": "dock", "lod0": 1660, "lod1": 468},
	{"asset": "SN_Dock_Mooring", "kind": "kit", "category": "dock", "lod0": 940, "lod1": 286},
	{"asset": "SN_Arch_Warehouse", "kind": "kit", "category": "architecture", "lod0": 2704, "lod1": 626},
	{"asset": "SN_Arch_Workshop", "kind": "kit", "category": "architecture", "lod0": 1996, "lod1": 444},
	{"asset": "SN_Arch_Tavern", "kind": "kit", "category": "architecture", "lod0": 2884, "lod1": 600},
	{"asset": "SN_Arch_Factory", "kind": "kit", "category": "architecture", "lod0": 3020, "lod1": 768},
	{"asset": "SN_Env_Reef", "kind": "kit", "category": "environment", "lod0": 1944, "lod1": 556},
	{"asset": "SN_Env_Wreck", "kind": "kit", "category": "environment", "lod0": 1046, "lod1": 268},
	{"asset": "SN_Env_Lighthouse", "kind": "kit", "category": "environment", "lod0": 1952, "lod1": 482},
	{"asset": "SN_Env_Buoy", "kind": "kit", "category": "environment", "lod0": 868, "lod1": 256},
	{"asset": "SN_Paddle_Freighter", "kind": "ship", "category": "ships", "lod0": 12200, "lod1": 2507},
	{"asset": "SN_Paddle_Steamer", "kind": "ship", "category": "ships", "lod0": 11764, "lod1": 2379},
	{"asset": "SN_Schooner_Fame", "kind": "ship", "category": "ships", "lod0": 13174, "lod1": 2484},
	{"asset": "SN_Ironclad", "kind": "ship", "category": "ships", "lod0": 8158, "lod1": 1656},
]

var _failures: Array[String] = []
var _totals := {"kit": 0, "ship": 0}
var _texture_ids := {}


func _init() -> void:
	print("=== LOD1 基础套件（M0-5）· Godot 运行时验收 ===")
	for entry in ASSETS:
		_check(entry)
	for kind in EXPECTED_TOTAL.keys():
		if int(_totals[kind]) != int(EXPECTED_TOTAL[kind]):
			_failures.append("%s: tri total %d != %d" % [
				kind, int(_totals[kind]), int(EXPECTED_TOTAL[kind])])
	print("=== 结果：%d 件 / %d 个共享贴图实例 / 失败 %d 项 ===" % [
		ASSETS.size(), _texture_ids.size(), _failures.size()])
	for failure in _failures:
		print("  FAIL: " + failure)
	for scene in ContentAssetLoader._scenes.values():
		if scene is Node and is_instance_valid(scene):
			scene.free()
	ContentAssetLoader.clear_cache()
	quit(0 if _failures.is_empty() else 1)


func _check(entry: Dictionary) -> void:
	var asset: String = entry["asset"]
	var kind: String = entry["kind"]
	var category: String = entry["category"]
	var base := "%s/%s" % [CORE_ROOT, category]
	var path := "%s/%s_LOD1.glb" % [base, asset]
	if not FileAccess.file_exists(path):
		_failures.append("%s: missing %s" % [asset, path])
		return
	var uris := ContentAssetLoader.material_image_uris(path)
	if uris.is_empty():
		_failures.append("%s: no external material images" % asset)
	for uri in uris:
		if not String(uri).begins_with(SHARED_URI):
			_failures.append("%s: uri not shared_materials/: %s" % [asset, uri])
			continue
		if not FileAccess.file_exists("%s/%s" % [base, uri]):
			_failures.append("%s: texture missing: %s" % [asset, uri])
	var scene := ContentAssetLoader.load_scene(path)
	if scene == null:
		_failures.append("%s: GLB load failed" % asset)
		return
	var metrics := _metrics(scene)
	if int(metrics["meshes"]) != 1:
		_failures.append("%s: mesh nodes %d != 1" % [asset, int(metrics["meshes"])])
	if int(metrics["surfaces"]) <= 0:
		_failures.append("%s: no surfaces" % asset)
	if int(metrics["uv"]) != int(metrics["surfaces"]):
		_failures.append("%s: UV missing (%d/%d)" % [
			asset, int(metrics["uv"]), int(metrics["surfaces"])])
	if int(metrics["tris"]) != int(entry["lod1"]):
		_failures.append("%s: tris %d != accepted %d" % [
			asset, int(metrics["tris"]), int(entry["lod1"])])
	var ratio := float(entry["lod1"]) / float(maxi(1, int(entry["lod0"])))
	if ratio > float(CAP_RATIO[kind]) + 0.0001:
		_failures.append("%s: ratio %.3f > cap %.2f" % [asset, ratio, CAP_RATIO[kind]])
	for material_name in (metrics["materials"] as Dictionary).keys():
		if not String(material_name).begins_with("SN_Tex_"):
			_failures.append("%s: material not SN_Tex_*: %s" % [asset, material_name])
		var texture_id := int((metrics["materials"] as Dictionary)[material_name])
		_texture_ids[texture_id] = true
	_totals[kind] = int(_totals[kind]) + int(metrics["tris"])
	print("%-26s %-5s L0 %5d L1 %4d (%.3f) mesh=%d surfaces=%d uv=%d" % [
		asset, kind, int(entry["lod0"]), int(metrics["tris"]), ratio,
		int(metrics["meshes"]), int(metrics["surfaces"]), int(metrics["uv"])])


func _metrics(scene: Node) -> Dictionary:
	var result := {"meshes": 0, "surfaces": 0, "uv": 0, "tris": 0, "materials": {}}
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var instance := node as MeshInstance3D
			result["meshes"] = int(result["meshes"]) + 1
			for surface in instance.mesh.get_surface_count():
				result["surfaces"] = int(result["surfaces"]) + 1
				var arrays := instance.mesh.surface_get_arrays(surface)
				var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
				if uv is PackedVector2Array and (uv as PackedVector2Array).size() > 0:
					result["uv"] = int(result["uv"]) + 1
				result["tris"] = int(result["tris"]) + _surface_triangles(instance.mesh, surface)
				var material := instance.mesh.surface_get_material(surface)
				if material is StandardMaterial3D:
					var standard := material as StandardMaterial3D
					if standard.albedo_texture != null:
						(result["materials"] as Dictionary)[String(standard.resource_name)] = \
							standard.albedo_texture.get_instance_id()
		for child in node.get_children():
			stack.append(child)
	return result


func _surface_triangles(mesh: Mesh, surface: int) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
		return int((indices as PackedInt32Array).size() / 3)
	var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
	if vertices is PackedVector3Array:
		return int((vertices as PackedVector3Array).size() / 3)
	return 0
