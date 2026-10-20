# 探索系统（阶段 4）实现契约 — 4.1 首切片

> 作用：把 [NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md) §5/§7 的探索与线索规则
> 落到可运行的第一切片。数值全部来自 Core JSON，框架只读规则。本文是实现契约，
> 与设计文档冲突时以设计文档的玩法意图为准、以本文的字段/命令形状为准。

## 1. 范围

**4.1 交付**：线索数据结构与 `ClueService`、抵达传闻 / 酒馆购买两条线索来源、
线索分级与海图可视化（方向箭头 / 虚线圆圈 / `？港口名？`）、`explore.start` 探索出航、
搜索区判定与发现概率、失败（线索作废 + 漂流到最近已知港）、发现（解锁港口 + 迷雾揭示 + 入港）、
探索演出接线与结算页。

**4.2（下一轮，本文预留字段但不做 UI）**：资源告急事件、掉头/继续决策、探索中事件化海洋。

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
  alert_needed: bool, alert_progress: float, alert_decided: String,
  outcome_roll: float,            # 0..1，出发时用命名流抽定；成功 = roll < chance
  status: "outbound",
}
data.voyage = { "kind": "explore", "status": "at_sea" }   # 仅作"在航"标记
```

- 探索期间 `data.voyage` 非空 → 既有 `is_at_port()` / `port.view.at_sea` / 贸易门禁自动生效。
- `explore.settle` / 掉头后同时清空 `explore_voyage` 与 `voyage`。

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
    alert_needed,
  },
}, events)
decide(context, choice)          # 4.2；4.1 允许 continue（清 alert）与 turn_back（立即结算返航）
settle(context) -> Result.ok({
  result: "discovered" | "failed",
  destination: port_id,          # 演出入港用的港口（目标港或漂流港）
  summary: { explore: {...}, destination, arrival_time, delayed_hours, injuries,
             contracts: [], ... },   # 兼容 settlement_screen 现有字段
}, events)
```

`start`：
- 前置：有 run、在港（`is_at_port()`）、线索 active、没有 `explore_voyage`、
  preview.feasible；扣工资与煤水（`add_money`/`record_expense`、`ship.coal/water`）。
- 写入 `explore_voyage` 与 `data.voyage` 标记；`at_sea` 标记不新增（用 `voyage` 判定）。
- `outcome_roll` 用命名流抽定；`alert_needed = coal_used >= coal_before*alert_threshold
  或 water_used >= water_before*alert_threshold`。
- 事件：`explore.started`（payload: clue_id/origin/duration_hours/coal_used/water_used）。

`settle`：
- 未出发 / 没有 explore_voyage → `Result.fail("not_exploring", "ui.error.not_exploring")`。
- 时间推进到 `arrival_time`；`stats.voyages += 1`。
- 成功（`outcome_roll < discovery_chance`）：
  - `WorldOps.discover_port_id` + `WorldOps.mark_visited` + `FogOps.reveal_arrival`；
  - `current_port_id = target`；线索 → resolved；
  - notices：`ui.notice.exploration_found`；事件 `explore.finished`（result=discovered）。
- 失败：
  - 线索 → failed；漂流：耐久 `-= drift_durability_loss`（≥0）、煤水各 `-= drift_extra_*`（≥0）、
    时间 `+= drift_hours`；目的地 = 距搜索区最近的**已发现**港口（通常出发港）；
  - notices：`ui.notice.exploration_failed`；事件 `explore.finished`（result=failed）。
- 成功/失败都给 `summary.explore = {result, port_id, port_name_key, clue_id,
  search_center:{x,y}, extra_coal, extra_water, durability_loss}`，
  并清空 `explore_voyage` 与 `data.voyage` 标记。

`decide("turn_back")`：额外消耗 `coal_used/water_used * turnback_extra_ratio`，时间前进
半个航程，目的地 = 出发港，线索保持 active，返回 `{returned: true, destination, summary}`；
`decide("continue")` 只标记 alert。4.1 的 Shell 不弹资源告急 UI（4.2 接）。

## 5. 命令 / 查询

命令（`command_registry.gd`）：

| 命令 | 参数 | 说明 |
|---|---|---|
| `explore.start` | `{clue_id, strategy_id}` | 见 §4 |
| `explore.settle` | `{}` | 演出抵达时由 Shell 调用 |
| `explore.decide` | `{choice}` | 4.2 UI 用；4.1 先给 turn_back 留口 |
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
  explore: {active: bool, clue_id: String}
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
    `VoyagePresentation`（`event_at = -1`）；航行页
    `AtSeaScreen.bind` 收到 `unknown_destination: {x, y, label_key}` 时，
    海图画虚线航线 + `?` 终点标记，航程条右侧显示 `？`（`ui.label.unknown_destination`）。
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
ui.error.not_at_port / .not_exploring / .unknown_clue / .clue_not_active
ui.error.already_exploring / .insufficient_money / .no_exploration_target
```

## 8. 测试验收

- 领域（新增 `framework/tests/cases/test_exploration.gd`，加入 `test_runner.SUITE_PATHS`）：
  线索等级/来源权重/可信度区间、无目标时不出线索、查询裁剪（不泄露 target/credibility）、
  抵达传闻按概率触发且命名流可复现、`clue.buy` 金币/设施/上限门禁、`explore.start`
  扣资源/写状态/在航门禁、`settle` 成功解锁港口 + 迷雾揭示 + current port + 线索 resolved、
  `settle` 失败线索 failed + 漂到最近已知港 + 耐久/煤水扣减、`decide("turn_back")` 回港且线索仍 active、
  存档 round-trip（`GameState.hash()` 前后一致）。
- UI：`test_sea_chart`（clues 出现在视图模型、图表几何、面板线索区块、探索信号）、
  `test_voyage_flow`（海图点击线索 → 演出到 settle → 结算页显示探索结果；成功与失败各一条）、
  `test_ui_shell`（`clue.buy` 按钮/入口）。
- 回归：既有 264 例全部保持通过。

## 9. 实现状态与验收截图（4.1）

**实现（2026-10-21）**

| 层 | 文件 |
|---|---|
| 规则 | `framework/domain/exploration/exploration_rules.gd`（读 `map_profiles.data.exploration`，`discovery_chance` / `roll_succeeds` 单一真源） |
| 线索 | `framework/domain/exploration/clue_service.gd`（抵达传闻 / 购买情报 / 等级裁剪视图 / resolved·failed 生命周期） |
| 预览 | `framework/domain/exploration/exploration_calculator.gd`（绕陆航线、航速/煤水/工资/风险/发现概率、blockers） |
| 航次 | `framework/domain/exploration/explore_voyage_service.gd`（`start` / `settle` / `decide(continue, turn_back)`） |
| 命令/查询 | `framework/application/commands/explore_commands.gd`（`explore.start/settle/decide`、`clue.buy`）；`sea_chart.view` 追加 `clues/explore/can_buy_clue` |
| UI | `sn_sea_chart_view` 线索层 + 未知终点、`sn_sea_chart_panel` 线索区块、`sea_chart_screen` 信号转发、`at_sea_screen` 探索终点、`settlement_screen` 探索结果块、`main.gd` Shell 接线 |
| 内容/本地化 | `dev_mods/core/content/map_profiles.json` 的 `exploration` 块 + `schemas/map_profile.schema.json`；框架 `zh_CN/en` 的 `ui.clue.*` / `ui.explore.*` / `ui.button.*` 键 |

**验收截图**（1440×900，`tools/godot/capture_exploration.gd` 窗口模式生成，两次运行证据逐字一致）

| 截图 | 验证内容 |
|---|---|
| [exploration_chart_clues.png](screenshots/exploration/exploration_chart_clues.png) | 海图线索层：level 2 参照港方向箭头、level 3 虚线圆、level 4 `？渔村？` + 选中高亮；右侧面板来源/等级/方位/航程区间/预计煤水风险/可出航性 |
| [exploration_chart_route.png](screenshots/exploration/exploration_chart_route.png) | 探索航行：金色计划航线 + 到 `?` 终点的虚线预测线（`?` 被顶栏挡住时 clamp 到可见区）；顶栏「探索中 → ？」；底部航程条 `铁港 → ？` |
| [exploration_result_found.png](screenshots/exploration/exploration_result_found.png) | 发现：结算页探索区块（发现新港口 / 抵达港口 / 线索已解决），原委托结算布局不变 |
| [exploration_result_failed.png](screenshots/exploration/exploration_result_failed.png) | 失败：红色「探索失败」、漂流回铁港、额外煤水/耐久损耗、延误 6h、线索已作废 |
| [exploration_arrival.png](screenshots/exploration/exploration_arrival.png) | 另一次真实发现的结算页（与 found 证据不同，验证不是同一帧） |

**测试**：领域 `test_exploration` 22 例、UI 线索/演出/结算与 E2E 9 例、海图船形朝向与
`?` 可见区 clamp 2 例；全套 **298 例通过 / 0 失败**。

**4.1 已知边界**：线索只做港口位置类（货物类 / 时效 / 调查方式留给后续）；资源告急事件
与掉头/继续的 UI 接线留给 4.2（领域 `explore.decide` 已可用并有测试）；探索结算暂不跑
委托 / 市场 / NPC 推进（与普通抵达的差别记录在 `explore_voyage_service.gd` 头注释）。
