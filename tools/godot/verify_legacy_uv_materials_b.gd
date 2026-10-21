extends SceneTree
## @static-doc
## 作用：旧资产 UV 迁移 B 的 **运行时共享贴图验收**（只读）——12 件船模块 /
## 4 艘船 / 5 件旧小镇道具走 `ContentAssetLoader.load_scene()` 加载，核对每件 GLB
## 的外部贴图 URI、每个 surface 的 UV、每个材质的 albedo 贴图，以及同一
## `shared_materials/<texture>.png` 在同一类别内命中同一个 `Texture2D` 实例。
##
## 用法：
##   godot --headless --path . --script res://tools/godot/verify_legacy_uv_materials_b.gd
##
## 判定口径：
## - `images[].uri` 必须是 `shared_materials/<texture>.png`，文件存在于 GLB 同级目录；
## - 每个 surface 必须有 `ARRAY_TEX_UV`；每个材质必须是 `SN_Tex_*` 且有 albedo_texture；
## - 同一 URI 在同类别的多个 GLB 之间必须命中同一个 `Texture2D` 实例 id；
## - 三角面总数：modules 7492 / ships 45968 / town 1796（与迁移前一致）；
## - 网格节点数：modules 12 / ships 101 / town 5（Ironclad 1 + 39 + 32 + 29）。
## @end-static-doc

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
const EXPECTED_UNIQUE_TEXTURES := {"modules": 7, "ships": 9, "town": 8}
const TEX_URI_PREFIX := "shared_materials/"

var _failures: Array[String] = []
var _texture_ids := {}          # "category/uri" -> texture instance id
var _unique_ids := {}           # texture instance id -> true
var _tris := {"modules": 0, "ships": 0, "town": 0}
var _meshes := {"modules": 0, "ships": 0, "town": 0}


func _init() -> void:
	print("=== 旧资产 UV 迁移 B · 共享贴图运行时验收 ===")
	var groups := [
		["modules", MODULES_DIR, MODULES],
		["ships", SHIPS_DIR, SHIPS],
		["town", PROPS_DIR, TOWN],
	]
	for group in groups:
		for asset in group[2]:
			_check_asset(group[0], group[1], asset)
		var category_ids := {}
		for key in _texture_ids.keys():
			if String(key).begins_with(group[0] + "/"):
				category_ids[_texture_ids[key]] = true
		if category_ids.size() != int(EXPECTED_UNIQUE_TEXTURES[group[0]]):
			_failures.append("%s: 共享贴图实例 %d != %d" % [
				group[0], category_ids.size(),
				int(EXPECTED_UNIQUE_TEXTURES[group[0]])])
		if int(_tris[group[0]]) != int(EXPECTED_TRIS[group[0]]):
			_failures.append("%s: 三角面 %d != %d" % [
				group[0], int(_tris[group[0]]),
				int(EXPECTED_TRIS[group[0]])])
		if int(_meshes[group[0]]) != int(EXPECTED_MESHES[group[0]]):
			_failures.append("%s: 网格节点 %d != %d" % [
				group[0], int(_meshes[group[0]]),
				int(EXPECTED_MESHES[group[0]])])
	print("=== 结果：%d 件 / %d 个共享贴图实例 / 失败 %d 项 ===" % [
		MODULES.size() + SHIPS.size() + TOWN.size(), _unique_ids.size(),
		_failures.size()])
	for failure in _failures:
		print("  FAIL: " + failure)
	for scene in ContentAssetLoader._scenes.values():
		if scene is Node and is_instance_valid(scene):
			scene.free()
	ContentAssetLoader.clear_cache()
	quit(0 if _failures.is_empty() else 1)


func _check_asset(category: String, base_dir: String, asset: String) -> void:
	var path := "%s/%s.glb" % [base_dir, asset]
	var uris := ContentAssetLoader.material_image_uris(path)
	if uris.is_empty():
		_failures.append("%s: 没有外部贴图 URI" % asset)
	for uri in uris:
		if not uri.begins_with(TEX_URI_PREFIX):
			_failures.append("%s: URI 不是 shared_materials/：%s" % [asset, uri])
			continue
		if not FileAccess.file_exists(base_dir + "/" + uri):
			_failures.append("%s: 贴图缺失：%s" % [asset, uri])
	var uri_of_material := _material_uri_map(path)
	if uri_of_material.is_empty():
		_failures.append("%s: GLB JSON 解析失败" % asset)
		return

	var scene := ContentAssetLoader.load_scene(path)
	if scene == null:
		_failures.append("%s: GLB 加载失败" % asset)
		return
	var acc := {"meshes": 0, "surfaces": 0, "uv": 0, "tris": 0, "textures": {}}
	_walk(scene, acc)
	_meshes[category] = int(_meshes[category]) + int(acc["meshes"])
	if int(acc["uv"]) != int(acc["surfaces"]):
		_failures.append("%s: UV 缺失（%d/%d surfaces）" % [
			asset, int(acc["uv"]), int(acc["surfaces"])])
	if (acc["textures"] as Dictionary).is_empty():
		_failures.append("%s: 没有材质贴图" % asset)
	for material_name in (acc["textures"] as Dictionary).keys():
		var entry: Dictionary = acc["textures"][material_name]
		if not String(material_name).begins_with("SN_Tex_"):
			_failures.append("%s: 材质名不是 SN_Tex_*：%s" % [asset, material_name])
		if int(entry["id"]) == 0:
			_failures.append("%s / %s: 没有 albedo_texture" % [asset, material_name])
			continue
		var uri := String(uri_of_material.get(material_name, ""))
		if uri.is_empty():
			_failures.append("%s / %s: 找不到对应贴图 URI" % [asset, material_name])
			continue
		var key := category + "/" + uri
		if _texture_ids.has(key) and int(_texture_ids[key]) != int(entry["id"]):
			_failures.append("%s / %s: 贴图实例不共享" % [asset, material_name])
		_texture_ids[key] = int(entry["id"])
		_unique_ids[int(entry["id"])] = true
	_tris[category] = int(_tris[category]) + int(acc["tris"])


## 直接读 GLB 的 JSON chunk：material name -> images[].uri。
func _material_uri_map(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20 or bytes.decode_u32(0) != 0x46546C67:
		return {}
	var chunk_length := bytes.decode_u32(12)
	var json_text := bytes.slice(20, 20 + chunk_length).get_string_from_utf8()
	json_text = json_text.replace("\u0000", "")
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return {}
	var document: Dictionary = parsed
	var images: Array = document.get("images", [])
	var textures: Array = document.get("textures", [])
	var output := {}
	for material in document.get("materials", []):
		if not (material is Dictionary):
			continue
		var name := String((material as Dictionary).get("name", ""))
		var pbr: Dictionary = (material as Dictionary).get("pbrMetallicRoughness", {})
		var texture_ref: Dictionary = pbr.get("baseColorTexture", {})
		if not texture_ref.has("index"):
			output[name] = ""
			continue
		var texture_index := int(texture_ref["index"])
		if texture_index < 0 or texture_index >= textures.size():
			output[name] = ""
			continue
		var source := int((textures[texture_index] as Dictionary).get("source", -1))
		if source < 0 or source >= images.size():
			output[name] = ""
			continue
		output[name] = String((images[source] as Dictionary).get("uri", ""))
	return output


func _walk(node: Node, acc: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		acc["meshes"] = int(acc["meshes"]) + 1
		for surface in mesh.get_surface_count():
			acc["surfaces"] = int(acc["surfaces"]) + 1
			var arrays := mesh.surface_get_arrays(surface)
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			if uv is PackedVector2Array and (uv as PackedVector2Array).size() > 0:
				acc["uv"] = int(acc["uv"]) + 1
			acc["tris"] = int(acc["tris"]) + _surface_triangles(mesh, surface)
			var material := mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				var standard := material as StandardMaterial3D
				var texture := standard.albedo_texture
				acc["textures"][String(standard.resource_name)] = {
					"id": texture.get_instance_id() if texture != null else 0,
				}
	for child in node.get_children():
		_walk(child, acc)


func _surface_triangles(mesh: Mesh, surface: int) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
		return int((indices as PackedInt32Array).size() / 3)
	var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
	if vertices is PackedVector3Array:
		return int((vertices as PackedVector3Array).size() / 3)
	return 0
