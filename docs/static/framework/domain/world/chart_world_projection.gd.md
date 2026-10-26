# `framework/domain/world/chart_world_projection.gd`

> 作用：把**唯一世界**（海图 `WorldMap` / `state.data["world_map"]`）转换成玩法层使用的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ChartWorldProjection` | L1 |
| `from_chart(world_map_data: Dictionary) -> Dictionary` | L27 |

`GameState.world()` 字典（ports / routes / 起始港），让 MapOps / 委托 / 航行 / BFS
全部读到同一份拓扑与距离。

## 契约与约束
- **海图是唯一真相**（2026-10-26）：`WorldMap.edges` 就是世界拓扑，本类只做形状转换，
  不生成、不修改、不重新计算任何拓扑或距离。`GameState.world().routes[].distance`
  ≡ `WorldMap.edges[].distance` ≡ 该边绘制路径的折线长度。
- 输出与历史 `MapGenerator` 世界的字典形状兼容：
  `{ports: {id: {id, name_key, description_key, archetype_id, source_mod,
  banner_asset, diorama, facilities, tags, size, discovered, visited,
  facilities_known, x, y}}, routes: [{a, b, distance, base_risk}],
  discovered_ports, current_port_id, start_port_id}`。
- 只有起始港初始为已发现 / 已访问 / 设施已知，其余港口保持迷雾状态。
- 边顺序按港口数值编号排序（`port_0`, `port_1`, ...），与 `WorldMap.edges` 的存储顺序
  无关，保证同 seed 输出逐字段一致。
- `base_risk` 随边存盘（`WorldMap` 1.2）；缺失时写 0.0，只可能出现在旧海图 / 通用
  生成器世界（战役世界总是有值）。

模块索引：[framework/domain](../README.md)
