# `framework/domain/economy/market_ops.gd`

> 作用：市场价格、买卖、补给购买与维修结算；任意港收购所有货物，买入仅限本地品种。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketOps` | L1 |

## 契约与约束

- 本地品种价格 = base_price × bias × (base_stock / stock)^elasticity，限制在 0.55–2.2。
- 非本地品种以 `buyable=false` 进入市场：只收购、不卖给你；价格按 base_price × 0.9 × 库存折减。
- 买入检查 buyable、货币、库存、总重量与货舱容量；卖出允许所有非合同货物。
- 玩家买卖只把价格向新均衡推进 `player_trade_impact`（默认 0.35）；NPC 交易仍完整重算。
- 买入把成交总额写入 cargo stack 的 total_cost，卖出按数量比例扣减成本。
- 补给只检查重量与货币；维修费用乘安全设备/工程师的 repair_cost 修正。
- `ensure_sell_only_entries()` 为旧存档补齐非本地收购项。

## 重点逻辑

### `buy(state, hub, port_id, item_id, amount, trade_margin, price_impact)`

- 所有前置条件通过后才扣款、减库存、按 price_impact 平滑重算价格、写入 cargo stack 和成本。
- 失败返回带 message_key 的 Result；命令总线因此不会提交工作副本。

### `compute_price(entry)`

- buyable=true 走本地市场供需公式；buyable=false 使用单向收购价，库存越多价格越低。

### `repair_cost(hub, state, repair_per_point)`

- 返回缺失耐久、费用、耐久上限与维修修正；supply.view 和 supply.repair 共用。

模块索引：[framework/domain](../README.md)
