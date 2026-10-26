# `framework/domain/world/world_ops.gd`

> 作用：世界地图查询与状态变更接口，替代 MVP 时期的 MapOps。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldOps` | L1 |
| `world_map(state: GameState) -> WorldMap` | L25 |
| `ports(world: WorldMap) -> Array[WorldPort]` | L32 |
| `port(world: WorldMap, port_id: String) -> WorldPort` | L36 |
| `neighbors(world: WorldMap, port_id: String) -> Array[String]` | L40 |
| `distance_between(world: WorldMap, from_port: String, to_port: String) -> float` | L48 |
| `route_between(world: WorldMap, from_port: WorldPort, to_port: WorldPort) -> Dictionary` | L56 |
| `has_facility(port_data: WorldPort, facility: String) -> bool` | L65 |
| `is_discovered(state: GameState, port_id: String) -> bool` | L69 |
| `is_visited(state: GameState, port_id: String) -> bool` | L75 |
| `discover_port_id(state: GameState, port_id: String) -> bool` | L81 |
| `route_key(a: String, b: String) -> String` | L95 |
| `unlocked_route_keys(state: GameState) -> Array` | L103 |
| `is_route_unlocked(state: GameState, from_port: String, to_port: String) -> bool` | L111 |
| `unlock_route(state: GameState, from_port: String, to_port: String) -> bool` | L121 |
| `unlocked_neighbor_ids(state: GameState, port_id: String) -> Array[String]` | L136 |
| `mark_visited(state: GameState, port_id: String) -> bool` | L159 |
| `bfs_distances(world: WorldMap, start_port_id: String) -> Dictionary` | L172 |
| `reachable(world: WorldMap, start_port_id: String) -> bool` | L185 |
| `port_display_key(world: WorldMap, port_id: String) -> String` | L189 |
| `current_port_id(state: GameState) -> String` | L194 |
| `set_current_port(state: GameState, port_id: String) -> void` | L198 |
| `start_port_id(world: WorldMap) -> String` | L202 |
| `port_count(world: WorldMap) -> int` | L207 |
| `landmass_count(world: WorldMap) -> int` | L211 |
| `region_count(world: WorldMap) -> int` | L215 |

## 契约与约束
- 世界结构查询只读，不修改 WorldMap。
- 发现与访问状态通过 `GameState.campaign_world()` 保存。
- `find_path` 使用 BFS，只按边数寻路；`distance_between` 返回直线距离。
- `route_between` 在港口不连通时可以返回空路径。

## 航线解锁（2026-10-26「任意两港可通航 + 航线需解锁」）
- **物理连通 = 完全图**（`WorldGenerator.generate_chart` 为每对港口生成一条航线）；
  **能否出航是运行时状态**，与几何无关。
- `campaign_world.unlocked_route_keys` 存规范 pair key（`a|b`，按字符串排序），
  是新局唯一「已测绘航线」真源；缺该键的旧存档按空数组惰性补齐（不解锁任何航线）。
- 解锁 API：`route_key(a, b)` / `is_route_unlocked(state, a, b)` /
  `unlock_route(state, a, b)` / `unlocked_neighbor_ids(state, port_id)`。
  解锁来源见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`：委托自带海图、剧情 `unlock_route`
  效果、酒馆 `chart.buy`；**单纯发现 / 访问港口不解锁航线**。
- `unlocked_neighbor_ids` 只返回与 `port_id` 相邻且已解锁的港口 id（按 id 排序），
  供航行目的地 / 海图筛选使用；当前港自身永远不出来。

模块索引：[framework/domain](../README.md)
