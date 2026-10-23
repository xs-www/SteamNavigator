class_name SimCommands
extends RefCounted
## @static-doc
## 作用：Phase D0 模拟时钟的四个命令入口：`sim.pause` / `sim.resume` /
## `sim.set_speed` / `sim.advance`。都经 CommandBus 事务执行，失败不提交状态。
##
## ## 契约与约束
## - 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
## - `sim.set_speed` 参数 `speed` 必须是有限数值且在
##   `SimulationService.MIN_SPEED..MAX_SPEED`；否则 `invalid_speed` 且状态不变。
## - `sim.advance` 参数 `hours` 必须 `> 0` 且 `<= SimulationService.MAX_ADVANCE_HOURS`；
##   否则 `invalid_advance_hours`。暂停时命令仍成功但 `ticks = 0`。
## - `sim.advance` 把每个 tick 的 `sim.tick` 事件经 `Result.ok(..., events)` 交给
##   CommandBus 发布；pause / resume / set_speed 不发领域事件。
## - D0 不接 gameplay：不触发 port.wait / 航行 / 制作等既有时间语义。
## @end-static-doc


static func pause(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	SimulationService.pause(context.state)
	return Result.ok(SimulationService.view(context.state))


static func resume(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	SimulationService.resume(context.state)
	return Result.ok(SimulationService.view(context.state))


static func set_speed(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var speed := float(params.get("speed", SimulationService.DEFAULT_SPEED))
	if not SimulationService.is_valid_speed(speed):
		return Result.fail("invalid_speed", "ui.error.invalid_sim_speed", {
			"speed": speed,
			"min": SimulationService.MIN_SPEED,
			"max": SimulationService.MAX_SPEED,
		})
	SimulationService.set_speed(context.state, speed)
	return Result.ok(SimulationService.view(context.state))


static func advance(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var hours := float(params.get("hours", SimulationService.TICK_HOURS))
	if not SimulationService.is_valid_advance_hours(hours):
		return Result.fail("invalid_advance_hours", "ui.error.invalid_advance_hours", {
			"hours": hours,
			"min": 0.0,
			"max": SimulationService.MAX_ADVANCE_HOURS,
		})
	if BaseOps.has_base(context.state):
		BaseProductionSystem.ensure_registered()
	if AutoTradeOps.has_auto_trade(context.state):
		AutoTradeSystem.ensure_registered()
	var advanced := SimulationService.advance(context.state, hours, context)
	var events: Array = advanced.get("events", [])
	advanced.erase("events")
	return Result.ok(advanced, events)
