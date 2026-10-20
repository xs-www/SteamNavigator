extends Control
## @static-doc
## 作用：海图系统（阶段 2）的独立预览场景，把 `sea_chart.view` 查询、`SNSeaChartView`
## 与 `SNSeaChartPanel` 按真实布局（海图铺满 + 右侧 320 px 信息面板）拼起来，供窗口截图
## 与人工目视验收使用。不属于主流程，不写存档。
##
## ## 契约与约束
## - 用与 `framework/tests/test_case.gd` 相同的 Bootstrap 配置加载 loose Core，
##   再用 `WorldGenerator.generate()` 造一个可复现世界（seed 固定）。
## - 四个变体通过 `set_variant()` 切换，只改变迷雾/已发现集合/船只位置：
##   `fresh`（仅起点港已发现，大片黑雾）、`bare`（诊断：整图已揭示，无迷雾干扰）、
##   `explored`（多港口 + 航线 + 沿岸航行留下的永久灰雾带与整岛剪影）、
##   `voyage`（在航 + 选中目的港，右侧面板有数据，船停在 45% 弧长处）。
## - `explored` / `voyage` 会按路径真实回放 `FogOps.update_ship_vision`，所以灰雾带是
##   阶段 1 的真实产出，不是画上去的；`bare` 用全 VISIBLE 网格表达"无迷雾"（查询在没有
##   迷雾数据时会注入全黑网格，所以不能靠"缺数据"表达已揭示）。
## - 所有数据都来自真实查询，预览不伪造港口/航线坐标。
## @end-static-doc

const PREVIEW_PROFILE := {
	"world_size": 400.0,
	# Same acceptance floor the production generator enforces (design §2.2): the
	# screenshots are the visual evidence for the 15-20 harbour world, so the
	# preview must not quietly generate a smaller map.
	"min_ports": WorldGenerator.MIN_PORTS,
	"max_ports": WorldGenerator.MAX_PORTS,
	"max_land_coverage": 0.3,
	# Core archetype tags: iron_harbor/free_town carry port.shipyard, spice/free/glass carry port.intel.
	"required_facility_tags": ["port.shipyard", "port.intel"],
	"required_facility_max_edges": 2,
	"regions": [
		{"id": "start_coast", "name_key": "world.region.start_coast", "tier": "coastal"},
		{"id": "mid_coast_1", "name_key": "world.region.mid_coast_1", "tier": "coastal"},
		{"id": "mid_coast_2", "name_key": "world.region.mid_coast_2", "tier": "coastal"},
		{"id": "ocean_1", "name_key": "world.region.ocean_1", "tier": "oceanic"},
	],
	# Every landmass stays inside world bounds: the fog grid only covers
	# [0, world_size]^2, so a continent straddling the edge would show bare water
	# and unrevealed land outside the fog coverage.
	"landmasses": [
		{"id": "continent_west", "region_id": "start_coast", "archetype": "continent", "cx": 45.0, "cy": 200.0, "rx": 34.0, "ry": 78.0},
		{"id": "iron_island", "region_id": "mid_coast_1", "archetype": "large_island", "cx": 140.0, "cy": 88.0, "rx": 18.0, "ry": 14.0},
		{"id": "spice_islands", "region_id": "mid_coast_2", "archetype": "large_island", "cx": 220.0, "cy": 288.0, "rx": 15.0, "ry": 12.0},
		{"id": "north_island", "region_id": "ocean_1", "archetype": "large_island", "cx": 312.0, "cy": 140.0, "rx": 20.0, "ry": 16.0},
		{"id": "coral_reef", "region_id": "start_coast", "archetype": "small_island", "cx": 100.0, "cy": 220.0, "rx": 6.0, "ry": 5.0},
		{"id": "fog_reef", "region_id": "ocean_1", "archetype": "small_island", "cx": 248.0, "cy": 168.0, "rx": 5.0, "ry": 4.0},
		{"id": "south_wind", "region_id": "mid_coast_2", "archetype": "small_island", "cx": 180.0, "cy": 352.0, "rx": 7.0, "ry": 5.0},
		{"id": "bone_reef", "region_id": "ocean_1", "archetype": "small_island", "cx": 328.0, "cy": 260.0, "rx": 4.0, "ry": 3.5},
		{"id": "glass_atoll", "region_id": "start_coast", "archetype": "atoll", "cx": 152.0, "cy": 180.0, "rx": 3.0, "ry": 2.5},
		{"id": "moon_atoll", "region_id": "ocean_1", "archetype": "atoll", "cx": 280.0, "cy": 72.0, "rx": 2.5, "ry": 2.0},
		{"id": "far_reef", "region_id": "ocean_1", "archetype": "atoll", "cx": 352.0, "cy": 328.0, "rx": 3.0, "ry": 2.0},
	],
	# Real Core archetype ids so facilities / tags / size / diorama resolve from
	# content (the chart then shows real facility lists). Core only ships six port
	# name keys, so the remaining preview ports use `port_name.preview.*` keys that
	# PREVIEW_NAMES resolves — a content gap worth filling before the real chart ships.
	"ports": [
		{"archetype_id": "core:port_archetype/iron_harbor", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.25, "name_key": "port_name.core.iron_harbor", "is_start": true},
		{"archetype_id": "core:port_archetype/spice_port", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.45, "name_key": "port_name.core.spice_port"},
		{"archetype_id": "core:port_archetype/free_town", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.62, "name_key": "port_name.core.free_town"},
		{"archetype_id": "core:port_archetype/fishing_village", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.82, "name_key": "port_name.core.fishing_village"},
		{"archetype_id": "core:port_archetype/glass_port", "region_id": "mid_coast_1", "landmass_id": "iron_island", "coast_t": 0.5, "name_key": "port_name.core.glass_port"},
		{"archetype_id": "core:port_archetype/spice_port", "region_id": "mid_coast_2", "landmass_id": "spice_islands", "coast_t": 0.3, "name_key": "port_name.core.mist_cove"},
		{"archetype_id": "core:port_archetype/glass_port", "region_id": "mid_coast_2", "landmass_id": "spice_islands", "coast_t": 0.72, "name_key": "port_name.preview.copper_cove"},
		{"archetype_id": "core:port_archetype/iron_harbor", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.25, "name_key": "port_name.preview.salt_rock"},
		{"archetype_id": "core:port_archetype/fishing_village", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.78, "name_key": "port_name.preview.whale_reach"},
		{"archetype_id": "core:port_archetype/fishing_village", "region_id": "start_coast", "landmass_id": "coral_reef", "coast_t": 0.5, "name_key": "port_name.preview.coral_station"},
		{"archetype_id": "core:port_archetype/glass_port", "region_id": "ocean_1", "landmass_id": "fog_reef", "coast_t": 0.5, "name_key": "port_name.preview.fog_lighthouse"},
		{"archetype_id": "core:port_archetype/free_town", "region_id": "mid_coast_2", "landmass_id": "south_wind", "coast_t": 0.5, "name_key": "port_name.preview.south_wind_port"},
		{"archetype_id": "core:port_archetype/spice_port", "region_id": "start_coast", "landmass_id": "glass_atoll", "coast_t": 0.5, "name_key": "port_name.preview.glass_atoll_port"},
		# Two more berths on the outer reefs, so the preview actually exercises the
		# 15-harbour acceptance floor instead of a smaller hand-made map.
		{"archetype_id": "core:port_archetype/spice_port", "region_id": "ocean_1", "landmass_id": "bone_reef", "coast_t": 0.5, "name_key": "port_name.preview.bone_harbor"},
		{"archetype_id": "core:port_archetype/glass_port", "region_id": "ocean_1", "landmass_id": "far_reef", "coast_t": 0.5, "name_key": "port_name.preview.far_reef_port"},
	],
}

## Preview-only port names for the ports Core has no localization key for.
## The real chart will need these keys in core content; until then they live here
## so the screenshot never shows a raw key. Region names ship in framework
## localization (`world.region.*`), so they are no longer listed here.
const PREVIEW_NAMES := {
	"port_name.preview.copper_cove": "铜湾",
	"port_name.preview.salt_rock": "盐岩港",
	"port_name.preview.whale_reach": "鲸岬",
	"port_name.preview.coral_station": "珊瑚站",
	"port_name.preview.fog_lighthouse": "雾灯港",
	"port_name.preview.south_wind_port": "南风港",
	"port_name.preview.glass_atoll_port": "玻璃礁港",
	"port_name.preview.bone_harbor": "骨礁港",
	"port_name.preview.far_reef_port": "远礁港",
}

const SEED := 12345
const PANEL_WIDTH := 320.0
const VISION_RADIUS := 20.0
const PORT_REVEAL_RADIUS := 24.0

var _context: AppContext
var _world: WorldMap
var _chart: SNSeaChartView
var _panel: SNSeaChartPanel
var _translate: Callable
var _variant: String = "explored"
## A real run's state data (ship / run clock / abstract map) so the right panel
## can show genuine voyage estimates instead of inventing numbers. The preview
## only replaces the coordinate `world_map`; everything the estimate is derived
## from (ship, boiler strategy, abstract-map routes) stays real domain data.
var _run_state: Dictionary = {}


func _ready() -> void:
	_bootstrap()
	_build_ui()
	await _wait_frames(3)
	set_variant(_variant)


func _bootstrap() -> void:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://preview_saves/sea_chart",
	})
	_context = bootstrap.context
	AppContext.set_active(_context)
	_translate = func(key: String) -> String:
		# Preview-only keys first (core has no name keys for these ports yet), then
		# the real localization tables from framework + content mods.
		if PREVIEW_NAMES.has(key):
			return String(PREVIEW_NAMES[key])
		return _context.translate(key)

	var rng := RngService.new(SEED)
	var result := WorldGenerator.generate(PREVIEW_PROFILE, _context.registries, rng, {})
	var world_dict: Dictionary = result.get("world_map", {})
	_world = WorldMap.from_dict(world_dict)
	print("[INFO] preview world: ports=%d landmasses=%d seed=%d" % [
		_world.ports.size(), _world.landmasses.size(), _world.world_seed,
	])

	# Real run: supplies the ship, the clock and the abstract-map routes that the
	# chart's estimate is derived from (see `VoyageEstimator`). Failure is not
	# fatal — the panel then shows geometry only, exactly like a legacy save.
	var run := RunFactory.create_run(_context, "core:starting_build/steady", SEED)
	if bool(run.get("ok", false)):
		var run_state = (run.get("data", {}) as Dictionary).get("state", null)
		if run_state is GameState:
			_run_state = (run_state as GameState).data.duplicate(true)
	print("[INFO] preview run: ship=%s abstract ports=%d" % [
		"yes" if not _run_state.is_empty() else "no",
		(_run_state.get("world", {}).get("ports", {}) as Dictionary).size(),
	])


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b2428")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	_chart = SNSeaChartView.new()
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_chart)

	_panel = SNSeaChartPanel.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_panel)


func set_variant(variant_name: String) -> void:
	_variant = variant_name
	if _chart == null or _world.is_empty():
		return
	var start_port := _world.get_start_port()
	var discovered: Array = [start_port.id]
	var visited: Array = [start_port.id]
	var ship_port_id := start_port.id
	var at_sea := false
	var ship_position := start_port.position
	var selected_port := ""
	var with_fog := true
	# Optional sailed path: replaying ship vision along it is what turns coastal
	# cells into permanent EXPLORED fog (and ocean cells back to BLACK).
	var sailed_path := PackedVector2Array()

	match variant_name:
		"fresh":
			# Only the starting harbour is known: the chart should be almost all black.
			pass
		"explored":
			# Two hops of exploration around the start: ports, routes, coastal grey fog.
			var hop1 := WorldOps.neighbors(_world, start_port.id)
			for neighbor_id in hop1:
				discovered.append(String(neighbor_id))
				visited.append(String(neighbor_id))
				for hop2_id in WorldOps.neighbors(_world, String(neighbor_id)):
					if not discovered.has(String(hop2_id)):
						discovered.append(String(hop2_id))
			selected_port = String(hop1[0]) if not hop1.is_empty() else ""
			# Sail the home continent's coast so the chart shows the permanent
			# grey "explored" band along the coastline, not just port reveal spots.
			var home := _world.get_landmass(start_port.landmass_id)
			if not home.is_empty():
				sailed_path = _coast_ring(home, VISION_RADIUS * 0.6)
			ship_position = start_port.position
		"voyage":
			var hop1 := WorldOps.neighbors(_world, start_port.id)
			for neighbor_id in hop1:
				discovered.append(String(neighbor_id))
				visited.append(String(neighbor_id))
			# Pick the farthest discovered port as the destination so the ship icon
			# clearly sits mid-ocean on a long active route. Prefer a destination
			# that also exists on the abstract map: only those have a base risk, so
			# the panel can show a real band instead of the "unknown" fallback.
			var farthest := ""
			var farthest_distance := -1.0
			var farthest_abstract := ""
			var farthest_abstract_distance := -1.0
			for port_id in discovered:
				if String(port_id) == start_port.id:
					continue
				var candidate := _world.get_port(String(port_id))
				if candidate.is_empty():
					continue
				var candidate_distance := start_port.position.distance_to(candidate.position)
				if candidate_distance > farthest_distance:
					farthest_distance = candidate_distance
					farthest = String(port_id)
				var abstract_world: Dictionary = _run_state.get("world", {})
				if not abstract_world.is_empty() \
						and not MapOps.route_between(abstract_world, start_port.id, String(port_id)).is_empty() \
						and candidate_distance > farthest_abstract_distance:
					farthest_abstract_distance = candidate_distance
					farthest_abstract = String(port_id)
			selected_port = farthest_abstract if not farthest_abstract.is_empty() else farthest
			at_sea = true
			if not selected_port.is_empty():
				var to_port := _world.get_port(selected_port)
				var route := RouteCalculator.calculate_route(start_port, to_port, _world.landmasses)
				var bezier: PackedVector2Array = route.get("bezier_path", PackedVector2Array())
				if bezier.size() >= 2:
					# 45% of the voyage *by arc length* (index-based would stop early on a
					# route whose first segments are dense).
					sailed_path = _sail_prefix(bezier, 0.45)
					ship_position = sailed_path[sailed_path.size() - 1]
				else:
					ship_position = start_port.position.lerp(to_port.position, 0.45)
					sailed_path = PackedVector2Array([start_port.position, ship_position])
		"bare":
			# Diagnostics: everything discovered, no fog at all. Used to check land
			# polygons / routes / icons in isolation from the fog overlay.
			for port in _world.ports:
				discovered.append(port.id)
				visited.append(port.id)
			with_fog = false
		_:
			push_warning("sea chart preview: unknown variant '%s'" % variant_name)

	_apply_state(discovered, visited, ship_port_id, at_sea, ship_position, selected_port, with_fog, sailed_path)


## Coastline ring pushed `offset` units seaward from the polygon, used to sail a
## closed loop around one island so its coastal fog becomes permanent.
func _coast_ring(landmass: Landmass, offset: float) -> PackedVector2Array:
	var ring := PackedVector2Array()
	if landmass.polygon.size() < 3:
		return ring
	var centroid := Vector2.ZERO
	for point in landmass.polygon:
		centroid += point
	centroid /= float(landmass.polygon.size())
	for point in landmass.polygon:
		var outward := (point - centroid).normalized()
		ring.append(point + outward * offset)
	return ring


## Prefix of `path` covering `fraction` of its arc length, ending on an interpolated
## point so the ship icon sits exactly that far along the route.
func _sail_prefix(path: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var prefix := PackedVector2Array()
	if path.size() < 2:
		return path
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	if total <= 0.0:
		return path
	var target := total * clampf(fraction, 0.0, 1.0)
	var walked := 0.0
	prefix.append(path[0])
	for index in range(1, path.size()):
		var segment := path[index - 1].distance_to(path[index])
		if walked + segment >= target:
			var ratio := (target - walked) / maxf(segment, 0.0001)
			prefix.append(path[index - 1].lerp(path[index], ratio))
			return prefix
		walked += segment
		prefix.append(path[index])
	return prefix


## Replays ship vision along a path. Each call first reverts VISIBLE cells, so
## coastal cells become permanent EXPLORED and open-ocean cells go back to BLACK —
## the exact rule the design doc asks the chart to show.
func _sail(fog: FogGrid, coastal_cells: Dictionary, path: PackedVector2Array) -> void:
	var step := maxf(2.0, VISION_RADIUS * 0.5)
	var previous := path[0]
	FogOps.update_ship_vision(fog, previous, VISION_RADIUS, coastal_cells)
	for index in range(1, path.size()):
		var target := path[index]
		var segment := previous.distance_to(target)
		var travelled := 0.0
		while travelled < segment:
			FogOps.update_ship_vision(
				fog, previous.lerp(target, travelled / segment), VISION_RADIUS, coastal_cells
			)
			travelled += step
		FogOps.update_ship_vision(fog, target, VISION_RADIUS, coastal_cells)
		previous = target


func _apply_state(
	discovered: Array,
	visited: Array,
	ship_port_id: String,
	at_sea: bool,
	ship_position: Vector2,
	selected_port: String,
	with_fog: bool = true,
	sailed_path: PackedVector2Array = PackedVector2Array()
) -> void:
	var state := GameState.new()
	if not _run_state.is_empty():
		# Keep the run's ship / clock / abstract map; replace only the coordinate
		# world and the progress the variant wants to show.
		state.data = _run_state.duplicate(true)
	state.data["world_map"] = _world.to_dict()
	state.data["current_port_id"] = ship_port_id
	state.data["at_sea"] = at_sea
	if at_sea:
		state.data["voyage"] = {
			"ship_position": {"x": ship_position.x, "y": ship_position.y},
		}
	var campaign_world := state.campaign_world()
	campaign_world["discovered_port_ids"] = discovered.duplicate()
	campaign_world["visited_port_ids"] = visited.duplicate()

	# Real Phase 1 fog: coastal cells, port reveal (lamp flower), ship vision.
	if with_fog:
		var fog := FogOps.create_fog_grid(_world, VISION_RADIUS)
		var coastal_cells := FogOps.mark_coastal_cells(fog, _world)
		for port in _world.ports:
			if discovered.has(port.id):
				FogOps.reveal_port(fog, port, PORT_REVEAL_RADIUS)
		if sailed_path.size() >= 2:
			_sail(fog, coastal_cells, sailed_path)
		FogOps.update_ship_vision(fog, ship_position, VISION_RADIUS, coastal_cells)
		fog.smooth_alpha_interpolation()
		FogOps.save_fog_state(state, fog, coastal_cells)
	else:
		# Diagnostic variant: persist an all-VISIBLE grid. The query injects an
		# all-black grid when no fog state exists, so "no fog at all" has to be
		# expressed as a fully revealed grid, not as missing data.
		var fog := FogOps.create_fog_grid(_world, VISION_RADIUS)
		for gy in fog.height:
			for gx in fog.width:
				fog.set_cell(gx, gy, FogGrid.CellState.VISIBLE)
		FogOps.save_fog_state(state, fog, {})

	_context.set_state(state)

	var result := SeaChartViewQuery.execute({}, _context)
	var vm: Dictionary = result.get("data", {})
	print("[INFO] variant=%s ports=%d routes=%d ship=(%.1f, %.1f) sailed_pts=%d at_sea=%s" % [
		_variant, vm.get("ports", []).size(), vm.get("routes", []).size(),
		ship_position.x, ship_position.y, sailed_path.size(), str(at_sea),
	])
	_chart.bind(vm, _translate)
	_chart.select_port(selected_port)
	_bind_panel(vm, selected_port, ship_port_id)


func _bind_panel(vm: Dictionary, selected_port: String, current_port_id: String) -> void:
	if selected_port.is_empty():
		_panel.clear()
		return
	var port_data := {}
	for entry in vm.get("ports", []):
		if String(entry.get("id", "")) == selected_port:
			port_data = entry
			break
	var route_data := {}
	if not port_data.is_empty() and String(port_data.get("id", "")) != current_port_id:
		for route in vm.get("routes", []):
			var from_id := String(route.get("from", ""))
			var to_id := String(route.get("to", ""))
			if (from_id == current_port_id and to_id == selected_port) \
					or (from_id == selected_port and to_id == current_port_id):
				route_data = route
				break
	_panel.bind(port_data, route_data, _translate)


func _wait_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func get_chart() -> SNSeaChartView:
	return _chart


func get_panel() -> SNSeaChartPanel:
	return _panel
