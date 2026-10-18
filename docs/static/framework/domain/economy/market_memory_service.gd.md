# `framework/domain/economy/market_memory_service.gd`

> 作用：每港“上次在港时”的市场快照：价格、储备、可买标记与时间戳。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketMemoryService` | L1 |

## 契约与约束

- 只在开局、抵达港口、在该港完成买卖时刷新；时间流逝和 NPC 变化不会改写快照。
- 与情报快照互相独立：情报可远程刷新，港口记忆只记录亲历市场。
- 快照包含普通商品与补给商品（煤/水），并记录 is_supply 标记。
- 快照存放在 GameState.port_memory，使用普通 Dictionary，可直接存档。

模块索引：[framework/domain](../README.md)
