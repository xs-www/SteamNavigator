class_name SNSlotTarget
extends PanelContainer
## @static-doc
## 作用：纵剖图/侧视蓝图上的单个模块槽位贴片：显示槽位与已装模块，接收 `ship_parts` 拖放载荷，只校验来源与槽位类型；支持紧凑两行模式（P2b 贴锚点窄区）与拖放开关（P2a 模式隔离）。
##
## One refit slot chip in the SNShipView cutaway.
##
## Draws the slot title, the installed module (or 空), and accepts a dragged
## owned free module (SNPartRow payload, `kind = "ship_parts"`). The screen owns
## the command intent; this control only validates the module category and source.
##
## ## 尺寸 / 紧凑模式（P2b，2026-10-28）
## - 本控件不设 `custom_minimum_size`，尺寸由 `SNShipView` 的侧视锚点布局决定。
## - `set_compact(true)`：隐藏第三行 hint、字号 10/12、内容边距收紧到 20/2（水平仍留
##   20 px 避开 `panel_recess` 九宫格的 19 px 黄铜角饰），让贴片在窄侧视区域仍保持两行
##   可读；`false` 恢复标题 11 / 正文 13 / hint 10 的三行样式。
##
## ## 拖放开关（P2a，2026-10-28）
## - `set_drop_enabled(false)`：`_can_drop_data` / `_drop_data` 一律拒绝，供武器装配模式
##   隐藏普通槽位时关闭接收；只影响接收，不影响可见性（可见性由 `SNShipView` 控制）。
## - `is_hovering()`：供 `SNShipView` 轮询，让槽位圆点与贴片一起变青色。
##
## ## 拖放载荷契约（2026-10-26 修复）
## - `_drop_data` 必须把**完整拖拽载荷**（`{kind:"ship_parts", part:{...}}`）原样
##   duplicate 后从 `part_dropped` 发出，不能只发内层 `part`：船厂页
##   `_on_slot_drop(payload, slot)` 的契约是按 `SNPartRow._get_drag_data()` 的载荷
##   形状解析 `payload.part`。只发内层 part 会让真实拖放在页面侧静默落空
##   （空槽安装 / 已装替换都不触发命令），而直接调用页面函数的测试发现不了。
## - `part_dropped(payload, slot)` → `SNShipView.slot_drop_requested` →
##   `ShipyardScreen._on_slot_drop` 全链路保持同一载荷形状。
##
## ## 外观来源（外部贴图 + SNSkin）
## - 槽位底板不再手搓 `StyleBoxFlat`：取 `SNSkin.style("panel_recess")`（仪表凹槽
##   纹理），悬停 / 匹配 / 固定槽位改用 `SNSkin.style("panel_steel")` 并以
##   `modulate_color = SNSkin.color(token)` 区分（state.water / brass.highlight /
##   brass.base）；内容边距 8 / 4（紧凑模式 8 / 2），保持旧槽位尺寸与文字裁切。
## - 文字色取 `SNSkin.color(token)`；不写十六进制色，不新增子节点。
## - 尺寸/契约：`fixed` 槽位仍用最亮黄铜语义；拖放只认 `kind == "ship_parts"`
##   且来源为仓库 / 随船。
## @end-static-doc

signal part_dropped(payload: Dictionary, slot: Dictionary)
signal slot_activated(slot: Dictionary)


var slot: Dictionary = {}
var _title_label: Label
var _value_label: Label
var _meta_label: Label
var _hovering := false
var _compatible := false
var _compact := false
## P2a mode gate: weapons mode hides the module chips and stops accepting drops.
var _drop_enabled := true


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
	_meta_label.visible = not hint.is_empty() and not _compact
	tooltip_text = String(slot.get("tooltip", ""))
	_apply_compact_fonts()
	_apply_style()


func set_compatible_hint(active: bool) -> void:
	if _compatible == active:
		return
	_compatible = active
	_apply_style()


## P2b compact layout: drop the hint line and shrink fonts / vertical padding so
## the chip stays readable as a two-line box beside a narrow side view.
func set_compact(active: bool) -> void:
	if _compact == active:
		return
	_compact = active
	if not is_node_ready():
		return
	_meta_label.visible = not _compact and not String(slot.get("hint", "")).is_empty()
	_apply_compact_fonts()
	_apply_style()


func is_compact() -> bool:
	return _compact


## P2a: gate the `ship_parts` drop contract (weapons mode hides these chips).
func set_drop_enabled(enabled: bool) -> void:
	if _drop_enabled == enabled:
		return
	_drop_enabled = enabled
	if not enabled:
		_hovering = false
	_apply_style()


func is_drop_enabled() -> bool:
	return _drop_enabled


## True while a compatible drag hovers this chip (SNShipView mirrors it on the dot).
func is_hovering() -> bool:
	return _hovering


func _apply_compact_fonts() -> void:
	if _title_label == null:
		return
	_title_label.add_theme_font_size_override("font_size", 10 if _compact else 11)
	_value_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
	_meta_label.add_theme_font_size_override("font_size", 10)


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
## brass-tinted steel = fixed hull/boiler slots. Horizontal content margin stays at
## 20 px so the first glyph is not drawn on top of the nine-slice corner ornaments
## (the old 8 px inset clipped the category title, player feedback 2026-10-28).
func _apply_style() -> void:
	var highlighted := _hovering or _compatible or bool(slot.get("fixed", false))
	var style_id := "panel_steel" if highlighted else "panel_recess"
	var base_style: StyleBoxTexture = SNSkin.style(style_id)
	if base_style == null:
		theme_type_variation = &"SNInsetPanel"
		return
	var style := base_style.duplicate() as StyleBoxTexture
	style.content_margin_left = 20.0
	style.content_margin_right = 14.0
	style.content_margin_top = 2.0 if _compact else 4.0
	style.content_margin_bottom = 2.0 if _compact else 4.0
	if not _drop_enabled:
		style.modulate_color = SNSkin.color("text.muted")
	elif _hovering:
		style.modulate_color = SNSkin.color("state.water")
	elif _compatible:
		style.modulate_color = SNSkin.color("brass.highlight")
	elif bool(slot.get("fixed", false)):
		style.modulate_color = SNSkin.color("brass.base")
	add_theme_stylebox_override("panel", style)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _drop_enabled:
		return false
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


## The drop handler forwards the **whole drag payload** (top-level `kind ==
## "ship_parts"` plus the `part` sub-dictionary), not just the part: the shipyard
## screen's `_on_slot_drop(payload, slot)` contract is defined on the payload shape
## that `SNPartRow._get_drag_data()` produces. Emitting the bare `part` here made
## every real drop fall through `payload.get("part", {})` and silently do nothing
## (empty-slot install and filled-slot replacement both), while the keyless unit
## test that called the screen directly with a hand-built payload kept passing.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _drop_enabled:
		_hovering = false
		_apply_style()
		return
	if not (data is Dictionary):
		return
	var part: Dictionary = (data as Dictionary).get("part", {})
	if _accepts(part):
		_hovering = false
		_apply_style()
		part_dropped.emit((data as Dictionary).duplicate(true), slot)
		return
	_hovering = false
	_apply_style()


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
