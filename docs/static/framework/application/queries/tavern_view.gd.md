# `framework/application/queries/tavern_view.gd`

> 作用：酒馆页（`tavern.view`）的只读查询——把原「情报站」的物价情报矩阵

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TavernViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L21 |

（`IntelViewQuery`）与港口线索（`ClueListViewQuery.clue_rows` 的等级裁剪视图）
合并成一份 ViewModel，并给出售价 / 调查成本与按钮可用性。

- 关键依赖：`IntelViewQuery`、`ClueListViewQuery`、`ClueService.buy_gate`、
  `MapOps.has_tavern`

## 契约与约束
- 只读：由 `QueryBus` 在状态克隆上执行；不 sweep 过期线索、不写状态。
- 线索字段裁剪完全复用 `ClueService.view_entry`：不输出 `target_port_id`、
  `credibility`、真实搜索区或未披露的货物快照。
- 酒馆设施判断兼容旧存档的 `intel` 设施（`MapOps.has_tavern`）。
- 物价情报的刷新命令仍是旧的 `intel.refresh`（兼容旧入口 / 本地化键），
  购买线索仍是 `clue.buy`，调查仍是 `clue.investigate`；查询只做展示。

模块索引：[framework/application](../README.md)
