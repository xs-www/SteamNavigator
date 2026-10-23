# `framework/domain/fleet/fleet_service.gd`

> 作用：Phase D2 舰队的领域用例：舰长指派、编队/槽位、战术选择、增删舰船。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FleetService` | L1 |
| `assign_captain(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L34 |
| `set_formation(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L82 |
| `set_doctrine(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L176 |
| `add_ship(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L194 |
| `remove_ship(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L256 |
| `reconcile_flagship_after_hull_change(state: GameState, hub: RegistryHub) -> Array` | L278 |

所有入口返回 `Result`（`{ok,error_code,message_key,data,events}`），由应用层命令
在 CommandBus 事务内调用；状态只落在 `data.fleet`，不复制 `data.ship`。

关键依赖：`RegistryHub`（ship_archetypes / captains / formations /
fleet_doctrines）、`FleetOps`、`GameState`

## 契约与约束
- 引用校验：ship archetype / captain / formation / doctrine 必须存在；captain 的
  `commandable_archetypes` 必须包含目标船的 archetype；formation slot 必须存在于
  当前 formation 且互斥；doctrine 的 `formation` 引用若存在则必须可解析。
- 旗舰：`data.fleet.flagship = "flagship"`，其 archetype 始终由 `data.ship.hull_id`
  反查，不允许 remove；`assign_captain` 对旗舰同样校验可指挥船型。role 为
  `flagship` 的 formation 槽位只能由旗舰使用（`flagship_slot_only`）；`add_ship`
  自动分配槽位时跳过旗舰槽与已占槽。`ship.install_module` 换 hull 后调用
  `reconcile_flagship_after_hull_change`，释放已无法指挥新旗舰 archetype 的舰长。
- 容量：`FleetOps.MAX_SHIPS` 为框架上限；有 formation 时缺省按
  `min(MAX_SHIPS, formation.slots.size())`，显式 `max_ships` 也以 MAX_SHIPS 封顶；
  无 formation 时用 MAX_SHIPS。
- 清空语义：`captain_id:""` / `doctrine_id:""` 清空对应选择；`slot:""` 清空单船槽位；
  `formation_id:""` 清空整队编队并清空所有槽位。切换 formation 时还会清空 role 变成
  `flagship` 的槽位上的非旗舰船。
- 领域事件（由命令层发布）：`fleet.captain_assigned` / `fleet.formation_changed` /
  `fleet.slot_assigned` / `fleet.doctrine_changed` / `fleet.ship_added` /
  `fleet.ship_removed`。
- 同一 captain 只能指挥一艘船；删除船会隐式释放其 captain（不复制其它状态）。

模块索引：[framework/domain](../README.md)
