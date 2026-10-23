class_name AutoTradeOps
extends RefCounted
## @static-doc
## 作用：Phase D4 自动贸易的纯结构/计算层：规范化 `data.trade`、读取贸易策略与
## 自动化规则、挑选买卖港口与商品、维护自动货舱、直接按港口市场价结算买卖，并给出
## 只读 `auto_trade.view` 数据。
##
## ## 契约与约束
## - `data.trade` 只在 `auto_trade.start` 后存在：`{active, policy_id, phase,
##   paused, home_port_id, target_port_id, at_port_id, travel_remaining,
##   cargo{item:qty}, legs, spent, earned, profit, log[]}`。
## - phase：`idle`（在母港等待）/ `outbound`（前往目标港）/ `returning`（返航）。
## - 只在已发现港口之间自动贸易；目标港按策略的 `sell_port_tags` / `buy_port_tags`
##   过滤，按“售价 - 买价”的利润率挑最高且 ≥ `min_margin` 的组合。
## - 自动货舱按 `max_cargo` 计件，不使用玩家船货舱；买卖直接改对应港口市场库存与
##   价格（`MarketOps.compute_price/recalc`），金额计入收入/支出统计。
## - 风险只在抵达目标港时掷一次；随机种子由 policy_id + tick 派生，保证同 tick 可复现。
## - 损坏数据一律规范化，`view()` 不写状态且不抛引擎错误。
## @end-static-doc

const TRADE_KEY := "trade"
const PHASES := ["idle", "outbound", "returning"]
const DEFAULT_TRADE := {
	"active": false,
	"policy_id": "",
	"phase": "idle",
	"paused": false,
	"home_port_id": "",
	"target_port_id": "",
	"at_port_id": "",
	"travel_remaining": 0.0,
	"cargo": {},
	"legs": 0,
	"spent": 0,
	"earned": 0,
	"profit": 0,
	"log": [],
}
const LOG_LIMIT := 8


static func has_auto_trade(state: GameState) -> bool:
	if state == null:
		return false
	var raw: Variant = state.data.get(TRADE_KEY, null)
	return raw is Dictionary and _safe_bool((raw as Dictionary).get("active", false), false)


## Returns the live trade block, or `{}` when auto trade is not active.
static func ensure_structure(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var raw: Variant = state.data.get(TRADE_KEY, null)
	if not (raw is Dictionary) or not _safe_bool((raw as Dictionary).get("active", false), false):
		return {}
	var trade := _normalize(raw)
	state.data[TRADE_KEY] = trade
	return trade


static func policy_definition(hub: RegistryHub, policy_id: String) -> ContentDefinition:
	if hub == null or policy_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.TRADE_POLICY, policy_id)


static func rule_definition(hub: RegistryHub, rule_id: String) -> ContentDefinition:
	if hub == null or rule_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.AUTOMATION_RULE, rule_id)


## Rules belonging to a policy, ordered by priority then id.
static func policy_rules(hub: RegistryHub, policy: ContentDefinition) -> Array:
	var rules: Array = []
	if policy == null:
		return rules
	for rule_id in policy.data.get("rules", []):
		var rule := rule_definition(hub, String(rule_id))
		if rule != null:
			rules.append(rule)
	rules.sort_custom(func(left: ContentDefinition, right: ContentDefinition) -> bool:
		var left_priority := int(left.data.get("priority", 0))
		var right_priority := int(right.data.get("priority", 0))
		if left_priority != right_priority:
			return left_priority < right_priority
		return left.id < right.id
	)
	return rules


static func condition_met(state: GameState, hub: RegistryHub, trade: Dictionary, policy: ContentDefinition, rule: ContentDefinition) -> bool:
	var condition: Dictionary = rule.data.get("condition", {})
	var op := String(condition.get("op", "always"))
	var value := float(condition.get("value", 0.0))
	var cargo := cargo_units(trade)
	match op:
		"always":
			return true
		"money_gte":
			return float(state.money()) >= value
		"money_lte":
			return float(state.money()) <= value
		"cargo_gte":
			return float(cargo) >= value
		"cargo_lte":
			return float(cargo) <= value
		"margin_gte":
			var target := choose_target(state, hub, policy, String(trade.get("at_port_id", "")))
			return not target.is_empty() and float(target.get("margin", 0.0)) >= value
		"risk_gte":
			return float(policy.data.get("risk", 0.0)) >= value
	return false


static func apply_rule_action(state: GameState, hub: RegistryHub, trade: Dictionary, rule: ContentDefinition, tick: int) -> void:
	var action := String(rule.data.get("action", ""))
	match action:
		"pause":
			if not bool(trade.get("paused", false)):
				trade["paused"] = true
				_append_log(trade, tick, "paused", "", 0, 0)
		"resume":
			if bool(trade.get("paused", false)):
				trade["paused"] = false
				_append_log(trade, tick, "resumed", "", 0, 0)
		"sell_now":
			var target := String(trade.get("target_port_id", ""))
			if String(trade.get("at_port_id", "")) == target and cargo_units(trade) > 0:
				_sell_cargo(state, hub, trade, tick)
				trade["phase"] = "returning"
				trade["travel_remaining"] = float(_travel_hours(policy_definition(hub, String(trade.get("policy_id", "")))))
		"buy_now":
			if String(trade.get("phase", "")) == "idle" and cargo_units(trade) == 0:
				_buy_and_depart(state, hub, trade, tick, policy_definition(hub, String(trade.get("policy_id", ""))))


static func cargo_units(trade: Dictionary) -> int:
	var total := 0
	for raw_item_id in (trade.get("cargo", {}) as Dictionary).keys():
		total += int((trade.get("cargo", {}) as Dictionary)[raw_item_id])
	return total


static func cargo_view(hub: RegistryHub, trade: Dictionary) -> Array:
	var rows: Array = []
	var cargo: Dictionary = trade.get("cargo", {})
	var item_ids: Array = cargo.keys()
	item_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	for raw_item_id in item_ids:
		var amount := int(cargo[raw_item_id])
		if amount <= 0:
			continue
		var item := hub.get_by_id(ContentTypes.ITEM, String(raw_item_id)) if hub != null else null
		rows.append({
			"item_id": String(raw_item_id),
			"name_key": item.name_key if item != null else String(raw_item_id),
			"amount": amount,
		})
	return rows


## Best discovered target port / good for one leg, or `{}`.
static func choose_target(state: GameState, hub: RegistryHub, policy: ContentDefinition, home_port_id: String) -> Dictionary:
	if policy == null or home_port_id.is_empty() or hub == null:
		return {}
	var world := state.world()
	var ports: Dictionary = world.get("ports", {})
	var discovered: Array = Array(world.get("discovered_ports", []))
	var sell_tags: Array = Array(policy.data.get("sell_port_tags", []))
	var buy_tags: Array = Array(policy.data.get("buy_port_tags", []))
	if not buy_tags.is_empty():
		var home_port: Dictionary = ports.get(home_port_id, {})
		if not _matches_tags(Array(home_port.get("tags", [])), buy_tags):
			return {}
	var best: Dictionary = {}
	for raw_port_id in ports.keys():
		var port_id := String(raw_port_id)
		if port_id == home_port_id or not discovered.has(port_id):
			continue
		var port: Dictionary = ports[raw_port_id]
		var tags: Array = Array(port.get("tags", []))
		if not _matches_tags(tags, sell_tags):
			continue
		for raw_good_id in policy.data.get("goods", []):
			var good_id := String(raw_good_id)
			var buy_entry := MarketOps.entry_for(state, home_port_id, good_id)
			var sell_entry := MarketOps.entry_for(state, port_id, good_id)
			if buy_entry.is_empty() or sell_entry.is_empty():
				continue
			var buy_price := float(buy_entry.get("price", 0.0))
			var sell_price := MarketOps.compute_price(sell_entry)
			if buy_price <= 0.0:
				continue
			var margin := (sell_price - buy_price) / buy_price
			if margin < float(policy.data.get("min_margin", 0.0)):
				continue
			if best.is_empty() or margin > float(best.get("margin", -999.0)):
				best = {
					"port_id": port_id,
					"good_id": good_id,
					"buy_price": buy_price,
					"sell_price": sell_price,
					"margin": margin,
				}
	return best


static func buy_and_depart(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int, policy: ContentDefinition) -> bool:
	return _buy_and_depart(state, hub, trade, tick, policy)


static func sell_cargo(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int) -> bool:
	return _sell_cargo(state, hub, trade, tick)


## Runs policy rules for this tick phase; returns true when the automation should stop
## processing the rest of the tick (paused). `when` selects the trigger phase:
## `tick` at the start of a tick, `departure` right after a buy, `arrival` at the
## destination before risk/sale (so `sell_now` rules can fire there).
static func evaluate_rules(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int, when: String = "tick") -> bool:
	var policy := policy_definition(hub, String(trade.get("policy_id", "")))
	if policy == null:
		return true
	for rule in policy_rules(hub, policy):
		var rule_when := String(rule.data.get("when", "tick"))
		if rule_when != when:
			continue
		if not condition_met(state, hub, trade, policy, rule):
			continue
		apply_rule_action(state, hub, trade, rule, tick)
	if bool(trade.get("paused", false)):
		return true
	return false


static func view(state: GameState, hub: RegistryHub = null) -> Dictionary:
	var raw: Variant = state.data.get(TRADE_KEY, null) if state != null else null
	var trade := _normalize(raw)
	var policy := policy_definition(hub, String(trade.get("policy_id", "")))
	var home_name := _port_name(state, String(trade.get("home_port_id", "")))
	var target_name := _port_name(state, String(trade.get("target_port_id", "")))
	var at_name := _port_name(state, String(trade.get("at_port_id", "")))
	return {
		"active": bool(trade.get("active", false)),
		"policy_id": String(trade.get("policy_id", "")),
		"policy": _policy_view(policy),
		"phase": String(trade.get("phase", "idle")),
		"paused": bool(trade.get("paused", false)),
		"home_port_id": String(trade.get("home_port_id", "")),
		"home_port_name": home_name,
		"target_port_id": String(trade.get("target_port_id", "")),
		"target_port_name": target_name,
		"at_port_id": String(trade.get("at_port_id", "")),
		"at_port_name": at_name,
		"travel_remaining": float(trade.get("travel_remaining", 0.0)),
		"cargo": cargo_view(hub, trade),
		"cargo_units": cargo_units(trade),
		"max_cargo": int(policy.data.get("max_cargo", 0)) if policy != null else 0,
		"legs": int(trade.get("legs", 0)),
		"spent": int(trade.get("spent", 0)),
		"earned": int(trade.get("earned", 0)),
		"profit": int(trade.get("profit", 0)),
		"log": (trade.get("log", []) as Array).duplicate(true),
	}


static func _buy_and_depart(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int, policy: ContentDefinition) -> bool:
	if policy == null:
		return false
	var home_port_id := String(trade.get("home_port_id", ""))
	var target := choose_target(state, hub, policy, home_port_id)
	if target.is_empty():
		_append_log(trade, tick, "no_route", "", 0, 0)
		return false
	var good_id := String(target.get("good_id", ""))
	var target_port_id := String(target.get("port_id", ""))
	var entry := MarketOps.entry_for(state, home_port_id, good_id)
	var stock := int(entry.get("stock", 0))
	var price := float(entry.get("price", 0.0))
	if stock <= 0 or price <= 0.0:
		_append_log(trade, tick, "no_stock", good_id, 0, 0)
		return false
	var capacity := maxi(0, int(policy.data.get("max_cargo", 1)) - cargo_units(trade))
	var wallet := maxf(0.0, minf(float(policy.data.get("budget", 0.0)), float(state.money()) - float(policy.data.get("reserve_money", 0.0))))
	var affordable := int(floor(wallet / price))
	var amount := mini(mini(capacity, affordable), stock)
	if amount <= 0:
		_append_log(trade, tick, "budget_short", good_id, 0, 0)
		return false
	var cost := int(round(price * float(amount)))
	state.add_money(-cost)
	state.record_expense(cost)
	entry["stock"] = stock - amount
	MarketOps.recalc(entry)
	var cargo: Dictionary = trade.get("cargo", {})
	cargo[good_id] = int(cargo.get(good_id, 0)) + amount
	trade["cargo"] = cargo
	trade["target_port_id"] = target_port_id
	trade["at_port_id"] = home_port_id
	trade["phase"] = "outbound"
	trade["travel_remaining"] = float(policy.data.get("travel_hours", 1.0))
	trade["spent"] = int(trade.get("spent", 0)) + cost
	trade["legs"] = int(trade.get("legs", 0)) + 1
	_append_log(trade, tick, "bought", good_id, amount, cost)
	return true


static func _sell_cargo(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int) -> bool:
	var at_port_id := String(trade.get("at_port_id", ""))
	var cargo: Dictionary = trade.get("cargo", {})
	if cargo.is_empty():
		return false
	var revenue := 0
	var sold := 0
	var item_ids: Array = cargo.keys()
	item_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	for raw_item_id in item_ids:
		var item_id := String(raw_item_id)
		var amount := int(cargo[raw_item_id])
		if amount <= 0:
			continue
		var entry := MarketOps.entry_for(state, at_port_id, item_id)
		if entry.is_empty():
			continue
		var price := MarketOps.compute_price(entry)
		revenue += int(round(price * float(amount)))
		entry["stock"] = int(entry.get("stock", 0)) + amount
		MarketOps.recalc(entry)
		sold += amount
	if revenue <= 0:
		return false
	state.add_money(revenue)
	state.record_income(revenue)
	trade["cargo"] = {}
	trade["earned"] = int(trade.get("earned", 0)) + revenue
	trade["profit"] = int(trade.get("earned", 0)) - int(trade.get("spent", 0))
	_append_log(trade, tick, "sold", "", sold, revenue)
	return true


static func _append_log(trade: Dictionary, tick: int, event: String, item_id: String, amount: int, money: int) -> void:
	var log: Array = trade.get("log", [])
	log.append({"tick": tick, "event": event, "item_id": item_id, "amount": amount, "money": money})
	while log.size() > LOG_LIMIT:
		log.pop_front()
	trade["log"] = log


static func _travel_hours(policy: ContentDefinition) -> float:
	return maxf(1.0, float(policy.data.get("travel_hours", 1.0))) if policy != null else 1.0


static func _matches_tags(port_tags: Array, required: Array) -> bool:
	if required.is_empty():
		return true
	for tag in required:
		if port_tags.has(String(tag)):
			return true
	return false


static func _port_name(state: GameState, port_id: String) -> String:
	if state == null or port_id.is_empty():
		return ""
	var port: Dictionary = state.world().get("ports", {}).get(port_id, {})
	return String(port.get("name_key", port_id))


static func _policy_view(policy: ContentDefinition) -> Dictionary:
	if policy == null:
		return {}
	return {
		"id": policy.id,
		"name_key": policy.name_key,
		"goods": Array(policy.data.get("goods", [])).duplicate(),
		"budget": float(policy.data.get("budget", 0.0)),
		"reserve_money": float(policy.data.get("reserve_money", 0.0)),
		"max_cargo": int(policy.data.get("max_cargo", 0)),
		"travel_hours": float(policy.data.get("travel_hours", 0.0)),
		"risk": float(policy.data.get("risk", 0.0)),
		"min_margin": float(policy.data.get("min_margin", 0.0)),
	}


static func _normalize(raw: Variant) -> Dictionary:
	var trade: Dictionary = DEFAULT_TRADE.duplicate(true)
	if not (raw is Dictionary):
		return trade
	var source: Dictionary = raw
	for key in ["policy_id", "home_port_id", "target_port_id", "at_port_id"]:
		trade[key] = _safe_string(source.get(key, ""))
	var phase := _safe_string(source.get("phase", "idle"), "idle")
	trade["phase"] = phase if PHASES.has(phase) else "idle"
	trade["active"] = _safe_bool(source.get("active", false), false)
	trade["paused"] = _safe_bool(source.get("paused", false), false)
	trade["travel_remaining"] = maxf(0.0, _safe_float(source.get("travel_remaining", 0.0), 0.0))
	trade["legs"] = maxi(0, _safe_int(source.get("legs", 0), 0))
	trade["spent"] = maxi(0, _safe_int(source.get("spent", 0), 0))
	trade["earned"] = maxi(0, _safe_int(source.get("earned", 0), 0))
	trade["profit"] = _safe_int(source.get("profit", 0), 0)
	var cargo: Dictionary = {}
	var raw_cargo: Variant = source.get("cargo", {})
	if raw_cargo is Dictionary:
		for raw_item_id in (raw_cargo as Dictionary).keys():
			var amount := _safe_int((raw_cargo as Dictionary)[raw_item_id], 0)
			if amount > 0:
				cargo[String(raw_item_id)] = amount
	trade["cargo"] = cargo
	var log: Array = []
	var raw_log: Variant = source.get("log", [])
	if raw_log is Array:
		for entry in raw_log:
			if entry is Dictionary and log.size() < LOG_LIMIT:
				log.append(entry.duplicate(true))
	trade["log"] = log
	return trade


static func _safe_string(value: Variant, fallback: String = "") -> String:
	return value if value is String else fallback


static func _safe_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(value)
	return fallback


static func _safe_float(value: Variant, fallback: float = 0.0) -> float:
	if value is int or value is float:
		var number := float(value)
		return number if is_finite(number) else fallback
	return fallback


static func _safe_bool(value: Variant, fallback: bool = false) -> bool:
	return value if value is bool else fallback
