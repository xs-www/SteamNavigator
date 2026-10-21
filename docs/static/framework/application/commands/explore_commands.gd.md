# `framework/application/commands/explore_commands.gd`

> 作用：探索系统的命令包装（`explore.start` / `explore.settle` / `explore.decide` /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ExploreCommands` | L1 |
| `start(params: Dictionary, context) -> Dictionary` | L20 |
| `settle(_params: Dictionary, context) -> Dictionary` | L32 |
| `decide(params: Dictionary, context) -> Dictionary` | L38 |
| `buy(_params: Dictionary, context) -> Dictionary` | L47 |
| `investigate(params: Dictionary, context) -> Dictionary` | L53 |
| `travel(params: Dictionary, context) -> Dictionary` | L65 |

`clue.buy` / `clue.investigate` / `clue.travel`），把参数校验与领域服务的返回原样
交给 CommandBus 的事务/事件流程。

- 关键依赖：`ExploreVoyageService`、`ClueService`、`Result`

## 契约与约束
- 命令只在 `CommandBus` 的 GameState 克隆上执行；失败返回 `Result.fail`
  （`code` + `ui.error.*` message_key），成功返回 `Result.ok(payload, events)`，
  领域事件由总线发布。
- 所有会改变状态的扣费 / 时间推进 / 发现都发生在领域服务里，这里只做缺参校验。
- 4.4.2：`clue.travel` 只用于 `port_goods` 线索，目标港由 `ClueService.travel`
  在领域层解析后调用 `VoyageService.start`；查询 / UI 不接触 `target_port_id`。

模块索引：[framework/application](../README.md)
