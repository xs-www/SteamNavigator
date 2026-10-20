class_name SeaChartScreen
extends VBoxContainer
## @static-doc
## 作用：全屏航海图页（海图系统阶段 2 入口集成）：左侧 `SNSeaChartView` 铺满、
## 右侧 `SNSeaChartPanel`（320 px）展示选中港口与航线，顶部章节标题 + 关闭按钮。
## 数据只来自 `sea_chart.view`，经 `bind(view_model, translate)` 注入。
##
## ## 契约与约束
## - 图上点击港口：视图只改选中态，面板绑定该港与当前港之间的航线数据；
##   本页自身不查询、不执行命令。
## - 面板「启航」冒泡为 `voyage_requested(port_id)`，由 Shell 路由到出航页并
##   预选目的港（锅炉策略仍在出航页确认后才发 `voyage.start`）。
## - `close_requested` 交给 Shell 决定返回页；`has_run=false` 时只显示提示文案。
## - 选中当前港时面板只显示港口信息（无航线区、无启航按钮）。
## @end-static-doc

signal close_requested
signal voyage_requested(port_id: String)

const COLOR_MUTED := Color("9fafa7")
const PANEL_WIDTH := 320.0

var _tr: Callable
var _view_model: Dictionary = {}
var _chart: SNSeaChartView
var _panel: SNSeaChartPanel


func bind(view_model: Dictionary, translate: Callable) -> void:
	_view_model = view_model
	_tr = translate
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	add_child(_header())
	if not bool(_view_model.get("has_run", false)):
		var message := Label.new()
		message.text = _loc("ui.sea_chart.no_data", "没有可用的世界数据。")
		message.add_theme_font_size_override("font_size", 15)
		message.add_theme_color_override("font_color", COLOR_MUTED)
		add_child(message)
		return
	var row := HBoxContainer.new()
	row.name = "ChartRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_chart = SNSeaChartView.new()
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.port_clicked.connect(_on_port_clicked)
	row.add_child(_chart)
	_panel = SNSeaChartPanel.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.voyage_requested.connect(voyage_requested.emit)
	row.add_child(_panel)
	_chart.bind(_view_model, _tr)
	var initial := String(_view_model.get("current_port_id", ""))
	var ports: Array = _view_model.get("ports", [])
	if initial.is_empty() and not ports.is_empty():
		initial = String((ports[0] as Dictionary).get("id", ""))
	if not initial.is_empty():
		_chart.select_port(initial)
		_bind_panel(initial)


func _header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	var heading := SNSectionHeader.new()
	heading.eyebrow = _loc("ui.sea_chart.eyebrow", "NAUTICAL CHART")
	heading.title = _loc("ui.sea_chart.title", "航海图")
	heading.detail = _loc("ui.sea_chart.detail", "滚轮缩放 · 拖拽平移 · 点击港口查看详情")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = _loc("ui.sea_chart.close", "返回")
	close.theme_type_variation = &"SNGhostButton"
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	return header


func _on_port_clicked(port_id: String) -> void:
	if _chart == null:
		return
	_chart.select_port(port_id)
	_bind_panel(port_id)


## Same glue as the standalone preview: the selected port plus the route between
## it and the current harbour drive the right-hand panel.
func _bind_panel(port_id: String) -> void:
	if _panel == null:
		return
	var ports: Array = _view_model.get("ports", [])
	var current := String(_view_model.get("current_port_id", ""))
	var port_data := {}
	for entry in ports:
		if String((entry as Dictionary).get("id", "")) == port_id:
			port_data = entry
			break
	var route_data := {}
	if not port_data.is_empty() and port_id != current:
		for route in _view_model.get("routes", []):
			var from_id := String((route as Dictionary).get("from", ""))
			var to_id := String((route as Dictionary).get("to", ""))
			if (from_id == current and to_id == port_id) \
					or (from_id == port_id and to_id == current):
				route_data = route
				break
	_panel.bind(port_data, route_data, _tr)


func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	return fallback if text.is_empty() or text == key else text
