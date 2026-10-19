extends Button
## Themed edge signboard used by the 2.5D port main view.
##
## A fixed-camera harbour scene needs its 2D facility entries to read as pieces
## of the set: weathered wood planks, an iron frame and brass rivets, with a
## small painted emblem per facility. The Shell keeps using plain `Button`
## semantics (focus, pressed, tooltip, keyboard activation); this component only
## replaces the theme drawing with a custom `_draw()` pass and keeps the button
## text for tests/tooltips.
##
## `text` is set to the full label ("市场 ▶") so existing assertions and
## tooltips keep working. The glyph is not painted twice: `_draw()` strips the
## arrow glyph and paints a real triangle on the scene-facing edge instead.
##
## Configure one sign with `configure()`; hover/pressed/focus repaint through
## `queue_redraw()` from the Button signals, no per-frame processing.

const COLOR_TEXT := Color("ece1c5")
const COLOR_PRIMARY_TEXT := Color("f4e6c8")
const COLOR_MUTED := Color("9fafa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_BRASS_DIM := Color(0.882, 0.769, 0.529, 0.55)
const COLOR_IRON := Color("14191a")
const COLOR_WOOD := Color("2a1e14")
const COLOR_WOOD_LIGHT := Color("3a2a1b")
const COLOR_WOOD_DARK := Color("1d150e")
const COLOR_EMBLEM := Color("173f42")
const GLYPH_COLOR := Color("f0d9a4")

## -1 = left column (sign sits on the window edge, arrow points right into the
## scene); 1 = right column (arrow points left). 0 hides the arrow.
var arrow_direction := -1
var primary := false
var facility := ""
## Small thematic emblem painted on the outer edge.
var show_emblem := true
var _hover := false
var _held := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_suppress_builtin_paint()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not focus_entered.is_connected(_on_focus_changed):
		focus_entered.connect(_on_focus_changed)
	if not focus_exited.is_connected(_on_focus_changed):
		focus_exited.connect(_on_focus_changed)
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)


## One-shot configuration from the Shell layout pass.
func configure(label_text: String, sign_primary: bool, sign_facility: String, sign_arrow: int) -> void:
	text = label_text
	primary = sign_primary
	facility = sign_facility
	arrow_direction = sign_arrow
	queue_redraw()


## Empty styleboxes + transparent built-in text: the sign paints itself, but the
## Button still owns hit-testing, focus and keyboard activation.
func _suppress_builtin_paint() -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	for color_key in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_focus_color", "font_disabled_color", "font_outline_color",
	]:
		add_theme_color_override(color_key, Color(0, 0, 0, 0))


func _on_resized() -> void:
	queue_redraw()


func _on_mouse_entered() -> void:
	_hover = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover = false
	queue_redraw()


func _on_focus_changed() -> void:
	queue_redraw()


func _on_button_down() -> void:
	_held = true
	queue_redraw()


func _on_button_up() -> void:
	_held = false
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var lit := _hover or has_focus()
	var pressed := _held and lit
	var wood := COLOR_WOOD
	if lit:
		wood = COLOR_WOOD.lightened(0.10)
	if pressed:
		wood = COLOR_WOOD.darkened(0.16)
	# Drop shadow keeps the plate readable over bright sky / painted banners.
	draw_rect(Rect2(Vector2(2.0, 3.0), rect.size), Color(0.0, 0.0, 0.0, 0.38))
	# Wood body: base, deterministic grain and two plank seams.
	draw_rect(rect, wood)
	_draw_grain(rect)
	draw_rect(rect, COLOR_WOOD_DARK, false, 1.0)
	# Iron frame + brass inner rule + corner brackets.
	var frame := rect.grow(-1.0)
	draw_rect(frame, COLOR_IRON, false, 2.0)
	draw_rect(rect.grow(-3.0), COLOR_BRASS_DIM, false, 1.0)
	_draw_corner_brackets(rect)
	# Rivets down both iron side posts.
	_draw_rivets(rect)
	if arrow_direction != 0:
		_draw_arrow(rect, lit)
	if show_emblem and not facility.is_empty():
		_draw_emblem(rect)
	_draw_label(rect, lit, pressed)
	# Hover / focus halo painted last so it frames the whole plate.
	if lit and not pressed:
		draw_rect(rect.grow(1.0), Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, 0.55), false, 1.5)


func _draw_grain(rect: Rect2) -> void:
	var seed_value := absi(text.hash())
	# Two plank seams: the plate reads as three boards rather than one slab.
	for fraction in [0.34, 0.67]:
		var x := rect.size.x * float(fraction)
		draw_line(Vector2(x, 3.0), Vector2(x, rect.size.y - 3.0), Color(0, 0, 0, 0.28), 1.0)
	# Sparse horizontal grain lines, deterministic per label.
	var step := 6.0
	var offset := float(seed_value % 5) * 0.7
	var y := 5.0 + offset
	while y < rect.size.y - 4.0:
		var wobble := float((seed_value >> int(y)) & 0x7) * 0.15
		var alpha := 0.035 + float((seed_value >> int(y)) & 0x3) * 0.012
		draw_line(Vector2(4.0, y), Vector2(rect.size.x - 4.0, y + wobble), Color(0, 0, 0, alpha), 1.0)
		y += step


func _draw_corner_brackets(rect: Rect2) -> void:
	var arm := 7.0
	var color := Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, 0.85)
	for corner in [Vector2(2.0, 2.0), Vector2(rect.size.x - 2.0, 2.0), Vector2(2.0, rect.size.y - 2.0), Vector2(rect.size.x - 2.0, rect.size.y - 2.0)]:
		var sign_x := -1.0 if corner.x < rect.size.x * 0.5 else 1.0
		var sign_y := -1.0 if corner.y < rect.size.y * 0.5 else 1.0
		draw_line(corner, corner + Vector2(arm * sign_x, 0.0), color, 1.0)
		draw_line(corner, corner + Vector2(0.0, arm * sign_y), color, 1.0)


func _draw_rivets(rect: Rect2) -> void:
	var radius := 1.7
	for side_x in [6.0, rect.size.x - 6.0]:
		for fraction in [0.22, 0.5, 0.78]:
			var center := Vector2(side_x, rect.size.y * float(fraction))
			draw_circle(center, radius + 0.8, Color(0.0, 0.0, 0.0, 0.45))
			draw_circle(center, radius, COLOR_BRASS_DIM)


func _draw_arrow(rect: Rect2, lit: bool) -> void:
	var color := COLOR_BRASS if lit else Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, 0.72)
	var half := 5.0
	var length := 8.0
	var center_y := rect.size.y * 0.5
	var points: PackedVector2Array
	if arrow_direction < 0:
		var x := rect.size.x - 12.0
		points = PackedVector2Array([Vector2(x, center_y - half), Vector2(x + length, center_y), Vector2(x, center_y + half)])
	else:
		var x := 12.0
		points = PackedVector2Array([Vector2(x, center_y - half), Vector2(x - length, center_y), Vector2(x, center_y + half)])
	draw_colored_polygon(points, color)


func _draw_emblem(rect: Rect2) -> void:
	var outer := 7.5
	var center := Vector2(18.0 if arrow_direction < 0 else rect.size.x - 18.0, rect.size.y * 0.5)
	draw_circle(center, outer + 1.2, Color(0.0, 0.0, 0.0, 0.5))
	draw_circle(center, outer, _facility_color())
	draw_arc(center, outer, 0.0, TAU, 20, COLOR_BRASS_DIM, 1.0, true)
	match facility:
		"exchange":
			draw_arc(center, 3.6, 0.0, TAU, 16, GLYPH_COLOR, 1.2, true)
			draw_circle(center, 1.0, GLYPH_COLOR)
		"contracts":
			for index in 3:
				var y := center.y - 3.0 + float(index) * 3.0
				draw_line(Vector2(center.x - 3.4, y), Vector2(center.x + 3.4, y), GLYPH_COLOR, 1.0)
		"supply":
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(center.x, center.y - 4.0),
					Vector2(center.x + 3.4, center.y + 2.6),
					Vector2(center.x - 3.4, center.y + 2.6),
				]),
				GLYPH_COLOR
			)
		"intel":
			draw_line(Vector2(center.x, center.y + 3.6), Vector2(center.x, center.y - 1.5), GLYPH_COLOR, 1.2)
			draw_arc(center + Vector2(0.0, -3.4), 1.8, 0.0, TAU, 12, GLYPH_COLOR, 1.0, true)
		"shipyard":
			draw_arc(center + Vector2(0.0, 1.0), 4.0, PI, TAU, 12, GLYPH_COLOR, 1.2, true)
			draw_line(Vector2(center.x, center.y - 4.0), Vector2(center.x, center.y + 3.2), GLYPH_COLOR, 1.2)
		_:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(center.x, center.y - 3.6),
					Vector2(center.x + 3.2, center.y),
					Vector2(center.x, center.y + 3.6),
					Vector2(center.x - 3.2, center.y),
				]),
				GLYPH_COLOR
			)


func _facility_color() -> Color:
	match facility:
		"exchange":
			return Color("8a5a1f")
		"contracts":
			return Color("5c4a24")
		"supply":
			return Color("1f5550")
		"intel":
			return Color("1f3d5c")
		"shipyard":
			return Color("5c2a1f")
		"voyage":
			return Color("6b4a17")
		_:
			return COLOR_EMBLEM


## Paints the label inside the plate, between the emblem and the arrow. The
## Button's own text stays invisible; `text` still carries the full label for
## tests, tooltips and accessibility.
func _draw_label(rect: Rect2, lit: bool, pressed: bool) -> void:
	var display := String(text)
	display = display.trim_prefix("◀ ").trim_suffix(" ▶").strip_edges()
	if display.is_empty():
		return
	var font: Font = get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 14
	var color := COLOR_PRIMARY_TEXT if primary else COLOR_TEXT
	if lit:
		color = COLOR_BRASS
	if pressed:
		color = color.darkened(0.15)
	var left_pad := 30.0 if show_emblem and not facility.is_empty() else 10.0
	var right_pad := 24.0 if arrow_direction != 0 else 10.0
	var available := maxf(10.0, rect.size.x - left_pad - right_pad)
	var text_size := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := rect.size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var text_position := Vector2(left_pad, baseline)
	# Keep the label centered in its own slot, not in the whole plate.
	var slot_center := left_pad + available * 0.5
	text_position.x = slot_center - text_size.x * 0.5
	draw_string(font, text_position, display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
