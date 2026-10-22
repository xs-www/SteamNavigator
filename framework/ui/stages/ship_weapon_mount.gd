## @static-doc
## 作用：一件「已装到船体安装点上的武器」的运行时句柄：持有 socket / 武器实例 / `SN_Mount`，按标准节点名暴露瞄准（yaw/pitch）、后坐（-X 平移）、炮口位置与净空复核，供战斗层、舞台层和 demo 使用。
##
## - 关键依赖：由 `ShipWeaponAssembly.mount()` 创建；节点来自 `framework/services/content_asset_loader.gd` 实例化的 GLB
##
## ## 契约与约束
## - 轴约定（Godot 导入轴）：yaw 绕 `SN_Pivot_Yaw` 局部 +Y，pitch 绕 `SN_Pivot_Pitch*` 局部 +Z（正角度抬高炮口），recoil 沿 `SN_Recoil*` 局部 -X；所有运动都叠在节点**装配时的静止变换**上，`reset_all()` 回到静止。
## - 多联装：`SN_Pivot_Pitch_1..N` / `SN_Recoil_1..N` / `SN_Muzzle_1..N` 按后缀排序，`aim()` / `recoil()` 同时作用于全部索引。
## - 缺节点按契约 §5 静默降级：没有 yaw 就只转 pitch，没有 recoil 就只有可见后坐为 0，没有 muzzle 时 `muzzle_world_positions()` 为空，不抛错。
## - 净空复核（契约 §8.3）在装配后实测，坐标是 **socket 局部**：Godot 局部 X = 舷外（对应 `clearance_x`）、局部 Z = 船体纵轴（对应 `clearance_y`）、局部 Y = 向上（对应 `clearance_h`）；底座 bbox 不含随俯仰/后坐运动的炮管。
## - 纯表现层：不写 GameState，不注册命令/查询；非法数值（NaN）按 0 处理，角度不在这里夹到武器 extras 的 `*_limit_deg`（目前资产未导出该字段）。
## @end-static-doc

class_name ShipWeaponMount
extends RefCounted
## One mounted weapon: the socket, the weapon instance, its `SN_Mount` and the
## movable parts found by the standard names. Created by
## `ShipWeaponAssembly.mount()`; callers keep this object as long as the weapon
## instance lives.
##
## All transforms are captured at mount time and the aim/recoil values are
## offsets from those rest transforms, so repeated `aim()` calls do not drift.

const YAW_AXIS := Vector3(0.0, 1.0, 0.0)
const PITCH_AXIS := Vector3(0.0, 0.0, 1.0)

var socket: Node3D
var weapon: Node3D
var mount_node: Node3D
var info: Dictionary = {}
var socket_info: Dictionary = {}
var scale: float = 1.0
var yaw_nodes: Array[Node3D] = []
var pitch_nodes: Array[Node3D] = []
var recoil_nodes: Array[Node3D] = []
var muzzle_nodes: Array[Node3D] = []
## Socket-local AABB of the non-moving parts (base / platform / carriage).
var pad_aabb: AABB = AABB()

var _rest_nodes: Dictionary = {}
var _yaw_deg := 0.0
var _pitch_deg := 0.0
var _recoil_offset := 0.0


func _init(
	owner_socket: Node3D,
	owner_weapon: Node3D,
	owner_mount: Node3D,
	weapon_info_value: Dictionary,
	socket_info_value: Dictionary,
	mount_scale: float
) -> void:
	socket = owner_socket
	weapon = owner_weapon
	mount_node = owner_mount
	info = weapon_info_value
	socket_info = socket_info_value
	scale = mount_scale
	var mechanism := ShipWeaponAssembly.find_mechanism_nodes(weapon)
	yaw_nodes = _as_node3d_array(mechanism.get("yaw", []))
	pitch_nodes = _as_node3d_array(mechanism.get("pitch", []))
	recoil_nodes = _as_node3d_array(mechanism.get("recoil", []))
	muzzle_nodes = _as_node3d_array(mechanism.get("muzzle", []))
	for node in yaw_nodes + pitch_nodes + recoil_nodes:
		_rest_nodes[node] = node.transform
	pad_aabb = ShipWeaponAssembly.mount_pad_aabb(socket, weapon, mechanism)


## Applies yaw (around local +Y) and pitch (around local +Z) in degrees.
func aim(yaw_deg: float, pitch_deg: float) -> void:
	_yaw_deg = _finite(yaw_deg)
	_pitch_deg = _finite(pitch_deg)
	for node in yaw_nodes:
		var rest: Transform3D = _rest_nodes[node]
		node.transform = Transform3D(
			rest.basis * Basis(YAW_AXIS, deg_to_rad(_yaw_deg)),
			rest.origin
		)
	for node in pitch_nodes:
		var rest: Transform3D = _rest_nodes[node]
		node.transform = Transform3D(
			rest.basis * Basis(PITCH_AXIS, deg_to_rad(_pitch_deg)),
			rest.origin
		)


## Moves every recoil node backwards along its local -X by `distance` (metres).
func recoil(distance: float) -> void:
	_recoil_offset = maxf(_finite(distance), 0.0)
	for node in recoil_nodes:
		var rest: Transform3D = _rest_nodes[node]
		node.transform = Transform3D(
			node.transform.basis,
			rest.origin + Vector3(-_recoil_offset, 0.0, 0.0)
		)


## Restores rest transforms (aim 0 / 0, recoil 0).
func reset_all() -> void:
	aim(0.0, 0.0)
	recoil(0.0)


func yaw_deg() -> float:
	return _yaw_deg


func pitch_deg() -> float:
	return _pitch_deg


func recoil_offset() -> float:
	return _recoil_offset


## World positions of every `SN_Muzzle*` node (empty when the weapon has none).
func muzzle_world_positions() -> PackedVector3Array:
	var positions := PackedVector3Array()
	for node in muzzle_nodes:
		positions.append(node.global_position)
	return positions


## World-space muzzle forward vectors (weapon local +X), one per muzzle.
func muzzle_forwards() -> PackedVector3Array:
	var forwards := PackedVector3Array()
	for node in muzzle_nodes:
		forwards.append(node.global_transform.basis.x.normalized())
	return forwards


## Number of triangles in the weapon instance (HUD / budget readout).
func triangle_count() -> int:
	var total := 0
	var stack: Array[Node] = [weapon]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh := (node as MeshInstance3D).mesh
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty():
					total += int((indices as PackedInt32Array).size() / 3)
				else:
					var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
					if vertices is PackedVector3Array:
						total += int((vertices as PackedVector3Array).size() / 3)
		for child in node.get_children():
			stack.append(child)
	return total


## Clearance verdict against the hull socket (`clearance_x/y/h`, §8.3).
##
## `fits` is a soft verdict: class matching is the only hard gate. A weapon that
## overhangs the deck shows up here so the UI can warn without blocking play.
## All extents are socket-local metres: `pad_aabb` is measured through the socket
## frame (already includes `mount_scale`), and the weapon Root `height` extras is
## scaled by `mount_scale` before it is compared with `clearance_h`.
func clearance_report() -> Dictionary:
	var half_x := maxf(absf(pad_aabb.position.x), absf(pad_aabb.end.x))
	var half_z := maxf(absf(pad_aabb.position.z), absf(pad_aabb.end.z))
	var height := float(info.get("height", 0.0)) * maxf(scale, 0.0)
	if height <= 0.0:
		height = maxf(absf(pad_aabb.position.y), absf(pad_aabb.end.y))
	var reasons: Array[String] = []
	var allowed_x := float(socket_info.get("clearance_x", 0.0))
	var allowed_z := float(socket_info.get("clearance_y", 0.0))
	var allowed_h := float(socket_info.get("clearance_h", 0.0))
	if allowed_x > 0.0 and half_x > allowed_x + 0.001:
		reasons.append("base overhangs outboard %.2f > %.2f m" % [half_x, allowed_x])
	if allowed_z > 0.0 and half_z > allowed_z + 0.001:
		reasons.append("base overhangs along hull %.2f > %.2f m" % [half_z, allowed_z])
	if allowed_h > 0.0 and height > allowed_h + 0.001:
		reasons.append("height %.2f > %.2f m" % [height, allowed_h])
	return {
		"fits": reasons.is_empty(),
		"reasons": reasons,
		"half_x": half_x,
		"half_z": half_z,
		"height": height,
		"allowed_x": allowed_x,
		"allowed_y": allowed_z,
		"allowed_h": allowed_h,
	}


func socket_name() -> String:
	return String(socket.name)


func weapon_asset() -> String:
	return String(info.get("asset", ""))


func weapon_class() -> String:
	return String(info.get("class", ""))


func profile() -> String:
	return String(info.get("profile", ""))


func _as_node3d_array(value: Variant) -> Array[Node3D]:
	var output: Array[Node3D] = []
	if value is Array:
		for item in value:
			if item is Node3D:
				output.append(item as Node3D)
	return output


static func _finite(value: float) -> float:
	return value if is_finite(value) else 0.0
