extends Control
## Playable shell for the framework slice.
##
## The UI only reads ViewModels through QueryBus and mutates through
## CommandBus. Each major function has its own screen; the shell owns
## navigation, the header, and transient selection state only.

const UI_THEME := preload("res://assets/ui/theme/steam_navigator_theme.tres")
const MARKET_SCREEN_SCENE := preload("res://framework/ui/screens/port/market_screen.tscn")
const CONTRACTS_SCREEN_SCENE := preload("res://framework/ui/screens/port/contracts_screen.tscn")
const SUPPLY_SCREEN_SCENE := preload("res://framework/ui/screens/port/supply_screen.tscn")
const INTEL_SCREEN_SCENE := preload("res://framework/ui/screens/port/intel_screen.tscn")
const VOYAGE_SCREEN_SCENE := preload("res://framework/ui/screens/port/voyage_screen.tscn")
const OVERVIEW_SCREEN_SCENE := preload("res://framework/ui/screens/port/overview_screen.tscn")
const SHIPYARD_SCREEN_SCENE := preload("res://framework/ui/screens/port/shipyard_screen.tscn")
const PORT_MEMORY_SCREEN_SCENE := preload("res://framework/ui/screens/flow/port_memory_screen.tscn")
const SETTLEMENT_SCREEN_SCENE := preload("res://framework/ui/screens/flow/settlement_screen.tscn")
const AT_SEA_SCREEN_SCENE := preload("res://framework/ui/screens/flow/at_sea_screen.tscn")
const EVENT_SCREEN_SCENE := preload("res://framework/ui/screens/flow/event_screen.tscn")
const VICTORY_SCREEN_SCENE := preload("res://framework/ui/screens/flow/victory_screen.tscn")
const MAIN_MENU_SCREEN_SCENE := preload("res://framework/ui/screens/menu/main_menu_screen.tscn")
const NEW_GAME_SCREEN_SCENE := preload("res://framework/ui/screens/menu/new_game_screen.tscn")
const MODS_SCREEN_SCENE := preload("res://framework/ui/screens/menu/mods_screen.tscn")
const SETTINGS_SCREEN_SCENE := preload("res://framework/ui/screens/menu/settings_screen.tscn")
const COLOR_BG := Color("071a1d")
const COLOR_PANEL := Color("10353a")
const COLOR_PANEL_ALT := Color("17464a")
const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_TEAL := Color("76aaa7")
const COLOR_RED := Color("c36b53")
const COLOR_GREEN := Color("76aa8c")
const DEV_TEAM := "PlayThought Team"
const GAME_VERSION_FALLBACK := "0.1.0"

const SCREENS := ["overview", "market", "contracts", "shipyard", "supply", "intel", "voyage"]
var _context: AppContext = null
@onready var _root_box: VBoxContainer = $PageMargin/PageScroll/RootBox
var _last_port_view: Dictionary = {}
var _settings: SettingsService = null
var _settings_applied: bool = false

var _active_screen: String = "overview"
var _menu_screen: String = "main"
var _memory_port_id: String = ""
var _selected_build: String = ""
var _selected_destination: String = ""
var _selected_strategy: String = ""
var _seed_text: String = ""
var _status_message: String = ""
var _status_is_error: bool = false
@onready var _footer_team: Label = $Footer/Team
@onready var _footer_version: Label = $Footer/Version
@onready var _menu_background: TextureRect = $MenuBackground
@onready var _menu_overlay: ColorRect = $MenuOverlay
@onready var _pickup_player: AudioStreamPlayer = $PickupPlayer
var _settlement_summary: Dictionary = {}
var _victory_dismissed: bool = false
var _shipyard_refit: bool = false
var _shipyard_category: String = "hulls"
@onready var _fade_layer: ColorRect = $TransitionLayer
var _transitioning: bool = false
var _pending_transition: bool = false


func _ready() -> void:
	theme = UI_THEME
	_settings = SettingsService.load_settings()
	_refresh()


func _apply_settings_if_needed() -> void:
	if _context == null or _settings == null or _settings_applied:
		return
	_context.localization.set_locale(_settings.locale())
	_context.autosave_enabled = _settings.autosave()
	_settings_applied = true


func _play_pickup() -> void:
	if _pickup_player != null and _pickup_player.stream != null:
		_pickup_player.play()


func _set_menu_visual(enabled: bool) -> void:
	if _menu_background != null:
		_menu_background.visible = enabled
	if _menu_overlay != null:
		_menu_overlay.visible = enabled


func _game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", GAME_VERSION_FALLBACK))


func _refresh_footer() -> void:
	if _footer_team != null:
		_footer_team.text = _tr("ui.menu.team", "开发团队：%s" % DEV_TEAM)
	if _footer_version != null:
		_footer_version.text = "%s v%s" % [_tr("ui.menu.version", "版本"), _game_version()]


func _refresh(animate: bool = false) -> void:
	if _transitioning:
		_pending_transition = true
		return
	if animate and _fade_layer != null:
		_begin_transition()
		return
	_rebuild_ui()


func _begin_transition() -> void:
	_transitioning = true
	_fade_layer.visible = true
	_fade_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_layer.color = Color(COLOR_BG.r, COLOR_BG.g, COLOR_BG.b, 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade_layer, "color:a", 0.96, 0.16)
	tween.tween_callback(func() -> void:
		_rebuild_ui()
		_fade_layer.color.a = 0.96
	)
	tween.tween_property(_fade_layer, "color:a", 0.0, 0.22)
	tween.tween_callback(func() -> void:
		_fade_layer.visible = false
		_fade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transitioning = false
		if _pending_transition:
			_pending_transition = false
			_refresh(true)
	)


func _rebuild_ui() -> void:
	_context = _resolve_context()
	for child in _root_box.get_children():
		_root_box.remove_child(child)
		child.queue_free()
	if _context == null:
		_root_box.add_child(_label("Loading framework...", 20, COLOR_MUTED))
		get_tree().create_timer(0.4).timeout.connect(_refresh)
		return
	_apply_settings_if_needed()
	var app_view := _context.queries.execute(&"app.view")
	if not bool(app_view.get("ok", false)):
		_root_box.add_child(_label(_error_text(app_view), 18, COLOR_RED))
		return
	var app: Dictionary = app_view["data"]
	_refresh_footer()
	var has_run := bool(app.get("has_run", false))
	_set_menu_visual(not has_run)
	if not has_run:
		_build_menu(app)
		return
	_build_header(app)

	var port_result := _context.queries.execute(&"port.view")
	if not bool(port_result.get("ok", false)):
		_root_box.add_child(_label(_error_text(port_result), 18, COLOR_RED))
		return
	var data: Dictionary = port_result["data"]
	_last_port_view = data
	_build_stats_bar(data)

	# The victory summary takes priority over the regular screens until the
	# player explicitly dismisses it. The dismissed flag is UI-session state
	# only and never written to the save.
	var victory := _victory_view()
	if bool(victory.get("achieved", false)) and not _victory_dismissed:
		_build_nav(data)
		_build_status_banner()
		_screen_victory(victory)
		return

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
	if not SCREENS.has(_active_screen) and _active_screen != "port_memory" and _active_screen != "settlement":
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
		"settlement":
			_screen_settlement(data)
		_:
			_screen_overview(data)


## ---------------------------------------------------------------------------
## Header, navigation, menu
## ---------------------------------------------------------------------------

func _build_header(app: Dictionary) -> void:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"SNInsetPanel"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(bar)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	bar.add_child(header)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	brand.add_child(_label("S T E A M   N A V I G A T O R", 9, COLOR_MUTED))
	brand.add_child(_label(_tr("ui.app.title", "Steam Navigator"), 24, COLOR_BRASS))
	header.add_child(_badge(
		_tr(String(app.get("status_key", "ui.status.ok")), ""),
		_status_badge_tone(app)
	))
	header.add_child(_label("v%s" % app.get("framework_version", "?"), 12, COLOR_MUTED))
	var log_button := _button(_tr("ui.button.log", "Diagnostics"), _show_diagnostics)
	log_button.theme_type_variation = &"SNGhostButton"
	header.add_child(log_button)
	var refresh_button := _button(_tr("ui.button.refresh", "Refresh"), _refresh)
	refresh_button.theme_type_variation = &"SNGhostButton"
	header.add_child(refresh_button)


func _status_badge_tone(app: Dictionary) -> int:
	match String(app.get("status", "fatal")):
		"ok":
			return SNBadge.Tone.SUCCESS
		"degraded":
			return SNBadge.Tone.WARNING
		_:
			return SNBadge.Tone.DANGER


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
	panel.theme_type_variation = &"SNElevatedPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_panel_add(panel, row)
	var ship: Dictionary = data.get("ship", {})
	var stats := [
		[_tr("ui.label.port", "Port"), _current_port_label(data), COLOR_BRASS],
		[_tr("ui.label.time", "Time"), String(data.get("time_label", "")), COLOR_TEXT],
		[_tr("ui.label.money", "Money"), str(int(data.get("money", 0))), COLOR_BRASS],
		[_tr("ui.label.reputation", "Reputation"), str(int(data.get("reputation", 0))), COLOR_GREEN],
		[_tr("ui.label.free_weight", ""), "%s / %s" % [
			_fmt(float(ship.get("free_weight", 0.0))),
			_fmt(float(ship.get("max_weight", 0.0))),
		], COLOR_TEXT],
		[_tr("ui.label.free_capacity", ""), "%s / %s" % [
			_fmt(float(ship.get("free_cargo_capacity", 0.0))),
			_fmt(float(ship.get("cargo_capacity", 0.0))),
		], COLOR_TEAL],
		[_tr("ui.label.coal", "Coal"), _fmt(float(ship.get("coal", 0.0))), COLOR_BRASS],
		[_tr("ui.label.water", "Water"), _fmt(float(ship.get("water", 0.0))), COLOR_TEAL],
		[_tr("ui.label.durability", "Durability"), "%s / %s" % [_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0)))], COLOR_GREEN],
	]
	var damaged_modules := int(ship.get("damaged_modules", 0))
	if damaged_modules > 0:
		var worst := clampf(float(ship.get("worst_module_condition", 1.0)), 0.0, 1.0)
		stats.append([
			_tr("ui.label.module_status", "Modules"),
			"%d · %d%%" % [damaged_modules, int(round(worst * 100.0))],
			COLOR_RED if worst <= 0.0 else COLOR_BRASS,
		])
	for index in stats.size():
		if index > 0:
			row.add_child(VSeparator.new())
		row.add_child(_stat_chip(stats[index][0], stats[index][1], stats[index][2]))
	_root_box.add_child(panel)


## Current port (or the destination while at sea) for the always-visible info bar.
func _current_port_label(data: Dictionary) -> String:
	var port: Dictionary = data.get("current_port", {})
	if bool(data.get("at_sea", false)):
		var voyage: Variant = data.get("voyage", null)
		if voyage is Dictionary:
			var destination := String(voyage.get("destination", ""))
			if not destination.is_empty():
				return "%s → %s" % [_tr("ui.label.at_sea", ""), _port_name(destination)]
		return _tr("ui.label.at_sea", "")
	return _tr(String(port.get("name_key", "")), String(port.get("id", "")))


func _stat_chip(label_text: String, value_text: String, accent: Color) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	column.add_child(_label(label_text, 10, COLOR_MUTED))
	column.add_child(_label(value_text, 16, accent))
	return column


func _build_nav(data: Dictionary) -> void:
	var panel := _panel()
	panel.theme_type_variation = &"SNInsetPanel"
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 2)
	_panel_add(panel, nav)
	var visual_active := "overview" if _active_screen in ["port_memory", "settlement", "victory"] else _active_screen
	for screen in SCREENS:
		var button := _button(_tr("ui.nav.%s" % screen, screen), _on_nav.bind(screen))
		button.custom_minimum_size = Vector2(100, 36)
		button.theme_type_variation = &"SNPrimaryButton" if screen == visual_active else &"SNGhostButton"
		nav.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	var port: Dictionary = data.get("current_port", {})
	nav.add_child(_badge("%s · %s" % [
		_tr("ui.label.port", "Port"),
		_tr(String(port.get("name_key", "")), String(port.get("id", ""))),
	], SNBadge.Tone.NEUTRAL))
	_root_box.add_child(panel)


func _build_status_banner() -> void:
	if _status_message.is_empty():
		return
	var panel := _panel()
	panel.theme_type_variation = &"SNInsetPanel"
	_panel_add(panel, _badge(_status_message, SNBadge.Tone.DANGER if _status_is_error else SNBadge.Tone.SUCCESS))
	_root_box.add_child(panel)


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

	match _menu_screen:
		"new_game":
			_screen_new_game(app)
		"mods":
			_screen_mods(app)
		"settings":
			_screen_settings(app)
		_:
			_screen_main_menu(app)


func _screen_main_menu(app: Dictionary) -> void:
	var vm := app.duplicate(true)
	vm["status_tone"] = _status_badge_tone(app)
	_mount_menu_screen(MAIN_MENU_SCREEN_SCENE, vm)
	_build_status_banner()


func _screen_new_game(app: Dictionary) -> void:
	var vm := app.duplicate(true)
	vm["selected_build"] = _selected_build
	vm["seed_text"] = _seed_text
	vm["warnings"] = app.get("report", {}).get("warnings", [])
	_mount_menu_screen(NEW_GAME_SCREEN_SCENE, vm)
	_build_status_banner()


func _screen_mods(app: Dictionary) -> void:
	_mount_menu_screen(MODS_SCREEN_SCENE, app)
	_build_status_banner()


func _screen_settings(_app: Dictionary) -> void:
	_mount_menu_screen(SETTINGS_SCREEN_SCENE, {
		"locale": _context.localization.active_locale if _context != null else "zh_CN",
		"autosave_enabled": bool(_context.autosave_enabled) if _context != null else true,
		"show_settings_path": _settings != null,
	})
	_build_status_banner()


func _mount_menu_screen(scene: PackedScene, view_model: Dictionary) -> void:
	var screen: Variant = scene.instantiate()
	screen.bind(view_model, Callable(self, "_tr"))
	screen.action_requested.connect(_on_menu_action)
	_root_box.add_child(screen)


## ---------------------------------------------------------------------------
## Overview
## ---------------------------------------------------------------------------

func _screen_overview(data: Dictionary) -> void:
	var screen: Variant = OVERVIEW_SCREEN_SCENE.instantiate()
	screen.bind(_overview_model(data), Callable(self, "_tr"))
	screen.navigation_requested.connect(_on_screen_navigation)
	screen.command_requested.connect(_run_command)
	screen.map_port_clicked.connect(_on_map_port_clicked)
	_root_box.add_child(screen)


func _overview_model(data: Dictionary) -> Dictionary:
	var model := data.duplicate(true)
	var port: Dictionary = data.get("current_port", {})
	var facilities: Array = []
	for facility in port.get("facilities", []):
		facilities.append(_facility_name(String(facility)))
	model["facility_labels"] = facilities
	model["banner_path"] = ""
	var banner_key := String(port.get("banner_asset", ""))
	var source_mod := String(port.get("source_mod", ""))
	if not banner_key.is_empty() and not source_mod.is_empty():
		var logical_key := "asset://%s/%s" % [source_mod, banner_key]
		if _context.assets.has(logical_key):
			model["banner_path"] = _context.assets.resolve(logical_key)
	var map_result := _context.queries.execute(&"map.view")
	if bool(map_result.get("ok", false)):
		var map_data: Dictionary = map_result["data"].duplicate(true)
		var labels := {}
		var discovered := 0
		for map_port in map_data.get("ports", []):
			labels[String(map_port.get("id", ""))] = _tr(String(map_port.get("name_key", "")), String(map_port.get("id", "")))
			if bool(map_port.get("visited", false)):
				discovered += 1
		map_data["labels"] = labels
		map_data["discovered"] = discovered
		model["map"] = map_data
	else:
		model["map"] = {"error_text": _error_text(map_result)}
	var contracts: Dictionary = model.get("contracts", {}).duplicate(true)
	for key in ["main", "main_offer"]:
		if contracts.get(key, null) is Dictionary:
			var contract: Dictionary = contracts[key].duplicate(true)
			contract["payload_text"] = _contract_payload_text(contract)
			contract["reward_text"] = _contract_reward_text(contract)
			contracts[key] = contract
	model["contracts"] = contracts
	var notice_texts: Array = []
	var notices: Array = data.get("notices", [])
	for notice in notices.slice(maxi(0, notices.size() - 6), notices.size()):
		notice_texts.append(_notice_text(notice))
	model["notice_texts"] = notice_texts
	return model


## Renders one notice: its localized template filled with the parameters recorded
## by `GameState.push_notice`. Parameters are positional in the order the notice
## was pushed, which is the order every `ui.notice.*` template is written for;
## string parameters are themselves localization keys (port / module / build
## names) and get translated first. A template whose slots do not line up with its
## parameters (count or type) is shown as-is instead of raising a format error on
## every overview refresh.
func _notice_text(notice: Dictionary) -> String:
	var key := String(notice.get("text_key", ""))
	var template := _tr(key, "")
	if template.is_empty():
		return key
	var params: Variant = notice.get("params", null)
	if not (params is Dictionary) or (params as Dictionary).is_empty():
		return template
	var slots := _format_slots(template)
	if slots.is_empty():
		return template
	var args: Array = []
	for value in (params as Dictionary).values():
		if value is String:
			var text := String(value)
			args.append(_tr(text, text))
		else:
			args.append(value)
	if args.size() != slots.size():
		return template
	for index in slots.size():
		if slots[index] == "%d" and not (args[index] is int or args[index] is float):
			return template
	return template % args


## The `%s` / `%d` slots of a format string, in order.
func _format_slots(template: String) -> PackedStringArray:
	var regex := RegEx.new()
	regex.compile("%[sd]")
	var slots := PackedStringArray()
	for match_result in regex.search_all(template):
		slots.append(match_result.get_string(0))
	return slots


## ---------------------------------------------------------------------------
## Market
## ---------------------------------------------------------------------------

func _screen_market(data: Dictionary) -> void:
	var screen: Variant = MARKET_SCREEN_SCENE.instantiate()
	var model := {
		"current_port": data.get("current_port", {}),
		"money": data.get("money", 0),
		"ship": data.get("ship", {}),
		"market": data.get("market", []),
		"trends": _market_trends(),
	}
	screen.bind(model, Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


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
	var model: Dictionary
	if not bool(result.get("ok", false)):
		model = {"error_text": _error_text(result)}
	else:
		model = result["data"].duplicate(true)
		var facilities: Array = []
		for facility in model.get("facilities", []): facilities.append(_facility_name(String(facility)))
		model["facility_labels"] = facilities
		model["age_text"] = _age_text(float(model.get("age_hours", 0.0)))
	var screen: Variant = PORT_MEMORY_SCREEN_SCENE.instantiate()
	screen.bind(model, Callable(self, "_tr"))
	screen.navigation_requested.connect(_on_screen_navigation)
	_root_box.add_child(screen)


## ---------------------------------------------------------------------------
## Contracts
## ---------------------------------------------------------------------------

func _screen_contracts(data: Dictionary) -> void:
	var screen: Variant = CONTRACTS_SCREEN_SCENE.instantiate()
	screen.bind(_contracts_screen_model(data), Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	screen.navigation_requested.connect(_on_screen_navigation)
	_root_box.add_child(screen)


func _contracts_screen_model(data: Dictionary) -> Dictionary:
	var contracts: Dictionary = data.get("contracts", {}).duplicate(true)
	for key in ["main", "main_offer"]:
		if contracts.get(key, null) is Dictionary:
			contracts[key] = _enrich_contract_for_screen(contracts[key])
	for key in ["offers", "active"]:
		var enriched: Array = []
		for contract in contracts.get(key, []):
			if contract is Dictionary:
				enriched.append(_enrich_contract_for_screen(contract))
		contracts[key] = enriched
	var completed_names: Array = []
	for contract_id in contracts.get("completed", []):
		completed_names.append(_definition_name(String(contract_id)))
	return {"contracts": contracts, "completed_names": completed_names}


func _enrich_contract_for_screen(contract: Dictionary) -> Dictionary:
	var enriched := contract.duplicate(true)
	enriched["destination_reachable"] = _is_neighbor(String(contract.get("destination", "")))
	var unlock_names: Array = []
	for unlock_id in contract.get("unlock_ids", []):
		unlock_names.append(_definition_name(String(unlock_id)))
	enriched["unlock_names"] = unlock_names
	return enriched


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


## ---------------------------------------------------------------------------
## Shipyard
## ---------------------------------------------------------------------------

func _screen_shipyard(data: Dictionary) -> void:
	var result := _context.queries.execute(&"shipyard.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, COLOR_RED))
		_root_box.add_child(error_panel)
		return
	var screen: Variant = SHIPYARD_SCREEN_SCENE.instantiate()
	screen.refit_mode_changed.connect(func(active: bool): _shipyard_refit = active)
	screen.refit_category_changed.connect(func(category: String): _shipyard_category = category)
	screen.bind(_shipyard_model(result["data"], data), Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


func _shipyard_model(yard: Dictionary, port_data: Dictionary) -> Dictionary:
	var model := yard.duplicate(true)
	model["refit"] = _shipyard_refit
	model["category"] = _shipyard_category
	var ship_model: Dictionary = model.get("ship", {}).duplicate(true)
	ship_model["hull_name"] = _definition_name(String(ship_model.get("hull_id", "")))
	model["ship"] = ship_model
	model["contracts"] = port_data.get("contracts", {}).duplicate(true)
	model["victory"] = port_data.get("victory", {}).duplicate(true)
	var warehouse: Dictionary = model.get("warehouse", {}).duplicate(true)
	var materials: Array = warehouse.get("materials", []).duplicate(true)
	for index in materials.size():
		if materials[index] is Dictionary:
			var material: Dictionary = materials[index].duplicate(true)
			material["ship_amount"] = _cargo_amount_on_ship(String(material.get("item_id", "")))
			materials[index] = material
	warehouse["materials"] = materials
	model["warehouse"] = warehouse
	var candidates: Array = model.get("candidates", []).duplicate(true)
	for index in candidates.size():
		if not (candidates[index] is Dictionary):
			continue
		var candidate: Dictionary = candidates[index].duplicate(true)
		var unlock_id := String(candidate.get("unlock_template_id", ""))
		candidate["unlock_name"] = _definition_name(unlock_id) if not unlock_id.is_empty() else ""
		var replacement: Variant = candidate.get("will_replace", "")
		candidate["replacement_name"] = _module_name(String(replacement)) if replacement is String or replacement is StringName else ""
		candidates[index] = candidate
	model["candidates"] = candidates
	return model




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
	var screen: Variant = SUPPLY_SCREEN_SCENE.instantiate()
	screen.bind(result["data"], Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


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
	var screen: Variant = INTEL_SCREEN_SCENE.instantiate()
	screen.bind(result["data"], Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


## ---------------------------------------------------------------------------
## Voyage planning
## ---------------------------------------------------------------------------

func _screen_voyage(data: Dictionary) -> void:
	var destinations: Array = data.get("destinations", [])
	var strategies: Array = data.get("strategies", [])
	if not destinations.is_empty():
		if _selected_destination.is_empty() or not _destination_exists(destinations, _selected_destination):
			_selected_destination = String(destinations[0].get("port_id", ""))
	if not strategies.is_empty() and _selected_strategy.is_empty():
		_selected_strategy = _standard_strategy_id()
		if _selected_strategy.is_empty():
			_selected_strategy = String(strategies[0].get("id", ""))
	var preview := _context.queries.execute(&"voyage.preview", {
		"destination_id": _selected_destination,
		"strategy_id": _selected_strategy,
	}) if not destinations.is_empty() and not strategies.is_empty() else {"ok": false, "error_text": "没有可用航线或锅炉策略。"}
	if not bool(preview.get("ok", false)):
		preview["error_text"] = _error_text(preview)
	var preview_data: Dictionary = preview.get("data", {})
	var facilities := PackedStringArray()
	for facility in preview_data.get("destination_facilities", []):
		facilities.append(_facility_name(String(facility)))
	var facility_text := "未知"
	if bool(preview_data.get("destination_facilities_known", false)):
		facility_text = ", ".join(facilities) if not facilities.is_empty() else "—"
	var main_contract: Variant = data.get("contracts", {}).get("main", null)
	var model := {
		"destinations": destinations,
		"strategies": strategies,
		"selected_destination": _selected_destination,
		"selected_strategy": _selected_strategy,
		"preview": preview,
		"current_port_name": _value_name(data.get("current_port", {}), ""),
		"is_main_destination": main_contract is Dictionary and String(main_contract.get("destination", "")) == _selected_destination,
		"facility_text": facility_text,
	}
	var screen: Variant = VOYAGE_SCREEN_SCENE.instantiate()
	screen.bind(model, Callable(self, "_tr"))
	screen.selection_changed.connect(_on_voyage_selection_changed)
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


func _on_voyage_selection_changed(destination_id: String, strategy_id: String) -> void:
	_selected_destination = destination_id
	_selected_strategy = strategy_id
	_refresh()


## ---------------------------------------------------------------------------
## At sea and events
## ---------------------------------------------------------------------------

func _screen_settlement(data: Dictionary) -> void:
	if _settlement_summary.is_empty():
		_screen_overview(data)
		return
	var summary := _settlement_summary.duplicate(true)
	var destination := String(summary.get("destination", ""))
	var contracts: Array = summary.get("contracts", []).duplicate(true)
	for index in contracts.size():
		if contracts[index] is Dictionary:
			var contract: Dictionary = contracts[index].duplicate(true)
			var name_key := String(contract.get("name_key", ""))
			contract["display_name"] = _tr(name_key, "") if not name_key.is_empty() else _definition_name(String(contract.get("template_id", "")))
			contracts[index] = contract
	summary["contracts"] = contracts
	var screen: Variant = SETTLEMENT_SCREEN_SCENE.instantiate()
	screen.bind({"summary": summary, "ship": data.get("ship", {}), "money": data.get("money", 0), "destination_name": _port_name(destination) if not destination.is_empty() else "目的港"}, Callable(self, "_tr"))
	screen.navigation_requested.connect(_on_screen_navigation)
	_root_box.add_child(screen)


func _victory_view() -> Dictionary:
	if _context == null or not _context.queries.has(&"victory.view"):
		return {}
	var result := _context.queries.execute(&"victory.view")
	if not bool(result.get("ok", false)):
		return {}
	var view: Variant = result.get("data", {})
	return view if view is Dictionary else {}


func _screen_victory(victory: Dictionary) -> void:
	var screen: Variant = VICTORY_SCREEN_SCENE.instantiate()
	screen.bind(victory, Callable(self, "_tr"))
	screen.action_requested.connect(_on_flow_action)
	_root_box.add_child(screen)


func _on_play_again() -> void:
	if _context == null:
		return
	_context.reset_state()
	_victory_dismissed = false
	_settlement_summary = {}
	_status_message = ""
	_menu_screen = "new_game"
	_active_screen = "overview"
	_refresh(true)


func _on_keep_playing() -> void:
	_victory_dismissed = true
	_status_message = ""
	_refresh(true)


func _on_flow_action(action: StringName, _params: Dictionary) -> void:
	match action:
		&"play_again":
			_on_play_again()
		&"keep_playing":
			_on_keep_playing()


func _screen_at_sea(data: Dictionary, voyage: Variant) -> void:
	var model := {"has_voyage": voyage is Dictionary}
	if voyage is Dictionary:
		model["origin_name"] = _port_name(String(voyage.get("origin", "")))
		model["destination_name"] = _port_name(String(voyage.get("destination", "")))
		model["arrival_time"] = voyage.get("arrival_time", 0.0)
	var screen: Variant = AT_SEA_SCREEN_SCENE.instantiate()
	screen.bind(model, Callable(self, "_tr"))
	_root_box.add_child(screen)


func _screen_event(data: Dictionary, event: Dictionary) -> void:
	var screen: Variant = EVENT_SCREEN_SCENE.instantiate()
	screen.bind({"event": event, "ship": data.get("ship", {}), "money": data.get("money", 0)}, Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


## ---------------------------------------------------------------------------
## Commands and callbacks
## ---------------------------------------------------------------------------

func _on_menu(screen: String) -> void:
	_menu_screen = screen
	_status_message = ""
	_refresh(true)


func _on_menu_back() -> void:
	_menu_screen = "main"
	_status_message = ""
	_refresh(true)


func _on_menu_action(action: StringName, params: Dictionary) -> void:
	match action:
		&"open":
			_on_menu(String(params.get("screen", "main")))
		&"back":
			_on_menu_back()
		&"continue":
			_on_continue()
		&"diagnostics":
			_show_diagnostics()
		&"retry":
			_retry_bootstrap()
		&"quit":
			_on_quit()
		&"set_locale":
			_on_set_locale(String(params.get("locale", "zh_CN")))
		&"toggle_autosave":
			_on_toggle_autosave()
		&"start_run":
			_selected_build = String(params.get("build_id", ""))
			_seed_text = String(params.get("seed_text", ""))
			_on_new_run()


func _on_quit() -> void:
	get_tree().quit()


func _on_set_locale(locale: String) -> void:
	if _context != null:
		_context.localization.set_locale(locale)
	if _settings != null:
		_settings.set_locale(locale)
	_save_settings()
	_refresh(true)


func _on_toggle_autosave() -> void:
	if _context != null:
		_context.autosave_enabled = not _context.autosave_enabled
	if _settings != null:
		_settings.set_autosave(_context.autosave_enabled if _context != null else true)
	_save_settings()
	_refresh(true)


func _save_settings() -> void:
	if _settings == null:
		return
	var saved := _settings.save()
	if bool(saved.get("ok", false)):
		_set_status(_tr("ui.menu.settings_saved", "设置已保存。"), false)
	else:
		_set_status(_error_text(saved), true)


func _on_nav(screen: String) -> void:
	# Navigating away from the victory summary counts as "keep playing".
	_victory_dismissed = true
	_active_screen = screen
	_status_message = ""
	_refresh(true)


func _on_screen_navigation(screen_id: StringName, params: Dictionary) -> void:
	if screen_id == &"voyage":
		_selected_destination = String(params.get("destination", ""))
	_on_nav(String(screen_id))


func _on_map_port_clicked(port_id: String) -> void:
	if port_id == String(_last_port_view.get("current_port_id", "")):
		_active_screen = "market"
	else:
		_memory_port_id = port_id
		_active_screen = "port_memory"
	_status_message = ""
	_refresh(true)


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
	_victory_dismissed = false
	_set_status("已载入自动存档", false)
	_refresh(true)


func _run_command(command: StringName, params: Dictionary) -> void:
	if _context == null:
		return
	var result := _context.commands.execute(command, params)
	if bool(result.get("ok", false)):
		_handle_success(command, result)
	else:
		_set_status(_error_text(result), true)
	var animate := command in [&"run.start", &"voyage.start", &"event.choose_option"]
	_refresh(animate)


func _handle_success(command: StringName, result: Dictionary) -> void:
	var data: Dictionary = result.get("data", {})
	if command in [&"trade.buy", &"trade.sell", &"contract.accept", &"supply.buy_coal", &"supply.buy_water", &"ship.craft_module"]:
		_play_pickup()
	match String(command):
		"run.start":
			_active_screen = "overview"
			_selected_destination = ""
			_selected_strategy = ""
			_victory_dismissed = false
			_settlement_summary = {}
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
			var install_source := String(data.get("source", "purchase"))
			var replaced := String(data.get("replaced_module_id", ""))
			var install_message := ""
			if install_source == "purchase":
				install_message = _tr("ui.notice.module_installed", "已购买并安装 %s，花费 %d 金币。") % [
					_module_name(String(data.get("module_id", ""))),
					int(data.get("price", 0)),
				]
			else:
				install_message = _tr("ui.notice.module_installed_free", "已免费安装 %s。") % [
					_module_name(String(data.get("module_id", ""))),
				]
			if not replaced.is_empty():
				install_message += _tr("ui.notice.module_replaced", " 旧件已存入当前港仓库。")
			var install_victory: Variant = data.get("victory", null)
			if install_victory is Dictionary and bool(install_victory.get("newly_achieved", false)):
				_victory_dismissed = false
				install_message += _tr("ui.notice.victory", " 已达成通关条件。")
			_set_status(install_message, false)
		"ship.uninstall_module":
			_set_status(_tr("ui.notice.module_uninstalled", "已卸下 %s，存入当前港仓库。") % [
				_module_name(String(data.get("module_id", ""))),
			], false)
		"ship.craft_module":
			var order_port := String(data.get("port_id", _last_port_view.get("current_port_id", "")))
			_set_status(_tr("ui.notice.craft_ordered", "") % [
				_port_name(order_port),
				_module_name(String(data.get("module_id", ""))),
				_fmt(float(data.get("craft_time_hours", 0.0))),
				int(data.get("craft_cost", 0)),
			], false)
		"port.wait":
			var wait_hours := float(data.get("hours", 0.0))
			var wait_port := String(data.get("port_id", _last_port_view.get("current_port_id", "")))
			var wait_message := _tr("ui.notice.waited", "") % [_port_name(wait_port), _fmt(wait_hours)]
			for order in data.get("completed_orders", []):
				if not (order is Dictionary):
					continue
				wait_message += " " + _tr("ui.notice.craft_completed", "") % [
					_module_name(String(order.get("module_id", ""))),
					_port_name(String(order.get("port_id", wait_port))),
				]
			_set_status(wait_message, false)
		"warehouse.store_module":
			_set_status(_tr("ui.notice.warehouse_module_stored", "已把 %s 存入港口仓库。") % [
				_module_name(String(data.get("module_id", ""))),
			], false)
		"warehouse.take_module":
			_set_status(_tr("ui.notice.warehouse_module_taken", "已把 %s 取到船上。") % [
				_module_name(String(data.get("module_id", ""))),
			], false)
		"warehouse.store_materials":
			_set_status(_tr("ui.notice.warehouse_materials_stored", "已存入 %s ×%d。") % [
				_item_name(String(data.get("item_id", ""))),
				int(data.get("amount", 0)),
			], false)
		"warehouse.take_materials":
			_set_status(_tr("ui.notice.warehouse_materials_taken", "已取出 %s ×%d。") % [
				_item_name(String(data.get("item_id", ""))),
				int(data.get("amount", 0)),
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
	var summary: Variant = data.get("summary", data.get("event_result", null))
	if summary is Dictionary:
		_settlement_summary = summary
		_active_screen = "settlement"
		_status_message = ""
	else:
		_active_screen = "overview"
		_set_status("已抵达目的港。", false)


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
	_settings_applied = false
	_set_status("" if not report.has_fatal() else _tr("ui.error.start_failed", ""), report.has_fatal())
	_refresh(true)


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


func _badge(text: String, tone: int = SNBadge.Tone.NEUTRAL) -> Label:
	var badge := SNBadge.new()
	badge.text = text
	badge.tone = tone
	return badge


func _page_heading(eyebrow: String, title: String, detail: String = "") -> SNSectionHeader:
	var header := SNSectionHeader.new()
	header.eyebrow = eyebrow
	header.title = title
	header.detail = detail
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return header


func _button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(callback)
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


func _facility_name(facility: String) -> String:
	var names := {
		"exchange": "交易所",
		"contracts": "港务承运局",
		"supply": "补给码头",
		"shipyard": "造船厂",
		"intel": "情报站",
	}
	return names.get(facility, facility)


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


func _cargo_amount_on_ship(item_id: String) -> int:
	var ship: Dictionary = _last_port_view.get("ship", {})
	for stack in ship.get("cargo", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("item_id", "")) != item_id:
			continue
		if bool(stack.get("is_contract", false)):
			continue
		return int(stack.get("amount", 0))
	return 0
