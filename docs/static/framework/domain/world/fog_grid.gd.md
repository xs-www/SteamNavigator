# `framework/domain/world/fog_grid.gd`

> 作用：Fog of war grid with three states: black (unexplored) / explored (coastal) / visible (ship vision).

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FogGrid` | L1 |
| `_init(world_bounds: Rect2, min_vision_radius: float) -> void` | L20 |
| `is_empty() -> bool` | L34 |
| `world_to_grid(world_pos: Vector2) -> Vector2i` | L38 |
| `grid_to_world(grid_pos: Vector2i) -> Vector2` | L44 |
| `get_cell(gx: int, gy: int) -> Dictionary` | L51 |
| `set_cell(gx: int, gy: int, state: CellState, alpha: float = -1.0) -> void` | L57 |
| `reveal_circle(center: Vector2, radius: float, state: CellState = CellState.EXPLORED) -> int` | L65 |
| `update_ship_vision(ship_pos: Vector2, vision_radius: float, coastal_cells: Dictionary) -> void` | L89 |
| `smooth_alpha_interpolation() -> void` | L119 |
| `get_alpha_at(world_pos: Vector2) -> float` | L150 |
| `is_cell_visible(gx: int, gy: int) -> bool` | L155 |
| `count_cells_by_state() -> Dictionary` | L160 |
| `to_dict() -> Dictionary` | L185 |

## 契约与约束

- Cell size is derived from the minimum vision radius (cell_size = min_vision_radius / 4).
- Coastal cells stay EXPLORED after ship leaves; ocean cells revert to BLACK.
- Alpha interpolation smooths transitions between adjacent cells.
- Serialization preserves cell_size, width, height, and all cell states.

模块索引：[framework/domain](../README.md)
