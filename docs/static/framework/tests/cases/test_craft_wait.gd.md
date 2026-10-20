# `framework/tests/cases/test_craft_wait.gd`

> 作用：迭代 2 打造订单测试：tier1 仅金币配方、下单不即时入库、port.wait/抵达结算与旧存档补齐。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `BUILD` | L6 |
| `STRATEGY` | L7 |
| `CONTRACT_FREIGHT` | L8 |
| `TIER1_MODULES` | L9 |
| `SMALL_HOLD` | L18 |
| `SPYGLASS` | L19 |
| `CHART_ROOM` | L20 |
| `test_tier1_recipes_are_money_only() -> void` | L57 |
| `test_money_only_craft_queues_order_and_wait_settles_it() -> void` | L75 |
| `test_money_only_craft_without_gold_reports_insufficient_money() -> void` | L119 |
| `test_order_is_delivered_after_a_voyage() -> void` | L129 |
| `test_port_wait_rejects_invalid_hours_and_wrong_state() -> void` | L148 |
| `test_old_save_without_order_fields_is_backfilled() -> void` | L165 |
| `test_order_state_survives_save_and_load() -> void` | L188 |
| `test_wait_outcome_is_reproducible_for_the_same_seed() -> void` | L206 |

## 契约与约束

- 覆盖 tier1 免材料可打造、金币不足 insufficient_money、订单 ready_at/remaining_hours 与 shipyard.view.orders。
- 覆盖 port.wait 边界（hours 非法、不在港口、失败时 state.hash 不变）与等待后成品入下单港仓库。
- 覆盖出航抵达时结算订单，以及 state.data 缺 shipyard_orders/order_serial 的旧存档补齐（含 float serial 归一化）。
- 覆盖 shipyard_orders/order_serial 的 save→load hash 一致性。

模块索引：[framework/tests](../README.md)
