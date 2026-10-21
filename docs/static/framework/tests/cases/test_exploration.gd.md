# `framework/tests/cases/test_exploration.gd`

> 作用：探索系统（阶段 4.1）领域层无头测试：线索生成 / 分级裁剪 / 命名流复现、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SEED` | L17 |
| `STRATEGY_ID` | L18 |
| `test_acquire_levels_and_credibility_stay_in_source_ranges() -> void` | L25 |
| `test_acquire_returns_empty_when_no_undiscovered_target() -> void` | L53 |
| `test_acquire_search_zone_and_distance_range_follow_credibility() -> void` | L67 |
| `test_clue_view_clips_secrets_by_level() -> void` | L95 |
| `test_chance_roll_boundaries_are_deterministic() -> void` | L132 |
| `test_on_arrival_rumour_is_reproducible() -> void` | L151 |
| `test_buy_requires_intel_facility() -> void` | L180 |
| `test_buy_requires_money() -> void` | L190 |
| `test_buy_charges_gold_and_adds_intel_clue() -> void` | L201 |
| `test_buy_is_blocked_by_the_active_clue_cap() -> void` | L231 |
| `test_explore_start_deducts_resources_and_marks_at_sea() -> void` | L255 |
| `test_explore_start_infeasible_does_not_charge() -> void` | L313 |
| `test_explore_start_twice_fails_with_already_exploring() -> void` | L334 |
| `test_explore_settle_success_discovers_target() -> void` | L350 |
| `test_explore_settle_failure_drifts_to_nearest_discovered_port() -> void` | L395 |
| `test_explore_settle_without_a_voyage_fails() -> void` | L444 |
| `test_explore_settle_runs_arrival_services_and_autosaves() -> void` | L453 |
| `test_explore_failure_settle_runs_arrival_services() -> void` | L487 |
| `test_turn_back_runs_arrival_services_and_autosaves() -> void` | L516 |
| `test_turn_back_returns_to_origin_and_keeps_clue_active() -> void` | L546 |
| `test_continue_keeps_sailing_and_marks_the_alert() -> void` | L590 |
| `test_alert_threshold_and_progress_come_from_the_rules() -> void` | L612 |
| `test_continue_cannot_answer_the_alert_twice() -> void` | L656 |
| `test_chart_view_exposes_alert_state_while_exploring() -> void` | L680 |
| `test_sea_chart_view_exposes_clues_explore_and_buy_state() -> void` | L704 |
| `test_rules_are_read_from_the_core_map_profile() -> void` | L756 |
| `test_game_state_backfills_the_clue_block_lazily() -> void` | L771 |
| `test_save_load_roundtrip_preserves_exploration_state() -> void` | L787 |

`clue.buy` 门禁、`explore.start` 扣费与在航标记、`explore.settle` 成功发现与失败漂流、
`explore.decide` 掉头 / 继续、`sea_chart.view` 的线索 / 探索 / 购买视图，以及存档往返。

## 契约与约束
- 每个用例用 `bootstrap_core()` + `run.start` 拿真实 Core 注册表与真实对局；
  线索一律通过 `ClueService.acquire` 构造（不依赖随机成功），需要固定等级/可信度时
  才在构造后改写测试用的字段。
- 概率用例直接验证 `ExplorationRules.roll_succeeds` 的 0 / 1 边界与固定 seed 复现；
  发现 / 未发现用出发时抽定的 `outcome_roll`（契约 §2）强制，而不是依赖真实随机。
- 断言取值遵守契约 §3 的 Core 数值（40 金币、漂流 6h、额外煤水 4、耐久 8 等），
  避免测试与内容 JSON 脱节。

模块索引：[framework/tests](../README.md)
