# `framework/tests/cases/test_schema_v2_drafts.gd`

> 作用：Content Schema 2.0 草案测试：用现有 SchemaValidator 验证 start/world/region/site/route/weather/faction/discovery 草案，并守护草案类型不进入 active 注册表。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_start_profile_v2_schema_accepts_valid_file() -> void` | L45 |
| `test_start_profile_v2_schema_rejects_invalid_data() -> void` | L51 |
| `test_world_profile_v2_schema_accepts_valid_file() -> void` | L63 |
| `test_world_generation_v2_drafts_accept_valid_definitions() -> void` | L107 |
| `test_world_actor_v2_drafts_accept_valid_definitions() -> void` | L141 |
| `test_world_actor_v2_drafts_reject_invalid_definitions() -> void` | L179 |
| `test_draft_schemas_are_planned_and_not_active() -> void` | L207 |

## 契约与约束

- 合法 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery envelope 必须零错误；缺字段、非法 ID、非法 difficulty、非法 cargo、越界概率、非法稀有度/权重必须报错。
- `draft_schemas` 中的类型必须出现在 planned、不得出现在 ContentTypes.all()，对应 Schema 文件必须存在。
- 草案 Schema 只使用项目校验器支持的 JSON Schema 子集；正式接入运行时前保持 planned。

模块索引：[framework/tests](../README.md)
