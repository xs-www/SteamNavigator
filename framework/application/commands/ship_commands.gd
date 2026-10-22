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
	var requested_slot := String(params.get("slot", ""))
	var module := ShipOps.find_installable(hub, module_id)
	if module == null:
		return Result.fail("unknown_module", "ui.error.unknown_module", {"module_id": module_id})
	var blockers := ShipOps.install_blockers(hub, state, module_id, source, replace_module_id, requested_slot)
	if not blockers.is_empty():
		return Result.fail(
			String(blockers[0]),
			"ui.error.%s" % String(blockers[0]),
			{"module_id": module_id, "source": source, "blockers": blockers}
		)

	var ship := state.ship()
	var price := int(round(float(module.data.get("purchase_price", 0.0)))) if source == "purchase" else 0
	var replaced_module_id := _replaced_module_id(state, module, module_id, replace_module_id, requested_slot)

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
		_remove_installed(state, _installed_slot(ship, replaced_module_id), replaced_module_id)
		WarehouseOps.add_module(state, state.current_port_id(), replaced_module_id, 1)
	_install(state, module, module_id, source, requested_slot)

	var validation := ShipOps.validate_configuration(hub, ship)
	if not bool(validation["ok"]):
		return Result.fail("invalid_configuration", "ui.error.invalid_configuration", {"errors": validation["errors"]})

	var victory := VictoryService.check(state, hub)
	var category := ModuleOps.category_of(module)
	var events: Array = [{
		"type": "ship.module_installed",
		"payload": {
			"module_id": module_id,
			"content_type": String(module.content_type),
			"category": category,
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
		"content_type": String(module.content_type),
		"category": category,
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
	var module := ShipOps.find_installable(hub, module_id)
	if module == null:
		return Result.fail("unknown_module", "ui.error.unknown_module", {"module_id": module_id})
	var blockers := ShipOps.uninstall_blockers(hub, state, module_id)
	if not blockers.is_empty():
		return Result.fail(
			String(blockers[0]),
			"ui.error.%s" % String(blockers[0]),
			{"module_id": module_id, "blockers": blockers}
		)
	var slot := _installed_slot(state.ship(), module_id)
	_remove_installed(state, slot, module_id)
	var warehouse_qty := WarehouseOps.add_module(state, state.current_port_id(), module_id, 1)
	var category := ModuleOps.category_of(module)
	return Result.ok({
		"module_id": module_id,
		"content_type": String(module.content_type),
		"category": category,
		"warehouse_qty": warehouse_qty,
	}, [{
		"type": "ship.module_uninstalled",
		"payload": {
			"module_id": module_id,
			"content_type": String(module.content_type),
			"category": category,
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
## utility/cabin occupy a single slot, so the current slot content is replaced
## automatically; cargo only replaces when the caller names a stored module from
## the same slot.
static func _replaced_module_id(state: GameState, module: ContentDefinition, module_id: String, requested_replace_id: String, requested_slot: String = "") -> String:
	var ship := state.ship()
	if module.content_type == ContentTypes.HULL:
		return _different(String(ship.get("hull_id", "")), module_id)
	var category := ModuleOps.category_of(module)
	if category == "cargo":
		if _different(requested_replace_id, module_id).is_empty():
			return ""
		return requested_replace_id if ShipOps.cargo_module_ids(ship).has(requested_replace_id) else ""
	var slot := ModuleOps.slot_for_with_request(module, ship, requested_slot)
	return _different(String(ship.get(ModuleOps.ship_slot_key(slot), "")), module_id)


static func _different(current_id: String, new_id: String) -> String:
	return current_id if current_id != new_id else ""


## Flat slot currently holding `module_id`, or "" when it is not installed.
static func _installed_slot(ship: Dictionary, module_id: String) -> String:
	if String(ship.get("hull_id", "")) == module_id:
		return "hull"
	for slot in ModuleOps.SLOT_CATEGORIES.keys():
		if slot == "cargo_modules":
			if ShipOps.cargo_module_ids(ship).has(module_id):
				return slot
			continue
		if String(ship.get(ModuleOps.ship_slot_key(slot), "")) == module_id:
			return slot
	return ""


## Removes one installed module from the ship without touching the warehouse.
## The flat slot key is the definition projection; the module instance carrying
## identity/condition is dropped in the same step.
static func _remove_installed(state: GameState, slot: String, module_id: String) -> void:
	var ship := state.ship()
	if slot == "hull":
		ship["hull_id"] = ""
		return
	if slot == "cargo_modules":
		var cargo_modules: Array = Array(ship.get("cargo_modules", []))
		var index := cargo_modules.find(module_id)
		if index >= 0:
			cargo_modules.remove_at(index)
			ship["cargo_modules"] = cargo_modules
			ShipModules.remove_cargo(ship, index)
		return
	var key := ModuleOps.ship_slot_key(slot)
	if key.is_empty():
		return
	ship[key] = ""
	var instance_slot := ModuleOps.instance_slot(slot)
	if not instance_slot.is_empty():
		ShipModules.remove_slot(ship, instance_slot)


## Installs a module onto the ship. Purchase replacements start at full durability;
## warehouse/transit hull swaps keep min(current durability, new max) so moving an
## old hull cannot repair it for free. Every installed module gets a fresh
## instance at full condition; a swapped-in old module is not repaired for free.
static func _install(state: GameState, module: ContentDefinition, module_id: String, source: String, requested_slot: String = "") -> void:
	var ship := state.ship()
	if module.content_type == ContentTypes.HULL:
		var previous_durability := float(ship.get("durability", 0.0))
		ship["hull_id"] = module_id
		var new_max := float(module.data.get("max_durability", 100.0))
		if source == "purchase" or not ship.has("durability"):
			ship["durability"] = new_max
		else:
			ship["durability"] = minf(previous_durability, new_max)
		return
	var slot := ModuleOps.slot_for_with_request(module, ship, requested_slot)
	if slot == "cargo_modules":
		ship["cargo_modules"] = Array(ship.get("cargo_modules", [])) + [module_id]
		ShipModules.append_cargo(ship)
		return
	var key := ModuleOps.ship_slot_key(slot)
	if key.is_empty():
		return
	ship[key] = module_id
	ShipModules.install_slot(ship, ModuleOps.instance_slot(slot))
