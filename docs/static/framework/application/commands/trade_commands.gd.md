# `framework/application/commands/trade_commands.gd`

> 作用：`trade.buy` / `trade.sell` 命令包装：读取场景贸易参数、透传落点（船货舱 / 当前港仓库）并发出 `market.changed` 事件。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TradeCommands` | L1 |
| `buy(params: Dictionary, context) -> Dictionary` | L14 |
| `sell(params: Dictionary, context) -> Dictionary` | L46 |

## 契约与约束
- `params.destination`（buy，默认 `"cargo"`）与 `params.source`（sell，默认 `"cargo"`）原样交给 `MarketOps`；
  非法值由领域层返回 `invalid_destination` / `invalid_trade_source`，命令总线不提交事务。
- 成功时 `MarketOps` 结果 data 携带实际 `destination` / `source`；`market.changed` 载荷保留
  `"source":"player"` 表示行为者，并新增 `"storage"` 表示实际落点，供状态栏 / 表现层使用。
- 成功交易后调用 `MarketMemoryService.remember` 记录价格记忆，与既往路径一致。

模块索引：[framework/application](../README.md)
