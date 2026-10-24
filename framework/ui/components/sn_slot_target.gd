class_name SNSlotTarget
extends PanelContainer
## @static-doc
## 作用：纵剖图上的单个槽位贴片：显示槽位与已装模块，接收 `ship_parts` 拖放载荷，只校验来源与槽位类型。
##
## One refit slot chip in the SNShipView cutaway.
##
## Draws the slot title, the installed module (or 空), and accepts a dragged
## owned free module (SNPartRow payload, `kind = "ship_parts"`). The screen owns
## the command intent; this control only validates the module category and source.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 槽位底板不再手搓 `StyleBoxFlat`：取 `SNSkin.style("panel_recess")`（仪表凹槽
##   纹理），悬停 / 匹配 / 固定槽位改用 `SNSkin.style("panel_steel")` 并以
##   `modulate_color = SNSkin.color(token)` 区分（state.water / brass.highlight /
##   brass.base）；内容边距固定回 8 / 4，保持旧槽位尺寸与文字裁切。
## - 文字色取 `SNSkin.color(token)`；不写十六进制色，不新增子节点。
## - 尺寸/契约：`fixed` 槽位仍用最亮黄铜语义；槽位尺寸由 SNShipView 的布局决定，
##   本控件不设 custom_minimum_size；拖放只认 `kind == "ship_parts"` 且来源为
##   仓库 / 随船。
## @end-static-doc

signal part_dropped(payload: Dictionary, slot: Dictionary)
signal slot_activated(slot: Dictionary)


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
		_value_label.add_theme_color_override("font_color", SNSkin.color("text.light"))
	else:
		_value_label.text = String(slot.get("empty_text", "空槽位"))
		_value_label.add_theme_color_override("font_color", SNSkin.color("text.muted"))
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
	_title_label = _label(11, SNSkin.color("brass.highlight"))
	_value_label = _label(13, SNSkin.color("text.light"))
	_meta_label = _label(10, SNSkin.color("text.muted"))
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


## Skin-backed slot sheet: recess = idle, steel + token tint = hover / compatible,
## brass-tinted steel = fixed hull/boiler slots. Content margins stay 8 / 4.
func _apply_style() -> void:
	var highlighted := _hovering or _compatible or bool(slot.get("fixed", false))
	var style_id := "panel_steel" if highlighted else "panel_recess"
	var base_style: StyleBoxTexture = SNSkin.style(style_id)
	if base_style == null:
		theme_type_variation = &"SNInsetPanel"
		return
	var style := base_style.duplicate() as StyleBoxTexture
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	if _hovering:
		style.modulate_color = SNSkin.color("state.water")
	elif _compatible:
		style.modulate_color = SNSkin.color("brass.highlight")
	elif bool(slot.get("fixed", false)):
		style.modulate_color = SNSkin.color("brass.base")
	add_theme_stylebox_override("panel", style)


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
	var part_category := String(part.get("category", ""))
	var slot_category := String(slot.get("category", ""))
	if part_category.is_empty() or part_category != slot_category:
		return false
	if part.has("can_install") and not bool(part.get("can_install", true)):
		return false
	return true
