# 剧情模式数据契约 V1（Story Mode Data Contract v1）

> **已被 V2 取代（2026-10-27）**：V2 契约见 [STORY_MODE_DATA_CONTRACT_V2.md](STORY_MODE_DATA_CONTRACT_V2.md)。
> V1 未发布任何内容，因此没有迁移负担；本文件仅保留为历史记录。当前冻结门禁以 V2 为准。

> 作用：冻结剧情模式（Story Mode）的 `story_arcs` / `story_levels` 数据结构与全部语义约束，
> 作为后续加载链（S2）、运行时（S4）、UI（S5）与模组编辑器剧情关卡编辑的唯一数据契约。
> 状态：**Frozen v1（2026-10-27）**。本文件定稿后，Schema 与约束只能按 §7 的版本流程变更。
> 运行时状态：`story_arcs` / `story_levels` 仍是 Content Schema 2.0 **草案类型**，Godot 运行时
> 暂不加载（S2 才开始加载）；本契约先冻结数据面，不改变运行时行为。
> 上位设计：[STORY_MODE.md](../design/STORY_MODE.md)；编辑器现状：[SNModMaker](../../SNModMaker/README.md)。

## 1. 范围与包结构

剧情包 = **一个只加剧情的普通内容模组**（`.snavmod.zip` 或同结构松散目录）：

```text
mods/<pack_id>/
  manifest.json                 # capabilities 必须含 "content.story.v1"
  content/story_arcs.json       # 恰好 1 个 story_arc
  content/story_levels.json     # 1..32 个 story_level，由 arc.levels[] 排序
  localization/<locale>.json    # 可选，剧情文本
  assets/**                     # 可选，演出资源
```

### 1.1 包级规则（v1）

| 规则 | 严重度 | 约束码 |
| --- | --- | --- |
| 内容文件只能出现 `story_arcs` / `story_levels`（+ 允许的 localization / assets） | error | `story_pack_off_whitelist` |
| 出现剧情内容时 `manifest.capabilities` 必须含 `content.story.v1` | error | `story_pack_capability_required` |
| 声明了 `content.story.v1` 但没有任何剧情内容 | warning | `story_pack_empty` |
| 一个包恰好 1 个 `story_arc` | error | `story_pack_multiple_arcs` |
| 有 `story_level` 但没有 `story_arc` | error | `story_pack_arc_missing` |
| `arc.levels[]` 只能引用 `story_level` | error | `story_arc_level_type` |
| `arc.levels[]` 只能引用**本包**（同 `<pack_id>`）的关卡 | error | `story_arc_level_foreign` |
| 未被任何 arc 引用的关卡（写作中途允许） | warning | `story_level_orphan` |
| 允许依赖 `core` 并引用 Core 定义；禁止 `patches` 与任何自由模式内容 | error | 见上 |

> v1 固定「1 包 = 1 篇章」。多篇章、多包合并等扩展需要新契约版本。

## 2. Schema 文件与共享定义

| 文件 | 状态 |
| --- | --- |
| `schemas/v2/story_arc.schema.json` | Frozen v1 |
| `schemas/v2/story_level.schema.json` | Frozen v1 |
| `schemas/v2/common.schema.json#/$defs/story_presentation` / `story_stage` / `story_condition` / `story_match` | Frozen v1（与教程 `map_configs` 共享；其它 `$defs` 不受本契约约束） |
| `content_types.json` → `draft_schemas` + `draft_types` + `planned` | 草案登记（运行时未加载）；S2 再提升 active |

所有内容文件写 `schema_version: "2.0"`；`content_type` 只允许 `story_arcs` / `story_levels`。
ID 形如 `<pack_id>:story_arc/<local_id>`、`<pack_id>:story_level/<local_id>`。

## 3. `story_arc` 字段约束

| 字段 | 约束 |
| --- | --- |
| `protagonist_id` | 必填；必须出现在 `characters[].id`；建议对应角色 `role = protagonist`（否则 warning `story_protagonist_role`） |
| `characters[]` | 1..64；`id` 本地 ID（`^[a-z][a-z0-9_]{0,31}$`）且唯一（`story_character_duplicate`） |
| `characters[].name_key` / `description_key` | 1..160 字符；本地化键 |
| `characters[].role` | `protagonist` / `supporting` / `antagonist` / `other`；全篇 `protagonist` 超过 1 个只 warning（`story_multiple_protagonists`） |
| `terms[]` | 0..64；`id` 唯一（`story_term_duplicate` warning） |
| `levels[]` | 0..32，unique，按**数组顺序**解锁；写作期可为空（warning `story_arc_empty_levels`），可玩的包至少 1 关 |
| `canon` / `completion_achievement` / `source` | 可选；`completion_achievement` 匹配 `^[a-z][a-z0-9_.]{1,63}$` |

## 4. `story_level` 字段约束

### 4.1 固定地图 `data.map.fixed`

| 字段 | 约束 |
| --- | --- |
| `ports[]` | 2..32；`id` 形如 `port_0`..`port_99` 且唯一；`position` 为 `[x, y]`，坐标 0..4096；> `name_key` 1..160 |
| `ports[].facilities[]` | ≤16，unique；规范键 `exchange` / `contracts` / `supply` / `shipyard` / `tavern`；旧键 `intel` 已归一为 `tavern`（出现 warning `story_facility_unknown`）；重复 error `story_facility_duplicate` |
| `ports[].market[]` | ≤64；每项 `{item, stock, price}`；`item` 必须是完整 `id_ref`（如 `core:item/coal`），同一港口同一 item 只能出现一次（`story_market_duplicate_item`） |
| `edges[]` | 1..128；`from` / `to` 必须是已声明港口（`story_fixed_edge_port_unknown`）；禁止自环（`story_fixed_edge_self`）；无向重复边报错（`story_fixed_edge_duplicate`）；`distance ≥ 1`，`risk ∈ [0,1]` |
| `start_port` | 可选；若写必须是已声明港口（`story_fixed_start_port_unknown`） |
| `map.fog` | `revealed` / `explored` / `unknown` |
| `map.map_config` | 可选，仅复用 Core `map_configs` 的经济/探索参数；地形仍以 `fixed` 为准 |

起点解析顺序：`start.port_id` → `map.fixed.start_port` → `ports[0]`。两者都写时必须一致
（`story_start_port_conflict`）；都不写 warning `story_level_start_port_missing`。
从起点走不到的港口只 warning（`story_fixed_map_disconnected`），不阻塞写作。

### 4.2 初始状态 `data.start`

| 字段 | 约束 |
| --- | --- |
| `starting_scenario` | 可选，`id_ref`，通常引用 `core:starting_scenario/*` |
| `port_id` | 可选；必须属于固定地图（`story_start_port_unknown`） |
| `money` / `ship_fuel` / `ship_water` | ≥ 0；每关独立，不继承自由模式 |
| `cargo[]` | ≤64，每项 `{item, amount}`，`item` 为 `id_ref`、`amount` 正整数 |
| `equipped_modules[]` | ≤64，unique，`id_ref` |
| `world_time` | 可选，`^[a-z][a-z0-9_]{0,63}$`（示例 `day_1_0600`） |

### 4.3 系统开关 `data.systems`

`unlock_features[]`（≤32，`^[a-z][a-z0-9_]{0,63}$`）、`unlock_items[]` / `unlock_modules[]`（≤64，unique，`id_ref`）、
`lock_actions[]`（≤64，`^[a-z][a-z0-9_.]{0,63}$`）。未知 feature / command 键只由运行时忽略或报诊断，
不进入 v1 Schema 枚举（允许框架后续扩展）。

### 4.4 任务线 `data.stages`

沿用 `common.schema.json#/$defs/story_stage`：

| 字段 | 约束 |
| --- | --- |
| `stages[]` | 1..64；`id` 匹配 `^[a-z][a-z0-9_]{0,63}$` 且唯一（`story_stage_duplicate`） |
| `checkpoint` | 至少一个阶段 `checkpoint = true`（`story_level_checkpoint_missing`） |
| `advance` | 至少 1 个触发字段（`minProperties: 1`）；`all[]` 1..32；`at_least ≥ 1` |
| `dialogue` | `title_key` 1..160；`body_keys` 1..32 项，每项 1..160 |
| `objective` | `text_key` 1..160；`target` 1..1,000,000 |
| `effects[]` | ≤64；`type` 1..64；效果参数由框架 operation 白名单解释（不在本 Schema 重复定义） |
| `unlock_*` / `lock_actions` / `preferred_strategy` / `focus` | 同上界；`focus.target` / `text_key` 1..160 |

`story_condition` 至少 1 个字段；`story_match` 至少 1 个键，值 1..160 字符。

### 4.5 叙事 `data.narrative`

| 字段 | 约束 |
| --- | --- |
| `brief` | 必填；`title_key` 1..160；`body_keys` 1..32 项；`speaker_key` 1..160；`presentation` 见枚举 |
| `beats[]` | ≤64；`id` 匹配 `^[a-z][a-z0-9_]{0,63}$` 且唯一（`story_beat_duplicate`）；`stage_id` 必须属于本关阶段（`story_beat_stage_unknown`） |
| `debrief` | 必填；`success_keys` 1..16；`failure_keys` 0..16；`hook_key` 1..160 |

`presentation` 枚举：`card` / `briefing` / `debrief` / `toast` / `choice` / `radio` / `camera_hint`。

### 4.6 难度、奖励与失败 `data.difficulty` / `data.rewards` / `data.fail`

| 字段 | 约束 |
| --- | --- |
| `difficulty.profile` | `story.intro` / `story.standard` / `story.hard` |
| `difficulty.knobs` | 各 scale 0..100；`hint_level` = `full` / `light` / `none` |
| `rewards` | 只允许 `achievements` / `codex_entries` / `cosmetics`（各 ≤64，unique，匹配 `^[a-z][a-z0-9_.]{1,63}$`）；**不允许金钱 / 货物 / 模块 / 解锁自由模式内容** |
| `fail.default_mode` | `checkpoint` / `level_start`，且必须出现在 `fail.allow` 中（`story_fail_default_not_allowed`） |
| `fail.allow` | 1..2，unique |

## 5. 引用与本地化约束

1. 所有 `id_ref` 字段必须可解析：本包内引用必须在同包注册表中存在（generic `ref_missing`）；
   剧情包引用 `core` 定义时，**在编辑器/CLI 有 Core 索引的情况下按 error 处理**（generic `ref_core_unknown`）。
2. `ref_type` 只做 warning：字段期望类型与引用类型不符时提示（例如用 `story_arc` 充当 `item`）。
3. `cargo[].item`、`market[].item` 解析到 `items`；`equipped_modules` 解析到 `modules`；
   `starting_scenario` 解析到 `starting_scenarios`；`unlock_items` / `unlock_modules` 同理。
4. 所有 `*_key`（定义级 `name_key` / `description_key`、叙事键、目标键、聚焦键、speaker 键）
   必须在包本地化文件中存在（generic `localization_missing` warning；发布前应清零）。
5. 剧情包只能引用已注册内容，不得新增商品 / 船体 / 模块 / 港口 / 委托等自由模式内容（§1.1）。

## 6. 语义约束码表（Node / SNModMaker）

| 约束码 | 严重度 | 含义 |
| --- | --- | --- |
| `schema_*` | error | JSON Schema 失败（由项目 Schema 子集校验器给出） |
| `story_pack_off_whitelist` | error | 剧情包出现非剧情内容类型 |
| `story_pack_capability_required` | error | 有剧情内容但 manifest 未声明 `content.story.v1` |
| `story_pack_empty` | warning | 声明了剧情能力但没有剧情内容 |
| `story_pack_multiple_arcs` | error | v1 超过 1 个篇章 |
| `story_pack_arc_missing` | error | 有关卡但没有篇章 |
| `story_arc_level_type` | error | `arc.levels[]` 不是 `story_level` |
| `story_arc_level_foreign` | error | `arc.levels[]` 引用了别的包 |
| `story_arc_empty_levels` | warning | 篇章还没有关卡（写作期允许） |
| `story_level_orphan` | warning | 关卡未被篇章引用 |
| `story_character_duplicate` | error | 角色本地 ID 重复 |
| `story_protagonist_unknown` | error | `protagonist_id` 不在角色表 |
| `story_protagonist_role` | warning | `protagonist_id` 的角色不是 `protagonist` |
| `story_multiple_protagonists` | warning | 多个 `role = protagonist` |
| `story_term_duplicate` | warning | 术语本地 ID 重复 |
| `story_stage_duplicate` | error | 阶段本地 ID 重复 |
| `story_level_checkpoint_missing` | error | 没有任何 checkpoint 阶段 |
| `story_beat_duplicate` | error | 叙事节拍 ID 重复 |
| `story_beat_stage_unknown` | error | 节拍引用了不存在的阶段 |
| `story_fail_default_not_allowed` | error | `default_mode` 不在 `allow` 中 |
| `story_fixed_port_duplicate` | error | 固定地图港口 ID 重复 |
| `story_fixed_start_port_unknown` | error | `map.fixed.start_port` 不存在 |
| `story_start_port_unknown` | error | `start.port_id` 不存在 |
| `story_start_port_conflict` | error | 两个起点字段不一致 |
| `story_level_start_port_missing` | warning | 两个起点字段都没写（回退第一个港口） |
| `story_fixed_edge_port_unknown` | error | 航道端点不存在 |
| `story_fixed_edge_self` | error | 航道自环 |
| `story_fixed_edge_duplicate` | error | 无向重复航道 |
| `story_fixed_map_disconnected` | warning | 从起点不可达某些港口 |
| `story_facility_duplicate` | error | 同一港口设施重复 |
| `story_facility_unknown` | warning | 设施键不在规范集合（如旧 `intel`） |
| `story_market_duplicate_item` | error | 同一港口市场重复商品 |
| `ref_missing` / `ref_core_unknown` / `ref_type` / `localization_missing` | error/error/warning/warning | 通用引用与本地化检查（见 §5） |
| `draft_content` | warning | 类型尚未 active，运行时暂不加载（S2 提升 active 后消失） |

## 7. 冻结规则与变更流程

- **契约版本**：`STORY_MODE_DATA_CONTRACT_V1`，`contract_version = 1`，冻结日期 2026-10-27。
  两个 Schema 文件与 `common` 的四个 story `$defs` 由
  [`tools/check_story_schema_freeze.mjs`](../../tools/check_story_schema_freeze.mjs) 按规范化 JSON 的
  SHA-256 锁定到 `schemas/v2/story_schema_freeze.json`。
- **允许的变更**：
  - 文档 / 注释 / 示例 / 本地化文本：随时；
  - 新增**向后兼容**的枚举值或**放宽**限制：需要同步契约说明与锁文件，仍算 v1 修订；
  - 结构变更、必填变更、收紧已有内容、字段改名/删除：必须升 `contract_version = 2`，
    新文件 `STORY_MODE_DATA_CONTRACT_V2.md`，并让旧 Schema 进入归档路径（不允许静默改 v1）。
- **操作**：任何 Schema/约束变更后先跑 `node tools/check_story_schema_freeze.mjs --check`；
  确认是计划内变更后运行 `--update` 重新冻结，并在本文件记录变更。
- **与运行时的关系**：把 `story_arcs` / `story_levels` 从 draft 提升为 active（S2）属于实现动作，
  不改数据契约版本；`draft_content` warning 会随之消失。

## 8. 验收与门禁

- `node SNModMaker/tools/content.mjs validate --mod sdk/templates/story_pack_iron_tide`：**0 error**，
  只保留 2 条 `draft_content` warning（S2 后消失）。
- `node SNModMaker/tests/run-tests.js`：剧情 Schema / 语义 / 白名单用例全绿。
- `node --test SNModMaker/tests/content-cli.test.mjs`：剧情包校验与 `--draft` 流程全绿。
- `node tools/check_story_schema_freeze.mjs --check`：通过。
- Godot `test_schema_v2_drafts.gd` / `test_content_types_manifest.gd`：草案 Schema 与类型登记不变。
- 示例包 `sdk/templates/story_pack_iron_tide/` 是唯一参考实现（1 篇章 + 2 关卡 + 中英文本）。
