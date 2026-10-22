# `framework/tests/cases/test_schema_v2_drafts.gd`

> 作用：Content Schema 2.0 世界/战役/剧情 Schema 测试：SchemaValidator 合法 / 非法样本，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `START_PROFILE_SCHEMA` | L18 |
| `WORLD_PROFILE_SCHEMA` | L19 |
| `REGION_SCHEMA` | L20 |
| `SITE_SCHEMA` | L21 |
| `ROUTE_TEMPLATE_SCHEMA` | L22 |
| `WEATHER_PROFILE_SCHEMA` | L23 |
| `FACTION_SCHEMA` | L24 |
| `DISCOVERY_SCHEMA` | L25 |
| `MAP_CONFIG_SCHEMA` | L26 |
| `STORY_ARC_SCHEMA` | L27 |
| `STORY_LEVEL_SCHEMA` | L28 |
| `test_start_profile_v2_schema_accepts_valid_file() -> void` | L62 |
| `test_start_profile_v2_schema_rejects_invalid_data() -> void` | L68 |
| `test_world_profile_v2_schema_accepts_valid_file() -> void` | L80 |
| `test_world_generation_v2_drafts_accept_valid_definitions() -> void` | L124 |
| `test_world_actor_v2_drafts_accept_valid_definitions() -> void` | L158 |
| `test_world_actor_v2_drafts_reject_invalid_definitions() -> void` | L196 |
| `test_map_config_v2_schema_accepts_all_exploration_keys() -> void` | L304 |
| `test_map_config_v2_schema_rejects_invalid_data() -> void` | L312 |
| `test_phase_b_types_are_active_and_drafts_are_editor_only() -> void` | L323 |
| `test_story_schemas_accept_valid_arc_and_level() -> void` | L435 |
| `test_story_schemas_reject_invalid_data() -> void` | L443 |

Phase B 9 类提升 active，`weapons` + 剧情 `story_arcs` / `story_levels` 仍是草案，
`map_configs` 覆盖 31 键 exploration。

## 契约与约束
- start_profile / world_profile / region / site / route_template / weather_profile /
  faction / discovery / map_config / story_arc / story_level 的合法 envelope 必须零错误；
  缺必填 / 非法 ID / 非法枚举 / 越界数值 / 未知 exploration 键必须报错。
- `map_configs.exploration` 必须完整覆盖 31 键（4.1 的 19 键 + 4.2–4.5 的 12 键），
  `twin_world_size` 范围 64–1024，`story` 走 story_flow 子 Schema；剧情关卡复用
  `common.schema.json#/$defs/story_stage`，其 checkpoint / presentation 为关卡层新增字段。
- Phase B 的 9 类必须出现在 `content_types.json.types`、schema_version 为 2.0、
  Schema 文件存在且进入 `ContentTypes`；`draft_schemas` 是 weapons + 2 类剧情。

模块索引：[framework/tests](../README.md)
