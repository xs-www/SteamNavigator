# `framework/application/queries/port_memory_view.gd`

> 作用：点击已访问港口时的只读市场记忆 ViewModel：上次在港的价格、储备与可买标记。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortMemoryViewQuery` | L1 |

## 契约与约束

- 数据来自 `MarketMemoryService`，不是实时市场；时间流逝不会自动刷新。
- 包含港口名、上次到港时间/年龄、设施与全部普通商品行。
- 未访问港口或旧存档缺少快照时返回 has_memory=false，不伪造价格。

模块索引：[framework/application](../README.md)
