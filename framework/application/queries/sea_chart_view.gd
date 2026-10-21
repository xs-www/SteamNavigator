class_name SeaChartViewQuery
extends RefCounted
## @static-doc
## 作用：为可缩放 2D 海图生成只读视图模型（`sea_chart.view`），输出世界边界、
## 陆地多边形、按发现等级分类的港口、已知航线、降采样迷雾网格与船只位置。
##
## - 关键依赖：`WorldOps`、`FogGrid`、`RouteCalculator`、`Landmass`、`GameState.campaign_world()`
##
## ## 契约与约束
## - 只在 `has_run=true` 且 `world_map` 非空时输出完整数据，否则返回空结果。
## - 港口列表只包含已发现港口；未发现的港口被过滤掉。
## - 航线只在两端都已发现时输出，`explored` 标记两端都**已访问**的航线。
## - 航线读取 `WorldMap.edges`（生成期预计算的只读表）；旧存档没有该表时回退到
##   现场计算（`_compute_routes`），这条回退路径不改状态。
## - 迷雾网格按 `max(width, height)/80` 步长降采样，便于 UI 渲染。
## - 迷雾半径（4.3 / U1）来自内容比例：`min(world.w, world.h) × fog_*_ratio`
##   （`ExplorationRules.fog_radii`），输出 `fog_radii` 供 UI 软圆与演出使用；
##   旧存档没有迷雾网格时按同一半径惰性建一份只读网格。
## - 船只坐标取当前港口或 `voyage.ship_position`（在航时）。
## - 探索系统（阶段 4.1）追加三组只读数据：`clues` 是 `ClueService.view` 的等级裁剪
##   视图（不含 `target_port_id` / `credibility` / 真实 `search_zone`）再合并
##   `ExplorationCalculator.preview` 的展示估算；`explore` 只说明是否有探索航次及其
##   clue id；`can_buy_clue` 用与 `clue.buy` 相同的门禁算出是否可买与原因键。
## - 4.3.2 / U2：每条 clue 追加调查入口字段——`investigation_cost` /
##   `investigation_hours`（来自 Core `exploration` 块，4.3 初始 0）、
##   `can_investigate`（在港且 `level < 4`）、`next_level`（4 级为 0）与
##   `next_level_key`（下一级披露文案键，4 级为空串）。裁剪规则不变。
## - 4.4 线索扩展：每条 clue 追加 `type` / `target_goods_id` / `goods`（按等级裁剪的
##   货物行情投影）/ `expires_at` / `remaining_hours` / `is_expired` 与
##   `investigation_success_chance`；`port_goods` 不合并探索估算（`estimated` 为空字典），
##   顶层追加 `expiring_clue_count` 供列表页入口角标；查询仍然不输出
##   `target_port_id` / `credibility` / 真实 `search_zone`。
## - 每条航线附**预计航程**：`distance` 是坐标单位，`travel_hours` / `risk_level` /
##   煤水消耗由 `VoyageEstimator` 结合船速、锅炉策略与航行规则推出（世界表里只存
##   几何量，不存时间/风险）。`distance_source` 标明这个估算是按哪条距离算的：
##   `voyage` = 抽象地图上真有这条航线（数值与 `voyage.preview` 逐项一致），
##   `chart` = 孪生世界 MST 图独有、抽象地图上没有对应边，此时风险为未知（-1），
##   不能假装安全。
## @end-static-doc

## Legacy fallbacks only (fixtures without content rules); the real radii come
## from `ExplorationRules.fog_radii()` so the UI never owns a fixed world-unit fog.
const DEFAULT_MIN_VISION_RADIUS := FogOps.DEFAULT_MIN_VISION_RADIUS
const DEFAULT_PORT_REVEAL_RADIUS := FogOps.DEFAULT_PORT_REVEAL_RADIUS


static func execute(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.ok({"has_run": false})

	# Load world map from GameState (new world_map format)
	var world := WorldOps.world_map(state)
	if world.is_empty():
		return Result.ok(_empty_result())

	var current_port := WorldOps.current_port_id(state)
	var campaign_world := state.campaign_world()
	var discovered_ids: Array = campaign_world.get("discovered_port_ids", [])
	var visited_ids: Array = campaign_world.get("visited_port_ids", [])
	var hub: RegistryHub = context.registries
	var fog_radii := ExplorationRules.fog_radii(state, hub, world)

	# Fog state: read directly from GameState.data to avoid FogOps class resolution issues
	var fog := FogGrid.new()
	var coastal_cell_count := 0
	var fog_data: Dictionary = state.data.get("fog", {})
	if not fog_data.is_empty():
		var grid_dict: Dictionary = fog_data.get("grid", {})
		if not grid_dict.is_empty():
			fog = FogGrid.from_dict(grid_dict)
		var coastal: Variant = fog_data.get("coastal_cells", {})
		if coastal is Dictionary:
			coastal_cell_count = (coastal as Dictionary).size()

	# If no fog grid exists yet, create a default one for the UI using the content
	# fog radius (4.3 / U1), not a fixed 20-unit radius.
	if fog.is_empty():
		fog = FogGrid.new(world.bounds, float(fog_radii.get("vision", DEFAULT_MIN_VISION_RADIUS)))

	# Build landmass data (only those near explored areas)
	var landmasses_data: Array = []
	for landmass in world.landmasses:
		landmasses_data.append({
			"id": landmass.id,
			"polygon": _pack_polygon(landmass.polygon),
			"archetype": _archetype_name(landmass.archetype),
			"region_id": landmass.region_id,
			"area": landmass.area(),
		})

	# Build port data with discovery levels
	var ports_data: Array = []
	for port in world.ports:
		var is_discovered := discovered_ids.has(port.id)
		var is_visited := visited_ids.has(port.id)
		var is_current := port.id == current_port
		# Only include discovered ports on the chart
		if not is_discovered:
			continue
		# Display keys so the chart/panel never render a raw content id.
		var archetype_name_key := ""
		var archetype_definition := hub.get_by_id(
			ContentTypes.PORT_ARCHETYPE, port.archetype_id
		)
		if archetype_definition != null:
			archetype_name_key = archetype_definition.name_key
		var region := world.get_region(port.region_id)
		var region_name_key := region.name_key if not region.is_empty() else ""
		ports_data.append({
			"id": port.id,
			"name_key": port.name_key,
			"x": port.position.x,
			"y": port.position.y,
			"discovered": true,
			"visited": is_visited,
			"current": is_current,
			"departure_angle": port.departure_angle,
			"facilities": Array(port.facilities),
			"archetype": port.archetype_id,
			"archetype_name_key": archetype_name_key,
			"region_id": port.region_id,
			"region_name_key": region_name_key,
			"landmass_id": port.landmass_id,
		})

	# Build route data (only between discovered ports). Routes are read from the world's
	# precomputed route table; a world generated before schema 1.1 has none, so those
	# saves fall back to computing paths here (slow, but only for legacy worlds).
	# Each emitted route also carries the voyage estimate (travel time, supplies, risk).
	var estimate := _estimate_context(context, params, current_port)
	var routes_data: Array = []
	if world.route_count() > 0:
		for edge in world.edges:
			var from_id := String(edge.get("from", ""))
			var to_id := String(edge.get("to", ""))
			if not discovered_ids.has(from_id) or not discovered_ids.has(to_id):
				continue
			var path: PackedVector2Array = edge.get("path", PackedVector2Array())
			if path.size() < 2:
				continue
			routes_data.append({
				"from": from_id,
				"to": to_id,
				"bezier_path": _pack_path(path),
				"distance": float(edge.get("distance", 0.0)),
				"explored": visited_ids.has(from_id) and visited_ids.has(to_id),
			}.merged(_route_estimate(estimate, from_id, to_id, float(edge.get("distance", 0.0)))))
	else:
		routes_data = _compute_routes(world, discovered_ids, visited_ids, estimate)

	# Build fog alpha grid (downsampled for UI performance)
	var fog_grid_data: Dictionary = {}
	if not fog.is_empty():
		# Downsample the fog grid for rendering (every N cells)
		var step := maxi(1, ceili(float(maxi(fog.width, fog.height)) / 80.0))
		var sampled_width := ceili(float(fog.width) / float(step))
		var sampled_height := ceili(float(fog.height) / float(step))
		var alpha_rows: Array = []
		var state_grid_rows: Array = []
		for sy in sampled_height:
			var alpha_row: Array = []
			var state_row: Array = []
			var gy := mini(sy * step, fog.height - 1)
			for sx in sampled_width:
				var gx := mini(sx * step, fog.width - 1)
				var cell := fog.get_cell(gx, gy)
				alpha_row.append(float(cell["alpha"]))
				state_row.append(int(cell["state"]))
			alpha_rows.append(alpha_row)
			state_grid_rows.append(state_row)
		fog_grid_data = {
			"cell_size": fog.cell_size * float(step),
			"width": sampled_width,
			"height": sampled_height,
			"alpha_grid": alpha_rows,
			"state_grid": state_grid_rows,
			"original_width": fog.width,
			"original_height": fog.height,
		}

	# Ship position (at port or at sea)
	var at_sea := bool(state.data.get("at_sea", false))
	var ship_pos := {"x": 0.0, "y": 0.0}
	if not at_sea and not current_port.is_empty():
		var port_data := world.get_port(current_port)
		if not port_data.is_empty():
			ship_pos = {"x": port_data.position.x, "y": port_data.position.y}
	elif at_sea:
		var voyage: Dictionary = state.data.get("voyage", {})
		var ship_world: Variant = voyage.get("ship_position", null)
		if ship_world is Dictionary:
			ship_pos = {
				"x": float((ship_world as Dictionary).get("x", 0.0)),
				"y": float((ship_world as Dictionary).get("y", 0.0)),
			}

	return Result.ok({
		"has_run": true,
		"world_bounds": {
			"x": world.bounds.position.x,
			"y": world.bounds.position.y,
			"w": world.bounds.size.x,
			"h": world.bounds.size.y,
		},
		"landmasses": landmasses_data,
		"ports": ports_data,
		"routes": routes_data,
		"fog": fog_grid_data,
		"fog_radii": fog_radii,
		"coastal_cell_count": coastal_cell_count,
		"current_port_id": current_port,
		"ship_position": ship_pos,
		"at_sea": at_sea,
		"world_seed": world.world_seed,
		"port_count": world.ports.size(),
		"discovered_count": discovered_ids.size(),
		"visited_count": visited_ids.size(),
		"clues": _clue_views(context, params),
		"expiring_clue_count": _expiring_clue_count(state),
		"explore": _explore_state(state),
		"can_buy_clue": _can_buy_clue(context, state),
	})


## Legacy fallback for worlds generated before schema 1.1 (no stored route table).
static func _compute_routes(
	world: WorldMap, discovered_ids: Array, visited_ids: Array, estimate: Dictionary
) -> Array:
	var routes: Array = []
	var connectivity: Dictionary = world.connectivity_graph
	for from_id in connectivity:
		if not discovered_ids.has(String(from_id)):
			continue
		for neighbor_id in connectivity[from_id]:
			var to_id := String(neighbor_id)
			if not discovered_ids.has(to_id):
				continue
			# Avoid duplicate edges (only emit from < to)
			if String(from_id) >= to_id:
				continue
			var from_port := world.get_port(String(from_id))
			var to_port := world.get_port(to_id)
			if from_port.is_empty() or to_port.is_empty():
				continue
			var route := RouteCalculator.calculate_route(from_port, to_port, world.landmasses)
			var distance := float(route.get("distance", 0.0))
			routes.append({
				"from": String(from_id),
				"to": to_id,
				"bezier_path": _pack_path(route.get("bezier_path", PackedVector2Array())),
				"distance": distance,
				"explored": visited_ids.has(String(from_id)) and visited_ids.has(to_id),
			}.merged(_route_estimate(estimate, String(from_id), to_id, distance)))
	return routes


## Everything the per-route estimate needs, resolved once per query: the ship
## (speed / coal / water rates / load), the boiler strategies and the played
## abstract map routes (`base_risk` lives there, not in the coordinate world).
## Returns `{}` when there is no run to estimate from — routes then carry only
## geometry, which is exactly what the old query emitted.
static func _estimate_context(context, params: Dictionary, current_port: String) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var ship := state.ship()
	if hub == null or ship.is_empty():
		return {}
	var stats := ShipOps.stats(hub, ship)
	if not bool(stats.get("valid", false)):
		return {}
	var preferred_strategy := String(params.get("strategy_id", ""))
	var strategies: Dictionary = {}
	var preferred: ContentDefinition = null
	for strategy in hub.get_all(ContentTypes.STRATEGY):
		strategies[strategy.id] = strategy
		if preferred == null and strategy.has_tag("strategy.standard"):
			preferred = strategy
	if preferred_strategy != "" and strategies.has(preferred_strategy):
		preferred = strategies[preferred_strategy]
	if preferred == null and not strategies.is_empty():
		preferred = (strategies.values()[0] as ContentDefinition)
	# Load ratio uses the full-load rules (`ShipOps.total_weight`), so the weight
	# penalty and the risk source match what `voyage.preview` will report.
	var max_weight := ShipOps.max_weight(hub, ship)
	var total_weight := ShipOps.total_weight(hub, state)
	var played_routes: Dictionary = {}
	for route in MapOps.routes(state.world()):
		if not (route is Dictionary):
			continue
		played_routes[_pair_key(
			String(route.get("a", "")), String(route.get("b", ""))
		)] = route
	return {
		"state": state,
		"hub": hub,
		"ship": ship,
		"stats": stats,
		"strategies": strategies,
		"preferred_strategy": preferred,
		"load_ratio": total_weight / max_weight if max_weight > 0.0 else 0.0,
		"passengers": ShipOps.passenger_count(state),
		"played_routes": played_routes,
		"current_port": current_port,
		"game_time": state.now(),
		# The hull's own base risk is already inside `stats.risk_add`; the
		# estimator subtracts it again to isolate equipment/crew risk, exactly as
		# `VoyageCalculator._risk_breakdown` does.
		"hull_base_risk": _hull_base_risk(hub, ship),
	}


static func _hull_base_risk(hub: RegistryHub, ship: Dictionary) -> float:
	var hull: ContentDefinition = hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	return float(hull.data.get("base_risk", 0.0)) if hull != null else 0.0


## Adds the estimate fields for one chart route. `travel_hours` is direction
## independent (distance / speed), so either orientation of the stored edge can
## use the same number; the supply block additionally names the boiler strategy
## it assumes and whether the abstract-map route matched the chart distance.
static func _route_estimate(
	estimate: Dictionary, from_id: String, to_id: String, distance: float
) -> Dictionary:
	if estimate.is_empty():
		return {}
	var strategies: Dictionary = estimate["strategies"]
	var preferred: ContentDefinition = estimate["preferred_strategy"]
	var played: Variant = (estimate["played_routes"] as Dictionary).get(_pair_key(from_id, to_id), null)
	# Pick the strategy the estimate is computed with: the played route's own
	# strategy when this exact voyage is on the abstract map, else the standard
	# one (`strategy_id` override from the caller wins for both).
	var chosen: ContentDefinition = preferred
	var strategy_source := "default"
	if played is Dictionary:
		var played_strategy := String((played as Dictionary).get("strategy_id", ""))
		if strategies.has(played_strategy):
			chosen = strategies[played_strategy]
			strategy_source = "voyage"
	var estimate_distance := distance
	var distance_source := "chart"
	if played is Dictionary:
		# The voyage is actually judged on the abstract map's route; when that
		# route exists, use it so time and supplies match `voyage.preview`.
		var played_distance := float((played as Dictionary).get("distance", 0.0))
		if played_distance > 0.0:
			estimate_distance = played_distance
			distance_source = "voyage"
	var voyage := VoyageEstimator.estimate(
		estimate,
		distance,
		estimate_distance,
		# No abstract-map route means no base risk is known for this pair: pass -1
		# so the estimator reports "unknown" instead of "safe".
		float((played as Dictionary).get("base_risk", 0.0)) if played is Dictionary else -1.0,
		chosen
	)
	voyage["distance_source"] = distance_source
	voyage["strategy_source"] = strategy_source
	return voyage


static func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


static func _empty_result() -> Dictionary:
	return {
		"has_run": false,
		"world_bounds": {"x": 0.0, "y": 0.0, "w": 400.0, "h": 400.0},
		"landmasses": [],
		"ports": [],
		"routes": [],
		"fog": {},
		"fog_radii": {
			"vision": DEFAULT_MIN_VISION_RADIUS,
			"port_reveal": DEFAULT_PORT_REVEAL_RADIUS,
		},
		"coastal_cell_count": 0,
		"current_port_id": "",
		"ship_position": {"x": 0.0, "y": 0.0},
		"at_sea": false,
		"world_seed": 0,
		"port_count": 0,
		"discovered_count": 0,
		"visited_count": 0,
		"clues": [],
		"expiring_clue_count": 0,
		"explore": {"active": false, "clue_id": ""},
		"can_buy_clue": {"available": false, "cost": 0, "reason_key": ""},
	}


## 4.4：列表页入口角标用的计数——所有带时效且仍有效的线索。
static func _expiring_clue_count(state: GameState) -> int:
	var count := 0
	for entry in ClueService.view(state):
		if entry is Dictionary and float((entry as Dictionary).get("expires_at", 0.0)) > 0.0:
			count += 1
	return count


## Level-trimmed clue views (`ClueService.view`) plus the ship-specific estimate the
## panel needs. The estimate is a display projection of `explore.start`, so it uses the
## same calculator and never reveals the departure roll.
static func _clue_views(context, params: Dictionary) -> Array:
	var state: GameState = context.state
	var strategy_id := String(params.get("strategy_id", ""))
	var rules := ExplorationRules.read(state, context.registries)
	var investigation_cost := int(rules.get("investigation_cost", 0))
	var investigation_hours := float(rules.get("investigation_hours", 0.0))
	var investigation_chance := clampf(
		float(rules.get("investigation_success_chance", 1.0)), 0.0, 1.0
	)
	var at_port := state.is_at_port()
	var views: Array = []
	for entry in ClueService.view(state, context):
		if not (entry is Dictionary):
			continue
		var clue_view: Dictionary = entry
		var level := int(clue_view.get("level", 1))
		var clue := ClueService.find_clue(state, String(clue_view.get("id", "")))
		var can_investigate := at_port and level < ClueService.NAME_MIN_LEVEL
		var next_level := level + 1 if level < ClueService.NAME_MIN_LEVEL else 0
		clue_view["investigation_cost"] = investigation_cost
		clue_view["investigation_hours"] = investigation_hours
		clue_view["investigation_success_chance"] = investigation_chance
		clue_view["can_investigate"] = can_investigate
		clue_view["can_sail"] = _clue_can_sail(state, clue, at_port)
		clue_view["next_level"] = next_level
		clue_view["next_level_key"] = "" if next_level == 0 else "ui.clue.level.%d" % next_level
		# 货物线索的目标是已发现港口，估算走普通航线（`clue.travel`）而不是探索搜索区。
		if String(clue_view.get("type", ClueService.TYPE_PORT_LOCATION)) == ClueService.TYPE_PORT_GOODS:
			clue_view["estimated"] = _goods_travel_estimate(context, clue, strategy_id)
		else:
			clue_view["estimated"] = _clue_estimate(
				context, String(clue_view.get("id", "")), strategy_id
			)
		views.append(clue_view)
	return views


## 4.4.2：线索当前能否出航（在港、没有探索航次；货物线索不能去当前港）。
static func _clue_can_sail(
	state: GameState, clue: Dictionary, at_port: bool
) -> bool:
	if not at_port or state.explore_voyage() is Dictionary or clue.is_empty():
		return false
	if String(clue.get("type", ClueService.TYPE_PORT_LOCATION)) == ClueService.TYPE_PORT_GOODS:
		return String(clue.get("target_port_id", "")) != state.current_port_id()
	return true


## 4.4.2：货物线索的「前往该港」预览 = 普通 `voyage.preview`（目标港在领域层解析，
## 查询不输出 target id）；形状与海图航线的展示估算一致，供统一确认弹窗渲染。
static func _goods_travel_estimate(
	context, clue: Dictionary, strategy_id: String
) -> Dictionary:
	var state: GameState = context.state
	var target_id := String(clue.get("target_port_id", ""))
	if clue.is_empty() or target_id.is_empty() or target_id == state.current_port_id():
		return {
			"feasible": false,
			"blockers": [{
				"code": "no_travel_target",
				"message_key": "ui.error.no_travel_target",
			}],
		}
	var result := VoyageCalculator.preview(context, target_id, strategy_id)
	if not bool(result.get("ok", false)):
		return {
			"feasible": false,
			"blockers": [{
				"code": String(result.get("error_code", "")),
				"message_key": String(result.get("message_key", "ui.error.voyage_not_feasible")),
			}],
		}
	var data: Dictionary = result.get("data", {})
	return {
		"feasible": bool(data.get("feasible", false)),
		"blockers": data.get("blockers", []),
		"distance": float(data.get("distance", 0.0)),
		"duration_hours": float(data.get("duration_hours", 0.0)),
		"coal_required": float(data.get("coal_required", 0.0)),
		"water_required": float(data.get("water_required", 0.0)),
		"risk_score": float(data.get("risk_score", -1.0)),
		"risk_label": String(data.get("risk_label", "")),
		"on_time": data.get("on_time", true) != false,
	}


static func _clue_estimate(context, clue_id: String, strategy_id: String) -> Dictionary:
	var result := ExplorationCalculator.preview(context, clue_id, strategy_id)
	if not bool(result.get("ok", false)):
		return {
			"feasible": false,
			"blockers": [{
				"code": String(result.get("error_code", "")),
				"message_key": String(result.get("message_key", "")),
			}],
			"duration_hours": 0.0,
			"coal_required": 0.0,
			"water_required": 0.0,
			"risk_score": 0.0,
			"discovery_chance": 0.0,
		}
	var data: Dictionary = result.get("data", {})
	return {
		"feasible": bool(data.get("feasible", false)),
		"blockers": data.get("blockers", []),
		"duration_hours": float(data.get("duration_hours", 0.0)),
		"coal_required": float(data.get("coal_required", 0.0)),
		"water_required": float(data.get("water_required", 0.0)),
		"risk_score": float(data.get("risk_score", 0.0)),
		"discovery_chance": float(data.get("discovery_chance", 0.0)),
	}


static func _explore_state(state: GameState) -> Dictionary:
	var voyage: Variant = state.explore_voyage()
	if not (voyage is Dictionary):
		return {
			"active": false, "clue_id": "",
			"alert_needed": false, "alert_progress": 0.0, "alert_decided": "",
		}
	return {
		"active": true, "clue_id": String((voyage as Dictionary).get("clue_id", "")),
		# 4.2 资源告急决策点：比例来自 Core JSON 的 `alert_progress`；`alert_decided`
		# 非空表示玩家已经做过选择（continue 后 alert_progress 置 1.0）。
		"alert_needed": bool((voyage as Dictionary).get("alert_needed", false)),
		"alert_progress": float((voyage as Dictionary).get("alert_progress", 0.0)),
		"alert_decided": String((voyage as Dictionary).get("alert_decided", "")),
	}


## Why the buy button is (not) available, resolved with the same gates `clue.buy` uses so
## the button never lies about a cost the command would refuse.
static func _can_buy_clue(context, state: GameState) -> Dictionary:
	var rules := ExplorationRules.read(state, context.registries)
	var cost := int(rules.get("intel_clue_cost", 40))
	if not state.is_at_port():
		return {"available": false, "cost": cost, "reason_key": "ui.error.not_at_port"}
	var port_data := MapOps.port(state.world(), state.current_port_id())
	if not MapOps.has_facility(port_data, "intel"):
		return {"available": false, "cost": cost, "reason_key": "ui.error.no_intel_facility"}
	if ClueService.active_count(state) >= int(rules.get("max_active_clues", 4)):
		return {"available": false, "cost": cost, "reason_key": "ui.notice.no_clue_available"}
	if state.money() < cost:
		return {"available": false, "cost": cost, "reason_key": "ui.error.insufficient_money"}
	if ClueService.eligible_target_ids(state).is_empty():
		return {"available": false, "cost": cost, "reason_key": "ui.error.no_exploration_target"}
	return {"available": true, "cost": cost, "reason_key": ""}


static func _archetype_name(archetype: int) -> String:
	match archetype:
		Landmass.Archetype.CONTINENT:
			return "continent"
		Landmass.Archetype.LARGE_ISLAND:
			return "large_island"
		Landmass.Archetype.SMALL_ISLAND:
			return "small_island"
		Landmass.Archetype.ATOLL:
			return "atoll"
		_:
			return "unknown"


static func _pack_polygon(polygon: PackedVector2Array) -> Array:
	var result: Array = []
	for point in polygon:
		result.append({"x": point.x, "y": point.y})
	return result


static func _pack_path(path: Variant) -> Array:
	var result: Array = []
	if path is PackedVector2Array:
		var packed: PackedVector2Array = path as PackedVector2Array
		for point in packed:
			result.append({"x": point.x, "y": point.y})
	elif path is Array:
		for point in path:
			if point is Vector2:
				result.append({"x": (point as Vector2).x, "y": (point as Vector2).y})
			elif point is Dictionary:
				result.append(point)
	return result
