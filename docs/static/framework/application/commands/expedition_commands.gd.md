# `framework/application/commands/expedition_commands.gd`

> 作用：Phase D5 遗迹远征的命令入口：`expedition.start` / `enter` / `choose` /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ExpeditionCommands` | L1 |
| `start(params: Dictionary, context) -> Dictionary` | L15 |
| `enter(params: Dictionary, context) -> Dictionary` | L21 |
| `choose(params: Dictionary, context) -> Dictionary` | L27 |
| `retreat(params: Dictionary, context) -> Dictionary` | L33 |

`retreat`。都经 CommandBus 事务执行，失败不提交 `data.expedition` / `data.relics`；
成功时发布 `expedition.*` 领域事件。

## 契约与约束
- 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
- 引用/状态规则在 `ExpeditionService`：在港启动、唯一进行中远征、事件选项下标、
  房间危险与完成奖励结算。

模块索引：[framework/application](../README.md)
