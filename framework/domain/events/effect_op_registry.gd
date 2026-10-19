class_name EffectOpRegistry
extends RefCounted
## Framework-owned whitelist of effect opcodes. Content never executes code.

static var _ops: Dictionary = {}
static var _initialized: bool = false


static func ensure_defaults() -> void:
	if _initialized:
		return
	_initialized = true
	register("add_money", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var amount := int(node.get("amount", 0))
		if amount < 0:
			return _fail("invalid_amount")
		ctx["state"].add_money(amount)
		return _ok()
	)
	register("remove_money", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var amount := int(node.get("amount", 0))
		if amount < 0:
			return _fail("invalid_amount")
		if ctx["state"].money() < amount:
			return _fail("insufficient_money")
		ctx["state"].add_money(-amount)
		return _ok()
	)
	register("add_reputation", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var player: Dictionary = ctx["state"].player()
		player["reputation"] = int(player.get("reputation", 0)) + int(node.get("amount", 1))
		return _ok()
	)
	register("remove_reputation", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var player: Dictionary = ctx["state"].player()
		player["reputation"] = maxi(0, int(player.get("reputation", 0)) - int(node.get("amount", 1)))
		return _ok()
	)
	register("add_item", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var item_id := String(node.get("item_id", node.get("id", "")))
		var amount := int(node.get("amount", 1))
		var definition := ShipOps.item_definition(ctx["hub"], item_id)
		if definition == null:
			return _fail("unknown_item")
		if amount <= 0:
			return _fail("invalid_amount")
		var state: GameState = ctx["state"]
		var ship := state.ship()
		var added_weight := float(definition.data.get("unit_weight", 0.0)) * float(amount)
		if ShipOps.total_weight(ctx["hub"], state) + added_weight > ShipOps.max_weight(ctx["hub"], ship) + 0.0001:
			return _fail("weight_limit")
		if ShipOps.cargo_used(ctx["hub"], ship) + added_weight > ShipOps.cargo_capacity(ctx["hub"], ship) + 0.0001:
			return _fail("cargo_capacity")
		ShipOps.add_cargo(ship, item_id, amount)
		return _ok()
	)
	register("remove_item", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var item_id := String(node.get("item_id", node.get("id", "")))
		var amount := int(node.get("amount", 1))
		var removed := ShipOps.remove_cargo(ctx["state"].ship(), item_id, amount, false)
		if removed < amount:
			return _fail("insufficient_cargo")
		return _ok()
	)
	register("add_coal", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		return _add_supply(ctx, "coal", node)
	)
	register("remove_coal", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		return _remove_supply(ctx, "coal", node)
	)
	register("add_water", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		return _add_supply(ctx, "water", node)
	)
	register("remove_water", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		return _remove_supply(ctx, "water", node)
	)
	register("damage_ship", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var state: GameState = ctx["state"]
		var ship := state.ship()
		var stats := ShipOps.stats(ctx["hub"], ship)
		var amount := float(node.get("amount", 0.0)) * float(stats.get("damage_mul", 1.0))
		ship["durability"] = maxf(0.0, float(ship.get("durability", 0.0)) - amount)
		if float(ship["durability"]) <= 0.0:
			ctx["flags"]["voyage_failed"] = true
		ctx["events"].append({
			"type": "ship.damaged",
			"payload": {"amount": amount, "durability": float(ship["durability"])},
		})
		return _ok()
	)
	register("repair_ship", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var state: GameState = ctx["state"]
		var ship := state.ship()
		var maximum := ShipOps.durability_max(ctx["hub"], ship)
		ship["durability"] = minf(maximum, float(ship.get("durability", 0.0)) + float(node.get("amount", 0.0)))
		return _ok()
	)
	register("damage_module", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var state: GameState = ctx["state"]
		var ship := state.ship()
		var slot := String(node.get("slot", ""))
		var amount := float(node.get("amount", 0.0))
		if amount <= 0.0:
			return _fail("invalid_amount")
		if not ShipModules.has_slot(ship, slot):
			return _fail("unknown_module_slot")
		var outcome: Dictionary = ShipModules.damage(ship, slot, int(node.get("index", 0)), amount)
		if not bool(outcome.get("ok", false)):
			return _fail(String(outcome.get("error", "invalid_amount")))
		ctx["events"].append({"type": "ship.module_damaged", "payload": outcome})
		return _ok()
	)
	register("add_delay_hours", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var hours := maxf(0.0, float(node.get("amount", 0.0)))
		var state: GameState = ctx["state"]
		var voyage: Variant = state.data.get("voyage", null)
		if voyage is Dictionary:
			voyage["delay_hours"] = float(voyage.get("delay_hours", 0.0)) + hours
			voyage["arrival_time"] = float(voyage.get("arrival_time", state.now())) + hours
		else:
			state.advance_time(hours)
		return _ok()
	)
	register("damage_cargo", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var state: GameState = ctx["state"]
		var removed := ShipOps.remove_non_contract_cargo_by_weight(ctx["hub"], state.ship(), float(node.get("amount", 0.0)))
		ctx["events"].append({"type": "cargo.damaged", "payload": {"weight": removed}})
		return _ok()
	)
	register("injure_passenger", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var amount := maxi(0, int(node.get("amount", 1)))
		var state: GameState = ctx["state"]
		var voyage: Variant = state.data.get("voyage", null)
		if voyage is Dictionary:
			voyage["injuries"] = int(voyage.get("injuries", 0)) + amount
		var main_contract: Variant = state.contracts().get("main", null)
		if main_contract is Dictionary:
			main_contract["injuries"] = int(main_contract.get("injuries", 0)) + amount
		ctx["events"].append({"type": "passenger.injured", "payload": {"amount": amount}})
		return _ok()
	)
	register("unlock_definition", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var target_id := String(node.get("id", ""))
		if not _definition_exists(ctx["hub"], target_id):
			return _fail("unknown_definition")
		var player: Dictionary = ctx["state"].player()
		var unlocks: Array = player.get("unlocks", [])
		if not unlocks.has(target_id):
			unlocks.append(target_id)
		player["unlocks"] = unlocks
		ctx["events"].append({"type": "content.unlocked", "payload": {"id": target_id}})
		return _ok()
	)
	register("complete_contract", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var contract_id := String(node.get("contract_id", ""))
		ctx["flags"]["complete_contract_id"] = contract_id
		return _ok()
	)
	register("fail_voyage", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		ctx["flags"]["voyage_failed"] = true
		return _ok()
	)
	register("reveal_port_facilities", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var port_id := String(node.get("port_id", ctx["state"].current_port_id()))
		var port_data := MapOps.port(ctx["state"].world(), port_id)
		if port_data.is_empty():
			return _fail("unknown_port")
		port_data["facilities_known"] = true
		return _ok()
	)
	register("update_intelligence", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var snapshot := IntelService.build_snapshot(ctx["state"], ctx["hub"], ctx["state"].now())
		IntelService.store(ctx["state"], snapshot)
		ctx["events"].append({"type": "intelligence.updated", "payload": {"generated_at": snapshot["generated_at"]}})
		return _ok()
	)
	register("emit_notice", func(node: Dictionary, ctx: Dictionary) -> Dictionary:
		var text_key := String(node.get("text_key", ""))
		if text_key.is_empty():
			return _fail("missing_text_key")
		ctx["state"].push_notice(text_key)
		ctx["notices"].append({"text_key": text_key})
		ctx["events"].append({"type": "notice.emitted", "payload": {"text_key": text_key}})
		return _ok()
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


static func _ok() -> Dictionary:
	return {"ok": true, "error_code": "", "message_key": ""}


static func _fail(error_code: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "message_key": "ui.error.%s" % error_code}


static func _add_supply(ctx: Dictionary, kind: String, node: Dictionary) -> Dictionary:
	var amount := float(node.get("amount", 0.0))
	if amount < 0.0:
		return _fail("invalid_amount")
	var state: GameState = ctx["state"]
	var ship := state.ship()
	var unit_weight := ShipOps.COAL_WEIGHT if kind == "coal" else ShipOps.WATER_WEIGHT
	if ShipOps.total_weight(ctx["hub"], state) + unit_weight * amount > ShipOps.max_weight(ctx["hub"], ship) + 0.0001:
		return _fail("weight_limit")
	ship[kind] = float(ship.get(kind, 0.0)) + amount
	return _ok()


static func _remove_supply(ctx: Dictionary, kind: String, node: Dictionary) -> Dictionary:
	var amount := float(node.get("amount", 0.0))
	if amount < 0.0:
		return _fail("invalid_amount")
	var ship: Dictionary = ctx["state"].ship()
	if float(ship.get(kind, 0.0)) < amount:
		return _fail("insufficient_%s" % kind)
	ship[kind] = float(ship.get(kind, 0.0)) - amount
	return _ok()


static func _definition_exists(hub: RegistryHub, target_id: String) -> bool:
	if target_id.is_empty():
		return false
	for content_type in ContentTypes.all():
		if hub.contains(content_type, target_id):
			return true
	return false


static func clear_runtime() -> void:
	_ops.clear()
	_initialized = false
