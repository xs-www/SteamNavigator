class_name PortCommands
extends RefCounted
## Port stay use case: spend time in port.
##
## Waiting advances game time, settles finished craft orders into their port
## warehouses, lets NPC traders move the market, checks overdue debt and pushes a
## notice. Everything runs inside the CommandBus transaction, so a rejected wait
## leaves state untouched.
##
## The travel-time path (VoyageService) also settles orders after advancing time;
## port.wait is the player-facing way to make time pass without sailing.

const MIN_WAIT_HOURS := 1
const MAX_WAIT_HOURS := 240
const WAIT_OPTIONS := [6, 12, 24]


static func wait(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var hours := int(params.get("hours", 0))
	if hours < MIN_WAIT_HOURS or hours > MAX_WAIT_HOURS:
		return Result.fail("invalid_hours", "ui.error.invalid_hours", {
			"hours": hours,
			"min": MIN_WAIT_HOURS,
			"max": MAX_WAIT_HOURS,
		})

	var position := state.current_port_id()
	state.advance_time(float(hours))
	var completed_orders := CraftOps.settle_orders(state, hub)
	var npc_events := NpcTraderSimulator.advance(
		state,
		hub,
		context.rng,
		state.now(),
		_profile_data(context)
	)
	var debt_events := DebtService.check_overdue(state)
	state.push_notice("ui.notice.waited", {
		"port": MapOps.port_display_key(state.world(), position),
		"hours": hours,
	})

	var events: Array = [{
		"type": "port.waited",
		"payload": {
			"port_id": position,
			"hours": hours,
			"game_time": state.now(),
		},
	}]
	for order in completed_orders:
		events.append({
			"type": "ship.module_crafted",
			"payload": {
				"order_id": String(order.get("order_id", "")),
				"module_id": String(order.get("module_id", "")),
				"content_type": String(order.get("content_type", "")),
				"port_id": String(order.get("port_id", "")),
				"warehouse_qty": int(order.get("warehouse_qty", 0)),
			},
		})
	events.append_array(npc_events)
	events.append_array(debt_events)

	return Result.ok({
		"hours": hours,
		"game_time": state.now(),
		"time_label": ClockService.format_time(state.now()),
		"completed_orders": completed_orders,
		"npc_events": npc_events,
		"debt_events": debt_events,
	}, events)


static func _profile_data(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}