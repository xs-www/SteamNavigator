class_name PortMemoryViewQuery
extends RefCounted
## Read-only last-visit market snapshot for a port the player has visited.

static func execute(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({"has_run": false, "has_memory": false})
	var state: GameState = context.state
	var port_id := String(params.get("port_id", state.current_port_id()))
	var port_data := MapOps.port(state.world(), port_id)
	if port_data.is_empty():
		return Result.fail("unknown_port", "ui.error.unknown_port", {"port_id": port_id})
	var memory := MarketMemoryService.get_memory(state, port_id)
	var rows: Array = []
	var snapshot: Dictionary = memory.get("market", {})
	var item_ids: Array = snapshot.keys()
	item_ids.sort()
	for item_id in item_ids:
		var definition := ShipOps.item_definition(context.registries, String(item_id))
		var entry: Dictionary = snapshot[item_id]
		rows.append({
			"item_id": String(item_id),
			"name_key": definition.name_key if definition != null else String(item_id),
			"unit_weight": float(definition.data.get("unit_weight", 0.0)) if definition != null else 0.0,
			"price": int(round(float(entry.get("price", 0.0)))),
			"stock": int(entry.get("stock", 0)),
			"buyable": bool(entry.get("buyable", true)),
		})
	var captured_at := float(memory.get("captured_at", 0.0))
	return Result.ok({
		"has_run": true,
		"port_id": port_id,
		"name_key": String(port_data.get("name_key", port_id)),
		"visited": MapOps.is_visited(state, port_id),
		"current": port_id == state.current_port_id(),
		"has_memory": not memory.is_empty(),
		"captured_at": captured_at,
		"captured_label": String(memory.get("captured_label", "")),
		"age_hours": maxf(0.0, state.now() - captured_at) if not memory.is_empty() else 0.0,
		"market": rows,
		"facilities": Array(port_data.get("facilities", [])),
		"facilities_known": MapOps.facilities_known(state, context.registries, port_id),
	})
