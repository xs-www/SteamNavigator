作用：内容类型单一真源：键、单数、Schema 路径、注册表/patch 类型、编辑器展示元数据、Schema 2.0 草案元数据、v2 模块分类与正式版路线图规划。

- `tools/gen_content_types.mjs` 生成 `framework/modding/content_types.gd`（只含可加载的 active 类型）与 `SNModMaker/js/content-types.js`（`TYPES` + `DRAFT_TYPES`）；`--check` 用于 CI 门禁。

## 契约与约束

- `types` 只列可加载的 active 类型；每个条目声明自己的 `schema_version`（D4 后 **37 类全部为 `2.0`**：36 个定义 + `patches`，0 个 1.0 runtime），生成器校验它等于对应 Schema 的版本声明并产出 `ContentTypes.SCHEMA_VERSIONS`。`planned` 只是路线图，禁止注册或加载。
- `content_schema` 只是基线/默认版本（存档 header、编辑器默认），运行时的唯一版本来源是每个类型的 `schema_version`。
- `v2_target` / `aliases` 已清空：全部 active 类型都已是目标类型（`map_profiles` 退役，`port_templates` / `starting_scenarios` / `voyage_events` / `crew_roles` / `boiler_strategies` 等已转正）。
- `v2_module_categories` 记录目标分类：导航/安全归入 `utility`，不再单独设内容类型或编辑器分组。
- `draft_schemas` 与 `draft_types` 键集合必须完全一致：前者登记 Schema 2.0 草案的 Schema 文件，后者登记编辑器展示元数据（`singular` / `key_prefix` / 标签 / 默认文件 / `schema_version` / `capability`）。草案类型必须仍在 `planned` 中、不得 active。当前 3 个草案类型：剧情 `story_arcs` / `story_levels`（`content.story.v1`，见 `docs/design/STORY_MODE.md`）与战斗 AI `combat_ai_profiles`（`content.combat.v1`，schema 先行，运行时暂不加载）；`weapons` 已于 D1 提升为 active（连同 `damage_types` / `combat_abilities` / `enemy_archetypes` / `encounter_tables` / `loot_tables`）。
- 草案类型只由 SNModMaker 与 Content CLI 编辑；运行时 `ContentCompiler` 按每个 active 类型的 `schema_version` 接收 2.0 内容，草案内容因类型未 active 被拒绝（`inactive_content_type`）。剧情包因此只允许 `story_arcs` / `story_levels` 内容（`story_pack_off_whitelist`），保证不改动自由模式；`combat_ai_profiles` 只随战斗 AI 后续切片接入。
- Godot `test_content_types_manifest.gd` / `test_schema_v2_drafts.gd` / `test_schema_v2_weapons.gd` / `test_combat.gd` / `test_simulation.gd` 与 Node 用例分别守护生成物、active 战斗类型与 manifest 一致性。
