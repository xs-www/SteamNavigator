作用：剧情模式关卡（Content Schema 2.0 草案）：内嵌固定地图、初始状态、任务线阶段、叙事简报/节点/结算、难度旋钮、checkpoint 重试与非玩法奖励。数据契约 V1 已冻结（2026-10-27），见 `docs/specs/STORY_MODE_DATA_CONTRACT_V1.md`。

- 引用关系：`content_types.json.draft_schemas.story_levels` 指向本文件；当前运行时不加载（草案），编辑器 / CLI 用它校验。
- 冻结：与 `story_arc.schema.json` 及 common 的 story `$defs` 一起被 `tools/check_story_schema_freeze.mjs --check` 哈希锁定；结构变更走契约 §7。
- 定义 envelope 固定 `schema_version: "2.0"`、`content_type: "story_levels"`，单条定义复用 `common.schema.json#/$defs/definition`。
- `data.map.fixed` 是手工固定地图：`ports` 2..32（ID 形如 `port_0`，坐标 0..4096）、`edges` 1..128，航道两端必须是已声明港口；`start_port` 可省，缺省时按 `start.port_id`、首个港口兜底；两个起点字段都写时必须一致（`story_start_port_conflict`）。自环 / 重复航道分别报 `story_fixed_edge_self` / `story_fixed_edge_duplicate`。
- `data.map.fixed.ports[].market` 是 `{item, stock, price}[]`，`item` 必须是完整定义 ID（如 `core:item/coal`），同一港口同一商品唯一（`story_market_duplicate_item`）；设施用规范键（`exchange` / `contracts` / `supply` / `shipyard` / `tavern`），旧 `intel` 报 `story_facility_unknown`。
- `data.map.map_config` 是可选引用：只复用 Core `map_config` 的经济 / 探索参数，地形始终以 `fixed` 为准。
- `data.start.starting_scenario` 引用 `core:starting_scenario/*`（C4 把 1.0 的 start-build 字段改名为 `starting_scenario`）；其余 `start.*` 字段是关卡内初始金钱 / 补给 / 货物 / 模块覆盖。
- `data.stages` 复用 `common.schema.json#/$defs/story_stage`（1..64，`advance` 至少 1 个触发字段）；至少一个 `checkpoint: true`，否则报 `story_level_checkpoint_missing`。
- `data.narrative.beats[].stage_id` 必须属于本关已声明阶段（`story_beat_stage_unknown`），beat `id` 唯一（`story_beat_duplicate`）；`data.fail.default_mode` 必须出现在 `data.fail.allow` 中（`story_fail_default_not_allowed`）。
- `data.rewards` 只允许 `achievements` / `codex_entries` / `cosmetics`（`additionalProperties: false`），保证剧情包不会把金钱、物品写进自由模式。
- 包级约束（`SNModMaker/js/validate.js`）：剧情包必须声明 `content.story.v1`（`story_pack_capability_required`）、v1 恰好 1 个篇章（`story_pack_multiple_arcs`）、只允许剧情类型（`story_pack_off_whitelist`）。
- 相关：`docs/specs/STORY_MODE_DATA_CONTRACT_V1.md`、`docs/design/STORY_MODE.md`、`schemas/v2/story_arc.schema.json`、`sdk/templates/story_pack_iron_tide/`（完整示例包）、`SNModMaker/js/validate.js`（`checkStoryLevelSemantics`）。