# `framework/domain/exploration/explore_voyage_service.gd`

> 作用：探索航次的领域执行——出航（只扣工资、记录出发库存与每小时煤水费率、写探索

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ExploreVoyageService` | L1 |
| `start(context, clue_id: String, strategy_id: String) -> Dictionary` | L49 |
| `decide(context, choice: String) -> Dictionary` | L184 |
| `settle(context) -> Dictionary` | L290 |

航次与在航标记、抽定发现 roll）、资源告急决策（继续 / 掉头）、抵达结算（发现港口 +
迷雾揭示 / 失败漂流 + 线索保留，按实际航行小时一次性扣煤水）。

- 关键依赖：`ClueService`、`ExplorationCalculator`、`ExplorationRules`、`WorldOps`、
  `FogOps`、`MapOps`、`ShipOps`、`RngService.STREAM_EXPLORATION`

## 契约与约束
- 探索期间 `data.voyage = {"kind": "explore", "status": "at_sea"}`，既有
  `is_at_port()` / `port.view.at_sea` / 贸易门禁自动生效；`settle` 与掉头都会同时清空
  `data.explore_voyage` 与 `data.voyage`。
- `start` 在任何扣费之前先跑完整预览：不可行直接失败，**不得扣资源**。
- 连续消耗（阶段 4.3.5 / U8）：出发**只扣工资**，煤水库存原样留在船上；航次记录
  `departure_coal` / `departure_water` 与 `coal_rate` / `water_rate`
  （= 计划消耗 ÷ 计划时长），`presentation` 也带这四个字段供 Shell 插值读数。
  实际扣款只在结算时按实际航行小时一次性发生：
  成功 `elapsed = arrival - departure`；失败 `duration + drift_hours`；掉头
  `duration × 0.5`。漂流 / 掉头的额外损耗（`drift_extra_*` / 计划消耗 × 比例）
  在小时扣款之后再扣，钳位到剩余库存；`summary.explore.extra_coal/water`
  仍只表示这笔额外损耗。
- 发现结果在出发时用命名流 `explore:<clue_id>:<departure>` 抽定（`outcome_roll`），
  结算只比较 `outcome_roll < discovery_chance`，同 seed 同状态可复现。
- 4.5.4：剧情线索可带 `guaranteed_explore_clue_id`（`StoryService` 写入）——结算
  时该线索无视 `outcome_roll` 直接成功，成功后消费 flag；其它线索 / 跳过教程不受影响。
- 成功：坐标世界 `discover_port_id` + `mark_visited` + `FogOps.reveal_arrival`，抽象地图
  同步发现 / 访问（贸易、市场、海图都读它），线索 resolved，进入目标港。
- 失败（4.3 / U3）：线索**保留在 active**（只累加 `attempts` / `last_attempt_at`，
  可再次 `start`），漂到**距搜索区最近的已发现港**并按其入港处理（记录访问 +
  揭示泊位），耐久 / 煤 / 水按规则扣减且不为负，时间加 `drift_hours`。结算摘要
  的 `explore.attempts` 报告累计尝试次数，`settlement_screen` 据此显示「线索保留」。
- 掉头：先按每小时费率扣实际半程（`duration × 0.5`），再额外消耗
  `coal_used/water_used * turnback_extra_ratio`（钳位到剩余库存），时间前进半个航程，
  回出发港，线索保持 active。
- 迷雾沿途落账（4.3.3 / U4）：成功与失败漂流都在 `reveal_arrival` 之前对
  `voyage.route_path` 调用 `FogOps.trace_route`，把实际航线的沿海格子留成
  EXPLORED；掉头只采样去程前半段（`end_progress = 0.5`）。旧存档没有坐标世界时
  `trace_route` 自行 no-op。
- 结算 `summary.explore` 与 `settlement_screen` 现有字段兼容；领域事件
  `explore.started` / `explore.finished` 随结果返回，由命令总线发布。
- 4.4：`start` 入口先 `ClueService.sweep_expired` 清理到期线索并把 `clue.expired`
  事件并入返回；过期线索不能再出航（`clue_expired`），避免 `port_goods` 线索被
  误当成探索目标。

模块索引：[framework/domain](../README.md)
