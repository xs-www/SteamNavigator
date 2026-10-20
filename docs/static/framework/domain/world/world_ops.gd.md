# `framework/domain/world/world_ops.gd`

> 作用：世界地图的查询和变更接口，替代 MVP 时期的 MapOps。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldOps` | L1 |

## 契约与约束

- 所有查询方法都是只读的，不修改世界状态。
- 状态管理方法通过 `GameState.campaign_world()` 存储发现/访问状态。
- `find_path` 使用BFS，不考虑实际路径长度（只计算边数）。
- `distance_between` 返回直线距离，不是路径长度。
- `route_between` 返回的路径可能为空（如果港口不连通）。

模块索引：[framework/domain](../README.md)
