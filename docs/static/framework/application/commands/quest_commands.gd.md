# `framework/application/commands/quest_commands.gd`

> 作用：抽象任务（Quest）的命令包装（C3）：`quest.start`（接取内容任务）、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `QuestCommands` | L1 |
| `start(params: Dictionary, context) -> Dictionary` | L20 |
| `complete(params: Dictionary, context) -> Dictionary` | L29 |
| `observe(params: Dictionary, context) -> Dictionary` | L38 |

`quest.complete`（手动完成）、`quest.observe`（Shell 把成功命令 / UI 事件转成
`cmd:*` / `ui:*` 交给 QuestService 推进目标）。只做参数校验与领域服务转交，
状态推进在 `CommandBus` 的 GameState 克隆事务内完成。

- 关键依赖：`QuestService`、`Result`

## 契约与约束
- 成功返回 `Result.ok(payload, events)`；领域事件（`quest.started` /
  `quest.updated` / `quest.completed`）由总线发布。
- `quest.start` 参数 `{quest_id}`；`quest.complete` 参数 `{instance_id}`；
  `quest.observe` 参数 `{event, data}`，未知事件不推进也不报错。
- 委托接取 / 完成由 `ContractOps` 直接调 `QuestService`，不经过本命令层。

模块索引：[framework/application](../README.md)
