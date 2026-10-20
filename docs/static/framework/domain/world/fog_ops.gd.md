# `framework/domain/world/fog_ops.gd`

> 作用：High-level fog operations that integrate FogGrid with WorldMap and GameState.

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FogOps` | L1 |

## 契约与约束

- mark_coastal_cells identifies cells within COASTAL_DISTANCE (2.0 units) from landmasses.
- reveal_port uses FogGrid.reveal_circle to clear fog around discovered ports.
- save_fog_state and load_fog_state persist fog grid and coastal cell data.
- get_visibility_at and is_position_visible provide read-only fog queries.

模块索引：[framework/domain](../README.md)
