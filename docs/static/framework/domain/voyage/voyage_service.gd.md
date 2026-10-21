# `framework/domain/voyage/voyage_service.gd`

> 作用：航行执行：校验预览、扣补给/工资、抽取事件、事件选择、抵达结算与失败回滚。

- 关键依赖：`VoyageCalculator`、`ShipOps`、`MapOps`、`ConditionEvaluator`、`EffectExecutor`、`ContractOps`、`NpcTraderSimulator`、`DebtService`、`SaveService`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VoyageService` | L1 |
| `OPPORTUNITY_CHANCE` | L15 |
| `MAX_EVENT_DELAY_HOURS` | L16 |
| `start(context, destination_id: String, strategy_id: String) -> Dictionary` | L19 |
| `choose_option(context, option_id: String) -> Dictionary` | L104 |
| `settle_arrival_services(context, destination: String, arrival_time: float, voyage: Dictionary) -> Dictionary` | L258 |
| `record_arrival_stats(state: GameState, contract_results: Array, injuries: int = 0) -> Dictionary` | L337 |

## 契约与约束

- 出航前把当前状态存入 `context.pre_voyage_state` 和 `pre_voyage` 存档槽。
- 风险事件概率对玩家隐藏；预览只暴露风险来源。事件最多提供 2 个加权抽样选项。
- 耐久归零或 `fail_voyage` 效果会把工作副本替换回出航前快照，并发布 voyage.failed。
- 抵达时统一推进时间、发现港口、结算打造订单（CraftOps.settle_orders，成品进下单港仓库并写入 summary.completed_orders）、结算主线/普通委托、推进 NPC、检查逾期、刷新普通委托池并自动存档。
- 工资通过 `state.record_expense()` 计入统计支出；委托收入在 ContractOps 结算时计入收入。
- 行动顺序固定：扣费/补给 → 生成 voyage → 选事件 → 若无事件立即抵达。

## 重点逻辑

### `start(context, destination_id, strategy_id)`

- 先调用 VoyageCalculator 生成可复现预览；feasible=false 时不修改状态。
- 工资、煤、水全部扣除后写入 `voyage` 快照；事件基础延误已计入 arrival_time。
- 事件选项仅保存 ID；选择时重新从注册表读取效果，避免存档注入效果对象。

### `choose_option(context, option_id)`

- 再次校验选项在本次抽样池中且条件成立，然后顺序执行效果。
- effect flags.voyage_failed 为真时恢复出航前状态，返回 ok + failed，以便 UI 展示而非命令错误。
- 成功后调用 `_complete_arrival()`；autosave 只在成功抵达后发生。

### `_complete_arrival(context)`

- 以 arrival_time 推进游戏时间并标记目的港 visited/discovered。
- 主线完成后 next_main_sequence+1，并生成下一段 main_offer；不自动接取。
- 普通 active 委托中目的港匹配者一起结算；其余保留。
- 调用 `ContractOps.refresh_normal_offers()` 整池刷新普通委托（键含港口/抵达时间/航次），summary.offers_refreshed=true 并发布 contract.offers_refreshed。
- NPC 市场推进、债务逾期、统计与通知都在此统一处理。

模块索引：[framework/domain](../README.md)
