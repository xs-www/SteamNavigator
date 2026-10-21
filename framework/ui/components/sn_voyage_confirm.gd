class_name SNVoyageConfirm
extends Control
## @static-doc
## 作用：海图内的出航确认弹窗（阶段 4.3.4 / U7）。以半透明遮罩 + 居中面板覆盖海图，
## 展示航线预估（距离 / 预计时间 / 煤水 / 风险 / 发现概率）、可行性 blockers、
## 锅炉策略切换与「取消 / 启航」。普通出航与「循线索出航」共用同一个弹窗。
##
## - 关键依赖：Shell 组合好的 `departure` 字典与本地化回调；本控件不查询、不发命令。
##
## ## 契约与约束
## - `bind(data, translate)` 注入数据，数据形状见 `main.gd` 的 `_chart_departure_model()`：
##   `{kind: "voyage"|"explore", target_name, current_port_name, strategy_id,
##     strategies: [{id, name}], preview: {feasible, blockers, distance,
##     duration_hours, coal_required, water_required, risk_score, risk_label,
##     discovery_chance}}`（名称/文案由 Shell 预翻译）。
## - 信号：`strategy_changed(strategy_id)`（Shell 用新策略重新查询预估并重开弹窗）、
##   `confirmed(strategy_id)`（Shell 直接执行 `voyage.start` / `explore.start`）、
##   `cancelled`（关闭弹窗）。
## - 不可行时「启航」禁用、blockers 逐条列出被翻译后的文案；面板不自行判断可行性。
## - 弹窗打开时遮罩吃掉点击（`mouse_filter = STOP`），避免误触下层海图。
## - 4.3.5 连续消耗只改页面读数与结算，不改变本弹窗的数据契约。
## @end-static-doc

signal confirmed(strategy_id: String)
signal cancelled
signal strategy_changed(strategy_id: String)

const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_RED := Color("c36b53")
const COLOR_GREEN := Color("76aa8c")
const PANEL_WIDTH := 520.0

var _data: Dictionary = {}
var _tr: Callable
var _strategy_picker: OptionButton = null
var _strategies: Array = []


func bind(data: Dictionary, translate: Callable) -> void:
	_data = data
	_tr = translate
	_strategies = data.get("strategies", []) if data.get("strategies", []) is Array else []
	_rebuild()


func get_strategy_id() -> String:
	if _strategy_picker != null and _strategies.size() > 0:
		var index := _strategy_picker.selected
		if index >= 0 and index < _strategies.size():
			return String((_strategies[index] as Dictionary).get("id", ""))
	return String(_data.get("strategy_id", ""))


func is_feasible() -> bool:
	var preview: Dictionary = _data.get("preview", {}) if _data.get("preview", null) is Dictionary else {}
	return bool(preview.get("feasible", true))


func _rebuild() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in get_children():
		remove_child(child)
		child.free()

	var shade := ColorRect.new()
	shade.name = "ConfirmShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.04, 0.05, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ConfirmPanel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var kind := String(_data.get("kind", "voyage"))
	var title_fallback := "确认出航" if kind == "voyage" else "循线索出航"
	box.add_child(_label(_loc(
		"ui.confirm.title.%s" % kind, title_fallback
	), 20, COLOR_BRASS))
	var current := String(_data.get("current_port_name", ""))
	var target := String(_data.get("target_name", ""))
	if kind == "explore":
		box.add_child(_label(_loc("ui.confirm.clue", "线索：%s") % target, 14, COLOR_TEXT))
	elif not current.is_empty() and not target.is_empty():
		box.add_child(_label(_loc("ui.confirm.route", "航线：%s → %s") % [current, target], 14, COLOR_TEXT))
	box.add_child(HSeparator.new())

	var preview: Dictionary = _data.get("preview", {}) if _data.get("preview", null) is Dictionary else {}
	_add_estimate_rows(box, preview, kind)
	_add_strategy_picker(box)
	_add_blockers(box, preview)
	box.add_child(HSeparator.new())
	box.add_child(_label(_loc("ui.confirm.hint", "出航后不能更改策略；遇到事件时只能从本次抽样出的选项中选择。"), 11, COLOR_MUTED))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = _loc("ui.button.cancel", "取消")
	cancel.theme_type_variation = &"SNGhostButton"
	cancel.pressed.connect(func() -> void: cancelled.emit())
	actions.add_child(cancel)
	var confirm := Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = _loc("ui.button.start_voyage", "启航")
	confirm.disabled = not bool(preview.get("feasible", true))
	confirm.pressed.connect(func() -> void: confirmed.emit(get_strategy_id()))
	actions.add_child(confirm)
	box.add_child(actions)


func _add_estimate_rows(box: VBoxContainer, preview: Dictionary, kind: String) -> void:
	var distance := float(preview.get("distance", 0.0))
	if distance > 0.0:
		box.add_child(_kv(_loc("ui.label.distance", "距离"), "%d %s" % [
			int(roundf(distance)), _loc("unit.nautical_miles", "海里"),
		]))
	var duration := float(preview.get("duration_hours", 0.0))
	if duration > 0.0:
		box.add_child(_kv(_loc("ui.label.estimated_time", "预计时间"), _format_duration(duration)))
	var coal := float(preview.get("coal_required", 0.0))
	var water := float(preview.get("water_required", 0.0))
	if coal > 0.0 or water > 0.0:
		box.add_child(_kv("%s / %s" % [_loc("ui.label.coal", "煤炭"), _loc("ui.label.water", "淡水")],
			"%s / %s" % [_format_amount(coal), _format_amount(water)]))
	var risk_level := float(preview.get("risk_score", 0.0))
	var risk_band := String(preview.get("risk_label", ""))
	if kind == "explore" and preview.has("discovery_chance"):
		box.add_child(_kv(_loc("ui.confirm.discovery_chance", "发现概率"), "%d%%" % int(roundf(
			clampf(float(preview.get("discovery_chance", 0.0)), 0.0, 1.0) * 100.0
		))))
	if risk_band == "unknown" or risk_level < 0.0:
		box.add_child(_kv(_loc("ui.label.risk", "风险"), _loc("ui.label.risk_unknown", "无法评估")))
	else:
		var band_text := _loc("risk." + risk_band, risk_band) if not risk_band.is_empty() \
			else _loc("risk." + VoyageCalculator.risk_label(risk_level), "")
		box.add_child(_kv(_loc("ui.label.risk", "风险"), band_text, _risk_color(risk_band, risk_level)))
	if preview.get("on_time", true) == false:
		box.add_child(_label(_loc("ui.confirm.on_time", "按本航程预计会迟到。"), 12, COLOR_RED))


func _add_strategy_picker(box: VBoxContainer) -> void:
	if _strategies.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := _label(_loc("ui.confirm.strategy", "锅炉策略"), 13, COLOR_MUTED)
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	_strategy_picker = OptionButton.new()
	_strategy_picker.name = "StrategyPicker"
	_strategy_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected := String(_data.get("strategy_id", ""))
	for index in _strategies.size():
		var entry: Dictionary = _strategies[index] if _strategies[index] is Dictionary else {}
		_strategy_picker.add_item(String(entry.get("name", entry.get("id", ""))))
		_strategy_picker.set_item_metadata(index, String(entry.get("id", "")))
		if String(entry.get("id", "")) == selected:
			_strategy_picker.select(index)
	_strategy_picker.item_selected.connect(func(index: int) -> void:
		strategy_changed.emit(String(_strategy_picker.get_item_metadata(index)))
	)
	row.add_child(_strategy_picker)
	box.add_child(row)


func _add_blockers(box: VBoxContainer, preview: Dictionary) -> void:
	var blockers: Array = preview.get("blockers", [])
	if blockers.is_empty():
		return
	box.add_child(_label(_loc("ui.confirm.blockers", "无法出航："), 12, COLOR_RED))
	for blocker in blockers:
		if not (blocker is Dictionary):
			continue
		var message_key := String((blocker as Dictionary).get("message_key", ""))
		if message_key.is_empty():
			continue
		box.add_child(_label("· " + _loc(message_key, String((blocker as Dictionary).get("code", ""))), 11, COLOR_RED))


func _kv(name: String, value: String, color: Color = COLOR_TEXT) -> Control:
	var row := HBoxContainer.new()
	var key := _label(name, 13, COLOR_MUTED)
	key.custom_minimum_size = Vector2(130, 0)
	row.add_child(key)
	row.add_child(_label(value, 13, color))
	return row


func _loc(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	if _tr.is_valid():
		var text := String(_tr.call(key))
		if not text.is_empty() and text != key:
			return text
	return fallback


func _risk_color(band: String, score: float) -> Color:
	match band:
		"low": return COLOR_GREEN
		"medium": return COLOR_BRASS
		"high": return COLOR_RED
		_: return COLOR_MUTED if score < 0.0 else COLOR_TEXT


## `36` / `36.5` — one decimal only when it adds information.
func _format_amount(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


func _format_duration(hours: float) -> String:
	var total := maxi(0, int(roundf(hours)))
	var days := total / 24
	var remainder := total % 24
	if days > 0 and remainder > 0:
		return "%d %s %d %s" % [days, _loc("unit.days", "天"), remainder, _loc("unit.hours", "小时")]
	if days > 0:
		return "%d %s" % [days, _loc("unit.days", "天")]
	return "%d %s" % [remainder, _loc("unit.hours", "小时")]


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.13, 0.145, 0.98)
	style.border_color = Color(0.35, 0.55, 0.52, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	return style
