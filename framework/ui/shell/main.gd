extends Control
## Playable shell for the framework slice.
##
## The UI only reads ViewModels through QueryBus and mutates through
## CommandBus. Each major function has its own screen; the shell owns
## navigation, the header, and transient selection state only.

const UI_THEME := preload("res://assets/ui/theme/steam_navigator_theme.tres")
const COLOR_BG := Color("071a1d")
const COLOR_PANEL := Color("10353a")
const COLOR_PANEL_ALT := Color("17464a")
const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_TEAL := Color("76aaa7")
const COLOR_RED := Color("c36b53")
const COLOR_GREEN := Color("76aa8c")
const DEV_TEAM := "Steam Navigator Team"
const GAME_VERSION_FALLBACK := "0.1.0"

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
var _footer_team: Label = null
var _footer_version: Label = null
var _menu_background: TextureRect = null
var _menu_overlay: ColorRect = null
var _pickup_player: AudioStreamPlayer = null
var _settlement_summary: Dictionary = {}
var _fade_layer: ColorRect = null
var _transitioning: bool = false
var _pending_transition: bool = false


func _ready() -> void:
	theme = UI_THEME
	_settings = SettingsService.load_settings()
	_build_shell()
	_build_audio()
	_refresh()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_menu_background = TextureRect.new()
	_menu_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_background.visible = false
	var menu_texture := load("res://assets/ui/banners/main_menu_harbor.png") as Texture2D
	if menu_texture != null:
		_menu_background.texture = menu_texture
	add_child(_menu_background)

	_menu_overlay = ColorRect.new()
	_menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_overlay.color = Color(0.01, 0.04, 0.05, 0.58)
	_menu_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_overlay.visible = false
	add_child(_menu_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)

	_build_footer()

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_root_box = VBoxContainer.new()
	_root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_root_box)

	_fade_layer = ColorRect.new()
	_fade_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.color = Color(COLOR_BG.r, COLOR_BG.g, COLOR_BG.b, 0.0)
	_fade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.visible = false
	add_child(_fade_layer)


func _apply_settings_if_needed() -> void:
	if _context == null or _settings == null or _settings_applied:
		return
	_context.localization.set_locale(_settings.locale())
	_context.autosave_enabled = _settings.autosave()
	_settings_applied = true


func _build_audio() -> void:
	_pickup_player = AudioStreamPlayer.new()
	var stream := load("res://assets/audio/sfx/economy/pickup_gold_00.wav") as AudioStream
	if stream != null:
		_pickup_player.stream = stream
		_pickup_player.volume_db = -7.0
	add_child(_pickup_player)


func _play_pickup() -> void:
	if _pickup_player != null and _pickup_player.stream != null:
		_pickup_player.play()


func _set_menu_visual(enabled: bool) -> void:
	if _menu_background != null:
		_menu_background.visible = enabled
	if _menu_overlay != null:
		_menu_overlay.visible = enabled


func _build_footer() -> void:
	var footer := VBoxContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -420
	footer.offset_top = -46
	footer.offset_right = -24
	footer.offset_bottom = -14
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 0)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	_footer_team = _label("开发团队：%s" % DEV_TEAM, 11, COLOR_MUTED)
	_footer_team.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer_team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_team.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_footer_team)
	_footer_version = _label("版本 v%s" % _game_version(), 11, COLOR_MUTED)
	_footer_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer_version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_footer_version)


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
		[_tr("ui.label.time", "Time"), String(data.get("time_label", "")), COLOR_TEXT],
		[_tr("ui.label.money", "Money"), str(int(data.get("money", 0))), COLOR_BRASS],
		[_tr("ui.label.reputation", "Reputation"), str(int(data.get("reputation", 0))), COLOR_GREEN],
		[_tr("ui.label.coal", "Coal"), _fmt(float(ship.get("coal", 0.0))), COLOR_BRASS],
		[_tr("ui.label.water", "Water"), _fmt(float(ship.get("water", 0.0))), COLOR_TEAL],
		[_tr("ui.label.weight", "Weight"), "%s / %s" % [_fmt(float(ship.get("total_weight", 0.0))), _fmt(float(ship.get("max_weight", 0.0)))], COLOR_TEXT],
		[_tr("ui.label.durability", "Durability"), "%s / %s" % [_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0)))], COLOR_GREEN],
	]
	for index in stats.size():
		if index > 0:
			row.add_child(VSeparator.new())
		row.add_child(_stat_chip(stats[index][0], stats[index][1], stats[index][2]))
	_root_box.add_child(panel)


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
	var visual_active := "overview" if _active_screen == "port_memory" or _active_screen == "settlement" else _active_screen
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


func _menu_button(text: String, callback: Callable, disabled: bool = false, primary: bool = false) -> Button:
	var button := _button(text, callback, disabled)
	button.custom_minimum_size = Vector2(360, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = &"SNPrimaryButton" if primary else &"SNSecondaryButton"
	button.add_theme_font_size_override("font_size", 17)
	return button


func _screen_main_menu(app: Dictionary) -> void:
	var top_row := HBoxContainer.new()
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)
	top_row.add_child(_badge(
		_tr(String(app.get("status_key", "ui.status.ok")), ""),
		_status_badge_tone(app)
	))
	var log_button := _button(_tr("ui.button.log", "Diagnostics"), _show_diagnostics)
	log_button.theme_type_variation = &"SNGhostButton"
	top_row.add_child(log_button)
	_root_box.add_child(top_row)

	var shell := HBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_box.add_child(shell)
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 72)
	shell.add_child(left_margin)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(470, 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	left_margin.add_child(column)

	column.add_child(_label("S T E A M   N A V I G A T O R", 11, COLOR_MUTED))
	var title := _label(_tr("ui.app.title", "Steam Navigator"), 68, COLOR_BRASS)
	column.add_child(title)
	column.add_child(_label(_tr("ui.menu.subtitle", ""), 16, COLOR_TEXT))
	var rule := ColorRect.new()
	rule.color = Color(COLOR_BRASS, 0.45)
	rule.custom_minimum_size = Vector2(360, 1)
	column.add_child(rule)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	column.add_child(spacer)

	var has_save := bool(app.get("autosave_available", false))
	column.add_child(_menu_button(_tr("ui.menu.start", "开始游戏"), _on_menu.bind("new_game"), false, true))
	column.add_child(_menu_button(
		_tr("ui.menu.load", "加载游戏") if has_save else _tr("ui.menu.load_empty", "加载游戏（无存档）"),
		_on_continue,
		not has_save
	))
	column.add_child(_menu_button(_tr("ui.menu.mods", "模组"), _on_menu.bind("mods")))
	column.add_child(_menu_button(_tr("ui.menu.settings", "设置"), _on_menu.bind("settings")))
	column.add_child(_menu_button(_tr("ui.menu.quit", "退出游戏"), _on_quit))
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(right_spacer)

	_build_status_banner()


func _screen_new_game(app: Dictionary) -> void:
	_root_box.add_child(_page_heading("航程准备", _tr("ui.menu.new_game", "新航程"), "选择初始构筑与种子"))

	var intro := _panel()
	_panel_add(intro, _label(_tr("ui.app.subtitle", ""), 15, COLOR_MUTED))
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
	var new_run := _button(_tr("ui.button.new_run", "开始航行"), _on_new_run)
	new_run.theme_type_variation = &"SNPrimaryButton"
	new_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(new_run)
	var back_button := _button(_tr("ui.menu.back", "返回主菜单"), _on_menu_back)
	back_button.theme_type_variation = &"SNGhostButton"
	buttons.add_child(back_button)
	_panel_add(form, buttons)
	_root_box.add_child(form)

	if not app.get("report", {}).get("warnings", []).is_empty():
		var warning_panel := _panel()
		_panel_add(warning_panel, _label(_tr("ui.label.warnings", "Warnings"), 15, COLOR_BRASS))
		for warning in app.get("report", {}).get("warnings", []).slice(0, 5):
			_panel_add(warning_panel, _label("• %s" % warning.get("message", ""), 13, COLOR_MUTED))
		_root_box.add_child(warning_panel)
	_build_status_banner()


func _screen_mods(app: Dictionary) -> void:
	_root_box.add_child(_page_heading("模组", _tr("ui.menu.mods_title", "已加载模组"), "启动时实际加载的内容包"))
	var note := _panel()
	_panel_add(note, _label(_tr("ui.menu.mods_note", "模组启用/禁用和加载顺序管理尚未实现；这里显示本次启动实际加载的模组。"), 13, COLOR_MUTED))
	_root_box.add_child(note)

	for mod in app.get("mods", []):
		var panel := _panel()
		var header := HBoxContainer.new()
		var name_label := _label("%s  ·  %s" % [String(mod.get("name", mod.get("id", ""))), String(mod.get("id", ""))], 17, COLOR_BRASS)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)
		header.add_child(_label("v%s" % String(mod.get("version", "?")), 13, COLOR_MUTED))
		_panel_add(panel, header)
		var source := String(mod.get("source", ""))
		if not source.is_empty():
			_panel_add(panel, _label("%s：%s" % [_tr("ui.menu.source", "源"), source], 12, COLOR_MUTED))
		var dependencies: Array = mod.get("dependencies", [])
		_panel_add(panel, _label("%s：%s" % [
			_tr("ui.menu.dependencies", "依赖"),
			", ".join(dependencies) if not dependencies.is_empty() else "—",
		], 12, COLOR_MUTED))
		_panel_add(panel, _label("%s：%s" % [
			_tr("ui.menu.required", "必需"),
			_tr("ui.menu.yes", "是") if bool(mod.get("required", false)) else _tr("ui.menu.no", "否"),
		], 12, COLOR_MUTED))
		_root_box.add_child(panel)

	var footer_buttons := HBoxContainer.new()
	footer_buttons.add_child(_button(_tr("ui.menu.back", "返回主菜单"), _on_menu_back))
	footer_buttons.add_child(_button(_tr("ui.menu.rescan", "重新扫描"), _retry_bootstrap))
	_root_box.add_child(footer_buttons)
	_build_status_banner()


func _screen_settings(_app: Dictionary) -> void:
	_root_box.add_child(_page_heading("偏好", _tr("ui.menu.settings_title", "设置"), "语言与自动存档"))
	var panel := _panel()
	var locale_row := HBoxContainer.new()
	locale_row.add_child(_label(_tr("ui.menu.language", "语言"), 15, COLOR_TEXT))
	var locale := _context.localization.active_locale if _context != null else "zh_CN"
	locale_row.add_child(_button("中文", _on_set_locale.bind("zh_CN")))
	locale_row.add_child(_button("English", _on_set_locale.bind("en")))
	var active := _label("%s：%s" % [_tr("ui.menu.current", "当前"), "中文" if locale == "zh_CN" else "English"], 13, COLOR_MUTED)
	locale_row.add_child(active)
	_panel_add(panel, locale_row)

	var autosave_row := HBoxContainer.new()
	autosave_row.add_child(_label(_tr("ui.menu.autosave", "自动存档"), 15, COLOR_TEXT))
	var enabled := bool(_context.autosave_enabled) if _context != null else true
	autosave_row.add_child(_button(_tr("ui.menu.autosave_on", "开") if enabled else _tr("ui.menu.autosave_off", "关"), _on_toggle_autosave))
	autosave_row.add_child(_label(_tr("ui.menu.autosave_note", "关闭后本次运行不再自动写入自动存档。"), 12, COLOR_MUTED))
	_panel_add(panel, autosave_row)
	_root_box.add_child(panel)

	var note := _panel()
	_panel_add(note, _label(_tr("ui.menu.settings_note", "设置仅对本次运行生效。"), 12, COLOR_MUTED))
	if _settings != null:
		_panel_add(note, _label(_tr("ui.menu.settings_path", "保存位置：user://config/config.json（默认 config/config.json）"), 12, COLOR_MUTED))
	_root_box.add_child(note)
	_root_box.add_child(_button(_tr("ui.menu.back", "返回主菜单"), _on_menu_back))
	_build_status_banner()


## ---------------------------------------------------------------------------
## Overview
## ---------------------------------------------------------------------------

func _screen_overview(data: Dictionary) -> void:
	var hero := _port_hero(data)
	if hero != null:
		_root_box.add_child(hero)
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


func _port_hero(data: Dictionary) -> Control:
	var port: Dictionary = data.get("current_port", {})
	var banner_key := String(port.get("banner_asset", ""))
	var source_mod := String(port.get("source_mod", ""))
	if banner_key.is_empty() or source_mod.is_empty():
		return null
	var logical_key := "asset://%s/%s" % [source_mod, banner_key]
	if not _context.assets.has(logical_key):
		return null
	var texture := load(_context.assets.resolve(logical_key)) as Texture2D
	if texture == null:
		return null

	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 236)
	hero.clip_contents = true
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(image)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.06, 0.07, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	column.add_child(_label("北纬 52° · 工业港", 11, COLOR_BRASS))
	column.add_child(_label(_tr(String(port.get("name_key", "")), String(port.get("id", ""))), 46, COLOR_BRASS))
	var description_key := String(port.get("description_key", ""))
	if not description_key.is_empty():
		column.add_child(_label(_tr(description_key, ""), 14, COLOR_TEXT))
	var facility_row := HBoxContainer.new()
	facility_row.add_theme_constant_override("separation", 6)
	for facility in port.get("facilities", []):
		facility_row.add_child(_badge(_facility_name(String(facility)), SNBadge.Tone.NEUTRAL))
	column.add_child(facility_row)
	return hero


func _map_panel() -> Control:
	var panel := _panel()
	var map_view := _context.queries.execute(&"map.view")
	if not bool(map_view.get("ok", false)):
		_panel_add(panel, _label(_error_text(map_view), 14, COLOR_RED))
		return panel
	var map_data: Dictionary = map_view["data"]
	var discovered := 0
	for map_port in map_data.get("ports", []):
		if bool(map_port.get("visited", false)):
			discovered += 1
	_panel_add(panel, _page_heading("航路局", "北部海图", "%d 个已访问港口 · 点击港口查看记忆" % discovered))
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
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 18)
	legend.add_child(_label("● 当前港", 11, COLOR_BRASS))
	legend.add_child(_label("● 已访问", 11, COLOR_TEAL))
	legend.add_child(_label("● 可航行", 11, COLOR_GREEN))
	legend.add_child(_label("● 未知", 11, COLOR_MUTED))
	_panel_add(panel, legend)
	return panel


func _port_panel(data: Dictionary) -> Control:
	var panel := _panel()
	var port: Dictionary = data.get("current_port", {})
	_panel_add(panel, _page_heading("港口", _tr(String(port.get("name_key", "")), String(port.get("id", ""))), "当前停靠"))
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
	_panel_add(panel, _page_heading("当前目标", "主线航程", "优先完成主线以推进章节"))
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
	_panel_add(panel, _page_heading("船只", "当前船只", "载重与消耗"))
	_panel_add(panel, _label("航速 %s · 煤耗 %s/h · 水耗 %s/h" % [
		_fmt(float(ship.get("speed", 0.0)), 2),
		_fmt(float(ship.get("coal_rate", 0.0)), 2),
		_fmt(float(ship.get("water_rate", 0.0)), 2),
	], 13, COLOR_MUTED))
	var durability := SNResourceMeter.new()
	durability.label_text = "耐久"
	durability.current_value = float(ship.get("durability", 0.0))
	durability.maximum_value = maxf(1.0, float(ship.get("max_durability", 1.0)))
	durability.suffix = ""
	durability.hint = ""
	durability.tone = SNResourceMeter.Tone.BRASS
	_panel_add(panel, durability)
	var cargo := SNResourceMeter.new()
	cargo.label_text = "货舱"
	cargo.current_value = float(ship.get("cargo_used", 0.0))
	cargo.maximum_value = maxf(1.0, float(ship.get("cargo_capacity", 1.0)))
	cargo.suffix = ""
	cargo.hint = "旅客 %d / %d" % [int(ship.get("passengers", 0)), int(ship.get("passenger_capacity", 0))]
	cargo.tone = SNResourceMeter.Tone.WATER
	_panel_add(panel, cargo)
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
	_panel_add(panel, _page_heading("快捷入口", "港口操作", "常用功能"))
	var actions := [
		["market", "市场买卖"],
		["contracts", "接取委托"],
		["shipyard", "船只改造"],
		["supply", "补给维修"],
		["intel", "情报报告"],
		["voyage", "规划出航"],
	]
	for action in actions:
		var button := _button(String(action[1]), _on_nav.bind(String(action[0])))
		button.theme_type_variation = &"SNGhostButton"
		_panel_add(panel, button)
	return panel


func _finance_panel(data: Dictionary) -> Control:
	var panel := _panel()
	_panel_add(panel, _page_heading("财务", "现金与债务", ""))
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
	var port: Dictionary = data.get("current_port", {})
	_root_box.add_child(_page_heading(
		_tr("ui.nav.market", "Market"),
		_tr(String(port.get("name_key", "")), String(port.get("id", ""))),
		"市场行情"
	))
	var panel := _panel()
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
		var trend_cell := HBoxContainer.new()
		trend_cell.add_theme_constant_override("separation", 4)
		var spark := SNSparkline.new()
		spark.custom_minimum_size = Vector2(58, 22)
		spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var recent_prices: Array = row.get("recent_prices", [])
		spark.set_values(recent_prices, _trend_color(trends.get(item_id, "")))
		trend_cell.add_child(spark)
		var trend_percent := float(row.get("trend_percent", 0.0)) * 100.0
		trend_cell.add_child(_label(
			("%+.1f%%" % trend_percent) if recent_prices.size() >= 2 else "—",
			11,
			_trend_color(trends.get(item_id, ""))
		))
		grid.add_child(trend_cell)
		var buy_row := HBoxContainer.new()
		buy_row.add_theme_constant_override("separation", 2)
		if buyable:
			for amount in [1, 5, 10]:
				var buy_button := _small_button(str(amount), _on_buy.bind(item_id, amount))
				buy_button.disabled = int(row.get("stock", 0)) < amount
				buy_row.add_child(buy_button)
		else:
			buy_row.add_child(_label("—", 13, COLOR_MUTED))
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
	_root_box.add_child(_page_heading("港口记忆", _tr(String(memory.get("name_key", "")), String(memory.get("port_id", ""))), "上次在港时的只读快照"))
	var panel := _panel()
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
	_root_box.add_child(_page_heading("海事局委托处", "委托与航线", "主线只能同时进行一个；普通委托持有上限随声誉提高。"))
	var main_contract: Variant = contracts.get("main", null)
	var main_offer: Variant = contracts.get("main_offer", null)
	var offers: Array = contracts.get("offers", [])
	var active: Array = contracts.get("active", [])

	var available_count := offers.size() + (1 if main_offer is Dictionary else 0)
	if available_count > 0:
		var available_header := HBoxContainer.new()
		var available_title := _label("可接委托", 18, COLOR_BRASS)
		available_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		available_header.add_child(available_title)
		available_header.add_child(_badge("%d 个" % available_count, SNBadge.Tone.NEUTRAL))
		_root_box.add_child(available_header)
		var grid := _contract_grid()
		_root_box.add_child(grid)
		if main_offer is Dictionary:
			grid.add_child(_contract_card(main_offer, "可接主线", true, false))
		for offer in offers:
			if offer is Dictionary:
				grid.add_child(_contract_card(offer, "普通委托", true, false))

	var active_count := active.size() + (1 if main_contract is Dictionary else 0)
	if active_count > 0:
		var active_header := HBoxContainer.new()
		var active_title := _label("进行中", 18, COLOR_BRASS)
		active_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_header.add_child(active_title)
		active_header.add_child(_badge("%d 个" % active_count, SNBadge.Tone.SUCCESS))
		_root_box.add_child(active_header)
		var grid := _contract_grid()
		_root_box.add_child(grid)
		if main_contract is Dictionary:
			grid.add_child(_contract_card(main_contract, "主线进行中", false, true))
		for contract in active:
			if contract is Dictionary:
				grid.add_child(_contract_card(contract, "普通进行中", false, true))

	if available_count == 0 and active_count == 0:
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


func _contract_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	return grid


func _contract_card(contract: Dictionary, tag: String, can_accept: bool, can_plan: bool) -> Control:
	var panel := _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = &"SNElevatedPanel"
	var is_main := tag.begins_with("主线")
	var title_row := HBoxContainer.new()
	var title := _label(_tr(String(contract.get("name_key", "")), String(contract.get("template_id", ""))), 18, COLOR_BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(title)
	title_row.add_child(_badge("主线" if is_main else "普通", SNBadge.Tone.WARNING if is_main else SNBadge.Tone.NEUTRAL))
	var risk := String(contract.get("risk", "low"))
	title_row.add_child(_badge(_risk_label(risk), _risk_tone(risk)))
	_panel_add(panel, title_row)

	var data_row := HBoxContainer.new()
	data_row.add_theme_constant_override("separation", 6)
	var remaining := float(contract.get("remaining_hours", 0.0))
	data_row.add_child(_contract_stat("目的地", _tr(String(contract.get("destination_name_key", "")), String(contract.get("destination", ""))), COLOR_TEXT))
	data_row.add_child(VSeparator.new())
	data_row.add_child(_contract_stat("剩余期限", String(contract.get("remaining_label", "—")), COLOR_RED if remaining < 24.0 else COLOR_TEXT))
	data_row.add_child(VSeparator.new())
	data_row.add_child(_contract_stat("载重", _contract_payload_text(contract).trim_prefix("载荷："), COLOR_TEXT))
	data_row.add_child(VSeparator.new())
	data_row.add_child(_contract_stat("预计航程", String(contract.get("estimated_label", "—")), COLOR_MUTED))
	_panel_add(panel, data_row)

	var description_key := String(contract.get("description_key", ""))
	if not description_key.is_empty():
		var description := _label(_tr(description_key, ""), 13, COLOR_MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.max_lines_visible = 2
		_panel_add(panel, description)
	var deadline_label := _label("截止 %s" % String(contract.get("deadline_label", "")), 11, COLOR_MUTED)
	deadline_label.tooltip_text = _tr("ui.label.deadline_hint", "绝对时间仅作参考，优先看剩余期限")
	_panel_add(panel, deadline_label)
	var reward_row := HBoxContainer.new()
	var reward := _label(_contract_reward_text(contract), 14, COLOR_TEXT)
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_row.add_child(reward)
	reward_row.add_child(_badge("声望 +%d" % int(contract.get("reputation", 0)), SNBadge.Tone.SUCCESS))
	_panel_add(panel, reward_row)
	var unlock_text := _contract_unlock_text(contract)
	if not unlock_text.is_empty():
		_panel_add(panel, _label("解锁：%s" % unlock_text, 12, COLOR_TEAL))

	var buttons := HBoxContainer.new()
	if can_accept:
		var accept := _button(_tr("ui.button.accept", "接受"), _on_accept_contract.bind(String(contract.get("instance_id", ""))))
		accept.theme_type_variation = &"SNPrimaryButton"
		buttons.add_child(accept)
	if can_plan:
		var destination := String(contract.get("destination", ""))
		var plan := _button(_tr("ui.button.plan", "规划出航"), _on_plan_contract.bind(destination))
		plan.theme_type_variation = &"SNPrimaryButton" if not can_accept else &"SNSecondaryButton"
		plan.disabled = not _is_neighbor(destination)
		buttons.add_child(plan)
	if buttons.get_child_count() > 0:
		_panel_add(panel, buttons)
	if can_plan and not _is_neighbor(String(contract.get("destination", ""))):
		_panel_add(panel, _label("目的港不直达，需要先到中转港。", 11, COLOR_RED))
	return panel


func _contract_stat(label_text: String, value_text: String, value_color: Color) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	column.add_child(_label(label_text, 10, COLOR_MUTED))
	column.add_child(_label(value_text, 14, value_color))
	return column


func _risk_tone(risk: String) -> int:
	match risk:
		"high":
			return SNBadge.Tone.DANGER
		"medium":
			return SNBadge.Tone.WARNING
		_:
			return SNBadge.Tone.SUCCESS


func _risk_label(risk: String) -> String:
	match risk:
		"high":
			return "高风险"
		"medium":
			return "中等风险"
		_:
			return "低风险"


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
	_root_box.add_child(_page_heading(
		_tr("ui.nav.shipyard", "Shipyard"),
		_tr(String(yard.get("port_name_key", "")), String(yard.get("port_id", ""))),
		"槽位、当前模块与替换限制"
	))
	if not bool(yard.get("has_shipyard", false)):
		var warn := _panel()
		_panel_add(warn, _label(_tr("ui.label.shipyard_absent", ""), 15, COLOR_RED))
		_root_box.add_child(warn)

	var current := _panel()
	_panel_add(current, _label(_tr("ui.label.current_ship", ""), 18, COLOR_BRASS))
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
	var port_name := _tr(String(supply.get("port_name_key", "")), String(supply.get("port_id", "")))
	_root_box.add_child(_page_heading("港务补给站", "补给与维护 · %s" % port_name, "煤水按当前港价购买；补给计入总重量。"))

	var summary := _panel()
	summary.theme_type_variation = &"SNInsetPanel"
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 18)
	summary_row.add_child(_badge("金币 %d" % int(supply.get("money", 0)), SNBadge.Tone.NEUTRAL))
	summary_row.add_child(_badge("重量 %s / %s" % [
		_fmt(float(supply.get("total_weight", 0.0))),
		_fmt(float(supply.get("max_weight", 0.0))),
	], SNBadge.Tone.NEUTRAL))
	summary_row.add_child(_badge("剩余载重 %s" % _fmt(float(supply.get("remaining_weight", 0.0))), SNBadge.Tone.WARNING))
	summary_row.add_child(_badge("耐久 %s / %s" % [
		_fmt(float(supply.get("durability", 0.0))),
		_fmt(float(supply.get("repair", {}).get("max_durability", 0.0))),
	], SNBadge.Tone.SUCCESS))
	_panel_add(summary, summary_row)
	if not bool(supply.get("has_supply", false)):
		_panel_add(summary, _label("当前港口没有补给码头。", 14, COLOR_RED))
	_root_box.add_child(summary)

	var cards := HFlowContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 16)
	cards.add_theme_constant_override("v_separation", 16)
	_root_box.add_child(cards)
	for kind in ["coal", "water"]:
		var data: Dictionary = supply.get("%s_view" % kind, {})
		var card := SNSupplyCard.new()
		card.custom_minimum_size = Vector2(560, 250)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.bind(data, _tr("ui.label.%s" % kind, ""), _supply_blocker_labels(data.get("blockers", [])))
		card.command_requested.connect(_on_supply_card_command)
		cards.add_child(card)

	var repair_panel := _panel()
	repair_panel.theme_type_variation = &"SNElevatedPanel"
	var repair: Dictionary = supply.get("repair", {})
	var repair_header := HBoxContainer.new()
	var repair_title := _label("维修", 20, COLOR_BRASS)
	repair_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair_header.add_child(repair_title)
	repair_header.add_child(_badge(
		"可维修" if bool(supply.get("can_repair", false)) else "无需维修或资源不足",
		SNBadge.Tone.SUCCESS if bool(supply.get("can_repair", false)) else SNBadge.Tone.WARNING
	))
	_panel_add(repair_panel, repair_header)
	_panel_add(repair_panel, _label("缺失耐久 %s · 预计费用 %d 金币（单位维修价 %s）" % [
		_fmt(float(repair.get("missing", 0.0))),
		int(repair.get("cost", 0)),
		_fmt(float(supply.get("repair_per_point", 0.0))),
	], 13, COLOR_TEXT))
	var repair_button := _button(_tr("ui.button.repair", ""), _on_repair)
	repair_button.theme_type_variation = &"SNPrimaryButton"
	repair_button.disabled = not bool(supply.get("can_repair", false))
	_panel_add(repair_panel, repair_button)
	_root_box.add_child(repair_panel)


func _on_supply_card_command(command: StringName, params: Dictionary) -> void:
	_run_command(command, params)


func _supply_blocker_labels(blockers: Array) -> Array:
	var labels: Array = []
	for blocker in blockers:
		match String(blocker):
			"no_supply":
				labels.append(_tr("ui.error.no_supply", ""))
			"no_stock":
				labels.append(_tr("ui.error.insufficient_stock", ""))
			"weight_limit":
				labels.append(_tr("ui.error.weight", ""))
			"insufficient_money":
				labels.append(_tr("ui.error.money", ""))
			_:
				labels.append(String(blocker))
	return labels


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
	_root_box.add_child(_page_heading("航路情报站", "商情报告", _tr("ui.hint.intel", "")))
	var header := _panel()
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
	_root_box.add_child(_page_heading("航路规划", "出航准备", "出航前确认耗时、消耗与风险来源。"))
	var panel := _panel()
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

func _screen_settlement(data: Dictionary) -> void:
	if _settlement_summary.is_empty():
		_screen_overview(data)
		return
	var summary := _settlement_summary
	var destination := String(summary.get("destination", ""))
	var ship: Dictionary = data.get("ship", {})
	_root_box.add_child(_page_heading(
		"航次完成",
		"抵达 %s" % (_port_name(destination) if not destination.is_empty() else "目的港"),
		ClockService.format_time(float(summary.get("arrival_time", 0.0)))
	))
	var panel := _panel()
	panel.theme_type_variation = &"SNElevatedPanel"
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	var contracts: Array = summary.get("contracts", [])
	var payout := 0
	var on_time := 0
	for contract in contracts:
		if contract is Dictionary:
			payout += int(contract.get("payout", 0))
			if bool(contract.get("on_time", false)):
				on_time += 1
	stats_row.add_child(_stat_chip("委托收入", str(payout), COLOR_BRASS))
	stats_row.add_child(VSeparator.new())
	stats_row.add_child(_stat_chip("准时交付", "%d / %d" % [on_time, contracts.size()], COLOR_GREEN))
	stats_row.add_child(VSeparator.new())
	stats_row.add_child(_stat_chip("延误", "%s h" % _fmt(float(summary.get("delayed_hours", 0.0))), COLOR_RED if float(summary.get("delayed_hours", 0.0)) > 0.0 else COLOR_TEXT))
	stats_row.add_child(VSeparator.new())
	stats_row.add_child(_stat_chip("当前金币", str(int(data.get("money", 0))), COLOR_BRASS))
	_panel_add(panel, stats_row)
	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 18)
	resource_row.add_child(_badge("煤炭 %s" % _fmt(float(ship.get("coal", 0.0))), SNBadge.Tone.WARNING))
	resource_row.add_child(_badge("淡水 %s" % _fmt(float(ship.get("water", 0.0))), SNBadge.Tone.NEUTRAL))
	resource_row.add_child(_badge("耐久 %s / %s" % [
		_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0))),
	], SNBadge.Tone.SUCCESS if float(ship.get("durability", 0.0)) > float(ship.get("max_durability", 1.0)) * 0.5 else SNBadge.Tone.DANGER))
	_panel_add(panel, resource_row)
	if not contracts.is_empty():
		_panel_add(panel, _label("交付明细", 14, COLOR_BRASS))
		for contract in contracts:
			if not (contract is Dictionary):
				continue
			var row := HBoxContainer.new()
			var contract_name_key := String(contract.get("name_key", ""))
			var contract_label := _tr(contract_name_key, "") if not contract_name_key.is_empty() else _definition_name(String(contract.get("template_id", "")))
			var name_label := _label(contract_label, 13, COLOR_TEXT)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			row.add_child(_badge(
				"准时" if bool(contract.get("on_time", false)) else "延误",
				SNBadge.Tone.SUCCESS if bool(contract.get("on_time", false)) else SNBadge.Tone.DANGER
			))
			row.add_child(_label("+%d" % int(contract.get("payout", 0)), 13, COLOR_BRASS))
			_panel_add(panel, row)
	var injuries := int(summary.get("injuries", 0))
	if injuries > 0:
		_panel_add(panel, _label("旅客受伤 %d 人" % injuries, 13, COLOR_RED))
	_panel_add(panel, _button("进入港口", _on_nav.bind("overview")))
	_root_box.add_child(panel)


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

func _on_menu(screen: String) -> void:
	_menu_screen = screen
	_status_message = ""
	_refresh(true)


func _on_menu_back() -> void:
	_menu_screen = "main"
	_status_message = ""
	_refresh(true)


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
	_active_screen = screen
	_status_message = ""
	_refresh(true)


func _on_map_port_clicked(port_id: String) -> void:
	if port_id == String(_last_port_view.get("current_port_id", "")):
		_active_screen = "market"
	else:
		_memory_port_id = port_id
		_active_screen = "port_memory"
	_status_message = ""
	_refresh(true)


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
	_refresh(true)


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
	_refresh(true)


func _on_install_module(module_id: String) -> void:
	_run_command(&"ship.install_module", {"module_id": module_id})


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
	var animate := command in [&"run.start", &"voyage.start", &"event.choose_option"]
	_refresh(animate)


func _handle_success(command: StringName, result: Dictionary) -> void:
	var data: Dictionary = result.get("data", {})
	if command in [&"trade.buy", &"trade.sell", &"contract.accept", &"supply.buy_coal", &"supply.buy_water"]:
		_play_pickup()
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
		for x in range(0, int(size.x), 48):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.35, 0.52, 0.52, 0.1), 1.0)
		for y in range(0, int(size.y), 48):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.35, 0.52, 0.52, 0.1), 1.0)
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
