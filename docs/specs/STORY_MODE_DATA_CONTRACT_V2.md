# 剧情模式数据契约 V2（Story Mode Data Contract v2）

> 作用：定义**完全数据驱动**的剧情关卡格式：固定地图（手写陆地 + 航道）、初始状态、
> 2D 叙事（文本 / 说话人 / 立绘 / 背景 / 音频 / 选项）、任务（复用 quest 状态机）、
> 可见系统限制（可用 / 可见但锁定 / 隐藏三态 + 阶段覆盖）与关卡流程。
> 状态：**V2 契约草案（2026-10-27）**，目标是在写运行时之前冻结；V1 由本文件取代。
> 运行时状态：`story_arcs` / `story_levels` 仍是 Content Schema 2.0 草案类型，Godot 运行时不加载。
> 上位设计：[STORY_MODE.md](../design/STORY_MODE.md)；V1 历史：[STORY_MODE_DATA_CONTRACT_V1.md](STORY_MODE_DATA_CONTRACT_V1.md)。

## 0. 决策与边界

| id | 决策 | 结论 |
| --- | --- | --- |
| D23 | 固定地图 | **手写陆地（多边形）+ 手写航道（路径点）**；不靠程序生成，剧情模式服务于教学与世界观 |
| D24 | 剧情表现 | **2D 叙事**：文本 / 说话人 / 立绘 / 背景 / 音频 / 选项；**不做 3D 镜头编排** |
| D25 | 任务 | 关卡内嵌 `tasks[]`，**复用 quest 状态机与任务追踪 UI**；不注册全局 `quests` 内容、不影响自由模式 |
| D26 | 可见系统限制 | 页面 / 动作三态：`available` / `locked`（可见但禁用 + 原因键）/ `hidden`；阶段可覆盖与重锁 |
| D27 | 效果与条件 | 效果是**框架拥有的 opcode 白名单**，内容只写类型与参数；条件沿用现有 story/quest DSL |
| D28 | 关卡线性 | 首版阶段线性推进；选项只做选择/效果，不做分支跳关（分支叙事后置） |
| D29 | 不做 | 3D 分镜/自由镜头、任意脚本（Lua/JS）、内容自定义 UI、剧情包新增自由模式内容 |

**完全数据驱动的含义**：新增一关 = 写一份 `story_levels` + 可选资源 + 本地化，不改代码；
*新增机制*（新 opcode / 新页面 / 新条件）仍需改框架并升契约版本。

## 1. 包结构与类型

```text
mods/<pack_id>/
  manifest.json                 # capabilities: ["content.story.v1"]；assets 可声明立绘/背景/音频
  content/story_arcs.json       # 恰好 1 个 story_arc
  content/story_levels.json     # 1..32 个 story_level，由 arc.levels[] 排序
  localization/<locale>.json
  assets/...
```

- 包级白名单不变：只允许 `story_arcs` / `story_levels` + localization / assets。
- 一个包恰好 1 个篇章（v2 仍不做多篇章）。
- 关卡 ID / 篇章 ID 仍为 `<pack_id>:story_arc/<local>`、`<pack_id>:story_level/<local>`。
- `schema_version: "2.0"`、`content_type` 不变；V2 是**契约版本**，不是 Content Schema 版本。

## 2. `story_arc`（篇章）

```json
{
  "id": "core_story:story_arc/iron_tide",
  "name_key": "story.iron_tide.name",
  "enabled": true,
  "data": {
    "protagonist_id": "captain",
    "characters": [
      {"id": "captain", "name_key": "story.cast.captain", "role": "protagonist",
       "portrait_asset": "portrait.captain"}
    ],
    "terms": [],
    "levels": ["core_story:story_level/01_first_smoke"],
    "canon": true,
    "completion_achievement": "iron_tide.complete"
  }
}
```

| 字段 | 约束 |
| --- | --- |
| `protagonist_id` | 必须在 `characters[].id` 中 |
| `characters[]` | 1..64；`id` 本地 ID 且唯一；`role` = protagonist / supporting / antagonist / other |
| `characters[].portrait_asset` | 可选；manifest assets 键；png / webp；用于叙事默认立绘 |
| `terms[]` | 0..64；`id` 唯一 |
| `levels[]` | 0..32，unique，只引用本包 `story_level`，数组顺序即解锁顺序 |

## 3. 固定地图（手写陆地 + 航道）

```json
"map": {
  "fog": "revealed",
  "revealed_ports": ["port_0", "port_1"],
  "fixed": {
    "landmasses": [
      {"id": "ash_harbor", "kind": "island", "name_key": "story.land.ash_harbor",
       "polygon": [[20, 40], [70, 30], [90, 75], [45, 95], [15, 70]]}
    ],
    "ports": [
      {"id": "port_0", "name_key": "story.port.ash_harbor", "archetype": "core:port_template/small",
       "position": [40, 130], "facilities": ["exchange", "supply"],
       "market": [{"item": "core:item/coal", "stock": 30, "price": 4}]}
    ],
    "edges": [
      {"from": "port_0", "to": "port_1", "risk": 0.05,
       "path": [[40, 130], [100, 140], [160, 130]]}
    ],
    "start_port": "port_0"
  }
}
```

### 3.1 `landmasses[]`（1..32）

| 字段 | 约束 |
| --- | --- |
| `id` | 本地 ID（`^[a-z][a-z0-9_]{0,31}$`）且唯一 |
| `kind` | 可选：`island` / `continent` / `reef`（默认 `island`）；只影响运行时表现，不影响碰撞 |
| `name_key` | 可选，1..160 |
| `polygon` | 3..256 个点；每点 `[x, y]`，坐标 0..4096；多边形自动闭合，不要求首尾重复 |

### 3.2 `ports[]`（2..32）

| 字段 | 约束 |
| --- | --- |
| `id` | `port_0`..`port_99`，唯一 |
| `name_key` | 1..160 |
| `archetype` | 可选，引用 `core:port_template/*`（只取规模/视觉/默认设施等静态表现） |
| `position` | `[x, y]`，0..4096；**不得落在任何陆地多边形内** |
| `facilities[]` | ≤16，unique；规范键 `exchange` / `contracts` / `supply` / `shipyard` / `tavern` |
| `market[]` | ≤64；`{item, stock, price}`；`item` 为完整 `id_ref`；同港同商品唯一 |

### 3.3 `edges[]`（1..128）

| 字段 | 约束 |
| --- | --- |
| `from` / `to` | 必须是已声明港口；禁止自环 |
| `path` | 2..512 个点，坐标 0..4096；**首点必须等于（容差 0.5）`from` 港口位置，末点必须等于 `to` 港口位置** |
| `risk` | 0..1 |
| `bidirectional` | 可选，默认 `true` |

- **不写 `distance`**：运行时按 `path` 折线长度计算，保证「海图弧长 = 航行里程」不变量。
- 航道不得穿越陆地（除端点外）；校验给 warning `story_route_crosses_land`，不阻塞创作
  （运河 / 河口等刻意设计可保留）。
- 无向重复边、自环、端点未知均为 error；从起点不可达的港口为 warning。

### 3.4 迷雾与起点

| 字段 | 约束 |
| --- | --- |
| `fog` | `revealed` / `explored` / `unknown` |
| `revealed_ports` | 可选；港口 id 列表；省略时默认 **全部港口已揭示**（剧情地图通常已知） |
| `fixed.start_port` | 必填，已声明港口 |
| `map_config` | 可选，引用 Core `map_configs` 只复用经济/探索参数 |

## 4. 初始状态 `start`

| 字段 | 约束 |
| --- | --- |
| `starting_scenario` | **必填**，引用 `core:starting_scenario/*`（船、构筑、初始模块） |
| `port_id` | 可选；必须等于/属于固定地图港口；省略时用 `start_port` |
| `money` / `ship_fuel` / `ship_water` | 可选，≥0；覆盖 starting_scenario 的初始值 |
| `cargo[]` | ≤64；`{item, amount}` |
| `equipped_modules[]` | ≤64，unique，`id_ref` |
| `world_time` | 可选，`^[a-z][a-z0-9_]{0,63}$`（示例 `day_1_0600`） |
| `route_access` | `all`（默认）/ `none` / `listed` |
| `unlocked_routes[]` | `route_access=listed` 时必填：`[[from_port, to_port], ...]`，两端与对应航道必须存在 |

## 5. 可见系统限制 `access`

顶层 `access` 在关卡开始时应用；阶段可带同结构的 `access` 覆盖（进入阶段时应用，持续到下一次覆盖）。

```json
"access": {
  "pages": [
    {"key": "market", "state": "locked", "reason_key": "ui.lock.need_supply_first"},
    {"key": "shipyard", "state": "hidden"}
  ],
  "actions": [
    {"key": "loan", "state": "locked", "reason_key": "ui.lock.early_game"}
  ],
  "market": {"mode": "allow", "items": ["core:item/coal", "core:item/water"]},
  "modules": {"mode": "all", "modules": []}
}
```

| 字段 | 约束 |
| --- | --- |
| `pages[].key` | 枚举：`overview` / `market` / `contracts` / `shipyard` / `tavern` / `chart` / `base` / `trade` / `ruins` |
| `pages[].state` | `available` / `locked` / `hidden` |
| `actions[].key` | 命令前缀（`^[a-z][a-z0-9_.]{0,95}$`，如 `trade.buy` / `loan` / `ship.install_module`）；前缀匹配命令名 |
| `actions[].state` | `available` / `locked`（动作没有 hidden） |
| `reason_key` | `locked` 时必填；本地化键 |
| `market.mode` | `all` / `allow`；`allow` 时 `items[]` 1..64 |
| `modules.mode` | `all` / `allow`；`allow` 时 `modules[]` 1..64 |
| 冲突 | 同层同 key 重复 → error；阶段覆盖只列变化的 entry |

- `locked` = 入口**可见但禁用**，鼠标/触摸提示 `reason_key`；`hidden` = 不渲染入口。
- `market` / `modules` 是关卡级白名单，阶段覆盖可整体替换。
- 页面键由框架映射到真实页面与设施招牌；内容不写控件路径。
- 动作锁只影响 Shell 的命令入口与快捷键，不改变领域规则。

## 6. 阶段与教程/引导 `stages`

阶段沿用 `story_stage` DSL（与教程共享），V2 增加 2D 叙事、选项、多目标引导与 access 覆盖。

```json
{
  "id": "supply_brief",
  "checkpoint": true,
  "presentation": "briefing",
  "background_asset": "bg.market",
  "audio_asset": "audio.market_ambience",
  "lines": [
    {"speaker_id": "harbor_master", "text_key": "story.l01.supply.0"},
    {"speaker_id": "captain", "text_key": "story.l01.supply.1",
     "portrait_asset": "portrait.captain_angry"}
  ],
  "choices": [
    {"id": "promise", "text_key": "story.l01.choice.promise", "effects": [{"type": "set_flag", "flag": "promised"}]},
    {"id": "refuse", "text_key": "story.l01.choice.refuse", "effects": [{"type": "set_flag", "flag": "refused"}]}
  ],
  "objective": {"text_key": "story.l01.supply.objective", "target": 4},
  "focus": {
    "targets": ["market_supply"],
    "text_key": "story.l01.focus.supply",
    "blocking": true
  },
  "access": {
    "pages": [{"key": "chart", "state": "hidden"}],
    "actions": [{"key": "supply.buy", "state": "available"}]
  },
  "advance": {
    "all": [
      {"event": "cmd:supply.buy_coal", "counter": "coal_bought", "at_least": 4},
      {"event": "cmd:supply.buy_water", "counter": "water_bought", "at_least": 2}
    ]
  }
}
```

| 字段 | 约束 |
| --- | --- |
| `id` | 本地 ID，唯一 |
| `checkpoint` | 至少 1 个阶段为 `true`（失败回档点） |
| `presentation` | `card` / `briefing` / `choice` / `debrief` / `toast` / `radio`；**`camera_hint` 在剧情关卡报 error**（无 3D 镜头） |
| `lines[]` | 0..64；每行 `{speaker_id?, text_key, portrait_asset?, background_asset?, audio_asset?}`；`speaker_id` 必须属于本篇角色表 |
| `dialogue` | 兼容字段（教程用）；与 `lines` 同阶段二选一（两者都给 → error） |
| `choices[]` | 0..8；`{id, text_key, condition?, effects?}`；id 同阶段唯一；选项只应用效果，不跳关 |
| `objective` | `{text_key, target}`，单目标；复杂任务用 `tasks[]` |
| `focus` | `target`（教程）或 `targets[]`（1..4，剧情），二选一；`text_key`；`blocking`（默认 true） |
| `access` | 阶段覆盖，见 §5；进入阶段时应用 |
| `effects[]` | 见 §7；在进入阶段时执行 |
| `advance` | 必填；`mode=confirm` / `event` / `counter` / `counter_from` / `at_least` / `flag` / `not_flag` / `all` / `match` |
| `preferred_strategy` | 可选；出航默认策略 |
| `background_asset` / `audio_asset` | 可选；阶段默认背景 / 音频；行内可覆盖 |

- 阶段按数组顺序推进；**最后一个阶段完成 = 关卡完成**。
- `focus.blocking=true` 时引导遮罩拦截遮罩外输入；`targets[]` 支持多目标（如海图选港 + 确认按钮）。
- 叙事播放顺序：进入阶段 → 应用 `access` / `effects` → 显示 `lines` → 显示 `choices`（若玩家有选择未定则等待）→ 等待 `advance` → 下一阶段。
- 选项效果立即生效；选项本身不推进阶段，推进仍由 `advance` 决定。

## 7. 效果 opcode（框架白名单）

`effects[].type` 必须是下列之一；参数由框架校验与解释，内容不得执行代码：

| type | 参数（框架解释） |
| --- | --- |
| `unlock_features` | `features[]` |
| `set_flag` / `clear_flag` | `flag`, `value?` |
| `set_counter` | `counter`, `value` |
| `add_money` / `remove_money` | `amount` |
| `add_item` / `remove_item` | `item_id`, `amount` |
| `add_fuel` / `add_water` | `amount` |
| `damage_ship` / `repair_ship` | `amount` |
| `set_world_time` | `world_time` |
| `set_ship_fuel` | `amount`（教程兼容） |
| `unlock_route` | `from`, `to`（支持 `current` / `home` 语义 token） |
| `add_facility` | `facility`（当前港） |
| `upgrade_hull` | `hull_id`（Core 船体） |
| `discover_contract_destination` | —（教程兼容） |
| `grant_tutorial_contract` | 教程专用参数（兼容） |
| `grant_clue` / `set_market_price_bias` / `guarantee_explore_success` | 教程兼容 |
| `set_counter_from_ship` | `counter`, `kind`（教程兼容） |
| `complete_story` | —（提前完成本关） |
| `start_task` / `complete_task` / `fail_task` | `task_id` |
| `set_access` | 与 §5 `access` 同结构（触发器用） |

- 未知名 / 缺参数 / 参数类型错：编辑器与 CLI **error**（不再 warning 忽略）。
- 教程已有的 opcode 保留；新剧情内容优先使用通用 opcode。
- 参数上限与枚举在实现时固化进校验表（Node + 运行时共用同一份规格）。

## 8. 任务 `tasks[]`（复用 quest 状态机）

```json
"tasks": [
  {
    "id": "deliver_medicine",
    "name_key": "story.l01.task.med.name",
    "kind": "guide",
    "auto_start": false,
    "tracking": {"label_key": "story.l01.task.group", "priority": 50},
    "stages": [
      {"id": "buy", "title_key": "story.l01.task.med.buy",
       "objectives": [{"event": "cmd:trade.buy", "counter": "med_bought", "at_least": 2,
                        "match": {"item_id": "core:item/medicine"}}]},
      {"id": "deliver", "title_key": "story.l01.task.med.deliver",
       "objectives": [{"event": "ui:arrival_settled", "at_least": 1}]}
    ],
    "rewards": {"money": 40, "items": [], "flags": ["med_delivered"]},
    "deadline_hours": 72
  }
]
```

| 字段 | 约束 |
| --- | --- |
| `id` | 关卡内唯一；供 `start_task` / `complete_task` / `fail_task` 引用 |
| `name_key` / `description_key` | 1..160 |
| `kind` | `story` / `guide` / `system`（与 quest 相同） |
| `auto_start` | 可选；true 时关卡开始即接取 |
| `tracking` | `{label_key?, priority?, hidden?}`（同 quest） |
| `stages[]` | 1..16，线性；字段与 quest `quest_stage` 一致：`id` / `title_key` / `description_key?` / `objectives[]` |
| `objectives[]` | 1..8；`{event, counter?, at_least?, match?, text_key?}`，语义与 quest 目标一致 |
| `rewards` | 可选；**只在本关生效**：`{money?, items[]?, flags[]?}`；不写自由模式 |
| `deadline_hours` | 可选；>0；超时任务失败（运行时） |

- 运行时复用 `QuestService` 的状态机与任务追踪 UI；任务定义**内嵌**，不注册进全局 `quests` 注册表，
  不参与自由模式，不需要剧情包携带 `quests` 内容。
- 任务实例状态存 `data.story_mode.tasks`；`task.view` 增加剧情任务来源（实现 S4/S5）。
- 任务的 `event` 命名与现有 DSL 一致（`cmd:*` / `ui:*`）；`match` 匹配命令/事件 payload。

## 9. 触发器 `triggers[]`

```json
"triggers": [
  {"id": "storm_warning", "once": true,
   "when": {"event": "cmd:voyage.start", "flag": "storm_seen", "not_flag": true},
   "effects": [{"type": "set_flag", "flag": "storm_seen"}]}
]
```

| 字段 | 约束 |
| --- | --- |
| `id` | 关卡内唯一 |
| `once` | 可选，默认 true |
| `when` | story_condition；至少 1 个条件字段 |
| `effects[]` | 1..16；见 §7；命中时执行 |

- 触发器不直接播放叙事；叙事仍由阶段承载。触发器用于脚本化状态变化（标记、任务、系统限制、资源）。
- 评估时机与 `story.observe` 相同（成功命令 / UI 事件 / tick 事件）。

## 10. 难度、奖励与失败

| 字段 | 约束 |
| --- | --- |
| `difficulty.profile` | `story.intro` / `story.standard` / `story.hard` |
| `difficulty.knobs` | 各 scale 0..100；`hint_level` = full / light / none |
| `rewards` | 只允许 `achievements` / `codex_entries` / `cosmetics`（各 ≤64，unique）；不影响自由模式 |
| `fail.default_mode` | `checkpoint` / `level_start`，必须出现在 `fail.allow` |
| `fail.failure_title_key` | 可选，1..160 |
| `fail.failure_keys[]` | 0..16；失败结算文案 |

## 11. 语义约束码表（新增/变更）

| 约束码 | 严重度 | 含义 |
| --- | --- | --- |
| `story_landmass_duplicate` | error | 陆地 ID 重复 |
| `story_port_on_land` | error | 港口落在陆地多边形内 |
| `story_route_endpoint_mismatch` | error | 航道首/末点与港口位置偏差 > 0.5 |
| `story_route_crosses_land` | warning | 航道穿越陆地（刻意设计可保留） |
| `story_unlocked_route_unknown` | error | `start.unlocked_routes` 的港口/航道不存在 |
| `story_route_access_invalid` | error | `route_access=listed` 但路线列表为空/缺失 |
| `story_access_duplicate_key` | error | 同层 access key 重复 |
| `story_access_reason_missing` | error | `locked` 没有 `reason_key` |
| `story_stage_lines_dialogue_conflict` | error | 同阶段同时有 `lines` 与 `dialogue` |
| `story_stage_choice_duplicate` | error | 同阶段选项 id 重复 |
| `story_speaker_unknown` | error | `speaker_id` 不在篇章角色表 |
| `story_presentation_unsupported` | error | 剧情关卡使用 `camera_hint` |
| `story_focus_target_conflict` | error | `focus.target` 与 `focus.targets` 同时存在 |
| `story_focus_targets_empty` | error | `targets` 为空 |
| `story_asset_missing` | error | 立绘/背景/音频引用不在 manifest assets |
| `story_asset_type` | error | 资源扩展名与用途不符（png/webp vs ogg/wav） |
| `story_effect_unknown` | error | 效果 type 不在白名单 |
| `story_effect_params` | error | 效果参数缺失/类型错误 |
| `story_task_duplicate` | error | 任务 ID 重复 |
| `story_task_stage_duplicate` | error | 任务阶段 ID 重复 |
| `story_task_reward_unknown` | error | 任务奖励引用不存在的内容 |
| `story_trigger_duplicate` | error | 触发器 ID 重复 |
| `story_trigger_condition_empty` | error | 触发器条件为空 |
| 旧码（`story_fixed_*` / `story_market_*` / `story_pack_*` / `story_arc_*` / `story_beat_*`） | — | 继续保留；`story_beat_*` 随 `narrative.beats` 移除而退役，`story_stage_*` 沿用 |

## 12. 运行时契约（实现时遵循，不在本次改动范围）

1. **StoryDirector** 泛化 `StoryService`：阶段/条件/效果/引导/系统限制；教程与剧情双来源。
2. **StoryWorldFactory** 从 `map` 构建 `WorldMap`：landmasses 多边形、ports、edges（path 直接使用，distance 由折线长度派生）、bounds 由陆地 + 港口自动外扩、fog / revealed_ports、route_access。
3. **初始状态**：复用 `CampaignFactory` / `RunFactory` 的 starting_scenario 装配，覆盖等级/资源/模块/货物；不做世界生成。
4. **access 状态机**：顶层 + 阶段覆盖；查询输出 `pages/actions/market/modules` 给 Shell；`locked` 渲染为禁用 + reason，`hidden` 不渲染。
5. **叙事 UI**：lines 逐行播放（说话人/立绘/背景/音频），choices 选择、effects、advance 门禁；无 3D 镜头。
6. **任务**：内嵌定义实例化为 QuestService 兼容实例；`task.view` / HUD / 任务日志复用现有 UI；状态存 `data.story_mode.tasks`。
7. **触发器**：在 StoryService.observe 同一事件流上求值；`once` 去重。
8. **存档**：`data.story_mode` 记录 `pack_id/version/arc_id/level_id/stage_index/checkpoint/flags/counters/tasks/access/completed`；不存定义本体；旧档无该块 = 自由模式。
9. **隔离**：剧情模式的任何数值/任务/奖励不写回自由模式；`data.campaign` 不参与。

## 13. 编辑器契约（复用 SNModMaker）

- 剧情页：篇章/角色（含立绘）、关卡列表；固定地图画布（陆地多边形、港口、航道路径点、市场、起点）；
  阶段流（lines / choices / focus / access / advance）；任务列表（stages/objectives/rewards）；触发器；难度/奖励/失败。
- 地图编辑器体量膨胀时抽成独立页面；与主编辑器共用同一项目模型、`validate.js` 与 `zip.js`。
- 校验码与 §11 一致；导出 `.snavmod.zip` 结构与手写包一致。

## 14. 版本与冻结

- `contract_version = 2`，替换 V1；V1 文件归档并在索引中标注被 V2 取代。
- `node tools/check_story_schema_freeze.mjs --check` 锁定：`story_arc.schema.json`、
  `story_level.schema.json`、common 的 story DSL（`story_presentation` / `story_stage` /
  `story_condition` / `story_match` / 新增的 `story_line` / `story_choice` / `story_access` /
  `story_effect`）。结构变更走本文 §14 版本流程（升 `contract_version`，不接受静默改 V2）。
- 冻结前的最后一步：示例包 + Node/Godot 测试 + `gen_static_docs --check` 全绿。

## 15. 验收（冻结 V2 时）

- [ ] `story_arcs` / `story_levels` V2 Schema 通过示例包与非法样本测试。
- [ ] 手写地图校验：港口/陆地/航道端点、穿陆、连通性；无 `distance` 字段。
- [ ] 叙事：lines / choices / speaker / 立绘/背景/音频资产引用 / focus targets / access 覆盖。
- [ ] 任务：内嵌 tasks 的 schema + 语义校验；奖励引用；期限。
- [ ] 触发器：条件 + 效果 + once。
- [ ] 白名单 / capability / 单篇章 / 引用 / 本地化约束保持。
- [ ] `node SNModMaker/tests/run-tests.js`、`node --test SNModMaker/tests/content-cli.test.mjs`、
      Godot `test_schema_v2_drafts.gd`、`check_story_schema_freeze --check`、`gen_static_docs --check` 全绿。
- [ ] 运行时代码**不改**（S2 起另行实现）。
