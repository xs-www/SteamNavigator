# `framework/domain/sim/tick_scheduler.gd`

> 作用：SimulationService 的确定性 tick 系统注册表。系统用 `(id, priority,

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TickScheduler` | L1 |
| `register(system_id: String, priority: int, callable: Callable) -> void` | L23 |
| `unregister(system_id: String) -> void` | L35 |
| `reset() -> void` | L41 |
| `has(system_id: String) -> bool` | L45 |
| `systems() -> Array[Dictionary]` | L54 |
| `run(state: GameState, tick: int, context = null) -> void` | L65 |

callable)` 注册，每次 tick 按 **priority 升序、再 id 字典序** 执行，保证同一
种子 / 同一注册集合下的推进结果可复现（不依赖 Dictionary 迭代顺序）。

## 契约与约束
- `register()` 允许重复调用：同一 `system_id` 覆盖旧系统，避免热重载 / 测试
  重复注册导致同名系统执行两次。
- callable 参数自适应：支持 `() / (state) / (state, tick) / (state, tick, context)`
  四种签名；D0 默认把 `context` 一起传给需要它的系统。
- `reset()` 清空注册表，仅供启动装配与测试使用；生产代码不应在 tick 中途重置。
- 系统本身必须确定性且不改写 `data.sim`（tick/paused/speed 由 SimulationService
  维护）；异常由调用方承担，调度器不做 try/catch。

模块索引：[framework/domain](../README.md)
