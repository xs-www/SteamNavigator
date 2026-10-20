class_name AtSeaScreen
extends VBoxContainer
## @static-doc
## 作用：航行演出页（海图系统阶段 3）：整幅海图 + 底部航程条。船只 icon 沿
## `sea_chart.view` 里那条航线的贝塞尔折线、按弧长行进，航程条显示进度、
## 预计抵达时间、时间倍率，并提供「跳过演出」。
##
## ## 契约与约束
## - 本页不查询、不执行命令、不推进时间：Shell 把 `sea_chart.view` 结果和
##   `VoyagePresentation.snapshot()` 推进来（`bind()` / `set_presentation()`）。
## - 船只坐标只通过 `SNSeaChartView.set_ship_position()` 覆盖，不重新绑定整个
##   视图模型（每帧重绑会把迷雾纹理与取景一起重建）。
## - 缺航线路径（例如孪生世界 MST 上没有这段边）时退回「起点→终点直线」，
##   演出仍然成立，不出现船停在原地不动。
## - `skip_requested` 只表达意图；跳过后事件仍由 Shell 推给玩家。
## @end-static-doc

signal skip_requested

const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_TEAL := Color("76a7a7")
const COLOR_BRASS := Color("e1c487")

var _tr: Callable
var _view_model: Dictionary = {}
var _voyage: Dictionary = {}
var _positions: Dictionary = {}
var _origin: String = ""
var _destination: String = ""
var _path: PackedVector2Array = PackedVector2Array()
var _progress: float = 0.0
var _chart: SNSeaChartView
var _progress_bar: ProgressBar
var _clock_label: Label
var _speed_label: Label
var _route_label: Label
var _skip_button: Button


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_view_model = vm.get("chart", {}) if vm.get("chart", {}) is Dictionary else {}
	_voyage = vm.get("voyage", {}) if vm.get("voyage", {}) is Dictionary else {}
	_positions = vm.get("positions", {}) if vm.get("positions", {}) is Dictionary else {}
	_origin = String(_voyage.get("origin", ""))
	_destination = String(_voyage.get("destination", ""))
	_path = _route_path()
	_rebuild()
	if vm.get("presentation", null) is Dictionary:
		set_presentation(vm["presentation"])


## 每帧由 Shell 推进：更新航程条与船只位置（世界坐标）。
func set_presentation(snapshot: Dictionary) -> void:
	if _chart == null:
		return
	_progress = clampf(float(snapshot.get("progress", 0.0)), 0.0, 1.0)
	if _progress_bar != null:
		_progress_bar.value = _progress * 100.0
	var total_hours := float(snapshot.get("total_hours", 0.0))
	var elapsed_hours := float(snapshot.get("elapsed_hours", 0.0))
	if _clock_label != null:
		_clock_label.text = "%s %s / %s" % [
			_tr_or("ui.label.voyage_clock", "航程"),
			_format_hours(elapsed_hours),
			_format_hours(total_hours),
		]
	if _speed_label != null:
		var rate := float(snapshot.get("hours_per_second", 0.0))
		_speed_label.text = "%s ×%s" % [
			_tr_or("ui.label.time_compression", "时间加速"),
			_format_rate(rate),
		]
	_chart.set_ship_position(_position_at(_progress))


func get_chart() -> SNSeaChartView:
	return _chart


## 航程进度（0..1），测试与 Shell 都读这个，而不是去猜 ProgressBar 的数值。
func get_progress() -> float:
	return _progress


## 当前船只世界坐标；没有路径时退回起点。
func get_ship_world_position() -> Vector2:
	return _position_at(_progress)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart = SNSeaChartView.new()
	_chart.name = "Chart"
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart.bind(_view_model, _tr)
	add_child(_chart)
	add_child(_build_strip())


func _build_strip() -> Control:
	var panel := PanelContainer.new()
	panel.name = "VoyageStrip"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	_route_label = _label(
		"%s → %s" % [_port_name(_origin), _port_name(_destination)],
		15,
		COLOR_TEXT
	)
	_route_label.name = "RouteLabel"
	_route_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_route_label)
	_speed_label = _label("", 12, COLOR_TEAL)
	_speed_label.name = "SpeedLabel"
	top.add_child(_speed_label)
	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = _tr_or("ui.button.skip_presentation", "跳过演出")
	_skip_button.theme_type_variation = &"SNGhostButton"
	_skip_button.pressed.connect(func() -> void: skip_requested.emit())
	top.add_child(_skip_button)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 10)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_progress_bar)

	_clock_label = _label("", 12, COLOR_MUTED)
	_clock_label.name = "ClockLabel"
	box.add_child(_clock_label)
	return panel


## The voyage is animated along the chart's stored route so the icon follows the
## same curve the player sees drawn; a straight origin→destination line is the
## fallback when this pair has no stored route (twin-world MST edges, or a
## destination the chart has not discovered yet — Shell passes its world position).
func _route_path() -> PackedVector2Array:
	var routes: Array = _view_model.get("routes", [])
	for route in routes:
		if not (route is Dictionary):
			continue
		var from_id := String((route as Dictionary).get("from", ""))
		var to_id := String((route as Dictionary).get("to", ""))
		var matches := (from_id == _origin and to_id == _destination) \
			or (from_id == _destination and to_id == _origin)
		if not matches:
			continue
		var packed := VoyagePresentation.unpack_path(
			(route as Dictionary).get("bezier_path", []) as Array
		)
		if packed.size() >= 2:
			# Routes are stored in one direction; walk them from the origin.
			if from_id == _origin:
				return packed
			var reversed := PackedVector2Array()
			for index in range(packed.size() - 1, -1, -1):
				reversed.append(packed[index])
			return reversed
	var from_pos := _port_position(_origin)
	var to_pos := _port_position(_destination)
	if from_pos.is_equal_approx(to_pos):
		return PackedVector2Array()
	return PackedVector2Array([from_pos, to_pos])


## Port position from the chart when it is discovered, else from the explicit
## positions Shell injected (the destination is often still undiscovered).
func _port_position(port_id: String) -> Vector2:
	for entry in _view_model.get("ports", []):
		if String((entry as Dictionary).get("id", "")) == port_id:
			return Vector2(float((entry as Dictionary).get("x", 0.0)), float((entry as Dictionary).get("y", 0.0)))
	var explicit: Variant = _positions.get(port_id, null)
	if explicit is Dictionary:
		return Vector2(float((explicit as Dictionary).get("x", 0.0)), float((explicit as Dictionary).get("y", 0.0)))
	return Vector2.ZERO


func _position_at(progress: float) -> Vector2:
	if _path.is_empty():
		return _port_position(_origin)
	return VoyagePresentation.sample_polyline(_path, progress)


func _port_name(port_id: String) -> String:
	for entry in _view_model.get("ports", []):
		if String((entry as Dictionary).get("id", "")) == port_id:
			var key := String((entry as Dictionary).get("name_key", ""))
			return _tr_or(key, port_id)
	return port_id


func _format_hours(hours: float) -> String:
	var total := maxi(0, int(roundf(hours)))
	var days := total / 24
	var remainder := total % 24
	if days > 0 and remainder > 0:
		return "%d %s %d %s" % [days, _tr_or("unit.days", "天"), remainder, _tr_or("unit.hours", "小时")]
	if days > 0:
		return "%d %s" % [days, _tr_or("unit.days", "天")]
	return "%d %s" % [remainder, _tr_or("unit.hours", "小时")]


func _format_rate(rate: float) -> String:
	if rate <= 0.0:
		return "0"
	if is_equal_approx(rate, roundf(rate)):
		return str(int(roundf(rate)))
	return "%.1f" % rate


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Localized text with a caller-supplied fallback, so a missing key never renders
## as a raw `ui.label.*` in the middle of the voyage animation.
func _tr_or(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	if text.is_empty() or text == key:
		return fallback
	return text
