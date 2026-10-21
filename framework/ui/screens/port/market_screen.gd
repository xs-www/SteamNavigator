class_name MarketScreen
extends VBoxContainer
## Port market presentation screen.
##
## The shell supplies a complete market ViewModel, including intelligence
## trends. Trading actions are emitted as intent and executed by the shell.
##
## Layout: the screen shares the window with the persistent 3D port stage, so
## it is designed for a 620 px berth sidebar. Goods render as a vertical list of
## compact entries instead of the old full-width nine-column grid; rows break
## vertically rather than clipping horizontally, and the outer PageScroll owns
## vertical scrolling (the screen itself adds no ScrollContainer).

signal command_requested(command: StringName, params: Dictionary)

const SPARKLINE_SCENE := preload("res://framework/ui/components/sn_sparkline.tscn")
const SUPPLY_CARD_SCENE := preload("res://framework/ui/components/sn_supply_card.tscn")
const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_TEAL := Color("76aaa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_RED := Color("c36b53")
const COLOR_GREEN := Color("76aa8c")
## Vertical gap between two commodity entries (design: 6-8 px).
const ENTRY_SEPARATION := 7

var _tr: Callable


func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	var port: Dictionary = view_model.get("current_port", {})
	add_child(_heading(
		_loc("ui.nav.market", "Market"),
		_loc(String(port.get("name_key", "")), String(port.get("id", ""))),
		"市场行情"
	))
	add_child(_summary_panel(view_model))
	add_child(_market_list(view_model))
	add_child(_supply_block(view_model))


## 4.5.3：补给并市 —— 市场页上方的煤 / 水区块，复用 `supply.buy_*` 命令。
func _supply_block(view_model: Dictionary) -> Control:
	var supply: Dictionary = view_model.get("supply", {})
	var block := VBoxContainer.new()
	block.name = "MarketSupply"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 7)
	if supply.is_empty():
		return block
	var title := _label(_loc("ui.market.supply_section", "补给（煤 / 水）"), 15, COLOR_BRASS)
	block.add_child(title)
	for kind in ["coal", "water"]:
		var data: Dictionary = supply.get("%s_view" % kind, {})
		if data.is_empty():
			continue
		var card: Variant = SUPPLY_CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(0, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.bind(
			data,
			_loc("ui.label.%s" % kind, kind),
			_supply_blocker_labels(data.get("blockers", [])),
			_tr
		)
		card.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
			command_requested.emit(command, params)
		)
		block.add_child(card)
	return block


func _supply_blocker_labels(blockers: Array) -> Array:
	var labels: Array = []
	for blocker in blockers:
		match String(blocker):
			"story_locked":
				labels.append(_loc("ui.story.supply_locked", ""))
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


func _summary_panel(view_model: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var ship: Dictionary = view_model.get("ship", {})
	content.add_child(_label("金币 %d · 重量 %s / %s" % [
		int(view_model.get("money", 0)),
		_fmt(float(ship.get("total_weight", 0.0))),
		_fmt(float(ship.get("max_weight", 0.0))),
	], 13, COLOR_MUTED))
	content.add_child(_label("货舱 %s / %s · %s %s" % [
		_fmt(float(ship.get("cargo_used", 0.0))),
		_fmt(float(ship.get("cargo_capacity", 0.0))),
		_loc("ui.label.inventory_cost", ""),
		_fmt(float(ship.get("cargo_cost_basis", 0.0))),
	], 13, COLOR_MUTED))
	var hint := _paragraph(_loc("ui.hint.market", ""), 12, COLOR_MUTED)
	if not hint.text.is_empty():
		content.add_child(hint)
	return panel


func _market_list(view_model: Dictionary) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", ENTRY_SEPARATION)
	var trends: Dictionary = view_model.get("trends", {})
	for row in view_model.get("market", []):
		if not (row is Dictionary):
			continue
		var item_id := String((row as Dictionary).get("item_id", ""))
		list.add_child(_market_entry(row as Dictionary, String(trends.get(item_id, ""))))
	return list


func _market_entry(row: Dictionary, trend: String) -> Control:
	var item_id := String(row.get("item_id", ""))
	var buyable := bool(row.get("buyable", true))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var item_label := _grid_label(_row_title(row, buyable), 13, COLOR_TEXT if buyable else COLOR_MUTED)
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(item_label)
	top.add_child(_trend_cell(row, trend))
	content.add_child(top)

	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	metrics.add_child(_grid_label("单价 %d" % int(row.get("price", 0)), 13, COLOR_TEAL))
	metrics.add_child(_grid_label("库存 %d" % int(row.get("stock", 0)), 13, COLOR_TEXT))
	metrics.add_child(_grid_label("%s %d / %s %d" % [
		_loc("ui.label.held", "Held"),
		int(row.get("cargo_amount", 0)),
		_loc("ui.label.sellable", "Sellable"),
		int(row.get("sellable_amount", 0)),
	], 13, COLOR_TEXT))
	var average_cost := float(row.get("cargo_avg_cost", 0.0))
	metrics.add_child(_grid_label("%s %s" % [
		_loc("ui.label.avg_cost", "Avg cost"),
		_fmt(average_cost) if average_cost > 0.0 else "—",
	], 13, COLOR_TEXT))
	metrics.add_child(_grid_label("%s %s" % [
		_loc("ui.label.unit_weight", "Unit weight"),
		_fmt(float(row.get("unit_weight", 0.0))),
	], 12, COLOR_MUTED))
	content.add_child(metrics)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	actions.add_child(_action_label("买入"))
	actions.add_child(_trade_buttons(&"trade.buy", item_id, [1, 5, 10], int(row.get("stock", 0)), buyable))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	actions.add_child(_action_label("卖出"))
	actions.add_child(_trade_buttons(&"trade.sell", item_id, [1, 5], int(row.get("sellable_amount", 0)), true))
	content.add_child(actions)
	return panel


func _row_title(row: Dictionary, buyable: bool) -> String:
	var item_id := String(row.get("item_id", ""))
	var item_label := _loc(String(row.get("name_key", "")), item_id)
	if not buyable:
		item_label += " · " + _loc("ui.label.sell_only", "Sell-only")
	return item_label


func _trend_cell(row: Dictionary, trend: String) -> Control:
	var cell := HBoxContainer.new()
	cell.custom_minimum_size.x = 136
	cell.add_theme_constant_override("separation", 4)
	cell.add_child(_label(_loc("ui.label.trend", "Trend"), 11, COLOR_MUTED))
	var spark: Variant = SPARKLINE_SCENE.instantiate()
	spark.custom_minimum_size = Vector2(64, 24)
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var prices: Array = row.get("recent_prices", [])
	spark.set_values(prices, _trend_color(trend))
	cell.add_child(spark)
	var percent := float(row.get("trend_percent", 0.0)) * 100.0
	cell.add_child(_label(("%+.1f%%" % percent) if prices.size() >= 2 else "—", 11, _trend_color(trend)))
	return cell


func _trade_buttons(command: StringName, item_id: String, amounts: Array, available: int, visible_actions: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if not visible_actions:
		row.add_child(_label("—", 13, COLOR_MUTED))
		return row
	for amount in amounts:
		var button := Button.new()
		button.text = str(amount)
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(34, 28)
		button.disabled = available < int(amount)
		button.pressed.connect(_emit_trade.bind(command, item_id, int(amount)))
		row.add_child(button)
	return row


func _action_label(text: String) -> Label:
	return _label(text, 12, COLOR_MUTED)


func _emit_trade(command: StringName, item_id: String, amount: int) -> void:
	command_requested.emit(command, {"item_id": item_id, "amount": amount})


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new()
	header.eyebrow = eyebrow
	header.title = title
	header.detail = detail
	return header


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Long descriptive copy (the market hint) wraps inside the 620 px panel instead
## of forcing a horizontal minimum width; dense field labels stay single-line.
func _paragraph(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _grid_label(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.custom_minimum_size.x = 72
	return label


func _trend_color(trend: String) -> Color:
	match trend:
		"up":
			return COLOR_GREEN
		"down":
			return COLOR_RED
		_:
			return COLOR_MUTED


func _loc(key: String, fallback: String) -> String:
	if not _tr.is_valid():
		return fallback
	var text := String(_tr.call(key))
	return fallback if text.is_empty() or text == key else text


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
