# `framework/application/queries/clue_list_view.gd`

> 作用：线索列表页的只读查询（`clue.list`）。返回全部 active 线索的等级裁剪视图

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ClueListViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L24 |

（与 `sea_chart.view` 同一套 `ClueService.view_entry` 裁剪）、调查入口字段、
可出航标记，以及最近过期线索的折叠历史（`data.clues.expired`）。

- 关键依赖：`ClueService`、`ExplorationRules`、`GameState.data.clues`、`WorldOps`

## 契约与约束
- 只读：由 `QueryBus` 在状态克隆上执行；不清理过期线索、不写状态、不发事件。
  「已过期但尚未被命令路径 sweep」的条目由 `ClueService.view` 过滤掉；
  历史折叠区只读 `expired` 快照。
- **任何类型、任何等级都不输出** `target_port_id`、`credibility`、真实
  `search_zone` 与未披露的 `goods_snapshot` 明细；字段裁剪完全复用领域视图。
- 调查成本 / 工时 / 成功率来自 Core `exploration` 块，列表页不自算规则。
- `can_sail`：在港、未在探索、线索 active；货物线索的目标港不能是当前港。
  港口位置线索允许出航（与海图面板一致，不因等级不足而禁止）。
- 过期条目只给历史需要的字段（id / 类型 / 来源 / 等级 / 货物与港口名 / 到期时间），
  供列表页灰显；不参与 `max_active_clues` 计数。

模块索引：[framework/application](../README.md)
