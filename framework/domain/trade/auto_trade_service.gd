class_name AutoTradeService
extends RefCounted
## @static-doc
## 作用：Phase D4 自动贸易的领域用例：启动/停止/切换贸易策略，手动暂停/恢复；
## 状态只落在 `data.trade`，买卖与风险结算由 `AutoTradeSystem` 在 tick 中执行。
##
## 关键依赖：`RegistryHub`（trade_policies / automation_rules）、`AutoTradeOps`、
## `MarketOps`、`GameState`
##
## ## 契约与约束
## - `start` 要求人在港口、没有正在运行的自动贸易，策略存在；母港 = 当前港。
## - `set_policy` 只在空闲且无货时允许，避免带着旧策略的货切换规则。
## - `stop` 清空自动货舱与运行态（不追回已发生的买卖），保留日志在清空后不可见。
## - 领域事件：`auto_trade.started` / `auto_trade.stopped` / `auto_trade.policy_changed` /
##   `auto_trade.paused` / `auto_trade.resumed`。
## @end-static-doc


static func start(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if AutoTradeOps.has_auto_trade(state):
		return Result.fail("trade_running", "ui.error.trade_running")
	var policy_id := String(params.get("policy_id", ""))
	var policy := AutoTradeOps.policy_definition(hub, policy_id)
	if policy == null:
		return Result.fail("unknown_trade_policy", "ui.error.unknown_trade_policy", {"policy_id": policy_id})
	var trade: Dictionary = AutoTradeOps.DEFAULT_TRADE.duplicate(true)
	trade["active"] = true
	trade["policy_id"] = policy.id
	trade["home_port_id"] = state.current_port_id()
	trade["at_port_id"] = state.current_port_id()
	state.data[AutoTradeOps.TRADE_KEY] = trade
	AutoTradeSystem.ensure_registered()
	return Result.ok({
		"trade": AutoTradeOps.view(state, hub),
	}, [{
		"type": "auto_trade.started",
		"payload": {"policy_id": policy.id, "home_port_id": String(trade["home_port_id"])},
	}])


static func stop(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary:
	if not AutoTradeOps.has_auto_trade(state):
		return Result.fail("no_trade", "ui.error.no_trade")
	var trade := state.data.get(AutoTradeOps.TRADE_KEY, {}) as Dictionary
	var policy_id := String(trade.get("policy_id", ""))
	state.data[AutoTradeOps.TRADE_KEY] = AutoTradeOps.DEFAULT_TRADE.duplicate(true)
	return Result.ok({
		"trade": AutoTradeOps.view(state, hub),
	}, [{
		"type": "auto_trade.stopped",
		"payload": {"policy_id": policy_id},
	}])


static func set_policy(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var trade := AutoTradeOps.ensure_structure(state)
	if trade.is_empty():
		return Result.fail("no_trade", "ui.error.no_trade")
	if String(trade.get("phase", "idle")) != "idle" or AutoTradeOps.cargo_units(trade) > 0:
		return Result.fail("trade_busy", "ui.error.trade_busy")
	var policy_id := String(params.get("policy_id", ""))
	var policy := AutoTradeOps.policy_definition(hub, policy_id)
	if policy == null:
		return Result.fail("unknown_trade_policy", "ui.error.unknown_trade_policy", {"policy_id": policy_id})
	trade["policy_id"] = policy.id
	return Result.ok({
		"trade": AutoTradeOps.view(state, hub),
	}, [{
		"type": "auto_trade.policy_changed",
		"payload": {"policy_id": policy.id},
	}])


static func pause(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary:
	var trade := AutoTradeOps.ensure_structure(state)
	if trade.is_empty():
		return Result.fail("no_trade", "ui.error.no_trade")
	trade["paused"] = true
	return Result.ok({
		"trade": AutoTradeOps.view(state, hub),
	}, [{"type": "auto_trade.paused", "payload": {}}])


static func resume(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary:
	var trade := AutoTradeOps.ensure_structure(state)
	if trade.is_empty():
		return Result.fail("no_trade", "ui.error.no_trade")
	trade["paused"] = false
	return Result.ok({
		"trade": AutoTradeOps.view(state, hub),
	}, [{"type": "auto_trade.resumed", "payload": {}}])
