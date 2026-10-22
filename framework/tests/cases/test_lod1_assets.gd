extends TestCase
## @static-doc
## 作用：LOD1 基础套件（M0-5）的资产守护用例：30 个 `SN_*_LOD1.glb`（kit 26 + 船 4）
## 必须能从 `dev_mods/core` 运行时加载，单 mesh、每个 surface 有 UV、材质全是
## `SN_Tex_*` 且绑定外部 `shared_materials/<texture>.png`；LOD1 三角面必须 ≤ 对应 LOD0
## 的 35%（kit）/ 30%（船），且与 LOD0 世界包围盒逐轴 ≤0.05 m；4 个船的
## `model.ship.*_lod1` manifest 键必须存在并指向真实文件。
##
## 这组用例守护的是「远景低模套件可在 Godot 里被真实加载」，不验证运行时 LOD 切换
##（本批为资产交付，切换属于后续接线）。
## @end-static-doc

const KIT := {
	"SN_Weapon_Cannon": "weapons", "SN_Weapon_GunCarriage": "weapons",
	"SN_Weapon_Turret": "weapons", "SN_Weapon_Pedestal": "weapons",
	"SN_ShipPart_Deck": "ship_parts", "SN_ShipPart_Mast": "ship_parts",
	"SN_ShipPart_Funnel": "ship_parts", "SN_ShipPart_HatchCover": "ship_parts",
	"SN_Machinery_GearSet": "machinery", "SN_Machinery_Winch": "machinery",
	"SN_Machinery_PowerUnit": "machinery",
	"SN_Cargo_Crate": "cargo", "SN_Cargo_CoalScuttle": "cargo",
	"SN_Cargo_Tank": "cargo", "SN_Cargo_Pallet": "cargo",
	"SN_Dock_Structure": "dock", "SN_Dock_Jetty": "dock",
	"SN_Dock_Mooring": "dock",
	"SN_Arch_Warehouse": "architecture", "SN_Arch_Workshop": "architecture",
	"SN_Arch_Tavern": "architecture", "SN_Arch_Factory": "architecture",
	"SN_Env_Reef": "environment", "SN_Env_Wreck": "environment",
	"SN_Env_Lighthouse": "environment", "SN_Env_Buoy": "environment",
}
const SHIPS := {
	"SN_Ironclad": "ships", "SN_Paddle_Freighter": "ships",
	"SN_Paddle_Steamer": "ships", "SN_Schooner_Fame": "ships",
}
const CAP_RATIO := {"kit": 0.35, "ship": 0.30}
const EXPECTED_TRIS := {"kit": 10824, "ship": 9026}
const EXPECTED_LOD0_TRIS := {"kit": 42058, "ship": 45296}  # 2026-10-22 铁甲舰炮管拆出为独立模块（-672 tri）
const MANIFEST_LOD1 := {
	"model.ship.ironclad_lod1": "assets/models/ships/SN_Ironclad_LOD1.glb",
	"model.ship.paddle_freighter_lod1": "assets/models/ships/SN_Paddle_Freighter_LOD1.glb",
	"model.ship.paddle_steamer_lod1": "assets/models/ships/SN_Paddle_Steamer_LOD1.glb",
	"model.ship.schooner_fame_lod1": "assets/models/ships/SN_Schooner_Fame_LOD1.glb",
}
const CORE_ROOT := "res://dev_mods/core/assets/models"


func test_lod1_assets_load_as_single_mesh_with_shared_textures() -> void:
	ContentAssetLoader.clear_cache()
	for group in [["kit", KIT], ["ship", SHIPS]]:
		var kind: String = group[0]
		var assets: Dictionary = group[1]
		var total_tris := 0
		for asset in assets.keys():
			var category: String = assets[asset]
			var path := "%s/%s/%s_LOD1.glb" % [CORE_ROOT, category, asset]
			assert_true(FileAccess.file_exists(path), "%s LOD1 exists in core" % asset)
			var uris := ContentAssetLoader.material_image_uris(path)
			assert_true(uris.size() > 0, "%s LOD1 declares material images" % asset)
			for uri in uris:
				assert_true(String(uri).begins_with("shared_materials/"),
					"%s LOD1 texture is external: %s" % [asset, uri])
				assert_true(FileAccess.file_exists("%s/%s/shared_materials/%s" % [
					CORE_ROOT, category, String(uri).get_file()]),
					"%s LOD1 texture file exists: %s" % [asset, uri])
			var info := _scene_metrics(path)
			assert_eq(int(info["meshes"]), 1, "%s LOD1 is a single mesh" % asset)
			assert_true(int(info["surfaces"]) > 0, "%s LOD1 has surfaces" % asset)
			assert_eq(int(info["uv_surfaces"]), int(info["surfaces"]),
				"%s LOD1 has UV on every surface" % asset)
			assert_eq(int(info["missing_texture"]), 0,
				"%s LOD1 every material has an albedo texture" % asset)
			for material_name in (info["materials"] as Dictionary).keys():
				assert_true(String(material_name).begins_with("SN_Tex_"),
					"%s LOD1 material is a shared texture material: %s" % [
						asset, material_name])
			total_tris += int(info["tris"])
		assert_eq(total_tris, int(EXPECTED_TRIS[kind]),
			"%s LOD1 triangle total matches the accepted build" % kind)


func test_lod1_assets_within_budget_and_match_lod0_bounds() -> void:
	ContentAssetLoader.clear_cache()
	for group in [["kit", KIT], ["ship", SHIPS]]:
		var kind: String = group[0]
		var assets: Dictionary = group[1]
		var total_lod0 := 0
		for asset in assets.keys():
			var category: String = assets[asset]
			var lod0_path := "%s/%s/%s.glb" % [CORE_ROOT, category, asset]
			var lod1_path := "%s/%s/%s_LOD1.glb" % [CORE_ROOT, category, asset]
			var lod0 := _scene_metrics(lod0_path)
			var lod1 := _scene_metrics(lod1_path)
			total_lod0 += int(lod0["tris"])
			var ratio := float(lod1["tris"]) / float(maxi(1, int(lod0["tris"])))
			assert_true(int(lod1["tris"]) >= 24, "%s LOD1 keeps enough geometry" % asset)
			assert_true(ratio <= float(CAP_RATIO[kind]) + 0.0001,
				"%s LOD1 tri ratio %.3f <= cap %.2f" % [asset, ratio, CAP_RATIO[kind]])
			var bounds0: AABB = lod0["aabb"]
			var bounds1: AABB = lod1["aabb"]
			for axis in 3:
				assert_almost_eq(bounds1.size[axis], bounds0.size[axis], 0.05,
					"%s LOD1 bbox size axis %d matches LOD0" % [asset, axis])
				assert_almost_eq(bounds1.position[axis], bounds0.position[axis], 0.05,
					"%s LOD1 bbox origin axis %d matches LOD0" % [asset, axis])
		assert_eq(total_lod0, int(EXPECTED_LOD0_TRIS[kind]),
			"%s LOD0 triangle total unchanged by the LOD1 batch" % kind)


func test_lod1_ship_manifest_keys_resolve() -> void:
	var manifest_path := "res://dev_mods/core/manifest.json"
	assert_true(FileAccess.file_exists(manifest_path), "core manifest exists")
	var text := FileAccess.get_file_as_string(manifest_path)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "core manifest parses")
	var assets: Dictionary = (parsed as Dictionary).get("assets", {})
	for key in MANIFEST_LOD1.keys():
		assert_eq(String(assets.get(key, "")), String(MANIFEST_LOD1[key]),
			"manifest %s maps to its LOD1 path" % key)
		assert_true(FileAccess.file_exists("res://dev_mods/core/%s" % MANIFEST_LOD1[key]),
			"manifest %s target file exists" % key)


func _scene_metrics(path: String) -> Dictionary:
	var result := {"tris": 0, "meshes": 0, "surfaces": 0, "uv_surfaces": 0,
		"missing_texture": 0, "materials": {}, "aabb": AABB()}
	var scene := ContentAssetLoader.load_scene(path)
	if scene == null:
		return result
	var bounds := AABB()
	var has_bounds := false
	var stack: Array = [[scene, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var parent: Transform3D = entry[1]
		var local: Transform3D = node.transform if node is Node3D else Transform3D.IDENTITY
		var world: Transform3D = parent * local
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var instance := node as MeshInstance3D
			result["meshes"] = int(result["meshes"]) + 1
			var mesh_bounds := world * instance.mesh.get_aabb()
			bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
			has_bounds = true
			for surface in instance.mesh.get_surface_count():
				result["surfaces"] = int(result["surfaces"]) + 1
				var arrays := instance.mesh.surface_get_arrays(surface)
				result["tris"] = int(result["tris"]) + _surface_triangles(instance.mesh, surface)
				var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
				if uv is PackedVector2Array and (uv as PackedVector2Array).size() > 0:
					result["uv_surfaces"] = int(result["uv_surfaces"]) + 1
				var material := instance.mesh.surface_get_material(surface)
				if material == null or not (material is StandardMaterial3D):
					result["missing_texture"] = int(result["missing_texture"]) + 1
					continue
				var standard := material as StandardMaterial3D
				if standard.albedo_texture == null:
					result["missing_texture"] = int(result["missing_texture"]) + 1
					continue
				(result["materials"] as Dictionary)[String(standard.resource_name)] = true
		for child in node.get_children():
			stack.append([child, world])
	result["aabb"] = bounds
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
