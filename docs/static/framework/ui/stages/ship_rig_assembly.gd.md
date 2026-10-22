# `framework/ui/stages/ship_rig_assembly.gd`

> 作用：rig_kit 运行时装配规则（契约 `rig-kit@1` / `rig-sockets@1` 的代码实现）：在船体 GLB 里按标准名找 `SN_Socket_Mast/Yard/Sail_*` 空节点，把套件 Root 的 `SN_Mount` 精确对齐到 socket，按内容名单隐藏被替换的烘焙节点，并给出可复现的节点快照。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipRigAssembly` | L15 |
| `MOUNT_NAME` | L18 |
| `MAST_PREFIX` | L19 |
| `YARD_PREFIX` | L20 |
| `SAIL_PREFIX` | L21 |
| `SOCKET_PREFIXES` | L22 |
| `SNAP_DIGITS` | L23 |
| `find_sockets(hull: Node) -> Array[Node3D]` | L27 |
| `socket_info(socket: Node) -> Dictionary` | L42 |
| `kind_from_name(node_name: String) -> String` | L57 |
| `find_mount(kit: Node) -> Node3D` | L68 |
| `mount(socket: Node3D, kit: Node3D, yaw_deg: float = 0.0) -> Node3D` | L83 |
| `hide_nodes(hull: Node, wanted: Array) -> Array[String]` | L102 |
| `find_named(root: Node, wanted: String) -> Node` | L120 |
| `snapshot(root: Node, prefixes: Array = []) -> Array[Dictionary]` | L135 |
| `triangle_count(root: Node) -> int` | L144 |
| `extras_of(node: Node) -> Dictionary` | L159 |
| `local_between(ancestor: Node3D, node: Node3D) -> Transform3D` | L167 |
| `relative_path(root: Node, node: Node) -> String` | L211 |

- 关键依赖：`framework/services/content_asset_loader.gd`（调用方加载套件 GLB）、`docs/design/RIG_KIT_CONTRACT.md`

## 契约与约束
- 只认标准节点名（`SN_Socket_Mast_*` / `SN_Socket_Yard_*` / `SN_Socket_Sail_*`、`SN_Mount`）与节点 extras（Godot 把 glTF extras 导入为 `get_meta("extras")` 字典），不认资产 ID。
- socket 排序确定：`socket_index`（extras，缺省 0）优先，其次节点名；同一份船体每次得到相同顺序。
- `mount()` 只对齐 `SN_Mount`：装配后 `SN_Mount` 的原点与基向量等于 socket 原点/基向量（再叠加可选 `yaw_deg`），套件本体不做缩放；缺 `SN_Mount` 返回 `null` 并释放传入实例。
- `hide_nodes()` 只处理内容声明的烘焙节点名：从父级摘下后立即 `free()`（不是 `queue_free()`），避免同帧后续的静态合批仍把被替换的网格烘进批次。
- `snapshot()` 输出「相对装配根的节点路径 + 量化到 1e-4 的位置/基向量」，供确定性断言；不包含资产 ID 或运行时指针。
- 纯表现层：不读 GameState / 注册表；缺 socket、缺套件只返回原因，不抛错。

模块索引：[framework/ui](../README.md)
