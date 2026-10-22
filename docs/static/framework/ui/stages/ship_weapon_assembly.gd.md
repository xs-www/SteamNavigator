# `framework/ui/stages/ship_weapon_assembly.gd`

> 作用：武器装配运行时（契约 `weapon-assembly@2` / `hull-sockets@1` 的代码实现）：从船体 GLB 找 `SN_Socket_Weapon_*`、从武器 GLB 读 Root extras、按 `weapon_class == socket_class` 硬门禁配对，把武器 `SN_Mount` 对齐到 socket、按 `mount_scale` 缩放，并交出可操控的 `ShipWeaponMount`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipWeaponAssembly` | L15 |
| `SOCKET_PREFIX` | L28 |
| `MOUNT_NAME` | L29 |
| `YAW_NAME` | L30 |
| `PITCH_PREFIX` | L31 |
| `RECOIL_PREFIX` | L32 |
| `MUZZLE_PREFIX` | L33 |
| `SOCKET_SPEC` | L34 |
| `ASSEMBLY_SPEC` | L35 |
| `find_sockets(hull: Node) -> Array[Node3D]` | L39 |
| `socket_info(socket: Node) -> Dictionary` | L56 |
| `find_weapon_root(weapon: Node) -> Node3D` | L75 |
| `weapon_info(weapon: Node) -> Dictionary` | L88 |
| `can_mount(info: Dictionary, socket: Dictionary) -> bool` | L111 |
| `rejection_reason(info: Dictionary, socket: Dictionary) -> String` | L116 |
| `mount(socket: Node3D, weapon: Node3D, mount_scale: float = -1.0) -> ShipWeaponMount` | L133 |
| `find_mount(weapon: Node) -> Node3D` | L161 |
| `clear_mounted(hull: Node) -> void` | L173 |
| `is_mounted(weapon: Node) -> bool` | L180 |
| `find_mechanism_nodes(weapon: Node) -> Dictionary` | L186 |
| `mount_pad_aabb(socket: Node3D, weapon: Node3D, mechanism: Dictionary) -> AABB` | L226 |

- 关键依赖：`framework/ui/stages/ship_weapon_mount.gd`（装配结果）、`framework/services/content_asset_loader.gd`（调用方用它加载 GLB）

## 契约与约束
- 只认标准节点名（`SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch*` / `SN_Recoil*` / `SN_Muzzle*`）与节点 extras（Godot 把 glTF extras 导入为 `get_meta("extras")` 字典），不认资产 ID。
- 配对硬门禁：武器 `weapon_class` 必须等于 socket `socket_class`；`Modular`（model kit 基座 / 炮架 / 炮塔）不是完整武器，装配层不直接上船，返回原因。
- 对齐以武器 `SN_Mount` 为准：装配后 `SN_Mount` 的世界变换原点 = socket 原点、基向量 = socket 基向量；`mount_scale` 只缩武器本体，不动 socket。
- 净空按契约 §8.3：高度 ≤ `clearance_h`；底座占地在 socket 局部 X/Y 用「不随俯仰/后坐运动的网格」实测 bbox（不把 `envelope_*` 的炮管外伸算进去），逐轴与 `clearance_x` / `clearance_y` 比较。
- 纯表现层：不读 GameState / 注册表；缺模型、缺 socket、class 不匹配只返回 `null` + 原因，不抛错、不阻断调用方。
- 轴约定（Godot 导入后）：yaw 绕节点局部 +Y，pitch 绕节点局部 +Z（正角度抬高炮口），recoil 沿节点局部 -X 平移。

模块索引：[framework/ui](../README.md)
