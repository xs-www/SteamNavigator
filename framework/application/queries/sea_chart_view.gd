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
## - 船只坐标取当前港口或 `voyage.ship_position`（在航时）。
## @end-static-doc

const DEFAULT_MIN_VISION_RADIUS := 20.0
const DEFAULT_PORT_REVEAL_RADIUS := 24.0


static func execute(_params: Dictionary, context) -> Dictionary:
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

	# If no fog grid exists yet, create a default one for the UI
	if fog.is_empty():
		fog = FogGrid.new(world.bounds, DEFAULT_MIN_VISION_RADIUS)

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
	var hub: RegistryHub = context.registries
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

	# Build route data (only between discovered ports)
	# Build route data (only between discovered ports). Routes are read from the world's
	# precomputed route table; a world generated before schema 1.1 has none, so those
	# saves fall back to computing paths here (slow, but only for legacy worlds).
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
			})
	else:
		routes_data = _compute_routes(world, discovered_ids, visited_ids)

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
		"coastal_cell_count": coastal_cell_count,
		"current_port_id": current_port,
		"ship_position": ship_pos,
		"at_sea": at_sea,
		"world_seed": world.world_seed,
		"port_count": world.ports.size(),
		"discovered_count": discovered_ids.size(),
		"visited_count": visited_ids.size(),
	})


## Legacy fallback for worlds generated before schema 1.1 (no stored route table).
static func _compute_routes(world: WorldMap, discovered_ids: Array, visited_ids: Array) -> Array:
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
			routes.append({
				"from": String(from_id),
				"to": to_id,
				"bezier_path": _pack_path(route.get("bezier_path", PackedVector2Array())),
				"distance": float(route.get("distance", 0.0)),
				"explored": visited_ids.has(String(from_id)) and visited_ids.has(to_id),
			})
	return routes


static func _empty_result() -> Dictionary:
	return {
		"has_run": false,
		"world_bounds": {"x": 0.0, "y": 0.0, "w": 400.0, "h": 400.0},
		"landmasses": [],
		"ports": [],
		"routes": [],
		"fog": {},
		"coastal_cell_count": 0,
		"current_port_id": "",
		"ship_position": {"x": 0.0, "y": 0.0},
		"at_sea": false,
		"world_seed": 0,
		"port_count": 0,
		"discovered_count": 0,
		"visited_count": 0,
	}


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
