# `framework/tests/cases/test_campaign_start.gd`

> 作用：C4 开局入口测试：`run.start` 的默认路径（无 start_profile）与显式 start_profile

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STEADY_SCENARIO` | L20 |
| `SWIFT_SCENARIO` | L21 |
| `STANDARD_PROFILE` | L22 |
| `HARD_PROFILE` | L23 |
| `CORE_MAP_CONFIG` | L24 |
| `TEST_MAP_CONFIG` | L25 |
| `test_default_run_start_assembles_a_campaign() -> void` | L63 |
| `test_default_scenario_and_scenario_override() -> void` | L88 |
| `test_save_header_is_unchanged() -> void` | L110 |
| `test_unknown_profile_or_scenario_returns_structured_errors() -> void` | L128 |
| `test_retired_types_are_not_registered() -> void` | L145 |
| `test_campaign_view_is_shape_stable() -> void` | L167 |
| `test_content_refs_reads_map_config_without_fallback() -> void` | L191 |
| `test_real_resolvers_read_the_map_config() -> void` | L223 |

路径都经 `CampaignFactory` 装配；`port_templates` / `starting_scenarios` / `map_configs`
是唯一内容来源，`map_profiles` 退役且 `ContentRefs` 不再回退；`campaign.view` 形状稳定；
存档 header 不变。

- 关键依赖：`bootstrap_core()`、`CampaignFactory.create_default_campaign`、
  `ContentRefs`、`StoryService.config()`、`ExplorationRules.read()`、`GameState`

## 契约与约束
- C4 起没有 1.0「build + map_profile」路径：无 `start_profile` 时使用最低 id 的 start
  profile（内容用 `start.standard` tag 声明，core 为 standard 档案）+ 可选 `starting_scenario` 覆盖。
- `data.run` / `state.world` / `campaign.setup` 只记 `starting_scenario(_id)`，不再有
  `map_profile_id` / `starting_build` 字段。
- resolver 用例只用公开入口（`ContentRefs` / `StoryService.config` /
  `ExplorationRules.read`），不依赖 dev_mods/core 之外的内容。

模块索引：[framework/tests](../README.md)
