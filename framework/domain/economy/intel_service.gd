class_name IntelService
extends RefCounted
## Builds immutable market/NPC intelligence snapshots.
##
## A snapshot is never auto-updated. It keeps `generated_at` until the player
## visits an intelligence station again.

static func build_snapshot(state: GameState, hub: RegistryHub, game_time: float) -> Dictionary:
	var world := state.world()
	var port_reports: Array = []
	for raw_port_id in world.get("discovered_ports", []):
		var port_id := String(raw_port_id)
		var port_data := MapOps.port(world, port_id)
		if port_data.is_empty():
			continue
		var market_rows: Array = []
		var market: Dictionary = state.market().get(port_id, {})
		var item_ids: Array = market.keys()
		item_ids.sort()
		for item_id in item_ids:
			var entry: Dictionary = market[item_id]
			market_rows.append({
				"item_id": String(item_id),
				"price": int(round(float(entry.get("price", 0.0)))),
				"stock": int(entry.get("stock", 0)),
				"buyable": bool(entry.get("buyable", true)),
				"is_supply": bool(entry.get("is_supply", false)),
				"trend": _trend(entry),
				"trend_percent": _trend_percent(entry),
			})
		port_reports.append({
			"port_id": port_id,
			"name_key": MapOps.port_display_key(world, port_id),
			"market": market_rows,
		})

	var npc_reports: Array = []
	for npc in state.data.get("npcs", []):
		if not (npc is Dictionary):
			continue
		var destination := String(npc.get("destination", ""))
		if not MapOps.is_discovered(state, destination):
			continue
		var eta := float(npc.get("eta", game_time))
		npc_reports.append({
			"npc_id": String(npc.get("id", "")),
			"destination": destination,
			"destination_name_key": MapOps.port_display_key(world, destination),
			"item_id": String(npc.get("item_id", "")),
			"action": String(npc.get("action", "")),
			"eta_from": maxf(game_time, eta - 2.0),
			"eta_to": eta + 2.0,
		})

	return {
		"generated_at": game_time,
		"generated_label": ClockService.format_time(game_time),
		"ports": port_reports,
		"npcs": npc_reports,
	}


static func store(state: GameState, snapshot: Dictionary) -> void:
	state.data["intelligence"] = snapshot.duplicate(true)


static func get_snapshot(state: GameState) -> Dictionary:
	return state.data.get("intelligence", {})


static func snapshot_age(state: GameState) -> float:
	var snapshot := get_snapshot(state)
	if snapshot.is_empty():
		return -1.0
	return maxf(0.0, state.now() - float(snapshot.get("generated_at", 0.0)))


static func _trend(entry: Dictionary) -> String:
	var stock := float(entry.get("stock", 0.0))
	var base_stock := maxf(1.0, float(entry.get("base_stock", 1.0)))
	if stock < base_stock * 0.85:
		return "up"
	if stock > base_stock * 1.15:
		return "down"
	return "stable"


## Same algorithm as PortViewQuery: first-to-last change of the last 8 real
## price samples, as a fraction (0.12 == +12%). Sell-only entries never write
## history, so they stay at 0.0 instead of faking a trend.
static func _trend_percent(entry: Dictionary) -> float:
	var history: Array = entry.get("price_history", [])
	var recent: Array = history.slice(maxi(0, history.size() - 8), history.size())
	if recent.size() >= 2 and float(recent[0]) > 0.0:
		return (float(recent[recent.size() - 1]) - float(recent[0])) / float(recent[0])
	return 0.0
