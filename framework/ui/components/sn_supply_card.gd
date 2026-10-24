class_name SNSupplyCard
extends PanelContainer
## @static-doc
## 作用：单种补给品的决策卡：存量、可补上限、价格、港存、预计续航和购买操作。
##
## One supply commodity card (coal or water).
##
## The card only renders a ViewModel and emits intent; the shell owns commands.
## bind() takes an optional tr callable for the cap-loss/headroom copy; without it
## the card keeps its original Chinese wording. ViewModels without capacity keep
## the legacy "current + max_buy" meter scale.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 卡片底层用 Theme 变体 `SNElevatedPanel`；资源条 `SNResourceMeter` 走
##   `SNBrassProgressBar` / `SNWaterProgressBar` 的纹理填充。文字色全部取
##   `SNSkin.color(token)`（text.light / text.muted / state.warning），不写十六进制。
## - 按钮：步进 `+5 / +10` 用 `SNCompactButton`（小铭牌，保持 38 px 高、不撑宽卡片），
##   补满用 `SNPrimaryButton` + `Button.icon = SNSkin.icon("action_confirm")`
##   （`icon_max_width` 16，不加包装容器，按钮 `text` 不变）。
## - 尺寸约束：三个按钮 `custom_minimum_size = (0, 38)` 不变；内容区
##   `Content` 节点名与行顺序（标题 / 资源条 / 信息行 / 阻断 / 操作）保持不变。
## @end-static-doc

signal command_requested(command: StringName, params: Dictionary)


var _content: VBoxContainer
var _kind: String = ""
var _tr: Callable = Callable()


func bind(data: Dictionary, title: String, blocker_labels: Array = [], tr: Callable = Callable()) -> void:
	_tr = tr
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
	var has_capacity := data.has("capacity")
	var capacity := float(data.get("capacity", maxf(current, fill_to)))
	var baseline_capacity := float(data.get("baseline_capacity", capacity))
	var cap_loss := float(data.get("cap_loss", maxf(0.0, baseline_capacity - capacity)))
	var headroom := float(data.get("headroom", maxf(0.0, capacity - current)))
	var maximum := maxf(current, capacity) if has_capacity else maxf(current, fill_to)

	var header := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", SNSkin.color("text.light"))
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
	meter.maximum_value = maximum
	meter.loss_value = cap_loss
	meter.loss_hint_text = _loc("ui.hint.cap_loss", "另一项补给占用的载重让本项上限下降") if cap_loss > 0.0 else ""
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
	if has_capacity:
		info.add_child(_small("%s %s" % [_loc("ui.label.headroom", "剩余可装"), _fmt(headroom)]))
		if cap_loss > 0.0:
			info.add_child(_small("%s %s" % [_loc("ui.label.cap_loss", "上限损失"), _fmt(cap_loss)], SNSkin.color("state.warning")))
	_content.add_child(info)

	if not blocker_labels.is_empty():
		var blocker := Label.new()
		blocker.text = ", ".join(blocker_labels)
		blocker.add_theme_font_size_override("font_size", 12)
		blocker.add_theme_color_override("font_color", SNSkin.color("state.warning"))
		_content.add_child(blocker)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var command := &"supply.buy_coal" if _kind == "coal" else &"supply.buy_water"
	for amount in [5, 10]:
		var button := _button("+%d" % amount, &"SNCompactButton")
		button.disabled = max_buy < amount
		button.pressed.connect(func() -> void:
			command_requested.emit(command, {"amount": amount})
		)
		actions.add_child(button)
	var fill := _button("补满 %d" % max_buy, &"SNPrimaryButton")
	fill.disabled = max_buy <= 0
	_apply_button_icon(fill, "action_confirm", 16)
	fill.pressed.connect(func() -> void:
		command_requested.emit(command, {"amount": max_buy})
	)
	actions.add_child(fill)
	_content.add_child(actions)


## Localized text with the key-name fallback convention of framework/localization.
func _loc(key: String, fallback: String) -> String:
	if not _tr.is_valid():
		return fallback
	var text := String(_tr.call(key))
	return fallback if text.is_empty() or text == key else text


func _build_once() -> void:
	if _content != null:
		return
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)


func _button(text: String, variation: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, 38)
	return button


## Skin icon without a wrapper node; the button text stays untouched.
func _apply_button_icon(button: Button, icon_id: String, max_width: int) -> void:
	var texture := SNSkin.icon(icon_id)
	if texture == null:
		return
	button.icon = texture
	button.add_theme_constant_override("icon_max_width", max_width)


func _small(text: String, color: Variant = null) -> Label:
	var resolved: Color = SNSkin.color("text.muted") if color == null else (color as Color)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", resolved)
	return label


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
