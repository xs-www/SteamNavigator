# `framework/domain/world/fog_ops.gd`

> 作用：战争迷雾高层操作，把 FogGrid 与 WorldMap、GameState 接合。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FogOps` | L1 |
| `COASTAL_CELLS` | L23 |
| `DEFAULT_MIN_VISION_RADIUS` | L26 |
| `DEFAULT_PORT_REVEAL_RADIUS` | L27 |
| `create_fog_grid(world: WorldMap, min_vision_radius: float) -> FogGrid` | L30 |
| `mark_coastal_cells(fog: FogGrid, world: WorldMap) -> Dictionary` | L34 |
| `reveal_port(fog: FogGrid, port: WorldPort, port_reveal_radius: float) -> int` | L70 |
| `update_ship_vision(fog: FogGrid, ship_pos: Vector2, vision_radius: float, coastal_cells: Dictionary) -> void` | L76 |
| `save_fog_state(state: GameState, fog: FogGrid, coastal_cells: Dictionary) -> void` | L82 |
| `load_fog_state(state: GameState) -> Dictionary` | L90 |
| `get_visibility_at(state: GameState, world_pos: Vector2) -> float` | L106 |
| `is_position_visible(state: GameState, world_pos: Vector2) -> bool` | L116 |
| `reveal_all_coastal(fog: FogGrid, world: WorldMap) -> int` | L127 |
| `reveal_arrival(state: GameState, world: WorldMap, port: WorldPort, radii: Dictionary = {}) -> void` | L151 |
| `trace_route(state: GameState,, world: WorldMap,, path: PackedVector2Array,, radii: Dictionary,, end_progress: float = 1.0) -> void` | L179 |

## 契约与约束
- `mark_coastal_cells` 把距海岸线 `COASTAL_CELLS` 个格子内的单元识别为海岸单元
  （单位是迷雾格子，不是世界单位：`cell_size` 由视野半径决定，固定世界距离会错配）。
- `reveal_port` 使用 `FogGrid.reveal_circle` 揭示已发现港口周边。
- `save_fog_state` / `load_fog_state` 持久化迷雾网格与海岸单元集合。
- `reveal_arrival` 是抵达钩子：揭示泊位并应用船视，首次调用时惰性建网格。
- `trace_route`（4.3.3 / U4）是航程落账钩子：沿实际航线按步长采样船视，把沿海
  格子留成 EXPLORED；它**不揭示港口**，路灯花由调用方随后 `reveal_arrival` 完成。
  旧存档没有坐标世界（空 `WorldMap`）或路径少于 2 点时整段 no-op。
- 半径不再由框架写死：调用方从 `ExplorationRules.fog_radii()`（`min(世界短边) ×
  Core ratio`）取 `{vision, port_reveal}` 传入。下面的 `DEFAULT_*` 只作为
  旧调用 / 测试夹具的防御兜底，正常内容路径必须传 `radii`。
- `get_visibility_at` / `is_position_visible` 是只读查询。

模块索引：[framework/domain](../README.md)
