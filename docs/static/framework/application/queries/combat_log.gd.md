# `framework/application/queries/combat_log.gd`

> 作用：`combat.log` 只读查询：按时间顺序输出持久化的战斗摘要（最新在最后），供

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CombatLogQuery` | L1 |
| `execute(params: Dictionary, context) -> Dictionary` | L16 |

调试 / 后续航海日志页复用。

## 契约与约束
- 参数 `limit`（默认 20，clamp 到 1..`CombatService.MAX_BATTLES`）。
- 返回 `{battles: [{id, sequence, at_time, port_id, encounter_table_id, outcome,
  rounds, durability_before, durability_after, money, item_count, enemies}], total}`；
  不含逐回合日志（完整日志由 `combat.view.last_battle` 提供）。
- 只读：旧档无 `data.combat` 时返回 `{battles:[], total:0}`，不创建状态块。

模块索引：[framework/application](../README.md)
