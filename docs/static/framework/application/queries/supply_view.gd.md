# `framework/application/queries/supply_view.gd`

> 作用：补给界面 ViewModel：煤水价/库存、载重余量、可补上限、预计续航与维修报价。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SupplyViewQuery` | L1 |

## 契约与约束

- 煤水单价与港口库存来自 `MarketOps.supply_entry_for()`，不再使用固定价格。
- 可买上限同时受 capacity（= max_weight − 非补给重量 − 另一项补给重量，按单位重量取整）、金币和港口库存限制，因此买一种补给只会压低另一种的上限，不会让比例条上涨。
- `coal_view`/`water_view` 额外给出 capacity/baseline_capacity/cap_loss/headroom/maximum_baseline；cap_loss 供 UI 绘制右端反向损失带，maximum=max(current, capacity) 为当前可达物理上限。
- fill_to、safe_level、estimated_days、fill_cost、blocker 代码与顶层 max_coal/max_water 语义保持兼容。
- 维修报价与 supply.repair 共用 `MarketOps.repair_cost()`，UI 不复制耐久/改装修正。
- 当前港没有 supply 设施时 has_supply=false，界面禁用补给与维修。

模块索引：[framework/application](../README.md)
