作用：剧情模式篇章（Content Schema 2.0 草案）：固定主角、角色表、术语、有序关卡列表与正史溯源；一个剧情包通常一个篇章。

- 引用关系：`content_types.json.draft_schemas.story_arcs` 指向本文件；SNModMaker / Content CLI 用它校验，当前运行时不加载（草案）。
- 定义 envelope 固定 `schema_version: "2.0"`、`content_type: "story_arcs"`，单条定义复用 `common.schema.json#/$defs/definition`（`id` / `name_key` / `enabled` / `data`）。
- `data.protagonist_id` 必须是 `characters` 中的角色 ID（语义错误 `story_protagonist_unknown`）；本作固定单主角。
- `data.characters[].id` / `data.terms[].id` 是篇章内局部标识符（`^[a-z][a-z0-9_]{0,31}$`），不是跨定义引用。
- `data.levels` 只列 `story_level` 的完整 ID，数组顺序即关卡顺序；关卡自身不写 `order` / `next_level` / `arc_id`。允许为空（语义 warning `story_arc_empty_levels`），方便先写世界观。
- `data.completion_achievement` 只登记成就 ID，不写金钱或物品；成就系统上线前可留空。
- 相关：`docs/design/STORY_MODE.md`、`schemas/v2/story_level.schema.json`、`SNModMaker/js/validate.js`（`checkStoryArcSemantics` / `checkStoryPack`）。