class_name ExpeditionCommands
extends RefCounted
## @static-doc
## 作用：Phase D5 遗迹远征的命令入口：`expedition.start` / `enter` / `choose` /
## `retreat`。都经 CommandBus 事务执行，失败不提交 `data.expedition` / `data.relics`；
## 成功时发布 `expedition.*` 领域事件。
##
## ## 契约与约束
## - 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
## - 引用/状态规则在 `ExpeditionService`：在港启动、唯一进行中远征、事件选项下标、
##   房间危险与完成奖励结算。
## @end-static-doc


static func start(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return ExpeditionService.start(context.state, context.registries, params)


static func enter(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return ExpeditionService.enter(context.state, context.registries, params)


static func choose(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return ExpeditionService.choose(context.state, context.registries, params)


static func retreat(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return ExpeditionService.retreat(context.state, context.registries, params)
