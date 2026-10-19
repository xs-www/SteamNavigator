class_name ShipCommands
extends RefCounted
## Shipyard use cases: install a module (purchase / warehouse / transit, with
## replacement), uninstall a module into the current port warehouse, and order a
## module craft (warehouse-first materials, delivered later by CraftOps settlement).
##
## All handlers run inside the CommandBus transaction. Slot, weight, money,
## lock and source rules come from ShipOps.install_blockers()/uninstall_blockers()
## and CraftOps.craft_blockers() so the shipyard ViewModel never drifts.

const VALID_SOURCES := ["purchase", "warehouse", "transit"]


static func install_module(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var port_data := MapOps.port(state.world(), state.current_port_id())
	if not MapOps.has_facility(port_data, "shipyard"):
		return Result.fail("no_shipyard", "ui.error.no_shipyard")
	var module_id := String(params.get("module_id", ""))
	if module_id.is_empty():
		return Result.fail("missing_module", "ui.error.missing_module")
	var source := String(params.get("source", "purchase"))
	if source.is_empty():
		source = "purchase"
	if not VALID_SOURCES.has(source):
		return Result.fail("invalid_source", "ui.error.invalid_source", {"source": source})
	var replace_module_id := String(params.get("replace_module_id", ""))
	var content_type := ShipOps.module_type(hub, module_id)
	var module := hub.get_by_id(content_type, module_id) if content_type != &"" else null
	if module == null:
		return Result.fail("unknown_module", "ui.error.unknown_module", {"module_id": module_id})
	var blockers := ShipOps.install_blockers(hub, state, module_id, source, replace_module_id)
	if not blockers.is_empty():
		return Result.fail(
			String(blockers[0]),
			"ui.error.%s" % String(blockers[0]),
			{"module_id": module_id, "source": source, "blockers": blockers}
		)

	var ship := state.ship()
	var price := int(round(float(module.data.get("purchase_price", 0.0)))) if source == "purchase" else 0
	var replaced_module_id := _replaced_module_id(state, content_type, module_id, replace_module_id)

	match source:
		"purchase":
			if price > 0:
				state.add_money(-price)
				state.record_expense(price)
		"warehouse":
			WarehouseOps.remove_module(state, state.current_port_id(), module_id, 1)
		"transit":
			var transit: Dictionary = WarehouseOps.transit_modules(ship)
			var remaining := int(transit.get(module_id, 0)) - 1
			if remaining <= 0:
				transit.erase(module_id)
			else:
				transit[module_id] = remaining

	if not replaced_module_id.is_empty() and replaced_module_id != module_id:
		_remove_installed(state, content_type, replaced_module_id)
		WarehouseOps.add_module(state, state.current_port_id(), replaced_module_id, 1)
	_install(hub, state, content_type, module_id, source)

	var validation := ShipOps.validate_configuration(hub, ship)
	if not bool(validation["ok"]):
		return Result.fail("invalid_configuration", "ui.error.invalid_configuration", {"errors": validation["errors"]})

	var victory := VictoryService.check(state, hub)
	var events: Array = [{
		"type": "ship.module_installed",
		"payload": {
			"module_id": module_id,
			"content_type": String(content_type),
			"source": source,
			"price": price,
			"replaced": replaced_module_id,
			"replaced_module_id": replaced_module_id,
		},
	}]
	if bool(victory.get("newly_achieved", false)):
		events.append({
			"type": "run.victory_achieved",
			"payload": victory.get("summary", {}),
		})
	return Result.ok({
		"module_id": module_id,
		"content_type": String(content_type),
		"source": source,
		"price": price,
		"replaced_module_id": replaced_module_id,
		"money": state.money(),
		"total_weight": ShipOps.total_weight(hub, state),
		"victory": victory,
	}, events)


static func uninstall_module(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var port_data := MapOps.port(state.world(), state.current_port_id())
	if not MapOps.has_facility(port_data, "shipyard"):
		return Result.fail("no_shipyard", "ui.error.no_shipyard")
	var module_id := String(params.get("module_id", ""))
	if module_id.is_empty():
		return Result.fail("missing_module", "ui.error.missing_module")
	var content_type := ShipOps.module_type(hub, module_id)
	if content_type == &"":
		return Result.fail("unknown_module", "ui.error.unknown_module", {"module_id": module_id})
	var blockers := ShipOps.uninstall_blockers(hub, state, module_id)
	if not blockers.is_empty():
		return Result.fail(
			String(blockers[0]),
			"ui.error.%s" % String(blockers[0]),
			{"module_id": module_id, "blockers": blockers}
		)
	_remove_installed(state, content_type, module_id)
	var warehouse_qty := WarehouseOps.add_module(state, state.current_port_id(), module_id, 1)
	return Result.ok({
		"module_id": module_id,
		"content_type": String(content_type),
		"warehouse_qty": warehouse_qty,
	}, [{
		"type": "ship.module_uninstalled",
		"payload": {
			"module_id": module_id,
			"content_type": String(content_type),
			"warehouse_qty": warehouse_qty,
		},
	}])


static func craft_module(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var port_data := MapOps.port(state.world(), state.current_port_id())
	if not MapOps.has_facility(port_data, "shipyard"):
		return Result.fail("no_shipyard", "ui.error.no_shipyard")
	var module_id := String(params.get("module_id", ""))
	if module_id.is_empty():
		return Result.fail("missing_module", "ui.error.missing_module")
	var craft_result := CraftOps.craft(state, hub, module_id)
	if not bool(craft_result.get("ok", false)):
		return craft_result
	var data: Dictionary = craft_result.get("data", {})
	return Result.ok(data, [{
		"type": "ship.craft_ordered",
		"payload": {
			"order_id": String(data.get("order_id", "")),
			"module_id": module_id,
			"content_type": String(data.get("content_type", "")),
			"port_id": String(state.current_port_id()),
			"craft_cost": int(data.get("craft_cost", 0)),
			"craft_time_hours": float(data.get("craft_time_hours", 0.0)),
			"ready_at": float(data.get("ready_at", 0.0)),
		},
	}])


## The installed module that the incoming module replaces, if any. Hull/boiler/
## navigation/safety/cabin occupy a single slot, so the current slot content is
## replaced automatically; cargo only replaces when the caller names a stored
## module from the same slot.
static func _replaced_module_id(state: GameState, content_type: StringName, module_id: String, requested_replace_id: String) -> String:
	var ship := state.ship()
	match content_type:
		ContentTypes.HULL:
			return _different(String(ship.get("hull_id", "")), module_id)
		ContentTypes.BOILER:
			return _different(String(ship.get("boiler_id", "")), module_id)
		ContentTypes.NAVIGATION_MODULE:
			return _different(String(ship.get("navigation_module_id", "")), module_id)
		ContentTypes.SAFETY_MODULE:
			return _different(String(ship.get("safety_module_id", "")), module_id)
		ContentTypes.CABIN:
			return _different(String(ship.get("passenger_cabin_id", "")), module_id)
		ContentTypes.CARGO_MODULE:
			if _different(requested_replace_id, module_id).is_empty():
				return ""
			return requested_replace_id if ShipOps.cargo_module_ids(ship).has(requested_replace_id) else ""
	return ""


static func _different(current_id: String, new_id: String) -> String:
	return current_id if current_id != new_id else ""


## Removes one installed module from the ship without touching the warehouse.
static func _remove_installed(state: GameState, content_type: StringName, module_id: String) -> void:
	var ship := state.ship()
	match content_type:
		ContentTypes.HULL:
			ship["hull_id"] = ""
		ContentTypes.BOILER:
			ship["boiler_id"] = ""
		ContentTypes.NAVIGATION_MODULE:
			ship["navigation_module_id"] = ""
		ContentTypes.SAFETY_MODULE:
			ship["safety_module_id"] = ""
		ContentTypes.CABIN:
			ship["passenger_cabin_id"] = ""
		ContentTypes.CARGO_MODULE:
			var cargo_modules: Array = Array(ship.get("cargo_modules", []))
			var index := cargo_modules.find(module_id)
			if index >= 0:
				cargo_modules.remove_at(index)
				ship["cargo_modules"] = cargo_modules


## Installs a module onto the ship. Purchase replacements start at full durability;
## warehouse/transit hull swaps keep min(current durability, new max) so moving an
## old hull cannot repair it for free.
static func _install(hub: RegistryHub, state: GameState, content_type: StringName, module_id: String, source: String) -> void:
	var ship := state.ship()
	match content_type:
		ContentTypes.HULL:
			var previous_durability := float(ship.get("durability", 0.0))
			ship["hull_id"] = module_id
			var new_max := ShipOps.durability_max(hub, ship)
			if source == "purchase" or not ship.has("durability"):
				ship["durability"] = new_max
			else:
				ship["durability"] = minf(previous_durability, new_max)
		ContentTypes.BOILER:
			ship["boiler_id"] = module_id
		ContentTypes.CARGO_MODULE:
			ship["cargo_modules"] = Array(ship.get("cargo_modules", [])) + [module_id]
		ContentTypes.NAVIGATION_MODULE:
			ship["navigation_module_id"] = module_id
		ContentTypes.SAFETY_MODULE:
			ship["safety_module_id"] = module_id
		ContentTypes.CABIN:
			ship["passenger_cabin_id"] = module_id
