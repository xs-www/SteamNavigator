# `framework/tests/cases/test_exploration.gd`

> 作用：探索系统（阶段 4.1–4.4）领域层无头测试：线索生成 / 固定 1 级 / 逐级调查

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SEED` | L29 |
| `STRATEGY_ID` | L30 |
| `test_acquire_always_starts_at_level_one_and_credibility_stays_in_source_ranges() -> void` | L39 |
| `test_acquire_returns_empty_when_no_undiscovered_target() -> void` | L63 |
| `test_acquire_search_zone_and_distance_range_follow_credibility() -> void` | L77 |
| `test_clue_view_clips_secrets_by_level() -> void` | L105 |
| `test_investigate_climbs_to_level_four_without_rerolling_the_target() -> void` | L145 |
| `test_investigate_failure_and_insufficient_money() -> void` | L262 |
| `test_investigate_requires_a_run_a_port_and_an_active_clue() -> void` | L326 |
| `test_chart_view_exposes_investigation_action_fields() -> void` | L379 |
| `test_chart_view_blocks_investigation_at_sea() -> void` | L442 |
| `test_chance_roll_boundaries_are_deterministic() -> void` | L463 |
| `test_on_arrival_rumour_is_reproducible() -> void` | L482 |
| `test_buy_requires_tavern_facility() -> void` | L511 |
| `test_buy_requires_money() -> void` | L521 |
| `test_buy_charges_gold_and_adds_intel_clue() -> void` | L532 |
| `test_buy_is_blocked_by_the_active_clue_cap() -> void` | L562 |
| `test_explore_start_charges_only_wages_and_marks_at_sea() -> void` | L587 |
| `test_explore_start_infeasible_does_not_charge() -> void` | L662 |
| `test_explore_start_twice_fails_with_already_exploring() -> void` | L683 |
| `test_explore_settle_success_discovers_target() -> void` | L699 |
| `test_explore_settle_failure_drifts_to_nearest_discovered_port() -> void` | L758 |
| `test_failed_clue_can_be_sailed_again() -> void` | L831 |
| `test_explore_settle_without_a_voyage_fails() -> void` | L865 |
| `test_explore_settle_runs_arrival_services_and_autosaves() -> void` | L874 |
| `test_explore_failure_settle_runs_arrival_services() -> void` | L908 |
| `test_turn_back_runs_arrival_services_and_autosaves() -> void` | L937 |
| `test_turn_back_returns_to_origin_and_keeps_clue_active() -> void` | L967 |
| `test_continue_keeps_sailing_and_marks_the_alert() -> void` | L1015 |
| `test_alert_threshold_and_progress_come_from_the_rules() -> void` | L1037 |
| `test_continue_cannot_answer_the_alert_twice() -> void` | L1086 |
| `test_chart_view_exposes_alert_state_while_exploring() -> void` | L1110 |
| `test_sea_chart_view_exposes_clues_explore_and_buy_state() -> void` | L1134 |
| `test_rules_are_read_from_the_core_map_config() -> void` | L1188 |
| `test_fog_radii_are_world_size_relative_and_content_driven() -> void` | L1232 |
| `test_game_state_backfills_the_clue_block_lazily() -> void` | L1264 |
| `test_save_load_roundtrip_preserves_exploration_state() -> void` | L1280 |
| `test_goods_clue_freezes_a_snapshot_and_discloses_by_level() -> void` | L1328 |
| `test_expired_goods_clue_is_swept_by_commands_and_frees_the_cap() -> void` | L1403 |
| `test_clue_list_query_returns_trimmed_clues_and_expired_history() -> void` | L1443 |
| `test_legacy_clue_entries_are_normalized_without_a_schema_bump() -> void` | L1502 |
| `test_wait_clue_chance_math_and_command_acquisition() -> void` | L1553 |
| `test_wait_prefers_goods_leads_when_a_market_is_known() -> void` | L1594 |
| `test_contract_completion_hook_unlocks_a_clue() -> void` | L1619 |
| `test_clue_travel_sails_to_the_goods_lead_harbour() -> void` | L1657 |

（`clue.investigate`）/ 分级裁剪 / 命名流复现、`clue.buy` 门禁、`explore.start`
扣费与在航标记、`explore.settle` 成功发现与失败漂流、`explore.decide` 掉头 / 继续、
`sea_chart.view` 的线索 / 探索 / 购买视图、4.4 货物行情线索（冻结快照 / 时效 /
`clue.list` / 旧存档 normalize）、新来源（在港等待 / 完成委托）与 `clue.travel`，
以及存档往返。

## 契约与约束
- 每个用例用 `bootstrap_core()` + `run.start` 拿真实 Core 注册表与真实对局；
  线索一律通过 `ClueService.acquire` 构造（不依赖随机成功），需要固定等级/可信度时
  才在构造后改写测试用的字段。
- 4.3.2 / U2：`acquire` 不再抽等级，新线索必为 1 级；升级只能走 `clue.investigate`
  （在港、active、上限 4）。目标港 / 搜索区 / 可信度在获得时固定，调查只逐级披露；
  测试逐次记录这些字段并断言不变。
- 概率用例直接验证 `ExplorationRules.roll_succeeds` 的 0 / 1 边界与固定 seed 复现；
  发现 / 未发现用出发时抽定的 `outcome_roll`（契约 §2）强制，而不是依赖真实随机。
- 4.3.5 / U8：探索出航只扣工资，煤水库存留在船上（`departure_coal/water` +
  `coal_rate/water_rate` 记入航次与 presentation）；结算按实际航行小时一次性扣款
  （成功 arrival-departure、失败 duration+drift、掉头 duration/2，额外损耗另计）。
  用例断言出发库存不变、各路径的实际扣减与告警仍按出发库存预判。
- 断言取值遵守契约 §3 的 Core 数值（40 金币、漂流 6h、额外煤水 4、耐久 8 等），
  避免测试与内容 JSON 脱节。
- 4.5.4：购买线索的设施判断改走酒馆（`tavern`），测试显式移除 / 添加酒馆设施，
  不再依赖起始港「没有情报站」的旧假设。

模块索引：[framework/tests](../README.md)
