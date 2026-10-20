extends TestCase
class_name TestWorldGenerator
## Tests for the new coordinate-space world generation system.
##
## Covers: reproducibility, port distribution, landmass generation,
## connectivity, Bezier routes, and departure angles.

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
		{"archetype_id": "port_archetype_1", "region_id": "start_coast", "landmass_id": "continent_west", "coast_t": 0.2, "name_key": "port.iron_harbor", "is_start": true, "required_tags": ["port.shipyard"]},
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

	assert_true(world.ports.size() >= 10, "should generate at least 10 ports, got %d" % world.ports.size())
	assert_true(world.ports.size() <= 20, "should generate at most 20 ports, got %d" % world.ports.size())


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

	const ENDPOINT_GRAZE := 12.0
	const SAMPLES := 41
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
			for sample in SAMPLES:
				var t := float(sample) / float(SAMPLES - 1)
				var scaled := clampf(t, 0.0, 1.0) * float(bezier.size() - 1)
				var index := clampi(int(floor(scaled)), 0, bezier.size() - 2)
				var point := bezier[index].lerp(bezier[index + 1], scaled - float(index))
				if not world.is_point_on_land(point):
					continue
				var near_end := point.distance_to(from_port.position) <= ENDPOINT_GRAZE \
					or point.distance_to(to_port.position) <= ENDPOINT_GRAZE
				assert_true(near_end, "route %s -> %s crosses land at (%.1f, %.1f)" % [
					from_id, to_id, point.x, point.y,
				])
	assert_true(edges >= world.ports.size() - 1, "connectivity should have at least n-1 edges, got %d" % edges)


func test_connectivity_graph_is_sparse_but_connected() -> void:
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
	var complete_edges := port_count * (port_count - 1) / 2
	# Connected (n-1) but far below a complete graph, so the chart stays readable.
	assert_true(edges >= port_count - 1, "graph should stay connected, got %d edges for %d ports" % [edges, port_count])
	assert_true(edges <= complete_edges / 2, "graph should stay sparse, got %d of %d possible edges" % [edges, complete_edges])


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
