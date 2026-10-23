class_name AutoTradeCommands
extends RefCounted
## @static-doc
## 作用：Phase D4 自动贸易的命令入口：`auto_trade.start` / `stop` / `set_policy` /
## `pause` / `resume`。都经 CommandBus 事务执行，失败不提交 `data.trade`；成功时
## 发布 `auto_trade.*` 领域事件。
##
## ## 契约与约束
## - 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
## - 引用/状态规则在 `AutoTradeService`：唯一运行中贸易、在港启动、策略存在、
##   有货时不切策略。
## - 买卖与风险只在 tick 中发生，命令只改运行意图。
## @end-static-doc


static func start(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return AutoTradeService.start(context.state, context.registries, params)


static func stop(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return AutoTradeService.stop(context.state, context.registries, params)


static func set_policy(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return AutoTradeService.set_policy(context.state, context.registries, params)


static func pause(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return AutoTradeService.pause(context.state, context.registries, params)


static func resume(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return AutoTradeService.resume(context.state, context.registries, params)
