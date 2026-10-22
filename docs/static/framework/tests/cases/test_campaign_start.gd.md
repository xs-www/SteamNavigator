# `framework/tests/cases/test_campaign_start.gd`

> 作用：Phase B B3 运行时接线的无头测试：`run.start` 的 1.0 legacy 路径零变化、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `LEGACY_BUILD` | L21 |
| `LEGACY_PROFILE` | L22 |
| `LEGACY_PROFILE_DEF` | L23 |
| `V2_MAP_CONFIG_DEF` | L24 |
| `ASSEMBLY_SUITE` | L25 |
| `test_legacy_run_start_keeps_shape_and_save_header() -> void` | L96 |
| `test_campaign_view_is_shape_stable() -> void` | L151 |
| `test_campaign_view_reads_v2_sections() -> void` | L172 |
| `test_content_refs_resolves_legacy_and_v2_definitions() -> void` | L238 |
| `test_real_resolvers_use_the_1_0_fallback() -> void` | L283 |
| `test_run_start_with_start_profile_creates_v2_campaign() -> void` | L340 |

可选 `start_profile` 走 `CampaignFactory` 的 v2 路径、`campaign.view` 形状稳定、
`campaign.setup` / `campaign.world.regions|sites` / `campaign.factions` 新字段的
惰性默认，以及 `ContentRefs.map_config` 对 1.0 / v2 两种 state 的解析。

- 关键依赖：`bootstrap_core()`、`RunStartCommand`、`CampaignFactory`、
  `CampaignViewQuery`、`ContentRefs`、`StoryService.config()`、
  `ExplorationRules.read()`、`test_campaign_assembly.gd` 的合成 v2 fixture

## 契约与约束
- 1.0 legacy 用例只断言「仍能开局 + 旧 header 不变 + map_profile 解析不变」，
  不锁 1.0 state 的完整 hash（新分区默认块会按设计惰性出现）。
- v2 用例不依赖 B4 core 内容：优先复用 B3-A 测试文件的 public 合成 fixture；
  fixture 不存在时用例失败并给出明确原因，而不是伪造通过。
- resolver 用例只用公开入口（`ContentRefs` / `StoryService.config` /
  `ExplorationRules.read`），不直接摸私有 `_profile` 辅助函数。

模块索引：[framework/tests](../README.md)
