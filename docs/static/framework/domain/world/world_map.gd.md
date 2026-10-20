# `framework/domain/world/world_map.gd`

> 作用：世界地图顶层容器，保存陆地、港口、区域、连通性、已算好的航线与本世界种子。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldMap` | L1 |
| `SCHEMA_VERSION` | L15 |
| `PATH_DECIMALS` | L18 |
| `_init() -> void` | L33 |
| `is_empty() -> bool` | L45 |
| `get_landmass(landmass_id: String) -> Landmass` | L49 |
| `get_port(port_id: String) -> WorldPort` | L56 |
| `get_region(region_id: String) -> Region` | L63 |
| `set_edges(new_edges: Array[Dictionary]) -> void` | L71 |
| `route_for(from_port_id: String, to_port_id: String) -> Dictionary` | L78 |
| `route_count() -> int` | L82 |
| `get_start_port() -> WorldPort` | L100 |
| `get_ports_in_region(region_id: String) -> Array[WorldPort]` | L107 |
| `get_landmasses_in_region(region_id: String) -> Array[Landmass]` | L115 |
| `find_landmass_containing(point: Vector2) -> Landmass` | L123 |
| `is_point_on_land(point: Vector2) -> bool` | L130 |
| `total_land_area() -> float` | L134 |
| `land_coverage_ratio() -> float` | L141 |
| `to_dict() -> Dictionary` | L147 |
| `from_dict(value: Dictionary) -> WorldMap` | L207 |

## 契约与约束
- `connectivity_graph` 是无向图，A 连接 B 时 B 也连接 A。
- `bounds` 供 UI 视口裁剪与世界坐标映射使用。
- `world_seed` 用于验证存档和当前内容版本的兼容性。
- `edges` 是**生成期算出、运行期只读**的航线表：每个连通边一条
  `{from, to, distance, path}`（`path` 为 `PackedVector2Array`）。航线算法可以随时替换，
  只要这个数据契约不变，查询/UI 就不受影响；缺 `edges` 的旧存档由消费方自行回退计算。

模块索引：[framework/domain](../README.md)
