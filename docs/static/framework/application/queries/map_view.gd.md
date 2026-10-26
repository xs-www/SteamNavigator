# `framework/application/queries/map_view.gd`

> 作用：`map.view` 只读查询——输出港口列表与**已解锁**航线，供地图类 UI / 测试使用。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MapViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L13 |

## 契约与约束
- 港口列表带发现 / 访问 / 设施可知状态（`MapOps`），未发现港口也在列表里但带标记。
- **航线解锁**（2026-10-26）：`routes` 只列 `WorldOps.is_route_unlocked` 为真的边。
  物理海图是完全图，未解锁的边仍存在于世界表里，但不出现在这个「玩家可用的地图」
  查询中（海图查询 `sea_chart.view` 才输出未测绘边 + `unlocked` 标记）。

模块索引：[framework/application](../README.md)
