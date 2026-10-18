class_name NpcTraderSimulator
extends RefCounted
## Background traders that move stock between ports and drive prices.
##
## NPCs are data only: position, destination, item, amount and ETA. They are
## advanced when game time moves, with a bounded catch-up loop per voyage.

const MAX_CATCH_UP_CYCLES := 4


static func create_initial(state: GameState, hub: RegistryHub, rng_service: RngService, config: Dictionary) -> Array:
	var npcs: Array = []
	var port_ids: Array = MapOps.ports(state.world()).keys()
	port_ids.sort()
	if port_ids.size() < 2:
		return npcs
	var count_range: Array = config.get("npc_count_range", [2, 3])
	var count := rng_service.stream(RngService.STREAM_NPC_TRADE, "count").randi_range(
		int(count_range[0]), int(count_range[1])
	)
	var cargo_range: Array = config.get("npc_cargo_range", [8, 24])
	for index in count:
		var npc := {
			"id": "npc_%d" % (index + 1),
			"current_port": "",
			"destination": "",
			"item_id": "",
			"amount": 0,
			"action": "deliver",
			"speed": 12.0,
			"eta": state.now(),
		}
		_assign_route(state, npc, rng_service, state.now(), cargo_range)
		npcs.append(npc)
	return npcs


static func advance(state: GameState, hub: RegistryHub, rng_service: RngService, now: float, config: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var cargo_range: Array = config.get("npc_cargo_range", [8, 24])
	for npc in state.data.get("npcs", []):
		if not (npc is Dictionary):
			continue
		var cycles := 0
		while float(npc.get("eta", now)) <= now and cycles < MAX_CATCH_UP_CYCLES:
			var arrival := _resolve_arrival(state, hub, npc, now)
			if not arrival.is_empty():
				events.append(arrival)
			_assign_route(state, npc, rng_service, now, cargo_range)
			cycles += 1
	return events


static func _resolve_arrival(state: GameState, hub: RegistryHub, npc: Dictionary, now: float) -> Dictionary:
	var destination := String(npc.get("destination", ""))
	var item_id := String(npc.get("item_id", ""))
	var entry := MarketOps.entry_for(state, destination, item_id)
	if entry.is_empty():
		return {}
	var amount := int(npc.get("amount", 0))
	var before := float(entry.get("price", 0.0))
	if String(npc.get("action", "deliver")) == "deliver":
		entry["stock"] = int(entry.get("stock", 0)) + amount
	else:
		entry["stock"] = maxi(1, int(entry.get("stock", 0)) - amount)
	MarketOps.recalc(entry)
	return {
		"type": "market.changed",
		"payload": {
			"port_id": destination,
			"item_id": item_id,
			"source": "npc",
			"npc_id": String(npc.get("id", "")),
			"action": String(npc.get("action", "deliver")),
			"stock": int(entry.get("stock", 0)),
			"price_before": before,
			"price_after": float(entry.get("price", 0.0)),
		},
	}


static func _assign_route(state: GameState, npc: Dictionary, rng_service: RngService, now: float, cargo_range: Array) -> void:
	var rng := rng_service.stream(RngService.STREAM_NPC_TRADE, String(npc.get("id", "npc")))
	var world := state.world()
	var port_ids: Array = MapOps.ports(world).keys()
	port_ids.sort()
	if port_ids.size() < 2:
		return
	var current_port := String(npc.get("current_port", ""))
	if current_port.is_empty() or not MapOps.ports(world).has(current_port):
		current_port = String(port_ids[rng.randi_range(0, port_ids.size() - 1)])
	var candidates: Array[String] = []
	for port_id in port_ids:
		if String(port_id) != current_port:
			candidates.append(String(port_id))
	candidates.sort()
	var destination := candidates[rng.randi_range(0, candidates.size() - 1)]
	var market: Dictionary = state.market().get(destination, {})
	var item_ids: Array = market.keys()
	if item_ids.is_empty():
		return
	item_ids.sort()
	var item_id := String(item_ids[rng.randi_range(0, item_ids.size() - 1)])
	var action := "deliver" if rng.randf() < 0.6 else "buy"
	var minimum := int(cargo_range[0]) if cargo_range.size() > 0 else 8
	var maximum := int(cargo_range[1]) if cargo_range.size() > 1 else minimum
	var amount := rng.randi_range(mini(minimum, maximum), maxi(minimum, maximum))
	var distance := MapOps.distance_between(world, current_port, destination)
	var speed := float(npc.get("speed", 12.0))
	var travel_hours := distance / maxf(1.0, speed)
	npc["current_port"] = current_port
	npc["destination"] = destination
	npc["item_id"] = item_id
	npc["amount"] = amount
	npc["action"] = action
	npc["eta"] = now + travel_hours + rng.randf_range(0.0, 2.0)
