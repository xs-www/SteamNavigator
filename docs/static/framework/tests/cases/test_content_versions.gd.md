# `framework/tests/cases/test_content_versions.gd`

> 作用：按内容类型声明 Schema 版本（Phase A）与 Phase B 世界/战役家族提升 active 的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TEMP_MOD_ID` | L23 |
| `TEMP_V2_MOD_ID` | L24 |
| `test_every_runtime_type_declares_its_content_schema_version() -> void` | L141 |
| `test_phase_b_world_family_is_active_with_2_0_schemas() -> void` | L190 |
| `test_unknown_type_has_no_declared_version() -> void` | L206 |
| `test_v2_draft_types_are_not_runtime_types() -> void` | L211 |
| `test_promoted_world_profile_content_compiles_and_registers() -> void` | L226 |
| `test_item_envelope_with_2_0_still_compiles() -> void` | L240 |
| `test_item_envelope_with_1_0_is_rejected_per_type() -> void` | L254 |
| `test_patch_revalidation_uses_target_type_version() -> void` | L273 |

回归测试：版本表、编译器按类型校验、Patch 再校验、2.0 内容真实加载与注册。

## 契约与约束
- 每个 runtime 类型都必须有非空 schema_version；Phase B 的 9 类
  （world_profiles / regions / sites / route_templates / weather_profiles /
  factions / discoveries / start_profiles / map_configs）、C1 合并后的
  `modules` + `hulls`、C2 合并后的 `items`、C3 新增的 `quests`、C4 的
  `port_templates` / `starting_scenarios` 与 C4-C 的 `voyage_events` /
  `crew_roles` / `boiler_strategies` 与 C4-D 的 `contracts` / `patches` 为 2.0；
  `map_profiles` / `port_archetypes` / `starting_builds` / `events` / `roles` /
  `strategies` 已退役；C4-D 后不再有 1.0 active 类型。
- `content_types.json.draft_schemas` 是 `weapons` + 剧情模式 `story_arcs` /
  `story_levels`，草案不得进入 `ContentTypes`。
- 所有 active 类型的 envelope 必须声明 2.0；任何声明 1.0 的内容（如 `items`）
  都会报 `unsupported_schema`（C4-D 后无 1.0 active 类型）。
- 一个 2.0 `world_profiles` 内容模组必须通过 ContentCompiler、进入注册表，
  且不产生 fatal / degraded 启动状态。

模块索引：[framework/tests](../README.md)
