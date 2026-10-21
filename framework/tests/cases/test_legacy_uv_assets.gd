extends TestCase
## Guards the "legacy UV migration A" contract for the 31 iron-harbor props and
## 6 port facilities:
## - every GLB declares external `shared_materials/<texture>.png` images (no
##   embedded/legacy pure-color materials);
## - every surface has baked UVs and an `SN_Tex_*` material with an albedo
##   texture (the box-projected `UVMap` from the migration pass);
## - triangles equal the pre-migration counts (only materials/UVs changed, no
##   geometry edits);
## - assets inside one category share one `Texture2D` per texture file, which is
##   what lets PortStage batch them.

const PROPS_DIR := "res://dev_mods/core/assets/models/props"
const PORT_DIR := "res://dev_mods/core/assets/models/port"
const PROPS := [
	"SN_Barrel", "SN_Bell", "SN_Boiler_Unit", "SN_Buoy", "SN_Capstan",
	"SN_Cargo_Net", "SN_Chain_Coil", "SN_Coal_Chute", "SN_Coal_Pile",
	"SN_Crate", "SN_Dock_Fender", "SN_Dock_Ladder", "SN_Dock_Stairs",
	"SN_Dock_Wall", "SN_Fender_Ball", "SN_Flag_Pole", "SN_Gangway",
	"SN_Gas_Lamp", "SN_Gear_Crate", "SN_Grab_Bucket", "SN_Handcart",
	"SN_Keel_Block", "SN_Mooring_Bollard", "SN_Mooring_Rope", "SN_Ore_Pile",
	"SN_Pallet", "SN_Plate_Stack", "SN_Port_Sign", "SN_Sack_Pile",
	"SN_Steam_Pipe", "SN_Timber_Stack",
]
const PORT := [
	"SN_Dry_Dock", "SN_Market_Stall", "SN_Notice_Board",
	"SN_Shipyard_Gantry", "SN_Signal_Tower", "SN_Water_Tank",
]
const EXPECTED_TRIS := {"props": 6282, "port": 4996}
const EXPECTED_TEXTURE_COUNT := {"props": 7, "port": 7}


func test_legacy_assets_use_external_shared_textures() -> void:
	ContentAssetLoader.clear_cache()
	for group in [["props", PROPS_DIR, PROPS], ["port", PORT_DIR, PORT]]:
		var category: String = group[0]
		var base_dir: String = group[1]
		var assets: Array = group[2]
		var total_tris := 0
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
			assert_eq(int(info["surfaces"]), int(info["uv_surfaces"]),
				"%s has UVs on every surface" % asset)
			assert_eq(int(info["missing_texture"]), 0,
				"%s every material has an albedo texture" % asset)
			for material_name in (info["textures"] as Dictionary).keys():
				assert_true(String(material_name).begins_with("SN_Tex_"),
					"%s material is a shared texture material: %s" % [asset, material_name])
			total_tris += int(info["tris"])
		assert_eq(total_tris, int(EXPECTED_TRIS[category]),
			"%s triangle total is unchanged by the UV/material migration" % category)


func test_legacy_assets_share_texture_instances_within_category() -> void:
	ContentAssetLoader.clear_cache()
	for group in [["props", PROPS_DIR, PROPS], ["port", PORT_DIR, PORT]]:
		var category: String = group[0]
		var base_dir: String = group[1]
		var assets: Array = group[2]
		var texture_ids := {}
		var material_ids := {}      # material name -> {instance id: true}
		var material_owners := {}   # material name -> number of assets using it
		for asset in assets:
			var info := _scene_info("%s/%s.glb" % [base_dir, asset])
			for material_name in (info["textures"] as Dictionary).keys():
				var texture_id := int((info["textures"] as Dictionary)[material_name])
				texture_ids[texture_id] = true
				if not material_ids.has(material_name):
					material_ids[material_name] = {}
					material_owners[material_name] = 0
				(material_ids[material_name] as Dictionary)[texture_id] = true
				material_owners[material_name] = int(material_owners[material_name]) + 1
		assert_eq(texture_ids.size(), int(EXPECTED_TEXTURE_COUNT[category]),
			"%s assets resolve to one Texture2D per texture file" % category)
		for material_name in material_ids.keys():
			assert_eq((material_ids[material_name] as Dictionary).size(), 1,
				"%s: %s resolves to a single Texture2D instance" % [category, material_name])
		assert_true(int(material_owners.get("SN_Tex_Wood", 0)) >= 2,
			"%s: wood material is shared by multiple assets" % category)


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
