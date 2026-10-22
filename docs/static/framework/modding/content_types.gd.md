# `framework/modding/content_types.gd`

> 作用：内容类型常量、Schema 路径、单数类型名与模块类型集合；由 tools/gen_content_types.mjs 从 content_types.json 生成。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentTypes` | L1 |
| `GOOD` | L9 |
| `MATERIAL` | L10 |
| `HULL` | L11 |
| `MODULE` | L12 |
| `ROLE` | L13 |
| `STRATEGY` | L14 |
| `PORT_ARCHETYPE` | L15 |
| `MAP_PROFILE` | L16 |
| `STARTING_BUILD` | L17 |
| `WORLD_PROFILE` | L18 |
| `REGION` | L19 |
| `SITE` | L20 |
| `ROUTE_TEMPLATE` | L21 |
| `WEATHER_PROFILE` | L22 |
| `FACTION` | L23 |
| `DISCOVERY` | L24 |
| `START_PROFILE` | L25 |
| `MAP_CONFIG` | L26 |
| `CONTRACT` | L27 |
| `EVENT` | L28 |
| `PATCH` | L29 |
| `SCHEMA_PATHS` | L31 |
| `SCHEMA_VERSIONS` | L55 |
| `SINGULAR` | L79 |
| `MODULE_TYPES` | L103 |
| `all() -> Array[StringName]` | L106 |
| `registry_types() -> Array[StringName]` | L116 |
| `is_known(content_type: StringName) -> bool` | L122 |
| `is_module(content_type: StringName) -> bool` | L126 |
| `is_patch(content_type: StringName) -> bool` | L130 |
| `schema_path(content_type: StringName) -> String` | L134 |
| `schema_version(content_type: StringName) -> String` | L138 |
| `singular(content_type: StringName) -> String` | L142 |
| `from_singular(singular_name: String) -> StringName` | L146 |

## 契约与约束

- 禁止手改；修改 `content_types.json` 后运行 `node tools/gen_content_types.mjs`。
- `content_type` 决定注册表与 Schema；`all()` 不包含 patches，patches 由 ContentCompiler 单独收集。
- `MODULE_TYPES` 由 manifest 的 `module: true` 派生；单数类型用于 `<mod>:<type>/<id>` 的 ID 校验。

模块索引：[framework/modding](./README.md)
