# `framework/domain/ship/weapon_ops.gd`

> 作用：玩家旗舰的舰载武器所有权与装配纯规则；校验 hull socket、weapon class、来源、价格和重量，并维护 `ship.weapon_loadout`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WeaponOps` | L1 |
| `VALID_SOURCES` | L11 |
| `all(hub: RegistryHub) -> Array[ContentDefinition]` | L14 |
| `get_by_id(hub: RegistryHub, weapon_id: String) -> ContentDefinition` | L18 |
| `sockets(hub: RegistryHub, ship: Dictionary) -> Array` | L22 |
| `socket_by_name(hub: RegistryHub, ship: Dictionary, socket_name: String) -> Dictionary` | L30 |
| `loadout(ship: Dictionary) -> Array` | L37 |
| `weapon_id_at(ship: Dictionary, socket_name: String) -> String` | L42 |
| `weapon_class(definition: ContentDefinition) -> String` | L49 |
| `accepts(socket: Dictionary, weapon: ContentDefinition) -> bool` | L56 |
| `total_weight(hub: RegistryHub, ship: Dictionary) -> float` | L61 |
| `install_blockers(hub: RegistryHub, state: GameState, weapon_id: String, socket_name: String, source: String = "purchase") -> Array[String]` | L77 |
| `install(ship: Dictionary, socket_name: String, weapon_id: String) -> String` | L110 |
| `uninstall(ship: Dictionary, socket_name: String) -> String` | L121 |
| `reconcile_for_hull(hub: RegistryHub, ship: Dictionary) -> Array[String]` | L135 |

- loadout 是 `{socket, weapon_id}` 数组；每个 socket 至多一件武器，数组按 hull socket 顺序输出。
- 武器是独立 `weapons` 内容，不进入 module_instances；港口仓库武器由 WarehouseOps 管理。
- 更换 hull 时 `reconcile_for_hull()` 保留同名且 class 兼容的装配，并返回应回仓的武器 id。

模块索引：[framework/domain](../README.md)
