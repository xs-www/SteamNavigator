## @static-doc
## 作用：rig_kit 运行时装配规则（契约 `rig-kit@1` / `rig-sockets@1` 的代码实现）：在船体 GLB 里按标准名找 `SN_Socket_Mast/Yard/Sail_*` 空节点，把套件 Root 的 `SN_Mount` 精确对齐到 socket，按内容名单隐藏被替换的烘焙节点，并给出可复现的节点快照。
##
## - 关键依赖：`framework/services/content_asset_loader.gd`（调用方加载套件 GLB）、`docs/design/RIG_KIT_CONTRACT.md`
##
## ## 契约与约束
## - 只认标准节点名（`SN_Socket_Mast_*` / `SN_Socket_Yard_*` / `SN_Socket_Sail_*`、`SN_Mount`）与节点 extras（Godot 把 glTF extras 导入为 `get_meta("extras")` 字典），不认资产 ID。
## - socket 排序确定：`socket_index`（extras，缺省 0）优先，其次节点名；同一份船体每次得到相同顺序。
## - `mount()` 只对齐 `SN_Mount`：装配后 `SN_Mount` 的原点与基向量等于 socket 原点/基向量（再叠加可选 `yaw_deg`），套件本体不做缩放；缺 `SN_Mount` 返回 `null` 并释放传入实例。
## - `hide_nodes()` 只处理内容声明的烘焙节点名：从父级摘下后立即 `free()`（不是 `queue_free()`），避免同帧后续的静态合批仍把被替换的网格烘进批次。
## - `snapshot()` 输出「相对装配根的节点路径 + 量化到 1e-4 的位置/基向量」，供确定性断言；不包含资产 ID 或运行时指针。
## - 纯表现层：不读 GameState / 注册表；缺 socket、缺套件只返回原因，不抛错。
## @end-static-doc

class_name ShipRigAssembly
extends RefCounted

const MOUNT_NAME := "SN_Mount"
const MAST_PREFIX := "SN_Socket_Mast_"
const YARD_PREFIX := "SN_Socket_Yard_"
const SAIL_PREFIX := "SN_Socket_Sail_"
const SOCKET_PREFIXES := [MAST_PREFIX, YARD_PREFIX, SAIL_PREFIX]
const SNAP_DIGITS := 10000.0


## All rig sockets under `hull`, ordered by `socket_index` then node name.
static func find_sockets(hull: Node) -> Array[Node3D]:
	var sockets: Array[Node3D] = []
	_collect_sockets(hull, sockets)
	sockets.sort_custom(func(left: Node3D, right: Node3D) -> bool:
		var left_index := int(socket_info(left).get("socket_index", 0))
		var right_index := int(socket_info(right).get("socket_index", 0))
		if left_index != right_index:
			return left_index < right_index
		return String(left.name) < String(right.name)
	)
	return sockets


## Reads one rig socket: `name / kind / mast_key / socket_index / extras`.
## `kind` falls back to the standard name prefix when extras are missing.
static func socket_info(socket: Node) -> Dictionary:
	var extras := extras_of(socket)
	var kind := String(extras.get("socket_kind", ""))
	if kind.is_empty():
		kind = kind_from_name(String(socket.name))
	return {
		"name": String(socket.name),
		"kind": kind,
		"mast_key": String(extras.get("mast_key", extras.get("mast_id", ""))),
		"socket_index": int(float(extras.get("socket_index", 0.0))),
		"extras": extras,
	}


## "mast" / "yard" / "sail" from a standard socket node name (`""` otherwise).
static func kind_from_name(node_name: String) -> String:
	if node_name.begins_with(MAST_PREFIX):
		return "mast"
	if node_name.begins_with(YARD_PREFIX):
		return "yard"
	if node_name.begins_with(SAIL_PREFIX):
		return "sail"
	return ""


## Finds the first `SN_Mount` under a kit instance (empty `Node3D` in the GLB).
static func find_mount(kit: Node) -> Node3D:
	var stack: Array[Node] = [kit]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D and String(node.name) == MOUNT_NAME:
			return node as Node3D
		for child in node.get_children():
			stack.append(child)
	return null


## Parents `kit` under `socket` and aligns its `SN_Mount` with the socket frame
## (`yaw_deg` rotates the kit around the socket local +Y before alignment).
## The socket keeps its own transform; only the kit moves. Returns the kit root,
## or `null` (and frees `kit`) when the kit has no `SN_Mount`.
static func mount(socket: Node3D, kit: Node3D, yaw_deg: float = 0.0) -> Node3D:
	if socket == null or kit == null:
		return null
	var mount_node := find_mount(kit)
	if mount_node == null:
		kit.free()
		return null
	if kit.get_parent() != null:
		kit.get_parent().remove_child(kit)
	socket.add_child(kit)
	kit.transform = Transform3D.IDENTITY
	var mount_local := local_between(kit, mount_node)
	var wanted := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3.ZERO)
	kit.transform = wanted * mount_local.affine_inverse()
	return kit


## Hides (detaches and frees) the named baked nodes under `hull`. Returns the
## names that were actually found; unknown names are simply not in the result.
static func hide_nodes(hull: Node, wanted: Array) -> Array[String]:
	var hidden: Array[String] = []
	for item in wanted:
		var node_name := String(item)
		if node_name.is_empty():
			continue
		var node := find_named(hull, node_name)
		if node == null:
			continue
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.free()
		hidden.append(node_name)
	return hidden


## Depth-first search for the first node whose name equals `wanted`.
static func find_named(root: Node, wanted: String) -> Node:
	if root == null:
		return null
	if String(root.name) == wanted:
		return root
	for child in root.get_children():
		var found := find_named(child, wanted)
		if found != null:
			return found
	return null


## Deterministic snapshot of the assembled ship (`prefixes` = node-name
## prefixes to include, empty = every Node3D). Positions/bases are quantised so
## two identical assemblies compare equal while real misalignment still shows.
static func snapshot(root: Node, prefixes: Array = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if root == null:
		return rows
	_collect_snapshot(root, root, prefixes, rows)
	return rows


## Total triangle count of every mesh under `root` (budget reporting).
static func triangle_count(root: Node) -> int:
	var total := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				total += _mesh_triangles(mesh)
		for child in node.get_children():
			stack.append(child)
	return total


## glTF extras dictionary of a node (empty when absent).
static func extras_of(node: Node) -> Dictionary:
	if node == null or not node.has_meta("extras"):
		return {}
	var value: Variant = node.get_meta("extras")
	return value if value is Dictionary else {}


## `node` transform expressed in `ancestor` space (works outside the SceneTree).
static func local_between(ancestor: Node3D, node: Node3D) -> Transform3D:
	var accumulated := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			accumulated = (current as Node3D).transform * accumulated
		current = current.get_parent()
	return accumulated


static func _collect_sockets(node: Node, output: Array[Node3D]) -> void:
	if node is Node3D:
		var node_name := String(node.name)
		for prefix in SOCKET_PREFIXES:
			if node_name.begins_with(String(prefix)):
				output.append(node as Node3D)
				break
	for child in node.get_children():
		_collect_sockets(child, output)


static func _collect_snapshot(root: Node, node: Node, prefixes: Array, rows: Array[Dictionary]) -> void:
	if node is Node3D:
		var node_name := String(node.name)
		var include := prefixes.is_empty()
		if not include:
			for prefix in prefixes:
				if node_name.begins_with(String(prefix)):
					include = true
					break
		if include:
			var node3d := node as Node3D
			rows.append({
				"path": relative_path(root, node3d),
				"position": _quantise(node3d.position),
				"basis": [
					_quantise(node3d.basis.x), _quantise(node3d.basis.y), _quantise(node3d.basis.z),
				],
			})
	for child in node.get_children():
		_collect_snapshot(root, child, prefixes, rows)


## Node path from `root` down to `node` as a "/"-joined name string.
static func relative_path(root: Node, node: Node) -> String:
	var parts: Array[String] = []
	var current: Node = node
	while current != null and current != root:
		parts.push_front(String(current.name))
		current = current.get_parent()
	return "/".join(parts)


static func _quantise(vector: Vector3) -> Array:
	var result: Array = []
	for axis in [vector.x, vector.y, vector.z]:
		result.append(roundf(float(axis) * SNAP_DIGITS) / SNAP_DIGITS)
	return result


static func _mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty():
			total += int((indices as PackedInt32Array).size() / 3)
		else:
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			if vertices is PackedVector3Array:
				total += int((vertices as PackedVector3Array).size() / 3)
	return total
