extends TestCase
## Guards the casemate gun modularisation (2026-10-22):
## - `SN_Ironclad.glb` exposes 12 `SN_Socket_GunPort_*` empty nodes as direct children of
##   the hull root (one per gun port), carries `hull-gunports@1` extras and the root-level
##   `gun_port_sockets` list, and no longer contains the 12 baked barrel / muzzle-band meshes
##   (geometry dropped from 8830 to 8158 tri);
## - `SN_Weapon_CasemateGun.glb` is the matching independent module: root origin on the gun
##   port plane, `port_pitch` assembly profile (no yaw), Mount -> Pitch -> Recoil -> Muzzle,
##   and the port gauge / protrusion / breech extras the assembler needs.
## Generator side: `tools/modeling/generators/sn_casemate_gun_generator.py`,
## `sn_ship_gun_ports.py`, `glb_gun_ports.py`; contract: WEAPON_SOCKET_CONTRACT.md §9.

const SHIPS_DIR := "res://dev_mods/core/assets/models/ships"
const WEAPONS_DIR := "res://dev_mods/core/assets/models/weapons"
const PORT_PREFIX := "SN_Socket_GunPort_"
const WEAPON_PREFIX := "SN_Socket_Weapon_"
const PORT_SPEC := "hull-gunports@1"
const GUN_ASSET := "SN_Weapon_CasemateGun"
const GUN_NODES := ["SN_Mount", "SN_Pivot_Pitch", "SN_Recoil", "SN_Muzzle"]

const EXPECTED_PORTS := [
	"SN_Socket_GunPort_Port_1", "SN_Socket_GunPort_Starboard_1",
	"SN_Socket_GunPort_Port_2", "SN_Socket_GunPort_Starboard_2",
	"SN_Socket_GunPort_Port_3", "SN_Socket_GunPort_Starboard_3",
	"SN_Socket_GunPort_Port_4", "SN_Socket_GunPort_Starboard_4",
	"SN_Socket_GunPort_Port_5", "SN_Socket_GunPort_Starboard_5",
	"SN_Socket_GunPort_Port_6", "SN_Socket_GunPort_Starboard_6",
]


func test_ironclad_gun_ports_are_empty_children_of_the_hull_root() -> void:
	ContentAssetLoader.clear_cache()
	var scene := ContentAssetLoader.load_scene("%s/SN_Ironclad.glb" % SHIPS_DIR)
	assert_not_null(scene, "SN_Ironclad GLB loads")
	if scene == null:
		return
	var root := _find_node(scene, "SN_Ironclad")
	assert_not_null(root, "SN_Ironclad hull root exists")
	if root == null:
		return
	var ports := {}
	for node in _nodes_named(scene, PORT_PREFIX):
		ports[node.name] = node
	assert_eq(ports.size(), EXPECTED_PORTS.size(), "ironclad exposes 12 gun ports")
	for port_name in EXPECTED_PORTS:
		assert_true(ports.has(port_name), "ironclad exposes %s" % port_name)
		if not ports.has(port_name):
			continue
		var port: Node = ports[port_name]
		assert_eq(port.get_parent(), root, "%s is a direct child of the hull root" % port_name)
		assert_eq(_mesh_descendants(port), 0, "%s is an empty node (no mesh)" % port_name)
	# 回归：甲板武器 socket 不能被炮门 socket 挤掉
	assert_eq(_nodes_named(scene, WEAPON_PREFIX).size(), 4,
		"ironclad still exposes its 4 deck weapon sockets")


func test_ironclad_gun_port_root_extras_match_the_contract() -> void:
	var gltf := _load_glb_json("%s/SN_Ironclad.glb" % SHIPS_DIR)
	assert_true(not gltf.is_empty(), "SN_Ironclad GLB JSON parses")
	if gltf.is_empty():
		return
	var nodes: Array = gltf.get("nodes", [])
	var root_index := -1
	var port_index := {}
	for index in nodes.size():
		var node: Dictionary = nodes[index]
		var node_name := String(node.get("name", ""))
		if node_name == "SN_Ironclad":
			root_index = index
		if node_name.begins_with(PORT_PREFIX):
			assert_false(port_index.has(node_name), "gun port name %s is unique" % node_name)
			port_index[node_name] = index
	assert_true(root_index >= 0, "SN_Ironclad root node found in GLB JSON")
	if root_index < 0:
		return
	var root: Dictionary = nodes[root_index]
	var extras: Dictionary = root.get("extras", {})
	assert_eq(String(extras.get("gun_port_socket_spec", "")), PORT_SPEC,
		"ironclad root declares %s" % PORT_SPEC)
	assert_eq(int(extras.get("gun_port_socket_count", -1)), EXPECTED_PORTS.size(),
		"ironclad root gun_port_socket_count matches")
	assert_eq(extras.get("gun_port_sockets", []), EXPECTED_PORTS,
		"ironclad root gun_port_sockets list matches port order")
	var children: Array = root.get("children", [])
	var child_indices := {}
	for child in children:
		child_indices[int(child)] = true
	for port_name in EXPECTED_PORTS:
		assert_true(port_index.has(port_name), "GLB exposes %s" % port_name)
		if not port_index.has(port_name):
			continue
		var node: Dictionary = nodes[int(port_index[port_name])]
		assert_false(node.has("mesh"), "%s has no mesh" % port_name)
		assert_true(child_indices.has(int(port_index[port_name])),
			"%s is parented to the hull root" % port_name)
		var port_extras: Dictionary = node.get("extras", {})
		assert_eq(String(port_extras.get("socket_spec", "")), PORT_SPEC,
			"%s socket_spec" % port_name)
		assert_eq(String(port_extras.get("port_class", "")), "Medium",
			"%s port_class" % port_name)
		for key in ["socket_index", "side_index", "port_w", "port_h", "sill_z", "deck_z",
				"inboard_depth", "outboard_clearance", "lid", "lid_hinge_z",
				"elev_min_deg", "elev_max_deg", "traverse_deg", "mount_scale"]:
			assert_true(port_extras.has(key), "%s carries extras.%s" % [port_name, key])
		if port_extras.has("port_w") and port_extras.has("port_h"):
			assert_true(abs(float(port_extras["port_w"]) - 1.90) < 0.001,
				"%s port_w is 1.90" % port_name)
			assert_true(abs(float(port_extras["port_h"]) - 1.90) < 0.001,
				"%s port_h is 1.90" % port_name)
		if port_extras.has("inboard_depth"):
			assert_true(float(port_extras["inboard_depth"]) >= 0.95,
				"%s can swallow the module breech" % port_name)
		if port_extras.has("lid_hinge_z"):
			assert_true(float(port_extras["lid_hinge_z"]) > float(port_extras.get("sill_z", 0.0)),
				"%s lid hinge sits above the sill" % port_name)


func test_casemate_gun_module_contract() -> void:
	ContentAssetLoader.clear_cache()
	var scene := ContentAssetLoader.load_scene("%s/%s.glb" % [WEAPONS_DIR, GUN_ASSET])
	assert_not_null(scene, "%s GLB loads" % GUN_ASSET)
	if scene == null:
		return
	for node_name in GUN_NODES:
		assert_not_null(_find_node(scene, node_name), "%s exposes %s" % [GUN_ASSET, node_name])
	assert_not_null(_find_node(scene, "SN_Weapon_CasemateGun_Barrel"),
		"%s exposes its barrel mesh" % GUN_ASSET)
	assert_not_null(_find_node(scene, "SN_Weapon_CasemateGun_Breech"),
		"%s exposes its hidden breech mesh" % GUN_ASSET)

	var gltf := _load_glb_json("%s/%s.glb" % [WEAPONS_DIR, GUN_ASSET])
	assert_true(not gltf.is_empty(), "%s GLB JSON parses" % GUN_ASSET)
	if gltf.is_empty():
		return
	var nodes: Array = gltf.get("nodes", [])
	var root_index := -1
	for index in nodes.size():
		if String(nodes[index].get("name", "")) == "SN_Weapon_CasemateGun_Root":
			root_index = index
	assert_true(root_index >= 0, "%s root node found" % GUN_ASSET)
	if root_index < 0:
		return
	var extras: Dictionary = nodes[root_index].get("extras", {})
	assert_eq(String(extras.get("assembly_spec", "")), "weapon-assembly@2",
		"%s uses weapon assembly v2" % GUN_ASSET)
	assert_eq(String(extras.get("assembly_profile", "")), "port_pitch",
		"%s is a fixed port gun (port_pitch)" % GUN_ASSET)
	assert_eq(String(extras.get("socket", "")), "SN_Socket_GunPort",
		"%s mounts on the gun port socket" % GUN_ASSET)
	assert_eq(String(extras.get("port_class", "")), "Medium",
		"%s port gauge class" % GUN_ASSET)
	assert_false(bool(extras.get("has_yaw", true)), "%s has no yaw pivot" % GUN_ASSET)
	assert_true(bool(extras.get("has_pitch", false)), "%s has a pitch pivot" % GUN_ASSET)
	assert_true(bool(extras.get("has_recoil", false)), "%s has a recoil node" % GUN_ASSET)
	assert_true(bool(extras.get("has_muzzle", false)), "%s has a muzzle node" % GUN_ASSET)
	assert_true(abs(float(extras.get("muzzle_protrusion", 0.0)) - 1.5407) < 0.001,
		"%s muzzle protrudes 1.5407 m" % GUN_ASSET)
	assert_true(abs(float(extras.get("breech_depth", 0.0)) - 0.95) < 0.001,
		"%s hides a 0.95 m breech inside the hull" % GUN_ASSET)


func _find_node(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_node(child, wanted)
		if found != null:
			return found
	return null


func _nodes_named(node: Node, prefix: String) -> Array[Node]:
	var output: Array[Node] = []
	if String(node.name).begins_with(prefix):
		output.append(node)
	for child in node.get_children():
		output.append_array(_nodes_named(child, prefix))
	return output


func _mesh_descendants(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_descendants(child)
	return count


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
