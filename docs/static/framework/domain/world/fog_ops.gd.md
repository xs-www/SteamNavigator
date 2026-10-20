# `framework/domain/world/fog_ops.gd`

> 作用：战争迷雾高层操作，把 FogGrid 与 WorldMap、GameState 接合。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FogOps` | L1 |
| `COASTAL_CELLS` | L16 |
| `create_fog_grid(world: WorldMap, min_vision_radius: float) -> FogGrid` | L19 |
| `mark_coastal_cells(fog: FogGrid, world: WorldMap) -> Dictionary` | L23 |
| `reveal_port(fog: FogGrid, port: WorldPort, port_reveal_radius: float) -> int` | L59 |
| `update_ship_vision(fog: FogGrid, ship_pos: Vector2, vision_radius: float, coastal_cells: Dictionary) -> void` | L65 |
| `save_fog_state(state: GameState, fog: FogGrid, coastal_cells: Dictionary) -> void` | L71 |
| `load_fog_state(state: GameState) -> Dictionary` | L79 |
| `get_visibility_at(state: GameState, world_pos: Vector2) -> float` | L95 |
| `is_position_visible(state: GameState, world_pos: Vector2) -> bool` | L105 |
| `reveal_all_coastal(fog: FogGrid, world: WorldMap) -> int` | L116 |

## 契约与约束
- `mark_coastal_cells` 把距海岸线 `COASTAL_CELLS` 个格子内的单元识别为海岸单元
  （单位是迷雾格子，不是世界单位：`cell_size` 由视野半径决定，固定世界距离会错配）。
- `reveal_port` 使用 `FogGrid.reveal_circle` 揭示已发现港口周边。
- `save_fog_state` / `load_fog_state` 持久化迷雾网格与海岸单元集合。
- `get_visibility_at` / `is_position_visible` 是只读查询。

模块索引：[framework/domain](../README.md)
