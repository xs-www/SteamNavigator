class_name PortCommands
extends RefCounted
## Port stay use case: spend time in port.
##
## Waiting advances game time, settles finished craft orders into their port
## warehouses, lets NPC traders move the market, checks overdue debt and pushes a
## notice. Everything runs inside the CommandBus transaction, so a rejected wait
## leaves state untouched.
##
## Stage 4.4: a wait also rolls the content-driven "dockside word" clue chance
## (`ClueService.on_wait`, per-block compounding, capped) and sweeps timed-out
## goods clues; `clue.acquired` / `clue.expired` events ride on the wait result.
##
## The travel-time path (VoyageService) also settles orders after advancing time;
## port.wait is the player-facing way to make time pass without sailing.

const MIN_WAIT_HOURS := 1
const MAX_WAIT_HOURS := 240
const WAIT_OPTIONS := [6, 12, 24]


static func wait(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
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
	# 4.4.3：时间推进 / 打造订单 / NPC 市场 / 逾期债务统一走 PortTimeService，
	# 与「调查线索」的在港工时消耗共用同一套规则。
	var spent := PortTimeService.spend(context, float(hours))
	# 4.4：等待推进时间后清理到期线索（释放 max_active_clues 名额）。
	var expired_ids := ClueService.sweep_expired(state)
	var completed_orders: Array = spent.get("completed_orders", [])
	var npc_events: Array = spent.get("npc_events", [])
	var debt_events: Array = spent.get("debt_events", [])
	state.push_notice("ui.notice.waited", {
		"port": MapOps.port_display_key(state.world(), position),
		"hours": hours,
	})
	# 4.4.2：在港等待可能换来一条线索（概率按档位复利，来自 Core）。
	var clue_result := ClueService.on_wait(context, hours)
	var clue: Dictionary = clue_result.get("clue", {})
	var clue_view: Dictionary = {}
	if not clue.is_empty():
		clue_view = ClueService.view_entry(state, clue)

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
	events.append_array(ClueService.expired_events_of(expired_ids))
	events.append_array(clue_result.get("events", []))

	return Result.ok({
		"hours": hours,
		"game_time": state.now(),
		"time_label": ClockService.format_time(state.now()),
		"completed_orders": completed_orders,
		"npc_events": npc_events,
		"debt_events": debt_events,
		"clue": clue_view,
	}, events)