# `framework/application/queries/sea_chart_view.gd`

> 作用：为可缩放 2D 海图生成只读视图模型（`sea_chart.view`），输出世界边界、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SeaChartViewQuery` | L1 |
| `DEFAULT_MIN_VISION_RADIUS` | L47 |
| `DEFAULT_PORT_REVEAL_RADIUS` | L48 |
| `execute(params: Dictionary, context) -> Dictionary` | L51 |

陆地多边形、按发现等级分类的港口、已知航线、降采样迷雾网格与船只位置。

- 关键依赖：`WorldOps`、`FogGrid`、`RouteCalculator`、`Landmass`、`GameState.campaign_world()`

## 契约与约束
- 只在 `has_run=true` 且 `world_map` 非空时输出完整数据，否则返回空结果。
- 港口列表只包含已发现港口；未发现的港口被过滤掉。
- 航线只在两端都已发现时输出，`explored` 标记两端都**已访问**的航线。
- 航线读取 `WorldMap.edges`（生成期预计算的只读表）；旧存档没有该表时回退到
  现场计算（`_compute_routes`），这条回退路径不改状态。
- 迷雾网格按 `max(width, height)/80` 步长降采样，便于 UI 渲染。
- 迷雾半径（4.3 / U1）来自内容比例：`min(world.w, world.h) × fog_*_ratio`
  （`ExplorationRules.fog_radii`），输出 `fog_radii` 供 UI 软圆与演出使用；
  旧存档没有迷雾网格时按同一半径惰性建一份只读网格。
- 船只坐标取当前港口或 `voyage.ship_position`（在航时）。
- 探索系统（阶段 4.1）追加三组只读数据：`clues` 是 `ClueService.view` 的等级裁剪
  视图（不含 `target_port_id` / `credibility` / 真实 `search_zone`）再合并
  `ExplorationCalculator.preview` 的展示估算；`explore` 只说明是否有探索航次及其
  clue id；`can_buy_clue` 用与 `clue.buy` 相同的门禁算出是否可买与原因键。
- 4.3.2 / U2：每条 clue 追加调查入口字段——`investigation_cost` /
  `investigation_hours`（来自 Core `exploration` 块，4.3 初始 0）、
  `can_investigate`（在港且 `level < 4`）、`next_level`（4 级为 0）与
  `next_level_key`（下一级披露文案键，4 级为空串）。裁剪规则不变。
- 4.4 线索扩展：每条 clue 追加 `type` / `target_goods_id` / `goods`（按等级裁剪的
  货物行情投影）/ `expires_at` / `remaining_hours` / `is_expired` 与
  `investigation_success_chance`；`port_goods` 不合并探索估算（`estimated` 为空字典），
  顶层追加 `expiring_clue_count` 供列表页入口角标；查询仍然不输出
  `target_port_id` / `credibility` / 真实 `search_zone`。
- **海图是唯一世界**（2026-10-26「海图唯一真相」）：`data.world_map` 的
  `connectivity_graph` + `edges` 就是世界拓扑；`GameState.world()` 的 `routes` 由它派生
  （`ChartWorldProjection.from_chart`）。每条边的 `distance` 是该边绘制路径的折线长度，
  `base_risk` 也存在同一条边上。因此本查询对每条海图航线只输出**一个**距离
  `distance` 和一个风险来源，不存在「第二把尺子」或「海图有边但不可出航」的分支。
- `travel_hours` / `risk_level` / 煤水消耗由 `VoyageEstimator` 结合船速、锅炉策略与
  航行规则推出（世界表里只存几何量与基础风险，不存时间/风险档位）。
- **航线解锁标记**（2026-10-26）：每条 route 追加 `unlocked: bool`，来自
  `WorldOps.is_route_unlocked`。输出条件仍是「两端都已发现」：未解锁但两端已发现的
  边照常输出，供 UI 画「未测绘」虚线并在面板里禁用启航；未发现的一端仍被迷雾隐藏。

模块索引：[framework/application](../README.md)
