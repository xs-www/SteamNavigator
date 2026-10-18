# `framework/application/queries/supply_view.gd`

> 作用：补给界面 ViewModel：市场煤水价/库存、载重余量与维修报价。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SupplyViewQuery` | L1 |

## 契约与约束

- 煤水单价与港口库存来自 `MarketOps.supply_entry_for()`，不再使用固定价格。
- 可买上限同时受剩余载重、金币和港口库存限制。
- 维修报价与 supply.repair 共用 `MarketOps.repair_cost()`，UI 不复制耐久/改装修正。
- 当前港没有 supply 设施时 has_supply=false，界面禁用补给与维修。

模块索引：[framework/application](../README.md)
