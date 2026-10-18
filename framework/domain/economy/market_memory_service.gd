class_name MarketMemoryService
extends RefCounted
## Last-known port market snapshots.
##
## Unlike intelligence (which can be refreshed remotely), this is exactly what
## the player saw the last time they were physically in that port. NPCs and
## later trades can move the live market; the memory stays frozen until the
## next visit or trade in that port.

const MEMORY_KEY := "port_memory"


static func ensure(state: GameState) -> void:
	if not state.data.get(MEMORY_KEY, null) is Dictionary:
		state.data[MEMORY_KEY] = {}


static func remember(state: GameState, port_id: String) -> void:
	ensure(state)
	var market: Dictionary = state.market().get(port_id, {})
	var snapshot := {}
	for item_id in market.keys():
		var entry: Dictionary = market[item_id]
		snapshot[String(item_id)] = {
			"price": float(entry.get("price", 0.0)),
			"stock": int(entry.get("stock", 0)),
			"base_stock": float(entry.get("base_stock", 0.0)),
			"buyable": bool(entry.get("buyable", true)),
			"is_supply": bool(entry.get("is_supply", false)),
		}
	state.data[MEMORY_KEY][port_id] = {
		"captured_at": state.now(),
		"captured_label": ClockService.format_time(state.now()),
		"market": snapshot,
	}


static func get_memory(state: GameState, port_id: String) -> Dictionary:
	ensure(state)
	return state.data[MEMORY_KEY].get(port_id, {})


static func has_memory(state: GameState, port_id: String) -> bool:
	return not get_memory(state, port_id).is_empty()
