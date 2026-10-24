class_name ContractsScreen
extends VBoxContainer
## @static-doc
## 作用：委托页面场景：按可接/进行中分组渲染主线与普通委托卡，并发出接取或规划出航意图。
##
## Contract board presentation screen.
##
## Reachability and definition names are composed by the shell. This scene only
## renders the board and emits command/navigation intent.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 委托卡是公告板上的纸面：Theme 变体 `SNParchmentPanel`；卡内正文一律改用 ink
##   token（`ink.primary` / `paper.ink_muted` / `brass.shadow`），危险期限仍用
##   `state.danger`，保证纸面可读性。任务追踪 / 持有上限 / 已完成面板保持钢制面板。
## - 「接受」按钮用 `SNPrimaryButton` + `Button.icon = SNSkin.icon("action_confirm")`
##   （`icon_max_width` 16）；按钮 `text` 不变，测试仍按文字查找。
## - 其余文字颜色取 `SNSkin.color(token)`；无内联十六进制色与 StyleBoxFlat。
## - 尺寸约束：卡片两列网格 16 px 间距、标题最多 2 行、`_button` 高度 38、
##   所有节点结构与信号（contract.accept / sea_chart 导航）不变。
## @end-static-doc

signal command_requested(command: StringName, params: Dictionary)
signal navigation_requested(screen_id: StringName, params: Dictionary)


var _tr: Callable


func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	add_child(_heading("海事局委托处", "委托与航线", "主线只能同时进行一个；普通委托持有上限随声誉提高。"))
	var tasks: Array = view_model.get("tasks", [])
	if not tasks.is_empty():
		add_child(_task_panel(tasks, String(view_model.get("active_task_id", ""))))
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
		_panel_content(empty).add_child(_label(_loc("ui.label.no_contracts", "暂无委托"), 14, SNSkin.color("text.muted")))
		add_child(empty)
	var completed_names: Array = view_model.get("completed_names", [])
	if not completed_names.is_empty():
		add_child(_completed_panel(completed_names))


## 4.6 Phase A：任务追踪聚合面板——列出剧情 / 主线 / 已接委托与各自步骤，
## 完成步骤打勾、当前步骤高亮。完整列表留在本页，HUD 只显示最高优先级任务。
func _task_panel(tasks: Array, active_task_id: String) -> Control:
	var panel := _panel(&"SNPanel")
	var content := _panel_content(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.add_child(_task_label(_loc("ui.task.title", "任务追踪"), 17, SNSkin.color("brass.highlight")))
	header.add_child(_badge("%d" % tasks.size(), SNBadge.Tone.NEUTRAL))
	content.add_child(header)
	for raw_task in tasks:
		if not (raw_task is Dictionary):
			continue
		var task: Dictionary = raw_task
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		var category := _loc(String(task.get("category_key", "")), "")
		if not category.is_empty():
			title_row.add_child(_badge(category, SNBadge.Tone.WARNING))
		var title_key := String(task.get("title_key", ""))
		var title := _loc(title_key, title_key)
		title_row.add_child(_task_label(title, 15, SNSkin.color("text.light") if String(task.get("id", "")) == active_task_id else SNSkin.color("text.muted")))
		var remaining := float(task.get("remaining_hours", -1.0))
		if remaining >= 0.0:
			title_row.add_child(_task_label(_loc("ui.task.remaining", "剩余 %d 小时") % int(ceil(remaining)), 12, SNSkin.color("text.muted")))
		row.add_child(title_row)
		for raw_step in Array(task.get("steps", [])):
			if not (raw_step is Dictionary):
				continue
			var step: Dictionary = raw_step
			var prefix := "✓  " if bool(step.get("done", false)) else "·  "
			var color := SNSkin.color("state.water") if bool(step.get("done", false)) else SNSkin.color("text.light")
			row.add_child(_task_label(prefix + _task_step_text(step), 13, color))
		content.add_child(row)
	return panel


func _task_label(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _task_step_text(step: Dictionary) -> String:
	var kind := String(step.get("kind", ""))
	var progress := int(step.get("progress", 0))
	var target := int(step.get("target", 0))
	match kind:
		"objective":
			var objective := _loc(String(step.get("text_key", "")), "")
			if target <= 1:
				return objective
			var remaining := maxi(0, target - progress)
			if remaining > 0:
				return (_loc("ui.task.step_progress_remaining", "%s（%d/%d，还差 %d）") % [
					objective, progress, target, remaining,
				])
			return _loc("ui.task.step_progress", "%s（%d/%d）") % [objective, progress, target]
		"accept":
			return _loc("ui.task.step.accept", "接取主线委托")
		"load":
			var item := _loc(String(step.get("item_name_key", "")), "")
			var template := _loc(
				"ui.task.step.load_fuel" if bool(step.get("fuel_sourced", false)) else "ui.task.step.load",
				"备货：%s（%d/%d）"
			)
			return template % [item, progress, target]
		"passenger":
			return _loc("ui.task.step.passenger", "接旅客（%d/%d）") % [progress, target]
		"sail":
			return _loc("ui.task.step.sail", "前往：%s") % _loc(String(step.get("destination_name_key", "")), "")
		"deliver":
			return _loc("ui.task.step.deliver", "抵达 %s 后自动交付") % _loc(String(step.get("destination_name_key", "")), "")
	return ""


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
	content.add_child(_label(_loc("ui.hint.contract_refresh", "每次抵达目的港后，普通委托池会自动刷新。"), 12, SNSkin.color("text.muted")))
	return panel


func _section_header(title_text: String, count: int, tone: int) -> Control:
	var row := HBoxContainer.new()
	var title := _label(title_text, 18, SNSkin.color("brass.highlight"))
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
	var panel := _panel(&"SNParchmentPanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := _panel_content(panel)
	var title_row := HBoxContainer.new()
	var title := _label(_loc(String(contract.get("name_key", "")), String(contract.get("template_id", ""))), 18, SNSkin.color("ink.primary"))
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
		var description := _label(_loc(description_key, ""), 13, SNSkin.color("paper.ink_muted"))
		description.max_lines_visible = 2
		content.add_child(description)
	var deadline := _label("截止 %s" % String(contract.get("deadline_label", "")), 11, SNSkin.color("paper.ink_muted"))
	deadline.tooltip_text = _loc("ui.label.deadline_hint", "绝对时间仅作参考，优先看剩余期限")
	content.add_child(deadline)
	var reward_row := HBoxContainer.new()
	var reward := _label(_reward_text(contract), 14, SNSkin.color("ink.primary"))
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_row.add_child(reward)
	reward_row.add_child(_badge("声望 +%d" % int(contract.get("reputation", 0)), SNBadge.Tone.SUCCESS))
	content.add_child(reward_row)
	var unlock_names: Array = contract.get("unlock_names", [])
	if not unlock_names.is_empty():
		content.add_child(_label("解锁：%s" % ", ".join(PackedStringArray(unlock_names)), 12, SNSkin.color("brass.shadow")))
	var buttons := HBoxContainer.new()
	if can_accept:
		var accept := _button(_loc("ui.button.accept", "接受"))
		accept.theme_type_variation = &"SNPrimaryButton"
		_apply_button_icon(accept, "action_confirm", 16)
		accept.pressed.connect(func() -> void:
			command_requested.emit(&"contract.accept", {"instance_id": String(contract.get("instance_id", ""))})
		)
		buttons.add_child(accept)
	if can_plan:
		var destination := String(contract.get("destination", ""))
		var plan := _button(_loc("ui.button.plan", "规划出航"))
		plan.theme_type_variation = &"SNPrimaryButton"
		plan.disabled = not bool(contract.get("destination_reachable", false))
		if plan.disabled:
			_apply_button_icon(plan, "status_locked", 16)
		plan.pressed.connect(func() -> void:
			# 4.3.4 / U7：出航准备页已删除，规划出航改为打开海图并预选目的港，
			# 真正的出航在确认弹窗里完成。
			navigation_requested.emit(&"sea_chart", {"destination": destination})
		)
		buttons.add_child(plan)
	if buttons.get_child_count() > 0:
		content.add_child(buttons)
	if can_plan and not bool(contract.get("destination_reachable", false)):
		content.add_child(_label("目的港不直达，需要先到中转港。", 11, SNSkin.color("state.danger")))
	return panel


func _contract_data(contract: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var remaining := float(contract.get("remaining_hours", 0.0))
	row.add_child(_contract_stat("目的地", _loc(String(contract.get("destination_name_key", "")), String(contract.get("destination", ""))), SNSkin.color("ink.primary")))
	row.add_child(VSeparator.new())
	row.add_child(_contract_stat("剩余期限", String(contract.get("remaining_label", "—")), SNSkin.color("state.danger") if remaining < 24.0 else SNSkin.color("ink.primary")))
	row.add_child(VSeparator.new())
	row.add_child(_contract_stat("载重", _payload_text(contract).trim_prefix("载荷："), SNSkin.color("ink.primary")))
	row.add_child(VSeparator.new())
	row.add_child(_contract_stat("预计航程", String(contract.get("estimated_label", "—")), SNSkin.color("paper.ink_muted")))
	return row


func _contract_stat(label_text: String, value_text: String, value_color: Color) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	column.add_child(_label(label_text, 10, SNSkin.color("paper.ink_muted")))
	column.add_child(_label(value_text, 14, value_color))
	return column


func _completed_panel(names: Array) -> Control:
	var panel := _panel(&"SNPanel")
	var content := _panel_content(panel)
	content.add_child(_label("已完成主线", 15, SNSkin.color("brass.highlight")))
	for name in names:
		content.add_child(_label("· %s" % String(name), 13, SNSkin.color("text.muted")))
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


## Skin icon without a wrapper node; the button text / node structure stay intact.
func _apply_button_icon(button: Button, icon_id: String, max_width: int) -> void:
	var texture := SNSkin.icon(icon_id)
	if texture == null:
		return
	button.icon = texture
	button.add_theme_constant_override("icon_max_width", max_width)


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
