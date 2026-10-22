class_name PortTimeService
extends RefCounted
## @static-doc
## 作用：在港时间推进的统一领域入口。推进游戏时间，并让打造订单、NPC 市场模拟与
## 逾期债务检查按与 `port.wait` 完全相同的规则结算，供「在港等待」和「调查线索工时」
## 共用，避免两套时间语义。
##
## - 关键依赖：`GameState.advance_time`、`CraftOps.settle_orders`、
##   `NpcTraderSimulator.advance`、`DebtService.check_overdue`、`ContentRefs.map_config_data`
##
## ## 契约与约束
## - 只在命令 path 中调用（CommandBus 事务内）；`hours <= 0` 时只做订单 / NPC / 债务
##   结算（用于 0 工时内容的兼容路径），不推进时间。
## - 返回与 `port.wait` 历史结果同形状的字典：`hours` / `game_time` /
##   `completed_orders` / `npc_events` / `debt_events`，事件由调用方决定如何并入。
## - 时间推进后**不**做线索过期清理：调用方自己决定 sweep 时机（等待 / 调查各自
##   需要不同的顺序）。
## @end-static-doc


static func spend(context, hours: float) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var advanced := maxf(0.0, hours)
	if advanced > 0.0:
		state.advance_time(advanced)
	var completed_orders := CraftOps.settle_orders(state, hub)
	var npc_events := NpcTraderSimulator.advance(
		state,
		hub,
		context.rng,
		state.now(),
		_profile_data(context)
	)
	var debt_events := DebtService.check_overdue(state)
	return {
		"hours": advanced,
		"game_time": state.now(),
		"completed_orders": completed_orders,
		"npc_events": npc_events,
		"debt_events": debt_events,
	}


static func _profile_data(context) -> Dictionary:
	return ContentRefs.map_config_data(context.state, context.registries)
