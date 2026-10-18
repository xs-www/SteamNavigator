class_name ShipOps
extends RefCounted
## Pure helpers for ship composition, weight, capacity and derived stats.

const COAL_WEIGHT := 1.0
const WATER_WEIGHT := 1.0
const PASSENGER_WEIGHT := 0.8

const EQUIPMENT_KEYS := ["hull_id", "boiler_id", "navigation_module_id", "safety_module_id", "passenger_cabin_id"]


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


static func add_cargo(ship: Dictionary, item_id: String, amount: int, contract_id: String = "") -> void:
	if amount <= 0:
		return
	if not ship.has("cargo"):
		ship["cargo"] = []
	var cargo: Array = ship["cargo"]
	for stack in cargo:
		if String(stack.get("item_id", "")) == item_id and String(stack.get("contract_id", "")) == contract_id:
			stack["amount"] = int(stack.get("amount", 0)) + amount
			return
	cargo.append({"item_id": item_id, "amount": amount, "contract_id": contract_id})


static func cargo_amount(ship: Dictionary, item_id: String, allow_contract: bool = true) -> int:
	var total := 0
	for stack in ship.get("cargo", []):
		if String(stack.get("item_id", "")) != item_id:
			continue
		if not allow_contract and not String(stack.get("contract_id", "")).is_empty():
			continue
		total += int(stack.get("amount", 0))
	return total


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
		stack["amount"] = available - take
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
		stack["amount"] = available - take
		removed_weight += take * unit_weight
		if int(stack["amount"]) <= 0:
			cargo.remove_at(index)
		if removed_weight >= weight:
			break
	return removed_weight


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


static func _apply_modifier(base: float, op: String, value: float) -> float:
	match op:
		"mul":
			return base * value
		"set":
			return value
		_:
			return base + value
