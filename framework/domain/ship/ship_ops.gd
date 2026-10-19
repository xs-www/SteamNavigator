class_name ShipOps
extends RefCounted
## Pure helpers for ship composition, weight, capacity and derived stats.

const COAL_WEIGHT := 1.0
const WATER_WEIGHT := 1.0
const PASSENGER_WEIGHT := 0.8

const EQUIPMENT_KEYS := ["hull_id", "boiler_id", "navigation_module_id", "safety_module_id", "passenger_cabin_id"]
const INSTALLABLE_TYPES := [
	ContentTypes.HULL,
	ContentTypes.BOILER,
	ContentTypes.CARGO_MODULE,
	ContentTypes.NAVIGATION_MODULE,
	ContentTypes.SAFETY_MODULE,
	ContentTypes.CABIN,
]


static func all_installed_module_ids(ship: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in EQUIPMENT_KEYS:
		var value := String(ship.get(key, ""))
		if not value.is_empty():
			result.append(value)
	for value in ship.get("cargo_modules", []):
		result.append(String(value))
	return result


static func cargo_module_ids(ship: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for value in ship.get("cargo_modules", []):
		result.append(String(value))
	return result


static func find_module(hub: RegistryHub, module_id: String) -> ContentDefinition:
	if module_id.is_empty():
		return null
	for content_type in ContentTypes.MODULE_TYPES:
		var definition := hub.get_by_id(content_type, module_id)
		if definition != null:
			return definition
	return null


static func item_definition(hub: RegistryHub, item_id: String) -> ContentDefinition:
	var good := hub.get_by_id(ContentTypes.GOOD, item_id)
	if good != null:
		return good
	return hub.get_by_id(ContentTypes.MATERIAL, item_id)


static func installed_modules(hub: RegistryHub, ship: Dictionary) -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for module_id in all_installed_module_ids(ship):
		var definition := find_module(hub, module_id)
		if definition != null:
			result.append(definition)
	return result


static func module_weight(hub: RegistryHub, ship: Dictionary) -> float:
	var total := 0.0
	for definition in installed_modules(hub, ship):
		total += float(definition.data.get("weight", 0.0))
	return total


## Damage points still owed by damaged module instances, using module weight as
## the size/cost proxy so repair pricing stays data-driven and close to hull
## points. Full condition contributes 0.
static func module_damage_points(hub: RegistryHub, ship: Dictionary) -> float:
	var total := 0.0
	for row in ShipModules.installed_rows(ship):
		var missing := 1.0 - float(row["condition"])
		if missing <= 0.0:
			continue
		var definition := find_module(hub, String(row["module_id"]))
		var weight := float(definition.data.get("weight", 0.0)) if definition != null else 0.0
		total += weight * missing
	return total


## True when at least one installed module instance is at zero condition.
static func has_disabled_module(ship: Dictionary) -> bool:
	for row in ShipModules.installed_rows(ship):
		if bool(row["disabled"]):
			return true
	return false


static func cargo_weight(hub: RegistryHub, ship: Dictionary) -> float:
	var total := 0.0
	for stack in ship.get("cargo", []):
		var item_id := String(stack.get("item_id", ""))
		var definition := item_definition(hub, item_id)
		if definition != null:
			total += float(definition.data.get("unit_weight", 0.0)) * float(stack.get("amount", 0))
	return total


static func passenger_count(state: GameState) -> int:
	var total := 0
	var contracts: Dictionary = state.contracts()
	var main_contract: Variant = contracts.get("main", null)
	if main_contract is Dictionary:
		total += int(main_contract.get("passengers", 0))
	for contract in contracts.get("active", []):
		if contract is Dictionary:
			total += int(contract.get("passengers", 0))
	return total


static func total_weight(hub: RegistryHub, state: GameState) -> float:
	var ship := state.ship()
	return module_weight(hub, ship) \
		+ WarehouseOps.transit_module_weight(hub, ship) \
		+ cargo_weight(hub, ship) \
		+ float(ship.get("coal", 0.0)) * COAL_WEIGHT \
		+ float(ship.get("water", 0.0)) * WATER_WEIGHT \
		+ float(passenger_count(state)) * PASSENGER_WEIGHT


static func max_weight(hub: RegistryHub, ship: Dictionary) -> float:
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	return float(hull.data.get("max_weight", 0.0)) if hull != null else 0.0


static func cargo_capacity(hub: RegistryHub, ship: Dictionary) -> float:
	var capacity := 0.0
	for module_id in cargo_module_ids(ship):
		var definition := hub.get_by_id(ContentTypes.CARGO_MODULE, module_id)
		if definition != null:
			capacity += float(definition.data.get("capacity", 0.0))
	return capacity


static func cargo_used(hub: RegistryHub, ship: Dictionary) -> float:
	return cargo_weight(hub, ship)


static func free_cargo_capacity(hub: RegistryHub, ship: Dictionary) -> float:
	return maxf(0.0, cargo_capacity(hub, ship) - cargo_used(hub, ship))


static func passenger_capacity(hub: RegistryHub, ship: Dictionary) -> int:
	var cabin_id := String(ship.get("passenger_cabin_id", ""))
	if cabin_id.is_empty():
		return 0
	var cabin := hub.get_by_id(ContentTypes.CABIN, cabin_id)
	return int(cabin.data.get("passenger_capacity", 0)) if cabin != null else 0


static func durability_max(hub: RegistryHub, ship: Dictionary) -> float:
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	return float(hull.data.get("max_durability", 100.0)) if hull != null else 100.0


static func stats(hub: RegistryHub, ship: Dictionary) -> Dictionary:
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	var boiler := hub.get_by_id(ContentTypes.BOILER, String(ship.get("boiler_id", "")))
	if hull == null or boiler == null:
		return {
			"valid": false,
			"speed": 0.0,
			"coal_rate": 0.0,
			"water_rate": 0.0,
			"risk_add": 0.0,
			"repair_cost_mul": 1.0,
			"damage_mul": 1.0,
			"max_weight": 0.0,
			"max_durability": 0.0,
			"cargo_capacity": 0.0,
			"passenger_capacity": 0,
			"hull_tier": 0,
			"reveal_facilities": false,
		}

	var speed := float(hull.data.get("base_speed", 10.0)) * float(boiler.data.get("speed_mul", 1.0))
	var coal_rate := float(boiler.data.get("coal_rate", 0.3))
	var water_rate := float(boiler.data.get("water_rate", 0.2))
	var risk_add := float(hull.data.get("base_risk", 0.0))
	var repair_cost_mul := 1.0
	var damage_mul := 1.0
	var reveal_facilities := false

	var navigation := hub.get_by_id(ContentTypes.NAVIGATION_MODULE, String(ship.get("navigation_module_id", "")))
	if navigation != null:
		speed *= float(navigation.data.get("speed_mul", 1.0))
		risk_add += float(navigation.data.get("risk_add", 0.0))
		reveal_facilities = bool(navigation.data.get("reveal_facilities", false))

	var safety := hub.get_by_id(ContentTypes.SAFETY_MODULE, String(ship.get("safety_module_id", "")))
	if safety != null:
		risk_add += float(safety.data.get("risk_add", 0.0))
		damage_mul *= float(safety.data.get("damage_mul", 1.0))
		repair_cost_mul *= float(safety.data.get("repair_cost_mul", 1.0))

	for definition in installed_modules(hub, ship):
		for modifier in definition.data.get("modifiers", []):
			if not (modifier is Dictionary):
				continue
			var stat := String(modifier.get("stat", ""))
			var value := float(modifier.get("value", 0.0))
			var op := String(modifier.get("op", "add"))
			match stat:
				"speed":
					speed = _apply_modifier(speed, op, value)
				"coal_rate":
					coal_rate = _apply_modifier(coal_rate, op, value)
				"water_rate":
					water_rate = _apply_modifier(water_rate, op, value)
				"risk":
					risk_add = _apply_modifier(risk_add, op, value)
				"repair_cost":
					repair_cost_mul = _apply_modifier(repair_cost_mul, op, value)
				"damage":
					damage_mul = _apply_modifier(damage_mul, op, value)

	for kind in ["engineer", "navigator"]:
		var role := role_definition(hub, ship, kind)
		if role == null:
			continue
		for modifier in role.data.get("modifiers", []):
			if not (modifier is Dictionary):
				continue
			var stat := String(modifier.get("stat", ""))
			var value := float(modifier.get("value", 0.0))
			var op := String(modifier.get("op", "add"))
			match stat:
				"speed":
					speed = _apply_modifier(speed, op, value)
				"coal_rate":
					coal_rate = _apply_modifier(coal_rate, op, value)
				"water_rate":
					water_rate = _apply_modifier(water_rate, op, value)
				"risk":
					risk_add = _apply_modifier(risk_add, op, value)
				"repair_cost":
					repair_cost_mul = _apply_modifier(repair_cost_mul, op, value)
				"damage":
					damage_mul = _apply_modifier(damage_mul, op, value)

	return {
		"valid": true,
		"speed": maxf(0.1, speed),
		"coal_rate": maxf(0.0, coal_rate),
		"water_rate": maxf(0.0, water_rate),
		"risk_add": clampf(risk_add, -0.5, 0.5),
		"repair_cost_mul": maxf(0.0, repair_cost_mul),
		"damage_mul": maxf(0.0, damage_mul),
		"max_weight": max_weight(hub, ship),
		"max_durability": durability_max(hub, ship),
		"cargo_capacity": cargo_capacity(hub, ship),
		"passenger_capacity": passenger_capacity(hub, ship),
		"hull_tier": int(hull.data.get("tier", 1)),
		"reveal_facilities": reveal_facilities,
	}


static func role_definition(hub: RegistryHub, ship: Dictionary, kind: String) -> ContentDefinition:
	var key := "%s_id" % kind
	var role_id := String(ship.get(key, ""))
	if role_id.is_empty():
		return null
	var role := hub.get_by_id(ContentTypes.ROLE, role_id)
	if role == null or String(role.data.get("kind", "")) != kind:
		return null
	return role


static func add_cargo(ship: Dictionary, item_id: String, amount: int, contract_id: String = "", total_cost: float = 0.0) -> void:
	if amount <= 0:
		return
	if not ship.has("cargo"):
		ship["cargo"] = []
	var cargo: Array = ship["cargo"]
	for stack in cargo:
		if String(stack.get("item_id", "")) == item_id and String(stack.get("contract_id", "")) == contract_id:
			stack["amount"] = int(stack.get("amount", 0)) + amount
			stack["total_cost"] = float(stack.get("total_cost", 0.0)) + maxf(0.0, total_cost)
			return
	cargo.append({
		"item_id": item_id,
		"amount": amount,
		"contract_id": contract_id,
		"total_cost": maxf(0.0, total_cost),
	})


static func cargo_amount(ship: Dictionary, item_id: String, allow_contract: bool = true) -> int:
	var total := 0
	for stack in ship.get("cargo", []):
		if String(stack.get("item_id", "")) != item_id:
			continue
		if not allow_contract and not String(stack.get("contract_id", "")).is_empty():
			continue
		total += int(stack.get("amount", 0))
	return total


static func cargo_total_cost(ship: Dictionary, allow_contract: bool = false) -> float:
	var total := 0.0
	for stack in ship.get("cargo", []):
		if not allow_contract and not String(stack.get("contract_id", "")).is_empty():
			continue
		total += float(stack.get("total_cost", 0.0))
	return total


static func cargo_average_cost(ship: Dictionary, item_id: String, allow_contract: bool = false) -> float:
	var amount := 0
	var cost := 0.0
	for stack in ship.get("cargo", []):
		if String(stack.get("item_id", "")) != item_id:
			continue
		if not allow_contract and not String(stack.get("contract_id", "")).is_empty():
			continue
		amount += int(stack.get("amount", 0))
		cost += float(stack.get("total_cost", 0.0))
	return cost / float(amount) if amount > 0 else 0.0


static func remove_cargo(ship: Dictionary, item_id: String, amount: int, allow_contract: bool = false) -> int:
	if amount <= 0:
		return 0
	var remaining := amount
	var removed := 0
	var cargo: Array = ship.get("cargo", [])
	for index in range(cargo.size() - 1, -1, -1):
		var stack: Dictionary = cargo[index]
		if String(stack.get("item_id", "")) != item_id:
			continue
		if not allow_contract and not String(stack.get("contract_id", "")).is_empty():
			continue
		var available := int(stack.get("amount", 0))
		var take := mini(remaining, available)
		var stack_cost := float(stack.get("total_cost", 0.0))
		var take_cost := stack_cost * float(take) / float(available) if available > 0 else 0.0
		stack["amount"] = available - take
		stack["total_cost"] = maxf(0.0, stack_cost - take_cost)
		remaining -= take
		removed += take
		if int(stack["amount"]) <= 0:
			cargo.remove_at(index)
		if remaining <= 0:
			break
	return removed


static func remove_non_contract_cargo_by_weight(hub: RegistryHub, ship: Dictionary, weight: float) -> float:
	if weight <= 0.0:
		return 0.0
	var removed_weight := 0.0
	var cargo: Array = ship.get("cargo", [])
	for index in range(cargo.size() - 1, -1, -1):
		var stack: Dictionary = cargo[index]
		if not String(stack.get("contract_id", "")).is_empty():
			continue
		var definition := item_definition(hub, String(stack.get("item_id", "")))
		if definition == null:
			continue
		var unit_weight := float(definition.data.get("unit_weight", 0.0))
		if unit_weight <= 0.0:
			continue
		var available := int(stack.get("amount", 0))
		var needed_units := int(ceil(weight / unit_weight))
		var take := mini(needed_units, available)
		var stack_cost := float(stack.get("total_cost", 0.0))
		stack["amount"] = available - take
		stack["total_cost"] = maxf(0.0, stack_cost * (1.0 - float(take) / float(available))) if available > 0 else 0.0
		removed_weight += take * unit_weight
		if int(stack["amount"]) <= 0:
			cargo.remove_at(index)
		if removed_weight >= weight:
			break
	return removed_weight


static func module_type(hub: RegistryHub, module_id: String) -> StringName:
	for content_type in INSTALLABLE_TYPES:
		if hub.contains(content_type, module_id):
			return content_type
	return &""


## Contract template whose `unlock_ids` gate this module, or "" when unlocked.
static func unlock_contract_id(hub: RegistryHub, module_id: String) -> String:
	if module_id.is_empty():
		return ""
	for template in hub.get_all(ContentTypes.CONTRACT):
		for unlock_id in _contract_unlock_ids(template):
			if String(unlock_id) == module_id:
				return template.id
	return ""


## True when the module is gated behind a contract the player has not completed.
## Completing a contract appends its `unlock_ids` (the module IDs themselves) to
## player.unlocks, so ownership of the module ID is the unlock test.
static func locked_by_contract(hub: RegistryHub, state: GameState, module_id: String) -> bool:
	if unlock_contract_id(hub, module_id).is_empty():
		return false
	return not Array(state.player().get("unlocks", [])).has(module_id)


## Returns a stable list of blocker codes for installing a module from a given
## source ("purchase", "warehouse" or "transit"). Callers add port/facility
## checks. The first code is the user-facing reason.
##
## Replacement semantics: hull/boiler/navigation/safety/cabin auto-replace the
## existing module in their single slot, so `slot_occupied` is never returned.
## Cargo modules need `replace_module_id` once all hull slots are used; passing
## it makes the weight check use the replaced module instead of adding weight.
## Weight is evaluated on the final configuration, subtracting both the replaced
## module and (for transit sources) the module weight already carried.
static func install_blockers(hub: RegistryHub, state: GameState, module_id: String, source: String = "purchase", replace_module_id: String = "") -> Array[String]:
	var blockers: Array[String] = []
	if not ["purchase", "warehouse", "transit"].has(source):
		blockers.append("invalid_source")
		return blockers
	var content_type := module_type(hub, module_id)
	if content_type == &"":
		blockers.append("unknown_module")
		return blockers
	var module := hub.get_by_id(content_type, module_id)
	if module == null:
		blockers.append("unknown_module")
		return blockers
	var player := state.player()
	if int(module.data.get("unlock_reputation", 0)) > int(player.get("reputation", 0)):
		blockers.append("locked_by_reputation")
	if locked_by_contract(hub, state, module_id):
		blockers.append("locked_by_contract")
	var ship := state.ship()
	var installed_ids := all_installed_module_ids(ship)
	if installed_ids.has(module_id):
		if content_type != ContentTypes.CARGO_MODULE:
			blockers.append("already_installed")
		else:
			# Cargo modules may be bought as duplicates while a slot is free; the
			# same ID is only "already installed" once every cargo slot is used.
			var cargo_hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
			var cargo_slot_count := int(cargo_hull.data.get("cargo_slots", 0)) if cargo_hull != null else 0
			if cargo_module_ids(ship).size() >= cargo_slot_count:
				blockers.append("already_installed")

	match source:
		"purchase":
			var price := int(round(float(module.data.get("purchase_price", 0.0))))
			if state.money() < price:
				blockers.append("insufficient_money")
		"warehouse":
			if WarehouseOps.module_qty(state, state.current_port_id(), module_id) < 1:
				blockers.append("warehouse_empty")
		"transit":
			if WarehouseOps.transit_qty(ship, module_id) < 1:
				blockers.append("not_in_transit")

	if not replace_module_id.is_empty() and replace_module_id != module_id:
		if not installed_ids.has(replace_module_id):
			blockers.append("not_installed")

	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	var current_weight := total_weight(hub, state)
	var current_max := max_weight(hub, ship)
	var module_weight := float(module.data.get("weight", 0.0))
	var replaced_weight := 0.0
	var weight_limit := current_max

	match content_type:
		ContentTypes.CARGO_MODULE:
			var slots := int(hull.data.get("cargo_slots", 0)) if hull != null else 0
			var cargo_ids := cargo_module_ids(ship)
			if not replace_module_id.is_empty():
				if cargo_ids.has(replace_module_id):
					replaced_weight = _module_weight_by_id(hub, ContentTypes.CARGO_MODULE, replace_module_id)
				else:
					if not blockers.has("not_installed"):
						blockers.append("not_installed")
					if cargo_ids.size() >= slots:
						blockers.append("cargo_slots_full")
			elif cargo_ids.size() >= slots:
				blockers.append("cargo_slots_full")
		ContentTypes.CABIN:
			if hull == null or int(hull.data.get("cabin_slots", 0)) < 1:
				blockers.append("no_cabin_slot")
			else:
				replaced_weight = _module_weight_by_id(hub, ContentTypes.CABIN, String(ship.get("passenger_cabin_id", "")))
		ContentTypes.NAVIGATION_MODULE:
			replaced_weight = _module_weight_by_id(hub, ContentTypes.NAVIGATION_MODULE, String(ship.get("navigation_module_id", "")))
		ContentTypes.SAFETY_MODULE:
			replaced_weight = _module_weight_by_id(hub, ContentTypes.SAFETY_MODULE, String(ship.get("safety_module_id", "")))
		ContentTypes.BOILER:
			replaced_weight = _module_weight_by_id(hub, ContentTypes.BOILER, String(ship.get("boiler_id", "")))
		ContentTypes.HULL:
			if hull != null:
				if cargo_module_ids(ship).size() > int(module.data.get("cargo_slots", 0)):
					blockers.append("too_many_cargo_modules")
				if not String(ship.get("passenger_cabin_id", "")).is_empty() and int(module.data.get("cabin_slots", 0)) < 1:
					blockers.append("no_cabin_slot")
			replaced_weight = _module_weight_by_id(hub, ContentTypes.HULL, String(ship.get("hull_id", "")))
			weight_limit = float(module.data.get("max_weight", current_max))

	var transit_release := module_weight if source == "transit" else 0.0
	var delta := module_weight - replaced_weight - transit_release
	if current_weight + delta > weight_limit + 0.0001:
		blockers.append("weight_limit")
	return blockers


## Returns blocker codes for uninstalling an installed module into the current
## port warehouse. Hull and boiler are required and can never be removed.
static func uninstall_blockers(hub: RegistryHub, state: GameState, module_id: String) -> Array[String]:
	var blockers: Array[String] = []
	var content_type := module_type(hub, module_id)
	if content_type == &"":
		blockers.append("unknown_module")
		return blockers
	if not all_installed_module_ids(state.ship()).has(module_id):
		blockers.append("not_installed")
		return blockers
	if content_type == ContentTypes.HULL or content_type == ContentTypes.BOILER:
		blockers.append("required_module")
	return blockers


static func validate_configuration(hub: RegistryHub, ship: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	var boiler := hub.get_by_id(ContentTypes.BOILER, String(ship.get("boiler_id", "")))
	if hull == null:
		errors.append("missing_hull")
	if boiler == null:
		errors.append("missing_boiler")
	if hull == null:
		return {"ok": false, "errors": errors}
	if cargo_module_ids(ship).size() > int(hull.data.get("cargo_slots", 0)):
		errors.append("too_many_cargo_modules")
	if not String(ship.get("passenger_cabin_id", "")).is_empty() and int(hull.data.get("cabin_slots", 0)) < 1:
		errors.append("hull_has_no_cabin_slot")
	if float(ship.get("durability", 0.0)) > durability_max(hub, ship):
		errors.append("durability_over_max")
	return {"ok": errors.is_empty(), "errors": errors}


static func _module_weight_by_id(hub: RegistryHub, content_type: StringName, module_id: String) -> float:
	if module_id.is_empty():
		return 0.0
	var definition := hub.get_by_id(content_type, module_id)
	return float(definition.data.get("weight", 0.0)) if definition != null else 0.0


static func _contract_unlock_ids(template: ContentDefinition) -> Array:
	var result: Array = []
	var rewards: Variant = template.data.get("rewards", null)
	if rewards is Dictionary:
		var reward_ids: Variant = rewards.get("unlock_ids", null)
		if reward_ids is Array:
			result.append_array(reward_ids)
	var top_level: Variant = template.data.get("unlock_ids", null)
	if top_level is Array:
		result.append_array(top_level)
	return result


static func _apply_modifier(base: float, op: String, value: float) -> float:
	match op:
		"mul":
			return base * value
		"set":
			return value
		_:
			return base + value
