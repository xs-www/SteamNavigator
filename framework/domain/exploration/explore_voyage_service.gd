class_name ExploreVoyageService
extends RefCounted
## @static-doc
## 作用：探索航次的领域执行——出航（只扣工资、记录出发库存与每小时煤水费率、写探索
## 航次与在航标记、抽定发现 roll）、资源告急决策（继续 / 掉头）、抵达结算（发现港口 +
## 迷雾揭示 / 失败漂流 + 线索保留，按实际航行小时一次性扣煤水）。
##
## - 关键依赖：`ClueService`、`ExplorationCalculator`、`ExplorationRules`、`WorldOps`、
##   `FogOps`、`MapOps`、`ShipOps`、`RngService.STREAM_EXPLORATION`
##
## ## 契约与约束
## - 探索期间 `data.voyage = {"kind": "explore", "status": "at_sea"}`，既有
##   `is_at_port()` / `port.view.at_sea` / 贸易门禁自动生效；`settle` 与掉头都会同时清空
##   `data.explore_voyage` 与 `data.voyage`。
## - `start` 在任何扣费之前先跑完整预览：不可行直接失败，**不得扣资源**。
## - 连续消耗（阶段 4.3.5 / U8）：出发**只扣工资**，煤水库存原样留在船上；航次记录
##   `departure_coal` / `departure_water` 与 `coal_rate` / `water_rate`
##   （= 计划消耗 ÷ 计划时长），`presentation` 也带这四个字段供 Shell 插值读数。
##   实际扣款只在结算时按实际航行小时一次性发生：
##   成功 `elapsed = arrival - departure`；失败 `duration + drift_hours`；掉头
##   `duration × 0.5`。漂流 / 掉头的额外损耗（`drift_extra_*` / 计划消耗 × 比例）
##   在小时扣款之后再扣，钳位到剩余库存；`summary.explore.extra_coal/water`
##   仍只表示这笔额外损耗。
## - 发现结果在出发时用命名流 `explore:<clue_id>:<departure>` 抽定（`outcome_roll`），
##   结算只比较 `outcome_roll < discovery_chance`，同 seed 同状态可复现。
## - 成功：坐标世界 `discover_port_id` + `mark_visited` + `FogOps.reveal_arrival`，抽象地图
##   同步发现 / 访问（贸易、市场、海图都读它），线索 resolved，进入目标港。
## - 失败（4.3 / U3）：线索**保留在 active**（只累加 `attempts` / `last_attempt_at`，
##   可再次 `start`），漂到**距搜索区最近的已发现港**并按其入港处理（记录访问 +
##   揭示泊位），耐久 / 煤 / 水按规则扣减且不为负，时间加 `drift_hours`。结算摘要
##   的 `explore.attempts` 报告累计尝试次数，`settlement_screen` 据此显示「线索保留」。
## - 掉头：先按每小时费率扣实际半程（`duration × 0.5`），再额外消耗
##   `coal_used/water_used * turnback_extra_ratio`（钳位到剩余库存），时间前进半个航程，
##   回出发港，线索保持 active。
## - 迷雾沿途落账（4.3.3 / U4）：成功与失败漂流都在 `reveal_arrival` 之前对
##   `voyage.route_path` 调用 `FogOps.trace_route`，把实际航线的沿海格子留成
##   EXPLORED；掉头只采样去程前半段（`end_progress = 0.5`）。旧存档没有坐标世界时
##   `trace_route` 自行 no-op。
## - 结算 `summary.explore` 与 `settlement_screen` 现有字段兼容；领域事件
##   `explore.started` / `explore.finished` 随结果返回，由命令总线发布。
## - 4.4：`start` 入口先 `ClueService.sweep_expired` 清理到期线索并把 `clue.expired`
##   事件并入返回；过期线索不能再出航（`clue_expired`），避免 `port_goods` 线索被
##   误当成探索目标。
## @end-static-doc


static func start(context, clue_id: String, strategy_id: String) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if state.explore_voyage() is Dictionary:
		return Result.fail("already_exploring", "ui.error.already_exploring")
	# 4.4：推进时间之前的时间点没有别的命令入口时也要清理过期线索（释放名额）。
	var expired_ids := ClueService.sweep_expired(state)
	var expired_events: Array = ClueService.expired_events_of(expired_ids)
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port", {}, expired_events)
	var clue := ClueService.find_clue(state, clue_id)
	if clue.is_empty():
		var clues_data := state.ensure_clues()
		var inactive := Array(clues_data.get("failed", [])).has(clue_id) \
			or Array(clues_data.get("resolved", [])).has(clue_id)
		var code := "clue_not_active" if inactive else "unknown_clue"
		var message_key := "ui.error.clue_not_active" if inactive else "ui.error.unknown_clue"
		return Result.fail(code, message_key, {"clue_id": clue_id}, expired_events)
	if ClueService.is_expired(clue, state.now()):
		return Result.fail(
			"clue_expired", "ui.error.clue_expired", {"clue_id": clue_id}, expired_events
		)
	var preview_result := ExplorationCalculator.preview(context, clue_id, strategy_id)
	if not bool(preview_result.get("ok", false)):
		return preview_result
	var preview: Dictionary = preview_result.get("data", {})
	if not bool(preview.get("feasible", false)):
		var blockers: Array = preview.get("blockers", [])
		var message_key := "ui.error.voyage_not_feasible"
		if not blockers.is_empty() and blockers[0] is Dictionary:
			message_key = String((blockers[0] as Dictionary).get("message_key", message_key))
		return Result.fail("explore_not_feasible", message_key, {"blockers": blockers})

	var rules := ExplorationRules.read(state, context.registries)
	var ship := state.ship()
	var wages := int(preview.get("crew_wages", 0))
	if wages > 0:
		state.add_money(-wages)
		state.record_expense(wages)
	var coal_used := float(preview.get("coal_required", 0.0))
	var water_used := float(preview.get("water_required", 0.0))
	var coal_before := float(ship.get("coal", 0.0))
	var water_before := float(ship.get("water", 0.0))
	# 4.3.5 / U8：出发只扣工资，煤水原样留在船上；这里的计划消耗只用于告警预判、
	# 掉头额外比例与演出插值，真实扣款在结算时按实际航行小时一次性发生。
	var planned_hours := maxf(0.0, float(preview.get("duration_hours", 0.0)))
	var coal_rate := coal_used / planned_hours if planned_hours > 0.0 else 0.0
	var water_rate := water_used / planned_hours if planned_hours > 0.0 else 0.0

	var threshold := float(rules.get("alert_threshold", 0.5))
	# A zero starting stock must not count as "already half consumed".
	var alert_needed := (coal_before > 0.0 and coal_used >= coal_before * threshold) \
		or (water_before > 0.0 and water_used >= water_before * threshold)

	var departure_time := state.now()
	var duration := float(preview.get("duration_hours", 0.0))
	var arrival_time := departure_time + duration
	var outcome_rng: RandomNumberGenerator = context.rng.stream(
		RngService.STREAM_EXPLORATION,
		"explore:%s:%.3f" % [clue_id, departure_time]
	)
	var outcome_roll := outcome_rng.randf()
	var zone: Dictionary = preview.get("zone", {})
	var voyage := {
		"clue_id": clue_id,
		"target_port_id": String(clue.get("target_port_id", "")),
		"origin": String(preview.get("origin_id", state.current_port_id())),
		"strategy_id": String(preview.get("strategy_id", strategy_id)),
		"zone": {
			"x": float(zone.get("x", 0.0)),
			"y": float(zone.get("y", 0.0)),
			"radius": float(zone.get("radius", 0.0)),
		},
		"route_path": Array(preview.get("route_path", [])),
		"distance": float(preview.get("distance", 0.0)),
		"duration_hours": duration,
		"departure_time": departure_time,
		"arrival_time": arrival_time,
		"coal_used": coal_used,
		"water_used": water_used,
		# 连续消耗（4.3.5 / U8）：出发库存与每小时费率；结算按实际小时扣款。
		"departure_coal": coal_before,
		"departure_water": water_before,
		"coal_rate": coal_rate,
		"water_rate": water_rate,
		"wages": wages,
		"alert_needed": alert_needed,
		# 决策点在航程中的比例（来自 Core JSON 的 `alert_progress`，默认 0.5）。
		# `alert_progress` 同时充当「已处理」标记：continue 后置 1.0（见 `decide`）。
		"alert_progress": float(rules.get("alert_progress", 0.5)),
		"alert_decided": "",
		"outcome_roll": outcome_roll,
		"status": "outbound",
	}
	state.set_explore_voyage(voyage)
	state.data["voyage"] = {"kind": "explore", "status": "at_sea"}

	var events: Array = expired_events.duplicate()
	events.append({
		"type": "explore.started",
		"payload": {
			"clue_id": clue_id,
			"origin": String(voyage["origin"]),
			"duration_hours": duration,
			"coal_used": coal_used,
			"water_used": water_used,
		},
	})
	var presentation := {
		"kind": "explore",
		"origin": String(voyage["origin"]),
		"clue_id": clue_id,
		"zone": (voyage["zone"] as Dictionary).duplicate(true),
		"route_path": Array(voyage["route_path"]).duplicate(),
		"total_hours": duration,
		"strategy_id": String(voyage["strategy_id"]),
		"departure_time": departure_time,
		"arrival_time": arrival_time,
		# 4.3.5 / U8：Shell 用这四个字段在演出中插值顶栏读数（不写领域状态）。
		"departure_coal": coal_before,
		"departure_water": water_before,
		"coal_rate": coal_rate,
		"water_rate": water_rate,
		"alert_needed": alert_needed,
		"alert_progress": float(voyage["alert_progress"]),
	}
	return Result.ok({"preview": preview, "presentation": presentation}, events)


## 4.2 resource-alert decision. `continue` merely acknowledges the alert; `turn_back`
## immediately settles a half-voyage return to the origin harbour (clue stays active).
## Answering `continue` twice is rejected instead of silently re-acknowledging; turning
## back is also usable as an explicit abort (it clears `explore_voyage`, so a second call
## fails with `not_exploring`).
static func decide(context, choice: String) -> Dictionary:
	var state: GameState = context.state
	var voyage_value: Variant = state.explore_voyage()
	if not (voyage_value is Dictionary):
		return Result.fail("not_exploring", "ui.error.not_exploring")
	var voyage: Dictionary = voyage_value
	match choice:
		"continue":
			if not String(voyage.get("alert_decided", "")).is_empty():
				return Result.fail("alert_already_decided", "ui.error.alert_already_decided")
			var at := float(voyage.get("alert_progress", 0.5))
			var remaining := maxf(0.0, float(voyage.get("duration_hours", 0.0)) * (1.0 - at))
			voyage["alert_decided"] = "continue"
			voyage["alert_progress"] = 1.0
			return Result.ok({
				"continued": true,
				"destination": String(voyage.get("target_port_id", "")),
				"remaining_hours": remaining,
			})
		"turn_back":
			return _turn_back(context, voyage)
		_:
			return Result.fail("unknown_choice", "ui.error.unknown_option", {"choice": choice})


static func _turn_back(context, voyage: Dictionary) -> Dictionary:
	var state: GameState = context.state
	var rules := ExplorationRules.read(state, context.registries)
	var ship := state.ship()
	var duration := float(voyage.get("duration_hours", 0.0))
	# 4.3.5 / U8：掉了头只实际走了半程——先按费率扣这半程，再扣掉头额外比例
	# （额外那笔钳位到小时扣款后的剩余库存）。
	_consume_hourly(state, voyage, duration * 0.5)
	var ratio := float(rules.get("turnback_extra_ratio", 0.25))
	var extra_coal := maxf(0.0, float(voyage.get("coal_used", 0.0)) * ratio)
	var extra_water := maxf(0.0, float(voyage.get("water_used", 0.0)) * ratio)
	var coal_deducted := minf(extra_coal, float(ship.get("coal", 0.0)))
	var water_deducted := minf(extra_water, float(ship.get("water", 0.0)))
	ship["coal"] = maxf(0.0, float(ship.get("coal", 0.0)) - extra_coal)
	ship["water"] = maxf(0.0, float(ship.get("water", 0.0)) - extra_water)

	var departure_time := float(voyage.get("departure_time", state.now()))
	var arrival_time := maxf(state.now(), departure_time + duration * 0.5)
	state.set_now(arrival_time)
	var world := WorldOps.world_map(state)
	# 掉头只走了去程的前半段：按 `end_progress = 0.5` 落账沿途迷雾（再入港前）。
	FogOps.trace_route(
		state,
		world,
		_route_polyline(voyage.get("route_path", [])),
		ExplorationRules.fog_radii(state, context.registries, world),
		0.5
	)
	var origin := String(voyage.get("origin", state.current_port_id()))
	_enter_port(state, origin, true)

	var port_name_key := WorldOps.port_display_key(world, origin)
	var clue_id := String(voyage.get("clue_id", ""))
	var zone: Dictionary = voyage.get("zone", {})
	state.push_notice("ui.notice.exploration_turned_back", {"port": port_name_key})
	state.set_explore_voyage(null)
	state.data["voyage"] = null

	# 掉头也是一次真实的入港：到港服务（打造订单 / 委托 / NPC / 市场记忆 / 债务 /
	# 委托刷新）与普通抵达一致地跑一遍，只是没有发现新港口。
	var services := VoyageService.settle_arrival_services(context, origin, arrival_time, {
		"destination": origin,
		"arrival_time": arrival_time,
		"delay_hours": 0.0,
		"injuries": 0,
	})
	VoyageService.record_arrival_stats(state, services.get("contract_results", []), 0)

	var events: Array = []
	events.append_array(services.get("events", []))
	events.append({
		"type": "explore.finished",
		"payload": {
			"result": "turned_back",
			"destination": origin,
			"clue_id": clue_id,
			"arrival_time": arrival_time,
		},
	})
	var summary := _summary(
		state,
		"turned_back",
		origin,
		port_name_key,
		clue_id,
		zone,
		coal_deducted,
		water_deducted,
		0.0,
		0.0,
		0,
		events,
		services
	)
	var result := Result.ok({"returned": true, "destination": origin, "summary": summary}, events)
	result["autosave"] = true
	return result


## Resolves the exploration voyage. `outcome_roll` was drawn at departure; here it is only
## compared to the rule-derived discovery chance.
static func settle(context) -> Dictionary:
	var state: GameState = context.state
	var voyage_value: Variant = state.explore_voyage()
	if not (voyage_value is Dictionary):
		return Result.fail("not_exploring", "ui.error.not_exploring")
	var voyage: Dictionary = voyage_value
	var hub: RegistryHub = context.registries
	var rules := ExplorationRules.read(state, hub)
	var clue_id := String(voyage.get("clue_id", ""))
	var target_id := String(voyage.get("target_port_id", ""))
	var origin := String(voyage.get("origin", state.current_port_id()))
	var zone: Dictionary = voyage.get("zone", {})
	var center := {
		"x": float(zone.get("x", 0.0)),
		"y": float(zone.get("y", 0.0)),
	}
	var clue := ClueService.find_clue(state, clue_id)
	var credibility := float(clue.get("credibility", 0.0)) if not clue.is_empty() else 0.0
	var chance := ExplorationRules.discovery_chance(rules, credibility)
	var success := target_id != "" and float(voyage.get("outcome_roll", 1.0)) < chance
	var world := WorldOps.world_map(state)
	var fog_radii := ExplorationRules.fog_radii(state, hub, world)
	# 实际航线是出发时算好、存进 explore_voyage 的扁平数组；沿途迷雾在抵达/漂流前
	# 一次性落账（4.3.3 / U4），港口路灯花仍由下面的 `reveal_arrival` 负责。
	var route_path := _route_polyline(voyage.get("route_path", []))

	var arrival_time := maxf(float(voyage.get("arrival_time", state.now())), state.now())
	state.set_now(arrival_time)
	var departure_time := float(voyage.get("departure_time", arrival_time))
	var duration := float(voyage.get("duration_hours", 0.0))

	var result_code := "discovered" if success else "failed"
	var destination := target_id
	var extra_coal := 0.0
	var extra_water := 0.0
	var durability_loss := 0.0
	var delayed_hours := 0.0
	var attempts := int(clue.get("attempts", 0)) if not clue.is_empty() else 0
	var events: Array = []

	if success:
		# 4.3.5 / U8：成功走完整段——按实际航行小时（arrival - departure）扣煤水。
		_consume_hourly(state, voyage, maxf(0.0, arrival_time - departure_time))
		var target_port := world.get_port(destination)
		# `_enter_port` syncs the played map (trade / market / chart read it) and records
		# the visit in the coordinate campaign partition.
		var newly_discovered := WorldOps.discover_port_id(state, destination)
		_enter_port(state, destination, true)
		FogOps.trace_route(state, world, route_path, fog_radii)
		if not target_port.is_empty():
			FogOps.reveal_arrival(state, world, target_port, fog_radii)
		ClueService.mark_resolved(state, clue_id)
		state.push_notice(
			"ui.notice.exploration_found",
			{"port": WorldOps.port_display_key(world, destination)}
		)
		events.append({
			"type": "explore.finished",
			"payload": {
				"result": result_code,
				"destination": destination,
				"clue_id": clue_id,
				"arrival_time": arrival_time,
			},
		})
		if newly_discovered:
			events.append({"type": "port.discovered", "payload": {"port_id": destination}})
	else:
		destination = _nearest_discovered_port(state, world, center, origin)
		var ship := state.ship()
		delayed_hours = float(rules.get("drift_hours", 6.0))
		# 4.3.5 / U8：失败也真的航行了 `duration + drift_hours` —— 先按费率扣小时消耗，
		# 再扣漂流额外损耗（在小时扣款之后的剩余库存上钳位）。
		_consume_hourly(state, voyage, duration + delayed_hours)
		var durability_before := float(ship.get("durability", 0.0))
		durability_loss = minf(float(rules.get("drift_durability_loss", 8.0)), durability_before)
		ship["durability"] = maxf(0.0, durability_before - durability_loss)
		extra_coal = minf(float(rules.get("drift_extra_coal", 4.0)), float(ship.get("coal", 0.0)))
		ship["coal"] = maxf(0.0, float(ship.get("coal", 0.0)) - extra_coal)
		extra_water = minf(float(rules.get("drift_extra_water", 4.0)), float(ship.get("water", 0.0)))
		ship["water"] = maxf(0.0, float(ship.get("water", 0.0)) - extra_water)
		state.set_now(arrival_time + delayed_hours)
		_enter_port(state, destination, true)
		if not world.is_empty():
			# 失败也真的走完了这条航线：沿途迷雾照常落账，再揭示漂流港的泊位。
			FogOps.trace_route(state, world, route_path, fog_radii)
			var drift_port := world.get_port(destination)
			if not drift_port.is_empty():
				FogOps.reveal_arrival(state, world, drift_port, fog_radii)
		# 4.3 / U3：失败不消耗线索——留在 active、记录尝试，玩家可再次出航。
		attempts = ClueService.mark_attempt_failed(state, clue_id, float(state.now()))
		state.push_notice(
			"ui.notice.exploration_failed",
			{"port": WorldOps.port_display_key(world, destination)}
		)
		events.append({
			"type": "explore.finished",
			"payload": {
				"result": result_code,
				"destination": destination,
				"clue_id": clue_id,
				"arrival_time": float(state.now()),
				"attempts": attempts,
			},
		})

	state.set_explore_voyage(null)
	state.data["voyage"] = null
	# 探索入港后与普通抵达一样跑一遍到港服务；失败漂流到的也是真实港口，所以同样
	# 允许委托 / 市场 / 债务 / 委托刷新发生（是否完成委托由目的地匹配自然决定）。
	var services := VoyageService.settle_arrival_services(context, destination, float(state.now()), {
		"destination": destination,
		"arrival_time": float(state.now()),
		"delay_hours": delayed_hours,
		"injuries": 0,
	})
	VoyageService.record_arrival_stats(state, services.get("contract_results", []), 0)
	events.append_array(services.get("events", []))
	var port_name_key := WorldOps.port_display_key(world, destination)
	var summary := _summary(
		state,
		result_code,
		destination,
		port_name_key,
		clue_id,
		zone,
		extra_coal,
		extra_water,
		durability_loss,
		delayed_hours,
		attempts,
		events,
		services
	)
	var result := Result.ok({"result": result_code, "destination": destination, "summary": summary}, events)
	result["autosave"] = true
	return result


## `explore_voyage.route_path` 是 `WorldMap.edges` 同款扁平数组 `[x0,y0,…]`；
## 转成折线交给 `FogOps.trace_route`。空/非法输入返回空折线（trace 自行 no-op）。
static func _route_polyline(raw: Variant) -> PackedVector2Array:
	if raw is PackedVector2Array:
		return raw
	if raw is Array:
		return VoyagePresentation.unpack_path(raw as Array)
	return PackedVector2Array()


## 4.3.5 / U8：按 `voyage.coal_rate/water_rate × elapsed_hours` 一次性扣煤水，
## 钳位到 0。`elapsed_hours` 由调用方按实际航行小时给出（含延误 / 漂流 / 半程）。
## 返回名义消耗 `{coal, water}`（未做库存钳位），供 UI / 测试使用。
static func _consume_hourly(
	state: GameState, voyage: Dictionary, elapsed_hours: float
) -> Dictionary:
	var ship := state.ship()
	var hours := maxf(0.0, elapsed_hours)
	var coal_used := maxf(0.0, float(voyage.get("coal_rate", 0.0)) * hours)
	var water_used := maxf(0.0, float(voyage.get("water_rate", 0.0)) * hours)
	ship["coal"] = maxf(0.0, float(ship.get("coal", 0.0)) - coal_used)
	ship["water"] = maxf(0.0, float(ship.get("water", 0.0)) - water_used)
	return {"coal": coal_used, "water": water_used}


## Records arrival in both the played map and the coordinate campaign partition.
static func _enter_port(state: GameState, port_id: String, reveal_facilities: bool) -> void:
	state.world()["current_port_id"] = port_id
	WorldOps.set_current_port(state, port_id)
	if reveal_facilities and not state.world().is_empty():
		MapOps.discover(state, port_id, true)
	WorldOps.mark_visited(state, port_id)


## Nearest discovered coordinate-world harbour to the search zone. Sorted ids make the
## tie-break deterministic; the origin is the fallback when nothing is discovered.
static func _nearest_discovered_port(
	state: GameState, world: WorldMap, center: Dictionary, fallback: String
) -> String:
	if world.is_empty():
		return fallback
	var center_position := Vector2(float(center.get("x", 0.0)), float(center.get("y", 0.0)))
	var discovered: Array = state.campaign_world().get("discovered_port_ids", [])
	var candidates: Array[String] = []
	for raw_id in discovered:
		candidates.append(String(raw_id))
	candidates.sort()
	var best := fallback
	var best_distance := INF
	for port_id in candidates:
		var port := world.get_port(port_id)
		if port.is_empty():
			continue
		var distance := port.position.distance_to(center_position)
		if distance < best_distance - 0.0001:
			best_distance = distance
			best = port_id
	return best


static func _summary(
	state: GameState,
	result_code: String,
	destination: String,
	port_name_key: String,
	clue_id: String,
	zone: Dictionary,
	extra_coal: float,
	extra_water: float,
	durability_loss: float,
	delayed_hours: float,
	attempts: int,
	events: Array,
	services: Dictionary = {}
) -> Dictionary:
	return {
		"destination": destination,
		"arrival_time": state.now(),
		"delayed_hours": delayed_hours,
		"injuries": 0,
		"contracts": services.get("contract_results", []),
		"market_events": services.get("npc_events", []),
		"debt_events": services.get("debt_events", []),
		"completed_orders": services.get("completed_orders", []),
		"offers_refreshed": not services.is_empty(),
		"stats": state.stats().duplicate(true),
		"explore": {
			"result": result_code,
			"port_id": destination,
			"port_name_key": port_name_key,
			"clue_id": clue_id,
			"search_center": {
				"x": float(zone.get("x", 0.0)),
				"y": float(zone.get("y", 0.0)),
			},
			"extra_coal": extra_coal,
			"extra_water": extra_water,
			"durability_loss": durability_loss,
			# 4.3 / U3：失败后线索保留，摘要报告累计尝试次数供结算页说明。
			"attempts": attempts,
			"clue_retained": result_code == "failed",
		},
		"events": events,
	}
