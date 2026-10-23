# `framework/application/commands/auto_trade_commands.gd`

> 作用：Phase D4 自动贸易的命令入口：`auto_trade.start` / `stop` / `set_policy` /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AutoTradeCommands` | L1 |
| `start(params: Dictionary, context) -> Dictionary` | L16 |
| `stop(params: Dictionary, context) -> Dictionary` | L22 |
| `set_policy(params: Dictionary, context) -> Dictionary` | L28 |
| `pause(params: Dictionary, context) -> Dictionary` | L34 |
| `resume(params: Dictionary, context) -> Dictionary` | L40 |

`pause` / `resume`。都经 CommandBus 事务执行，失败不提交 `data.trade`；成功时
发布 `auto_trade.*` 领域事件。

## 契约与约束
- 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
- 引用/状态规则在 `AutoTradeService`：唯一运行中贸易、在港启动、策略存在、
  有货时不切策略。
- 买卖与风险只在 tick 中发生，命令只改运行意图。

模块索引：[framework/application](../README.md)
