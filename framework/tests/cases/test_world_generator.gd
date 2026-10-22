extends TestCase
class_name TestWorldGenerator
## Tests for the new coordinate-space world generation system.
##
## Covers: reproducibility, port distribution, landmass generation,
## connectivity, Bezier routes, and departure angles.

const SEED_A := 12345
const SEED_B := 67890
## Fixture for the design-frozen world size (NAUTICAL_CHART_SYSTEM.md §2.2/§12):
## 18 ports on 11 landmasses across four regions. `min_ports` mirrors the formal
## profile so the generator has to place all of them instead of silently
## producing a smaller world.
const TEST_PORT_COUNT := 18
const TEST_PROFILE := {
	"world_size": 400.0,
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
	# 18 ports: 6 on the home continent (dense starting coast), 3 around the
	# mid-coast islands, 3 in the open ocean, 4 on the small islands, 2 atolls.
	"ports": [
		{"archetype_id": "port_template_1", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.10, "name_key": "port.iron_harbor", "is_start": true, "required_tags": ["port.shipyard"]},
		{"archetype_id": "port_template_2", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.24, "name_key": "port.spice_harbor"},
		{"archetype_id": "port_template_3", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.38, "name_key": "port.free_town"},
		{"archetype_id": "port_template_4", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.52, "name_key": "port.fishing_village", "required_tags": ["port.intelligence"]},
		{"archetype_id": "port_template_5", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.68, "name_key": "port.iron_port"},
		{"archetype_id": "port_template_6", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.84, "name_key": "port.glass_port"},
		{"archetype_id": "port_template_7", "region_id": "mid_coast_1", "landmass_id": "iron_island", "coast_t": 0.20, "name_key": "port.south_station"},
		{"archetype_id": "port_template_8", "region_id": "mid_coast_1", "landmass_id": "iron_island", "coast_t": 0.55, "name_key": "port.north_outpost"},
		{"archetype_id": "port_template_9", "region_id": "mid_coast_1", "landmass_id": "iron_island", "coast_t": 0.88, "name_key": "port.ice_wind"},
		{"archetype_id": "port_template_10", "region_id": "mid_coast_2", "landmass_id": "spice_islands", "coast_t": 0.25, "name_key": "port.coral_station"},
		{"archetype_id": "port_template_11", "region_id": "mid_coast_2", "landmass_id": "spice_islands", "coast_t": 0.72, "name_key": "port.fog_lighthouse"},
		{"archetype_id": "port_template_12", "region_id": "mid_coast_2", "landmass_id": "south_wind", "coast_t": 0.40, "name_key": "port.south_wind_port"},
		{"archetype_id": "port_template_13", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.18, "name_key": "port.glass_atoll_port"},
		{"archetype_id": "port_template_14", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.50, "name_key": "port.mist_cove"},
		{"archetype_id": "port_template_15", "region_id": "ocean_1", "landmass_id": "north_island", "coast_t": 0.85, "name_key": "port.bone_harbor"},
		{"archetype_id": "port_template_16", "region_id": "start_coast", "landmass_id": "coral_reef", "coast_t": 0.35, "name_key": "port.reef_haven"},
		{"archetype_id": "port_template_17", "region_id": "start_coast", "landmass_id": "glass_atoll", "coast_t": 0.50, "name_key": "port.atoll_haven"},
		{"archetype_id": "port_template_18", "region_id": "ocean_1", "landmass_id": "moon_atoll", "coast_t": 0.50, "name_key": "port.moon_haven"},
	],
}


func test_same_seed_produces_identical_world() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var rng_service: RngService = context.rng

	var result_a := _generate_world(SEED_A, context)
	var result_b := _generate_world(SEED_A, context)

	assert_true(bool(result_a.get("ok", false)), "seed A first attempt should succeed")
	assert_true(bool(result_b.get("ok", false)), "seed A second attempt should succeed")

	var world_a: Dictionary = result_a.get("world_map", {})
	var world_b: Dictionary = result_b.get("world_map", {})
	assert_eq(world_a.size(), world_b.size(), "world maps should have same size")

	var ports_a: Array = world_a.get("ports", [])
	var ports_b: Array = world_b.get("ports", [])
	assert_eq(ports_a.size(), ports_b.size(), "port counts should match")

	for i in ports_a.size():
		var port_a: Dictionary = ports_a[i]
		var port_b: Dictionary = ports_b[i]
		assert_eq(port_a.get("id", ""), port_b.get("id", ""), "port id should match at index %d" % i)
		var pos_a: Dictionary = port_a.get("position", {})
		var pos_b: Dictionary = port_b.get("position", {})
		assert_almost_eq(float(pos_a.get("x", 0.0)), float(pos_b.get("x", 0.0)), 0.001, "port %d x should match" % i)
		assert_almost_eq(float(pos_a.get("y", 0.0)), float(pos_b.get("y", 0.0)), 0.001, "port %d y should match" % i)


func test_different_seeds_produce_different_worlds() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]

	var result_a := _generate_world(SEED_A, context)
	var result_b := _generate_world(SEED_B, context)

	assert_true(bool(result_a.get("ok", false)), "seed A should succeed")
	assert_true(bool(result_b.get("ok", false)), "seed B should succeed")

	var world_a: Dictionary = result_a.get("world_map", {})
	var world_b: Dictionary = result_b.get("world_map", {})

	var ports_a: Array = world_a.get("ports", [])
	var ports_b: Array = world_b.get("ports", [])

	var same_positions := true
	for i in mini(ports_a.size(), ports_b.size()):
		var pos_a: Dictionary = ports_a[i].get("position", {})
		var pos_b: Dictionary = ports_b[i].get("position", {})
		if absf(float(pos_a.get("x", 0.0)) - float(pos_b.get("x", 0.0))) > 1.0 or absf(float(pos_a.get("y", 0.0)) - float(pos_b.get("y", 0.0))) > 1.0:
			same_positions = false
			break

	assert_false(same_positions, "different seeds should produce different port positions")


func test_world_generates_enough_ports() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	# Design freeze (NAUTICAL_CHART_SYSTEM.md §2.2 / §12): a single run has 15-20
	# harbours. Assert the frozen bounds, not whatever the fixture happens to emit.
	var ports := world.ports.size()
	assert_true(ports >= WorldGenerator.MIN_PORTS,
		"should generate at least %d ports (design floor), got %d" % [WorldGenerator.MIN_PORTS, ports])
	assert_true(ports <= WorldGenerator.MAX_PORTS,
		"should generate at most %d ports (design ceiling), got %d" % [WorldGenerator.MAX_PORTS, ports])
	assert_eq(ports, TEST_PORT_COUNT, "the fixture should place all %d of its ports" % TEST_PORT_COUNT)


## A profile that authorises too few ports for the frozen world size must fail
## generation rather than return a small world that quietly passes the count check.
func test_world_below_port_floor_is_rejected() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var underfilled := TEST_PROFILE.duplicate(true)
	underfilled["ports"] = (TEST_PROFILE["ports"] as Array).slice(0, 10)

	var result := WorldGenerator.generate(underfilled, context.registries, RngService.new(SEED_A), {})
	assert_false(bool(result.get("ok", false)), "a 10-port world must not pass the 15-port floor")
	assert_true(String(result.get("reason", "")).contains("too few ports"),
		"the failure should name the port floor, got: %s" % String(result.get("reason", "")))


## The frozen 15-20 range must be executable, not just documented: a profile that
## advertises those bounds has to actually yield a public world inside them, with
## every port anchored to a coastline.
func test_formal_profile_matches_design_bounds() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var spec := {
		"port_count_range": [WorldGenerator.MIN_PORTS, WorldGenerator.MAX_PORTS],
		"archetypes": [
			"core:port_template/iron_harbor",
			"core:port_template/spice_port",
			"core:port_template/free_town",
			"core:port_template/fishing_village",
			"core:port_template/glass_port",
		],
		"port_name_keys": ["port_name.core.iron_harbor", "port_name.core.mist_cove"],
		"required_facility_tags": ["port.shipyard", "port.intel"],
		"required_facility_max_edges": 2,
	}
	var profile := ContentDefinition.new()
	profile.content_type = ContentTypes.MAP_CONFIG
	profile.id = "test:map_profile/nautical"
	profile.name_key = "test.map_profile.nautical.name"
	profile.data = spec.duplicate(true)
	var formal := WorldGenerator.formal_profile(profile)
	assert_eq(int(formal["min_ports"]), WorldGenerator.MIN_PORTS, "the formal profile floor is the design floor")
	assert_eq(int(formal["max_ports"]), WorldGenerator.MAX_PORTS, "the formal profile ceiling is the design ceiling")
	assert_eq((formal["ports"] as Array).size(), WorldGenerator.MIN_PORTS,
		"the formal profile starts at the floor port count")

	var world_result := WorldGenerator.generate(formal, context.registries, RngService.new(SEED_A), {})
	assert_true(bool(world_result.get("ok", false)),
		"the formal profile should generate a world: %s" % String(world_result.get("reason", "")))
	if not bool(world_result.get("ok", false)):
		return
	var world := WorldMap.from_dict(world_result.get("world_map", {}))
	assert_eq(world.ports.size(), WorldGenerator.MIN_PORTS, "every formal port should be placed")
	assert_false(world.get_start_port().is_empty(), "the formal world should have a start port")
	for port in world.ports:
		assert_false(port.landmass_id.is_empty(), "formal world port %s should sit on a landmass" % port.id)
		var landmass := world.get_landmass(port.landmass_id)
		assert_false(landmass.is_empty(), "formal world port %s should reference a real landmass" % port.id)
		if not landmass.is_empty():
			assert_true(_distance_to_nearest_coastline(port.position, landmass) < 2.0,
				"formal world port %s should be anchored on the coastline" % port.id)
	assert_true(world.land_coverage_ratio() < 0.45, "the formal world should not be mostly land")


func test_ports_are_anchored_to_landmasses() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	for port in world.ports:
		assert_false(port.landmass_id.is_empty(), "port %s should have a landmass_id" % port.id)
		var landmass := world.get_landmass(port.landmass_id)
		assert_false(landmass.is_empty(), "port %s landmass should exist" % port.id)

		var distance_to_coast := _distance_to_nearest_coastline(port.position, landmass)
		assert_true(distance_to_coast < 2.0, "port %s should be within 2 units of coastline, got %.2f" % [port.id, distance_to_coast])


func test_ports_have_minimum_spacing() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	for i in world.ports.size():
		for j in range(i + 1, world.ports.size()):
			var distance := world.ports[i].position.distance_to(world.ports[j].position)
			assert_true(distance >= 15.0, "ports %s and %s should be at least 15 units apart, got %.2f" % [world.ports[i].id, world.ports[j].id, distance])


func test_landmasses_have_valid_polygons() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	for landmass in world.landmasses:
		assert_true(landmass.polygon.size() >= 3, "landmass %s should have at least 3 polygon points, got %d" % [landmass.id, landmass.polygon.size()])
		assert_true(landmass.area() > 0.0, "landmass %s should have positive area" % landmass.id)


func test_land_coverage_is_reasonable() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	var coverage := world.land_coverage_ratio()
	assert_true(coverage > 0.05, "land coverage should be at least 5%, got %.2f%%" % (coverage * 100.0))
	assert_true(coverage < 0.3, "land coverage should be less than 30%, got %.2f%%" % (coverage * 100.0))


func test_all_ports_are_connected() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	var start_port := world.get_start_port()
	assert_false(start_port.is_empty(), "should have a start port")

	var reachable_count := WorldOps.bfs_distances(world, start_port.id).size()
	assert_eq(reachable_count, world.ports.size(), "all ports should be reachable from start, got %d / %d" % [reachable_count, world.ports.size()])


func test_ports_have_departure_angles() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	for port in world.ports:
		var neighbors := WorldOps.neighbors(world, port.id)
		if not neighbors.is_empty():
			assert_true(port.departure_angle >= -PI and port.departure_angle <= PI, "port %s departure angle should be in [-PI, PI], got %.2f" % [port.id, port.departure_angle])
		# A departure angle pointing inland drags the whole Bezier across the island.
		var landmass := world.get_landmass(port.landmass_id)
		if landmass.is_empty():
			continue
		var exit := Vector2(cos(port.departure_angle), sin(port.departure_angle))
		assert_false(landmass.contains_point(port.position + exit * 3.0), "port %s departure angle should point seaward" % port.id)


## Regression guard: every connectivity edge must produce a sailable curve. The chart
## draws these curves verbatim, so a route that cuts across an island shows up as a
## line over a mountain. Harbour approaches (near the endpoints) may graze the coast
## the port is built on; anything deeper is a failure.
func test_routes_never_cross_land() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	# Reference the implementation's own tolerance instead of a looser copy: straight-line
	# distance to a crossing point is never more than its arc distance, so this bound still
	# fails if the implementation starts allowing deeper land contact.
	var endpoint_graze := RouteCalculator.END_GRAZE_TOLERANCE
	var edges := 0
	for from_id in world.connectivity_graph:
		for to_id in world.connectivity_graph[from_id]:
			if String(from_id) >= String(to_id):
				continue
			edges += 1
			var from_port := world.get_port(String(from_id))
			var to_port := world.get_port(String(to_id))
			var route := RouteCalculator.calculate_route(from_port, to_port, world.landmasses)
			var bezier: PackedVector2Array = route.get("bezier_path", PackedVector2Array())
			assert_true(bezier.size() >= 2, "route %s -> %s should have a path" % [from_id, to_id])
			if bezier.size() < 2:
				continue
			for segment in range(bezier.size() - 1):
				var crossing := _segment_land_crossing(
					bezier[segment], bezier[segment + 1], world.landmasses,
					from_port.position, to_port.position, endpoint_graze
				)
				assert_true(crossing.is_empty(), "route %s -> %s crosses land: %s" % [
					from_id, to_id, crossing,
				])
	assert_true(edges >= world.ports.size() - 1, "connectivity should have at least n-1 edges, got %d" % edges)


## Exact crossing test for one segment: returns a description when the segment passes
## over land farther than `tolerance` from either endpoint, otherwise "".
##
## This deliberately does not reuse `RouteCalculator`'s own helper — a regression in the
## validator must not make the guard pass. Landing points from the harbour approach are
## expected (ports are drawn on the coastline), so crossings near the endpoints are fine.
func _segment_land_crossing(
	start: Vector2,
	end: Vector2,
	landmasses: Array[Landmass],
	path_start: Vector2,
	path_end: Vector2,
	tolerance: float
) -> String:
	var segment_box := Rect2(start, (end - start).abs()).grow(0.5)
	for landmass in landmasses:
		if landmass.polygon.size() < 3:
			continue
		if not landmass.bounding_box().intersects(segment_box):
			continue
		# Wholly inside the landmass: no boundary crossing to detect.
		var midpoint := (start + end) * 0.5
		if landmass.contains_point(midpoint) and _away_from_ends(midpoint, path_start, path_end, tolerance):
			return "segment inside %s at (%.1f, %.1f)" % [landmass.id, midpoint.x, midpoint.y]
		for index in landmass.polygon.size():
			var edge_start: Vector2 = landmass.polygon[index]
			var edge_end: Vector2 = landmass.polygon[(index + 1) % landmass.polygon.size()]
			var hit: Variant = Geometry2D.segment_intersects_segment(start, end, edge_start, edge_end)
			if hit == null:
				continue
			var point: Vector2 = hit
			if _away_from_ends(point, path_start, path_end, tolerance):
				return "crosses %s at (%.1f, %.1f)" % [landmass.id, point.x, point.y]
	return ""


func _away_from_ends(point: Vector2, path_start: Vector2, path_end: Vector2, tolerance: float) -> bool:
	return point.distance_to(path_start) > tolerance and point.distance_to(path_end) > tolerance


## Detour clearance bands scale with the blocker: a small reef must not throw
## route waypoints out to the continent-sized band (a 4-unit atoll used to be
## detoured by up to 42 units), while a continent keeps the full escalation.
func test_detour_clearances_scale_with_island_size() -> void:
	var reef := _circular_landmass("reef", Vector2(100.0, 100.0), 4.0, 24)
	var floor_band := RouteCalculator.COAST_CLEARANCE * 0.5
	var small_band: Array = RouteCalculator._detour_clearances(reef)
	assert_eq(small_band, [floor_band, floor_band * 2.0, floor_band * 3.0],
		"a tiny reef should use the floor band instead of the continent band")

	var continent := _circular_landmass("continent", Vector2(0.0, 0.0), 90.0, 48)
	var full_band: Array = RouteCalculator._detour_clearances(continent)
	assert_eq(full_band, [RouteCalculator.COAST_CLEARANCE, RouteCalculator.COAST_CLEARANCE * 2.0, RouteCalculator.COAST_CLEARANCE * 3.0],
		"a continent keeps the full legacy escalation band")

	# End to end: the blocked route still exists, exactly crosses no land, and
	# every detour waypoint stays inside the small-island band.
	var landmasses: Array[Landmass] = [reef]
	var from_port := _open_sea_port("west", Vector2(60.0, 100.0))
	var to_port := _open_sea_port("east", Vector2(140.0, 100.0))
	var route := RouteCalculator.calculate_route(from_port, to_port, landmasses)
	var path: PackedVector2Array = route.get("bezier_path", PackedVector2Array())
	assert_true(path.size() >= 2, "a route blocked by the reef should still be found")
	for segment in range(path.size() - 1):
		var crossing := _segment_land_crossing(
			path[segment], path[segment + 1], landmasses,
			from_port.position, to_port.position, RouteCalculator.END_GRAZE_TOLERANCE
		)
		assert_true(crossing.is_empty(), "reef detour must not cross the reef: %s" % crossing)

	var centroid := Vector2(100.0, 100.0)
	var max_ring := 4.0 + float(small_band[2])
	for candidate in RouteCalculator._detour_candidates(from_port.position, to_port.position, reef):
		# Endpoints are the harbours themselves (40 units out by construction);
		# only the interior waypoints are detour geometry and must stay in-band.
		for index in range(1, candidate.size() - 1):
			var point: Vector2 = candidate[index]
			var distance := point.distance_to(centroid)
			assert_true(distance <= max_ring + 0.5,
				"reef detour waypoints must stay within the small-island band: %.1f > %.1f" % [distance, max_ring + 0.5])


func _circular_landmass(id: String, center: Vector2, radius: float, segments: int) -> Landmass:
	var landmass := Landmass.new()
	landmass.id = id
	var polygon := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
	landmass.polygon = polygon
	return landmass


func _open_sea_port(id: String, position: Vector2) -> WorldPort:
	var port := WorldPort.new()
	port.id = id
	port.position = position
	return port


func test_connectivity_graph_is_sparse_and_connected() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	var edges := 0
	for from_id in world.connectivity_graph:
		edges += world.connectivity_graph[from_id].size()
	edges = edges / 2
	var port_count := world.ports.size()

	# Connected: assert reachability itself, not just an edge-count proxy.
	var start_port := world.get_start_port()
	assert_false(start_port.is_empty(), "should have a start port")
	var reachable := WorldOps.bfs_distances(world, start_port.id)
	assert_eq(reachable.size(), port_count, "every port should be reachable, got %d / %d" % [reachable.size(), port_count])

	# Sparse: an MST is n-1 edges and each port adds at most 2 shortcuts, so the ceiling
	# is ~3n regardless of port count (the old `complete/2` bound scaled with n² and only
	# passed by one edge at 13 ports).
	assert_true(edges >= port_count - 1, "graph needs at least n-1 edges, got %d for %d ports" % [edges, port_count])
	assert_true(edges <= 3 * port_count, "graph should stay sparse, got %d edges for %d ports" % [edges, port_count])


## The route table is written once at generation time so the chart/voyage code never
## re-runs pathfinding. This pins the data contract that makes swapping the route
## algorithm later a non-event for consumers.
func test_routes_are_precomputed_in_the_world() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world := WorldMap.from_dict(result.get("world_map", {}))

	var graph_edges := 0
	for from_id in world.connectivity_graph:
		for to_id in world.connectivity_graph[from_id]:
			if String(from_id) < String(to_id):
				graph_edges += 1
	assert_true(graph_edges > 0, "fixture should produce connectivity edges")
	assert_eq(world.route_count(), graph_edges, "every connectivity edge should have one stored route")

	var first_path_size := 0
	for edge in world.edges:
		var from_id := String(edge.get("from", ""))
		var to_id := String(edge.get("to", ""))
		assert_true(from_id < to_id, "stored routes are unique per unordered pair (%s, %s)" % [from_id, to_id])
		var path: PackedVector2Array = edge.get("path", PackedVector2Array())
		assert_true(path.size() >= 2, "stored route %s -> %s should carry a path" % [from_id, to_id])
		assert_true(float(edge.get("distance", 0.0)) > 0.0, "stored route should carry a distance")
		# Lookup must work in both directions.
		assert_false(world.route_for(from_id, to_id).is_empty(), "route_for should find %s -> %s" % [from_id, to_id])
		assert_false(world.route_for(to_id, from_id).is_empty(), "route_for should find %s -> %s" % [to_id, from_id])
		if first_path_size == 0:
			first_path_size = path.size()

	# The table must survive the save roundtrip byte-for-byte at PATH_DECIMALS precision.
	var restored := WorldMap.from_dict(world.to_dict())
	assert_eq(restored.route_count(), world.route_count(), "route count should survive the roundtrip")
	var original_edge: Dictionary = world.edges[0]
	var restored_edge := restored.route_for(String(original_edge["from"]), String(original_edge["to"]))
	assert_false(restored_edge.is_empty(), "first route should survive the roundtrip")
	var original_path: PackedVector2Array = original_edge["path"]
	var restored_path: PackedVector2Array = restored_edge["path"]
	assert_eq(restored_path.size(), original_path.size(), "route path length should survive the roundtrip")
	assert_almost_eq(restored_path[0].x, original_path[0].x, 0.01, "route start x should survive the roundtrip")
	assert_almost_eq(float(restored_edge["distance"]), float(original_edge["distance"]), 0.01, "route distance should survive the roundtrip")

	# Legacy worlds (no `edges`) must load and simply have no stored routes.
	var legacy := world.to_dict()
	legacy.erase("edges")
	var legacy_world := WorldMap.from_dict(legacy)
	assert_eq(legacy_world.route_count(), 0, "a world without `edges` should load with an empty route table")
	assert_true(legacy_world.route_for("port_0", "port_1").is_empty(), "missing routes must report empty, not guess")


func test_start_port_exists_and_is_valid() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	var start_port := world.get_start_port()
	assert_false(start_port.is_empty(), "should have a start port")
	assert_true(start_port.is_start_port, "start port should be marked as start")
	assert_true(WorldOps.neighbors(world, start_port.id).size() >= 1, "start port should have at least 1 neighbor")


func test_required_facilities_are_near_start() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	var start_port := world.get_start_port()
	var distances := WorldOps.bfs_distances(world, start_port.id)

	var has_shipyard_within_2 := false
	var has_intelligence_within_2 := false
	for port in world.ports:
		var distance: int = distances.get(port.id, 999)
		if distance <= 2:
			if port.has_tag("port.shipyard"):
				has_shipyard_within_2 = true
			if port.has_tag("port.intelligence"):
				has_intelligence_within_2 = true

	assert_true(has_shipyard_within_2, "should have a shipyard within 2 edges of start")
	assert_true(has_intelligence_within_2, "should have an intelligence facility within 2 edges of start")


func test_world_serialization_roundtrip() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := _generate_world(SEED_A, context)

	assert_true(bool(result.get("ok", false)), "generation should succeed")
	var world_dict: Dictionary = result.get("world_map", {})
	var world := WorldMap.from_dict(world_dict)

	var serialized := world.to_dict()
	var deserialized := WorldMap.from_dict(serialized)

	assert_eq(world.ports.size(), deserialized.ports.size(), "port count should survive roundtrip")
	assert_eq(world.landmasses.size(), deserialized.landmasses.size(), "landmass count should survive roundtrip")
	assert_eq(world.regions.size(), deserialized.regions.size(), "region count should survive roundtrip")
	assert_eq(world.world_seed, deserialized.world_seed, "world seed should survive roundtrip")

	for i in world.ports.size():
		assert_eq(world.ports[i].id, deserialized.ports[i].id, "port id should survive roundtrip at index %d" % i)
		assert_almost_eq(world.ports[i].position.x, deserialized.ports[i].position.x, 0.001, "port %d x should survive roundtrip" % i)
		assert_almost_eq(world.ports[i].position.y, deserialized.ports[i].position.y, 0.001, "port %d y should survive roundtrip" % i)


func _generate_world(seed_value: int, context: AppContext) -> Dictionary:
	var rng_service := RngService.new(seed_value)
	var hub: RegistryHub = context.registries
	var ship := {}
	return WorldGenerator.generate(TEST_PROFILE, hub, rng_service, ship)


func _distance_to_nearest_coastline(point: Vector2, landmass: Landmass) -> float:
	if landmass.polygon.size() < 2:
		return 0.0
	var min_distance := INF
	for i in landmass.polygon.size():
		var j := (i + 1) % landmass.polygon.size()
		var segment_distance := _point_to_segment_distance(point, landmass.polygon[i], landmass.polygon[j])
		if segment_distance < min_distance:
			min_distance = segment_distance
	return min_distance


func _point_to_segment_distance(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var dx := segment_end.x - segment_start.x
	var dy := segment_end.y - segment_start.y
	if dx == 0.0 and dy == 0.0:
		return point.distance_to(segment_start)
	var t := ((point.x - segment_start.x) * dx + (point.y - segment_start.y) * dy) / (dx * dx + dy * dy)
	t = clampf(t, 0.0, 1.0)
	var nearest := Vector2(segment_start.x + t * dx, segment_start.y + t * dy)
	return point.distance_to(nearest)
