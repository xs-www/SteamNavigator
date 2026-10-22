class_name FleetViewQuery
extends RefCounted
## @static-doc
## 作用：`fleet.view` 只读查询：输出旗舰 / 名册 / captain 指派 / 编队与槽位 /
## 战术（doctrine）以及容量。无 run 或旧档（缺 `data.fleet`）返回默认视图，且不
## 持久化状态（QueryBus 的克隆保证）。
##
## ## 契约与约束
## - 字段稳定：`flagship_id / ship_count / max_ships / ships[] / formation_id /
##   formation / doctrine_id / doctrine`。
## - `ships[]`：`{ship_id, is_flagship, archetype_id, archetype_name_key,
##   captain_id, captain_name_key, formation_slot, condition}`。
## - 旗舰的 archetype 由当前 `data.ship.hull_id` 反查 ship_archetypes，不复制模块状态。
## @end-static-doc


static func execute(_params: Dictionary, context) -> Dictionary:
	return Result.ok(FleetOps.view(context.state, context.registries))
