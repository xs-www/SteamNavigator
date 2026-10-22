# `framework/application/commands/sim_commands.gd`

> 作用：Phase D0 模拟时钟的四个命令入口：`sim.pause` / `sim.resume` /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SimCommands` | L1 |
| `pause(_params: Dictionary, context) -> Dictionary` | L19 |
| `resume(_params: Dictionary, context) -> Dictionary` | L26 |
| `set_speed(params: Dictionary, context) -> Dictionary` | L33 |
| `advance(params: Dictionary, context) -> Dictionary` | L47 |

`sim.set_speed` / `sim.advance`。都经 CommandBus 事务执行，失败不提交状态。

## 契约与约束
- 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
- `sim.set_speed` 参数 `speed` 必须是有限数值且在
  `SimulationService.MIN_SPEED..MAX_SPEED`；否则 `invalid_speed` 且状态不变。
- `sim.advance` 参数 `hours` 必须 `> 0` 且 `<= SimulationService.MAX_ADVANCE_HOURS`；
  否则 `invalid_advance_hours`。暂停时命令仍成功但 `ticks = 0`。
- `sim.advance` 把每个 tick 的 `sim.tick` 事件经 `Result.ok(..., events)` 交给
  CommandBus 发布；pause / resume / set_speed 不发领域事件。
- D0 不接 gameplay：不触发 port.wait / 航行 / 制作等既有时间语义。

模块索引：[framework/application](../README.md)
