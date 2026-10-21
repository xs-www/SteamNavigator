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
| `CONTRACT` | L22 |
| `EVENT` | L23 |
| `PATCH` | L24 |
| `SCHEMA_PATHS` | L26 |
| `SCHEMA_VERSIONS` | L45 |
| `SINGULAR` | L64 |
| `MODULE_TYPES` | L83 |
| `all() -> Array[StringName]` | L86 |
| `registry_types() -> Array[StringName]` | L95 |
| `is_known(content_type: StringName) -> bool` | L101 |
| `is_module(content_type: StringName) -> bool` | L105 |
| `is_patch(content_type: StringName) -> bool` | L109 |
| `schema_path(content_type: StringName) -> String` | L113 |
| `schema_version(content_type: StringName) -> String` | L117 |
| `singular(content_type: StringName) -> String` | L121 |
| `from_singular(singular_name: String) -> StringName` | L125 |

## 契约与约束

- 禁止手改；修改 `content_types.json` 后运行 `node tools/gen_content_types.mjs`。
- `content_type` 决定注册表与 Schema；`all()` 不包含 patches，patches 由 ContentCompiler 单独收集。
- `MODULE_TYPES` 由 manifest 的 `module: true` 派生；单数类型用于 `<mod>:<type>/<id>` 的 ID 校验。

模块索引：[framework/modding](./README.md)
