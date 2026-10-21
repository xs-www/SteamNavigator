# `framework/tests/cases/test_story.gd`

> 作用：新手剧情 / 教学系统（阶段 4.5.1）领域层无头测试：`run.start tutorial=true`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SEED` | L16 |
| `BUILD_ID` | L17 |
| `test_tutorial_run_starts_story_and_locks_features() -> void` | L20 |
| `test_tutorial_run_discovers_the_main_contract_destination() -> void` | L37 |
| `test_non_tutorial_run_is_not_gated() -> void` | L51 |
| `test_advance_unlocks_supply_and_shows_objective() -> void` | L63 |
| `test_observe_walks_the_first_voyage_act() -> void` | L79 |
| `test_main_contract_needs_player_supplied_coal_before_departure() -> void` | L111 |
| `test_skip_unlocks_everything_and_keeps_the_run_playable() -> void` | L150 |
| `test_story_survives_a_save_load_roundtrip() -> void` | L167 |
| `test_old_save_without_story_block_stays_open() -> void` | L193 |

初始化剧情、功能解锁 / 门禁 ViewModel、剧情卡继续、`story.observe` 事件计数推进、
`story.skip` 保底解锁与主委托目的港揭示、非教程局 / 旧存档不门禁、存档往返。

## 契约与约束
- 用真实 Core 注册表：剧情步骤 / 文案 / 解锁 / 数值必须来自
  `dev_mods/core/content/map_profiles.json` 的 `story` 块，测试不写死框架步骤。
- `run.start` 的 `tutorial` 默认 false（测试 / 旧入口不弹剧情）；Shell 的
  「开始新航行」显式传 true，生产局每局默认进入剧情。
- 跳过 / 完成必须解锁配置里的全部功能并执行 `discover_contract_destination`，
  避免跳过教程后无目的港可出航。

模块索引：[framework/tests](../README.md)
