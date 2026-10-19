class_name SNIntelTable
extends PanelContainer
## Commodity x port comparison matrix for the intelligence page.
##
## The current port column reads the live market while every other column is a
## frozen intelligence snapshot; undiscovered ports keep a masked column so the
## player can still see how many ports are left to explore. All copy goes
## through the `tr` callable, so the component never hardcodes a language.
##
## Cell rules:
## - `？`  : the port is unknown or the snapshot does not cover this commodity.
## - `-`  : the port neither buys nor sells the commodity (per side otherwise).
## - price: "port buy price / port sell price", i.e. player sell / player buy.

const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_RED := Color("c36b53")
const COLOR_GREEN := Color("76aa8c")
const COLOR_CELL := Color("0b292d")
const COLOR_CELL_BORDER := Color("2e4b4c")

const KEY_UNKNOWN_PORT := "ui.label.unknown_port"
const KEY_GOODS := "ui.label.goods"
const KEY_UNIT_WEIGHT := "ui.label.unit_weight"
const KEY_REF_PRICE := "ui.label.ref_price"
const KEY_COL_AGE := "ui.intel.col_age"
const KEY_LEGEND_CELL := "ui.intel.legend_cell"
const KEY_LEGEND_GAP := "ui.intel.legend_gap"
const KEY_LEGEND_TREND := "ui.intel.legend_trend"

const UNKNOWN_TEXT := "？"
const GAP_TEXT := "-"

var _content: VBoxContainer
var _tr: Callable


## Renders `columns` (IntelViewQuery columns) against `rows` (IntelViewQuery
## rows). Safe to call repeatedly; the previous content is rebuilt.
func bind(columns: Array, rows: Array, current_port_id: String, tr: Callable) -> void:
	_tr = tr
	theme_type_variation = &"SNElevatedPanel"
	_build_once()
	for child in _content.get_children():
		_content.remove_child(child)
		child.free()
	_build_legend()
	_build_grid(columns, rows, current_port_id)


func _build_once() -> void:
	if _content != null:
		return
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)


func _build_legend() -> void:
	var legend := Label.new()
	legend.name = "Legend"
	legend.text = "  ·  ".join([_txt(KEY_LEGEND_CELL), _txt(KEY_LEGEND_GAP), _txt(KEY_LEGEND_TREND)])
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", COLOR_MUTED)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(legend)


func _build_grid(columns: Array, rows: Array, current_port_id: String) -> void:
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3 + columns.size()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	grid.add_child(_header_cell(_txt(KEY_GOODS), 180.0))
	grid.add_child(_header_cell(_txt(KEY_UNIT_WEIGHT), 120.0))
	grid.add_child(_header_cell(_txt(KEY_REF_PRICE), 100.0))
	for column in columns:
		if column is Dictionary:
			grid.add_child(_port_header(column, current_port_id))
	for row in rows:
		if not (row is Dictionary):
			continue
		var name_label := Label.new()
		name_label.text = _item_name(row)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", COLOR_TEXT)
		name_label.custom_minimum_size.x = 180.0
		grid.add_child(name_label)
		var weight_label := _muted_label(_fmt(float(row.get("unit_weight", 0.0))))
		weight_label.custom_minimum_size.x = 120.0
		grid.add_child(weight_label)
		var price_label := _muted_label(str(int(row.get("ref_price", 0))))
		price_label.custom_minimum_size.x = 100.0
		grid.add_child(price_label)
		var cells: Array = row.get("cells", [])
		for index in columns.size():
			var column: Dictionary = columns[index] if columns[index] is Dictionary else {}
			var cell: Dictionary = cells[index] if index < cells.size() and cells[index] is Dictionary else {}
			grid.add_child(_value_cell(cell, _is_current(column, current_port_id)))
	_content.add_child(grid)


func _header_cell(text: String, minimum_width: float) -> Control:
	return _frame(_muted_label(text), false, minimum_width, false)


func _port_header(column: Dictionary, current_port_id: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var current := _is_current(column, current_port_id)
	var masked := bool(column.get("masked", false)) or not bool(column.get("discovered", true))
	var name_label := Label.new()
	name_label.text = _txt(KEY_UNKNOWN_PORT) if masked else _txt(String(column.get("name_key", "")))
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_BRASS if current else COLOR_MUTED)
	box.add_child(name_label)
	var age := float(column.get("age_hours", -1.0))
	if not current and bool(column.get("in_snapshot", false)) and age >= 0.0:
		var age_label := Label.new()
		age_label.text = _age_label_text(age)
		age_label.add_theme_font_size_override("font_size", 10)
		age_label.add_theme_color_override("font_color", COLOR_MUTED)
		box.add_child(age_label)
	return _frame(box, current, 120.0, true)


func _value_cell(cell: Dictionary, highlight: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var price_label := Label.new()
	price_label.text = _price_text(cell)
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", COLOR_TEXT if bool(cell.get("known", false)) else COLOR_MUTED)
	box.add_child(price_label)
	if bool(cell.get("known", false)):
		var percent := float(cell.get("trend_percent", 0.0))
		var trend_label := Label.new()
		trend_label.text = _percent_text(percent)
		trend_label.add_theme_font_size_override("font_size", 11)
		trend_label.add_theme_color_override("font_color", _percent_color(percent))
		box.add_child(trend_label)
	return _frame(box, highlight, 120.0, true)


func _frame(inner: Control, highlight: bool, minimum_width: float, expand: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minimum_width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_BRASS, 0.10) if highlight else COLOR_CELL
	style.border_color = Color(COLOR_BRASS, 0.35) if highlight else COLOR_CELL_BORDER
	style.set_border_width_all(1)
	if highlight:
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_left = 2
		style.corner_radius_bottom_right = 2
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(inner)
	return panel


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	return label


func _item_name(row: Dictionary) -> String:
	var name_key := String(row.get("name_key", ""))
	if name_key.is_empty():
		name_key = String(row.get("item_id", ""))
	return _txt(name_key)


func _is_current(column: Dictionary, current_port_id: String) -> bool:
	if bool(column.get("is_current", false)):
		return true
	return not current_port_id.is_empty() and String(column.get("port_id", "")) == current_port_id


func _price_text(cell: Dictionary) -> String:
	if not bool(cell.get("known", false)):
		return UNKNOWN_TEXT
	var buy := int(cell.get("buy_price", -1))
	var sell := int(cell.get("sell_price", -1))
	if buy < 0 and sell < 0:
		return GAP_TEXT
	return "%s/%s" % [_price_part(buy), _price_part(sell)]


func _price_part(value: int) -> String:
	return str(value) if value >= 0 else GAP_TEXT


func _percent_text(percent: float) -> String:
	if absf(percent) < 0.0005:
		return "0.0%"
	return "%+.1f%%" % (percent * 100.0)


func _percent_color(percent: float) -> Color:
	if percent > 0.0005:
		return COLOR_GREEN
	if percent < -0.0005:
		return COLOR_RED
	return COLOR_MUTED


## `ui.intel.col_age` is a format string ("Snapshot %s h old"); fall back to a
## prefix + neutral unit when it carries no placeholder.
func _age_label_text(hours: float) -> String:
	var template := _txt(KEY_COL_AGE)
	if template.contains("%s"):
		return template % _fmt(hours)
	return "%s %s" % [template, _age_text(hours)]


func _age_text(hours: float) -> String:
	if hours < 1.0:
		return "%dmin" % int(round(hours * 60.0))
	if hours < 48.0:
		return "%.1fh" % hours
	return "%.1fd" % (hours / 24.0)


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _txt(key: String) -> String:
	if key.is_empty():
		return key
	if _tr.is_valid():
		var value: Variant = _tr.call(key)
		if value is String and not String(value).is_empty():
			return String(value)
	return key
