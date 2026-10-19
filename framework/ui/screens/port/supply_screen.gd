class_name SupplyScreen
extends VBoxContainer
## Supply and repair presentation screen.
##
## The shell owns queries and commands. This scene only binds a SupplyView
## dictionary, renders it, and emits the player's command intent.

signal command_requested(command: StringName, params: Dictionary)

const SUPPLY_CARD_SCENE := preload("res://framework/ui/components/sn_supply_card.tscn")
const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_RED := Color("c36b53")

var _tr: Callable


func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	var port_name := _loc(
		String(view_model.get("port_name_key", "")),
		String(view_model.get("port_id", ""))
	)
	add_child(_heading("港务补给站", "补给与维护 · %s" % port_name, "煤水按当前港价购买；补给计入总重量。"))
	add_child(_summary(view_model))
	add_child(_supply_cards(view_model))
	add_child(_repair_panel(view_model))


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _summary(view_model: Dictionary) -> Control:
	var panel := _panel(&"SNInsetPanel")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.add_child(_badge("金币 %d" % int(view_model.get("money", 0)), SNBadge.Tone.NEUTRAL))
	row.add_child(_badge("重量 %s / %s" % [
		_fmt(float(view_model.get("total_weight", 0.0))),
		_fmt(float(view_model.get("max_weight", 0.0))),
	], SNBadge.Tone.NEUTRAL))
	row.add_child(_badge(
		"剩余载重 %s" % _fmt(float(view_model.get("remaining_weight", 0.0))),
		SNBadge.Tone.WARNING
	))
	row.add_child(_badge("耐久 %s / %s" % [
		_fmt(float(view_model.get("durability", 0.0))),
		_fmt(float(view_model.get("repair", {}).get("max_durability", 0.0))),
	], SNBadge.Tone.SUCCESS))
	content.add_child(row)
	if not bool(view_model.get("has_supply", false)):
		content.add_child(_label("当前港口没有补给码头。", 14, COLOR_RED))
	return panel


func _supply_cards(view_model: Dictionary) -> Control:
	var cards := HFlowContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 16)
	cards.add_theme_constant_override("v_separation", 16)
	for kind in ["coal", "water"]:
		var data: Dictionary = view_model.get("%s_view" % kind, {})
		var card = SUPPLY_CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(560, 250)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.bind(
			data,
			_loc("ui.label.%s" % kind, kind),
			_blocker_labels(data.get("blockers", [])),
			_tr
		)
		card.command_requested.connect(_forward_command)
		cards.add_child(card)
	return cards


func _repair_panel(view_model: Dictionary) -> Control:
	var panel := _panel(&"SNElevatedPanel")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var repair: Dictionary = view_model.get("repair", {})
	var header := HBoxContainer.new()
	var title := _label("维修", 20, COLOR_BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_badge(
		"可维修" if bool(view_model.get("can_repair", false)) else "无需维修或资源不足",
		SNBadge.Tone.SUCCESS if bool(view_model.get("can_repair", false)) else SNBadge.Tone.WARNING
	))
	content.add_child(header)
	content.add_child(_label("缺失耐久 %s · 预计费用 %d 金币（单位维修价 %s）" % [
		_fmt(float(repair.get("missing", 0.0))),
		int(repair.get("cost", 0)),
		_fmt(float(view_model.get("repair_per_point", 0.0))),
	], 13, COLOR_TEXT))
	var repair_button := Button.new()
	repair_button.text = _loc("ui.button.repair", "维修")
	repair_button.custom_minimum_size = Vector2(0, 38)
	repair_button.theme_type_variation = &"SNPrimaryButton"
	repair_button.disabled = not bool(view_model.get("can_repair", false))
	repair_button.pressed.connect(func() -> void:
		command_requested.emit(&"supply.repair", {})
	)
	content.add_child(repair_button)
	return panel


func _forward_command(command: StringName, params: Dictionary) -> void:
	command_requested.emit(command, params)


func _blocker_labels(blockers: Array) -> Array:
	var labels: Array = []
	for blocker in blockers:
		match String(blocker):
			"no_supply":
				labels.append(_loc("ui.error.no_supply", ""))
			"no_stock":
				labels.append(_loc("ui.error.insufficient_stock", ""))
			"weight_limit":
				labels.append(_loc("ui.error.weight", ""))
			"insufficient_money":
				labels.append(_loc("ui.error.money", ""))
			_:
				labels.append(String(blocker))
	return labels


func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new()
	header.eyebrow = eyebrow
	header.title = title
	header.detail = detail
	return header


func _panel(variation: StringName) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _badge(text: String, tone: int) -> SNBadge:
	var badge := SNBadge.new()
	badge.text = text
	badge.tone = tone
	return badge


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


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
