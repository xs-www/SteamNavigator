# `schemas`

> Manifest 与内容文件的 JSON Schema（项目校验器支持的子集）；`schemas/v2/` 存放 Content Schema 2.0（Phase B/C 运行时 Schema + 草案）。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `boiler.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `cabin.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `cargo_module.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `common.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `contract.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `event.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `good.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `hull.schema.json` | hull 内容类型（`schemas/hull.schema.json`）的 1.0 JSON Schema 契约：船体定义 = `common.schema.json#/$defs/module_common` + 船体字段（速度 / 载重 / 耐久 / 槽位 / size_tag），2026-10-22 新增 `$defs/rig_plan` 运行时帆索装配计划。 | [查看](./hull.schema.json.md) |
| `manifest.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `map_profile.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `material.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `navigation_module.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `patch.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `port_archetype.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `role.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `safety_module.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `starting_build.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `strategy.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `v2/common.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/discovery.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/faction.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/hull.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/map_config.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/module.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/region.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/route_template.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/site.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/start_profile.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/story_arc.schema.json` | 剧情模式篇章（Content Schema 2.0 草案）：固定主角、角色表、术语、有序关卡列表与正史溯源；一个剧情包通常一个篇章。 | [查看](./v2/story_arc.schema.json.md) |
| `v2/story_level.schema.json` | 剧情模式关卡（Content Schema 2.0 草案）：内嵌固定地图、初始状态、任务线阶段、叙事简报/节点/结算、难度旋钮、checkpoint 重试与非玩法奖励。 | [查看](./v2/story_level.schema.json.md) |
| `v2/weapon.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/weather_profile.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |
| `v2/world_profile.schema.json` | Content Schema 2.0：common + Phase B active 的 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / map_config + C1 的 module / hull，以及仍为草案的 weapon / story_arc / story_level。 | 本页 |

## 模块契约

- 每类内容一个 envelope Schema；公共字段在 `common.schema.json`。
- 1.x 类型继续使用根目录 Schema；Phase B 的 9 类与 C1 的 `module` / `hull` 共 11 类 2.0 运行时 Schema 在 `schemas/v2/`，由 `content_types.json.types[].schema` 登记并由运行时按类型版本加载。
- `schemas/v2/` 当前：`common`、`start_profile`、`world_profile`、`region`、`site`、`route_template`、`weather_profile`、`faction`、`discovery`、`map_config`、`module`、`hull`、`weapon`、`story_arc`、`story_level`；其中 `weapon` / `story_arc` / `story_level` 仍是草案。
- 标准实体可选 `information.texture/model` 资源键；贴图与 GLB 模型属于展示信息，不替代 data 权威字段。
- Schema 的 `const`/`enum` 与 `ContentTypes`/操作码注册表需同步维护；效果操作码枚举（如 `damage_module`）必须与 `EffectOpRegistry` 同时增改，否则 core 校验会 fatal。
