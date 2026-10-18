class_name ShipCommands
extends RefCounted
## Minimal shipyard flow for the framework slice: buy and install a module.


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
	var content_type := ShipOps.module_type(hub, module_id)
	var module := hub.get_by_id(content_type, module_id) if content_type != &"" else null
	if module == null:
		return Result.fail("unknown_module", "ui.error.unknown_module", {"module_id": module_id})
	var blockers := ShipOps.install_blockers(hub, state, module_id)
	if not blockers.is_empty():
		return Result.fail(
			String(blockers[0]),
			"ui.error.%s" % String(blockers[0]),
			{"module_id": module_id, "blockers": blockers}
		)
	var price := int(round(float(module.data.get("purchase_price", 0.0))))
	var ship := state.ship()
	state.add_money(-price)
	match content_type:
		ContentTypes.CARGO_MODULE:
			ship["cargo_modules"] = Array(ship.get("cargo_modules", [])) + [module_id]
		ContentTypes.NAVIGATION_MODULE:
			ship["navigation_module_id"] = module_id
		ContentTypes.SAFETY_MODULE:
			ship["safety_module_id"] = module_id
		ContentTypes.CABIN:
			ship["passenger_cabin_id"] = module_id
		ContentTypes.HULL:
			ship["hull_id"] = module_id
			var new_max := ShipOps.durability_max(hub, ship)
			ship["durability"] = new_max
		ContentTypes.BOILER:
			ship["boiler_id"] = module_id

	var validation := ShipOps.validate_configuration(hub, ship)
	if not bool(validation["ok"]):
		return Result.fail("invalid_configuration", "ui.error.invalid_configuration", {"errors": validation["errors"]})
	return {
		"ok": true,
		"error_code": "",
		"message_key": "",
		"data": {
			"module_id": module_id,
			"content_type": String(content_type),
			"price": price,
			"money": state.money(),
			"total_weight": ShipOps.total_weight(hub, state),
		},
		"events": [{
			"type": "ship.module_installed",
			"payload": {"module_id": module_id, "content_type": String(content_type), "price": price},
		}],
	}
