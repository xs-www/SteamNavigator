## @static-doc
## 作用：武器装配运行时（契约 `weapon-assembly@2` / `hull-sockets@1` 的代码实现）：从船体 GLB 找 `SN_Socket_Weapon_*`、从武器 GLB 读 Root extras、按 `weapon_class == socket_class` 硬门禁配对，把武器 `SN_Mount` 对齐到 socket、按 `mount_scale` 缩放，并交出可操控的 `ShipWeaponMount`。
##
## - 关键依赖：`framework/ui/stages/ship_weapon_mount.gd`（装配结果）、`framework/services/content_asset_loader.gd`（调用方用它加载 GLB）
##
## ## 契约与约束
## - 只认标准节点名（`SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch*` / `SN_Recoil*` / `SN_Muzzle*`）与节点 extras（Godot 把 glTF extras 导入为 `get_meta("extras")` 字典），不认资产 ID。
## - 配对硬门禁：武器 `weapon_class` 必须等于 socket `socket_class`；`Modular`（model kit 基座 / 炮架 / 炮塔）不是完整武器，装配层不直接上船，返回原因。
## - 对齐以武器 `SN_Mount` 为准：装配后 `SN_Mount` 的世界变换原点 = socket 原点、基向量 = socket 基向量；`mount_scale` 只缩武器本体，不动 socket。
## - 净空按契约 §8.3：高度 ≤ `clearance_h`；底座占地在 socket 局部 X/Y 用「不随俯仰/后坐运动的网格」实测 bbox（不把 `envelope_*` 的炮管外伸算进去），逐轴与 `clearance_x` / `clearance_y` 比较。
## - 纯表现层：不读 GameState / 注册表；缺模型、缺 socket、class 不匹配只返回 `null` + 原因，不抛错、不阻断调用方。
## - 轴约定（Godot 导入后）：yaw 绕节点局部 +Y，pitch 绕节点局部 +Z（正角度抬高炮口），recoil 沿节点局部 -X 平移。
## @end-static-doc

class_name ShipWeaponAssembly
extends RefCounted
## Runtime half of `docs/design/WEAPON_SOCKET_CONTRACT.md`.
##
## The Blender/generator side only guarantees names and extras. This file is the
## game-side implementation of the assembly fallback chain (§5) and clearance
## rules (§8.3): find sockets, read weapon root extras, pair by class, align
## `SN_Mount` onto the socket, and hand back a `ShipWeaponMount` that combat/
## presentation code can aim, recoil and read muzzles from.
##
## All lookups are by standard node name and node extras, never by asset id.
## Missing pieces skip that mount and report why instead of failing the caller.

const SOCKET_PREFIX := "SN_Socket_Weapon_"
const MOUNT_NAME := "SN_Mount"
const YAW_NAME := "SN_Pivot_Yaw"
const PITCH_PREFIX := "SN_Pivot_Pitch"
const RECOIL_PREFIX := "SN_Recoil"
const MUZZLE_PREFIX := "SN_Muzzle"
const SOCKET_SPEC := "hull-sockets@1"
const ASSEMBLY_SPEC := "weapon-assembly@2"


## All weapon sockets under `hull`, ordered by `socket_index` then name.
static func find_sockets(hull: Node) -> Array[Node3D]:
	var sockets: Array[Node3D] = []
	_collect_named(hull, SOCKET_PREFIX, sockets)
	sockets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var a_index := float(socket_info(a).get("index", 0.0))
		var b_index := float(socket_info(b).get("index", 0.0))
		if absf(a_index - b_index) > 0.001:
			return a_index < b_index
		return String(a.name) < String(b.name)
	)
	return sockets


## Reads the hull-side socket extras from a `SN_Socket_Weapon_*` node.
##
## Keys: name, index, class, clearance_r/x/y/h, mount_scale, note. Missing
## extras fall back to safe defaults so a hand-made hull still assembles.
static func socket_info(socket: Node) -> Dictionary:
	var extras := _extras(socket)
	var socket_class := String(extras.get("socket_class", ""))
	return {
		"name": String(socket.name),
		"index": int(float(extras.get("socket_index", 0.0))),
		"class": socket_class,
		"clearance_r": float(extras.get("clearance_r", 0.0)),
		"clearance_x": float(extras.get("clearance_x", 0.0)),
		"clearance_y": float(extras.get("clearance_y", 0.0)),
		"clearance_h": float(extras.get("clearance_h", 0.0)),
		"mount_scale": float(extras.get("mount_scale", 1.0)),
		"note": String(extras.get("note", "")),
		"socket_spec": String(extras.get("socket_spec", "")),
	}


## The node that carries the weapon Root extras (`assembly_spec`), usually the
## `SN_Weapon_<Name>_Root` child of the imported GLB scene root.
static func find_weapon_root(weapon: Node) -> Node3D:
	var stack: Array[Node] = [weapon]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var extras := _extras(node)
		if extras.has("assembly_spec"):
			return node as Node3D
		for child in node.get_children():
			stack.append(child)
	return weapon as Node3D


## Reads the weapon Root extras (class, profile, pivot availability, envelope).
static func weapon_info(weapon: Node) -> Dictionary:
	var root := find_weapon_root(weapon)
	var extras := _extras(root)
	return {
		"asset": String(extras.get("asset", root.name if root != null else "")),
		"class": String(extras.get("weapon_class", "")),
		"mount_class": String(extras.get("mount_class", "")),
		"profile": String(extras.get("assembly_profile", "")),
		"has_yaw": bool(extras.get("has_yaw", false)),
		"has_pitch": bool(extras.get("has_pitch", false)),
		"has_recoil": bool(extras.get("has_recoil", false)),
		"has_muzzle": bool(extras.get("has_muzzle", false)),
		"muzzle_count": int(float(extras.get("muzzle_count", 0.0))),
		"envelope_x": float(extras.get("envelope_x", 0.0)),
		"envelope_y": float(extras.get("envelope_y", 0.0)),
		"height": float(extras.get("height", 0.0)),
		"assembly_spec": String(extras.get("assembly_spec", "")),
	}


## Hard gate from §5: a complete weapon mounts only on a socket of the same class.
## `Modular` kit parts (cannon body / carriage / turret / pedestal) are not
## complete weapons and are assembled by the kit layer, not directly on a hull.
static func can_mount(info: Dictionary, socket: Dictionary) -> bool:
	return rejection_reason(info, socket).is_empty()


## Human-readable reason why a weapon cannot take a socket ("" when compatible).
static func rejection_reason(info: Dictionary, socket: Dictionary) -> String:
	var weapon_class := String(info.get("class", ""))
	var socket_class := String(socket.get("class", ""))
	if weapon_class.is_empty():
		return "weapon has no assembly extras (missing SN_Weapon_* Root extras)"
	if weapon_class == "Modular":
		return "modular kit part (%s), not a complete weapon" % String(info.get("profile", ""))
	if socket_class.is_empty():
		return "socket has no socket_class extras"
	if weapon_class != socket_class:
		return "class mismatch: weapon %s vs socket %s" % [weapon_class, socket_class]
	return ""


## Instances `weapon` under `socket`, aligns `SN_Mount` onto the socket and
## returns the mount controller. Returns `null` when the pair is incompatible or
## the weapon has no `SN_Mount`; in that case the weapon instance is freed.
static func mount(socket: Node3D, weapon: Node3D, mount_scale: float = -1.0) -> ShipWeaponMount:
	if socket == null or weapon == null:
		return null
	var info := weapon_info(weapon)
	var socket_info_value := socket_info(socket)
	var reason := rejection_reason(info, socket_info_value)
	if not reason.is_empty():
		push_warning("ShipWeaponAssembly: skip %s -> %s: %s" % [info.get("asset", ""), socket.name, reason])
		weapon.queue_free()
		return null
	var mount_node := find_mount(weapon)
	if mount_node == null:
		push_warning("ShipWeaponAssembly: %s has no %s" % [weapon.name, MOUNT_NAME])
		weapon.queue_free()
		return null
	if weapon.get_parent() != null:
		weapon.get_parent().remove_child(weapon)
	socket.add_child(weapon)
	weapon.transform = Transform3D.IDENTITY
	var scale_value := mount_scale if mount_scale > 0.0 else float(socket_info_value.get("mount_scale", 1.0))
	var local_to_mount := weapon.global_transform.affine_inverse() * mount_node.global_transform
	var scaled := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), Vector3.ZERO)
	var offset := scaled * local_to_mount.affine_inverse()
	weapon.transform = offset
	return ShipWeaponMount.new(socket, weapon, mount_node, info, socket_info_value, scale_value)


## Finds the first `SN_Mount` node in the weapon instance.
static func find_mount(weapon: Node) -> Node3D:
	var stack: Array[Node] = [weapon]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D and String(node.name) == MOUNT_NAME:
			return node as Node3D
		for child in node.get_children():
			stack.append(child)
	return null


## Frees every weapon instance currently mounted on `hull` (children of sockets).
static func clear_mounted(hull: Node) -> void:
	for socket in find_sockets(hull):
		for child in socket.get_children():
			child.queue_free()


## True when `weapon` is a child of a weapon socket (i.e. was mounted).
static func is_mounted(weapon: Node) -> bool:
	var parent := weapon.get_parent()
	return parent != null and String(parent.name).begins_with(SOCKET_PREFIX)


## All `SN_Pivot_*` / `SN_Recoil*` / `SN_Muzzle*` nodes under a weapon, grouped.
static func find_mechanism_nodes(weapon: Node) -> Dictionary:
	var yaw_nodes: Array[Node3D] = []
	var pitch_nodes: Array[Node3D] = []
	var recoil_nodes: Array[Node3D] = []
	var muzzle_nodes: Array[Node3D] = []
	var stack: Array[Node] = [weapon]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D:
			var node_name := String(node.name)
			if node_name == YAW_NAME:
				yaw_nodes.append(node as Node3D)
			elif node_name.begins_with(PITCH_PREFIX):
				pitch_nodes.append(node as Node3D)
			elif node_name.begins_with(RECOIL_PREFIX):
				recoil_nodes.append(node as Node3D)
			elif node_name.begins_with(MUZZLE_PREFIX):
				muzzle_nodes.append(node as Node3D)
		for child in node.get_children():
			stack.append(child)
	_sort_by_suffix(yaw_nodes)
	_sort_by_suffix(pitch_nodes)
	_sort_by_suffix(recoil_nodes)
	_sort_by_suffix(muzzle_nodes)
	return {
		"yaw": yaw_nodes,
		"pitch": pitch_nodes,
		"recoil": recoil_nodes,
		"muzzle": muzzle_nodes,
	}


## Socket-local AABB (metres, i.e. after `mount_scale`) of the parts that stay
## put when the weapon aims (base, platform, carriage, pedestal, shield), i.e.
## meshes not under a pitch/recoil node. This is the contract §8.3 mount-pad
## measurement; the barrel overhang in `envelope_*` is deliberately excluded.
##
## Measured through the **socket** inverse, not the `SN_Mount` frame: the mount
## frame itself carries `mount_scale`, so measuring through it would return
## weapon-local units and report unscaled clearance for scaled mounts.
static func mount_pad_aabb(socket: Node3D, weapon: Node3D, mechanism: Dictionary) -> AABB:
	var moving: Dictionary = {}
	for key in ["pitch", "recoil"]:
		for node in mechanism.get(key, []):
			moving[node] = true
	var bounds := AABB()
	var found := false
	var socket_inverse := socket.global_transform.affine_inverse()
	var stack: Array = [{"node": weapon, "moving": false}]
	while not stack.is_empty():
		var entry: Dictionary = stack.pop_back()
		var node: Node = entry["node"]
		var is_moving: bool = entry["moving"] or moving.has(node)
		if node is MeshInstance3D and not is_moving:
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				var local := socket_inverse * (node as Node3D).global_transform
				var box := _transform_aabb(local, mesh.get_aabb())
				bounds = box if not found else bounds.merge(box)
				found = true
		for child in node.get_children():
			stack.append({"node": child, "moving": is_moving})
	if not found:
		return AABB()
	return bounds


static func _sort_by_suffix(nodes: Array[Node3D]) -> void:
	nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _node_suffix(a) < _node_suffix(b)
	)


static func _node_suffix(node: Node) -> int:
	var node_name := String(node.name)
	var tail := node_name.substr(node_name.rfind("_") + 1)
	return tail.to_int() if tail.is_valid_int() else 0


static func _collect_named(node: Node, prefix: String, output: Array[Node3D]) -> void:
	if node is Node3D and String(node.name).begins_with(prefix):
		output.append(node as Node3D)
	for child in node.get_children():
		_collect_named(child, prefix, output)


static func _extras(node: Node) -> Dictionary:
	if node != null and node.has_meta("extras"):
		var extras: Variant = node.get_meta("extras")
		if extras is Dictionary:
			return extras as Dictionary
	return {}


static func _transform_aabb(xform: Transform3D, box: AABB) -> AABB:
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
