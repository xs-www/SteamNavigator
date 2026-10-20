class_name SNSeaChartPanel
extends PanelContainer
## @static-doc
## 作用：海图右侧信息面板。选中港口后展示港口名、原型、区域、设施列表与
## 航线信息（距离/预计时间/风险/是否已探索），并提供「启航」按钮。
##
## - 关键依赖：`sea_chart.view` 中的 port/route 字典与本地化回调。
##
## ## 契约与约束
## - `bind(port_data, route_data, translate)` 注入数据；`clear()` 回到「点击港口」提示。
## - 面板不自行计算距离/时间/风险；所有数值由外部传入。
## - 风险等级按阈值分四档（low/medium/high/extreme），文案与颜色均走本地化。
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
			var days := int(travel_hours / 24.0)
			var hours := int(fmod(travel_hours, 24.0))
			var time_text := ""
			if days > 0:
				time_text = str(days) + " " + _tr("unit.days") + " " + str(hours) + " " + _tr("unit.hours")
			else:
				time_text = str(hours) + " " + _tr("unit.hours")
			time_label.text = _tr("ui.label.estimated_time") + ": " + time_text
			time_label.add_theme_font_size_override("font_size", 12)
			vbox.add_child(time_label)
		
		# Risk level (if available)
		var risk_level: float = float(_route_data.get("risk_level", 0.0))
		if risk_level > 0.0:
			var risk_label := Label.new()
			var risk_text := _risk_level_text(risk_level)
			risk_label.text = _tr("ui.label.risk") + ": " + risk_text
			risk_label.add_theme_font_size_override("font_size", 12)
			risk_label.add_theme_color_override("font_color", _risk_color(risk_level))
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


func _risk_level_text(risk: float) -> String:
	if risk < 0.3:
		return _tr("risk.low")
	elif risk < 0.6:
		return _tr("risk.medium")
	elif risk < 0.85:
		return _tr("risk.high")
	else:
		return _tr("risk.extreme")


func _risk_color(risk: float) -> Color:
	if risk < 0.3:
		return Color("8fd694")  # Green
	elif risk < 0.6:
		return Color("e1c487")  # Yellow
	elif risk < 0.85:
		return Color("e8967f")  # Orange
	else:
		return Color("e87f7f")  # Red


func _button_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	return style
