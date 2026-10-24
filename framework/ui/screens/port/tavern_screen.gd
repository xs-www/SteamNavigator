class_name TavernScreen
extends VBoxContainer
## @static-doc
## 作用：酒馆页（阶段 4.5.4，替换原情报站页面）——上半部分保留物价情报矩阵与
## NPC 动向，下半部分列出港口线索（购买线索、调查线索），把「物价情报 + 港口线索」
## 合并到同一个设施入口。
##
## - 关键依赖：`tavern.view` 查询（Shell 传入 ViewModel）、`sn_intel_table`
## - 信号：`command_requested(command, params)` → Shell 执行 `intel.refresh` /
##   `clue.buy` / `clue.investigate`
##
## ## 契约与约束
## - 纯展示：不查状态、不发命令；线索不输出目标港 / credibility / 搜索区。
## - 线索行由 `tavern.view.clues` 的等级裁剪字段渲染，购买与调查可用性完全由
##   `can_buy_clue` / `clue.can_investigate` 决定，按钮不自行猜规则。
##
## ## 外观来源（外部贴图 + SNSkin）
## - 面板用 Theme 默认钢制 `Panel`（纹理化）；物价情报矩阵由 `SNIntelTable`
##   自己换皮（钢制抬高面 + 凹槽格）。文字 / 状态色取 `SNSkin.color(token)`
##   （text.light / text.muted / brass.highlight / state.water / state.danger）。
## - 按钮保持默认纹理化 `Button`（刷新物价 / 购买线索 / 调查线索），按钮文字与
##   节点名 `RefreshIntelButton` / `BuyClueButton` / `InvestigateButton` 不变。
## - 尺寸约束：面板间距 8、线索行间距 12、字号 16/14/13/12 不变；不新增布局。
## @end-static-doc

signal command_requested(command: StringName, params: Dictionary)

const INTEL_TABLE_SCRIPT := preload("res://framework/ui/components/sn_intel_table.gd")
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	var intel: Dictionary = vm.get("intel", {}) if vm.get("intel", {}) is Dictionary else {}
	add_child(_heading(
		_loc("ui.tavern.eyebrow", "酒馆"),
		_loc("ui.tavern.title", "物价情报与港口线索"),
		_loc("ui.hint.tavern", "在酒馆可以刷新物价情报，也可以购买 / 调查港口线索。")
	))
	add_child(_intel_panel(intel))
	add_child(_clue_panel(vm))


func _intel_panel(vm: Dictionary) -> Control:
	var panel := _panel()
	var content := _content(panel)
	content.add_child(_label(_loc("ui.tavern.intel_title", "物价情报"), 16, SNSkin.color("brass.highlight")))
	if bool(vm.get("has_report", false)):
		content.add_child(_label("%s：%s · %s" % [_loc("ui.label.generated", ""), vm.get("generated_label", ""), _age(float(vm.get("age_hours", 0.0)))], 14, SNSkin.color("text.light")))
		content.add_child(_label(_loc("ui.intel.summary", "") % [int(vm.get("port_count", 0)), int(vm.get("column_count", 0)), int(vm.get("npc_count", 0))], 12, SNSkin.color("text.muted")))
		content.add_child(_label(_loc("ui.label.snapshot_tip", ""), 12, SNSkin.color("text.muted")))
	else:
		content.add_child(_label(_loc("ui.label.no_intel", ""), 14, SNSkin.color("text.muted")))
	var rows: Array = vm.get("rows", [])
	if rows.is_empty():
		content.add_child(_message(_loc("ui.intel.empty", "")))
	else:
		var table: Variant = INTEL_TABLE_SCRIPT.new()
		table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.bind(vm.get("columns", []), rows, String(vm.get("current_port_id", "")), _tr)
		content.add_child(table)
	if bool(vm.get("has_tavern_facility", vm.get("has_intel_facility", false))):
		var button := Button.new()
		button.name = "RefreshIntelButton"
		button.text = "%s（%d 金币）" % [_loc("ui.button.refresh_intel", ""), int(vm.get("cost", 25))]
		button.disabled = not bool(vm.get("can_refresh", false))
		button.pressed.connect(func(): command_requested.emit(&"intel.refresh", {}))
		content.add_child(button)
	else:
		content.add_child(_label(_loc("ui.tavern.no_tavern", "当前港口没有酒馆。"), 12, SNSkin.color("text.muted")))
	content.add_child(_npc_panel(vm.get("npcs", [])))
	return panel


func _clue_panel(vm: Dictionary) -> Control:
	var panel := _panel()
	var content := _content(panel)
	content.add_child(_label(_loc("ui.tavern.clues_title", "港口线索"), 16, SNSkin.color("brass.highlight")))
	content.add_child(_label(
		_loc("ui.tavern.clues_count", "持有 %d / %d 条线索") % [
			int(vm.get("active_clue_count", 0)), int(vm.get("max_active_clues", 4)),
		],
		12,
		SNSkin.color("text.muted")
	))
	var buy: Dictionary = vm.get("can_buy_clue", {}) if vm.get("can_buy_clue", {}) is Dictionary else {}
	var buy_button := Button.new()
	buy_button.name = "BuyClueButton"
	buy_button.text = "%s（%d 金币）" % [
		_loc("ui.tavern.buy_clue", "购买线索"), int(buy.get("cost", 0)),
	]
	buy_button.disabled = not bool(buy.get("available", false))
	buy_button.pressed.connect(func(): command_requested.emit(&"clue.buy", {}))
	content.add_child(buy_button)
	if not bool(buy.get("available", true)):
		content.add_child(_label(_loc(String(buy.get("reason_key", "")), ""), 12, SNSkin.color("state.danger")))
	var clues: Array = vm.get("clues", [])
	if clues.is_empty():
		content.add_child(_label(_loc("ui.tavern.clues_empty", "暂时没有线索。在港等待、完成委托或向酒馆购买都可能得到线索。"), 13, SNSkin.color("text.muted")))
		return panel
	for entry in clues:
		if entry is Dictionary:
			content.add_child(_clue_row(entry as Dictionary))
	return panel


func _clue_row(clue: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var level := int(clue.get("level", 1))
	var source_key := String(clue.get("source_display_key", ""))
	var source_text := _loc(source_key, String(clue.get("source_key", "")))
	var title := "%s · Lv.%d · %s" % [
		source_text,
		level,
		_loc("ui.clue.level.%d" % level, ""),
	]
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_label(title, 13, SNSkin.color("text.light")))
	var type := String(clue.get("type", ClueService.TYPE_PORT_LOCATION))
	if type == ClueService.TYPE_PORT_GOODS:
		var goods: Dictionary = clue.get("goods", {}) if clue.get("goods", {}) is Dictionary else {}
		var port_text := _loc(String(goods.get("port_name_key", "")), "")
		var goods_line := _loc("ui.clue.goods.port", "港口：%s") % port_text
		goods_line += " · %s" % _loc("ui.clue.goods.level.%d" % level, "")
		info.add_child(_label(goods_line, 12, SNSkin.color("state.water")))
	else:
		var distance := _loc("ui.clue.distance_range", "") % [
			int(clue.get("distance_min_hours", 0.0)), int(clue.get("distance_max_hours", 0.0)),
		]
		info.add_child(_label(distance, 12, SNSkin.color("state.water")))
	if bool(clue.get("can_investigate", false)):
		var investigate := Button.new()
		investigate.name = "InvestigateButton"
		investigate.text = _loc("ui.tavern.investigate", "调查（%d 金 / %d 时）") % [
			int(clue.get("investigation_cost", 0)), int(clue.get("investigation_hours", 0.0)),
		]
		var clue_id := String(clue.get("id", ""))
		investigate.pressed.connect(
			func(): command_requested.emit(&"clue.investigate", {"clue_id": clue_id})
		)
		row.add_child(investigate)
	row.add_child(info)
	return row


func _npc_panel(npcs: Array) -> Control:
	var panel := _panel()
	var content := _content(panel)
	content.add_child(_label(_loc("ui.tavern.npc_title", "NPC 商船动向"), 16, SNSkin.color("brass.highlight")))
	if npcs.is_empty():
		content.add_child(_label(_loc("ui.tavern.npc_empty", "暂无覆盖到的 NPC 动向（未发现的目的港不会出现）。"), 12, SNSkin.color("text.muted")))
		return panel
	var grid := GridContainer.new()
	grid.columns = 4
	for heading in ["目的港", "货物", _loc("ui.label.action", ""), _loc("ui.label.eta", "")]:
		grid.add_child(_label(heading, 12, SNSkin.color("text.muted")))
	for npc in npcs:
		grid.add_child(_label(_loc(String(npc.get("destination_name_key", "")), String(npc.get("destination", ""))), 13, SNSkin.color("text.light")))
		grid.add_child(_label(_loc(String(npc.get("item_name_key", "")), String(npc.get("item_id", ""))), 13, SNSkin.color("text.light")))
		grid.add_child(_label(_loc(String(npc.get("action_label_key", "")), String(npc.get("action", ""))), 13, SNSkin.color("state.water")))
		grid.add_child(_label("%s – %s" % [ClockService.format_time(float(npc.get("eta_from", 0.0))), ClockService.format_time(float(npc.get("eta_to", 0.0)))], 13, SNSkin.color("text.muted")))
	content.add_child(grid)
	return panel


func _message(text: String) -> Control:
	var panel := _panel(); _content(panel).add_child(_label(text, 13, SNSkin.color("text.muted"))); return panel
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
