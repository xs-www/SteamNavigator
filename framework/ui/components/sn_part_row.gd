class_name SNPartRow
extends PanelContainer
## One module entry in the shipyard parts HUD.
##
## A row is one of: installed (已装), owned free module (仓库/随船, draggable),
## purchasable candidate (点击购买安装). Owned free rows produce the
## `ship_parts` drag payload consumed by SNSlotTarget.

signal activated(part: Dictionary)
signal drag_started(part: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const TEAL := Color("76aaa7")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")

var part: Dictionary = {}
var draggable := false
var _title: Label
var _tag: Label
var _meta: Label
var _hint: Label
var _compatible := false
var _tag_text := ""
var _tag_color := Color("e1c487")
var _meta_text := ""
var _hint_text := ""


func configure(part_data: Dictionary, tag_text: String, tag_color: Color, meta_text: String, hint_text: String, can_drag: bool) -> void:
	part = part_data.duplicate(true)
	draggable = can_drag
	_tag_text = tag_text
	_tag_color = tag_color
	_meta_text = meta_text
	_hint_text = hint_text
	if not is_node_ready():
		return
	_apply_content()
	_apply_style()


func _apply_content() -> void:
	_title.text = String(part.get("name", part.get("module_id", "")))
	_tag.text = _tag_text
	_tag.add_theme_color_override("font_color", _tag_color)
	_meta.text = _meta_text
	_meta.visible = not _meta_text.is_empty()
	_hint.text = _hint_text
	_hint.visible = not _hint_text.is_empty()
	mouse_default_cursor_shape = Control.CURSOR_DRAG if draggable else Control.CURSOR_POINTING_HAND


## Highlight every row whose slot type matches the activated slot.
func set_compatible_hint(active: bool) -> void:
	if _compatible == active:
		return
	_compatible = active
	_apply_style()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)
	_title = _label(13, TEXT)
	_meta = _label(11, MUTED)
	_hint = _label(10, TEAL)
	text_box.add_child(_title)
	text_box.add_child(_meta)
	text_box.add_child(_hint)
	_tag = _label(11, BRASS)
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag.custom_minimum_size = Vector2(64, 0)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tag.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.add_child(_tag)
	gui_input.connect(_on_gui_input)
	if not part.is_empty():
		_apply_content()
	_apply_style()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.098, 0.110, 0.62)
	style.border_color = Color(BRASS, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	if draggable:
		style.border_color = Color(TEAL, 0.55)
	if _compatible:
		style.bg_color = Color(0.086, 0.176, 0.173, 0.82)
		style.border_color = Color(BRASS, 0.85)
		style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable:
		return null
	var preview := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.145, 0.137, 0.95)
	style.border_color = Color(TEAL, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	preview.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "装配 · " + String(part.get("name", part.get("module_id", "")))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("d8efe8"))
	preview.add_child(label)
	set_drag_preview(preview)
	drag_started.emit(part)
	return {"kind": "ship_parts", "part": part.duplicate(true)}


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not draggable:
			activated.emit(part)
