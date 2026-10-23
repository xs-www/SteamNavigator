# `framework/domain/ship/warehouse_ops.gd`

> 作用：港口仓库（模块、材料、武器）与随船运输模块的状态操作；旧存档缺分区时惰性补齐。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WarehouseOps` | L1 |
| `MODULE_SECTION` | L12 |
| `MATERIAL_SECTION` | L13 |
| `WEAPON_SECTION` | L14 |
| `ensure_structure(state: GameState) -> void` | L19 |
| `warehouse(state: GameState, port_id: String) -> Dictionary` | L43 |
| `module_qty(state: GameState, port_id: String, module_id: String) -> int` | L56 |
| `material_amount(state: GameState, port_id: String, item_id: String) -> int` | L61 |
| `weapon_qty(state: GameState, port_id: String, weapon_id: String) -> int` | L66 |
| `transit_modules(ship: Dictionary) -> Dictionary` | L71 |
| `transit_qty(ship: Dictionary, module_id: String) -> int` | L76 |
| `transit_module_weight(hub: RegistryHub, ship: Dictionary) -> float` | L82 |
| `owned_module_count(state: GameState, hub: RegistryHub, module_id: String) -> int` | L97 |
| `store_module(state: GameState, hub: RegistryHub, port_id: String, module_id: String, qty: int = 1) -> Dictionary` | L109 |
| `take_module(state: GameState, hub: RegistryHub, port_id: String, module_id: String, qty: int = 1) -> Dictionary` | L139 |
| `store_materials(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int) -> Dictionary` | L177 |
| `take_materials(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int) -> Dictionary` | L204 |
| `add_module(state: GameState, port_id: String, module_id: String, qty: int = 1) -> int` | L247 |
| `remove_module(state: GameState, port_id: String, module_id: String, qty: int = 1) -> int` | L256 |
| `add_weapon(state: GameState, port_id: String, weapon_id: String, qty: int = 1) -> int` | L268 |
| `remove_weapon(state: GameState, port_id: String, weapon_id: String, qty: int = 1) -> int` | L276 |
| `add_material(state: GameState, port_id: String, item_id: String, amount: int = 1) -> int` | L289 |
| `remove_material(state: GameState, port_id: String, item_id: String, amount: int = 1) -> int` | L298 |

Warehouses live at `world.warehouses[port_id] = {modules:{}, materials:{}, weapons:{}}`.
Modules that are not installed travel with the ship in `ship.transit_modules`;
they add weight but never occupy cargo capacity. All helpers are pure state
manipulation and never touch content definitions.

模块索引：[framework/domain](../README.md)
