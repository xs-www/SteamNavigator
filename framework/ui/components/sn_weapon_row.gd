class_name SNWeaponRow
extends PanelContainer
## @static-doc
## 作用：船厂武器分类里的可拖行武器条目：显示本地化武器名、等级 / 重量 / 伤害与来源标签，仓库武器 / 购买候选都可通过它拖到蓝图炮位或右侧槽位卡；可选行内操作按钮（安装到指定炮位、购买并安装）。
##
## One draggable weapon row in the shipyard refit operations dock.
##
## `SNPartRow` owns the module (`ship_parts`) drag contract; weapons are a
## separate content type with their own command (`ship.install_weapon`) and a
## socket-class gate, so they get their own row instead of overloading the module
## payload. The row only paints the data and owns the `ship_weapon` drag payload:
## the shipyard screen decides which sockets are offered and emits the command.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 底板取 `SNSkin.style("panel_recess")`；可拖行 / 悬停时换 `panel_steel` 并用
##   `modulate_color = SNSkin.color("state.water")` 染色；内容边距固定 8 / 4，保持旧行高。
## - 文字色全部取 `SNSkin.color(token)`，不写十六进制色、不新增 StyleBoxFlat。
## - 尺寸约束：标题 13、meta 11、提示 10；标题省略号截断，不撑宽固定宽度操作坞。
##
## ## 契约与约束
## - `configure(data)` 接收 `{title, tag, tag_color, meta, hint, draggable,
##   payload: Dictionary, actions?: Array}`；`payload` 必须带顶层
##   `kind == "ship_weapon"`（`weapon_id` / `weapon_class` / `source`）。
## - `actions` 条目：`{text: String, command: StringName, params: Dictionary, disabled?: bool}`；
##   点击只发 `command_requested`，不写状态。
## - `drag_payload()` 返回副本（测试可直接调用）；`_get_drag_data()` 复用同一份载荷并挂预览。
## - 拖拽只表达意图：class 匹配、重量 / 金币 / 仓库数量由落点与命令层校验。
## @end-static-doc

## Row action (安装到指定炮位 / 购买并安装) pressed.
signal command_requested(command: StringName, params: Dictionary)
## Click on a non-draggable row (kept for future selection flows).
signal activated(payload: Dictionary)
## Drag gesture started (tests / analytics).
signal drag_started(payload: Dictionary)

const TAG_MIN_WIDTH := 64.0

var payload: Dictionary = {}
var draggable := false

var _title_text := ""
var _tag_text := ""
var _tag_color: Color = SNSkin.color("brass.highlight")
var _meta_text := ""
var _hint_text := ""
var _actions: Array = []
var _title: Label = null
var _tag: Label = null
var _meta: Label = null
var _hint: Label = null
var _actions_box: HBoxContainer = null
var _hovered := false


## Binds one weapon row. Safe before `_ready()`; content is applied on entering tree.
func configure(data: Dictionary) -> void:
	_title_text = String(data.get("title", ""))
	_tag_text = String(data.get("tag", ""))
	_tag_color = data.get("tag_color", SNSkin.color("brass.highlight")) as Color
	_meta_text = String(data.get("meta", ""))
	_hint_text = String(data.get("hint", ""))
	draggable = bool(data.get("draggable", false)) and data.get("payload", null) is Dictionary
	payload = (data.get("payload", {}) as Dictionary).duplicate(true) if data.get("payload", null) is Dictionary else {}
	_actions = (data.get("actions", []) as Array).duplicate(true) if data.get("actions", null) is Array else []
	if is_node_ready():
		_apply_content()
		_apply_style()
	_update_tooltip()


## Drag payload copy, always flagged as the weapon drag kind. Empty when the row
## cannot be dragged (e.g. no compatible socket).
func drag_payload() -> Dictionary:
	if not draggable or payload.is_empty():
		return {}
	var data := payload.duplicate(true)
	data["kind"] = "ship_weapon"
	data["name"] = _title_text
	return data


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply_content()
	_apply_style()
	mouse_entered.connect(func() -> void:
		_hovered = true
		_apply_style()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_apply_style()
	)
	gui_input.connect(_on_gui_input)


func _build() -> void:
	if _title != null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	_title = _label(13, SNSkin.color("text.light"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_tag = _label(11, _tag_color)
	_tag.custom_minimum_size = Vector2(TAG_MIN_WIDTH, 0)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_tag)
	_meta = _label(11, SNSkin.color("text.muted"))
	box.add_child(_meta)
	_hint = _label(10, SNSkin.color("state.water"))
	box.add_child(_hint)
	_actions_box = HBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", 6)
	_actions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_actions_box)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_content() -> void:
	if _title == null:
		return
	_title.text = _title_text
	_tag.text = _tag_text
	_tag.add_theme_color_override("font_color", _tag_color)
	_tag.visible = not _tag_text.is_empty()
	_meta.text = _meta_text
	_meta.visible = not _meta_text.is_empty()
	_hint.text = _hint_text
	_hint.visible = not _hint_text.is_empty()
	mouse_default_cursor_shape = Control.CURSOR_DRAG if draggable else Control.CURSOR_POINTING_HAND
	_rebuild_actions()


func _rebuild_actions() -> void:
	if _actions_box == null:
		return
	for child in _actions_box.get_children():
		_actions_box.remove_child(child)
		child.queue_free()
	for raw_action in _actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var button := SNButton.new()
		button.variant = SNButton.Variant.SECONDARY
		button.compact = true
		button.text = String(action.get("text", ""))
		button.disabled = bool(action.get("disabled", false))
		var command := StringName(String(action.get("command", "")))
		var params: Dictionary = (action.get("params", {}) as Dictionary).duplicate(true) if action.get("params", null) is Dictionary else {}
		button.pressed.connect(func() -> void: command_requested.emit(command, params))
		_actions_box.add_child(button)
	_actions_box.visible = _actions_box.get_child_count() > 0


## Skin-backed row sheet: recess = idle, steel + water tint = draggable / hovered.
func _apply_style() -> void:
	if not is_node_ready():
		return
	var highlighted := draggable or _hovered
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
	if _hovered:
		style.modulate_color = SNSkin.color("brass.highlight")
	elif draggable:
		style.modulate_color = SNSkin.color("state.water")
	add_theme_stylebox_override("panel", style)


func _update_tooltip() -> void:
	var parts: PackedStringArray = []
	if not _title_text.is_empty():
		parts.append(_title_text)
	if not _meta_text.is_empty():
		parts.append(_meta_text)
	if not _hint_text.is_empty():
		parts.append(_hint_text)
	tooltip_text = " · ".join(parts)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var data := drag_payload()
	if data.is_empty():
		return null
	set_drag_preview(_drag_preview(data))
	drag_started.emit(data.duplicate(true))
	return data


func _drag_preview(data: Dictionary) -> Control:
	var preview := PanelContainer.new()
	var base_style: StyleBoxTexture = SNSkin.style("panel_steel")
	if base_style != null:
		var style := base_style.duplicate() as StyleBoxTexture
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		style.modulate_color = SNSkin.color("state.water")
		preview.add_theme_stylebox_override("panel", style)
	else:
		preview.theme_type_variation = &"SNInsetPanel"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "装配 · " + String(data.get("name", _title_text))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", SNSkin.color("text.light"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(label)
	return preview


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not draggable:
			activated.emit(payload.duplicate(true))
