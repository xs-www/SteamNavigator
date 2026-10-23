# `framework/tests/cases/test_base.gd`

> 作用：Phase D3 基地运行时的回归测试：`data.base` 惰性结构、占领/建造/升级、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STEADY` | L16 |
| `COASTAL` | L17 |
| `INDUSTRIAL` | L18 |
| `test_commands_and_query_are_registered() -> void` | L77 |
| `test_claim_is_unique_and_requires_a_port() -> void` | L90 |
| `test_build_consumes_materials_and_finishes_with_ticks() -> void` | L108 |
| `test_storage_withdraw_and_capacity() -> void` | L127 |
| `test_hire_assign_and_wages() -> void` | L142 |
| `test_upgrade_raises_level_and_production_speed() -> void` | L165 |
| `test_production_chain_reaches_shipbuilding_material() -> void` | L184 |
| `test_unpaid_upkeep_halts_production() -> void` | L219 |
| `test_malformed_base_data_is_normalized() -> void` | L230 |
| `test_save_round_trip() -> void` | L252 |
| `test_same_seed_and_commands_are_deterministic() -> void` | L271 |

仓储存取与容量、雇工/派工与工资、生产链（tick 产物进仓储）、维护费不足停机、
损坏数据规范化、存档 round-trip 与确定性。

## 契约与约束
- 内容从 Core 注册表动态选取（base_sites / buildings / production_recipes /
  worker_roles），不写死数值到断言里；测试通过公开命令驱动。
- 生产由 `BaseProductionSystem` 在 `sim.advance` 的 tick 中推进；测试用
  `sim.advance` 让时间流动，而不是直接改 `remaining_hours`。
- 仓储输入通过 `base.deposit` 从当前港仓库转入；材料由测试预先写入港口仓库。
- 所有写操作走 `base.*` 命令（CommandBus 事务）；失败命令不得提交状态。

模块索引：[framework/tests](../README.md)
