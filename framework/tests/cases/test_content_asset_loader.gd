extends TestCase
## Guards the shared-texture building GLBs and `ContentAssetLoader`'s external
## texture re-binding:
## - the five iron-harbor building GLBs declare external `image.uri` entries
##   instead of embedded textures;
## - `load_scene()` binds every material albedo texture to the loader's path
##   cache, so two buildings that sample the same trim-sheet cell share ONE
##   `Texture2D` instance (that is what lets `PortStage` merge them into one
##   material batch);
## - the same holds for a GLB mounted from a `.snavmod.zip` (raw loading path);
## - legacy GLBs without external images, and missing files, keep their old
##   behaviour.

const PROPS_DIR := "res://dev_mods/core/assets/models/props"
const ZIP_PROPS_DIR := "res://mods/core/assets/models/props"
const BUILDINGS := [
	"SN_HT_Warehouse_Long",
	"SN_HT_Warehouse_Short",
	"SN_HT_Harbor_Office",
	"SN_HT_Cargo_Shed",
	"SN_HT_Tavern",
]
const EXPECTED_TRIS := {
	"SN_HT_Warehouse_Long": 7436,
	"SN_HT_Warehouse_Short": 3788,
	"SN_HT_Harbor_Office": 10336,
	"SN_HT_Cargo_Shed": 3356,
	"SN_HT_Tavern": 5116,
}
const EXPECTED_CELLS := {
	"SN_HT_Warehouse_Long": 6,
	"SN_HT_Warehouse_Short": 6,
	"SN_HT_Harbor_Office": 6,
	"SN_HT_Cargo_Shed": 5,
	"SN_HT_Tavern": 6,
}


func test_material_image_uris_are_external() -> void:
	ContentAssetLoader.clear_cache()
	for building in BUILDINGS:
		var path := "%s/%s.glb" % [PROPS_DIR, building]
		var uris := ContentAssetLoader.material_image_uris(path)
		assert_eq(uris.size(), int(EXPECTED_CELLS[building]), "%s material count" % building)
		for uri in uris:
			assert_true(uri.begins_with("iron_harbor_shared/"), "%s has an external shared image uri: %s" % [building, uri])
			assert_true(FileAccess.file_exists(PROPS_DIR + "/" + uri), "%s image file exists: %s" % [building, uri])


func test_shared_texture_instances_across_buildings() -> void:
	ContentAssetLoader.clear_cache()
	var textures: Dictionary = {}
	var cells: Dictionary = {}
	for building in BUILDINGS:
		var info := _material_textures("%s/%s.glb" % [PROPS_DIR, building])
		assert_eq(int(info["tris"]), int(EXPECTED_TRIS[building]), "%s triangles" % building)
		assert_eq(int(info["missing_texture"]), 0, "%s has no material without an albedo texture" % building)
		var material_textures: Dictionary = info["textures"]
		textures[building] = material_textures
		var uris := ContentAssetLoader.material_image_uris("%s/%s.glb" % [PROPS_DIR, building])
		for material_name in material_textures.keys():
			var index := _material_index(building, material_name)
			if index >= 0 and index < uris.size():
				cells[uris[index]] = true
	# Same trim-sheet cell across buildings -> same Texture2D instance.
	# Instance ids are 64-bit; compare them as strings so the assertion does not
	# lose precision through the float-based `assert_eq`/`assert_ne` helpers.
	var long_textures: Dictionary = textures["SN_HT_Warehouse_Long"]
	var short_textures: Dictionary = textures["SN_HT_Warehouse_Short"]
	var office_textures: Dictionary = textures["SN_HT_Harbor_Office"]
	assert_true(
		_texture_id(long_textures, "SN_Town_Brick") == _texture_id(short_textures, "SN_Town_Brick"),
		"brick_wall texture is shared between warehouse_long and warehouse_short"
	)
	assert_true(
		_texture_id(long_textures, "SN_Town_Glass") == _texture_id(short_textures, "SN_Town_Glass"),
		"glass_dark texture is shared between warehouse_long and warehouse_short"
	)
	# Different cells must stay distinct.
	assert_true(
		_texture_id(long_textures, "SN_Town_Glass") != _texture_id(office_textures, "SN_Town_Glass"),
		"glass_dark and glass_reflect are different textures"
	)
	# The whole kit resolves to exactly one Texture2D per authored cell.
	var unique_ids: Dictionary = {}
	for building in textures.keys():
		for material_name in textures[building].keys():
			unique_ids[_texture_id(textures[building], material_name)] = true
	assert_eq(unique_ids.size(), 11, "five buildings share 11 unique trim textures")
	assert_eq(cells.size(), 11, "five buildings reference 11 unique image uris")


func test_glb_without_images_keeps_legacy_path() -> void:
	ContentAssetLoader.clear_cache()
	var path := PROPS_DIR + "/SN_HT_Fence_Row.glb"
	var uris := ContentAssetLoader.material_image_uris(path)
	assert_eq(uris.size(), 2, "texture-less GLB still reports its materials")
	for uri in uris:
		assert_eq(uri, "", "texture-less GLB reports no external image uri")
	var scene := ContentAssetLoader.load_scene(path)
	assert_not_null(scene, "texture-less GLB still loads")


func test_missing_glb_fails_once() -> void:
	ContentAssetLoader.clear_cache()
	var path := PROPS_DIR + "/SN_HT_This_File_Does_Not_Exist.glb"
	assert_true(ContentAssetLoader.load_scene(path) == null, "missing GLB returns null")
	assert_true(ContentAssetLoader.load_scene(path) == null, "missing GLB stays null on the second call")


func test_zip_mounted_glb_shares_textures() -> void:
	ContentAssetLoader.clear_cache()
	var pack_path := "user://test_content_asset_loader/core-1.0.0.snavmod.zip"
	assert_true(_pack_core(pack_path), "core zip pack is created")
	assert_true(ProjectSettings.load_resource_pack(pack_path, false), "core zip pack is mounted")
	var long_path := ZIP_PROPS_DIR + "/SN_HT_Warehouse_Long.glb"
	var short_path := ZIP_PROPS_DIR + "/SN_HT_Warehouse_Short.glb"
	for path in [long_path, short_path]:
		var uris := ContentAssetLoader.material_image_uris(path)
		assert_eq(uris.size(), 6, "zip-mounted GLB reports six external images: " + path)
		for uri in uris:
			assert_true(uri.begins_with("iron_harbor_shared/"), "zip-mounted GLB keeps the shared uri prefix")
	var long_info := _material_textures(long_path)
	var short_info := _material_textures(short_path)
	assert_eq(int(long_info["missing_texture"]), 0, "zip-mounted long building has textures")
	assert_eq(int(short_info["missing_texture"]), 0, "zip-mounted short building has textures")
	assert_true(
		_texture_id(long_info["textures"], "SN_Town_Brick") == _texture_id(short_info["textures"], "SN_Town_Brick"),
		"brick texture is shared between ZIP-mounted buildings"
	)
	var unique_ids: Dictionary = {}
	for info in [long_info, short_info]:
		for material_name in (info["textures"] as Dictionary).keys():
			unique_ids[_texture_id(info["textures"], material_name)] = true
	assert_eq(unique_ids.size(), 9, "two ZIP-mounted buildings share nine unique textures")


func _material_textures(path: String) -> Dictionary:
	var result := {"tris": 0, "missing_texture": 0, "textures": {}}
	var scene := ContentAssetLoader.load_scene(path)
	if scene == null:
		return result
	var instances: Array[MeshInstance3D] = []
	_collect(scene, instances)
	for instance in instances:
		for surface in instance.mesh.get_surface_count():
			var triangles := _surface_triangles(instance.mesh, surface)
			result["tris"] = int(result["tris"]) + triangles
			var material := instance.mesh.surface_get_material(surface)
			if material == null or not (material is StandardMaterial3D):
				result["missing_texture"] = int(result["missing_texture"]) + 1
				continue
			var standard := material as StandardMaterial3D
			if standard.albedo_texture == null:
				result["missing_texture"] = int(result["missing_texture"]) + 1
				continue
			(result["textures"] as Dictionary)[String(standard.resource_name)] = standard.albedo_texture.get_instance_id()
	return result


## Texture instance id as a string (64-bit ids lose precision in float asserts).
func _texture_id(textures: Dictionary, material_name: String) -> String:
	if not textures.has(material_name):
		return "<missing:" + material_name + ">"
	return str(textures[material_name])


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


func _material_index(building: String, material_name: String) -> int:
	var path := "%s/%s.glb" % [PROPS_DIR, building]
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20:
		return -1
	var chunk_length := bytes.decode_u32(12)
	var parsed: Variant = JSON.parse_string(bytes.slice(20, 20 + chunk_length).get_string_from_utf8())
	if not (parsed is Dictionary):
		return -1
	var index := 0
	for material in (parsed as Dictionary).get("materials", []):
		if material is Dictionary and String(material.get("name", "")) == material_name:
			return index
		index += 1
	return -1


func _pack_core(pack_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(pack_path.get_base_dir())
	if FileAccess.file_exists(pack_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pack_path))
	var files := PackedStringArray()
	_walk("res://dev_mods/core", "", files)
	var packer := ZIPPacker.new()
	if packer.open(pack_path) != OK:
		return false
	for relative_path in files:
		var bytes := FileAccess.get_file_as_bytes("res://dev_mods/core/" + relative_path)
		if packer.start_file("mods/core/" + relative_path) != OK:
			packer.close()
			return false
		packer.write_file(bytes)
		packer.close_file()
	packer.close()
	return true


func _walk(root: String, relative: String, output: PackedStringArray) -> void:
	var path := root if relative.is_empty() else root + "/" + relative
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		var child := file_name if relative.is_empty() else relative + "/" + file_name
		if file_name.ends_with(".import") or file_name.ends_with(".uid"):
			continue
		output.append(child)
	for directory_name in directory.get_directories():
		var child := directory_name if relative.is_empty() else relative + "/" + directory_name
		_walk(root, child, output)
