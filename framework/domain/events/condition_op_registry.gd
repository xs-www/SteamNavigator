class_name ConditionOpRegistry
extends RefCounted
## Framework-owned whitelist of condition opcodes.

static var _ops: Dictionary = {}
static var _initialized: bool = false


static func ensure_defaults() -> void:
	if _initialized:
		return
	_initialized = true
	register("money_gte", func(node: Dictionary, ctx: Dictionary) -> bool:
		return ctx["state"].money() >= int(node.get("value", 0))
	)
	register("reputation_gte", func(node: Dictionary, ctx: Dictionary) -> bool:
		return int(ctx["state"].player().get("reputation", 0)) >= int(node.get("value", 0))
	)
	register("debt_lte", func(node: Dictionary, ctx: Dictionary) -> bool:
		var debt: Variant = ctx["state"].player().get("debt", null)
		var remaining := 0.0 if debt == null else float(debt.get("remaining", 0.0))
		return remaining <= float(node.get("value", 0))
	)
	register("at_port", func(node: Dictionary, ctx: Dictionary) -> bool:
		if not ctx["state"].is_at_port():
			return false
		var required_port := String(node.get("port_id", ""))
		return required_port.is_empty() or ctx["state"].current_port_id() == required_port
	)
	register("port_has_tag", func(node: Dictionary, ctx: Dictionary) -> bool:
		var port_id := String(node.get("port_id", ctx["state"].current_port_id()))
		var port: Dictionary = ctx["state"].world().get("ports", {}).get(port_id, {})
		return Array(port.get("tags", [])).has(String(node.get("tag", "")))
	)
	register("has_item", func(node: Dictionary, ctx: Dictionary) -> bool:
		var item_id := String(node.get("item_id", ""))
		var required := int(node.get("amount", 1))
		return _item_amount(ctx["state"].ship(), item_id) >= required
	)
	register("has_module", func(node: Dictionary, ctx: Dictionary) -> bool:
		return _installed_module_ids(ctx["state"].ship()).has(String(node.get("id", "")))
	)
	register("has_module_tag", func(node: Dictionary, ctx: Dictionary) -> bool:
		var tag := String(node.get("tag", ""))
		for module_id in _installed_module_ids(ctx["state"].ship()):
			var definition: ContentDefinition = _find_module(ctx["hub"], module_id)
			if definition != null and definition.has_tag(tag):
				return true
		return false
	)
	register("has_role", func(node: Dictionary, ctx: Dictionary) -> bool:
		var ship: Dictionary = ctx["state"].ship()
		var wanted_kind := String(node.get("role_kind", ""))
		var wanted_id := String(node.get("id", ""))
		for key in ["engineer_id", "navigator_id"]:
			var role_id := String(ship.get(key, ""))
			if role_id.is_empty():
				continue
			if not wanted_id.is_empty() and role_id == wanted_id:
				return true
			if not wanted_kind.is_empty():
				var role: ContentDefinition = ctx["hub"].get_by_id(ContentTypes.ROLE, role_id)
				if role != null and String(role.data.get("kind", "")) == wanted_kind:
					return true
		return false
	)
	register("contract_completed", func(node: Dictionary, ctx: Dictionary) -> bool:
		var completed: Array = ctx["state"].contracts().get("completed", [])
		return completed.has(String(node.get("id", "")))
	)
	register("port_discovered", func(node: Dictionary, ctx: Dictionary) -> bool:
		var discovered: Array = ctx["state"].world().get("discovered_ports", [])
		return discovered.has(String(node.get("port_id", "")))
	)
	register("ship_tier_gte", func(node: Dictionary, ctx: Dictionary) -> bool:
		var hull: ContentDefinition = ctx["hub"].get_by_id(ContentTypes.HULL, String(ctx["state"].ship().get("hull_id", "")))
		return hull != null and int(hull.data.get("tier", 0)) >= int(node.get("value", 1))
	)
	register("durability_gte", func(node: Dictionary, ctx: Dictionary) -> bool:
		return float(ctx["state"].ship().get("durability", 0.0)) >= float(node.get("value", 0.0))
	)


static func register(op: String, handler: Callable) -> void:
	_ops[op] = handler


static func has(op: String) -> bool:
	ensure_defaults()
	return _ops.has(op)


static func get_handler(op: String) -> Callable:
	ensure_defaults()
	return _ops.get(op, Callable())


static func known_ops() -> PackedStringArray:
	ensure_defaults()
	var result := PackedStringArray()
	for key in _ops.keys():
		result.append(String(key))
	result.sort()
	return result


static func _installed_module_ids(ship: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in ["hull_id", "boiler_id", "navigation_module_id", "safety_module_id", "passenger_cabin_id"]:
		var value := String(ship.get(key, ""))
		if not value.is_empty():
			result.append(value)
	var cargo_modules: Array = ship.get("cargo_modules", [])
	for value in cargo_modules:
		result.append(String(value))
	return result


static func _find_module(hub: RegistryHub, module_id: String) -> ContentDefinition:
	for content_type in ContentTypes.MODULE_TYPES:
		var definition := hub.get_by_id(content_type, module_id)
		if definition != null:
			return definition
	return null


static func _item_amount(ship: Dictionary, item_id: String) -> int:
	var total := 0
	for stack in ship.get("cargo", []):
		if String(stack.get("item_id", "")) == item_id:
			total += int(stack.get("amount", 0))
	return total


static func clear_runtime() -> void:
	_ops.clear()
	_initialized = false
