## @static-doc
## 作用：守护运行时武器装配层（`ShipWeaponAssembly` / `ShipWeaponMount`）与契约 v2 / M0-3 船体安装点：socket 发现与排序、武器 Root extras 读取、class 硬门禁、`SN_Mount` 精确对齐、`mount_scale`、机制节点与多联装、瞄准 / 后坐轴、净空软判定（socket 局部实测、非 envelope / base_footprint）以及 `clear_mounted`。
##
## ## 契约与约束
## - 资产用 `ContentAssetLoader.instantiate_model()` 读 4 艘船与 8+1 件武器原始 GLB，挂到 SceneTree 根下的临时 holder，保证 `global_transform` 与实际游戏一致；每个测试自建 / 释放 holder。
## - class 是唯一硬门禁：class 匹配必定装配成功（即使净空 `fits=false`），class 不匹配、`Modular` kit 件、缺 `SN_Mount` 返回 `null` 并释放实例。
## - 对齐断言用 0.001 m / 角度容差；`mount_scale=0.5` 必须让 socket 局部 pad 与 height 同步减半（防空/防未缩放回归）。
## - 净空口径锁定 §8.3：pad 排除 pitch/recoil 子树、在 socket 帧实测；F1 陷阱（`base_footprint_*` = envelope）用正向用例守死：DeckGun / HeavyCannon 能装进 clearance 较小的 socket。
## - 测试不依赖场景 / UI / 存档；不写 GameState。注册在 `framework/tests/test_runner.gd` 的 `SUITE_PATHS`。
## @end-static-doc

extends TestCase
## Guards the runtime weapon-assembly layer (`ShipWeaponAssembly` / `ShipWeaponMount`)
## against `docs/design/WEAPON_SOCKET_CONTRACT.md` v2 and the M0-3 hull sockets:
## - `find_sockets()` returns every `SN_Socket_Weapon_*` node of the four hull GLBs in
##   `socket_index` order, and `socket_info()` reads the hull-side extras safely;
## - `find_weapon_root()` / `weapon_info()` / `find_mount()` read the weapon Root extras
##   (`weapon-assembly@2`) for all eight batch weapons + the Modular turret kit part;
## - the class gate is the only hard gate: matching class mounts, mismatch and Modular kit
##   parts return `null` with a human-readable reason and free the instance;
## - `mount()` puts `SN_Mount` exactly on the socket frame (origin + basis), re-parents the
##   weapon under the socket and honours `mount_scale`;
## - mechanism discovery follows the standard node names, and `aim()` / `recoil()` /
##   `reset_all()` move every indexed pitch/recoil/muzzle node by the documented axes;
## - `clearance_report()` is the soft §8.3 verdict measured in socket-local metres from the
##   mount-pad mesh bbox (not `envelope_*` / `base_footprint_*`, the F1 trap), and mounting
##   still succeeds when it reports overhang.
##
## Assets are raw GLBs loaded through `ContentAssetLoader.instantiate_model()` and parented
## to a throw-away holder under the SceneTree root, so `global_transform` is real.

const HULLS_DIR := "res://dev_mods/core/assets/models/ships"
const WEAPONS_DIR := "res://assets/models/weapons"
const SOCKET_PREFIX := "SN_Socket_Weapon_"
const MOUNT_NAME := "SN_Mount"
const SOCKET_SPEC := "hull-sockets@1"
const ASSEMBLY_SPEC := "weapon-assembly@2"

## Expected sockets per hull, in `socket_index` order (contract §8.1).
const HULL_SOCKETS := {
	"SN_Paddle_Steamer": {
		"names": [
			"SN_Socket_Weapon_Port_1",
			"SN_Socket_Weapon_Starboard_1",
			"SN_Socket_Weapon_Stern",
		],
		"classes": ["Light", "Light", "Medium"],
	},
	"SN_Paddle_Freighter": {
		"names": [
			"SN_Socket_Weapon_Port_1",
			"SN_Socket_Weapon_Starboard_1",
			"SN_Socket_Weapon_Port_2",
			"SN_Socket_Weapon_Starboard_2",
		],
		"classes": ["Side", "Side", "Light", "Light"],
	},
	"SN_Schooner_Fame": {
		"names": [
			"SN_Socket_Weapon_Port_1",
			"SN_Socket_Weapon_Starboard_1",
			"SN_Socket_Weapon_Bow",
		],
		"classes": ["Light", "Light", "Medium"],
	},
	"SN_Ironclad": {
		"names": [
			"SN_Socket_Weapon_Port_1",
			"SN_Socket_Weapon_Starboard_1",
			"SN_Socket_Weapon_Port_2",
			"SN_Socket_Weapon_Starboard_2",
		],
		"classes": ["Heavy", "Heavy", "Medium", "Medium"],
	},
}

## Expected Root-extras contract values per weapon asset (contract §4 / §7 F1).
## `yaw/pitch/recoil/muzzle` are mechanism node counts (not `muzzle_count`).
const WEAPON_EXPECTED := {
	"SN_Weapon_DeckGun": {
		"class": "Light", "profile": "yaw_pitch", "muzzle_count": 1,
		"yaw": 1, "pitch": 1, "recoil": 1, "muzzle": 1,
	},
	"SN_Weapon_Repeater": {
		"class": "Medium", "profile": "yaw_pitch", "muzzle_count": 1,
		"yaw": 1, "pitch": 1, "recoil": 1, "muzzle": 1,
	},
	"SN_Weapon_HarpoonLauncher": {
		"class": "Medium", "profile": "yaw_pitch", "muzzle_count": 1,
		"yaw": 1, "pitch": 1, "recoil": 1, "muzzle": 1,
	},
	"SN_Weapon_HeavyCannon": {
		"class": "Heavy", "profile": "yaw_pitch", "muzzle_count": 1,
		"yaw": 1, "pitch": 1, "recoil": 1, "muzzle": 1,
	},
	"SN_Weapon_Mortar": {
		"class": "Heavy", "profile": "yaw_pitch", "muzzle_count": 1,
		"yaw": 1, "pitch": 1, "recoil": 1, "muzzle": 1,
	},
	"SN_Weapon_Broadside": {
		"class": "Side", "profile": "pitch_only", "muzzle_count": 4,
		"yaw": 0, "pitch": 4, "recoil": 4, "muzzle": 4,
	},
	"SN_Weapon_ArrowTower": {
		"class": "Tower", "profile": "fixed", "muzzle_count": 1,
		"yaw": 0, "pitch": 0, "recoil": 0, "muzzle": 0,
	},
	"SN_Weapon_Turret": {
		"class": "Modular", "profile": "yaw_only", "muzzle_count": 1,
		"yaw": 1, "pitch": 0, "recoil": 0, "muzzle": 1,
	},
}

var _holder: Node3D


func test_find_sockets_returns_declared_sockets_in_index_order() -> void:
	var holder := _holder_node()
	for hull_asset in HULL_SOCKETS.keys():
		var hull := _load_hull(holder, String(hull_asset))
		assert_not_null(hull, "%s GLB loads" % hull_asset)
		if hull == null:
			continue
		var spec: Dictionary = HULL_SOCKETS[hull_asset]
		var expected_names: Array = spec["names"]
		var expected_classes: Array = spec["classes"]
		var sockets := ShipWeaponAssembly.find_sockets(hull)
		assert_eq(sockets.size(), expected_names.size(),
			"%s exposes the declared number of weapon sockets" % hull_asset)
		var actual_names: Array = []
		var previous_index := -1
		for socket in sockets:
			assert_true(socket is Node3D, "%s socket entries are Node3D" % hull_asset)
			if not (socket is Node3D):
				continue
			actual_names.append(String(socket.name))
			var info := ShipWeaponAssembly.socket_info(socket)
			assert_true(int(info["index"]) > previous_index,
				"%s sockets are ordered by socket_index (%s)" % [hull_asset, socket.name])
			previous_index = int(info["index"])
			assert_eq(info["socket_spec"], SOCKET_SPEC,
				"%s/%s declares %s" % [hull_asset, socket.name, SOCKET_SPEC])
			assert_almost_eq(float(info["mount_scale"]), 1.0, 0.0001,
				"%s/%s mount_scale is 1.0" % [hull_asset, socket.name])
			assert_true(not String(info["note"]).is_empty(),
				"%s/%s carries the human-readable note" % [hull_asset, socket.name])
		assert_eq(actual_names, expected_names,
			"%s socket names are returned in socket_index order" % hull_asset)
		if actual_names == expected_names:
			for index in expected_names.size():
				var socket := _find_socket(hull, String(expected_names[index]))
				assert_not_null(socket, "%s exposes %s" % [hull_asset, expected_names[index]])
				if socket == null:
					continue
				assert_eq(String(ShipWeaponAssembly.socket_info(socket)["class"]),
					String(expected_classes[index]),
					"%s/%s socket_class" % [hull_asset, expected_names[index]])
				assert_true(hull.is_ancestor_of(socket),
					"%s/%s is part of the hull scene" % [hull_asset, expected_names[index]])
	_free_holder()


func test_socket_info_exposes_contract_fields_and_safe_defaults() -> void:
	var holder := _holder_node()
	var hull := _load_hull(holder, "SN_Schooner_Fame")
	assert_not_null(hull, "SN_Schooner_Fame GLB loads")
	if hull != null:
		var socket := _find_socket(hull, "SN_Socket_Weapon_Bow")
		assert_not_null(socket, "SN_Schooner_Fame exposes the Bow socket")
		if socket != null:
			var info := ShipWeaponAssembly.socket_info(socket)
			assert_eq(info.size(), 10, "socket_info exposes the documented key set")
			for key in ["name", "index", "class", "clearance_r", "clearance_x",
					"clearance_y", "clearance_h", "mount_scale", "note", "socket_spec"]:
				assert_true(info.has(key), "socket_info carries %s" % key)
			var raw: Dictionary = socket.get_meta("extras", {})
			assert_eq(String(info["name"]), String(socket.name),
				"socket_info name matches the node")
			assert_eq(int(info["index"]), int(float(raw.get("socket_index", 0.0))),
				"Bow socket_index comes from the extras")
			assert_eq(String(info["class"]), String(raw.get("socket_class", "")),
				"Bow socket_class comes from the extras")
			for key in ["clearance_r", "clearance_x", "clearance_y", "clearance_h"]:
				assert_almost_eq(float(info[key]), float(raw.get(key, 0.0)), 0.0001,
					"Bow %s comes from the extras" % key)
			assert_almost_eq(float(info["mount_scale"]),
				float(raw.get("mount_scale", 1.0)), 0.0001,
				"Bow mount_scale comes from the extras")

		var bare := Node3D.new()
		bare.name = "SN_Socket_Weapon_Handmade"
		holder.add_child(bare)
		var fallback := ShipWeaponAssembly.socket_info(bare)
		assert_eq(String(fallback["class"]), "",
			"a socket without extras keeps an empty class instead of failing")
		assert_eq(int(fallback["index"]), 0,
			"a socket without extras defaults socket_index to 0")
		assert_almost_eq(float(fallback["mount_scale"]), 1.0, 0.0001,
			"a socket without extras defaults mount_scale to 1.0")
		assert_eq(String(fallback["socket_spec"]), "",
			"a socket without extras has no socket_spec")
	_free_holder()


func test_weapon_root_and_info_read_the_assembly_extras() -> void:
	var holder := _holder_node()
	for weapon_asset in WEAPON_EXPECTED.keys():
		var weapon := _load_weapon(holder, String(weapon_asset))
		assert_not_null(weapon, "%s GLB loads" % weapon_asset)
		if weapon == null:
			continue
		var root := ShipWeaponAssembly.find_weapon_root(weapon)
		assert_not_null(root, "%s find_weapon_root finds the Root extras node" % weapon_asset)
		if root == null:
			continue
		assert_eq(String(root.name), "%s_Root" % weapon_asset,
			"%s Root node keeps the asset name" % weapon_asset)
		var raw: Dictionary = root.get_meta("extras", {})
		assert_eq(String(raw.get("assembly_spec", "")), ASSEMBLY_SPEC,
			"%s Root declares %s" % [weapon_asset, ASSEMBLY_SPEC])
		var expected: Dictionary = WEAPON_EXPECTED[weapon_asset]
		var info := ShipWeaponAssembly.weapon_info(weapon)
		assert_eq(info.size(), 13, "%s weapon_info exposes the documented key set" % weapon_asset)
		for key in ["asset", "class", "mount_class", "profile", "has_yaw", "has_pitch",
				"has_recoil", "has_muzzle", "muzzle_count", "envelope_x", "envelope_y",
				"height", "assembly_spec"]:
			assert_true(info.has(key), "%s weapon_info carries %s" % [weapon_asset, key])
		assert_eq(String(info["asset"]), String(weapon_asset),
			"%s weapon_info asset" % weapon_asset)
		assert_eq(String(info["class"]), String(expected["class"]),
			"%s weapon_class" % weapon_asset)
		assert_eq(String(info["profile"]), String(expected["profile"]),
			"%s assembly_profile" % weapon_asset)
		assert_eq(String(info["assembly_spec"]), ASSEMBLY_SPEC,
			"%s weapon_info assembly_spec" % weapon_asset)
		for flag in ["has_yaw", "has_pitch", "has_recoil", "has_muzzle"]:
			assert_eq(bool(info[flag]), bool(raw.get(flag, false)),
				"%s weapon_info %s mirrors the extras" % [weapon_asset, flag])
		assert_eq(int(info["muzzle_count"]), int(expected["muzzle_count"]),
			"%s muzzle_count" % weapon_asset)
		assert_eq(int(info["muzzle_count"]), int(float(raw.get("muzzle_count", 0.0))),
			"%s muzzle_count mirrors the extras" % weapon_asset)
		assert_almost_eq(float(info["envelope_x"]), float(raw.get("envelope_x", 0.0)),
			0.0001, "%s envelope_x mirrors the extras" % weapon_asset)
		assert_almost_eq(float(info["envelope_y"]), float(raw.get("envelope_y", 0.0)),
			0.0001, "%s envelope_y mirrors the extras" % weapon_asset)
		assert_almost_eq(float(info["height"]), float(raw.get("height", 0.0)),
			0.0001, "%s height mirrors the extras" % weapon_asset)
		var mount_node := ShipWeaponAssembly.find_mount(weapon)
		assert_not_null(mount_node, "%s exposes %s" % [weapon_asset, MOUNT_NAME])
		if mount_node != null:
			assert_eq(String(mount_node.name), MOUNT_NAME,
				"%s find_mount returns the standard mount frame" % weapon_asset)
	_free_holder()


func test_class_gate_rejects_mismatches_and_modular_parts() -> void:
	var holder := _holder_node()
	var hull := _load_hull(holder, "SN_Paddle_Steamer")
	assert_not_null(hull, "SN_Paddle_Steamer GLB loads")
	if hull == null:
		_free_holder()
		return
	var light_socket := _find_socket(hull, "SN_Socket_Weapon_Port_1")
	assert_not_null(light_socket, "SN_Paddle_Steamer exposes a Light socket")
	if light_socket == null:
		_free_holder()
		return
	var light_socket_info := ShipWeaponAssembly.socket_info(light_socket)
	var deck_gun := _load_weapon(holder, "SN_Weapon_DeckGun")
	var deck_gun_info := ShipWeaponAssembly.weapon_info(deck_gun)
	assert_true(ShipWeaponAssembly.can_mount(deck_gun_info, light_socket_info),
		"DeckGun (Light) can mount on a Light socket")
	assert_eq(ShipWeaponAssembly.rejection_reason(deck_gun_info, light_socket_info), "",
		"DeckGun on a Light socket has no rejection reason")

	for weapon_asset in ["SN_Weapon_Repeater", "SN_Weapon_HarpoonLauncher",
			"SN_Weapon_HeavyCannon", "SN_Weapon_Mortar", "SN_Weapon_Broadside"]:
		var weapon := _load_weapon(holder, String(weapon_asset))
		assert_not_null(weapon, "%s GLB loads" % weapon_asset)
		if weapon == null:
			continue
		var info := ShipWeaponAssembly.weapon_info(weapon)
		assert_false(ShipWeaponAssembly.can_mount(info, light_socket_info),
			"%s cannot mount on a Light socket" % weapon_asset)
		var reason := ShipWeaponAssembly.rejection_reason(info, light_socket_info)
		assert_true(reason.contains("class mismatch"),
			"%s rejection explains the class mismatch (got '%s')" % [weapon_asset, reason])
		var mounted := ShipWeaponAssembly.mount(light_socket, weapon)
		assert_eq(mounted, null, "%s mount returns null on a class mismatch" % weapon_asset)
		assert_true(weapon.is_queued_for_deletion(),
			"%s instance is freed after a rejected mount" % weapon_asset)

	var heavy_hull := _load_hull(holder, "SN_Ironclad")
	assert_not_null(heavy_hull, "SN_Ironclad GLB loads")
	if heavy_hull != null:
		var heavy_socket := _find_socket(heavy_hull, "SN_Socket_Weapon_Port_1")
		assert_not_null(heavy_socket, "SN_Ironclad exposes a Heavy socket")
		if heavy_socket != null:
			var heavy_socket_info := ShipWeaponAssembly.socket_info(heavy_socket)
			var turret := _load_weapon(holder, "SN_Weapon_Turret")
			var turret_info := ShipWeaponAssembly.weapon_info(turret)
			assert_eq(String(turret_info["class"]), "Modular",
				"Turret kit part reports the Modular class")
			assert_false(ShipWeaponAssembly.can_mount(turret_info, heavy_socket_info),
				"Modular kit parts never mount directly on a hull, even on a matching mount_class")
			var turret_reason := ShipWeaponAssembly.rejection_reason(turret_info, heavy_socket_info)
			assert_true(turret_reason.contains("modular kit part"),
				"Modular rejection is reported before the class mismatch (got '%s')" % turret_reason)
			var rejected := ShipWeaponAssembly.mount(heavy_socket, turret)
			assert_eq(rejected, null, "mount() rejects a Modular kit part")
			assert_true(turret.is_queued_for_deletion(),
				"rejected Modular instance is freed")

	var bare := Node3D.new()
	bare.name = "NotAWeapon"
	holder.add_child(bare)
	var bare_info := ShipWeaponAssembly.weapon_info(bare)
	assert_eq(String(bare_info["class"]), "",
		"a node without assembly extras reports no weapon class")
	assert_true(ShipWeaponAssembly.rejection_reason(bare_info, light_socket_info)
		.contains("no assembly extras"),
		"a node without assembly extras is rejected with a clear reason")
	_free_holder()


func test_mount_aligns_sn_mount_exactly_with_the_socket() -> void:
	var holder := _holder_node()
	var cases := [
		{"hull": "SN_Paddle_Steamer", "socket": "SN_Socket_Weapon_Port_1",
			"weapon": "SN_Weapon_DeckGun", "class": "Light"},
		{"hull": "SN_Paddle_Steamer", "socket": "SN_Socket_Weapon_Stern",
			"weapon": "SN_Weapon_Repeater", "class": "Medium"},
		{"hull": "SN_Paddle_Freighter", "socket": "SN_Socket_Weapon_Port_1",
			"weapon": "SN_Weapon_Broadside", "class": "Side"},
		{"hull": "SN_Schooner_Fame", "socket": "SN_Socket_Weapon_Bow",
			"weapon": "SN_Weapon_HarpoonLauncher", "class": "Medium"},
		{"hull": "SN_Ironclad", "socket": "SN_Socket_Weapon_Port_1",
			"weapon": "SN_Weapon_HeavyCannon", "class": "Heavy"},
	]
	for entry in cases:
		var hull := _load_hull(holder, String(entry["hull"]))
		assert_not_null(hull, "%s GLB loads for the alignment case" % entry["hull"])
		if hull == null:
			continue
		var socket := _find_socket(hull, String(entry["socket"]))
		assert_not_null(socket, "%s exposes %s" % [entry["hull"], entry["socket"]])
		if socket == null:
			continue
		var weapon := _load_weapon(holder, String(entry["weapon"]))
		assert_not_null(weapon, "%s GLB loads for the alignment case" % entry["weapon"])
		if weapon == null:
			continue
		var mount := ShipWeaponAssembly.mount(socket, weapon)
		assert_not_null(mount,
			"%s mounts on %s/%s" % [entry["weapon"], entry["hull"], entry["socket"]])
		if mount == null:
			continue
		assert_eq(mount.socket, socket, "%s mount keeps the socket reference" % entry["weapon"])
		assert_eq(mount.weapon, weapon, "%s mount keeps the weapon reference" % entry["weapon"])
		assert_not_null(mount.mount_node, "%s mount exposes its SN_Mount" % entry["weapon"])
		assert_eq(weapon.get_parent(), socket,
			"%s is re-parented under the socket" % entry["weapon"])
		assert_true(ShipWeaponAssembly.is_mounted(weapon),
			"%s reports as mounted" % entry["weapon"])
		assert_eq(ShipWeaponAssembly.find_mount(weapon), mount.mount_node,
			"%s find_mount returns the aligned frame" % entry["weapon"])
		assert_almost_eq(mount.scale, 1.0, 0.0001,
			"%s socket mount_scale is 1.0" % entry["weapon"])
		assert_eq(mount.socket_name(), String(socket.name),
			"%s socket_name matches" % entry["weapon"])
		assert_eq(mount.weapon_asset(), String(entry["weapon"]),
			"%s weapon_asset matches" % entry["weapon"])
		assert_eq(mount.weapon_class(), String(entry["class"]),
			"%s weapon_class matches the socket class" % entry["weapon"])
		assert_eq(String(mount.socket_info["class"]), String(entry["class"]),
			"%s socket class matches" % entry["weapon"])
		if mount.mount_node == null:
			continue
		var origin_error := mount.mount_node.global_position.distance_to(socket.global_position)
		assert_almost_eq(origin_error, 0.0, 0.001,
			"%s SN_Mount origin lands on the socket origin" % entry["weapon"])
		var basis_delta := _basis_max_delta(
			mount.mount_node.global_transform.basis, socket.global_transform.basis)
		assert_almost_eq(basis_delta, 0.0, 0.001,
			"%s SN_Mount basis equals the socket basis" % entry["weapon"])
	_free_holder()


func test_mount_scale_scales_the_weapon_geometry() -> void:
	var holder := _holder_node()
	var hull := _load_hull(holder, "SN_Paddle_Steamer")
	assert_not_null(hull, "SN_Paddle_Steamer GLB loads for the scale case")
	if hull == null:
		_free_holder()
		return
	var socket := _find_socket(hull, "SN_Socket_Weapon_Port_1")
	assert_not_null(socket, "SN_Socket_Weapon_Port_1 exists for the scale case")
	if socket == null:
		_free_holder()
		return
	var full_weapon := _load_weapon(holder, "SN_Weapon_DeckGun")
	var full_mount := ShipWeaponAssembly.mount(socket, full_weapon, 1.0)
	assert_not_null(full_mount, "DeckGun mounts at mount_scale 1.0")
	var scaled_weapon := _load_weapon(holder, "SN_Weapon_DeckGun")
	var scaled_mount := ShipWeaponAssembly.mount(socket, scaled_weapon, 0.5)
	assert_not_null(scaled_mount, "DeckGun mounts at mount_scale 0.5")
	if full_mount == null or scaled_mount == null:
		_free_holder()
		return
	assert_almost_eq(scaled_mount.scale, 0.5, 0.0001,
		"explicit mount_scale 0.5 is kept on the mount")
	var full_extents := _weapon_aabb_in_space(full_weapon,
		socket.global_transform.affine_inverse())
	var scaled_extents := _weapon_aabb_in_space(scaled_weapon,
		socket.global_transform.affine_inverse())
	assert_true(full_extents.size.x > 0.1 and full_extents.size.z > 0.1,
		"the socket-local DeckGun AABB is measurable")
	if full_extents.size.x > 0.1:
		assert_almost_eq(scaled_extents.size.x / full_extents.size.x, 0.5, 0.01,
			"mount_scale 0.5 halves the socket-local X extent of the weapon geometry")
	if full_extents.size.z > 0.1:
		assert_almost_eq(scaled_extents.size.z / full_extents.size.z, 0.5, 0.01,
			"mount_scale 0.5 halves the socket-local Z extent of the weapon geometry")
	# The public static `mount_pad_aabb(socket, weapon, mechanism)` must return the same
	# socket-local pad frame the mount captured at assembly time.
	var mechanism := ShipWeaponAssembly.find_mechanism_nodes(scaled_weapon)
	var direct_pad := ShipWeaponAssembly.mount_pad_aabb(socket, scaled_weapon, mechanism)
	assert_almost_eq(direct_pad.position.distance_to(scaled_mount.pad_aabb.position), 0.0,
		0.001, "mount_pad_aabb(socket, weapon, mechanism) returns the socket-local pad")
	assert_almost_eq(direct_pad.size.distance_to(scaled_mount.pad_aabb.size), 0.0,
		0.001, "mount_pad_aabb matches the mount's captured pad_aabb")
	_free_holder()


func test_mount_scale_halves_the_reported_clearance_extents() -> void:
	var holder := _holder_node()
	var hull := _load_hull(holder, "SN_Paddle_Steamer")
	assert_not_null(hull, "SN_Paddle_Steamer GLB loads for the scaled clearance case")
	if hull == null:
		_free_holder()
		return
	var socket := _find_socket(hull, "SN_Socket_Weapon_Port_1")
	assert_not_null(socket, "SN_Socket_Weapon_Port_1 exists for the scaled clearance case")
	if socket == null:
		_free_holder()
		return
	var full_mount := ShipWeaponAssembly.mount(
		socket, _load_weapon(holder, "SN_Weapon_DeckGun"), 1.0)
	assert_not_null(full_mount, "DeckGun mounts at mount_scale 1.0 for the clearance baseline")
	var scaled_mount := ShipWeaponAssembly.mount(
		socket, _load_weapon(holder, "SN_Weapon_DeckGun"), 0.5)
	assert_not_null(scaled_mount, "DeckGun mounts at mount_scale 0.5 for the clearance baseline")
	if full_mount == null or scaled_mount == null:
		_free_holder()
		return
	var full_report := full_mount.clearance_report()
	var scaled_report := scaled_mount.clearance_report()
	# Contract: `clearance_report()` is measured in socket-local metres (mount header),
	# so a uniformly scaled weapon occupies half the socket-local footprint.
	assert_almost_eq(float(scaled_report["half_x"]), float(full_report["half_x"]) * 0.5, 0.06,
		"mount_scale 0.5 halves the reported socket-local half_x")
	assert_almost_eq(float(scaled_report["half_z"]), float(full_report["half_z"]) * 0.5, 0.06,
		"mount_scale 0.5 halves the reported socket-local half_z")
	assert_almost_eq(float(scaled_report["height"]), float(full_report["height"]) * 0.5, 0.05,
		"mount_scale 0.5 halves the reported socket-local height")
	_free_holder()


func test_mechanism_nodes_follow_the_standard_names() -> void:
	var holder := _holder_node()
	for weapon_asset in WEAPON_EXPECTED.keys():
		var weapon := _load_weapon(holder, String(weapon_asset))
		assert_not_null(weapon, "%s GLB loads for mechanism discovery" % weapon_asset)
		if weapon == null:
			continue
		var expected: Dictionary = WEAPON_EXPECTED[weapon_asset]
		var mechanism := ShipWeaponAssembly.find_mechanism_nodes(weapon)
		for key in ["yaw", "pitch", "recoil", "muzzle"]:
			var nodes: Array = mechanism[key]
			assert_eq(nodes.size(), int(expected[key]),
				"%s %s node count" % [weapon_asset, key])
			for node in nodes:
				assert_true(node is Node3D, "%s %s entry is Node3D" % [weapon_asset, key])
		if int(expected["pitch"]) > 1:
			var suffixes: Array = []
			for node in mechanism["pitch"]:
				suffixes.append(_node_suffix(node))
			var sorted_suffixes := suffixes.duplicate()
			sorted_suffixes.sort()
			assert_eq(suffixes, sorted_suffixes,
				"%s pitch nodes are ordered by index suffix" % weapon_asset)
			var muzzle_suffixes: Array = []
			for node in mechanism["muzzle"]:
				muzzle_suffixes.append(_node_suffix(node))
			var sorted_muzzle_suffixes := muzzle_suffixes.duplicate()
			sorted_muzzle_suffixes.sort()
			assert_eq(muzzle_suffixes, sorted_muzzle_suffixes,
				"%s muzzle nodes are ordered by index suffix" % weapon_asset)
	_free_holder()


func test_multi_muzzle_broadside_moves_every_muzzle() -> void:
	var holder := _holder_node()
	var hull := _load_hull(holder, "SN_Paddle_Freighter")
	assert_not_null(hull, "SN_Paddle_Freighter GLB loads")
	if hull == null:
		_free_holder()
		return
	var socket := _find_socket(hull, "SN_Socket_Weapon_Port_1")
	assert_not_null(socket, "SN_Paddle_Freighter exposes a Side socket")
	if socket == null:
		_free_holder()
		return
	var mount := ShipWeaponAssembly.mount(socket, _load_weapon(holder, "SN_Weapon_Broadside"))
	assert_not_null(mount, "Broadside mounts on a Side socket")
	if mount == null:
		_free_holder()
		return
	assert_eq(mount.muzzle_nodes.size(), 4, "Broadside exposes four muzzle nodes")
	var rest := mount.muzzle_world_positions()
	assert_eq(rest.size(), 4, "muzzle_world_positions returns all four muzzles")
	var forwards := mount.muzzle_forwards()
	assert_eq(forwards.size(), 4, "muzzle_forwards returns all four forwards")
	mount.aim(0.0, 20.0)
	var pitched := mount.muzzle_world_positions()
	assert_eq(pitched.size(), rest.size(), "aim keeps every muzzle indexed")
	for index in rest.size():
		assert_true(pitched[index].y > rest[index].y + 0.05,
			"aim(0,20) raises Broadside muzzle %d" % index)
	mount.reset_all()
	mount.recoil(0.4)
	var recoiled := mount.muzzle_world_positions()
	assert_eq(recoiled.size(), rest.size(), "recoil keeps every muzzle indexed")
	for index in rest.size():
		var delta := recoiled[index] - rest[index]
		assert_almost_eq(delta.length(), 0.4, 0.02,
			"recoil(0.4) moves Broadside muzzle %d by 0.4 m" % index)
		assert_true(delta.dot(forwards[index]) < -0.35,
			"recoil(0.4) moves Broadside muzzle %d backwards along -X" % index)
	mount.reset_all()
	var restored := mount.muzzle_world_positions()
	for index in rest.size():
		assert_almost_eq(restored[index].distance_to(rest[index]), 0.0, 0.001,
			"reset_all restores Broadside muzzle %d" % index)
	_free_holder()


func test_aim_yaw_moves_muzzle_and_positive_pitch_raises_it() -> void:
	var holder := _holder_node()
	var hull := _load_hull(holder, "SN_Paddle_Steamer")
	assert_not_null(hull, "SN_Paddle_Steamer GLB loads for the aim case")
	if hull == null:
		_free_holder()
		return
	var socket := _find_socket(hull, "SN_Socket_Weapon_Port_1")
	assert_not_null(socket, "SN_Socket_Weapon_Port_1 exists for the aim case")
	if socket == null:
		_free_holder()
		return
	var mount := ShipWeaponAssembly.mount(socket, _load_weapon(holder, "SN_Weapon_DeckGun"))
	assert_not_null(mount, "DeckGun mounts for the aim case")
	if mount == null:
		_free_holder()
		return
	var rest := mount.muzzle_world_positions()
	assert_eq(rest.size(), 1, "DeckGun exposes one muzzle")
	if rest.is_empty():
		_free_holder()
		return
	mount.aim(35.0, 0.0)
	assert_almost_eq(mount.yaw_deg(), 35.0, 0.0001, "yaw_deg reports the applied yaw")
	assert_almost_eq(mount.pitch_deg(), 0.0, 0.0001, "pitch_deg reports the applied pitch")
	var yawed := mount.muzzle_world_positions()
	assert_true(rest[0].distance_to(yawed[0]) > 0.2,
		"aim(35,0) moves the muzzle horizontally")
	assert_almost_eq(yawed[0].y, rest[0].y, 0.02,
		"yaw rotates around the up axis and keeps muzzle height")
	mount.aim(35.0, 0.0)
	var reaimed := mount.muzzle_world_positions()
	assert_almost_eq(reaimed[0].distance_to(yawed[0]), 0.0, 0.001,
		"repeated aim() calls do not drift")
	mount.reset_all()
	mount.aim(0.0, 25.0)
	var pitched := mount.muzzle_world_positions()
	assert_true(pitched[0].y > rest[0].y + 0.1,
		"aim(0,25) raises the muzzle: positive pitch lifts the barrel")
	mount.reset_all()
	var restored := mount.muzzle_world_positions()
	assert_almost_eq(restored[0].distance_to(rest[0]), 0.0, 0.001,
		"aim(0,0) restores the rest muzzle transform")
	assert_almost_eq(mount.yaw_deg(), 0.0, 0.0001, "reset_all clears yaw")
	assert_almost_eq(mount.pitch_deg(), 0.0, 0.0001, "reset_all clears pitch")
	for forward in mount.muzzle_forwards():
		assert_almost_eq(forward.length(), 1.0, 0.001,
			"muzzle_forwards returns unit vectors")
	_free_holder()


func test_recoil_moves_along_negative_x_and_is_absolute() -> void:
	var holder := _holder_node()
	var hull := _load_hull(holder, "SN_Paddle_Freighter")
	assert_not_null(hull, "SN_Paddle_Freighter GLB loads for the recoil case")
	if hull == null:
		_free_holder()
		return
	var socket := _find_socket(hull, "SN_Socket_Weapon_Port_2")
	assert_not_null(socket, "SN_Socket_Weapon_Port_2 exists for the recoil case")
	if socket == null:
		_free_holder()
		return
	var mount := ShipWeaponAssembly.mount(socket, _load_weapon(holder, "SN_Weapon_DeckGun"))
	assert_not_null(mount, "DeckGun mounts for the recoil case")
	if mount == null:
		_free_holder()
		return
	var rest := mount.muzzle_world_positions()
	var forwards := mount.muzzle_forwards()
	if rest.is_empty() or forwards.is_empty():
		assert_true(false, "DeckGun muzzle exists for the recoil case")
		_free_holder()
		return
	mount.recoil(0.4)
	assert_almost_eq(mount.recoil_offset(), 0.4, 0.0001, "recoil_offset reports 0.4")
	var recoiled := mount.muzzle_world_positions()
	var delta := recoiled[0] - rest[0]
	assert_almost_eq(delta.length(), 0.4, 0.02,
		"recoil(0.4) moves the muzzle by 0.4 m")
	assert_almost_eq(delta.dot(forwards[0]), -0.4, 0.02,
		"recoil(0.4) moves the muzzle backwards along weapon -X")
	mount.recoil(0.4)
	var repeated := mount.muzzle_world_positions()
	assert_almost_eq(repeated[0].distance_to(recoiled[0]), 0.0, 0.001,
		"recoil is an absolute offset, repeated calls do not stack")
	mount.recoil(0.0)
	var cleared := mount.muzzle_world_positions()
	assert_almost_eq(cleared[0].distance_to(rest[0]), 0.0, 0.001,
		"recoil(0) restores the rest muzzle position")
	mount.aim(20.0, 10.0)
	mount.recoil(0.4)
	mount.reset_all()
	var restored := mount.muzzle_world_positions()
	assert_almost_eq(restored[0].distance_to(rest[0]), 0.0, 0.001,
		"reset_all restores the muzzle after aim and recoil")
	assert_eq(mount.recoil_offset(), 0.0, "reset_all clears the recoil offset")
	mount.recoil(-1.0)
	assert_almost_eq(mount.recoil_offset(), 0.0, 0.0001,
		"negative recoil distance clamps to 0")
	_free_holder()


func test_clearance_report_is_soft_and_uses_the_pad_not_envelope() -> void:
	var holder := _holder_node()
	# F1 nuance: DeckGun `base_footprint_x`/`envelope_x` is 2.8 m (half 1.4 m), larger
	# than the PS Light socket `clearance_x` 1.35 m, yet the real base pad fits.
	var ps_hull := _load_hull(holder, "SN_Paddle_Steamer")
	if ps_hull != null:
		var ps_socket := _find_socket(ps_hull, "SN_Socket_Weapon_Port_1")
		if ps_socket != null:
			var deck_gun_mount := ShipWeaponAssembly.mount(
				ps_socket, _load_weapon(holder, "SN_Weapon_DeckGun"))
			assert_not_null(deck_gun_mount, "DeckGun mounts on the PS Light socket")
			if deck_gun_mount != null:
				var report := deck_gun_mount.clearance_report()
				assert_true(bool(report["fits"]),
					"DeckGun fits the PS Light socket: base pad is smaller than envelope_x")
				assert_true(float(report["half_x"]) < 1.0,
					"clearance half_x comes from the base pad, not the 2.8 m envelope")
	var schooner_hull := _load_hull(holder, "SN_Schooner_Fame")
	if schooner_hull != null:
		var bow_socket := _find_socket(schooner_hull, "SN_Socket_Weapon_Bow")
		assert_not_null(bow_socket, "SN_Schooner_Fame exposes the Bow socket")
		if bow_socket != null:
			var repeater_mount := ShipWeaponAssembly.mount(
				bow_socket, _load_weapon(holder, "SN_Weapon_Repeater"))
			assert_not_null(repeater_mount,
				"clearance is a soft verdict: Repeater still mounts on the SF Bow socket")
			if repeater_mount != null:
				var report := repeater_mount.clearance_report()
				assert_false(bool(report["fits"]),
					"Repeater on the SF Bow socket reports a clearance overhang")
				assert_true(not (report["reasons"] as Array).is_empty(),
					"the overhang verdict carries a reason")
				assert_almost_eq(float(report["half_x"]), 1.49, 0.02,
					"SF Bow Repeater half_x is the measured 1.49 m pad")
				assert_almost_eq(float(report["allowed_x"]), 1.10, 0.02,
					"SF Bow allowed_x is the socket clearance_x 1.10 m")
				assert_true(bool(report["fits"]) == false,
					"clearance overhang does not block the mount")
				repeater_mount.aim(0.0, 10.0)
				var raised := repeater_mount.muzzle_world_positions()
				assert_eq(raised.size(), 1,
					"an overhanging mount still exposes its muzzle")
			# Corrected measurement (§8.3): both Medium weapons overhang the narrow
			# SF Bow socket (HarpoonLauncher pad_x 1.40 m > clearance_x 1.10 m, not
			# just the Repeater), and the soft verdict still lets the mount succeed.
			var bow_harpoon_mount := ShipWeaponAssembly.mount(
				bow_socket, _load_weapon(holder, "SN_Weapon_HarpoonLauncher"))
			assert_not_null(bow_harpoon_mount,
				"HarpoonLauncher still mounts on the overhanging SF Bow socket")
			if bow_harpoon_mount != null:
				var harpoon_report := bow_harpoon_mount.clearance_report()
				assert_false(bool(harpoon_report["fits"]),
					"HarpoonLauncher on the SF Bow socket reports the outboard overhang")
				assert_almost_eq(float(harpoon_report["half_x"]), 1.40, 0.02,
					"SF Bow HarpoonLauncher half_x is the measured 1.40 m pad")
				assert_almost_eq(float(harpoon_report["allowed_x"]), 1.10, 0.02,
					"SF Bow HarpoonLauncher allowed_x is the socket clearance_x 1.10 m")
				assert_almost_eq(float(harpoon_report["height"]), 2.20, 0.02,
					"unscaled HarpoonLauncher height is reported in metres")
	var ironclad_hull := _load_hull(holder, "SN_Ironclad")
	if ironclad_hull != null:
		var heavy_socket := _find_socket(ironclad_hull, "SN_Socket_Weapon_Port_1")
		assert_not_null(heavy_socket, "SN_Ironclad exposes a Heavy socket")
		if heavy_socket != null:
			var cannon_mount := ShipWeaponAssembly.mount(
				heavy_socket, _load_weapon(holder, "SN_Weapon_HeavyCannon"))
			assert_not_null(cannon_mount, "HeavyCannon mounts on the IC Heavy socket")
			if cannon_mount != null:
				var report := cannon_mount.clearance_report()
				assert_true(bool(report["fits"]), "HeavyCannon fits the IC Heavy socket")
				assert_true(float(report["half_x"]) < 2.0,
					"HeavyCannon half_x is the 1.80 m pad, not the 4.8 m envelope")
		var medium_socket := _find_socket(ironclad_hull, "SN_Socket_Weapon_Port_2")
		assert_not_null(medium_socket, "SN_Ironclad exposes a Medium socket")
		if medium_socket != null:
			var harpoon_mount := ShipWeaponAssembly.mount(
				medium_socket, _load_weapon(holder, "SN_Weapon_HarpoonLauncher"))
			assert_not_null(harpoon_mount, "HarpoonLauncher mounts on the IC Medium socket")
			if harpoon_mount != null:
				assert_true(bool(harpoon_mount.clearance_report()["fits"]),
					"HarpoonLauncher fits the IC Medium socket")
	_free_holder()


func test_clear_mounted_frees_every_weapon_on_the_hull() -> void:
	var holder := _holder_node()
	var hull := _load_hull(holder, "SN_Paddle_Steamer")
	assert_not_null(hull, "SN_Paddle_Steamer GLB loads for the clear_mounted case")
	if hull == null:
		_free_holder()
		return
	var port_socket := _find_socket(hull, "SN_Socket_Weapon_Port_1")
	var stern_socket := _find_socket(hull, "SN_Socket_Weapon_Stern")
	assert_not_null(port_socket, "SN_Paddle_Steamer exposes the Port_1 socket")
	assert_not_null(stern_socket, "SN_Paddle_Steamer exposes the Stern socket")
	if port_socket == null or stern_socket == null:
		_free_holder()
		return
	var port_weapon := _load_weapon(holder, "SN_Weapon_DeckGun")
	var stern_weapon := _load_weapon(holder, "SN_Weapon_Repeater")
	assert_not_null(ShipWeaponAssembly.mount(port_socket, port_weapon), "Port_1 weapon mounts")
	assert_not_null(ShipWeaponAssembly.mount(stern_socket, stern_weapon), "Stern weapon mounts")
	assert_eq(port_socket.get_child_count(), 1,
		"the Port_1 socket holds its mounted weapon")
	assert_eq(stern_socket.get_child_count(), 1,
		"the Stern socket holds its mounted weapon")
	assert_true(ShipWeaponAssembly.is_mounted(port_weapon),
		"Port_1 weapon reports as mounted")
	assert_true(ShipWeaponAssembly.is_mounted(stern_weapon),
		"Stern weapon reports as mounted")
	var loose := _load_weapon(holder, "SN_Weapon_DeckGun")
	assert_false(ShipWeaponAssembly.is_mounted(loose),
		"an unparented weapon is not reported as mounted")
	ShipWeaponAssembly.clear_mounted(hull)
	assert_true(port_weapon.is_queued_for_deletion(),
		"clear_mounted frees the Port_1 weapon instance")
	assert_true(stern_weapon.is_queued_for_deletion(),
		"clear_mounted frees the Stern weapon instance")
	assert_false(loose.is_queued_for_deletion(),
		"clear_mounted leaves unmounted weapons alone")
	ShipWeaponAssembly.clear_mounted(hull)
	_free_holder()


func test_arrow_tower_pairs_with_no_hull_socket() -> void:
	var holder := _holder_node()
	var tower := _load_weapon(holder, "SN_Weapon_ArrowTower")
	assert_not_null(tower, "SN_Weapon_ArrowTower GLB loads")
	if tower == null:
		_free_holder()
		return
	var tower_info := ShipWeaponAssembly.weapon_info(tower)
	assert_eq(String(tower_info["class"]), "Tower",
		"ArrowTower declares the Tower weapon class")
	assert_eq(String(tower_info["profile"]), "fixed",
		"ArrowTower uses the fixed assembly profile")
	assert_false(bool(tower_info["has_yaw"]), "ArrowTower has no yaw node")
	assert_false(bool(tower_info["has_pitch"]), "ArrowTower has no pitch node")
	var accepted := 0
	for hull_asset in HULL_SOCKETS.keys():
		var hull := _load_hull(holder, String(hull_asset))
		assert_not_null(hull, "%s GLB loads for the Tower loadout case" % hull_asset)
		if hull == null:
			continue
		for socket in ShipWeaponAssembly.find_sockets(hull):
			var socket_info := ShipWeaponAssembly.socket_info(socket)
			assert_ne(String(socket_info["class"]), "Tower",
				"%s/%s is not a Tower socket" % [hull_asset, socket.name])
			if ShipWeaponAssembly.can_mount(tower_info, socket_info):
				accepted += 1
				assert_true(false,
					"Tower weapon must not pair with %s/%s" % [hull_asset, socket.name])
	assert_eq(accepted, 0,
		"the four hulls leave no socket for the ArrowTower Tower weapon")
	var ps_hull := _load_hull(holder, "SN_Paddle_Steamer")
	if ps_hull != null:
		var light_socket := _find_socket(ps_hull, "SN_Socket_Weapon_Port_1")
		if light_socket != null:
			var rejected := ShipWeaponAssembly.mount(
				light_socket, _load_weapon(holder, "SN_Weapon_ArrowTower"))
			assert_eq(rejected, null, "mount() rejects the Tower weapon on a Light socket")
	_free_holder()


# --- helpers ---------------------------------------------------------------

func _holder_node() -> Node3D:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node3D.new()
		_holder.name = "WeaponAssemblyTestHolder"
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			tree.root.add_child(_holder)
	return _holder


func _free_holder() -> void:
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
	_holder = null


func _load_hull(holder: Node3D, asset: String) -> Node3D:
	var hull := ContentAssetLoader.instantiate_model("%s/%s.glb" % [HULLS_DIR, asset])
	if hull != null and holder != null:
		holder.add_child(hull)
	return hull


func _load_weapon(holder: Node3D, asset: String) -> Node3D:
	var weapon := ContentAssetLoader.instantiate_model("%s/%s.glb" % [WEAPONS_DIR, asset])
	if weapon != null and holder != null:
		holder.add_child(weapon)
	return weapon


func _find_socket(hull: Node, socket_name: String) -> Node3D:
	for socket in ShipWeaponAssembly.find_sockets(hull):
		if String(socket.name) == socket_name:
			return socket
	return null


func _basis_max_delta(left: Basis, right: Basis) -> float:
	return maxf(maxf((left.x - right.x).length(), (left.y - right.y).length()),
		(left.z - right.z).length())


func _node_suffix(node: Node) -> int:
	var node_name := String(node.name)
	var tail := node_name.substr(node_name.rfind("_") + 1)
	return tail.to_int() if tail.is_valid_int() else 0


## AABB of every mesh under `root` expressed in the `space` frame.
func _weapon_aabb_in_space(root: Node3D, space: Transform3D) -> AABB:
	var bounds := AABB()
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				var box := _transform_aabb(space * mesh_instance.global_transform,
					mesh_instance.mesh.get_aabb())
				bounds = box if not found else bounds.merge(box)
				found = true
		for child in node.get_children():
			stack.append(child)
	return bounds


func _transform_aabb(xform: Transform3D, box: AABB) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for index in 8:
		var corner := box.position + Vector3(
			box.size.x if index & 1 else 0.0,
			box.size.y if index & 2 else 0.0,
			box.size.z if index & 4 else 0.0
		)
		var world_corner := xform * corner
		minimum = minimum.min(world_corner)
		maximum = maximum.max(world_corner)
	return AABB(minimum, maximum - minimum)
