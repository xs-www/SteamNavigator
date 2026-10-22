# 探索系统（阶段 4）实现契约 — 4.1 / 4.2 / 4.3 / 4.4

> 作用：把 [NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md) §5/§7 的探索与线索规则
> 落到可运行的纵向切片。数值全部来自 Core JSON，框架只读规则。本文是实现契约，
> 与设计文档冲突时以设计文档的玩法意图为准、以本文的字段/命令形状为准。
> **4.3 探索体验修正已全部实现**（2026-10-21，U1–U8，分片 4.3.1–4.3.5 见 §10）。
> **4.4 线索扩展已全部实现**（2026-10-21，分片 4.4.1–4.4.5 见 §11，含验收截图 §11.8）。

## 1. 范围

**4.1 交付**：线索数据结构与 `ClueService`、抵达传闻 / 酒馆购买两条线索来源、
线索分级与海图可视化（方向箭头 / 虚线圆圈 / `？港口名？`）、`explore.start` 探索出航、
搜索区判定与发现概率、失败（线索作废 + 漂流到最近已知港）、发现（解锁港口 + 迷雾揭示 + 入港）、
探索演出接线与结算页。

**4.2 交付**：资源告急决策（航程 50% 处停下，继续 / 掉头两条真实路径）、
`VoyagePresentation.force_arrival()`、到港服务复用（探索入港与普通抵达同一套
委托 / 市场记忆 / NPC / 债务 / 委托刷新 / 统计 / 自动存档）、告警状态进查询与演出。
**4.3 交付（体验修正）**：雾半径改为最小世界尺寸 × Core 比例、双子世界尺寸内容化；
失败探索不消耗线索（记 `attempts` / `last_attempt_at`，可再次出航）；线索获得固定 1 级
并可在港逐级 `clue.investigate`（1→4，核心消耗字段预留 0）；演出中船周连续照亮与
抵达 / 掉头沿途迷雾持久化；普通航线只在选中港口时显示；删除详细总览旧海图；删除
出航准备页、出航确认（预估 + 锅炉策略切换，默认上次）移入海图弹窗；资源演出中连续
显示、出发只扣工资、结算按实际航行小时一次性落账。
**仍不在 4.3**：探索中事件化海洋（归阶段 5）、货物类线索与 `expires_at` 时效、
调查的具体消耗数值（留待线索系统下一轮）。

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
  attempts: int,                # 4.3/U3：失败尝试次数（失败不再消耗线索）
  last_attempt_at: float,       # 最近一次失败尝试的结算时间
}

data.explore_voyage = null | {
  clue_id, target_port_id, origin, strategy_id,
  zone: {x, y, radius},
  route_path: [x0, y0, ...],      # 与 WorldMap.edges 同格式的扁平数组
  distance: float, duration_hours: float,
  departure_time: float, arrival_time: float,
  # 4.3.5/U8 连续消耗：出发库存 + 每小时费率；出发不扣煤水，结算按实际小时扣
  departure_coal: float, departure_water: float,
  coal_rate: float, water_rate: float,
  coal_used: float, water_used: float, wages: int,   # 计划值：告警 / 掉头比例 / 事件
  alert_needed: bool,             # 出发时按 alert_threshold 预判（计划消耗 vs 出发库存）
  alert_progress: float,          # 决策点比例（Core alert_progress，默认 0.5）；continue 后置 1.0
  alert_decided: String,          # "" | "continue" | "turn_back"
  outcome_roll: float,            # 0..1，出发时用命名流抽定；成功 = roll < chance
  status: "outbound",
}
data.voyage = { "kind": "explore", "status": "at_sea" }   # 仅作"在航"标记
data.fog = { grid, coastal_cells }                        # 4.3/U1：网格半径由内容比例推导
```

- 探索期间 `data.voyage` 非空 → 既有 `is_at_port()` / `port.view.at_sea` / 贸易门禁自动生效。
- `explore.settle` / 掉头后同时清空 `explore_voyage` 与 `voyage`。
- 4.2 起 `sea_chart.view.explore` 同时输出 `alert_needed / alert_progress / alert_decided`，
  演出与顶栏据此决定何时停下；`alert_progress` 在 `continue` 后变为 1.0（已处理）。

## 3. 内容数值（Core JSON）

`dev_mods/core/content/map_configs.json` 的每个 profile `data` 增加 `exploration` 块与
`twin_world_size`，并同步扩展 `schemas/v2/map_config.schema.json`
（`additionalProperties: false`，新增可选 `exploration` 对象与顶层 `twin_world_size`）。
框架不得写死这些数字：

```json
"twin_world_size": 160.0,
"exploration": {
  "rumor_clue_chance": 0.65,
  "fog_port_reveal_ratio": 0.05,
  "fog_vision_ratio": 0.05,
  "investigation_cost": 0,
  "investigation_hours": 0.0,
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

规则读取顺序：当前 `map_config_id` 的 `exploration`（`map_configs.data.exploration`）→ 缺字段用同文件 `data` 里的
框架兜底常量（仅防御，不参与调参）。`distance_error_ratio` 表示的航程误差区间：
`distance_min_hours = true_hours * (1 - ratio*(1-credibility))`，max 对称。

**4.3 落地说明**

- 雾半径 = `min(world.bounds.w, world.bounds.h) × fog_*_ratio`；160 世界下 reveal /
  vision 都是 8，泊位揭示直径 16 = 世界的 10%（§10.3 验收口径；此前建议的
  `0.075` 会让直径达到 15%，以验收为准取 `0.05`）。`RunFactory` 用
  `twin_world_size` 缩放 160 单位手写布局。
- `level_weights` 在 4.3.2 起**不再参与获得等级**（获得固定 1 级），字段保留给后续
  线索系统；`investigation_cost` / `investigation_hours` 只作为预留接口暴露，本轮
  不做资源判定、不扣钱、不推进时间。

## 4. 领域服务（`framework/domain/exploration/`）

### `ClueService`

```text
clues(state) -> Dictionary                  # 惰性 ensure data.clues
active(state) -> Array[Dictionary]
on_arrival(context) -> Dictionary           # 抵达后按 rumor_clue_chance 抽传闻线索
buy(context) -> Dictionary                  # 花钱买情报线索（Result）
acquire(context, source_key, rng, target_port_id="") -> Dictionary
investigate(context, clue_id) -> Result     # 4.3.2：在港把 active 线索推进一级（上限 4）
mark_attempt_failed(state, clue_id, at_time=-1.0) -> int   # 4.3/U3：失败不消耗线索
mark_resolved(state, clue_id) -> bool
view(state, context) -> Array               # 只读视图，按等级裁剪字段
```

- 目标：坐标世界里**未发现**、且未被其它活跃线索指向的港口；没有目标返回 `{}`（不报错）。
- **等级：获得时固定 1 级**（4.3.2/U2 起不再用 `level_weights` 抽）；只有
  `investigate` 逐级推进 1→2→3→4。可信度仍按 `credibility_range[source_key]` 均匀抽。
- 搜索区：真实港口位置 + 随机方向（命名流）× `(1 - credibility) * search_zone_noise`，
  半径 `search_zone_radius`。目标港 / 可信度 / 搜索区 / 方向 / 航程区间在获得时固定，
  调查只披露下一层，绝不重抽。
- `investigate` 门禁：有 run、线索在 active、在港（`is_at_port()`）、`level < 4`；
  成功只改 `level`，返回 `{clue_id, level, next_level, cost, hours, view}`，
  `cost` / `hours` 来自 Core 预留字段（本轮不执行扣费）。
- **失败不消耗线索**：`explore.settle` 失败只调用 `mark_attempt_failed` 累加
  `attempts`、写 `last_attempt_at`，线索仍 active 且可再次 `explore.start`；旧存档
  `failed` 列表仅兼容保留，不再新增。
- 查询视图裁剪：`level < 4` 不含 `name_key`；`level < 3` 不含 `circle`；
  **任何等级都不含 `target_port_id` 与 `credibility`**。level 2 给 `direction_angle`，
  level 3/4 给 `circle`，level 4 额外 `name_key`；另输出 `attempts` /
  `last_attempt_at` 与 4.3.2 调查入口字段（`investigation_cost` /
  `investigation_hours` / `can_investigate` / `next_level` / `next_level_key`）。
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
  preview.feasible；**只扣工资**（`add_money`/`record_expense`），煤水原样留在船上
  （4.3.5/U8）。
- 写入 `explore_voyage` 与 `data.voyage` 标记；`at_sea` 标记不新增（用 `voyage` 判定）。
- 航次同时记录 `departure_coal/water` 与 `coal_rate/water_rate`（计划消耗 ÷ 计划时长）；
  `presentation` 也带这四个字段供 Shell 演出中插值读数。
- `outcome_roll` 用命名流抽定；`alert_needed = coal_used >= coal_before*alert_threshold
  或 water_used >= water_before*alert_threshold`（0 库存守卫，用计划消耗 vs 出发库存）；
  `alert_progress` 取 Core 的 `alert_progress`（决策点比例，默认 0.5），同时作为
  "已处理"标记：`continue` 后置 1.0。
- 事件：`explore.started`（payload: clue_id/origin/duration_hours/coal_used/water_used）。

`settle`（4.2 / 4.3.5）：
- 未出发 / 没有 explore_voyage → `Result.fail("not_exploring", "ui.error.not_exploring")`。
- 时间推进到 `arrival_time`（失败再加 `drift_hours`）。
- 成功（`outcome_roll < discovery_chance`）：
  - 按 `rate × (arrival - departure)` 一次性扣煤水；`WorldOps.discover_port_id` +
    `WorldOps.mark_visited` + `FogOps.trace_route` + `FogOps.reveal_arrival`；
  - `current_port_id = target`；线索 → resolved；
  - notices：`ui.notice.exploration_found`；事件 `explore.finished`（result=discovered）。
- 失败：
  - **线索保留在 active**（只 `mark_attempt_failed` 累加 `attempts` / 写 `last_attempt_at`）；
  - 漂流：按 `rate × (duration + drift_hours)` 扣小时消耗，再扣 `drift_extra_coal/water`
    额外损耗（钳位到剩余库存）；耐久 `-= drift_durability_loss`（≥0）；时间 `+= drift_hours`；
    目的地 = 距搜索区最近的**已发现**港口（通常出发港）；
  - notices：`ui.notice.exploration_failed`；事件 `explore.finished`（result=failed，
    payload 带 `attempts`）。
- 成功后调用 `VoyageService.settle_arrival_services()`：打造订单、委托完成（目标港匹配时）、
  NPC 市场推进、市场记忆、逾期债务、普通委托刷新；`VoyageService.record_arrival_stats()`
  记一次航次；结果带 `autosave=true`。成功/失败都给 `summary.explore = {result, port_id,
  port_name_key, clue_id, search_center:{x,y}, extra_coal, extra_water, durability_loss}`，
  并清空 `explore_voyage` 与 `data.voyage` 标记。

`decide("continue")`：只确认告警（不做别的状态变化），返回 `{continued: true, destination,
remaining_hours}`；重复回答返回 `Result.fail("alert_already_decided", "ui.error.alert_already_decided")`。
`decide("turn_back")`：先按 `rate × duration × 0.5` 扣实际半程，再额外消耗
`coal_used/water_used * turnback_extra_ratio`（钳位到剩余库存），时间前进半个航程，
目的地 = 出发港，线索保持 active，返回 `{returned: true, destination, summary}`；
同样跑 `settle_arrival_services()`（真实入港）、记一次航次并带 `autosave=true`。

## 5. 命令 / 查询

命令（`command_registry.gd`）：

| 命令 | 参数 | 说明 |
|---|---|---|
| `explore.start` | `{clue_id, strategy_id}` | 见 §4 |
| `explore.settle` | `{}` | 演出抵达时由 Shell 调用 |
| `explore.decide` | `{choice}` | `continue` / `turn_back`；重复 continue → `ui.error.alert_already_decided` |
| `clue.buy` | `{}` | 当前港有 `intel` 设施时购买情报线索 |
| `clue.investigate` | `{clue_id}` | 4.3.2：在港把 active 线索推进一级（1→4）；成功事件 `clue.investigated`（payload 仅 `clue_id` / `level`） |

查询：

- `sea_chart.view` 追加：
  ```text
  clues: [{
    id, source_key, source_display_key, level, reference_port_id,
    direction_angle, distance_min_hours, distance_max_hours,
    circle: null | {x, y, radius},         # level >= 3
    name_key: "" | key,                     # level == 4
    attempts, last_attempt_at,              # 4.3/U3：失败不消耗线索
    investigation_cost, investigation_hours, can_investigate,
    next_level, next_level_key,             # 4.3.2：调查入口与下一级预告
    estimated: {feasible, blockers, duration_hours, coal_required,
                water_required, risk_score, discovery_chance},
  }]
  fog_radii: {vision: float, port_reveal: float}   # 4.3/U1：世界单位，供演出软圆
  explore: {active: bool, clue_id: String,
            alert_needed: bool, alert_progress: float, alert_decided: String}
  can_buy_clue: {available: bool, cost: int, reason_key: String}
  ```
  注意：`clues` 不含 target_port_id / credibility / search_zone 中心误差来源。

## 6. 演出与 UI 接线

- 海图页（M 键 / 顶栏「海图」/ 状态条「海图 ▶」/ 港口「海图」招牌）：
  - `SNSeaChartView` 画线索：level 2 从参照港沿 `direction_angle` 画方向箭头；
    level 3 在 `circle` 画虚线圆；level 4 圆圈 + 文本 `？<港口名>？`。点击任一线索图形
    发 `clue_clicked(id)`，选中高亮。
  - **普通航线只在选中港口时显示**（4.3/U5）：`visible_routes()` 只保留与
    `_selected_port` 相邻的航线，未选中（含选中线索）时一条不画；演出模式只保留计划
    航线。选中港口时面板照旧展示与当前港之间的航线预估。
  - **演出随船照亮**（4.3/U4）：`SNSeaChartView.set_ship_vision(radius)` 在船周画软圆
    （纯表现，`ship_vision_rings()` 控制衰减）；`AtSeaScreen` 用
    `fog_radii.vision` 每帧推给海图。
  - `SNSeaChartPanel` 线索区块：来源、等级文案、方向（8 方位）、航程区间、
    `attempts`（失败尝试次数）、「下一级：%s」预告、「调查线索」按钮与
    预计航程/煤水/风险/可行性。`investigate_requested` / `purchase_clue_requested`
    由屏幕原样转发；「循此线索出航」不再直接出航，而是发
    `departure_requested("explore", clue_id)` 打开确认弹窗。
  - **出航确认弹窗**（4.3/U7，4.3.4）：港口面板「启航」与线索面板「循线索出航」
    共用 `SNVoyageConfirm`（预估 / 发现概率 / 可行性 blockers / 锅炉策略切换 /
    取消 / 启航）；Shell 用 `_chart_departure_model()` 组装数据，确认后才发
    `voyage.start` / `explore.start`。出航准备页与旧「出航」导航项已删除。
- 探索演出：
  - Shell 保存命令返回的 `presentation`（`_presentation_explore`），沿用
    `VoyagePresentation`（`event_at = alert_needed ? alert_progress : -1`）；航行页
    `AtSeaScreen.bind` 收到 `unknown_destination: {x, y, label_key}` 时，
    海图画虚线航线 + `?` 终点标记，航程条右侧显示 `？`（`ui.label.unknown_destination`）。
  - **沿途迷雾持久化**（4.3/U4）：成功 / 失败漂流在 `reveal_arrival` 前对
    `voyage.route_path` 调 `FogOps.trace_route()`；掉头只采样前半程（`end_progress=0.5`）；
    普通航行抵达也按 `WorldOps.route_between` 的折线落账。沿海格子留 EXPLORED，
    海洋格子按 §3.2 规则回黑雾；旧存档无 `world_map` 时 no-op。
  - **连续消耗**（4.3/U8）：出发只扣工资；领域 `voyage` 记录
    `departure_coal/water` 与 `coal_rate/water_rate`，`_complete_arrival` 按
    `rate × (arrival - departure)` 一次性扣（事件延误计入）。探索成功按
    `arrival - departure`，失败按 `duration + drift_hours`，掉头按 `duration × 0.5`
    + 额外比例。演出顶栏煤 / 水 chip 用同一组字段逐帧插值（只改 Label 文本，
    不写领域状态）；告警仍按「计划消耗 vs 出发库存」预判。
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
ui.clue.attempts ("已尝试 %d 次")
ui.clue.next_level ("下一级：%s")
ui.clue.max_level ("已达最高等级")
ui.button.explore_clue ("循此线索出航")
ui.button.investigate_clue ("调查线索")
ui.label.unknown_destination ("？")
ui.label.exploring ("探索中")
ui.notice.clue_acquired ("获得线索：%s")
ui.notice.clue_investigated ("线索调查完成：已升至 %d 级")
ui.error.clue_max_level ("这条线索已经是最高等级")
ui.confirm.title.voyage / .explore
ui.confirm.route / .clue / .strategy / .blockers / .discovery_chance / .on_time / .hint
ui.button.cancel ("取消")
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
- **4.3 增量**：
  - 领域：雾半径 = 世界短边 × Core 比例（160 世界下 8/8、cell_size=2、泊位直径 ≤10%）、
    双子世界尺寸来自 `twin_world_size`；失败线索仍在 active 且可再次出航、`attempts`
    累加；线索获得必为 1 级、连续调查 3 次到 2/3/4 且 target/credibility/search_zone
    不变、4 级再调查报错；`explore.start` 只扣工资、结算 / 失败 / 掉头按小时扣煤水的
    精确公式；沿途迷雾落账。
  - UI：`visible_routes()` 选中过滤；确认弹窗渲染/信号（策略默认 standard）；演出中
    `get_ship_vision_radius() > 0`、海图 `has_ship_vision()`；顶栏煤 / 水文本随演出下降、
    领域库存不变；`clue.investigate` 面板按钮/转发；详细总览无 `MapCanvas`。
  - 回归：全套 **325 例通过 / 0 失败**（新增/改写 17 例）。

## 9. 实现状态与验收截图（4.1 / 4.2）

**实现（2026-10-21）**

| 层 | 文件 |
|---|---|
| 规则 | `framework/domain/exploration/exploration_rules.gd`（读 `map_configs.data.exploration`，`discovery_chance` / `roll_succeeds` 单一真源） |
| 线索 | `framework/domain/exploration/clue_service.gd`（抵达传闻 / 购买情报 / 等级裁剪视图 / resolved·failed 生命周期） |
| 预览 | `framework/domain/exploration/exploration_calculator.gd`（绕陆航线、航速/煤水/工资/风险/发现概率、blockers） |
| 航次 | `framework/domain/exploration/explore_voyage_service.gd`（`start` / `settle` / `decide(continue, turn_back)`；4.2 起复用 `VoyageService.settle_arrival_services()` + 自动存档） |
| 演出模型 | `framework/domain/voyage/voyage_presentation.gd`：4.2 新增 `force_arrival()`（告警掉头直接入港；`skip()` 语义不变） |
| 命令/查询 | `framework/application/commands/explore_commands.gd`（`explore.start/settle/decide`、`clue.buy`）；`sea_chart.view` 追加 `clues/explore/can_buy_clue` |
| UI | `sn_sea_chart_view` 线索层 + 未知终点、`sn_sea_chart_panel` 线索区块、`sea_chart_screen` 信号转发、`at_sea_screen` 探索终点、`settlement_screen` 探索结果块、`main.gd` Shell 接线（4.2 资源告急页 + 继续/掉头） |
| 内容/本地化 | `dev_mods/core/content/map_configs.json` 的 `exploration` 块 + `schemas/v2/map_config.schema.json`；框架 `zh_CN/en` 的 `ui.clue.*` / `ui.explore.*` / `ui.button.*` 键 |

**验收截图**（1440×900，`tools/godot/capture_exploration.gd` 窗口模式生成，两次运行证据逐字一致）

| 截图 | 验证内容 |
|---|---|
| [exploration_chart_clues.png](screenshots/exploration/exploration_chart_clues.png) | 海图线索层：level 2 参照港方向箭头、level 3 虚线圆、level 4 `？渔村？` + 选中高亮；右侧面板来源/等级/方位/航程区间/预计煤水风险/可出航性 |
| [exploration_chart_route.png](screenshots/exploration/exploration_chart_route.png) | 探索航行：金色计划航线 + 到 `?` 终点的虚线预测线（`?` 被顶栏挡住时 clamp 到可见区）；顶栏「探索中 → ？」；底部航程条 `铁港 → ？` |
| [exploration_resource_alert.png](screenshots/exploration/exploration_resource_alert.png) | **4.2 资源告急页**：航程 50% 停下，「资源告急」+ 煤/水/耐久 +「继续探索 / 掉头返航」，跳过演出不可用 |
| [exploration_turned_back.png](screenshots/exploration/exploration_turned_back.png) | **4.2 掉头结算**：回出发港、线索保留、额外煤水损耗、结算显示「掉头返航」 |
| [exploration_alert_continue.png](screenshots/exploration/exploration_alert_continue.png) | **4.2 继续路径**：同一线索告警后选「继续探索」→ 正常 settle 并发现新港口（目标港仍隐藏到结算） |
| [exploration_result_found.png](screenshots/exploration/exploration_result_found.png) | 发现：结算页探索区块（发现新港口 / 抵达港口 / 线索已解决），原委托结算布局不变 |
| [exploration_result_failed.png](screenshots/exploration/exploration_result_failed.png) | 4.3 起失败：红色「探索失败」、漂流回铁港、额外煤水/耐久损耗、延误 6h、**线索保留（可再次出航）** |
| [exploration_arrival.png](screenshots/exploration/exploration_arrival.png) | 另一次真实发现的结算页（与 found 证据不同，验证不是同一帧） |
| [exploration_chart_investigate.png](screenshots/exploration/exploration_chart_investigate.png) | 4.3.2：选中 2 级线索，面板显示「下一级：已知航程」与「调查线索」按钮 |
| [exploration_depart_confirm.png](screenshots/exploration/exploration_depart_confirm.png) | 4.3.4：海图内出航确认弹窗（预估 / 锅炉策略切换 / 取消 / 启航） |

**测试**：领域 `test_exploration`、UI 线索/演出/结算/告警与 E2E、海图几何、presentation；
4.3 完成后全套 **325 例通过 / 0 失败**（4.3 新增/改写 17 例，明细见 §10.5）。

**4.2 已知边界**：探索中的事件化海洋（敌对/环境/奖励）归阶段 5，与其共享事件暂停/恢复机制；
货物类线索、`expires_at` 时效、在港等待/委托解锁线索留给 4.3；资源告急仅覆盖煤/水
（4.2 探索途中没有耐久损耗来源，耐久告急等阶段 5 的敌对/环境事件接入后再补）。

## 10. 4.3 探索体验修正（Implemented，2026-10-21）

> 状态：**4.3.1–4.3.5 已全部实现并验收**（2026-10-21，按 §10.3 顺序逐片提交全量测试）。
> 玩家实机体验后提出 8 条问题，逐条已定位根因；本节保留实施清单与验收口径，
> 数值走 Core JSON（`map_configs` 的 `exploration` 块，schema 同步扩展），
> 不触碰 Content Schema 2.0。实现台账见 §10.5。

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
   比例放进 Core `map_configs.exploration`；`CampaignFactory` 的双子世界尺寸也从内容读取
   （`twin_world_size`），不再硬编码 160。迷雾网格 `cell_size = vision_radius / 4`
   随之缩放。**实际取值**：`fog_port_reveal_ratio = fog_vision_ratio = 0.05`
   （160 世界下 8 / 8，泊位揭示直径 16 = 世界 10%，满足 §10.3 验收）。
   最初建议的 `0.075 / 0.05` 会让揭示直径达到 15%，与验收口径冲突，以验收为准取 0.05。
5. **出航策略**：海图内的出航确认弹窗提供锅炉策略切换，**默认上一次选择**
   （Shell 记忆；无记忆时用 `strategy.standard` tag 解析，不写 `core:*` 字面量）；
   弹窗同时显示距离 / 预计时间 / 煤水 / 风险 / 可行性 blockers。

### 10.3 实施切片（按顺序完成）

| 切片 | 内容 | 验收口径 | 状态 |
|---|---|---|---|
| **4.3.1 海图观感与线索规则** | U1 雾比例 + 世界尺寸内容化；U3 失败不消耗线索（记 `attempts` / `last_attempt_at`，可再探索）；U5 航线仅在选中港口时显示；U6 删除详细总览旧海图 | 160 世界下泊位雾直径 ≤ 世界 10%；失败后线索仍在 active 且可再次出航；未选港口时海图无线（演出计划航线除外）；详细总览无 `map_canvas` | ✅ 已实现 |
| **4.3.2 线索逐级升级** | U2 + `clue.investigate` 命令（等级 +1，上限 4）；面板「调查线索」与下一级预告；获得永远 1 级；Core 预留消耗字段（0） | 新线索必为 level 1；连续调查 3 次依次到 2/3/4；目标港/搜索区/可信度不变；查询仍按等级裁剪 | ✅ 已实现 |
| **4.3.3 随船照亮** | U4 演出层 `SNSeaChartView.set_ship_vision()` 软圆；抵达/掉头时按实际航线采样 `FogOps.trace_route` 持久化沿途迷雾 | 演出中船周有连续照亮；结算后存档里航线沿海岸为 EXPLORED；旧存档无 world_map 时 no-op | ✅ 已实现 |
| **4.3.4 出航流程重构** | U7 删除 `voyage_screen` 与导航/招牌入口；海图港口面板「启航」+ 线索面板「循线索出航」统一打开确认弹窗（预估 + 策略切换 + 取消/启航）；确认后直接 `voyage.start` / `explore.start` | 导航无「出航」；从海图两处入口都能完成出航；策略默认上次选择且可切换；可行性 blockers 在弹窗内可见 | ✅ 已实现 |
| **4.3.5 连续消耗** | U8 出发只扣工资；状态存 `departure_coal/water` + 每小时费率；顶栏按 `elapsed_hours` 连续刷新；结算/漂流/掉头按实际小时落账；事件延误补算 | 出发后船库不变；演出中读数随进度下降；抵达后扣减=实际小时×费率；掉头扣实际半程+额外；告警仍按预判触发；存档在结算后为最终值 | ✅ 已实现 |

每片完成后跑全量测试 + 相关窗口截图；全部做完后更新本文 §10 状态、
[NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md) 的对应段落、README/CHANGELOG/todo，并重生成静态文档。

### 10.5 实现台账（2026-10-21）

| 切片 | 主要文件 | 验证 |
|---|---|---|
| 4.3.1 | `ExplorationRules.fog_radii()`、`FogOps`（内容半径入参）、`RunFactory`（`twin_world_size` + 布局缩放）、`ClueService.mark_attempt_failed()`、`ExploreVoyageService` 失败分支、`SNSeaChartView.visible_routes()`、删除 `map_canvas.gd/.tscn` 与总览海图块 | `test_exploration` 雾比例/失败保留/再出航、`test_sea_chart` 选中过滤、`test_ui_shell` 无 MapCanvas |
| 4.3.2 | `ClueService.investigate()` / `clue.investigated`、`clue.investigate` 命令、`sea_chart.view` 调查字段、面板「调查线索」+ 下一级预告、5 个本地化键 | 获得必为 1 级、3 次调查到 2/3/4、目标/可信度/搜索区不变、4 级报错、查询裁剪、存档往返 |
| 4.3.3 | `SNSeaChartView.set_ship_vision()` / `ship_vision_rings()`、`AtSeaScreen` 每帧推半径、`FogOps.trace_route()`、探索 settle/turn_back 与普通抵达落账 | 软圆半径单调衰减、演出 `has_ship_vision()`、航线沿海 EXPLORED、legacy no-op |
| 4.3.4 | 删除 `voyage_screen.gd/.tscn`；`SNVoyageConfirm`（新）、`SeaChartScreen` 叠层、面板统一 `departure_requested`、Shell `_chart_departure*` / `_chart_departure_model()`、导航/招牌/状态条改「海图」 | 导航无出航、两处入口打开弹窗、策略默认上次/可切换、blockers 可见、确认后启动演出 |
| 4.3.5 | `VoyageService.start/_complete_arrival`（费率落账）、`ExploreVoyageService`（成功/失败/掉头按小时扣）、Shell `_update_presentation_resources()` / 具名煤水 chip | 出发只扣工资、顶栏读数连续下降、结算扣减=费率×实际小时、事件延误计费 |

**实现中的决策偏差**

- 雾比例取 `0.05 / 0.05`（不是原建议 0.075 / 0.05），以满足「160 世界泊位雾直径
  ≤ 10%」的验收口径。
- 掉头 / 漂流先按费率扣实际小时，再扣原有的额外损耗（`summary.extra_*` 仍只表示额外那笔）。
- 无事件的普通航段沿用阶段 3 架构：`voyage.start` 内同步结算抵达（按实际小时扣款），
  因此「出发后船库不变」只在有事件、演出真正中断的航段可观测；有事件航段已按
  「出发只扣工资 → 演出插值读数 → 结算一次性落账」执行。

### 10.4 仍未定 / 后续迭代

- 线索调查的具体消耗（金币/时间/成功率/上限）——等线索系统下一轮迭代定；
  4.3 已在 Core 预留 `investigation_cost` / `investigation_hours`（0）与命令/查询形状。
- 货物类线索（`port_goods`）与 `expires_at` 时效、在港等待/完成委托解锁线索。
- 耐久告急（需要阶段 5 的敌对/环境事件造成途中损伤）。
- en locale 收尾（结算页/事件页既有硬编码中文）。
- 无事件普通航段的结算时机（当前阶段 3 架构在 `voyage.start` 内同步抵达；若后续要让
  「命令返回时库存不动、抵达拍才落账」，需要改航行演出状态机接线）。
- 旧 `map_canvas` 已删除；`map.view` 仍被港口名查询使用，保留。
- `level_weights` 目前保留但不再参与获得等级，等线索系统下一轮再决定复用或移除。

## 11. 阶段 4.4 线索扩展（Implemented，2026-10-21）

> 状态：**4.4.1–4.4.5 已全部实现并验收**（2026-10-21，分片提交 + 每片全量测试）；玩法
> 决策见 §11.6，验收截图见 §11.8。4.4 只做线索系统扩展，不碰阶段 5 事件化海洋、
> 耐久告急与 en locale 收尾；数值全部进 Core JSON，框架不写死内容 ID / 可调数字。

### 11.1 范围

**4.4 交付**

1. **`port_goods` 货物类线索**：指向已发现港口 + 一种该港可买货物，披露该港行情
   （价格 / 供需 / 库存），按等级逐级披露，**有时效**；不参与 `explore.start`
   的搜索区判定，走普通 `voyage.start` 前往。
2. **`expires_at` 时效**：货物线索按游戏小时到期；到期后从 active 移入
   `data.clues.expired`（保留历史），释放 `max_active_clues` 名额；查询侧同时过滤。
3. **新来源**：在港等待（`port.wait`）解锁线索；完成委托（普通 / 主线）解锁线索。
   两者都走命名随机流、受上限约束、可配置概率。
4. **调查消耗真正落地**：`clue.investigate` 从「只涨等级」改成消耗金币 + 在港时间 +
   成功率判定（数值来自 Core）；失败照扣成本但不升级、线索保留可再试。
5. **线索列表页**：独立页面列出全部 active 线索（类型 / 来源 / 等级 / 剩余时效 /
   可调查状态），可点击回到海图并选中；过期条目折叠灰显。

**不在 4.4**：探索途中事件化海洋（阶段 5）、耐久告急、线索分享 / 交易、多人 / 成就、
`level_weights` 复用、线索内容 JSON 化（仍由「世界 + 内容数据 + 规则」推导，
框架不写死 `core:*` 内容 ID）。

**不回归的 4.3 不变量**（4.4 每片验收都必须守住）

- `sea_chart.view.clues` **任何类型、任何等级**都不含 `target_port_id`、
  `credibility`、真实 `search_zone`；港口位置线索的分级裁剪不变
  （level < 4 无 `name_key`，level < 3 无 `circle`，level 1 无方向）。
- 线索获得固定 1 级，只能靠 `clue.investigate` 逐级推进（上限 4）；目标港 / 可信度 /
  搜索区在获得时固定，调查只披露不重抽。
- 探索失败不消耗线索（只记 `attempts` / `last_attempt_at`），线索保留且可再次出航；
  失败漂流、逐级调查、雾半径比例、连续消耗、普通航线选中过滤全部保持。
- 查询只读（`QueryBus` 克隆）、命令事务提交（失败不落状态、成功发领域事件）。

### 11.2 数据模型（`GameState.data`，全部可 JSON 化，惰性 ensure，不改 `schema_version`）

`Clue` 在 4.3 形状上追加（旧字段不删不改名）：

```text
Clue = {
  ...§2 的 4.3 全部字段...,
  type: "port_location" | "port_goods",
  # port_goods 专用；港口位置线索恒为空串 / null
  target_goods_id: String,             # 仅领域层知道完整快照；查询按等级裁剪
  goods_snapshot: null | {             # 获得时冻结的行情快照，不随后市变化
    port_id: String,
    good_id: String,
    buy_price: int,                    # 玩家在该港买入的单件价（回合后）
    sell_price: int,                   # 玩家在该港卖出的单件价（floor(margin)）
    stock: int,                        # 该港可买库存
    demand: String,                    # "high" | "normal" | "low"，由价格偏离 base 推导
    recorded_at: float,                # 快照时间
    price_error_ratio: float,          # 获得时冻结的报价误差比例（来自 Core）
  },
  expires_at: float,                   # 游戏小时；0.0 = 永久（port_location 恒为 0）
  source_key: "rumor" | "intel" | "wait" | "contract",
  source_display_key: String,          # "ui.clue.source.<key>"
  unlock_source: String,               # "wait:<hours>" / "contract:<instance_id>"，仅追溯用
}
data.clues = {
  next_id, active, failed, resolved,
  expired: [Clue],                     # 4.4：已过期线索的整条快照（历史，不占上限）
}
```

- **惰性 ensure**：`GameState.ensure_clues()` 保持现有结构，另把 `expired` 缺省补 `[]`；
  `ClueService.normalize_clue(clue)` 在读取 active 时把旧存档条目补齐
  `type="port_location"` / `target_goods_id=""` / `goods_snapshot=null` /
  `expires_at=0.0` / `unlock_source=""`。只补内存字典，不改 `schema_version`。
- **到期清理**：`ClueService.sweep_expired(state, now)` 把 `expires_at > 0 且 <= now`
  的 active 条目（连同 `goods_snapshot`）移入 `expired`，返回被清理的 id 数组。
  只在**命令路径**调用（`port.wait`、`settle_arrival_services` 覆盖所有抵达路径、
  `clue.buy` / `clue.investigate` / `explore.start` / `clue.list` 之外的入口），
  查询侧只过滤不写状态。
- **上限**：`max_active_clues` 只数「active 且未过期」；到期后立即释放名额。
- `goods_snapshot` 的 `buy_price` / `sell_price` 使用与贸易查询相同的公式
  （`round(price)` / `floor(price × trade_margin)`），`demand` 由 `price / base_price`
  分档（≥1.15 high、≤0.9 low、其余 normal），`stock` 取市场条目 `stock`。
- 候选目标（领域推导，不写死内容 ID）：**已发现、非当前港**的港口；货物候选 = 该港
  `state.market()[port_id]` 里 `buyable=true` 且非补给商品的条目，按 item id 排序后
  用命名流抽取；同一条 active 线索不重复指向同一 `(port_id, good_id)`。

### 11.3 查询 / 命令形状

**查询**（新增必须经 `QueryRegistry` → `FrameworkApi` 注册，并补测试）

- `clue.list`（新增）：只读线索列表。

  ```text
  {
    now: float, max_active: int, active_count: int,
    clues: [{
      id, type, source_key, source_display_key, level, next_level,
      next_level_key, direction_angle, distance_min_hours, distance_max_hours,
      circle: null | {x, y, radius}, name_key,            # 与 sea_chart 同裁剪
      target_goods_id,                                    # port_goods 公开字段
      goods: null | {                                     # 按等级裁剪的行情
        port_name_key,                                    # 1 级起
        buy_price_min, buy_price_max,                     # 2 级起（参考价区间）
        sell_price_min, sell_price_max,
        stock, demand,                                    # 3 级起
        buy_price, sell_price,                            # 4 级（精确）
      },
      expires_at, remaining_hours, is_expired,            # port_location 恒 0 / -1
      attempts, last_attempt_at,
      investigation_cost, investigation_hours, investigation_success_chance,
      can_investigate, can_sail,
    }],
    expired: [{id, type, level, source_key, source_display_key, expires_at,
               target_goods_id, port_name_key}],
  }
  ```
- `sea_chart.view.clues` 追加（**不删旧字段**）：`type`、`target_goods_id`、
  `goods`（按等级裁剪，形状同上）、`expires_at`、`remaining_hours`、`is_expired`。
  端口位置线索的 `goods` 恒为 `null`，其余字段与 4.3 完全一致（回归测试锁死）。
- `sea_chart.view` 可选追加 `expiring_clue_count`（列表页入口角标用），不改变旧字段语义。

**命令**（`command_registry.gd`；新增必须经 `FrameworkApi`）

| 命令 | 参数 | 4.4 行为 |
|---|---|---|
| `clue.investigate` | `{clue_id}` | 扣 `investigation_cost` 金币、推进 `investigation_hours`、按 `investigation_success_chance` 判定；成功 `level+1`（事件 `clue.investigated`），失败不升级但扣成本（事件 `clue.investigation_failed`），线索保留 |
| `clue.travel` | `{clue_id, strategy_id}` | 4.4.2 新增：对 `port_goods` 线索执行普通 `VoyageService.start` 前往其（已发现的）目标港；不泄露 target id，目标在领域层解析 |
| `clue.buy` | `{}` | 不变；默认 `goods_clue_source_weights.intel = 0`，仍只出港口位置线索（权重 > 0 时按权重出 `port_goods`） |
| `port.wait` | `{hours}` | 时间推进后调用 `ClueService.on_wait(context, hours)`；可能获得线索并附 `clue.acquired` 事件 / notice |
| 抵达服务 | — | `VoyageService.settle_arrival_services` 在委托结算后调用 `ClueService.on_contract_completed(context, completed)`；可能获得线索 |

`clue.investigate` 成功 / 失败返回体：

```text
{ success: bool, clue_id, level, next_level, cost, hours, success_chance,
  charged: bool, roll: float,          # roll 0..1，仅用于测试复现（不进 UI）
  view: {...} }                        # 成功时为升级后的 view_entry
```

**事件 / notice**

```text
clue.acquired          已存在（payload 仅 clue_id / source_key / level）
clue.investigated      成功升级（payload 仍只有 clue_id / level）
clue.investigation_failed  失败（payload clue_id / level / cost / hours）
clue.expired           sweep 清理时批量发出（payload clue_ids / count）
ui.notice.clue_expired / ui.notice.clue_investigation_failed / ui.notice.goods_clue_acquired
```

### 11.4 Core JSON 与 Schema

`dev_mods/core/content/map_configs.json` 的 `data.exploration` 追加（框架只读规则），
并同步 `schemas/v2/map_config.schema.json`（`exploration` 是
`additionalProperties: false`，每个新键都要声明；数值范围按语义给 `minimum/maximum`）：

```json
"investigation_cost": 20,
"investigation_hours": 6.0,
"investigation_success_chance": 0.75,
"goods_clue_expiry_hours": {"rumor": 24.0, "intel": 72.0, "wait": 48.0, "contract": 72.0},
"goods_clue_price_error_ratio": 0.15,
"goods_clue_source_weights": {"rumor": 0.0, "intel": 0.0, "wait": 1.0, "contract": 0.0},
"wait_clue_hours_block": 6.0,
"wait_clue_chance_per_block": 0.35,
"wait_clue_max_chance": 0.85,
"contract_clue_chance": 0.5
```

- `goods_clue_source_weights` 决定哪个来源出货物线索（其余来源仍只出港口线索），
  权重 0 表示不产出；缺失 / 非法时按框架兜底（`wait` 出货物、`contract` 出港口）。
- `investigation_*` 三个键在 4.3 已预留；4.4 起 `cost > 0` / `hours > 0` /
  `chance < 1` 才真正生效，`0 / 0 / 1.0` 表示保持 4.3 行为（内容可回退）。
- 等待线索概率按档位复利：`1 - (1 - per_block) ^ (hours / block)`，
  再与 `wait_clue_max_chance` 取小；等待小时数向下取整到档位。
- 所有数值仍集中在 Core；`ExplorationRules.DEFAULTS` 同步键（防御兜底），
  但正常内容必须覆盖。

### 11.5 实施切片与验收口径

| 切片 | 内容 | 验收口径 | 状态 |
|---|---|---|---|
| **4.4.1 数据模型 + 时效 + 查询裁剪** | `Clue` 扩展字段；`GameState.ensure_clues` 的 `expired` 与旧条目 normalize；`ClueService.sweep_expired` / `normalize_clue`；`sea_chart.view.clues` 追加字段（含 goods 分级裁剪）；`clue.list` 查询注册；`max_active_clues` 只数未过期 | 旧存档线索自动补齐且 `schema_version` 不变；`expires_at<=now` 只在命令路径清理并进 `expired`、名额释放；查询对任意类型/等级不含 `target_port_id`/`credibility`/真实 `search_zone`；port_location 视图与 4.3 逐字段一致；存档 round-trip 哈希一致 | ✅ 已实现 |
| **4.4.2 新来源（在港等待 / 完成委托）** | `ClueService.on_wait` / `on_contract_completed` / `wait_clue_chance` / `acquire_goods` 来源权重 / `travel`；`PortCommands.wait` 与 `VoyageService.settle_arrival_services` 接线；`clue.travel` 命令 + 海图面板货物区块 /「前往该港」/ 统一确认弹窗（kind=goods）；事件 / notice / 本地化 | 等待概率 = `1-(1-p)^(hours/block)` 且封顶；委托完成按 `contract_clue_chance` 抽取；来源为 `wait`/`contract`、可信度落在对应区间；受 `max_active_clues` 约束、无可用目标时静默返回；同 seed 可复现；不阻断等待 / 抵达；`clue.travel` 在领域层解析目标港并走普通航线，查询仍不泄露 target id；货物线索面板显示分级行情 / 时效 / 前往按钮 | ✅ 已实现 |
| **4.4.3 调查消耗真正落地** | `ClueService.investigate` 扣金币 + 推进小时 + 成功率；在港时间效果抽到新领域服务 `PortTimeService.spend`，与 `port.wait` 共用（打造订单 / NPC 市场 / 逾期债务）；`clue.investigate` 返回体与查询字段（`investigation_success_chance` / `can_afford_investigation`）；面板显示成本 / 工时 / 成功率 | 成功：金币 -cost、时间 +hours、level+1；失败：金币照扣、时间照进、level 不变、线索 active 可再试、事件 `clue.investigation_failed`；金币不足在扣费前 `Result.fail`；工时内线索到期返回 `expired` 且不发升级事件；4 级再调查报错不变；`investigation_cost/hours/chance` 为 0/0/1 时行为与 4.3 一致 | ✅ 已实现 |
| **4.4.4 线索列表页** | 新页面 `clue_log_screen`（场景 + 脚本）+ Shell 接线（`clue_log` flow 子页）+ 海图顶栏入口按钮；列 active 线索（类型 / 来源 / 等级 / 剩余时效 / 可调查）/ 过期折叠区；点击条目回海图并选中；空态文案 | 页面只读 `clue.list`，不自行计算规则；剩余时效与 `expires_at` 一致、过期条目在折叠区；点击线索回到海图并选中该 id；无泄漏字段；本地化键中英同步；960×540 与 1440×900 不裁切 | ✅ 已实现 |
| **4.4.5 测试 / 截图 / 文档收尾** | 全量测试（基线 325，0 failed）；`tools/godot/capture_clue_expansion.gd`（新增专用 capture）抓货物线索面板 / 前往确认 / 调查成本 / 调查结果 / 线索列表 5 张图；§11 回填、§7 更新、README / todo；静态文档重生成 + `--check`；分片提交 | 全量 `Tests:` 0 failed；5 张截图两次运行 SHA256 逐字一致并落 `docs/design/screenshots/exploration/`；`gen_static_docs.mjs --check` 通过；每片 commit 只含本片文件 | ✅ 已实现 |

每片完成后的固定动作：实现 → 全量测试（0 failed）→ 相关窗口截图 → 更新本节 / 台账 →
只提交本片文件。全部完成后统一重生成静态文档并报告并行未提交文件的影响。

### 11.6 已确认决策（2026-10-21，全部选推荐项 A）

用户已确认五项玩法细节，实现以下决策（数值全部进 Core JSON / Schema）：

1. **`port_goods` 披露**：目标 = **已发现港口 + 货物**（同一 `(port, good)` 不重复
   出现在 active）；1 级披露港口名与「有行情」、2 级参考价区间（买 / 卖各一组，
   误差 = `goods_clue_price_error_ratio × (1 - credibility)`）、3 级加库存与供需档、
   4 级精确买入 / 卖出价。**不走 `explore.start`**（目标是已发现港口，没有搜索区），
   面板 / 列表页的「前往该港」走普通航线（`clue.travel`，4.4.2）。
2. **时效**：游戏小时、按来源 `goods_clue_expiry_hours` = 传闻 24 / 等待 48 /
   情报 72 / 委托 72；到期后由命令路径 `sweep_expired` 移出 active，**整条快照**
   进 `data.clues.expired` 供列表页灰显历史，并释放 `max_active_clues` 名额。
3. **新来源**：在港等待每 `wait_clue_hours_block = 6h` 一档、每档 35%（复利，
   24h ≈ 87%，封顶 85%），优先出**货物线索**（没有货物候选时退回港口位置线索）；
   每完成 1 份普通 / 主线委托按 `contract_clue_chance = 50%` 出**港口位置线索**。
   两者都受 `max_active_clues` 与「无可用目标」约束，静默失败、不阻断原流程。
4. **调查消耗**：每次 **20 金 + 在港 6 小时 + 75% 成功率**；失败照扣成本和时间、
   不升级、线索保留可再试；三个数值全部来自 Core，可回退为 `0 / 0 / 1.0`
   （4.3 行为）。
5. **线索列表页**：海图页新增「线索列表」按钮打开独立页；列全部 active 线索
   （类型 / 来源 / 等级 / 剩余时效 / 状态 / 可调查），点击条目回海图并选中；
   过期线索折叠灰显。顶部导航不新增一级页面。

### 11.7 实施台账（4.4，逐片回填）

| 切片 | 主要文件 | 验证 |
|---|---|---|
| 4.4.1 | `GameState.CLUES_DEFAULTS.expired`、`ClueService`（`normalize_clue` / `is_expired` / `active_count` / `sweep_expired` / `acquire_goods` / `goods_candidates` / `_goods_view` / `expired_events_of`）、`SeaChartViewQuery`（`expiring_clue_count`、goods 跳过探索估算、active_count 上限）、`ClueListViewQuery`（新）+ `QueryRegistry`、`ExplorationRules.DEFAULTS`、Core `map_configs.exploration` + `v2/map_config.schema.json`、`PortCommands.wait` / `VoyageService.settle_arrival_services` / `ExploreVoyageService.start` 的 sweep 接线、中英本地化 27 键 | `test_exploration` 5 例（行情冻结与分级裁剪、过期 sweep 与名额、clue.list 形状与历史、旧存档 normalize、Core 新键）；全套 329 例 / 0 失败 |
| 4.4.2 | `ClueService`（`wait_clue_chance` / `on_wait` / `on_contract_completed` / `_acquire_by_source` / `travel`）、`PortCommands.wait`、`VoyageService.settle_arrival_services`、`ExploreCommands.travel` + `CommandRegistry`、`SeaChartViewQuery`（货物 travel 估算 / `can_sail`）、`SNSeaChartPanel`（货物区块 / 时效 / `SailButton`）、`SNSeaChartView`（货物线索不画几何）、`main.gd`（`kind=goods` 确认弹窗 + `clue.travel` 演出接线）、Core/`Schema` 的 `wait`/`contract` 可信度区间 | `test_exploration` 4 例（等待概率与真实获取、等待优先货物、委托完成钩子、`clue.travel` 成功与三类拒绝）；`test_sea_chart` 2 例（货物面板 / 无几何）；`capture_clue_expansion.gd` 两张截图；全套 335 例 / 0 失败 |
| 4.4.3 | `PortTimeService`（新，`port.wait` 与调查共用时间结算）、`ClueService.investigate`（扣费 / 工时 / 成功率 / 失败事件 / 工时内过期）、`ExplorationRules.roll_hits`、`PortCommands.wait` 重构、`sea_chart.view` + `clue.list` 的 `can_afford_investigation` / 调查成功率、`SNSeaChartPanel` 成本行与买不起禁用、Shell 调查失败状态、Core `investigation_*` = 20 / 6h / 0.75 | `test_exploration` 新增失败 / 金币不足用例并改写升级 / 查询 / 存档用例；`test_sea_chart` 成本显示与禁用；`capture_clue_expansion.gd` 两张 4.4.3 截图；全套 336 例 / 0 失败 |
| 4.4.4 | `clue_log_screen.gd/.tscn`（新）、`SeaChartScreen`（`clue_list_requested` + 顶栏按钮 + `preselect_clue_id`）、`main.gd`（`clue_log` flow 子页 / 查询接线 / 列表→海图选中 / M、Esc 返回）、中英本地化 `ui.clue.list.back` | `test_sea_chart` 新增 2 例（顶栏入口 + 预选线索、列表页 active/过期/点击/空态）；`capture_clue_expansion.gd` 列表页截图 + 回海图选中 round-trip；全套 338 例 / 0 失败 |
| 4.4.5 | `tools/godot/capture_clue_expansion.gd`（5 张图：货物面板 / 前往确认 / 调查成本 / 调查结果 / 线索列表，两次运行 SHA256 一致）、`README.md` / `todo.md` / 本文 §11 / `NAUTICAL_CHART_SYSTEM.md` §7、静态文档重生成 | 全套 **338 例 / 0 失败**（4.4 新增/改写 13 例 + 1 条 query 注册）；`gen_static_docs.mjs --check` 通过；5 张截图逐字一致 |

### 11.8 验收截图（4.4，1440×900，两次运行 SHA256 逐字一致）

工具：`godot --path . --resolution 1440x900 --script res://tools/godot/capture_clue_expansion.gd`
（窗口模式；命中 query 契约 / 面板文本 / 成本与结果 / 列表 round-trip 的硬断言后才落盘）。

| 截图 | 验证内容 |
|---|---|
| [clue_goods_lead.png](screenshots/exploration/clue_goods_lead.png) | `port_goods` 线索 4 级面板：类型「货物行情」、来源、港口名、参考价区间、库存 / 供需、精确买卖价、剩余 30h、「前往该港」；无 `ExploreButton` |
| [clue_goods_depart.png](screenshots/exploration/clue_goods_depart.png) | 「前往该港」统一确认弹窗（kind=goods）：标题、航线、距离 / 时间 / 煤水 / 风险、锅炉策略，确认后走 `clue.travel` 普通航线 |
| [clue_investigate_cost.png](screenshots/exploration/clue_investigate_cost.png) | 4.4.3 调查成本行「调查：20 金 · 6 小时 · 成功率 75%」+ 可用的「调查线索」按钮，下一级预告为货物等级文案「已知参考价」 |
| [clue_investigate_result.png](screenshots/exploration/clue_investigate_result.png) | 4.4.3 调查结果状态栏：真实命令后金币 840→820、时间 +6h，状态栏「线索调查完成：已升至 2 级」 |
| [clue_log.png](screenshots/exploration/clue_log.png) | 4.4.4 线索列表页：持有 2/4、两张 active 行情卡片（2 级参考价 / 4 级精确行情）、「已过期」折叠行；点击卡片回海图并在面板中选中该线索 |

**4.4 收尾结论**：4.4.1–4.4.5 全部实现；全套 **338 例通过 / 0 失败**（4.3 基线 325）；
查询裁剪不变量、失败保留线索、逐级调查、雾半径与连续消耗等 4.3 行为均由既有用例回归。
已知边界：货物线索只在「已发现、非当前港」的港口市场里生成（早期单港开局等待会退回
港口位置线索）；线索列表页是海图 flow 子页（不占顶部导航）；en 结算页既有硬编码中文
仍属阶段 4.3 已知边界，不在 4.4 范围。
