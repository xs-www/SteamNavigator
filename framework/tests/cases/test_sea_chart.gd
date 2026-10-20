extends TestCase
class_name TestSeaChart
## @static-doc
## 作用：海图系统的无头测试——阶段 2 验证 `sea_chart.view` 的输出结构与陆地/港口/
## 航线/迷雾数据；阶段 4.1 追加线索可视化（视图几何、点击命中、面板线索区块、
## 未知终点）和整页信号转发。
##
## ## 契约与约束
## - 每个用例通过 `bootstrap_core()` 获得真实 Core 注册表，再用内联 `TEST_PROFILE`
##   生成世界；纯几何/组件用例直接构造视图模型或面板，不渲染、不驱动帧。
## - `_setup_world_and_state()` 把起始港与其首个邻居标为已发现/已访问，
##   使航线用例具备两端可见的前提。
## - 线索用例用 `CLUE_VM`（含 level 2/3/4 线索与缺失参照港）断言：几何换算是
##   纯静态函数（`clue_arrow_endpoint` / `clue_circle_screen` / `clue_hit_test`），
##   面板/整页只验证接线与文案，不依赖真实对局。
## - 港口坐标断言使用宽松范围：大陆可能跨出 `world.bounds`，港口锚定在海岸线上。
## @end-static-doc

const SEED_A := 12345
const SEED_B := 67890
## Loaded by path, not via the global class cache: brand-new `class_name`s only
## enter the cache after an editor reimport, and the headless runner must not
## depend on one (same convention as `test_ui_shell.gd`).
const SEA_CHART_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/sea_chart_screen.gd")
const TEST_PROFILE := {
	"world_size": 400.0,
	# Design freeze (NAUTICAL_CHART_SYSTEM.md §2.2/§12): 15-20 harbours per run.
	"min_ports": 15,
	"max_ports": 20,
	"max_land_coverage": 0.3,
	"required_facility_tags": ["port.shipyard", "port.intelligence"],
	"required_facility_max_edges": 2,
	"regions": [
		{"id": "start_coast", "name_key": "world.region.start_coast", "tier": "coastal"},
		{"id": "mid_coast_1", "name_key": "world.region.mid_coast_1", "tier": "coastal"},
		{"id": "mid_coast_2", "name_key": "world.region.mid_coast_2", "tier": "coastal"},
		{"id": "ocean_1", "name_key": "world.region.ocean_1", "tier": "oceanic"},
	],
	"landmasses": [
		{"id": "continent_west", "region_id": "start_coast", "archetype": "continent", "cx": -10.0, "cy": 200.0, "rx": 35.0, "ry": 80.0},
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
	"ports": [
		# The start port uses a real Core archetype / name key so the query's
		# `archetype_name_key` / `region_name_key` resolution is actually exercised.
		{"archetype_id": "core:port_archetype/iron_harbor", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.10, "name_key": "port_name.core.iron_harbor", "is_start": true},
		{"archetype_id": "port_archetype_2", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.24, "name_key": "port.spice_harbor"},
		{"archetype_id": "port_archetype_3", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.38, "name_key": "port.free_town"},
		{"archetype_id": "port_archetype_4", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.52, "name_key": "port.fishing_village", "required_tags": ["port.intelligence"]},
		{"archetype_id": "port_archetype_5", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.68, "name_key": "port.iron_port"},
		{"archetype_id": "port_archetype_6", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.84, "name_key": "port.glass_port"},
		{"archetype_id": "port_archetype_7", "region_id": "mid_coast_1", "landmass_id": "iron_island", "coast_t": 0.20, "name_key": "port.south_station"},
		{"archetype_id": "port_archetype_8", "region_id": "mid_coast_1", "landmass_id": "iron_island", "coast_t": 0.55, "name_key": "port.north_outpost"},
		{"archetype_id": "port_archetype_9", "region_id": "mid_coast_1", "landmass_id": "iron_island", "coast_t": 0.88, "name_key": "port.ice_wind"},
		{"archetype_id": "port_archetype_10", "region_id": "mid_coast_2", "landmass_id": "spice_islands", "coast_t": 0.25, "name_key": "port.coral_station"},
		{"archetype_id": "port_archetype_11", "region_id": "mid_coast_2", "landmass_id": "spice_islands", "coast_t": 0.72, "name_key": "port.fog_lighthouse"},
		{"archetype_id": "port_archetype_12", "region_id": "mid_coast_2", "landmass_id": "south_wind", "coast_t": 0.40, "name_key": "port.south_wind_port"},
		{"archetype_id": "port_archetype_13", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.18, "name_key": "port.glass_atoll_port"},
		{"archetype_id": "port_archetype_14", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.50, "name_key": "port.mist_cove"},
		{"archetype_id": "port_archetype_15", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.85, "name_key": "port.bone_harbor"},
		{"archetype_id": "port_archetype_16", "region_id": "start_coast", "landmass_id": "coral_reef", "coast_t": 0.35, "name_key": "port.reef_haven"},
		{"archetype_id": "port_archetype_17", "region_id": "start_coast", "landmass_id": "glass_atoll", "coast_t": 0.50, "name_key": "port.atoll_haven"},
		{"archetype_id": "port_archetype_18", "region_id": "ocean_1", "landmass_id": "moon_atoll", "coast_t": 0.50, "name_key": "port.moon_haven"},
	],
}


func test_sea_chart_query_returns_valid_structure() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var result := SeaChartViewQuery.execute({}, context)
	assert_true(bool(result.get("ok", false)), "query should succeed")
	var data: Dictionary = result.get("data", {})

	assert_true(data.has("has_run"), "should have has_run")
	assert_true(data.has("world_bounds"), "should have world_bounds")
	assert_true(data.has("landmasses"), "should have landmasses")
	assert_true(data.has("ports"), "should have ports")
	assert_true(data.has("routes"), "should have routes")
	assert_true(data.has("fog"), "should have fog")
	assert_true(data.has("current_port_id"), "should have current_port_id")
	assert_true(data.has("ship_position"), "should have ship_position")
	assert_true(data.has("at_sea"), "should have at_sea")
	assert_true(data.has("world_seed"), "should have world_seed")
	assert_true(bool(data.get("has_run", false)), "has_run should be true")


func test_sea_chart_query_world_bounds_match() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var world_dict := _setup_world_and_state(SEED_A, context)
	var world := WorldMap.from_dict(world_dict)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var bounds: Dictionary = data["world_bounds"]

	assert_almost_eq(float(bounds.get("x", 0.0)), world.bounds.position.x, 0.001, "bounds x should match")
	assert_almost_eq(float(bounds.get("y", 0.0)), world.bounds.position.y, 0.001, "bounds y should match")
	assert_almost_eq(float(bounds.get("w", 0.0)), world.bounds.size.x, 0.001, "bounds width should match")
	assert_almost_eq(float(bounds.get("h", 0.0)), world.bounds.size.y, 0.001, "bounds height should match")


func test_sea_chart_query_includes_all_landmasses() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var world_dict := _setup_world_and_state(SEED_A, context)
	var world := WorldMap.from_dict(world_dict)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var landmasses: Array = data["landmasses"]

	assert_eq(landmasses.size(), world.landmasses.size(), "should include all landmasses")

	for lm in landmasses:
		assert_true(lm.has("id"), "landmass should have id")
		assert_true(lm.has("polygon"), "landmass should have polygon")
		assert_true(lm.has("archetype"), "landmass should have archetype")
		assert_true(lm.has("region_id"), "landmass should have region_id")
		assert_true(lm.has("area"), "landmass should have area")
		var polygon: Array = lm["polygon"]
		assert_true(polygon.size() >= 3, "polygon should have at least 3 points")


func test_sea_chart_query_current_port_marked() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var world_dict := _setup_world_and_state(SEED_A, context)
	var world := WorldMap.from_dict(world_dict)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var current_port_id := String(data["current_port_id"])
	var start_port := world.get_start_port()

	assert_eq(current_port_id, start_port.id, "current port should be start port")

	var ports: Array = data["ports"]
	var found_current := false
	for port_data in ports:
		if String(port_data.get("id", "")) == current_port_id:
			assert_true(bool(port_data.get("current", false)), "current port should be marked")
			found_current = true
			break
	assert_true(found_current, "current port should be in ports list")


func test_sea_chart_query_routes_between_discovered_ports() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var routes: Array = data["routes"]

	assert_true(routes.size() > 0, "should have at least one route")

	for route in routes:
		assert_true(route.has("from"), "route should have from")
		assert_true(route.has("to"), "route should have to")
		assert_true(route.has("bezier_path"), "route should have bezier_path")
		assert_true(route.has("distance"), "route should have distance")
		assert_true(route.has("explored"), "route should have explored flag")

		var bezier_path: Array = route["bezier_path"]
		assert_true(bezier_path.size() >= 2, "bezier path should have at least 2 points")

		var distance: float = float(route["distance"])
		assert_true(distance > 0.0, "distance should be positive")
		assert_true(distance < 10000.0, "distance should be reasonable")


## Phase 2 required the right-hand panel to show estimated time, consumption and
## risk. The world's stored edge only has geometry, so the query layer has to
## derive the rest from the ship and the sailing rules: every route must carry a
## positive travel time, a supply block and a risk level that the panel can print.
func test_sea_chart_routes_carry_voyage_estimates() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": SEED_A})
	var world := WorldOps.world_map(context.state)
	var current := WorldOps.current_port_id(context.state)
	# A fresh run only knows its starting harbour, so no edge has both ends
	# discovered yet. Reveal the start's chart neighbours the way exploration
	# would, so the query has real edges to estimate.
	for neighbor_id in WorldOps.neighbors(world, current):
		WorldOps.discover_port_id(context.state, String(neighbor_id))

	var result := SeaChartViewQuery.execute({}, context)
	var vm: Dictionary = result.get("data", {})
	var routes: Array = vm.get("routes", [])
	assert_true(routes.size() > 0, "the real run should expose at least one chart route")

	var stats := ShipOps.stats(context.registries, context.state.ship())
	for route in routes:
		var label := "%s-%s" % [route.get("from", ""), route.get("to", "")]
		assert_true(route.has("travel_hours"), "route %s should carry travel_hours" % label)
		assert_true(float(route.get("travel_hours", 0.0)) > 0.0,
			"route %s should have a positive travel time" % label)
		assert_true(float(route.get("speed", 0.0)) > 0.0, "route %s should report the effective speed" % label)
		assert_true(route.has("supplies"), "route %s should carry a supply estimate" % label)
		assert_true(route.has("risk_level"), "route %s should carry a risk level" % label)
		var supplies: Dictionary = route.get("supplies", {})
		assert_true(float(supplies.get("coal_required", -1.0)) >= 0.0,
			"route %s should estimate coal" % label)
		assert_true(float(supplies.get("water_required", -1.0)) >= 0.0,
			"route %s should estimate water" % label)
		# The estimate must agree with the voyage preview formula: distance / speed.
		var expected_hours := float(route.get("voyage_distance", 0.0)) / float(route.get("speed", 1.0))
		assert_almost_eq(float(route.get("travel_hours", 0.0)), expected_hours, 0.01,
			"route %s travel time should be distance / speed" % label)
		# Coal is duration × boiler rate × strategy coal multiplier. Recompute it
		# from the route's own travel time and the reported strategy.
		var strategy_id := String(route.get("strategy_id", ""))
		var strategy := context.registries.get_by_id(ContentTypes.STRATEGY, strategy_id)
		var coal_mul := float(strategy.data.get("coal_mul", 1.0)) if strategy != null else 1.0
		var water_mul := float(strategy.data.get("water_mul", 1.0)) if strategy != null else 1.0
		var expected_coal := float(route.get("travel_hours", 0.0)) * float(stats.get("coal_rate", 0.0)) * coal_mul
		assert_almost_eq(float(supplies.get("coal_required", 0.0)), expected_coal, 0.05,
			"route %s coal should be duration × boiler rate × strategy multiplier" % label)
		var expected_water := float(route.get("travel_hours", 0.0)) * (
			float(stats.get("water_rate", 0.0)) * water_mul
			+ float(ShipOps.passenger_count(context.state)) * VoyageCalculator.PASSENGER_WATER_RATE
		)
		assert_almost_eq(float(supplies.get("water_required", 0.0)), expected_water, 0.05,
			"route %s water should match the preview's water rule" % label)

		# The twin world's MST graph is not the abstract map's graph (a known
		# boundary recorded in todo.md), so only pairs that exist on both can be
		# cross-checked. For those, the chart estimate must equal the preview.
		var from_id := String(route.get("from", ""))
		var to_id := String(route.get("to", ""))
		var destination := to_id if from_id == current else (from_id if to_id == current else "")
		if destination.is_empty():
			continue
		var abstract_route := MapOps.route_between(context.state.world(), current, destination)
		if abstract_route.is_empty():
			assert_eq(String(route.get("distance_source", "")), "chart",
				"route %s has no abstract-map counterpart, so it estimates on chart distance" % label)
			assert_eq(String(route.get("risk_source", "")), "none",
				"route %s has no abstract-map counterpart, so its risk is unknown" % label)
			assert_almost_eq(float(route.get("risk_level", 0.0)), -1.0, 0.0001,
				"route %s should report unknown risk (-1), not zero" % label)
			continue
		var preview := context.commands.execute(&"voyage.preview", {
			"destination_id": destination,
			"strategy_id": String(route.get("strategy_id", "")),
		})
		assert_true(bool(preview.get("ok", false)), "preview for %s should succeed" % label)
		var preview_data: Dictionary = preview.get("data", {})
		assert_almost_eq(float(route.get("travel_hours", 0.0)), float(preview_data.get("duration_hours", 0.0)), 0.05,
			"chart estimate for %s should match voyage.preview duration (both feed the same voyage)" % label)
		assert_almost_eq(float(route.get("risk_level", -1.0)), float(preview_data.get("risk_score", -2.0)), 0.02,
			"chart risk for %s should match voyage.preview risk" % label)
		assert_eq(String(route.get("distance_source", "")), "voyage",
			"a route that exists on the abstract map should estimate on the voyage distance")


## The panel is a pure renderer: when the query supplies the estimate it must
## print estimated time, supplies and risk, and it must not print a made-up
## "no risk" line when the query reports an unknown risk.
func test_sea_chart_panel_renders_voyage_estimates() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)
	var world := WorldMap.from_dict(context.state.data["world_map"])
	var start_port := world.get_start_port()
	var neighbor_id := String(WorldOps.neighbors(world, start_port.id)[0])

	var panel := SNSeaChartPanel.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	var port_data := {"id": neighbor_id, "name_key": "port_name.core.mist_cove"}
	var route_data := {
		"from": start_port.id,
		"to": neighbor_id,
		"distance": 120.0,
		"travel_hours": 30.0,
		"risk_level": 0.42,
		"risk_label": VoyageCalculator.risk_label(0.42),
		"supplies": {
			"coal_required": 36.0,
			"coal_available": 120.0,
			"water_required": 24.0,
			"water_available": 60.0,
			"sufficient": true,
		},
	}
	panel.bind(port_data, route_data, Callable(context, "translate"))
	var texts := _label_texts(panel)
	assert_true(_any_text_contains(texts, context.translate("ui.label.estimated_time")),
		"the panel should print the estimated travel time, got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("ui.label.voyage_supplies")),
		"the panel should print the supply estimate, got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("ui.label.coal")),
		"the panel should print the coal requirement, got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("risk." + VoyageCalculator.risk_label(0.42))),
		"the panel should print the risk band the query reported, got: %s" % str(texts))
	# 30 hours renders as "1 天 6 小时", not the raw float.
	assert_true(_any_text_contains(texts, context.translate("unit.days")),
		"the duration should use day/hour units, got: %s" % str(texts))

	# Short supplies: the panel still renders, but flags the shortfall.
	panel.bind(port_data, {
		"from": start_port.id,
		"to": neighbor_id,
		"distance": 120.0,
		"travel_hours": 12.0,
		"risk_level": 0.2,
		"risk_label": VoyageCalculator.risk_label(0.2),
		"supplies": {
			"coal_required": 90.0,
			"coal_available": 20.0,
			"water_required": 10.0,
			"water_available": 80.0,
			"sufficient": false,
		},
	}, Callable(context, "translate"))
	texts = _label_texts(panel)
	assert_true(_any_text_contains(texts, context.translate("ui.hint.supplies_short")),
		"a short supply estimate should warn, got: %s" % str(texts))

	# The query's band wins over the numeric fallback, so the chart and the voyage
	# page can never disagree about the same score.
	panel.bind(port_data, {
		"from": start_port.id, "to": neighbor_id, "distance": 120.0,
		"risk_level": 0.42, "risk_label": "medium",
	}, Callable(context, "translate"))
	texts = _label_texts(panel)
	assert_true(_any_text_contains(texts, context.translate("risk.medium")),
		"an explicit risk_label should override the numeric fallback, got: %s" % str(texts))

	# Unknown risk (no abstract-map route) must not look like zero risk.
	panel.bind(port_data, {"from": start_port.id, "to": neighbor_id, "distance": 120.0}, Callable(context, "translate"))
	texts = _label_texts(panel)
	assert_true(_any_text_contains(texts, context.translate("ui.label.risk_unknown")),
		"an unknown risk should be labelled as such, got: %s" % str(texts))
	assert_false(_any_text_contains(texts, context.translate("risk.low")),
		"an unknown risk must not be rendered as low risk, got: %s" % str(texts))
	panel.free()


func _label_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in root.get_children():
		if child is Label:
			texts.append(String((child as Label).text))
		texts.append_array(_label_texts(child))
	return texts


func _any_text_contains(texts: Array[String], needle: String) -> bool:
	if needle.is_empty():
		return false
	for text in texts:
		if text.contains(needle):
			return true
	return false


func test_sea_chart_query_fog_grid_downsampled() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var fog: Dictionary = data["fog"]

	assert_true(fog.has("cell_size"), "fog should have cell_size")
	assert_true(fog.has("width"), "fog should have width")
	assert_true(fog.has("height"), "fog should have height")
	assert_true(fog.has("alpha_grid"), "fog should have alpha_grid")
	assert_true(fog.has("state_grid"), "fog should have state_grid")

	var cell_size: float = float(fog["cell_size"])
	assert_true(cell_size > 0.0, "cell size should be positive")

	var width: int = int(fog["width"])
	var height: int = int(fog["height"])
	assert_true(width > 0 and height > 0, "grid dimensions should be positive")
	# Downsampled grid should be at most ~80 cells in each dimension
	assert_true(width <= 82, "downsampled width should be <= 82, got %d" % width)
	assert_true(height <= 82, "downsampled height should be <= 82, got %d" % height)

	var alpha_grid: Array = fog["alpha_grid"]
	assert_eq(alpha_grid.size(), height, "alpha grid height should match")
	for row in alpha_grid:
		assert_eq(row.size(), width, "alpha grid row width should match")
		for alpha in row:
			assert_true(float(alpha) >= 0.0 and float(alpha) <= 1.0, "alpha should be in [0, 1]")


## The chart must read the precomputed route table, not re-run pathfinding. Mutating a
## stored path to a sentinel proves the query is a reader: a recomputing query would
## ignore the sentinel and return the real curve.
func test_sea_chart_reads_precomputed_routes() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var world_dict: Dictionary = context.state.data["world_map"]
	var edges: Array = world_dict.get("edges", [])
	assert_true(edges.size() > 0, "generated worlds should carry a route table")

	# Pick any stored route between two discovered ports; both ends are in the fixture.
	var discovered: Array = context.state.campaign_world().get("discovered_port_ids", [])
	var target_index := -1
	for index in edges.size():
		var edge: Dictionary = edges[index]
		if discovered.has(String(edge.get("from", ""))) and discovered.has(String(edge.get("to", ""))):
			target_index = index
			break
	assert_true(target_index >= 0, "fixture should have a route between two discovered ports")

	const SENTINEL_X := 123.45
	const SENTINEL_Y := 234.56
	var sentinel_flat: Array = [SENTINEL_X, SENTINEL_Y, SENTINEL_X + 10.0, SENTINEL_Y + 10.0]
	edges[target_index]["path"] = sentinel_flat

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var target_edge: Dictionary = edges[target_index]
	var found := {}
	for route in data.get("routes", []):
		var from_id := String(route.get("from", ""))
		var to_id := String(route.get("to", ""))
		if (from_id == String(target_edge["from"]) and to_id == String(target_edge["to"])) \
				or (from_id == String(target_edge["to"]) and to_id == String(target_edge["from"])):
			found = route
			break
	assert_false(found.is_empty(), "the mutated route should still be listed")
	var points: Array = found.get("bezier_path", [])
	assert_true(points.size() >= 2, "route should expose a path")
	if points.size() >= 2:
		assert_almost_eq(float(points[0].get("x", 0.0)), SENTINEL_X, 0.01, "query should return the stored path, not a recomputed one")


## Worlds saved before the route table existed must still render: the query falls back to
## computing paths on the fly.
func test_legacy_world_without_route_table_still_renders() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var world_dict: Dictionary = context.state.data["world_map"]
	world_dict.erase("edges")

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var routes: Array = data.get("routes", [])
	assert_true(routes.size() > 0, "legacy worlds without a route table should still produce routes")
	for route in routes:
		var path: Array = route.get("bezier_path", [])
		assert_true(path.size() >= 2, "fallback routes should carry a path")
		assert_true(float(route.get("distance", 0.0)) > 0.0, "fallback routes should carry a distance")


func test_sea_chart_query_port_positions_within_bounds() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var ports: Array = data["ports"]
	# Ports are anchored to landmass coastlines; landmasses can extend slightly past
	# world.bounds (e.g. a continent straddling the western edge). Allow generous tolerance.
	for port_data in ports:
		var x: float = float(port_data["x"])
		var y: float = float(port_data["y"])
		var port_id: String = String(port_data["id"])
		assert_true(x >= -100.0 and x <= 500.0, "port %s x should be in reasonable range, got %.2f" % [port_id, x])
		assert_true(y >= -50.0 and y <= 450.0, "port %s y should be in reasonable range, got %.2f" % [port_id, y])


func test_sea_chart_query_no_run_returns_empty() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	# Don't set up any state - context.has_run() returns false

	var result := SeaChartViewQuery.execute({}, context)
	assert_true(result.has("ok"), "query should succeed")
	var data: Dictionary = result.get("data", {})
	assert_false(bool(data.get("has_run", true)), "has_run should be false")


func test_sea_chart_query_serialization_roundtrip() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})

	# Serialize to JSON
	var json := JSON.stringify(data)
	assert_true(json.length() > 0, "JSON should not be empty")

	# Parse back
	var parsed = JSON.parse_string(json)
	assert_true(parsed is Dictionary, "parsed JSON should be Dictionary")
	var parsed_dict: Dictionary = parsed as Dictionary
	assert_true(parsed_dict.has("world_bounds"), "parsed should have world_bounds")
	assert_true(parsed_dict.has("ports"), "parsed should have ports")
	assert_true(parsed_dict.has("routes"), "parsed should have routes")


func test_sea_chart_query_reproducible() -> void:
	var boot_a := bootstrap_core()
	var ctx_a: AppContext = boot_a["context"]
	_setup_world_and_state(SEED_A, ctx_a)
	var result_a := SeaChartViewQuery.execute({}, ctx_a)
	var data_a: Dictionary = result_a.get("data", {})

	var boot_b := bootstrap_core()
	var ctx_b: AppContext = boot_b["context"]
	_setup_world_and_state(SEED_A, ctx_b)
	var result_b := SeaChartViewQuery.execute({}, ctx_b)
	var data_b: Dictionary = result_b.get("data", {})

	var ports_a: Array = data_a["ports"]
	var ports_b: Array = data_b["ports"]
	assert_eq(ports_a.size(), ports_b.size(), "same seed should produce same port count")

	for i in mini(ports_a.size(), ports_b.size()):
		assert_almost_eq(float(ports_a[i]["x"]), float(ports_b[i]["x"]), 0.001, "port %d x should match" % i)
		assert_almost_eq(float(ports_a[i]["y"]), float(ports_b[i]["y"]), 0.001, "port %d y should match" % i)


func test_sea_chart_query_different_seeds_differ() -> void:
	var boot_a := bootstrap_core()
	var ctx_a: AppContext = boot_a["context"]
	_setup_world_and_state(SEED_A, ctx_a)
	var result_a := SeaChartViewQuery.execute({}, ctx_a)
	var data_a: Dictionary = result_a.get("data", {})

	var boot_b := bootstrap_core()
	var ctx_b: AppContext = boot_b["context"]
	_setup_world_and_state(SEED_B, ctx_b)
	var result_b := SeaChartViewQuery.execute({}, ctx_b)
	var data_b: Dictionary = result_b.get("data", {})

	var ports_a: Array = data_a["ports"]
	var ports_b: Array = data_b["ports"]

	# At least one port position should differ
	var all_same := true
	for i in mini(ports_a.size(), ports_b.size()):
		var dx := absf(float(ports_a[i]["x"]) - float(ports_b[i]["x"]))
		var dy := absf(float(ports_a[i]["y"]) - float(ports_b[i]["y"]))
		if dx > 1.0 or dy > 1.0:
			all_same = false
			break
	assert_false(all_same, "different seeds should produce different port positions")


func test_sea_chart_query_discovered_port_count() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})

	var ports: Array = data["ports"]
	var discovered_count: int = int(data.get("discovered_count", 0))

	# Start port should be discovered
	assert_true(ports.size() >= 1, "should have at least one discovered port")
	assert_true(discovered_count >= 1, "discovered count should be at least 1")


func test_sea_chart_query_archetype_names_valid() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var landmasses: Array = data["landmasses"]

	var valid_archetypes := ["continent", "large_island", "small_island", "atoll"]
	for lm in landmasses:
		var archetype: String = String(lm["archetype"])
		assert_true(valid_archetypes.has(archetype), "archetype '%s' should be valid" % archetype)


# ── Helpers ──

func _generate_world(seed_value: int, context: AppContext) -> Dictionary:
	var rng_service := RngService.new(seed_value)
	var hub: RegistryHub = context.registries
	var ship := {}
	return WorldGenerator.generate(TEST_PROFILE, hub, rng_service, ship)


func _setup_world_and_state(seed_value: int, context: AppContext) -> Dictionary:
	var result := _generate_world(seed_value, context)
	assert_true(bool(result.get("ok", false)), "world generation should succeed")

	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)
	var start_port := world.get_start_port()

	var state := GameState.new()
	state.data["world_map"] = world_dict
	state.data["current_port_id"] = start_port.id

	# Mark start port + one neighbor as discovered and visited, so route tests work
	var neighbors := WorldOps.neighbors(world, start_port.id)
	var discovered: Array = [start_port.id]
	var visited: Array = [start_port.id]
	if not neighbors.is_empty():
		discovered.append(String(neighbors[0]))
		visited.append(String(neighbors[0]))
	var campaign_world := state.campaign_world()
	campaign_world["discovered_port_ids"] = discovered
	campaign_world["visited_port_ids"] = visited

	context.set_state(state)
	return world_dict


## The chart and its panel must never render a raw content id: the query resolves the
## display keys for the archetype and the region so the UI can localize them.
func test_port_view_model_carries_display_name_keys() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_setup_world_and_state(SEED_A, context)

	var result := SeaChartViewQuery.execute({}, context)
	var data: Dictionary = result.get("data", {})
	var start_port_id := String(data.get("current_port_id", ""))
	var port_data := {}
	for entry in data.get("ports", []):
		if String(entry.get("id", "")) == start_port_id:
			port_data = entry
			break
	assert_false(port_data.is_empty(), "current port should be in the view model")

	var archetype_key := String(port_data.get("archetype_name_key", ""))
	var region_key := String(port_data.get("region_name_key", ""))
	assert_true(not archetype_key.is_empty(), "archetype_name_key should resolve for a Core archetype")
	assert_true(not region_key.is_empty(), "region_name_key should resolve from the world regions")
	assert_ne(archetype_key, String(port_data.get("archetype", "")), "name key must not be the raw archetype id")
	# Both keys must be real localization entries, not invented ones.
	assert_ne(context.translate(archetype_key), archetype_key, "archetype name key should have a translation")
	assert_ne(context.translate(region_key), region_key, "region name key should have a translation")


## Guards the departure tick unit handling: `departure_angle` is radians, and the chart
## used to convert it again as degrees, aiming every tick due east.
func test_departure_tick_direction_uses_radians() -> void:
	var view := SNSeaChartView.new()
	# PI/2 rad = north on a chart where +Y is south in screen space, so expect (0, 1).
	var north := view.exit_direction({"departure_angle": PI / 2.0})
	assert_almost_eq(north.x, 0.0, 0.001, "PI/2 radians should not point east")
	assert_almost_eq(north.y, 1.0, 0.001, "PI/2 radians should point along +Y")
	var east := view.exit_direction({"departure_angle": 0.0})
	assert_almost_eq(east.x, 1.0, 0.001, "0 radians should point along +X")
	assert_almost_eq(east.y, 0.0, 0.001, "0 radians should have no Y component")
	# A degree-style value (90) must not be misread as radians-looking-east.
	var degrees_like := view.exit_direction({"departure_angle": 90.0})
	assert_true(absf(degrees_like.y) < 0.999, "90 must not be treated as 90 degrees")
	view.free()


## Centring before the control has a size must be queued, not silently applied with a
## zero-size viewport (which would frame at the wrong zoom and lock `_needs_fit` off).
func test_center_on_port_before_layout_is_queued() -> void:
	var view := SNSeaChartView.new()
	var vm := {
		"has_run": true,
		"world_bounds": {"x": 0.0, "y": 0.0, "w": 400.0, "h": 400.0},
		"landmasses": [],
		"ports": [
			{"id": "port_a", "name_key": "port.a", "x": 120.0, "y": 240.0,
				"discovered": true, "visited": true, "current": true, "departure_angle": 0.0},
		],
		"routes": [],
		"fog": {},
		"current_port_id": "port_a",
		"ship_position": {"x": 120.0, "y": 240.0},
		"at_sea": false,
	}
	view.bind(vm)
	# No layout yet: the request has to wait for `_try_fit()`.
	view.center_on_port("port_a")
	assert_true(view._needs_fit, "an unlayouted centre request must keep the fit pending")

	view.size = Vector2(800.0, 600.0)
	view._try_fit()
	var on_screen := view.world_to_screen(Vector2(120.0, 240.0))
	assert_almost_eq(on_screen.x, 400.0, 1.0, "queued centre should place the port at the viewport centre (x)")
	assert_almost_eq(on_screen.y, 300.0, 1.0, "queued centre should place the port at the viewport centre (y)")
	assert_false(view._needs_fit, "fit should be resolved once layout exists")
	view.free()


## 验收反馈 F3：航行页的海图按 cover 铺满窗口（世界边界外画成开阔水面，不再是
## 中间一块方形），同时航线包围盒（含起终港）必须留在视野里。
func test_presentation_framing_fills_the_window_and_keeps_the_route_visible() -> void:
	var view := SNSeaChartView.new()
	view.bind(_presentation_vm())
	# 航线贴着世界中心：铺满后整幅世界仍能盖住窗口，不需要为了航线退让。
	var route := PackedVector2Array([
		Vector2(120.0, 190.0), Vector2(200.0, 196.0), Vector2(280.0, 205.0),
	])
	view.set_presentation_mode(true, route)
	view.size = Vector2(1440.0, 700.0)
	view._try_fit()

	assert_true(view.is_presentation_mode(), "the at-sea page asks for the presentation framing")
	var cover := maxf(1440.0 / 400.0, 700.0 / 400.0)
	assert_almost_eq(view.get_base_zoom(), cover, 0.01,
		"the chart fills the window (cover), not the letterboxed table fit")
	var top_left := view.world_to_screen(Vector2(0.0, 0.0))
	var bottom_right := view.world_to_screen(Vector2(400.0, 400.0))
	assert_almost_eq(top_left.x, 0.0, 0.5, "the world starts at the left window edge")
	assert_almost_eq(bottom_right.x, 1440.0, 0.5, "the world ends at the right window edge")
	assert_true(top_left.y <= 0.5, "the chart covers the top edge")
	assert_true(bottom_right.y >= 699.5, "the chart covers the bottom edge")
	# 起终港都不能被铺满裁掉。
	for point in [route[0], route[route.size() - 1]]:
		var screen := view.world_to_screen(point)
		assert_true(screen.x >= 0.0 and screen.x <= 1440.0 and screen.y >= 0.0 and screen.y <= 700.0,
			"the route endpoint stays inside the window: %s" % str(screen))

	# 演出倍数：>1 = 近景，1 = 严格回到上面的稳态取景；倍数变化时不重排稳态。
	view.set_frame_scale(2.8)
	assert_almost_eq(view.get_zoom(), cover * 2.8, 0.01, "the near shot scales the steady framing")
	view.set_frame_scale(1.0)
	assert_almost_eq(view.get_zoom(), cover, 0.01, "framing scale 1 returns to the steady shot")
	view.free()


## 铺满不能以裁掉航线为代价：航线比窗口高时退回「装得下整条航线」的缩放，
## 世界边界外的余下部分由演出取景画成开阔水面。
func test_presentation_framing_gives_way_to_a_long_route() -> void:
	var view := SNSeaChartView.new()
	view.bind(_presentation_vm())
	var route := PackedVector2Array([Vector2(60.0, 10.0), Vector2(340.0, 390.0)])
	view.set_presentation_mode(true, route)
	view.size = Vector2(1440.0, 700.0)
	view._try_fit()

	var route_zoom := minf(
		1440.0 / (route[1].x - route[0].x + SNSeaChartView.PRESENTATION_MARGIN * 2.0),
		700.0 / (route[1].y - route[0].y + SNSeaChartView.PRESENTATION_MARGIN * 2.0)
	)
	assert_almost_eq(view.get_base_zoom(), route_zoom, 0.01,
		"a route longer than the window falls back to a zoom that fits the whole route")
	for point in [route[0], route[1]]:
		var screen := view.world_to_screen(point)
		assert_true(screen.x >= 0.0 and screen.x <= 1440.0 and screen.y >= 0.0 and screen.y <= 700.0,
			"both route endpoints stay visible at the fallback zoom: %s" % str(screen))
	view.free()


## 孪生世界可能很小（真实对局里见过 160 单位见方的世界），铺满 1440 px 需要
## ×9。演出的取景不能被手动缩放的 ZOOM_MAX 卡住，否则小世界又会缩回一块方形。
func test_presentation_framing_ignores_the_manual_zoom_cap() -> void:
	var view := SNSeaChartView.new()
	var vm := _presentation_vm()
	vm["world_bounds"] = {"x": 0.0, "y": 0.0, "w": 160.0, "h": 160.0}
	for port_data in vm["ports"]:
		(port_data as Dictionary)["x"] = float((port_data as Dictionary)["x"]) * 0.4
		(port_data as Dictionary)["y"] = float((port_data as Dictionary)["y"]) * 0.4
	var route := PackedVector2Array([Vector2(48.0, 76.0), Vector2(112.0, 82.0)])
	view.bind(vm)
	view.set_presentation_mode(true, route)
	view.size = Vector2(1440.0, 810.0)
	view._try_fit()

	var cover := maxf(1440.0 / 160.0, 810.0 / 160.0)
	assert_almost_eq(view.get_base_zoom(), cover, 0.01,
		"a small world is scaled past ZOOM_MAX so the chart still fills the window")
	assert_true(view.get_base_zoom() > SNSeaChartView.ZOOM_MAX,
		"the presentation framing is not limited by the manual zoom cap")
	var top_left := view.world_to_screen(Vector2(0.0, 0.0))
	var bottom_right := view.world_to_screen(Vector2(160.0, 160.0))
	assert_almost_eq(top_left.x, 0.0, 0.5, "the small world starts at the left window edge")
	assert_almost_eq(bottom_right.x, 1440.0, 0.5, "the small world ends at the right window edge")
	assert_true(top_left.y <= 0.5 and bottom_right.y >= 809.5, "the chart covers the window height")
	view.free()


## 船 icon 是船形而不是固定菱形：艏尖在本地 +X，按 heading 旋转后船头朝移动方向。
func test_ship_icon_points_along_its_heading() -> void:
	var shape := SNSeaChartView.ship_icon_shape(10.0)
	assert_eq(shape.size(), 6, "the marker is a six-point hull outline")
	var bow := shape[0]
	assert_true(bow.x > 10.0, "the bow is the long-axis tip at +X")
	for index in range(1, shape.size()):
		assert_true(shape[index].x < bow.x, "every other hull point sits behind the bow")
	# Chart space is +Y down, so a heading of +PI/2 (world south) must point down.
	var south := bow.rotated(PI / 2.0)
	assert_almost_eq(south.angle(), PI / 2.0, 0.001, "rotating by the heading aims the bow")
	assert_true(south.y > 10.0 and absf(south.x) < 0.01, "world +Y points down on the chart")

	var view := SNSeaChartView.new()
	view.set_ship_pose(Vector2(10.0, 20.0), -PI / 2.0)
	assert_true(view.has_ship_heading(), "a pose carries a real heading")
	assert_almost_eq(view.get_ship_heading(), -PI / 2.0, 0.0001, "the chart keeps the heading it was fed")
	view.set_ship_position(Vector2(30.0, 40.0))
	assert_almost_eq(view.get_ship_heading(), -PI / 2.0, 0.0001,
		"plain position updates keep the last known heading instead of snapping to 0")
	view.free()


func _presentation_vm() -> Dictionary:
	return {
		"has_run": true,
		"world_bounds": {"x": 0.0, "y": 0.0, "w": 400.0, "h": 400.0},
		"landmasses": [],
		"ports": [
			{"id": "port_a", "name_key": "port.a", "x": 120.0, "y": 190.0,
				"discovered": true, "visited": true, "current": true, "departure_angle": 0.0},
			{"id": "port_b", "name_key": "port.b", "x": 280.0, "y": 205.0,
				"discovered": false, "visited": false, "current": false, "departure_angle": 0.0},
		],
		"routes": [],
		"fog": {},
		"current_port_id": "port_a",
		"ship_position": {"x": 120.0, "y": 190.0},
		"at_sea": true,
	}


## The full-screen chart page (phase 2 entry integration) composes the real view
## and panel: `bind()` feeds the query result through, clicking a port selects it
## and fills the panel, and the panel's depart button bubbles up as
## `voyage_requested(port_id)` for the Shell to route to the voyage page.
func test_sea_chart_screen_binds_chart_and_panel() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var world_dict := _setup_world_and_state(SEED_A, context)
	var world := WorldMap.from_dict(world_dict)
	var start_port := world.get_start_port()
	var neighbor_id := String(WorldOps.neighbors(world, start_port.id)[0])

	var result := SeaChartViewQuery.execute({}, context)
	var vm: Dictionary = result.get("data", {})

	var screen: Control = SEA_CHART_SCREEN_SCRIPT.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.bind(vm, Callable(context, "translate"))

	var chart := _find_descendant(screen, func(node: Node) -> bool: return node is SNSeaChartView) as SNSeaChartView
	var panel := _find_descendant(screen, func(node: Node) -> bool: return node is SNSeaChartPanel) as SNSeaChartPanel
	assert_not_null(chart, "the screen should mount a sea chart view")
	assert_not_null(panel, "the screen should mount a sea chart panel")
	assert_eq((chart.view_model.get("ports", []) as Array).size(), 2,
		"the chart should bind exactly the discovered ports")

	# The current harbour is preselected; the panel shows it without a route.
	assert_eq(chart._selected_port, String(vm.get("current_port_id", "")),
		"the screen should preselect the current port")
	assert_false(panel._port_data.is_empty(),
		"the panel should bind the preselected port")

	# Clicking the neighbour selects it and rebinds the panel to that port.
	screen._on_port_clicked(neighbor_id)
	assert_eq(chart._selected_port, neighbor_id, "clicking a port should select it")
	assert_eq(String(panel._port_data.get("id", "")), neighbor_id,
		"the panel should bind the clicked port")

	# The panel's depart button bubbles up as voyage_requested(port_id).
	var received: Array = []
	screen.voyage_requested.connect(func(port_id: String) -> void: received.append(port_id))
	var depart := _find_descendant(screen, func(node: Node) -> bool:
		return node is Button and String((node as Button).text) == String(context.translate("ui.button.start_voyage"))
	)
	assert_not_null(depart, "a selected remote port should expose the depart button")
	(depart as Button).pressed.emit()
	assert_eq(received, [neighbor_id], "the depart button should emit voyage_requested(port_id)")

	screen.free()


func _find_descendant(root: Node, predicate: Callable) -> Node:
	for child in root.get_children():
		if bool(predicate.call(child)):
			return child
		var found := _find_descendant(child, predicate)
		if found != null:
			return found
	return null


# ── Exploration phase 4.1: clues / unknown destination ──

const CLUE_VM := {
	"has_run": true,
	"world_bounds": {"x": 0.0, "y": 0.0, "w": 400.0, "h": 400.0},
	"landmasses": [],
	"ports": [
		{"id": "port_a", "name_key": "port.a", "x": 120.0, "y": 140.0,
			"discovered": true, "visited": true, "current": true, "departure_angle": 0.0},
	],
	"routes": [],
	"fog": {},
	"current_port_id": "port_a",
	"ship_position": {"x": 120.0, "y": 140.0},
	"at_sea": false,
	"clues": [
		{
			"id": "clue:1", "source_key": "rumor", "source_display_key": "ui.clue.source.rumor",
			"level": 2, "reference_port_id": "port_a", "direction_angle": 0.0,
			"distance_min_hours": 4.0, "distance_max_hours": 9.0, "circle": null, "name_key": "",
		},
		{
			"id": "clue:2", "source_key": "rumor", "source_display_key": "ui.clue.source.rumor",
			"level": 2, "reference_port_id": "missing_port", "direction_angle": 0.0,
			"distance_min_hours": 4.0, "distance_max_hours": 9.0, "circle": null, "name_key": "",
		},
		{
			"id": "clue:3", "source_key": "intel", "source_display_key": "ui.clue.source.intel",
			"level": 3, "reference_port_id": "port_a", "direction_angle": 0.5,
			"distance_min_hours": 6.0, "distance_max_hours": 11.0,
			"circle": {"x": 200.0, "y": 200.0, "radius": 14.0}, "name_key": "",
		},
		{
			"id": "clue:4", "source_key": "intel", "source_display_key": "ui.clue.source.intel",
			"level": 4, "reference_port_id": "port_a", "direction_angle": 0.5,
			"distance_min_hours": 6.0, "distance_max_hours": 11.0,
			"circle": {"x": 300.0, "y": 260.0, "radius": 14.0},
			"name_key": "port_name.core.mist_cove",
		},
	],
	"explore": {"active": false, "clue_id": ""},
	"can_buy_clue": {"available": false, "cost": 40, "reason_key": ""},
}


## 线索几何是纯函数：方向箭头按世界弧度换算终点，虚线圆按 zoom/offset 换算屏幕
## 圆心与半径；点击命中对箭头线段、圆环与圆心都留 12 px 容差。
func test_clue_geometry_helpers_and_hit_test() -> void:
	var origin := Vector2(100.0, 100.0)
	var east := SNSeaChartView.clue_arrow_endpoint(origin, 0.0, 40.0)
	assert_almost_eq(east.x, 140.0, 0.001, "angle 0 points along +X (chart east)")
	assert_almost_eq(east.y, 100.0, 0.001, "angle 0 keeps y")
	# 图表 +Y 朝下 = 南；PI/2 的箭头必须朝下而不是被当成角度。
	var south := SNSeaChartView.clue_arrow_endpoint(origin, PI / 2.0, 40.0)
	assert_almost_eq(south.x, 100.0, 0.001, "angle PI/2 has no x component")
	assert_almost_eq(south.y, 140.0, 0.001, "angle PI/2 points along +Y")
	assert_almost_eq(south.distance_to(origin), 40.0, 0.001, "the arrow keeps its world length")

	var circle := SNSeaChartView.clue_circle_screen(
		Vector2(50.0, 60.0), 12.0, 2.0, Vector2(10.0, 20.0)
	)
	var circle_center: Vector2 = circle["center"]
	assert_almost_eq(circle_center.x, 110.0, 0.001, "circle centre x = world * zoom + offset")
	assert_almost_eq(circle_center.y, 140.0, 0.001, "circle centre y = world * zoom + offset")
	assert_almost_eq(float(circle["radius"]), 24.0, 0.001, "radius scales with zoom")

	var arrow := {"kind": "arrow", "start": Vector2(0.0, 0.0), "end": Vector2(100.0, 0.0)}
	assert_true(SNSeaChartView.clue_hit_test(Vector2(50.0, 8.0), arrow),
		"a click 8 px off the arrow shaft is still a hit")
	assert_false(SNSeaChartView.clue_hit_test(Vector2(50.0, 30.0), arrow),
		"a click 30 px off the arrow is not a hit")
	var ring := {"kind": "circle", "center": Vector2(200.0, 200.0), "radius": 30.0}
	assert_true(SNSeaChartView.clue_hit_test(Vector2(230.0, 200.0), ring),
		"clicking the dashed ring hits the clue")
	assert_true(SNSeaChartView.clue_hit_test(Vector2(203.0, 200.0), ring),
		"clicking the circle centre (the ? marker) hits the clue")
	assert_false(SNSeaChartView.clue_hit_test(Vector2(260.0, 200.0), ring),
		"a click far outside the circle misses")
	assert_false(SNSeaChartView.clue_hit_test(Vector2(10.0, 10.0), {}),
		"an unrenderable clue never reports a hit")


## 八方位换算：世界弧度 0 = 东，+Y 朝下 = 南。面板与海图共用这个映射。
func test_clue_compass_key_conversion() -> void:
	assert_eq(SNSeaChartPanel.compass_key(0.0), "E", "0 rad is east")
	assert_eq(SNSeaChartPanel.compass_key(PI / 4.0), "SE", "45 deg is south-east")
	assert_eq(SNSeaChartPanel.compass_key(PI / 2.0), "S", "90 deg is south (+Y down)")
	assert_eq(SNSeaChartPanel.compass_key(PI), "W", "180 deg is west")
	assert_eq(SNSeaChartPanel.compass_key(-PI / 2.0), "N", "-90 deg is north")
	assert_eq(SNSeaChartPanel.compass_key(TAU + PI / 4.0), "SE", "angles wrap around")


## 视图绑定线索后：level 2 从存在的参照港画出箭头（缺失参照港跳过），level 3/4
## 换算虚线圆；选中线索与选中港口互斥。
func test_clue_view_geometry_and_selection() -> void:
	var view := SNSeaChartView.new()
	view.bind(CLUE_VM)
	view.size = Vector2(800.0, 600.0)
	view._try_fit()

	assert_eq(view.get_clues().size(), 4, "all clues enter the view model")
	assert_eq(String(view.clue_by_id("clue:1").get("id", "")), "clue:1", "clues are addressable by id")

	var arrow := view.clue_screen_geometry(view.clue_by_id("clue:1"))
	assert_eq(String(arrow.get("kind", "")), "arrow", "a level-2 clue draws a direction arrow")
	var expected_end := view.world_to_screen(SNSeaChartView.clue_arrow_endpoint(
		Vector2(120.0, 140.0), 0.0, SNSeaChartView.CLUE_ARROW_LENGTH
	))
	var arrow_end: Vector2 = arrow["end"]
	assert_almost_eq(arrow_end.x, expected_end.x, 0.01, "the arrow endpoint is the projected helper value")
	assert_almost_eq(arrow_end.y, expected_end.y, 0.01, "the arrow endpoint is the projected helper value")

	assert_true(view.clue_screen_geometry(view.clue_by_id("clue:2")).is_empty(),
		"a clue whose reference port is not on the chart is skipped instead of drawn at (0,0)")

	var ring := view.clue_screen_geometry(view.clue_by_id("clue:3"))
	assert_eq(String(ring.get("kind", "")), "circle", "a level-3 clue draws a dashed circle")
	var ring_center: Vector2 = ring["center"]
	assert_almost_eq(ring_center.x, view.world_to_screen(Vector2(200.0, 200.0)).x, 0.01,
		"the circle centre comes from the clue's world circle")
	assert_almost_eq(float(ring["radius"]), 14.0 * view.get_zoom(), 0.01,
		"the circle radius is world radius × zoom")
	assert_false(view.clue_screen_geometry(view.clue_by_id("clue:4")).is_empty(),
		"a level-4 clue also draws its circle")

	view.select_clue("clue:3")
	assert_eq(view.get_selected_clue(), "clue:3", "select_clue stores the selection")
	assert_eq(view.get_selected_port(), "", "selecting a clue clears the port selection")
	view.select_port("port_a")
	assert_eq(view.get_selected_port(), "port_a", "select_port stores the port")
	assert_eq(view.get_selected_clue(), "", "selecting a port clears the clue selection")

	# 点击虚线圆环 → clue_clicked(id) 且视图高亮该线索。
	var received: Array = []
	view.clue_clicked.connect(func(clue_id: String) -> void: received.append(clue_id))
	var ring_point: Vector2 = ring_center + Vector2(float(ring["radius"]), 0.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = ring_point
	view._gui_input(click)
	assert_eq(received, ["clue:3"], "clicking the dashed circle emits clue_clicked(clue_id)")
	assert_eq(view.get_selected_clue(), "clue:3", "the clicked clue becomes the highlighted clue")
	view.free()


## level 4 的圆内文字是 `？<翻译后的港口名>？`；缺键/缺回调时退回 `?`，绝不渲染键名。
func test_clue_name_text_localizes_and_falls_back() -> void:
	var view := SNSeaChartView.new()
	view.bind(CLUE_VM, func(key: String) -> String:
		return "雾湾" if key == "port_name.core.mist_cove" else key
	)
	assert_eq(view._clue_name_text("port_name.core.mist_cove"), "？雾湾？",
		"the level-4 label wraps the translated port name")
	assert_eq(view._clue_name_text(""), "?", "a missing name key falls back to ?")
	var untranslated := SNSeaChartView.new()
	untranslated.bind(CLUE_VM)
	assert_eq(untranslated._clue_name_text("port_name.core.mist_cove"), "?",
		"a key without a translation must not leak into the chart label")
	untranslated.free()
	view.free()


## 探索演出：未知终点（搜索区中心）能从视图里存取，并在清空后不再绘制。
func test_unknown_destination_roundtrip() -> void:
	var view := SNSeaChartView.new()
	view.bind(CLUE_VM)
	assert_false(view.has_unknown_destination(), "a normal voyage has no unknown destination")
	view.set_unknown_destination(Vector2(300.0, 220.0), "ui.label.unknown_destination")
	assert_true(view.has_unknown_destination(), "the exploration destination is stored")
	var stored := view.get_unknown_destination()
	assert_almost_eq(float(stored.get("x", 0.0)), 300.0, 0.001, "x is kept")
	assert_almost_eq(float(stored.get("y", 0.0)), 220.0, 0.001, "y is kept")
	assert_eq(String(stored.get("label_key", "")), "ui.label.unknown_destination",
		"the label key is kept for the ? marker")
	view.clear_unknown_destination()
	assert_false(view.has_unknown_destination(), "clear_unknown_destination removes it")
	view.free()


## 验收反馈：探索航行的 `?` 终点曾被顶栏整个盖住。未知终点标记必须 clamp 进
## 「顶栏以下 + 左右/下留边」的可见区；正常在可见区的标记不应被移动。
func test_unknown_destination_marker_is_clamped_below_the_hud() -> void:
	var view_size := Vector2(1440.0, 900.0)
	var hidden := SNSeaChartView.clamp_marker_to_view(Vector2(720.0, 58.0), view_size, 115.0)
	assert_true(hidden.y >= 115.0 + 26.0 - 0.01,
		"a marker under the top chrome is pushed below it: %s" % str(hidden))
	assert_almost_eq(hidden.x, 720.0, 0.01, "clamping only moves the axis that was hidden")
	var visible := SNSeaChartView.clamp_marker_to_view(Vector2(400.0, 500.0), view_size, 115.0)
	assert_true(visible.is_equal_approx(Vector2(400.0, 500.0)),
		"a marker already inside the visible area is left alone")
	var corner := SNSeaChartView.clamp_marker_to_view(Vector2(1439.0, 899.0), view_size, 0.0)
	assert_true(corner.x <= 1440.0 - 26.0 + 0.01 and corner.y <= 900.0 - 26.0 + 0.01,
		"a marker beyond the bottom-right keeps a readable margin: %s" % str(corner))
	# 存档的 inset 随终点一起保留，绘制时才能用同一套 clamp。
	var view := SNSeaChartView.new()
	view.set_unknown_destination(Vector2(10.0, 10.0), "ui.label.unknown_destination", 140.0)
	assert_almost_eq(float(view.get_unknown_destination().get("top_inset", 0.0)), 140.0, 0.001,
		"the top inset travels with the unknown destination")
	view.free()


## 面板线索区块：来源/等级/方位/航程区间/预计值，出航与购买按钮各自发信号；
## 不可行时按钮禁用并列出 blockers 的 message_key。
func test_sea_chart_panel_renders_clue_section() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var panel := SNSeaChartPanel.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	panel.set_can_buy_clue({"available": true, "cost": 40, "reason_key": ""})
	var explored: Array = []
	var purchased: Array = []
	panel.explore_requested.connect(func(clue_id: String) -> void: explored.append(clue_id))
	panel.purchase_clue_requested.connect(func() -> void: purchased.append(true))

	var clue := {
		"id": "clue:1",
		"source_key": "intel",
		"source_display_key": "ui.clue.source.intel",
		"level": 4,
		"reference_port_id": "port_a",
		"direction_angle": PI / 2.0,
		"distance_min_hours": 10.0,
		"distance_max_hours": 18.0,
		"circle": {"x": 200.0, "y": 200.0, "radius": 14.0},
		"name_key": "port_name.core.mist_cove",
		"estimated": {
			"feasible": true,
			"blockers": [],
			"duration_hours": 12.0,
			"coal_required": 10.0,
			"water_required": 8.0,
			"risk_score": 0.3,
			"discovery_chance": 0.6,
		},
	}
	panel.bind_clue(clue, Callable(context, "translate"))
	var texts := _label_texts(panel)
	assert_true(_any_text_contains(texts, context.translate("ui.clue.section_title")),
		"the panel shows the clue section title, got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("ui.clue.reliability_hint") % context.translate("ui.clue.source.intel")),
		"the panel shows the source (reliability hint), got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("ui.clue.level.4")),
		"the panel shows the level text, got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("ui.clue.direction.S")),
		"PI/2 is south, got: %s" % str(texts))
	assert_true(_any_text_contains(texts,
		context.translate("ui.clue.distance_range") % [10, 18]),
		"the panel shows the distance range, got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("ui.label.estimated_time")),
		"the panel shows the estimated duration, got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("ui.label.coal")),
		"the panel shows the coal estimate, got: %s" % str(texts))
	assert_true(_any_text_contains(texts, context.translate("risk." + VoyageCalculator.risk_label(0.3))),
		"the panel shows the risk band, got: %s" % str(texts))

	var explore_button := _find_descendant(panel, func(node: Node) -> bool:
		return node is Button and String((node as Button).text) == String(context.translate("ui.button.explore_clue"))
	) as Button
	assert_not_null(explore_button, "an explore button is present")
	if explore_button != null:
		explore_button.pressed.emit()
	assert_eq(explored, ["clue:1"], "the explore button emits explore_requested(clue_id)")
	var purchase := _find_descendant(panel, func(node: Node) -> bool:
		return node is Button and String((node as Button).name) == "PurchaseClueButton"
	) as Button
	assert_not_null(purchase, "can_buy_clue.available shows the purchase entry")
	if purchase != null:
		purchase.pressed.emit()
	assert_eq(purchased.size(), 1, "the purchase entry emits purchase_clue_requested")

	# 不可行：按钮禁用并逐条列出 blockers 的 message_key。
	var blocked := clue.duplicate(true)
	blocked["estimated"] = {
		"feasible": false,
		"blockers": [{"code": "insufficient_money", "message_key": "ui.error.insufficient_money"}],
		"duration_hours": 12.0, "coal_required": 999.0, "water_required": 0.0,
		"risk_score": 0.3, "discovery_chance": 0.6,
	}
	panel.bind_clue(blocked, Callable(context, "translate"))
	texts = _label_texts(panel)
	assert_true(_any_text_contains(texts, context.translate("ui.error.insufficient_money")),
		"an infeasible clue lists the blocker message, got: %s" % str(texts))
	explore_button = _find_descendant(panel, func(node: Node) -> bool:
		return node is Button and String((node as Button).text) == String(context.translate("ui.button.explore_clue"))
	) as Button
	assert_not_null(explore_button, "the explore button stays visible for an infeasible clue")
	if explore_button != null:
		assert_true(explore_button.disabled, "an infeasible clue disables the explore button")
	panel.free()


## 整页接线：图上点线索 → 面板切到线索区块；线索的 explore_requested 由屏幕原样
## 转发（Shell 再接 explore.start）。
func test_sea_chart_screen_binds_clue_panel_and_forwards_signals() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var vm: Dictionary = CLUE_VM.duplicate(true)
	vm["can_buy_clue"] = {"available": true, "cost": 40, "reason_key": ""}
	var screen: Control = SEA_CHART_SCREEN_SCRIPT.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.bind(vm, Callable(context, "translate"))
	var chart := _find_descendant(screen, func(node: Node) -> bool: return node is SNSeaChartView) as SNSeaChartView
	var panel := _find_descendant(screen, func(node: Node) -> bool: return node is SNSeaChartPanel) as SNSeaChartPanel
	assert_not_null(chart, "the screen mounts the chart view")
	assert_not_null(panel, "the screen mounts the panel")

	# 视图发信号（真实鼠标路径由 test_clue_view_geometry_and_selection 覆盖）。
	chart.clue_clicked.emit("clue:3")
	assert_eq(String(panel.get_clue().get("id", "")), "clue:3",
		"a chart clue click binds the clue into the panel")
	assert_eq(chart.get_selected_clue(), "clue:3", "the chart keeps the clue selection")

	# 面板出航按钮 → 屏幕 explore_requested(clue_id)。
	var forwarded: Array = []
	screen.explore_requested.connect(func(clue_id: String) -> void: forwarded.append(clue_id))
	var button := _find_descendant(screen, func(node: Node) -> bool:
		return node is Button and String((node as Button).text) == String(context.translate("ui.button.explore_clue"))
	) as Button
	assert_not_null(button, "the clue panel exposes its explore button")
	if button != null:
		button.pressed.emit()
	assert_eq(forwarded, ["clue:3"], "the screen forwards explore_requested(clue_id)")

	# 购买入口：屏幕把 view model 的 can_buy_clue 塞给面板。
	assert_not_null(_find_descendant(screen, func(node: Node) -> bool:
		return node is Button and String((node as Button).name) == "PurchaseClueButton"
	), "the screen wires can_buy_clue into the panel")
	screen.free()
