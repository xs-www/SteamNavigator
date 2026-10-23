# `framework/tests/cases/test_auto_trade.gd`

> 作用：Phase D4 自动贸易运行时测试：策略启动/停止/切换、规则暂停与恢复、买卖航程、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STEADY` | L13 |
| `test_commands_and_query_are_registered() -> void` | L93 |
| `test_start_validates_policy_and_is_unique() -> void` | L103 |
| `test_buy_travel_sell_cycle() -> void` | L113 |
| `test_rules_pause_and_resume_the_run() -> void` | L135 |
| `test_core_full_cargo_rule_sells_on_arrival() -> void` | L158 |
| `test_arrival_pause_blocks_a_later_sell_rule() -> void` | L179 |
| `test_set_policy_and_stop() -> void` | L205 |
| `test_save_round_trip() -> void` | L222 |
| `test_malformed_trade_data_is_normalized() -> void` | L239 |
| `test_rule_when_gates_the_trigger_phase() -> void` | L270 |
| `test_same_seed_and_commands_are_deterministic() -> void` | L284 |

风险日志、存档 round-trip、损坏数据规范化与确定性。

## 契约与约束
- 内容从 Core 的 `trade_policies` / `automation_rules` 动态选取，不写死 policy id。
- 测试直接布置已发现港口与市场库存/价格，保证利润率满足策略的 `min_margin`；
  不依赖随机世界是否有价差。
- 自动贸易由 `AutoTradeSystem` 在 `sim.advance` 中推进；断言货舱、利润与日志。

模块索引：[framework/tests](../README.md)
