# `framework/application/commands/port_commands.gd`

> 作用：港口停留用例：在本港消耗时间，让打造订单、NPC 市场与债务期限一起推进。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortCommands` | L1 |

## 契约与约束

- `port.wait` 参数 hours ∈ [1,240]（否则 invalid_hours），必须在停靠状态（否则 not_at_port）且已开局（否则 no_run）。
- 顺序固定：advance_time → CraftOps.settle_orders → NpcTraderSimulator.advance → DebtService.check_overdue → push_notice(ui.notice.waited)。
- data 返回 hours/game_time/time_label/completed_orders/npc_events/debt_events；事件为 port.waited + 每个完成订单的 ship.module_crafted（外加 NPC 市场/债务事件）。
- 全部修改在命令事务内完成，失败自动回滚；WAIT_OPTIONS=[6,12,24] 由船厂 ViewModel 暴露给 UI。

模块索引：[framework/application](../README.md)
