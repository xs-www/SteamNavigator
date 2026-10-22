# `framework/domain/sim/simulation_service.gd`

> 作用：最小确定性 tick / 模拟框架（Phase D0）。以 1 游戏小时为固定步长推进

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SimulationService` | L1 |
| `SIM_KEY` | L23 |
| `TICK_HOURS` | L24 |
| `DEFAULT_SPEED` | L25 |
| `MIN_SPEED` | L26 |
| `MAX_SPEED` | L27 |
| `MAX_ADVANCE_HOURS` | L28 |
| `DEFAULT_STATE` | L29 |
| `ensure_state(state: GameState) -> Dictionary` | L37 |
| `pause(state: GameState) -> Dictionary` | L57 |
| `resume(state: GameState) -> Dictionary` | L63 |
| `set_speed(state: GameState, speed: float) -> Dictionary` | L70 |
| `advance(state: GameState, hours: float, context = null) -> Dictionary` | L81 |
| `view(state: GameState) -> Dictionary` | L120 |
| `is_valid_speed(speed: float) -> bool` | L147 |
| `is_valid_advance_hours(hours: float) -> bool` | L151 |

`data.sim`（`{paused, speed, tick}` 惰性状态），按 TickScheduler 的
priority + id 顺序调用已注册系统，并为每个 tick 生成 `sim.tick` 领域事件。

关键依赖：`GameState.advance_time`、`ClockService.format_time`、`TickScheduler`

## 契约与约束
- `ensure_state()` 惰性创建 / 修复 `data.sim`；旧档没有该块时按默认值补齐，
  不写存档迁移、不触碰 `port.wait` / 航行时间语义（D0 不接 gameplay）。
- 固定步长 `TICK_HOURS = 1.0`；`advance()` 先把真实小时数乘以 `speed`，再按
  **整 tick** 推进（不足 1 小时的部分直接丢弃，不做跨调用累计）。
- 暂停（`paused=true`）时不推进时间、不调用系统、不发事件；暂停状态下
  `advance()` 返回 `ticks = 0`。
- 每 tick 依次：`tick += 1` → `advance_time(TICK_HOURS)` → TickScheduler.run(...)
  → 生成 `{type: "sim.tick", payload: {tick, game_time, step_hours}}`；命令层把
  这些事件交给 CommandBus 发布（服务本身不发事件）。
- `view()` 只读，不创建 / 不修改 `data.sim`；无 run 或旧档返回默认值。

模块索引：[framework/domain](../README.md)
