class_name LandGenerator
extends RefCounted
## Procedural landmass generator using noise-based polygon generation.
##
## Generates different archetypes:
##   - CONTINENT: Large landmass along world edge (Perlin/Simplex noise)
##   - LARGE_ISLAND: Medium island with organic edges (Voronoi + noise)
##   - SMALL_ISLAND: Small island with irregular shape
##   - ATOLL: Ring-shaped island with central lagoon

const CONTINENT_SEGMENTS := 48
const ISLAND_SEGMENTS := 32
const ATOLL_SEGMENTS := 24


static func generate_continent(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass:
	var polygon := PackedVector2Array()
	for i in CONTINENT_SEGMENTS:
		var angle := (float(i) / float(CONTINENT_SEGMENTS)) * TAU
		var base_noise := 0.8 + rng.randf() * 0.4
		var detail_noise := sin(angle * 3.0 + rng.randf() * 2.0) * 0.15
		var noise := base_noise + detail_noise
		var x := center.x + cos(angle) * radius_x * noise
		var y := center.y + sin(angle) * radius_y * noise
		polygon.append(Vector2(x, y))
	return Landmass.new(id, polygon, Landmass.Archetype.CONTINENT, region_id)


static func generate_large_island(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass:
	var polygon := PackedVector2Array()
	for i in ISLAND_SEGMENTS:
		var angle := (float(i) / float(ISLAND_SEGMENTS)) * TAU
		var n1 := 0.75 + rng.randf() * 0.5
		var n2 := sin(angle * 3.0 + rng.randf() * 2.0) * 0.12
		var n3 := cos(angle * 5.0 + rng.randf() * 3.0) * 0.06
		var noise := n1 + n2 + n3
		var x := center.x + cos(angle) * radius_x * noise
		var y := center.y + sin(angle) * radius_y * noise
		polygon.append(Vector2(x, y))
	return Landmass.new(id, polygon, Landmass.Archetype.LARGE_ISLAND, region_id)


static func generate_small_island(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass:
	var polygon := PackedVector2Array()
	for i in ISLAND_SEGMENTS:
		var angle := (float(i) / float(ISLAND_SEGMENTS)) * TAU
		var n1 := 0.7 + rng.randf() * 0.6
		var n2 := sin(angle * 4.0 + rng.randf() * 2.5) * 0.15
		var noise := n1 + n2
		var x := center.x + cos(angle) * radius_x * noise
		var y := center.y + sin(angle) * radius_y * noise
		polygon.append(Vector2(x, y))
	return Landmass.new(id, polygon, Landmass.Archetype.SMALL_ISLAND, region_id)


static func generate_atoll(id: String, center: Vector2, outer_radius_x: float, outer_radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass:
	var polygon := PackedVector2Array()
	for i in ATOLL_SEGMENTS:
		var angle := (float(i) / float(ATOLL_SEGMENTS)) * TAU
		var n1 := 0.8 + rng.randf() * 0.4
		var n2 := sin(angle * 3.0 + rng.randf() * 2.0) * 0.1
		var noise := n1 + n2
		var x := center.x + cos(angle) * outer_radius_x * noise
		var y := center.y + sin(angle) * outer_radius_y * noise
		polygon.append(Vector2(x, y))
	return Landmass.new(id, polygon, Landmass.Archetype.ATOLL, region_id)


static func generate_region_landmasses(region: Region, world_bounds: Rect2, land_defs: Array, rng: RandomNumberGenerator) -> Array[Landmass]:
	var result: Array[Landmass] = []
	for i in land_defs.size():
		var def: Dictionary = land_defs[i]
		var id := String(def.get("id", "%s_land_%d" % [region.id, i]))
		var center := Vector2(float(def.get("cx", 0.0)), float(def.get("cy", 0.0)))
		var rx := float(def.get("rx", 10.0))
		var ry := float(def.get("ry", 10.0))
		var archetype_name := String(def.get("archetype", "small_island"))
		var landmass: Landmass
		match archetype_name:
			"continent":
				landmass = generate_continent(id, center, rx, ry, region.id, rng)
			"large_island":
				landmass = generate_large_island(id, center, rx, ry, region.id, rng)
			"small_island":
				landmass = generate_small_island(id, center, rx, ry, region.id, rng)
			"atoll":
				landmass = generate_atoll(id, center, rx, ry, region.id, rng)
			_:
				landmass = generate_small_island(id, center, rx, ry, region.id, rng)
		result.append(landmass)
		region.add_landmass(landmass.id)
	return result


static func simplify_polygon(polygon: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if polygon.size() < 3 or tolerance <= 0.0:
		return polygon
	return _douglas_peucker(polygon, tolerance)


static func _douglas_peucker(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var dmax := 0.0
	var index := 0
	var end_index := points.size() - 1
	for i in range(1, end_index):
		var d := _perpendicular_distance(points[i], points[0], points[end_index])
		if d > dmax:
			index = i
			dmax = d
	var result := PackedVector2Array()
	if dmax > epsilon:
		var left := PackedVector2Array()
		for i in range(0, index + 1):
			left.append(points[i])
		var right := PackedVector2Array()
		for i in range(index, points.size()):
			right.append(points[i])
		var left_simplified := _douglas_peucker(left, epsilon)
		var right_simplified := _douglas_peucker(right, epsilon)
		for i in range(0, left_simplified.size() - 1):
			result.append(left_simplified[i])
		for point in right_simplified:
			result.append(point)
	else:
		result.append(points[0])
		result.append(points[end_index])
	return result


static func _perpendicular_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var dx := line_end.x - line_start.x
	var dy := line_end.y - line_start.y
	if dx == 0.0 and dy == 0.0:
		return point.distance_to(line_start)
	var t := ((point.x - line_start.x) * dx + (point.y - line_start.y) * dy) / (dx * dx + dy * dy)
	t = clampf(t, 0.0, 1.0)
	var nearest := Vector2(line_start.x + t * dx, line_start.y + t * dy)
	return point.distance_to(nearest)
