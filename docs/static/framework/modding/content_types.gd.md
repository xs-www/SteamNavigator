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
| `BOILER` | L12 |
| `CARGO_MODULE` | L13 |
| `NAVIGATION_MODULE` | L14 |
| `SAFETY_MODULE` | L15 |
| `CABIN` | L16 |
| `ROLE` | L17 |
| `STRATEGY` | L18 |
| `PORT_ARCHETYPE` | L19 |
| `MAP_PROFILE` | L20 |
| `STARTING_BUILD` | L21 |
| `WORLD_PROFILE` | L22 |
| `REGION` | L23 |
| `SITE` | L24 |
| `ROUTE_TEMPLATE` | L25 |
| `WEATHER_PROFILE` | L26 |
| `FACTION` | L27 |
| `DISCOVERY` | L28 |
| `START_PROFILE` | L29 |
| `MAP_CONFIG` | L30 |
| `CONTRACT` | L31 |
| `EVENT` | L32 |
| `PATCH` | L33 |
| `SCHEMA_PATHS` | L35 |
| `SCHEMA_VERSIONS` | L63 |
| `SINGULAR` | L91 |
| `MODULE_TYPES` | L119 |
| `all() -> Array[StringName]` | L122 |
| `registry_types() -> Array[StringName]` | L133 |
| `is_known(content_type: StringName) -> bool` | L139 |
| `is_module(content_type: StringName) -> bool` | L143 |
| `is_patch(content_type: StringName) -> bool` | L147 |
| `schema_path(content_type: StringName) -> String` | L151 |
| `schema_version(content_type: StringName) -> String` | L155 |
| `singular(content_type: StringName) -> String` | L159 |
| `from_singular(singular_name: String) -> StringName` | L163 |

## 契约与约束

- 禁止手改；修改 `content_types.json` 后运行 `node tools/gen_content_types.mjs`。
- `content_type` 决定注册表与 Schema；`all()` 不包含 patches，patches 由 ContentCompiler 单独收集。
- `MODULE_TYPES` 由 manifest 的 `module: true` 派生；单数类型用于 `<mod>:<type>/<id>` 的 ID 校验。

模块索引：[framework/modding](./README.md)
