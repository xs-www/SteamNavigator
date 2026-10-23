# `framework/tests/cases/test_expedition.gd`

> 作用：Phase D5 遗迹远征运行时测试：开始/进入/事件选择/撤退/完成奖励、危险结算、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STEADY` | L13 |
| `test_commands_and_query_are_registered() -> void` | L49 |
| `test_start_validates_ruin_and_is_unique() -> void` | L56 |
| `test_full_expedition_completes_and_grants_a_relic() -> void` | L69 |
| `test_hazards_are_resolved_on_entering_rooms() -> void` | L82 |
| `test_retreat_ends_the_run_without_completion_reward() -> void` | L100 |
| `test_save_round_trip_mid_expedition() -> void` | L111 |
| `test_malformed_expedition_data_is_normalized() -> void` | L127 |
| `test_same_seed_and_commands_are_deterministic() -> void` | L138 |

遗物收藏、存档往返、损坏数据规范化与确定性。

## 契约与约束
- 内容从 Core 的 ruin_archetypes / room_templates / expedition_events /
  hazard_tables / relics 动态选取，不写死房间/遗物 id。
- 全程用公开命令推进；事件选项按 0 处理，循环直到远征结束。
- 完成奖励断言钱/物品/遗物至少有一项落地，且遗物进入 `data.relics`。

模块索引：[framework/tests](../README.md)
