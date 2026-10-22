extends TestCase
## @static-doc
## 作用：`combat_kit` 敌舰套件（M2-1，4 艘 `SN_Enemy_*.glb`）的运行时守护用例：资产必须
## 能从 `res://dev_mods/core` 真实加载，且几何 / 材质 / socket 契约与生成器
## `tools/modeling/generators/combat_kit_generator.py` 的交付口径一致。
##
## ## 覆盖范围
## - **加载 + 几何**：4 个 GLB 均能经 `ContentAssetLoader.load_scene()` 加载；每艘
##   mesh 节点数与三角面总数与常量一致（总 31,324 tri；逐艘 8,678 / 11,746 / 7,440 / 3,460）。
##   口径：tri = 每个 surface 的 index 数 / 3（= Blender loop triangles，n-gon 三角化），
##   与 `combat_kit_generator.report(asset)["tris"]` / `verify_combat_kit_glb.py` 完全一致；
##   mesh 数 = 生成器对象数 `report(asset)["objects"]`（多节点船，root 不是单 mesh）。
##   若最终导出因生成器改动而变化，需同时更新本表、`verify_combat_kit_glb.py` 与 catalog。
## - **UV / 材质 / 外部贴图**：每个 surface 有 UV；材质名 `SN_Tex_*`、`albedo_texture`
##   非空；`ContentAssetLoader.material_image_uris()` 返回的每个 URI 都是
##   `shared_materials/<texture>.png` 且对应外部 PNG 文件存在（共享贴图外部化契约）。
## - **GLB JSON 结构**：root extras（`asset` / `combat_kit="enemy-ships@1"` /
##   `enemy_class` / `enemy_archetype` / `weapon_sockets` / `weapon_socket_count` /
##   `socket_spec="hull-sockets@1"`）；4 艘武器 socket 数 3 / 6 / 4 / 3，名字有序、是
##   root 直接子节点、无 mesh、`socket_class` / `clearance_*` / `mount_scale` 齐备；
##   铁甲舰 8 个 `SN_Socket_GunPort_*`（每舷 4 个）与 root `gun_port_sockets` 名单，
##   契约 `hull-gunports@1`；节点名无 Blender `.001` 后缀、无重名。
##
## 生成器 / 导出链：`combat_kit_generator.py` → `export_combat_kit_glb.py` →
## `glb_enemy_sockets.normalize()` → `assets/models/combat/` + `dev_mods/core/...`。
## 静态验收（不进 Godot）：`python tools/modeling/generators/verify_combat_kit_glb.py`。
## @end-static-doc

const COMBAT_DIR := "res://dev_mods/core/assets/models/combat"
const WEAPON_SOCKET_PREFIX := "SN_Socket_Weapon_"
const GUN_PORT_PREFIX := "SN_Socket_GunPort_"
const COMBAT_KIT_SPEC := "enemy-ships@1"
const SOCKET_SPEC := "hull-sockets@1"
const GUN_PORT_SPEC := "hull-gunports@1"
const IRONCLAD := "SN_Enemy_Ironclad_Raider"
const TOTAL_TRIS := 31324

const GUN_PORT_NAMES := [
	"SN_Socket_GunPort_Port_1", "SN_Socket_GunPort_Port_2",
	"SN_Socket_GunPort_Port_3", "SN_Socket_GunPort_Port_4",
	"SN_Socket_GunPort_Starboard_1", "SN_Socket_GunPort_Starboard_2",
	"SN_Socket_GunPort_Starboard_3", "SN_Socket_GunPort_Starboard_4",
]

# 逐艘常量（插入顺序 = socket_index 顺序）。数值口径见文件头 @static-doc。
const SHIPS := {
	"SN_Enemy_Pirate_Sloop": {
		"root": "SN_ES_Root",
		"enemy_class": "Light",
		"enemy_archetype": "pirate_sloop",
		"meshes": 15,
		"tris": 8678,
		"sockets": {
			"SN_Socket_Weapon_Port_1": "Light",
			"SN_Socket_Weapon_Starboard_1": "Light",
			"SN_Socket_Weapon_Bow": "Light",
		},
	},
	"SN_Enemy_Merchant_Armed": {
		"root": "SN_EM_Root",
		"enemy_class": "Medium",
		"enemy_archetype": "armed_merchantman",
		"meshes": 18,
		"tris": 11746,
		"sockets": {
			"SN_Socket_Weapon_Port_1": "Medium",
			"SN_Socket_Weapon_Starboard_1": "Medium",
			"SN_Socket_Weapon_Port_2": "Medium",
			"SN_Socket_Weapon_Starboard_2": "Medium",
			"SN_Socket_Weapon_Bow": "Medium",
			"SN_Socket_Weapon_Stern": "Medium",
		},
	},
	"SN_Enemy_Ironclad_Raider": {
		"root": "SN_ER_Root",
		"enemy_class": "Heavy",
		"enemy_archetype": "ironclad_raider",
		"meshes": 12,
		"tris": 7440,
		"sockets": {
			"SN_Socket_Weapon_Port_1": "Heavy",
			"SN_Socket_Weapon_Starboard_1": "Heavy",
			"SN_Socket_Weapon_Port_2": "Medium",
			"SN_Socket_Weapon_Starboard_2": "Medium",
		},
	},
	"SN_Enemy_Gunboat": {
		"root": "SN_EG_Root",
		"enemy_class": "Light",
		"enemy_archetype": "gunboat",
		"meshes": 10,
		"tris": 3460,
		"sockets": {
			"SN_Socket_Weapon_Bow_1": "Heavy",
			"SN_Socket_Weapon_Port_1": "Light",
			"SN_Socket_Weapon_Starboard_1": "Light",
		},
	},
}


func test_combat_kit_glbs_load_with_expected_geometry() -> void:
	ContentAssetLoader.clear_cache()
	var total_tris := 0
	for asset in SHIPS.keys():
		var path := "%s/%s.glb" % [COMBAT_DIR, asset]
		assert_true(FileAccess.file_exists(path), "%s GLB exists in core" % asset)
		var scene := ContentAssetLoader.load_scene(path)
		assert_not_null(scene, "%s GLB loads" % asset)
		if scene == null:
			continue
		var info := _scene_metrics(scene)
		assert_eq(int(info["meshes"]), int(SHIPS[asset]["meshes"]),
			"%s mesh count matches the generator object count" % asset)
		assert_eq(int(info["tris"]), int(SHIPS[asset]["tris"]),
			"%s triangle count matches the generator report" % asset)
		total_tris += int(info["tris"])
	assert_eq(total_tris, TOTAL_TRIS,
		"combat_kit triangle total matches the accepted build")


func test_combat_kit_surfaces_use_uvs_and_shared_textures() -> void:
	ContentAssetLoader.clear_cache()
	for asset in SHIPS.keys():
		var path := "%s/%s.glb" % [COMBAT_DIR, asset]
		var uris := ContentAssetLoader.material_image_uris(path)
		assert_true(uris.size() > 0, "%s declares material images" % asset)
		for uri in uris:
			assert_true(String(uri).begins_with("shared_materials/"),
				"%s texture is external: %s" % [asset, uri])
			assert_true(FileAccess.file_exists("%s/%s" % [COMBAT_DIR, String(uri)]),
				"%s texture file exists: %s" % [asset, uri])
		var scene := ContentAssetLoader.load_scene(path)
		assert_not_null(scene, "%s GLB loads" % asset)
		if scene == null:
			continue
		var info := _scene_metrics(scene)
		assert_true(int(info["surfaces"]) > 0, "%s has surfaces" % asset)
		assert_eq(int(info["uv_surfaces"]), int(info["surfaces"]),
			"%s every surface has UVs" % asset)
		assert_eq(int(info["missing_texture"]), 0,
			"%s every material has an albedo texture" % asset)
		for material_name in (info["materials"] as Dictionary).keys():
			assert_true(String(material_name).begins_with("SN_Tex_"),
				"%s surface material is a shared texture material: %s" % [
					asset, material_name])


func test_combat_kit_glb_materials_are_double_sided_shared_textures() -> void:
	for asset in SHIPS.keys():
		var gltf := _load_glb_json("%s/%s.glb" % [COMBAT_DIR, asset])
		assert_true(not gltf.is_empty(), "%s GLB JSON parses" % asset)
		if gltf.is_empty():
			continue
		var materials: Array = gltf.get("materials", [])
		assert_true(materials.size() > 0, "%s declares materials" % asset)
		for material in materials:
			var material_name := String((material as Dictionary).get("name", ""))
			assert_true(material_name.begins_with("SN_Tex_"),
				"%s material is a shared texture material: %s" % [asset, material_name])
			assert_true(bool((material as Dictionary).get("doubleSided", false)),
				"%s material is double sided: %s" % [asset, material_name])
			var pbr: Dictionary = (material as Dictionary).get(
				"pbrMetallicRoughness", {})
			assert_true(pbr.has("baseColorTexture"),
				"%s material has a base color texture: %s" % [asset, material_name])


func test_combat_kit_root_extras_and_weapon_sockets_match_the_contract() -> void:
	for asset in SHIPS.keys():
		var spec: Dictionary = SHIPS[asset]
		var gltf := _load_glb_json("%s/%s.glb" % [COMBAT_DIR, asset])
		assert_true(not gltf.is_empty(), "%s GLB JSON parses" % asset)
		if gltf.is_empty():
			continue
		var nodes: Array = gltf.get("nodes", [])
		var root_index := -1
		var socket_index := {}
		var seen_names := {}
		for index in nodes.size():
			var node: Dictionary = nodes[index]
			var node_name := String(node.get("name", ""))
			assert_false(seen_names.has(node_name),
				"%s node name is unique: %s" % [asset, node_name])
			seen_names[node_name] = true
			assert_false(node_name.ends_with(".001"),
				"%s has no Blender .001 suffixed node (%s)" % [asset, node_name])
			if node_name == String(spec["root"]):
				root_index = index
			if node_name.begins_with(WEAPON_SOCKET_PREFIX):
				socket_index[node_name] = index
		assert_true(root_index >= 0, "%s root node found in GLB JSON" % asset)
		if root_index < 0:
			continue

		var root: Dictionary = nodes[root_index]
		var extras: Dictionary = root.get("extras", {})
		assert_eq(String(extras.get("asset", "")), asset,
			"%s root extras.asset" % asset)
		assert_eq(String(extras.get("combat_kit", "")), COMBAT_KIT_SPEC,
			"%s root declares %s" % [asset, COMBAT_KIT_SPEC])
		assert_eq(String(extras.get("enemy_class", "")), String(spec["enemy_class"]),
			"%s root enemy_class" % asset)
		assert_eq(String(extras.get("enemy_archetype", "")),
			String(spec["enemy_archetype"]), "%s root enemy_archetype" % asset)
		assert_eq(String(extras.get("socket_spec", "")), SOCKET_SPEC,
			"%s root declares %s" % [asset, SOCKET_SPEC])

		var expected: Dictionary = spec["sockets"]
		var expected_names: Array = expected.keys()
		assert_eq(int(extras.get("weapon_socket_count", -1)), expected_names.size(),
			"%s root weapon_socket_count matches" % asset)
		assert_eq(extras.get("weapon_sockets", []), expected_names,
			"%s root weapon_sockets list matches socket order" % asset)
		assert_eq(socket_index.size(), expected_names.size(),
			"%s exposes exactly the declared number of weapon sockets" % asset)

		var children: Array = root.get("children", [])
		var child_indices := {}
		for child in children:
			child_indices[int(child)] = true
		for socket_name in expected_names:
			assert_true(socket_index.has(socket_name),
				"%s GLB exposes %s" % [asset, socket_name])
			if not socket_index.has(socket_name):
				continue
			var node: Dictionary = nodes[int(socket_index[socket_name])]
			assert_false(node.has("mesh"),
				"%s/%s has no mesh" % [asset, socket_name])
			assert_true(child_indices.has(int(socket_index[socket_name])),
				"%s/%s is parented to the root" % [asset, socket_name])
			var socket_extras: Dictionary = node.get("extras", {})
			assert_eq(String(socket_extras.get("socket_spec", "")), SOCKET_SPEC,
				"%s/%s socket_spec" % [asset, socket_name])
			assert_eq(String(socket_extras.get("socket_class", "")),
				String(expected[socket_name]),
				"%s/%s socket_class" % [asset, socket_name])
			assert_true(socket_extras.has("socket_index"),
				"%s/%s carries extras.socket_index" % [asset, socket_name])
			for key in ["clearance_r", "clearance_x", "clearance_y", "clearance_h"]:
				assert_true(socket_extras.has(key),
					"%s/%s carries extras.%s" % [asset, socket_name, key])
				if socket_extras.has(key):
					assert_true(float(socket_extras[key]) >= 0.5,
						"%s/%s extras.%s is usable" % [asset, socket_name, key])
			assert_true(socket_extras.has("mount_scale"),
				"%s/%s carries extras.mount_scale" % [asset, socket_name])
			if socket_extras.has("mount_scale"):
				assert_true(abs(float(socket_extras["mount_scale"]) - 1.0) < 0.0001,
					"%s/%s mount_scale is 1.0" % [asset, socket_name])


func test_ironclad_gun_ports_match_the_contract() -> void:
	var gltf := _load_glb_json("%s/%s.glb" % [COMBAT_DIR, IRONCLAD])
	assert_true(not gltf.is_empty(), "%s GLB JSON parses" % IRONCLAD)
	if gltf.is_empty():
		return
	var nodes: Array = gltf.get("nodes", [])
	var root_index := -1
	var port_index := {}
	for index in nodes.size():
		var node: Dictionary = nodes[index]
		var node_name := String(node.get("name", ""))
		if node_name == String(SHIPS[IRONCLAD]["root"]):
			root_index = index
		if node_name.begins_with(GUN_PORT_PREFIX):
			assert_false(port_index.has(node_name), "gun port name %s is unique" % node_name)
			port_index[node_name] = index
	assert_true(root_index >= 0, "%s root node found in GLB JSON" % IRONCLAD)
	if root_index < 0:
		return
	var root: Dictionary = nodes[root_index]
	var extras: Dictionary = root.get("extras", {})
	assert_eq(String(extras.get("gun_port_socket_spec", "")), GUN_PORT_SPEC,
		"%s root declares %s" % [IRONCLAD, GUN_PORT_SPEC])
	assert_eq(int(extras.get("gun_port_socket_count", -1)), GUN_PORT_NAMES.size(),
		"%s root gun_port_socket_count matches" % IRONCLAD)
	assert_eq(extras.get("gun_port_sockets", []), GUN_PORT_NAMES,
		"%s root gun_port_sockets list matches port order" % IRONCLAD)
	assert_eq(port_index.size(), GUN_PORT_NAMES.size(),
		"%s exposes 8 gun port sockets" % IRONCLAD)
	var children: Array = root.get("children", [])
	var child_indices := {}
	for child in children:
		child_indices[int(child)] = true
	for port_name in GUN_PORT_NAMES:
		assert_true(port_index.has(port_name), "%s GLB exposes %s" % [IRONCLAD, port_name])
		if not port_index.has(port_name):
			continue
		var node: Dictionary = nodes[int(port_index[port_name])]
		assert_false(node.has("mesh"), "%s has no mesh" % port_name)
		assert_true(child_indices.has(int(port_index[port_name])),
			"%s is parented to the root" % port_name)
		var port_extras: Dictionary = node.get("extras", {})
		assert_eq(String(port_extras.get("socket_spec", "")), GUN_PORT_SPEC,
			"%s socket_spec" % port_name)
		assert_eq(String(port_extras.get("port_class", "")), "Medium",
			"%s port_class" % port_name)
		for key in ["socket_index", "side_index", "port_w", "port_h", "sill_z",
				"deck_z", "inboard_depth", "outboard_clearance", "lid",
				"lid_hinge_z", "elev_min_deg", "elev_max_deg", "traverse_deg",
				"mount_scale"]:
			assert_true(port_extras.has(key), "%s carries extras.%s" % [port_name, key])
		if port_extras.has("port_w") and port_extras.has("port_h"):
			assert_true(abs(float(port_extras["port_w"]) - 2.05) < 0.001,
				"%s port_w matches the casemate gun gauge" % port_name)
			assert_true(abs(float(port_extras["port_h"]) - 1.95) < 0.001,
				"%s port_h matches the casemate gun gauge" % port_name)
		if port_extras.has("lid_hinge_z") and port_extras.has("sill_z"):
			assert_true(float(port_extras["lid_hinge_z"]) > float(port_extras["sill_z"]),
				"%s lid hinge sits above the sill" % port_name)


# ---------------------------------------------------------------- helpers

func _scene_metrics(scene: Node3D) -> Dictionary:
	var result := {"meshes": 0, "tris": 0, "surfaces": 0,
		"uv_surfaces": 0, "missing_texture": 0, "materials": {}}
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
			(result["materials"] as Dictionary)[String(standard.resource_name)] = true
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


func _load_glb_json(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20:
		return {}
	if bytes.decode_u32(0) != 0x46546C67:
		return {}
	var chunk_length := int(bytes.decode_u32(12))
	if bytes.decode_u32(16) != 0x4E4F534A or chunk_length <= 0 or 20 + chunk_length > bytes.size():
		return {}
	var text := bytes.slice(20, 20 + chunk_length).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
