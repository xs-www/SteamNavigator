class_name AtSeaScreen
extends VBoxContainer
## Passive sailing-state presentation.

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const TEAL := Color("76aaa7")


func bind(vm: Dictionary, _translate: Callable) -> void:
	_clear(); var panel := PanelContainer.new(); var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); box.add_child(_label("航行中", 20, TEAL))
	if bool(vm.get("has_voyage", false)):
		box.add_child(_label("%s → %s" % [vm.get("origin_name", ""), vm.get("destination_name", "")], 15, TEXT)); box.add_child(_label("预计抵达 %s" % ClockService.format_time(float(vm.get("arrival_time", 0.0))), 13, MUTED))
	else: box.add_child(_label("正在等待航行结算……", 13, MUTED))
	box.add_child(_label("当前画面会在抵达后自动刷新。", 12, MUTED)); add_child(panel)
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
