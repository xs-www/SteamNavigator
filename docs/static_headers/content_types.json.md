作用：内容类型单一真源：键、单数、Schema 路径、注册表/patch 类型、编辑器展示元数据、Schema 2.0 草案元数据、v2 模块分类与正式版路线图规划。

- `tools/gen_content_types.mjs` 生成 `framework/modding/content_types.gd`（只含可加载的 active 类型）与 `SNModMaker/js/content-types.js`（`TYPES` + `DRAFT_TYPES`）；`--check` 用于 CI 门禁。

## 契约与约束

- `types` 只列可加载的 Content Schema 1.0 active 类型；`planned` 只是路线图，禁止注册或加载。
- `v2_target` / `aliases` 是迁移提示，不代表当前运行时支持合并后的实体。
- `v2_module_categories` 记录目标分类：导航/安全归入 `utility`，不再单独设内容类型或编辑器分组。
- `draft_schemas` 与 `draft_types` 键集合必须完全一致：前者登记 Schema 2.0 草案的 Schema 文件，后者登记编辑器展示元数据（`singular` / `key_prefix` / 标签 / 默认文件 / `schema_version` / `capability`）。草案类型必须仍在 `planned` 中、不得 active。
- 草案类型只由 SNModMaker 与 Content CLI 编辑；运行时 `ContentCompiler` 只接受 `FrameworkInfo.CONTENT_SCHEMA`（`1.0`），草案内容因 `schema_version` 不匹配不会被加载。
- Godot `test_content_types_manifest.gd` / `test_schema_v2_drafts.gd` 与 Node 用例分别守护生成物、草案 Schema 与 manifest 一致性。
