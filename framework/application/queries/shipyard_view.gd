class_name ShipyardViewQuery
extends RefCounted
## Shipyard ViewModel: current modules, slot occupancy, and every purchasable
## module with the same blocker rules as ship.install_module.

static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({"has_run": false, "has_shipyard": false})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var port_data := MapOps.port(state.world(), state.current_port_id())
	var has_shipyard := MapOps.has_facility(port_data, "shipyard")
	var ship := state.ship()
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	var stats := ShipOps.stats(hub, ship)
	var installed_ids := ShipOps.all_installed_module_ids(ship)
	var current_modules: Array = []
	for content_type in ShipOps.INSTALLABLE_TYPES:
		var module_ids: Array[String] = []
		match content_type:
			ContentTypes.CARGO_MODULE:
				module_ids = ShipOps.cargo_module_ids(ship)
			ContentTypes.HULL:
				module_ids.append(String(ship.get("hull_id", "")))
			ContentTypes.BOILER:
				module_ids.append(String(ship.get("boiler_id", "")))
			ContentTypes.NAVIGATION_MODULE:
				module_ids.append(String(ship.get("navigation_module_id", "")))
			ContentTypes.SAFETY_MODULE:
				module_ids.append(String(ship.get("safety_module_id", "")))
			ContentTypes.CABIN:
				module_ids.append(String(ship.get("passenger_cabin_id", "")))
		for module_id in module_ids:
			if module_id.is_empty():
				continue
			var module := hub.get_by_id(content_type, module_id)
			current_modules.append({
				"content_type": String(content_type),
				"module_id": module_id,
				"name_key": module.name_key if module != null else module_id,
				"price": int(round(float(module.data.get("purchase_price", 0.0)))) if module != null else 0,
				"weight": float(module.data.get("weight", 0.0)) if module != null else 0.0,
			})

	var candidates: Array = []
	for content_type in ShipOps.INSTALLABLE_TYPES:
		for module in hub.get_all(content_type):
			var blockers := ShipOps.install_blockers(hub, state, module.id)
			if not has_shipyard:
				blockers.push_front("no_shipyard")
			if not state.is_at_port():
				blockers.push_front("not_at_port")
			var installed := installed_ids.has(module.id)
			if installed:
				blockers.push_front("already_installed")
			candidates.append({
				"content_type": String(content_type),
				"module_id": module.id,
				"name_key": module.name_key,
				"description_key": module.description_key,
				"price": int(round(float(module.data.get("purchase_price", 0.0)))),
				"weight": float(module.data.get("weight", 0.0)),
				"tier": int(module.data.get("tier", 1)),
				"installed": installed,
				"blockers": blockers,
				"can_install": blockers.is_empty(),
				"effect": module.data.duplicate(true),
			})

	return Result.ok({
		"has_run": true,
		"at_port": state.is_at_port(),
		"has_shipyard": has_shipyard,
		"port_id": state.current_port_id(),
		"port_name_key": String(port_data.get("name_key", state.current_port_id())),
		"money": state.money(),
		"ship": {
			"hull_id": String(ship.get("hull_id", "")),
			"boiler_id": String(ship.get("boiler_id", "")),
			"modules": current_modules,
			"durability": float(ship.get("durability", 0.0)),
			"max_durability": float(stats.get("max_durability", 0.0)),
			"total_weight": ShipOps.total_weight(hub, state),
			"max_weight": ShipOps.max_weight(hub, ship),
			"cargo_slots": int(hull.data.get("cargo_slots", 0)) if hull != null else 0,
			"cargo_used": ShipOps.cargo_module_ids(ship).size(),
			"cabin_slots": int(hull.data.get("cabin_slots", 0)) if hull != null else 0,
			"cabin_used": 0 if String(ship.get("passenger_cabin_id", "")).is_empty() else 1,
			"navigation_occupied": not String(ship.get("navigation_module_id", "")).is_empty(),
			"safety_occupied": not String(ship.get("safety_module_id", "")).is_empty(),
			"cargo_capacity": ShipOps.cargo_capacity(hub, ship),
			"passenger_capacity": ShipOps.passenger_capacity(hub, ship),
		},
		"candidates": candidates,
	})
