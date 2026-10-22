# `framework/tests/cases/test_world_schema_refs.gd`

> 作用：Phase B 世界/战役 9 类内容的跨引用校验测试：用真实 Core 基线（`bootstrap_core()`）

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TEST_MOD` | L23 |
| `TEST_FILE` | L24 |
| `test_world_profiles_weather_profile_reference() -> void` | L137 |
| `test_regions_weather_and_faction_references() -> void` | L163 |
| `test_sites_planned_references_are_warnings_only() -> void` | L194 |
| `test_route_template_planned_encounter_table_is_warning_only() -> void` | L210 |
| `test_weather_profiles_have_no_outgoing_references() -> void` | L225 |
| `test_factions_trade_goods_and_rival_references() -> void` | L233 |
| `test_faction_self_rival_is_reference_self() -> void` | L254 |
| `test_faction_missing_trade_good_and_rival_are_errors() -> void` | L271 |
| `test_faction_contract_family_is_inactive_type_warning() -> void` | L289 |
| `test_discoveries_unlock_ids_reference_checks() -> void` | L307 |
| `test_start_profile_valid_without_optional_map_config() -> void` | L334 |
| `test_start_profile_missing_hard_references_are_errors() -> void` | L359 |
| `test_map_config_valid_with_matching_world_profile() -> void` | L378 |
| `test_map_config_archetype_count_below_world_port_count_is_error() -> void` | L415 |
| `test_map_config_count_check_skips_missing_world_profile() -> void` | L449 |
| `test_map_config_missing_archetype_and_default_build_are_errors() -> void` | L478 |

复制出的临时 `RegistryHub` 注册合成定义，驱动 `CrossReferenceValidator.validate()`，
覆盖硬引用缺失 error、planned 目标 `ref_inactive_type` warning、阵营自指
`reference_self` 与 `map_configs.archetypes` 数量组合规则。

## 契约与约束
- 测试不假设 Core 已有 v2 内容（B4 才落盘）；所有 9 类定义都是合成 ID（`test:*`）。
  基线只借用已存在的 1.0 定义（contracts / events / starting_builds / port_archetypes 等）
  让 `validate()` 的既有检查保持干净，从而能对合成定义的 error / warning 做精确断言。
- 硬引用缺失（`reference_missing`）：world_profiles.weather_profile、regions 的
  weather_profile / factions[]、factions.trade_goods / rival_factions、discoveries.unlock_ids、
  start_profiles 的 world_profile / starting_build / starting_contract / starting_cargo[].item /
  map_config、map_configs 的 archetypes / default_starting_build。
- sites 的 ruin_archetype / encounter_table / loot_table、route_templates.encounter_table、
  factions.contract_family 指向 planned 类型：只出 `ref_inactive_type` warning，不出 error。
- factions.rival_factions 允许同类型引用，但指向自身报 `reference_self`。
- `map_configs.archetypes` 数量 < 引用它的 start_profile.world_profile.port_count 时报
  `map_config_archetype_count`；world_profile 不存在时跳过该组合检查。

模块索引：[framework/tests](../README.md)
