extends Control
## Playable shell for the framework slice.
##
## The UI only reads ViewModels through QueryBus and mutates through
## CommandBus. Each major function has its own screen; the shell owns
## navigation, the header, and transient selection state only.
##
## Two mount paths exist: ordinary pages go into `PageMargin/PageScroll/RootBox`,
## while the at-sea chart page goes into the full-window `FullscreenLayer` (no
## page margins, no scrolling) so the sea really fills the window. The voyage
## presentation also feeds that page its route polyline straight from the twin
## world's `WorldMap.edges` (`_presentation_route_path`) instead of the
## fog-filtered `sea_chart.view` routes.
##
## Exploration (phase 4.1) reuses that same presentation: `explore.start` returns
## a `presentation` block (`_presentation_explore`) whose route ends at a search
## zone centre the player cannot name yet. The chart page then draws a dashed
## prediction line to a `?` marker, and the arrival milestone runs `explore.settle`
## before cutting to the harbour (the destination only exists after that command).
##
## Phase 4.2 adds the resource-alert decision: when the exploration's Core rules
## report `alert_needed`, the state machine stops at the alert's `alert_progress`
## and `_rebuild_ui` mounts the alert page (reusing `EventScreen`) instead of the
## chart. `continue` acknowledges it in the domain and resumes the voyage;
## `turn_back` lets `explore.decide` settle a half-voyage return immediately, then
## `VoyagePresentation.force_arrival()` plays the normal harbour cut without ever
## calling `explore.settle` again (that is what `_presentation_explore["returned"]`
## guards in `ARRIVAL_READY`).

const UI_THEME := preload("res://assets/ui/theme/steam_navigator_theme.tres")
## Themed edge signboard (wood/iron/brass custom draw, plain Button semantics).
const HARBOR_SIGN_SCRIPT := preload("res://framework/ui/components/sn_harbor_sign.gd")
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
const SEA_CHART_SCREEN_SCENE := preload("res://framework/ui/screens/flow/sea_chart_screen.tscn")
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
const GAME_VERSION_FALLBACK := "0.2.0"

const SCREENS := ["overview", "market", "contracts", "shipyard", "supply", "intel", "voyage"]
## 2.5D port stage presented behind the overview page. Kept as a path (not a
## preload) so a missing scene degrades to the 2D banner instead of a parse error.
const PORT_STAGE_SCENE_PATH := "res://framework/ui/stages/port_stage.tscn"
## Facility id -> page opened by the 2D sign drawn over the stage.
const PORT_STAGE_FACILITY_SCREENS := {
	"exchange": &"market",
	"contracts": &"contracts",
	"supply": &"supply",
	"intel": &"intel",
	"shipyard": &"shipyard",
}
## Screens that share the one continuous 3D port stage. The pages map to adjacent
## stations of the same harbour district: navigating between them keeps the same
## stage instance mounted and only pans the camera + sails the player's hull to
## the station berth (Bounty Train style), so there is no rebuild and no fade to
## black between the market, the harbour authority and the supply yard.
const STAGE_SCREENS := {
	"overview": "harbor",
	"market": "market",
	"supply": "supply",
}
## Width of the dock information panel on the market / supply pages. The stage
## keeps the left part of the window, the panel floats over the right side.
const DOCK_PANEL_WIDTH := 640.0
## Compact top chrome: header + resource stats + navigation in two tight rows.
## The measured minimum height must stay under `TOP_CHROME_MAX_HEIGHT`, because
## the 3D stage is the main view and the HUD only frames it.
const TOP_CHROME_MAX_HEIGHT := 130.0
## Bottom ship/port status strip on the overview page (fixed shell layer).
const PORT_STATUS_BAR_HEIGHT := 60.0
const PORT_STATUS_BAR_GAP := 14.0
## Side signboards: fixed columns at the scene edges, one per present facility
## plus the always-present "voyage" sign at the bottom of the right column.
const PORT_SIGN_WIDTH := 172.0
const PORT_SIGN_HEIGHT := 42.0
const PORT_SIGN_GAP := 10.0
const PORT_SIGN_MARGIN := 20.0
## Optional HUD icon keys. Content packs may declare `icon.*` assets; the Shell
## resolves whichever mounted pack provides them and silently falls back to a
## text-only chip when none do.
const HUD_ICON_KEYS := {
	"money": "icon.money",
	"coal": "icon.coal",
	"water": "icon.water",
}
const HUD_ICON_SIZE := 22.0
## Page bottom reserve: default leaves room for the footer, the overview status
## bar is taller and replaces the footer while it is visible.
const PAGE_BOTTOM_MARGIN := 56
const PAGE_BOTTOM_MARGIN_WITH_BAR := 84
var _context: AppContext = null
@onready var _root_box: VBoxContainer = $PageMargin/PageScroll/RootBox
## 全窗演出层：航行页的海图挂在这里（在网页边距/滚动容器之外），海图才能真正
## 铺满整屏（阶段 3 验收反馈 F3）。它位于页面层之下、顶部 chrome 与转场层之上。
@onready var _fullscreen_layer: Control = $FullscreenLayer
var _last_port_view: Dictionary = {}
var _settings: SettingsService = null
var _settings_applied: bool = false

var _active_screen: String = "overview"
var _menu_screen: String = "main"
var _memory_port_id: String = ""
var _selected_build: String = ""
var _selected_destination: String = ""
var _selected_strategy: String = ""
var _sea_chart_return: String = "voyage"
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
## Overview 3D stage state. `_overview_stage_mode` is UI-session state only.
## The 3D port stage is the default main view; the 2D overview stays reachable
## as a fallback / accessibility toggle.
var _overview_stage_mode: bool = true
var _port_stage_load_failed: bool = false
var _port_stage_host: SNStageHost = null
## Station the stage is currently showing ("harbor" / "market" / "supply") and
## the framing it was asked for ("stage" / "panel"). Kept on the shell so a page
## rebuild does not restart the pan.
var _stage_station: String = ""
var _stage_framing: String = ""
## 2D sign layer over the stage (one sign per present facility + voyage).
var _port_hotspot_layer: Control = null
## Overview detail drawer: when opened, the existing 2D overview panels are
## shown over an opaque backdrop instead of the bare 3D stage.
var _overview_detail: bool = false
var _overview_detail_backdrop: ColorRect = null
## Fixed chrome nodes rebuilt every refresh; kept so tests and the layout code
## can measure them without walking the whole tree.
var _top_chrome: PanelContainer = null
var _port_status_bar: PanelContainer = null
## Resolved optional HUD icon textures (key -> Texture2D or null). Assets are
## frozen after bootstrap, so the cache never needs invalidation.
var _hud_icon_cache: Dictionary = {}
@onready var _page_margin: MarginContainer = $PageMargin
@onready var _fade_layer: ColorRect = $TransitionLayer
var _transitioning: bool = false
var _pending_transition: bool = false
## Voyage presentation (nautical chart phase 3). `_presentation` is the whole
## at-sea演出 session state: while it is set, the shell renders the chart
## presentation, hides navigation and drives `_process` ticks. It is UI-session
## state only — the voyage itself is already resolved by `voyage.start`.
var _presentation: VoyagePresentation = null
var _presentation_summary: Dictionary = {}
## 探索演出（阶段 4.1）：`explore.start` 命令返回的 `presentation`（origin / zone /
## route_path / total_hours / alert_needed / alert_progress / …）。非空表示这次演出是
## 探索，抵达摘要要由 `explore.settle` 现算，目的地直到结算后才存在。4.2 的告警
## 决策点也记在这里（`alert_*`；`returned = true` 表示已掉头并提前结算）。
var _presentation_explore: Dictionary = {}
## Endpoints of the voyage being presented. Kept on the shell because the domain
## voyage record is already cleared when the arrival settles instantly.
var _presentation_voyage: Dictionary = {}
## `port.view` of the harbour the voyage departed from, captured before the
## command settled the arrival (the departure cut is filmed there).
var _presentation_origin_view: Dictionary = {}
var _at_sea_screen: AtSeaScreen = null
## Procedural cloud veil used by the presentation; created lazily as the topmost
## child so it covers both the 3D stage and the pages.
var _cloud_veil: SNCloudVeil = null


func _ready() -> void:
	theme = UI_THEME
	_settings = SettingsService.load_settings()
	_refresh()


## Drives the at-sea演出. Only the presentation advances the animation; the
## domain voyage was already resolved when `voyage.start` returned.
func _process(delta: float) -> void:
	if _presentation == null:
		return
	_tick_presentation(delta)


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
	# The at-sea chart lives outside the scrolling page stack (it must fill the
	# window), so it has to be cleared here too or the page would linger.
	for child in _fullscreen_layer.get_children():
		_fullscreen_layer.remove_child(child)
		child.queue_free()
	_top_chrome = null
	_at_sea_screen = null
	if _context == null:
		_hide_port_stage()
		_set_port_status_bar_visible(false)
		_root_box.add_child(_label("Loading framework...", 20, COLOR_MUTED))
		get_tree().create_timer(0.4).timeout.connect(_refresh)
		return
	_apply_settings_if_needed()
	var app_view := _context.queries.execute(&"app.view")
	if not bool(app_view.get("ok", false)):
		_hide_port_stage()
		_set_port_status_bar_visible(false)
		_root_box.add_child(_label(_error_text(app_view), 18, COLOR_RED))
		return
	var app: Dictionary = app_view["data"]
	_refresh_footer()
	var has_run := bool(app.get("has_run", false))
	_set_menu_visual(not has_run)
	if not has_run:
		_hide_port_stage()
		_set_port_status_bar_visible(false)
		_build_menu(app)
		return
	var port_result := _context.queries.execute(&"port.view")
	if not bool(port_result.get("ok", false)):
		_hide_port_stage()
		_set_port_status_bar_visible(false)
		_root_box.add_child(_label(_error_text(port_result), 18, COLOR_RED))
		return
	var data: Dictionary = port_result["data"]
	_last_port_view = data
	var at_sea := bool(data.get("at_sea", false))
	# While the voyage presentation owns the screen the player is not actually in
	# port: navigation stays hidden and the chart page is mounted instead.
	var presenting := _presentation_on_chart()

	# The victory summary takes priority over the regular screens until the
	# player explicitly dismisses it. The dismissed flag is UI-session state
	# only and never written to the save.
	var victory := _victory_view()
	var victory_active := bool(victory.get("achieved", false)) and not _victory_dismissed
	# One compact chrome serves every port/flow page; navigation is omitted while
	# at sea, exactly like the old separate nav panel. During the演出 the chrome
	# must show the departure harbour and "在航 → 目的港" even though the domain
	# already settled the arrival, otherwise the header would reveal the ending.
	var chrome_data := data
	if _presentation != null:
		chrome_data = data.duplicate(true)
		chrome_data["at_sea"] = true
		chrome_data["current_port_id"] = String(_presentation_voyage.get("origin", data.get("current_port_id", "")))
		chrome_data["voyage"] = _presentation_voyage
	_build_top_chrome(app, chrome_data, not at_sea and _presentation == null)
	if victory_active:
		_hide_port_stage()
		_set_port_status_bar_visible(false)
		_build_status_banner()
		_screen_victory(victory)
		return
	if _presentation_on_stage():
		# Departure / arrival cut: the harbour *is* the screen, no page on top.
		_set_port_status_bar_visible(false)
		_build_status_banner()
		_screen_voyage_stage(data)
		return
	if _presentation_on_alert():
		# 探索演出 · 资源告急（4.2）：海图已被云层盖住，事件页换成告警页。
		# 必须在 `presenting` / `at_sea` 之前判断，否则会先挂出海图页。
		_hide_port_stage()
		_set_port_status_bar_visible(false)
		_build_status_banner()
		_screen_explore_alert(data)
		return
	if presenting:
		_hide_port_stage()
		_set_port_status_bar_visible(false)
		_build_status_banner()
		_screen_at_sea(data, data.get("voyage", null))
		return
	if at_sea:
		_hide_port_stage()
		_set_port_status_bar_visible(false)
		_build_status_banner()
		var voyage: Variant = data.get("voyage", null)
		if voyage is Dictionary and voyage.get("event", null) is Dictionary:
			_screen_event(data, voyage["event"])
		else:
			_screen_at_sea(data, voyage)
		return

	_build_status_banner()
	if not SCREENS.has(_active_screen) and not ["port_memory", "settlement", "sea_chart"].has(_active_screen):
		_active_screen = "overview"
	# The overview main view is a full-window 3D stage with edge HUD; the other
	# pages keep their own layout and hide the stage/status strip again.
	_set_port_status_bar_visible(_active_screen == "overview", data)
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
		"sea_chart":
			_screen_sea_chart(data)
		"port_memory":
			_screen_port_memory(data)
		"settlement":
			_screen_settlement(data)
		_:
			_screen_overview(data)
	_sync_port_stage(data)


## ---------------------------------------------------------------------------
## Compact top chrome (shared by every in-run page)
## ---------------------------------------------------------------------------
##
## Two dense rows replace the old header + stats bar + navigation stack:
##   row 1  brand / status / version | port · time · money · reputation | stage
##          toggle · diagnostics · refresh
##   row 2  remaining weight / cargo / coal / water / durability / damaged chip |
##          7 navigation buttons
## The panel is semi-transparent so the 3D stage shows through; the measured
## minimum height stays below `TOP_CHROME_MAX_HEIGHT`.
func _build_top_chrome(app: Dictionary, data: Dictionary, show_nav: bool) -> void:
	var panel := PanelContainer.new()
	panel.name = "TopChrome"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _chrome_style())
	_root_box.add_child(panel)
	_top_chrome = panel
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)

	var row := HBoxContainer.new()
	row.name = "Chrome"
	row.add_theme_constant_override("separation", 12)
	rows.add_child(row)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	row.add_child(brand)
	brand.add_child(_label("S T E A M   N A V I G A T O R", 9, COLOR_MUTED))
	brand.add_child(_label(_tr("ui.app.title", "Steam Navigator"), 22, COLOR_BRASS))
	row.add_child(_badge(
		_tr(String(app.get("status_key", "ui.status.ok")), ""),
		_status_badge_tone(app)
	))
	row.add_child(_label("v%s" % app.get("framework_version", "?"), 10, COLOR_MUTED))
	row.add_child(VSeparator.new())
	for stat in [
		[_tr("ui.label.port", "Port"), _current_port_label(data), COLOR_BRASS, ""],
		[_tr("ui.label.time", "Time"), String(data.get("time_label", "")), COLOR_TEXT, ""],
		[_tr("ui.label.money", "Money"), str(int(data.get("money", 0))), COLOR_BRASS, HUD_ICON_KEYS["money"]],
		[_tr("ui.label.reputation", "Reputation"), str(int(data.get("reputation", 0))), COLOR_GREEN, ""],
	]:
		row.add_child(_stat_chip(stat[0], stat[1], stat[2], 10, 16, String(stat[3])))
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(top_spacer)
	if _active_screen == "overview" and _port_stage_available():
		var stage_button := _small_chrome_button(
			_tr("ui.button.overview_2d", "2D overview")
			if _overview_stage_mode
			else _tr("ui.button.port_stage", "Port view (3D)"),
			_on_overview_stage_toggle
		)
		row.add_child(stage_button)
	row.add_child(_small_chrome_button(_tr("ui.button.log", "Diagnostics"), _show_diagnostics))
	row.add_child(_small_chrome_button(_tr("ui.button.refresh", "Refresh"), _refresh))

	var row2 := HBoxContainer.new()
	row2.name = "ChromeDetail"
	row2.add_theme_constant_override("separation", 14)
	rows.add_child(row2)
	var ship: Dictionary = data.get("ship", {})
	var detail_stats := [
		[_tr("ui.label.free_weight", ""), "%s / %s" % [
			_fmt(float(ship.get("free_weight", 0.0))),
			_fmt(float(ship.get("max_weight", 0.0))),
		], COLOR_TEXT, ""],
		[_tr("ui.label.free_capacity", ""), "%s / %s" % [
			_fmt(float(ship.get("free_cargo_capacity", 0.0))),
			_fmt(float(ship.get("cargo_capacity", 0.0))),
		], COLOR_TEAL, ""],
		[_tr("ui.label.coal", "Coal"), _fmt(float(ship.get("coal", 0.0))), COLOR_BRASS, HUD_ICON_KEYS["coal"]],
		[_tr("ui.label.water", "Water"), _fmt(float(ship.get("water", 0.0))), COLOR_TEAL, HUD_ICON_KEYS["water"]],
		[_tr("ui.label.durability", "Durability"), "%s / %s" % [
			_fmt(float(ship.get("durability", 0.0))),
			_fmt(float(ship.get("max_durability", 0.0))),
		], COLOR_GREEN, ""],
	]
	var damaged_modules := int(ship.get("damaged_modules", 0))
	if damaged_modules > 0:
		var worst := clampf(float(ship.get("worst_module_condition", 1.0)), 0.0, 1.0)
		detail_stats.append([
			_tr("ui.label.module_status", "Modules"),
			"%d · %d%%" % [damaged_modules, int(round(worst * 100.0))],
			COLOR_RED if worst <= 0.0 else COLOR_BRASS,
			"",
		])
	for stat in detail_stats:
		row2.add_child(_stat_chip(stat[0], stat[1], stat[2], 10, 16, String(stat[3])))
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(bottom_spacer)
	if show_nav:
		_build_nav_buttons(row2)


func _build_nav_buttons(parent: HBoxContainer) -> void:
	var visual_active := "overview" if _active_screen in ["port_memory", "settlement", "victory"] else _active_screen
	# Nested container so the compact navigation gap does not override the
	# resource-chip spacing of the chrome row it is mounted in.
	var nav := HBoxContainer.new()
	nav.name = "Nav"
	nav.add_theme_constant_override("separation", 2)
	parent.add_child(nav)
	for screen in SCREENS:
		var button := _button(_tr("ui.nav.%s" % screen, screen), _on_nav.bind(screen))
		button.custom_minimum_size = Vector2(64, 36)
		button.add_theme_font_size_override("font_size", 13)
		button.theme_type_variation = &"SNPrimaryButton" if screen == visual_active else &"SNGhostButton"
		nav.add_child(button)
	# The nautical chart is a toggle, not a nav page: M opens/closes it and the
	# button highlights only while the chart is up.
	var chart_button := _button(_tr("ui.nav.sea_chart", "海图"), _toggle_sea_chart)
	chart_button.custom_minimum_size = Vector2(64, 36)
	chart_button.add_theme_font_size_override("font_size", 13)
	chart_button.theme_type_variation = &"SNPrimaryButton" if _active_screen == "sea_chart" else &"SNGhostButton"
	nav.add_child(chart_button)


func _small_chrome_button(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.theme_type_variation = &"SNGhostButton"
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 12)
	return button


## Semi-transparent dark chrome so the 3D stage is visible but the HUD stays
## readable over bright sky, water or a banner.
func _chrome_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027451, 0.101961, 0.113725, 0.84)
	style.border_color = Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, 0.35)
	style.border_width_bottom = 1
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 14.0
	style.set_corner_radius_all(4)
	return style


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


## Current port (or the destination while at sea) for the always-visible info bar.
func _current_port_label(data: Dictionary) -> String:
	var port: Dictionary = data.get("current_port", {})
	if bool(data.get("at_sea", false)):
		var voyage: Variant = data.get("voyage", null)
		if voyage is Dictionary:
			var destination := String(voyage.get("destination", ""))
			if not destination.is_empty():
				return "%s → %s" % [_tr("ui.label.at_sea", ""), _port_name(destination)]
			# 探索演出：目的港要等 `explore.settle` 才知道，顶栏只能显示"探索中 → ？"。
			if not _presentation_explore.is_empty():
				return "%s → %s" % [
					_tr("ui.label.exploring", "探索中"),
					_tr("ui.label.unknown_destination", "？"),
				]
		return _tr("ui.label.at_sea", "")
	return _tr(String(port.get("name_key", "")), String(port.get("id", "")))


func _stat_chip(label_text: String, value_text: String, accent: Color, label_size: int = 9, value_size: int = 14, icon_key: String = "") -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	var icon := _hud_icon(icon_key)
	if icon != null:
		var texture_rect := TextureRect.new()
		texture_rect.texture = icon
		texture_rect.custom_minimum_size = Vector2(HUD_ICON_SIZE, HUD_ICON_SIZE)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(texture_rect)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 0)
	column.add_child(_label(label_text, label_size, COLOR_MUTED))
	column.add_child(_label(value_text, value_size, accent))
	chip.add_child(column)
	return chip


## Optional HUD icon resolved from whichever mounted content pack declares the
## logical key (`icon.money` -> `asset://<pack>/icon.money`). Missing packs and
## missing files both degrade to a text-only chip.
func _hud_icon(icon_key: String) -> Texture2D:
	if _context == null or icon_key.is_empty():
		return null
	if _hud_icon_cache.has(icon_key):
		return _hud_icon_cache[icon_key] as Texture2D
	var texture: Texture2D = null
	var logical_key := _context.assets.find_key(icon_key)
	if not logical_key.is_empty() and _context.assets.has(logical_key):
		texture = _context.assets.load_texture(logical_key)
	_hud_icon_cache[icon_key] = texture
	return texture


## Layout note: `project.godot` uses `canvas_items` stretch with a 1440x900 base
## and `expand` aspect, so a real 960x540 window renders a scaled 1600x900
## logical canvas: the two-row HUD keeps every chip and fits without clipping.
## There is therefore no compact/drop-secondary branch; the 960x540 acceptance
## screenshot is the evidence that the full layout stays in frame.
func _build_status_banner() -> void:
	if _status_message.is_empty():
		return
	var panel := _panel()
	panel.theme_type_variation = &"SNInsetPanel"
	_panel_add(panel, _badge(_status_message, SNBadge.Tone.DANGER if _status_is_error else SNBadge.Tone.SUCCESS))
	_root_box.add_child(panel)


## ---------------------------------------------------------------------------
## Bottom ship / port status strip (overview only, fixed shell layer)
## ---------------------------------------------------------------------------

## Builds (once) the fixed bottom strip and syncs its contents for the current
## view model: durability, hold usage, coal, water, damaged parts, the latest
## notice and the detail / depart / wait actions.
func _set_port_status_bar_visible(visible: bool, data: Dictionary = {}) -> void:
	if not visible:
		if _port_status_bar != null and is_instance_valid(_port_status_bar):
			_port_status_bar.visible = false
		_set_footer_visible(true)
		_set_page_bottom_reserve(false)
		return
	if data.is_empty():
		data = _last_port_view
	if data.is_empty():
		return
	_ensure_port_status_bar()
	_refresh_port_status_bar(data)
	if _port_status_bar != null:
		_port_status_bar.visible = true
	_set_footer_visible(false)
	_set_page_bottom_reserve(true)


func _ensure_port_status_bar() -> void:
	if _port_status_bar != null and is_instance_valid(_port_status_bar):
		return
	_port_status_bar = PanelContainer.new()
	_port_status_bar.name = "PortStatusBar"
	_port_status_bar.add_theme_stylebox_override("panel", _bottom_bar_style())
	_port_status_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_port_status_bar)
	_port_status_bar.anchor_left = 0.0
	_port_status_bar.anchor_top = 1.0
	_port_status_bar.anchor_right = 1.0
	_port_status_bar.anchor_bottom = 1.0
	_port_status_bar.offset_left = PORT_SIGN_MARGIN
	_port_status_bar.offset_right = -PORT_SIGN_MARGIN
	_port_status_bar.offset_top = -(PORT_STATUS_BAR_HEIGHT + PORT_STATUS_BAR_GAP)
	_port_status_bar.offset_bottom = -PORT_STATUS_BAR_GAP
	var content := HBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	_port_status_bar.add_child(content)
	# Above the page and footer, below the transition fade.
	if _fade_layer != null:
		move_child(_port_status_bar, _fade_layer.get_index())


func _refresh_port_status_bar(data: Dictionary) -> void:
	if _port_status_bar == null or not is_instance_valid(_port_status_bar):
		return
	var content := _port_status_bar.get_node_or_null("Content") as HBoxContainer
	if content == null:
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var ship: Dictionary = data.get("ship", {})
	var damaged := int(ship.get("damaged_modules", 0))
	var worst := clampf(float(ship.get("worst_module_condition", 1.0)), 0.0, 1.0)
	var chips := [
		[_tr("ui.label.durability", "Durability"), "%s / %s" % [
			_fmt(float(ship.get("durability", 0.0))),
			_fmt(float(ship.get("max_durability", 0.0))),
		], COLOR_GREEN, ""],
		[_tr("ui.label.cargo_hold", "Hold"), "%s / %s" % [
			_fmt(float(ship.get("cargo_used", 0.0))),
			_fmt(float(ship.get("cargo_capacity", 0.0))),
		], COLOR_TEAL, ""],
		[_tr("ui.label.coal", "Coal"), _fmt(float(ship.get("coal", 0.0))), COLOR_BRASS, HUD_ICON_KEYS["coal"]],
		[_tr("ui.label.water", "Water"), _fmt(float(ship.get("water", 0.0))), COLOR_TEAL, HUD_ICON_KEYS["water"]],
		[_tr("ui.label.damaged_modules", "Damaged modules"),
			"%d · %d%%" % [damaged, int(round(worst * 100.0))] if damaged > 0
			else _tr("ui.label.none", "None"),
			COLOR_RED if damaged > 0 and worst <= 0.0 else (COLOR_BRASS if damaged > 0 else COLOR_MUTED),
			""],
	]
	for chip in chips:
		content.add_child(_stat_chip(chip[0], chip[1], chip[2], 10, 15, String(chip[3])))
	content.add_child(VSeparator.new())
	var notice_box := VBoxContainer.new()
	notice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice_box.add_theme_constant_override("separation", 0)
	notice_box.add_child(_label(_tr("ui.label.latest_notice", "Latest notice"), 9, COLOR_MUTED))
	var notice_label := _label(_latest_notice_text(data), 12, COLOR_TEXT)
	notice_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notice_label.clip_text = true
	notice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice_box.add_child(notice_label)
	content.add_child(notice_box)
	# The detail drawer only exists over the live stage; the 2D overview already
	# shows every panel, so it gets no detail toggle.
	if _active_screen == "overview" and _overview_stage_mode and _port_stage_available():
		var detail_button := _button(
			_tr("ui.button.overview_main", "Back to scene")
			if _overview_detail
			else _tr("ui.button.overview_detail", "Detail overview"),
			_on_overview_detail_toggle
		)
		detail_button.custom_minimum_size = Vector2(0, 32)
		detail_button.add_theme_font_size_override("font_size", 13)
		content.add_child(detail_button)
	var depart_button := _button("%s ▶" % _tr("ui.nav.voyage", "Voyage"), _on_nav.bind("voyage"))
	depart_button.theme_type_variation = &"SNPrimaryButton"
	depart_button.custom_minimum_size = Vector2(0, 32)
	depart_button.add_theme_font_size_override("font_size", 13)
	content.add_child(depart_button)
	var wait_button := _button(
		_tr("ui.button.wait_hours", "Wait %d h") % 12,
		func() -> void: _run_command(&"port.wait", {"hours": 12})
	)
	wait_button.custom_minimum_size = Vector2(0, 32)
	wait_button.add_theme_font_size_override("font_size", 13)
	content.add_child(wait_button)


## Last pushed notice rendered with the same template filling as the overview log.
func _latest_notice_text(data: Dictionary) -> String:
	var notices: Array = data.get("notices", [])
	if notices.is_empty():
		return _tr("ui.label.no_notice", "No notices yet")
	var notice: Variant = notices[notices.size() - 1]
	if not (notice is Dictionary):
		return ""
	return _notice_text(notice)


func _bottom_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027451, 0.101961, 0.113725, 0.88)
	style.border_color = Color(COLOR_BRASS.r, COLOR_BRASS.g, COLOR_BRASS.b, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_top = 6.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 6.0
	return style


func _set_footer_visible(visible: bool) -> void:
	if _footer_team == null:
		return
	var footer := _footer_team.get_parent() as CanvasItem
	if footer != null:
		footer.visible = visible


## Reserve space under the scroll page so neither the footer nor the status strip
## covers the last row of a page.
func _set_page_bottom_reserve(bar_visible: bool) -> void:
	if _page_margin == null:
		return
	_page_margin.add_theme_constant_override(
		"margin_bottom",
		PAGE_BOTTOM_MARGIN_WITH_BAR if bar_visible else PAGE_BOTTOM_MARGIN
	)


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
	screen.stage_toggle_requested.connect(_on_overview_stage_toggle)
	screen.detail_toggle_requested.connect(_on_overview_detail_toggle)
	_root_box.add_child(screen)


func _overview_model(data: Dictionary) -> Dictionary:
	var model := data.duplicate(true)
	var port: Dictionary = data.get("current_port", {})
	var facilities: Array = []
	for facility in port.get("facilities", []):
		facilities.append(_facility_name(String(facility)))
	model["facility_labels"] = facilities
	model["banner_path"] = _port_banner_path(data)
	# 2.5D overview stage: availability is decided by the shell (scene present
	# and not previously failed); stage mode and the detail drawer are UI-session
	# state only.
	model["stage_available"] = _port_stage_available()
	model["stage_mode"] = _overview_stage_mode and _port_stage_available()
	model["overview_detail"] = _overview_detail
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


## ---------------------------------------------------------------------------
## Overview 3D port stage (2.5D fixed stage + edge signs + detail drawer)
## ---------------------------------------------------------------------------

## Toggles the 3D stage / 2D overview fallback. Leaving the stage also closes the
## detail drawer, because the drawer only makes sense over the live scene.
func _on_overview_stage_toggle() -> void:
	if not _port_stage_available():
		return
	_overview_stage_mode = not _overview_stage_mode
	if not _overview_stage_mode:
		_overview_detail = false
	_status_message = ""
	_refresh()


## Toggles the detailed 2D overview drawer over the 3D stage.
func _on_overview_detail_toggle() -> void:
	_overview_detail = not _overview_detail
	_status_message = ""
	_refresh()


## The stage scene is loaded lazily; a failed load permanently falls back to the
## 2D overview for this session instead of retrying on every refresh.
func _port_stage_available() -> bool:
	return not _port_stage_load_failed and ResourceLoader.exists(PORT_STAGE_SCENE_PATH)


func _ensure_port_stage_host() -> void:
	if _port_stage_host != null and is_instance_valid(_port_stage_host):
		return
	# Full-window 3D backdrop: directly above the flat Background and below every
	# UI layer, so the chrome / status bar / side signs float over the scene.
	_port_stage_host = SNStageHost.new()
	_port_stage_host.name = "PortStageHost"
	_port_stage_host.auto_load = false
	_port_stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_port_stage_host.fallback_requested.connect(_on_port_stage_fallback)
	add_child(_port_stage_host)
	_port_stage_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_port_stage_host, $Background.get_index() + 1)
	_port_stage_host.set_stage_visible(false)

	# Opaque backdrop for the detail drawer: covers the stage (but not the top
	# chrome or the bottom status strip) while the 2D overview panels are open.
	_ensure_overview_detail_backdrop()

	# Edge sign layer over the stage: fixed left/right columns driven by the
	# PortStage camera projection, never 3D raycasts. The layer itself ignores
	# the mouse so clicks outside the signs fall through to the page.
	_port_hotspot_layer = Control.new()
	_port_hotspot_layer.name = "PortStageHotspots"
	_port_hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_port_hotspot_layer)
	_port_hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_port_hotspot_layer, $PageMargin.get_index() + 1)
	_port_hotspot_layer.visible = false
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _ensure_overview_detail_backdrop() -> void:
	if _overview_detail_backdrop != null and is_instance_valid(_overview_detail_backdrop):
		return
	_overview_detail_backdrop = ColorRect.new()
	_overview_detail_backdrop.name = "OverviewDetailBackdrop"
	_overview_detail_backdrop.color = COLOR_BG
	_overview_detail_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview_detail_backdrop.visible = false
	add_child(_overview_detail_backdrop)
	_overview_detail_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_place_overview_detail_backdrop()


## Keeps the backdrop above the stage but below the scrolling page. `move_child`
## takes the final sibling index, so a forward move needs the page's current
## index while the backdrop is still behind it.
func _place_overview_detail_backdrop() -> void:
	if _overview_detail_backdrop == null or not is_instance_valid(_overview_detail_backdrop):
		return
	if _page_margin == null:
		return
	var page_index := _page_margin.get_index()
	if _overview_detail_backdrop.get_index() < page_index:
		return
	move_child(_overview_detail_backdrop, page_index)


func _sync_overview_detail_backdrop() -> void:
	if _overview_detail_backdrop == null or not is_instance_valid(_overview_detail_backdrop):
		_ensure_overview_detail_backdrop()
	if _overview_detail_backdrop == null:
		return
	var visible_now := _overview_detail and _port_stage_active()
	_overview_detail_backdrop.visible = visible_now
	if visible_now:
		_place_overview_detail_backdrop()


## Shows the shared 3D district. `force_station` is used by the voyage演出: during
## the departure / arrival beat the harbour must be visible even though no page of
## `STAGE_SCREENS` is active, and it always plays the harbour-authority shot.
func _sync_port_stage(data: Dictionary, force_station: String = "") -> void:
	var station := force_station if not force_station.is_empty() else String(STAGE_SCREENS.get(_active_screen, ""))
	# The 2D-overview toggle only affects the overview page; market / supply are
	# always presented over the district because that is where their station is.
	var stage_page_enabled := _active_screen != "overview" or _overview_stage_mode
	var should_show := (
		bool(data.get("has_run", false))
		and (not force_station.is_empty() or not bool(data.get("at_sea", false)))
		and not station.is_empty()
		and (not force_station.is_empty() or stage_page_enabled)
		and _port_stage_available()
	)
	if not should_show:
		_hide_port_stage()
		return
	_ensure_port_stage_host()
	if _port_stage_host == null:
		_hide_port_stage()
		return
	# The stage scene is loaded once and kept for the whole session: switching
	# between overview / market / supply only retargets the camera and the hull.
	var just_mounted := not _port_stage_host.has_stage()
	if just_mounted:
		if not _port_stage_host.load_stage(PORT_STAGE_SCENE_PATH):
			_on_port_stage_fallback("stage_scene_load_failed")
			return
	var framing := "stage" if _active_screen == "overview" or not force_station.is_empty() else "panel"
	_port_stage_host.bind_view_model(_port_stage_payload(data))
	_port_stage_host.set_stage_visible(true)
	_focus_stage_station(station, framing, just_mounted)
	_sync_overview_detail_backdrop()
	if _port_hotspot_layer != null:
		# Edge signs belong to the overview main view; the market / supply dock
		# panels carry their own navigation, and the voyage cut shows a clean shot.
		_port_hotspot_layer.visible = _active_screen == "overview" and not _overview_detail and force_station.is_empty()
	_refresh_port_hotspots_soon()


## Retargets the mounted stage to one of the adjacent stations. The stage API is
## a no-op when the station/framing already match, so this is safe to call on
## every page rebuild and never restarts the pan.
func _focus_stage_station(station: String, framing: String, immediate: bool) -> void:
	_stage_station = station
	_stage_framing = framing
	if _port_stage_host == null or not is_instance_valid(_port_stage_host):
		return
	var stage: Node = _port_stage_host.current_stage()
	if stage == null or not stage.has_method("focus_station"):
		return
	stage.call("focus_station", station, framing, immediate)


## True when the current page is drawn over the shared 3D district. Used by the
## market / supply pages to pick the dock-panel layout instead of a full page.
func _stage_backed_page() -> bool:
	return not String(STAGE_SCREENS.get(_active_screen, "")).is_empty() and _port_stage_available()


## Market / supply layout over the live stage: the scene keeps the left part of
## the window, the page becomes an opaque dock panel pinned to the right side
## (Bounty Train's station screens). Falls back to a plain full-width page when
## the stage is unavailable, so the pages always stay usable.
func _mount_dock_panel(screen: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "DockPanelRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var window := Control.new()
	window.name = "StageWindow"
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(window)
	var panel := PanelContainer.new()
	panel.name = "DockPanel"
	panel.theme_type_variation = &"SNPanel"
	panel.custom_minimum_size = Vector2(DOCK_PANEL_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(screen)
	row.add_child(panel)
	_root_box.add_child(row)


func _hide_port_stage() -> void:
	if _port_stage_host != null and is_instance_valid(_port_stage_host):
		_port_stage_host.set_stage_visible(false)
	if _overview_detail_backdrop != null and is_instance_valid(_overview_detail_backdrop):
		_overview_detail_backdrop.visible = false
	if _port_hotspot_layer != null and is_instance_valid(_port_hotspot_layer):
		_port_hotspot_layer.visible = false
		for child in _port_hotspot_layer.get_children():
			_port_hotspot_layer.remove_child(child)
			child.queue_free()


func _port_stage_active() -> bool:
	return (
		_overview_stage_mode
		and _active_screen == "overview"
		and _port_stage_host != null
		and is_instance_valid(_port_stage_host)
		and _port_stage_host.is_stage_visible()
	)


func _port_stage_payload(data: Dictionary) -> Dictionary:
	var port: Dictionary = data.get("current_port", {})
	var ship: Dictionary = data.get("ship", {})
	var port_payload := {
		"id": String(port.get("id", "")),
		"size": String(port.get("size", "medium")),
		"facilities": Array(port.get("facilities", [])).duplicate(),
		"banner_path": _port_banner_path(data),
	}
	# Optional diorama inputs are forwarded only when present, so the stage keeps
	# its defaults until content exposes them.
	if port.get("facility_visuals", null) is Dictionary:
		port_payload["facility_visuals"] = (port["facility_visuals"] as Dictionary).duplicate(true)
	if port.get("town_visuals", null) is Dictionary:
		port_payload["town_visuals"] = (port["town_visuals"] as Dictionary).duplicate(true)
	if port.get("diorama", null) is Dictionary:
		port_payload["diorama"] = (port["diorama"] as Dictionary).duplicate(true)
		var density := String((port["diorama"] as Dictionary).get("density", ""))
		if not density.is_empty():
			port_payload["density"] = density
	if port.get("palette", null) is Dictionary:
		port_payload["palette"] = (port["palette"] as Dictionary).duplicate(true)
	if not String(port.get("landmark_path", "")).is_empty():
		port_payload["landmark_path"] = String(port.get("landmark_path", ""))
	return {
		"port": port_payload,
		"ship": {
			"hull_model_path": String(ship.get("hull_model_path", "")),
			"hull_tier": int(ship.get("hull_tier", 1)),
		},
	}


## Resolved physical path of the port banner (content-mod raw PNG) or "".
func _port_banner_path(data: Dictionary) -> String:
	var port: Dictionary = data.get("current_port", {})
	var banner_key := String(port.get("banner_asset", ""))
	var source_mod := String(port.get("source_mod", ""))
	if banner_key.is_empty() or source_mod.is_empty() or _context == null:
		return ""
	var logical_key := "asset://%s/%s" % [source_mod, banner_key]
	if _context.assets.has(logical_key):
		return _context.assets.resolve(logical_key)
	return ""


func _on_port_stage_fallback(reason: String) -> void:
	if _port_stage_load_failed:
		return
	_port_stage_load_failed = true
	_overview_stage_mode = false
	_overview_detail = false
	_hide_port_stage()
	push_warning("PortStage unavailable (%s), falling back to the 2D overview" % reason)
	_set_status(_tr("ui.error.port_stage_unavailable", "3D port stage unavailable, showing the 2D overview."), true)
	_refresh.call_deferred()


func _on_viewport_size_changed() -> void:
	if _port_stage_active():
		_refresh_port_hotspots_soon()


## Two deferred passes: the first runs after the container re-layout, the second
## catches the SubViewport resize that the stage uses for camera projection.
func _refresh_port_hotspots_soon() -> void:
	_layout_port_hotspots.call_deferred()
	_delayed_port_hotspot_pass.call_deferred()


func _delayed_port_hotspot_pass() -> void:
	_layout_port_hotspots.call_deferred()


## Fixed edge signboards replacing the old floating labels: facilities are split
## by their projected x (< 0.5 -> left column, otherwise right column), sorted by
## projected y and stacked at the screen edges. The right column reserves its
## bottom slot for the permanent "voyage" sign. Layout keeps clear of the compact
## top chrome and the bottom status strip, and is redone on every resize.
func _layout_port_hotspots() -> void:
	if _port_hotspot_layer == null or not is_instance_valid(_port_hotspot_layer):
		return
	for child in _port_hotspot_layer.get_children():
		_port_hotspot_layer.remove_child(child)
		child.queue_free()
	if not _port_stage_active() or _overview_detail:
		return
	var stage := _port_stage_host.current_stage()
	if stage == null or not stage.has_method("facility_screen_anchor"):
		return
	var anchors: Dictionary = stage.facility_anchors() if stage.has_method("facility_anchors") else {}
	var layer_size := _port_hotspot_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		layer_size = get_viewport_rect().size
	var top_safe := _port_hud_top_safe()
	var bottom_safe := _port_hud_bottom_safe(layer_size)
	var left: Array = []
	var right: Array = []
	for raw_facility in anchors.keys():
		var facility := String(raw_facility)
		if not PORT_STAGE_FACILITY_SCREENS.has(facility):
			continue
		var normalized: Vector2 = stage.facility_screen_anchor(facility)
		if normalized == Vector2.ZERO:
			continue
		var entry := {"facility": facility, "y": normalized.y}
		if normalized.x < 0.5:
			left.append(entry)
		else:
			right.append(entry)
	left.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	right.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	_layout_sign_column(left, false, top_safe, bottom_safe, layer_size)
	_layout_sign_column(right, true, top_safe, bottom_safe, layer_size)
	# Permanent voyage sign pinned to the bottom of the right column.
	var voyage_sign := _port_sign(
		"%s ▶" % _tr("ui.nav.voyage", "Voyage"),
		_on_port_hotspot.bind("voyage"),
		true,
		"voyage",
		-1
	)
	voyage_sign.name = "Hotspot_voyage"
	voyage_sign.position = Vector2(
		layer_size.x - PORT_SIGN_MARGIN - PORT_SIGN_WIDTH,
		bottom_safe - PORT_SIGN_HEIGHT
	)
	_port_hotspot_layer.add_child(voyage_sign)


func _layout_sign_column(entries: Array, right_column: bool, top_safe: float, bottom_safe: float, layer_size: Vector2) -> void:
	var count := entries.size()
	if count == 0:
		return
	var area_top := top_safe + 8.0
	var area_bottom := bottom_safe - 8.0
	if right_column:
		# Keep the pinned voyage sign out of the facility stack.
		area_bottom -= PORT_SIGN_HEIGHT + PORT_SIGN_GAP
	var total := count * PORT_SIGN_HEIGHT + (count - 1) * PORT_SIGN_GAP
	var start := area_top + maxf(0.0, (area_bottom - area_top - total) * 0.5)
	var x := (
		layer_size.x - PORT_SIGN_MARGIN - PORT_SIGN_WIDTH
		if right_column
		else PORT_SIGN_MARGIN
	)
	for index in count:
		var facility := String(entries[index]["facility"])
		var label := (
			"◀ %s" % _facility_sign_name(facility)
			if right_column
			else "%s ▶" % _facility_sign_name(facility)
		)
		var button := _port_sign(label, _on_port_hotspot.bind(facility), false, facility, 1 if right_column else -1)
		button.name = "Hotspot_%s" % facility
		button.position = Vector2(x, start + index * (PORT_SIGN_HEIGHT + PORT_SIGN_GAP))
		_port_hotspot_layer.add_child(button)


## One fixed signboard at the scene edge: themed wood/iron/brass plate with a
## painted facility emblem, a real arrow triangle pointing into the scene and a
## brass hover halo. Falls back to the plain themed button if the component is
## unavailable, so the stage never loses its navigation.
func _port_sign(text: String, callback: Callable, primary: bool, facility: String = "", arrow: int = -1) -> Button:
	var sign_size := Vector2(PORT_SIGN_WIDTH, PORT_SIGN_HEIGHT)
	var button: Button
	if HARBOR_SIGN_SCRIPT != null:
		button = HARBOR_SIGN_SCRIPT.new()
		button.call("configure", text, primary, facility, arrow)
	else:
		button = _button(text, callback)
		button.theme_type_variation = &"SNGhostButton"
	button.custom_minimum_size = sign_size
	button.size = sign_size
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_hover_color", COLOR_BRASS)
	button.tooltip_text = _tr("ui.hint.port_hotspot", "Open this facility")
	if button.get_signal_connection_list("pressed").is_empty():
		button.pressed.connect(callback)
	return button


## Bottom edge of the compact top chrome in window coordinates; fallback keeps
## the first (not yet laid out) pass from drawing signs over the HUD.
func _port_hud_top_safe() -> float:
	if _top_chrome != null and is_instance_valid(_top_chrome):
		var rect := _top_chrome.get_global_rect()
		if rect.size.y > 0.0:
			return rect.end.y + 8.0
	return TOP_CHROME_MAX_HEIGHT + 8.0


## Top edge of the bottom status strip (or the footer reserve) in window coords.
func _port_hud_bottom_safe(layer_size: Vector2) -> float:
	if _port_status_bar != null and is_instance_valid(_port_status_bar) and _port_status_bar.visible:
		var rect := _port_status_bar.get_global_rect()
		if rect.size.y > 0.0:
			return rect.position.y - 8.0
	return layer_size.y - 48.0


func _on_port_hotspot(facility: String) -> void:
	if facility == "voyage":
		_on_nav("voyage")
		return
	var screen_id: StringName = PORT_STAGE_FACILITY_SCREENS.get(facility, &"")
	if screen_id == &"":
		return
	_on_nav(String(screen_id))


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
	if _stage_backed_page():
		_mount_dock_panel(screen)
	else:
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
	if _stage_backed_page():
		_mount_dock_panel(screen)
	else:
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
	screen.navigation_requested.connect(_on_screen_navigation)
	_root_box.add_child(screen)


func _on_voyage_selection_changed(destination_id: String, strategy_id: String) -> void:
	_selected_destination = destination_id
	_selected_strategy = strategy_id
	_refresh()


## Full-window nautical chart: the query result is passed straight into the
## screen; departures route through the voyage page so the boiler strategy is
## still confirmed there before `voyage.start` fires.
func _screen_sea_chart(data: Dictionary) -> void:
	var result := _context.queries.execute(&"sea_chart.view")
	var view_model: Dictionary = result.get("data", {}) if bool(result.get("ok", false)) else {}
	var screen: Variant = SEA_CHART_SCREEN_SCENE.instantiate()
	screen.bind(view_model, Callable(self, "_tr"))
	screen.close_requested.connect(_on_sea_chart_closed)
	screen.voyage_requested.connect(_on_sea_chart_voyage)
	screen.explore_requested.connect(_on_explore_requested)
	screen.purchase_clue_requested.connect(_on_purchase_clue_requested)
	_root_box.add_child(screen)


## 海图面板「循此线索出航」：跑 `explore.start`，成功即进入探索演出。
## 策略沿用出航页当前选择；还没有选择时用标准锅炉（注册表按 tag 解析，框架不写死
## `core:*` ID —— 与"框架无具体内容 ID"不变量一致）。
func _on_explore_requested(clue_id: String) -> void:
	var strategy := _selected_strategy
	if strategy.is_empty():
		strategy = _standard_strategy_id()
	_run_command(&"explore.start", {"clue_id": clue_id, "strategy_id": strategy})


## 海图面板「购买线索」：`clue.buy` 成功后 `_run_command` 会重建当前页（仍是海图页），
## 查询重新执行即带出新的 `clues` 列表。
func _on_purchase_clue_requested() -> void:
	_run_command(&"clue.buy", {})


func _toggle_sea_chart() -> void:
	if _active_screen == "sea_chart":
		_on_sea_chart_closed()
	else:
		_on_nav("sea_chart")


## M/Esc shortcuts are only meaningful inside an active, in-port run without a
## pending victory summary; every other state keeps the keys untouched.
func _sea_chart_available() -> bool:
	if _context == null or not _context.has_run():
		return false
	# No chart, no navigation while the voyage演出 owns the screen.
	if _presentation != null:
		return false
	if bool(_context.state.data.get("at_sea", false)):
		return false
	var victory := _victory_view()
	return not (bool(victory.get("achieved", false)) and not _victory_dismissed)


func _on_sea_chart_closed() -> void:
	var target := _sea_chart_return
	if not SCREENS.has(target):
		target = "voyage"
	_on_nav(target)


func _on_sea_chart_voyage(port_id: String) -> void:
	_selected_destination = port_id
	_on_nav("voyage")


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_M and (_active_screen == "sea_chart" or _sea_chart_available()):
		_toggle_sea_chart()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and _active_screen == "sea_chart":
		_on_sea_chart_closed()
		get_viewport().set_input_as_handled()


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
	_reset_voyage_presentation()
	_status_message = ""
	_overview_detail = false
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


## At-sea page. While a voyage presentation is running this is the chart演出 page
## (moving ship + voyage strip); with no presentation (legacy save already at sea)
## it falls back to the same chart page without animation data.
func _screen_at_sea(data: Dictionary, voyage: Variant) -> void:
	var chart_vm: Dictionary = {}
	var result := _context.queries.execute(&"sea_chart.view")
	if bool(result.get("ok", false)):
		chart_vm = result.get("data", {})
	# The query reports the harbour the domain already put the ship in. While the
	#演出 is running the chart should mark the departure harbour instead, so the
	# pulsing "you are here" ring does not sit on the destination before arrival.
	if _presentation != null and not chart_vm.is_empty():
		chart_vm["current_port_id"] = String(_presentation_voyage.get("origin", chart_vm.get("current_port_id", "")))
		chart_vm["at_sea"] = true
	# While presenting, the endpoints come from the presentation session: the
	# domain voyage record is gone the moment an eventless voyage arrives.
	var endpoints: Variant = _presentation_voyage if _presentation != null else voyage
	var model := {
		"chart": chart_vm,
		"voyage": endpoints if endpoints is Dictionary else {},
		"positions": _presentation_positions(endpoints),
		# 航路点来自坐标世界的完整航线表（`WorldMap.edges`），不是 `sea_chart.view`
		# 的迷雾过滤结果：航线发现与否是玩家视角的规则，演出取用程序内部事实
		# （验收反馈 F4）。
		"route_path": _presentation_route_path(endpoints),
	}
	# 探索演出：航线取自 `explore.start` 的 presentation（终点是搜索区中心，不是
	# 已发现的港口），并把未知终点交给海图画虚线预测线 + `?`。`top_inset` 让 `?`
	# 被顶部 chrome / 状态条挡住时 clamp 到可见区（截图验收发现的遮挡）。
	if not _presentation_explore.is_empty():
		model["route_path"] = _presentation_explore.get("route_path", [])
		var zone: Variant = _presentation_explore.get("zone", null)
		if zone is Dictionary and not (zone as Dictionary).is_empty():
			model["unknown_destination"] = {
				"x": float((zone as Dictionary).get("x", 0.0)),
				"y": float((zone as Dictionary).get("y", 0.0)),
				"label_key": "ui.label.unknown_destination",
				"top_inset": _chart_top_inset(),
			}
		# 正在追的这条线索不画在演出海图上：它的虚线圆和 `?` 终点会重叠，反而看不清
		# 探索目标；其它线索保留（玩家仍能看到别的传闻）。
		_filter_chasing_clue(chart_vm)
	if _presentation != null:
		model["presentation"] = _presentation.snapshot()
	var screen: Variant = AT_SEA_SCREEN_SCENE.instantiate()
	screen.bind(model, Callable(self, "_tr"))
	screen.skip_requested.connect(_on_skip_presentation)
	_at_sea_screen = screen
	# 航行页是全窗海面：挂在滚动容器之外，页面边距也不再裁掉海图（F3）——
	# 只有顶部 chrome 浮在它上面。
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fullscreen_layer.add_child(screen)


## 顶部固定 chrome（顶栏 + 状态提示条）占掉的高度。航行页挂在全窗层、海图从窗口
## 顶边开始画，所以未知终点标记要把它当作不可用区：布局还没排完时用子控件的最小
## 高度估算，第一帧也不会把 `?` 藏在顶栏后面。
func _chart_top_inset() -> float:
	var total := 24.0
	var separation := 8.0
	if _root_box == null:
		return total
	for child in _root_box.get_children():
		if child is Control:
			total += (child as Control).get_combined_minimum_size().y + separation
	return total


## 正在追的线索不画在探索演出的海图上：它的虚线圆和未知终点 `?` 会重叠，反而
## 让玩家看不清自己在往哪走。其它线索保留，演出结束后海图页仍显示完整线索层。
func _filter_chasing_clue(chart_vm: Dictionary) -> void:
	var clue_id := String(_presentation_explore.get("clue_id", ""))
	var clues: Variant = chart_vm.get("clues", null)
	if clue_id.is_empty() or not (clues is Array):
		return
	var kept: Array = []
	for entry in (clues as Array):
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == clue_id:
			continue
		kept.append(entry)
	chart_vm["clues"] = kept


## World positions of the voyage endpoints. The chart only knows discovered
## ports, and the destination of a fresh voyage usually is not discovered yet,
## so the shell reads them from the twin world it already owns.
func _presentation_positions(voyage: Variant) -> Dictionary:
	var positions: Dictionary = {}
	if not (voyage is Dictionary) or _context == null:
		return positions
	var world_map: Variant = _context.state.data.get("world_map", null)
	if not (world_map is Dictionary) or (world_map as Dictionary).is_empty():
		return positions
	var world := WorldMap.from_dict(world_map)
	for key in ["origin", "destination"]:
		var port_id := String((voyage as Dictionary).get(key, ""))
		if port_id.is_empty():
			continue
		var port := world.get_port(port_id)
		if port.is_empty():
			continue
		positions[port_id] = {"x": port.position.x, "y": port.position.y}
	return positions


## 航路点表：从坐标世界的航线表（`WorldMap.edges`，旧世界回退现算）取 origin →
## destination 的完整折线，按「起点在 origin」的方向返回扁平数组 `[x0,y0,…]`。
##
## 它**不经过** `sea_chart.view` 的战争迷雾过滤：迷雾只决定玩家能不能在图上看到
## 这条线，演出（船位、进度、取景）取的是程序内部事实（验收反馈 F4）。
## 世界表里确实没有这条边时返回空数组，航行页再退回两点直线。
func _presentation_route_path(voyage: Variant) -> Array:
	if not (voyage is Dictionary) or _context == null:
		return []
	var world_map: Variant = _context.state.data.get("world_map", null)
	if not (world_map is Dictionary) or (world_map as Dictionary).is_empty():
		return []
	var world := WorldMap.from_dict(world_map)
	var origin_id := String((voyage as Dictionary).get("origin", ""))
	var destination_id := String((voyage as Dictionary).get("destination", ""))
	var from_port := world.get_port(origin_id)
	var to_port := world.get_port(destination_id)
	if from_port.is_empty() or to_port.is_empty():
		return []
	var route := WorldOps.route_between(world, from_port, to_port)
	var raw: Variant = route.get("path", null)
	if raw == null:
		raw = route.get("bezier_path", null)
	var path := _as_path_points(raw)
	if path.size() < 2:
		return []
	# 航线表只存一个方向；按几何位置（而不是 from/to 字段）决定要不要反转，
	# 这样旧世界现算出来的航线也能对齐。
	if path[0].distance_to(from_port.position) > path[path.size() - 1].distance_to(from_port.position):
		var reversed := PackedVector2Array()
		for index in range(path.size() - 1, -1, -1):
			reversed.append(path[index])
		path = reversed
	# 世界表里的路点是按存档精度存的（2 位小数），端点直接对齐港口坐标：演出的
	# 起点必须正好是出发港图标，终点正好是目的港图标（阶段 3 的接缝不变量）。
	path[0] = from_port.position
	path[path.size() - 1] = to_port.position
	# 航路点保持世界表里的原始精度，不做量化。
	var flat: Array = []
	for point in path:
		flat.append(point.x)
		flat.append(point.y)
	return flat


static func _as_path_points(raw: Variant) -> PackedVector2Array:
	if raw is PackedVector2Array:
		return raw
	if raw is Array:
		return VoyagePresentation.unpack_path(raw as Array)
	return PackedVector2Array()


## ---------------------------------------------------------------------------
## Voyage presentation (nautical chart phase 3)
## ---------------------------------------------------------------------------

## True while the chart演出 page should be mounted. `DEPARTURE_VEIL` is excluded
## on purpose: the clouds first cover the 3D harbour shot, then the chart takes over.
func _presentation_on_chart() -> bool:
	if _presentation == null:
		return false
	return _presentation.phase in [
		VoyagePresentation.Phase.AT_SEA,
		VoyagePresentation.Phase.EVENT_APPROACH,
		VoyagePresentation.Phase.EVENT_RESUME,
		VoyagePresentation.Phase.ARRIVAL_APPROACH,
	]


## True while the 3D harbour is the screen: the ship sailing out (departure) and
## the ship entering the destination harbour (arrival).
func _presentation_on_stage() -> bool:
	if _presentation == null:
		return false
	return _presentation.phase in [
		VoyagePresentation.Phase.DEPARTURE_3D,
		VoyagePresentation.Phase.ARRIVAL_HARBOR,
	]


## True while an exploration is stopped at the 4.2 resource-alert decision.
## `EVENT_WAIT` is the same phase a normal risk event uses; only an exploration
## presentation with a pending alert mounts the alert page instead of the event
## screen / chart page.
func _presentation_on_alert() -> bool:
	if _presentation == null or _presentation_explore.is_empty():
		return false
	return _presentation.phase == VoyagePresentation.Phase.EVENT_WAIT


## 探索演出是否已被「掉头返航」提前结算（`explore.decide(turn_back)` 已经把船送回
## 出发港并写好 summary）。此时 `ARRIVAL_READY` 不能再调 `explore.settle`。
func _explore_returned() -> bool:
	return bool(_presentation_explore.get("returned", false))


## Full-window 3D cut. The stage is forced onto the harbour-authority shot even
## though no `STAGE_SCREENS` page is active, and the beat is kicked off *after*
## the stage has been (re)mounted so the high shot starts from a settled camera.
func _screen_voyage_stage(data: Dictionary) -> void:
	# Departure plays at the harbour the ship is leaving, which `port.view` no
	# longer reports once the command has already settled the arrival; the origin
	# view was captured from the last in-port rebuild. Arrival uses the live view
	# (the ship is now at the destination).
	var stage_data := data
	if _presentation.phase == VoyagePresentation.Phase.DEPARTURE_3D \
			and not _presentation_origin_view.is_empty():
		stage_data = _presentation_origin_view
	_sync_port_stage(stage_data, PortStage.DEFAULT_STATION)
	if _presentation.phase == VoyagePresentation.Phase.DEPARTURE_3D:
		_begin_stage_departure()
	else:
		_begin_stage_arrival()


## Starts the演出 for a voyage that `voyage.start` already resolved. `hours` is
## the voyage's own schedule, so the animation lasts as long as the voyage says.
func _start_voyage_presentation(data: Dictionary) -> void:
	# `voyage.start` erases the in-flight `state.data["voyage"]` as soon as the
	# arrival settles, so the presentation reads the endpoints and duration from
	# the command's preview instead of the (possibly already cleared) voyage.
	var preview: Dictionary = data.get("preview", {}) if data.get("preview", null) is Dictionary else {}
	var origin := String(preview.get("origin_id", ""))
	var destination := String(preview.get("destination_id", ""))
	var hours := float(preview.get("duration_hours", 0.0))
	if hours <= 0.0:
		var voyage: Variant = _context.state.data.get("voyage", null)
		if voyage is Dictionary:
			hours = float((voyage as Dictionary).get("arrival_time", 0.0)) \
				- float((voyage as Dictionary).get("departure_time", 0.0))
	if hours <= 0.0:
		hours = VoyagePresentation.FALLBACK_HOURS
	_presentation_voyage = {
		"origin": origin,
		"destination": destination,
		"departure_time": float(preview.get("departure_time", _context.state.now())),
		"arrival_time": float(preview.get("arrival_time", _context.state.now() + hours)),
		"distance": float(preview.get("distance", 0.0)),
		"strategy_id": String(preview.get("strategy_id", "")),
	}
	_presentation_summary = {}
	var summary: Variant = data.get("summary", null)
	if summary is Dictionary:
		_presentation_summary = summary
	var event: Variant = data.get("event", null)
	var event_at := -1.0
	if event is Dictionary:
		event_at = VoyagePresentation.DEFAULT_EVENT_PROGRESS
	_presentation = VoyagePresentation.new()
	_presentation.plan(hours, event_at)
	# Capture the origin harbour view *before* anything rebuilds: the departure cut
	# is filmed at the harbour being left, and `port.view` has already moved on.
	_presentation_origin_view = _last_port_view.duplicate(true)
	_presentation.departure_3d_seconds = PortStage.VOYAGE_BEAT_SECONDS
	_presentation.harbor_seconds = PortStage.VOYAGE_BEAT_SECONDS
	_presentation.begin_departure()
	_sync_cloud_veil(0.0)
	_set_status("出航，航向 %s。" % _port_name(destination), false)


## 探索演出（阶段 4.1/4.2）。`explore.start` 已经在领域层扣完资源并写好
## `explore_voyage`，这里保存它返回的 `presentation`（origin / zone / route_path /
## total_hours / alert_needed / alert_progress）并启动与普通航行相同的状态机：
## 3D 离港 → 云层 → 海图。与普通航行的差别：目的地暂时为空（抵达时才由
## `explore.settle` 决定）、海图航线终点是搜索区中心、以及 4.2 的途中资源告急
## 决策点（`alert_needed` 时事件位由 Core 的 `alert_progress` 决定，命中后停在
## `EVENT_WAIT` 挂告警页）。
func _start_explore_presentation(data: Dictionary) -> void:
	var presentation: Dictionary = {}
	if data.get("presentation", null) is Dictionary:
		presentation = (data["presentation"] as Dictionary).duplicate(true)
	var preview: Dictionary = {}
	if data.get("preview", null) is Dictionary:
		preview = data["preview"] as Dictionary
	var origin := String(presentation.get("origin", ""))
	var hours := float(presentation.get("total_hours", 0.0))
	if hours <= 0.0:
		hours = float(preview.get("duration_hours", 0.0))
	if hours <= 0.0:
		hours = VoyagePresentation.FALLBACK_HOURS
	# 4.2：告警决策点来自 Core JSON（`alert_progress`，默认 0.5）；不需要告急时
	# 传 -1，状态机就按「没有途中事件」跑完整段航程。
	var alert_needed := bool(presentation.get("alert_needed", false))
	var alert_progress := float(presentation.get("alert_progress", VoyagePresentation.DEFAULT_EVENT_PROGRESS))
	_presentation_explore = presentation
	_presentation_explore["alert_needed"] = alert_needed
	_presentation_explore["alert_progress"] = alert_progress
	_presentation_voyage = {
		"kind": "explore",
		"origin": origin,
		# 目的港在 `explore.settle` 之前不存在：追查线索时玩家只知道搜索区。
		"destination": "",
		"clue_id": String(presentation.get("clue_id", "")),
		"departure_time": float(presentation.get("departure_time", _context.state.now())),
		"arrival_time": float(presentation.get("arrival_time", _context.state.now() + hours)),
		"distance": float(preview.get("distance", 0.0)),
		"strategy_id": String(presentation.get("strategy_id", _selected_strategy)),
	}
	_presentation_summary = {}
	_presentation = VoyagePresentation.new()
	_presentation.plan(hours, alert_progress if alert_needed else -1.0)
	_presentation_origin_view = _last_port_view.duplicate(true)
	_presentation.departure_3d_seconds = PortStage.VOYAGE_BEAT_SECONDS
	_presentation.harbor_seconds = PortStage.VOYAGE_BEAT_SECONDS
	_presentation.begin_departure()
	_sync_cloud_veil(0.0)
	_set_status("%s…" % _tr("ui.label.exploring", "探索中"), false)


## 抵达海图终点后由 Shell 主动结算探索：目的地（目标港或失败后的漂流港）与
## `summary.explore` 只存在于命令结果里。失败时把错误交给状态栏并返回 false，
## 调用方负责退回出发港的入港镜头。
func _settle_exploration() -> bool:
	var result := _context.commands.execute(&"explore.settle", {})
	if not bool(result.get("ok", false)):
		_set_status(_error_text(result), true)
		return false
	var data: Dictionary = result.get("data", {})
	var destination := String(data.get("destination", ""))
	if not destination.is_empty():
		_presentation_voyage["destination"] = destination
	var summary: Variant = data.get("summary", null)
	if summary is Dictionary:
		_presentation_summary = summary
	return true


func _tick_presentation(delta: float) -> void:
	if _presentation == null:
		return
	var step := _presentation.tick(delta)
	_sync_cloud_veil(delta)
	# The port stage owns the 3D half of the cut; stepping it from the shell keeps
	# it in lockstep with the state machine (and lets headless tests step both).
	_advance_stage_voyage(delta)
	# The chart page stays mounted through the arrival veil (it is covered by the
	# clouds, then swapped for the harbour), so it must keep receiving snapshots:
	# `ARRIVAL_APPROACH` is what pushes the chart framing in before the cut. Feeding
	# only `AT_SEA` used to freeze the framing at 1x for the whole arrival.
	if _at_sea_screen != null and _presentation_on_chart():
		_at_sea_screen.set_presentation(_presentation.snapshot())
	match step:
		VoyagePresentation.Step.DEPARTED:
			if not _presentation_explore.is_empty():
				# 探索出航还没有目的港：只说"探索中"，不能拼出一个空的目的港名。
				_set_status("%s…" % _tr("ui.label.exploring", "探索中"), false)
			else:
				_set_status("离港，航向 %s。" % _port_name(String(_presentation_voyage.get("destination", ""))), false)
		VoyagePresentation.Step.AT_SEA_STARTED:
			_rebuild_ui()
		VoyagePresentation.Step.EVENT_READY:
			# The decision is pushed to the player, then the veil clears over it.
			# Exploration (4.2) mounts the resource-alert page instead of the chart
			# / event page; normal voyages keep the regular event screen.
			_rebuild_ui()
			_presentation.begin_event_reveal()
		VoyagePresentation.Step.ARRIVAL_READY:
			# 探索演出：先把目的地结算出来（目标港 / 失败漂流港），再换成目的港的
			# 3D 入港镜头——普通航行的目的地出发时就已经知道，探索要等这一拍。
			# 掉头返航（4.2）已经在 `explore.decide(turn_back)` 里结算过，这里不能再
			# settle：`explore_voyage` 已被清空，再调只会得到 `not_exploring`。
			if not _presentation_explore.is_empty() \
					and not _explore_returned() \
					and not _settle_exploration():
				# 结算失败（状态被外部改动 / 没有 explore_voyage）：退回出发港，
				# 不把玩家留在"没有目的地的入港镜头"里。错误已由结算函数写进状态栏。
				_presentation_explore = {}
				_presentation_summary = {}
				_presentation_voyage["destination"] = String(
					_presentation_voyage.get("origin", "")
				)
				_rebuild_ui()
				_begin_stage_arrival()
				return
			# Charts are covered: swap in the destination harbour from the high
			# "arriving from sea" shot, then let the camera come down.
			_set_status("抵达 %s。" % _port_name(String(_presentation_voyage.get("destination", ""))), false)
			_rebuild_ui()
			_begin_stage_arrival()
		VoyagePresentation.Step.DONE:
			_finish_presentation()
		_:
			pass


## Ends the presentation on the settlement screen (or the overview when the
## command produced no summary, e.g. a legacy save).
func _finish_presentation() -> void:
	_settlement_summary = _presentation_summary.duplicate(true)
	_active_screen = "settlement" if not _settlement_summary.is_empty() else "overview"
	_status_message = ""
	_presentation = null
	# 4.2：探索上下文（含 `returned` 掉头标记）随演出一起清掉；下一次探索重新写入。
	_presentation_explore = {}
	_at_sea_screen = null
	_sync_cloud_veil(0.0)
	_rebuild_ui()


func _on_skip_presentation() -> void:
	if _presentation == null:
		return
	_presentation.skip()


## Steps the port stage's departure/arrival beat, if it is playing one.
func _advance_stage_voyage(delta: float) -> void:
	var stage := _port_stage()
	if stage == null or not stage.is_voyage_transitioning():
		return
	stage.advance_voyage(delta)


func _port_stage() -> PortStage:
	if _port_stage_host == null:
		return null
	return _port_stage_host.current_stage() as PortStage


## Starts the 3D harbour beat for a presentation phase. Called right after the
## stage has been (re)mounted, so the high shot is set up before the first frame.
func _begin_stage_departure() -> void:
	var stage := _port_stage()
	if stage == null:
		# No 3D stage available: skip straight to the veil so the演出 still runs.
		_presentation.finish_departure_beat()
		return
	if stage.voyage_mode() == "depart":
		return
	stage.begin_departure(_presentation.departure_3d_seconds)


func _begin_stage_arrival() -> void:
	var stage := _port_stage()
	if stage == null:
		_presentation.skip_harbor_beat()
		return
	stage.begin_arrival(_presentation.harbor_seconds)


## Drops any in-flight presentation (new run, load, give-up paths). The veil is
## pulled back to clear so a stale overlay never covers the next screen.
func _reset_voyage_presentation() -> void:
	_presentation = null
	_presentation_summary = {}
	# 4.2：探索上下文（含告警决策点与 `returned` 掉头标记）也一起清掉。
	_presentation_explore = {}
	_presentation_voyage = {}
	_presentation_origin_view = {}
	_at_sea_screen = null
	if _cloud_veil != null:
		_cloud_veil.cover = 0.0
	var stage := _port_stage()
	if stage != null:
		stage.reset_voyage()


## Lazily creates the veil as the topmost child so it covers the 3D stage, the
## pages and the fade layer alike.
func _ensure_cloud_veil() -> SNCloudVeil:
	if _cloud_veil != null:
		return _cloud_veil
	_cloud_veil = SNCloudVeil.new()
	_cloud_veil.name = "CloudVeil"
	add_child(_cloud_veil)
	# Keep it anchored to the whole shell even if the window is resized mid-演出.
	_cloud_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _cloud_veil


func _sync_cloud_veil(delta: float) -> void:
	if _presentation == null and _cloud_veil == null:
		return
	var veil := _ensure_cloud_veil()
	if _presentation == null:
		veil.cover = 0.0
		return
	veil.cover = _presentation.veil
	veil.set_meta("veil_direction", _presentation.veil_direction)
	veil.advance(delta)


func _screen_event(data: Dictionary, event: Dictionary) -> void:
	var screen: Variant = EVENT_SCREEN_SCENE.instantiate()
	screen.bind({"event": event, "ship": data.get("ship", {}), "money": data.get("money", 0)}, Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


## 资源告急页（4.2）：复用事件页的版式（标题 / 描述 / 船况 / 两个选项），但选项由
## `_on_explore_alert_choice` 处理——`continue` 只确认告警，`turn_back` 让领域立即
## 结算半程返航，两者都不能走 `event.choose_option`。
##
## `event.hint_text` 覆盖事件页默认的「选择后会立即结算」：对 `continue` 那句话是
## 错的，这里改显示本段剩余航程（全部用已有本地化键拼出，不新增文案）。
func _screen_explore_alert(data: Dictionary) -> void:
	var remaining := 0.0
	if _presentation != null:
		remaining = _presentation.remaining_hours()
	var event := {
		"event_id": "explore_resource_alert",
		"name_key": "ui.explore.alert.title",
		"description_key": "ui.explore.alert.description",
		"hint_text": "%s %s %s" % [
			_tr("ui.explore.alert.remaining", "剩余航程"),
			_fmt(remaining),
			_tr("unit.hours", "小时"),
		],
		"options": [
			{"id": "continue", "name_key": "ui.explore.alert.continue"},
			{"id": "turn_back", "name_key": "ui.explore.alert.turn_back"},
		],
	}
	var ship: Dictionary = data.get("ship", {})
	if ship.is_empty():
		ship = _last_port_view.get("ship", {})
	var screen: Variant = EVENT_SCREEN_SCENE.instantiate()
	screen.bind({
		"event": event,
		"ship": ship,
		"money": data.get("money", 0),
	}, Callable(self, "_tr"))
	screen.command_requested.connect(_on_explore_alert_choice)
	_root_box.add_child(screen)


## 资源告急的选择处理。两个选项都通过 `explore.decide` 在领域层落地；失败时把
## 错误交给状态栏并重新挂告警页（不吞错、也不把玩家留在一张空页上）。
func _on_explore_alert_choice(_command: StringName, params: Dictionary) -> void:
	if _presentation == null or _presentation_explore.is_empty():
		return
	var choice := String(params.get("option_id", ""))
	if choice != "continue" and choice != "turn_back":
		return
	var result := _context.commands.execute(&"explore.decide", {"choice": choice})
	if not bool(result.get("ok", false)):
		_set_status(_error_text(result), true)
		_rebuild_ui()
		return
	if choice == "turn_back":
		var data: Variant = result.get("data", null)
		_handle_explore_turn_back(data if data is Dictionary else {})
		return
	# continue：告警确认，云层重新盖上后回海图继续最后半程（剩余航程仍照常结算）。
	_set_status("%s…" % _tr("ui.label.exploring", "探索中"), false)
	_presentation.resolve_event()
	_rebuild_ui()


## 掉头成功（`explore.decide(turn_back)` 已经在领域层回港并写好 summary）：
## 演出放弃剩余航程，直接进入「云层盖住海图 → 3D 入港」。`returned` 标记让
## `ARRIVAL_READY` 跳过 `explore.settle`——否则会对已经清空的探索航次报
## `not_exploring`，也就是一次 double settle。
func _handle_explore_turn_back(data: Dictionary) -> void:
	var destination := String(data.get("destination", ""))
	if not destination.is_empty():
		_presentation_voyage["destination"] = destination
	var summary: Variant = data.get("summary", null)
	if summary is Dictionary:
		_presentation_summary = summary
	_presentation_explore["returned"] = true
	_set_status(
		_tr("ui.notice.exploration_turned_back", "掉头返航：%s") % _port_name(destination),
		false
	)
	_presentation.force_arrival()
	_sync_cloud_veil(0.0)
	_rebuild_ui()


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
	var from := _active_screen
	if screen == "sea_chart":
		# Remember where the chart was opened from so closing returns there.
		_sea_chart_return = from if SCREENS.has(from) else "voyage"
	if screen != "overview":
		# The detail drawer only belongs to the overview main view.
		_overview_detail = false
	_active_screen = screen
	_status_message = ""
	# Adjacent station pages share one 3D district: a fade to black would hide the
	# camera pan and the sailing hull that are the point of the switch, so those
	# navigations rebuild instantly and let the stage carry the transition. Every
	# other navigation keeps the fade.
	var continuous := (
		STAGE_SCREENS.has(from)
		and STAGE_SCREENS.has(screen)
		and _port_stage_available()
	)
	_refresh(not continuous)


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
	_sea_chart_return = "voyage"
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
	_sea_chart_return = "voyage"
	_reset_voyage_presentation()
	_active_screen = "overview"
	_overview_detail = false
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
	# `voyage.start` / `event.choose_option` hand over to the cloud transition,
	# so the generic page fade would fight the veil — rebuild without animation.
	var presentation_handoff := _presentation != null and command in [
		&"voyage.start", &"event.choose_option", &"explore.start",
	]
	var animate := command in [&"run.start", &"voyage.start", &"event.choose_option"] and not presentation_handoff
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
			_reset_voyage_presentation()
			_set_status("新航程开始 · 种子 %d" % int(data.get("seed", 0)), false)
		"voyage.start":
			_handle_voyage_result(data)
		"explore.start":
			# 探索出航走同一套演出，只是目的地要等 `explore.settle`。
			_start_explore_presentation(data)
		"clue.buy":
			_handle_clue_bought(data)
		"event.choose_option":
			if bool(data.get("failed", false)):
				_presentation = null
				_presentation_explore = {}
				_at_sea_screen = null
				_sync_cloud_veil(0.0)
				_active_screen = "overview"
				_set_status("航行失败，已恢复到出航前状态。", true)
			elif _presentation != null:
				# Resume the remaining leg of the voyage: the veil comes back, the
				# chart page returns, and the presentation plays out to arrival.
				var summary: Variant = data.get("summary", data.get("event_result", null))
				_presentation_summary = summary if summary is Dictionary else {}
				_presentation.resolve_event()
				_sync_cloud_veil(0.0)
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
	# Every successful departure runs the phase-3 presentation: clouds over the
	# port, the chart with the ship sailing, then event/arrival. The voyage itself
	# was already settled by the command, so this only decides how it is shown.
	_start_voyage_presentation(data)


## `clue.buy` 成功：状态栏只报来源（不泄露等级/目标港），海图由 `_run_command`
## 的常规 `_refresh()` 重建，新的 `clues` 自然出现在图上。
func _handle_clue_bought(data: Dictionary) -> void:
	var clue: Dictionary = {}
	if data.get("clue", null) is Dictionary:
		clue = data["clue"] as Dictionary
	elif data.get("source_key", null) != null or data.get("id", null) != null:
		clue = data
	var source_key := String(clue.get("source_display_key", ""))
	if source_key.is_empty():
		source_key = "ui.clue.source." + String(clue.get("source_key", ""))
	var source := _tr(source_key, "线索")
	_set_status(_tr("ui.notice.clue_acquired", "获得线索：%s") % source, false)


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


## Short label for an edge signboard ("市场" / "Market"); the long facility name
## above stays in the detail panels.
func _facility_sign_name(facility: String) -> String:
	return _tr("ui.facility.%s" % facility, _facility_name(facility))


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
