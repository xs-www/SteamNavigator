class_name AppContext
extends RefCounted
## Composition root handed to commands, queries and the UI.
##
## Systems receive AppContext, but only CommandBus mutates GameState. Queries
## and UI read through ViewModels.

const FRAMEWORK_VERSION := FrameworkInfo.VERSION
const API_MAJOR := FrameworkInfo.API_MAJOR
const API_MINOR := FrameworkInfo.API_MINOR
const KNOWN_CAPABILITIES := FrameworkInfo.CAPABILITIES

static var active: AppContext = null

var config: Dictionary = {}
var logger: AppLogger
var localization: LocalizationService
var assets: AssetService
var registries: RegistryHub
var events: DomainEventBus
var commands: CommandBus
var queries: QueryBus
var save: SaveService
var clock: ClockService
var rng: RngService
var state: GameState
var report: StartupReport
var mod_order: PackedStringArray = PackedStringArray()
var autosave_enabled: bool = true
var pre_voyage_state: GameState = null


func _init(app_config: Dictionary = {}) -> void:
	config = app_config.duplicate(true)
	var locale := String(config.get("locale", "zh_CN"))
	var echo_logs := bool(config.get("log_to_console", true))
	logger = AppLogger.new(AppLogger.Level.INFO, echo_logs)
	localization = LocalizationService.new(locale, logger)
	assets = AssetService.new(logger)
	registries = RegistryHub.new(ContentTypes.all())
	events = DomainEventBus.new()
	clock = ClockService.new()
	rng = RngService.new(1)
	state = GameState.new()
	autosave_enabled = bool(config.get("autosave", true))
	save = SaveService.new(logger, String(config.get("save_directory", "user://saves")))
	commands = CommandBus.new(self)
	queries = QueryBus.new(self)


static func set_active(context: AppContext) -> void:
	active = context


static func get_active() -> AppContext:
	return active


func is_ready() -> bool:
	return report != null and not report.has_fatal() and registries.is_frozen()


func has_run() -> bool:
	return not state.is_empty()


func reset_state() -> void:
	state = GameState.new()


func set_state(new_state: GameState) -> void:
	state = new_state


func set_seed(seed_value: int) -> void:
	rng = RngService.new(seed_value)


func content_count(content_type: StringName) -> int:
	var target := registries.registry(content_type)
	return target.size() if target != null else 0


func content_total() -> int:
	return registries.total_count()


func mod_summaries() -> Array[Dictionary]:
	return report.mods.duplicate(true) if report != null else []


func save_meta(extra: Dictionary = {}) -> Dictionary:
	var meta := {
		"framework_version": FRAMEWORK_VERSION,
		"api_version": "%d.%d" % [API_MAJOR, API_MINOR],
		"mods": mod_summaries(),
		"current_port_id": state.current_port_id(),
		"seed": state.seed(),
	}
	for key in extra.keys():
		meta[String(key)] = extra[key]
	return meta


func autosave(extra: Dictionary = {}) -> Dictionary:
	if not autosave_enabled or not has_run():
		return {"ok": false, "error": "autosave disabled or no run"}
	return save.autosave(state, save_meta(extra))


func translate(key: String, fallback: String = "") -> String:
	return localization.tr_key(key, fallback)


func format_time(game_time: float = -1.0) -> String:
	var value := state.now() if game_time < 0.0 else game_time
	return ClockService.format_time(value)
