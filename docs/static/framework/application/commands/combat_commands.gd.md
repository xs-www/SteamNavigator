# `framework/application/commands/combat_commands.gd`

> 作用：`combat.resolve` 命令入口（Phase D1 自动战斗）。把参数（可选

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CombatCommands` | L1 |
| `resolve(params: Dictionary, context) -> Dictionary` | L19 |

`encounter_table_id` / `seed`）交给 `CombatService.resolve`，在 CommandBus 事务里
提交耐久、战利品与 `data.combat` 记录，并发布 `combat.resolved` 领域事件。

## 契约与约束
- 参数：`encounter_table_id` 省略时用注册表里 id 最小的遭遇表（确定性默认）；
  `seed` 省略（0）时由 run seed + 战斗序号派生，显式传入则直接决定本场结果。
- 失败原样返回 `CombatService` 的结构化 Result（`no_run` / `no_ship` /
  `unknown_encounter` / `combat_resolve_failed`），命令事务不提交状态。
- 成功返回 `{battle, durability, loot_applied}`；`autosave=true`（战斗会改持久状态）。
- 不发 `run.started` 等既有事件；本切片不接入航行风险结算，commander 可直接
  `context.commands.execute(&"combat.resolve", {...})` 调用。

模块索引：[framework/application](../README.md)
