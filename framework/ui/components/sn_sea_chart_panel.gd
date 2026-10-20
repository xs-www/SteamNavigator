class_name SNSeaChartPanel
extends PanelContainer
## @static-doc
## 作用：海图右侧信息面板。选中港口后展示港口名、原型、区域、设施列表，以及
## **航程预估**（距离 / 预计时间 / 煤水消耗 / 风险 / 是否已探索），并提供「启航」按钮。
##
## - 关键依赖：`sea_chart.view` 中的 port/route 字典与本地化回调。
##
## ## 契约与约束
## - `bind(port_data, route_data, translate)` 注入数据；`clear()` 回到「点击港口」提示。
## - 面板不自行计算距离/时间/风险/消耗；所有数值由查询层（`VoyageEstimator`）给出。
## - 风险分档直接复用 `VoyageCalculator.risk_label`（low/medium/high），文案与颜色走本地化；
##   查询给的 `risk_label` 优先，避免海图与出航预览对同一个分数给出不同档位。
## - `risk_level < 0` 表示该航线没有可用的基础风险（坐标世界缺抽象地图对应边），
##   显示「无法评估」而不是「无风险」。
## - 煤水块只在查询给出 `supplies` 时出现；`sufficient=false` 用警示色并提示，
##   但不在这里拦截出航（阻断仍由出航页的 `voyage.preview` 决定）。
## - 点击「启航」发出 `voyage_requested(port_id)`，由 Shell 路由到 `voyage.start`。
## @end-static-doc

signal voyage_requested(port_id: String)

var _port_id: String = ""
var _port_data: Dictionary = {}
var _route_data: Dictionary = {}
var _translate: Callable


func _ready() -> void:
	custom_minimum_size = Vector2(320, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.12, 0.14, 0.92)
	style.border_color = Color(0.35, 0.55, 0.52, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)


func bind(port_data: Dictionary, route_data: Dictionary, translate: Callable = Callable()) -> void:
	_port_data = port_data
	_route_data = route_data
	_port_id = String(port_data.get("id", ""))
	_translate = translate
	_rebuild()


func clear() -> void:
	_port_id = ""
	_port_data = {}
	_route_data = {}
	_rebuild()


func _rebuild() -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	if _port_data.is_empty():
		_build_empty_state()
		return
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	
	# Header: Port name
	var name_key := String(_port_data.get("name_key", ""))
	var port_name := _tr(name_key) if name_key != "" else String(_port_data.get("id", ""))
	var header := Label.new()
	header.text = port_name
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color("e1c487"))
	vbox.add_child(header)
	
	# Archetype and region: prefer the content name keys the query resolved, so a
	# raw content id never reaches the label.
	var archetype_key := String(_port_data.get("archetype_name_key", ""))
	var archetype_id := String(_port_data.get("archetype", ""))
	var region_key := String(_port_data.get("region_name_key", ""))
	var region_id := String(_port_data.get("region_id", ""))
	if archetype_key != "" or archetype_id != "" or region_key != "" or region_id != "":
		var detail := Label.new()
		var parts: Array[String] = []
		if archetype_key != "":
			parts.append(_tr(archetype_key))
		elif archetype_id != "":
			parts.append(_archetype_label(archetype_id))
		if region_key != "":
			parts.append(_tr(region_key))
		elif region_id != "":
			parts.append(region_id)
		detail.text = " · ".join(parts)
		detail.add_theme_font_size_override("font_size", 11)
		detail.add_theme_color_override("font_color", Color(0.6, 0.7, 0.7, 0.75))
		vbox.add_child(detail)
	
	# Separator
	var sep1 := HSeparator.new()
	sep1.add_theme_constant_override("separation", 8)
	vbox.add_child(sep1)
	
	# Facilities
	var facilities: Array = _port_data.get("facilities", [])
	if not facilities.is_empty():
		var fac_label := Label.new()
		fac_label.text = _tr("ui.label.facilities") + ":"
		fac_label.add_theme_font_size_override("font_size", 12)
		fac_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.78, 0.9))
		vbox.add_child(fac_label)
		
		var fac_list := Label.new()
		var fac_names: Array[String] = []
		for fac in facilities:
			# Framework localization owns `ui.facility.*`; the bare facility id is only
			# a last-resort fallback when a mod ships an unknown facility.
			var facility_key := "ui.facility." + String(fac)
			var facility_label := _tr(facility_key)
			fac_names.append(String(fac) if facility_label == facility_key else facility_label)
		fac_list.text = "  " + "、".join(fac_names)
		fac_list.add_theme_font_size_override("font_size", 11)
		fac_list.add_theme_color_override("font_color", Color(0.65, 0.75, 0.73, 0.8))
		fac_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(fac_list)
	
	# Route information
	if not _route_data.is_empty():
		var sep2 := HSeparator.new()
		sep2.add_theme_constant_override("separation", 8)
		vbox.add_child(sep2)
		
		var route_header := Label.new()
		route_header.text = _tr("ui.label.voyage_info")
		route_header.add_theme_font_size_override("font_size", 14)
		route_header.add_theme_color_override("font_color", Color("7fc8e8"))
		vbox.add_child(route_header)
		
		# Distance
		var distance: float = float(_route_data.get("distance", 0.0))
		if distance > 0.0:
			var dist_label := Label.new()
			dist_label.text = _tr("ui.label.distance") + ": " + str(int(roundf(distance))) + " " + _tr("unit.nautical_miles")
			dist_label.add_theme_font_size_override("font_size", 12)
			vbox.add_child(dist_label)
		
		# Estimated travel time (if available)
		var travel_hours: float = float(_route_data.get("travel_hours", 0.0))
		if travel_hours > 0.0:
			var time_label := Label.new()
			time_label.text = _tr("ui.label.estimated_time") + ": " + _format_duration(travel_hours)
			time_label.add_theme_font_size_override("font_size", 12)
			vbox.add_child(time_label)

		# Fuel / water the voyage will burn (query-supplied; absent for worlds
		# with no ship context, e.g. a legacy save without a run).
		var supplies: Variant = _route_data.get("supplies", null)
		if supplies is Dictionary and not (supplies as Dictionary).is_empty():
			vbox.add_child(_supply_block(supplies as Dictionary))

		# Risk level (if available). A negative value means "no base risk for this
		# pair", which must not be rendered as zero risk. The query also ships the
		# band name from `VoyageCalculator.risk_label`, so the chart and the voyage
		# page cannot disagree about which band a score falls into; the numeric
		# thresholds here are only a fallback for callers that pass a bare score.
		var risk_level: float = float(_route_data.get("risk_level", -1.0))
		var risk_band := String(_route_data.get("risk_label", ""))
		var risk_label := Label.new()
		risk_label.add_theme_font_size_override("font_size", 12)
		if risk_level < 0.0 or risk_band == "unknown":
			risk_label.text = _tr("ui.label.risk") + ": " + _tr("ui.label.risk_unknown")
			risk_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.66, 0.85))
		else:
			var band_text := _tr("risk." + risk_band) if not risk_band.is_empty() else _risk_level_text(risk_level)
			risk_label.text = _tr("ui.label.risk") + ": " + band_text
			risk_label.add_theme_color_override(
				"font_color",
				_risk_band_color(risk_band) if not risk_band.is_empty() else _risk_color(risk_level)
			)
		vbox.add_child(risk_label)
		
		# Explored status
		var explored := bool(_route_data.get("explored", false))
		var status_label := Label.new()
		if explored:
			status_label.text = "✓ " + _tr("ui.label.route_explored")
			status_label.add_theme_color_override("font_color", Color("8fd694"))
		else:
			status_label.text = "? " + _tr("ui.label.route_unexplored")
			status_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5, 0.8))
		status_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(status_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Voyage button (only if route exists)
	if not _route_data.is_empty():
		var voyage_btn := Button.new()
		voyage_btn.text = _tr("ui.button.start_voyage")
		voyage_btn.add_theme_stylebox_override("normal", _button_style(Color(0.25, 0.45, 0.42)))
		voyage_btn.add_theme_stylebox_override("hover", _button_style(Color(0.30, 0.52, 0.48)))
		voyage_btn.add_theme_stylebox_override("pressed", _button_style(Color(0.20, 0.38, 0.35)))
		voyage_btn.pressed.connect(_on_voyage_pressed)
		vbox.add_child(voyage_btn)


## Coal / water the voyage burns, with the on-board stock so the player can tell
## whether the trip is affordable before opening the voyage page. Colours follow
## the same convention as the supply page: sufficient = normal, short = warning.
func _supply_block(supplies: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var header := Label.new()
	header.text = _tr("ui.label.voyage_supplies")
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.78, 0.9))
	box.add_child(header)
	var sufficient := bool(supplies.get("sufficient", true))
	for entry in [
		{"key": "ui.label.coal", "required": "coal_required", "available": "coal_available"},
		{"key": "ui.label.water", "required": "water_required", "available": "water_available"},
	]:
		var required := float(supplies.get(String(entry["required"]), 0.0))
		var available := float(supplies.get(String(entry["available"]), 0.0))
		var row := Label.new()
		row.text = "  %s %s / %s" % [
			_tr(String(entry["key"])),
			_format_amount(required),
			_format_amount(available),
		]
		row.add_theme_font_size_override("font_size", 11)
		var short := available + 0.0001 < required
		row.add_theme_color_override(
			"font_color",
			Color("e8967f") if short else Color(0.65, 0.75, 0.73, 0.85)
		)
		box.add_child(row)
	if not sufficient:
		var warning := Label.new()
		warning.text = _tr("ui.hint.supplies_short")
		warning.add_theme_font_size_override("font_size", 11)
		warning.add_theme_color_override("font_color", Color("e8967f"))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(warning)
	return box


## `36` / `36.5` — one decimal only when it adds information, so a panel row
## does not jitter between integer and fractional values.
func _format_amount(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


## Hours as "2 天 5 小时" / "7 小时"; the smallest unit is hours, matching the
## clock resolution used by `voyage.preview`.
func _format_duration(hours: float) -> String:
	var total := maxi(0, int(roundf(hours)))
	var days := total / 24
	var remainder := total % 24
	if days > 0 and remainder > 0:
		return "%d %s %d %s" % [days, _tr("unit.days"), remainder, _tr("unit.hours")]
	if days > 0:
		return "%d %s" % [days, _tr("unit.days")]
	return "%d %s" % [remainder, _tr("unit.hours")]


func _build_empty_state() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	
	var hint := Label.new()
	hint.text = _tr("ui.hint.select_destination")
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.7, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hint)


func _on_voyage_pressed() -> void:
	if not _port_id.is_empty():
		voyage_requested.emit(_port_id)


func _tr(key: String) -> String:
	if key.is_empty():
		return key
	if _translate.is_valid():
		return _translate.call(key)
	# Fallback: return key with common prefixes stripped for readability
	if key.begins_with("ui."):
		return key.substr(3).replace("_", " ").capitalize()
	return key


func _archetype_label(archetype: String) -> String:
	match archetype:
		"iron_port":
			return _tr("archetype.iron_port")
		"spice_port":
			return _tr("archetype.spice_port")
		"free_town":
			return _tr("archetype.free_town")
		"fishing_village":
			return _tr("archetype.fishing_village")
		"glass_port":
			return _tr("archetype.glass_port")
		_:
			return archetype.replace("_", " ").capitalize()


## Fallback banding for a bare 0–1 score. `VoyageCalculator` owns the real bands
## (`RISK_LABEL_LOW` / `RISK_LABEL_HIGH`) and the query ships the resolved name in
## `risk_label`; when it is present `_risk_band_color` is used instead.
func _risk_level_text(risk: float) -> String:
	return _tr("risk." + VoyageCalculator.risk_label(risk))


func _risk_band_color(band: String) -> Color:
	match band:
		"low":
			return Color("8fd694")  # Green
		"medium":
			return Color("e1c487")  # Yellow
		"high":
			return Color("e87f7f")  # Red
		_:
			return Color(0.62, 0.68, 0.66, 0.85)  # Unknown risk: neutral grey


func _risk_color(risk: float) -> Color:
	return _risk_band_color(VoyageCalculator.risk_label(risk))


func _button_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	return style
