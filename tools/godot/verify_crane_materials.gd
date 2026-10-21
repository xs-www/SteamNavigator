extends SceneTree
## @static-doc
## 作用：四台起重机 GLB 的**共享贴图运行时验收**（只读）：外部贴图 URI 解析、
## 每个网格有 UV、每个材质都绑定贴图，且同一贴图在多个 GLB 之间是同一个 Texture2D 实例。
##
## 用法：
##   godot --headless --path . --script res://tools/godot/verify_crane_materials.gd
##
## 判定口径：
## - 走 `ContentAssetLoader.load_scene()`（运行时模组资产路径），而不是 `ResourceLoader`；
## - GLB 的 `images[].uri` 必须是 `shared_materials/<texture>.png`，文件存在；
## - 每个 surface 必须有 `ARRAY_TEX_UV`（UV 箱投影已烘焙）；
## - 每个材质必须有 `albedo_texture`；
## - 同一材质名（= 同一贴图）在不同 GLB 里必须命中同一个 `Texture2D` 实例 id；
## - 记录材质名 / 贴图实例 / UV 数量，失败返回非 0。
## @end-static-doc

const CRANES := [
	"res://dev_mods/core/assets/models/props/SN_Harbor_Crane.glb",
	"res://dev_mods/core/assets/models/props/SN_Mega_Gantry.glb",
	"res://dev_mods/core/assets/models/props/SN_Wooden_Mast_Crane.glb",
	"res://dev_mods/core/assets/models/props/SN_Hand_Jib_Crane.glb",
]

var _material_textures := {}   # material name -> texture instance id
var _failures: Array[String] = []
var _texture_count := 0


func _init() -> void:
	print("=== 起重机共享贴图运行时验收 ===")
	for path in CRANES:
		_check_asset(path)
	_check_sharing()
	print("=== 结果：%d 个 GLB，%d 个共享贴图实例，失败 %d 项 ===" % [
		CRANES.size(), _texture_count, _failures.size()])
	for failure in _failures:
		print("  FAIL: " + failure)
	for scene in ContentAssetLoader._scenes.values():
		if scene is Node and is_instance_valid(scene):
			scene.free()
	ContentAssetLoader.clear_cache()
	quit(0 if _failures.is_empty() else 1)


func _check_asset(path: String) -> void:
	var name := path.get_file().get_basename()
	var uris := ContentAssetLoader.material_image_uris(path)
	if uris.is_empty():
		_failures.append("%s: 没有外部贴图 URI" % name)
	var base := path.get_base_dir()
	for uri in uris:
		if uri.is_empty():
			_failures.append("%s: 存在没有贴图的材质" % name)
			continue
		if not uri.begins_with("shared_materials/"):
			_failures.append("%s: 贴图 URI 不是 shared_materials/：%s" % [name, uri])
			continue
		if not FileAccess.file_exists(base.path_join(uri)):
			_failures.append("%s: 贴图文件缺失：%s" % [name, uri])

	var scene := ContentAssetLoader.load_scene(path)
	if scene == null:
		_failures.append("%s: GLB 加载失败" % name)
		return

	var acc := {"meshes": 0, "surfaces": 0, "uv_surfaces": 0, "materials": {}}
	_walk(scene, acc)
	if int(acc["meshes"]) == 0:
		_failures.append("%s: 没有网格" % name)
	if int(acc["uv_surfaces"]) != int(acc["surfaces"]):
		_failures.append("%s: UV 缺失（%d/%d 个 surface）" % [
			name, int(acc["uv_surfaces"]), int(acc["surfaces"])])
	if (acc["materials"] as Dictionary).is_empty():
		_failures.append("%s: 没有材质" % name)

	for mat_name in (acc["materials"] as Dictionary).keys():
		var entry: Dictionary = acc["materials"][mat_name]
		if entry["textures"].is_empty():
			_failures.append("%s / %s: 没有 albedo_texture" % [name, mat_name])
			continue
		for texture_id in entry["textures"]:
			if not _material_textures.has(mat_name):
				_material_textures[mat_name] = texture_id
			elif _material_textures[mat_name] != texture_id:
				_failures.append("%s / %s: 贴图实例不共享（%d != %d）" % [
					name, mat_name, int(_material_textures[mat_name]),
					int(texture_id)])

	print("[%s] %s  meshes=%d surfaces=%d uv=%d materials=%s external_uris=%d" % [
		"PASS" if _failures.is_empty() else "PARTIAL",
		name, int(acc["meshes"]), int(acc["surfaces"]), int(acc["uv_surfaces"]),
		",".join((acc["materials"] as Dictionary).keys()), uris.size()])


func _check_sharing() -> void:
	_texture_count = _material_textures.size()
	if _texture_count < 4:
		_failures.append("共享贴图实例过少：%d（至少 4 个材质跨资产共享）" % _texture_count)
	for mat_name in _material_textures.keys():
		if not String(mat_name).begins_with("SN_Tex_"):
			_failures.append("材质名不是 SN_Tex_*：%s" % mat_name)


func _walk(node: Node, acc: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			acc["meshes"] = int(acc["meshes"]) + 1
			for surface in mi.mesh.get_surface_count():
				acc["surfaces"] = int(acc["surfaces"]) + 1
				var arrays := mi.mesh.surface_get_arrays(surface)
				var uv = arrays[Mesh.ARRAY_TEX_UV]
				if uv != null and (uv as PackedVector2Array).size() > 0:
					acc["uv_surfaces"] = int(acc["uv_surfaces"]) + 1
				var material := mi.mesh.surface_get_material(surface)
				if material is StandardMaterial3D:
					var standard := material as StandardMaterial3D
					var mat_name := standard.resource_name
					if mat_name.is_empty():
						mat_name = "material_%d" % material.get_instance_id()
					var materials: Dictionary = acc["materials"]
					if not materials.has(mat_name):
						materials[mat_name] = {"textures": []}
					if standard.albedo_texture != null:
						var texture_id := standard.albedo_texture.get_instance_id()
						if not (materials[mat_name]["textures"] as Array).has(texture_id):
							(materials[mat_name]["textures"] as Array).append(texture_id)
	for child in node.get_children():
		_walk(child, acc)
