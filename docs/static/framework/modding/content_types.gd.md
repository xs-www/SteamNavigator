# `framework/modding/content_types.gd`

> 作用：内容类型常量、Schema 路径、单数类型名与模块类型集合；由 tools/gen_content_types.mjs 从 content_types.json 生成。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentTypes` | L1 |
| `ITEM` | L9 |
| `HULL` | L10 |
| `MODULE` | L11 |
| `CREW_ROLE` | L12 |
| `BOILER_STRATEGY` | L13 |
| `PORT_TEMPLATE` | L14 |
| `STARTING_SCENARIO` | L15 |
| `WORLD_PROFILE` | L16 |
| `REGION` | L17 |
| `SITE` | L18 |
| `ROUTE_TEMPLATE` | L19 |
| `WEATHER_PROFILE` | L20 |
| `FACTION` | L21 |
| `DISCOVERY` | L22 |
| `START_PROFILE` | L23 |
| `MAP_CONFIG` | L24 |
| `CONTRACT` | L25 |
| `QUEST` | L26 |
| `VOYAGE_EVENT` | L27 |
| `PATCH` | L28 |
| `WEAPON` | L29 |
| `DAMAGE_TYPE` | L30 |
| `COMBAT_ABILITY` | L31 |
| `ENEMY_ARCHETYPE` | L32 |
| `ENCOUNTER_TABLE` | L33 |
| `LOOT_TABLE` | L34 |
| `SHIP_ARCHETYPE` | L35 |
| `CAPTAIN` | L36 |
| `FORMATION` | L37 |
| `FLEET_DOCTRINE` | L38 |
| `BASE_SITE` | L39 |
| `BUILDING` | L40 |
| `BUILDING_UPGRADE` | L41 |
| `PRODUCTION_RECIPE` | L42 |
| `WORKER_ROLE` | L43 |
| `TRADE_POLICY` | L44 |
| `AUTOMATION_RULE` | L45 |
| `RUIN_ARCHETYPE` | L46 |
| `ROOM_TEMPLATE` | L47 |
| `EXPEDITION_EVENT` | L48 |
| `HAZARD_TABLE` | L49 |
| `RELIC` | L50 |
| `SCHEMA_PATHS` | L52 |
| `SCHEMA_VERSIONS` | L97 |
| `SINGULAR` | L142 |
| `MODULE_TYPES` | L187 |
| `all() -> Array[StringName]` | L190 |
| `registry_types() -> Array[StringName]` | L205 |
| `is_known(content_type: StringName) -> bool` | L211 |
| `is_module(content_type: StringName) -> bool` | L215 |
| `is_patch(content_type: StringName) -> bool` | L219 |
| `schema_path(content_type: StringName) -> String` | L223 |
| `schema_version(content_type: StringName) -> String` | L227 |
| `singular(content_type: StringName) -> String` | L231 |
| `from_singular(singular_name: String) -> StringName` | L235 |

## 契约与约束

- 禁止手改；修改 `content_types.json` 后运行 `node tools/gen_content_types.mjs`。
- `content_type` 决定注册表与 Schema；`all()` 不包含 patches，patches 由 ContentCompiler 单独收集。
- `MODULE_TYPES` 由 manifest 的 `module: true` 派生；单数类型用于 `<mod>:<type>/<id>` 的 ID 校验。

模块索引：[framework/modding](./README.md)
