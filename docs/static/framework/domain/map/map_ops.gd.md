# `framework/domain/map/map_ops.gd`

> 作用：GameState.world 上的港口/航线查询、设施可见性、发现与 BFS。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MapOps` | L1 |
| `ports(world: Dictionary) -> Dictionary` | L5 |
| `port(world: Dictionary, port_id: String) -> Dictionary` | L9 |
| `routes(world: Dictionary) -> Array` | L13 |
| `route_between(world: Dictionary, from_port: String, to_port: String) -> Dictionary` | L17 |
| `distance_between(world: Dictionary, from_port: String, to_port: String) -> float` | L28 |
| `neighbors(world: Dictionary, port_id: String) -> Array[String]` | L33 |
| `has_facility(port_data: Dictionary, facility: String) -> bool` | L47 |
| `has_tavern(port_data: Dictionary) -> bool` | L53 |
| `is_discovered(state: GameState, port_id: String) -> bool` | L57 |
| `is_visited(state: GameState, port_id: String) -> bool` | L61 |
| `facilities_known(state: GameState, hub: RegistryHub, port_id: String) -> bool` | L65 |
| `visible_facilities(state: GameState, hub: RegistryHub, port_id: String) -> Array[String]` | L75 |
| `discover(state: GameState, port_id: String, mark_visited: bool = false) -> bool` | L84 |
| `bfs_distances(world: Dictionary, start_port: String) -> Dictionary` | L102 |
| `reachable(world: Dictionary, start_port: String) -> bool` | L115 |
| `port_display_key(world: Dictionary, port_id: String) -> String` | L119 |
| `route_risk(world: Dictionary, from_port: String, to_port: String) -> float` | L123 |

## 契约与约束

- 航线按无向边存储，`route_between()` 双向匹配。
- `facilities_known` = 已访问 OR 导航设备揭示 OR 港口自身标记。
- `discover()` 同时更新港口布尔与 discovered_ports 数组。
- BFS 用于委托目的地与地图约束检查。

模块索引：[framework/domain](../README.md)
