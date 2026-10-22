# `framework/tests/cases/test_content_versions.gd`

> 作用：按内容类型声明 Schema 版本（Phase A）与 Phase B 世界/战役家族提升 active 的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TEMP_MOD_ID` | L17 |
| `TEMP_V2_MOD_ID` | L18 |
| `test_every_runtime_type_declares_its_content_schema_version() -> void` | L134 |
| `test_phase_b_world_family_is_active_with_2_0_schemas() -> void` | L149 |
| `test_unknown_type_has_no_declared_version() -> void` | L165 |
| `test_v2_draft_types_are_not_runtime_types() -> void` | L170 |
| `test_promoted_world_profile_content_compiles_and_registers() -> void` | L183 |
| `test_goods_envelope_with_1_0_still_compiles() -> void` | L197 |
| `test_goods_envelope_with_2_0_is_rejected_per_type() -> void` | L211 |
| `test_patch_revalidation_uses_target_type_version() -> void` | L230 |

回归测试：版本表、编译器按类型校验、Patch 再校验、2.0 内容真实加载与注册。

## 契约与约束
- 每个 runtime 类型都必须有非空 schema_version；Phase B 的 9 类
  （world_profiles / regions / sites / route_templates / weather_profiles /
  factions / discoveries / start_profiles / map_configs）为 2.0，其余运行时类型与
  patches 仍为 1.0。
- `content_types.json.draft_schemas` 只剩 `weapons`，草案不得进入 `ContentTypes`。
- 1.0 内容的 envelope 仍走 1.0 校验；goods 声明 2.0 必须报 `unsupported_schema`。
- 一个 2.0 `world_profiles` 内容模组必须通过 ContentCompiler、进入注册表，
  且不产生 fatal / degraded 启动状态。

模块索引：[framework/tests](../README.md)
