# `framework/domain/economy/market_ops.gd`

> 作用：市场价格、买卖、补给购买与维修结算。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketOps` | L1 |

## 契约与约束

- 价格 = base_price × bias × (base_stock / stock)^elasticity，限制在 0.55–2.2。
- 买入改变库存并立即重算价格；卖出使用买卖价差 trade_margin。
- 买入检查货币、库存、总重量与货舱容量；合同货物不可卖。
- 补给只检查重量与货币；维修费用乘安全设备/工程师的 repair_cost 修正。

## 重点逻辑

### `buy(state, hub, port_id, item_id, amount, trade_margin)`

- 所有前置条件通过后才扣款、减库存、重算价格、写入 cargo stack。
- 失败返回带 message_key 的 Result；命令总线因此不会提交工作副本。

模块索引：[framework/domain](../README.md)
