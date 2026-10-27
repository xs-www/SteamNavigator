作用：剧情模式篇章（Story Mode 数据契约 V2，草案类型）：固定主角、带可选立绘的角色表、术语、有序关卡列表与正史溯源；一个剧情包通常一个篇章。契约见 `docs/specs/STORY_MODE_DATA_CONTRACT_V2.md`。

- 引用关系：`content_types.json.draft_schemas.story_arcs` 指向本文件；SNModMaker / Content CLI 用它校验，当前运行时不加载（草案）。
- 冻结：本文件与 `story_level.schema.json` 及 common 的 12 个 story `$defs` 由 `tools/check_story_schema_freeze.mjs --check` 按规范化 JSON 哈希锁定（`schemas/v2/story_schema_freeze.json`）；结构变更走契约 §14 版本流程。
- 定义 envelope 固定 `schema_version: "2.0"`、`content_type: "story_arcs"`，单条定义复用 `common.schema.json#/$defs/definition`（`id` / `name_key` / `enabled` / `data`）。
- `data.protagonist_id` 必须是 `characters` 中的角色 ID；角色 `role` 不是 `protagonist` 时 warning `story_protagonist_role`。
- `data.characters[].id` / `data.terms[].id` 是篇章内局部标识符（`^[a-z][a-z0-9_]{0,31}$`），不是跨定义引用；`characters` / `terms` 各 ≤64；`portrait_asset` 是 manifest assets 键（png/webp），供 2D 叙事默认立绘。
- `data.levels` 只列 `story_level` 的完整 ID，数组顺序即关卡顺序；≤32、不能跨包（`story_arc_level_foreign`）；允许为空（warning `story_arc_empty_levels`），方便先写世界观。
- `data.completion_achievement` 只登记成就 ID，不写金钱或物品；成就系统上线前可留空。
- 相关：`docs/specs/STORY_MODE_DATA_CONTRACT_V2.md`、`docs/design/STORY_MODE.md`、`schemas/v2/story_level.schema.json`、`SNModMaker/js/validate.js`（`checkStoryArcSemantics` / `checkStoryPack`）。