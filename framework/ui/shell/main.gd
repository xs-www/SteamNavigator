extends Control
## Playable shell for the framework slice.
##
## The UI only reads ViewModels through QueryBus and mutates through
## CommandBus. Each major function has its own screen; the shell owns
## navigation, the header, and transient selection state only.

const COLOR_BG := Color("0b1116")
const COLOR_PANEL := Color("16212a")
const COLOR_PANEL_ALT := Color("1d2a34")
const COLOR_TEXT := Color("d7e3ea")
const COLOR_MUTED := Color("8b9aa5")
const COLOR_BRASS := Color("f0c674")
const COLOR_TEAL := Color("7fc8e8")
const COLOR_RED := Color("e8837f")
const COLOR_GREEN := Color("8fd694")

const SCREENS := ["overview", "market", "contracts", "shipyard", "supply", "intel", "voyage"]
const MODULE_TYPE_ORDER := [
	ContentTypes.HULL,
	ContentTypes.BOILER,
	ContentTypes.CARGO_MODULE,
	ContentTypes.NAVIGATION_MODULE,
	ContentTypes.SAFETY_MODULE,
	ContentTypes.CABIN,
]
const MODULE_TYPE_LABELS := {
	ContentTypes.HULL: "船体",
	ContentTypes.BOILER: "锅炉",
	ContentTypes.CARGO_MODULE: "货舱",
	ContentTypes.NAVIGATION_MODULE: "导航",
	ContentTypes.SAFETY_MODULE: "安全",
	ContentTypes.CABIN: "客舱",
}

var _context: AppContext = null
var _root_box: VBoxContainer = null
var _last_port_view: Dictionary = {}

var _active_screen: String = "overview"
var _memory_port_id: String = ""
var _selected_build: String = ""
var _selected_destination: String = ""
var _selected_strategy: String = ""
var _seed_text: String = ""
var _status_message: String = ""
var _status_is_error: bool = false


func _ready() -> void:
	theme = _build_theme()
	_build_shell()
	_refresh()


func _build_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC",
		"Source Han Sans SC", "SimHei", "Arial", "sans-serif",
	])
	var result := Theme.new()
	result.default_font = font
	result.default_font_size = 15
	result.set_color("font_color", "Label", COLOR_TEXT)
	result.set_color("font_color", "Button", COLOR_TEXT)
	result.set_color("font_color", "RichTextLabel", COLOR_TEXT)
	result.set_color("font_color", "OptionButton", COLOR_TEXT)
	result.set_color("font_color", "LineEdit", COLOR_TEXT)
	result.set_color("font_hover_color", "Button", COLOR_BRASS)
	result.set_stylebox("panel", "PanelContainer", _style(COLOR_PANEL, 10))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var color := COLOR_PANEL_ALT
		if state == "hover":
			color = Color("2a3945")
		elif state == "pressed":
			color = Color("0f1a22")
		elif state == "disabled":
			color = Color("121b22")
		result.set_stylebox(state, "Button", _style(color, 6))
	result.set_color("font_disabled_color", "Button", Color("5a6a75"))
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 10)
	result.set_constant("h_separation", "GridContainer", 12)
	return result


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_root_box = VBoxContainer.new()
	_root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_root_box)


func _refresh() -> void:
	_context = _resolve_context()
	for child in _root_box.get_children():
		_root_box.remove_child(child)
		child.queue_free()
	if _context == null:
		_root_box.add_child(_label("Loading framework...", 20, COLOR_MUTED))
		get_tree().create_timer(0.4).timeout.connect(_refresh)
		return
	var app_view := _context.queries.execute(&"app.view")
	if not bool(app_view.get("ok", false)):
		_root_box.add_child(_label(_error_text(app_view), 18, COLOR_RED))
		return
	var app: Dictionary = app_view["data"]
	_build_header(app)
	if not bool(app.get("has_run", false)):
		_build_menu(app)
		return

	var port_result := _context.queries.execute(&"port.view")
	if not bool(port_result.get("ok", false)):
		_root_box.add_child(_label(_error_text(port_result), 18, COLOR_RED))
		return
	var data: Dictionary = port_result["data"]
	_last_port_view = data
	_build_stats_bar(data)

	if bool(data.get("at_sea", false)):
		_build_status_banner()
		var voyage: Variant = data.get("voyage", null)
		if voyage is Dictionary and voyage.get("event", null) is Dictionary:
			_screen_event(data, voyage["event"])
		else:
			_screen_at_sea(data, voyage)
		return

	_build_nav(data)
	_build_status_banner()
	if not SCREENS.has(_active_screen) and _active_screen != "port_memory":
		_active_screen = "overview"
	match _active_screen:
		"market":
			_screen_market(data)
		"contracts":
			_screen_contracts(data)
		"shipyard":
			_screen_shipyard(data)
		"supply":
			_screen_supply(data)
		"intel":
			_screen_intel(data)
		"voyage":
			_screen_voyage(data)
		"port_memory":
			_screen_port_memory(data)
		_:
			_screen_overview(data)


## ---------------------------------------------------------------------------
## Header, navigation, menu
## ---------------------------------------------------------------------------

func _build_header(app: Dictionary) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(header)
	var title := _label(_tr("ui.app.title", "Steam Navigator"), 24, COLOR_BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label(_tr(String(app.get("status_key", "ui.status.ok")), ""), 14, _status_color(app)))
	header.add_child(_label("v%s" % app.get("framework_version", "?"), 13, COLOR_MUTED))
	header.add_child(_button(_tr("ui.button.log", "Diagnostics"), _show_diagnostics))
	if bool(app.get("has_run", false)):
		header.add_child(_button(_tr("ui.button.refresh", "Refresh"), _refresh))
	_root_box.add_child(HSeparator.new())


func _status_color(app: Dictionary) -> Color:
	match String(app.get("status", "fatal")):
		"ok":
			return COLOR_GREEN
		"degraded":
			return COLOR_BRASS
		_:
			return COLOR_RED


func _build_stats_bar(data: Dictionary) -> void:
	var panel := _panel()
	var row := HBoxContainer.new()
	_panel_add(panel, row)
	var ship: Dictionary = data.get("ship", {})
	var pairs := [
		[_tr("ui.label.time", "Time"), String(data.get("time_label", ""))],
		[_tr("ui.label.money", "Money"), str(int(data.get("money", 0)))],
		[_tr("ui.label.reputation", "Reputation"), str(int(data.get("reputation", 0)))],
		[_tr("ui.label.coal", "Coal"), _fmt(float(ship.get("coal", 0.0)))],
		[_tr("ui.label.water", "Water"), _fmt(float(ship.get("water", 0.0)))],
		[_tr("ui.label.weight", "Weight"), "%s / %s" % [_fmt(float(ship.get("total_weight", 0.0))), _fmt(float(ship.get("max_weight", 0.0)))]],
		[_tr("ui.label.durability", "Durability"), "%s / %s" % [_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0)))]],
	]
	for pair in pairs:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(_label(pair[0], 12, COLOR_MUTED))
		column.add_child(_label(pair[1], 17, COLOR_TEXT))
		row.add_child(column)
	_root_box.add_child(panel)


func _build_nav(data: Dictionary) -> void:
	var nav := HBoxContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(nav)
	var visual_active := "overview" if _active_screen == "port_memory" else _active_screen
	for screen in SCREENS:
		var button := _button(_tr("ui.nav.%s" % screen, screen), _on_nav.bind(screen))
		button.custom_minimum_size = Vector2(96, 34)
		button.toggle_mode = false
		if screen == visual_active:
			button.disabled = true
			button.add_theme_color_override("font_disabled_color", COLOR_BRASS)
			button.add_theme_stylebox_override("disabled", _style(COLOR_PANEL_ALT, 6))
		nav.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	var port: Dictionary = data.get("current_port", {})
	nav.add_child(_label("%s · %s" % [
		_tr("ui.label.port", "Port"),
		_tr(String(port.get("name_key", "")), String(port.get("id", ""))),
	], 14, COLOR_MUTED))
	_root_box.add_child(HSeparator.new())


func _build_status_banner() -> void:
	if _status_message.is_empty():
		return
	_root_box.add_child(_label(_status_message, 14, COLOR_RED if _status_is_error else COLOR_GREEN))


func _build_menu(app: Dictionary) -> void:
	var report: Dictionary = app.get("report", {})
	if not report.get("errors", []).is_empty():
		var error_panel := _panel()
		_panel_add(error_panel, _label(_tr("ui.error.start_failed", "Startup failed"), 18, COLOR_RED))
		for entry in report.get("errors", []):
			_panel_add(error_panel, _label("[%s] %s" % [entry.get("severity", "error"), entry.get("message", "")], 14, COLOR_RED))
		_root_box.add_child(error_panel)
		_root_box.add_child(_button(_tr("ui.button.retry", "Retry"), _retry_bootstrap))
		return

	var intro := _panel()
	_panel_add(intro, _label(_tr("ui.app.subtitle", ""), 16, COLOR_MUTED))
	_panel_add(intro, _label("%s: %d" % [_tr("ui.label.content", "Content"), int(app.get("content_total", 0))], 14, COLOR_TEXT))
	_panel_add(intro, _label("%s: %s" % [_tr("ui.label.registry", "Registry"), "frozen" if bool(app.get("registry_frozen", false)) else "open"], 14, COLOR_TEXT))
	var mod_names := PackedStringArray()
	for mod in app.get("mods", []):
		mod_names.append("%s %s" % [mod.get("id", "?"), mod.get("version", "?")])
	_panel_add(intro, _label("%s: %s" % [_tr("ui.label.mods", "Mods"), ", ".join(mod_names)], 14, COLOR_TEXT))
	_root_box.add_child(intro)

	var form := _panel()
	_panel_add(form, _label(_tr("ui.label.build", "Starting build"), 15, COLOR_BRASS))
	var build_option := OptionButton.new()
	build_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var builds: Array = app.get("builds", [])
	for index in builds.size():
		var build: Dictionary = builds[index]
		build_option.add_item(_tr(String(build.get("name_key", "")), String(build.get("id", ""))))
		build_option.set_item_metadata(index, String(build.get("id", "")))
		if _selected_build.is_empty() or _selected_build == String(build.get("id", "")):
			build_option.select(index)
			_selected_build = String(build.get("id", ""))
	build_option.item_selected.connect(_on_build_selected.bind(build_option))
	_panel_add(form, build_option)
	if not builds.is_empty():
		var selected: Dictionary = builds[0]
		for build in builds:
			if String(build.get("id", "")) == _selected_build:
				selected = build
		_panel_add(form, _label(_tr(String(selected.get("description_key", "")), ""), 13, COLOR_MUTED))

	var seed_row := HBoxContainer.new()
	seed_row.add_child(_label(_tr("ui.label.seed", "Seed"), 14, COLOR_TEXT))
	var seed_input := LineEdit.new()
	seed_input.placeholder_text = "random"
	seed_input.text = _seed_text
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.text_changed.connect(func(value: String) -> void: _seed_text = value)
	seed_row.add_child(seed_input)
	_panel_add(form, seed_row)

	var buttons := HBoxContainer.new()
	var new_run := _button(_tr("ui.button.new_run", "Start a new run"), _on_new_run)
	new_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(new_run)
	if bool(app.get("autosave_available", false)):
		buttons.add_child(_button(_tr("ui.button.continue", "Continue"), _on_continue))
	_panel_add(form, buttons)
	_root_box.add_child(form)

	if not report.get("warnings", []).is_empty():
		var warning_panel := _panel()
		_panel_add(warning_panel, _label(_tr("ui.label.warnings", "Warnings"), 15, COLOR_BRASS))
		for warning in report.get("warnings", []).slice(0, 5):
			_panel_add(warning_panel, _label("• %s" % warning.get("message", ""), 13, COLOR_MUTED))
		_root_box.add_child(warning_panel)


## ---------------------------------------------------------------------------
## Overview
## ---------------------------------------------------------------------------

func _screen_overview(data: Dictionary) -> void:
	_root_box.add_child(_map_panel())
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.7
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.custom_minimum_size = Vector2(400, 0)
	columns.add_child(right)

	left.add_child(_port_panel(data))
	left.add_child(_objective_panel(data))
	left.add_child(_notices_panel(data))
	right.add_child(_ship_summary_panel(data))
	right.add_child(_quick_actions_panel())
	right.add_child(_finance_panel(data))


func _map_panel() -> Control:
	var panel := _panel()
	var map_view := _context.queries.execute(&"map.view")
	if not bool(map_view.get("ok", false)):
		_panel_add(panel, _label(_error_text(map_view), 14, COLOR_RED))
		return panel
	var map_data: Dictionary = map_view["data"]
	_panel_add(panel, _label(_tr("ui.map.hint", ""), 12, COLOR_MUTED))
	var canvas := MapCanvas.new()
	canvas.custom_minimum_size = Vector2(0, 280)
	canvas.ports = map_data.get("ports", [])
	canvas.routes = map_data.get("routes", [])
	canvas.labels = {}
	for port in canvas.ports:
		canvas.labels[String(port.get("id", ""))] = _tr(String(port.get("name_key", "")), String(port.get("id", "")))
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.port_clicked.connect(_on_map_port_clicked)
	_panel_add(panel, canvas)
	return panel


func _port_panel(data: Dictionary) -> Control:
	var panel := _panel()
	var port: Dictionary = data.get("current_port", {})
	_panel_add(panel, _label("%s · %s" % [
		_tr("ui.label.port", "Port"),
		_tr(String(port.get("name_key", "")), String(port.get("id", ""))),
	], 18, COLOR_BRASS))
	var facilities := PackedStringArray()
	for facility in port.get("facilities", []):
		facilities.append(_facility_name(String(facility)))
	_panel_add(panel, _label("设施: " + (", ".join(facilities) if not facilities.is_empty() else "—"), 13, COLOR_MUTED))
	_panel_add(panel, _label("时间 %s · 金币 %d · 声誉 %d" % [
		String(data.get("time_label", "")), int(data.get("money", 0)), int(data.get("reputation", 0))
	], 13, COLOR_TEXT))
	if data.get("debt", null) is Dictionary:
		var debt: Dictionary = data["debt"]
		_panel_add(panel, _label("债务剩余 %s · 到期 %s" % [
			_fmt(float(debt.get("remaining", 0.0))),
			ClockService.format_time(float(debt.get("due_time", 0.0))),
		], 13, COLOR_RED))
	return panel


func _objective_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label("当前目标", 17, COLOR_BRASS))
	var contracts: Dictionary = data.get("contracts", {})
	var main_contract: Variant = contracts.get("main", null)
	var main_offer: Variant = contracts.get("main_offer", null)
	var contract: Variant = main_contract if main_contract is Dictionary else main_offer
	if contract is Dictionary:
		var tag := "主线进行中" if main_contract is Dictionary else "可接主线"
		_panel_add(panel, _label("%s · %s" % [
			tag,
			_tr(String(contract.get("name_key", "")), String(contract.get("template_id", ""))),
		], 14, COLOR_TEXT))
		_panel_add(panel, _label("%s → %s · 期限 %s" % [
			_tr(String(contract.get("origin_name_key", "")), String(contract.get("origin", ""))),
			_tr(String(contract.get("destination_name_key", "")), String(contract.get("destination", ""))),
			String(contract.get("deadline_label", "")),
		], 13, COLOR_MUTED))
		_panel_add(panel, _label(_contract_payload_text(contract), 13, COLOR_TEXT))
		_panel_add(panel, _label(_contract_reward_text(contract), 13, COLOR_MUTED))
	else:
		_panel_add(panel, _label("暂无主线委托", 13, COLOR_MUTED))
	_panel_add(panel, _button("查看全部委托", _on_nav.bind("contracts")))
	return panel


func _ship_summary_panel(data: Dictionary) -> Control:
	var panel := _panel()
	var ship: Dictionary = data.get("ship", {})
	_panel_add(panel, _label("船只", 17, COLOR_BRASS))
	_panel_add(panel, _label("航速 %s · 煤耗 %s/h · 水耗 %s/h" % [
		_fmt(float(ship.get("speed", 0.0)), 2),
		_fmt(float(ship.get("coal_rate", 0.0)), 2),
		_fmt(float(ship.get("water_rate", 0.0)), 2),
	], 13, COLOR_MUTED))
	_panel_add(panel, _label("重量 %s / %s · 耐久 %s / %s" % [
		_fmt(float(ship.get("total_weight", 0.0))),
		_fmt(float(ship.get("max_weight", 0.0))),
		_fmt(float(ship.get("durability", 0.0))),
		_fmt(float(ship.get("max_durability", 0.0))),
	], 13, COLOR_TEXT))
	_panel_add(panel, _label("货舱 %s / %s · 旅客 %d / %d" % [
		_fmt(float(ship.get("cargo_used", 0.0))),
		_fmt(float(ship.get("cargo_capacity", 0.0))),
		int(ship.get("passengers", 0)),
		int(ship.get("passenger_capacity", 0)),
	], 13, COLOR_MUTED))
	_panel_add(panel, _label("%s %s" % [_tr("ui.label.inventory_cost", ""), _fmt(float(ship.get("cargo_cost_basis", 0.0)))], 13, COLOR_MUTED))
	for module in ship.get("modules", []):
		_panel_add(panel, _label("· %s" % _tr(String(module.get("name_key", "")), String(module.get("module_id", ""))), 13, COLOR_TEXT))
	for stack in ship.get("cargo", []):
		var cargo_name := _tr(String(stack.get("name_key", "")), String(stack.get("item_id", "")))
		if bool(stack.get("is_contract", false)):
			_panel_add(panel, _label("· %s ×%d · %s" % [cargo_name, int(stack.get("amount", 0)), _tr("ui.label.contract_cargo", "")], 13, COLOR_MUTED))
		else:
			_panel_add(panel, _label("· %s ×%d · %s %s" % [
				cargo_name,
				int(stack.get("amount", 0)),
				_tr("ui.label.avg_cost", ""),
				_fmt(float(stack.get("average_cost", 0.0))),
			], 13, COLOR_TEXT))
	_panel_add(panel, _button("前往船厂改造", _on_nav.bind("shipyard")))
	return panel


func _quick_actions_panel() -> Control:
	var panel := _panel()
	_panel_add(panel, _label("快捷入口", 17, COLOR_BRASS))
	var actions := [
		["market", "市场买卖"],
		["contracts", "接取委托"],
		["shipyard", "船只改造"],
		["supply", "补给维修"],
		["intel", "情报报告"],
		["voyage", "规划出航"],
	]
	for action in actions:
		_panel_add(panel, _button(String(action[1]), _on_nav.bind(String(action[0]))))
	return panel


func _finance_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label("财务", 17, COLOR_BRASS))
	_panel_add(panel, _label("金币 %d" % int(data.get("money", 0)), 15, COLOR_TEXT))
	if data.get("debt", null) is Dictionary:
		_panel_add(panel, _label("已有贷款，收入将优先自动还款。", 12, COLOR_MUTED))
	else:
		_panel_add(panel, _label("可借款 400，利息 10%，96 小时后到期。", 12, COLOR_MUTED))
		_panel_add(panel, _button("借款 400", _on_borrow))
	return panel


func _notices_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label("航行记录", 15, COLOR_MUTED))
	var notices: Array = data.get("notices", [])
	if notices.is_empty():
		_panel_add(panel, _label("—", 13, COLOR_MUTED))
	for notice in notices.slice(maxi(0, notices.size() - 6), notices.size()):
		_panel_add(panel, _label("· %s" % _tr(String(notice.get("text_key", "")), ""), 13, COLOR_TEXT))
	return panel


## ---------------------------------------------------------------------------
## Market
## ---------------------------------------------------------------------------

func _screen_market(data: Dictionary) -> void:
	var panel := _panel()
	var port: Dictionary = data.get("current_port", {})
	_panel_add(panel, _label("交易所 · %s" % _tr(String(port.get("name_key", "")), String(port.get("id", ""))), 20, COLOR_BRASS))
	var ship: Dictionary = data.get("ship", {})
	_panel_add(panel, _label("金币 %d · 重量 %s / %s · 货舱 %s / %s · %s %s" % [
		int(data.get("money", 0)),
		_fmt(float(ship.get("total_weight", 0.0))),
		_fmt(float(ship.get("max_weight", 0.0))),
		_fmt(float(ship.get("cargo_used", 0.0))),
		_fmt(float(ship.get("cargo_capacity", 0.0))),
		_tr("ui.label.inventory_cost", ""),
		_fmt(float(ship.get("cargo_cost_basis", 0.0))),
	], 13, COLOR_MUTED))
	_panel_add(panel, _label(_tr("ui.hint.market", ""), 12, COLOR_MUTED))

	var trends := _market_trends()
	var grid := GridContainer.new()
	grid.columns = 9
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for heading in ["商品", "单价", "库存", _tr("ui.label.unit_weight", "单位重量"), "持有 / 可售", _tr("ui.label.avg_cost", ""), _tr("ui.label.trend", "趋势"), "买入", "卖出"]:
		grid.add_child(_label(heading, 12, COLOR_MUTED))
	for row in data.get("market", []):
		var item_id := String(row.get("item_id", ""))
		var buyable := bool(row.get("buyable", true))
		var item_label := _tr(String(row.get("name_key", "")), item_id)
		if not buyable:
			item_label += " · " + _tr("ui.label.sell_only", "Sell-only")
		grid.add_child(_label(item_label, 13, COLOR_TEXT if buyable else COLOR_MUTED))
		grid.add_child(_label(str(int(row.get("price", 0))), 13, COLOR_TEAL))
		grid.add_child(_label(str(int(row.get("stock", 0))), 13, COLOR_TEXT))
		grid.add_child(_label(_fmt(float(row.get("unit_weight", 0.0))), 13, COLOR_MUTED))
		grid.add_child(_label("%d / %d" % [int(row.get("cargo_amount", 0)), int(row.get("sellable_amount", 0))], 13, COLOR_TEXT))
		var average_cost := float(row.get("cargo_avg_cost", 0.0))
		grid.add_child(_label(_fmt(average_cost) if average_cost > 0.0 else "—", 13, COLOR_TEXT))
		grid.add_child(_label(_trend_text(trends.get(item_id, "")), 13, _trend_color(trends.get(item_id, ""))))
		var buy_row := HBoxContainer.new()
		buy_row.add_theme_constant_override("separation", 2)
		for amount in [1, 5, 10]:
			var buy_button := _small_button(str(amount), _on_buy.bind(item_id, amount))
			buy_button.disabled = not buyable or int(row.get("stock", 0)) < amount
			buy_row.add_child(buy_button)
		grid.add_child(buy_row)
		var sell_row := HBoxContainer.new()
		sell_row.add_theme_constant_override("separation", 2)
		for amount in [1, 5]:
			var sell_button := _small_button(str(amount), _on_sell.bind(item_id, amount))
			sell_button.disabled = int(row.get("sellable_amount", 0)) < amount
			sell_row.add_child(sell_button)
		grid.add_child(sell_row)
	_panel_add(panel, grid)
	_root_box.add_child(panel)


func _market_trends() -> Dictionary:
	var result: Dictionary = {}
	var intel := _context.queries.execute(&"intel.view")
	if not bool(intel.get("ok", false)) or not bool(intel["data"].get("has_report", false)):
		return result
	var current_port := String(_last_port_view.get("current_port_id", ""))
	for port_report in intel["data"].get("ports", []):
		if String(port_report.get("port_id", "")) != current_port:
			continue
		for row in port_report.get("market", []):
			result[String(row.get("item_id", ""))] = String(row.get("trend", ""))
	return result


## ---------------------------------------------------------------------------
## Port memory (clicked on the map)
## ---------------------------------------------------------------------------

func _screen_port_memory(_data: Dictionary) -> void:
	if _memory_port_id.is_empty():
		_memory_port_id = String(_last_port_view.get("current_port_id", ""))
	var result := _context.queries.execute(&"port.memory", {"port_id": _memory_port_id})
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, COLOR_RED))
		_panel_add(error_panel, _button(_tr("ui.button.back_overview", ""), _on_nav.bind("overview")))
		_root_box.add_child(error_panel)
		return
	var memory: Dictionary = result["data"]
	var panel := _panel()
	_panel_add(panel, _label("港口记忆 · %s" % _tr(String(memory.get("name_key", "")), String(memory.get("port_id", ""))), 20, COLOR_BRASS))
	if bool(memory.get("has_memory", false)):
		_panel_add(panel, _label("%s：%s · %s" % [
			_tr("ui.label.last_visit", ""),
			String(memory.get("captured_label", "")),
			_age_text(float(memory.get("age_hours", 0.0))),
		], 14, COLOR_TEXT))
		_panel_add(panel, _label(_tr("ui.label.readonly_memory", ""), 12, COLOR_MUTED))
		var grid := GridContainer.new()
		grid.columns = 4
		for heading in ["商品", "上次单价", "上次储备", "买卖"]:
			grid.add_child(_label(heading, 12, COLOR_MUTED))
		for row in memory.get("market", []):
			var buyable := bool(row.get("buyable", true))
			var is_supply := bool(row.get("is_supply", false))
			grid.add_child(_label(_tr(String(row.get("name_key", "")), String(row.get("item_id", ""))), 13, COLOR_TEXT))
			grid.add_child(_label(str(int(row.get("price", 0))), 13, COLOR_TEAL))
			grid.add_child(_label(str(int(row.get("stock", 0))), 13, COLOR_TEXT))
			if is_supply:
				grid.add_child(_label(_tr("ui.label.supply", "Supply"), 13, COLOR_BRASS))
			else:
				grid.add_child(_label("可买" if buyable else _tr("ui.label.sell_only", ""), 13, COLOR_GREEN if buyable else COLOR_MUTED))
		_panel_add(panel, grid)
	else:
		_panel_add(panel, _label("没有该港口的到港市场记录。", 14, COLOR_MUTED))
	var facilities := PackedStringArray()
	for facility in memory.get("facilities", []):
		facilities.append(_facility_name(String(facility)))
	if bool(memory.get("facilities_known", false)):
		_panel_add(panel, _label("设施：" + (", ".join(facilities) if not facilities.is_empty() else "—"), 13, COLOR_MUTED))
	_panel_add(panel, _button(_tr("ui.button.back_overview", ""), _on_nav.bind("overview")))
	_root_box.add_child(panel)


## ---------------------------------------------------------------------------
## Contracts
## ---------------------------------------------------------------------------

func _screen_contracts(data: Dictionary) -> void:
	var contracts: Dictionary = data.get("contracts", {})
	var header := _panel()
	_panel_add(header, _label("委托", 20, COLOR_BRASS))
	_panel_add(header, _label("主线只能同时进行一个；普通委托持有上限随声誉提高。", 12, COLOR_MUTED))
	_root_box.add_child(header)

	var any := false
	var main_contract: Variant = contracts.get("main", null)
	if main_contract is Dictionary:
		any = true
		_root_box.add_child(_contract_card(main_contract, "主线进行中", false, true))
	var main_offer: Variant = contracts.get("main_offer", null)
	if main_offer is Dictionary:
		any = true
		_root_box.add_child(_contract_card(main_offer, "可接主线", true, false))
	var offers: Array = contracts.get("offers", [])
	for offer in offers:
		if offer is Dictionary:
			any = true
			_root_box.add_child(_contract_card(offer, "普通委托", true, false))
	var active: Array = contracts.get("active", [])
	for contract in active:
		if contract is Dictionary:
			any = true
			_root_box.add_child(_contract_card(contract, "普通进行中", false, true))
	if not any:
		var empty := _panel()
		_panel_add(empty, _label(_tr("ui.label.no_contracts", "暂无委托"), 14, COLOR_MUTED))
		_root_box.add_child(empty)

	var completed: Array = contracts.get("completed", [])
	if not completed.is_empty():
		var panel := _panel()
		_panel_add(panel, _label("已完成主线", 15, COLOR_BRASS))
		for contract_id in completed:
			_panel_add(panel, _label("· %s" % _definition_name(String(contract_id)), 13, COLOR_MUTED))
		_root_box.add_child(panel)


func _contract_card(contract: Dictionary, tag: String, can_accept: bool, can_plan: bool) -> Control:
	var panel := _panel()
	panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL_ALT, 8))
	var title_row := HBoxContainer.new()
	var title := _label(_tr(String(contract.get("name_key", "")), String(contract.get("template_id", ""))), 16, COLOR_BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(title)
	title_row.add_child(_label(tag, 12, COLOR_MUTED))
	_panel_add(panel, title_row)
	_panel_add(panel, _label("%s → %s" % [
		_tr(String(contract.get("origin_name_key", "")), String(contract.get("origin", ""))),
		_tr(String(contract.get("destination_name_key", "")), String(contract.get("destination", ""))),
	], 14, COLOR_TEXT))
	_panel_add(panel, _label("期限 %s" % String(contract.get("deadline_label", "")), 13, COLOR_MUTED))
	_panel_add(panel, _label(_contract_payload_text(contract), 13, COLOR_TEXT))
	_panel_add(panel, _label(_contract_reward_text(contract), 13, COLOR_TEXT))
	var unlock_text := _contract_unlock_text(contract)
	if not unlock_text.is_empty():
		_panel_add(panel, _label("解锁：%s" % unlock_text, 13, COLOR_TEAL))
	var time_hint := _contract_time_hint(contract)
	if not time_hint.is_empty():
		_panel_add(panel, _label(time_hint, 12, COLOR_MUTED))
	var buttons := HBoxContainer.new()
	if can_accept:
		buttons.add_child(_button(_tr("ui.button.accept", "接受"), _on_accept_contract.bind(String(contract.get("instance_id", "")))))
	if can_plan:
		var destination := String(contract.get("destination", ""))
		var plan := _button(_tr("ui.button.plan", "规划出航"), _on_plan_contract.bind(destination))
		plan.disabled = not _is_neighbor(destination)
		buttons.add_child(plan)
	if buttons.get_child_count() > 0:
		_panel_add(panel, buttons)
	return panel


func _contract_payload_text(contract: Dictionary) -> String:
	var parts := PackedStringArray()
	if float(contract.get("cargo_weight", 0.0)) > 0.0:
		parts.append("货物 %.0f 重量" % float(contract.get("cargo_weight", 0.0)))
	if int(contract.get("passengers", 0)) > 0:
		parts.append("旅客 %d 人" % int(contract.get("passengers", 0)))
	if parts.is_empty():
		return "载荷：—"
	return "载荷：" + " · ".join(parts)


func _contract_reward_text(contract: Dictionary) -> String:
	var parts := PackedStringArray()
	parts.append("基础 %d" % int(contract.get("base_money", 0)))
	parts.append("准时 +%d" % int(contract.get("on_time_bonus", 0)))
	parts.append("声誉 +%d" % int(contract.get("reputation", 0)))
	return "报酬：" + " · ".join(parts)


func _contract_unlock_text(contract: Dictionary) -> String:
	var names := PackedStringArray()
	for unlock_id in contract.get("unlock_ids", []):
		names.append(_definition_name(String(unlock_id)))
	return ", ".join(names)


func _contract_time_hint(contract: Dictionary) -> String:
	var destination := String(contract.get("destination", ""))
	if not _is_neighbor(destination):
		return "标准策略：目的港不直达，需要中转。"
	var preview := _context.queries.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": _standard_strategy_id(),
	})
	if not bool(preview.get("ok", false)):
		return ""
	var data: Dictionary = preview["data"]
	if not bool(data.get("feasible", false)):
		return "标准策略当前不可行。"
	var arrival := float(data.get("arrival_time", 0.0))
	var deadline := float(contract.get("deadline", 0.0))
	var verdict := "期限前抵达" if arrival <= deadline else "预计迟到"
	return "标准策略预计 %s 抵达 · %s" % [ClockService.format_time(arrival), verdict]


## ---------------------------------------------------------------------------
## Shipyard
## ---------------------------------------------------------------------------

func _screen_shipyard(_data: Dictionary) -> void:
	var result := _context.queries.execute(&"shipyard.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, COLOR_RED))
		_root_box.add_child(error_panel)
		return
	var yard: Dictionary = result["data"]
	if not bool(yard.get("has_shipyard", false)):
		var warn := _panel()
		_panel_add(warn, _label(_tr("ui.label.shipyard_absent", ""), 15, COLOR_RED))
		_root_box.add_child(warn)

	var current := _panel()
	_panel_add(current, _label("%s · %s" % [_tr("ui.label.current_ship", ""), _tr(String(yard.get("port_name_key", "")), String(yard.get("port_id", "")))], 20, COLOR_BRASS))
	var ship: Dictionary = yard.get("ship", {})
	_panel_add(current, _label("货舱槽 %d / %d · 客舱槽 %d / %d · 导航 %s · 安全 %s" % [
		int(ship.get("cargo_used", 0)), int(ship.get("cargo_slots", 0)),
		int(ship.get("cabin_used", 0)), int(ship.get("cabin_slots", 0)),
		"已装" if bool(ship.get("navigation_occupied", false)) else "空",
		"已装" if bool(ship.get("safety_occupied", false)) else "空",
	], 13, COLOR_TEXT))
	_panel_add(current, _label("重量 %s / %s · 耐久 %s / %s · 金币 %d" % [
		_fmt(float(ship.get("total_weight", 0.0))),
		_fmt(float(ship.get("max_weight", 0.0))),
		_fmt(float(ship.get("durability", 0.0))),
		_fmt(float(ship.get("max_durability", 0.0))),
		int(yard.get("money", 0)),
	], 13, COLOR_MUTED))
	for module in ship.get("modules", []):
		_panel_add(current, _label("· %s" % _tr(String(module.get("name_key", "")), String(module.get("module_id", ""))), 13, COLOR_TEXT))
	_panel_add(current, _label(_tr("ui.hint.shipyard", ""), 12, COLOR_MUTED))
	_root_box.add_child(current)

	var candidates: Array = yard.get("candidates", [])
	for content_type in MODULE_TYPE_ORDER:
		var group: Array = []
		for candidate in candidates:
			if String(candidate.get("content_type", "")) == String(content_type):
				group.append(candidate)
		if group.is_empty():
			continue
		var panel := _panel()
		_panel_add(panel, _label(String(MODULE_TYPE_LABELS.get(content_type, String(content_type))), 16, COLOR_BRASS))
		for candidate in group:
			_panel_add(panel, _shipyard_candidate_card(candidate))
		_root_box.add_child(panel)


func _shipyard_candidate_card(candidate: Dictionary) -> Control:
	var card := _panel()
	var title_row := HBoxContainer.new()
	var installed := bool(candidate.get("installed", false))
	var title := _label(_tr(String(candidate.get("name_key", "")), String(candidate.get("module_id", ""))), 14, COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(_label("%d 金币 · %s" % [
		int(candidate.get("price", 0)), _fmt(float(candidate.get("weight", 0.0)))
	], 12, COLOR_MUTED))
	_panel_add(card, title_row)
	var description_key := String(candidate.get("description_key", ""))
	if not description_key.is_empty():
		var description := _label(_tr(description_key, ""), 12, COLOR_MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_add(card, description)
	var effect_text := _module_effect_text(String(candidate.get("content_type", "")), candidate.get("effect", {}))
	if not effect_text.is_empty():
		_panel_add(card, _label(_tr("ui.label.effect", "") + "：" + effect_text, 12, COLOR_TEAL))
	var blockers: Array = candidate.get("blockers", [])
	var blocker_text := _blocker_text(blockers)
	if not blocker_text.is_empty():
		_panel_add(card, _label(blocker_text, 12, COLOR_RED if not installed else COLOR_MUTED))
	var button := _button(
		_tr("ui.label.already_installed", "") if installed else _tr("ui.button.install", ""),
		_on_install_module.bind(String(candidate.get("module_id", "")))
	)
	button.disabled = not bool(candidate.get("can_install", false))
	_panel_add(card, button)
	return card


func _module_effect_text(content_type: String, effect: Dictionary) -> String:
	match content_type:
		"hulls":
			return "货舱 %d · 客舱 %d · 载重 %s · 航速 %s · 耐久 %s" % [
				int(effect.get("cargo_slots", 0)),
				int(effect.get("cabin_slots", 0)),
				_fmt(float(effect.get("max_weight", 0.0))),
				_fmt(float(effect.get("base_speed", 0.0))),
				_fmt(float(effect.get("max_durability", 0.0))),
			]
		"boilers":
			return "航速 ×%s · 煤耗 %s/h · 水耗 %s/h" % [
				_fmt(float(effect.get("speed_mul", 1.0)), 2),
				_fmt(float(effect.get("coal_rate", 0.0)), 2),
				_fmt(float(effect.get("water_rate", 0.0)), 2),
			]
		"cargo_modules":
			return "容量 %s" % _fmt(float(effect.get("capacity", 0.0)))
		"navigation_modules":
			return "风险 %+.3f · 速度 ×%s · %s" % [
				float(effect.get("risk_add", 0.0)),
				_fmt(float(effect.get("speed_mul", 1.0)), 2),
				"出航前揭示设施" if bool(effect.get("reveal_facilities", false)) else "无设施揭示",
			]
		"safety_modules":
			return "风险 %+.3f · 损伤 ×%s · 维修 ×%s" % [
				float(effect.get("risk_add", 0.0)),
				_fmt(float(effect.get("damage_mul", 1.0)), 2),
				_fmt(float(effect.get("repair_cost_mul", 1.0)), 2),
			]
		"cabins":
			return "旅客 %d" % int(effect.get("passenger_capacity", 0))
		_:
			return ""


func _blocker_text(blockers: Array) -> String:
	var parts := PackedStringArray()
	for raw_code in blockers:
		var code := String(raw_code)
		if code == "already_installed":
			continue
		var text := _tr("ui.reason.%s" % code, "")
		if text.is_empty() or parts.has(text):
			continue
		parts.append(text)
	if parts.is_empty():
		return ""
	return "限制：" + ", ".join(parts)


## ---------------------------------------------------------------------------
## Supply dock
## ---------------------------------------------------------------------------

func _screen_supply(_data: Dictionary) -> void:
	var result := _context.queries.execute(&"supply.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, COLOR_RED))
		_root_box.add_child(error_panel)
		return
	var supply: Dictionary = result["data"]
	var panel := _panel()
	_panel_add(panel, _label("补给码头 · %s" % _tr(String(supply.get("port_name_key", "")), String(supply.get("port_id", ""))), 20, COLOR_BRASS))
	if not bool(supply.get("has_supply", false)):
		_panel_add(panel, _label("当前港口没有补给码头。", 14, COLOR_RED))
	_panel_add(panel, _label("煤炭 %s · 淡水 %s · 耐久 %s / %s" % [
		_fmt(float(supply.get("coal", 0.0))),
		_fmt(float(supply.get("water", 0.0))),
		_fmt(float(supply.get("durability", 0.0))),
		_fmt(float(supply.get("repair", {}).get("max_durability", 0.0))),
	], 14, COLOR_TEXT))
	_panel_add(panel, _label("重量 %s / %s · 剩余载重 %s · 金币 %d" % [
		_fmt(float(supply.get("total_weight", 0.0))),
		_fmt(float(supply.get("max_weight", 0.0))),
		_fmt(float(supply.get("remaining_weight", 0.0))),
		int(supply.get("money", 0)),
	], 13, COLOR_MUTED))
	_panel_add(panel, _label("补给价格随港口库存和商船流动浮动；补给计入总重量。", 12, COLOR_MUTED))
	_root_box.add_child(panel)

	var coal_panel := _panel()
	_panel_add(coal_panel, _label("%s · 单价 %s · %s %d · 最多可买 %d" % [
		_tr("ui.label.coal", ""),
		_fmt(float(supply.get("coal_price", 0.0))),
		_tr("ui.label.port_stock", ""),
		int(supply.get("coal_stock", 0)),
		int(supply.get("max_coal", 0)),
	], 16, COLOR_BRASS))
	var coal_buttons := HBoxContainer.new()
	for amount in [5, 10, 25]:
		var button := _button("买入 %d" % amount, _on_buy_coal.bind(amount))
		button.disabled = not bool(supply.get("has_supply", false)) or int(supply.get("max_coal", 0)) < amount
		coal_buttons.add_child(button)
	_panel_add(coal_panel, coal_buttons)
	_root_box.add_child(coal_panel)

	var water_panel := _panel()
	_panel_add(water_panel, _label("%s · 单价 %s · %s %d · 最多可买 %d" % [
		_tr("ui.label.water", ""),
		_fmt(float(supply.get("water_price", 0.0))),
		_tr("ui.label.port_stock", ""),
		int(supply.get("water_stock", 0)),
		int(supply.get("max_water", 0)),
	], 16, COLOR_BRASS))
	var water_buttons := HBoxContainer.new()
	for amount in [5, 10, 25]:
		var button := _button("买入 %d" % amount, _on_buy_water.bind(amount))
		button.disabled = not bool(supply.get("has_supply", false)) or int(supply.get("max_water", 0)) < amount
		water_buttons.add_child(button)
	_panel_add(water_panel, water_buttons)
	_root_box.add_child(water_panel)

	var repair_panel := _panel()
	var repair: Dictionary = supply.get("repair", {})
	_panel_add(repair_panel, _label("维修", 16, COLOR_BRASS))
	_panel_add(repair_panel, _label("缺失耐久 %s · 预计费用 %d 金币（单位维修价 %s）" % [
		_fmt(float(repair.get("missing", 0.0))),
		int(repair.get("cost", 0)),
		_fmt(float(supply.get("repair_per_point", 0.0))),
	], 13, COLOR_TEXT))
	var repair_button := _button(_tr("ui.button.repair", ""), _on_repair)
	repair_button.disabled = not bool(supply.get("can_repair", false))
	_panel_add(repair_panel, repair_button)
	_root_box.add_child(repair_panel)


## ---------------------------------------------------------------------------
## Intelligence
## ---------------------------------------------------------------------------

func _screen_intel(_data: Dictionary) -> void:
	var result := _context.queries.execute(&"intel.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, COLOR_RED))
		_root_box.add_child(error_panel)
		return
	var intel: Dictionary = result["data"]
	var header := _panel()
	_panel_add(header, _label("情报", 20, COLOR_BRASS))
	_panel_add(header, _label(_tr("ui.hint.intel", ""), 12, COLOR_MUTED))
	if bool(intel.get("has_report", false)):
		_panel_add(header, _label("%s：%s · %s" % [
			_tr("ui.label.generated", ""),
			String(intel.get("generated_label", "")),
			_age_text(float(intel.get("age_hours", 0.0))),
		], 14, COLOR_TEXT))
		_panel_add(header, _label("覆盖 %d 个已发现港口 · %d 条 NPC 动向" % [
			int(intel.get("port_count", 0)), int(intel.get("npc_count", 0)),
		], 12, COLOR_MUTED))
		_panel_add(header, _label(_tr("ui.label.snapshot_tip", ""), 12, COLOR_MUTED))
	else:
		_panel_add(header, _label(_tr("ui.label.no_intel", ""), 14, COLOR_MUTED))
	if bool(intel.get("has_intel_facility", false)):
		var refresh := _button("%s（%d 金币）" % [_tr("ui.button.refresh_intel", ""), int(intel.get("cost", 25))], _on_refresh_intel)
		refresh.disabled = not bool(intel.get("can_refresh", false))
		_panel_add(header, refresh)
	else:
		_panel_add(header, _label("当前港口没有情报站。", 12, COLOR_MUTED))
	_root_box.add_child(header)

	for port_report in intel.get("ports", []):
		var panel := _panel()
		_panel_add(panel, _label(_tr(String(port_report.get("name_key", "")), String(port_report.get("port_id", ""))), 16, COLOR_TEAL))
		var grid := GridContainer.new()
		grid.columns = 4
		for heading in ["商品", "价格", "库存", _tr("ui.label.trend", "")]:
			grid.add_child(_label(heading, 12, COLOR_MUTED))
		for row in port_report.get("market", []):
			var item_label := _tr(String(row.get("item_name_key", "")), String(row.get("item_id", "")))
			if bool(row.get("is_supply", false)):
				item_label += " · " + _tr("ui.label.supply", "")
			elif not bool(row.get("buyable", true)):
				item_label += " · " + _tr("ui.label.sell_only", "")
			grid.add_child(_label(item_label, 13, COLOR_TEXT))
			grid.add_child(_label(str(int(row.get("price", 0))), 13, COLOR_TEAL))
			grid.add_child(_label(str(int(row.get("stock", 0))), 13, COLOR_TEXT))
			grid.add_child(_label(_trend_text(String(row.get("trend", ""))), 13, _trend_color(String(row.get("trend", "")))))
		_panel_add(panel, grid)
		_root_box.add_child(panel)

	var npc_panel := _panel()
	_panel_add(npc_panel, _label("NPC 商船动向", 16, COLOR_BRASS))
	var npcs: Array = intel.get("npcs", [])
	if npcs.is_empty():
		_panel_add(npc_panel, _label("暂无覆盖到的 NPC 动向（未发现的目的港不会出现）。", 12, COLOR_MUTED))
	else:
		var npc_grid := GridContainer.new()
		npc_grid.columns = 4
		for heading in ["目的港", "货物", _tr("ui.label.action", ""), _tr("ui.label.eta", "")]:
			npc_grid.add_child(_label(heading, 12, COLOR_MUTED))
		for npc in npcs:
			npc_grid.add_child(_label(_tr(String(npc.get("destination_name_key", "")), String(npc.get("destination", ""))), 13, COLOR_TEXT))
			npc_grid.add_child(_label(_tr(String(npc.get("item_name_key", "")), String(npc.get("item_id", ""))), 13, COLOR_TEXT))
			npc_grid.add_child(_label(_tr(String(npc.get("action_label_key", "")), String(npc.get("action", ""))), 13, COLOR_TEAL))
			npc_grid.add_child(_label("%s – %s" % [
				ClockService.format_time(float(npc.get("eta_from", 0.0))),
				ClockService.format_time(float(npc.get("eta_to", 0.0))),
			], 13, COLOR_MUTED))
		_panel_add(npc_panel, npc_grid)
	_root_box.add_child(npc_panel)


## ---------------------------------------------------------------------------
## Voyage planning
## ---------------------------------------------------------------------------

func _screen_voyage(data: Dictionary) -> void:
	var panel := _panel()
	_panel_add(panel, _label("出航规划", 20, COLOR_BRASS))
	var destinations: Array = data.get("destinations", [])
	var strategies: Array = data.get("strategies", [])
	if destinations.is_empty() or strategies.is_empty():
		_panel_add(panel, _label("没有可用航线或锅炉策略。", 14, COLOR_RED))
		_root_box.add_child(panel)
		return
	if _selected_destination.is_empty() or not _destination_exists(destinations, _selected_destination):
		_selected_destination = String(destinations[0].get("port_id", ""))
	if _selected_strategy.is_empty():
		_selected_strategy = _standard_strategy_id()
		if _selected_strategy.is_empty():
			_selected_strategy = String(strategies[0].get("id", ""))

	var selector_row := HBoxContainer.new()
	var destination_option := OptionButton.new()
	destination_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var destination_index := 0
	for index in destinations.size():
		var destination: Dictionary = destinations[index]
		destination_option.add_item("%s · %.0f 海里" % [
			_tr(String(destination.get("name_key", "")), String(destination.get("port_id", ""))),
			float(destination.get("distance", 0.0)),
		])
		destination_option.set_item_metadata(index, String(destination.get("port_id", "")))
		if String(destination.get("port_id", "")) == _selected_destination:
			destination_index = index
	destination_option.select(destination_index)
	destination_option.item_selected.connect(_on_destination_selected.bind(destination_option))
	selector_row.add_child(destination_option)

	var strategy_option := OptionButton.new()
	var strategy_index := 0
	for index in strategies.size():
		var strategy: Dictionary = strategies[index]
		strategy_option.add_item(_tr(String(strategy.get("name_key", "")), String(strategy.get("id", ""))))
		strategy_option.set_item_metadata(index, String(strategy.get("id", "")))
		if String(strategy.get("id", "")) == _selected_strategy:
			strategy_index = index
	strategy_option.select(strategy_index)
	strategy_option.item_selected.connect(_on_strategy_selected.bind(strategy_option))
	selector_row.add_child(strategy_option)
	_panel_add(panel, selector_row)
	_root_box.add_child(panel)

	var preview := _context.queries.execute(&"voyage.preview", {
		"destination_id": _selected_destination,
		"strategy_id": _selected_strategy,
	})
	if not bool(preview.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(preview), 14, COLOR_RED))
		_root_box.add_child(error_panel)
		return
	var p: Dictionary = preview["data"]
	var detail := _panel()
	var main_contract: Variant = data.get("contracts", {}).get("main", null)
	var is_main_destination := main_contract is Dictionary and String(main_contract.get("destination", "")) == _selected_destination
	_panel_add(detail, _label("航线：%s → %s%s" % [
		_value_name(data.get("current_port", {}), ""),
		_tr(String(p.get("destination_name_key", "")), String(p.get("destination_id", ""))),
		"（主线目的港）" if is_main_destination else "",
	], 16, COLOR_TEXT))
	_panel_add(detail, _kv_row("距离", "%s 海里" % _fmt(float(p.get("distance", 0.0)))))
	_panel_add(detail, _kv_row("有效航速", "%s · 重量系数 %s" % [
		_fmt(float(p.get("effective_speed", 0.0)), 2), _fmt(float(p.get("weight_factor", 1.0)), 2)
	]))
	_panel_add(detail, _kv_row("耗时", "%s · 抵达 %s" % [
		ClockService.format_duration(float(p.get("duration_hours", 0.0))),
		ClockService.format_time(float(p.get("arrival_time", 0.0))),
	]))
	_panel_add(detail, _kv_row("煤炭", "%s / %s" % [_fmt(float(p.get("coal_required", 0.0))), _fmt(float(p.get("coal_available", 0.0)))], COLOR_RED if float(p.get("coal_required", 0.0)) > float(p.get("coal_available", 0.0)) else COLOR_TEXT))
	_panel_add(detail, _kv_row("淡水", "%s / %s" % [_fmt(float(p.get("water_required", 0.0))), _fmt(float(p.get("water_available", 0.0)))], COLOR_RED if float(p.get("water_required", 0.0)) > float(p.get("water_available", 0.0)) else COLOR_TEXT))
	_panel_add(detail, _kv_row("重量", "%s / %s" % [_fmt(float(p.get("total_weight", 0.0))), _fmt(float(p.get("max_weight", 0.0)))]))
	_panel_add(detail, _kv_row("船员工资", "%d 金币" % int(p.get("crew_wages", 0))))
	if float(p.get("deadline", -1.0)) >= 0.0:
		_panel_add(detail, _kv_row("委托期限", "%s · %s" % [
			ClockService.format_time(float(p.get("deadline", 0.0))),
			"预计准时" if bool(p.get("on_time", false)) else "预计迟到",
		], COLOR_GREEN if bool(p.get("on_time", false)) else COLOR_RED))
	var risk_parts := PackedStringArray()
	for source in p.get("risk_sources", []):
		risk_parts.append("%s %+.3f" % [
			_tr(String(source.get("key", "")), String(source.get("key", ""))),
			float(source.get("value", 0.0)),
		])
	_panel_add(detail, _kv_row("风险来源", "，".join(risk_parts), COLOR_TEXT))
	_panel_add(detail, _kv_row("情报时间", "无" if float(p.get("intel_generated_at", -1.0)) < 0.0 else ClockService.format_time(float(p.get("intel_generated_at", 0.0)))))
	var facilities := PackedStringArray()
	for facility in p.get("destination_facilities", []):
		facilities.append(_facility_name(String(facility)))
	_panel_add(detail, _kv_row("目的港设施", "未知" if not bool(p.get("destination_facilities_known", false)) else (", ".join(facilities) if not facilities.is_empty() else "—")))
	_root_box.add_child(detail)

	if not p.get("blockers", []).is_empty():
		var blocker_panel := _panel()
		var blocker_text := PackedStringArray()
		for blocker in p.get("blockers", []):
			blocker_text.append(_tr(String(blocker.get("message_key", "")), String(blocker.get("code", ""))))
		_panel_add(blocker_panel, _label("无法出航：" + "，".join(blocker_text), 14, COLOR_RED))
		_root_box.add_child(blocker_panel)

	var action_panel := _panel()
	var depart := _button(_tr("ui.button.depart", "Depart"), _on_depart)
	depart.disabled = not bool(p.get("feasible", false))
	_panel_add(action_panel, depart)
	_panel_add(action_panel, _label("出航后不能更改策略；遇到事件时只能从本次抽样出的选项中选择。", 12, COLOR_MUTED))
	_root_box.add_child(action_panel)


## ---------------------------------------------------------------------------
## At sea and events
## ---------------------------------------------------------------------------

func _screen_at_sea(data: Dictionary, voyage: Variant) -> void:
	var panel := _panel()
	_panel_add(panel, _label("航行中", 20, COLOR_TEAL))
	if voyage is Dictionary:
		_panel_add(panel, _label("%s → %s" % [
			_port_name(String(voyage.get("origin", ""))),
			_port_name(String(voyage.get("destination", ""))),
		], 15, COLOR_TEXT))
		_panel_add(panel, _label("预计抵达 %s" % ClockService.format_time(float(voyage.get("arrival_time", 0.0))), 13, COLOR_MUTED))
	else:
		_panel_add(panel, _label("正在等待航行结算……", 13, COLOR_MUTED))
	_panel_add(panel, _label("当前画面会在抵达后自动刷新。", 12, COLOR_MUTED))
	_root_box.add_child(panel)


func _screen_event(data: Dictionary, event: Dictionary) -> void:
	var panel := _panel()
	_panel_add(panel, _label(_tr(String(event.get("name_key", "")), String(event.get("event_id", ""))), 22, COLOR_RED))
	var description_key := String(event.get("description_key", ""))
	if not description_key.is_empty():
		var description := _label(_tr(description_key, ""), 14, COLOR_TEXT)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_add(panel, description)
	var ship: Dictionary = data.get("ship", {})
	_panel_add(panel, _label("耐久 %s / %s · 淡水 %s · 煤炭 %s · 金币 %d" % [
		_fmt(float(ship.get("durability", 0.0))),
		_fmt(float(ship.get("max_durability", 0.0))),
		_fmt(float(ship.get("water", 0.0))),
		_fmt(float(ship.get("coal", 0.0))),
		int(data.get("money", 0)),
	], 13, COLOR_MUTED))
	_panel_add(panel, _label("从以下方案中选择一个，选择后会立即结算。", 12, COLOR_MUTED))
	for option in event.get("options", []):
		var option_id := String(option.get("id", ""))
		_panel_add(panel, _button(_tr(String(option.get("name_key", "")), option_id), _on_event_option.bind(option_id)))
	_root_box.add_child(panel)


## ---------------------------------------------------------------------------
## Commands and callbacks
## ---------------------------------------------------------------------------

func _on_nav(screen: String) -> void:
	_active_screen = screen
	_status_message = ""
	_refresh()


func _on_map_port_clicked(port_id: String) -> void:
	if port_id == String(_last_port_view.get("current_port_id", "")):
		_active_screen = "market"
	else:
		_memory_port_id = port_id
		_active_screen = "port_memory"
	_status_message = ""
	_refresh()


func _on_build_selected(_index: int, option: OptionButton) -> void:
	_selected_build = String(option.get_item_metadata(option.selected))
	_refresh()


func _on_destination_selected(_index: int, option: OptionButton) -> void:
	_selected_destination = String(option.get_item_metadata(option.selected))
	_refresh()


func _on_strategy_selected(_index: int, option: OptionButton) -> void:
	_selected_strategy = String(option.get_item_metadata(option.selected))
	_refresh()


func _on_new_run() -> void:
	var seed := 0
	if not _seed_text.strip_edges().is_empty() and _seed_text.strip_edges().is_valid_int():
		seed = int(_seed_text.strip_edges())
	_selected_destination = ""
	_selected_strategy = ""
	_status_message = ""
	_run_command(&"run.start", {"build_id": _selected_build, "seed": seed})


func _on_continue() -> void:
	var loaded := _context.save.load_autosave()
	if not bool(loaded.get("ok", false)):
		_set_status(String(loaded.get("error", "load failed")), true)
		_refresh()
		return
	var validation := _context.save.validate_mods(loaded.get("header", {}), _context.mod_summaries())
	if not bool(validation.get("ok", false)):
		_set_status(", ".join(validation.get("errors", [])), true)
		_refresh()
		return
	_context.set_state(loaded["state"])
	_context.set_seed(_context.state.seed())
	MarketOps.ensure_sell_only_entries(_context.registries, _context.state)
	if not MarketMemoryService.has_memory(_context.state, _context.state.current_port_id()):
		MarketMemoryService.remember(_context.state, _context.state.current_port_id())
	_selected_destination = ""
	_selected_strategy = ""
	_active_screen = "overview"
	_set_status("已载入自动存档", false)
	_refresh()


func _on_buy(item_id: String, amount: int) -> void:
	_run_command(&"trade.buy", {"item_id": item_id, "amount": amount})


func _on_sell(item_id: String, amount: int) -> void:
	_run_command(&"trade.sell", {"item_id": item_id, "amount": amount})


func _on_accept_contract(instance_id: String) -> void:
	_run_command(&"contract.accept", {"instance_id": instance_id})


func _on_plan_contract(destination: String) -> void:
	if not _is_neighbor(destination):
		_set_status("目的港不直达，需要先航行到中转港。", true)
		_refresh()
		return
	_selected_destination = destination
	_active_screen = "voyage"
	_status_message = ""
	_refresh()


func _on_install_module(module_id: String) -> void:
	_run_command(&"ship.install_module", {"module_id": module_id})


func _on_buy_coal(amount: int) -> void:
	_run_command(&"supply.buy_coal", {"amount": amount})


func _on_buy_water(amount: int) -> void:
	_run_command(&"supply.buy_water", {"amount": amount})


func _on_repair() -> void:
	_run_command(&"supply.repair", {})


func _on_refresh_intel() -> void:
	_run_command(&"intel.refresh", {})


func _on_borrow() -> void:
	_run_command(&"debt.borrow", {"amount": 400})


func _on_depart() -> void:
	if _selected_destination.is_empty() or _selected_strategy.is_empty():
		_set_status("请选择目的港和锅炉策略。", true)
		_refresh()
		return
	_run_command(&"voyage.start", {"destination_id": _selected_destination, "strategy_id": _selected_strategy})


func _on_event_option(option_id: String) -> void:
	_run_command(&"event.choose_option", {"option_id": option_id})


func _run_command(command: StringName, params: Dictionary) -> void:
	if _context == null:
		return
	var result := _context.commands.execute(command, params)
	if bool(result.get("ok", false)):
		_handle_success(command, result)
	else:
		_set_status(_error_text(result), true)
	_refresh()


func _handle_success(command: StringName, result: Dictionary) -> void:
	var data: Dictionary = result.get("data", {})
	match String(command):
		"run.start":
			_active_screen = "overview"
			_selected_destination = ""
			_selected_strategy = ""
			_set_status("新航程开始 · 种子 %d" % int(data.get("seed", 0)), false)
		"voyage.start":
			_handle_voyage_result(data)
		"event.choose_option":
			if bool(data.get("failed", false)):
				_active_screen = "overview"
				_set_status("航行失败，已恢复到出航前状态。", true)
			else:
				_full_stop_after_voyage(data)
		"trade.buy":
			_set_status("买入 %s ×%d，花费 %d 金币。" % [
				_item_name(String(data.get("item_id", ""))),
				int(data.get("amount", 0)),
				int(data.get("total", 0)),
			], false)
		"trade.sell":
			_set_status("卖出 %s ×%d，收入 %d 金币。" % [
				_item_name(String(data.get("item_id", ""))),
				int(data.get("amount", 0)),
				int(data.get("revenue", 0)),
			], false)
		"supply.buy_coal", "supply.buy_water":
			var supply_kind := "ui.label.coal" if String(data.get("kind", "")) == "coal" else "ui.label.water"
			_set_status("已购买%s ×%d，花费 %d 金币。" % [
				_tr(supply_kind, ""),
				int(data.get("amount", 0)),
				int(data.get("total", 0)),
			], false)
		"supply.repair":
			_set_status("维修完成，花费 %d 金币。" % int(data.get("cost", 0)), false)
		"ship.install_module":
			_set_status("已安装 %s，花费 %d 金币。" % [
				_module_name(String(data.get("module_id", ""))),
				int(data.get("price", 0)),
			], false)
		"contract.accept":
			var contract: Dictionary = data.get("contract", {})
			_set_status("已接受委托：%s" % _tr(String(contract.get("name_key", "")), String(contract.get("template_id", ""))), false)
		"intel.refresh":
			_set_status("情报已刷新 · %s" % String(data.get("generated_label", "")), false)
		"debt.borrow":
			_set_status("已借款 %d，到期需偿还 %s。" % [
				int(data.get("principal", 0)),
				_fmt(float(data.get("total_due", 0.0))),
			], false)
		_:
			_set_status("", false)


func _handle_voyage_result(data: Dictionary) -> void:
	if bool(data.get("arrived", false)):
		_full_stop_after_voyage(data)
		return
	if data.get("event", null) is Dictionary:
		_active_screen = "voyage"
		_set_status("航行中遭遇事件，请选择处理方案。", false)


func _full_stop_after_voyage(data: Dictionary) -> void:
	_active_screen = "overview"
	var summary: Variant = data.get("summary", data.get("event_result", null))
	if summary is Dictionary:
		_set_status(_arrival_message(summary), false)
	else:
		_set_status("已抵达目的港。", false)


func _arrival_message(summary: Dictionary) -> String:
	var parts := PackedStringArray()
	var destination := String(summary.get("destination", ""))
	parts.append("抵达 %s" % (_port_name(destination) if not destination.is_empty() else "目的港"))
	var contracts: Array = summary.get("contracts", [])
	if not contracts.is_empty():
		var payout := 0
		var on_time := 0
		for contract in contracts:
			if contract is Dictionary:
				payout += int(contract.get("payout", 0))
				if bool(contract.get("on_time", false)):
					on_time += 1
		parts.append("交付 %d 个委托" % contracts.size())
		parts.append("收入 %d 金币" % payout)
		if on_time > 0:
			parts.append("准时 %d 个" % on_time)
	var injuries := int(summary.get("injuries", 0))
	if injuries > 0:
		parts.append("旅客受伤 %d 人" % injuries)
	return " · ".join(parts)


## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------

func _resolve_context() -> AppContext:
	var active := AppContext.get_active()
	if active != null:
		return active
	var autoload := get_node_or_null("/root/AppBootstrap")
	if autoload != null and autoload.context != null:
		return autoload.context
	return null


func _set_status(message: String, is_error: bool) -> void:
	_status_message = message
	_status_is_error = is_error


func _retry_bootstrap() -> void:
	var boot := Bootstrap.new()
	var report := boot.run()
	AppContext.set_active(boot.context)
	_context = boot.context
	_set_status("" if not report.has_fatal() else _tr("ui.error.start_failed", ""), report.has_fatal())
	_refresh()


func _show_diagnostics() -> void:
	if _context == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = _tr("ui.button.log", "Diagnostics")
	dialog.dialog_text = _context.report.format_text() + "\n\ncommands: " + ", ".join(_context.commands.names()) + "\n\n" + _context.logger.to_text()
	dialog.ok_button_text = _tr("ui.button.close", "Close")
	add_child(dialog)
	dialog.popup_centered(Vector2i(1000, 700))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _error_text(result: Dictionary) -> String:
	var message_key := String(result.get("message_key", ""))
	var error_code := String(result.get("error_code", ""))
	return _tr(message_key, error_code)


func _tr(key: String, fallback: String = "") -> String:
	if _context == null:
		return fallback if not fallback.is_empty() else key
	return _context.translate(key, fallback)


func _label(text: String, font_size: int = 15, color: Color = COLOR_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(callback)
	return button


func _small_button(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.add_theme_font_size_override("font_size", 12)
	button.custom_minimum_size = Vector2(30, 26)
	return button


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)
	return panel


func _panel_add(panel: PanelContainer, node: Node) -> void:
	var content := panel.get_node_or_null("Content")
	if content is VBoxContainer:
		content.add_child(node)
	else:
		panel.add_child(node)


func _kv_row(label_text: String, value_text: String, value_color: Color = COLOR_TEXT) -> Control:
	var row := HBoxContainer.new()
	var key := _label(label_text, 13, COLOR_MUTED)
	key.custom_minimum_size = Vector2(120, 0)
	row.add_child(key)
	var value := _label(value_text, 13, value_color)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value)
	return row


func _fmt(value: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f") % value


func _facility_name(facility: String) -> String:
	var names := {
		"exchange": "交易所",
		"contracts": "港务承运局",
		"supply": "补给码头",
		"shipyard": "造船厂",
		"intel": "情报站",
	}
	return names.get(facility, facility)


func _trend_text(trend: String) -> String:
	if trend.is_empty():
		return "—"
	return _tr("intel.trend.%s" % trend, trend)


func _trend_color(trend: String) -> Color:
	match trend:
		"up":
			return COLOR_RED
		"down":
			return COLOR_GREEN
		_:
			return COLOR_MUTED


func _age_text(age_hours: float) -> String:
	if age_hours < 0.5:
		return "刚刚刷新"
	return "%s 小时前" % _fmt(age_hours)


func _definition_name(definition_id: String) -> String:
	for content_type in ContentTypes.all():
		var definition := _context.registries.get_by_id(content_type, definition_id)
		if definition != null:
			return _tr(definition.name_key, definition_id)
	return definition_id


func _item_name(item_id: String) -> String:
	var definition := ShipOps.item_definition(_context.registries, item_id)
	return _tr(definition.name_key, item_id) if definition != null else item_id


func _module_name(module_id: String) -> String:
	var content_type := ShipOps.module_type(_context.registries, module_id)
	var definition := _context.registries.get_by_id(content_type, module_id) if content_type != &"" else null
	return _tr(definition.name_key, module_id) if definition != null else module_id


func _port_name(port_id: String) -> String:
	var map_result := _context.queries.execute(&"map.view")
	if bool(map_result.get("ok", false)):
		for port in map_result["data"].get("ports", []):
			if String(port.get("id", "")) == port_id:
				return _tr(String(port.get("name_key", "")), port_id)
	return port_id


func _value_name(port: Dictionary, fallback: String) -> String:
	return _tr(String(port.get("name_key", "")), fallback)


func _standard_strategy_id() -> String:
	for strategy in _context.registries.get_all(ContentTypes.STRATEGY):
		if strategy.has_tag("strategy.standard"):
			return strategy.id
	var strategies := _context.registries.get_all(ContentTypes.STRATEGY)
	return strategies[0].id if not strategies.is_empty() else ""


func _neighbor_ids() -> Array[String]:
	var result: Array[String] = []
	for destination in _last_port_view.get("destinations", []):
		result.append(String(destination.get("port_id", "")))
	return result


func _is_neighbor(port_id: String) -> bool:
	return _neighbor_ids().has(port_id)


func _destination_exists(destinations: Array, port_id: String) -> bool:
	for destination in destinations:
		if String(destination.get("port_id", "")) == port_id:
			return true
	return false


class MapCanvas:
	extends Control

	signal port_clicked(port_id: String)

	var ports: Array = []
	var routes: Array = []
	var labels: Dictionary = {}

	var _hovered_port: String = ""
	var _positions: Dictionary = {}

	func _draw() -> void:
		_layout()
		if ports.is_empty():
			return
		for route in routes:
			var from_id := String(route.get("a", ""))
			var to_id := String(route.get("b", ""))
			if _positions.has(from_id) and _positions.has(to_id):
				draw_line(_positions[from_id], _positions[to_id], Color(0.35, 0.45, 0.52, 0.75), 2.0)
		var font := get_theme_default_font()
		for port in ports:
			var port_id := String(port.get("id", ""))
			if not _positions.has(port_id):
				continue
			var position: Vector2 = _positions[port_id]
			var color := Color(0.4, 0.48, 0.54)
			if bool(port.get("current", false)):
				color = Color("f0c674")
			elif bool(port.get("visited", false)):
				color = Color("7fc8e8")
			elif bool(port.get("discovered", false)):
				color = Color("8fd694")
			draw_circle(position, 10.0, color)
			draw_circle(position, 4.0, Color("0b1116"))
			if port_id == _hovered_port:
				draw_arc(position, 15.0, 0.0, TAU, 32, Color("f0c674"), 2.0)
			var label := String(labels.get(port_id, port_id))
			draw_string(font, position + Vector2(-50.0, 28.0), label, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 13, Color("d7e3ea"))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var port_id := _port_at(event.position)
			if not port_id.is_empty():
				port_clicked.emit(port_id)
				accept_event()
			return
		if event is InputEventMouseMotion:
			var port_id := _port_at(event.position)
			if port_id != _hovered_port:
				_hovered_port = port_id
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not port_id.is_empty() else Control.CURSOR_ARROW
				queue_redraw()

	func _layout() -> void:
		_positions = {}
		if ports.is_empty() or size.x <= 1.0 or size.y <= 1.0:
			return
		var min_x := 0.0
		var max_x := 0.0
		var min_y := 0.0
		var max_y := 0.0
		var first := true
		for port in ports:
			var x := float(port.get("x", 0.0))
			var y := float(port.get("y", 0.0))
			if first:
				min_x = x
				max_x = x
				min_y = y
				max_y = y
				first = false
			else:
				min_x = minf(min_x, x)
				max_x = maxf(max_x, x)
				min_y = minf(min_y, y)
				max_y = maxf(max_y, y)
		var width := maxf(1.0, max_x - min_x)
		var height := maxf(1.0, max_y - min_y)
		var scale_value := minf((size.x - 160.0) / width, (size.y - 100.0) / height)
		scale_value = clampf(scale_value, 0.2, 2.0)
		var center := size * 0.5
		var origin := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
		for port in ports:
			_positions[String(port.get("id", ""))] = center + (Vector2(float(port.get("x", 0.0)), float(port.get("y", 0.0))) - origin) * scale_value

	func _port_at(position: Vector2) -> String:
		_layout()
		var best := ""
		var best_distance := 18.0
		for port in ports:
			if not bool(port.get("visited", false)):
				continue
			var port_id := String(port.get("id", ""))
			if not _positions.has(port_id):
				continue
			var distance := position.distance_to(_positions[port_id])
			if distance <= best_distance:
				best = port_id
				best_distance = distance
		return best

