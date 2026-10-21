class_name SNSeaChartPanel
extends PanelContainer
## @static-doc
## 作用：海图右侧信息面板。选中港口后展示港口名、原型、区域、设施列表，以及
## **航程预估**（距离 / 预计时间 / 煤水消耗 / 风险 / 是否已探索），并提供「启航」按钮
## （阶段 4.3.4 / U7 起只打开 Shell 的出航确认弹窗，不再跳转出航准备页）。
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
##   但不在这里拦截出航（阻断仍由确认弹窗里的 `voyage.preview` / 线索预估决定）。
## - 点击「启航」发出 `departure_requested("voyage", port_id)`；线索区块的
##   「循此线索出航」发出 `departure_requested("explore", clue_id)`。两者都由
##   `SeaChartScreen` 转发，Shell 打开统一的出航确认弹窗（预估 + 锅炉策略切换 +
##   取消/启航）后才执行 `voyage.start` / `explore.start`（4.3.4 / U7）。
## - **线索区块**（探索系统 4.1）：`bind_clue(clue)` 时面板改成显示一条线索——标题、
##   来源（只给来源不给 credibility 数字）、等级、八方位、航程区间、预计航程/煤水/
##   风险/可行性（不可行时列出 blockers 的 message_key）。`can_buy_clue.available`
##   时多一个购买按钮，发出 `purchase_clue_requested`，由 Shell 执行 `clue.buy`
##   并刷新海图。
##   面板仍不计算任何数值：预计值全部来自查询层的 `clue["estimated"]`。
## - **逐级调查**（阶段 4.3.2 / U2）：线索区块显示「下一级：%s」预告（4 级显示已达最高），
##   并多一个「调查线索」按钮，发出 `investigate_requested(clue_id)`。
##   `can_investigate` 来自查询层（在港且 `level < 4`），面板只据它启用/禁用按钮。
## @end-static-doc

## 「启航」与「循此线索出航」共用的出航入口（4.3.4 / U7）：
## `kind` = `"voyage" | "explore"`，`target_id` = 目的港 id 或线索 id。
## 由 SeaChartScreen 转发，Shell 打开确认弹窗后才真正执行出航命令。
signal departure_requested(kind: String, target_id: String)
## 「购买线索」：由 SeaChartScreen 转发给 Shell 执行 `clue.buy`。
signal purchase_clue_requested
## 「调查线索」：由 SeaChartScreen 转发给 Shell 执行 `clue.investigate`（等级 +1）。
signal investigate_requested(clue_id: String)

## 八方位键（世界弧度 0 = 屏幕 +X 东；图表 +Y 朝下 = 南）。
const COMPASS_KEYS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
## 本地化键缺失时的中文回退（键由内容/框架本地化提供，回退只防缺键空白）。
const COMPASS_FALLBACK := {
	"E": "东", "SE": "东南", "S": "南", "SW": "西南",
	"W": "西", "NW": "西北", "N": "北", "NE": "东北",
}
const LEVEL_FALLBACK := {
	1: "模糊传闻", 2: "方位线索", 3: "距离线索", 4: "港口名称",
}
const SOURCE_FALLBACK := {"rumor": "传闻", "intel": "情报"}
## 线索等级上限（1 存在 → 2 方向 → 3 距离 → 4 名称）。查询层也按这个上限裁剪；
## 面板只在 fallback 时用它判断「下一级」与按钮是否可用。
const MAX_CLUE_LEVEL := 4

var _port_id: String = ""
var _port_data: Dictionary = {}
var _route_data: Dictionary = {}
var _clue: Dictionary = {}
var _can_buy: Dictionary = {}
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
	_clue = {}
	_translate = translate
	_rebuild()


## 绑定一条线索：面板切换成线索区块（港口信息同时清空，一次只展示一种对象）。
func bind_clue(clue: Dictionary, translate: Callable = Callable()) -> void:
	_clue = clue
	_port_data = {}
	_route_data = {}
	_port_id = ""
	if translate.is_valid():
		_translate = translate
	_rebuild()


## 当前展示的线索（空字典 = 正在展示港口/空态）。
func get_clue() -> Dictionary:
	return _clue


## 购买线索入口的数据（`sea_chart.view` 的 `can_buy_clue`）：`available` 为真时
## 面板底部出现「购买线索（%d 金）」按钮。可以在一开始 `bind_clue`/`bind` 之前设置。
func set_can_buy_clue(can_buy: Dictionary) -> void:
	_can_buy = can_buy.duplicate(true)


func clear() -> void:
	_port_id = ""
	_port_data = {}
	_route_data = {}
	_clue = {}
	_rebuild()


func _rebuild() -> void:
	# Clear existing children. `queue_free()` alone leaves the old controls in the
	# tree until the end of the frame, which makes repeated binds (clue → port →
	# clue) return stale buttons to callers/tests within the same frame.
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if not _clue.is_empty():
		_build_clue_state()
		return

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
		voyage_btn.name = "DepartButton"
		voyage_btn.text = _tr("ui.button.start_voyage")
		voyage_btn.add_theme_stylebox_override("normal", _button_style(Color(0.25, 0.45, 0.42)))
		voyage_btn.add_theme_stylebox_override("hover", _button_style(Color(0.30, 0.52, 0.48)))
		voyage_btn.add_theme_stylebox_override("pressed", _button_style(Color(0.20, 0.38, 0.35)))
		voyage_btn.pressed.connect(_on_voyage_pressed)
		vbox.add_child(voyage_btn)
	_append_purchase_button(vbox)


## 线索区块：来源/等级/方位/航程区间 + 查询层给出的预计值与可行性，底部出航按钮。
## 所有数值都是只读展示；面板不重算航程、不读 credibility（设计上不可见）。
func _build_clue_state() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var header := Label.new()
	header.text = _tr_or("ui.clue.section_title", "线索")
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color("e1c487"))
	vbox.add_child(header)

	var source_key := String(_clue.get("source_key", ""))
	var source_display_key := String(_clue.get("source_display_key", ""))
	if source_display_key.is_empty() and not source_key.is_empty():
		source_display_key = "ui.clue.source." + source_key
	var source_label := _tr_or(
		source_display_key, String(SOURCE_FALLBACK.get(source_key, source_key))
	)
	# 可靠度只以来源暗示，从不显示 credibility 数值（设计文档 §5）。
	var reliability := Label.new()
	reliability.text = _tr_or("ui.clue.reliability_hint", "来源：%s") % source_label
	reliability.add_theme_font_size_override("font_size", 12)
	reliability.add_theme_color_override("font_color", Color(0.62, 0.72, 0.69, 0.9))
	vbox.add_child(reliability)

	var level := int(_clue.get("level", 0))
	if level > 0:
		var level_label := Label.new()
		level_label.text = _tr_or(
			"ui.clue.level.%d" % level, String(LEVEL_FALLBACK.get(level, "线索"))
		)
		level_label.add_theme_font_size_override("font_size", 13)
		level_label.add_theme_color_override("font_color", Color("7fc8e8"))
		vbox.add_child(level_label)
		_append_next_level_row(vbox, level)

	# 4.3 / U3：失败不消耗线索，面板提示已经尝试过几次（0 次不显示）。
	var attempts := int(_clue.get("attempts", 0))
	if attempts > 0:
		var attempts_label := Label.new()
		attempts_label.text = _tr_or("ui.clue.attempts", "已尝试 %d 次") % attempts
		attempts_label.add_theme_font_size_override("font_size", 11)
		attempts_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.69, 0.9))
		vbox.add_child(attempts_label)

	if _clue.has("direction_angle"):
		var angle := float(_clue.get("direction_angle", 0.0))
		var compass := compass_key(angle)
		var direction := Label.new()
		direction.text = "%s: %s" % [
			_tr_or("ui.label.direction", "方向"),
			_tr_or("ui.clue.direction." + compass, String(COMPASS_FALLBACK.get(compass, compass))),
		]
		direction.add_theme_font_size_override("font_size", 12)
		vbox.add_child(direction)

	var distance_min := float(_clue.get("distance_min_hours", 0.0))
	var distance_max := float(_clue.get("distance_max_hours", 0.0))
	if distance_max > 0.0:
		var range_label := Label.new()
		var template := _tr_or("ui.clue.distance_range", "约 %d–%d 小时航程")
		range_label.text = template % [
			int(roundf(distance_min)), int(roundf(maxf(distance_min, distance_max)))
		]
		range_label.add_theme_font_size_override("font_size", 12)
		range_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.78, 0.9))
		vbox.add_child(range_label)

	var estimated: Variant = _clue.get("estimated", null)
	if estimated is Dictionary and not (estimated as Dictionary).is_empty():
		vbox.add_child(HSeparator.new())
		vbox.add_child(_clue_estimate_block(estimated as Dictionary))

	_append_investigate_button(vbox, level)

	var explore_button := Button.new()
	explore_button.name = "ExploreButton"
	explore_button.text = _tr_or("ui.button.explore_clue", "循此线索出航")
	explore_button.add_theme_stylebox_override("normal", _button_style(Color(0.25, 0.45, 0.42)))
	explore_button.add_theme_stylebox_override("hover", _button_style(Color(0.30, 0.52, 0.48)))
	explore_button.add_theme_stylebox_override("pressed", _button_style(Color(0.20, 0.38, 0.35)))
	# 不可行时按钮保留但禁用：让玩家看到"为什么不能去"（blockers）而不是按钮凭空消失。
	if estimated is Dictionary and (estimated as Dictionary).has("feasible"):
		explore_button.disabled = not bool((estimated as Dictionary).get("feasible", true))
	explore_button.pressed.connect(_on_explore_pressed)
	vbox.add_child(explore_button)
	_append_purchase_button(vbox)


## 线索预计值：航程 / 煤 / 水 / 风险 / 可行性；不可行时逐条列出 blockers 的文案键。
func _clue_estimate_block(estimated: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var header := Label.new()
	header.text = _tr("ui.label.voyage_info")
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color("7fc8e8"))
	box.add_child(header)

	var duration := float(estimated.get("duration_hours", 0.0))
	if duration > 0.0:
		box.add_child(_clue_row("%s: %s" % [
			_tr("ui.label.estimated_time"), _format_duration(duration)
		], Color(0.72, 0.82, 0.8, 0.92)))
	var coal := float(estimated.get("coal_required", 0.0))
	var water := float(estimated.get("water_required", 0.0))
	if coal > 0.0 or water > 0.0:
		box.add_child(_clue_row("%s %s / %s %s" % [
			_tr("ui.label.coal"), _format_amount(coal),
			_tr("ui.label.water"), _format_amount(water),
		], Color(0.65, 0.75, 0.73, 0.85)))
	if estimated.has("risk_score"):
		var risk := float(estimated.get("risk_score", 0.0))
		var band := VoyageCalculator.risk_label(risk)
		var risk_row := _clue_row("%s: %s" % [
			_tr("ui.label.risk"), _tr_or("risk." + band, band)
		], _risk_band_color(band))
		box.add_child(risk_row)

	var feasible := bool(estimated.get("feasible", true))
	var feasible_label := Label.new()
	feasible_label.text = _tr_or(
		"ui.clue.feasible" if feasible else "ui.clue.infeasible",
		"可出航" if feasible else "航道条件不满足"
	)
	feasible_label.add_theme_font_size_override("font_size", 12)
	feasible_label.add_theme_color_override(
		"font_color", Color("8fd694") if feasible else Color("e8967f")
	)
	box.add_child(feasible_label)

	var blockers: Array = estimated.get("blockers", [])
	for blocker in blockers:
		if not (blocker is Dictionary):
			continue
		var message_key := String((blocker as Dictionary).get("message_key", ""))
		if message_key.is_empty():
			continue
		var blocker_label := Label.new()
		blocker_label.text = "· " + _tr_or(message_key, String((blocker as Dictionary).get("code", "")))
		blocker_label.add_theme_font_size_override("font_size", 11)
		blocker_label.add_theme_color_override("font_color", Color("e8967f"))
		blocker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(blocker_label)
	return box


## 4.3.2 / U2：「下一级」预告——下一级会披露什么（方向 → 圆圈 → 名称）；4 级显示
## 已达最高。披露文案键由查询层给出（`next_level_key`），面板只负责本地化与排版。
func _append_next_level_row(vbox: VBoxContainer, level: int) -> void:
	if level <= 0:
		return
	var row := Label.new()
	row.add_theme_font_size_override("font_size", 11)
	if level >= MAX_CLUE_LEVEL:
		row.text = _tr_or("ui.clue.max_level", "已达最高等级")
		row.add_theme_color_override("font_color", Color("8fd694"))
		vbox.add_child(row)
		return
	var next_level := int(_clue.get("next_level", level + 1))
	if next_level <= 0 or next_level > MAX_CLUE_LEVEL:
		next_level = mini(level + 1, MAX_CLUE_LEVEL)
	var next_key := String(_clue.get("next_level_key", ""))
	if next_key.is_empty():
		next_key = "ui.clue.level.%d" % next_level
	var next_text := _tr_or(next_key, String(LEVEL_FALLBACK.get(next_level, "线索")))
	row.text = _tr_or("ui.clue.next_level", "下一级：%s") % next_text
	row.add_theme_color_override("font_color", Color(0.62, 0.72, 0.69, 0.9))
	vbox.add_child(row)


## 4.3.2 / U2：「调查线索」按钮。`can_investigate`（查询层：在港且 level<4）为假或
## 已达 4 级时禁用；点击只发信号，等级推进在 `clue.investigate` 命令里完成。
func _append_investigate_button(vbox: VBoxContainer, level: int) -> void:
	if level <= 0:
		return
	var button := Button.new()
	button.name = "InvestigateButton"
	button.text = _tr_or("ui.button.investigate_clue", "调查线索")
	button.add_theme_stylebox_override("normal", _button_style(Color(0.30, 0.26, 0.16)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.38, 0.32, 0.20)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.24, 0.20, 0.13)))
	var can_investigate := bool(
		_clue.get("can_investigate", level < MAX_CLUE_LEVEL)
	) and level < MAX_CLUE_LEVEL
	button.disabled = not can_investigate
	button.pressed.connect(_on_investigate_pressed)
	vbox.add_child(button)


func _on_investigate_pressed() -> void:
	var clue_id := String(_clue.get("id", ""))
	if not clue_id.is_empty():
		investigate_requested.emit(clue_id)


func _clue_row(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


## 查询层报告的 `can_buy_clue.available` 为真时，面板底部追加购买入口。
func _append_purchase_button(vbox: VBoxContainer) -> void:
	if not bool(_can_buy.get("available", false)):
		return
	var cost := int(_can_buy.get("cost", 0))
	var button := Button.new()
	button.name = "PurchaseClueButton"
	button.text = _tr_or("ui.button.buy_clue", "购买线索（%d 金）") % cost
	button.theme_type_variation = &"SNGhostButton"
	button.add_theme_stylebox_override("normal", _button_style(Color(0.30, 0.26, 0.16)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.38, 0.32, 0.20)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.24, 0.20, 0.13)))
	button.pressed.connect(func() -> void: purchase_clue_requested.emit())
	vbox.add_child(button)


## 把线索的 `direction_angle` 映射成 8 方位键。纯函数：测试不用渲染就能断言方位。
static func compass_key(angle: float) -> String:
	var index := int(roundf(angle / (PI / 4.0)))
	index = ((index % 8) + 8) % 8
	return COMPASS_KEYS[index]


func _on_explore_pressed() -> void:
	var clue_id := String(_clue.get("id", ""))
	if not clue_id.is_empty():
		departure_requested.emit("explore", clue_id)


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
	_append_purchase_button(vbox)


func _on_voyage_pressed() -> void:
	if not _port_id.is_empty():
		departure_requested.emit("voyage", _port_id)


func _tr(key: String) -> String:
	if key.is_empty():
		return key
	if _translate.is_valid():
		return _translate.call(key)
	# Fallback: return key with common prefixes stripped for readability
	if key.begins_with("ui."):
		return key.substr(3).replace("_", " ").capitalize()
	return key


## 与 `_tr` 相同，但缺键时用调用方给的中文回退（探索系统新键先按契约编码，
## 本地化由领域侧补齐；缺键时不能让玩家看到 `ui.clue.*` 原始键名）。
func _tr_or(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	if _translate.is_valid():
		var text := String(_translate.call(key))
		if not text.is_empty() and text != key:
			return text
	return fallback


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
