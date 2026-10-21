# 新手剧情 / 教学系统（阶段 4.5）实现契约 — 4.5.1 / 4.5.2 Implemented（2026-10-22）

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
   （`map_profiles.data.story` + Schema），框架只跑状态机与门禁。

## 3. 剧情流程（五幕）

> 触发事件由 Shell 在**成功命令后**转发为 `story.observe`；条件 / 数值见 §10。
> 每一幕的「解锁」是该幕进入时追加的 feature 集合。

### 幕 0 · 开局（4.5.2）

| 阶段 id | 玩家看到 / 可做 | 系统动作 | 推进条件 |
|---|---|---|---|
| `opening` | 无任何功能；剧情卡「无船 → 获船」、任务说明 | 生成船（内部）；解锁 `overview`；揭示主委托目的港 | 点「继续」 |
| `supply_intro` | 解锁 `supply`；目标「为船购买 4 煤 2 水」 | 补给页可用；引导目标条 | `cmd:supply.buy_coal` 累计 ≥ 4 且 `buy_water` ≥ 2 |
| `supply_hold` | 剧情卡「补给受限」；解锁 `chart`；目标「打开海图」 | 补给购买暂时禁用（story flag）；海图入口出现 | `ui:chart_opened` |
| `chart_brief` | 海图目标：目的港已标记；目标「关闭海图并继续补给」 | 剧情卡说明「快速航行」 | `ui:chart_closed` |
| `supply_finish` | 补给恢复；目标「买够 10 煤」 | 限时委托提示（standard 迟到、express 准时） | 煤累计 ≥ 10 |
| `depart` | 解锁 `chart`；目标「打开海图 → 出航 → 选快速航行」 | 确认弹窗默认策略由 Shell 记忆；剧情提示 | `cmd:voyage.start` |
| `first_arrival` | 抵达第二港，结算页 | 完成第一主线、解锁邻港 | `ui:arrival_settled` |

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
| `second_port` | 剧情卡：第三港 1 级线索；解锁 `clues`、`market`、`contracts`；第二个主线「买 6 件货送回第一港」 | 自动获得一条第三港 L1 线索；市场开启（仅 2 种货 + 水煤） |
| `second_buy` | 目标：在市场买够 6 件并出航回第一港 | `cmd:trade.buy` 累计 ≥ 6 且 `cmd:voyage.start` |
| `back_first` | 抵达第一港；剧情卡：卖掉货物、完成第二主线 | `cmd:trade.sell` 累计 ≥ 6 / 委托完成 |
| `tavern_open` | 剧情卡：酒馆开店（物价情报 + 港口线索）；解锁 `tavern`；自动给第一条线索 | `story.advance` |

### 幕 2 · 酒馆与线索（4.5.4）

| 阶段 | 内容 | 系统动作 / 推进 |
|---|---|---|
| `tavern_intro` | 酒馆自动给一条港口线索；前两港 2 种货有明显价差 | 酒馆页可用（物价 / 线索）；`clue.buy` 走酒馆 |
| `third_good` | 获得第一条线索后解锁第三种货；目标：跑一个来回 | 市场商品 +1；`cmd:voyage.start` & `ui:arrival_settled` 各一次 |
| `second_clue` | 剧情卡：第二条线索给出具体方向（level 3）；目标：备齐水煤并探索 | 自动获得同港 L3 线索；`story` 标记 `guaranteed_explore_success` |
| `explore_third` | 海图循线索出航（`explore.start`） | 本次探索必定成功；发现第三港；解锁 `shipyard` 待第三港 |

### 幕 3 · 第三港（4.5.5）

| 阶段 | 内容 | 系统动作 / 推进 |
|---|---|---|
| `third_port` | 剧情卡：第三主线「送 1 名旅客去某港」；解锁 `shipyard` | 船厂只上架「小型客舱（1 人）」；客舱模块不存在时先给一个占位条目 |
| `refit` | 目标：卸下货舱 → 装上客舱 | `cmd:ship.uninstall_module` + `cmd:ship.install_module` |
| `passenger_run` | 出航送客 | `cmd:voyage.start` → `ui:arrival_settled`；完成第三主线 |
| `story_complete` | 剧情卡：教学结束，进入沙盒 | 解锁剩余功能；`data.story.completed=true` |

## 4. 系统改造清单（按切片落地）

1. **剧情框架**（4.5.1）：`StoryService`、`data.story`、`story.view` /
   `story.advance` / `story.skip` / `story.observe`、剧情卡、目标条、功能门禁。
2. **开局幕**（4.5.2）：新局固定构筑（隐藏选构筑）、主委托目的港揭示、补给限购
   flag、海图解锁、限时委托与快速航行提示、第一主线（玩家自备 10 煤）改造。
3. **并市与第二主线**（4.5.3）：`port.view` / 市场页显示水煤并复用 `supply.buy_*`；
   移除 `supply` 页面 / 导航 / 港口招牌；删除 `supply` feature；市场商品按 story
   `unlocked_items` 过滤；第二主线（玩家自备货物、反向航线）与买卖计数。
4. **酒馆 / 线索 / 保底探索**（4.5.4）：酒馆页替换情报页（`tavern` feature、设施标签
   迁移、旧存档 `intel` 兼容）；酒馆自动 / 购买线索；前两港价差注入；第三种货物
   解锁；保底探索成功。
5. **船厂 / 客舱 / 旅客**（4.5.5）：新增 1 人小型客舱内容；`shipyard.view` 按 story
   `unlocked_modules` 过滤；第三主线旅客委托与卸货舱 / 装客舱引导。
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
    unlocked_features: [String], unlocked_items: [String], unlocked_modules: [String],
    can_skip: bool,
  }
  ```

  查询只读：由 `QueryBus` 克隆执行；Shell 每帧 / 每命令后读取即可。

**命令**（经 `CommandRegistry` → `FrameworkApi`）

| 命令 | 参数 | 行为 |
|---|---|---|
| `story.advance` | `{}` | 剧情卡「继续」：`confirm` 阶段记录 seen 并进入下一阶段（应用解锁 / 效果）；有目标（条件型）阶段只记录 seen 收起卡片，阶段仍由事件 / 计数推进 |
| `story.skip` | `{}` | 跳过整段教程：`completed=true, skipped=true`，按 Core `skip_unlocks` 解锁全部功能；**必须**保底执行 `discover_contract_destination`，避免跳过即卡死 |
| `story.observe` | `{event: String, data: Dictionary}` | 由 Shell 在成功命令 / UI 事件后调用：累加 counters、评估推进条件、进入下一阶段、应用效果 |

Shell 转发的事件名约定：

```text
cmd:<command_name>        # payload = 该命令返回的 data（含 amount / item_id / ...）
ui:chart_opened / ui:chart_closed
ui:arrival_settled        # 结算页出现后
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

`dev_mods/core/content/map_profiles.json` 的 `data` 增加 `story` 块，并同步
`schemas/map_profile.schema.json`（`additionalProperties: false`，新增键全部声明）：

```json
"story": {
  "flow_id": "core:story/opening",
  "enabled": true,
  "tutorial_build_id": "core:starting_build/steady",
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
- **目标条**（非阻塞）：顶部 chrome 第二行右侧或底部状态条显示当前 objective 文案
  与进度；不遮挡操作，不锁输入。
- **跳过**：确认弹窗后执行 `story.skip`；跳过必须解锁全部功能并揭示主委托目的港，
  保证可继续正常游戏。教程完成后不再出现剧情卡，功能保持解锁。
- `960×540` 与 `1440×900` 不裁切；中英同步。

## 9. 分片与验收口径

| 切片 | 内容 | 验收口径 | 状态 |
|---|---|---|---|
| **4.5.1 剧情框架 + 门禁 + 剧情卡** | ✅ 已实现：`GameState.ensure_story` / `StoryService`（配置读取、阶段推进、事件计数、解锁、效果分发、目标阶段收卡）；`story.view` / `advance` / `skip` / `observe` + 注册；Core `map_profiles.story` + Schema；Core/框架本地化；Shell 剧情卡 + 目标条 + feature 门禁 + 跳过确认（`run.start` 新增 `tutorial` 参数，Shell 新局传 true） | 新局自动进入第 0 阶段且只解锁配置的功能；导航 / 港口招牌 / `M` / 状态条海图入口按解锁过滤；剧情卡可继续 / 跳过；跳过解锁全部并揭示主委托目的港；旧存档无 `story` 时全开且不弹；`story.view` 不泄露内部 counters / flags；存档 round-trip 一致；全量 **352 例 0 failed**；截图 `docs/design/screenshots/story/tutorial_card.png` / `tutorial_objective.png` | ✅ |
| **4.5.2 开局幕** | ✅ 已实现：教程新局隐藏选构筑（`new_game_screen` tutorial_mode + Shell 传默认教学船）；`opening`→`depart_brief` 全流程（获船叙事 / 补给 4 煤 2 水 / 补给受限 `lock_actions: supply.buy` / 海图解禁 / 关闭海图恢复补给 / 买够 10 煤 / 出航默认极速 / 抵达收尾）；燃料舱运煤教学委托（`grant_tutorial_contract` + `provider: fuel` + `set_ship_fuel`，出航前货物校验）；`tutorial_express` 限时 | 按 §3 幕 0 全流程可走通：补给购买触发阶段、限购命令被拦截且卡片显示原因、海图打开 / 关闭推进、买够出航、抵达第二港；标准速度迟到 / 极速准时；非教程局主线与 9 seed 通关回归不变；全量 **354 例 0 failed**；截图 `tutorial_supply_hold.png` / `tutorial_depart_fast.png` | ✅ |
| **4.5.3 并市 + 第二主线** | 水煤进市场（补给区块 + `supply.buy_*`），删除补给页 / 导航 / 招牌；市场商品按 `unlocked_items` 过滤；第二主线（自备货物反向交付）与买卖计数；回到第一港卖货结案 | 补给页不存在；市场可买煤 / 水且扣款正确；市场仅显示解锁商品；第二主线可买货 → 出航 → 回港卖出 → 完成；旧存档 `supply` 页面消失但命令仍可用 | ⬜ |
| **4.5.4 酒馆 / 线索 / 保底探索** | 酒馆页替换情报页（物价情报 + 港口线索，`tavern` 设施 / feature，旧 `intel` 兼容）；自动 / 购买线索；前两港价差；第三件货解锁；两条线索与保底探索成功、发现第三港 | 酒馆可买物价情报与港口线索；前两港同货价差 ≥ Core 配置且可盈利；第一条线索后第三件货出现在市场；第二条线索 L3 + 保底探索必成功并解锁第三港；跳过流程不触发保底 | ⬜ |
| **4.5.5 船厂 / 客舱 / 旅客** | 新增 1 人小型客舱（Core 模块 + 本地化）；`shipyard.view` 按 `unlocked_modules` 过滤；第三主线旅客 1 人；卸货舱 / 装客舱引导 | 第三港船厂只显示小型客舱；客舱安装后可接 / 完成旅客委托；未解锁模块不可见不可买；剧情引导步骤可推进到完成 | ⬜ |
| **4.5.6 收尾** | 全量测试、窗口截图（剧情卡 / 目标条 / 门禁 / 酒馆 / 并市 / 船厂）、README / todo / 本文回填、静态文档 | 全量 0 failed；截图两次运行逐字一致；`gen_static_docs --check` 通过；每片提交只含本片文件 | ⬜ |

## 10. 数值建议（Core 可调，不写死框架）

- 第一主线：自备 `10` 煤（4.5.2 以 `provider: fuel` 从煤舱交付，完成时扣 10；开场
  `set_ship_fuel = 4` 强制补给），水 2；补给首段目标 4 煤 / 2 水；契约时限用
  `tutorial_express = max(6, distance / 13.5)`（标准迟到、极速准时）。
- 第二主线：玩家自备 `6` 件指定货物（建议香料 / 纺织品，按 Core 商品表），前两港
  价差 ≥ 40%；市场此阶段仅 2 种货 + 水煤。
- 酒馆：物价情报价沿用 `intel_cost`；港口线索免费自动 1 条（L1）+ 第二段免费 1 条
  （L3）；保底探索无视 `outcome_roll` 直接成功。
- 第三主线：1 名旅客；小型客舱 `passenger_capacity = 1`；船厂只上架该客舱。
- 解锁顺序：`overview`（始终）→ `supply` → `chart` → `clues/market/contracts` →
  `tavern` → `shipyard`。

## 11. 风险与未决

- **主线链映射**：剧情接管 `main_01..main_03` 后，`main_04/05` 是否按原内容接续
  （当前 5 段主线结构 / 9 seed 通关回归会受影响）。实现 4.5.3 前必须用测试锁定
  「剧情第三幕完成 → 主线剩余段继续」或「主线在第三幕后结束」；默认按前者。
- **并市回归**：移除补给页会影响 `test_ui_shell` / 补给页测试 / 导航断言；先保留
  `supply.*` 命令，页面与导航再删，测试同步改。
- **酒馆替换情报页**：`intel` 设施 / `intel.view` / `clue.buy` 门禁需要迁移；旧存档
  保留 `intel` 兼容分支。
- **真实无船**：按决策 A 内部保留船，`data.ship` 不置空；剧情只叙事 + 解锁。
- **跳过教程**：必须揭示主委托目的港并解锁全部功能，避免卡死；跳过后的第一主线
  仍可按现有规则完成。
- **数值 / 文本量**：五幕文本与内容数值较大，全部进 Core JSON / Core 本地化；
  首版数值先按 §10，试玩后再调。
