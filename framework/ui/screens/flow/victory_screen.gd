class_name VictoryScreen
extends VBoxContainer
## Victory summary presentation. Run reset/dismiss remain shell actions.

signal action_requested(action: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear(); var summary: Dictionary = vm.get("summary", {}); var achieved_at := float(vm.get("achieved_at", 0.0)); var timestamp := String(vm.get("achieved_at_label", ""))
	if timestamp.is_empty():
		var game_time := float(summary.get("game_time", achieved_at))
		if game_time > 0.0:
			timestamp = ClockService.format_time(game_time)
	add_child(_heading(_loc("ui.victory.eyebrow", "航程完成"), _loc("ui.victory.title", "通关"), timestamp))
	var panel := _panel(); panel.theme_type_variation = &"SNElevatedPanel"; var box := _content(panel); box.add_child(_label(_loc("ui.victory.subtitle", "大型船已组装完成，主线全部交付。"), 15, TEXT))
	var voyages := int(summary.get("voyages", 0)); var on_time := int(summary.get("on_time", 0)); var rate := float(summary.get("on_time_rate", -1.0))
	if rate < 0.0:
		rate = float(on_time) / float(maxi(1, voyages))
	if rate > 1.0:
		rate /= 100.0
	var accidents := int(summary.get("accidents", 0))
	var stats := HBoxContainer.new(); stats.add_theme_constant_override("separation", 6); stats.add_child(_stat(_loc("ui.victory.seed", "种子"), str(int(summary.get("seed", 0))), BRASS)); stats.add_child(VSeparator.new()); stats.add_child(_stat(_loc("ui.victory.voyages", "航次"), str(voyages), TEXT)); stats.add_child(VSeparator.new()); stats.add_child(_stat(_loc("ui.victory.on_time", "准时率"), "%d / %d（%.0f%%）" % [on_time, voyages, rate * 100.0], GREEN)); stats.add_child(VSeparator.new()); stats.add_child(_stat(_loc("ui.victory.accidents", "事故"), str(accidents), RED if accidents > 0 else TEXT)); box.add_child(stats)
	var scenario_key := String(summary.get("starting_scenario_name_key", "")); box.add_child(_kv(_loc("ui.victory.starting_scenario", "起始场景"), _loc(scenario_key, String(summary.get("starting_scenario", ""))) if not scenario_key.is_empty() else String(summary.get("starting_scenario", "—"))))
	var hull_key := String(summary.get("hull_name_key", "")); box.add_child(_kv(_loc("ui.victory.hull", "船体"), _loc(hull_key, String(summary.get("hull_id", ""))) if not hull_key.is_empty() else String(summary.get("hull_id", "—"))))
	var income := int(summary.get("income", 0)); var expense := int(summary.get("expense", 0)); var profit := int(summary.get("profit", income - expense)); box.add_child(_kv(_loc("ui.victory.income", "收入"), str(income), GREEN)); box.add_child(_kv(_loc("ui.victory.expense", "支出"), str(expense), RED)); box.add_child(_kv(_loc("ui.victory.profit", "利润"), str(profit), GREEN if profit >= 0 else RED)); var debt := float(summary.get("debt_remaining", 0.0)); box.add_child(_kv(_loc("ui.victory.debt", "剩余债务"), _fmt(debt), RED if debt > 0.0 else TEXT)); box.add_child(_kv(_loc("ui.victory.durability", "耐久"), "%s / %s" % [_fmt(float(summary.get("durability", 0.0))), _fmt(float(summary.get("max_durability", 0.0)))]))
	var modules := PackedStringArray()
	for module in summary.get("modules", []):
		if module is Dictionary:
			modules.append(_loc(String(module.get("name_key", "")), String(module.get("module_id", ""))))
	box.add_child(_kv(_loc("ui.victory.modules", "已安装模块"), ", ".join(modules) if not modules.is_empty() else "—"))
	var buttons := HBoxContainer.new(); buttons.add_theme_constant_override("separation", 12); var again := _action_button(_loc("ui.button.play_again", "再来一局"), &"play_again"); again.theme_type_variation = &"SNPrimaryButton"; buttons.add_child(again); var keep := _action_button(_loc("ui.button.keep_playing", "继续游玩"), &"keep_playing"); keep.theme_type_variation = &"SNGhostButton"; buttons.add_child(keep); box.add_child(buttons); add_child(panel)


func _action_button(text: String, action: StringName) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(func(): action_requested.emit(action, {})); return button
func _stat(name: String, value: String, color: Color) -> Control:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var key := _label(name, 11, MUTED); key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(key); var val := _label(value, 16, color); val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(val); return box
func _kv(name: String, value: String, color: Color = TEXT) -> Control:
	var row := HBoxContainer.new(); var key := _label(name, 13, MUTED); key.custom_minimum_size.x = 160; row.add_child(key); var val := _label(value, 13, color); val.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(val); return row
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _fmt(value: float) -> String: return "%.1f" % value
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
