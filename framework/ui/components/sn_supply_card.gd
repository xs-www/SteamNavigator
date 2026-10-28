class_name SNSupplyCard
extends PanelContainer
## @static-doc
## 作用：单种补给品的决策卡：存量条、可补上限、价格、港存、预计续航和购买操作；信息行已图标化（图标 + 数值，字段名只进 tooltip）。
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
##
## ## 文字精简（2026-10-28 图标轮）
## - 信息行原来是「单价 / 港存 / 补满花费 / 剩余可装 / 上限损失」五个文字字段，
##   现在改为 16 px 皮肤图标 + 数值的 chip 行：
##   `resource_coins` 单价、`shipyard_cargo` 港存、`resource_coins` 补满花费、
##   `resource_cargo` 剩余可装、`status_warning`（`state.warning` 色）上限损失。
## - 字段名只挂在每枚 chip 的 `tooltip_text` 上，复用现有本地化键
##   （`ui.label.ref_price` / `ui.label.port_stock` / `ui.label.cost` /
##   `ui.label.headroom` / `ui.label.cap_loss`），不新增键。
## - 资源条不再渲染「存量」名称（`label_text = ""`），数值 `当前 / 上限` 保留。
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
	# 2026-10-28 文字精简：卡片标题已写明补给种类，条内不再重复「存量」名称；
	# 数值（当前 / 上限）与损失带保持不变。
	meter.label_text = ""
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
	info.add_child(_info_chip("resource_coins", _fmt(price), _loc("ui.label.ref_price", "单价")))
	info.add_child(_info_chip("shipyard_cargo", str(port_stock), _loc("ui.label.port_stock", "港存")))
	info.add_child(_info_chip("resource_coins", str(fill_cost), _loc("ui.label.cost", "补满花费")))
	if has_capacity:
		info.add_child(_info_chip("resource_cargo", _fmt(headroom), _loc("ui.label.headroom", "剩余可装")))
		if cap_loss > 0.0:
			info.add_child(_info_chip(
				"status_warning",
				_fmt(cap_loss),
				_loc("ui.label.cap_loss", "上限损失"),
				SNSkin.color("state.warning")
			))
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


## 信息行单枚 chip：16 px 皮肤图标 + 数值；字段名只挂 tooltip（键由调用方传入，
## 不新增本地化键，也不在卡片里写数据标签文字）。
func _info_chip(icon_id: String, value: String, tooltip: String, color: Variant = null) -> Control:
	var resolved: Color = SNSkin.color("text.muted") if color == null else (color as Color)
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.tooltip_text = tooltip
	chip.add_child(SNSkin.icon_rect(icon_id, 16.0))
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", resolved)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
