class_name RouteCalculator
extends RefCounted
## Calculates routes between ports using Bezier curves that avoid landmasses.
##
## Each port has a unique departure angle (the tangent direction of the Bezier curve
## at the port), computed from the centroid of its neighbor group.

const BEZIER_SEGMENTS := 20
const PATHFINDING_MAX_ITERATIONS := 1000


static func compute_departure_angles(ports: Array[WorldPort], connectivity: Dictionary) -> void:
	for port in ports:
		var neighbor_positions: Array[Vector2] = []
		var neighbors: Array = connectivity.get(port.id, [])
		for neighbor_id in neighbors:
			for other_port in ports:
				if other_port.id == String(neighbor_id):
					neighbor_positions.append(other_port.position)
					break
		if neighbor_positions.is_empty():
			port.departure_angle = 0.0
			continue
		var centroid := Vector2.ZERO
		for pos in neighbor_positions:
			centroid += pos
		centroid /= float(neighbor_positions.size())
		var direction := (centroid - port.position).normalized()
		port.departure_angle = atan2(direction.y, direction.x)


static func calculate_route(from_port: WorldPort, to_port: WorldPort, landmasses: Array[Landmass]) -> Dictionary:
	var straight_path := PackedVector2Array([from_port.position, to_port.position])
	if not _path_intersects_land(straight_path, landmasses):
		var distance := from_port.position.distance_to(to_port.position)
		return {
			"from_port_id": from_port.id,
			"to_port_id": to_port.id,
			"bezier_path": _create_bezier_path(from_port, to_port, straight_path),
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
	var bezier_path := _create_bezier_path(from_port, to_port, waypoints)
	return {
		"from_port_id": from_port.id,
		"to_port_id": to_port.id,
		"bezier_path": bezier_path,
		"distance": path_length,
		"intersects_land": false,
	}


static func _path_intersects_land(path: PackedVector2Array, landmasses: Array[Landmass]) -> bool:
	if path.size() < 2:
		return false
	for i in range(path.size() - 1):
		var segment_start := path[i]
		var segment_end := path[i + 1]
		for landmass in landmasses:
			if _segment_intersects_polygon(segment_start, segment_end, landmass.polygon):
				return true
	return false


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
	var waypoints := PackedVector2Array([start])
	var current := start
	var iterations := 0
	while iterations < PATHFINDING_MAX_ITERATIONS:
		iterations += 1
		var direct_path := PackedVector2Array([current, end])
		if not _path_intersects_land(direct_path, landmasses):
			waypoints.append(end)
			return waypoints
		var blocking_landmass: Landmass = _find_blocking_landmass(current, end, landmasses)
		if blocking_landmass.is_empty():
			waypoints.append(end)
			return waypoints
		var waypoint := _find_waypoint_around_landmass(current, end, blocking_landmass)
		waypoints.append(waypoint)
		current = waypoint
	waypoints.append(end)
	return waypoints


static func _find_blocking_landmass(start: Vector2, end: Vector2, landmasses: Array[Landmass]) -> Landmass:
	for landmass in landmasses:
		if _segment_intersects_polygon(start, end, landmass.polygon):
			return landmass
	return Landmass.new()


static func _find_waypoint_around_landmass(start: Vector2, end: Vector2, landmass: Landmass) -> Vector2:
	var centroid := landmass.centroid()
	var bbox := landmass.bounding_box()
	var offset := Vector2(0.0, bbox.size.y * 0.5 + 5.0)
	var candidate1 := centroid + offset
	var candidate2 := centroid - offset
	var path1 := PackedVector2Array([start, candidate1, end])
	var path2 := PackedVector2Array([start, candidate2, end])
	var length1 := start.distance_to(candidate1) + candidate1.distance_to(end)
	var length2 := start.distance_to(candidate2) + candidate2.distance_to(end)
	if _path_intersects_land(path1, [landmass]) and not _path_intersects_land(path2, [landmass]):
		return candidate2
	if _path_intersects_land(path2, [landmass]) and not _path_intersects_land(path1, [landmass]):
		return candidate1
	return candidate1 if length1 < length2 else candidate2


static func _create_bezier_path(from_port: WorldPort, to_port: WorldPort, waypoints: PackedVector2Array) -> PackedVector2Array:
	if waypoints.size() < 2:
		return PackedVector2Array()
	var result := PackedVector2Array()
	var departure_dir := Vector2(cos(from_port.departure_angle), sin(from_port.departure_angle))
	var arrival_dir := Vector2(cos(to_port.departure_angle + PI), sin(to_port.departure_angle + PI))
	if waypoints.size() == 2:
		var distance := waypoints[0].distance_to(waypoints[1])
		var control_length := distance * 0.3
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
			var segment_result := _smooth_segment(prev, curr, next, i == 1, i == waypoints.size() - 1, departure_dir, arrival_dir)
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


static func _smooth_segment(prev: Vector2, curr: Vector2, next: Vector2, is_first: bool, is_last: bool, departure_dir: Vector2, arrival_dir: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var direction := (curr - prev).normalized()
	var distance := prev.distance_to(curr)
	var control_length := distance * 0.25
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


static func build_connectivity_graph(ports: Array[WorldPort], landmasses: Array[Landmass]) -> Dictionary:
	var graph := {}
	for port in ports:
		graph[port.id] = []
	for i in ports.size():
		for j in range(i + 1, ports.size()):
			var from_port := ports[i]
			var to_port := ports[j]
			graph[from_port.id].append(to_port.id)
			graph[to_port.id].append(from_port.id)
	return graph
