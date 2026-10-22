class_name FleetCommands
extends RefCounted
## @static-doc
## 作用：Phase D2 舰队的命令入口：`fleet.assign_captain` / `fleet.set_formation` /
## `fleet.set_doctrine` / `fleet.add_ship` / `fleet.remove_ship`。都经 CommandBus
## 事务执行，失败不提交 `data.fleet`；成功时把 `fleet.*` 领域事件交给 CommandBus 发布。
##
## ## 契约与约束
## - 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
## - 校验/引用规则全部在 `FleetService`（captain 可指挥船型、captain 唯一、
##   formation slot 存在且互斥、doctrine 存在、fleet 容量、flagship 不可删）。
## - `fleet.set_formation` 支持 `{formation_id}`（整队编队）以及
##   `{ship_id, slot}`（单船槽位；slot 为 formation slots 的字符串 id）。
## - 不复制 `data.ship`；旗舰的 archetype 由当前 hull 反查。
## @end-static-doc


static func assign_captain(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return FleetService.assign_captain(context.state, context.registries, params)


static func set_formation(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return FleetService.set_formation(context.state, context.registries, params)


static func set_doctrine(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return FleetService.set_doctrine(context.state, context.registries, params)


static func add_ship(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return FleetService.add_ship(context.state, context.registries, params)


static func remove_ship(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return FleetService.remove_ship(context.state, context.registries, params)
