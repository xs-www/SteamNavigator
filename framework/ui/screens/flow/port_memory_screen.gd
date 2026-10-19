class_name PortMemoryScreen
extends VBoxContainer
## Read-only snapshot for a previously visited port.

signal navigation_requested(screen_id: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const TEAL := Color("76aaa7")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear()
	var error_text := String(vm.get("error_text", ""))
	if not error_text.is_empty():
		var error := _panel(); var error_box := _content(error); error_box.add_child(_label(error_text, 14, RED)); error_box.add_child(_back_button()); add_child(error); return
	add_child(_heading("港口记忆", _loc(String(vm.get("name_key", "")), String(vm.get("port_id", ""))), "上次在港时的只读快照"))
	var panel := _panel(); var box := _content(panel)
	if bool(vm.get("has_memory", false)):
		box.add_child(_label("%s：%s · %s" % [_loc("ui.label.last_visit", ""), String(vm.get("captured_label", "")), String(vm.get("age_text", ""))], 14, TEXT)); box.add_child(_label(_loc("ui.label.readonly_memory", ""), 12, MUTED)); box.add_child(_market_grid(vm.get("market", [])))
	else:
		box.add_child(_label("没有该港口的到港市场记录。", 14, MUTED))
	if bool(vm.get("facilities_known", false)):
		var facilities: Array = vm.get("facility_labels", []); box.add_child(_label("设施：" + (", ".join(facilities) if not facilities.is_empty() else "—"), 13, MUTED))
	box.add_child(_back_button()); add_child(panel)


func _market_grid(rows: Array) -> GridContainer:
	var grid := GridContainer.new(); grid.columns = 4
	for heading in ["商品", "上次单价", "上次储备", "买卖"]: grid.add_child(_label(heading, 12, MUTED))
	for row in rows:
		var buyable := bool(row.get("buyable", true)); var supply := bool(row.get("is_supply", false)); grid.add_child(_label(_loc(String(row.get("name_key", "")), String(row.get("item_id", ""))), 13, TEXT)); grid.add_child(_label(str(int(row.get("price", 0))), 13, TEAL)); grid.add_child(_label(str(int(row.get("stock", 0))), 13, TEXT)); grid.add_child(_label(_loc("ui.label.supply", "Supply") if supply else ("可买" if buyable else _loc("ui.label.sell_only", "")), 13, BRASS if supply else (GREEN if buyable else MUTED)))
	return grid
func _back_button() -> Button:
	var button := Button.new(); button.text = _loc("ui.button.back_overview", ""); button.pressed.connect(func(): navigation_requested.emit(&"overview", {})); return button
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
