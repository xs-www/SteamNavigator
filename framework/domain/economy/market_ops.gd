class_name MarketOps
extends RefCounted
## Deterministic market pricing, trading, supplies and repairs.

const DEFAULT_TRADE_MARGIN := 0.95
const MIN_PRICE_FACTOR := 0.55
const MAX_PRICE_FACTOR := 2.2
const SELL_ONLY_PRICE_FACTOR := 0.9


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
	# assortment has a buy-side market.
	for content_type in [ContentTypes.GOOD, ContentTypes.MATERIAL]:
		for item_definition in hub.get_all(content_type):
			if listed.has(item_definition.id) or item_definition.has_tag("good.contract"):
				continue
			var entry := create_market_entry(item_definition, 1, SELL_ONLY_PRICE_FACTOR)
			entry["stock"] = 0
			entry["buyable"] = false
			recalc(entry)
			market[item_definition.id] = entry
	return market


## Adds sell-only entries to markets created before the all-goods model.
static func ensure_sell_only_entries(hub: RegistryHub, state: GameState) -> void:
	for port_id in state.market().keys():
		var market: Dictionary = state.market()[port_id]
		for entry in market.values():
			if entry is Dictionary and not entry.has("buyable"):
				entry["buyable"] = true
		for content_type in [ContentTypes.GOOD, ContentTypes.MATERIAL]:
			for item_definition in hub.get_all(content_type):
				if market.has(item_definition.id) or item_definition.has_tag("good.contract"):
					continue
				var entry := create_market_entry(item_definition, 1, SELL_ONLY_PRICE_FACTOR)
				entry["stock"] = 0
				entry["buyable"] = false
				recalc(entry)
				market[item_definition.id] = entry


static func buy(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int, trade_margin: float = DEFAULT_TRADE_MARGIN) -> Dictionary:
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
	entry["stock"] = int(entry.get("stock", 0)) - amount
	recalc(entry)
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


static func sell(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int, trade_margin: float = DEFAULT_TRADE_MARGIN) -> Dictionary:
	if state.current_port_id() != port_id or not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount")
	var entry := entry_for(state, port_id, item_id)
	if entry.is_empty():
		return Result.fail("item_not_traded", "ui.error.item_not_traded", {"item_id": item_id, "port_id": port_id})
	var ship := state.ship()
	var available := ShipOps.cargo_amount(ship, item_id, false)
	if available < amount:
		return Result.fail("insufficient_cargo", "ui.error.insufficient_cargo", {"available": available})
	var unit_price := float(entry.get("price", 1.0))
	var revenue := int(floor(unit_price * trade_margin * float(amount)))
	ShipOps.remove_cargo(ship, item_id, amount, false)
	entry["stock"] = int(entry.get("stock", 0)) + amount
	recalc(entry)
	state.add_money(revenue)
	return Result.ok({
		"item_id": item_id,
		"amount": amount,
		"unit_price": unit_price,
		"revenue": revenue,
		"money": state.money(),
		"stock": int(entry["stock"]),
	})


static func buy_supply(state: GameState, hub: RegistryHub, port_id: String, kind: String, amount: int, unit_price: float) -> Dictionary:
	if state.current_port_id() != port_id or not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount")
	if kind != "coal" and kind != "water":
		return Result.fail("unknown_supply", "ui.error.unknown_supply", {"kind": kind})
	var total := int(ceil(unit_price * float(amount)))
	if state.money() < total:
		return Result.fail("insufficient_money", "ui.error.money", {"required": total, "money": state.money()})
	var ship := state.ship()
	var unit_weight := ShipOps.COAL_WEIGHT if kind == "coal" else ShipOps.WATER_WEIGHT
	var max_weight := ShipOps.max_weight(hub, ship)
	if max_weight > 0.0 and ShipOps.total_weight(hub, state) + unit_weight * float(amount) > max_weight + 0.0001:
		return Result.fail("weight_limit", "ui.error.weight", {"max_weight": max_weight})
	state.add_money(-total)
	ship[kind] = float(ship.get(kind, 0.0)) + float(amount)
	return Result.ok({
		"kind": kind,
		"amount": amount,
		"total": total,
		"money": state.money(),
		"stock": float(ship[kind]),
	})


static func repair(state: GameState, hub: RegistryHub, port_id: String, repair_per_point: float) -> Dictionary:
	if state.current_port_id() != port_id or not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var ship := state.ship()
	var maximum := ShipOps.durability_max(hub, ship)
	var missing := maxf(0.0, maximum - float(ship.get("durability", 0.0)))
	if missing <= 0.0:
		return Result.fail("not_damaged", "ui.error.not_damaged")
	var stats := ShipOps.stats(hub, ship)
	var cost := int(ceil(missing * repair_per_point * float(stats.get("repair_cost_mul", 1.0))))
	if state.money() < cost:
		return Result.fail("insufficient_money", "ui.error.money", {"required": cost, "money": state.money()})
	state.add_money(-cost)
	ship["durability"] = maximum
	return Result.ok({
		"repaired": missing,
		"cost": cost,
		"money": state.money(),
		"durability": maximum,
	})


static func total_market_value(state: GameState) -> float:
	var total := 0.0
	for port_id in state.market().keys():
		for item_id in state.market()[port_id].keys():
			var entry: Dictionary = state.market()[port_id][item_id]
			total += float(entry.get("price", 0.0)) * float(entry.get("stock", 0))
	return total
