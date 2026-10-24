# `framework/tests/cases/test_market_trade.gd`

> 作用：市场买卖领域测试：船货舱买卖、港口仓库买入 / 直卖、默认落点、非法落点与失败回滚。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_trade_buy_and_sell() -> void` | L31 |
| `test_failed_trade_rolls_back() -> void` | L56 |
| `test_price_moves_with_stock() -> void` | L66 |
| `test_player_trade_price_impact_is_damped() -> void` | L83 |
| `test_default_trade_storage_is_cargo() -> void` | L110 |
| `test_buy_into_warehouse_keeps_hold() -> void` | L128 |
| `test_sell_from_warehouse_keeps_hold() -> void` | L157 |
| `test_invalid_trade_storage_fails_without_state_change() -> void` | L187 |
| `test_warehouse_trade_failures_roll_back() -> void` | L204 |

## 契约与约束
- 买进仓库不占船上重量 / 货舱，仓库直卖不动船舱；两者复用市场价格、库存与收入/支出口径。
- 非法 `destination` / `source`、港存不足、金币不足、仓库数量不足必须失败，且 `state.hash()` 不变（命令事务不提交）。
- 交易后状态引用会被事务提交替换，断言一律重新读取 `context.state`，不缓存 `ship` 字典。

模块索引：[framework/tests](../README.md)
