# `framework/ui/stages/ship_weapon_mount.gd`

> 作用：一件「已装到船体安装点上的武器」的运行时句柄：持有 socket / 武器实例 / `SN_Mount`，按标准节点名暴露瞄准（yaw/pitch）、后坐（-X 平移）、炮口位置与净空复核，供战斗层、舞台层和 demo 使用。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipWeaponMount` | L14 |
| `YAW_AXIS` | L24 |
| `PITCH_AXIS` | L25 |
| `_init(owner_socket: Node3D,, owner_weapon: Node3D,, owner_mount: Node3D,, weapon_info_value: Dictionary,, socket_info_value: Dictionary,, mount_scale: float) -> void` | L46 |
| `aim(yaw_deg: float, pitch_deg: float) -> void` | L71 |
| `recoil(distance: float) -> void` | L89 |
| `reset_all() -> void` | L100 |
| `yaw_deg() -> float` | L105 |
| `pitch_deg() -> float` | L109 |
| `recoil_offset() -> float` | L113 |
| `muzzle_world_positions() -> PackedVector3Array` | L118 |
| `muzzle_forwards() -> PackedVector3Array` | L126 |
| `triangle_count() -> int` | L134 |
| `clearance_report() -> Dictionary` | L162 |
| `socket_name() -> String` | L190 |
| `weapon_asset() -> String` | L194 |
| `weapon_class() -> String` | L198 |
| `profile() -> String` | L202 |

- 关键依赖：由 `ShipWeaponAssembly.mount()` 创建；节点来自 `framework/services/content_asset_loader.gd` 实例化的 GLB

## 契约与约束
- 轴约定（Godot 导入轴）：yaw 绕 `SN_Pivot_Yaw` 局部 +Y，pitch 绕 `SN_Pivot_Pitch*` 局部 +Z（正角度抬高炮口），recoil 沿 `SN_Recoil*` 局部 -X；所有运动都叠在节点**装配时的静止变换**上，`reset_all()` 回到静止。
- 多联装：`SN_Pivot_Pitch_1..N` / `SN_Recoil_1..N` / `SN_Muzzle_1..N` 按后缀排序，`aim()` / `recoil()` 同时作用于全部索引。
- 缺节点按契约 §5 静默降级：没有 yaw 就只转 pitch，没有 recoil 就只有可见后坐为 0，没有 muzzle 时 `muzzle_world_positions()` 为空，不抛错。
- 净空复核（契约 §8.3）在装配后实测，坐标是 **socket 局部**：Godot 局部 X = 舷外（对应 `clearance_x`）、局部 Z = 船体纵轴（对应 `clearance_y`）、局部 Y = 向上（对应 `clearance_h`）；底座 bbox 不含随俯仰/后坐运动的炮管。
- 纯表现层：不写 GameState，不注册命令/查询；非法数值（NaN）按 0 处理，角度不在这里夹到武器 extras 的 `*_limit_deg`（目前资产未导出该字段）。

模块索引：[framework/ui](../README.md)
