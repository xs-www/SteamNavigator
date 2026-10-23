class_name BaseCommands
extends RefCounted
## @static-doc
## 作用：Phase D3 基地的命令入口：`base.claim` / `base.build` / `base.upgrade` /
## `base.deposit` / `base.withdraw` / `base.hire_worker` / `base.assign_worker` /
## `base.start_production`。都经 CommandBus 事务执行，失败不提交 `data.base`；成功时
## 把 `base.*` 领域事件交给 CommandBus 发布。
##
## ## 契约与约束
## - 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
## - 校验/引用规则全部在 `BaseService`（基地唯一、建筑槽位、配方归属、工人槽位、
##   仓储容量、在基地港口存取等）。
## - `base.claim` 绑定当前港口；`deposit` / `withdraw` 要求当前港 == 基地港。
## - 生产由 tick 系统推进，命令只负责锁存输入与订单。
## @end-static-doc


static func claim(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return BaseService.claim(context.state, context.registries, params)


static func build(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return BaseService.build(context.state, context.registries, params)


static func upgrade(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return BaseService.upgrade(context.state, context.registries, params)


static func deposit(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return BaseService.deposit(context.state, context.registries, params)


static func withdraw(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return BaseService.withdraw(context.state, context.registries, params)


static func hire_worker(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return BaseService.hire_worker(context.state, context.registries, params)


static func assign_worker(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return BaseService.assign_worker(context.state, context.registries, params)


static func start_production(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return BaseService.start_production(context.state, context.registries, params)
