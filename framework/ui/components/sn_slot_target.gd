class_name SNSlotTarget
extends PanelContainer
## One refit slot chip in the SNShipView cutaway.
##
## Draws the slot title, the installed module (or 空), and accepts a dragged
## owned free module (SNPartRow payload, `kind = "ship_parts"`). The screen owns
## the command intent; this control only validates content type and source.

signal part_dropped(payload: Dictionary, slot: Dictionary)
signal slot_activated(slot: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const TEAL := Color("76aaa7")
const RED := Color("c36b53")
const DROP_HINT := Color("9fd3cc")

var slot: Dictionary = {}
var _title_label: Label
var _value_label: Label
var _meta_label: Label
var _hovering := false
var _compatible := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply_style()
	gui_input.connect(_on_gui_input)
	if not slot.is_empty():
		configure(slot)


func configure(slot_data: Dictionary) -> void:
	slot = slot_data.duplicate(true)
	if not is_node_ready():
		return
	_build()
	var installed: Variant = slot.get("module", null)
	_title_label.text = String(slot.get("title", ""))
	if installed is Dictionary and not String(installed.get("module_id", "")).is_empty():
		_value_label.text = String(installed.get("name", String(installed.get("module_id", ""))))
		_value_label.add_theme_color_override("font_color", TEXT)
	else:
		_value_label.text = String(slot.get("empty_text", "空槽位"))
		_value_label.add_theme_color_override("font_color", MUTED)
	var hint := String(slot.get("hint", ""))
	_meta_label.text = hint
	_meta_label.visible = not hint.is_empty()
	tooltip_text = String(slot.get("tooltip", ""))
	_apply_style()


func set_compatible_hint(active: bool) -> void:
	if _compatible == active:
		return
	_compatible = active
	_apply_style()


func _build() -> void:
	if _title_label != null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title_label = _label(11, BRASS)
	_value_label = _label(13, TEXT)
	_meta_label = _label(10, MUTED)
	box.add_child(_title_label)
	box.add_child(_value_label)
	box.add_child(_meta_label)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.078, 0.090, 0.86)
	style.border_color = Color(BRASS, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	if _hovering:
		style.bg_color = Color(0.086, 0.176, 0.173, 0.94)
		style.border_color = DROP_HINT
		style.set_border_width_all(2)
	elif _compatible:
		style.border_color = Color(TEAL, 0.85)
		style.set_border_width_all(2)
	if bool(slot.get("fixed", false)):
		style.border_color = Color(BRASS, 0.75)
	add_theme_stylebox_override("panel", style)
	modulate = Color(1.0, 1.0, 1.0, 1.0)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if String(data.get("kind", "")) != "ship_parts":
		return false
	var part: Dictionary = data.get("part", {})
	var accepted := _accepts(part)
	if accepted:
		_hovering = true
		_apply_style()
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_hovering = false
	_apply_style()
	if not (data is Dictionary):
		return
	var part: Dictionary = data.get("part", {})
	if _accepts(part):
		part_dropped.emit(part, slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hovering = false
		_apply_style()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovering = false
		_apply_style()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_activated.emit(slot)


func _accepts(part: Dictionary) -> bool:
	if part.is_empty():
		return false
	if not ["warehouse", "transit"].has(String(part.get("source", ""))):
		return false
	if String(part.get("content_type", "")) != String(slot.get("content_type", "")):
		return false
	if part.has("can_install") and not bool(part.get("can_install", true)):
		return false
	return true
