class_name VoyageService
extends RefCounted
## @static-doc
## 作用：航行执行：校验预览、出发扣工资、抽取事件、事件选择、抵达结算（按实际航行
## 小时一次性扣煤水）与失败回滚。
##
## - 关键依赖：`VoyageCalculator`、`ShipOps`、`MapOps`、`ConditionEvaluator`、
##   `EffectExecutor`、`ContractOps`、`NpcTraderSimulator`、`DebtService`、`SaveService`、
##   `WorldOps` / `FogOps` / `ExplorationRules`（坐标世界与迷雾）
##
## ## 契约与约束
## - 出航前把当前状态存入 `context.pre_voyage_state` 和 `pre_voyage` 存档槽。
## - 风险事件概率对玩家隐藏；预览只暴露风险来源。事件最多提供 2 个加权抽样选项。
## - 耐久归零或 `fail_voyage` 效果会把工作副本替换回出航前快照，并发布 voyage.failed。
## - 抵达时统一推进时间、发现港口、结算打造订单（`CraftOps.settle_orders`，成品进
##   下单港仓库并写入 `summary.completed_orders`）、结算主线/普通委托、推进 NPC、
##   检查逾期、刷新普通委托池并自动存档。
## - 工资通过 `state.record_expense()` 计入统计支出；委托收入在 ContractOps 结算时计入收入。
## - 行动顺序固定：扣工资 → 生成 voyage（存出发库存与每小时煤水费率）→ 选事件 →
##   若无事件立即抵达结算。
## - 连续消耗（阶段 4.3.5 / U8）：出发**不扣**煤水，只扣工资；`voyage` 快照记录
##   `departure_coal` / `departure_water` 与 `coal_rate` / `water_rate`（每小时消耗 =
##   预览计划消耗 ÷ 计划时长）。`_complete_arrival` 按 `elapsed = arrival_time -
##   departure_time`（已含事件延误）一次性扣 `rate × elapsed`，演出期间顶栏只做插值
##   读数、不写领域状态。事件 payload 仍报计划消耗，语义不变。
## - 坐标世界（海图数据源）与抽象地图同步：`_complete_arrival` 记录访问并揭示泊位；
##   4.3.3 / U4 起在揭示前先 `_trace_voyage_fog` 沿实际航线把沿途迷雾落账（沿海
##   格子留 EXPLORED），旧存档没有 `world_map` 时这些调用全部 no-op。
## - 4.1 起每次抵达还调用 `ClueService.on_arrival` 抽传闻线索；空结果（没抽中 /
##   没有目标 / 上限已满）永不阻断或失败抵达。
##
## ## 重点逻辑
## ### `start(context, destination_id, strategy_id)`
## - 先调用 VoyageCalculator 生成可复现预览；feasible=false 时不修改状态。
## - 只扣工资后写入 `voyage` 快照（含出发煤水库存与每小时费率）；事件基础延误已计入
##   arrival_time。煤水的实际扣除发生在抵达结算，不在出发时。
## - 事件选项仅保存 ID；选择时重新从注册表读取效果，避免存档注入效果对象。
##
## ### `choose_option(context, option_id)`
## - 再次校验选项在本次抽样池中且条件成立，然后顺序执行效果。
## - effect flags.voyage_failed 为真时恢复出航前状态，返回 ok + failed，以便 UI 展示。
## - 成功后调用 `_complete_arrival()`；autosave 只在成功抵达后发生。
##
## ### `_complete_arrival(context)`
## - 先按 `rate × (arrival_time - departure_time)` 扣煤水（事件 `add_delay_hours`
##   会推后 arrival_time，因此延误小时也计费；钳位到 0），summary 附
##   `coal_used_actual` / `water_used_actual` 供 UI / 测试读取。
## - 以 arrival_time 推进游戏时间并标记目的港 visited/discovered。
## - `_trace_voyage_fog` 先从 `WorldMap.edges`（缺失时 `RouteCalculator` 的
##   `bezier_path`，再缺就两港直线）采样沿途迷雾，`_reveal_world_fog` 再揭示泊位。
## - 主线完成后 next_main_sequence+1，并生成下一段 main_offer；不自动接取。
## - 普通 active 委托中目的港匹配者一起结算；其余保留。
## - 调用 `ContractOps.refresh_normal_offers()` 整池刷新普通委托，summary.offers_refreshed=true。
## - NPC 市场推进、债务逾期、统计与通知都在此统一处理。
## @end-static-doc

const OPPORTUNITY_CHANCE := 0.12
const MAX_EVENT_DELAY_HOURS := 72.0


static func start(context, destination_id: String, strategy_id: String) -> Dictionary:
	var preview_result := VoyageCalculator.preview(context, destination_id, strategy_id)
	if not bool(preview_result["ok"]):
		return preview_result
	var preview: Dictionary = preview_result["data"]
	if not bool(preview.get("feasible", false)):
		return Result.fail("voyage_not_feasible", "ui.error.voyage_not_feasible", {"blockers": preview.get("blockers", [])})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var ship := state.ship()

	var retry_snapshot := state.clone()
	context.pre_voyage_state = retry_snapshot
	if context.autosave_enabled:
		context.save.save_pre_voyage(state, context.save_meta())

	var wages := int(preview.get("crew_wages", 0))
	if wages > 0:
		state.add_money(-wages)
		state.record_expense(wages)
	# 4.3.5 / U8：出发只扣工资。煤水库存原样留在船上，演出中顶栏按费率插值读数；
	# 实际扣款统一在 `_complete_arrival` 按实际航行小时一次性落账。
	var departure_coal := float(ship.get("coal", 0.0))
	var departure_water := float(ship.get("water", 0.0))
	var planned_hours := maxf(0.0, float(preview.get("duration_hours", 0.0)))
	var coal_rate := float(preview.get("coal_required", 0.0)) / planned_hours if planned_hours > 0.0 else 0.0
	var water_rate := float(preview.get("water_required", 0.0)) / planned_hours if planned_hours > 0.0 else 0.0

	var departure_time := state.now()
	var arrival_time := float(preview.get("arrival_time", departure_time))
	var voyage := {
		"origin": String(preview.get("origin_id", "")),
		"destination": destination_id,
		"strategy_id": strategy_id,
		"distance": float(preview.get("distance", 0.0)),
		"departure_time": departure_time,
		"base_duration": float(preview.get("duration_hours", 0.0)),
		"arrival_time": arrival_time,
		"delay_hours": 0.0,
		"injuries": 0,
		"event": null,
		"status": "at_sea",
		# 连续消耗（4.3.5）：出发库存与每小时煤水费率。结算时用
		# `rate × (arrival_time - departure_time)` 一次性扣款。
		"departure_coal": departure_coal,
		"departure_water": departure_water,
		"coal_rate": coal_rate,
		"water_rate": water_rate,
	}
	state.data["voyage"] = voyage

	var events: Array = [{
		"type": "voyage.started",
		"payload": {
			"origin": voyage["origin"],
			"destination": destination_id,
			"strategy_id": strategy_id,
			"duration_hours": voyage["base_duration"],
			"coal_used": preview.get("coal_required", 0.0),
			"water_used": preview.get("water_required", 0.0),
		},
	}]

	var event := _pick_event(context, preview, destination_id)
	if not event.is_empty():
		var base_delay := clampf(float(event.get("base_delay_hours", 0.0)), 0.0, MAX_EVENT_DELAY_HOURS)
		voyage["delay_hours"] = float(voyage["delay_hours"]) + base_delay
		voyage["arrival_time"] = float(voyage["arrival_time"]) + base_delay
		voyage["event"] = event
		events.append({
			"type": "voyage.event_triggered",
			"payload": {
				"event_id": event.get("event_id", ""),
				"category": event.get("category", ""),
				"option_ids": event.get("option_ids", []),
			},
		})
		return Result.ok({
			"preview": preview,
			"arrived": false,
			"event": event,
		}, events)

	var summary := _complete_arrival(context)
	events.append_array(summary.get("events", []))
	events.append({
		"type": "voyage.completed",
		"payload": {"destination": destination_id, "arrival_time": summary.get("arrival_time", 0.0)},
	})
	return _with_autosave(Result.ok({
		"preview": preview,
		"arrived": true,
		"summary": summary,
	}, events))


static func choose_option(context, option_id: String) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var voyage: Variant = state.data.get("voyage", null)
	if not (voyage is Dictionary):
		return Result.fail("not_at_sea", "ui.error.not_at_sea")
	var event_state: Variant = voyage.get("event", null)
	if not (event_state is Dictionary):
		return Result.fail("no_pending_event", "ui.error.no_pending_event")
	var event_id := String(event_state.get("event_id", ""))
	var template := hub.get_by_id(ContentTypes.EVENT, event_id)
	if template == null:
		return Result.fail("unknown_event", "ui.error.unknown_event", {"event_id": event_id})
	var option := _find_option(template, option_id)
	if option.is_empty():
		return Result.fail("unknown_option", "ui.error.unknown_option", {"option_id": option_id})
	var option_ids: Array = event_state.get("option_ids", [])
	if not option_ids.has(option_id):
		return Result.fail("option_not_offered", "ui.error.option_not_offered", {"option_id": option_id})

	var eval_context := _eval_context(context, String(voyage.get("destination", "")))
	var condition_result := ConditionEvaluator.evaluate(option.get("condition", null), eval_context)
	if not bool(condition_result["value"]):
		return Result.fail("option_unavailable", "ui.error.option_unavailable", {"error": condition_result.get("error", "")})

	var execution_context := {
		"state": state,
		"hub": hub,
		"game_time": state.now(),
		"flags": {},
		"notices": [],
		"events": [],
	}
	var effect_result := EffectExecutor.execute(option.get("effects", []), execution_context)
	if not bool(effect_result["ok"]):
		return effect_result
	var flags: Dictionary = execution_context["flags"]
	if bool(flags.get("voyage_failed", false)):
		if context.pre_voyage_state != null:
			state.replace_with(context.pre_voyage_state)
		var failure_events: Array = execution_context["events"]
		failure_events.append({
			"type": "voyage.failed",
			"payload": {
				"destination": voyage.get("destination", ""),
				"reason": option_id,
				"restored_pre_voyage": true,
			},
		})
		return Result.ok({
			"failed": true,
			"reason": option_id,
			"restored": true,
			"notices": execution_context["notices"],
		}, failure_events)

	event_state["chosen"] = option_id
	var summary := _complete_arrival(context)
	summary["chosen_option"] = option_id
	summary["effect_notices"] = execution_context["notices"]
	var events: Array = execution_context["events"]
	events.append_array(summary.get("events", []))
	events.append({
		"type": "voyage.completed",
		"payload": {
			"destination": voyage.get("destination", ""),
			"arrival_time": summary.get("arrival_time", 0.0),
			"chosen_option": option_id,
		},
	})
	return _with_autosave(Result.ok({"failed": false, "event_result": summary}, events))


## Reveals the destination berth's fog in the coordinate-space twin world.
## No-op when the run predates the chart integration (no `world_map`). Radii
## come from the content fog ratios so every world size keeps the same look.
static func _reveal_world_fog(state: GameState, destination: String, hub: RegistryHub) -> void:
	var world := WorldOps.world_map(state)
	if world.ports.is_empty():
		return
	var port := world.get_port(destination)
	if port.is_empty():
		return
	FogOps.reveal_arrival(state, world, port, ExplorationRules.fog_radii(state, hub, world))


## Persists the fog met along a normal voyage (4.3.3 / U4): read the actual route
## polyline between `voyage.origin` and `voyage.destination` from the coordinate
## world's route table and sample it through `FogOps.trace_route` before the berth
## reveal. Legacy worlds (no `world_map`) and voyages without a route are no-ops.
static func _trace_voyage_fog(state: GameState, voyage: Dictionary, hub: RegistryHub) -> void:
	var world := WorldOps.world_map(state)
	if world.is_empty():
		return
	var origin := world.get_port(String(voyage.get("origin", "")))
	var destination := world.get_port(String(voyage.get("destination", "")))
	if origin.is_empty() or destination.is_empty():
		return
	FogOps.trace_route(
		state,
		world,
		_route_path_between(world, origin, destination),
		ExplorationRules.fog_radii(state, hub, world)
	)


## Worldwide route polyline between two harbours. The stored table uses `path`, the
## on-the-fly `RouteCalculator` fallback uses `bezier_path`; a world with no edge for
## the pair (legacy save / disconnected) falls back to the two-port straight line.
static func _route_path_between(
	world: WorldMap, from_port: WorldPort, to_port: WorldPort
) -> PackedVector2Array:
	var route := WorldOps.route_between(world, from_port, to_port)
	for key in ["path", "bezier_path"]:
		var raw: Variant = route.get(key, null)
		if raw is PackedVector2Array and (raw as PackedVector2Array).size() >= 2:
			return raw
		if raw is Array and not (raw as Array).is_empty():
			return VoyagePresentation.unpack_path(raw as Array)
	return PackedVector2Array([from_port.position, to_port.position])


static func _complete_arrival(context) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var voyage: Dictionary = state.data.get("voyage", {})
	var destination := String(voyage.get("destination", ""))
	var arrival_time := maxf(state.now(), float(voyage.get("arrival_time", state.now())))
	state.set_now(arrival_time)
	state.world()["current_port_id"] = destination
	WorldOps.set_current_port(state, destination)
	var was_discovered := MapOps.is_discovered(state, destination)
	MapOps.discover(state, destination, true)
	var newly_discovered := not was_discovered
	# Keep the coordinate-space twin world (nautical chart) in step with the
	# played map: record the visit in the campaign partition, persist the fog met
	# along the actual route, then reveal the berth. Without `world_map` (legacy
	# saves) all three calls are no-ops.
	WorldOps.mark_visited(state, destination)
	_trace_voyage_fog(state, voyage, hub)
	_reveal_world_fog(state, destination, hub)

	# 4.3.5 / U8：整段航程的煤水按实际航行小时一次性落账。出发时没有扣过煤水，
	# 这里是唯一的扣款点；事件延误 / 事件效果都会推后 `arrival_time`，因此一并计费。
	var departure_time := float(voyage.get("departure_time", arrival_time))
	var elapsed_hours := maxf(0.0, arrival_time - departure_time)
	var ship := state.ship()
	var coal_used_actual := maxf(0.0, float(voyage.get("coal_rate", 0.0)) * elapsed_hours)
	var water_used_actual := maxf(0.0, float(voyage.get("water_rate", 0.0)) * elapsed_hours)
	ship["coal"] = maxf(0.0, float(ship.get("coal", 0.0)) - coal_used_actual)
	ship["water"] = maxf(0.0, float(ship.get("water", 0.0)) - water_used_actual)

	# Craft orders that finished while the ship was under way are delivered to
	# their owning port warehouse on arrival (the ship may be elsewhere).
	var services := settle_arrival_services(context, destination, arrival_time, voyage)
	var completed_orders: Array = services.get("completed_orders", [])
	var contract_results: Array = services.get("contract_results", [])
	var npc_events: Array = services.get("npc_events", [])
	var debt_events: Array = services.get("debt_events", [])
	var injuries := int(voyage.get("injuries", 0))
	var stats := record_arrival_stats(state, contract_results, injuries)

	state.data["voyage"] = null
	context.pre_voyage_state = null
	if newly_discovered:
		state.push_notice("ui.notice.discovered_port", {"port": MapOps.port_display_key(state.world(), destination)})
	state.push_notice("ui.notice.arrived", {"port": MapOps.port_display_key(state.world(), destination)})

	# Stage 4.1: every arrival can produce a tavern rumour from the named exploration
	# stream. This never blocks or fails the arrival — an empty result just means no clue.
	var clue_result := ClueService.on_arrival(context)

	var events: Array = []
	if newly_discovered:
		events.append({"type": "port.discovered", "payload": {"port_id": destination}})
	events.append({"type": "port.arrived", "payload": {"port_id": destination, "arrival_time": arrival_time}})
	events.append_array(services.get("events", []))
	events.append_array(clue_result.get("events", []))

	var summary := {
		"destination": destination,
		"arrival_time": arrival_time,
		"delayed_hours": float(voyage.get("delay_hours", 0.0)),
		"injuries": injuries,
		"contracts": contract_results,
		"market_events": npc_events,
		"debt_events": debt_events,
		"completed_orders": completed_orders,
		"offers_refreshed": true,
		"stats": stats.duplicate(true),
		# 4.3.5 / U8：实际落账的煤水（= 每小时费率 × 实际航行小时，含事件延误）。
		"coal_used_actual": coal_used_actual,
		"water_used_actual": water_used_actual,
		"events": events,
	}
	return summary


## The arrival-side services every harbour entry runs, independent of how the ship got
## there (normal voyage, exploration discovery, failure drift, turn-back). It handles the
## systems that react to "the ship is in port now": craft orders, contract completion,
## NPC market advance, market memory, overdue debt and the normal-offer pool. It does NOT
## touch the current port / fog / notices / save flags — callers own those.
##
## `voyage` supplies `delay_hours` / `injuries` for contract and stat bookkeeping; an
## exploration voyage passes a synthetic dictionary with zeros.
static func settle_arrival_services(
	context, destination: String, arrival_time: float, voyage: Dictionary
) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var completed_orders := CraftOps.settle_orders(state, hub)

	var contract_results: Array = []
	var contracts: Dictionary = state.data.get("contracts", {})
	var main_contract: Variant = contracts.get("main", null)
	if main_contract is Dictionary and String(main_contract.get("destination", "")) == destination:
		var completed := ContractOps.complete(state, hub, main_contract, arrival_time)
		contract_results.append(completed)
		contracts["completed"] = state.contracts().get("completed", [])
		contracts["main"] = null
		var next_sequence := int(main_contract.get("sequence", 0)) + 1
		contracts["next_main_sequence"] = next_sequence
		_generate_next_main_offer(context, next_sequence)

	var remaining_active: Array = []
	for contract in contracts.get("active", []):
		if contract is Dictionary and String(contract.get("destination", "")) == destination:
			contract_results.append(ContractOps.complete(state, hub, contract, arrival_time))
		else:
			remaining_active.append(contract)
	contracts["active"] = remaining_active

	var npc_events := NpcTraderSimulator.advance(
		state,
		hub,
		context.rng,
		arrival_time,
		_profile_data(context)
	)
	MarketMemoryService.remember(state, destination)
	var debt_events := DebtService.check_overdue(state)

	# Arrival refreshes the whole normal-offer pool. This never fails the
	# arrival: an empty template set simply clears the pool.
	var refreshed_offers := ContractOps.refresh_normal_offers(state, hub, context.rng, destination, arrival_time)

	var events: Array = []
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
	for contract_result in contract_results:
		events.append({"type": "contract.completed", "payload": contract_result})
		if not bool(contract_result.get("on_time", true)):
			events.append({"type": "contract.late", "payload": contract_result})
	events.append_array(npc_events)
	events.append_array(debt_events)
	events.append({
		"type": "contract.offers_refreshed",
		"payload": {
			"port_id": destination,
			"count": refreshed_offers.size(),
			"game_time": arrival_time,
		},
	})
	return {
		"completed_orders": completed_orders,
		"contract_results": contract_results,
		"npc_events": npc_events,
		"debt_events": debt_events,
		"refreshed_offers": refreshed_offers,
		"events": events,
	}


## Records one arrival in the run stats. Callers decide whether an exploration leg
## counts as a voyage (it always does, but normal arrival also tracks injuries).
static func record_arrival_stats(
	state: GameState, contract_results: Array, injuries: int = 0
) -> Dictionary:
	var stats: Dictionary = state.stats()
	stats["voyages"] = int(stats.get("voyages", 0)) + 1
	if not contract_results.is_empty():
		var any_on_time := false
		for result in contract_results:
			if bool(result.get("on_time", false)):
				any_on_time = true
		if any_on_time:
			stats["on_time"] = int(stats.get("on_time", 0)) + 1
	if injuries > 0:
		stats["accidents"] = int(stats.get("accidents", 0)) + 1
	return stats


static func _generate_next_main_offer(context, sequence: int) -> void:
	if sequence > 5:
		return
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var template := ContractOps.find_template_by_sequence(hub, sequence)
	if template == null:
		return
	var offer := ContractOps.generate_offer(state, hub, template, context.rng, state.current_port_id())
	if offer.is_empty():
		state.push_notice("ui.notice.no_contract_offer", {"sequence": sequence})
		return
	state.data["contracts"]["main_offer"] = offer


static func _pick_event(context, preview: Dictionary, destination_id: String) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var origin := state.current_port_id()
	var departure := state.now()
	var risk_rng: RandomNumberGenerator = context.rng.stream(RngService.STREAM_VOYAGE_RISK, "%s:%s:%.3f" % [origin, destination_id, departure])
	var trigger := ""
	if risk_rng.randf() < VoyageCalculator.event_chance(float(preview.get("risk_score", 0.0))):
		trigger = "voyage_risk"
	else:
		var opportunity_rng: RandomNumberGenerator = context.rng.stream(RngService.STREAM_VOYAGE_EVENT, "opportunity:%s:%.3f" % [origin, departure])
		if opportunity_rng.randf() < OPPORTUNITY_CHANCE:
			trigger = "voyage_opportunity"
	if trigger.is_empty():
		return {}
	var candidates: Array = []
	for definition in hub.get_all(ContentTypes.EVENT):
		if String(definition.data.get("trigger", "")) != trigger:
			continue
		var condition_result := ConditionEvaluator.evaluate(
			definition.data.get("condition", null),
			_eval_context(context, destination_id)
		)
		if bool(condition_result["value"]):
			candidates.append({"definition": definition, "weight": float(definition.data.get("weight", 1.0))})
	if candidates.is_empty():
		return {}
	var event_rng: RandomNumberGenerator = context.rng.stream(RngService.STREAM_VOYAGE_EVENT, "%s:%s" % [trigger, destination_id])
	var picked: Variant = RngService.choose_weighted(event_rng, candidates)
	if not (picked is Dictionary):
		return {}
	var definition: ContentDefinition = picked["definition"]
	var option_candidates: Array = []
	for option in definition.data.get("options", []):
		if not (option is Dictionary):
			continue
		var condition_result := ConditionEvaluator.evaluate(
			option.get("condition", null),
			_eval_context(context, destination_id)
		)
		if bool(condition_result["value"]):
			option_candidates.append(option)
	if option_candidates.is_empty():
		return {}
	var options_rng: RandomNumberGenerator = context.rng.stream(RngService.STREAM_EVENT_OPTIONS, definition.id)
	var chosen_options := _weighted_sample(options_rng, option_candidates, mini(2, option_candidates.size()))
	var option_ids: Array = []
	var view_options: Array = []
	for option in chosen_options:
		option_ids.append(String(option.get("id", "")))
		view_options.append({
			"id": String(option.get("id", "")),
			"name_key": String(option.get("name_key", "")),
		})
	return {
		"event_id": definition.id,
		"name_key": definition.name_key,
		"description_key": definition.description_key,
		"category": String(definition.data.get("category", "")),
		"base_delay_hours": float(definition.data.get("base_delay_hours", 0.0)),
		"option_ids": option_ids,
		"options": view_options,
		"chosen": null,
	}


static func _find_option(template: ContentDefinition, option_id: String) -> Dictionary:
	for option in template.data.get("options", []):
		if option is Dictionary and String(option.get("id", "")) == option_id:
			return option
	return {}


static func _weighted_sample(rng: RandomNumberGenerator, options: Array, count: int) -> Array:
	var pool := options.duplicate()
	var result: Array = []
	while result.size() < count and not pool.is_empty():
		var total := 0.0
		for option in pool:
			total += maxf(0.0, float(option.get("weight", 1.0)))
		if total <= 0.0:
			break
		var roll := rng.randf() * total
		var picked_index := 0
		for index in pool.size():
			roll -= maxf(0.0, float(pool[index].get("weight", 1.0)))
			if roll <= 0.0:
				picked_index = index
				break
		result.append(pool[picked_index])
		pool.remove_at(picked_index)
	return result


static func _eval_context(context, target_port_id: String) -> Dictionary:
	return {
		"state": context.state,
		"hub": context.registries,
		"current_port_id": context.state.current_port_id(),
		"target_port_id": target_port_id,
	}


static func _profile_data(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}


static func _with_autosave(result: Dictionary) -> Dictionary:
	result["autosave"] = true
	return result
