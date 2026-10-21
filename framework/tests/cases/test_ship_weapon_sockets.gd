extends TestCase
## Guards the M0-3 hull-side weapon sockets for the four gameplay ships:
## - every ship GLB exposes its declared `SN_Socket_Weapon_*` empty nodes as direct
##   children of the hull root, and none of them carries a mesh (sockets add no geometry);
## - the root node extras list `weapon_sockets` (ordered) and each socket node carries
##   `socket_class` / `clearance_r` / `clearance_x` / `clearance_y` / `clearance_h` /
##   `mount_scale` / `socket_index`, matching the `WEAPON_SOCKET_CONTRACT` v2 layout;
## - the socket names standardised in the GLB (`SN_Socket_Weapon_*`, no `.001` suffixes)
##   are the only weapon sockets, so runtime assembly can find them by name.
## The Blender/generator side lives in `tools/modeling/generators/sn_ship_weapon_sockets.py`.

const SHIPS_DIR := "res://dev_mods/core/assets/models/ships"
const SOCKET_PREFIX := "SN_Socket_Weapon_"
const SOCKET_SPEC := "hull-sockets@1"

const EXPECTED := {
	"SN_Ironclad": {
		"root": "SN_Ironclad",
		"sockets": {
			"SN_Socket_Weapon_Port_1": "Heavy",
			"SN_Socket_Weapon_Starboard_1": "Heavy",
			"SN_Socket_Weapon_Port_2": "Medium",
			"SN_Socket_Weapon_Starboard_2": "Medium",
		},
	},
	"SN_Paddle_Freighter": {
		"root": "SN_PF_Root",
		"sockets": {
			"SN_Socket_Weapon_Port_1": "Side",
			"SN_Socket_Weapon_Starboard_1": "Side",
			"SN_Socket_Weapon_Port_2": "Light",
			"SN_Socket_Weapon_Starboard_2": "Light",
		},
	},
	"SN_Paddle_Steamer": {
		"root": "SN_PS_Root",
		"sockets": {
			"SN_Socket_Weapon_Port_1": "Light",
			"SN_Socket_Weapon_Starboard_1": "Light",
			"SN_Socket_Weapon_Stern": "Medium",
		},
	},
	"SN_Schooner_Fame": {
		"root": "SN_SF_Root",
		"sockets": {
			"SN_Socket_Weapon_Port_1": "Light",
			"SN_Socket_Weapon_Starboard_1": "Light",
			"SN_Socket_Weapon_Bow": "Medium",
		},
	},
}


func test_ship_sockets_are_empty_children_of_the_hull_root() -> void:
	ContentAssetLoader.clear_cache()
	for asset in EXPECTED.keys():
		var spec: Dictionary = EXPECTED[asset]
		var scene := ContentAssetLoader.load_scene("%s/%s.glb" % [SHIPS_DIR, asset])
		assert_not_null(scene, "%s GLB loads" % asset)
		if scene == null:
			continue
		var root := _find_node(scene, String(spec["root"]))
		assert_not_null(root, "%s hull root node exists" % asset)
		if root == null:
			continue
		var sockets := {}
		for node in _nodes_named(scene, SOCKET_PREFIX):
			sockets[node.name] = node
		var expected: Dictionary = spec["sockets"]
		assert_eq(sockets.size(), expected.size(),
			"%s exposes exactly the declared number of weapon sockets" % asset)
		for socket_name in expected.keys():
			assert_true(sockets.has(socket_name),
				"%s exposes %s" % [asset, socket_name])
			if not sockets.has(socket_name):
				continue
			var socket: Node = sockets[socket_name]
			assert_eq(socket.get_parent(), root,
				"%s/%s is a direct child of the hull root" % [asset, socket_name])
			assert_eq(_mesh_descendants(socket), 0,
				"%s/%s is an empty node (no mesh)" % [asset, socket_name])


func test_ship_socket_root_extras_match_the_contract() -> void:
	for asset in EXPECTED.keys():
		var spec: Dictionary = EXPECTED[asset]
		var gltf := _load_glb_json("%s/%s.glb" % [SHIPS_DIR, asset])
		assert_true(not gltf.is_empty(), "%s GLB JSON parses" % asset)
		if gltf.is_empty():
			continue
		var nodes: Array = gltf.get("nodes", [])
		var root_index := -1
		var socket_index := {}
		for index in nodes.size():
			var node: Dictionary = nodes[index]
			var node_name := String(node.get("name", ""))
			if node_name == String(spec["root"]):
				root_index = index
			if node_name.begins_with(SOCKET_PREFIX):
				assert_false(socket_index.has(node_name),
					"%s socket name %s is unique" % [asset, node_name])
				socket_index[node_name] = index
			assert_false(node_name.ends_with(".001"),
				"%s has no Blender .001 suffixed node (%s)" % [asset, node_name])
		assert_true(root_index >= 0, "%s root node found in GLB JSON" % asset)
		if root_index < 0:
			continue
		var root: Dictionary = nodes[root_index]
		var extras: Dictionary = root.get("extras", {})
		var expected: Dictionary = spec["sockets"]
		var expected_order: Array = expected.keys()
		assert_eq(extras.get("socket_spec", ""), SOCKET_SPEC,
			"%s root declares %s" % [asset, SOCKET_SPEC])
		assert_eq(int(extras.get("weapon_socket_count", -1)), expected_order.size(),
			"%s root weapon_socket_count matches" % asset)
		assert_eq(extras.get("weapon_sockets", []), expected_order,
			"%s root weapon_sockets list matches socket order" % asset)
		var children: Array = root.get("children", [])
		var child_indices := {}
		for child in children:
			child_indices[int(child)] = true
		for socket_name in expected_order:
			assert_true(socket_index.has(socket_name),
				"%s GLB exposes %s" % [asset, socket_name])
			if not socket_index.has(socket_name):
				continue
			var node: Dictionary = nodes[int(socket_index[socket_name])]
			assert_false(node.has("mesh"), "%s/%s has no mesh" % [asset, socket_name])
			assert_true(child_indices.has(int(socket_index[socket_name])),
				"%s/%s is parented to the hull root" % [asset, socket_name])
			var socket_extras: Dictionary = node.get("extras", {})
			assert_eq(String(socket_extras.get("socket_class", "")), String(expected[socket_name]),
				"%s/%s socket_class" % [asset, socket_name])
			assert_eq(String(socket_extras.get("socket_spec", "")), SOCKET_SPEC,
				"%s/%s socket_spec" % [asset, socket_name])
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
