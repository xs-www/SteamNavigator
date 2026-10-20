# `framework/domain/world/world_map.gd`

> 作用：世界地图的顶层容器，包含所有陆地、港口、区域和连通性图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldMap` | L1 |
| `_init() -> void` | L19 |
| `is_empty() -> bool` | L29 |
| `get_landmass(landmass_id: String) -> Landmass` | L33 |
| `get_port(port_id: String) -> WorldPort` | L40 |
| `get_region(region_id: String) -> Region` | L47 |
| `get_start_port() -> WorldPort` | L54 |
| `get_ports_in_region(region_id: String) -> Array[WorldPort]` | L61 |
| `get_landmasses_in_region(region_id: String) -> Array[Landmass]` | L69 |
| `find_landmass_containing(point: Vector2) -> Landmass` | L77 |
| `is_point_on_land(point: Vector2) -> bool` | L84 |
| `total_land_area() -> float` | L88 |
| `land_coverage_ratio() -> float` | L95 |
| `to_dict() -> Dictionary` | L101 |

## 契约与约束

- `connectivity_graph` 是无向图（A连接B意味着B也连接A）。
- `bounds` 用于UI层的视口裁剪和坐标映射。
- `world_seed` 用于验证存档与当前模组版本的兼容性。

模块索引：[framework/domain](../README.md)
