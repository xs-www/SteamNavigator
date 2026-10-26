class_name VoyageCalculator
extends RefCounted
## @static-doc
## 作用：纯计算航行预览：速度、耗时、煤水、准点、风险来源与可行性阻断。
##
## ## 契约与约束
## - 有效航速 = 船体基础 × 锅炉系数 × 策略 × 重量系数 × 导航/岗位修正。
## - 重量系数在 50% 载重内为 1.0，100% 为 0.65，超载继续线性下降并触发阻断。
## - 煤/水需求基于耗时与单位时间消耗；旅客额外耗水。
## - 预览返回 risk_score（内部）与 risk_sources（公开），不返回事故概率。
## - 工资不足、补给不足、超重、无耐久都会进入 blockers。
## - 反馈 #3：无期限主线委托（`ContractOps.is_untimed`）预览恒 `on_time=true`、`deadline=0`，
##   完成奖励计入 `revenue_estimate`，确认弹窗不会误报「预计迟到」。
## - 航线解锁（2026-10-26）：`MapOps.route_between` 只是「物理上有边」；`preview` 还要求
##   `WorldOps.is_route_unlocked(state, origin, destination)`，否则返回
##   `Result.fail("route_locked", "ui.error.route_locked")`。`voyage.start` 走同一个
##   `preview`，因此命令层无法绕过；`clue.travel` 同样经 `VoyageService.start` 受门禁。
##   `explore.start`（探索未知海域）不受此限制。
##
## ## 重点逻辑
## ### `preview(context, destination_id, strategy_id)`
## - 读取 strategy ContentDefinition，缺失或船只无效直接返回 Result.fail。
## - 主线目的港匹配时附加 deadline/on_time/revenue_estimate（含 `timed`）。
## - 所有计算只读；查询总线会额外克隆状态，保证无副作用。
##
## ### `weight_speed_factor(load_ratio)`
## - 分段线性且连续：≤0.5 → 1.0；0.5–1.0 线性降至 0.65；>1.0 继续下降，最低 0.45。
## @end-static-doc

const PASSENGER_WATER_RATE := 0.06
const RISK_LABEL_LOW := 0.12
const RISK_LABEL_HIGH := 0.24


static func preview(context, destination_id: String, strategy_id: String) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var origin := state.current_port_id()
	if origin == destination_id:
		return Result.fail("same_port", "ui.error.same_port")
	var route := MapOps.route_between(state.world(), origin, destination_id)
	if route.is_empty():
		return Result.fail("no_route", "ui.error.no_route", {"destination": destination_id})
	# 航线解锁（2026-10-26）：物理上任意两港可通航，但只有**已测绘**（unlocked）的
	# 航线才能出航。解锁来源见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`（委托自带海图 /
	# 剧情效果 / 酒馆 `chart.buy`）；单纯发现港口不解锁。
	if not WorldOps.is_route_unlocked(state, origin, destination_id):
		return Result.fail("route_locked", "ui.error.route_locked", {
			"destination": destination_id,
			"origin": origin,
		})
	var strategy: ContentDefinition = hub.get_by_id(ContentTypes.BOILER_STRATEGY, strategy_id)
	if strategy == null:
		return Result.fail("unknown_strategy", "ui.error.unknown_strategy", {"strategy_id": strategy_id})

	var ship := state.ship()
	var stats := ShipOps.stats(hub, ship)
	if not bool(stats.get("valid", false)):
		return Result.fail("invalid_ship", "ui.error.invalid_ship")
	var strategy_speed := float(strategy.data.get("speed_mul", 1.0))
	var strategy_coal := float(strategy.data.get("coal_mul", 1.0))
	var strategy_water := float(strategy.data.get("water_mul", 1.0))
	var strategy_risk := float(strategy.data.get("risk_add", 0.0))

	var max_weight := ShipOps.max_weight(hub, ship)
	var total_weight := ShipOps.total_weight(hub, state)
	var load_ratio := total_weight / max_weight if max_weight > 0.0 else 0.0
	var weight_factor := weight_speed_factor(load_ratio)
	var speed := float(stats.get("speed", 1.0)) * strategy_speed * weight_factor
	var distance := float(route.get("distance", 0.0))
	var duration := distance / maxf(0.1, speed)
	var passenger_count := ShipOps.passenger_count(state)
	var coal_required := duration * float(stats.get("coal_rate", 0.0)) * strategy_coal
	var water_required := duration * (
		float(stats.get("water_rate", 0.0)) * strategy_water
		+ float(passenger_count) * PASSENGER_WATER_RATE
	)
	var coal_available := float(ship.get("coal", 0.0))
	var water_available := float(ship.get("water", 0.0))
	var crew_wages := crew_wage(hub, ship)
	var arrival_time := state.now() + duration

	var contract := active_main_contract(state)
	var deadline := -1.0
	var on_time: Variant = null
	var revenue_estimate := {}
	if not contract.is_empty() and String(contract.get("destination", "")) == destination_id:
		# 反馈 #3：无期限委托不会迟到；确认弹窗不要误报「预计迟到」，完成奖励照给。
		var untimed := ContractOps.is_untimed(contract)
		deadline = 0.0 if untimed else float(contract.get("deadline", 0.0))
		on_time = true if untimed else arrival_time <= deadline
		revenue_estimate = {
			"base_money": int(contract.get("base_money", 0)),
			"on_time_bonus": int(contract.get("on_time_bonus", 0)) if on_time else 0,
			"deadline": deadline,
			"on_time": on_time,
			"timed": not untimed,
		}

	var risk := _risk_breakdown(
		float(route.get("base_risk", 0.0)),
		strategy_risk,
		load_ratio,
		float(ship.get("durability", 0.0)),
		float(stats.get("max_durability", 1.0)),
		stats,
		hub,
		ship
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

	var risk_score := clampf(float(risk["score"]), 0.01, 0.7)
	var preview := {
		"origin_id": origin,
		"destination_id": destination_id,
		"destination_name_key": MapOps.port_display_key(state.world(), destination_id),
		"distance": distance,
		"route_base_risk": float(route.get("base_risk", 0.0)),
		"strategy_id": strategy_id,
		"strategy_name_key": strategy.name_key,
		"strategy_speed_mul": strategy_speed,
		"strategy_coal_mul": strategy_coal,
		"strategy_water_mul": strategy_water,
		"ship_speed": float(stats.get("speed", 0.0)),
		"effective_speed": speed,
		"weight_factor": weight_factor,
		"total_weight": total_weight,
		"max_weight": max_weight,
		"cargo_used": ShipOps.cargo_used(hub, ship),
		"cargo_capacity": ShipOps.cargo_capacity(hub, ship),
		"passengers": passenger_count,
		"duration_hours": duration,
		"departure_time": state.now(),
		"arrival_time": arrival_time,
		"coal_required": coal_required,
		"coal_available": coal_available,
		"water_required": water_required,
		"water_available": water_available,
		"crew_wages": crew_wages,
		"feasible": blockers.is_empty(),
		"blockers": blockers,
		"risk_score": risk_score,
		"risk_label": risk_label(risk_score),
		"risk_sources": risk["sources"],
		"contract": contract.duplicate(true) if not contract.is_empty() else {},
		"deadline": deadline,
		"on_time": on_time,
		"revenue_estimate": revenue_estimate,
		"intel_generated_at": float(state.data.get("intelligence", {}).get("generated_at", -1.0)),
		"destination_facilities_known": MapOps.facilities_known(state, hub, destination_id),
		"destination_facilities": MapOps.visible_facilities(state, hub, destination_id),
	}
	return Result.ok(preview)


static func weight_speed_factor(load_ratio: float) -> float:
	var ratio := clampf(load_ratio, 0.0, 1.5)
	if ratio <= 0.5:
		return 1.0
	if ratio <= 1.0:
		return lerpf(1.0, 0.65, (ratio - 0.5) / 0.5)
	return maxf(0.45, 0.65 - (ratio - 1.0) * 0.2)


static func risk_label(risk_score: float) -> String:
	if risk_score < RISK_LABEL_LOW:
		return "low"
	if risk_score < RISK_LABEL_HIGH:
		return "medium"
	return "high"


static func event_chance(risk_score: float) -> float:
	return clampf(risk_score * 1.25, 0.02, 0.65)


static func active_main_contract(state: GameState) -> Dictionary:
	var contract: Variant = state.contracts().get("main", null)
	return contract if contract is Dictionary else {}


static func crew_wage(hub: RegistryHub, ship: Dictionary) -> int:
	var total := 0
	for kind in ["engineer", "navigator"]:
		var role := ShipOps.role_definition(hub, ship, kind)
		if role != null:
			total += int(round(float(role.data.get("wage_per_voyage", 0.0))))
	return total


static func _risk_breakdown(
	route_risk: float,
	strategy_risk: float,
	load_ratio: float,
	durability: float,
	maximum_durability: float,
	stats: Dictionary,
	hub: RegistryHub,
	ship: Dictionary
) -> Dictionary:
	var sources: Array[Dictionary] = []
	sources.append({"key": "risk.route", "value": route_risk, "direction": "add"})
	if not is_zero_approx(strategy_risk):
		sources.append({"key": "risk.strategy", "value": strategy_risk, "direction": "add"})
	var overload := maxf(0.0, load_ratio - 0.75) * 0.08
	if overload > 0.0:
		sources.append({"key": "risk.overload", "value": overload, "direction": "add"})
	var low_durability := 0.0
	if maximum_durability > 0.0 and durability / maximum_durability < 0.35:
		low_durability = 0.06
		sources.append({"key": "risk.low_durability", "value": low_durability, "direction": "add"})
	var equipment := float(stats.get("risk_add", 0.0)) - float(_hull_base_risk(hub, ship))
	if not is_zero_approx(equipment):
		sources.append({"key": "risk.equipment_crew", "value": equipment, "direction": "add"})
	var score := route_risk + strategy_risk + overload + low_durability + equipment
	return {"score": score, "sources": sources}


static func _hull_base_risk(hub: RegistryHub, ship: Dictionary) -> float:
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	return float(hull.data.get("base_risk", 0.0)) if hull != null else 0.0
