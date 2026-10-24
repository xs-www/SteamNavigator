class_name PortMemoryScreen
extends VBoxContainer
## @static-doc
## 作用：港口记忆流程场景：只读展示上次到港时的市场和设施快照。
##
## - 关键依赖：`port.memory` 查询结果、`SNSectionHeader`、`SNSkin`、纹理化 Theme
##
## ## 契约与约束
## - bind(vm, translate) 接收 port.memory 结果及 Shell 补齐的 age_text/facility_labels，
##   不直接查询端口记忆或注册表。
## - 市场快照不提供交易按钮；返回操作只发出 overview navigation_requested。
## - 快照表四列使用明确最小宽度与横向间距，所有密集字段禁用自动换行，避免中文被
##   压成逐字竖排；`_label(text, size, color)` / `_grid_label(..., minimum_width)`
##   签名被 test_ui_shell 直接调用，不得改。
## - 查询失败时展示 error_text，并仍保留返回总览入口。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 快照是账册页：主面板与错误面板都用 `SNParchmentPanel`，正文取
##   `ink.primary`、次要说明取 `paper.ink_muted`、价格用 `brass.shadow`；
##   返回按钮用 `SNGhostButton`。颜色不再写常量，统一 `SNSkin.color(token)`。
## - 表格宽度（760 总宽 / 240/140/140/160 列）与 `PORT_MEMORY` 四列结构不变。
## @end-static-doc

signal navigation_requested(screen_id: StringName, params: Dictionary)

var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear()
	var error_text := String(vm.get("error_text", ""))
	if not error_text.is_empty():
		var error := _panel(); var error_box := _content(error); error_box.add_child(_label(error_text, 14, SNSkin.color("state.danger"))); error_box.add_child(_back_button()); add_child(error); return
	add_child(_heading("港口记忆", _loc(String(vm.get("name_key", "")), String(vm.get("port_id", ""))), "上次在港时的只读快照"))
	var panel := _panel(); var box := _content(panel)
	if bool(vm.get("has_memory", false)):
		box.add_child(_label("%s：%s · %s" % [_loc("ui.label.last_visit", ""), String(vm.get("captured_label", "")), String(vm.get("age_text", ""))], 14, SNSkin.color("ink.primary"))); box.add_child(_label(_loc("ui.label.readonly_memory", ""), 12, SNSkin.color("paper.ink_muted"))); box.add_child(_market_grid(vm.get("market", [])))
	else:
		box.add_child(_label("没有该港口的到港市场记录。", 14, SNSkin.color("paper.ink_muted")))
	if bool(vm.get("facilities_known", false)):
		var facilities: Array = vm.get("facility_labels", []); box.add_child(_label("设施：" + (", ".join(facilities) if not facilities.is_empty() else "—"), 13, SNSkin.color("paper.ink_muted")))
	box.add_child(_back_button()); add_child(panel)


func _market_grid(rows: Array) -> GridContainer:
	var grid := GridContainer.new(); grid.columns = 4; grid.custom_minimum_size.x = 760.0; grid.add_theme_constant_override("h_separation", 16); grid.add_theme_constant_override("v_separation", 8)
	var widths := [240.0, 140.0, 140.0, 160.0]
	var headings := ["商品", "上次单价", "上次储备", "买卖"]
	for index in headings.size(): grid.add_child(_grid_label(headings[index], 12, SNSkin.color("paper.ink_muted"), widths[index]))
	for row in rows:
		var buyable := bool(row.get("buyable", true)); var supply := bool(row.get("is_supply", false)); grid.add_child(_grid_label(_loc(String(row.get("name_key", "")), String(row.get("item_id", ""))), 13, SNSkin.color("ink.primary"), widths[0])); grid.add_child(_grid_label(str(int(row.get("price", 0))), 13, SNSkin.color("brass.shadow"), widths[1])); grid.add_child(_grid_label(str(int(row.get("stock", 0))), 13, SNSkin.color("ink.primary"), widths[2])); grid.add_child(_grid_label(_loc("ui.label.supply", "Supply") if supply else ("可买" if buyable else _loc("ui.label.sell_only", "")), 13, SNSkin.color("brass.shadow") if supply else (SNSkin.color("ink.primary") if buyable else SNSkin.color("paper.ink_muted")), widths[3]))
	return grid
func _back_button() -> Button:
	var button := Button.new(); button.text = _loc("ui.button.back_overview", ""); button.theme_type_variation = &"SNGhostButton"; button.pressed.connect(func(): navigation_requested.emit(&"overview", {})); return button
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.theme_type_variation = &"SNParchmentPanel"; panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _grid_label(text: String, size: int, color: Color, minimum_width: float) -> Label:
	var label := _label(text, size, color); label.custom_minimum_size.x = minimum_width; return label
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_OFF; return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
