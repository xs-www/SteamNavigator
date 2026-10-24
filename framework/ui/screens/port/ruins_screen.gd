class_name RuinsScreen
extends VBoxContainer
## @static-doc
## 作用：Phase D5 遗迹远征页：渲染 `expedition.view` 与可用遗迹原型，展示房间进度、
## 当前事件选项、奖励日志与永久遗物，并把开始/进入/选择/撤退转成
## `command_requested` 意图；页面本身不查询、不写状态。
##
## ## 契约与约束
## - `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在
##   `expedition.view` 基础上补 `available_ruins`。
## - 未开始：列出遗迹与开始按钮；进行中：房间进度、进入/选项/撤退按钮、日志。
## - 所有按钮只 emit `command_requested(command, params)`。
##
## ## 外观来源（外部贴图 + SNSkin）
## - 面板用 Theme 变体 `SNInsetPanel`（钢制凹槽）；状态徽标改用 `SNBadge`
##   （13 px 中性纹理铭牌）。开始 / 进入按钮挂
##   `Button.icon = SNSkin.icon("status_route")` + `icon_max_width` 16（远征路线语义），
##   其余操作仍是 30 px 高的 `SNGhostButton`；按钮 `text` 不变。
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
		box.add_child(_label(_t("ui.ruins.select", "选择遗迹开始远征"), 16, SNSkin.color("brass.highlight")))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		for ruin in _model.get("available_ruins", []):
			if ruin is Dictionary:
				row.add_child(_action(_name((ruin as Dictionary).get("name_key", "")),
					&"expedition.start", {"ruin_id": String((ruin as Dictionary).get("id", ""))}, "status_route"))
		box.add_child(row)
		panel.add_child(box)
		add_child(panel)
		add_child(_relics())
		return
	add_child(_status())
	var phase := String(_model.get("phase", "room"))
	if phase == "room":
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_child(_action(_t("ui.ruins.enter", "进入房间"), &"expedition.enter", {}, "status_route"))
		row.add_child(_action(_t("ui.ruins.retreat", "撤退"), &"expedition.retreat", {}))
		add_child(row)
	elif phase == "event":
		add_child(_event_card())
		add_child(_action(_t("ui.ruins.retreat", "撤退"), &"expedition.retreat", {}))
	add_child(_log())
	add_child(_relics())


func _heading() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label(_t("ui.ruins.title", "遗迹远征"), 24, SNSkin.color("brass.highlight")))
	var ruin: Dictionary = _model.get("ruin", {})
	var subtitle := _t("ui.ruins.subtitle", "房间、危险与遗物")
	if not ruin.is_empty():
		subtitle = _name(ruin.get("name_key", ""))
	box.add_child(_label(subtitle, 14, SNSkin.color("text.muted")))
	return box


func _status() -> Control:
	var panel := _panel()
	var badges := HFlowContainer.new()
	badges.add_theme_constant_override("h_separation", 10)
	badges.add_child(_badge("%s %d/%d" % [
		_t("ui.ruins.room", "房间"), int(_model.get("room_index", 0)) + 1, int(_model.get("room_count", 0)),
	]))
	var current: Dictionary = _model.get("current_room", {})
	badges.add_child(_badge(_name(current.get("name_key", ""))))
	if bool(_model.get("event", {}).is_empty()) == false:
		badges.add_child(_badge(_name(_model.get("event", {}).get("name_key", ""))))
	panel.add_child(badges)
	return panel


func _event_card() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var event: Dictionary = _model.get("event", {})
	box.add_child(_label(_t(String(event.get("text_key", "")), String(event.get("text_key", "事件"))), 15, SNSkin.color("text.light")))
	for index in _model.get("event_options", []).size():
		var option: Dictionary = _model.get("event_options", [])[index]
		box.add_child(_action(_name(option.get("text_key", "")), &"expedition.choose", {"option_index": index}))
	panel.add_child(box)
	return panel


func _log() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label(_t("ui.ruins.log", "远征记录"), 16, SNSkin.color("brass.highlight")))
	var log: Array = _model.get("log", [])
	if log.is_empty():
		box.add_child(_label("—", 13, SNSkin.color("text.muted")))
	for entry in log:
		if entry is Dictionary:
			box.add_child(_label(_log_line(entry), 13, SNSkin.color("text.muted")))
	return box


func _relics() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label("%s %d" % [_t("ui.ruins.relics", "遗物收藏"), _model.get("relics", []).size()], 16, SNSkin.color("brass.highlight")))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	for relic in _model.get("relic_names", []):
		row.add_child(_badge(String(relic)))
	box.add_child(row)
	return box


func _log_line(entry: Dictionary) -> String:
	var event := String(entry.get("event", ""))
	var amount := int(entry.get("amount", 0))
	match event:
		"hazard":
			return _t("ui.ruins.log.hazard", "遭遇危险，损失 %d") % amount
		"event":
			return _t("ui.ruins.log.event", "处理事件：%s") % _t(String(entry.get("detail", "")), String(entry.get("detail", "")))
		"completed":
			return _t("ui.ruins.log.completed", "远征完成，获得奖励")
		"retreated":
			return _t("ui.ruins.log.retreated", "撤退离开遗迹")
	return event


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
