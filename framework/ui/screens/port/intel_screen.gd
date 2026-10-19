class_name IntelScreen
extends VBoxContainer
## Intelligence report presentation; queries and commands remain in the shell.

signal command_requested(command: StringName, params: Dictionary)

const INTEL_TABLE_SCRIPT := preload("res://framework/ui/components/sn_intel_table.gd")
const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const TEAL := Color("76aaa7")
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	add_child(_heading("航路情报站", "商情报告", _loc("ui.hint.intel", "")))
	add_child(_header(vm))
	var rows: Array = vm.get("rows", [])
	if rows.is_empty():
		add_child(_message(_loc("ui.intel.empty", "")))
	else:
		var table: Variant = INTEL_TABLE_SCRIPT.new()
		table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.bind(vm.get("columns", []), rows, String(vm.get("current_port_id", "")), _tr)
		add_child(table)
	add_child(_npc_panel(vm.get("npcs", [])))


func _header(vm: Dictionary) -> Control:
	var panel := _panel()
	var content := _content(panel)
	if bool(vm.get("has_report", false)):
		content.add_child(_label("%s：%s · %s" % [_loc("ui.label.generated", ""), vm.get("generated_label", ""), _age(float(vm.get("age_hours", 0.0)))], 14, TEXT))
		content.add_child(_label(_loc("ui.intel.summary", "") % [int(vm.get("port_count", 0)), int(vm.get("column_count", 0)), int(vm.get("npc_count", 0))], 12, MUTED))
		content.add_child(_label(_loc("ui.label.snapshot_tip", ""), 12, MUTED))
	else:
		content.add_child(_label(_loc("ui.label.no_intel", ""), 14, MUTED))
	if bool(vm.get("has_intel_facility", false)):
		var button := Button.new()
		button.text = "%s（%d 金币）" % [_loc("ui.button.refresh_intel", ""), int(vm.get("cost", 25))]
		button.disabled = not bool(vm.get("can_refresh", false))
		button.pressed.connect(func(): command_requested.emit(&"intel.refresh", {}))
		content.add_child(button)
	else:
		content.add_child(_label("当前港口没有情报站。", 12, MUTED))
	return panel


func _npc_panel(npcs: Array) -> Control:
	var panel := _panel()
	var content := _content(panel)
	content.add_child(_label("NPC 商船动向", 16, BRASS))
	if npcs.is_empty():
		content.add_child(_label("暂无覆盖到的 NPC 动向（未发现的目的港不会出现）。", 12, MUTED))
		return panel
	var grid := GridContainer.new()
	grid.columns = 4
	for heading in ["目的港", "货物", _loc("ui.label.action", ""), _loc("ui.label.eta", "")]:
		grid.add_child(_label(heading, 12, MUTED))
	for npc in npcs:
		grid.add_child(_label(_loc(String(npc.get("destination_name_key", "")), String(npc.get("destination", ""))), 13, TEXT))
		grid.add_child(_label(_loc(String(npc.get("item_name_key", "")), String(npc.get("item_id", ""))), 13, TEXT))
		grid.add_child(_label(_loc(String(npc.get("action_label_key", "")), String(npc.get("action", ""))), 13, TEAL))
		grid.add_child(_label("%s – %s" % [ClockService.format_time(float(npc.get("eta_from", 0.0))), ClockService.format_time(float(npc.get("eta_to", 0.0)))], 13, MUTED))
	content.add_child(grid)
	return panel


func _message(text: String) -> Control:
	var panel := _panel(); _content(panel).add_child(_label(text, 13, MUTED)); return panel
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label
func _age(hours: float) -> String:
	return "刚刚刷新" if hours < 0.5 else "%s 小时前" % _fmt(hours)
func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
