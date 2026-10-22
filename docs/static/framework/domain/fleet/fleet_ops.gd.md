# `framework/domain/fleet/fleet_ops.gd`

> 作用：Phase D2 舰队（fleet）的纯结构助手：惰性维护 `data.fleet`、解析旗舰条目、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FleetOps` | L1 |
| `FLEET_KEY` | L21 |
| `FLAGSHIP_ID` | L22 |
| `MAX_SHIPS` | L23 |
| `DEFAULT_SHIP` | L24 |
| `DEFAULT_FLEET` | L31 |
| `ensure_structure(state: GameState, hub: RegistryHub = null) -> Dictionary` | L40 |
| `view(state: GameState, hub: RegistryHub = null) -> Dictionary` | L75 |
| `flagship_archetype_id(state: GameState, hub: RegistryHub = null) -> String` | L114 |
| `max_ships(hub: RegistryHub = null, formation_id: String = "") -> int` | L128 |
| `formation_slot_ids(hub: RegistryHub, formation_id: String) -> Array[String]` | L136 |
| `formation_slot(hub: RegistryHub, formation_id: String, slot_id: String) -> Dictionary` | L149 |
| `ship_entry(fleet: Dictionary, ship_id: String) -> Dictionary` | L160 |
| `is_valid_slot_id(slot_id: String) -> bool` | L167 |
| `next_ship_id(fleet: Dictionary) -> String` | L173 |

编队槽位、引用与视图数据。持久状态只记录「队伍编成」（ship_id / archetype_id /
captain_id / formation_slot / condition）与 doctrine / formation 选择，**不复制**
当前单船 `data.ship` 的模块 / 耐久 / 货舱状态。

## 契约与约束
- `data.fleet = {flagship: "flagship", ships: [{ship_id, archetype_id, captain_id,
  formation_slot, condition}], doctrine_id, formation_id}`；flagship 条目固定
  `ship_id = "flagship"` 且永远存在。
- 旗舰的 `archetype_id` 由当前 `data.ship.hull_id` 反查 `ship_archetypes.hull_ref`
  得到（不写死内容 id）；hull 升级后 ensure 会重新同步。
- 其余船是「名册条目」，只保存编队元数据；最多 `MAX_SHIPS` 艘（含旗舰）。
- formation slot 是 formations 定义里的字符串 slot id；空串表示未分配。
- `view()` 只读，缺 `data.fleet` 时返回默认视图而不写状态；`ensure_structure()`
  才会持久化/修复块。

模块索引：[framework/domain](../README.md)
