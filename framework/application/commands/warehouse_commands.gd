class_name WarehouseCommands
extends RefCounted
## Port warehouse transfers: modules between transit and the current port, and
## materials between non-contract cargo and the current port warehouse.
##
## All handlers run inside the CommandBus transaction; WarehouseOps supplies the
## result-envelope validation so command and domain share one rule set.

static func store_module(params: Dictionary, context) -> Dictionary:
	var guard := _port_guard(context)
	if not bool(guard.get("ok", false)):
		return guard
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var module_id := String(params.get("module_id", ""))
	if module_id.is_empty():
		return Result.fail("missing_module", "ui.error.missing_module")
	var qty := int(params.get("qty", 1))
	var result := WarehouseOps.store_module(state, hub, state.current_port_id(), module_id, qty)
	if bool(result.get("ok", false)):
		result["events"] = [{
			"type": "warehouse.module_stored",
			"payload": result.get("data", {}).duplicate(true),
		}]
	return result


static func take_module(params: Dictionary, context) -> Dictionary:
	var guard := _port_guard(context)
	if not bool(guard.get("ok", false)):
		return guard
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var module_id := String(params.get("module_id", ""))
	if module_id.is_empty():
		return Result.fail("missing_module", "ui.error.missing_module")
	var qty := int(params.get("qty", 1))
	var result := WarehouseOps.take_module(state, hub, state.current_port_id(), module_id, qty)
	if bool(result.get("ok", false)):
		result["events"] = [{
			"type": "warehouse.module_taken",
			"payload": result.get("data", {}).duplicate(true),
		}]
	return result


static func store_materials(params: Dictionary, context) -> Dictionary:
	var guard := _port_guard(context)
	if not bool(guard.get("ok", false)):
		return guard
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var item_id := String(params.get("item_id", ""))
	if item_id.is_empty():
		return Result.fail("unknown_item", "ui.error.unknown_item", {"item_id": item_id})
	var amount := int(params.get("amount", 0))
	var result := WarehouseOps.store_materials(state, hub, state.current_port_id(), item_id, amount)
	if bool(result.get("ok", false)):
		result["events"] = [{
			"type": "warehouse.materials_stored",
			"payload": result.get("data", {}).duplicate(true),
		}]
	return result


static func take_materials(params: Dictionary, context) -> Dictionary:
	var guard := _port_guard(context)
	if not bool(guard.get("ok", false)):
		return guard
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var item_id := String(params.get("item_id", ""))
	if item_id.is_empty():
		return Result.fail("unknown_item", "ui.error.unknown_item", {"item_id": item_id})
	var amount := int(params.get("amount", 0))
	var result := WarehouseOps.take_materials(state, hub, state.current_port_id(), item_id, amount)
	if bool(result.get("ok", false)):
		result["events"] = [{
			"type": "warehouse.materials_taken",
			"payload": result.get("data", {}).duplicate(true),
		}]
	return result


## Warehouse access is only meaningful while docked (any shipyard or non-shipyard
## port has a warehouse; the UI exposes it through the shipyard page).
static func _port_guard(context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if not context.state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	return Result.ok()
