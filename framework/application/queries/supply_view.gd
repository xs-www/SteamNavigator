class_name SupplyViewQuery
extends RefCounted
## Supply dock ViewModel: coal/water prices, weight headroom and repair quote.
##
## Each tank exposes a stable physical capacity, so buying one supply can never
## inflate the other tank's fill ratio:
##   base_weight       = total_weight - coal_weight - water_weight
##   baseline_capacity = floor((max_weight - base_weight) / unit_weight)  # other tank empty
##   capacity          = floor((max_weight - base_weight - other_weight) / unit_weight)
##   cap_loss          = max(0, baseline_capacity - capacity)
## The lost headroom is exported as capacity / baseline_capacity / cap_loss /
## headroom so the UI can draw a reverse loss band from the right edge.

static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({"has_run": false, "has_supply": false})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var port_data := MapOps.port(state.world(), state.current_port_id())
	var has_supply := MapOps.has_facility(port_data, "supply")
	var profile := _profile(context)
	var prices: Dictionary = profile.get("supply_prices", {})
	var coal_entry := MarketOps.supply_entry_for(state, state.current_port_id(), "coal")
	var water_entry := MarketOps.supply_entry_for(state, state.current_port_id(), "water")
	var coal_price := float(coal_entry.get("price", prices.get("coal", 4.0)))
	var water_price := float(water_entry.get("price", prices.get("water", 2.0)))
	var coal_stock := int(coal_entry.get("stock", 0))
	var water_stock := int(water_entry.get("stock", 0))
	var repair_per_point := float(prices.get("repair_per_point", 6.0))
	var ship := state.ship()
	var total_weight := ShipOps.total_weight(hub, state)
	var max_weight := ShipOps.max_weight(hub, ship)
	var remaining_weight := maxf(0.0, max_weight - total_weight)
	var coal_amount := float(ship.get("coal", 0.0))
	var water_amount := float(ship.get("water", 0.0))
	var coal_weight := coal_amount * ShipOps.COAL_WEIGHT
	var water_weight := water_amount * ShipOps.WATER_WEIGHT
	var base_weight := maxf(0.0, total_weight - coal_weight - water_weight)
	var money := state.money()
	var stats := ShipOps.stats(hub, ship)
	var repair := MarketOps.repair_cost(hub, state, repair_per_point)
	var coal := _resource_view(
		"coal", coal_amount, float(stats.get("coal_rate", 0.0)), coal_price, coal_stock, has_supply, money,
		_capacity(max_weight, base_weight, water_weight, ShipOps.COAL_WEIGHT),
		_capacity(max_weight, base_weight, 0.0, ShipOps.COAL_WEIGHT),
		ShipOps.COAL_WEIGHT
	)
	var water := _resource_view(
		"water", water_amount, float(stats.get("water_rate", 0.0)), water_price, water_stock, has_supply, money,
		_capacity(max_weight, base_weight, coal_weight, ShipOps.WATER_WEIGHT),
		_capacity(max_weight, base_weight, 0.0, ShipOps.WATER_WEIGHT),
		ShipOps.WATER_WEIGHT
	)
	return Result.ok({
		"has_run": true,
		"at_port": state.is_at_port(),
		"port_id": state.current_port_id(),
		"port_name_key": String(port_data.get("name_key", state.current_port_id())),
		"has_supply": has_supply,
		"coal_price": coal_price,
		"water_price": water_price,
		"coal_stock": coal_stock,
		"water_stock": water_stock,
		"repair_per_point": repair_per_point,
		"money": money,
		"coal": coal_amount,
		"water": water_amount,
		"coal_view": coal,
		"water_view": water,
		"durability": float(ship.get("durability", 0.0)),
		"total_weight": total_weight,
		"max_weight": max_weight,
		"remaining_weight": remaining_weight,
		"max_coal": int(coal["max_buy"]),
		"max_water": int(water["max_buy"]),
		"repair": repair,
		"can_repair": has_supply and state.is_at_port() and float(repair.get("missing", 0.0)) > 0.0 and money >= int(repair.get("cost", 0)),
	})


## Stable physical capacity for one tank: max weight minus non-supply weight and
## minus the other tank's weight, floored to whole units.
static func _capacity(max_weight: float, base_weight: float, other_weight: float, unit_weight: float) -> int:
	if unit_weight <= 0.0:
		return 0
	return maxi(0, int(floor((max_weight - base_weight - other_weight) / unit_weight)))


static func _resource_view(kind: String, current: float, rate: float, price: float, port_stock: int, has_supply: bool, money: int, capacity: int, baseline_capacity: int, unit_weight: float) -> Dictionary:
	var cap_loss := maxi(0, baseline_capacity - capacity)
	var headroom := maxf(0.0, float(capacity) - current)
	var affordable := int(floor(float(money) / maxf(0.01, price)))
	var max_buy := maxi(0, mini(mini(int(floor(headroom)), port_stock), affordable))
	var fill_to := current + float(max_buy)
	var safe_level := minf(fill_to, rate * 24.0 * 2.0)
	var daily_rate := rate * 24.0
	var blockers: Array[String] = []
	if not has_supply:
		blockers.append("no_supply")
	if port_stock <= 0:
		blockers.append("no_stock")
	if headroom < unit_weight:
		blockers.append("weight_limit")
	if money < int(ceil(price)):
		blockers.append("insufficient_money")
	return {
		"kind": kind,
		"current": current,
		"fill_to": fill_to,
		"maximum": maxf(current, float(capacity)),
		"maximum_baseline": maxf(current, float(baseline_capacity)),
		"capacity": capacity,
		"baseline_capacity": baseline_capacity,
		"cap_loss": cap_loss,
		"headroom": headroom,
		"safe_level": safe_level,
		"estimated_days": current / daily_rate if daily_rate > 0.0 else -1.0,
		"daily_rate": daily_rate,
		"price": price,
		"port_stock": port_stock,
		"max_buy": max_buy,
		"fill_cost": int(ceil(price * float(max_buy))),
		"can_buy": has_supply and max_buy > 0,
		"blockers": blockers,
		"unit_weight": unit_weight,
	}


static func _profile(context) -> Dictionary:
	return ContentRefs.map_config_data(context.state, context.registries)
