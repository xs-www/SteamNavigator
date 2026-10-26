class_name SNWeaponSocketTarget
extends Control
## @static-doc
## 作用：蓝图上的单个武器槽位贴片：两行自绘（槽位短标签 + 已装武器名 / 空槽位），
## 区分空槽 / 已装 / 高亮 / 拖拽悬停四种状态，并作为 `ship_weapon` 拖放落点。
##
## ## 状态语义
## - 空槽：`panel_recess` 凹槽底板 + 暗色蒙版 + `text.muted` 文字；已装：`panel_steel`
##   钢板 + `brass.base` 黄铜蒙版 + 亮色文字。两种状态的底板与第二行文字始终不同；
##   高亮 / 悬停只改描边与青色蒙版，不会把已装与空槽画成同一种颜色（旧版小框把两者
##   都涂成青色，玩家装配后看不出变化）。
## - `set_highlighted(true)`（武器分类 / 右侧卡片 hover）：青色描边 + 四角标记。
## - 拖放兼容悬停（`_can_drop_data` 返回 true）：更粗的青色描边 + 青色角标，表示当前
##   载荷可以落在本槽位。
##
## ## 拖放载荷契约
## - 只接受 `{kind:"ship_weapon", weapon_id, weapon_class, source, name}`：
##   `weapon_class` 必须等于本行 `socket_class`（大小写不敏感），
##   `source ∈ {warehouse, purchase}`；已装同一 `weapon_id` 时拒绝（避免重复安装）。
## - `_drop_data` 把**完整载荷**与**槽位行字典**一起从 `weapon_dropped` 发出；
##   `SNShipView` 汇总成 `weapon_drop_requested`，页面据此发 `ship.install_weapon`。
## - 贴片默认接受拖放；页面用 `set_drop_enabled(false)` 关闭非武器分类 / 非装配页签的
##   接收。可见性由 `SNShipView` 的模式与布局决定，与是否接受拖放无关。
##
## ## 字段契约（`configure(row)`）
## - 必含：`socket`、`socket_class`、`weapon_id`、`display_name`、`slot_label`、
##   `empty_text`、`occupied`；可选：`slot_title`（完整本地化炮位名，作 tooltip）、
##   `view`（"side" / "top"，由 SNShipView 注入）。
## - 旧调用兜底：缺 `slot_label` 用 socket 名尾部（`SN_Socket_Weapon_Port_1` → `Port 1`），
##   缺 `display_name` 用 `name_key` / `weapon_id`，缺 `empty_text` 用 `"Empty"`，
##   缺 `occupied` 按 `weapon_id` 是否为空推断；归一化后的字段写回 `row`。
##
## ## 外观来源（外部贴图 + SNSkin）
## - 颜色只取 `SNSkin.color(token)`，底板只用 `SNSkin.style("panel_recess" /
##   "panel_steel")`；本文件不写十六进制色、不自建 StyleBoxFlat。
## - 36 px 贴片避不开九宫格 19 px 的黄铜角饰：两行文字下方有 `bg.abyss` 低透明内衬带，
##   并带 2 px 深色描边（`draw_string_outline`），长武器名按可用宽度截断并加省略号，
##   文字不再压角饰。
## - 全部自绘、无子节点；尺寸由 `SNShipView.weapon_socket_display_rects()` 决定，
##   本控件不设 custom_minimum_size。
## @end-static-doc

## Drag payload accepted / dropped. `payload` is the whole drag dictionary
## (top-level `kind == "ship_weapon"`); `socket` is the normalized row dictionary
## (same fields as `configure()`'s input, so the screen can read `socket.socket`).
signal weapon_dropped(payload: Dictionary, socket: Dictionary)
## Hover started on this patch (right-hand cards can mirror the highlight).
signal hovered(socket_name: String)
## Hover left this patch.
signal unhovered

const CARD_PADDING := 10.0
const TITLE_FONT_SIZE := 11
const VALUE_FONT_SIZE := 12
## Baseline positions relative to the patch height: two readable lines inside >=30 px.
const TITLE_BASELINE_RATIO := 0.42
const VALUE_BASELINE_RATIO := 0.84
## The skin nine-slice keeps 19 px brass corner ornaments, which a 36 px patch
## cannot avoid. Text therefore sits on a dark inner band and carries a dark
## outline, so both lines stay readable on the brass (occupied) plate too.
const TEXT_BAND_INSET_X := 5.0
const TEXT_BAND_INSET_Y := 2.0
const TEXT_BAND_ALPHA := 0.34
const TEXT_OUTLINE_SIZE := 2
const TEXT_OUTLINE_ALPHA := 0.9
const CORNER_LENGTH := 6.0
const DRAG_SOURCES := ["warehouse", "purchase"]
const SOCKET_PREFIX := "SN_Socket_Weapon_"

## Normalized socket row (see field contract above). Public: SNShipView and tests
## read it to know which socket / view this patch belongs to.
var row: Dictionary = {}
## Blueprint view this patch is drawn on: "side" or "top".
var view: String = ""

var _title := ""
var _display := ""
var _occupied := false
var _highlighted := false
var _drop_hover := false
var _drop_enabled := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	queue_redraw()


## Binds one weapon socket row. Safe before `_ready()`: drawing reads these fields.
func configure(slot_row: Dictionary) -> void:
	row = slot_row.duplicate(true)
	view = String(row.get("view", ""))
	var socket_name := socket_name()
	var weapon_id := String(row.get("weapon_id", ""))
	var occupied := bool(row.get("occupied", not weapon_id.is_empty()))
	var display_name := String(row.get("display_name", ""))
	if display_name.is_empty() and occupied:
		display_name = String(row.get("name_key", ""))
		if display_name.is_empty():
			display_name = weapon_id
	_occupied = occupied
	_title = String(row.get("slot_label", ""))
	if _title.is_empty():
		_title = _fallback_slot_label(socket_name)
	var empty_text := String(row.get("empty_text", ""))
	if empty_text.is_empty():
		empty_text = "Empty"
	_display = display_name if occupied else empty_text
	# Normalized fields travel back to the screen through `weapon_dropped`.
	row["socket"] = socket_name
	row["display_name"] = display_name
	row["slot_label"] = _title
	row["empty_text"] = empty_text
	row["occupied"] = occupied
	var tooltip := String(row.get("slot_title", ""))
	if tooltip.is_empty():
		tooltip = _title
		if occupied and not display_name.is_empty():
			tooltip = "%s · %s" % [_title, display_name]
	tooltip_text = tooltip
	queue_redraw()


## Highlight state from the shipyard (weapons category / hovered socket card).
## Only changes the ring colour, never the occupied / empty plate and text colour.
func set_highlighted(active: bool) -> void:
	if _highlighted == active:
		return
	_highlighted = active
	queue_redraw()


## Whether this patch accepts `ship_weapon` drops (page disables it outside the
## weapons category / install tab). Visibility is not affected.
func set_drop_enabled(enabled: bool) -> void:
	if _drop_enabled == enabled:
		return
	_drop_enabled = enabled
	if not enabled:
		_drop_hover = false
	queue_redraw()


func socket_name() -> String:
	return String(row.get("socket", row.get("name", "")))


func slot_label() -> String:
	return _title


## Localized installed weapon name, empty for an empty socket.
func display_name() -> String:
	return _display if _occupied else ""


## Second line as drawn: weapon name when occupied, empty-slot text otherwise.
func display_text() -> String:
	return _display


func is_occupied() -> bool:
	return _occupied


func is_highlighted() -> bool:
	return _highlighted


func is_drop_hovering() -> bool:
	return _drop_hover


func is_drop_enabled() -> bool:
	return _drop_enabled


## Public drop predicate (same rules as `_can_drop_data`). Tests can call this
## without going through the drag system; `_can_drop_data` just adds hover state.
func accepts_payload(data: Variant) -> bool:
	if not _drop_enabled:
		return false
	if not (data is Dictionary):
		return false
	var payload: Dictionary = data
	if String(payload.get("kind", "")) != "ship_weapon":
		return false
	var weapon_id := String(payload.get("weapon_id", ""))
	if weapon_id.is_empty():
		return false
	if not DRAG_SOURCES.has(String(payload.get("source", ""))):
		return false
	var socket_class := String(row.get("socket_class", ""))
	if socket_class.is_empty():
		return false
	if String(payload.get("weapon_class", "")).to_lower() != socket_class.to_lower():
		return false
	if _occupied and String(row.get("weapon_id", "")) == weapon_id:
		return false
	return true


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var accepted := accepts_payload(data)
	if _drop_hover != accepted:
		_drop_hover = accepted
		queue_redraw()
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var accepted := accepts_payload(data)
	_drop_hover = false
	queue_redraw()
	if not accepted:
		return
	weapon_dropped.emit((data as Dictionary).duplicate(true), row.duplicate(true))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(socket_name())
	elif what == NOTIFICATION_MOUSE_EXIT:
		if _drop_hover:
			_drop_hover = false
			queue_redraw()
		unhovered.emit()
	elif what == NOTIFICATION_DRAG_END:
		if _drop_hover:
			_drop_hover = false
			queue_redraw()


# ---------------------------------------------------------------------------
# Self-drawn patch: skin plate + occupancy tint + state ring + two text lines.
# ---------------------------------------------------------------------------
func _draw() -> void:
	if size.x < 24.0 or size.y < 16.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	_draw_plate(rect)
	_draw_state_ring(rect)
	_draw_text()


## Occupied keeps a brass plate, empty keeps the dark recess: that difference is
## what the player reads after installing a weapon, so it is never state-tinted.
func _draw_plate(rect: Rect2) -> void:
	var plate_id := "panel_steel" if _occupied else "panel_recess"
	var box := SNSkin.style(plate_id)
	if box != null:
		draw_style_box(box, rect)
	else:
		draw_rect(rect, SNSkin.color("steel.raised" if _occupied else "steel.recess"), true)
	if _occupied:
		draw_rect(rect, Color(SNSkin.color("brass.base"), 0.5), true)
	else:
		draw_rect(rect, Color(SNSkin.color("bg.abyss"), 0.38), true)
	if _drop_hover:
		draw_rect(rect, Color(SNSkin.color("state.water"), 0.16), true)


func _draw_state_ring(rect: Rect2) -> void:
	var ring_color := SNSkin.color("brass.highlight") if _occupied else SNSkin.color("brass.shadow")
	var width := 1.0
	if _highlighted:
		ring_color = SNSkin.color("state.water")
		width = 2.0
	if _drop_hover:
		ring_color = SNSkin.color("state.water")
		width = 3.0
	draw_rect(rect.grow(-width * 0.5), ring_color, false, width)
	if _highlighted or _drop_hover:
		_draw_corners(rect, ring_color)


func _draw_corners(rect: Rect2, color: Color) -> void:
	var inset := 2.0
	var length := minf(CORNER_LENGTH, minf(rect.size.x, rect.size.y) * 0.25)
	var left := rect.position.x + inset
	var right := rect.end.x - inset
	var top := rect.position.y + inset
	var bottom := rect.end.y - inset
	draw_line(Vector2(left, top), Vector2(left + length, top), color, 2.0)
	draw_line(Vector2(left, top), Vector2(left, top + length), color, 2.0)
	draw_line(Vector2(right, top), Vector2(right - length, top), color, 2.0)
	draw_line(Vector2(right, top), Vector2(right, top + length), color, 2.0)
	draw_line(Vector2(left, bottom), Vector2(left + length, bottom), color, 2.0)
	draw_line(Vector2(left, bottom), Vector2(left, bottom - length), color, 2.0)
	draw_line(Vector2(right, bottom), Vector2(right - length, bottom), color, 2.0)
	draw_line(Vector2(right, bottom), Vector2(right, bottom - length), color, 2.0)


func _draw_text() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var text_width := size.x - CARD_PADDING * 2.0
	if text_width <= 8.0:
		return
	# Dark band behind the glyphs: the nine-slice corners reach into the patch, and
	# a light weapon name on a brass plate needs this contrast everywhere.
	var band := Rect2(
		Vector2(TEXT_BAND_INSET_X, TEXT_BAND_INSET_Y),
		Vector2(maxf(size.x - TEXT_BAND_INSET_X * 2.0, 1.0), maxf(size.y - TEXT_BAND_INSET_Y * 2.0, 1.0))
	)
	draw_rect(band, Color(SNSkin.color("bg.abyss"), TEXT_BAND_ALPHA), true)
	var title_color := SNSkin.color("text.light") if _occupied else SNSkin.color("text.muted")
	if _highlighted or _drop_hover:
		title_color = SNSkin.color("state.water")
	var value_color := SNSkin.color("text.light") if _occupied else SNSkin.color("text.muted")
	var outline := Color(SNSkin.color("bg.abyss"), TEXT_OUTLINE_ALPHA)
	var title_text := _fit_text(font, _title, TITLE_FONT_SIZE, text_width)
	var value_text := _fit_text(font, _display, VALUE_FONT_SIZE, text_width)
	var title_baseline := size.y * TITLE_BASELINE_RATIO
	var value_baseline := size.y * VALUE_BASELINE_RATIO
	draw_string_outline(font, Vector2(CARD_PADDING, title_baseline), title_text,
		HORIZONTAL_ALIGNMENT_LEFT, text_width, TITLE_FONT_SIZE, TEXT_OUTLINE_SIZE, outline)
	draw_string(font, Vector2(CARD_PADDING, title_baseline), title_text,
		HORIZONTAL_ALIGNMENT_LEFT, text_width, TITLE_FONT_SIZE, title_color)
	draw_string_outline(font, Vector2(CARD_PADDING, value_baseline), value_text,
		HORIZONTAL_ALIGNMENT_LEFT, text_width, VALUE_FONT_SIZE, TEXT_OUTLINE_SIZE, outline)
	draw_string(font, Vector2(CARD_PADDING, value_baseline), value_text,
		HORIZONTAL_ALIGNMENT_LEFT, text_width, VALUE_FONT_SIZE, value_color)


## Trims a line with a trailing ellipsis so long weapon names never spill over the
## patch edge (the text band is narrow on purpose).
func _fit_text(font: Font, text: String, font_size: int, max_width: float) -> String:
	if text.is_empty():
		return text
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
		return text
	var ellipsis := "…"
	var trimmed := text
	while not trimmed.is_empty():
		trimmed = trimmed.substr(0, trimmed.length() - 1)
		if font.get_string_size(trimmed + ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			return trimmed + ellipsis
	return ellipsis


## Legacy rows without `slot_label`: `SN_Socket_Weapon_Port_1` -> `Port 1`.
func _fallback_slot_label(socket_name_value: String) -> String:
	var label := socket_name_value
	if label.begins_with(SOCKET_PREFIX):
		label = label.substr(SOCKET_PREFIX.length())
	return label.replace("_", " ")
