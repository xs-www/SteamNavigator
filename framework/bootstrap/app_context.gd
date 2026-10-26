class_name AppContext
extends RefCounted
## @static-doc
## 作用：应用组合根：持有服务、总线、GameState 与启动报告，交给命令/查询/UI 使用；`telemetry` 是可选的本局游玩日志记录器（默认 null，未开启上传时不创建）。
##
## - 关键依赖：`AppLogger`、`LocalizationService`、`RegistryHub`、`DomainEventBus`、`CommandBus`、`QueryBus`、`SaveService`、`TelemetryService`
##
## ## 契约与约束
## - 系统只通过 AppContext 取依赖，但只有 CommandBus 能改 GameState；查询/UI 走 ViewModel。
## - `telemetry` 必须 null 安全：菜单/启动失败/旧工具链没有记录器时，CommandBus 等调用方直接跳过记录（`docs/design/TELEMETRY.md` §3、§5）。
## - 启动链路不创建记录器：由 `main.gd` 在首次拿到 context 后按设置创建并绑定，避免无头工具意外产生上传数据。
##
## ## 重点逻辑
## ### `autosave()/save_meta()`
## - 自动存档只在 `autosave_enabled` 且有本局状态时写入，并把版本/模组/港口/种子写进头信息。
## @end-static-doc

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
## 本局游玩日志记录器（docs/design/TELEMETRY.md §5）。null 表示未开启/未接线，
## 所有记录点必须 null 安全；由 `main.gd` 按设置创建并绑定。
var telemetry: TelemetryService = null


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
