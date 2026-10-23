# `framework/application/commands/ship_commands.gd`

> 作用：船厂事务用例：模块购买/仓库/运输安装、卸装与打造，以及舰载武器购买/仓库安装和卸下。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipCommands` | L1 |
| `VALID_SOURCES` | L21 |
| `install_module(params: Dictionary, context) -> Dictionary` | L24 |
| `install_weapon(params: Dictionary, context) -> Dictionary` | L123 |
| `uninstall_weapon(params: Dictionary, context) -> Dictionary` | L170 |
| `uninstall_module(params: Dictionary, context) -> Dictionary` | L195 |
| `craft_module(params: Dictionary, context) -> Dictionary` | L238 |

Shipyard use cases: install a module (purchase / warehouse / transit, with
replacement), uninstall a module into the current port warehouse, and order a
module craft (warehouse-first materials, delivered later by CraftOps settlement).

All handlers run inside the CommandBus transaction. Slot, weight, money,
lock and source rules come from ShipOps.install_blockers()/uninstall_blockers()
and CraftOps.craft_blockers() so the shipyard ViewModel never drifts.
A successful hull replacement also reconciles `data.fleet`: a flagship captain
that cannot command the new archetype is released in the same transaction.
Hull replacement also reconciles the weapon loadout and returns incompatible
weapons to the current-port warehouse without losing ownership.

模块索引：[framework/application](../README.md)
