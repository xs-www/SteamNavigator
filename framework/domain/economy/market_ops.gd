class_name MarketOps
extends RefCounted
## Deterministic market pricing, trading, supplies and repairs.

const DEFAULT_TRADE_MARGIN := 0.95
const MIN_PRICE_FACTOR := 0.55
const MAX_PRICE_FACTOR := 2.2
const SELL_ONLY_PRICE_FACTOR := 0.9
const DEFAULT_PLAYER_PRICE_IMPACT := 0.35
const PRICE_HISTORY_LIMIT := 8


static func create_market_entry(item_definition: ContentDefinition, stock: int, price_bias: float = 1.0) -> Dictionary:
	var base_price := float(item_definition.data.get("base_price", 1.0))
	var base_stock := float(item_definition.data.get("base_stock", 100.0))
	var elasticity := float(item_definition.data.get("price_elasticity", 0.15))
	var entry := {
		"item_id": item_definition.id,
		"stock": maxi(1, stock),
		"base_stock": base_stock,
		"base_price": base_price,
		"price_bias": price_bias,
		"elasticity": elasticity,
		"buyable": true,
		"price": 0.0,
		"price_history": [],
	}
	recalc(entry)
	return entry


static func compute_price(entry: Dictionary) -> float:
	var base_stock := maxf(1.0, float(entry.get("base_stock", 1)))
	if not bool(entry.get("buyable", true)):
		# Ports will buy any cargo, but goods outside the local assortment do
		# not have a real buy-side market. The more the player dumps, the lower
		# the one-way purchase price becomes.
		var held := maxf(0.0, float(entry.get("stock", 0)))
		var factor := clampf(base_stock / maxf(1.0, base_stock + held), 0.45, 1.0)
		return maxf(1.0, float(entry.get("base_price", 1)) * SELL_ONLY_PRICE_FACTOR * factor)
	var stock := maxf(1.0, float(entry.get("stock", 1)))
	var ratio := base_stock / stock
	var elasticity := float(entry.get("elasticity", 0.15))
	var factor := clampf(pow(ratio, elasticity), MIN_PRICE_FACTOR, MAX_PRICE_FACTOR)
	return maxf(1.0, float(entry.get("base_price", 1)) * float(entry.get("price_bias", 1.0)) * factor)


static func recalc(entry: Dictionary) -> void:
	entry["price"] = compute_price(entry)
	if bool(entry.get("buyable", true)):
		_push_price_history(entry, float(entry["price"]))


static func _push_price_history(entry: Dictionary, price: float) -> void:
	var history: Array = entry.get("price_history", [])
	history.append(price)
	while history.size() > PRICE_HISTORY_LIMIT:
		history.pop_front()
	entry["price_history"] = history


## Player trades move the live price only part-way toward the new equilibrium.
## NPC trades still reprice fully, so the world can move without the player's
## single purchase hammering the local market.
static func _apply_player_price_change(entry: Dictionary, price_before: float, impact: float) -> void:
	var target := compute_price(entry)
	entry["price"] = lerpf(price_before, target, clampf(impact, 0.0, 1.0))
	if bool(entry.get("buyable", true)):
		_push_price_history(entry, float(entry["price"]))


static func market_for(state: GameState, port_id: String) -> Dictionary:
	return state.market().get(port_id, {})


static func entry_for(state: GameState, port_id: String, item_id: String) -> Dictionary:
	return market_for(state, port_id).get(item_id, {})


static func initialize_port_market(hub: RegistryHub, archetype: ContentDefinition, rng: RandomNumberGenerator) -> Dictionary:
	var market := {}
	var listed := {}
	var entries: Array = archetype.data.get("market", [])
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var item_id := String(raw_entry.get("good", ""))
		var item_definition := ShipOps.item_definition(hub, item_id)
		if item_definition == null:
			continue
		var stock_range: Array = raw_entry.get("stock_range", [50, 100])
		var minimum := int(stock_range[0]) if stock_range.size() > 0 else 50
		var maximum := int(stock_range[1]) if stock_range.size() > 1 else minimum
		var stock := rng.randi_range(mini(minimum, maximum), maxi(minimum, maximum))
		var price_bias := float(raw_entry.get("price_bias", 1.0))
		var entry := create_market_entry(item_definition, stock, price_bias)
		entry["buyable"] = true
		market[item_id] = entry
		listed[item_id] = true
	# Every port buys every ordinary good/material, but only the listed
	# assortment has a buy-side market. Coal and water are handled separately
	# below as supply commodities.
	for content_type in [ContentTypes.GOOD, ContentTypes.MATERIAL]:
		for item_definition in hub.get_all(content_type):
			if listed.has(item_definition.id) or item_definition.has_tag("good.contract") or item_definition.has_tag("good.supply"):
				continue
			var entry := create_market_entry(item_definition, 1, SELL_ONLY_PRICE_FACTOR)
			entry["stock"] = 0
			entry["buyable"] = false
			recalc(entry)
			market[item_definition.id] = entry
	for item_definition in hub.get_all(ContentTypes.GOOD):
		var supply_kind := supply_kind_for(item_definition)
		if supply_kind.is_empty():
			continue
		var entry := create_market_entry(item_definition, rng.randi_range(90, 180), 1.0)
		entry["is_supply"] = true
		entry["supply_kind"] = supply_kind
		market[item_definition.id] = entry
	return market


static func supply_kind_for(definition: ContentDefinition) -> String:
	if definition.has_tag("supply.coal"):
		return "coal"
	if definition.has_tag("supply.water"):
		return "water"
	return ""


static func supply_entry_for(state: GameState, port_id: String, kind: String) -> Dictionary:
	for entry in market_for(state, port_id).values():
		if entry is Dictionary and bool(entry.get("is_supply", false)) and String(entry.get("supply_kind", "")) == kind:
			return entry
	return {}


## Adds sell-only entries to markets created before the all-goods model.
static func ensure_sell_only_entries(hub: RegistryHub, state: GameState) -> void:
	for port_id in state.market().keys():
		var market: Dictionary = state.market()[port_id]
		for entry in market.values():
			if entry is Dictionary and not entry.has("buyable"):
				entry["buyable"] = true
		for content_type in [ContentTypes.GOOD, ContentTypes.MATERIAL]:
			for item_definition in hub.get_all(content_type):
				if market.has(item_definition.id) or item_definition.has_tag("good.contract") or item_definition.has_tag("good.supply"):
					continue
				var entry := create_market_entry(item_definition, 1, SELL_ONLY_PRICE_FACTOR)
				entry["stock"] = 0
				entry["buyable"] = false
				recalc(entry)
				market[item_definition.id] = entry
		for item_definition in hub.get_all(ContentTypes.GOOD):
			var supply_kind := supply_kind_for(item_definition)
			if supply_kind.is_empty() or market.has(item_definition.id):
				continue
			var entry := create_market_entry(item_definition, 120, 1.0)
			entry["is_supply"] = true
			entry["supply_kind"] = supply_kind
			market[item_definition.id] = entry


static func buy(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int, trade_margin: float = DEFAULT_TRADE_MARGIN, price_impact: float = DEFAULT_PLAYER_PRICE_IMPACT) -> Dictionary:
	if state.current_port_id() != port_id or not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount")
	var item_definition := ShipOps.item_definition(hub, item_id)
	if item_definition == null:
		return Result.fail("unknown_item", "ui.error.unknown_item", {"item_id": item_id})
	var entry := entry_for(state, port_id, item_id)
	if entry.is_empty():
		return Result.fail("item_not_traded", "ui.error.item_not_traded", {"item_id": item_id, "port_id": port_id})
	if bool(entry.get("is_supply", false)):
		return Result.fail("supply_only", "ui.error.supply_only", {"item_id": item_id, "port_id": port_id})
	if not bool(entry.get("buyable", true)):
		return Result.fail("not_buyable", "ui.error.not_buyable", {"item_id": item_id, "port_id": port_id})
	if int(entry.get("stock", 0)) < amount:
		return Result.fail("insufficient_stock", "ui.error.insufficient_stock", {"stock": int(entry.get("stock", 0))})
	var unit_price := float(entry.get("price", 1.0))
	var total := int(ceil(unit_price * float(amount)))
	if state.money() < total:
		return Result.fail("insufficient_money", "ui.error.money", {"required": total, "money": state.money()})
	var ship := state.ship()
	var unit_weight := float(item_definition.data.get("unit_weight", 0.0))
	var added_weight := unit_weight * float(amount)
	var max_weight := ShipOps.max_weight(hub, ship)
	if max_weight > 0.0 and ShipOps.total_weight(hub, state) + added_weight > max_weight + 0.0001:
		return Result.fail("weight_limit", "ui.error.weight", {"max_weight": max_weight})
	if ShipOps.cargo_used(hub, ship) + added_weight > ShipOps.cargo_capacity(hub, ship) + 0.0001:
		return Result.fail("cargo_capacity", "ui.error.capacity", {"capacity": ShipOps.cargo_capacity(hub, ship)})
	state.add_money(-total)
	state.record_expense(total)
	var price_before := unit_price
	entry["stock"] = int(entry.get("stock", 0)) - amount
	_apply_player_price_change(entry, price_before, price_impact)
	ShipOps.add_cargo(ship, item_id, amount, "", float(total))
	return Result.ok({
		"item_id": item_id,
		"amount": amount,
		"unit_price": unit_price,
		"total": total,
		"money": state.money(),
		"stock": int(entry["stock"]),
		"trade_margin": trade_margin,
	})


static func sell(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int, trade_margin: float = DEFAULT_TRADE_MARGIN, price_impact: float = DEFAULT_PLAYER_PRICE_IMPACT) -> Dictionary:
	if state.current_port_id() != port_id or not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount")
	var entry := entry_for(state, port_id, item_id)
	if entry.is_empty():
		return Result.fail("item_not_traded", "ui.error.item_not_traded", {"item_id": item_id, "port_id": port_id})
	if bool(entry.get("is_supply", false)):
		return Result.fail("supply_only", "ui.error.supply_only", {"item_id": item_id, "port_id": port_id})
	var ship := state.ship()
	var available := ShipOps.cargo_amount(ship, item_id, false)
	if available < amount:
		return Result.fail("insufficient_cargo", "ui.error.insufficient_cargo", {"available": available})
	var unit_price := float(entry.get("price", 1.0))
	var revenue := int(floor(unit_price * trade_margin * float(amount)))
	ShipOps.remove_cargo(ship, item_id, amount, false)
	entry["stock"] = int(entry.get("stock", 0)) + amount
	_apply_player_price_change(entry, unit_price, price_impact)
	state.add_money(revenue)
	state.record_income(revenue)
	return Result.ok({
		"item_id": item_id,
		"amount": amount,
		"unit_price": unit_price,
		"revenue": revenue,
		"money": state.money(),
		"stock": int(entry["stock"]),
	})


static func buy_supply(state: GameState, hub: RegistryHub, port_id: String, kind: String, amount: int, price_impact: float = DEFAULT_PLAYER_PRICE_IMPACT) -> Dictionary:
	if state.current_port_id() != port_id or not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if not MapOps.has_facility(MapOps.port(state.world(), port_id), "supply"):
		return Result.fail("no_supply", "ui.error.no_supply", {"port_id": port_id})
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount")
	if kind != "coal" and kind != "water":
		return Result.fail("unknown_supply", "ui.error.unknown_supply", {"kind": kind})
	var entry := supply_entry_for(state, port_id, kind)
	if entry.is_empty():
		return Result.fail("no_supply", "ui.error.no_supply", {"port_id": port_id})
	if int(entry.get("stock", 0)) < amount:
		return Result.fail("insufficient_stock", "ui.error.insufficient_stock", {"stock": int(entry.get("stock", 0))})
	var unit_price := float(entry.get("price", 0.0))
	var total := int(ceil(unit_price * float(amount)))
	if state.money() < total:
		return Result.fail("insufficient_money", "ui.error.money", {"required": total, "money": state.money()})
	var ship := state.ship()
	var unit_weight := ShipOps.COAL_WEIGHT if kind == "coal" else ShipOps.WATER_WEIGHT
	var max_weight := ShipOps.max_weight(hub, ship)
	if max_weight > 0.0 and ShipOps.total_weight(hub, state) + unit_weight * float(amount) > max_weight + 0.0001:
		return Result.fail("weight_limit", "ui.error.weight", {"max_weight": max_weight})
	state.add_money(-total)
	state.record_expense(total)
	entry["stock"] = int(entry.get("stock", 0)) - amount
	_apply_player_price_change(entry, unit_price, price_impact)
	ship[kind] = float(ship.get(kind, 0.0)) + float(amount)
	return Result.ok({
		"kind": kind,
		"amount": amount,
		"unit_price": unit_price,
		"total": total,
		"money": state.money(),
		"stock": float(ship[kind]),
		"port_stock": int(entry["stock"]),
		"price_after": float(entry["price"]),
	})


static func repair_cost(hub: RegistryHub, state: GameState, repair_per_point: float) -> Dictionary:
	var ship := state.ship()
	var maximum := ShipOps.durability_max(hub, ship)
	var missing := maxf(0.0, maximum - float(ship.get("durability", 0.0)))
	var stats := ShipOps.stats(hub, ship)
	var cost := int(ceil(missing * repair_per_point * float(stats.get("repair_cost_mul", 1.0))))
	return {
		"missing": missing,
		"cost": cost,
		"max_durability": maximum,
		"repair_cost_mul": float(stats.get("repair_cost_mul", 1.0)),
	}


static func repair(state: GameState, hub: RegistryHub, port_id: String, repair_per_point: float) -> Dictionary:
	if state.current_port_id() != port_id or not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if not MapOps.has_facility(MapOps.port(state.world(), port_id), "supply"):
		return Result.fail("no_supply", "ui.error.no_supply", {"port_id": port_id})
	var details := repair_cost(hub, state, repair_per_point)
	var missing := float(details["missing"])
	if missing <= 0.0:
		return Result.fail("not_damaged", "ui.error.not_damaged")
	var cost := int(details["cost"])
	if state.money() < cost:
		return Result.fail("insufficient_money", "ui.error.money", {"required": cost, "money": state.money()})
	state.add_money(-cost)
	state.record_expense(cost)
	var ship := state.ship()
	ship["durability"] = float(details["max_durability"])
	return Result.ok({
		"repaired": missing,
		"cost": cost,
		"money": state.money(),
		"durability": float(details["max_durability"]),
	})


static func total_market_value(state: GameState) -> float:
	var total := 0.0
	for port_id in state.market().keys():
		for item_id in state.market()[port_id].keys():
			var entry: Dictionary = state.market()[port_id][item_id]
			total += float(entry.get("price", 0.0)) * float(entry.get("stock", 0))
	return total
