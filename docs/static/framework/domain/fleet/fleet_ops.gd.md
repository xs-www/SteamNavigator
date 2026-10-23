# `framework/domain/fleet/fleet_ops.gd`

> 作用：Phase D2 舰队（fleet）的纯结构助手：惰性维护 `data.fleet`、解析旗舰条目、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FleetOps` | L1 |
| `FLEET_KEY` | L28 |
| `FLAGSHIP_ID` | L29 |
| `FLAGSHIP_TAG` | L30 |
| `MAX_SHIPS` | L31 |
| `DEFAULT_SHIP` | L32 |
| `DEFAULT_FLEET` | L39 |
| `ensure_structure(state: GameState, hub: RegistryHub = null) -> Dictionary` | L48 |
| `view(state: GameState, hub: RegistryHub = null) -> Dictionary` | L58 |
| `flagship_archetype_id(state: GameState, hub: RegistryHub = null) -> String` | L100 |
| `max_ships(hub: RegistryHub = null, formation_id: String = "") -> int` | L121 |
| `formation_slot_ids(hub: RegistryHub, formation_id: String) -> Array[String]` | L132 |
| `formation_slot(hub: RegistryHub, formation_id: String, slot_id: String) -> Dictionary` | L145 |
| `formation_slot_role(hub: RegistryHub, formation_id: String, slot_id: String) -> String` | L155 |
| `flagship_slot_ids(hub: RegistryHub, formation_id: String) -> Array[String]` | L160 |
| `ship_entry(fleet: Dictionary, ship_id: String) -> Dictionary` | L174 |
| `is_valid_slot_id(slot_id: String) -> bool` | L181 |
| `next_ship_id(fleet: Dictionary) -> String` | L189 |

编队槽位、引用与视图数据。持久状态只记录「队伍编成」（ship_id / archetype_id /
captain_id / formation_slot / condition）与 doctrine / formation 选择，**不复制**
当前单船 `data.ship` 的模块 / 耐久 / 货舱状态。

## 契约与约束
- `data.fleet = {flagship: "flagship", ships: [{ship_id, archetype_id, captain_id,
  formation_slot, condition}], doctrine_id, formation_id}`；flagship 条目固定
  `ship_id = "flagship"` 且永远存在。
- 旗舰的 `archetype_id` 由当前 `data.ship.hull_id` 反查 `ship_archetypes.hull_ref`
  得到（不写死内容 id）；hull 升级后 ensure 会重新同步。同一 hull 有多个候选时
  优先带 `ship_archetype.flagship` tag 的定义，再按 id 字典序；跨引用校验保证
  每个 hull 最多一个带该 tag 的 archetype。
- 其余船是「名册条目」，只保存编队元数据；最多 `MAX_SHIPS` 艘（含旗舰）。
- 容量：有 formation 时默认按 `min(MAX_SHIPS, formation.slots.size())`，显式
  `max_ships` 同样以 MAX_SHIPS 封顶；无 formation 时用 `MAX_SHIPS`。formation
  Schema 的 slots / max_ships 上限与 MAX_SHIPS 一致。
- formation slot 是 formations 定义里的字符串 slot id；空串表示未分配。role 为
  `flagship` 的槽位只允许旗舰使用；每艘船一个槽位，槽位互斥。切换 formation 时
  清空失效槽位，以及 role 变为 `flagship` 的槽位上的非旗舰船。
- 损坏数据（`data.fleet` 不是字典、ships 不是数组、条目/字段类型不对）一律规范化
  为默认块或跳过，`view()` 绝不抛引擎错误；`view()` 只读不写状态。

模块索引：[framework/domain](../README.md)
