# `framework/domain/ship/ship_ops.gd`

> 作用：船只组合、重量、容量与派生属性的纯规则；模块实例 condition 会按槽位缩放能力贡献，舰载武器重量计入总重。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipOps` | L1 |
| `COAL_WEIGHT` | L13 |
| `WATER_WEIGHT` | L14 |
| `PASSENGER_WEIGHT` | L15 |
| `EQUIPMENT_KEYS` | L17 |
| `installable_definitions(hub: RegistryHub) -> Array[ContentDefinition]` | L21 |
| `find_installable(hub: RegistryHub, module_id: String) -> ContentDefinition` | L29 |
| `all_installed_module_ids(ship: Dictionary) -> Array[String]` | L38 |
| `cargo_module_ids(ship: Dictionary) -> Array[String]` | L49 |
| `find_module(hub: RegistryHub, module_id: String) -> ContentDefinition` | L56 |
| `module_in_slot(hub: RegistryHub, ship: Dictionary, slot: String) -> ContentDefinition` | L62 |
| `item_definition(hub: RegistryHub, item_id: String) -> ContentDefinition` | L74 |
| `is_crafting_material(hub: RegistryHub, item_id: String) -> bool` | L80 |
| `installed_modules(hub: RegistryHub, ship: Dictionary) -> Array[ContentDefinition]` | L85 |
| `module_weight(hub: RegistryHub, ship: Dictionary) -> float` | L94 |
| `module_damage_points(hub: RegistryHub, ship: Dictionary) -> float` | L104 |
| `has_disabled_module(ship: Dictionary) -> bool` | L117 |
| `cargo_weight(hub: RegistryHub, ship: Dictionary) -> float` | L124 |
| `passenger_count(state: GameState) -> int` | L134 |
| `total_weight(hub: RegistryHub, state: GameState) -> float` | L146 |
| `max_weight(hub: RegistryHub, ship: Dictionary) -> float` | L157 |
| `cargo_capacity(hub: RegistryHub, ship: Dictionary) -> float` | L162 |
| `cargo_used(hub: RegistryHub, ship: Dictionary) -> float` | L173 |
| `free_cargo_capacity(hub: RegistryHub, ship: Dictionary) -> float` | L177 |
| `passenger_capacity(hub: RegistryHub, ship: Dictionary) -> int` | L181 |
| `durability_max(hub: RegistryHub, ship: Dictionary) -> float` | L188 |
| `stats(hub: RegistryHub, ship: Dictionary) -> Dictionary` | L193 |
| `role_definition(hub: RegistryHub, ship: Dictionary, kind: String) -> ContentDefinition` | L315 |
| `add_cargo(ship: Dictionary, item_id: String, amount: int, contract_id: String = "", total_cost: float = 0.0) -> void` | L326 |
| `cargo_amount(ship: Dictionary, item_id: String, allow_contract: bool = true) -> int` | L345 |
| `cargo_total_cost(ship: Dictionary, allow_contract: bool = false) -> float` | L356 |
| `cargo_average_cost(ship: Dictionary, item_id: String, allow_contract: bool = false) -> float` | L365 |
| `remove_cargo(ship: Dictionary, item_id: String, amount: int, allow_contract: bool = false) -> int` | L378 |
| `remove_non_contract_cargo_by_weight(hub: RegistryHub, ship: Dictionary, weight: float) -> float` | L405 |
| `module_category(hub: RegistryHub, module_id: String) -> String` | L434 |
| `unlock_contract_id(hub: RegistryHub, module_id: String) -> String` | L439 |
| `locked_by_contract(hub: RegistryHub, state: GameState, module_id: String) -> bool` | L452 |
| `install_blockers(hub: RegistryHub, state: GameState, module_id: String, source: String = "purchase", replace_module_id: String = "", requested_slot: String = "") -> Array[String]` | L470 |
| `uninstall_blockers(hub: RegistryHub, state: GameState, module_id: String) -> Array[String]` | L573 |
| `validate_configuration(hub: RegistryHub, ship: Dictionary) -> Dictionary` | L587 |

- 模块重量不随损伤变化；货舱/客舱容量、锅炉输出、utility 数值与 modifiers 按 condition 衰减。
- add modifier 乘 condition；mul modifier在中性值 1 与定义值之间插值。
- 玩家武器装配由 WeaponOps 读取，已装武器重量属于船舶总重量。

模块索引：[framework/domain](../README.md)
