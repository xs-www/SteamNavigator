# `framework/application/queries/supply_view.gd`

> 作用：补给界面 ViewModel：煤水单价、载重余量、可买上限与维修报价。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SupplyViewQuery` | L1 |

## 契约与约束

- 煤水价格与维修单价来自 map_profile；买卖上限同时受剩余载重和金币限制。
- 维修报价与 supply.repair 共用 `MarketOps.repair_cost()`，UI 不复制耐久/改装修正。
- 当前港没有 supply 设施时 has_supply=false，界面禁用补给与维修。

模块索引：[framework/application](../README.md)
