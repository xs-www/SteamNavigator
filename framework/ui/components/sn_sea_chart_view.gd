class_name SNSeaChartView
extends Control
## @static-doc
## 作用：可缩放/平移的 2D 海图视图，使用 `_draw()` 在世界坐标上绘制水面、
## 陆地多边形、贝塞尔航线、港口图标、迷雾网格、船只标记、罗盘、图例与缩放指示。
##
## - 关键依赖：`sea_chart.view` 查询输出的视图模型（`bind(vm)` 注入）。
##
## ## 契约与约束
## - 输入仅为 `sea_chart.view` 的输出；点击港口时发出 `port_clicked(port_id)`，
##   hover 时发出 `port_hovered(port_id)`，不执行导航或查询。
## - 世界↔屏幕坐标由 `_zoom` 和 `_offset` 线性变换；缩放以鼠标位置为不动点。
## - 陆地多边形在迷雾未探索时使用暗色（explored 态），已探索时使用亮色（fill + outline）。
## - 迷雾网格按 cell 绘制带状态的半透明矩形；BLACK 与 EXPLORED 用不同基色，VISIBLE 跳过。
## - 港口图标半径随 `sqrt(_zoom)` 缩放，当前港带脉冲；选中港用黄铜弧线高亮。
## - 滚轮缩放、左键拖拽、`Esc` 取消选中、`+/-` 键缩放。
## @end-static-doc

signal port_clicked(port_id: String)
signal port_hovered(port_id: String)

# ── Visual constants ──
const COLOR_WATER := Color("0b2428")
## Chart table outside the mapped world (uncharted margin).
const COLOR_CHART_MARGIN := Color("071418")
const COLOR_CHART_FRAME := Color(0.35, 0.55, 0.52, 0.28)
const COLOR_WATER_DEEP := Color(0.04, 0.12, 0.14, 0.12)
const COLOR_WATER_SHALLOW := Color(0.12, 0.28, 0.30, 0.06)
const COLOR_GRID_MINOR := Color(0.38, 0.58, 0.58, 0.06)
const COLOR_GRID_MAJOR := Color(0.46, 0.68, 0.66, 0.12)
const COLOR_LAND_FILL := Color(0.22, 0.38, 0.24, 0.85)
const COLOR_LAND_OUTLINE := Color(0.35, 0.55, 0.35, 0.95)
## Unexplored land, drawn under the fog (mostly hidden by opaque black cells).
const COLOR_LAND_EXPLORED := Color(0.16, 0.27, 0.19, 0.75)
const COLOR_LAND_EXPLORED_OUTLINE := Color(0.28, 0.44, 0.30, 0.8)
## Charted land, drawn above the fog: dim silhouette so a mapped island reads whole.
const COLOR_LAND_SILHOUETTE := Color(0.20, 0.34, 0.23, 0.55)
const COLOR_LAND_SILHOUETTE_OUTLINE := Color(0.42, 0.62, 0.42, 0.75)
const COLOR_FOG_BLACK := Color(0.02, 0.06, 0.08, 1.0)
const COLOR_FOG_EXPLORED := Color(0.05, 0.12, 0.14, 0.5)
const COLOR_ROUTE_ACTIVE := Color(0.88, 0.76, 0.44, 0.86)
const COLOR_ROUTE_EXPLORED := Color(0.45, 0.68, 0.68, 0.62)
const COLOR_ROUTE_UNKNOWN := Color(0.4, 0.5, 0.5, 0.22)
const COLOR_PORT_CURRENT := Color("f0c674")
const COLOR_PORT_VISITED := Color("7fc8e8")
const COLOR_PORT_DISCOVERED := Color("8fd694")
const COLOR_PORT_UNKNOWN := Color(0.46, 0.54, 0.58)
const COLOR_SHIP := Color(0.95, 0.85, 0.45)
const COLOR_BRASS := Color("e1c487")
const COLOR_INK := Color("d7e3ea")

# ── Zoom constraints ──
const ZOOM_MIN := 0.15
const ZOOM_MAX := 5.0
const ZOOM_STEP := 1.15

# ── State ──
var view_model: Dictionary = {}
var _zoom: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_offset_start: Vector2 = Vector2.ZERO
var _hovered_port: String = ""
var _selected_port: String = ""
var _time: float = 0.0
var _world_bounds: Rect2 = Rect2(0, 0, 400, 400)
var _translate: Callable = Callable()
## Set on bind/resize while the control still has no layout size; the first draw
## with a real size then frames the world once (binding before layout must not
## leave the chart at zoom 1 offset 0).
var _needs_fit: bool = true
## Fog baked to one texel per cell; drawn with linear filtering so cell borders
## interpolate instead of reading as hard rectangles.
var _fog_texture: ImageTexture = null
var _fog_rect_world: Rect2 = Rect2()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(_on_resized)


func bind(vm: Dictionary, translate: Callable = Callable()) -> void:
	view_model = vm
	_translate = translate
	if vm.is_empty():
		return
	var bounds: Dictionary = vm.get("world_bounds", {})
	_world_bounds = Rect2(
		float(bounds.get("x", 0.0)),
		float(bounds.get("y", 0.0)),
		float(bounds.get("w", 400.0)),
		float(bounds.get("h", 400.0))
	)
	_needs_fit = true
	_build_fog_texture(vm.get("fog", {}))
	_try_fit()
	queue_redraw()


func _on_resized() -> void:
	if _needs_fit:
		_try_fit()
		queue_redraw()


## Frames the world once, as soon as the control actually has a size.
func _try_fit() -> void:
	if not _needs_fit:
		return
	if size.x <= 1.0 or size.y <= 1.0 or view_model.is_empty():
		return
	_fit_to_view()
	_needs_fit = false


func get_selected_port() -> String:
	return _selected_port


func select_port(port_id: String) -> void:
	# Selecting must not move the chart: re-centring on click would yank the map out
	# from under the cursor. Callers that want to travel to a port use `center_on_port()`.
	_selected_port = port_id
	queue_redraw()


## Explicitly pans the chart so `port_id` sits in the middle (entry animation, "show me").
func center_on_port(port_id: String) -> void:
	if port_id.is_empty():
		return
	_center_on_port(port_id)
	_needs_fit = false
	queue_redraw()


func get_zoom() -> float:
	return _zoom


func _fit_to_view() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var margin := 60.0
	var available := Vector2(size.x - margin * 2.0, size.y - margin * 2.0)
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var zoom_x := available.x / maxf(1.0, _world_bounds.size.x)
	var zoom_y := available.y / maxf(1.0, _world_bounds.size.y)
	_zoom = clampf(minf(zoom_x, zoom_y), ZOOM_MIN, ZOOM_MAX)
	# Center the world
	var center_world := _world_bounds.position + _world_bounds.size * 0.5
	_offset = size * 0.5 - center_world * _zoom


func _center_on_port(port_id: String) -> void:
	var ports: Array = view_model.get("ports", [])
	for port_data in ports:
		if String(port_data.get("id", "")) == port_id:
			var px := float(port_data.get("x", 0.0))
			var py := float(port_data.get("y", 0.0))
			_offset = size * 0.5 - Vector2(px, py) * _zoom
			return


# ── World ↔ Screen transforms ──

func world_to_screen(world_pos: Vector2) -> Vector2:
	return world_pos * _zoom + _offset


func screen_to_world(screen_pos: Vector2) -> Vector2:
	if _zoom <= 0.001:
		return Vector2.ZERO
	return (screen_pos - _offset) / _zoom


# ── Process ──

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if view_model.is_empty():
		return
	_time += delta
	# Only redraw when needed (current port pulse, ship movement)
	var at_sea := bool(view_model.get("at_sea", false))
	var current_port := String(view_model.get("current_port_id", ""))
	if at_sea or not current_port.is_empty():
		queue_redraw()


func _draw() -> void:
	_try_fit()
	if view_model.is_empty():
		_draw_empty_state()
		return
	_draw_water()
	_draw_grid()
	_draw_landmasses(false)
	# Fog sits above unexplored land (unknown coastlines stay hidden) but below
	# routes/ports: a known route between two discovered ports is knowledge, not terrain.
	_draw_fog()
	# Charted islands keep a dim silhouette above the grey fog so the landmass reads
	# as a whole instead of a coastal fringe.
	_draw_landmasses(true)
	_draw_routes()
	_draw_ports()
	_draw_ship()
	_draw_compass()
	_draw_legend()
	_draw_zoom_indicator()


func _draw_empty_state() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_WATER)
	var font := get_theme_default_font()
	draw_string(font, Vector2(size.x * 0.5 - 60, size.y * 0.5), "海图加载中...",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.6, 0.7, 0.7, 0.5))


func _draw_water() -> void:
	# Chart table: everything outside the mapped world is darker "uncharted" margin,
	# so the world rect reads as the charted area instead of ragging into open water.
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_CHART_MARGIN)
	var world_rect := Rect2(
		world_to_screen(_world_bounds.position),
		_world_bounds.size * _zoom
	)
	draw_rect(world_rect, COLOR_WATER)
	# Depth bands in world coordinates
	var cx := _world_bounds.position.x + _world_bounds.size.x * 0.3
	var cy := _world_bounds.position.y + _world_bounds.size.y * 0.4
	draw_circle(world_to_screen(Vector2(cx, cy)), _world_bounds.size.y * 0.5 * _zoom, COLOR_WATER_DEEP)
	cx = _world_bounds.position.x + _world_bounds.size.x * 0.75
	cy = _world_bounds.position.y + _world_bounds.size.y * 0.6
	draw_circle(world_to_screen(Vector2(cx, cy)), _world_bounds.size.y * 0.4 * _zoom, COLOR_WATER_SHALLOW)
	# Chart frame around the mapped world.
	draw_rect(world_rect, COLOR_CHART_FRAME, false, 1.0)


func _draw_grid() -> void:
	# World-space grid lines (every 50 units major, every 10 minor)
	var step_minor := 10.0
	var step_major := 50.0
	# Only draw if zoom is high enough
	if _zoom < 0.3:
		return
	var x_start := floorf(_world_bounds.position.x / step_minor) * step_minor
	var x_end := ceilf((_world_bounds.position.x + _world_bounds.size.x) / step_minor) * step_minor
	var y_start := floorf(_world_bounds.position.y / step_minor) * step_minor
	var y_end := ceilf((_world_bounds.position.y + _world_bounds.size.y) / step_minor) * step_minor

	var x := x_start
	while x <= x_end:
		var screen_x := world_to_screen(Vector2(x, 0)).x
		if screen_x >= 0.0 and screen_x <= size.x:
			var is_major := absf(fmod(x, step_major)) < 0.1
			draw_line(
				Vector2(screen_x, 0), Vector2(screen_x, size.y),
				COLOR_GRID_MAJOR if is_major else COLOR_GRID_MINOR, 1.0
			)
		x += step_minor

	var y := y_start
	while y <= y_end:
		var screen_y := world_to_screen(Vector2(0, y)).y
		if screen_y >= 0.0 and screen_y <= size.y:
			var is_major := absf(fmod(y, step_major)) < 0.1
			draw_line(
				Vector2(0, screen_y), Vector2(size.x, screen_y),
				COLOR_GRID_MAJOR if is_major else COLOR_GRID_MINOR, 1.0
			)
		y += step_minor


func _draw_landmasses(only_explored: bool) -> void:
	## `only_explored = false` runs before the fog and draws the unexplored land that
	## the fog then blanks out. `only_explored = true` runs after the fog and paints a
	## dim silhouette of the islands the player has charted: the design doc says an
	## explored (grey) region still shows the coastline dimly, not just a fringe.
	var landmasses: Array = view_model.get("landmasses", [])
	var fog_data: Dictionary = view_model.get("fog", {})
	for lm in landmasses:
		var polygon: Array = lm.get("polygon", [])
		if polygon.size() < 3:
			continue
		var is_explored := _is_landmass_explored(lm, fog_data)
		if is_explored != only_explored:
			continue
		var screen_points := PackedVector2Array()
		for point in polygon:
			var wx := float(point.get("x", 0.0))
			var wy := float(point.get("y", 0.0))
			screen_points.append(world_to_screen(Vector2(wx, wy)))
		if is_explored:
			draw_colored_polygon(screen_points, COLOR_LAND_SILHOUETTE)
			draw_polyline(screen_points, COLOR_LAND_SILHOUETTE_OUTLINE, 1.5, true)
			if screen_points.size() >= 2:
				draw_line(screen_points[-1], screen_points[0], COLOR_LAND_SILHOUETTE_OUTLINE, 1.5)
		else:
			# Dim the landmass under fog
			draw_colored_polygon(screen_points, COLOR_LAND_EXPLORED)
			draw_polyline(screen_points, COLOR_LAND_EXPLORED_OUTLINE, 1.5, true)
			if screen_points.size() >= 2:
				draw_line(screen_points[-1], screen_points[0], COLOR_LAND_EXPLORED_OUTLINE, 1.5)


func _is_landmass_explored(lm: Dictionary, fog_data: Dictionary) -> bool:
	## A landmass is "charted" once a meaningful share of its coastline has been
	## revealed. Sampling the centroid is wrong (the coastal band rings the island, so
	## the centre stays BLACK while the coast is mapped); requiring only one revealed
	## sample is equally wrong (sailing into one harbour would reveal a whole continent).
	const EXPLORED_COAST_RATIO := 0.25
	if fog_data.is_empty():
		return true
	var state_grid: Array = fog_data.get("state_grid", [])
	if state_grid.is_empty():
		return true
	var polygon: Array = lm.get("polygon", [])
	if polygon.size() < 3:
		return false
	var cell_size: float = fog_data.get("cell_size", 8.0)
	var grid_height: int = fog_data.get("height", 0)
	var grid_width: int = fog_data.get("width", 0)
	if cell_size <= 0.0 or grid_height <= 0 or grid_width <= 0:
		return false
	var step := maxi(1, polygon.size() / 24)
	var samples := 0
	var revealed := 0
	var index := 0
	while index < polygon.size():
		var point: Dictionary = polygon[index]
		var gx := int(float(point.get("x", 0.0)) / cell_size)
		var gy := int(float(point.get("y", 0.0)) / cell_size)
		if gx >= 0 and gx < grid_width and gy >= 0 and gy < grid_height:
			samples += 1
			var row: Array = state_grid[gy]
			if gx < row.size() and int(row[gx]) != 0:
				revealed += 1
		index += step
	if samples == 0:
		return false
	return float(revealed) / float(samples) >= EXPLORED_COAST_RATIO


func _draw_routes() -> void:
	var routes: Array = view_model.get("routes", [])
	var current_port := String(view_model.get("current_port_id", ""))
	var font := get_theme_default_font()
	for route in routes:
		var from_id := String(route.get("from", ""))
		var to_id := String(route.get("to", ""))
		var bezier_path: Array = route.get("bezier_path", [])
		var distance: float = float(route.get("distance", 0.0))
		var explored := bool(route.get("explored", false))
		if bezier_path.size() < 2:
			continue
		# Convert path to screen coordinates
		var screen_path := PackedVector2Array()
		for point in bezier_path:
			var wx := float(point.get("x", 0.0))
			var wy := float(point.get("y", 0.0))
			screen_path.append(world_to_screen(Vector2(wx, wy)))
		var is_active := from_id == current_port or to_id == current_port
		var color := COLOR_ROUTE_UNKNOWN
		if is_active:
			color = COLOR_ROUTE_ACTIVE
		elif explored:
			color = COLOR_ROUTE_EXPLORED
		# Draw shadow
		draw_polyline(screen_path, Color(color.r, color.g, color.b, 0.075), 7.0, true)
		# Draw route
		var line_width := 2.0 if is_active else 1.3
		draw_polyline(screen_path, color, line_width, true)
		# Distance label at the arc-length midpoint, skipped when a port label would sit
		# on top of it (index-based midpoints pile up next to the origin port).
		if _zoom > 0.4 and distance > 0.0 and is_active:
			var midpoint := _path_midpoint(screen_path)
			if not _near_any_port(midpoint, 46.0):
				var text := "%d 海里" % int(roundf(distance))
				var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
				var plate := Rect2(
					midpoint + Vector2(-text_width * 0.5 - 3, -7),
					Vector2(text_width + 6, 13)
				)
				draw_rect(plate, Color(0.02, 0.08, 0.09, 0.7), true)
				draw_string(font, midpoint + Vector2(-text_width * 0.5, 3), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.9, 0.8, 0.58, 0.8))


## Point at half the polyline's arc length.
func _path_midpoint(path: PackedVector2Array) -> Vector2:
	if path.size() < 2:
		return path[0] if path.size() == 1 else Vector2.ZERO
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	var target := total * 0.5
	var walked := 0.0
	for index in range(1, path.size()):
		var segment := path[index - 1].distance_to(path[index])
		if walked + segment >= target:
			return path[index - 1].lerp(path[index], (target - walked) / maxf(segment, 0.0001))
		walked += segment
	return path[path.size() - 1]


## True when `point` is within `radius` screen pixels of any drawn port icon.
func _near_any_port(point: Vector2, radius: float) -> bool:
	for port_data in view_model.get("ports", []):
		var port_pos := world_to_screen(Vector2(
			float(port_data.get("x", 0.0)), float(port_data.get("y", 0.0))
		))
		if point.distance_to(port_pos) <= radius:
			return true
	return false


func _draw_fog() -> void:
	## The fog is baked into a small RGBA texture (one texel per fog cell) and drawn
	## with linear filtering, so cell borders interpolate instead of showing as hard
	## rectangles — the design doc requires smoothed alpha between cells, and this is
	## also a single draw call instead of one per cell.
	if _fog_texture == null:
		return
	var top_left := world_to_screen(_fog_rect_world.position)
	var bottom_right := world_to_screen(_fog_rect_world.end)
	draw_texture_rect(_fog_texture, Rect2(top_left, bottom_right - top_left), false)


## Bakes `fog.alpha_grid` / `fog.state_grid` into a texture, one texel per cell.
func _build_fog_texture(fog_data: Dictionary) -> void:
	_fog_texture = null
	_fog_rect_world = Rect2()
	var grid_w: int = int(fog_data.get("width", 0))
	var grid_h: int = int(fog_data.get("height", 0))
	var alpha_grid: Array = fog_data.get("alpha_grid", [])
	var state_grid: Array = fog_data.get("state_grid", [])
	var cell_size: float = float(fog_data.get("cell_size", 0.0))
	if grid_w <= 0 or grid_h <= 0 or cell_size <= 0.0 or alpha_grid.size() < grid_h:
		return
	var image := Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	for gy in grid_h:
		var alpha_row: Array = alpha_grid[gy]
		var state_row: Array = state_grid[gy]
		for gx in grid_w:
			var alpha: float = 1.0
			if gx < alpha_row.size():
				alpha = float(alpha_row[gx])
			var cell_state: int = 0
			if gx < state_row.size():
				cell_state = int(state_row[gx])
			var color: Color
			if cell_state == 2:  # VISIBLE: no fog at all
				color = Color(0, 0, 0, 0)
			elif cell_state == 1:  # EXPLORED: dim, lets the coastline read through
				color = Color(
					COLOR_FOG_EXPLORED.r, COLOR_FOG_EXPLORED.g, COLOR_FOG_EXPLORED.b,
					clampf(alpha * 0.85, 0.0, 1.0)
				)
			else:  # BLACK: opaque unknown
				color = Color(
					COLOR_FOG_BLACK.r, COLOR_FOG_BLACK.g, COLOR_FOG_BLACK.b,
					clampf(alpha, 0.0, 1.0)
				)
			image.set_pixel(gx, gy, color)
	_fog_texture = ImageTexture.create_from_image(image)
	# FogGrid maps world (0,0) to grid (0,0); honour a shifted world origin if any.
	var origin := Vector2(_world_bounds.position.x, _world_bounds.position.y)
	_fog_rect_world = Rect2(origin, Vector2(grid_w * cell_size, grid_h * cell_size))


func _draw_ports() -> void:
	var ports: Array = view_model.get("ports", [])
	var current_port := String(view_model.get("current_port_id", ""))
	var font := get_theme_default_font()
	for port_data in ports:
		var port_id := String(port_data.get("id", ""))
		var px := float(port_data.get("x", 0.0))
		var py := float(port_data.get("y", 0.0))
		var screen_pos := world_to_screen(Vector2(px, py))
		# Skip off-screen ports
		if screen_pos.x < -30.0 or screen_pos.x > size.x + 30.0:
			continue
		if screen_pos.y < -30.0 or screen_pos.y > size.y + 30.0:
			continue
		var is_current := port_id == current_port
		var is_visited := bool(port_data.get("visited", false))
		var is_discovered := bool(port_data.get("discovered", false))
		var is_selected := port_id == _selected_port
		# Port icon radius scales with zoom
		var base_r := 10.0
		var r := clampf(base_r * sqrt(_zoom), 5.0, 18.0)
		# Current port pulse
		if is_current:
			var pulse := 2.0 + sin(_time * 2.2) * 2.0
			draw_circle(screen_pos, r + 8.0 + pulse, Color(0.94, 0.8, 0.46, 0.055))
			draw_arc(screen_pos, r + 4.0 + pulse, 0.0, TAU, 40, Color(0.94, 0.8, 0.46, 0.25), 1.0)
		# Port body
		if is_current:
			draw_circle(screen_pos, r, COLOR_PORT_CURRENT)
			draw_circle(screen_pos, r * 0.4, Color("0b1116"))
		elif is_visited:
			draw_circle(screen_pos, r, Color(0.06, 0.14, 0.16, 0.95))
			draw_circle(screen_pos, r * 0.85, COLOR_PORT_VISITED)
			draw_circle(screen_pos, r * 0.35, Color("0b1116"))
		elif is_discovered:
			draw_circle(screen_pos, r * 0.7, Color(0.08, 0.16, 0.16, 0.95))
			draw_arc(screen_pos, r * 0.7, 0.0, TAU, 24, COLOR_PORT_DISCOVERED, 1.6)
			draw_circle(screen_pos, r * 0.24, COLOR_PORT_DISCOVERED)
		else:
			draw_circle(screen_pos, r * 0.5, Color(0.1, 0.16, 0.18, 0.95))
			draw_arc(screen_pos, r * 0.5, 0.0, TAU, 20, COLOR_PORT_UNKNOWN, 1.2)
		# Selection highlight
		if is_selected:
			draw_arc(screen_pos, r + 6.0, 0.0, TAU, 40, COLOR_BRASS, 2.0)
		# Hover highlight
		if port_id == _hovered_port:
			draw_arc(screen_pos, r + 8.0, 0.0, TAU, 40, COLOR_BRASS, 2.0)
		# Departure angle tick
		var departure_angle: float = float(port_data.get("departure_angle", 0.0))
		var exit := Vector2(cos(deg_to_rad(departure_angle)), sin(deg_to_rad(departure_angle)))
		var tick_color := Color(0.62, 0.76, 0.73, 0.45)
		if is_current:
			tick_color = Color(0.94, 0.81, 0.5, 0.8)
		draw_line(
			screen_pos + exit * (r + 2.0),
			screen_pos + exit * (r + 10.0),
			tick_color, 1.4
		)
		# Port name label (only when zoomed in enough)
		if _zoom > 0.35:
			var name_key := String(port_data.get("name_key", ""))
			var label := _tr(name_key) if name_key != "" else port_id
			var label_color := COLOR_INK
			if is_current:
				label_color = COLOR_BRASS
			elif not is_visited and not is_discovered:
				label_color = Color(0.62, 0.7, 0.7, 0.65)
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			var plate := Rect2(
				screen_pos + Vector2(-text_size.x * 0.5 - 5, r + 4),
				Vector2(text_size.x + 10, 17)
			)
			draw_rect(plate, Color(0.02, 0.08, 0.09, 0.72), true)
			draw_rect(plate, Color(0.44, 0.6, 0.56, 0.18 if not is_current else 0.42), false, 1.0)
			draw_string(font, screen_pos + Vector2(-text_size.x * 0.5, r + 16),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12 if not is_current else 13, label_color)
		# Hover tooltip
		if port_id == _hovered_port and _zoom <= 0.35:
			var name_key := String(port_data.get("name_key", ""))
			var label := _tr(name_key) if name_key != "" else port_id
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			draw_string(font, screen_pos + Vector2(-text_size.x * 0.5, r + 14),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, COLOR_BRASS)


func _draw_ship() -> void:
	var at_sea := bool(view_model.get("at_sea", false))
	if not at_sea:
		return
	var ship_pos: Dictionary = view_model.get("ship_position", {})
	var wx := float(ship_pos.get("x", 0.0))
	var wy := float(ship_pos.get("y", 0.0))
	var screen_pos := world_to_screen(Vector2(wx, wy))
	var r := clampf(8.0 * sqrt(_zoom), 4.0, 14.0)
	# Ship icon: filled diamond with pulse
	var pulse := 1.5 + sin(_time * 3.0) * 1.5
	draw_colored_polygon(PackedVector2Array([
		screen_pos + Vector2(0, -r - pulse),
		screen_pos + Vector2(r * 0.6, 0),
		screen_pos + Vector2(0, r * 0.6),
		screen_pos + Vector2(-r * 0.6, 0),
	]), COLOR_SHIP)
	draw_polyline(PackedVector2Array([
		screen_pos + Vector2(0, -r - pulse),
		screen_pos + Vector2(r * 0.6, 0),
		screen_pos + Vector2(0, r * 0.6),
		screen_pos + Vector2(-r * 0.6, 0),
		screen_pos + Vector2(0, -r - pulse),
	]), Color(0.7, 0.6, 0.2, 0.8), 1.5, true)


func _draw_compass() -> void:
	var center := Vector2(size.x - 50.0, 50.0)
	var font := get_theme_default_font()
	draw_circle(center, 22.0, Color(0.02, 0.08, 0.09, 0.6))
	draw_arc(center, 22.0, 0.0, TAU, 48, Color(0.62, 0.72, 0.66, 0.28), 1.0)
	draw_arc(center, 15.0, 0.0, TAU, 40, Color(0.62, 0.72, 0.66, 0.16), 1.0)
	draw_line(center + Vector2(0, -18), center + Vector2(0, 18), Color(0.72, 0.64, 0.42, 0.55), 1.0)
	draw_line(center + Vector2(-18, 0), center + Vector2(18, 0), Color(0.62, 0.72, 0.66, 0.3), 1.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -18), center + Vector2(-3.5, -8), center + Vector2(3.5, -8),
	]), Color(0.88, 0.7, 0.4, 0.7))
	draw_string(font, center + Vector2(-4, -26), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9,
		Color(0.78, 0.7, 0.48, 0.8))


func _draw_legend() -> void:
	var font := get_theme_default_font()
	var entries := [
		[COLOR_PORT_CURRENT, "当前港"], [COLOR_PORT_VISITED, "已访问"],
		[COLOR_PORT_DISCOVERED, "已发现"], [COLOR_PORT_UNKNOWN, "未知"],
	]
	var x := 16.0
	var y := size.y - 14.0
	# Background plate
	draw_rect(Rect2(x - 4, y - 14, 360, 22), Color(0.02, 0.08, 0.09, 0.6), true)
	for entry in entries:
		draw_circle(Vector2(x + 3.0, y - 3.0), 3.0, entry[0])
		draw_string(font, Vector2(x + 11.0, y), String(entry[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.62, 0.72, 0.69, 0.7))
		x += 11.0 + font.get_string_size(String(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9).x + 16.0


func _draw_zoom_indicator() -> void:
	var font := get_theme_default_font()
	var text := "×%.1f" % _zoom
	draw_string(font, Vector2(size.x - 90, size.y - 14), text,
		HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 10, Color(0.6, 0.7, 0.7, 0.5))


# ── Input handling ──

func _gui_input(event: InputEvent) -> void:
	# Zoom with mouse wheel
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, ZOOM_STEP)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Check for port click first
				var port_id := _port_at(mb.position)
				if not port_id.is_empty():
					_selected_port = port_id
					port_clicked.emit(port_id)
					queue_redraw()
					accept_event()
					return
				# Start dragging
				_is_dragging = true
				_drag_start = mb.position
				_drag_offset_start = _offset
			else:
				_is_dragging = false
			return
	# Pan with mouse drag
	if event is InputEventMouseMotion and _is_dragging:
		var motion := event as InputEventMouseMotion
		_offset = _drag_offset_start + (motion.position - _drag_start)
		queue_redraw()
		accept_event()
		return
	# Hover detection
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var port_id := _port_at(motion.position)
		if port_id != _hovered_port:
			_hovered_port = port_id
			port_hovered.emit(port_id)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not port_id.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
	# Keyboard: Escape to deselect, +/- to zoom
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			_selected_port = ""
			queue_redraw()
			accept_event()
		elif key.keycode == KEY_EQUAL or key.keycode == KEY_KP_ADD:
			_zoom_at(size * 0.5, ZOOM_STEP)
			accept_event()
		elif key.keycode == KEY_MINUS or key.keycode == KEY_KP_SUBTRACT:
			_zoom_at(size * 0.5, 1.0 / ZOOM_STEP)
			accept_event()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if _zoom == old_zoom:
		return
	# Keep the point under the cursor stationary
	var ratio := _zoom / old_zoom
	_offset = screen_pos - (screen_pos - _offset) * ratio
	queue_redraw()


func _port_at(screen_pos: Vector2) -> String:
	var ports: Array = view_model.get("ports", [])
	var best := ""
	var best_distance := 20.0
	for port_data in ports:
		var port_id := String(port_data.get("id", ""))
		var px := float(port_data.get("x", 0.0))
		var py := float(port_data.get("y", 0.0))
		var pos := world_to_screen(Vector2(px, py))
		var distance := screen_pos.distance_to(pos)
		var hit_radius := clampf(12.0 * sqrt(_zoom), 8.0, 22.0)
		if distance <= hit_radius and distance <= best_distance:
			best = port_id
			best_distance = distance
	return best


func _tr(key: String) -> String:
	if key.is_empty():
		return key
	if _translate.is_valid():
		var value: Variant = _translate.call(key)
		if value is String and not (value as String).is_empty():
			return value
	# Fallback: return the key itself so a missing translate callback is visible,
	# never a silently blank label.
	return key
