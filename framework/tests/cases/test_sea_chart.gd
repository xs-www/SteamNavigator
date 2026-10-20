extends TestCase
class_name TestSeaChart
## @static-doc
## 作用：海图系统（阶段 2）的无头测试，验证 `sea_chart.view` 查询的输出结构、
## 陆地/港口/航线/迷雾数据正确性，以及同 seed 可复现性与 JSON 序列化往返。
##
## ## 契约与约束
## - 每个用例通过 `bootstrap_core()` 获得真实 Core 注册表，再用内联 `TEST_PROFILE`
##   生成世界；测试不实例化任何 UI 节点，只断言查询输出的纯数据。
## - `_setup_world_and_state()` 把起始港与其首个邻居标为已发现/已访问，
##   使航线用例具备两端可见的前提。
## - 港口坐标断言使用宽松范围：大陆可能跨出 `world.bounds`，港口锚定在海岸线上。
## @end-static-doc

const SEED_A := 12345
const SEED_B := 67890
const TEST_PROFILE := {
	"world_size": 400.0,
	"min_ports": 10,
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
		{"archetype_id": "core:port_archetype/iron_harbor", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.2, "name_key": "port_name.core.iron_harbor", "is_start": true},
		{"archetype_id": "port_archetype_2", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.4, "name_key": "port.spice_harbor"},
		{"archetype_id": "port_archetype_3", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.6, "name_key": "port.free_town"},
		{"archetype_id": "port_archetype_4", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.8, "name_key": "port.fishing_village", "required_tags": ["port.intelligence"]},
		{"archetype_id": "port_archetype_5", "region_id": "mid_coast_1", "landmass_id": "iron_island", "coast_t": 0.5, "name_key": "port.iron_port"},
		{"archetype_id": "port_archetype_6", "region_id": "mid_coast_2", "landmass_id": "spice_islands", "coast_t": 0.3, "name_key": "port.glass_port"},
		{"archetype_id": "port_archetype_7", "region_id": "mid_coast_2", "landmass_id": "spice_islands", "coast_t": 0.7, "name_key": "port.south_station"},
		{"archetype_id": "port_archetype_8", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.2, "name_key": "port.north_outpost"},
		{"archetype_id": "port_archetype_9", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.8, "name_key": "port.ice_wind"},
		{"archetype_id": "port_archetype_10", "region_id": "start_coast", "landmass_id": "coral_reef", "coast_t": 0.5, "name_key": "port.coral_station"},
		{"archetype_id": "port_archetype_11", "region_id": "ocean_1", "landmass_id": "fog_reef", "coast_t": 0.5, "name_key": "port.fog_lighthouse"},
		{"archetype_id": "port_archetype_12", "region_id": "mid_coast_2", "landmass_id": "south_wind", "coast_t": 0.5, "name_key": "port.south_wind_port"},
		{"archetype_id": "port_archetype_13", "region_id": "start_coast", "landmass_id": "glass_atoll", "coast_t": 0.5, "name_key": "port.glass_atoll_port"},
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
