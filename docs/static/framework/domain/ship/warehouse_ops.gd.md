# `framework/domain/ship/warehouse_ops.gd`

> 作用：港口仓库与随船运输：每港独立保存模块/材料，transit 模块计入重量但不占货舱。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WarehouseOps` | L1 |

## 契约与约束

- 仓库数据位于 `world.warehouses[port_id] = {modules:{id:qty}, materials:{id:amount}}`；`ensure_structure()` 幂等补齐所有港口与 ship.transit_modules，兼容旧存档。
- store/take 模块在 transit 与当前港仓库之间移动；take 检查船体 max_weight，store 只要求停靠。
- store 材料把船上非委托货物移入仓库；take 材料检查重量与货舱容量。
- 仓库操作只处理纯数据与结果码，不删除安装态；安装/替换由 ShipOps/ShipCommands 负责。
- 所有失败返回 Result.fail，命令总线因此回滚工作副本。

## 重点逻辑

### `ensure_structure(state)`

- 对每个 world.ports 键确保 warehouses 条目存在并含 modules/materials；缺失 ship 时也补齐。
- 对已有条目只补缺失 section，不清空已有库存。

### `take_module(...)`

- 重量校验使用 ShipOps.total_weight + qty*module.weight；通过后才从仓库移除并写入 transit。
- 返回 transit_qty/warehouse_qty/transit_weight 供 ViewModel 直接使用。

模块索引：[framework/domain](../README.md)
