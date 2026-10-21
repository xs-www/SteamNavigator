extends TestCase
## Guards the "legacy UV migration B" contract for the ship modules (12 GLBs
## including the modules/SN_Boiler_Unit placeholder), the four gameplay ships and
## the five remaining old town props:
## - every GLB declares external `shared_materials/<texture>.png` images (no
##   embedded/legacy pure-color materials);
## - every surface has baked UVs and an `SN_Tex_*` material with an albedo
##   texture (local box UV for single meshes, root-space for multi-node ships);
## - triangle / mesh totals equal the pre-migration baseline (geometry unchanged);
## - assets inside one category share one `Texture2D` per texture file.

const MODULES_DIR := "res://dev_mods/core/assets/models/modules"
const SHIPS_DIR := "res://dev_mods/core/assets/models/ships"
const PROPS_DIR := "res://dev_mods/core/assets/models/props"
const MODULES := [
	"SN_Boiler_Efficient", "SN_Boiler_Performance", "SN_Boiler_Standard",
	"SN_Boiler_Unit", "SN_Cabin_Passenger", "SN_Cargo_Large_Hold",
	"SN_Cargo_Medium_Hold", "SN_Cargo_Small_Hold", "SN_Nav_Chart_Room",
	"SN_Nav_Spyglass", "SN_Safety_Lifeboat", "SN_Safety_Valve",
]
const SHIPS := [
	"SN_Ironclad", "SN_Paddle_Freighter", "SN_Paddle_Steamer", "SN_Schooner_Fame",
]
const TOWN := [
	"SN_HT_Cargo_Lighter", "SN_HT_Dock_Worker_A", "SN_HT_Dock_Worker_B",
	"SN_HT_Fence_Row", "SN_HT_Rowboat",
]
const EXPECTED_TRIS := {"modules": 7492, "ships": 45968, "town": 1796}
const EXPECTED_MESHES := {"modules": 12, "ships": 101, "town": 5}
const EXPECTED_TEXTURE_COUNT := {"modules": 7, "ships": 9, "town": 8}


func test_legacy_b_assets_use_external_shared_textures() -> void:
	ContentAssetLoader.clear_cache()
	for group in [
		["modules", MODULES_DIR, MODULES],
		["ships", SHIPS_DIR, SHIPS],
		["town", PROPS_DIR, TOWN],
	]:
		var category: String = group[0]
		var base_dir: String = group[1]
		var assets: Array = group[2]
		var total_tris := 0
		var total_meshes := 0
		for asset in assets:
			var path := "%s/%s.glb" % [base_dir, asset]
			var uris := ContentAssetLoader.material_image_uris(path)
			assert_true(uris.size() > 0, "%s reports its material textures" % asset)
			for uri in uris:
				assert_true(uri.begins_with("shared_materials/"),
					"%s texture uri is external: %s" % [asset, uri])
				assert_true(FileAccess.file_exists(base_dir + "/" + uri),
					"%s texture file exists: %s" % [asset, uri])
			var info := _scene_info(path)
			total_tris += int(info["tris"])
			total_meshes += int(info["meshes"])
			assert_eq(int(info["surfaces"]), int(info["uv_surfaces"]),
				"%s has UVs on every surface" % asset)
			assert_eq(int(info["missing_texture"]), 0,
				"%s every material has an albedo texture" % asset)
			for material_name in (info["textures"] as Dictionary).keys():
				assert_true(String(material_name).begins_with("SN_Tex_"),
					"%s material is a shared texture material: %s" % [asset, material_name])
		assert_eq(total_tris, int(EXPECTED_TRIS[category]),
			"%s triangle total is unchanged by the UV/material migration" % category)
		assert_eq(total_meshes, int(EXPECTED_MESHES[category]),
			"%s mesh count is unchanged by the migration" % category)


func test_legacy_b_assets_share_texture_instances_within_category() -> void:
	ContentAssetLoader.clear_cache()
	for group in [
		["modules", MODULES_DIR, MODULES],
		["ships", SHIPS_DIR, SHIPS],
		["town", PROPS_DIR, TOWN],
	]:
		var category: String = group[0]
		var base_dir: String = group[1]
		var assets: Array = group[2]
		var texture_ids := {}
		var material_ids := {}      # material name -> {instance id: true}
		for asset in assets:
			var info := _scene_info("%s/%s.glb" % [base_dir, asset])
			for material_name in (info["textures"] as Dictionary).keys():
				var texture_id := int((info["textures"] as Dictionary)[material_name])
				texture_ids[texture_id] = true
				if not material_ids.has(material_name):
					material_ids[material_name] = {}
				(material_ids[material_name] as Dictionary)[texture_id] = true
		assert_eq(texture_ids.size(), int(EXPECTED_TEXTURE_COUNT[category]),
			"%s assets resolve to one Texture2D per texture file" % category)
		for material_name in material_ids.keys():
			assert_eq((material_ids[material_name] as Dictionary).size(), 1,
				"%s: %s resolves to a single Texture2D instance" % [category, material_name])


func _scene_info(path: String) -> Dictionary:
	var result := {"tris": 0, "meshes": 0, "surfaces": 0, "uv_surfaces": 0,
		"missing_texture": 0, "textures": {}}
	var scene := ContentAssetLoader.load_scene(path)
	if scene == null:
		return result
	var instances: Array[MeshInstance3D] = []
	_collect(scene, instances)
	result["meshes"] = instances.size()
	for instance in instances:
		for surface in instance.mesh.get_surface_count():
			result["surfaces"] = int(result["surfaces"]) + 1
			result["tris"] = int(result["tris"]) + _surface_triangles(instance.mesh, surface)
			var arrays := instance.mesh.surface_get_arrays(surface)
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
			(result["textures"] as Dictionary)[String(standard.resource_name)] = \
				standard.albedo_texture.get_instance_id()
	return result


func _collect(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect(child, output)


func _surface_triangles(mesh: Mesh, surface: int) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
		return int((indices as PackedInt32Array).size() / 3)
	var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
	if vertices is PackedVector3Array:
		return int((vertices as PackedVector3Array).size() / 3)
	return 0
