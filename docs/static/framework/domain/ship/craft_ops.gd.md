# `framework/domain/ship/craft_ops.gd`

> 作用：模块打造：读取模块 JSON 配方、规划材料来源、仓库优先消耗、扣费并生成带工时的打造订单，时间到位后把成品写入下单港仓库。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CraftOps` | L1 |

## 契约与约束

- 配方来自 module.data.materials / craft_time_hours / craft_cost；可打造 = 类型在 CRAFTABLE_TYPES 且（materials 非空 或 craft_cost>0），所以 tier1「仅金币」配方不需要材料。
- 材料来源顺序：当前港仓库优先，再从船上非委托货物扣除；不足返回 missing_materials。
- craft() 不再推进时间、不再立即入库：扣材料与 craft_cost（记支出）后写入 state.data.shipyard_orders（order_id=order_N，ready_at=now+craft_time_hours），并发布 ship.craft_ordered。
- 订单字段由 ensure_orders 幂等补齐（旧存档兼容、float serial 归一化为 int）：state.data.shipyard_orders / order_serial，全部为纯 JSON。
- settle_orders(state, hub) 在 now>=ready_at 时把成品写入订单所属港口仓库、推 notice ui.notice.craft_completed（参数按模板顺序：模块 → 港口）并返回完成明细；结算时机：craft() 开头、VoyageService 抵达、port.wait。
- 成品进入下单港仓库而不是直接安装；随后由 ship.install_module(source=warehouse) 免费安装。
- craft_blockers 与船厂 ViewModel 共用：unknown_module/not_craftable/locked_by_contract/missing_materials/insufficient_money。

## 重点逻辑

### `craft(state, hub, module_id)`

- 先 ensure_orders + settle_orders，再复用 craft_blockers 做整体校验，避免部分扣材料后失败。
- 逐个材料先扣仓库再扣 cargo，返回 consumed 明细（from_warehouse/from_cargo）。
- add_money(-craft_cost) 时同步 record_expense；随后只写订单，不推进时间。

### `settle_orders(state, hub)`

- 只处理 now>=ready_at 的订单，按 port_id 写 WarehouseOps 仓库；返回行含 order_id/module_id/content_type/name_key/port_id/warehouse_qty 供命令层发事件。

模块索引：[framework/domain](../README.md)
