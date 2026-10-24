class_name AutoTradeScreen
extends VBoxContainer
## @static-doc
## 作用：Phase D4 自动贸易页：渲染 `auto_trade.view` 与可用策略，展示阶段、航程、
## 自动货舱、累计利润与最近日志，并把启动/停止/暂停/恢复/等待转成
## `command_requested` 意图；页面本身不查询、不写状态。
##
## ## 契约与约束
## - `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在
##   `auto_trade.view` 基础上补 `available_policies`。
## - 未启动：列出策略与启动按钮；运行中：状态徽章、货舱、日志、暂停/恢复/停止。
## - 所有按钮只 emit `command_requested(command, params)`。
##
## ## 外观来源（外部贴图 + SNSkin）
## - 面板用 Theme 变体 `SNInsetPanel`（钢制凹槽）；摘要徽标改用 `SNBadge`
##   （13 px 中性纹理铭牌），不再返回 PanelContainer + Label 的临时徽标。
## - 启停按钮挂 `Button.icon = SNSkin.icon("status_route")` + `icon_max_width` 16
##   （航线语义），其余操作仍是 `SNGhostButton`（30 px 高）；按钮 `text` 不变。
## - 文字色取 `SNSkin.color(token)`（text.light / text.muted / brass.highlight）；
##   本文件无内联十六进制色与 StyleBoxFlat。
## @end-static-doc

signal command_requested(command: StringName, params: Dictionary)


var _tr: Callable
var _model: Dictionary = {}


func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	_model = view_model
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	add_child(_heading())
	if not bool(_model.get("active", false)):
		var panel := _panel()
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.add_child(_label(_t("ui.trade.select_policy", "选择贸易策略"), 16, SNSkin.color("brass.highlight")))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		for policy in _model.get("available_policies", []):
			if policy is Dictionary:
				row.add_child(_action(_name((policy as Dictionary).get("name_key", "")),
					&"auto_trade.start", {"policy_id": String((policy as Dictionary).get("id", ""))}, "status_route"))
		box.add_child(row)
		panel.add_child(box)
		add_child(panel)
		add_child(_wait_row())
		return
	add_child(_summary())
	add_child(_cargo())
	add_child(_log())
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	if bool(_model.get("paused", false)):
		buttons.add_child(_action(_t("ui.trade.resume", "恢复"), &"auto_trade.resume", {}))
	else:
		buttons.add_child(_action(_t("ui.trade.pause", "暂停"), &"auto_trade.pause", {}))
	buttons.add_child(_action(_t("ui.trade.stop", "停止"), &"auto_trade.stop", {}, "status_route"))
	add_child(buttons)
	add_child(_wait_row())


func _heading() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label(_t("ui.trade.title", "自动贸易"), 24, SNSkin.color("brass.highlight")))
	var policy: Dictionary = _model.get("policy", {})
	var subtitle := _t("ui.trade.subtitle", "策略、航线与规则")
	if not policy.is_empty():
		subtitle = _name(policy.get("name_key", ""))
	box.add_child(_label(subtitle, 14, SNSkin.color("text.muted")))
	return box


func _summary() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var badges := HFlowContainer.new()
	badges.add_theme_constant_override("h_separation", 10)
	badges.add_child(_badge(_phase_text()))
	badges.add_child(_badge("%s %d" % [_t("ui.trade.profit", "利润"), int(_model.get("profit", 0))]))
	badges.add_child(_badge("%s %d" % [_t("ui.trade.legs", "航次"), int(_model.get("legs", 0))]))
	badges.add_child(_badge("%s → %s" % [
		String(_model.get("at_port_name", "")), String(_model.get("target_port_name", "")),
	]))
	if float(_model.get("travel_remaining", 0.0)) > 0.0:
		badges.add_child(_badge(_t("ui.trade.remaining", "剩余 %s 小时") % _fmt(float(_model.get("travel_remaining", 0.0)))))
	box.add_child(badges)
	panel.add_child(box)
	return panel


func _cargo() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_label("%s %d/%d" % [
		_t("ui.trade.cargo", "自动货舱"), int(_model.get("cargo_units", 0)), int(_model.get("max_cargo", 0)),
	], 18, SNSkin.color("brass.highlight")))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	for item in _model.get("cargo", []):
		if item is Dictionary:
			row.add_child(_badge("%s × %d" % [_name((item as Dictionary).get("name_key", "")), int((item as Dictionary).get("amount", 0))]))
	box.add_child(row)
	return box


func _log() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label(_t("ui.trade.log", "最近日志"), 16, SNSkin.color("brass.highlight")))
	var log: Array = _model.get("log", [])
	if log.is_empty():
		box.add_child(_label("—", 13, SNSkin.color("text.muted")))
	for entry in log:
		if entry is Dictionary:
			box.add_child(_label(_log_line(entry), 13, SNSkin.color("text.muted")))
	return box


func _log_line(entry: Dictionary) -> String:
	var event := String(entry.get("event", ""))
	var amount := int(entry.get("amount", 0))
	var money := int(entry.get("money", 0))
	var item := _name(entry.get("item_id", ""))
	match event:
		"bought":
			return _t("ui.trade.log.bought", "买入 %s ×%d（%d 金）") % [item, amount, money]
		"sold":
			return _t("ui.trade.log.sold", "卖出 %d 件（%d 金）") % [amount, money]
		"risk":
			return _t("ui.trade.log.risk", "遭遇风险，损失 %d 件货物") % amount
		"paused":
			return _t("ui.trade.log.paused", "规则暂停自动贸易")
		"resumed":
			return _t("ui.trade.log.resumed", "规则恢复自动贸易")
		_:
			return _t("ui.trade.log.%s" % event, event)


func _phase_text() -> String:
	if bool(_model.get("paused", false)):
		return _t("ui.trade.phase.paused", "已暂停")
	return _t("ui.trade.phase.%s" % String(_model.get("phase", "idle")), String(_model.get("phase", "idle")))


func _wait_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_child(_action(_t("ui.trade.wait_1", "等待 1 小时"), &"sim.advance", {"hours": 1}))
	row.add_child(_action(_t("ui.trade.wait_12", "等待 12 小时"), &"sim.advance", {"hours": 12}))
	return row


func _action(text: String, command: StringName, params: Dictionary, icon_id: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SNGhostButton"
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 13)
	if not icon_id.is_empty():
		var texture := SNSkin.icon(icon_id)
		if texture != null:
			button.icon = texture
			button.add_theme_constant_override("icon_max_width", 16)
	button.pressed.connect(func() -> void: command_requested.emit(command, params))
	return button


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	return panel


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Skin-badge, not a hand-rolled PanelContainer + Label; text stays a Label.
func _badge(text: String) -> Control:
	var badge := SNBadge.new()
	badge.text = text
	badge.tone = SNBadge.Tone.NEUTRAL
	badge.add_theme_font_size_override("font_size", 13)
	return badge


func _name(key: Variant) -> String:
	return _t(String(key), String(key))


func _t(key: String, fallback: String) -> String:
	if _tr.is_valid():
		return String(_tr.call(key, fallback))
	return fallback


func _fmt(value: float) -> String:
	return "%.1f" % value if absf(value - roundf(value)) > 0.01 else "%d" % int(roundf(value))
