class_name ExplorationCalculator
extends RefCounted
## @static-doc
## 作用：把「一条线索的搜索区 + 当前船况 + 锅炉策略 + 探索规则」折算成探索出航预览
## （距离、耗时、煤水、工资、风险、发现概率、绕陆航线），供 `explore.start` 与海图
## 右侧面板使用。纯投影：不写状态、不抽发现结果。
##
## - 关键依赖：`ClueService`、`ExplorationRules`、`WorldOps`、`RouteCalculator`、
##   `ShipOps`、`VoyageCalculator`
##
## ## 契约与约束
## - 航速 / 载重系数 / 煤水费率 / 工资 / 风险来源与 `VoyageCalculator.preview` 同一套
##   公式与钳位：航速 = 船速 × 策略 `speed_mul` × 载重系数；煤 = 耗时 × 煤耗 ×
##   `coal_mul`；水 = 耗时 ×（水耗 × `water_mul` + 乘客 × 0.06）；风险钳位 [0.01, 0.7]。
## - 距离按坐标世界 `origin.position -> zone.center` 的**直线距离**；`route_path` 另用
##   `RouteCalculator` 生成绕陆航线（失败退回直线），只用于演出画线。
## - 探索航线不是海图世界的一条边，因此基础风险取探索规则：`risk_base +
##   risk_per_unreliability * (1 - credibility)`，再叠加策略 / 超载 / 低耐久 / 装备风险。
## - `discovery_chance` 只是展示值（规则函数），真实判定在 `explore.settle` 用出发时
##   抽定的 `outcome_roll` 比较，预览绝不泄露 roll。
## - 不可行时仍返回 `Result.ok`，把原因放进 `blockers`；`explore.start` 负责拒绝并保证
##   不扣任何资源。
## @end-static-doc

const RISK_MIN := 0.01
const RISK_MAX := 0.7
const OVERLOAD_THRESHOLD := 0.75
const OVERLOAD_RISK := 0.08
const LOW_DURABILITY_RATIO := 0.35
const LOW_DURABILITY_RISK := 0.06


## Preview of an exploration voyage to a clue's search zone.
## Returns `Result.fail` for missing run/port/clue/strategy; infeasibility is `ok` + blockers.
static func preview(context, clue_id: String, strategy_id: String = "") -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var clue := ClueService.find_clue(state, clue_id)
	if clue.is_empty():
		return Result.fail("unknown_clue", "ui.error.unknown_clue", {"clue_id": clue_id})
	var world := WorldOps.world_map(state)
	if world.is_empty():
		return Result.fail("no_world_map", "ui.error.unknown_port")
	var origin := world.get_port(state.current_port_id())
	if origin.is_empty():
		return Result.fail("unknown_port", "ui.error.unknown_port", {"port_id": state.current_port_id()})
	var strategy: ContentDefinition = null
	if not strategy_id.is_empty():
		strategy = hub.get_by_id(ContentTypes.BOILER_STRATEGY, strategy_id)
		if strategy == null:
			return Result.fail("unknown_strategy", "ui.error.unknown_strategy", {"strategy_id": strategy_id})
	else:
		strategy = _default_strategy(hub)
	var resolved_strategy_id := strategy.id if strategy != null else ""
	var strategy_speed := float(strategy.data.get("speed_mul", 1.0)) if strategy != null else 1.0
	var strategy_coal := float(strategy.data.get("coal_mul", 1.0)) if strategy != null else 1.0
	var strategy_water := float(strategy.data.get("water_mul", 1.0)) if strategy != null else 1.0
	var strategy_risk := float(strategy.data.get("risk_add", 0.0)) if strategy != null else 0.0

	var ship := state.ship()
	var stats := ShipOps.stats(hub, ship)
	if not bool(stats.get("valid", false)):
		return Result.fail("invalid_ship", "ui.error.invalid_ship")

	var zone: Dictionary = clue.get("search_zone", {})
	var center := Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))
	var radius := float(zone.get("radius", 0.0))
	var distance := origin.position.distance_to(center)
	var route_path := _route_path_to_zone(origin, center, world)

	var max_weight := ShipOps.max_weight(hub, ship)
	var total_weight := ShipOps.total_weight(hub, state)
	var load_ratio := total_weight / max_weight if max_weight > 0.0 else 0.0
	var weight_factor := VoyageCalculator.weight_speed_factor(load_ratio)
	var effective_speed := maxf(0.1, float(stats.get("speed", 1.0)) * strategy_speed * weight_factor)
	var duration := distance / effective_speed
	var passengers := ShipOps.passenger_count(state)
	var coal_required := duration * float(stats.get("coal_rate", 0.0)) * strategy_coal
	var water_required := duration * (
		float(stats.get("water_rate", 0.0)) * strategy_water
		+ float(passengers) * VoyageCalculator.PASSENGER_WATER_RATE
	)
	var crew_wages := VoyageCalculator.crew_wage(hub, ship)
	var coal_available := float(ship.get("coal", 0.0))
	var water_available := float(ship.get("water", 0.0))

	var rules := ExplorationRules.read(state, hub)
	var credibility := float(clue.get("credibility", 0.0))
	var risk_score := _risk_score(
		rules,
		credibility,
		strategy_risk,
		load_ratio,
		float(ship.get("durability", 0.0)),
		float(stats.get("max_durability", 1.0)),
		float(stats.get("risk_add", 0.0)) - _hull_base_risk(hub, ship)
	)

	var blockers: Array[Dictionary] = []
	if coal_available + 0.0001 < coal_required:
		blockers.append({
			"code": "insufficient_coal",
			"message_key": "ui.error.coal",
			"required": coal_required,
			"available": coal_available,
		})
	if water_available + 0.0001 < water_required:
		blockers.append({
			"code": "insufficient_water",
			"message_key": "ui.error.water",
			"required": water_required,
			"available": water_available,
		})
	if max_weight > 0.0 and total_weight > max_weight + 0.0001:
		blockers.append({"code": "overweight", "message_key": "ui.error.weight"})
	if float(ship.get("durability", 0.0)) <= 0.0:
		blockers.append({"code": "no_durability", "message_key": "ui.error.no_durability"})
	if state.money() < crew_wages:
		blockers.append({
			"code": "insufficient_wages",
			"message_key": "ui.error.wages",
			"required": crew_wages,
			"available": state.money(),
		})

	return Result.ok({
		"clue_id": clue_id,
		"origin_id": origin.id,
		"strategy_id": resolved_strategy_id,
		"strategy_name_key": strategy.name_key if strategy != null else "",
		"zone": {"x": center.x, "y": center.y, "radius": radius},
		"distance": distance,
		"duration_hours": duration,
		"effective_speed": effective_speed,
		"weight_factor": weight_factor,
		"total_weight": total_weight,
		"max_weight": max_weight,
		"coal_required": coal_required,
		"coal_available": coal_available,
		"water_required": water_required,
		"water_available": water_available,
		"crew_wages": crew_wages,
		"risk_score": risk_score,
		"risk_label": VoyageCalculator.risk_label(risk_score),
		"discovery_chance": ExplorationRules.discovery_chance(rules, credibility),
		"feasible": blockers.is_empty(),
		"blockers": blockers,
		"route_path": _pack_flat(route_path),
	})


## Effective speed for the exploration estimate. Kept public so tests can pin the
## arithmetic without rebuilding the whole preview payload.
static func effective_speed(context, strategy_id: String = "") -> float:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var ship := state.ship()
	var stats := ShipOps.stats(hub, ship)
	if not bool(stats.get("valid", false)):
		return maxf(0.1, float(stats.get("speed", 1.0)))
	var strategy: ContentDefinition = null
	if strategy_id.is_empty():
		strategy = _default_strategy(hub)
	else:
		strategy = hub.get_by_id(ContentTypes.BOILER_STRATEGY, strategy_id)
	var speed_mul := float(strategy.data.get("speed_mul", 1.0)) if strategy != null else 1.0
	var max_weight := ShipOps.max_weight(hub, ship)
	var total_weight := ShipOps.total_weight(hub, state)
	var load_ratio := total_weight / max_weight if max_weight > 0.0 else 0.0
	return maxf(
		0.1,
		float(stats.get("speed", 1.0)) * speed_mul * VoyageCalculator.weight_speed_factor(load_ratio)
	)


static func _default_strategy(hub: RegistryHub) -> ContentDefinition:
	for definition in hub.get_all(ContentTypes.BOILER_STRATEGY):
		if definition.has_tag("strategy.standard"):
			return definition
	var all := hub.get_all(ContentTypes.BOILER_STRATEGY)
	return all[0] if not all.is_empty() else null


## Around-land Bezier path from the harbour to the search-zone centre. The zone is not a
## real port, so a synthetic WorldPort carries its position / departure angle; when the
## router finds no clear path the straight line is used (the演出 still has a route).
static func _route_path_to_zone(origin: WorldPort, center: Vector2, world: WorldMap) -> PackedVector2Array:
	var zone_port := WorldPort.new("explore_zone", center)
	zone_port.departure_angle = (center - origin.position).angle()
	var route := RouteCalculator.calculate_route(origin, zone_port, world.landmasses)
	var path: Variant = route.get("bezier_path", PackedVector2Array())
	if path is PackedVector2Array and (path as PackedVector2Array).size() >= 2:
		return path
	if path is Array and (path as Array).size() >= 2:
		var converted := PackedVector2Array()
		for point in path:
			if point is Vector2:
				converted.append(point)
		if converted.size() >= 2:
			return converted
	return PackedVector2Array([origin.position, center])


static func _risk_score(
	rules: Dictionary,
	credibility: float,
	strategy_risk: float,
	load_ratio: float,
	durability: float,
	maximum_durability: float,
	equipment_risk: float
) -> float:
	var base_risk := float(rules.get("risk_base", 0.08)) \
		+ float(rules.get("risk_per_unreliability", 0.12)) * (1.0 - credibility)
	var overload := maxf(0.0, load_ratio - OVERLOAD_THRESHOLD) * OVERLOAD_RISK
	var low_durability := 0.0
	if maximum_durability > 0.0 and durability / maximum_durability < LOW_DURABILITY_RATIO:
		low_durability = LOW_DURABILITY_RISK
	return clampf(
		base_risk + strategy_risk + overload + low_durability + equipment_risk,
		RISK_MIN,
		RISK_MAX
	)


static func _hull_base_risk(hub: RegistryHub, ship: Dictionary) -> float:
	var hull: ContentDefinition = hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	return float(hull.data.get("base_risk", 0.0)) if hull != null else 0.0


## `WorldMap.edges` / save JSON use a flat `[x0, y0, x1, y1, ...]` path array.
static func _pack_flat(path: PackedVector2Array) -> Array:
	var flat: Array = []
	for point in path:
		flat.append(point.x)
		flat.append(point.y)
	return flat
