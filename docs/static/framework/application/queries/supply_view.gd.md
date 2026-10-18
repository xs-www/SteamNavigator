# `framework/application/queries/supply_view.gd`

> 作用：补给界面 ViewModel：煤水价/库存、载重余量、可补上限、预计续航与维修报价。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SupplyViewQuery` | L1 |

## 契约与约束

- 煤水单价与港口库存来自 `MarketOps.supply_entry_for()`，不再使用固定价格。
- 可买上限同时受剩余载重、金币和港口库存限制；`coal_view`/`water_view` 额外给出 fill_to、safe_level、estimated_days、fill_cost 和 blocker 代码。
- 维修报价与 supply.repair 共用 `MarketOps.repair_cost()`，UI 不复制耐久/改装修正。
- 当前港没有 supply 设施时 has_supply=false，界面禁用补给与维修。

模块索引：[framework/application](../README.md)
