class_name AutoTradeSystem
extends RefCounted
## @static-doc
## 作用：Phase D4 自动贸易的确定性 tick 系统：按策略在港口之间自动买卖，处理航程、
## 风险、规则暂停/恢复与利润统计。由 `AutoTradeService.start` 惰性注册到
## `TickScheduler`（id `auto_trade`，priority 110），`sim.advance` 驱动。
##
## ## 契约与约束
## - 只在 `data.trade.active` 时工作；没有注册表上下文时 no-op。
## - phase `idle` → 选出目标港并买入（无满足 `min_margin` 的路线时保持空闲）；
##   `outbound` / `returning` 每 tick 递减 `travel_remaining`，到 0 时结算。
## - 抵达目标港时先按 policy.risk 掷一次确定性风险（seed = policy_id + tick），
##   命中则损失一半货舱；随后全部卖出并开始返航。
## - 规则在每 tick 开始按 priority 顺序评估；`pause` 后本 tick 不再推进。
## - 只改 `data.trade`、港口市场库存/价格与玩家金钱；不改玩家船货舱。
## @end-static-doc

const SYSTEM_ID := "auto_trade"
const PRIORITY := 110


static func register() -> void:
	TickScheduler.register(SYSTEM_ID, PRIORITY, Callable(AutoTradeSystem, "tick"))


static func ensure_registered() -> void:
	if not TickScheduler.has(SYSTEM_ID):
		register()


static func tick(state: GameState, tick: int, context = null) -> void:
	if state == null or context == null or not AutoTradeOps.has_auto_trade(state):
		return
	var hub: RegistryHub = context.registries
	var trade := AutoTradeOps.ensure_structure(state)
	if trade.is_empty():
		return
	if AutoTradeOps.evaluate_rules(state, hub, trade, tick, "tick"):
		return
	var policy := AutoTradeOps.policy_definition(hub, String(trade.get("policy_id", "")))
	if policy == null:
		return
	match String(trade.get("phase", "idle")):
		"idle":
			if AutoTradeOps.buy_and_depart(state, hub, trade, tick, policy):
				AutoTradeOps.evaluate_rules(state, hub, trade, tick, "departure")
		"outbound":
			_advance_leg(state, hub, trade, tick, policy, true)
		"returning":
			_advance_leg(state, hub, trade, tick, policy, false)


static func _advance_leg(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int, policy: ContentDefinition, outbound: bool) -> void:
	var remaining := maxf(0.0, float(trade.get("travel_remaining", 0.0))) - 1.0
	trade["travel_remaining"] = maxf(0.0, remaining)
	if remaining > 0.0:
		return
	if outbound:
		trade["at_port_id"] = String(trade.get("target_port_id", ""))
		# Arrival rules run before risk/sale so `sell_now` rules (e.g. a full-cargo
		# sell rule) actually fire instead of being dead content.
		AutoTradeOps.evaluate_rules(state, hub, trade, tick, "arrival")
		_apply_risk(state, hub, trade, tick, policy)
		AutoTradeOps.sell_cargo(state, hub, trade, tick)
		trade["phase"] = "returning"
		trade["travel_remaining"] = maxf(1.0, float(policy.data.get("travel_hours", 1.0)))
	else:
		trade["at_port_id"] = String(trade.get("home_port_id", ""))
		trade["target_port_id"] = ""
		trade["phase"] = "idle"
		trade["travel_remaining"] = 0.0


static func _apply_risk(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int, policy: ContentDefinition) -> void:
	var risk := clampf(float(policy.data.get("risk", 0.0)), 0.0, 1.0)
	if risk <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("auto_trade:%s:%d" % [policy.id, tick])
	if rng.randf() >= risk:
		return
	var cargo: Dictionary = trade.get("cargo", {})
	var lost := 0
	for raw_item_id in cargo.keys():
		var item_id := String(raw_item_id)
		var amount := int(cargo[item_id])
		var cut := int(ceil(float(amount) * 0.5))
		cargo[item_id] = amount - cut
		lost += cut
		if int(cargo[item_id]) <= 0:
			cargo.erase(item_id)
	trade["cargo"] = cargo
	_append_risk_log(trade, tick, lost)


static func _append_risk_log(trade: Dictionary, tick: int, lost: int) -> void:
	var log: Array = trade.get("log", [])
	log.append({"tick": tick, "event": "risk", "item_id": "", "amount": lost, "money": 0})
	while log.size() > AutoTradeOps.LOG_LIMIT:
		log.pop_front()
	trade["log"] = log
