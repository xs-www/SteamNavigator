class_name SettlementScreen
extends VBoxContainer
## Arrival settlement presentation.

signal navigation_requested(screen_id: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear()
	var summary: Dictionary = vm.get("summary", {}); var ship: Dictionary = vm.get("ship", {}); var contracts: Array = summary.get("contracts", [])
	add_child(_heading("航次完成", "抵达 %s" % String(vm.get("destination_name", "目的港")), ClockService.format_time(float(summary.get("arrival_time", 0.0)))))
	var panel := _panel(); panel.theme_type_variation = &"SNElevatedPanel"; var box := _content(panel); var payout := 0; var on_time := 0
	for contract in contracts:
		if contract is Dictionary:
			payout += int(contract.get("payout", 0))
			if bool(contract.get("on_time", false)):
				on_time += 1
	var stats := HBoxContainer.new(); stats.add_theme_constant_override("separation", 6); stats.add_child(_stat("委托收入", str(payout), BRASS)); stats.add_child(VSeparator.new()); stats.add_child(_stat("准时交付", "%d / %d" % [on_time, contracts.size()], GREEN)); stats.add_child(VSeparator.new()); var delayed := float(summary.get("delayed_hours", 0.0)); stats.add_child(_stat("延误", "%s h" % _fmt(delayed), RED if delayed > 0.0 else TEXT)); stats.add_child(VSeparator.new()); stats.add_child(_stat("当前金币", str(int(vm.get("money", 0))), BRASS)); box.add_child(stats)
	var resources := HBoxContainer.new(); resources.add_theme_constant_override("separation", 18); resources.add_child(_badge("煤炭 %s" % _fmt(float(ship.get("coal", 0.0))), SNBadge.Tone.WARNING)); resources.add_child(_badge("淡水 %s" % _fmt(float(ship.get("water", 0.0))), SNBadge.Tone.NEUTRAL)); resources.add_child(_badge("耐久 %s / %s" % [_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0)))], SNBadge.Tone.SUCCESS if float(ship.get("durability", 0.0)) > float(ship.get("max_durability", 1.0)) * 0.5 else SNBadge.Tone.DANGER)); box.add_child(resources)
	if not contracts.is_empty(): box.add_child(_label("交付明细", 14, BRASS))
	for contract in contracts:
		if not (contract is Dictionary): continue
		var row := HBoxContainer.new(); var name := _label(String(contract.get("display_name", contract.get("template_id", ""))), 13, TEXT); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(name); var timely := bool(contract.get("on_time", false)); row.add_child(_badge("准时" if timely else "延误", SNBadge.Tone.SUCCESS if timely else SNBadge.Tone.DANGER)); row.add_child(_label("+%d" % int(contract.get("payout", 0)), 13, BRASS)); box.add_child(row)
	var injuries := int(summary.get("injuries", 0))
	if injuries > 0:
		box.add_child(_label("旅客受伤 %d 人" % injuries, 13, RED))
	var enter := Button.new(); enter.text = "进入港口"; enter.pressed.connect(func(): navigation_requested.emit(&"overview", {})); box.add_child(enter); add_child(panel)


func _stat(name: String, value: String, color: Color) -> Control:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var key := _label(name, 11, MUTED); key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(key); var val := _label(value, 16, color); val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(val); return box
func _badge(text: String, tone: SNBadge.Tone) -> SNBadge:
	var badge := SNBadge.new(); badge.text = text; badge.tone = tone; return badge
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label
func _fmt(value: float) -> String: return "%.1f" % value
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
