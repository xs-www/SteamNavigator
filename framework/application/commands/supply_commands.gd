class_name SupplyCommands
extends RefCounted

static func buy_coal(params: Dictionary, context) -> Dictionary:
	return _buy_supply("coal", params, context)


static func buy_water(params: Dictionary, context) -> Dictionary:
	return _buy_supply("water", params, context)


static func _buy_supply(kind: String, params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var port_id := String(params.get("port_id", state.current_port_id()))
	var amount := int(params.get("amount", 10))
	var profile := _profile(context)
	var impact := float(profile.get("player_trade_impact", MarketOps.DEFAULT_PLAYER_PRICE_IMPACT))
	var result := MarketOps.buy_supply(state, context.registries, port_id, kind, amount, impact)
	if bool(result["ok"]):
		MarketMemoryService.remember(state, port_id)
		result["events"] = [{
			"type": "supply.purchased",
			"payload": {"kind": kind, "amount": amount, "total": result["data"].get("total", 0)},
		}]
	return result


static func repair(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var port_id := String(params.get("port_id", state.current_port_id()))
	var prices: Dictionary = _profile(context).get("supply_prices", {})
	var repair_per_point := float(prices.get("repair_per_point", 6.0))
	var result := MarketOps.repair(state, context.registries, port_id, repair_per_point)
	if bool(result["ok"]):
		result["events"] = [{
			"type": "ship.repaired",
			"payload": {"repaired": result["data"].get("repaired", 0.0), "cost": result["data"].get("cost", 0)},
		}]
	return result


static func _profile(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}
