class_name CraftOps
extends RefCounted
## Module crafting as work orders: recipe lookup, material planning, warehouse-first
## consumption and settlement.
##
## Recipes live in module.data.materials / craft_time_hours / craft_cost. A recipe
## is craftable when its type is in CRAFTABLE_TYPES and it either needs materials
## or has a craft_cost > 0, so tier-1 "money only" recipes (materials: []) are
## still craftable without ever reporting missing_materials.
##
## Crafting consumes materials from the current port warehouse first, then from
## non-contract cargo on the ship, pays craft_cost and queues an order. The ship
## does not wait: the finished module only enters the owning port's warehouse once
## game time reaches ready_at, settled by CraftOps.settle_orders() (called at the
## start of a craft, after voyage time advances and by the port.wait command).

const CRAFTABLE_TYPES := [
	ContentTypes.HULL,
	ContentTypes.BOILER,
	ContentTypes.CARGO_MODULE,
	ContentTypes.NAVIGATION_MODULE,
	ContentTypes.SAFETY_MODULE,
	ContentTypes.CABIN,
]

const ORDER_KEY := "shipyard_orders"
const SERIAL_KEY := "order_serial"
const EPSILON := 0.000000001


## Normalized recipe rows: [{item_id, amount}]. Empty when the module has no recipe.
static func materials_required(hub: RegistryHub, module_id: String) -> Array:
	var result: Array = []
	var module := ShipOps.find_module(hub, module_id)
	if module == null:
		return result
	if not CRAFTABLE_TYPES.has(module.content_type):
		return result
	var materials: Variant = module.data.get("materials", null)
	if not (materials is Array):
		return result
	for raw_material in materials:
		if not (raw_material is Dictionary):
			continue
		var material: Dictionary = raw_material
		var item_id := String(material.get("id", material.get("item_id", "")))
		var amount := int(material.get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			continue
		result.append({"item_id": item_id, "amount": amount})
	return result


## Craftable = supported type and (materials required or a gold cost). A recipe
## with an empty materials list is never "not_craftable" on its own.
static func craftable(hub: RegistryHub, module_id: String) -> bool:
	var module := ShipOps.find_module(hub, module_id)
	if module == null or not CRAFTABLE_TYPES.has(module.content_type):
		return false
	return not materials_required(hub, module_id).is_empty() or craft_cost(hub, module_id) > 0


## True for tier-1 convenience recipes that only ask for gold (materials: []).
static func money_only(hub: RegistryHub, module_id: String) -> bool:
	if not craftable(hub, module_id):
		return false
	return materials_required(hub, module_id).is_empty() and craft_cost(hub, module_id) > 0


static func craft_cost(hub: RegistryHub, module_id: String) -> int:
	var module := ShipOps.find_module(hub, module_id)
	if module == null:
		return 0
	return maxi(0, int(round(float(module.data.get("craft_cost", 0.0)))))


static func craft_time(hub: RegistryHub, module_id: String) -> float:
	var module := ShipOps.find_module(hub, module_id)
	if module == null:
		return 0.0
	return maxf(0.0, float(module.data.get("craft_time_hours", 0.0)))


## Idempotently creates state.data.shipyard_orders (Array) and order_serial (int).
## Safe on old saves that predate work orders; also normalizes a JSON-loaded
## float serial back to an int so later order ids stay stable.
static func ensure_orders(state: GameState) -> void:
	if not (state.data.get(ORDER_KEY, null) is Array):
		state.data[ORDER_KEY] = []
	# `.get(key, 0)` hides an absent key, so presence is checked separately: an
	# old save must actually receive `order_serial`, otherwise later `data[key]`
	# reads fail at runtime while still coercing to 0.
	var missing := not state.data.has(SERIAL_KEY)
	var serial: Variant = state.data.get(SERIAL_KEY, 0)
	var normalized := 0
	if serial is float or serial is int:
		normalized = maxi(0, int(serial))
	elif serial is String and String(serial).is_valid_int():
		normalized = maxi(0, int(serial))
	if missing or typeof(serial) != TYPE_INT or int(serial) != normalized:
		state.data[SERIAL_KEY] = normalized


## Open (unfinished) orders, oldest first. Never null so callers can iterate.
static func orders(state: GameState) -> Array:
	var raw: Variant = state.data.get(ORDER_KEY, null)
	return raw if raw is Array else []


## Material rows for the shipyard UI: warehouse-first view of a recipe.
static func material_plan(state: GameState, hub: RegistryHub, port_id: String, module_id: String) -> Array:
	var plan: Array = []
	var ship := state.ship()
	for requirement in materials_required(hub, module_id):
		var item_id := String(requirement.get("item_id", ""))
		var required := int(requirement.get("amount", 0))
		var in_warehouse := WarehouseOps.material_amount(state, port_id, item_id)
		var in_cargo := ShipOps.cargo_amount(ship, item_id, false)
		var definition := ShipOps.item_definition(hub, item_id)
		plan.append({
			"item_id": item_id,
			"name_key": definition.name_key if definition != null else item_id,
			"required": required,
			"warehouse": in_warehouse,
			"cargo": in_cargo,
			"owned": in_warehouse + in_cargo,
			"enough": in_warehouse + in_cargo >= required,
		})
	return plan


## Blocker codes shared by ship.craft_module and shipyard.view. Order is the
## user-facing priority. Callers add port/facility checks.
static func craft_blockers(hub: RegistryHub, state: GameState, module_id: String) -> Array[String]:
	var blockers: Array[String] = []
	var content_type := ShipOps.module_type(hub, module_id)
	if content_type == &"" or ShipOps.find_module(hub, module_id) == null:
		blockers.append("unknown_module")
		return blockers
	if not craftable(hub, module_id):
		blockers.append("not_craftable")
		return blockers
	if ShipOps.locked_by_contract(hub, state, module_id):
		blockers.append("locked_by_contract")
	var plan := material_plan(state, hub, state.current_port_id(), module_id)
	for requirement in plan:
		if not bool(requirement.get("enough", false)):
			blockers.append("missing_materials")
			break
	if state.money() < craft_cost(hub, module_id):
		blockers.append("insufficient_money")
	return blockers


## Consumes materials (warehouse first, then non-contract cargo), pays craft_cost,
## records the expense and queues a work order. Game time does NOT advance and the
## finished module does not enter any warehouse yet: settle_orders() delivers it
## when state.now() reaches ready_at. Must run inside a command transaction.
static func craft(state: GameState, hub: RegistryHub, module_id: String) -> Dictionary:
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port", {"module_id": module_id})
	ensure_orders(state)
	# Orders that became ready while the ship stood in port are collected first.
	settle_orders(state, hub)
	var blockers := craft_blockers(hub, state, module_id)
	if not blockers.is_empty():
		return Result.fail(String(blockers[0]), "ui.error.%s" % String(blockers[0]), {
			"module_id": module_id,
			"blockers": blockers,
			"materials": material_plan(state, hub, state.current_port_id(), module_id),
		})
	var content_type := ShipOps.module_type(hub, module_id)
	var ship := state.ship()
	var port_id := state.current_port_id()
	WarehouseOps.ensure_structure(state)
	var consumed: Array = []
	for requirement in materials_required(hub, module_id):
		var item_id := String(requirement.get("item_id", ""))
		var remaining := int(requirement.get("amount", 0))
		var from_warehouse := mini(remaining, WarehouseOps.material_amount(state, port_id, item_id))
		if from_warehouse > 0:
			WarehouseOps.remove_material(state, port_id, item_id, from_warehouse)
			remaining -= from_warehouse
		var from_cargo := 0
		if remaining > 0:
			from_cargo = ShipOps.remove_cargo(ship, item_id, remaining, false)
			remaining -= from_cargo
		if remaining > 0:
			return Result.fail("missing_materials", "ui.error.missing_materials", {
				"module_id": module_id,
				"item_id": item_id,
				"missing": remaining,
			})
		consumed.append({
			"item_id": item_id,
			"from_warehouse": from_warehouse,
			"from_cargo": from_cargo,
		})
	var cost := craft_cost(hub, module_id)
	var hours := craft_time(hub, module_id)
	if cost > 0:
		state.add_money(-cost)
		state.record_expense(cost)
	var placed_at := state.now()
	var ready_at := placed_at + hours
	var serial := int(state.data.get(SERIAL_KEY, 0)) + 1
	state.data[SERIAL_KEY] = serial
	var order := {
		"order_id": "order_%d" % serial,
		"module_id": module_id,
		"port_id": port_id,
		"content_type": String(content_type),
		"placed_at": placed_at,
		"ready_at": ready_at,
		"craft_cost": cost,
	}
	state.data[ORDER_KEY].append(order)
	state.push_notice("ui.notice.craft_ordered", {
		"port": MapOps.port_display_key(state.world(), port_id),
		"module": _module_name_key(hub, module_id),
		"hours": hours,
		"cost": cost,
	})
	return Result.ok({
		"module_id": module_id,
		"content_type": String(content_type),
		"craft_time_hours": hours,
		"craft_cost": cost,
		"consumed": consumed,
		"game_time": state.now(),
		"order_id": String(order["order_id"]),
		"ready_at": ready_at,
		"remaining_hours": maxf(0.0, ready_at - state.now()),
		"orders": orders(state).duplicate(true),
		"money": state.money(),
	})


## Delivers every order whose ready_at has been reached into its owning port's
## warehouse, pushes a completion notice per order and removes it from the list.
## Returns one detail row per finished order ([] when nothing was ready).
static func settle_orders(state: GameState, hub: RegistryHub) -> Array:
	ensure_orders(state)
	var pending: Array = []
	var completed: Array = []
	var current_time := state.now()
	for raw_order in state.data[ORDER_KEY]:
		if not (raw_order is Dictionary):
			continue
		var order: Dictionary = raw_order
		if float(order.get("ready_at", 0.0)) > current_time + EPSILON:
			pending.append(order)
			continue
		var port_id := String(order.get("port_id", ""))
		var module_id := String(order.get("module_id", ""))
		var cost := int(order.get("craft_cost", 0))
		var warehouse_qty := WarehouseOps.add_module(state, port_id, module_id, 1)
		var name_key := _module_name_key(hub, module_id)
		state.push_notice("ui.notice.craft_completed", {
			"module": name_key,
			"port": MapOps.port_display_key(state.world(), port_id),
		})
		completed.append({
			"order_id": String(order.get("order_id", "")),
			"module_id": module_id,
			"content_type": String(order.get("content_type", "")),
			"name_key": name_key,
			"port_id": port_id,
			"placed_at": float(order.get("placed_at", 0.0)),
			"ready_at": float(order.get("ready_at", 0.0)),
			"craft_cost": cost,
			"warehouse_qty": warehouse_qty,
		})
	state.data[ORDER_KEY] = pending
	return completed


static func _module_name_key(hub: RegistryHub, module_id: String) -> String:
	var module := ShipOps.find_module(hub, module_id)
	return module.name_key if module != null else module_id