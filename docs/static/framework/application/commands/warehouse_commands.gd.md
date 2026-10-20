# `framework/application/commands/warehouse_commands.gd`

> 作用：仓库命令包装：ship.transit 与当前港仓库之间的模块/材料存取。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WarehouseCommands` | L1 |
| `store_module(params: Dictionary, context) -> Dictionary` | L9 |
| `take_module(params: Dictionary, context) -> Dictionary` | L28 |
| `store_materials(params: Dictionary, context) -> Dictionary` | L47 |
| `take_materials(params: Dictionary, context) -> Dictionary` | L66 |

## 契约与约束

- 四个命令分别为 warehouse.store_module / take_module / store_materials / take_materials。
- 命令只做参数解析、WarehouseOps 调用与领域事件发布；规则全部在 WarehouseOps。
- 事件类型：warehouse.module_stored / module_taken / materials_stored / materials_taken。

模块索引：[framework/application](../README.md)
