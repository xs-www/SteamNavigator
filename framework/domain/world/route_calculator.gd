class_name RouteCalculator
extends RefCounted
## @static-doc
## 作用：计算避开陆地的港口间贝塞尔航路、出航角度和连通关系。
##
## ## 契约与约束
## - 贝塞尔控制点方向由港口出航角度决定；控制臂过长会把曲线拽进岛里，
##   因此每条曲线发出前都必须过陆地校验（`_safe_bezier` 逐档收紧控制臂）。
## - **可玩世界 = 完全图**（2026-10-26）：任意两港之间都有一条物理航线，
##   拓扑不再做 MST / 补边；能否出航由运行时「航线解锁」状态决定
##   （`WorldOps.is_route_unlocked`，见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`）。
## - 通用生成器（15–20 港验收骨架）仍用旧的稀疏图 `build_connectivity_graph`。
## - 路径计算不考虑运行时海洋迷雾（那是运行时状态）。
## - 港口正好在海岸线上，端点附近 `END_GRAZE_TOLERANCE` 内的擦岸算靠泊，不算穿陆。
##
## ## 重点逻辑
## ### `calculate_route(...)`
## - 直线不穿陆 → 直接造 20 段三次贝塞尔；穿陆 → `_find_path_around_land` 沿岸绕行，
##   两者最终都由 `_safe_bezier` 生成并校验。
## ### `_detour(...)`
## - 有界递归：对挡路的岛，取"沿其海岸外扩环走的较短弧"或"外切点"作候选，整条折线
##   过 `_path_is_clear` 才采纳；递归深度上限 3，无 A*、无网格。
## - 外扩距离按岛屿尺寸自适应（`_detour_clearances`）：三档 = 半长轴 ×1/2/3，下限
##   `COAST_CLEARANCE * 0.5`、上限 `COAST_CLEARANCE`，小礁石不再把航线拽出 42 单位。
## ### `compute_departure_angles(...)`
## - 默认取直接邻居质心方向；若该方向指向本岛内陆，回退为"背离本岛质心"的向海方向。
## ### `build_complete_connectivity(...)`
## - **唯一可玩世界**的拓扑：每对港口互相连接（5 港 → 10 条边），只由港口 id 决定，
##   确定性、无 RNG。生成器随后为每条边算贝塞尔路径 / 折线距离 / 基础风险；
##   任一对算不出路径即判本次世界生成失败重试，不允许缺边。
## ### `build_connectivity_graph(...)`
## - 通用生成器（15–20 港验收骨架、`WorldGenerator.generate()`）用的旧稀疏图：MST +
##   每港 2 条最近邻。**战役不再走它**，保留给通用世界生成与测试。
## @end-static-doc

const BEZIER_SEGMENTS := 20
## Upper bound for how far seaward a detour hugs the blocking coastline, in world
## units. Procedural coastlines wiggle by several units, so a small offset would
## leave ring edges cutting back into the shore. The actual band is scaled to the
## blocker by `_detour_clearances` — this is the ceiling a continent reaches.
const COAST_CLEARANCE := 14.0
## Ports sit exactly on the coastline, so any path grazes land near its endpoints.
## Land contact within this distance of either end is a harbour approach, not a
## crossing, and must not invalidate the route.
const END_GRAZE_TOLERANCE := 8.0


static func compute_departure_angles(ports: Array[WorldPort], connectivity: Dictionary, landmasses: Array[Landmass] = []) -> void:
	## The departure angle is the tangent the Bezier leaves the harbour at. Neighbour
	## centroid alone is not enough: with a sparse network the centroid can sit inland,
	## and the armed control point then drags the whole curve across the island. When
	## the centroid direction is not seaward, fall back to the outward normal of the
	## port's own landmass.
	const PROBE_DISTANCE := 3.0
	for port in ports:
		var neighbor_positions: Array[Vector2] = []
		var neighbors: Array = connectivity.get(port.id, [])
		for neighbor_id in neighbors:
			for other_port in ports:
				if other_port.id == String(neighbor_id):
					neighbor_positions.append(other_port.position)
					break
		var landmass := _landmass_by_id(landmasses, port.landmass_id)
		if neighbor_positions.is_empty():
			port.departure_angle = _seaward_angle(port, landmass)
			continue
		var centroid := Vector2.ZERO
		for pos in neighbor_positions:
			centroid += pos
		centroid /= float(neighbor_positions.size())
		var direction := (centroid - port.position).normalized()
		if direction.length() < 0.01:
			port.departure_angle = _seaward_angle(port, landmass)
			continue
		if not landmass.is_empty() and landmass.contains_point(port.position + direction * PROBE_DISTANCE):
			# Centroid points inland — aim away from the island instead.
			port.departure_angle = _seaward_angle(port, landmass)
			continue
		port.departure_angle = atan2(direction.y, direction.x)


## Angle pointing from the port away from its landmass centroid (open water side).
static func _seaward_angle(port: WorldPort, landmass: Landmass) -> float:
	if landmass.is_empty():
		return 0.0
	var outward := (port.position - landmass.centroid()).normalized()
	if outward.length() < 0.01:
		return 0.0
	return atan2(outward.y, outward.x)


static func _landmass_by_id(landmasses: Array[Landmass], landmass_id: String) -> Landmass:
	for landmass in landmasses:
		if landmass.id == landmass_id:
			return landmass
	return Landmass.new()


static func calculate_route(from_port: WorldPort, to_port: WorldPort, landmasses: Array[Landmass]) -> Dictionary:
	var straight_path := PackedVector2Array([from_port.position, to_port.position])
	if _path_is_clear(straight_path, landmasses):
		var distance := from_port.position.distance_to(to_port.position)
		return {
			"from_port_id": from_port.id,
			"to_port_id": to_port.id,
			"bezier_path": _safe_bezier(from_port, to_port, straight_path, landmasses),
			"distance": distance,
			"intersects_land": false,
		}
	var waypoints := _find_path_around_land(from_port.position, to_port.position, landmasses)
	if waypoints.is_empty():
		return {
			"from_port_id": from_port.id,
			"to_port_id": to_port.id,
			"bezier_path": PackedVector2Array(),
			"distance": 0.0,
			"intersects_land": true,
			"error": "no path found around land",
		}
	var path_length := 0.0
	for i in range(waypoints.size() - 1):
		path_length += waypoints[i].distance_to(waypoints[i + 1])
	var bezier_path := _safe_bezier(from_port, to_port, waypoints, landmasses)
	return {
		"from_port_id": from_port.id,
		"to_port_id": to_port.id,
		"bezier_path": bezier_path,
		"distance": path_length,
		"intersects_land": false,
	}


## Builds the Bezier path and guarantees it does not cut across land.
##
## A wide control arm (0.3 × segment) is what makes the curve read as a sailed arc,
## but it can also bow the curve into an island even when the waypoints are clear.
## Tighten the arms step by step and, as the last resort, emit the waypoint polyline
## itself — a slightly angular route beats a route that sails over a mountain.
static func _safe_bezier(
	from_port: WorldPort,
	to_port: WorldPort,
	waypoints: PackedVector2Array,
	landmasses: Array[Landmass]
) -> PackedVector2Array:
	for control_scale in [0.3, 0.18, 0.09, 0.0]:
		var candidate := _create_bezier_path(from_port, to_port, waypoints, control_scale)
		if candidate.size() >= 2 and _path_is_clear(candidate, landmasses):
			return candidate
	return waypoints.duplicate()


static func _path_intersects_land(path: PackedVector2Array, landmasses: Array[Landmass]) -> bool:
	if path.size() < 2:
		return false
	var path_box := _polyline_bounds(path)
	for landmass in landmasses:
		# Cheap reject first: most islands are nowhere near a given route, and the
		# exact test is 48 edge crossings per segment.
		if landmass.polygon.size() < 3:
			continue
		var land_box := landmass.bounding_box()
		if not land_box.intersects(path_box):
			continue
		for i in range(path.size() - 1):
			if _segment_intersects_polygon(path[i], path[i + 1], landmass.polygon):
				return true
	return false


static func _polyline_bounds(path: PackedVector2Array) -> Rect2:
	if path.is_empty():
		return Rect2()
	var min_point := path[0]
	var max_point := path[0]
	for point in path:
		min_point = Vector2(minf(min_point.x, point.x), minf(min_point.y, point.y))
		max_point = Vector2(maxf(max_point.x, point.x), maxf(max_point.y, point.y))
	return Rect2(min_point, max_point - min_point).grow(0.5)


static func _segment_intersects_polygon(start: Vector2, end: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var mid := (start + end) * 0.5
	if _point_in_polygon(mid, polygon):
		return true
	for i in polygon.size():
		var j := (i + 1) % polygon.size()
		if _segments_intersect(start, end, polygon[i], polygon[j]):
			return true
	return false


static func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var j := polygon.size() - 1
	for i in polygon.size():
		var xi := polygon[i].x
		var yi := polygon[i].y
		var xj := polygon[j].x
		var yj := polygon[j].y
		if ((yi > point.y) != (yj > point.y)) and (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi):
			inside = not inside
		j = i
	return inside


static func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d1 := _direction(p3, p4, p1)
	var d2 := _direction(p3, p4, p2)
	var d3 := _direction(p1, p2, p3)
	var d4 := _direction(p1, p2, p4)
	if ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0)):
		return true
	if d1 == 0.0 and _on_segment(p3, p4, p1):
		return true
	if d2 == 0.0 and _on_segment(p3, p4, p2):
		return true
	if d3 == 0.0 and _on_segment(p1, p2, p3):
		return true
	if d4 == 0.0 and _on_segment(p1, p2, p4):
		return true
	return false


static func _direction(pi: Vector2, pj: Vector2, pk: Vector2) -> float:
	return (pk.x - pi.x) * (pj.y - pi.y) - (pj.x - pi.x) * (pk.y - pi.y)


static func _on_segment(pi: Vector2, pj: Vector2, pk: Vector2) -> bool:
	return minf(pi.x, pj.x) <= pk.x and pk.x <= maxf(pi.x, pj.x) and minf(pi.y, pj.y) <= pk.y and pk.y <= maxf(pi.y, pj.y)


static func _find_path_around_land(start: Vector2, end: Vector2, landmasses: Array[Landmass]) -> PackedVector2Array:
	## Sail around blocking coastlines with bounded recursion.
	##
	## The previous implementation stepped "one waypoint around the blocker" up to 1000
	## times: it could oscillate, spend unbounded time per edge, and the polyline it
	## returned was never validated, so routes still cut across islands. A chart line
	## over a mountain is worse than a slightly longer route, so every candidate path
	## here is validated against *all* landmasses before it is accepted, and detours are
	## recursive (a detour can itself be blocked by a neighbouring island).
	const MAX_DEPTH := 3
	var path := _detour(start, end, landmasses, MAX_DEPTH)
	if path.size() >= 2 and _path_is_clear(path, landmasses):
		return path
	return PackedVector2Array()


static func _detour(start: Vector2, end: Vector2, landmasses: Array[Landmass], depth: int) -> PackedVector2Array:
	var direct := PackedVector2Array([start, end])
	if _path_is_clear(direct, landmasses):
		return direct
	if depth <= 0:
		return PackedVector2Array()
	var blocker := _first_blocker(direct, landmasses)
	if blocker.is_empty():
		return PackedVector2Array()

	for candidate in _detour_candidates(start, end, blocker):
		var chain := _build_chain(candidate, landmasses, depth - 1)
		if chain.size() >= 2 and _path_is_clear(chain, landmasses):
			return chain
	return PackedVector2Array()


## Waypoint chains that plausibly get around `blocker`: coastline arcs at escalating
## clearance (both directions) plus a pass outside the blocker's bounding circle.
static func _detour_candidates(start: Vector2, end: Vector2, blocker: Landmass) -> Array:
	var candidates: Array = []
	for clearance in _detour_clearances(blocker):
		var ring := _offset_ring(blocker, clearance)
		if ring.size() < 3:
			continue
		var start_index := _nearest_ring_index(ring, start)
		var end_index := _nearest_ring_index(ring, end)
		var forward := _simplify_arc(_ring_arc(ring, start_index, end_index, true))
		var backward := _simplify_arc(_ring_arc(ring, start_index, end_index, false))
		var arcs := [forward, backward]
		if _polyline_length(backward) < _polyline_length(forward):
			arcs = [backward, forward]
		for arc in arcs:
			var points: Array = [start]
			for point in arc:
				points.append(point)
			points.append(end)
			candidates.append(points)

	var box := blocker.bounding_box()
	var centre := blocker.centroid()
	var radius := box.size.length() * 0.5 + COAST_CLEARANCE
	var direction := (end - start).normalized()
	if direction.length() > 0.001:
		var normal := Vector2(-direction.y, direction.x)
		for sign_value in [1.0, -1.0]:
			var tangent: Vector2 = centre + normal * float(sign_value) * radius
			candidates.append([start, tangent, end])
	return candidates


## Escalating seaward clearances for a coastline detour, scaled to the blocker's
## own size: a small reef should not throw route waypoints 42 units into open
## sea, while a continent keeps the full band needed to clear its wiggling coast.
## Every candidate is still validated against the land, so an undersized ring
## only costs one rejected attempt before the next clearance is tried.
static func _detour_clearances(blocker: Landmass) -> Array:
	var box := blocker.bounding_box()
	var half_extent := maxf(box.size.x, box.size.y) * 0.5
	var base := clampf(half_extent * 0.5, COAST_CLEARANCE * 0.5, COAST_CLEARANCE)
	return [base, base * 2.0, base * 3.0]


## Keeps at most ~8 evenly spaced vertices of an arc so the chain has few legs.
static func _simplify_arc(arc: PackedVector2Array) -> PackedVector2Array:
	if arc.size() <= 8:
		return arc
	var stride := maxi(1, arc.size() / 8)
	var simplified := PackedVector2Array()
	var index := 0
	while index < arc.size():
		simplified.append(arc[index])
		index += stride
	if simplified[simplified.size() - 1].distance_to(arc[arc.size() - 1]) > 0.001:
		simplified.append(arc[arc.size() - 1])
	return simplified


## Connects `points`, recursively detouring only the legs that actually hit land.
static func _build_chain(points: Array, landmasses: Array[Landmass], depth: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in points.size():
		var point: Vector2 = points[index]
		if index == 0:
			result.append(point)
			continue
		var previous: Vector2 = result[result.size() - 1]
		var leg := _detour(previous, point, landmasses, depth)
		if leg.size() < 2:
			return PackedVector2Array()
		for leg_index in range(1, leg.size()):
			result.append(leg[leg_index])
	return result


## Landmass polygon pushed `clearance` units seaward from its centroid.
static func _offset_ring(landmass: Landmass, clearance: float) -> PackedVector2Array:
	var ring := PackedVector2Array()
	if landmass.polygon.size() < 3:
		return ring
	var centre := landmass.centroid()
	for point in landmass.polygon:
		var outward := (point - centre).normalized()
		if outward.length() < 0.001:
			return PackedVector2Array()
		ring.append(point + outward * clearance)
	return ring


static func _nearest_ring_index(ring: PackedVector2Array, point: Vector2) -> int:
	var best_index := 0
	var best_distance := INF
	for index in ring.size():
		var distance := ring[index].distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


## Ring vertices from `from_index` to `to_index`, walking forward or backward.
static func _ring_arc(ring: PackedVector2Array, from_index: int, to_index: int, forward: bool) -> PackedVector2Array:
	var arc := PackedVector2Array()
	var count := ring.size()
	if count == 0:
		return arc
	var index := from_index
	for _step in count + 1:
		arc.append(ring[index])
		if index == to_index:
			break
		index = (index + 1) % count if forward else (index - 1 + count) % count
	return arc


static func _polyline_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


## A path is clear when it crosses no land away from its endpoints. The first and
## last `END_GRAZE_TOLERANCE` units are a harbour approach and are allowed to touch
## the coast (the port itself is drawn on the coastline).
static func _path_is_clear(path: PackedVector2Array, landmasses: Array[Landmass]) -> bool:
	var trimmed := _trim_ends(path, END_GRAZE_TOLERANCE)
	if trimmed.size() < 2:
		return true
	return not _path_intersects_land(trimmed, landmasses)


## First landmass that blocks the interior of `path` (endpoint grazes ignored).
static func _first_blocker(path: PackedVector2Array, landmasses: Array[Landmass]) -> Landmass:
	var trimmed := _trim_ends(path, END_GRAZE_TOLERANCE)
	if trimmed.size() < 2:
		return Landmass.new()
	var path_box := _polyline_bounds(trimmed)
	for landmass in landmasses:
		if landmass.polygon.size() < 3:
			continue
		if not landmass.bounding_box().intersects(path_box):
			continue
		for index in range(trimmed.size() - 1):
			if _segment_intersects_polygon(trimmed[index], trimmed[index + 1], landmass.polygon):
				return landmass
	return Landmass.new()


## Drops the first and last `tolerance` units of arc length, clipping segments so the
## remaining polyline starts/ends exactly on the cut points.
static func _trim_ends(path: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if path.size() < 2 or tolerance <= 0.0:
		return path
	var total := _polyline_length(path)
	var limit_start := tolerance
	var limit_end := total - tolerance
	if limit_end <= limit_start:
		return PackedVector2Array()
	var result := PackedVector2Array()
	var walked := 0.0
	for index in range(path.size() - 1):
		var a := path[index]
		var b := path[index + 1]
		var segment := a.distance_to(b)
		if segment <= 0.0001:
			continue
		var segment_start := walked
		var segment_end := walked + segment
		var clip_start := maxf(segment_start, limit_start)
		var clip_end := minf(segment_end, limit_end)
		if clip_end > clip_start:
			var point_a := a.lerp(b, (clip_start - segment_start) / segment)
			var point_b := a.lerp(b, (clip_end - segment_start) / segment)
			if result.is_empty() or result[result.size() - 1].distance_to(point_a) > 0.0001:
				result.append(point_a)
			result.append(point_b)
		walked = segment_end
	return result


static func _create_bezier_path(from_port: WorldPort, to_port: WorldPort, waypoints: PackedVector2Array, control_scale: float = 0.3) -> PackedVector2Array:
	if waypoints.size() < 2:
		return PackedVector2Array()
	var result := PackedVector2Array()
	var departure_dir := Vector2(cos(from_port.departure_angle), sin(from_port.departure_angle))
	var arrival_dir := Vector2(cos(to_port.departure_angle + PI), sin(to_port.departure_angle + PI))
	if waypoints.size() == 2:
		var distance := waypoints[0].distance_to(waypoints[1])
		var control_length := distance * control_scale
		var c0 := waypoints[0]
		var c1 := waypoints[0] + departure_dir * control_length
		var c2 := waypoints[1] + arrival_dir * control_length
		var c3 := waypoints[1]
		for i in BEZIER_SEGMENTS + 1:
			var t := float(i) / float(BEZIER_SEGMENTS)
			var point := _cubic_bezier(c0, c1, c2, c3, t)
			result.append(point)
	else:
		result.append(waypoints[0])
		for i in range(1, waypoints.size()):
			var prev := waypoints[i - 1]
			var curr := waypoints[i]
			var next := waypoints[i + 1] if i + 1 < waypoints.size() else curr
			var segment_result := _smooth_segment(
				prev, curr, next, i == 1, i == waypoints.size() - 1,
				departure_dir, arrival_dir, control_scale
			)
			for point in segment_result:
				result.append(point)
	return result


static func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	var tt := t * t
	var uu := u * u
	var uuu := uu * u
	var ttt := tt * t
	var result := p0 * uuu
	result += p1 * (3.0 * uu * t)
	result += p2 * (3.0 * u * tt)
	result += p3 * ttt
	return result


static func _smooth_segment(prev: Vector2, curr: Vector2, next: Vector2, is_first: bool, is_last: bool, departure_dir: Vector2, arrival_dir: Vector2, control_scale: float = 0.25) -> PackedVector2Array:
	var result := PackedVector2Array()
	var direction := (curr - prev).normalized()
	var distance := prev.distance_to(curr)
	var control_length := distance * control_scale
	var c0 := prev
	var c1: Vector2
	var c2: Vector2
	var c3 := curr
	if is_first:
		c1 = prev + departure_dir * control_length
	else:
		c1 = prev + direction * control_length
	var next_dir := (next - curr).normalized()
	if is_last:
		c2 = curr + arrival_dir * control_length
	else:
		c2 = curr - next_dir * control_length
	for i in range(1, BEZIER_SEGMENTS + 1):
		var t := float(i) / float(BEZIER_SEGMENTS)
		result.append(_cubic_bezier(c0, c1, c2, c3, t))
	return result


## Builds the **playable world's** route network: a complete graph over every harbour
## pair (2026-10-26, 「任意两港间均能通航，但航线需要解锁」).
##
## The chart is the single world, so this graph is the gameplay topology too. Every
## pair of harbours gets exactly one physical route; the runtime "route unlocked" state
## (`WorldOps.is_route_unlocked` / `campaign_world.unlocked_route_keys`) decides whether
## the player may actually sail it. Geometry never gates sailing anymore, so the topology
## is purely `n(n-1)/2` deterministic pairs with no RNG, no MST and no density budget.
static func build_complete_connectivity(ports: Array[WorldPort]) -> Dictionary:
	var graph := {}
	for port in ports:
		graph[port.id] = []
	for i in ports.size():
		for j in range(i + 1, ports.size()):
			_connect(graph, ports[i].id, ports[j].id)
	return graph


static func build_connectivity_graph(ports: Array[WorldPort], landmasses: Array[Landmass]) -> Dictionary:
	## Builds a connected but sparse port network.
	##
	## A complete graph (every port reachable from every port) is wrong for the chart:
	## with 13 ports it is 78 routes, the sea chart becomes an unreadable hairball and
	## every voyage is trivially direct. Instead this builds a minimum spanning tree
	## (always connected) plus a couple of nearest-neighbour shortcuts per port, which
	## keeps alternate hops readable while staying well below n².
	const EXTRA_NEIGHBORS := 2
	var graph := {}
	for port in ports:
		graph[port.id] = []
	if ports.size() < 2:
		return graph

	# Cost proxy: distance, doubled when the straight line crosses land, so the
	# spanning tree prefers coastal hops over open-ocean shortcuts through an island.
	var cost := {}
	for i in ports.size():
		for j in range(i + 1, ports.size()):
			var a := ports[i]
			var b := ports[j]
			var distance := a.position.distance_to(b.position)
			var crosses := _path_intersects_land(PackedVector2Array([a.position, b.position]), landmasses)
			cost[_edge_key(a.id, b.id)] = distance * (2.0 if crosses else 1.0)

	# Prim's algorithm from the first port.
	var in_tree := {ports[0].id: true}
	while in_tree.size() < ports.size():
		var best_from := ""
		var best_to := ""
		var best_cost := INF
		for i in ports.size():
			if not in_tree.has(ports[i].id):
				continue
			for j in ports.size():
				if in_tree.has(ports[j].id):
					continue
				var candidate: float = float(cost.get(_edge_key(ports[i].id, ports[j].id), INF))
				if candidate < best_cost:
					best_cost = candidate
					best_from = ports[i].id
					best_to = ports[j].id
		if best_to.is_empty():
			break
		_connect(graph, best_from, best_to)
		in_tree[best_to] = true

	# Shortcut edges so the network is not a bare tree.
	for port in ports:
		var candidates: Array = []
		for other in ports:
			if other.id == port.id:
				continue
			candidates.append({
				"id": other.id,
				"cost": float(cost.get(_edge_key(port.id, other.id), INF)),
			})
		candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return float(left["cost"]) < float(right["cost"])
		)
		var added := 0
		for entry in candidates:
			if added >= EXTRA_NEIGHBORS:
				break
			var other_id := String(entry["id"])
			if graph[port.id].has(other_id):
				continue
			_connect(graph, port.id, other_id)
			added += 1

	return graph


static func _edge_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


static func _connect(graph: Dictionary, a: String, b: String) -> void:
	if not graph.has(a) or not graph.has(b):
		return
	var a_edges: Array = graph[a]
	if not a_edges.has(b):
		a_edges.append(b)
	var b_edges: Array = graph[b]
	if not b_edges.has(a):
		b_edges.append(a)
