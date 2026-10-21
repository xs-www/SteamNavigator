class_name ContractsScreen
extends VBoxContainer
## Contract board presentation screen.
##
## Reachability and definition names are composed by the shell. This scene only
## renders the board and emits command/navigation intent.

signal command_requested(command: StringName, params: Dictionary)
signal navigation_requested(screen_id: StringName, params: Dictionary)

const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_TEAL := Color("76aaa7")
const COLOR_RED := Color("c36b53")

var _tr: Callable


func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	add_child(_heading("海事局委托处", "委托与航线", "主线只能同时进行一个；普通委托持有上限随声誉提高。"))
	var contracts: Dictionary = view_model.get("contracts", {})
	add_child(_holding_panel(contracts))
	var main_contract: Variant = contracts.get("main", null)
	var main_offer: Variant = contracts.get("main_offer", null)
	var offers: Array = contracts.get("offers", [])
	var active: Array = contracts.get("active", [])
	var available_count := offers.size() + (1 if main_offer is Dictionary else 0)
	if available_count > 0:
		add_child(_section_header("可接委托", available_count, SNBadge.Tone.NEUTRAL))
		var available_grid := _contract_grid()
		add_child(available_grid)
		if main_offer is Dictionary:
			available_grid.add_child(_contract_card(main_offer, true, true, false))
		for offer in offers:
			if offer is Dictionary:
				available_grid.add_child(_contract_card(offer, false, true, false))
	var active_count := active.size() + (1 if main_contract is Dictionary else 0)
	if active_count > 0:
		add_child(_section_header("进行中", active_count, SNBadge.Tone.SUCCESS))
		var active_grid := _contract_grid()
		add_child(active_grid)
		if main_contract is Dictionary:
			active_grid.add_child(_contract_card(main_contract, true, false, true))
		for contract in active:
			if contract is Dictionary:
				active_grid.add_child(_contract_card(contract, false, false, true))
	if available_count == 0 and active_count == 0:
		var empty := _panel(&"SNPanel")
		_panel_content(empty).add_child(_label(_loc("ui.label.no_contracts", "暂无委托"), 14, COLOR_MUTED))
		add_child(empty)
	var completed_names: Array = view_model.get("completed_names", [])
	if not completed_names.is_empty():
		add_child(_completed_panel(completed_names))


func _holding_panel(contracts: Dictionary) -> Control:
	var panel := _panel(&"SNInsetPanel")
	var content := _panel_content(panel)
	var active: Array = contracts.get("active", [])
	var holds := int(contracts.get("active_count", contracts.get("normal_holds", active.size())))
	var limit := int(contracts.get("active_limit", 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := "%s %d" % [_loc("ui.label.contract_limit", "普通委托持有"), holds]
	if limit > 0:
		text = "%s %d / %d" % [_loc("ui.label.contract_limit", "普通委托持有"), holds, limit]
	row.add_child(_badge(text, SNBadge.Tone.WARNING if limit > 0 and holds >= limit else SNBadge.Tone.SUCCESS))
	if bool(contracts.get("main_chain_complete", false)):
		row.add_child(_badge(_loc("ui.label.main_chain_complete", "主线已完成"), SNBadge.Tone.SUCCESS))
	content.add_child(row)
	content.add_child(_label(_loc("ui.hint.contract_refresh", "每次抵达目的港后，普通委托池会自动刷新。"), 12, COLOR_MUTED))
	return panel


func _section_header(title_text: String, count: int, tone: int) -> Control:
	var row := HBoxContainer.new()
	var title := _label(title_text, 18, COLOR_BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_badge("%d 个" % count, tone))
	return row


func _contract_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	return grid


func _contract_card(contract: Dictionary, is_main: bool, can_accept: bool, can_plan: bool) -> Control:
	var panel := _panel(&"SNElevatedPanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := _panel_content(panel)
	var title_row := HBoxContainer.new()
	var title := _label(_loc(String(contract.get("name_key", "")), String(contract.get("template_id", ""))), 18, COLOR_BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.max_lines_visible = 2
	title_row.add_child(title)
	title_row.add_child(_badge("主线" if is_main else "普通", SNBadge.Tone.WARNING if is_main else SNBadge.Tone.NEUTRAL))
	var risk := String(contract.get("risk", "low"))
	title_row.add_child(_badge(_risk_label(risk), _risk_tone(risk)))
	content.add_child(title_row)
	content.add_child(_contract_data(contract))
	var description_key := String(contract.get("description_key", ""))
	if not description_key.is_empty():
		var description := _label(_loc(description_key, ""), 13, COLOR_MUTED)
		description.max_lines_visible = 2
		content.add_child(description)
	var deadline := _label("截止 %s" % String(contract.get("deadline_label", "")), 11, COLOR_MUTED)
	deadline.tooltip_text = _loc("ui.label.deadline_hint", "绝对时间仅作参考，优先看剩余期限")
	content.add_child(deadline)
	var reward_row := HBoxContainer.new()
	var reward := _label(_reward_text(contract), 14, COLOR_TEXT)
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_row.add_child(reward)
	reward_row.add_child(_badge("声望 +%d" % int(contract.get("reputation", 0)), SNBadge.Tone.SUCCESS))
	content.add_child(reward_row)
	var unlock_names: Array = contract.get("unlock_names", [])
	if not unlock_names.is_empty():
		content.add_child(_label("解锁：%s" % ", ".join(PackedStringArray(unlock_names)), 12, COLOR_TEAL))
	var buttons := HBoxContainer.new()
	if can_accept:
		var accept := _button(_loc("ui.button.accept", "接受"))
		accept.theme_type_variation = &"SNPrimaryButton"
		accept.pressed.connect(func() -> void:
			command_requested.emit(&"contract.accept", {"instance_id": String(contract.get("instance_id", ""))})
		)
		buttons.add_child(accept)
	if can_plan:
		var destination := String(contract.get("destination", ""))
		var plan := _button(_loc("ui.button.plan", "规划出航"))
		plan.theme_type_variation = &"SNPrimaryButton"
		plan.disabled = not bool(contract.get("destination_reachable", false))
		plan.pressed.connect(func() -> void:
			# 4.3.4 / U7：出航准备页已删除，规划出航改为打开海图并预选目的港，
			# 真正的出航在确认弹窗里完成。
			navigation_requested.emit(&"sea_chart", {"destination": destination})
		)
		buttons.add_child(plan)
	if buttons.get_child_count() > 0:
		content.add_child(buttons)
	if can_plan and not bool(contract.get("destination_reachable", false)):
		content.add_child(_label("目的港不直达，需要先到中转港。", 11, COLOR_RED))
	return panel


func _contract_data(contract: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var remaining := float(contract.get("remaining_hours", 0.0))
	row.add_child(_contract_stat("目的地", _loc(String(contract.get("destination_name_key", "")), String(contract.get("destination", ""))), COLOR_TEXT))
	row.add_child(VSeparator.new())
	row.add_child(_contract_stat("剩余期限", String(contract.get("remaining_label", "—")), COLOR_RED if remaining < 24.0 else COLOR_TEXT))
	row.add_child(VSeparator.new())
	row.add_child(_contract_stat("载重", _payload_text(contract).trim_prefix("载荷："), COLOR_TEXT))
	row.add_child(VSeparator.new())
	row.add_child(_contract_stat("预计航程", String(contract.get("estimated_label", "—")), COLOR_MUTED))
	return row


func _contract_stat(label_text: String, value_text: String, value_color: Color) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	column.add_child(_label(label_text, 10, COLOR_MUTED))
	column.add_child(_label(value_text, 14, value_color))
	return column


func _completed_panel(names: Array) -> Control:
	var panel := _panel(&"SNPanel")
	var content := _panel_content(panel)
	content.add_child(_label("已完成主线", 15, COLOR_BRASS))
	for name in names:
		content.add_child(_label("· %s" % String(name), 13, COLOR_MUTED))
	return panel


func _payload_text(contract: Dictionary) -> String:
	var parts := PackedStringArray()
	if float(contract.get("cargo_weight", 0.0)) > 0.0:
		parts.append("货物 %.0f 重量" % float(contract.get("cargo_weight", 0.0)))
	if int(contract.get("passengers", 0)) > 0:
		parts.append("旅客 %d 人" % int(contract.get("passengers", 0)))
	return "载荷：—" if parts.is_empty() else "载荷：" + " · ".join(parts)


func _reward_text(contract: Dictionary) -> String:
	return "报酬：基础 %d · 准时 +%d · 声誉 +%d" % [
		int(contract.get("base_money", 0)),
		int(contract.get("on_time_bonus", 0)),
		int(contract.get("reputation", 0)),
	]


func _risk_tone(risk: String) -> int:
	match risk:
		"high": return SNBadge.Tone.DANGER
		"medium": return SNBadge.Tone.WARNING
		_: return SNBadge.Tone.SUCCESS


func _risk_label(risk: String) -> String:
	match risk:
		"high": return "高风险"
		"medium": return "中等风险"
		_: return "低风险"


func _panel(variation: StringName) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _panel_content(panel: PanelContainer) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	return content


func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new()
	header.eyebrow = eyebrow
	header.title = title
	header.detail = detail
	return header


func _badge(text: String, tone: int) -> SNBadge:
	var badge := SNBadge.new()
	badge.text = text
	badge.tone = tone
	return badge


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _loc(key: String, fallback: String) -> String:
	if not _tr.is_valid():
		return fallback
	var text := String(_tr.call(key))
	return fallback if text.is_empty() or text == key else text


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
