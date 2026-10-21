# 探索系统（阶段 4）实现契约 — 4.1 / 4.2（4.3 计划中）

> 作用：把 [NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md) §5/§7 的探索与线索规则
> 落到可运行的纵向切片。数值全部来自 Core JSON，框架只读规则。本文是实现契约，
> 与设计文档冲突时以设计文档的玩法意图为准、以本文的字段/命令形状为准。
> **4.3 是已记录、尚未实现的体验修正计划**（见 §10）。

## 1. 范围

**4.1 交付**：线索数据结构与 `ClueService`、抵达传闻 / 酒馆购买两条线索来源、
线索分级与海图可视化（方向箭头 / 虚线圆圈 / `？港口名？`）、`explore.start` 探索出航、
搜索区判定与发现概率、失败（线索作废 + 漂流到最近已知港）、发现（解锁港口 + 迷雾揭示 + 入港）、
探索演出接线与结算页。

**4.2 交付**：资源告急决策（航程 50% 处停下，继续 / 掉头两条真实路径）、
`VoyagePresentation.force_arrival()`、到港服务复用（探索入港与普通抵达同一套
委托 / 市场记忆 / NPC / 债务 / 委托刷新 / 统计 / 自动存档）、告警状态进查询与演出。
**仍不在 4.2**：探索中事件化海洋（归阶段 5）、货物类线索与时效（4.3）。

## 2. 数据（`GameState.data`，全部可 JSON 化，惰性 ensure，无需迁移）

```text
data.clues = {
  next_id: int,
  active: [Clue],
  failed: [clue_id],
  resolved: [clue_id],
}
Clue = {
  id: String,                    # "clue:1"
  type: "port_location",
  source_key: "rumor" | "intel", # 决定可信度区间与分级权重
  source_display_key: String,    # 本地化键 ui.clue.source.<key>
  target_port_id: String,        # 只有领域层知道；查询不得泄露
  level: int,                    # 1 存在 / 2 方向 / 3 距离 / 4 名称
  reference_port_id: String,     # 线索里的"xx 港以东"参照港
  direction_angle: float,        # 世界弧度，reference -> target 的真实方向
  distance_min_hours: float,     # 按可信度加误差后的航程区间
  distance_max_hours: float,
  credibility: float,            # 0..1，不直接显示
  search_zone: {x: float, y: float, radius: float},
  created_at: float,
}

data.explore_voyage = null | {
  clue_id, target_port_id, origin, strategy_id,
  zone: {x, y, radius},
  route_path: [x0, y0, ...],      # 与 WorldMap.edges 同格式的扁平数组
  distance: float, duration_hours: float,
  departure_time: float, arrival_time: float,
  coal_used: float, water_used: float, wages: int,
  alert_needed: bool,             # 出发时按 alert_threshold 预判
  alert_progress: float,          # 决策点比例（Core alert_progress，默认 0.5）；continue 后置 1.0
  alert_decided: String,          # "" | "continue" | "turn_back"
  outcome_roll: float,            # 0..1，出发时用命名流抽定；成功 = roll < chance
  status: "outbound",
}
data.voyage = { "kind": "explore", "status": "at_sea" }   # 仅作"在航"标记
```

- 探索期间 `data.voyage` 非空 → 既有 `is_at_port()` / `port.view.at_sea` / 贸易门禁自动生效。
- `explore.settle` / 掉头后同时清空 `explore_voyage` 与 `voyage`。
- 4.2 起 `sea_chart.view.explore` 同时输出 `alert_needed / alert_progress / alert_decided`，
  演出与顶栏据此决定何时停下；`alert_progress` 在 `continue` 后变为 1.0（已处理）。

## 3. 内容数值（Core JSON）

`dev_mods/core/content/map_profiles.json` 的每个 profile `data` 增加 `exploration` 块，
并同步扩展 `schemas/map_profile.schema.json`（`additionalProperties: false`，新增可选
`exploration` 对象）。框架不得写死这些数字：

```json
"exploration": {
  "rumor_clue_chance": 0.65,
  "intel_clue_cost": 40,
  "max_active_clues": 4,
  "level_weights": {
    "rumor": [0.55, 0.35, 0.10, 0.00],
    "intel": [0.00, 0.15, 0.45, 0.40]
  },
  "credibility_range": {
    "rumor": [0.25, 0.55],
    "intel": [0.60, 0.95]
  },
  "distance_error_ratio": 0.35,
  "search_zone_radius": 14.0,
  "search_zone_noise": 12.0,
  "discovery_chance_base": 0.20,
  "discovery_chance_per_credibility": 0.70,
  "risk_base": 0.08,
  "risk_per_unreliability": 0.12,
  "drift_durability_loss": 8.0,
  "drift_extra_coal": 4.0,
  "drift_extra_water": 4.0,
  "drift_hours": 6.0,
  "alert_threshold": 0.5,
  "alert_progress": 0.5,
  "turnback_extra_ratio": 0.25
}
```

规则读取顺序：当前 `map_profile_id` 的 `exploration` → 缺字段用同文件 `data` 里的
框架兜底常量（仅防御，不参与调参）。`distance_error_ratio` 表示的航程误差区间：
`distance_min_hours = true_hours * (1 - ratio*(1-credibility))`，max 对称。

## 4. 领域服务（`framework/domain/exploration/`）

### `ClueService`

```text
clues(state) -> Dictionary                  # 惰性 ensure data.clues
active(state) -> Array[Dictionary]
on_arrival(context) -> Dictionary           # 抵达后按 rumor_clue_chance 抽传闻线索
buy(context) -> Dictionary                  # 花钱买情报线索（Result）
acquire(context, source_key, rng, target_port_id="") -> Dictionary
mark_failed(state, clue_id) -> bool
mark_resolved(state, clue_id) -> bool
view(state, context) -> Array               # 只读视图，按等级裁剪字段
```

- 目标：坐标世界里**未发现**、且未被其它活跃线索指向的港口；没有目标返回 `{}`（不报错）。
- 等级：按 `level_weights[source_key]` 加权抽；可信度：`credibility_range[source_key]` 均匀抽。
- 搜索区：真实港口位置 + 随机方向（命名流）× `(1 - credibility) * search_zone_noise`，
  半径 `search_zone_radius`。
- 查询视图裁剪：`level < 4` 不含 `name_key`；`level < 3` 不含 `circle`；
  **任何等级都不含 `target_port_id` 与 `credibility`**。level 2 给 `direction_angle`，
  level 3/4 给 `circle`，level 4 额外 `name_key`。
- 线索来源展示：`source_display_key = "ui.clue.source." + source_key`。

### `ExplorationCalculator`

```text
preview(context, clue_id, strategy_id) -> Result.ok({
  clue_id, origin_id, strategy_id, zone, distance, duration_hours,
  effective_speed, coal_required, water_required, crew_wages,
  risk_score, feasible, blockers: [{code, message_key, ...}],
  discovery_chance,          # 展示用（≈ 可信度的函数），不泄露 roll
  route_path: [x0,y0,...],
})
```

- 航速 / 载重系数 / 煤水费率 / 风险来源与 `VoyageCalculator.preview` 同一套公式与钳位，
  只是距离用坐标世界 `origin.position -> zone.center` 的直线距离（按 `RouteCalculator`
  生成绕陆航线，失败退回直线）。
- 命名流：`RngService.STREAM_EXPLORATION`（新增，加入 `STREAM_NAMES`），
  key 规则：传闻 `"rumor:<port>:<time>"`、购买 `"intel:<port>:<time>"`、
  出发 `"explore:<clue_id>:<departure>"`。

### `ExploreVoyageService`

```text
start(context, clue_id, strategy_id) -> Result.ok({
  preview,                       # 见上
  presentation: {
    kind: "explore", origin, clue_id, zone,
    route_path, total_hours, strategy_id, departure_time, arrival_time,
    alert_needed, alert_progress,
  },
}, events)
decide(context, choice)          # choice: continue | turn_back（重复 continue 被拒）
settle(context) -> Result.ok({
  result: "discovered" | "failed",
  destination: port_id,          # 演出入港用的港口（目标港或漂流港）
  summary: { explore: {...}, destination, arrival_time, delayed_hours, injuries,
             contracts, market_events, debt_events, completed_orders,
             offers_refreshed: true, ... },   # 4.2 起与普通抵达同形状
}, events)
```

`start`：
- 前置：有 run、在港（`is_at_port()`）、线索 active、没有 `explore_voyage`、
  preview.feasible；扣工资与煤水（`add_money`/`record_expense`、`ship.coal/water`）。
- 写入 `explore_voyage` 与 `data.voyage` 标记；`at_sea` 标记不新增（用 `voyage` 判定）。
- `outcome_roll` 用命名流抽定；`alert_needed = coal_used >= coal_before*alert_threshold
  或 water_used >= water_before*alert_threshold`（0 库存守卫）；`alert_progress` 取
  Core 的 `alert_progress`（决策点比例，默认 0.5），同时作为"已处理"标记：
  `continue` 后置 1.0。
- 事件：`explore.started`（payload: clue_id/origin/duration_hours/coal_used/water_used）。

`settle`（4.2 起）：
- 未出发 / 没有 explore_voyage → `Result.fail("not_exploring", "ui.error.not_exploring")`。
- 时间推进到 `arrival_time`（失败再加 `drift_hours`）。
- 成功（`outcome_roll < discovery_chance`）：
  - `WorldOps.discover_port_id` + `WorldOps.mark_visited` + `FogOps.reveal_arrival`；
  - `current_port_id = target`；线索 → resolved；
  - notices：`ui.notice.exploration_found`；事件 `explore.finished`（result=discovered）。
- 失败：
  - 线索 → failed；漂流：耐久 `-= drift_durability_loss`（≥0）、煤水各 `-= drift_extra_*`（≥0）、
    时间 `+= drift_hours`；目的地 = 距搜索区最近的**已发现**港口（通常出发港）；
  - notices：`ui.notice.exploration_failed`；事件 `explore.finished`（result=failed）。
- 成功后调用 `VoyageService.settle_arrival_services()`：打造订单、委托完成（目标港匹配时）、
  NPC 市场推进、市场记忆、逾期债务、普通委托刷新；`VoyageService.record_arrival_stats()`
  记一次航次；结果带 `autosave=true`。成功/失败都给 `summary.explore = {result, port_id,
  port_name_key, clue_id, search_center:{x,y}, extra_coal, extra_water, durability_loss}`，
  并清空 `explore_voyage` 与 `data.voyage` 标记。

`decide("continue")`：只确认告警（不做别的状态变化），返回 `{continued: true, destination,
remaining_hours}`；重复回答返回 `Result.fail("alert_already_decided", "ui.error.alert_already_decided")`。
`decide("turn_back")`：额外消耗 `coal_used/water_used * turnback_extra_ratio`，时间前进
半个航程，目的地 = 出发港，线索保持 active，返回 `{returned: true, destination, summary}`；
同样跑 `settle_arrival_services()`（真实入港）、记一次航次并带 `autosave=true`。

## 5. 命令 / 查询

命令（`command_registry.gd`）：

| 命令 | 参数 | 说明 |
|---|---|---|
| `explore.start` | `{clue_id, strategy_id}` | 见 §4 |
| `explore.settle` | `{}` | 演出抵达时由 Shell 调用 |
| `explore.decide` | `{choice}` | `continue` / `turn_back`；重复 continue → `ui.error.alert_already_decided` |
| `clue.buy` | `{}` | 当前港有 `intel` 设施时购买情报线索 |

查询：

- `sea_chart.view` 追加：
  ```text
  clues: [{
    id, source_key, source_display_key, level, reference_port_id,
    direction_angle, distance_min_hours, distance_max_hours,
    circle: null | {x, y, radius},         # level >= 3
    name_key: "" | key,                     # level == 4
    estimated: {feasible, blockers, duration_hours, coal_required,
                water_required, risk_score, discovery_chance},
  }]
  explore: {active: bool, clue_id: String,
            alert_needed: bool, alert_progress: float, alert_decided: String}
  can_buy_clue: {available: bool, cost: int, reason_key: String}
  ```
  注意：`clues` 不含 target_port_id / credibility / search_zone 中心误差来源。

## 6. 演出与 UI 接线

- 海图页（M 键）：
  - `SNSeaChartView` 画线索：level 2 从参照港沿 `direction_angle` 画方向箭头；
    level 3 在 `circle` 画虚线圆；level 4 圆圈 + 文本 `？<港口名>？`。点击任一线索图形
    发 `clue_clicked(id)`（新增信号），选中高亮。
  - `SNSeaChartPanel` 增加线索区块：来源、等级文案、方向（8 方位）、航程区间、
    预计航程/煤水/风险、可行性；「循此线索出航」按钮 → 屏幕发 `explore_requested(clue_id)`。
  - `SeaChartScreen` 新增 `explore_requested(clue_id)`；Shell 接上后运行
    `explore.start`（策略暂用 `core:strategy/standard`，4.2 再让玩家选）。
- 探索演出：
  - Shell 保存命令返回的 `presentation`（`_presentation_explore`），沿用
    `VoyagePresentation`（`event_at = alert_needed ? alert_progress : -1`）；航行页
    `AtSeaScreen.bind` 收到 `unknown_destination: {x, y, label_key}` 时，
    海图画虚线航线 + `?` 终点标记，航程条右侧显示 `？`（`ui.label.unknown_destination`）。
  - **资源告急（4.2）**：演出走到 `EVENT_WAIT` 时，`_rebuild_ui` 优先挂资源告急页
    （复用 `EventScreen`，标题 `ui.explore.alert.title`、选项
    `ui.explore.alert.continue` / `ui.explore.alert.turn_back`，船况来自 `state.ship()`）。
    告警期间 `skip()` 仍返回 `NONE`（不能替玩家决策），顶栏保持「探索中 → ？」。
    - `continue`：`explore.decide` → `_presentation.resolve_event()` → 演出继续到抵达，
      `ARRIVAL_READY` 自动 `explore.settle`；
    - `turn_back`：`explore.decide` 返回的 `destination/summary` 写入演出状态，
      `_presentation_explore["returned"] = true` → `VoyagePresentation.force_arrival()`
      （直接进入 ARRIVAL_APPROACH）→ 3D 入港 → 结算；`ARRIVAL_READY` 用 returned 守卫
      跳过二次 settle；
    - 决策失败：状态栏报 `_error_text`，告警页重新挂载。
  - `VoyagePresentation.Step.ARRIVAL_READY`：Shell 先跑 `explore.settle`，把
    `_presentation_voyage.destination` 换成 `result.destination`，
    `_presentation_summary = result.summary`，再 `_rebuild_ui()` + `_begin_stage_arrival()`。
  - 结算页：`settlement_screen` 在 `summary.explore` 存在时追加探索结果区块
    （发现 / 失败漂流 / 返航；港口名、额外煤水、耐久损失、线索说明）。
- 海图、航行页、结算页、顶栏所有新文案走本地化键（见 §7），不得硬编码中文。

## 7. 本地化键（框架 `framework/localization/zh_CN.json` + `en.json` 同步）

```text
ui.clue.section_title / ui.clue.source.rumor / ui.clue.source.intel
ui.clue.level.1 / .2 / .3 / .4
ui.clue.direction.N/NE/E/SE/S/SW/W/NW
ui.clue.distance_range ("约 %d–%d 小时航程")
ui.clue.reliability_hint ("来源：%s")
ui.button.explore_clue ("循此线索出航")
ui.label.unknown_destination ("？")
ui.label.exploring ("探索中")
ui.notice.clue_acquired ("获得线索：%s")
ui.notice.no_clue_available
ui.notice.exploration_found ("发现新港口：%s")
ui.notice.exploration_failed ("探索失败，漂流到 %s")
ui.notice.exploration_turned_back ("掉头返航：%s")
ui.explore.result.discovered / .failed / .turned_back
ui.explore.alert.title / .description / .continue / .turn_back / .remaining
ui.explore.section_title / .destination / .extra_losses
ui.explore.clue_resolved / .clue_failed / .clue_retained
ui.error.not_at_port / .not_exploring / .unknown_clue / .clue_not_active
ui.error.already_exploring / .insufficient_money / .no_exploration_target
ui.error.alert_already_decided
```

## 8. 测试验收

- 领域（`framework/tests/cases/test_exploration.gd`，已在 `test_runner.SUITE_PATHS`）：
  线索等级/来源权重/可信度区间、无目标时不出线索、查询裁剪（不泄露 target/credibility）、
  抵达传闻按概率触发且命名流可复现、`clue.buy` 金币/设施/上限门禁、`explore.start`
  扣资源/写状态/在航门禁、`settle` 成功解锁港口 + 迷雾揭示 + current port + 线索 resolved、
  `settle` 失败线索 failed + 漂到最近已知港 + 耐久/煤水扣减、`decide("turn_back")` 回港且线索仍 active、
  存档 round-trip（`GameState.hash()` 前后一致）。
- **4.2 增量**：告警阈值/决策点来自 Core JSON、presentation/query 暴露告警状态、重复 continue 被拒；
  settle / failure / turn_back 都跑到港服务（委托完成、市场记忆、委托刷新、统计 +1）并带 `autosave` 标记。
- UI：`test_sea_chart`（clues 出现在视图模型、图表几何、面板线索区块、探索信号）、
  `test_voyage_flow`（海图点击线索 → 演出到 settle → 结算页显示探索结果；成功与失败各一条；
  资源告急「继续」与「掉头」两条 E2E，含 `skip()` 不可用、无 double settle）、
  `test_ui_shell`（`clue.buy` 按钮/入口）、`test_voyage_presentation`（force_arrival 从 AT_SEA / EVENT_WAIT）。
- 回归：既有 264 例 + 4.1 的 34 例全部保持通过。

## 9. 实现状态与验收截图（4.1 / 4.2）

**实现（2026-10-21）**

| 层 | 文件 |
|---|---|
| 规则 | `framework/domain/exploration/exploration_rules.gd`（读 `map_profiles.data.exploration`，`discovery_chance` / `roll_succeeds` 单一真源） |
| 线索 | `framework/domain/exploration/clue_service.gd`（抵达传闻 / 购买情报 / 等级裁剪视图 / resolved·failed 生命周期） |
| 预览 | `framework/domain/exploration/exploration_calculator.gd`（绕陆航线、航速/煤水/工资/风险/发现概率、blockers） |
| 航次 | `framework/domain/exploration/explore_voyage_service.gd`（`start` / `settle` / `decide(continue, turn_back)`；4.2 起复用 `VoyageService.settle_arrival_services()` + 自动存档） |
| 演出模型 | `framework/domain/voyage/voyage_presentation.gd`：4.2 新增 `force_arrival()`（告警掉头直接入港；`skip()` 语义不变） |
| 命令/查询 | `framework/application/commands/explore_commands.gd`（`explore.start/settle/decide`、`clue.buy`）；`sea_chart.view` 追加 `clues/explore/can_buy_clue` |
| UI | `sn_sea_chart_view` 线索层 + 未知终点、`sn_sea_chart_panel` 线索区块、`sea_chart_screen` 信号转发、`at_sea_screen` 探索终点、`settlement_screen` 探索结果块、`main.gd` Shell 接线（4.2 资源告急页 + 继续/掉头） |
| 内容/本地化 | `dev_mods/core/content/map_profiles.json` 的 `exploration` 块 + `schemas/map_profile.schema.json`；框架 `zh_CN/en` 的 `ui.clue.*` / `ui.explore.*` / `ui.button.*` 键 |

**验收截图**（1440×900，`tools/godot/capture_exploration.gd` 窗口模式生成，两次运行证据逐字一致）

| 截图 | 验证内容 |
|---|---|
| [exploration_chart_clues.png](screenshots/exploration/exploration_chart_clues.png) | 海图线索层：level 2 参照港方向箭头、level 3 虚线圆、level 4 `？渔村？` + 选中高亮；右侧面板来源/等级/方位/航程区间/预计煤水风险/可出航性 |
| [exploration_chart_route.png](screenshots/exploration/exploration_chart_route.png) | 探索航行：金色计划航线 + 到 `?` 终点的虚线预测线（`?` 被顶栏挡住时 clamp 到可见区）；顶栏「探索中 → ？」；底部航程条 `铁港 → ？` |
| [exploration_resource_alert.png](screenshots/exploration/exploration_resource_alert.png) | **4.2 资源告急页**：航程 50% 停下，「资源告急」+ 煤/水/耐久 +「继续探索 / 掉头返航」，跳过演出不可用 |
| [exploration_turned_back.png](screenshots/exploration/exploration_turned_back.png) | **4.2 掉头结算**：回出发港、线索保留、额外煤水损耗、结算显示「掉头返航」 |
| [exploration_alert_continue.png](screenshots/exploration/exploration_alert_continue.png) | **4.2 继续路径**：同一线索告警后选「继续探索」→ 正常 settle 并发现新港口（目标港仍隐藏到结算） |
| [exploration_result_found.png](screenshots/exploration/exploration_result_found.png) | 发现：结算页探索区块（发现新港口 / 抵达港口 / 线索已解决），原委托结算布局不变 |
| [exploration_result_failed.png](screenshots/exploration/exploration_result_failed.png) | 失败：红色「探索失败」、漂流回铁港、额外煤水/耐久损耗、延误 6h、线索已作废 |
| [exploration_arrival.png](screenshots/exploration/exploration_arrival.png) | 另一次真实发现的结算页（与 found 证据不同，验证不是同一帧） |

**测试**：领域 `test_exploration` 28 例、UI 线索/演出/结算/告警与 E2E 15 例、海图船形朝向与
`?` 可见区 clamp 2 例、presentation force_arrival 2 例；全套 **308 例通过 / 0 失败**。

**4.2 已知边界**：探索中的事件化海洋（敌对/环境/奖励）归阶段 5，与其共享事件暂停/恢复机制；
货物类线索、`expires_at` 时效、在港等待/委托解锁线索留给 4.3；资源告急仅覆盖煤/水
（4.2 探索途中没有耐久损耗来源，耐久告急等阶段 5 的敌对/环境事件接入后再补）。

## 10. 4.3 探索体验修正（Planned，2026-10-21 记录）

> 状态：**只记录需求与决策，未实现**。玩家实机体验后提出 8 条问题，逐条已定位根因；
> 本节是实施清单与验收口径。实现时按 §10.3 的切片顺序推进，数值仍走 Core JSON
> （`map_profiles` 的 `exploration` 块，schema 同步扩展），不触碰 Content Schema 2.0。

### 10.1 反馈与根因

| # | 反馈 | 根因（当前实现） |
|---|---|---|
| U1 | 港口周围无雾区相对海图太大，不自然 | 雾半径是固定常量（`FogOps.DEFAULT_MIN_VISION_RADIUS=20`、`DEFAULT_PORT_REVEAL_RADIUS=24`），而真实对局孪生世界尺寸被 `RunFactory` 硬编码为 160（默认 400）；半径/世界≈15%，直径 48 占世界 30% |
| U2 | 能直接获得四级线索 | `ClueService.acquire` 用 `level_weights` 一次抽到 1–4 级（intel 权重 `[0,0.15,0.45,0.40]`），没有逐级过程 |
| U3 | 线索探索一次就消失；失败不应消耗线索 | `ExploreVoyageService.settle` 失败分支 `ClueService.mark_failed`，线索从 active 移入 failed；`resolved` 也会移出 active |
| U4 | 船移动时海图不随船照亮，演出生硬 | 迷雾只在抵达时 `FogOps.reveal_arrival` 更新；演出层没有按船位绘制/更新照亮 |
| U5 | 航线一直显示在海图上 | `SNSeaChartView._draw_routes()` 无条件绘制 view model 里全部航线 |
| U6 | 详细总览里的海图还是老版 | `overview_screen._map_panel` 仍挂旧 `map_canvas`（节点/线稿） |
| U7 | 出航准备页多余，出航操作应放进海图 | 旧 `voyage_screen` 仍是导航项/港口招牌入口；海图面板只把选择路由到出航页 |
| U8 | 资源在出航时一次性扣除，应随航行时间连续变化并实时计算 | `VoyageService.start` / `ExploreVoyageService.start` 在出发时把整段煤水扣光，演出期间顶栏读数不变化 |

### 10.2 已确认决策

1. **线索逐级升级**：线索**获得时固定为 1 级**；新增「调查线索」逐级升级（1→2→3→4）。
   **具体消耗（金币/时间/成功率）留到后续线索系统迭代再定**——4.3 先只做机制、接口与界面，
   Core 里预留 `investigation_cost` / `investigation_hours`（初始 0，先不做资源判定）。
   同一线索的 `target_port_id`、`credibility`、`search_zone` 在获得时固定，升级只是**逐级披露**
   （方向 → 圆圈 → 名称），不重抽目标。
2. **旧总览海图**：直接从「详细总览」删除（不替换成小海图）。
3. **连续消耗**：演出中顶栏煤水读数**按航行时间连续变化**；领域状态**结算时一次性落账**
   （不在航程中每帧写状态）。出发时只扣工资；抵达 / 失败漂流 / 掉头时按实际航行小时扣煤水
   （含事件延误小时）；资源告急阈值仍用"本段预计消耗 vs 出发库存"预判。
4. **雾半径**：改为**最小世界尺寸相关量**——`radius = min(bounds.w, bounds.h) * ratio`，
   比例放进 Core `map_profiles.exploration`（建议初始 `fog_port_reveal_ratio ≈ 0.075`、
   `fog_vision_ratio ≈ 0.05`，160 世界下即 12 / 8）；`RunFactory` 的双子世界尺寸也从内容读取，
   不再硬编码 160。迷雾网格 `cell_size = vision_radius / 4` 随之缩放。
5. **出航策略**：海图内的出航确认弹窗提供锅炉策略切换，**默认上一次选择**
   （Shell 记忆；无记忆时用 `strategy.standard` tag 解析，不写 `core:*` 字面量）；
   弹窗同时显示距离 / 预计时间 / 煤水 / 风险 / 可行性 blockers。

### 10.3 实施切片（建议顺序）

| 切片 | 内容 | 验收口径 | 估时 |
|---|---|---|---|
| **4.3.1 海图观感与线索规则** | U1 雾比例 + 世界尺寸内容化；U3 失败不消耗线索（记 `attempts` / `last_attempt_at`，可再探索）；U5 航线仅在选中港口时显示；U6 删除详细总览旧海图 | 160 世界下泊位雾直径 ≤ 世界 10%；失败后线索仍在 active 且可再次出航；未选港口时海图无线（演出计划航线除外）；详细总览无 `map_canvas` | 1–1.5 天 |
| **4.3.2 线索逐级升级** | U2 + `clue.investigate` 命令（等级 +1，上限 4）；面板「调查线索」与下一级预告；获得永远 1 级；Core 预留消耗字段（0） | 新线索必为 level 1；连续调查 3 次依次到 2/3/4；目标港/搜索区/可信度不变；查询仍按等级裁剪 | 1.5 天 |
| **4.3.3 随船照亮** | U4 演出层 `SNSeaChartView.set_ship_vision()` 软圆；抵达/掉头时按实际航线采样 `FogOps.update_ship_vision` 持久化沿途迷雾 | 演出中船周有连续照亮；结算后存档里航线沿海岸为 EXPLORED；旧存档无 world_map 时 no-op | 1 天 |
| **4.3.4 出航流程重构** | U7 删除 `voyage_screen` 与导航/招牌入口；海图港口面板「启航」+ 线索面板「循线索出航」统一打开确认弹窗（预估 + 策略切换 + 取消/启航）；确认后直接 `voyage.start` / `explore.start` | 导航无「出航」；从海图两处入口都能完成出航；策略默认上次选择且可切换；可行性 blockers 在弹窗内可见 | 1.5 天 |
| **4.3.5 连续消耗** | U8 出发只扣工资；状态存 `departure_coal/water` + 每小时费率；顶栏按 `elapsed_hours` 连续刷新；结算/漂流/掉头按实际小时落账；事件延误补算 | 出发后船库不变；演出中读数随进度下降；抵达后扣减=实际小时×费率；掉头扣实际半程+额外；告警仍按预判触发；存档在结算后为最终值 | 2 天 |

每片完成后跑全量测试 + 相关窗口截图；全部做完后更新本文 §10 状态、
[NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md) 的对应段落、README/CHANGELOG/todo，并重生成静态文档。

### 10.4 仍未定 / 后续迭代

- 线索调查的具体消耗（金币/时间/成功率/上限）——等线索系统下一轮迭代定。
- 货物类线索（`port_goods`）与 `expires_at` 时效、在港等待/完成委托解锁线索。
- 耐久告急（需要阶段 5 的敌对/环境事件造成途中损伤）。
- en locale 收尾（结算页/事件页既有硬编码中文）。
- 旧 `map_canvas`/`map_view` 若在删除总览入口后无其它引用，可一并删除；实现时先查引用再删。
