# `framework/domain/map/map_ops.gd`

> 作用：GameState.world 上的港口/航线查询、设施可见性、发现与 BFS。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MapOps` | L1 |

## 契约与约束

- 航线按无向边存储，`route_between()` 双向匹配。
- `facilities_known` = 已访问 OR 导航设备揭示 OR 港口自身标记。
- `discover()` 同时更新港口布尔与 discovered_ports 数组。
- BFS 用于委托目的地与地图约束检查。

模块索引：[framework/domain](../README.md)
