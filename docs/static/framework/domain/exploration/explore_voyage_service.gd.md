# `framework/domain/exploration/explore_voyage_service.gd`

> 作用：探索航次的领域执行——出航（扣工资与煤水、写探索航次与在航标记、抽定发现 roll）、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ExploreVoyageService` | L1 |
| `start(context, clue_id: String, strategy_id: String) -> Dictionary` | L28 |
| `decide(context, choice: String) -> Dictionary` | L136 |
| `settle(context) -> Dictionary` | L210 |

资源告急决策（继续 / 掉头）、抵达结算（发现港口 + 迷雾揭示 / 失败漂流 + 线索作废）。

- 关键依赖：`ClueService`、`ExplorationCalculator`、`ExplorationRules`、`WorldOps`、
  `FogOps`、`MapOps`、`ShipOps`、`RngService.STREAM_EXPLORATION`

## 契约与约束
- 探索期间 `data.voyage = {"kind": "explore", "status": "at_sea"}`，既有
  `is_at_port()` / `port.view.at_sea` / 贸易门禁自动生效；`settle` 与掉头都会同时清空
  `data.explore_voyage` 与 `data.voyage`。
- `start` 在任何扣费之前先跑完整预览：不可行直接失败，**不得扣资源**。
- 发现结果在出发时用命名流 `explore:<clue_id>:<departure>` 抽定（`outcome_roll`），
  结算只比较 `outcome_roll < discovery_chance`，同 seed 同状态可复现。
- 成功：坐标世界 `discover_port_id` + `mark_visited` + `FogOps.reveal_arrival`，抽象地图
  同步发现 / 访问（贸易、市场、海图都读它），线索 resolved，进入目标港。
- 失败：线索 failed（不删除），漂到**距搜索区最近的已发现港**并按其入港处理（记录访问
  + 揭示泊位），耐久 / 煤 / 水按规则扣减且不为负，时间加 `drift_hours`。
- 掉头：额外消耗 `coal_used/water_used * turnback_extra_ratio`，时间前进半个航程，
  回出发港，线索保持 active。
- 结算 `summary.explore` 与 `settlement_screen` 现有字段兼容；领域事件
  `explore.started` / `explore.finished` 随结果返回，由命令总线发布。

模块索引：[framework/domain](../README.md)
