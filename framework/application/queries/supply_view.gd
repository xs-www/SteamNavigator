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
	var coal_price := float(prices.get("coal", 4.0))
	var water_price := float(prices.get("water", 2.0))
	var repair_per_point := float(prices.get("repair_per_point", 6.0))
	var ship := state.ship()
	var total_weight := ShipOps.total_weight(hub, state)
	var max_weight := ShipOps.max_weight(hub, ship)
	var remaining_weight := maxf(0.0, max_weight - total_weight)
	var money := state.money()
	var max_coal := mini(int(remaining_weight / ShipOps.COAL_WEIGHT), int(floor(money / maxf(0.01, coal_price))))
	var max_water := mini(int(remaining_weight / ShipOps.WATER_WEIGHT), int(floor(money / maxf(0.01, water_price))))
	var repair := MarketOps.repair_cost(hub, state, repair_per_point)
	return Result.ok({
		"has_run": true,
		"at_port": state.is_at_port(),
		"port_id": state.current_port_id(),
		"port_name_key": String(port_data.get("name_key", state.current_port_id())),
		"has_supply": has_supply,
		"coal_price": coal_price,
		"water_price": water_price,
		"repair_per_point": repair_per_point,
		"money": money,
		"coal": float(ship.get("coal", 0.0)),
		"water": float(ship.get("water", 0.0)),
		"durability": float(ship.get("durability", 0.0)),
		"total_weight": total_weight,
		"max_weight": max_weight,
		"remaining_weight": remaining_weight,
		"max_coal": maxi(0, max_coal),
		"max_water": maxi(0, max_water),
		"repair": repair,
		"can_repair": has_supply and state.is_at_port() and float(repair.get("missing", 0.0)) > 0.0 and money >= int(repair.get("cost", 0)),
	})


static func _profile(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}
