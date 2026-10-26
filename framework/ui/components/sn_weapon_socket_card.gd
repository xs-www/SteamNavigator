class_name SNWeaponSocketCard
extends PanelContainer
## @static-doc
## 作用：船厂改装操作坞里的单个武器槽位卡：显示本地化炮位名 / 武器等级、已装武器或空槽位、卸下按钮，并作为 `ship_weapon` 拖放落点（等级匹配才接受），把玩家意图交回船厂页。
##
## One weapon mount card in the shipyard operations dock.
##
## The screen lists the same sockets on the blueprint chips (`SNShipView`), so the
## card is a second, larger drop target for players who drag from the warehouse /
## purchase list: it never executes commands itself, it only validates the socket
## class and forwards `weapon_dropped(payload, socket)` or `command_requested`.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 底板取 `SNSkin.style("panel_recess")`；拖入兼容武器 / 悬停时换 `panel_steel`
##   并以 `modulate_color = SNSkin.color("state.water")` 高亮；内容边距固定 8 / 6。
## - 已装状态用 `SNBadge`（SUCCESS 变体）+ `text.light` 武器名；空槽用 `text.muted`。
## - 不写十六进制色、不手搓 StyleBoxFlat。
##
## ## 契约与约束
## - `configure(row)` 接收 `{socket, socket_class, occupied, display_name, slot_title,
##   slot_label, empty_text, weight, damage, can_uninstall, drop_hint}`；字段全部由
##   船厂页本地化后传入，本组件不访问注册表 / 不翻译。
## - 接受拖放载荷 `kind == "ship_weapon"`：`weapon_class` 必须等于本槽位
##   `socket_class`，且不能是「已装同型同 id」；`_drop_data` 只发
##   `weapon_dropped(payload, socket)`。
## - `hovered` / `unhovered` 用于让船厂页高亮左侧蓝图上的同名贴片。
## - 卸下按钮只发 `command_requested(&"ship.uninstall_weapon", {socket})`。
## @end-static-doc

## Data of the socket this card represents (enriched, localized by the screen).
signal weapon_dropped(payload: Dictionary, socket: Dictionary)
signal command_requested(command: StringName, params: Dictionary)
signal hovered(socket_name: String)
signal unhovered(socket_name: String)

const CONTENT_MARGIN := Vector2(8.0, 6.0)

var socket: Dictionary = {}

var _title: Label = null
var _badge: SNBadge = null
var _weapon_label: Label = null
var _meta: Label = null
var _hint: Label = null
var _uninstall_button: SNButton = null
var _dragover := false


## Binds one socket row. Safe before / after `_ready()`.
func configure(row: Dictionary) -> void:
	socket = row.duplicate(true)
	if is_node_ready():
		_apply_content()
		_apply_style()


func is_dragover() -> bool:
	return _dragover


## What the card currently paints as the mounted weapon ("" when empty).
func weapon_text() -> String:
	return _weapon_label.text if _weapon_label != null else ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_build()
	_apply_content()
	_apply_style()
	mouse_entered.connect(func() -> void: hovered.emit(String(socket.get("socket", ""))))
	mouse_exited.connect(func() -> void:
		_dragover = false
		_apply_style()
		unhovered.emit(String(socket.get("socket", "")))
	)


func _build() -> void:
	if _title != null:
		return
	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	_title = _label(13, SNSkin.color("brass.highlight"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_badge = SNBadge.new()
	_badge.name = "InstalledBadge"
	_badge.tone = SNBadge.Tone.SUCCESS
	_badge.visible = false
	header.add_child(_badge)
	_weapon_label = _label(15, SNSkin.color("text.light"))
	box.add_child(_weapon_label)
	_meta = _label(11, SNSkin.color("text.muted"))
	box.add_child(_meta)
	_hint = _label(10, SNSkin.color("state.water"))
	box.add_child(_hint)
	_uninstall_button = SNButton.new()
	_uninstall_button.variant = SNButton.Variant.SECONDARY
	_uninstall_button.compact = true
	_uninstall_button.text = "Uninstall"
	_uninstall_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_uninstall_button.pressed.connect(func() -> void:
		command_requested.emit(&"ship.uninstall_weapon", {"socket": String(socket.get("socket", ""))})
	)
	box.add_child(_uninstall_button)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_content() -> void:
	if _title == null:
		return
	var occupied := bool(socket.get("occupied", not String(socket.get("weapon_id", "")).is_empty()))
	_title.text = String(socket.get("slot_title", socket.get("slot_label", String(socket.get("socket", "")))))
	_badge.text = String(socket.get("installed_tag", "已装"))
	_badge.visible = occupied
	if occupied:
		_weapon_label.text = String(socket.get("display_name", String(socket.get("weapon_id", ""))))
		_weapon_label.add_theme_color_override("font_color", SNSkin.color("text.light"))
	else:
		_weapon_label.text = String(socket.get("empty_text", "空槽位"))
		_weapon_label.add_theme_color_override("font_color", SNSkin.color("text.muted"))
	var meta_parts: PackedStringArray = []
	if occupied:
		meta_parts.append("%s %s" % [
			String(socket.get("weight_label", "重量")),
			_format(float(socket.get("weight", 0.0))),
		])
		meta_parts.append("%s %s" % [
			String(socket.get("damage_label", "伤害")),
			_format(float(socket.get("damage", 0.0))),
		])
	_meta.text = " · ".join(meta_parts)
	_meta.visible = not meta_parts.is_empty()
	_hint.text = "" if occupied else String(socket.get("drop_hint", ""))
	_hint.visible = not _hint.text.is_empty()
	_uninstall_button.text = String(socket.get("uninstall_text", "Uninstall"))
	_uninstall_button.visible = occupied and bool(socket.get("can_uninstall", true))
	tooltip_text = String(socket.get("slot_title", ""))


func _format(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## Skin-backed card sheet. Dragover / hover only tint; the socket / weapon state
## stays readable because it never swaps the card for a flat highlight.
func _apply_style() -> void:
	if not is_node_ready():
		return
	var highlighted := _dragover
	var base_style: StyleBoxTexture = SNSkin.style("panel_steel" if highlighted else "panel_recess")
	if base_style == null:
		theme_type_variation = &"SNInsetPanel"
		return
	var style := base_style.duplicate() as StyleBoxTexture
	style.content_margin_left = CONTENT_MARGIN.x
	style.content_margin_right = CONTENT_MARGIN.x
	style.content_margin_top = CONTENT_MARGIN.y
	style.content_margin_bottom = CONTENT_MARGIN.y
	if _dragover:
		style.modulate_color = SNSkin.color("state.water")
	add_theme_stylebox_override("panel", style)


func _accepts(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload: Dictionary = data
	if String(payload.get("kind", "")) != "ship_weapon":
		return false
	if String(payload.get("weapon_id", "")).is_empty():
		return false
	if String(payload.get("weapon_class", "")) != String(socket.get("socket_class", "")):
		return false
	var installed := String(socket.get("weapon_id", ""))
	if not installed.is_empty() and installed == String(payload.get("weapon_id", "")):
		return false
	return true


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var accepted := _accepts(data)
	if accepted != _dragover:
		_dragover = accepted
		set_process(accepted)
		_apply_style()
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_dragover = false
	set_process(false)
	_apply_style()
	if not _accepts(data):
		return
	weapon_dropped.emit((data as Dictionary).duplicate(true), socket.duplicate(true))


func _process(_delta: float) -> void:
	# Godot only notifies the drag source about drag end; a card highlighted by a
	# drag released elsewhere would otherwise stay lit until the page rebuilds.
	if _dragover and is_inside_tree() and not get_viewport().gui_is_dragging():
		_dragover = false
		set_process(false)
		_apply_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_dragover = false
		set_process(false)
		_apply_style()
