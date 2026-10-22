# `framework/tests/cases/test_world_completeness.gd`

> 作用：Phase B Core 完整性规则（WORLD_SCHEMA_V2_RUNTIME §5.2/§5.3）测试：用最小可运行的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WORLD_PROFILE_ID` | L21 |
| `MAP_CONFIG_ID` | L22 |
| `REGION_ID` | L23 |
| `WEATHER_PROFILE_ID` | L24 |
| `START_PROFILE_ID` | L25 |
| `STARTING_BUILD_ID` | L26 |
| `STANDARD_HULL_ID` | L27 |
| `STANDARD_BOILER_ID` | L28 |
| `STANDARD_CARGO_ID` | L29 |
| `test_bootstrapped_core_baseline_is_ok_without_phase_b() -> void` | L32 |
| `test_gate_is_off_without_world_profiles() -> void` | L45 |
| `test_third_party_world_profile_does_not_enable_core_rules() -> void` | L53 |
| `test_missing_map_config_reports_error() -> void` | L68 |
| `test_missing_start_profile_reports_error() -> void` | L75 |
| `test_missing_weather_profile_reports_error() -> void` | L81 |
| `test_missing_region_reports_error() -> void` | L86 |
| `test_complete_phase_b_content_has_no_errors() -> void` | L92 |
| `test_suggested_content_is_warning_only() -> void` | L98 |
| `test_map_config_needs_at_least_port_count_archetypes() -> void` | L114 |
| `test_start_region_tags_must_match_a_region() -> void` | L122 |
| `test_start_profile_must_resolve_starting_build() -> void` | L130 |
| `test_phase_b_capabilities_are_whitelisted() -> void` | L139 |

1.0 合成基线 + 注入的 2.0 世界/战役定义驱动 `CoreCompletenessChecker.check()`，覆盖
presence gate、5 个硬性数量下限、4 个建议 warning、start_profile 组合解析与 capability 白名单。

## 契约与约束
- v2 规则只在 **Core 自己** 发布至少一个 `world_profiles` 定义时启用（B4 之后）；当前 Core
  没有 v2 内容时 `bootstrap_core()` 基线必须保持 `ok`，第三方单独提供的 v2 world profile
  也不能让 Core 完整性规则变红。
- 硬性 error（`content_count`）：world_profiles / map_configs / start_profiles /
  weather_profiles / regions 各 ≥1。
- 建议 warning（`content_count_recommended`）：route_templates / factions / sites / discoveries 各 ≥1。
- 组合规则：start_profile 必须解析 world_profile + map_config（缺省引用回退到唯一 map config）+
  starting_build；start_region_tags 至少匹配一个 regions.region_tags；map config 的
  archetypes 数量 ≥ world_profile.port_count。
- `content.world.v1` / `content.campaign.v1` 在 `AppContext.KNOWN_CAPABILITIES` 中，声明它们的
  manifest 不会被 dependency_resolver 以 unsupported capability 禁用。

模块索引：[framework/tests](../README.md)
