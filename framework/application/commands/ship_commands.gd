class_name ShipCommands
extends RefCounted
## Minimal shipyard flow for the framework slice: buy and install a module.

const INSTALLABLE_TYPES := [
	ContentTypes.HULL,
	ContentTypes.BOILER,
	ContentTypes.CARGO_MODULE,
	ContentTypes.NAVIGATION_MODULE,
	ContentTypes.SAFETY_MODULE,
	ContentTypes.CABIN,
]


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
	var content_type := &""
	var module: ContentDefinition = null
	for candidate_type in INSTALLABLE_TYPES:
		var candidate := hub.get_by_id(candidate_type, module_id)
		if candidate != null:
			content_type = candidate_type
			module = candidate
			break
	if module == null:
		return Result.fail("unknown_module", "ui.error.unknown_module", {"module_id": module_id})
	if int(module.data.get("unlock_reputation", 0)) > int(state.player().get("reputation", 0)):
		return Result.fail("locked_by_reputation", "ui.error.locked_by_reputation", {
			"required": int(module.data.get("unlock_reputation", 0)),
		})
	var price := int(round(float(module.data.get("purchase_price", 0.0))))
	if state.money() < price:
		return Result.fail("insufficient_money", "ui.error.money", {"required": price, "money": state.money()})
	var ship := state.ship()
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))

	if content_type == ContentTypes.CARGO_MODULE:
		var slots := int(hull.data.get("cargo_slots", 0)) if hull != null else 0
		if Array(ship.get("cargo_modules", [])).size() >= slots:
			return Result.fail("cargo_slots_full", "ui.error.cargo_slots_full", {"slots": slots})
	elif content_type == ContentTypes.CABIN:
		if hull == null or int(hull.data.get("cabin_slots", 0)) < 1:
			return Result.fail("no_cabin_slot", "ui.error.no_cabin_slot")
		if not String(ship.get("passenger_cabin_id", "")).is_empty():
			return Result.fail("slot_occupied", "ui.error.slot_occupied")
	elif content_type == ContentTypes.NAVIGATION_MODULE:
		if not String(ship.get("navigation_module_id", "")).is_empty():
			return Result.fail("slot_occupied", "ui.error.slot_occupied")
	elif content_type == ContentTypes.SAFETY_MODULE:
		if not String(ship.get("safety_module_id", "")).is_empty():
			return Result.fail("slot_occupied", "ui.error.slot_occupied")
	elif content_type == ContentTypes.HULL:
		if hull != null:
			if Array(ship.get("cargo_modules", [])).size() > int(module.data.get("cargo_slots", 0)):
				return Result.fail("too_many_cargo_modules", "ui.error.too_many_cargo_modules")
			if not String(ship.get("passenger_cabin_id", "")).is_empty() and int(module.data.get("cabin_slots", 0)) < 1:
				return Result.fail("no_cabin_slot", "ui.error.no_cabin_slot")

	var added_weight := float(module.data.get("weight", 0.0))
	if ShipOps.total_weight(hub, state) + added_weight > ShipOps.max_weight(hub, ship) + 0.0001 and content_type != ContentTypes.HULL:
		return Result.fail("weight_limit", "ui.error.weight")

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
