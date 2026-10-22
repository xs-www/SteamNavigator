# `framework/tests/cases/test_simulation.gd`

> 作用：Phase D0 确定性 tick / 模拟框架的回归测试：`data.sim` 惰性状态、暂停 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STEADY` | L17 |
| `test_commands_and_query_are_registered() -> void` | L40 |
| `test_state_is_lazy_and_defaults_are_reported() -> void` | L47 |
| `test_pause_blocks_advance_and_resume_restores_it() -> void` | L62 |
| `test_speed_scales_ticks_and_is_validated() -> void` | L81 |
| `test_advance_rejects_invalid_hours_and_keeps_whole_ticks() -> void` | L97 |
| `test_advance_is_deterministic_for_the_same_seed() -> void` | L113 |
| `test_systems_run_by_priority_then_id() -> void` | L134 |
| `test_each_tick_emits_a_sim_tick_event() -> void` | L153 |
| `test_save_round_trip_persists_the_sim_block() -> void` | L167 |
| `test_legacy_state_without_sim_is_backfilled_lazily() -> void` | L194 |

恢复 / 速度 / 推进命令、`sim.view` 查询、tick 系统顺序与 `sim.tick` 领域事件、
同种子状态 hash 确定性、存档 round-trip 与旧档（缺 `data.sim`）惰性补齐。

## 契约与约束
- 固定步长 1 游戏小时；`advance(hours)` 实际 tick 数 = floor(hours * speed)。
- 暂停时不推进时间、不调用系统、不发事件；`advance` 仍返回 ok + ticks=0。
- 系统执行顺序为 priority 升序、再 id 字典序；测试用 TickScheduler.reset()
  隔离静态注册表，结束时也清理，避免污染其他套件。
- 确定性用 `GameState.hash()` 比较；与现有刚启动跑测一致，比较前先删掉
  `started_at` / `campaign.created_at` 这类真实时钟字段。
- D0 不改变 port.wait / voyage 时间语义，本套件不覆盖它们。

模块索引：[framework/tests](../README.md)
