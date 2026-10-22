# `framework/domain/fleet/fleet_service.gd`

> 作用：Phase D2 舰队的领域用例：舰长指派、编队/槽位、战术选择、增删舰船。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FleetService` | L1 |
| `assign_captain(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L26 |
| `set_formation(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L74 |
| `set_doctrine(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L138 |
| `add_ship(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L156 |
| `remove_ship(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L212 |

所有入口返回 `Result`（`{ok,error_code,message_key,data,events}`），由应用层命令
在 CommandBus 事务内调用；状态只落在 `data.fleet`，不复制 `data.ship`。

关键依赖：`RegistryHub`（ship_archetypes / captains / formations /
fleet_doctrines）、`FleetOps`、`GameState`

## 契约与约束
- 引用校验：ship archetype / captain / formation / doctrine 必须存在；captain 的
  `commandable_archetypes` 必须包含目标船的 archetype；formation slot 必须存在于
  当前 formation 且互斥；doctrine 的 `formation` 引用若存在则必须可解析。
- 旗舰：`data.fleet.flagship = "flagship"`，其 archetype 始终由 `data.ship.hull_id`
  反查，不允许 remove；`assign_captain` 对旗舰同样校验可指挥船型。
- 容量：`FleetOps.MAX_SHIPS` 为框架上限，当前 formation 的 `max_ships` 可进一步收紧。
- 领域事件（由命令层发布）：`fleet.captain_assigned` / `fleet.formation_changed` /
  `fleet.slot_assigned` / `fleet.doctrine_changed` / `fleet.ship_added` /
  `fleet.ship_removed`。
- 同一 captain 只能指挥一艘船；删除船会隐式释放其 captain（不复制其它状态）。

模块索引：[framework/domain](../README.md)
