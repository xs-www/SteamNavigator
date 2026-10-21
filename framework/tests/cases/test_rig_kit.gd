extends TestCase
## Guards the M0-4 `rig_kit` assets (12 standalone `SN_Rig_*` GLBs) and the 22 hull-side
## rig sockets on the three sailing ships:
## - every rig kit GLB exposes exactly one `SN_Mount` plus its declared `SN_Socket_*`
##   empty nodes as direct children of the asset root, without meshes;
## - root extras carry `kit_family = "rig_kit"`, `rig_spec`, and the ordered
##   `rig_sockets` list written by `glb_rig_kit.standardize()`;
## - hulls PF/SF/IC expose `SN_Socket_Mast/Yard/Sail_*` as empty direct children of the
##   hull root, and the root extras list all of them (`rig_sockets` / count / spec);
## - socket names are standardised in the GLB (no `.001` suffixes, no Blender prefixes).
## Generation side: `tools/modeling/generators/rig_kit_batch1_generator.py`,
## `sn_ship_rig_sockets.py`; contract: `docs/design/RIG_KIT_CONTRACT.md`.

const RIG_DIR := "res://dev_mods/core/assets/models/rig"
const SHIPS_DIR := "res://dev_mods/core/assets/models/ships"
const RIG_SPEC := "rig-kit@1"
const SOCKET_SPEC := "rig-sockets@1"

const ASSETS := {
	"SN_Rig_Mast_Sail": {
		"root": "SN_Rig_Mast_Sail_Root",
		"sockets": ["SN_Mount", "SN_Socket_Yard_Lower", "SN_Socket_Yard_Upper", "SN_Socket_Sail_Head", "SN_Socket_Sail_Tack", "SN_Socket_Deadeye_Port", "SN_Socket_Deadeye_Starboard"],
	},
	"SN_Rig_Mast_Steam": {
		"root": "SN_Rig_Mast_Steam_Root",
		"sockets": ["SN_Mount", "SN_Socket_Yard", "SN_Socket_Stay_Fore", "SN_Socket_Stay_Aft"],
	},
	"SN_Rig_Yard": {
		"root": "SN_Rig_Yard_Root",
		"sockets": ["SN_Mount", "SN_Socket_Sail", "SN_Socket_Brace_Port", "SN_Socket_Brace_Starboard"],
	},
	"SN_Rig_Gaff": {
		"root": "SN_Rig_Gaff_Root",
		"sockets": ["SN_Mount", "SN_Socket_Sail_Peak", "SN_Socket_Halyard"],
	},
	"SN_Rig_Boom": {
		"root": "SN_Rig_Boom_Root",
		"sockets": ["SN_Mount", "SN_Socket_Sail_Clew", "SN_Socket_Sheet"],
	},
	"SN_Rig_Bowsprit": {
		"root": "SN_Rig_Bowsprit_Root",
		"sockets": ["SN_Mount", "SN_Socket_Jib_Tack", "SN_Socket_Stay_Fore"],
	},
	"SN_Rig_Sail_Gaff": {
		"root": "SN_Rig_Sail_Gaff_Root",
		"sockets": ["SN_Mount", "SN_Socket_Sail_Head", "SN_Socket_Sail_Peak", "SN_Socket_Sail_Clew"],
	},
	"SN_Rig_Sail_Square": {
		"root": "SN_Rig_Sail_Square_Root",
		"sockets": ["SN_Mount", "SN_Socket_Yard", "SN_Socket_Sheet_Port", "SN_Socket_Sheet_Starboard"],
	},
	"SN_Rig_Sail_Jib": {
		"root": "SN_Rig_Sail_Jib_Root",
		"sockets": ["SN_Mount", "SN_Socket_Sail_Head", "SN_Socket_Sail_Clew"],
	},
	"SN_Rig_Shrouds": {
		"root": "SN_Rig_Shrouds_Root",
		"sockets": ["SN_Mount", "SN_Socket_Mast_Top", "SN_Socket_Chainplate_Port", "SN_Socket_Chainplate_Starboard"],
	},
	"SN_Rig_Stays": {
		"root": "SN_Rig_Stays_Root",
		"sockets": ["SN_Mount", "SN_Socket_Mast_Top", "SN_Socket_Bowsprit_Tip"],
	},
	"SN_Rig_Running": {
		"root": "SN_Rig_Running_Root",
		"sockets": ["SN_Mount", "SN_Socket_Mast_Top", "SN_Socket_Sail_Clew"],
	},
}

const SHIPS := {
	"SN_Paddle_Freighter": {
		"root": "SN_PF_Root",
		"sockets": ["SN_Socket_Mast_Fore", "SN_Socket_Yard_Fore", "SN_Socket_Sail_Fore", "SN_Socket_Mast_Main", "SN_Socket_Yard_Main", "SN_Socket_Sail_Main"],
	},
	"SN_Schooner_Fame": {
		"root": "SN_SF_Root",
		"sockets": ["SN_Socket_Mast_Fore", "SN_Socket_Mast_Main", "SN_Socket_Yard_Fore", "SN_Socket_Yard_Main", "SN_Socket_Sail_Fore", "SN_Socket_Sail_Main", "SN_Socket_Sail_Jib"],
	},
	"SN_Ironclad": {
		"root": "SN_Ironclad",
		"sockets": ["SN_Socket_Mast_Fore", "SN_Socket_Yard_Fore", "SN_Socket_Sail_Fore", "SN_Socket_Mast_Main", "SN_Socket_Yard_Main", "SN_Socket_Sail_Main", "SN_Socket_Mast_Mizzen", "SN_Socket_Yard_Mizzen", "SN_Socket_Sail_Mizzen"],
	},
}


func test_rig_kit_assets_expose_mount_and_sockets() -> void:
	ContentAssetLoader.clear_cache()
	for asset in ASSETS.keys():
		var spec: Dictionary = ASSETS[asset]
		var scene := ContentAssetLoader.load_scene("%s/%s.glb" % [RIG_DIR, asset])
		assert_not_null(scene, "%s GLB loads" % asset)
		if scene == null:
			continue
		var root := _find_node(scene, String(spec["root"]))
		assert_not_null(root, "%s root node exists" % asset)
		if root == null:
			continue
		var mount := _find_node(scene, "SN_Mount")
		assert_not_null(mount, "%s exposes SN_Mount" % asset)
		if mount != null:
			assert_eq(mount.get_parent(), root, "%s/SN_Mount is a direct child of root" % asset)
			assert_eq(_mesh_descendants(mount), 0, "%s/SN_Mount is an empty node" % asset)
		var expected: Array = spec["sockets"].duplicate()
		expected.erase("SN_Mount")
		var found := {}
		for node in _nodes_named(scene, "SN_Socket_"):
			found[node.name] = node
		assert_eq(found.size(), expected.size(),
			"%s exposes exactly the declared number of rig sockets" % asset)
		for socket_name in expected:
			assert_true(found.has(socket_name), "%s exposes %s" % [asset, socket_name])
			if not found.has(socket_name):
				continue
			var socket: Node = found[socket_name]
			assert_eq(socket.get_parent(), root,
				"%s/%s is a direct child of the asset root" % [asset, socket_name])
			assert_eq(_mesh_descendants(socket), 0,
				"%s/%s is an empty node" % [asset, socket_name])
		var meshes := _mesh_descendants(root)
		assert_eq(meshes, 1, "%s is one mesh body" % asset)


func test_rig_kit_root_extras_match_the_contract() -> void:
	for asset in ASSETS.keys():
		var spec: Dictionary = ASSETS[asset]
		var gltf := _load_glb_json("%s/%s.glb" % [RIG_DIR, asset])
		assert_true(not gltf.is_empty(), "%s GLB JSON parses" % asset)
		if gltf.is_empty():
			continue
		var nodes: Array = gltf.get("nodes", [])
		var root_index := -1
		var by_name := {}
		for index in nodes.size():
			var node_name := String(nodes[index].get("name", ""))
			assert_false(node_name.ends_with(".001"),
				"%s has no .001 suffixed node (%s)" % [asset, node_name])
			by_name[node_name] = index
			if node_name == String(spec["root"]):
				root_index = index
		assert_true(root_index >= 0, "%s root found in GLB JSON" % asset)
		if root_index < 0:
			continue
		var extras: Dictionary = nodes[root_index].get("extras", {})
		assert_eq(String(extras.get("kit_family", "")), "rig_kit",
			"%s root declares kit_family rig_kit" % asset)
		assert_eq(String(extras.get("rig_spec", "")), RIG_SPEC,
			"%s root declares %s" % [asset, RIG_SPEC])
		assert_eq(extras.get("rig_sockets", []), spec["sockets"],
			"%s root rig_sockets list matches the socket order" % asset)
		assert_eq(int(extras.get("rig_socket_count", -1)), Array(spec["sockets"]).size(),
			"%s root rig_socket_count matches" % asset)
		assert_true(extras.has("tri_budget"), "%s root carries tri_budget" % asset)
		assert_true(extras.has("datum"), "%s root carries datum" % asset)
		var children: Array = nodes[root_index].get("children", [])
		var child_indices := {}
		for child in children:
			child_indices[int(child)] = true
		for socket_name in spec["sockets"]:
			var index: int = int(by_name[socket_name])
			assert_false(nodes[index].has("mesh"),
				"%s/%s has no mesh" % [asset, socket_name])
			assert_true(child_indices.has(index),
				"%s/%s is parented to the root" % [asset, socket_name])
			var socket_extras: Dictionary = nodes[index].get("extras", {})
			assert_eq(String(socket_extras.get("socket_spec", "")), SOCKET_SPEC,
				"%s/%s carries socket_spec" % [asset, socket_name])


func test_ship_rig_sockets_are_empty_children_of_the_hull_root() -> void:
	ContentAssetLoader.clear_cache()
	var total := 0
	for asset in SHIPS.keys():
		var spec: Dictionary = SHIPS[asset]
		var scene := ContentAssetLoader.load_scene("%s/%s.glb" % [SHIPS_DIR, asset])
		assert_not_null(scene, "%s GLB loads" % asset)
		if scene == null:
			continue
		var root := _find_node(scene, String(spec["root"]))
		assert_not_null(root, "%s hull root exists" % asset)
		if root == null:
			continue
		var expected: Array = spec["sockets"]
		var found := {}
		for node in _nodes_named(scene, "SN_Socket_"):
			var node_name := String(node.name)
			if not node_name.begins_with("SN_Socket_Mast_") and not node_name.begins_with("SN_Socket_Yard_") and not node_name.begins_with("SN_Socket_Sail_"):
				continue
			found[node.name] = node
		assert_eq(found.size(), expected.size(),
			"%s exposes the declared number of rig sockets" % asset)
		total += found.size()
		for socket_name in expected:
			assert_true(found.has(socket_name), "%s exposes %s" % [asset, socket_name])
			if not found.has(socket_name):
				continue
			var socket: Node = found[socket_name]
			assert_eq(socket.get_parent(), root,
				"%s/%s is a direct child of the hull root" % [asset, socket_name])
			assert_eq(_mesh_descendants(socket), 0,
				"%s/%s is an empty node" % [asset, socket_name])
	assert_eq(total, 22, "three ships expose 22 hull-side rig sockets in total")
	for asset in SHIPS.keys():
		var spec: Dictionary = SHIPS[asset]
		var gltf := _load_glb_json("%s/%s.glb" % [SHIPS_DIR, asset])
		assert_true(not gltf.is_empty(), "%s GLB JSON parses" % asset)
		if gltf.is_empty():
			continue
		var nodes: Array = gltf.get("nodes", [])
		var root_index := -1
		for index in nodes.size():
			if String(nodes[index].get("name", "")) == String(spec["root"]):
				root_index = index
		assert_true(root_index >= 0, "%s root found in GLB JSON" % asset)
		if root_index < 0:
			continue
		var extras: Dictionary = nodes[root_index].get("extras", {})
		assert_eq(extras.get("rig_sockets", []), spec["sockets"],
			"%s root rig_sockets list matches the socket order" % asset)
		assert_eq(int(extras.get("rig_socket_count", -1)), Array(spec["sockets"]).size(),
			"%s root rig_socket_count matches" % asset)
		assert_eq(String(extras.get("rig_socket_spec", "")), SOCKET_SPEC,
			"%s root declares %s" % [asset, SOCKET_SPEC])


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
