作用：剧情模式关卡（Content Schema 2.0 草案）：内嵌固定地图、初始状态、任务线阶段、叙事简报/节点/结算、难度旋钮、checkpoint 重试与非玩法奖励。

- 引用关系：`content_types.json.draft_schemas.story_levels` 指向本文件；当前运行时不加载（草案），编辑器 / CLI 用它校验。
- 定义 envelope 固定 `schema_version: "2.0"`、`content_type: "story_levels"`，单条定义复用 `common.schema.json#/$defs/definition`。
- `data.map.fixed` 是手工固定地图：`ports` ≥ 2（ID 形如 `port_0`）、`edges` ≥ 1，航道两端必须是已声明港口；`start_port` 可省，缺省时按 `start.port_id`、首个港口兜底。
- `data.map.map_config` 是可选引用：只复用 Core `map_config` 的经济 / 探索参数，地形始终以 `fixed` 为准。
- `data.start.starting_scenario` 引用 `core:starting_scenario/*`（C4 把 1.0 的 start-build 字段改名为 `starting_scenario`）；其余 `start.*` 字段是关卡内初始金钱 / 补给 / 货物 / 模块覆盖。
- `data.stages` 复用 `common.schema.json#/$defs/story_stage`（关卡层在其上增加 `checkpoint` / `presentation` 语义）；至少一个 `checkpoint: true`，否则报 `story_level_checkpoint_missing`。
- `data.narrative.beats[].stage_id` 必须属于本关已声明阶段（`story_beat_stage_unknown`）；`data.fail.default_mode` 必须出现在 `data.fail.allow` 中（`story_fail_default_not_allowed`）。
- `data.rewards` 只允许 `achievements` / `codex_entries` / `cosmetics`（`additionalProperties: false`），保证剧情包不会把金钱、物品写进自由模式。
- 相关：`docs/design/STORY_MODE.md`、`schemas/v2/story_arc.schema.json`、`sdk/templates/story_pack_iron_tide/`（完整示例包）、`SNModMaker/js/validate.js`（`checkStoryLevelSemantics`）。