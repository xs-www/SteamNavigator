class_name WarehouseOps
extends RefCounted
## Port warehouses (stored modules + materials) and module transit.
##
## Warehouses live at `world.warehouses[port_id] = {modules:{}, materials:{}}`.
## Modules that are not installed travel with the ship in `ship.transit_modules`;
## they add weight but never occupy cargo capacity. All helpers are pure state
## manipulation and never touch content definitions.

const MODULE_SECTION := "modules"
const MATERIAL_SECTION := "materials"


## Idempotently creates warehouses for every port plus ship.transit_modules.
## Safe on old saves that predate the iteration-1 fields.
static func ensure_structure(state: GameState) -> void:
	if not (state.data.get("world", null) is Dictionary):
		state.data["world"] = {}
	var world: Dictionary = state.data["world"]
	if not (world.get("warehouses", null) is Dictionary):
		world["warehouses"] = {}
	var warehouses: Dictionary = world["warehouses"]
	var ports: Variant = world.get("ports", null)
	if ports is Dictionary:
		for raw_port_id in ports.keys():
			var port_id := String(raw_port_id)
			var entry: Variant = warehouses.get(port_id, null)
			if not (entry is Dictionary):
				warehouses[port_id] = {MODULE_SECTION: {}, MATERIAL_SECTION: {}}
				continue
			_ensure_sections(entry)
	if not (state.data.get("ship", null) is Dictionary):
		state.data["ship"] = {}
	var ship: Dictionary = state.data["ship"]
	if not (ship.get("transit_modules", null) is Dictionary):
		ship["transit_modules"] = {}


## Read-only lookup. Returns an empty structure when the port has no warehouse.
static func warehouse(state: GameState, port_id: String) -> Dictionary:
	var world: Variant = state.data.get("world", null)
	if not (world is Dictionary):
		return {MODULE_SECTION: {}, MATERIAL_SECTION: {}}
	var warehouses: Variant = world.get("warehouses", null)
	if not (warehouses is Dictionary):
		return {MODULE_SECTION: {}, MATERIAL_SECTION: {}}
	var entry: Variant = warehouses.get(port_id, null)
	if not (entry is Dictionary):
		return {MODULE_SECTION: {}, MATERIAL_SECTION: {}}
	return entry


static func module_qty(state: GameState, port_id: String, module_id: String) -> int:
	var modules := _section(warehouse(state, port_id), MODULE_SECTION)
	return int(modules.get(module_id, 0))


static func material_amount(state: GameState, port_id: String, item_id: String) -> int:
	var materials := _section(warehouse(state, port_id), MATERIAL_SECTION)
	return int(materials.get(item_id, 0))


static func transit_modules(ship: Dictionary) -> Dictionary:
	var transit: Variant = ship.get("transit_modules", null)
	return transit if transit is Dictionary else {}


static func transit_qty(ship: Dictionary, module_id: String) -> int:
	return int(transit_modules(ship).get(module_id, 0))


## Weight of every uninstalled module carried in transit. Counted in
## ShipOps.total_weight but not against cargo capacity.
static func transit_module_weight(hub: RegistryHub, ship: Dictionary) -> float:
	var transit := transit_modules(ship)
	var total := 0.0
	for raw_module_id in transit.keys():
		var module_id := String(raw_module_id)
		var qty := int(transit[raw_module_id])
		if qty <= 0:
			continue
		var definition := ShipOps.find_module(hub, module_id)
		if definition != null:
			total += float(definition.data.get("weight", 0.0)) * float(qty)
	return total


## Installed + transit + current-port warehouse copies of a module.
static func owned_module_count(state: GameState, hub: RegistryHub, module_id: String) -> int:
	var installed := ShipOps.all_installed_module_ids(state.ship())
	var total := 0
	for installed_id in installed:
		if installed_id == module_id:
			total += 1
	total += transit_qty(state.ship(), module_id)
	total += module_qty(state, state.current_port_id(), module_id)
	return total


## transit -> current-port warehouse.
static func store_module(state: GameState, hub: RegistryHub, port_id: String, module_id: String, qty: int = 1) -> Dictionary:
	if qty <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount", {"module_id": module_id, "qty": qty})
	if not _at_warehouse_port(state, port_id):
		return Result.fail("not_at_port", "ui.error.not_at_port", {"port_id": port_id})
	if ShipOps.find_module(hub, module_id) == null:
		return Result.fail("unknown_module", "ui.error.unknown_module", {"module_id": module_id})
	ensure_structure(state)
	var ship := state.ship()
	var transit: Dictionary = ship["transit_modules"]
	var available := int(transit.get(module_id, 0))
	if available < qty:
		return Result.fail("missing_module", "ui.error.missing_module", {
			"module_id": module_id,
			"qty": qty,
			"available": available,
		})
	transit[module_id] = available - qty
	if int(transit[module_id]) <= 0:
		transit.erase(module_id)
	var warehouse_qty := add_module(state, port_id, module_id, qty)
	return Result.ok({
		"module_id": module_id,
		"qty": qty,
		"transit_qty": transit_qty(ship, module_id),
		"warehouse_qty": warehouse_qty,
	})


## current-port warehouse -> transit, respecting the hull weight limit.
static func take_module(state: GameState, hub: RegistryHub, port_id: String, module_id: String, qty: int = 1) -> Dictionary:
	if qty <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount", {"module_id": module_id, "qty": qty})
	if not _at_warehouse_port(state, port_id):
		return Result.fail("not_at_port", "ui.error.not_at_port", {"port_id": port_id})
	var module := ShipOps.find_module(hub, module_id)
	if module == null:
		return Result.fail("unknown_module", "ui.error.unknown_module", {"module_id": module_id})
	ensure_structure(state)
	var available := module_qty(state, port_id, module_id)
	if available < qty:
		return Result.fail("warehouse_empty", "ui.error.warehouse_empty", {
			"module_id": module_id,
			"qty": qty,
			"available": available,
		})
	var ship := state.ship()
	var added_weight := float(module.data.get("weight", 0.0)) * float(qty)
	if ShipOps.total_weight(hub, state) + added_weight > ShipOps.max_weight(hub, ship) + 0.0001:
		return Result.fail("weight_limit", "ui.error.weight_limit", {
			"module_id": module_id,
			"total_weight": ShipOps.total_weight(hub, state),
			"max_weight": ShipOps.max_weight(hub, ship),
			"added_weight": added_weight,
		})
	remove_module(state, port_id, module_id, qty)
	var transit: Dictionary = ship["transit_modules"]
	transit[module_id] = int(transit.get(module_id, 0)) + qty
	return Result.ok({
		"module_id": module_id,
		"qty": qty,
		"transit_qty": int(transit[module_id]),
		"warehouse_qty": module_qty(state, port_id, module_id),
		"transit_weight": transit_module_weight(hub, ship),
	})


## Non-contract cargo -> current-port warehouse.
static func store_materials(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int) -> Dictionary:
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount", {"item_id": item_id, "amount": amount})
	if not _at_warehouse_port(state, port_id):
		return Result.fail("not_at_port", "ui.error.not_at_port", {"port_id": port_id})
	if ShipOps.item_definition(hub, item_id) == null:
		return Result.fail("unknown_item", "ui.error.unknown_item", {"item_id": item_id})
	ensure_structure(state)
	var ship := state.ship()
	var carried := ShipOps.cargo_amount(ship, item_id, false)
	if carried < amount:
		return Result.fail("insufficient_cargo", "ui.error.insufficient_cargo", {
			"item_id": item_id,
			"amount": amount,
			"available": carried,
		})
	ShipOps.remove_cargo(ship, item_id, amount, false)
	var warehouse_amount := add_material(state, port_id, item_id, amount)
	return Result.ok({
		"item_id": item_id,
		"amount": amount,
		"warehouse_amount": warehouse_amount,
		"cargo_amount": ShipOps.cargo_amount(ship, item_id, false),
	})


## current-port warehouse -> non-contract cargo, respecting cargo capacity and weight.
static func take_materials(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int) -> Dictionary:
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount", {"item_id": item_id, "amount": amount})
	if not _at_warehouse_port(state, port_id):
		return Result.fail("not_at_port", "ui.error.not_at_port", {"port_id": port_id})
	var item := ShipOps.item_definition(hub, item_id)
	if item == null:
		return Result.fail("unknown_item", "ui.error.unknown_item", {"item_id": item_id})
	ensure_structure(state)
	var stored := material_amount(state, port_id, item_id)
	if stored < amount:
		return Result.fail("insufficient_materials", "ui.error.insufficient_materials", {
			"item_id": item_id,
			"amount": amount,
			"available": stored,
		})
	var ship := state.ship()
	var added_weight := float(item.data.get("unit_weight", 0.0)) * float(amount)
	if ShipOps.cargo_used(hub, ship) + added_weight > ShipOps.cargo_capacity(hub, ship) + 0.0001:
		return Result.fail("cargo_capacity", "ui.error.cargo_capacity", {
			"item_id": item_id,
			"amount": amount,
			"free_capacity": ShipOps.free_cargo_capacity(hub, ship),
			"added_weight": added_weight,
		})
	if ShipOps.total_weight(hub, state) + added_weight > ShipOps.max_weight(hub, ship) + 0.0001:
		return Result.fail("weight_limit", "ui.error.weight_limit", {
			"item_id": item_id,
			"total_weight": ShipOps.total_weight(hub, state),
			"max_weight": ShipOps.max_weight(hub, ship),
			"added_weight": added_weight,
		})
	remove_material(state, port_id, item_id, amount)
	ShipOps.add_cargo(ship, item_id, amount, "", 0.0)
	return Result.ok({
		"item_id": item_id,
		"amount": amount,
		"warehouse_amount": material_amount(state, port_id, item_id),
		"cargo_amount": ShipOps.cargo_amount(ship, item_id, false),
	})


## Adds module copies to a port warehouse; returns the new stored quantity.
static func add_module(state: GameState, port_id: String, module_id: String, qty: int = 1) -> int:
	ensure_structure(state)
	var entry := _warehouse_entry(state, port_id)
	var modules: Dictionary = entry[MODULE_SECTION]
	modules[module_id] = int(modules.get(module_id, 0)) + maxi(0, qty)
	return int(modules[module_id])


## Removes module copies from a port warehouse; returns the new stored quantity.
static func remove_module(state: GameState, port_id: String, module_id: String, qty: int = 1) -> int:
	ensure_structure(state)
	var entry := _warehouse_entry(state, port_id)
	var modules: Dictionary = entry[MODULE_SECTION]
	var remaining := maxi(0, int(modules.get(module_id, 0)) - maxi(0, qty))
	if remaining <= 0:
		modules.erase(module_id)
	else:
		modules[module_id] = remaining
	return remaining


## Adds material units to a port warehouse; returns the new stored amount.
static func add_material(state: GameState, port_id: String, item_id: String, amount: int = 1) -> int:
	ensure_structure(state)
	var entry := _warehouse_entry(state, port_id)
	var materials: Dictionary = entry[MATERIAL_SECTION]
	materials[item_id] = int(materials.get(item_id, 0)) + maxi(0, amount)
	return int(materials[item_id])


## Removes material units from a port warehouse; returns the new stored amount.
static func remove_material(state: GameState, port_id: String, item_id: String, amount: int = 1) -> int:
	ensure_structure(state)
	var entry := _warehouse_entry(state, port_id)
	var materials: Dictionary = entry[MATERIAL_SECTION]
	var remaining := maxi(0, int(materials.get(item_id, 0)) - maxi(0, amount))
	if remaining <= 0:
		materials.erase(item_id)
	else:
		materials[item_id] = remaining
	return remaining


static func _at_warehouse_port(state: GameState, port_id: String) -> bool:
	return state.is_at_port() and not port_id.is_empty() and port_id == state.current_port_id()


static func _warehouse_entry(state: GameState, port_id: String) -> Dictionary:
	var warehouses: Dictionary = state.world()["warehouses"]
	var entry: Variant = warehouses.get(port_id, null)
	if not (entry is Dictionary):
		entry = {MODULE_SECTION: {}, MATERIAL_SECTION: {}}
		warehouses[port_id] = entry
	_ensure_sections(entry)
	return entry


static func _ensure_sections(entry: Dictionary) -> void:
	if not (entry.get(MODULE_SECTION, null) is Dictionary):
		entry[MODULE_SECTION] = {}
	if not (entry.get(MATERIAL_SECTION, null) is Dictionary):
		entry[MATERIAL_SECTION] = {}


static func _section(entry: Dictionary, key: String) -> Dictionary:
	var value: Variant = entry.get(key, null)
	return value if value is Dictionary else {}
