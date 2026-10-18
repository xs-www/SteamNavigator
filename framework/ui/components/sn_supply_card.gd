class_name SNSupplyCard
extends PanelContainer
## One supply commodity card (coal or water).
##
## The card only renders a ViewModel and emits intent; the shell owns commands.

signal command_requested(command: StringName, params: Dictionary)

var _content: VBoxContainer
var _kind: String = ""


func bind(data: Dictionary, title: String, blocker_labels: Array = []) -> void:
	_kind = String(data.get("kind", "coal"))
	theme_type_variation = &"SNElevatedPanel"
	_build_once()
	var current := float(data.get("current", 0.0))
	var fill_to := float(data.get("fill_to", current))
	var max_buy := int(data.get("max_buy", 0))
	var price := float(data.get("price", 0.0))
	var port_stock := int(data.get("port_stock", 0))
	var estimated_days := float(data.get("estimated_days", -1.0))
	var fill_cost := int(data.get("fill_cost", 0))

	var header := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("e1c487"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var badge := SNBadge.new()
	badge.text = "可补 %d" % max_buy
	badge.tone = SNBadge.Tone.SUCCESS if max_buy > 0 else SNBadge.Tone.WARNING
	header.add_child(badge)
	_content.add_child(header)

	var meter := SNResourceMeter.new()
	meter.label_text = "存量"
	meter.current_value = current
	meter.maximum_value = maxf(current, fill_to)
	meter.suffix = ""
	meter.hint = "可补至 %.0f · 预计可用 %s" % [
		fill_to,
		("%.1f 天" % estimated_days) if estimated_days >= 0.0 else "未知",
	]
	meter.tone = SNResourceMeter.Tone.BRASS if _kind == "coal" else SNResourceMeter.Tone.WATER
	_content.add_child(meter)

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 14)
	info.add_child(_small("单价 %s" % _fmt(price)))
	info.add_child(_small("港存 %d" % port_stock))
	info.add_child(_small("补满花费 %d" % fill_cost))
	_content.add_child(info)

	if not blocker_labels.is_empty():
		var blocker := Label.new()
		blocker.text = ", ".join(blocker_labels)
		blocker.add_theme_font_size_override("font_size", 12)
		blocker.add_theme_color_override("font_color", Color("c36b53"))
		_content.add_child(blocker)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var command := &"supply.buy_coal" if _kind == "coal" else &"supply.buy_water"
	for amount in [5, 10]:
		var button := _button("+%d" % amount)
		button.theme_type_variation = &"SNSecondaryButton"
		button.disabled = max_buy < amount
		button.pressed.connect(func() -> void:
			command_requested.emit(command, {"amount": amount})
		)
		actions.add_child(button)
	var fill := _button("补满 %d" % max_buy)
	fill.theme_type_variation = &"SNPrimaryButton"
	fill.disabled = max_buy <= 0
	fill.pressed.connect(func() -> void:
		command_requested.emit(command, {"amount": max_buy})
	)
	actions.add_child(fill)
	_content.add_child(actions)


func _build_once() -> void:
	if _content != null:
		return
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	return button


func _small(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("9fafa7"))
	return label


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
