class_name TradeCommands
extends RefCounted

static func buy(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var port_id := String(params.get("port_id", state.current_port_id()))
	var item_id := String(params.get("item_id", ""))
	var amount := int(params.get("amount", 1))
	var profile := _profile(context)
	var margin := float(profile.get("trade_margin", MarketOps.DEFAULT_TRADE_MARGIN))
	var result := MarketOps.buy(state, context.registries, port_id, item_id, amount, margin)
	if bool(result["ok"]):
		var entry := MarketOps.entry_for(state, port_id, item_id)
		result["events"] = [{
			"type": "market.changed",
			"payload": {
				"port_id": port_id,
				"item_id": item_id,
				"source": "player",
				"stock": int(entry.get("stock", 0)),
				"price_after": float(entry.get("price", 0.0)),
			},
		}]
	return result


static func sell(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var port_id := String(params.get("port_id", state.current_port_id()))
	var item_id := String(params.get("item_id", ""))
	var amount := int(params.get("amount", 1))
	var profile := _profile(context)
	var margin := float(profile.get("trade_margin", MarketOps.DEFAULT_TRADE_MARGIN))
	var result := MarketOps.sell(state, context.registries, port_id, item_id, amount, margin)
	if bool(result["ok"]):
		var entry := MarketOps.entry_for(state, port_id, item_id)
		result["events"] = [{
			"type": "market.changed",
			"payload": {
				"port_id": port_id,
				"item_id": item_id,
				"source": "player",
				"stock": int(entry.get("stock", 0)),
				"price_after": float(entry.get("price", 0.0)),
			},
		}]
	return result


static func _profile(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}
