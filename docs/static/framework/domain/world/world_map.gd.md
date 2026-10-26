# `framework/domain/world/world_map.gd`

> 作用：世界地图顶层容器，保存陆地、港口、区域、连通性、已算好的航线与本世界种子。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldMap` | L1 |
| `SCHEMA_VERSION` | L20 |
| `PATH_DECIMALS` | L23 |
| `_init() -> void` | L38 |
| `is_empty() -> bool` | L50 |
| `get_landmass(landmass_id: String) -> Landmass` | L54 |
| `get_port(port_id: String) -> WorldPort` | L61 |
| `get_region(region_id: String) -> Region` | L68 |
| `set_edges(new_edges: Array[Dictionary]) -> void` | L76 |
| `route_for(from_port_id: String, to_port_id: String) -> Dictionary` | L83 |
| `route_count() -> int` | L87 |
| `get_start_port() -> WorldPort` | L105 |
| `get_ports_in_region(region_id: String) -> Array[WorldPort]` | L112 |
| `get_landmasses_in_region(region_id: String) -> Array[Landmass]` | L120 |
| `find_landmass_containing(point: Vector2) -> Landmass` | L128 |
| `is_point_on_land(point: Vector2) -> bool` | L135 |
| `total_land_area() -> float` | L139 |
| `land_coverage_ratio() -> float` | L146 |
| `to_dict() -> Dictionary` | L152 |
| `from_dict(value: Dictionary) -> WorldMap` | L220 |

## 契约与约束
- `connectivity_graph` 是无向图，A 连接 B 时 B 也连接 A。
- `bounds` 供 UI 视口裁剪与世界坐标映射使用。
- `world_seed` 用于验证存档和当前内容版本的兼容性。
- `edges` 是**生成期算出、运行期只读**的航线表：每个边一条
  `{from, to, distance, base_risk?, path}`（`path` 为 `PackedVector2Array`）。这是唯一的
  世界拓扑：`GameState.world()` 的 `routes` 由它派生（`ChartWorldProjection.from_chart`），
  海图、航行演出、委托与 BFS 全部读这一张表。航线算法可以随时替换，只要这个数据契约
  不变，查询/UI 就不受影响；缺 `edges` 的旧存档由消费方自行回退计算。
- `base_risk` 只由可玩世界生成器（`WorldGenerator.generate_chart`，范围来自
  `route_templates.risk_range`）写入；通用生成器 / 旧存档的世界没有该键，消费方读不到
  时应视为「未知风险」而不是 0。

模块索引：[framework/domain](../README.md)
