# `framework/tests/cases/test_story.gd`

> 作用：新手剧情 / 教学系统（阶段 4.5.1 – 4.5.5）领域层无头测试：`run.start tutorial=true`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SEED` | L19 |
| `BUILD_ID` | L20 |
| `test_tutorial_run_starts_story_and_locks_features() -> void` | L23 |
| `test_tutorial_run_discovers_the_main_contract_destination() -> void` | L40 |
| `test_non_tutorial_run_is_not_gated() -> void` | L54 |
| `test_advance_unlocks_market_and_shows_objective() -> void` | L66 |
| `test_observe_walks_the_first_voyage_act() -> void` | L86 |
| `test_departure_beat_and_arrival_beat_are_separate_stages() -> void` | L128 |
| `test_story_view_passes_the_optional_focus_target_through() -> void` | L169 |
| `test_second_mainline_buys_market_goods_and_returns_home() -> void` | L188 |
| `test_tavern_clue_guaranteed_explore_and_third_port() -> void` | L252 |
| `test_skip_does_not_arm_the_guaranteed_exploration() -> void` | L385 |
| `test_main_contract_needs_player_supplied_coal_before_departure() -> void` | L395 |
| `test_skip_unlocks_everything_and_keeps_the_run_playable() -> void` | L434 |
| `test_story_survives_a_save_load_roundtrip() -> void` | L451 |
| `test_old_save_without_story_block_stays_open() -> void` | L477 |

初始化剧情、功能解锁 / 门禁 ViewModel、剧情卡继续、`story.observe` 事件计数推进、
`story.skip` 保底解锁与主委托目的港揭示、非教程局 / 旧存档不门禁、存档往返；
第二主线买卖回运；酒馆自动 / 购买线索、两港价差、第三件货、第二条 L3 线索与
保底探索成功发现第三港；第三港换船、船厂只卖 1 人客舱、卸货舱 / 装客舱、
第三主线旅客与教学完成。

## 契约与约束
- 用真实 Core 注册表：剧情步骤 / 文案 / 解锁 / 数值必须来自
  `dev_mods/core/content/map_configs.json` 的 `story` 块，测试不写死框架步骤。
- `run.start` 的 `tutorial` 默认 false（测试 / 旧入口不弹剧情）；Shell 的
  「开始新航行」显式传 true，生产局每局默认进入剧情。
- 跳过 / 完成必须解锁配置里的全部功能并执行 `discover_contract_destination`，
  避免跳过教程后无目的港可出航；跳过不会设置保底探索 flag。

模块索引：[framework/tests](../README.md)
