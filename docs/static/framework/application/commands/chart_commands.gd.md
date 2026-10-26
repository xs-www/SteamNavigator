# `framework/application/commands/chart_commands.gd`

> 作用：航海图 / 航线解锁相关命令。本轮只有 `chart.buy {port_id}`：在带酒馆设施的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ChartCommands` | L1 |
| `DEFAULT_CHART_COST` | L25 |
| `buy(params: Dictionary, context) -> Dictionary` | L28 |
| `chart_cost(state: GameState, hub: RegistryHub) -> int` | L80 |

当前港花钱购买一张海图，解锁当前港 ↔ 目标港的航线（同一条无向航线两端共用
`a|b` 规范键）。

- 关键依赖：`MapOps`（当前港 / 发现状态 / 酒馆设施）、`WorldOps`（航线解锁名册）、
  `ContentRefs.map_config_data`（Core `map_config.chart_cost`）、`Result`

## 契约与约束
- 命令只在 `CommandBus` 的 GameState 克隆上执行；失败返回结构化
  `Result.fail(error_code, "ui.error.*", data)`，事务不提交（不扣钱、不解锁）。
- 门禁顺序固定（先便宜后昂贵的信息检查）：无航程 → 不在港 → 参数/未知港 →
  同港 → 目标未发现 → 当前港无酒馆 → 航线已解锁 → 金额不足。
- 价格来自内容（`map_config.data.chart_cost`，默认 60 金），框架不写死数值；
  扣款同时计入统计支出（`state.record_expense`）。
- 成功发 `chart.purchased` 事件（payload: from / to / cost / money），并写一条
  `ui.notice.chart_purchased` 通知；海图 / 酒馆页面由 Shell 重建刷新。
- 发现港口本身不解锁航线；本命令是三种解锁来源之一（另两种是委托自带海图与
  剧情 `unlock_route`），见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`。

模块索引：[framework/application](../README.md)
