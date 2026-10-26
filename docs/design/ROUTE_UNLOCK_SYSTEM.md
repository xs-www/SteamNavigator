# 航线解锁系统（Route Unlock System）

> 状态：**已实现 v1.0（2026-10-26）**。用户设计要求：「任意两港间均能通航，但航线不是
> 发现港口就能联通的，需要玩家用别的方式解锁。」
>
> 前置：世界已经是「海图唯一真相」（`state.data["world_map"]` 是唯一世界与唯一拓扑，
> `GameState.world()` 由 `ChartWorldProjection.from_chart` 派生），见
> [NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md) §4.1.1 与
> [WORLD_SCHEMA_V2_RUNTIME.md](WORLD_SCHEMA_V2_RUNTIME.md) §6.3.1。

## 1. 模型：物理连通 ≠ 可出航

| 层 | 真源 | 内容 |
| --- | --- | --- |
| 物理连通（几何） | `WorldMap.connectivity_graph / edges` | **完全图**：任意两港之间都有一条合法航线（5 港 = 10 条边），每条边有绘制路径、折线 `distance`、`base_risk`。生成期任一对算不出路径即本次世界生成失败重试，**不允许缺边 / 直线兜底**。 |
| 可出航（运行时） | `campaign_world.unlocked_route_keys` | 玩家**已测绘**（unlocked）的航线名册。物理上能走不等于玩家知道怎么走；只有名册里的 pair 才能被 `voyage.start` / `voyage.preview` / `clue.travel` 接受。 |
| 可见性（迷雾） | `discovered_port_ids` / `visited_port_ids` | 港口与海图的发现状态。**发现港口不解锁任何航线**；它只决定港口/航线能不能画在海图上、目的地列表是否展示。 |

由此：

- 「任意两港可通航」= 海图拓扑是完全图，不再有 MST / 补边 / `edge_density` 预算。
- 「航线需要解锁」= 出航前多一道运行时门禁，不改世界几何、不改距离/风险口径。
- 未解锁但两端都已发现的航线**仍然输出**到 `sea_chart.view`（带 `unlocked: false`），
  让海图画「未测绘」虚线、面板禁用启航；未发现的一端继续被迷雾隐藏。

## 2. 状态

```text
data.campaign.world.unlocked_route_keys = ["port_0|port_1", ...]
```

- 规范 pair key：`a|b`，两个港口 id 按字符串排序（`WorldOps.route_key(a, b)`），
  无方向、无重复。
- 新局由 `CampaignFactory` 显式写空数组；`GameState.CAMPAIGN_SECTION_DEFAULTS.world`
  也声明 `unlocked_route_keys: []`，旧存档惰性补空（= 什么都不解锁，与「旧档重开」
  提示一致，不做迁移）。
- 只存在 `GameState`（存档的一部分），注册表与世界几何不变；存档 round-trip 与
  `state.hash()` 逐字节一致。

### 2.1 WorldOps API（唯一读写入口）

| API | 语义 |
| --- | --- |
| `WorldOps.route_key(a, b) -> String` | 规范无向 pair key；任一 id 为空时返回 `""`。 |
| `WorldOps.is_route_unlocked(state, a, b) -> bool` | 名册是否含该 pair。 |
| `WorldOps.unlock_route(state, a, b) -> bool` | 解锁一条航线；仅「新解锁」返回 true（调用方可据此只发一次事件）。同港 / 空 id 忽略。 |
| `WorldOps.unlocked_neighbor_ids(state, port_id) -> Array[String]` | 从名册推出的已测绘邻港（按 id 排序），供目的地列表 / 测试使用。 |

## 3. 解锁来源矩阵

| 来源 | 触发点 | 行为 | 锁定测试 |
| --- | --- | --- | --- |
| ① 委托自带海图 | `ContractOps.generate_offer`（主线 + 普通委托生成） | 生成实例后立即解锁 `origin ↔ destination`。委托卡的「规划出航」永远可执行，不会出现「有委托但航线未测绘」。 | `test_route_unlock::test_new_run_unlocks_only_the_routes_its_contracts_carry` / `test_normal_offer_refresh_unlocks_each_generated_route` |
| ① 教学委托 | `StoryService._grant_tutorial_contract` | 教学模板生成（含 `destination: home` 覆盖、旅客改造）后，按**最终目的地**再解锁一次（幂等）。 | `test_tutorial_opening_unlocks_the_main_route` |
| ② 剧情效果 | 内容 `map_configs.story.stages[].effects[]` 的 `unlock_route` | `{from, to}` 两端支持语义 token：`current` / `home` / `contract_destination` / 具体港口 id；解析后解锁并（新解锁时）发 `chart.route_unlocked` 事件。 | `test_story_unlock_route_effect_resolves_semantic_tokens` |
| ③ 酒馆购买海图 | 命令 `chart.buy {port_id}`（Core `map_config.chart_cost`，默认 60 金） | 当前港有酒馆、目标已发现、非当前港、航线未解锁、金币足够 → 扣款 + 记支出 + 解锁 + 发 `chart.purchased` + 通知。 | `test_chart_buy_unlocks_the_route_charges_gold_and_survives_save_load` / `test_chart_buy_fails_cleanly_in_every_invalid_case` |
| 不解锁 | 发现 / 访问港口、购买线索 | 只改迷雾与可见性；线索出航仍要求航线已解锁。 | `test_new_run_unlocks_only_the_routes_its_contracts_carry` / `test_route_locked_blocks_preview_start_and_clue_travel` |

### 3.1 Core 内容挂接

| 内容 | 变化 |
| --- | --- |
| `core:map_config/standard` | 新增 `chart_cost: 60`；`story` 阶段补三条 `unlock_route`：`opening`（`current → contract_destination`）、`second_port`（`current → home`）、`passenger_run`（`current → contract_destination`）。 |
| `core:world_profile/default_world` | 删除 `edge_density`（完全图不再需要边预算）。 |
| 委托（main/normal） | 无需内容改动：生成即解锁，主线/普通模板共用。 |

Schema：`schemas/v2/map_config.schema.json` 新增 `chart_cost`（number ≥ 0）；
`schemas/v2/world_profile.schema.json` 删除 `edge_density`；
SNModMaker 嵌入式 bundle 已同步（`node SNModMaker/tools/sync-schemas.mjs`）。

## 4. 航行门禁

| 入口 | 未解锁时 |
| --- | --- |
| `voyage.preview` / `voyage.start`（`VoyageCalculator.preview`） | `Result.fail("route_locked", "ui.error.route_locked", {origin, destination})`。`voyage.start` 复用同一个 preview，命令层无法绕过。 |
| `clue.travel`（货物行情线索 → 普通航线） | 走 `VoyageService.start` → 同一 preview，同样返回 `route_locked`。 |
| `explore.start`（未知海域探索） | **不受限**：探索就是找新航线/新港口；它有自己的线索与搜索区规则。 |
| `map.view` | `routes` 只列已解锁航线。 |
| `port.view.destinations` | 只列当前港的**已解锁**邻港。 |
| `sea_chart.view` | 每条 route 追加 `unlocked: bool`；两端都已发现的边全部输出（含未解锁），未发现的一端仍隐藏。 |
| `tavern.view` | 追加 `chart_cost` 与 `chart_offers[]`（每个已发现、非当前港：`port_id / name_key / cost / unlocked / can_buy / reason_key`）。 |

## 5. 命令：`chart.buy {port_id}`

注册：`CommandRegistry` → `ChartCommands.buy`；查询价签：`ChartCommands.chart_cost`。

门禁顺序（先便宜后昂贵，任一步失败都返回结构化 `Result.fail`，事务不提交）：

1. 无航程 → `no_run`（`ui.error.no_run`）
2. 不在港 → `not_at_port`
3. 空 / 未知港口 → `unknown_port`
4. 目标 = 当前港 → `same_port`
5. 世界表没有该 pair（防御）→ `no_route`
6. 目标未发现 → `port_not_discovered`（`ui.error.port_not_discovered`）
7. 当前港无酒馆（`MapOps.has_tavern`，兼容旧存档 `intel` 设施）→ `no_tavern`（`ui.error.no_tavern`）
8. 航线已解锁 → `route_already_unlocked`（`ui.error.route_already_unlocked`）
9. 金币 < `chart_cost` → `insufficient_money`（`ui.error.insufficient_money`）

成功：`add_money(-cost)` + `record_expense(cost)` + `WorldOps.unlock_route` + 通知
`ui.notice.chart_purchased` + 事件 `chart.purchased {from, to, cost, money}`。

> 价格来自内容 `map_config.data.chart_cost`（Core 60），框架常量
> `ChartCommands.DEFAULT_CHART_COST` 只作旧内容的兜底。

## 6. UI

| 位置 | 表现 |
| --- | --- |
| 海图视图（`SNSeaChartView`） | 已测绘航线按原有实线画；未测绘（两端已发现）的航线用 `COLOR_ROUTE_LOCKED` **虚线**画，距离标注照旧。 |
| 海图右侧面板（`SNSeaChartPanel`） | 选中未测绘航线时显示「未测绘航线：在酒馆购买海图解锁」（`ui.chart.route_locked_hint`）并**禁用**「启航」；`DepartButton` 始终存在，可用性只由 `route_data.unlocked` 决定。 |
| 酒馆页（`TavernScreen`） | 新增「海图（航线解锁）」区块：`tavern.view.chart_offers` 每行一个已发现港口；未解锁显示「海图价格：N 金币」+「购买海图」按钮（发 `chart.buy {port_id}`），已解锁显示「已测绘」。按钮可用性完全由查询的 `can_buy` / `reason_key` 决定。 |
| 出航确认弹窗（`SNVoyageConfirm`） | 未解锁航线不会进入弹窗（面板按钮禁用）；若命令仍被调用，`voyage.preview` 失败的 `blockers` / 错误键会按既有机制显示。 |

本地化键：`ui.chart.route_locked_hint`、`ui.error.route_locked`、
`ui.error.route_already_unlocked`、`ui.error.port_not_discovered`、`ui.error.no_tavern`、
`ui.tavern.chart_title / chart_hint / chart_empty / chart_cost / chart_buy / chart_unlocked`、
`ui.notice.chart_purchased`（中英双语）。

## 7. 确定性 / 存档

- 解锁名册只由命令 / 剧情 / 委托生成顺序决定；同 seed + 同命令序列 → 同名册。
  完全图拓扑本身不含 RNG（`base_risk` 仍按 `route_template:<pair>` 命名流）。
- 名册在 `data.campaign.world` 内随存档保存；`GameState.ensure_campaign_sections()`
  对旧档补空数组，不重排世界。
- 旧档兼容：没有名册的旧档 = 一条航线都没测绘；开发期不做旧档补解锁迁移。

## 8. 边界与后续

- 「未解锁航线在海上模式的表现」：本轮只做「海图可见 + 不可启航」；航行中不可能停在
  未测绘航线上（门禁在出发前）。未来若做「漂流到未知港口」等强制移动，应视为
  探索/剧情事件直接落港，不经过普通出航门禁。
- 剧情阶段编号沿用现有 20 阶段表（`opening / second_port / passenger_run` 只加效果，
  不改阶段数量与顺序）。
- 完全图让 `MapOps.bfs_distances` 对所有 pair 恒为 1：委托内容里的
  `min_route_edges / max_route_edges` 目前全为 1，仍按原语义求值；若未来内容写
  `≥2`，在完全图上将没有候选（属于内容约束问题，不在框架兜底）。
