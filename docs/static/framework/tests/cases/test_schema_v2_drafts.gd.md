# `framework/tests/cases/test_schema_v2_drafts.gd`

> 作用：Content Schema 2.0 世界/战役 Schema 测试：SchemaValidator 合法 / 非法样本，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `START_PROFILE_SCHEMA` | L16 |
| `WORLD_PROFILE_SCHEMA` | L17 |
| `REGION_SCHEMA` | L18 |
| `SITE_SCHEMA` | L19 |
| `ROUTE_TEMPLATE_SCHEMA` | L20 |
| `WEATHER_PROFILE_SCHEMA` | L21 |
| `FACTION_SCHEMA` | L22 |
| `DISCOVERY_SCHEMA` | L23 |
| `MAP_CONFIG_SCHEMA` | L24 |
| `test_start_profile_v2_schema_accepts_valid_file() -> void` | L58 |
| `test_start_profile_v2_schema_rejects_invalid_data() -> void` | L64 |
| `test_world_profile_v2_schema_accepts_valid_file() -> void` | L76 |
| `test_world_generation_v2_drafts_accept_valid_definitions() -> void` | L120 |
| `test_world_actor_v2_drafts_accept_valid_definitions() -> void` | L154 |
| `test_world_actor_v2_drafts_reject_invalid_definitions() -> void` | L192 |
| `test_map_config_v2_schema_accepts_all_exploration_keys() -> void` | L300 |
| `test_map_config_v2_schema_rejects_invalid_data() -> void` | L308 |
| `test_phase_b_types_are_active_and_only_weapons_remains_draft() -> void` | L319 |

Phase B 9 类提升 active，`weapons` 仍是唯一草案，`map_configs` 覆盖 31 键 exploration。

## 契约与约束
- start_profile / world_profile / region / site / route_template / weather_profile /
  faction / discovery / map_config 的合法 envelope 必须零错误；缺必填 / 非法 ID /
  非法枚举 / 越界数值 / 未知 exploration 键必须报错。
- `map_configs.exploration` 必须完整覆盖 31 键（4.1 的 19 键 + 4.2–4.5 的 12 键），
  `twin_world_size` 范围 64–1024，`story` 走 story_flow 子 Schema。
- Phase B 的 9 类必须出现在 `content_types.json.types`、schema_version 为 2.0、
  Schema 文件存在且进入 `ContentTypes`；`draft_schemas` 只剩 `weapons`。

模块索引：[framework/tests](../README.md)
