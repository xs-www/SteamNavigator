extends TestCase
## Guards the batch-5 base-kit production-building contract for the five M1-2
## assets (sawmill / smelter / foundry / stockyard / defense tower):
## - every GLB declares external `shared_materials/<texture>.png` images (no
##   embedded textures, no legacy pure-color materials);
## - every surface has baked UVs and an `SN_Tex_*` material with an albedo
##   texture;
## - triangle totals stay at the delivered modeling budget so future edits that
##   silently change geometry are caught;
## - all five assets resolve one shared `Texture2D` per texture file, which is
##   what lets a base stage batch them with the existing kit.

const BASE_DIR := "res://dev_mods/core/assets/models/base"
const ASSETS := [
	"SN_Base_Sawmill",
	"SN_Base_Smelter",
	"SN_Base_Foundry",
	"SN_Base_Stockyard",
	"SN_Base_Defense_Tower",
]
const EXPECTED_TRIS := {
	"SN_Base_Sawmill": 2684,
	"SN_Base_Smelter": 3012,
	"SN_Base_Foundry": 4096,
	"SN_Base_Stockyard": 3260,
	"SN_Base_Defense_Tower": 2896,
}
const EXPECTED_TOTAL_TRIS := 15948
const EXPECTED_TEXTURE_COUNT := 11


func test_base_kit_assets_use_external_shared_textures() -> void:
	ContentAssetLoader.clear_cache()
	var total_tris := 0
	for asset in ASSETS:
		var path := "%s/%s.glb" % [BASE_DIR, asset]
		var uris := ContentAssetLoader.material_image_uris(path)
		assert_true(uris.size() > 0, "%s reports its material textures" % asset)
		for uri in uris:
			assert_true(uri.begins_with("shared_materials/"),
				"%s texture uri is external: %s" % [asset, uri])
			assert_true(FileAccess.file_exists(BASE_DIR + "/" + uri),
				"%s texture file exists: %s" % [asset, uri])
		var info := _scene_info(path)
		assert_eq(int(info["surfaces"]), int(info["uv_surfaces"]),
			"%s has UVs on every surface" % asset)
		assert_eq(int(info["missing_texture"]), 0,
			"%s every material has an albedo texture" % asset)
		for material_name in (info["textures"] as Dictionary).keys():
			assert_true(String(material_name).begins_with("SN_Tex_"),
				"%s material is a shared texture material: %s" % [asset, material_name])
		var tris := int(info["tris"])
		assert_eq(tris, int(EXPECTED_TRIS[asset]),
			"%s triangle count matches the delivered asset" % asset)
		total_tris += tris
	assert_eq(total_tris, EXPECTED_TOTAL_TRIS,
		"batch-5 base kit total triangle budget is locked")


func test_base_kit_assets_share_texture_instances() -> void:
	ContentAssetLoader.clear_cache()
	var texture_ids := {}
	var material_ids := {}      # material name -> {instance id: true}
	for asset in ASSETS:
		var info := _scene_info("%s/%s.glb" % [BASE_DIR, asset])
		for material_name in (info["textures"] as Dictionary).keys():
			var texture_id := int((info["textures"] as Dictionary)[material_name])
			texture_ids[texture_id] = true
			if not material_ids.has(material_name):
				material_ids[material_name] = {}
			(material_ids[material_name] as Dictionary)[texture_id] = true
	assert_eq(texture_ids.size(), EXPECTED_TEXTURE_COUNT,
		"batch-5 assets resolve to one Texture2D per shared texture file")
	for material_name in material_ids.keys():
		assert_eq((material_ids[material_name] as Dictionary).size(), 1,
			"%s resolves to a single Texture2D instance" % material_name)


func _scene_info(path: String) -> Dictionary:
	var result := {"tris": 0, "surfaces": 0, "uv_surfaces": 0,
		"missing_texture": 0, "textures": {}}
	var scene := ContentAssetLoader.load_scene(path)
	if scene == null:
		return result
	var instances: Array[MeshInstance3D] = []
	_collect(scene, instances)
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
