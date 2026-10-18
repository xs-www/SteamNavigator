extends Control
## Minimal playable shell for the framework slice.
##
## The UI only reads ViewModels through QueryBus and mutates through
## CommandBus. All panels are rebuilt from plain dictionaries after each
## command; there is no direct GameState access for rule decisions.

const COLOR_BG := Color("0b1116")
const COLOR_PANEL := Color("16212a")
const COLOR_PANEL_ALT := Color("1d2a34")
const COLOR_TEXT := Color("d7e3ea")
const COLOR_MUTED := Color("8b9aa5")
const COLOR_BRASS := Color("f0c674")
const COLOR_TEAL := Color("7fc8e8")
const COLOR_RED := Color("e8837f")
const COLOR_GREEN := Color("8fd694")

var _context: AppContext = null
var _root_box: VBoxContainer = null
var _busy: bool = false

var _selected_build: String = ""
var _selected_destination: String = ""
var _selected_strategy: String = ""
var _selected_module: String = ""
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
		result.set_stylebox(state, "Button", _style(color, 6))
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 10)
	return result


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
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
	var port_view := _context.queries.execute(&"port.view")
	if not bool(port_view.get("ok", false)):
		_root_box.add_child(_label(_error_text(port_view), 18, COLOR_RED))
		return
	_build_game(port_view["data"], app)


func _resolve_context() -> AppContext:
	var active := AppContext.get_active()
	if active != null:
		return active
	var autoload := get_node_or_null("/root/AppBootstrap")
	if autoload != null and autoload.context != null:
		return autoload.context
	return null


func _build_header(app: Dictionary) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(header)
	var title := _label(_tr("ui.app.title", "Steam Navigator"), 24, COLOR_BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label(_tr(String(app.get("status_key", "ui.status.ok")), ""), 14, _status_color(app)))
	header.add_child(_label("v%s" % app.get("framework_version", "?"), 13, COLOR_MUTED))
	var diagnostics := _button(_tr("ui.button.log", "Diagnostics"), _show_diagnostics)
	header.add_child(diagnostics)
	if bool(app.get("has_run", false)):
		var refresh := _button(_tr("ui.button.refresh", "Refresh"), _refresh)
		header.add_child(refresh)
	_root_box.add_child(HSeparator.new())
	if not _status_message.is_empty():
		_root_box.add_child(_label(_status_message, 14, COLOR_RED if _status_is_error else COLOR_GREEN))


func _status_color(app: Dictionary) -> Color:
	match String(app.get("status", "fatal")):
		"ok":
			return COLOR_GREEN
		"degraded":
			return COLOR_BRASS
		_:
			return COLOR_RED


func _build_menu(app: Dictionary) -> void:
	var report: Dictionary = app.get("report", {})
	if not report.get("errors", []).is_empty():
		var error_panel := _panel()
		_panel_add(error_panel, _label(_tr("ui.error.start_failed", "Startup failed"), 18, COLOR_RED))
		for entry in report.get("errors", []):
			_panel_add(error_panel, _label("[%s] %s" % [entry.get("severity", "error"), entry.get("message", "")], 14, COLOR_RED))
		_root_box.add_child(error_panel)
		var retry := _button(_tr("ui.button.retry", "Retry"), _retry_bootstrap)
		_root_box.add_child(retry)
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


func _build_game(data: Dictionary, _app: Dictionary) -> void:
	var stats := _stats_bar(data)
	_root_box.add_child(stats)
	var at_sea := bool(data.get("at_sea", false))
	var voyage: Variant = data.get("voyage", null)
	if at_sea and voyage is Dictionary and voyage.get("event", null) is Dictionary:
		_root_box.add_child(_event_panel(voyage["event"]))
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
	right.custom_minimum_size = Vector2(380, 0)
	columns.add_child(right)

	left.add_child(_port_panel(data))
	left.add_child(_market_panel(data))
	left.add_child(_contract_panel(data))
	right.add_child(_ship_panel(data))
	right.add_child(_shipyard_panel(data))
	right.add_child(_intel_panel(data))
	if not at_sea:
		_root_box.add_child(_voyage_panel(data))
	else:
		var waiting := _panel()
		_panel_add(waiting, _label(_tr("ui.label.voyage", "Voyage") + " · at sea", 16, COLOR_TEAL))
		if voyage is Dictionary:
			_panel_add(waiting, _label("%s → %s" % [
				_tr(String(voyage.get("origin", "")), String(voyage.get("origin", ""))),
				_tr(String(voyage.get("destination", "")), String(voyage.get("destination", ""))),
			], 14, COLOR_TEXT))
		_root_box.add_child(waiting)
	_root_box.add_child(_notices_panel(data))


func _stats_bar(data: Dictionary) -> Control:
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
	return panel


func _map_panel() -> Control:
	var panel := _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var map_view := _context.queries.execute(&"map.view")
	if not bool(map_view.get("ok", false)):
		_panel_add(panel, _label(_error_text(map_view), 14, COLOR_RED))
		return panel
	var map_data: Dictionary = map_view["data"]
	var canvas := MapCanvas.new()
	canvas.custom_minimum_size = Vector2(0, 250)
	canvas.ports = map_data.get("ports", [])
	canvas.routes = map_data.get("routes", [])
	canvas.labels = {}
	for port in canvas.ports:
		canvas.labels[String(port.get("id", ""))] = _tr(String(port.get("name_key", "")), String(port.get("id", "")))
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if data.get("debt", null) is Dictionary:
		var debt: Dictionary = data["debt"]
		_panel_add(panel, _label("债务剩余: %s（到期 %s）" % [
			_fmt(float(debt.get("remaining", 0.0))),
			ClockService.format_time(float(debt.get("due_time", 0.0))),
		], 13, COLOR_RED))
	return panel


func _market_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label(_tr("ui.label.market", "Market"), 17, COLOR_BRASS))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for heading in ["商品", "单价", "库存", "货重", "持有", _tr("ui.button.buy", "Buy"), _tr("ui.button.sell", "Sell")]:
		grid.add_child(_label(heading, 12, COLOR_MUTED))
	for row in data.get("market", []):
		grid.add_child(_label(_tr(String(row.get("name_key", "")), String(row.get("item_id", ""))), 13, COLOR_TEXT))
		grid.add_child(_label(str(int(row.get("price", 0))), 13, COLOR_TEAL))
		grid.add_child(_label(str(int(row.get("stock", 0))), 13, COLOR_TEXT))
		grid.add_child(_label(_fmt(float(row.get("unit_weight", 0.0))), 13, COLOR_MUTED))
		grid.add_child(_label(str(int(row.get("cargo_amount", 0))), 13, COLOR_TEXT))
		var buy_row := HBoxContainer.new()
		buy_row.add_theme_constant_override("separation", 2)
		buy_row.add_child(_small_button("1", _on_buy.bind(String(row.get("item_id", "")), 1)))
		buy_row.add_child(_small_button("5", _on_buy.bind(String(row.get("item_id", "")), 5)))
		grid.add_child(buy_row)
		var sell_row := HBoxContainer.new()
		sell_row.add_theme_constant_override("separation", 2)
		sell_row.add_child(_small_button("1", _on_sell.bind(String(row.get("item_id", "")), 1)))
		sell_row.add_child(_small_button("5", _on_sell.bind(String(row.get("item_id", "")), 5)))
		grid.add_child(sell_row)
	_panel_add(panel, grid)
	return panel


func _contract_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label("委托", 17, COLOR_BRASS))
	var contracts: Dictionary = data.get("contracts", {})
	var main_contract: Variant = contracts.get("main", null)
	if main_contract is Dictionary:
		_panel_add(panel, _contract_line(main_contract, "主线"))
	var main_offer: Variant = contracts.get("main_offer", null)
	if main_offer is Dictionary:
		_panel_add(panel, _contract_line(main_offer, "可接主线", true))
	for offer in contracts.get("offers", []):
		_panel_add(panel, _contract_line(offer, "普通", true))
	for active in contracts.get("active", []):
		_panel_add(panel, _contract_line(active, "普通", false))
	return panel


func _contract_line(contract: Dictionary, tag: String, can_accept: bool = false) -> Control:
	var row := HBoxContainer.new()
	var text := "%s · %s → %s · %s" % [
		tag,
		_tr(String(contract.get("name_key", "")), String(contract.get("template_id", ""))),
		_tr(String(contract.get("destination_name_key", "")), String(contract.get("destination", ""))),
		String(contract.get("deadline_label", "")),
	]
	var label := _label(text, 13, COLOR_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	if can_accept:
		row.add_child(_small_button("接受", _on_accept_contract.bind(String(contract.get("instance_id", "")))))
	return row


func _ship_panel(data: Dictionary) -> Control:
	var panel := _panel()
	var ship: Dictionary = data.get("ship", {})
	_panel_add(panel, _label("船只", 17, COLOR_BRASS))
	_panel_add(panel, _label("航速 %s · 煤耗 %s/h · 水耗 %s/h" % [
		_fmt(float(ship.get("speed", 0.0)), 2),
		_fmt(float(ship.get("coal_rate", 0.0)), 2),
		_fmt(float(ship.get("water_rate", 0.0)), 2),
	], 13, COLOR_MUTED))
	_panel_add(panel, _label("货舱 %s / %s · 旅客 %d / %d" % [
		_fmt(float(ship.get("cargo_used", 0.0))),
		_fmt(float(ship.get("cargo_capacity", 0.0))),
		int(ship.get("passengers", 0)),
		int(ship.get("passenger_capacity", 0)),
	], 13, COLOR_MUTED))
	for module in ship.get("modules", []):
		_panel_add(panel, _label("· %s" % _tr(String(module.get("name_key", "")), String(module.get("module_id", ""))), 13, COLOR_TEXT))
	var cargo: Array = ship.get("cargo", [])
	if not cargo.is_empty():
		var cargo_names := PackedStringArray()
		for stack in cargo:
			cargo_names.append("%s ×%d" % [_tr(String(stack.get("name_key", "")), String(stack.get("item_id", ""))), int(stack.get("amount", 0))])
		_panel_add(panel, _label("装载: " + ", ".join(cargo_names), 12, COLOR_MUTED))
	return panel


func _shipyard_panel(data: Dictionary) -> Control:
	var panel := _panel()
	var port: Dictionary = data.get("current_port", {})
	if not Array(port.get("facilities", [])).has("shipyard"):
		return panel
	_panel_add(panel, _label("船厂", 17, COLOR_BRASS))
	var available: Array = []
	for content_type in [ContentTypes.CARGO_MODULE, ContentTypes.NAVIGATION_MODULE, ContentTypes.SAFETY_MODULE, ContentTypes.CABIN, ContentTypes.HULL, ContentTypes.BOILER]:
		for module in _context.registries.get_all(content_type):
			if int(module.data.get("unlock_reputation", 0)) > int(data.get("reputation", 0)):
				continue
			available.append(module)
	if available.is_empty():
		_panel_add(panel, _label("暂无可安装模块", 13, COLOR_MUTED))
		return panel
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_index := 0
	for index in available.size():
		var module: ContentDefinition = available[index]
		option.add_item("%s · %d 金币" % [_tr(module.name_key, module.id), int(module.data.get("purchase_price", 0))])
		option.set_item_metadata(index, module.id)
		if module.id == _selected_module:
			selected_index = index
	option.select(selected_index)
	_selected_module = String(option.get_item_metadata(selected_index))
	option.item_selected.connect(func(index: int) -> void:
		_selected_module = String(option.get_item_metadata(index))
	)
	_panel_add(panel, option)
	_panel_add(panel, _button("购买并安装", _on_install_module))
	return panel


func _intel_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label("情报", 17, COLOR_BRASS))
	var intel: Dictionary = data.get("intelligence", {})
	var generated := String(intel.get("generated_label", ""))
	if generated.is_empty():
		_panel_add(panel, _label("尚无情报快照", 13, COLOR_MUTED))
	else:
		_panel_add(panel, _label("%s · %s 前" % [generated, _fmt(float(intel.get("age_hours", 0.0)))], 12, COLOR_MUTED))
	var port: Dictionary = data.get("current_port", {})
	if Array(port.get("facilities", [])).has("intel"):
		_panel_add(panel, _button("刷新情报（25 金币）", _on_refresh_intel))
	_panel_add(panel, _button("借款 400（10% 利息）", _on_borrow))
	return panel


func _voyage_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label(_tr("ui.label.preview", "Voyage preview"), 17, COLOR_BRASS))
	var destinations: Array = data.get("destinations", [])
	var strategies: Array = data.get("strategies", [])
	if destinations.is_empty() or strategies.is_empty():
		_panel_add(panel, _label("无可用航线", 13, COLOR_MUTED))
		return panel
	var row := HBoxContainer.new()
	var destination_option := OptionButton.new()
	destination_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var destination_index := 0
	for index in destinations.size():
		var destination: Dictionary = destinations[index]
		var known := "?" if not bool(destination.get("facilities_known", false)) else ""
		destination_option.add_item("%s · %.0f 海里 %s" % [
			_tr(String(destination.get("name_key", "")), String(destination.get("port_id", ""))),
			float(destination.get("distance", 0.0)),
			known,
		])
		destination_option.set_item_metadata(index, String(destination.get("port_id", "")))
		if String(destination.get("port_id", "")) == _selected_destination:
			destination_index = index
	if _selected_destination.is_empty():
		_selected_destination = String(destinations[0].get("port_id", ""))
	destination_option.select(destination_index)
	destination_option.item_selected.connect(_on_destination_selected.bind(destination_option))
	row.add_child(destination_option)
	var strategy_option := OptionButton.new()
	if _selected_strategy.is_empty():
		for strategy in strategies:
			if Array(strategy.get("tags", [])).has("strategy.standard"):
				_selected_strategy = String(strategy.get("id", ""))
		if _selected_strategy.is_empty():
			_selected_strategy = String(strategies[0].get("id", ""))
	var strategy_index := 0
	for index in strategies.size():
		var strategy: Dictionary = strategies[index]
		strategy_option.add_item(_tr(String(strategy.get("name_key", "")), String(strategy.get("id", ""))))
		strategy_option.set_item_metadata(index, String(strategy.get("id", "")))
		if String(strategy.get("id", "")) == _selected_strategy:
			strategy_index = index
	strategy_option.select(strategy_index)
	strategy_option.item_selected.connect(_on_strategy_selected.bind(strategy_option))
	row.add_child(strategy_option)
	row.add_child(_small_button(_tr("ui.button.refresh", "Refresh"), _refresh))
	_panel_add(panel, row)

	var preview := _context.queries.execute(&"voyage.preview", {
		"destination_id": _selected_destination,
		"strategy_id": _selected_strategy,
	})
	if not bool(preview.get("ok", false)):
		_panel_add(panel, _label(_error_text(preview), 13, COLOR_RED))
		return panel
	var p: Dictionary = preview["data"]
	var lines := PackedStringArray()
	lines.append("耗时 %s · 抵达 %s" % [_duration(float(p.get("duration_hours", 0.0))), ClockService.format_time(float(p.get("arrival_time", 0.0)))])
	lines.append("煤 %s / %s · 水 %s / %s · 重量 %s / %s（速度系数 %s）" % [
		_fmt(float(p.get("coal_required", 0.0))), _fmt(float(p.get("coal_available", 0.0))),
		_fmt(float(p.get("water_required", 0.0))), _fmt(float(p.get("water_available", 0.0))),
		_fmt(float(p.get("total_weight", 0.0))), _fmt(float(p.get("max_weight", 0.0))),
		_fmt(float(p.get("weight_factor", 1.0)), 2),
	])
	if p.get("deadline", -1.0) >= 0.0:
		lines.append("委托期限 %s · %s" % [
			ClockService.format_time(float(p.get("deadline", 0.0))),
			"预计准时" if bool(p.get("on_time", false)) else "预计迟到",
		])
	var risk_names := PackedStringArray()
	for source in p.get("risk_sources", []):
		risk_names.append("%s %+.3f" % [_tr(String(source.get("key", "")), String(source.get("key", ""))), float(source.get("value", 0.0))])
	lines.append("风险来源（不显示概率）: " + (", ".join(risk_names) if not risk_names.is_empty() else "—"))
	lines.append("情报时间: %s" % ("无" if float(p.get("intel_generated_at", -1.0)) < 0.0 else ClockService.format_time(float(p.get("intel_generated_at", 0.0)))))
	var body := _label("\n".join(lines), 13, COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_add(panel, body)
	if not p.get("blockers", []).is_empty():
		var blocker_text := PackedStringArray()
		for blocker in p.get("blockers", []):
			blocker_text.append(_tr(String(blocker.get("message_key", "")), String(blocker.get("code", ""))))
		_panel_add(panel, _label("无法出航: " + ", ".join(blocker_text), 13, COLOR_RED))
	var depart := _button(_tr("ui.button.depart", "Depart"), _on_depart)
	depart.disabled = not bool(p.get("feasible", false))
	_panel_add(panel, depart)
	return panel


func _event_panel(event: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label(_tr(String(event.get("name_key", "")), String(event.get("event_id", ""))), 20, COLOR_RED))
	var description_key := String(event.get("description_key", ""))
	if not description_key.is_empty():
		_panel_add(panel, _label(_tr(description_key, ""), 14, COLOR_TEXT))
	for option in event.get("options", []):
		var option_id := String(option.get("id", ""))
		_panel_add(panel, _button(_tr(String(option.get("name_key", "")), option_id), _on_event_option.bind(option_id)))
	return panel


func _notices_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _label("航行记录", 14, COLOR_MUTED))
	var notices: Array = data.get("notices", [])
	if notices.is_empty():
		_panel_add(panel, _label("—", 13, COLOR_MUTED))
	for notice in notices.slice(maxi(0, notices.size() - 5), notices.size()):
		_panel_add(panel, _label("· %s" % _tr(String(notice.get("text_key", "")), ""), 13, COLOR_TEXT))
	return panel


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
	_run_command(&"run.start", {"build_id": _selected_build, "seed": seed})


func _on_continue() -> void:
	var loaded := _context.save.load_autosave()
	if not bool(loaded.get("ok", false)):
		_set_status(String(loaded.get("error", "load failed")), true)
		return
	var validation := _context.save.validate_mods(loaded.get("header", {}), _context.mod_summaries())
	if not bool(validation.get("ok", false)):
		_set_status(", ".join(validation.get("errors", [])), true)
		return
	_context.set_state(loaded["state"])
	_context.set_seed(_context.state.seed())
	_selected_destination = ""
	_set_status("已载入自动存档", false)
	_refresh()


func _on_buy(item_id: String, amount: int) -> void:
	_run_command(&"trade.buy", {"item_id": item_id, "amount": amount})


func _on_sell(item_id: String, amount: int) -> void:
	_run_command(&"trade.sell", {"item_id": item_id, "amount": amount})


func _on_accept_contract(instance_id: String) -> void:
	_run_command(&"contract.accept", {"instance_id": instance_id})


func _on_depart() -> void:
	_set_status("", false)
	_run_command(&"voyage.start", {"destination_id": _selected_destination, "strategy_id": _selected_strategy})


func _on_event_option(option_id: String) -> void:
	_run_command(&"event.choose_option", {"option_id": option_id})


func _on_refresh_intel() -> void:
	_run_command(&"intel.refresh", {})


func _on_borrow() -> void:
	_run_command(&"debt.borrow", {"amount": 300})


func _on_install_module() -> void:
	if _selected_module.is_empty():
		_set_status("请选择模块", true)
		return
	_run_command(&"ship.install_module", {"module_id": _selected_module})


func _run_command(command: StringName, params: Dictionary) -> void:
	if _context == null:
		return
	var result := _context.commands.execute(command, params)
	if bool(result.get("ok", false)):
		_set_status("", false)
	else:
		_set_status(_error_text(result), true)
	_refresh()


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


func _fmt(value: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f") % value


func _duration(hours: float) -> String:
	return ClockService.format_duration(hours)


func _facility_name(facility: String) -> String:
	var names := {
		"exchange": "交易所",
		"contracts": "港务承运局",
		"supply": "补给码头",
		"shipyard": "造船厂",
		"intel": "情报站",
	}
	return names.get(facility, facility)


class MapCanvas:
	extends Control

	var ports: Array = []
	var routes: Array = []
	var labels: Dictionary = {}

	func _draw() -> void:
		if ports.is_empty():
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
		var scale_value := minf((size.x - 120.0) / width, (size.y - 80.0) / height)
		scale_value = clampf(scale_value, 0.2, 2.0)
		var center := size * 0.5
		var origin := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
		var positions := {}
		for port in ports:
			positions[String(port.get("id", ""))] = center + (Vector2(float(port.get("x", 0.0)), float(port.get("y", 0.0))) - origin) * scale_value
		for route in routes:
			var from_id := String(route.get("a", ""))
			var to_id := String(route.get("b", ""))
			if positions.has(from_id) and positions.has(to_id):
				draw_line(positions[from_id], positions[to_id], Color(0.35, 0.45, 0.52, 0.7), 2.0)
		var font := get_theme_default_font()
		for port in ports:
			var port_id := String(port.get("id", ""))
			if not positions.has(port_id):
				continue
			var position: Vector2 = positions[port_id]
			var color := Color(0.4, 0.48, 0.54)
			if bool(port.get("current", false)):
				color = Color("f0c674")
			elif bool(port.get("visited", false)):
				color = Color("7fc8e8")
			elif bool(port.get("discovered", false)):
				color = Color("8fd694")
			draw_circle(position, 10.0, color)
			draw_circle(position, 4.0, Color("0b1116"))
			var label := String(labels.get(port_id, port_id))
			draw_string(font, position + Vector2(-40.0, 26.0), label, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 13, Color("d7e3ea"))
