class_name MarketScreen
extends VBoxContainer
## Port market presentation screen.
##
## The shell supplies a complete market ViewModel, including intelligence
## trends. Trading actions are emitted as intent and executed by the shell.

signal command_requested(command: StringName, params: Dictionary)

const SPARKLINE_SCENE := preload("res://framework/ui/components/sn_sparkline.tscn")
const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_TEAL := Color("76aaa7")
const COLOR_RED := Color("c36b53")
const COLOR_GREEN := Color("76aa8c")

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
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var ship: Dictionary = view_model.get("ship", {})
	content.add_child(_label("金币 %d · 重量 %s / %s · 货舱 %s / %s · %s %s" % [
		int(view_model.get("money", 0)),
		_fmt(float(ship.get("total_weight", 0.0))),
		_fmt(float(ship.get("max_weight", 0.0))),
		_fmt(float(ship.get("cargo_used", 0.0))),
		_fmt(float(ship.get("cargo_capacity", 0.0))),
		_loc("ui.label.inventory_cost", ""),
		_fmt(float(ship.get("cargo_cost_basis", 0.0))),
	], 13, COLOR_MUTED))
	content.add_child(_label(_loc("ui.hint.market", ""), 12, COLOR_MUTED))
	content.add_child(_market_grid(view_model))
	add_child(panel)


func _market_grid(view_model: Dictionary) -> GridContainer:
	var trends: Dictionary = view_model.get("trends", {})
	var grid := GridContainer.new()
	grid.columns = 9
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for heading in ["商品", "单价", "库存", _loc("ui.label.unit_weight", "单位重量"), "持有 / 可售", _loc("ui.label.avg_cost", ""), _loc("ui.label.trend", "趋势"), "买入", "卖出"]:
		grid.add_child(_grid_label(heading, 12, COLOR_MUTED))
	for row in view_model.get("market", []):
		if not (row is Dictionary):
			continue
		_add_market_row(grid, row, String(trends.get(String(row.get("item_id", "")), "")))
	return grid


func _add_market_row(grid: GridContainer, row: Dictionary, trend: String) -> void:
	var item_id := String(row.get("item_id", ""))
	var buyable := bool(row.get("buyable", true))
	var item_label := _loc(String(row.get("name_key", "")), item_id)
	if not buyable:
		item_label += " · " + _loc("ui.label.sell_only", "Sell-only")
	grid.add_child(_grid_label(item_label, 13, COLOR_TEXT if buyable else COLOR_MUTED))
	grid.add_child(_grid_label(str(int(row.get("price", 0))), 13, COLOR_TEAL))
	grid.add_child(_grid_label(str(int(row.get("stock", 0))), 13, COLOR_TEXT))
	grid.add_child(_grid_label(_fmt(float(row.get("unit_weight", 0.0))), 13, COLOR_MUTED))
	grid.add_child(_grid_label("%d / %d" % [int(row.get("cargo_amount", 0)), int(row.get("sellable_amount", 0))], 13, COLOR_TEXT))
	var average_cost := float(row.get("cargo_avg_cost", 0.0))
	grid.add_child(_grid_label(_fmt(average_cost) if average_cost > 0.0 else "—", 13, COLOR_TEXT))
	grid.add_child(_trend_cell(row, trend))
	grid.add_child(_trade_buttons(&"trade.buy", item_id, [1, 5, 10], int(row.get("stock", 0)), buyable))
	grid.add_child(_trade_buttons(&"trade.sell", item_id, [1, 5], int(row.get("sellable_amount", 0)), true))


func _trend_cell(row: Dictionary, trend: String) -> Control:
	var cell := HBoxContainer.new()
	cell.custom_minimum_size.x = 110
	cell.add_theme_constant_override("separation", 4)
	var spark: Variant = SPARKLINE_SCENE.instantiate()
	spark.custom_minimum_size = Vector2(58, 22)
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var prices: Array = row.get("recent_prices", [])
	spark.set_values(prices, _trend_color(trend))
	cell.add_child(spark)
	var percent := float(row.get("trend_percent", 0.0)) * 100.0
	cell.add_child(_label(("%+.1f%%" % percent) if prices.size() >= 2 else "—", 11, _trend_color(trend)))
	return cell


func _trade_buttons(command: StringName, item_id: String, amounts: Array, available: int, visible_actions: bool) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = 88 if amounts.size() <= 2 else 136
	row.add_theme_constant_override("separation", 2)
	if not visible_actions:
		row.add_child(_label("—", 13, COLOR_MUTED))
		return row
	for amount in amounts:
		var button := Button.new()
		button.text = str(amount)
		button.custom_minimum_size = Vector2(34, 30)
		button.disabled = available < int(amount)
		button.pressed.connect(_emit_trade.bind(command, item_id, int(amount)))
		row.add_child(button)
	return row


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
