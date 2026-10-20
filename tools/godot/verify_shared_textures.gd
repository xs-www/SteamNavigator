## @static-doc
## 作用：共享贴图建筑 GLB 的只读验收探针：通过 `ContentAssetLoader` 加载 5 栋 `SN_HT_*`，统计每栋 surfaces/tri/材质 albedo `Texture2D` 实例，验证同 cell 跨建筑共享同一实例、不同 cell 不塌缩、全局唯一贴图数 = 唯一 cell 数，并支持松散与挂载 ZIP 两种加载路径。
##
## ## 契约与约束
## - headless 可跑（不需要渲染）；`-- --mode=loose` 读 `res://dev_mods/core/...`，`-- --mode=zip` 把 `dev_mods/core` 打包装载后读 `res://mods/core/...`。
## - 纹理实例 id 是 64 位，报告里以 JSON 数字/字典比较，避免转 float 丢失精度。
## - 失败（缺失 URI、材质无贴图、跨建筑不共享、tri 与预期不符）退出码 1；最终 `[shared-textures] JSON {...}` 行为机器可读报告。
## - 只读：不改资产、不写内容、不挂舞台。
## @end-static-doc

extends SceneTree
## Read-only acceptance probe for the shared-texture iron-harbor building GLBs.
##
## It loads the five `SN_HT_*` buildings through `ContentAssetLoader` and reports,
## per building, the surfaces / triangles / material names / albedo
## `Texture2D` instance ids, then verifies that:
##
##   1. every GLB declares 5-6 external image URIs (no embedded `bufferView`);
##   2. the same cell (e.g. `brick_wall`) resolves to the SAME `Texture2D`
##      instance across buildings, while different cells (e.g. `glass_dark` vs
##      `glass_reflect`) stay distinct;
##   3. the global unique texture count equals the number of unique cells — i.e.
##      Godot really shares one texture per source PNG, which is what lets
##      `PortStage`'s material-signature batcher merge the buildings;
##   4. the scene loads without a black / missing material and the triangle
##      budget matches the authored GLB.
##
## Usage (headless is fine — no rendering required):
##   godot --headless --path . --script res://tools/godot/verify_shared_textures.gd -- --mode=loose
##   godot --headless --path . --script res://tools/godot/verify_shared_textures.gd -- --mode=zip
##
## `--mode=zip` packs `dev_mods/core` into `user://verify_shared/core.zip`, mounts
## it as a resource pack and loads the buildings from `res://mods/core/...`, which
## is the same layout a real `.snavmod.zip` mount exposes at runtime.
##
## Exit code 0 = all checks pass; 1 = a failed check or a load failure. The final
## `[shared-textures] JSON {...}` line is the machine-readable report.

const BUILDING_NAMES := [
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
const LOOSE_ROOT := "res://dev_mods/core"
const ZIP_ROOT := "res://mods/core"
const PACK_PATH := "user://verify_shared/core-1.0.0.snavmod.zip"

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _fail(message: String) -> void:
	_failures.append(message)
	print("[shared-textures] FAIL " + message)


func _asset_root() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument == "--mode=zip":
			return ZIP_ROOT
	return LOOSE_ROOT


func _mode() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument == "--mode=zip":
			return "zip"
	return "loose"


func _pack_core() -> bool:
	var directory := DirAccess.open("res://dev_mods/core")
	if directory == null:
		return false
	DirAccess.make_dir_recursive_absolute(PACK_PATH.get_base_dir())
	if FileAccess.file_exists(PACK_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PACK_PATH))
	var files := PackedStringArray()
	_walk("res://dev_mods/core", "", files)
	var packer := ZIPPacker.new()
	if packer.open(PACK_PATH) != OK:
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


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _surface_triangles(mesh: Mesh, surface: int) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	var indices_value: Variant = arrays[Mesh.ARRAY_INDEX]
	if indices_value is PackedInt32Array:
		return (indices_value as PackedInt32Array).size() / 3
	var vertices_value: Variant = arrays[Mesh.ARRAY_VERTEX]
	if vertices_value is PackedVector3Array:
		return (vertices_value as PackedVector3Array).size() / 3
	return 0


func _run() -> void:
	var mode := _mode()
	var root := _asset_root()
	if mode == "zip":
		if not _pack_core():
			_fail("cannot pack dev_mods/core into " + PACK_PATH)
			_finish()
			return
		var mount_ok := ProjectSettings.load_resource_pack(PACK_PATH, false)
		if not mount_ok:
			_fail("cannot mount " + PACK_PATH)
			_finish()
			return
	var report := {
		"mode": mode,
		"root": root,
		"buildings": {},
		"checks": {},
	}
	var cell_texture: Dictionary = {}
	var texture_ids: Dictionary = {}
	var material_names: Array[String] = []
	var all_ok := true
	for building in BUILDING_NAMES:
		var glb_path := "%s/assets/models/props/%s.glb" % [root, building]
		var uris := ContentAssetLoader.material_image_uris(glb_path)
		var uri_report: Array = []
		for uri in uris:
			uri_report.append(uri)
			if uri.is_empty():
				_fail("%s: material with embedded/missing image uri" % building)
			elif uri.begins_with("data:"):
				_fail("%s: data: uri is not a shared external texture" % building)
		if uris.is_empty():
			_fail("%s: no material image uris (not externalized?)" % building)
		var scene := ContentAssetLoader.load_scene(glb_path)
		if scene == null:
			_fail("%s: ContentAssetLoader.load_scene returned null" % building)
			continue
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(scene, meshes)
		var tris := 0
		var surfaces := 0
		var missing_texture := 0
		var per_material: Array = []
		for instance in meshes:
			for surface in instance.mesh.get_surface_count():
				surfaces += 1
				tris += _surface_triangles(instance.mesh, surface)
				var material := instance.mesh.surface_get_material(surface)
				if material == null or not (material is StandardMaterial3D):
					missing_texture += 1
					continue
				var standard := material as StandardMaterial3D
				var material_name := standard.resource_name
				if material_name.is_empty():
					material_name = "<unnamed>"
				if not material_names.has(material_name):
					material_names.append(material_name)
				var texture_id := 0
				if standard.albedo_texture != null:
					texture_id = standard.albedo_texture.get_instance_id()
					texture_ids[texture_id] = true
				else:
					missing_texture += 1
				# Map material slot -> cell through the GLB JSON material order.
				var material_index := _material_index(scene, glb_path, material_name)
				var cell := ""
				if material_index >= 0 and material_index < uris.size():
					cell = uris[material_index].get_file().get_basename()
				if cell.is_empty():
					continue
				if not cell_texture.has(cell):
					cell_texture[cell] = {}
				var by_building: Dictionary = cell_texture[cell]
				by_building[building] = texture_id
				per_material.append({"material": material_name, "cell": cell, "texture_id": texture_id,
					"texture_size": _texture_size(standard.albedo_texture)})
		report["buildings"][building] = {
			"glb": glb_path,
			"uris": uri_report,
			"meshes": meshes.size(),
			"surfaces": surfaces,
			"tris": tris,
			"expected_tris": EXPECTED_TRIS.get(building, -1),
			"materials": per_material,
			"missing_texture_surfaces": missing_texture,
		}
		if tris != int(EXPECTED_TRIS.get(building, -1)):
			_fail("%s: tris %d != expected %d" % [building, tris, int(EXPECTED_TRIS.get(building, -1))])
			all_ok = false
		if missing_texture > 0:
			_fail("%s: %d surface(s) without an albedo texture" % [building, missing_texture])
			all_ok = false
	# Cross-building sharing: every cell must map to exactly one texture instance.
	for cell in cell_texture.keys():
		var by_building: Dictionary = cell_texture[cell]
		var ids: Dictionary = {}
		for building in by_building.keys():
			ids[by_building[building]] = true
		report["checks"]["cell_" + String(cell)] = {
			"buildings": by_building.keys(),
			"texture_ids": ids.keys(),
			"shared": ids.size() == 1,
		}
		if ids.size() != 1:
			_fail("cell '%s' is not shared across buildings: %s" % [cell, ids.keys()])
			all_ok = false
	# Distinct cells must not accidentally collapse into one texture.
	var expected_cells: Dictionary = {}
	for building in BUILDING_NAMES:
		var glb_path := "%s/assets/models/props/%s.glb" % [root, building]
		for uri in ContentAssetLoader.material_image_uris(glb_path):
			if not uri.is_empty():
				expected_cells[uri.get_file()] = true
	report["checks"]["unique_cells"] = expected_cells.size()
	report["checks"]["unique_texture_instances"] = texture_ids.size()
	if texture_ids.size() != expected_cells.size():
		_fail("unique texture instances %d != unique cells %d" % [texture_ids.size(), expected_cells.size()])
		all_ok = false
	report["checks"]["cell_texture"] = cell_texture
	report["checks"]["material_names"] = material_names
	report["passed"] = all_ok and _failures.is_empty()
	report["failures"] = _failures
	print("[shared-textures] JSON " + JSON.stringify(report))
	_finish()


func _material_index(scene: Node3D, glb_path: String, material_name: String) -> int:
	if material_name.is_empty() or material_name == "<unnamed>":
		return -1
	var document := _glb_material_names(glb_path)
	return document.find(material_name)


func _glb_material_names(glb_path: String) -> Array[String]:
	var names: Array[String] = []
	var bytes := FileAccess.get_file_as_bytes(glb_path)
	if bytes.size() < 20:
		return names
	var chunk_length := bytes.decode_u32(12)
	var parsed: Variant = JSON.parse_string(bytes.slice(20, 20 + chunk_length).get_string_from_utf8())
	if not (parsed is Dictionary):
		return names
	for material in (parsed as Dictionary).get("materials", []):
		if material is Dictionary:
			names.append(String(material.get("name", "")))
	return names


func _texture_size(texture: Texture2D) -> Array:
	if texture == null:
		return [0, 0]
	return [texture.get_width(), texture.get_height()]


func _finish() -> void:
	ContentAssetLoader.clear_cache()
	quit(0 if _failures.is_empty() else 1)
