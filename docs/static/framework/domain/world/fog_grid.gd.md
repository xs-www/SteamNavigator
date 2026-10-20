# `framework/domain/world/fog_grid.gd`

> 作用：战争迷雾网格，维护未探索、已探索海岸与当前可见三种状态。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FogGrid` | L1 |
| `is_empty() -> bool` | L39 |
| `world_to_grid(world_pos: Vector2) -> Vector2i` | L43 |
| `grid_to_world(grid_pos: Vector2i) -> Vector2` | L49 |
| `get_cell(gx: int, gy: int) -> Dictionary` | L56 |
| `set_cell(gx: int, gy: int, state: CellState, alpha: float = -1.0) -> void` | L62 |
| `reveal_circle(center: Vector2, radius: float, state: CellState = CellState.EXPLORED) -> int` | L70 |
| `update_ship_vision(ship_pos: Vector2, vision_radius: float, coastal_cells: Dictionary) -> void` | L94 |
| `smooth_alpha_interpolation() -> void` | L124 |
| `get_alpha_at(world_pos: Vector2) -> float` | L155 |
| `is_cell_visible(gx: int, gy: int) -> bool` | L160 |
| `count_cells_by_state() -> Dictionary` | L165 |
| `to_dict() -> Dictionary` | L190 |
| `from_dict(data: Dictionary) -> FogGrid` | L207 |

## 契约与约束
- 单元尺寸由最小视野半径推导：`cell_size = min_vision_radius / 4`。
- 船只离开后，海岸单元保持 `EXPLORED`，普通海洋单元回到 `BLACK`。
- 相邻单元之间通过 alpha 插值平滑过渡。
- 序列化必须保留 `cell_size`、宽高和全部单元状态。

模块索引：[framework/domain](../README.md)
