class_name LandGenerator
extends RefCounted
## @static-doc
## 作用：程序化生成陆地多边形，支持大陆、大岛、小岛和环礁。
##
## ## 契约与约束
## - 所有生成方法都接收 `rng`，保证同 seed 可复现。
## - 海岸线是**相干**噪声：每个地形的谐波相位只抽一次，半径随角度连续变化；
##   逐顶点 `randf()` 是白噪声，只会产生锯齿状尖刺。
## - 轮廓必须保持星形（相对中心单值），避免自交导致多边形填充/三角形化出错。
## - 生成后按 `SIMPLIFY_TOLERANCE` 做 Douglas-Peucker 简化，去掉近似共线的采样点。
##
## ## 重点逻辑
## ### `_make_profile` / `_profile_radius`
## - 半径剖面 = base + Σ amplitude·sin(frequency·θ + phase)，相位在生成前一次性抽取。
## ### `generate_*`
## - 各原型共用同一套剖面机制，只是谐波数量、频率与振幅不同。
## @end-static-doc

const CONTINENT_SEGMENTS := 128
const ISLAND_SEGMENTS := 96
const ATOLL_SEGMENTS := 64
## Douglas-Peucker tolerance in world units; small enough to be invisible at chart
## zoom while dropping near-collinear samples.
const SIMPLIFY_TOLERANCE := 0.3

## Harmonic sets per archetype: (frequency, amplitude) pairs. Low frequencies shape
## the landmass, the highest octaves only ruffle the coastline.
const CONTINENT_HARMONICS := [[2.0, 0.10], [3.0, 0.07], [5.0, 0.045], [8.0, 0.022], [13.0, 0.012]]
const LARGE_ISLAND_HARMONICS := [[2.0, 0.12], [3.0, 0.09], [5.0, 0.055], [7.0, 0.030], [11.0, 0.016]]
const SMALL_ISLAND_HARMONICS := [[2.0, 0.15], [3.0, 0.11], [5.0, 0.065], [8.0, 0.030]]
const ATOLL_HARMONICS := [[3.0, 0.10], [5.0, 0.060], [8.0, 0.030]]


## Radius profile sampled once per landmass: `radius(θ) = base + Σ aᵢ·sin(fᵢ·θ + φᵢ)`.
## All phases come from the same `rng` call sequence, so the shape is reproducible.
static func _make_profile(rng: RandomNumberGenerator, harmonics: Array, base_jitter: float) -> Dictionary:
	var terms: Array = []
	for harmonic in harmonics:
		terms.append({
			"frequency": float(harmonic[0]),
			"amplitude": float(harmonic[1]) * (0.85 + rng.randf() * 0.3),
			"phase": rng.randf() * TAU,
		})
	return {
		"base": 1.0 + (rng.randf() - 0.5) * base_jitter,
		"terms": terms,
	}


static func _profile_radius(profile: Dictionary, angle: float) -> float:
	var radius: float = float(profile["base"])
	for term in profile["terms"]:
		radius += sin(angle * float(term["frequency"]) + float(term["phase"])) * float(term["amplitude"])
	# Keep the outline star-shaped and non-degenerate.
	return maxf(0.35, radius)


## Builds a closed coastline polygon from a radial profile.
static func _build_polygon(
	id: String,
	center: Vector2,
	radius_x: float,
	radius_y: float,
	region_id: String,
	archetype: Landmass.Archetype,
	segments: int,
	profile: Dictionary
) -> Landmass:
	var polygon := PackedVector2Array()
	for index in segments:
		var angle := (float(index) / float(segments)) * TAU
		var radius := _profile_radius(profile, angle)
		polygon.append(Vector2(
			center.x + cos(angle) * radius_x * radius,
			center.y + sin(angle) * radius_y * radius
		))
	polygon = simplify_polygon(polygon, SIMPLIFY_TOLERANCE)
	return Landmass.new(id, polygon, archetype, region_id)


static func generate_continent(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass:
	var profile := _make_profile(rng, CONTINENT_HARMONICS, 0.10)
	return _build_polygon(id, center, radius_x, radius_y, region_id, Landmass.Archetype.CONTINENT, CONTINENT_SEGMENTS, profile)


static func generate_large_island(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass:
	var profile := _make_profile(rng, LARGE_ISLAND_HARMONICS, 0.12)
	return _build_polygon(id, center, radius_x, radius_y, region_id, Landmass.Archetype.LARGE_ISLAND, ISLAND_SEGMENTS, profile)


static func generate_small_island(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass:
	var profile := _make_profile(rng, SMALL_ISLAND_HARMONICS, 0.15)
	return _build_polygon(id, center, radius_x, radius_y, region_id, Landmass.Archetype.SMALL_ISLAND, ISLAND_SEGMENTS, profile)


static func generate_atoll(id: String, center: Vector2, outer_radius_x: float, outer_radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass:
	var profile := _make_profile(rng, ATOLL_HARMONICS, 0.10)
	return _build_polygon(id, center, outer_radius_x, outer_radius_y, region_id, Landmass.Archetype.ATOLL, ATOLL_SEGMENTS, profile)


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
