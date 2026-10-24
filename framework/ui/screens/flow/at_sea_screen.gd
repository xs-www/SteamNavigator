class_name AtSeaScreen
extends VBoxContainer
## @static-doc
## 作用：航行演出页（海图系统阶段 3）：整幅海图 + 底部航程条。船只 icon 沿
## **世界航线表里的真实航线**（Shell 通过 `route_path` 传入）按弧长行进，航程条
## 显示进度、预计抵达时间、时间倍率，并提供「跳过演出」。
##
## ## 契约与约束
## - 本页不查询、不执行命令、不推进时间：Shell 把 `sea_chart.view` 结果、
##   完整航线路点（`route_path`）和 `VoyagePresentation.snapshot()` 推进来
##   （`bind()` / `set_presentation()`）。
## - **航线数据源**：优先用 `route_path`（来自 `WorldMap.edges` 的完整世界航线表，
##   与战争迷雾无关——迷雾只决定"画不画在图上"，不决定演出数据）。它缺失时
##   才退回海图查询的已发现航线，最后才退回「起点→终点直线」。
## - 船只坐标只通过 `SNSeaChartView.set_ship_pose()` 覆盖（位置 + 航线切线艏向），
##   不重新绑定整个视图模型（每帧重绑会把迷雾纹理与取景一起重建）。艏向取航线
##   切线，船 icon 因此始终朝着实际移动方向。
## - 航行页的海图是演出取景（`set_presentation_mode`）：铺满可用窗口，并由
##   `snapshot()["chart_zoom_scale"]` 驱动「云层散开时由近拉远 / 入港前推近」。
## - **探索演出**（探索系统 4.1）：`bind()` 收到 `unknown_destination: {x, y, label_key}`
##   时把未知终点交给海图（虚线预测线 + `?` 标记），航程条右侧目的地显示 `？`
##   （`label_key`，通常 `ui.label.unknown_destination`），起点仍显示港口名。
## - **随船照亮**（4.3.3 / U4）：演出视野半径取 `sea_chart.view` 的
##   `fog_radii.vision`（与领域同源，由 Core 比例推导），`bind()` 重建海图后与每次
##   `set_presentation()` 都推给 `SNSeaChartView.set_ship_vision()`。纯表现：本页
##   不查询后端、不写领域状态。
## - `skip_requested` 只表达意图；跳过后事件仍由 Shell 推给玩家。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 外观全部来自 `assets/ui/skin/sn_v1/`：底部航程条用 `SNPanel` 纹理承托，
##   进度条用 `SNBrassProgressBar`，跳过按钮用 `SNGhostButton`；文字颜色一律取
##   `SNSkin.color(...)`（`text.light` / `text.muted` / `state.water`），
##   本页不再保留颜色常量或内联手写色值。
## - 海图绘制归 `SNSeaChartView`（不在本页写域）；本页只驱动进度与取景。
## - 节点名 `VoyageStrip` / `RouteLabel` / `SpeedLabel` / `ClockLabel` /
##   `ProgressBar` / `SkipButton`、航程条布局与全屏海图 + 底部条结构不变，
##   测试（test_voyage_flow / test_ui_shell）按名字与文本断言。
## @end-static-doc

signal skip_requested

## 求航线切线时前后各取的弧长比例。足够小才能贴合弯道，足够大才不会被折线
## 顶点的数值抖动影响（14 节的航线是离散折线，间距不均匀）。
const HEADING_SAMPLE := 0.004

var _tr: Callable
var _view_model: Dictionary = {}
var _voyage: Dictionary = {}
var _positions: Dictionary = {}
var _route_path: PackedVector2Array = PackedVector2Array()
var _origin: String = ""
var _destination: String = ""
## Shell 解析好的本地化港口名（图表视图被迷雾过滤时 id 无法反查名称）。
var _origin_name: String = ""
var _destination_name: String = ""
## 探索演出的未知目的地（`{x, y, label_key}`）；空字典 = 普通航行。
var _unknown_destination: Dictionary = {}
var _path: PackedVector2Array = PackedVector2Array()
var _progress: float = 0.0
## 上一次算出的船艏向（世界弧度）。路径退化或相邻采样重合时沿用它，避免 icon 抖。
var _last_heading: float = 0.0
## 演出随船照亮半径（世界单位）。来自海图视图模型的 `fog_radii.vision`，
## 只影响画在船周的多层软圆，不写领域状态。
var _ship_vision_radius: float = 0.0
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
	_origin_name = String(vm.get("origin_name", ""))
	_destination_name = String(vm.get("destination_name", ""))
	var unknown: Variant = vm.get("unknown_destination", null)
	_unknown_destination = unknown if unknown is Dictionary else {}
	_route_path = unpack_route_path(vm.get("route_path", null))
	_ship_vision_radius = _model_ship_vision_radius()
	_path = _resolve_path()
	_rebuild()
	# 探索演出：把未知终点画到海图上（虚线预测线 + `?`）。必须在 `_rebuild()` 之后，
	# 因为重建会创建新的 `_chart` 实例。
	_apply_unknown_destination()
	if vm.get("presentation", null) is Dictionary:
		set_presentation(vm["presentation"])


## 每帧由 Shell 推进：更新航程条、船只位置与海图取景倍数。
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
	_chart.set_ship_pose(_position_at(_progress), _heading_at(_progress))
	_chart.set_ship_vision(_ship_vision_radius)
	_chart.set_frame_scale(float(snapshot.get("chart_zoom_scale", 1.0)))


func get_chart() -> SNSeaChartView:
	return _chart


## 本页实际用来行进的折线：完整世界航线优先，退化路径兜底（测试直接读它来
## 证明"船沿航线而不是两点直线"）。
func get_route_path() -> PackedVector2Array:
	return _path


## Shell 传入的完整航线路点（`WorldMap.edges` 的航线，不受迷雾过滤）。
func get_world_route_path() -> PackedVector2Array:
	return _route_path


## 探索演出的未知目的地（`{x, y, label_key}`）；普通航行为空字典。
func get_unknown_destination() -> Dictionary:
	return _unknown_destination.duplicate()


## 航程进度（0..1），测试与 Shell 都读这个，而不是去猜 ProgressBar 的数值。
func get_progress() -> float:
	return _progress


## 当前船只世界坐标；没有路径时退回起点。
func get_ship_world_position() -> Vector2:
	return _position_at(_progress)


## 当前船艏向（世界弧度，0 = +X）。航行页把它喂给海图，船 icon 才会朝着实际
## 移动方向——航线转弯时 icon 跟着转，而不是固定指向屏幕上方。
func get_ship_heading() -> float:
	return _heading_at(_progress)


## 演出随船照亮半径（世界单位）；0 表示这局没有可用的迷雾半径数据。
func get_ship_vision_radius() -> float:
	return _ship_vision_radius


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
	# 航行页的海图是"铺满窗口的海"，不是港口里那张带边距的图表（验收反馈 F3）。
	_chart.set_presentation_mode(true, _path)
	# 重建会换掉海图实例，随船照亮要重新推给它（剧本每帧还会再推一次）。
	_chart.set_ship_vision(_ship_vision_radius)
	_apply_unknown_destination()
	add_child(_chart)
	add_child(_build_strip())


## 演出照亮半径（世界单位）：只读 `sea_chart.view` 的 `fog_radii.vision`（与领域
## 同源、已按内容比例推导），页面不查询后端、也不写任何状态。
func _model_ship_vision_radius() -> float:
	var radii: Variant = _view_model.get("fog_radii", null)
	if not (radii is Dictionary):
		return 0.0
	return maxf(0.0, float((radii as Dictionary).get("vision", 0.0)))


## 把未知终点交给海图：探索演出画虚线预测线 + `?`，普通航行清掉。
## `top_inset` 由 Shell 传入（顶部固定 chrome 高度），`?` 被顶栏/状态条挡住时
## 海图会把标记 clamp 到可见区，玩家不会看不到探索目标。
func _apply_unknown_destination() -> void:
	if _chart == null:
		return
	if _unknown_destination.is_empty():
		_chart.clear_unknown_destination()
		return
	var target := Vector2(
		float(_unknown_destination.get("x", 0.0)),
		float(_unknown_destination.get("y", 0.0))
	)
	_chart.set_unknown_destination(
		target,
		String(_unknown_destination.get("label_key", "")),
		float(_unknown_destination.get("top_inset", 0.0))
	)


func _build_strip() -> Control:
	var panel := PanelContainer.new()
	panel.name = "VoyageStrip"
	panel.theme_type_variation = &"SNPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	_route_label = _label(
		"%s → %s" % [_port_name(_origin), _destination_label()],
		15,
		SNSkin.color("text.light")
	)
	_route_label.name = "RouteLabel"
	_route_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_route_label)
	_speed_label = _label("", 12, SNSkin.color("state.water"))
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
	_progress_bar.theme_type_variation = &"SNBrassProgressBar"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 10)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_progress_bar)

	_clock_label = _label("", 12, SNSkin.color("text.muted"))
	_clock_label.name = "ClockLabel"
	box.add_child(_clock_label)
	return panel


## 还原 Shell 传来的航线路点。接受 `PackedVector2Array`（测试/内部）或海图同款
## 扁平数组 `[x0,y0,x1,y1,…]`（`WorldMap.edges` 的存储格式）。
static func unpack_route_path(raw: Variant) -> PackedVector2Array:
	if raw is PackedVector2Array:
		return raw
	if raw is Array:
		return VoyagePresentation.unpack_path(raw as Array)
	return PackedVector2Array()


## The voyage is animated along the world's stored route so the icon follows the
## same curve the chart draws; the chart query's discovered routes are only a
## fallback, and a straight origin→destination line is the last resort.
##
## 航线「发现没发现」是玩家视角的规则：迷雾只影响画不画、面板显不显示，
## 不允许影响演出取景（验收反馈 F4）。
func _resolve_path() -> PackedVector2Array:
	if _route_path.size() >= 2:
		# Routes are stored in one direction; walk them from the origin.
		if _route_path[0].distance_to(_port_position(_origin)) \
				> _route_path[_route_path.size() - 1].distance_to(_port_position(_origin)):
			var reversed := PackedVector2Array()
			for index in range(_route_path.size() - 1, -1, -1):
				reversed.append(_route_path[index])
			return reversed
		return _route_path
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
			if from_id == _origin:
				return packed
			var reversed := PackedVector2Array()
			for index in range(packed.size() - 1, -1, -1):
				reversed.append(packed[index])
			return reversed
	var from_pos := _port_position(_origin)
	var to_pos := _destination_position()
	if from_pos.is_equal_approx(to_pos):
		return PackedVector2Array()
	return PackedVector2Array([from_pos, to_pos])


## 目的地在世界里的位置：普通航行取目的地港坐标；探索演出取未知终点（搜索区中心）。
func _destination_position() -> Vector2:
	if not _unknown_destination.is_empty():
		return Vector2(
			float(_unknown_destination.get("x", 0.0)),
			float(_unknown_destination.get("y", 0.0))
		)
	return _port_position(_destination)


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


## 航线在 `progress` 处的切线方向（世界弧度）。取前后各 `HEADING_SAMPLE` 弧长的
## 两点做差，起终两端也能得到朝向；采样重合（退化路径 / 原地）时沿用上一次值。
func _heading_at(progress: float) -> float:
	if _path.is_empty():
		return _last_heading
	var backward := _position_at(maxf(0.0, progress - HEADING_SAMPLE))
	var forward := _position_at(minf(1.0, progress + HEADING_SAMPLE))
	var delta := forward - backward
	if delta.length() < 0.0001:
		return _last_heading
	_last_heading = atan2(delta.y, delta.x)
	return _last_heading


func _port_name(port_id: String) -> String:
	if port_id == _origin and not _origin_name.is_empty():
		return _origin_name
	if port_id == _destination and not _destination_name.is_empty():
		return _destination_name
	for entry in _view_model.get("ports", []):
		if String((entry as Dictionary).get("id", "")) == port_id:
			var key := String((entry as Dictionary).get("name_key", ""))
			return _tr_or(key, port_id)
	return port_id


## 航程条右侧的目的地文案：普通航行 = 港口名；探索演出 = `？`
## （`unknown_destination.label_key`，通常 `ui.label.unknown_destination`）。
func _destination_label() -> String:
	if not _unknown_destination.is_empty():
		var label_key := String(_unknown_destination.get("label_key", ""))
		return _tr_or(
			"ui.label.unknown_destination" if label_key.is_empty() else label_key, "？"
		)
	var name := _port_name(_destination)
	return name if not name.is_empty() else _tr_or("ui.label.unknown_destination", "？")


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
