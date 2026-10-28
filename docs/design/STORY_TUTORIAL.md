# 新手剧情 / 教学系统（阶段 4.5）实现契约 — 全部 Implemented（2026-10-22）

> 作用：把「当前阶段每局开局默认触发的新手剧情」落成可运行的纵向切片：剧情状态机、
> 功能门禁、剧情卡 / 目标提示、脚本化委托与解锁、补给并市、酒馆、保底探索、船厂限制。
> 剧情文本 / 步骤 / 解锁 / 数值全部来自 Core JSON，框架只跑状态机与门禁，不写死
> 内容 ID。本文是实现契约；玩法细节未定项集中在 §11。

## 1. 范围

**4.5 交付**：新开局默认进入一条固定五幕剧情（起始港 → 第二港 → 回第一港 →
第三港线索与保底探索 → 第三港旅客主线），剧情接管现有主线前 3 段并在第三幕后
交还沙盒 / 现有主线剩余段；剧情期间按幕解锁 `补给 / 海图 / 市场 / 线索 / 酒馆 /
船厂` 等功能，未解锁功能在导航、快捷键、港口招牌、页面入口全部隐藏或拒绝。

**不做（本轮）**：语音 / 立绘 / 多分支对话（单线、可跳过、可回看日志）；Content
Schema 2.0 接入；新存档格式（`data.story` 惰性 ensure，不改 `schema_version`）；
事件化海洋（阶段 5）。

## 2. 已确认决策（2026-10-22，全部选推荐项 A）

1. **实现定位**：所有新开局默认触发剧情；剧情用脚本化委托 / 线索 / 解锁接管现有
   主线 `main_01..main_03`（仍用程序生成地图，按「起始港 → 邻港 → 另一邻港」映射；
   第三幕后交还沙盒 / 主线剩余段）。
2. **无船开局**：内部仍生成船实体；剧情首幕用「获得船」叙事 + 解锁，不引入空 ship
   状态（避免破坏航行预览 / 市场 / 存档 / 测试）。
3. **补给并市**：水煤永久进市场（市场「补给」区块，复用 `supply.buy_*` 命令），移除
   补给页与导航；市场商品按剧情阶段解锁（2 种 → 第 3 种 → 常规）。
4. **酒馆**：新「酒馆」页替换现有情报页（物价情报 + 港口线索购买合并），接管
   `intel.refresh` / `clue.buy`；设施标签由 `intel` 改为 `tavern`（Core 内容）。
5. **呈现 / 内容**：全屏剧情卡（标题 + 多段文本 + 继续 / 跳过整段教程 / 日志回看）
   + 非阻塞目标提示；步骤、文案、解锁、数值全部进 Core JSON
   （`map_configs.data.story` + Schema），框架只跑状态机与门禁。

## 3. 剧情流程（五幕）

> 触发事件由 Shell 在**成功命令后**转发为 `story.observe`；条件 / 数值见 §10。
> 每一幕的「解锁」是该幕进入时追加的 feature 集合。

### 触发时机契约（v0.2.0-dev.3 反馈 #1 修复）

剧情推进只认两类事件，且**一次玩家动作只上报一次**：

| 事件 | 语义 | Shell 上报点（唯一） |
|---|---|---|
| `cmd:<command>` | 成功命令 | `_run_command()` → `_observe_story("cmd:...")` |
| `ui:chart_opened` | 玩家**打开**海图 | `_on_nav("sea_chart")`（真正的打开动作） |
| `ui:chart_closed` | 玩家**关闭**海图 | `_on_sea_chart_closed()` |
| `ui:arrival_settled` | 航次**抵达结算** | `_finish_presentation()`（演出结束）/ `_full_stop_after_voyage()`（无演出旧路径） |

- `_screen_settlement()` / `_screen_sea_chart()` 等**页面挂载函数只渲染，不再 observe**：
  剧情卡继续、窗口 resize、状态刷新引起的页面重建不会重复推进阶段（旧实现里一次抵达
  会被上报至少 2 次，海图页每次重建都会重发 `ui:chart_opened`）。
- **出航 / 抵达拆成两个阶段**：`depart_brief` / `second_depart` 是「出航指示」，由
  `cmd:voyage.start` 收掉；紧随其后的 `first_arrival` / `second_arrival` 才吃
  `ui:arrival_settled`。这样「返航到港」的剧情只可能在抵达结算时出现，不可能在启航时
  触发（旧内容把两个语义塞进同一个阶段，是 dev.3 反馈 #1 的根因）。
- 离开结算页会清空 `_settlement_summary`；`DEPARTURE_VEIL` 归入演出分支（继续挂出发港
  3D 舞台），演出中途的重建不会掉回上一页重发事件。
- 回归测试：`test_story::test_departure_beat_and_arrival_beat_are_separate_stages`、
  `test_story_ui::test_first_voyage_advances_the_arrival_story_once_at_arrival`（真实
  `voyage.start → 逐帧演出 → _finish_presentation` + `story.observe` 计数）、
  `test_story_ui::test_chart_events_are_reported_once_per_player_action`。

### 幕 0 · 开局（4.5.2）

| 阶段 id | 玩家看到 / 可做 | 系统动作 | 推进条件 |
|---|---|---|---|
| `opening` | 无任何功能；剧情卡「无船 → 获船」、任务说明 | 生成船（内部）；解锁 `overview`；揭示主委托目的港 | 点「继续」 |
| `supply_intro` | 解锁 `supply`；目标「为船购买 4 煤 2 水」 | 补给页可用；引导目标条 | `cmd:supply.buy_coal` 累计 ≥ 4 且 `buy_water` ≥ 2 |
| `supply_hold` | 剧情卡「补给受限」；解锁 `chart`；目标「打开海图」 | 补给购买暂时禁用（story flag）；海图入口出现 | `ui:chart_opened` |
| `chart_brief` | 海图目标：目的港已标记；目标「关闭海图并继续补给」 | 剧情卡说明「快速航行」 | `ui:chart_closed` |
| `supply_finish` | 补给恢复；目标「煤舱补到 10 煤」（进度从当前 8/10 起算，显示还差 2） | 限时委托提示（standard 迟到、express 准时） | 煤舱 ≥ 10 |
| `depart_brief` | 解锁 `chart`；目标「打开海图 → 出航 → 选快速航行」 | 确认弹窗默认策略由 Shell 记忆；剧情提示 | `cmd:voyage.start` |
| `first_arrival` | 抵达第二港（过渡阶段，无卡片）；结算页出现 | 完成第一主线、解锁邻港 | `ui:arrival_settled` |

> **4.5.2 实装说明**：第一主线不再使用默认 `main_01` 的委托货箱，而由 Core story 的
> `grant_tutorial_contract` 效果以 `main_01` 模板生成一个「燃料舱交付 10 煤」的实例
> （`provider: fuel`，不可装船、不占载重，完成时从煤舱扣除；出航前 `VoyageService`
> 校验煤舱是否 ≥ 10），时限用 `tutorial_express`（标准迟到、极速准时）。开场
> `set_ship_fuel: 4` 把老船的煤舱清到 4，迫使玩家先补给。4.5.1 框架期的「2 煤」临时
> 目标已撤销。有目标（非 `confirm`）的阶段，剧情卡的「继续」只收起卡片、显示非阻塞
> 目标条，不推进阶段；阶段仍由事件 / 计数推进。

### 幕 1 · 第二港（4.5.3）

| 阶段 | 内容 | 系统动作 / 推进 |
|---|---|---|
| `second_port` | 剧情卡：解锁 `market`、`contracts`；第二主线「买 8 件纺织品，送 6 件回铁港」 | 市场只开放纺织品 / 香料两种贸易货物 + 补给区块；`grant_tutorial_contract`（main_02 模板，`provider: player`，`destination: home`，交付 6 件）；推进条件 `cmd:trade.buy`（match 纺织品）累计 ≥ 8 |
| `second_depart` | 剧情卡「返航」：目标「从海图出航返回铁港」 | 出航指示阶段；`cmd:voyage.start` 收掉并进入 `second_arrival` |
| `second_arrival` | 过渡阶段（无卡片）；抵达铁港结算页 | 只吃 `ui:arrival_settled`，抵达后才进入交货剧情 |
| `back_first` | 抵达铁港；委托自动交付 6 件，剧情引导卖出剩余 2 件 | `cmd:trade.sell`（match 纺织品）累计 ≥ 2 |
| `tavern_open` | 4.5.4：酒馆开店（物价情报 + 港口线索）；解锁 `clues` / `tavern`；自动给第一条线索并拉开两港价差 | `story.advance` |

### 幕 2 · 酒馆与线索（4.5.4）

| 阶段 | 内容 | 系统动作 / 推进 |
|---|---|---|
| `tavern_intro` | 酒馆自动给一条 L1 港口线索；前两港 2 种货有明显价差 | 酒馆页可用（物价 / 线索）；目标：刷新一次物价情报；`cmd:intel.refresh` |
| `third_good` | 获得第一种线索后解锁第三种货（木材）；目标：跑一个来回 | 市场商品 +1；`cmd:voyage.start` & `ui:arrival_settled` 各一次 |
| `second_clue` | 剧情卡：第二条线索给出具体方向（level 3，同一未发现港）；目标：备齐水煤并探索 | 自动获得同港 L3 线索；`story.flags.guaranteed_explore_clue_id` 指向该线索 |
| `explore_third` | 海图循线索出航（`explore.start`） | 本次探索必定成功（只对该线索生效并消费）；`cmd:explore.start` + `ui:arrival_settled` → `third_port` |

> **4.5.4 实装说明**：酒馆页替换情报站，设施 id 从 `intel` 迁移到 `tavern`（旧存档的
> `intel` 设施由 `MapOps.has_tavern` / 港口舞台归一化兼容）；命令 `intel.refresh` 与
> `clue.buy` / `clue.investigate` 保留原名，只是入口统一到酒馆。第一条线索按「离当前
> 港最近的未发现港」确定性选取并记入 `story_target_port_id`，第二条线索复用同一目标。
> `third_port` 在 4.5.4 是收尾占位阶段（船厂已解锁，旅客主线留给 4.5.5）。

### 幕 3 · 第三港（4.5.5）

| 阶段 | 内容 | 系统动作 / 推进 |
|---|---|---|
| `third_port` | 剧情卡：第三港船厂可改造载客；解锁 `shipyard` | Core 补上 `shipyard` 设施；`upgrade_hull` 换成带客舱位的 `medium_standard`（旧船进仓库）；`unlock_modules = ["core:module/small_cabin"]`；船厂只显示 1 人小型客舱 |
| `refit_unload` | 目标：卸下货舱 | `cmd:ship.uninstall_module`（match `category: cargo`） |
| `refit_cabin` | 目标：装上 1 人小型客舱 | `cmd:ship.install_module`（match `core:module/small_cabin`） |
| `passenger_run` | 进入时自动接第三主线：送 1 名旅客（沿用 `main_03` 主线槽位，清空货箱改为 1 名旅客） | `grant_tutorial_contract`（`passengers: 1`）；`cmd:voyage.start` + `ui:arrival_settled` |
| `story_complete` | 剧情卡：教学结束，进入沙盒 | 确认后 `data.story.completed=true`，解锁全部功能，`main_04` 继续由沙盒主线生成 |

> **4.5.5 实装说明**：小型客舱是 Core 新内容（`core:module/small_cabin`，`passenger_capacity = 1`）。
> 起始小船没有客舱位，所以第三港由 Core story 的 `upgrade_hull` 把船换成中型船体并补上
> `shipyard` 设施；`shipyard.view` 在剧情期间按 `unlocked_modules` 过滤购买 / 打造 / 仓库安装
> 候选（当前已装模块仍可查看 / 卸下）。第三主线沿用 `main_03` 段以保证 5 段主线计数与
> 通关回归，只把 payload 从货箱替换成 1 名旅客；完成时照常推进到 `main_04`。
>
> **反馈 #2 / #3（2026-10）**：`contracts` 的 `main_03`–`main_05` 的 `deadline_formula`
> 改为 `"none"`（第三主线起无期限，`FormulaRegistry` 新增 `none` → 0 哨兵）；
> `on_time_bonus` 保留原数值，作为「完成奖励」无条件发放，UI 文案「准时 +N」→「完成 +N」。
> `main_01/02` 保留教程限时（`tutorial_first` / `tutorial_trade`，教学首航另有
> `tutorial_express` 覆盖）。同时主线 offer（含沙盒 `main_04/05`）在
> `ContractOps.generate_offer` 生成时自动揭示目的港；普通委托目的地未发现前由
> `port.view` 隐藏（`state.contracts().offers` 池仍是 3 条，发现后同一实例自动重现）。

## 4. 系统改造清单（按切片落地）

1. **剧情框架**（4.5.1）：`StoryService`、`data.story`、`story.view` /
   `story.advance` / `story.skip` / `story.observe`、剧情卡、目标条、功能门禁。
2. **开局幕**（4.5.2）：新局固定构筑（隐藏选构筑）、主委托目的港揭示、补给限购
   flag、海图解锁、限时委托与快速航行提示、第一主线（玩家自备 10 煤）改造。
3. **并市与第二主线**（4.5.3）：`port.view` / 市场页显示水煤并复用 `supply.buy_*`；
   移除 `supply` 页面 / 导航 / 港口招牌；删除 `supply` feature；市场商品按 story
   `unlocked_items` 过滤；第二主线（玩家自备货物、反向航线）与买卖计数。
4. **酒馆 / 线索 / 保底探索**（4.5.4）：✅ 酒馆页替换情报页（`tavern` 设施 /
   feature、旧存档 `intel` 兼容）；酒馆自动 + 购买线索；前两港价差注入（Core
   `set_market_price_bias`）；第三种货物解锁；第二条 L3 线索与保底探索成功。
5. **船厂 / 客舱 / 旅客**（4.5.5）：✅ 新增 1 人小型客舱内容；`shipyard.view` 按
   story `unlocked_modules` 过滤购买 / 打造 / 仓库候选；第三主线旅客（沿用 `main_03`
   段）与卸货舱 / 装客舱引导；第三港补船厂设施并换带客舱位的船体。
6. **收尾**（4.5.6）：全量测试、窗口截图、README / todo / 本文、静态文档。

## 5. 数据模型（`GameState.data`，全部可 JSON 化，惰性 ensure，不改 `schema_version`）

```text
data.story = {
  flow_id: String,                 # Core map profile 的 story.flow_id
  stage_index: int,                # 当前阶段（-1 = 未开始）
  active: bool,
  completed: bool,                 # 正常完成
  skipped: bool,                   # 玩家跳过整段教程
  seen: [String],                  # 已经点过「继续」的剧情卡阶段 id
  counters: {String: int},         # 事件累计（如 supply_coal / trade_goods）
  flags: {String: bool},           # supply_locked / guaranteed_explore_success ...
  unlocked_features: [String],     # 见 §8 的框架 feature 枚举
  unlocked_items: [String],        # 市场可见的商品 id（Core story 数值）
  unlocked_modules: [String],      # 船厂可见的模块 id
}
```

- `GameState.ensure_story()`：缺块补默认值（`active=false`、`completed=true`，
  旧存档不弹剧情、不门禁）；`RunFactory` 在 `run.start` 时按当前 map profile 初始化
  为 active 并进入第 0 阶段，应用 `start_unlocks` / 初始效果。
- 存档 round-trip 必须一致；旧存档不触发剧情、功能保持全开。
- `story.observe` 只在事件 / 条件满足时推进，可一次跨多个阶段；每进入新阶段写
  `stage_index`、解锁集合、`seen` 清空当前卡、发 `story.stage_entered` 事件。

## 6. 命令 / 查询形状

**查询**（经 `QueryRegistry` → `FrameworkApi`）

- `story.view`：

  ```text
  {
    enabled, active, completed, skipped, flow_id, stage_index, stage_id,
    card: null | {title_key, body_keys: [key], advance_label_key, skip_label_key},
    objective: null | {text_key, progress: int, target: int},
    focus: {} | {target: String, text_key: String},
    unlocked_features: [String], unlocked_items: [String], unlocked_modules: [String],
    lock_actions: [String], preferred_strategy: String,
    can_skip: bool,
  }
  ```

  查询只读：由 `QueryBus` 克隆执行；Shell 每帧 / 每命令后读取即可。`focus` 是可选
  的强制引导目标（见 §8.1），未声明时是空字典。

**命令**（经 `CommandRegistry` → `FrameworkApi`）

| 命令 | 参数 | 行为 |
|---|---|---|
| `story.advance` | `{}` | 剧情卡「继续」：`confirm` 阶段记录 seen 并进入下一阶段（应用解锁 / 效果）；有目标（条件型）阶段只记录 seen 收起卡片，阶段仍由事件 / 计数推进 |
| `story.skip` | `{}` | 跳过整段教程：`completed=true, skipped=true`，按 Core `skip_unlocks` 解锁全部功能；**必须**保底执行 `discover_contract_destination`，避免跳过即卡死 |
| `story.observe` | `{event: String, data: Dictionary}` | 由 Shell 在成功命令 / UI 事件后调用：累加 counters、评估推进条件、进入下一阶段、应用效果 |

Shell 转发的事件名约定（每个玩家动作只发一次，见 §3「触发时机契约」）：

```text
cmd:<command_name>        # payload = 该命令返回的 data（含 amount / item_id / ...）
ui:chart_opened / ui:chart_closed
ui:arrival_settled        # 演出结束、进入抵达结算时
ui:screen_opened:<screen> # 可选
```

效果（Effect）类型（按切片实现；未实现的类型忽略并记录 warning，不崩）：

```text
unlock_features / set_flag / clear_flag / discover_contract_destination
grant_tutorial_contract / set_ship_fuel
grant_clue {port: "next_unknown" | id, level: 1..4}
set_market_items / set_market_price_bias / unlock_items
guarantee_explore_success / unlock_modules / complete_story
```

## 7. Core JSON 与 Schema

`dev_mods/core/content/map_configs.json` 的 `data` 增加 `story` 块，并同步
`schemas/v2/map_config.schema.json`（`additionalProperties: false`，新增键全部声明）：

```json
"story": {
  "flow_id": "core:story/opening",
  "enabled": true,
  "skip_unlocks": ["supply", "chart", "market", "contracts", "clues", "tavern", "shipyard"],
  "stages": [
    {
      "id": "opening",
      "dialogue": {"title_key": "story.core.opening.title", "body_keys": ["..."]},
      "unlock_features": ["overview"],
      "effects": [{"type": "discover_contract_destination"}],
      "advance": {"mode": "confirm"}
    },
    {
      "id": "supply_intro",
      "dialogue": {"title_key": "...", "body_keys": ["..."]},
      "unlock_features": ["supply"],
      "objective": {"text_key": "story.core.supply_intro.objective", "target": 4},
      "advance": {"event": "cmd:supply.buy_coal", "counter": "supply_coal", "at_least": 4}
    }
  ]
}
```

- 文案键放 **Core 本地化**（`dev_mods/core/localization/zh_CN.json` / `en.json`，
  `story.core.*`），框架只放通用按钮 / 目标条键（`ui.story.*`）。
- 阶段可选 `focus: {target, text_key}`（语义引导目标，见 §8.1）：`target` 由 Shell
  解析成真实控件，内容不出现页面 / 节点路径；`text_key` 走 Core 本地化。
- 阶段推进条件支持：`mode: confirm`、`event + counter + at_least`、`all/any` 组合、
  `flag` / `not_flag`（用于「打开海图后恢复补给」）。
- 非法 / 缺失配置：`story.view.enabled=false`（不门禁、不弹剧情），不阻断开局。

## 8. 功能门禁与 UI（Shell）

- **框架 feature 枚举**（框架常量，不是内容 ID）：
  `overview / supply / chart / market / contracts / clues / tavern / shipyard`。
  `story.view.unlocked_features` 决定：
  - 顶部导航按钮、`M` 快捷键、港口招牌、状态条「海图 ▶」是否出现；
  - 未解锁页面直接拒绝（`_on_nav` 回退 overview），未解锁命令入口不渲染；
  - `clues` = 海图线索层 + 线索列表 + 调查入口；`tavern` = 替换后的情报页。
- **剧情卡**（Shell 全窗 overlay）：标题 + 多段正文 + 「继续」+「跳过教程」；卡片
  打开期间暂停其它输入（导航 / 快捷键），关闭后恢复；`Esc` 等同「继续」。
- **目标条**（非阻塞）：顶部 chrome 第二行右侧显示当前 objective 文案与进度
  （2026-10-28 UI 轮底部状态条移除后只有顶部这一处）；不遮挡操作，不锁输入。
- **跳过**：确认弹窗后执行 `story.skip`；跳过必须解锁全部功能并揭示主委托目的港，
  保证可继续正常游戏。教程完成后不再出现剧情卡，功能保持解锁。
- `960×540` 与 `1440×900` 不裁切；中英同步。

### 8.1 强制引导（focus）契约（v0.2.0-dev.3 反馈 #3）

需求：剧情早期「只有唯一一处可交互，其余全屏用半透明遮罩盖住」，且必须是**框架接口**，
内容只声明语义目标、不写死页面 / 控件。实现拆成三层：

1. **内容声明**（Core `map_configs.story.stages[]`，可选）：
   ```json
   "focus": {"target": "market_supply", "text_key": "story.core.focus.supply_brief"}
   ```
   `schemas/v2/common.schema.json#/$defs/story_stage` 已声明 `focus{target*, text_key}`；
   `SNModMaker` 嵌入式 schema bundle 由 `node SNModMaker/tools/sync-schemas.mjs` 同步。
2. **查询透传**：`StoryService.view()` 把阶段的 `focus` 原样放进 `story.view.focus`
   （只在剧情 active 且阶段声明时非空）。
3. **呈现组件** `framework/ui/components/sn_focus_overlay.gd`（`SNFocusOverlay`）：
   - 全屏四块遮罩拼出目标之外的四边（目标区域没有遮罩子节点，控件照常收到点击）；
     四块遮罩 `mouse_filter = STOP` 吃掉其余点击，根节点 `IGNORE`。
   - 外观全部来自皮肤：遮罩 = `SNSkin.style("fill_aqua")` + `bg.abyss` 半透明；
     高亮边框 = `SNSkin.style("focus_ring")` + `brass.highlight`；提示底板 =
     `SNSkin.style("panel_steel")` + `text.light`。禁止 `StyleBoxFlat` / 十六进制色。
   - API：`focus(rect, text)`（屏幕坐标）/ `focus_target(control, text)`（绑定真实控件）/
     `refresh_target()` / `clear_focus()` / `is_active()` / `get_target_rect()` /
     `get_mask_rects()`；resize 时重新拼边，不溢出视口。
   - 位置自愈（2026-10-28 P0）：容器排版 / 页面重建 / resize 会让目标控件在调用方
     拿到一次 `get_global_rect()` 之后继续移动，因此 Shell 优先传**真实 Control**，
     遮罩每帧重读目标矩形并在变化时重排；目标被释放 / 隐藏 / 矩形归零立即清除。
     提示板高度按字体实测换行高度固定，水平内容边距 24 px 避开 `panel_steel` 的
     19 px 黄铜角饰。
4. **Shell 解析**（`_resolve_story_focus_target`）：语义 id → 真实控件：
   - `market_supply`：市场页的 `MarketSupply` 区块；不在市场页时回退到「市场」导航入口；
   - `chart_entry`：状态条「海图 ▶」/ 顶部导航的海图开关；
   - `chart_close`：海图页 `CloseButton`（回退 `chart_entry`）；
   - `<screen>_nav`：对应页面的导航按钮。
   目标找不到时 **fail-open**（清空遮罩），内容写错也不会把玩家锁死。
5. **显示规则**：剧情卡打开时卡片优先（不显示遮罩）；演出 / 结算页 / 菜单清除；
   页面切换（重建）与窗口 resize 后重新解析目标；阶段推进 / `story.skip` 后自动清除。
   遮罩在 `StoryLayer` 中**最后挂载**（位于目标条 / 任务追踪条之上），否则提示文案会
   被目标条压住；Shell 在页面重建后做同步 + 两次 deferred 重解析，位置正确性最终由
   遮罩的目标绑定自愈兜底。
6. 当前覆盖阶段：`supply_brief`（`market_supply`）、`supply_hold`（`chart_entry`）、
   `chart_brief`（`chart_entry`：海图页上同一个开关即「关闭海图」）、`supply_finish`
   （`market_supply`）。`depart_brief` / `second_depart` 不声明 `focus`：它们要在海图页
   选目的港并确认出航，遮罩只留单一目标会把玩家锁在「只能关海图」的状态。
7. 测试：`test_story_ui::test_focus_overlay_component_masks_everything_but_the_target`
   （组件遮罩 / 点击穿透 / resize）、`..._test_guided_focus_masks_the_supply_block_and_clears_on_advance`
   （Shell 解析 + 清除）、`test_story::test_story_view_passes_the_optional_focus_target_through`
   （查询透传）；2026-10-28 新增 `test_focus_overlay_tracks_the_market_nav_after_rebuild`
   （真实 shell + 教程局：重建后遮罩洞 = 「市场」导航按钮 ≤8 px、提示板高度 ≤80 px、
   四块遮罩在目标四边）；`960×540` / `1440×900` 由组件布局断言覆盖。

## 9. 分片与验收口径

| 切片 | 内容 | 验收口径 | 状态 |
|---|---|---|---|
| **4.5.1 剧情框架 + 门禁 + 剧情卡** | ✅ 已实现：`GameState.ensure_story` / `StoryService`（配置读取、阶段推进、事件计数、解锁、效果分发、目标阶段收卡）；`story.view` / `advance` / `skip` / `observe` + 注册；Core `map_configs.story` + Schema；Core/框架本地化；Shell 剧情卡 + 目标条 + feature 门禁 + 跳过确认（`run.start` 新增 `tutorial` 参数，Shell 新局传 true） | 新局自动进入第 0 阶段且只解锁配置的功能；导航 / 港口招牌 / `M` / 状态条海图入口按解锁过滤；剧情卡可继续 / 跳过；跳过解锁全部并揭示主委托目的港；旧存档无 `story` 时全开且不弹；`story.view` 不泄露内部 counters / flags；存档 round-trip 一致；全量 **352 例 0 failed**；截图 `docs/design/screenshots/story/tutorial_card.png` / `tutorial_objective.png` | ✅ |
| **4.5.2 开局幕** | ✅ 已实现：教程新局隐藏选构筑（`new_game_screen` tutorial_mode + Shell 传默认教学船）；`opening`→`depart_brief` 全流程（获船叙事 / 补给 4 煤 2 水 / 补给受限 `lock_actions: supply.buy` / 海图解禁 / 关闭海图恢复补给 / 买够 10 煤 / 出航默认极速 / 抵达收尾）；燃料舱运煤教学委托（`grant_tutorial_contract` + `provider: fuel` + `set_ship_fuel`，出航前货物校验）；`tutorial_express` 限时 | 按 §3 幕 0 全流程可走通：补给购买触发阶段、限购命令被拦截且卡片显示原因、海图打开 / 关闭推进、买够出航、抵达第二港；标准速度迟到 / 极速准时；非教程局主线与 9 seed 通关回归不变；全量 **354 例 0 failed**；截图 `tutorial_supply_hold.png` / `tutorial_depart_fast.png` | ✅ |
| **4.5.3 并市 + 第二主线** | ✅ 已实现：水煤并入市场「补给（煤 / 水）」区块（复用 `supply.buy_*`），删除补给页 / 导航 / 港口招牌（旧 `supply` 入口重定向市场，旧存档兼容）；市场贸易货物按 story `unlocked_items` 过滤；Act 0 市场只有补给区块，第二港开放纺织品 / 香料；第二主线用 `grant_tutorial_contract`（main_02 模板、`provider: player`、`destination: home`）交付 6 件纺织品，剧情目标买 8 件、回港卖剩余 2 件；新增 `match` 事件条件与 `destination: home` | 补给页不存在，市场可买煤 / 水且扣款正确；Act 0 市场 0 条贸易货物，第二港 2 条；第二主线可买货 → 出航 → 回港交付 → 卖出剩余 → 收尾；全量 **363 例 0 failed**；截图 `tutorial_market_supply.png` / `tutorial_market_goods.png` | ✅ |
| **4.5.4 酒馆 / 线索 / 保底探索** | ✅ 已实现：酒馆页替换情报页（`tavern` 设施 / feature，旧 `intel` 设施 / 页面兼容并归一）；酒馆自动给 L1 线索 + 刷新物价情报，前两港纺织品 / 香料注入确定性价差（归位库存、双向交易）；第三种货（木材）解锁；第二条 L3 线索指向同一未发现港并带 `guaranteed_explore_clue_id`，`explore.settle` 对该线索无视 `outcome_roll` 直接成功且消费 flag；`third_port` 占位阶段解锁船厂待 4.5.5 | 酒馆可刷新物价情报、购买 / 调查线索；起始港卖价 > 邻港买价且可盈利；第一条线索后市场出现第三种货；第二条线索 L3 + 保底探索必成功并发现第三港；跳过教程不设置保底；全量 **369 例 0 failed**；截图 `tutorial_tavern.png` / `tutorial_tavern_clues.png` / `tutorial_market_third_good.png` / `tutorial_clue_list.png` | ✅ |
| **4.5.5 船厂 / 客舱 / 旅客** | ✅ 已实现：新增 `core:module/small_cabin`（1 人，120 金 / 轻量）；`shipyard.view` 在剧情期间按 `unlocked_modules` 过滤购买 / 打造 / 仓库候选，第三港只显示该客舱；第三港由 Core 补 `shipyard` 设施并用 `upgrade_hull` 换成带客舱位的船体；`refit_unload`（match `category: cargo`）→ `refit_cabin`（match 小型客舱）→ 自动接 `main_03` 旅客委托（`passengers: 1`，货箱清空）→ 出航送客 → `story_complete` 解锁全部并交还沙盒；`ContractOps.attach` 不再用空货箱校验货舱容量 | 第三港船厂只显示小型客舱；客舱安装后可接 / 完成 1 人旅客委托；未解锁模块不可见不可买；剧情可推进到完成并解锁全部功能；`main_03` 完成推进 `main_04`；全量测试 0 failed；截图 `tutorial_shipyard_cabin.png` / `tutorial_shipyard_refit.png` / `tutorial_passenger_contract.png` | ✅ |
| **4.5.6 收尾** | ✅ 已实现：全量测试（当前工作树 369 例 0 failed，其中本仓提交的测试集 363 例；并行 session 的 legacy UV / 武器 socket 套件 6 例不属于本片）、窗口截图（剧情卡 / 目标条 / 门禁 / 酒馆 / 并市 / 船厂 / 旅客，1440×900，脚本可重复运行）、README / todo / 本文回填、静态文档 | 全量 0 failed；截图脚本可重复生成同尺寸 PNG；`gen_static_docs --check` 通过；每片提交只含本片文件 | ✅ |
| **dev.3 反馈 #1 / #3 修复** | ✅ 已实现：①触发时机——`ui:chart_opened` / `ui:arrival_settled` 改为玩家动作点一次性上报（页面挂载不再 observe）；`depart_brief` / `second_depart` 拆出 `first_arrival` / `second_arrival`（`cmd:voyage.start` vs `ui:arrival_settled`）；`DEPARTURE_VEIL` 归入演出分支；离开结算页清空摘要。②强制引导——`SNFocusOverlay` + `story.view.focus` + Schema `focus` 字段 + Shell 语义 target 解析（`market_supply` / `chart_entry` / `<screen>_nav`），覆盖 `supply_brief` / `supply_hold` / `chart_brief` / `supply_finish`，中英文案同步 | 真实航海驱动 T1：出航只收出航指示、抵达才出现第二港剧情、一次动作恰好 1 次 `story.observe`、结算页重建 0 次额外上报；T2：海图开 / 关各 1 次、页面重建 0 次；T3：DEPARTURE_VEIL 重建不重挂海图 / 不上报；`test_story` 14、`test_story_ui` 9、`test_ui_shell` 26、`test_voyage_flow` 16、schema 55、quest 14、task 6、full_clear 2 全绿；`gen_static_docs --check`、`check_content_schema_v2`、SNModMaker content CLI 64 全过；`960×540` / `1440×900` 由遮罩 rect 断言覆盖 | ✅ |
| **2026-10-28 P0 引导框错位修复** | ✅ 已实现：玩家反馈「框与按钮根本不在一个地方」。根因：`main.gd` 在刚重建的 `TopChrome/Nav` 完成排版前同步调用 `_sync_story_focus()`，只拿到旧 `global_rect`；且之后不再重排，右上「市场」按钮的引导框停在左上角、提示板被 autowrap Label 的过期最小高度撑到 484×387。修复：`SNFocusOverlay.focus_target(control, text)` 绑定真实控件并逐帧 `refresh_target()` 自愈（目标释放 / 隐藏即清除），`main.gd` 重建后补两次 deferred 重解析；遮罩最后挂到 `StoryLayer`（在目标条之上，提示不再被压）；三处 `SNSkin.style()` 共享 StyleBox 改为克隆后 tint；提示板按字体实测换行高度 + 24 px 水平内边距避开角饰 | 1440×900 实测 hole = target = (1332,77,72,38)（误差 0）、FocusHint 484×30、四块遮罩分别贴目标四边；960×540 同样 hole=target；`test_story_ui` 新增重建后回归用例（单测 / 组件 / Shell 各层）；窗口重截 `docs/design/screenshots/story/tutorial_objective.png`（ring 套住「市场」按钮、提示完整可读） | ✅ |

## 10. 数值建议（Core 可调，不写死框架）

- 第一主线：自备 `10` 煤（4.5.2 以 `provider: fuel` 从煤舱交付，完成时扣 10；开场
  `set_ship_fuel = 4` 强制补给），水 2；补给首段目标 4 煤 / 2 水；关闭海图后目标
  改为「煤舱达到 10」（进入阶段用 `set_counter_from_ship` 从当前 8 煤起算，购买时用
  `counter_from: stock` 跟随煤舱，目标条显示「8/10，还差 2」）。契约时限用
  `tutorial_express = max(6, distance / 13.5)`（标准迟到、极速准时）。
- 第二主线：玩家自备 `8` 件纺织品（市场单价约 66，起始资金足够），委托交付 `6`
  件回起始港，余下 `2` 件在起始港市场卖出；Act 1 市场只开放纺织品 / 香料两种货物。
- 酒馆：物价情报价沿用 `intel_cost`（25）；港口线索免费自动 1 条（L1）+ 第二段
  免费 1 条（L3，同一未发现港）；购买线索沿用 `intel_clue_cost`（40）。
- 前两港价差：`set_market_price_bias` 对纺织品 / 香料把库存归位到基准、把起始港
  卖价 ×1.35、其它港买价 ×0.7，并打开双向交易；保底探索只对第二条剧情线索生效
  （消费 `guaranteed_explore_clue_id`，跳过教程不设置）。
- 第三种货：木材（`core:item/timber`，起始港可双向交易）。
- 第三主线：1 名旅客；小型客舱 `core:module/small_cabin`（`passenger_capacity = 1`，
  120 金 / 60 打造 / 8 重量）；第三港由 Core 补 `shipyard` 并换成 `medium_standard`
  船体（旧船进仓库）；船厂只上架该客舱。沿用 `main_03` 主线槽位，完成后主线链
  自动生成 `main_04`。
- 解锁顺序：`overview`（始终）→ `supply` → `chart` → `clues/market/contracts` →
  `tavern` → `shipyard`。

## 11. 风险与未决

- **主线链映射（4.5.5 已收口）**：剧情三段分别沿用 `main_01` / `main_02` / `main_03`
  模板（第三段 payload 改成 1 名旅客），完成第三段后主线链自动推进 `main_04`，沙盒
  继续剩余段；`main_04/05` 的 9 seed 通关回归由既有 `test_full_clear` 覆盖。
- **并市回归**：移除补给页会影响 `test_ui_shell` / 补给页测试 / 导航断言；先保留
  `supply.*` 命令，页面与导航再删，测试同步改。
- **酒馆替换情报页**：`intel` 设施 / `intel.view` / `clue.buy` 门禁需要迁移；旧存档
  保留 `intel` 兼容分支。
- **真实无船**：按决策 A 内部保留船，`data.ship` 不置空；剧情只叙事 + 解锁。
- **跳过教程**：必须揭示主委托目的港并解锁全部功能，避免卡死；跳过后的第一主线
  仍可按现有规则完成。
- **数值 / 文本量**：五幕文本与内容数值较大，全部进 Core JSON / Core 本地化；
  首版数值先按 §10，试玩后再调。
