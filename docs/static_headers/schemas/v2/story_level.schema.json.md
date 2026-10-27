作用：剧情模式关卡（Story Mode 数据契约 V2，草案类型）：手写陆地与航道路径、初始状态、可见系统限制、2D 叙事（lines/choices/focus）、内嵌 tasks、触发器、难度/奖励/失败。契约见 `docs/specs/STORY_MODE_DATA_CONTRACT_V2.md`。

- 引用关系：`content_types.json.draft_schemas.story_levels` 指向本文件；当前运行时不加载（草案），编辑器 / CLI 用它校验。
- 冻结：与 `story_arc.schema.json` 及 common 的 12 个 story `$defs` 一起被 `tools/check_story_schema_freeze.mjs --check` 哈希锁定；结构变更走契约 §14。
- 定义 envelope 固定 `schema_version: "2.0"`、`content_type: "story_levels"`，单条定义复用 `common.schema.json#/$defs/definition`。
- `data.map.fixed` 是手写固定地图：`landmasses` 1..32（polygon 3..256 点，坐标 0..4096）、`ports` 2..32（不得落在陆地内，`story_port_on_land`）、`edges` 1..128（`path` 2..512 点，首末点必须与港口位置一致，`story_route_endpoint_mismatch`；不写 `distance`，由路径折线长度派生）。自环/重复航道、端点未知、穿陆（warning）与连通性均有校验。
- `data.map.revealed_ports` 控制初始揭示港口；`fog` = revealed/explored/unknown；`map_config` 可选，只复用 Core 经济/探索参数。
- `data.start.starting_scenario` 必填（船/构筑/初始模块），`money` / `ship_fuel` / `ship_water` / `cargo` / `equipped_modules` 可覆盖；`route_access` = all/none/listed，`unlocked_routes` 在 listed 时必填。
- `data.access` 与 `stages[].access`：页面 / 动作三态 `available` / `locked`（必带 `reason_key`）/ `hidden`，市场/模块白名单 `mode: all|allow`；阶段覆盖在进入阶段时应用。
- `data.stages` 复用 `common.schema.json#/$defs/story_stage`（1..64）：`lines`（说话人 + 文本 + 可选立绘/背景/音频）、`choices`（选项只应用效果、不跳关）、`focus.targets`（1..4）、`access` 覆盖、`effects`（opcode 白名单）与 `advance`；至少一个 `checkpoint: true`。剧情关卡禁止 `camera_hint`（无 3D 镜头，`story_presentation_unsupported`）。
- `data.tasks` 1..16：内嵌任务复用 quest 阶段/目标语义（`event` / `counter` / `at_least` / `match`），任务奖励只在本关生效；运行时复用 QuestService 状态机。
- `data.triggers` 0..64：`when` 条件 + `effects`，`once` 默认 true。
- `data.rewards` 只允许 `achievements` / `codex_entries` / `cosmetics`（`additionalProperties: false`），保证剧情包不会把金钱、物品写进自由模式；`fail` 支持 checkpoint/level_start 与失败文案键。
- 包级约束（`SNModMaker/js/validate.js`）：剧情包必须声明 `content.story.v1`（`story_pack_capability_required`）、v2 恰好 1 个篇章（`story_pack_multiple_arcs`）、只允许剧情类型（`story_pack_off_whitelist`）；speaker 必须在篇章角色表、媒体资源必须存在于 manifest.assets。
- 相关：`docs/specs/STORY_MODE_DATA_CONTRACT_V2.md`、`docs/design/STORY_MODE.md`、`schemas/v2/story_arc.schema.json`、`sdk/templates/story_pack_iron_tide/`（完整示例包）、`SNModMaker/js/validate.js`。
