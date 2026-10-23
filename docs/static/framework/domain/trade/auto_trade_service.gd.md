# `framework/domain/trade/auto_trade_service.gd`

> 作用：Phase D4 自动贸易的领域用例：启动/停止/切换贸易策略，手动暂停/恢复；

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AutoTradeService` | L1 |
| `start(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L19 |
| `stop(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary` | L43 |
| `set_policy(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L57 |
| `pause(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary` | L76 |
| `resume(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary` | L86 |

状态只落在 `data.trade`，买卖与风险结算由 `AutoTradeSystem` 在 tick 中执行。

关键依赖：`RegistryHub`（trade_policies / automation_rules）、`AutoTradeOps`、
`MarketOps`、`GameState`

## 契约与约束
- `start` 要求人在港口、没有正在运行的自动贸易，策略存在；母港 = 当前港。
- `set_policy` 只在空闲且无货时允许，避免带着旧策略的货切换规则。
- `stop` 清空自动货舱与运行态（不追回已发生的买卖），保留日志在清空后不可见。
- 领域事件：`auto_trade.started` / `auto_trade.stopped` / `auto_trade.policy_changed` /
  `auto_trade.paused` / `auto_trade.resumed`。

模块索引：[framework/domain](../README.md)
