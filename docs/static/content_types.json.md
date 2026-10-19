# `content_types.json`

> 作用：内容类型单一真源：键、单数、Schema 路径、注册表/patch 类型、编辑器展示元数据、v2 模块分类与正式版路线图规划。

- 类型：JSON 数据/配置

## 契约与约束

- `tools/gen_content_types.mjs` 生成 `framework/modding/content_types.gd` 与 `SNModMaker/js/content-types.js`；`--check` 用于门禁。
- Godot 的 `test_content_types_manifest.gd` 与 Node 用例分别守护生成物与 manifest 一致。
- `types` 只列可加载的 active 类型；`planned` 只用于路线图，禁止注册或加载。
- `v2_target` / `aliases` 是迁移提示，不代表当前运行时支持合并后的实体。
- `v2_module_categories` 记录目标分类：导航/安全归入 `utility`，不再单独设内容类型或编辑器分组。
- `draft_schemas` 登记 Schema 2.0 草案：类型必须仍在 planned 中、不得 active，Schema 文件由 `test_schema_v2_drafts.gd` 校验；当前包含 start_profiles / world_profiles / regions / sites / route_templates / weather_profiles / factions / discoveries。
