class_name SupplyViewQuery
extends RefCounted
## Supply dock ViewModel: coal/water prices, weight headroom and repair quote.

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
	var money := state.money()
	var max_coal := mini(int(remaining_weight / ShipOps.COAL_WEIGHT), int(floor(money / maxf(0.01, coal_price))))
	max_coal = mini(max_coal, coal_stock)
	var max_water := mini(int(remaining_weight / ShipOps.WATER_WEIGHT), int(floor(money / maxf(0.01, water_price))))
	max_water = mini(max_water, water_stock)
	var repair := MarketOps.repair_cost(hub, state, repair_per_point)
	var coal := _resource_view("coal", float(ship.get("coal", 0.0)), float(ShipOps.stats(hub, ship).get("coal_rate", 0.0)), coal_price, coal_stock, maxi(0, max_coal), has_supply, money, remaining_weight, ShipOps.COAL_WEIGHT)
	var water := _resource_view("water", float(ship.get("water", 0.0)), float(ShipOps.stats(hub, ship).get("water_rate", 0.0)), water_price, water_stock, maxi(0, max_water), has_supply, money, remaining_weight, ShipOps.WATER_WEIGHT)
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
		"coal": float(ship.get("coal", 0.0)),
		"water": float(ship.get("water", 0.0)),
		"coal_view": coal,
		"water_view": water,
		"durability": float(ship.get("durability", 0.0)),
		"total_weight": total_weight,
		"max_weight": max_weight,
		"remaining_weight": remaining_weight,
		"max_coal": maxi(0, max_coal),
		"max_water": maxi(0, max_water),
		"repair": repair,
		"can_repair": has_supply and state.is_at_port() and float(repair.get("missing", 0.0)) > 0.0 and money >= int(repair.get("cost", 0)),
	})


static func _resource_view(kind: String, current: float, rate: float, price: float, port_stock: int, max_buy: int, has_supply: bool, money: int, remaining_weight: float, unit_weight: float) -> Dictionary:
	var fill_to := current + float(max_buy)
	var safe_level := minf(fill_to, rate * 24.0 * 2.0)
	var daily_rate := rate * 24.0
	var blockers: Array[String] = []
	if not has_supply:
		blockers.append("no_supply")
	if port_stock <= 0:
		blockers.append("no_stock")
	if remaining_weight < unit_weight:
		blockers.append("weight_limit")
	if money < int(ceil(price)):
		blockers.append("insufficient_money")
	return {
		"kind": kind,
		"current": current,
		"fill_to": fill_to,
		"maximum": maxf(fill_to, current),
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
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}
