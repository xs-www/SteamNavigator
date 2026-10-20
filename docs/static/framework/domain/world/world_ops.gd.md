# `framework/domain/world/world_ops.gd`

> 作用：世界地图查询与状态变更接口，替代 MVP 时期的 MapOps。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldOps` | L1 |
| `world_map(state: GameState) -> WorldMap` | L13 |
| `ports(world: WorldMap) -> Array[WorldPort]` | L20 |
| `port(world: WorldMap, port_id: String) -> WorldPort` | L24 |
| `neighbors(world: WorldMap, port_id: String) -> Array[String]` | L28 |
| `distance_between(world: WorldMap, from_port: String, to_port: String) -> float` | L36 |
| `route_between(world: WorldMap, from_port: WorldPort, to_port: WorldPort) -> Dictionary` | L44 |
| `has_facility(port_data: WorldPort, facility: String) -> bool` | L53 |
| `is_discovered(state: GameState, port_id: String) -> bool` | L57 |
| `is_visited(state: GameState, port_id: String) -> bool` | L63 |
| `discover_port_id(state: GameState, port_id: String) -> bool` | L69 |
| `mark_visited(state: GameState, port_id: String) -> bool` | L81 |
| `bfs_distances(world: WorldMap, start_port_id: String) -> Dictionary` | L94 |
| `reachable(world: WorldMap, start_port_id: String) -> bool` | L107 |
| `port_display_key(world: WorldMap, port_id: String) -> String` | L111 |
| `current_port_id(state: GameState) -> String` | L116 |
| `set_current_port(state: GameState, port_id: String) -> void` | L120 |
| `start_port_id(world: WorldMap) -> String` | L124 |
| `port_count(world: WorldMap) -> int` | L129 |
| `landmass_count(world: WorldMap) -> int` | L133 |
| `region_count(world: WorldMap) -> int` | L137 |

## 契约与约束
- 世界结构查询只读，不修改 WorldMap。
- 发现与访问状态通过 `GameState.campaign_world()` 保存。
- `find_path` 使用 BFS，只按边数寻路；`distance_between` 返回直线距离。
- `route_between` 在港口不连通时可以返回空路径。

模块索引：[framework/domain](../README.md)
