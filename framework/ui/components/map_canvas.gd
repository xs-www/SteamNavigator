class_name SNMapCanvas
extends Control

signal port_clicked(port_id: String)

const WATER := Color("0b2428")
const GRID_MINOR := Color(0.38, 0.58, 0.58, 0.075)
const GRID_MAJOR := Color(0.46, 0.68, 0.66, 0.13)
const INK := Color("d7e3ea")
const MUTED := Color("8fa9a6")
const BRASS := Color("e1c487")
const VISITED := Color("7fc8e8")
const DISCOVERED := Color("8fd694")

var ports: Array = []
var routes: Array = []
var labels: Dictionary = {}

var _hovered_port: String = ""
var _positions: Dictionary = {}
var _exits: Dictionary = {}
var _time: float = 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not is_visible_in_tree() or ports.is_empty():
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	_layout()
	if ports.is_empty():
		return
	_draw_water()
	_draw_currents()
	_draw_grid()
	_draw_routes()
	_draw_ports()
	_draw_legend()

func _draw_water() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WATER)
	# Soft depth bands keep the chart from reading as a flat table.
	draw_circle(Vector2(size.x * 0.2, size.y * 0.3), size.y * 0.9, Color(0.16, 0.38, 0.4, 0.05))
	draw_circle(Vector2(size.x * 0.83, size.y * 0.68), size.y * 0.75, Color(0.08, 0.2, 0.24, 0.08))
	draw_rect(Rect2(14, 14, size.x - 28, size.y - 28), Color(0.36, 0.62, 0.58, 0.05), false, 1.0)
	# Faint soundings and shoal marks, deterministic and non-interactive.
	for index in 18:
		var x := fposmod(index * 173.7 + 31.0, maxf(1.0, size.x - 40.0)) + 20.0
		var y := fposmod(index * 97.3 + 57.0, maxf(1.0, size.y - 40.0)) + 20.0
		draw_circle(Vector2(x, y), 1.2, Color(0.45, 0.65, 0.64, 0.16))
		if index % 4 == 0:
			draw_line(Vector2(x - 6, y + 4), Vector2(x + 6, y + 4), Color(0.45, 0.65, 0.64, 0.09), 1.0)

func _draw_currents() -> void:
	for band in 5:
		var points := PackedVector2Array()
		var base_y := size.y * (0.18 + 0.16 * band)
		for sample in 41:
			var x := size.x * float(sample) / 40.0
			var y := base_y + sin(sample * 0.28 + band * 1.7) * 9.0 + sin(sample * 0.09 + band) * 15.0
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.35, 0.65, 0.63, 0.055), 1.0, true)

func _draw_grid() -> void:
	for x in range(0, int(size.x) + 1, 64):
		var major := x % 256 == 0
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_MAJOR if major else GRID_MINOR, 1.0)
	for y in range(0, int(size.y) + 1, 64):
		var major := y % 256 == 0
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_MAJOR if major else GRID_MINOR, 1.0)
	# Latitude/longitude labels on the frame.
	var font := get_theme_default_font()
	draw_string(font, Vector2(22, 30), "52° N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.45, 0.62, 0.6, 0.45))
	draw_string(font, Vector2(22, size.y - 20), "50° N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.45, 0.62, 0.6, 0.45))
	_draw_compass(Vector2(size.x - 54.0, 54.0), font)

func _draw_compass(center: Vector2, font: Font) -> void:
	draw_circle(center, 24.0, Color(0.02, 0.08, 0.09, 0.28))
	draw_arc(center, 24.0, 0.0, TAU, 48, Color(0.62, 0.72, 0.66, 0.28), 1.0)
	draw_arc(center, 17.0, 0.0, TAU, 40, Color(0.62, 0.72, 0.66, 0.16), 1.0)
	draw_line(center + Vector2(0, -20), center + Vector2(0, 20), Color(0.72, 0.64, 0.42, 0.55), 1.0)
	draw_line(center + Vector2(-20, 0), center + Vector2(20, 0), Color(0.62, 0.72, 0.66, 0.3), 1.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -20), center + Vector2(-4, -9), center + Vector2(4, -9),
	]), Color(0.88, 0.7, 0.4, 0.7))
	draw_string(font, center + Vector2(-4, -28), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.78, 0.7, 0.48, 0.8))

func _draw_routes() -> void:
	var current_ids := {}
	for port in ports:
		if bool(port.get("current", false)):
			current_ids[String(port.get("id", ""))] = true
	var font := get_theme_default_font()
	for route in routes:
		var from_id := String(route.get("a", ""))
		var to_id := String(route.get("b", ""))
		if not _positions.has(from_id) or not _positions.has(to_id):
			continue
		var start: Vector2 = _positions[from_id]
		var end: Vector2 = _positions[to_id]
		var active := current_ids.has(from_id) or current_ids.has(to_id)
		var known := _port_visited(from_id) and _port_visited(to_id)
		var color := Color(0.4, 0.5, 0.5, 0.18)
		if active:
			color = Color(0.88, 0.76, 0.44, 0.86)
		elif known:
			color = Color(0.45, 0.68, 0.68, 0.62)
		elif _port_visited(from_id) or _port_visited(to_id):
			color = Color(0.42, 0.58, 0.55, 0.34)
		var curve := _route_curve(start, end, from_id, to_id)
		draw_polyline(curve, Color(color.r, color.g, color.b, 0.075), 7.0, true)
		draw_polyline(curve, color, 1.8 if active else 1.3, true)
		if active:
			var midpoint := _bezier_point(curve, 0.5)
			draw_circle(midpoint, 2.4, Color(0.96, 0.84, 0.53, 0.9))
			var distance := float(route.get("distance", 0.0))
			if distance > 0.0:
				var text := "%d 海里" % int(roundf(distance))
				draw_string(font, midpoint + Vector2(-34, -8), text, HORIZONTAL_ALIGNMENT_CENTER, 68.0, 9, Color(0.9, 0.8, 0.58, 0.55))

func _draw_ports() -> void:
	var font := get_theme_default_font()
	for port in ports:
		var port_id := String(port.get("id", ""))
		if not _positions.has(port_id):
			continue
		var position: Vector2 = _positions[port_id]
		var current := bool(port.get("current", false))
		var visited := bool(port.get("visited", false))
		var discovered := bool(port.get("discovered", false))
		if current:
			var pulse := 2.0 + sin(_time * 2.2) * 2.0
			draw_circle(position, 20.0 + pulse, Color(0.94, 0.8, 0.46, 0.055))
			draw_arc(position, 16.0 + pulse, 0.0, TAU, 40, Color(0.94, 0.8, 0.46, 0.25), 1.0)
		if visited:
			draw_circle(position, 10.0, Color(0.06, 0.14, 0.16, 0.95))
			draw_circle(position, 8.5, VISITED)
			draw_circle(position, 3.5, Color("0b1116"))
		elif discovered:
			draw_circle(position, 7.0, Color(0.08, 0.16, 0.16, 0.95))
			draw_arc(position, 7.0, 0.0, TAU, 24, DISCOVERED, 1.6)
			draw_circle(position, 2.4, DISCOVERED)
		else:
			draw_circle(position, 5.0, Color(0.1, 0.16, 0.18, 0.95))
			draw_arc(position, 5.0, 0.0, TAU, 20, Color(0.4, 0.48, 0.52, 0.75), 1.2)
		if current:
			draw_circle(position, 9.5, Color("f0c674"))
			draw_circle(position, 4.0, Color("0b1116"))
		# The short tick points along the port's single seaward exit.
		var exit: Vector2 = _exits.get(port_id, Vector2.RIGHT)
		var tick_color := Color(0.62, 0.76, 0.73, 0.45)
		if current:
			tick_color = Color(0.94, 0.81, 0.5, 0.8)
		draw_line(position + exit * 9.0, position + exit * 17.0, tick_color, 1.4)
		var tick_normal := Vector2(-exit.y, exit.x)
		draw_colored_polygon(PackedVector2Array([
			position + exit * 19.0,
			position + exit * 14.5 + tick_normal * 2.2,
			position + exit * 14.5 - tick_normal * 2.2,
		]), tick_color)
		var label := String(labels.get(port_id, port_id))
		var label_color := Color(0.82, 0.88, 0.86, 0.9)
		if current:
			label_color = BRASS
		elif not visited and not discovered:
			label_color = Color(0.62, 0.7, 0.7, 0.65)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if not current else 13)
		var plate := Rect2(position + Vector2(-text_size.x * 0.5 - 7, 13), Vector2(text_size.x + 14, 19))
		draw_rect(plate, Color(0.02, 0.08, 0.09, 0.72), true)
		draw_rect(plate, Color(0.44, 0.6, 0.56, 0.18 if not current else 0.42), false, 1.0)
		draw_string(font, position + Vector2(-text_size.x * 0.5, 27), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12 if not current else 13, label_color)
		if port_id == _hovered_port:
			draw_arc(position, 19.0, 0.0, TAU, 40, BRASS, 2.0)
			draw_string(font, position + Vector2(-text_size.x * 0.5, 46), "点击查看", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.88, 0.8, 0.55, 0.8))

func _draw_legend() -> void:
	var font := get_theme_default_font()
	var entries := [
		[BRASS, "当前港"], [VISITED, "已访问"], [DISCOVERED, "可航行"], [Color(0.46, 0.54, 0.58), "未知"],
	]
	var x := 22.0
	var y := size.y - 15.0
	for entry in entries:
		draw_circle(Vector2(x + 3.0, y - 3.0), 3.0, entry[0])
		draw_string(font, Vector2(x + 11.0, y), String(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.62, 0.72, 0.69, 0.7))
		x += 11.0 + font.get_string_size(String(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9).x + 18.0

func _port_visited(port_id: String) -> bool:
	for port in ports:
		if String(port.get("id", "")) == port_id:
			return bool(port.get("visited", false))
	return false

func _route_curve(start: Vector2, end: Vector2, from_id: String, to_id: String) -> PackedVector2Array:
	var delta := end - start
	var distance := maxf(1.0, delta.length())
	var exit_from: Vector2 = _exits.get(from_id, delta.normalized())
	var exit_to: Vector2 = _exits.get(to_id, -delta.normalized())
	var handle := clampf(distance * 0.38, 24.0, 96.0)
	# Every route leaves its origin along the port's single exit direction;
	# the destination control point is on the destination's seaward side.
	var c1 := start + exit_from * handle
	var c2 := end + exit_to * handle
	var points := PackedVector2Array()
	for index in 25:
		var t := float(index) / 24.0
		var u := 1.0 - t
		points.append(
			start * (u * u * u)
			+ c1 * (3.0 * u * u * t)
			+ c2 * (3.0 * u * t * t)
			+ end * (t * t * t)
		)
	return points

func _bezier_point(points: PackedVector2Array, t: float) -> Vector2:
	var scaled := clampf(t, 0.0, 1.0) * float(points.size() - 1)
	var index := clampi(int(floor(scaled)), 0, points.size() - 2)
	return points[index].lerp(points[index + 1], scaled - float(index))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var port_id := _port_at(event.position)
		if not port_id.is_empty():
			port_clicked.emit(port_id)
			accept_event()
		return
	if event is InputEventMouseMotion:
		var port_id := _port_at(event.position)
		if port_id != _hovered_port:
			_hovered_port = port_id
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not port_id.is_empty() else Control.CURSOR_ARROW
			queue_redraw()

func _layout() -> void:
	_positions = {}
	if ports.is_empty() or size.x <= 1.0 or size.y <= 1.0:
		return
	var min_x := 0.0
	var max_x := 0.0
	var min_y := 0.0
	var max_y := 0.0
	var first := true
	for port in ports:
		var x := float(port.get("x", 0.0))
		var y := float(port.get("y", 0.0))
		if first:
			min_x = x
			max_x = x
			min_y = y
			max_y = y
			first = false
		else:
			min_x = minf(min_x, x)
			max_x = maxf(max_x, x)
			min_y = minf(min_y, y)
			max_y = maxf(max_y, y)
	var width := maxf(1.0, max_x - min_x)
	var height := maxf(1.0, max_y - min_y)
	var target_width := maxf(1.0, size.x - 260.0)
	var target_height := maxf(1.0, size.y - 96.0)
	var scale_x := target_width / width
	var scale_y := target_height / height
	var base_scale := minf(scale_x, scale_y)
	# Sea charts are wider than their island clusters; allow a measured
	# horizontal stretch so the route web uses the available table width.
	scale_x = minf(scale_x, base_scale * 2.2)
	scale_y = minf(scale_y, base_scale * 1.6)
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var origin := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	for port in ports:
		var delta := Vector2(float(port.get("x", 0.0)), float(port.get("y", 0.0))) - origin
		_positions[String(port.get("id", ""))] = center + Vector2(delta.x * scale_x, delta.y * scale_y)
	_compute_exit_directions()

func _compute_exit_directions() -> void:
	_exits = {}
	for port in ports:
		var port_id := String(port.get("id", ""))
		if not _positions.has(port_id):
			continue
		var position: Vector2 = _positions[port_id]
		var neighbor_center := Vector2.ZERO
		var neighbor_count := 0
		for route in routes:
			var other_id := ""
			if String(route.get("a", "")) == port_id:
				other_id = String(route.get("b", ""))
			elif String(route.get("b", "")) == port_id:
				other_id = String(route.get("a", ""))
			if other_id.is_empty() or not _positions.has(other_id):
				continue
			neighbor_center += Vector2(_positions[other_id]) - position
			neighbor_count += 1
		var exit := Vector2.RIGHT
		if neighbor_count > 0:
			var direction := neighbor_center / float(neighbor_count)
			if direction.length() > 0.01:
				exit = direction.normalized()
			else:
				exit = (size * 0.5 - position).normalized()
		# A generated map may author a stable exit vector later; the UI
		# derives one from the neighbor cluster until then.
		var authored: Variant = port.get("exit_direction", null)
		if authored is Vector2:
			var authored_vector: Vector2 = authored
			if authored_vector.length() > 0.01:
				exit = authored_vector.normalized()
		elif authored is Array:
			var authored_array: Array = authored
			if authored_array.size() >= 2:
				var authored_vector := Vector2(float(authored_array[0]), float(authored_array[1]))
				if authored_vector.length() > 0.01:
					exit = authored_vector.normalized()
		_exits[port_id] = exit

func _port_at(position: Vector2) -> String:
	_layout()
	var best := ""
	var best_distance := 20.0
	for port in ports:
		if not bool(port.get("visited", false)):
			continue
		var port_id := String(port.get("id", ""))
		if not _positions.has(port_id):
			continue
		var distance := position.distance_to(_positions[port_id])
		if distance <= best_distance:
			best = port_id
			best_distance = distance
	return best

