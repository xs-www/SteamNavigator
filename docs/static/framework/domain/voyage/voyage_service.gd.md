# `framework/domain/voyage/voyage_service.gd`

> 作用：航行执行：校验预览、出发扣工资、抽取事件、事件选择、抵达结算（按实际航行

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VoyageService` | L1 |
| `OPPORTUNITY_CHANCE` | L59 |
| `MAX_EVENT_DELAY_HOURS` | L60 |
| `start(context, destination_id: String, strategy_id: String) -> Dictionary` | L63 |
| `choose_option(context, option_id: String) -> Dictionary` | L164 |
| `settle_arrival_services(context, destination: String, arrival_time: float, voyage: Dictionary) -> Dictionary` | L370 |
| `record_arrival_stats(state: GameState, contract_results: Array, injuries: int = 0) -> Dictionary` | L455 |

小时一次性扣煤水）与失败回滚。

- 关键依赖：`VoyageCalculator`、`ShipOps`、`MapOps`、`ConditionEvaluator`、
  `EffectExecutor`、`ContractOps`、`NpcTraderSimulator`、`DebtService`、`SaveService`、
  `WorldOps` / `FogOps` / `ExplorationRules`（坐标世界与迷雾）

## 契约与约束
- 出航前把当前状态存入 `context.pre_voyage_state` 和 `pre_voyage` 存档槽。
- 风险事件概率对玩家隐藏；预览只暴露风险来源。事件最多提供 2 个加权抽样选项。
- 耐久归零或 `fail_voyage` 效果会把工作副本替换回出航前快照，并发布 voyage.failed。
- 抵达时统一推进时间、发现港口、结算打造订单（`CraftOps.settle_orders`，成品进
  下单港仓库并写入 `summary.completed_orders`）、结算主线/普通委托、推进 NPC、
  检查逾期、刷新普通委托池并自动存档。
- 工资通过 `state.record_expense()` 计入统计支出；委托收入在 ContractOps 结算时计入收入。
- 行动顺序固定：扣工资 → 生成 voyage（存出发库存与每小时煤水费率）→ 选事件 →
  若无事件立即抵达结算。
- 连续消耗（阶段 4.3.5 / U8）：出发**不扣**煤水，只扣工资；`voyage` 快照记录
  `departure_coal` / `departure_water` 与 `coal_rate` / `water_rate`（每小时消耗 =
  预览计划消耗 ÷ 计划时长）。`_complete_arrival` 按 `elapsed = arrival_time -
  departure_time`（已含事件延误）一次性扣 `rate × elapsed`，演出期间顶栏只做插值
  读数、不写领域状态。事件 payload 仍报计划消耗，语义不变。
- 坐标世界（海图数据源）与抽象地图同步：`_complete_arrival` 记录访问并揭示泊位；
  4.3.3 / U4 起在揭示前先 `_trace_voyage_fog` 沿实际航线把沿途迷雾落账（沿海
  格子留 EXPLORED），旧存档没有 `world_map` 时这些调用全部 no-op。
- 4.1 起每次抵达还调用 `ClueService.on_arrival` 抽传闻线索；空结果（没抽中 /
  没有目标 / 上限已满）永不阻断或失败抵达。
- 4.4 起 `settle_arrival_services` 先按抵达时间 sweep 到期货物线索（所有抵达路径
  共用），把 `clue.expired` 事件并入到港事件；4.4.2 还会在这里接入完成委托解锁线索。

## 重点逻辑
### `start(context, destination_id, strategy_id)`
- 先调用 VoyageCalculator 生成可复现预览；feasible=false 时不修改状态。
- 只扣工资后写入 `voyage` 快照（含出发煤水库存与每小时费率）；事件基础延误已计入
  arrival_time。煤水的实际扣除发生在抵达结算，不在出发时。
- 事件选项仅保存 ID；选择时重新从注册表读取效果，避免存档注入效果对象。

### `choose_option(context, option_id)`
- 再次校验选项在本次抽样池中且条件成立，然后顺序执行效果。
- effect flags.voyage_failed 为真时恢复出航前状态，返回 ok + failed，以便 UI 展示。
- 成功后调用 `_complete_arrival()`；autosave 只在成功抵达后发生。

### `_complete_arrival(context)`
- 先按 `rate × (arrival_time - departure_time)` 扣煤水（事件 `add_delay_hours`
  会推后 arrival_time，因此延误小时也计费；钳位到 0），summary 附
  `coal_used_actual` / `water_used_actual` 供 UI / 测试读取。
- 以 arrival_time 推进游戏时间并标记目的港 visited/discovered。
- `_trace_voyage_fog` 先从 `WorldMap.edges`（缺失时 `RouteCalculator` 的
  `bezier_path`，再缺就两港直线）采样沿途迷雾，`_reveal_world_fog` 再揭示泊位。
- 主线完成后 next_main_sequence+1，并生成下一段 main_offer；不自动接取。
- 普通 active 委托中目的港匹配者一起结算；其余保留。
- 调用 `ContractOps.refresh_normal_offers()` 整池刷新普通委托，summary.offers_refreshed=true。
- NPC 市场推进、债务逾期、统计与通知都在此统一处理。

模块索引：[framework/domain](../README.md)
