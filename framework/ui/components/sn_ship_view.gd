class_name SNShipView
extends Control
## Refit stage for the centre of the shipyard screen.
##
## Two modes share one coordinate space:
##   EXTERIOR — a side view of the current ship (procedural placeholder today).
##   CUTAWAY  — a textured longitudinal section (assets/ui/shipyard/ship_section.png)
##              with one SNSlotTarget chip per slot, so owned free modules can be
##              dragged straight onto a slot. When the texture is missing the
##              built-in procedural section is used as a fallback.
##
## ## 2.5D integration contract
## `set_renderer(node)` swaps the procedural placeholder for a real renderer.
## The node is added as a child filling this control and must expose:
##   func ship_view_update(model: Dictionary) -> void
##   func ship_view_set_mode(mode: int) -> void
##   func ship_view_highlight(slot_ids: Array) -> void
## Slot chips, drag & drop, and hit layout stay here, so a future 2.5D scene
## only has to draw the hull and can ignore input entirely. Passing null
## restores the built-in placeholder. Nothing in the screen depends on how the
## ship is drawn, so the swap needs no screen change.

signal slot_drop_requested(payload: Dictionary, slot: Dictionary)
signal slot_activated(slot: Dictionary)

enum Mode { EXTERIOR, CUTAWAY }

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const TEAL := Color("76aaa7")
const HULL_DARK := Color("223237")
const HULL_MID := Color("30474b")
const WATER := Color("10212a")
const SLOT_H := 62.0
const CARGO_SLOT_H := 58.0
## Refit cross-section texture. Replace this PNG to reskin the whole cutaway;
## the screen and slot logic never depend on how the section is drawn.
const SECTION_TEXTURE_PATH := "res://assets/ui/shipyard/ship_section.png"

var mode: int = Mode.EXTERIOR
var _model: Dictionary = {}
var _slots: Array = []
var _slot_targets: Array = []
var _renderer: Node = null
var _slot_layer: Control
var _section_texture: Texture2D = null
var _time := 0.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(520, 400)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_load_section_texture()
	_slot_layer = Control.new()
	_slot_layer.name = "SlotLayer"
	_slot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot_layer)
	_slot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout_slots)
	set_process(true)
	if not _slots.is_empty():
		set_slots(_slots)


func _process(delta: float) -> void:
	_time += delta
	if _renderer == null or mode == Mode.EXTERIOR:
		queue_redraw()


## Swap the visual backend. See the 2.5D integration contract above.
func set_renderer(node: Node) -> void:
	if _renderer != null and is_instance_valid(_renderer):
		remove_child(_renderer)
		_renderer.queue_free()
	_renderer = node
	if _renderer != null:
		add_child(_renderer)
		move_child(_renderer, 0)
		if _renderer is Control:
			(_renderer as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			(_renderer as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notify_renderer("ship_view_update", [_model])
		_notify_renderer("ship_view_set_mode", [mode])
	queue_redraw()


func has_renderer() -> bool:
	return _renderer != null and is_instance_valid(_renderer)


## True once the authored cross-section PNG is imported and available.
func has_section_texture() -> bool:
	return _section_texture != null


func section_texture_size() -> Vector2:
	return _section_texture.get_size() if _section_texture != null else Vector2.ZERO


func _load_section_texture() -> void:
	if not ResourceLoader.exists(SECTION_TEXTURE_PATH):
		return
	_section_texture = load(SECTION_TEXTURE_PATH) as Texture2D


func set_ship_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	_notify_renderer("ship_view_update", [_model])
	queue_redraw()


## Replace the slot descriptors. Each descriptor: id, content_type, index,
## title, module (Dictionary or null), replace_module_id, fixed.
func set_slots(slots: Array) -> void:
	_slots = slots.duplicate(true)
	if _slot_layer == null:
		return
	for target in _slot_targets:
		if is_instance_valid(target):
			_slot_layer.remove_child(target)
			target.queue_free()
	_slot_targets.clear()
	for slot in _slots:
		if not (slot is Dictionary):
			continue
		var target := SNSlotTarget.new()
		target.configure(slot)
		target.part_dropped.connect(_on_slot_drop)
		target.slot_activated.connect(func(slot_data: Dictionary): slot_activated.emit(slot_data))
		_slot_layer.add_child(target)
		target.visible = mode == Mode.CUTAWAY
		_slot_targets.append(target)
	_layout_slots()
	queue_redraw()


func set_mode(next: int) -> void:
	mode = next
	for target in _slot_targets:
		if target is SNSlotTarget:
			target.visible = mode == Mode.CUTAWAY
	_notify_renderer("ship_view_set_mode", [mode])
	_layout_slots()
	queue_redraw()


func highlight_slots(slot_ids: Array) -> void:
	for target in _slot_targets:
		if target is SNSlotTarget:
			target.set_compatible_hint(slot_ids.has(String(target.slot.get("id", ""))))
	_notify_renderer("ship_view_highlight", [slot_ids])


func _on_slot_drop(payload: Dictionary, slot: Dictionary) -> void:
	slot_drop_requested.emit(payload, slot)


func _notify_renderer(method: StringName, args: Array) -> void:
	if _renderer != null and is_instance_valid(_renderer) and _renderer.has_method(method):
		_renderer.callv(method, args)


# ---------------------------------------------------------------------------
# Slot chip layout: fixed slots in one row, cargo slots in a second row.
# ---------------------------------------------------------------------------
func _layout_slots() -> void:
	if _slot_targets.is_empty() or size.x < 80.0:
		return
	var fixed: Array = []
	var cargo: Array = []
	for target in _slot_targets:
		if String(target.slot.get("content_type", "")) == "cargo_modules":
			cargo.append(target)
		else:
			fixed.append(target)
	var w := size.x
	var h := size.y
	_place_row(fixed, 16.0, w - 32.0, h * 0.60, SLOT_H, 8.0)
	_place_row(cargo, w * 0.12, w * 0.76, h * 0.82, CARGO_SLOT_H, 8.0)


func _place_row(targets: Array, left: float, span: float, top: float, chip_h: float, gap: float) -> void:
	var count := targets.size()
	if count == 0:
		return
	var chip_w := minf(148.0, (span - gap * float(count - 1)) / float(count))
	chip_w = maxf(84.0, chip_w)
	var total := chip_w * float(count) + gap * float(count - 1)
	var x := left + maxf(0.0, (span - total) * 0.5)
	for target in targets:
		target.custom_minimum_size = Vector2(chip_w, chip_h)
		target.size = Vector2(chip_w, chip_h)
		target.position = Vector2(x, top)
		target.visible = mode == Mode.CUTAWAY
		x += chip_w + gap


func _chip_anchor(content_type: String, index: int, cargo_count: int) -> Vector2:
	var w := size.x
	var h := size.y
	match content_type:
		"hulls":
			return Vector2(w * 0.20, h * 0.47)
		"boilers":
			return Vector2(w * 0.37, h * 0.50)
		"cargo_modules":
			var step := 0.055 if cargo_count <= 1 else 0.09
			return Vector2(w * (0.52 + step * float(index)), h * 0.52)
		"navigation_modules":
			return Vector2(w * 0.74, h * 0.42)
		"safety_modules":
			return Vector2(w * 0.63, h * 0.50)
		"cabins":
			return Vector2(w * 0.85, h * 0.46)
		_:
			return Vector2(w * 0.5, h * 0.5)


func _draw() -> void:
	if size.x < 80.0 or size.y < 80.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.051, 0.090, 0.106, 0.55))
	if mode == Mode.CUTAWAY:
		_draw_cutaway()
	else:
		_draw_exterior()


func _draw_exterior() -> void:
	var w := size.x
	var h := size.y
	var water_y := h * 0.76
	draw_rect(Rect2(0.0, water_y, w, h - water_y), WATER)
	_draw_waves(water_y, w, h)
	var hull := PackedVector2Array([
		Vector2(w * 0.10, water_y - h * 0.16),
		Vector2(w * 0.90, water_y - h * 0.19),
		Vector2(w * 0.83, water_y),
		Vector2(w * 0.18, water_y),
	])
	draw_colored_polygon(hull, HULL_DARK)
	_draw_polyline_closed(hull, BRASS, 2.0)
	draw_line(Vector2(w * 0.10, water_y - h * 0.16), Vector2(w * 0.90, water_y - h * 0.19), BRASS, 3.0)
	# Cabin superstructure.
	var cabin := Rect2(w * 0.34, water_y - h * 0.32, w * 0.30, h * 0.14)
	draw_rect(cabin, HULL_MID)
	draw_rect(cabin, BRASS, false, 1.5)
	# Funnel and animated smoke.
	var funnel := Rect2(w * 0.56, water_y - h * 0.46, w * 0.035, h * 0.15)
	draw_rect(funnel, HULL_MID)
	draw_rect(funnel, BRASS, false, 1.5)
	for index in 3:
		var phase := fmod(_time * 0.45 + float(index) / 3.0, 1.0)
		var center := Vector2(funnel.get_center().x - phase * w * 0.05, funnel.position.y - phase * h * 0.16)
		var alpha := 0.32 * (1.0 - phase)
		draw_circle(center, 4.0 + phase * 12.0, Color(0.80, 0.78, 0.70, alpha))
	# Mast + flag.
	draw_line(Vector2(w * 0.72, water_y - h * 0.19), Vector2(w * 0.72, water_y - h * 0.42), BRASS, 2.0)
	var flag := PackedVector2Array([
		Vector2(w * 0.72, water_y - h * 0.42),
		Vector2(w * 0.80, water_y - h * 0.39),
		Vector2(w * 0.72, water_y - h * 0.36),
	])
	draw_colored_polygon(flag, TEAL)
	# Paddle wheel at the stern.
	var wheel_center := Vector2(w * 0.17, water_y - h * 0.035)
	var radius := h * 0.075
	draw_circle(wheel_center, radius, HULL_MID)
	draw_arc(wheel_center, radius, 0.0, TAU, 32, BRASS, 1.5)
	for spoke in 8:
		var angle := _time * 0.9 + float(spoke) * TAU / 8.0
		draw_line(wheel_center, wheel_center + Vector2(cos(angle), sin(angle)) * radius, BRASS, 1.0)
	# Portholes.
	for index in 4:
		draw_circle(Vector2(w * (0.28 + float(index) * 0.10), water_y - h * 0.075), 3.0, BRASS)
	# Cargo tags on deck for each installed cargo module.
	var modules: Array = _model.get("modules", [])
	var cargo_total := 0
	for module in modules:
		if module is Dictionary and String(module.get("content_type", "")) == "cargo_modules":
			cargo_total += 1
	for index in cargo_total:
		draw_rect(Rect2(w * (0.62 + float(index) * 0.045), water_y - h * 0.245, w * 0.03, h * 0.045), BRASS, false, 1.5)


func _draw_cutaway() -> void:
	if _section_texture != null:
		_draw_section_texture()
	else:
		_draw_cutaway_placeholder()
	_draw_slot_leaders()


## Authored PNG section, cropped to cover the stage while keeping its aspect.
## The whole refit view is a texture: no runtime hull/section geometry here.
func _draw_section_texture() -> void:
	var texture_size := _section_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var destination := Rect2(Vector2.ZERO, size)
	var cover_scale := maxf(destination.size.x / texture_size.x, destination.size.y / texture_size.y)
	var source_size := destination.size / cover_scale
	var source_position := (texture_size - source_size) * 0.5
	draw_texture_rect_region(_section_texture, destination, Rect2(source_position, source_size))
	draw_rect(destination, Color(0.02, 0.055, 0.065, 0.18))


## Procedural fallback used only before the section texture is imported.
func _draw_cutaway_placeholder() -> void:
	var w := size.x
	var h := size.y
	var deck_y := h * 0.30
	var keel_y := h * 0.56
	var left := w * 0.07
	var right := w * 0.93
	var hull := PackedVector2Array([
		Vector2(left, deck_y),
		Vector2(right, deck_y),
		Vector2(right - w * 0.05, keel_y),
		Vector2(left + w * 0.04, keel_y),
	])
	draw_colored_polygon(hull, HULL_DARK)
	var inner := PackedVector2Array([
		Vector2(left + w * 0.012, deck_y + h * 0.012),
		Vector2(right - w * 0.012, deck_y + h * 0.012),
		Vector2(right - w * 0.058, keel_y - h * 0.012),
		Vector2(left + w * 0.050, keel_y - h * 0.012),
	])
	draw_colored_polygon(inner, HULL_MID)
	_draw_polyline_closed(hull, BRASS, 2.0)
	draw_line(Vector2(left, deck_y), Vector2(right, deck_y), BRASS, 3.0)
	var cabin := Rect2(w * 0.36, deck_y - h * 0.115, w * 0.26, h * 0.115)
	draw_rect(cabin, HULL_MID)
	draw_rect(cabin, BRASS, false, 1.5)
	var funnel := Rect2(w * 0.565, deck_y - h * 0.185, w * 0.032, h * 0.07)
	draw_rect(funnel, HULL_MID)
	draw_rect(funnel, BRASS, false, 1.5)
	draw_line(Vector2(w * 0.72, deck_y), Vector2(w * 0.72, deck_y - h * 0.15), BRASS, 2.0)
	var flag := PackedVector2Array([
		Vector2(w * 0.72, deck_y - h * 0.15),
		Vector2(w * 0.80, deck_y - h * 0.125),
		Vector2(w * 0.72, deck_y - h * 0.10),
	])
	draw_colored_polygon(flag, TEAL)
	var sections := [0.18, 0.36, 0.54, 0.70, 0.86]
	for fraction in sections:
		var x := left + (right - left) * float(fraction)
		draw_line(Vector2(x, deck_y + 2.0), Vector2(x, keel_y - 2.0), Color(TEAL, 0.35), 1.0)
	var boiler_center := Vector2(left + (right - left) * 0.30, (deck_y + keel_y) * 0.55)
	draw_circle(boiler_center, h * 0.055, HULL_MID)
	draw_arc(boiler_center, h * 0.055, 0.0, TAU, 24, BRASS, 1.5)
	var wheel_center := Vector2(left + (right - left) * 0.10, keel_y - h * 0.02)
	draw_circle(wheel_center, h * 0.055, HULL_MID)
	draw_arc(wheel_center, h * 0.055, 0.0, TAU, 24, TEAL, 1.5)
	draw_line(Vector2(left, keel_y), Vector2(right, keel_y), TEAL, 1.0)


## Leader lines from slot chips towards their compartment in the texture.
func _draw_slot_leaders() -> void:
	if _slot_targets.is_empty():
		return
	var cargo_count := 0
	for target in _slot_targets:
		if String(target.slot.get("content_type", "")) == "cargo_modules":
			cargo_count += 1
	for target in _slot_targets:
		var content_type := String(target.slot.get("content_type", ""))
		var anchor := _chip_anchor(content_type, int(target.slot.get("index", 0)), cargo_count)
		var start := Vector2(target.position.x + target.size.x * 0.5, target.position.y)
		draw_line(start, anchor, Color(TEAL, 0.28), 1.0)
		draw_circle(anchor, 3.0, Color(BRASS, 0.6))


func _draw_waves(water_y: float, w: float, h: float) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for index in steps + 1:
		var x := w * float(index) / float(steps)
		var y := water_y + sin(_time * 1.4 + float(index) * 0.7) * h * 0.004
		points.append(Vector2(x, y))
	draw_polyline(points, Color(TEAL, 0.25), 1.5)
	var far := PackedVector2Array()
	for index in steps + 1:
		var x := w * float(index) / float(steps)
		var y := water_y + h * 0.035 + sin(_time * 1.1 + float(index) * 0.5) * h * 0.005
		far.append(Vector2(x, y))
	draw_polyline(far, Color(TEAL, 0.14), 1.0)


func _draw_polyline_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width)
