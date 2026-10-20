class_name VoyageScreen
extends VBoxContainer
## Voyage selector and preview. The shell owns voyage.preview and voyage.start.

signal selection_changed(destination_id: String, strategy_id: String)
signal command_requested(command: StringName, params: Dictionary)
signal navigation_requested(screen_id: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")
var _tr: Callable
var _destination: OptionButton
var _strategy: OptionButton


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	add_child(_heading("航路规划", "出航准备", "出航前确认耗时、消耗与风险来源。"))
	if vm.get("destinations", []).is_empty() or vm.get("strategies", []).is_empty():
		add_child(_message("没有可用航线或锅炉策略。", RED)); return
	add_child(_selectors(vm))
	var preview: Dictionary = vm.get("preview", {})
	if not bool(preview.get("ok", false)):
		add_child(_message(String(preview.get("error_text", "无法生成航程预览")), RED)); return
	var data: Dictionary = preview.get("data", {})
	add_child(_details(data, vm))
	if not data.get("blockers", []).is_empty(): add_child(_blockers(data.get("blockers", [])))
	var action := _panel(); var content := _content(action)
	var depart := Button.new(); depart.text = _loc("ui.button.depart", "Depart"); depart.disabled = not bool(data.get("feasible", false))
	depart.pressed.connect(func(): command_requested.emit(&"voyage.start", {"destination_id": vm.get("selected_destination", ""), "strategy_id": vm.get("selected_strategy", "")}))
	var chart := Button.new(); chart.text = _loc("ui.button.sea_chart", "打开海图 (M)"); chart.pressed.connect(func(): navigation_requested.emit(&"sea_chart", {}))
	content.add_child(depart); content.add_child(chart); content.add_child(_label("出航后不能更改策略；遇到事件时只能从本次抽样出的选项中选择。", 12, MUTED)); add_child(action)


func _selectors(vm: Dictionary) -> Control:
	var panel := _panel(); var row := HBoxContainer.new(); panel.add_child(row)
	_destination = OptionButton.new(); _destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for destination in vm.get("destinations", []):
		_destination.add_item("%s · %.0f 海里" % [_loc(String(destination.get("name_key", "")), String(destination.get("port_id", ""))), float(destination.get("distance", 0.0))])
		_destination.set_item_metadata(_destination.item_count - 1, String(destination.get("port_id", "")))
		if String(destination.get("port_id", "")) == String(vm.get("selected_destination", "")): _destination.select(_destination.item_count - 1)
	_strategy = OptionButton.new()
	for strategy in vm.get("strategies", []):
		_strategy.add_item(_loc(String(strategy.get("name_key", "")), String(strategy.get("id", ""))))
		_strategy.set_item_metadata(_strategy.item_count - 1, String(strategy.get("id", "")))
		if String(strategy.get("id", "")) == String(vm.get("selected_strategy", "")): _strategy.select(_strategy.item_count - 1)
	_destination.item_selected.connect(_selection_updated); _strategy.item_selected.connect(_selection_updated)
	row.add_child(_destination); row.add_child(_strategy); return panel


func _selection_updated(_index: int) -> void:
	selection_changed.emit(String(_destination.get_item_metadata(_destination.selected)), String(_strategy.get_item_metadata(_strategy.selected)))


func _details(p: Dictionary, vm: Dictionary) -> Control:
	var panel := _panel(); var content := _content(panel)
	content.add_child(_label("航线：%s → %s%s" % [vm.get("current_port_name", ""), _loc(String(p.get("destination_name_key", "")), String(p.get("destination_id", ""))), "（主线目的港）" if bool(vm.get("is_main_destination", false)) else ""], 16, TEXT))
	content.add_child(_kv("距离", "%s 海里" % _fmt(float(p.get("distance", 0.0)))))
	content.add_child(_kv("有效航速", "%s · 重量系数 %s" % [_fmt(float(p.get("effective_speed", 0.0)), 2), _fmt(float(p.get("weight_factor", 1.0)), 2)]))
	content.add_child(_kv("耗时", "%s · 抵达 %s" % [ClockService.format_duration(float(p.get("duration_hours", 0.0))), ClockService.format_time(float(p.get("arrival_time", 0.0)))]))
	content.add_child(_kv("煤炭", "%s / %s" % [_fmt(float(p.get("coal_required", 0.0))), _fmt(float(p.get("coal_available", 0.0)))], RED if float(p.get("coal_required", 0.0)) > float(p.get("coal_available", 0.0)) else TEXT))
	content.add_child(_kv("淡水", "%s / %s" % [_fmt(float(p.get("water_required", 0.0))), _fmt(float(p.get("water_available", 0.0)))], RED if float(p.get("water_required", 0.0)) > float(p.get("water_available", 0.0)) else TEXT))
	content.add_child(_kv("重量", "%s / %s" % [_fmt(float(p.get("total_weight", 0.0))), _fmt(float(p.get("max_weight", 0.0)))]))
	content.add_child(_kv("船员工资", "%d 金币" % int(p.get("crew_wages", 0))))
	if float(p.get("deadline", -1.0)) >= 0.0: content.add_child(_kv("委托期限", "%s · %s" % [ClockService.format_time(float(p.get("deadline", 0.0))), "预计准时" if bool(p.get("on_time", false)) else "预计迟到"], GREEN if bool(p.get("on_time", false)) else RED))
	var risks := PackedStringArray(); for source in p.get("risk_sources", []): risks.append("%s %+.3f" % [_loc(String(source.get("key", "")), String(source.get("key", ""))), float(source.get("value", 0.0))])
	content.add_child(_kv("风险来源", "，".join(risks)))
	content.add_child(_kv("情报时间", "无" if float(p.get("intel_generated_at", -1.0)) < 0.0 else ClockService.format_time(float(p.get("intel_generated_at", 0.0)))))
	content.add_child(_kv("目的港设施", String(vm.get("facility_text", "未知")))); return panel


func _blockers(blockers: Array) -> Control:
	var parts := PackedStringArray(); for blocker in blockers: parts.append(_loc(String(blocker.get("message_key", "")), String(blocker.get("code", ""))))
	return _message("无法出航：" + "，".join(parts), RED)
func _kv(name: String, value: String, color: Color = TEXT) -> Control:
	var row := HBoxContainer.new(); var key := _label(name, 13, MUTED); key.custom_minimum_size.x = 110; row.add_child(key); row.add_child(_label(value, 13, color)); return row
func _message(text: String, color: Color) -> Control:
	var panel := _panel(); _content(panel).add_child(_label(text, 14, color)); return panel
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label
func _fmt(value: float, decimals: int = 1) -> String:
	return str(int(value)) if decimals == 1 and is_equal_approx(value, roundf(value)) else ("%.*f" % [decimals, value])
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
