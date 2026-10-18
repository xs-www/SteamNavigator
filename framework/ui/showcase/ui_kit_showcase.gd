extends Control
## Standalone visual QA scene for the reusable Godot UI kit.

const SNButtonScene := preload("res://framework/ui/components/sn_button.tscn")
const SNPanelScene := preload("res://framework/ui/components/sn_panel.tscn")
const SNBadgeScene := preload("res://framework/ui/components/sn_badge.tscn")
const SNSectionHeaderScene := preload("res://framework/ui/components/sn_section_header.tscn")
const SNResourceMeterScene := preload("res://framework/ui/components/sn_resource_meter.tscn")
const SNSupplyCardScene := preload("res://framework/ui/components/sn_supply_card.tscn")
const SNSparklineScene := preload("res://framework/ui/components/sn_sparkline.tscn")


func _ready() -> void:
	_build_showcase()


func _build_showcase() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	$Margin/Scroll.add_child(root)

	var page_header := SNSectionHeaderScene.instantiate() as SNSectionHeader
	page_header.eyebrow = "STEAM NAVIGATOR · DESIGN SYSTEM 0.1"
	page_header.title = "Godot UI 控件库"
	page_header.detail = "可直接拖入场景 · 1440 × 900 基准"
	root.add_child(page_header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(grid)
	grid.add_child(_button_panel())
	grid.add_child(_badge_panel())
	grid.add_child(_meter_panel())
	grid.add_child(_form_panel())
	grid.add_child(_supply_panel())
	grid.add_child(_sparkline_panel())


func _button_panel() -> Control:
	var panel := _panel_with_content("按钮", "语义决定样式，不由页面临时覆写")
	var content := panel.get_meta("content") as VBoxContainer
	for index in range(4):
		var button := SNButtonScene.instantiate() as SNButton
		button.variant = index
		button.text = ["确认出航", "查看详情", "放弃委托", "返回港口"][index]
		content.add_child(button)
	var disabled := SNButtonScene.instantiate() as SNButton
	disabled.text = "载重不足"
	disabled.disabled = true
	content.add_child(disabled)
	return panel


func _badge_panel() -> Control:
	var panel := _panel_with_content("状态徽标", "用于风险、开放状态与价格趋势")
	var content := panel.get_meta("content") as VBoxContainer
	var row := HBoxContainer.new()
	content.add_child(row)
	for index in range(4):
		var badge := SNBadgeScene.instantiate() as SNBadge
		badge.tone = index
		badge.text = ["当前港", "已完成", "中等风险", "严重损坏"][index]
		row.add_child(badge)
	var inset := SNPanelScene.instantiate() as SNPanel
	inset.variant = SNPanel.Variant.INSET
	inset.custom_minimum_size.y = 118
	content.add_child(inset)
	var copy := Label.new()
	copy.text = "状态颜色必须同时配合文字或图标，\n不能只依赖色相传达信息。"
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inset.add_child(copy)
	return panel


func _meter_panel() -> Control:
	var panel := _panel_with_content("资源存量", "煤水、耐久和载重采用同一信息结构")
	var content := panel.get_meta("content") as VBoxContainer
	var data := [
		["煤炭", 31.0, 50.0, "预计续航 6.2 天", SNResourceMeter.Tone.BRASS],
		["淡水", 39.0, 50.0, "预计续航 9.8 天", SNResourceMeter.Tone.WATER],
		["船体耐久", 22.0, 100.0, "低于安全线，建议维修", SNResourceMeter.Tone.DANGER],
	]
	for item in data:
		var meter := SNResourceMeterScene.instantiate() as SNResourceMeter
		meter.label_text = item[0]
		meter.current_value = item[1]
		meter.maximum_value = item[2]
		meter.suffix = "%" if item[0] == "船体耐久" else "单位"
		meter.hint = item[3]
		meter.tone = item[4]
		content.add_child(meter)
	return panel


func _form_panel() -> Control:
	var panel := _panel_with_content("表单与选择", "键盘焦点与禁用状态由 Theme 统一")
	var content := panel.get_meta("content") as VBoxContainer
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "输入航次名称"
	content.add_child(line_edit)
	var option := OptionButton.new()
	option.add_item("经济航速 · 低消耗")
	option.add_item("标准航速 · 平衡")
	option.add_item("极速航行 · 高风险")
	content.add_child(option)
	var check := CheckBox.new()
	check.text = "抵达时自动保存"
	check.button_pressed = true
	content.add_child(check)
	return panel


func _supply_panel() -> Control:
	var panel := _panel_with_content("补给卡", "正常 / 禁用原因 / 最大购买")
	var content := panel.get_meta("content") as VBoxContainer
	var card := SNSupplyCardScene.instantiate() as SNSupplyCard
	card.bind({
		"kind": "coal",
		"current": 31.0,
		"fill_to": 40.0,
		"maximum": 50.0,
		"safe_level": 24.0,
		"estimated_days": 6.2,
		"price": 3.9,
		"port_stock": 170,
		"max_buy": 9,
		"fill_cost": 35,
	}, "煤炭", [])
	content.add_child(card)
	return panel


func _sparkline_panel() -> Control:
	var panel := _panel_with_content("价格趋势", "历史不足显示样本不足；有样本后绘制折线")
	var content := panel.get_meta("content") as VBoxContainer
	for prices in [[72, 75, 73, 79, 78, 84], [84, 82, 80, 77, 74, 71], [63]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var spark := SNSparklineScene.instantiate() as SNSparkline
		spark.set_values(prices, Color("e1c487") if prices.size() > 1 and float(prices[prices.size() - 1]) >= float(prices[0]) else Color("c36b53"))
		row.add_child(spark)
		var note := Label.new()
		note.text = "样本不足" if prices.size() < 2 else "%d 个样本" % prices.size()
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color("9fafa7"))
		row.add_child(note)
		content.add_child(row)
	return panel


func _panel_with_content(title: String, subtitle: String) -> SNPanel:
	var panel := SNPanelScene.instantiate() as SNPanel
	panel.custom_minimum_size = Vector2(480, 330)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := SNSectionHeaderScene.instantiate() as SNSectionHeader
	header.eyebrow = "UI KIT"
	header.title = title
	header.detail = ""
	content.add_child(header)
	var note := Label.new()
	note.text = subtitle
	note.add_theme_color_override("font_color", Color("9fafa7"))
	note.add_theme_font_size_override("font_size", 11)
	content.add_child(note)
	panel.set_meta("content", content)
	return panel
