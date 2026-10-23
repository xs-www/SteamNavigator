# `framework/domain/trade/auto_trade_system.gd`

> 作用：Phase D4 自动贸易的确定性 tick 系统：按策略在港口之间自动买卖，处理航程、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AutoTradeSystem` | L1 |
| `SYSTEM_ID` | L18 |
| `PRIORITY` | L19 |
| `register() -> void` | L22 |
| `ensure_registered() -> void` | L26 |
| `tick(state: GameState, tick: int, context = null) -> void` | L31 |

风险、规则暂停/恢复与利润统计。由 `AutoTradeService.start` 惰性注册到
`TickScheduler`（id `auto_trade`，priority 110），`sim.advance` 驱动。

## 契约与约束
- 只在 `data.trade.active` 时工作；没有注册表上下文时 no-op。
- phase `idle` → 选出目标港并买入（无满足 `min_margin` 的路线时保持空闲）；
  `outbound` / `returning` 每 tick 递减 `travel_remaining`，到 0 时结算。
- 抵达目标港时先按 policy.risk 掷一次确定性风险（seed = policy_id + tick），
  命中则损失一半货舱；随后全部卖出并开始返航。
- 规则在每 tick 开始按 priority 顺序评估；`pause` 后本 tick 不再推进。
- 只改 `data.trade`、港口市场库存/价格与玩家金钱；不改玩家船货舱。

模块索引：[framework/domain](../README.md)
