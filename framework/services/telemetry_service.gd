class_name TelemetryService
extends RefCounted
## @static-doc
## 作用：游玩数据（telemetry）会话的纯逻辑服务：记录命令/白名单事件/WARN+ 日志、按契约裁剪、生成 `sn.telemetry.session/1` 载荷并读写 `user://telemetry/pending/` 待上传队列；不依赖 SceneTree / HTTP。
##
## - 关键依赖：`JsonUtils`（canonical JSON）、`AppLogger`（收尾快照 WARN/ERROR/FATAL）、`FrameworkInfo`（版本基线）
##
## ## 契约与约束
## - 唯一契约是 `docs/design/TELEMETRY.md` §1-§3、§6：schema、文件名、上限、默认值与隐私红线不得在本文件自行变更。
## - 默认关闭（opt-in）：`enabled` 为假时 `begin_session` / `record_*` / `finalize_session` 全部 no-op，且不创建任何文件（验收 §6.2）。
## - `set_enabled(false)` = 停止记录 + 丢弃当前会话缓冲 + 删除 `pending_dir` 下全部文件（§2）。
## - 隐私：只记录白名单事件前缀（`voyage.` / `port.` / `contract.` / `combat.` / `story.` / `quest.` / `market.` / `run.`），字符串字段 ≤300 字符、命令/事件名 ≤80（§1、§3.3）。
## - 命令参数只上传 `PARAM_ALLOWLIST` 白名单键的标量值（内容 ID / 数量 / 时长等），嵌套对象、自由文本字段与 `data` 一律丢弃；字符串值 ≤80、最多 8 个键（§3.4）。
## - 缓冲上限 commands 300 / events 150 / errors 40，超出丢最旧；单文件 ≤512 KiB，超限先裁剪命令/事件再写；队列 ≤20 个 pending 文件，超出丢最旧（§3.4、§3.6）。
## - 时间用 ISO-8601 UTC（`...Z`），序列化只用 `JsonUtils.canonical_stringify`（UTF-8、无 BOM）；`session_id` 必须匹配 `^[A-Za-z0-9_-]{8,64}$`（服务端按它做文件名，防路径穿越）。
##
## ## 重点逻辑
## ### `begin_session(meta)`
## - 关闭时直接返回失败；开启时重置缓冲并生成 `${UTC 时间}-${8 位十六进制}` 的 session id，`is_recording()` 从此为真直到 `finalize_session`。
## ### `record_command(command, ok, error_code, duration_ms, game_time, params)`
## - CommandBus 每条命令一条记录；`params` 经 `sanitize_command_params()` 过滤后才写入 `params` 字段（无白名单参数时不写该字段）。
## ### `sanitize_command_params(params)`
## - 纯函数：按 `PARAM_ALLOWLIST` 只保留标量（String/StringName/Bool/Int/Float），嵌套对象/数组与其他类型丢弃；字符串按 `MAX_NAME_LENGTH` 截断，最多 `MAX_COMMAND_PARAMS` 个键。
## ### `record_event(event)`
## - 只接受 §3 白名单前缀的领域事件；payload 递归截断后再入缓冲，UI / 框架内部事件不会上传。
## ### `finalize_session(summary, logger)`
## - 结束计时、快照 `logger` 的 WARN/ERROR/FATAL、生成载荷并写入 pending；`run.commands` / `run.failed_commands` 是本局计数（不受列表裁剪影响）。
## ### `serialize_with_budget(payload)`
## - 纯函数：按单文件 512 KiB 预算序列化载荷，超限时先丢最旧命令、再丢最旧事件/错误；返回 `{ok, error, text, bytes, trimmed}`，finalize 与测试共用。
## ### `_trim_pending_queue(keep_path)`
## - pending 文件名以 UTC 时间戳开头，按文件名升序即先进先出；写入后超过 20 个就删最旧的（§3.6）。
## @end-static-doc

## 服务端按 session_id 命名文件，客户端必须使用同一 schema 标识。
const SCHEMA := "sn.telemetry.session/1"
## 官网接收端默认地址；设置里的 endpoint 为空/非法时回退到这里（§2）。
const DEFAULT_ENDPOINT := "https://steamnavigator.playthought.cn/api/telemetry/session"
const PENDING_DIR := "user://telemetry/pending"
const MAX_PENDING_FILES := 20
const MAX_PENDING_BYTES := 512 * 1024
const MAX_COMMANDS := 300
const MAX_EVENTS := 150
const MAX_ERRORS := 40
const MAX_STRING_LENGTH := 300
const MAX_NAME_LENGTH := 80
## §3.4：每条命令最多上传 8 个白名单参数键，避免载荷膨胀。
const MAX_COMMAND_PARAMS := 8
## §3.4：命令参数白名单。只收内容 ID / 枚举 / 数量 / 时长等结构性字段；
## `data`、自由文本、嵌套对象与数组一律不上传。
const PARAM_ALLOWLIST: Array[String] = [
	"item_id", "module_id", "replace_module_id", "weapon_id", "hull_id",
	"port_id", "destination", "destination_id", "origin", "origin_id",
	"source", "strategy_id", "socket", "slot", "tier",
	"instance_id", "contract_id", "clue_id", "quest_id",
	"event", "option_id", "encounter_id", "encounter_table_id",
	"starting_scenario", "start_profile", "settlement_key",
	"amount", "qty", "hours", "speed", "seed",
]
const SESSION_ID_PATTERN := "^[A-Za-z0-9_-]{8,64}$"
## §3.3：只有这些领域事件前缀会进入上传载荷。
const EVENT_PREFIXES: Array[String] = [
	"voyage.", "port.", "contract.", "combat.", "story.", "quest.", "market.", "run.",
]

## 待上传队列目录；测试用构造参数覆盖，避免污染真实 `user://telemetry/`。
var pending_dir: String = PENDING_DIR
## 设置里的开关。关闭时立即丢弃缓冲与队列。
var enabled := false
var session_id := ""
var started_at := ""
var ended_at := ""
## `begin_session` 收到的版本/语言/平台/模组元数据（已截断）。
var meta: Dictionary = {}

var _recording := false
var _started_at_unix := 0
var _ended_at_unix := 0
var _commands: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _errors: Array[Dictionary] = []
var _sequence := 0
var _command_total := 0
var _failed_command_total := 0


func _init(pending_dir_override: String = "") -> void:
	pending_dir = pending_dir_override if not pending_dir_override.is_empty() else PENDING_DIR


static func is_valid_endpoint(url: String) -> bool:
	## 绝对 `http(s)://` URL 且有非空 authority；其余一律视为非法，由 normalize 回退默认值。
	var text := url.strip_edges()
	if text.is_empty() or text.length() > 2048:
		return false
	var scheme := ""
	if text.begins_with("https://"):
		scheme = "https://"
	elif text.begins_with("http://"):
		scheme = "http://"
	else:
		return false
	var rest := text.substr(scheme.length())
	if rest.is_empty() or rest.contains(" ") or rest.contains("\t"):
		return false
	var slash := rest.find("/")
	var authority := rest if slash < 0 else rest.substr(0, slash)
	return not authority.is_empty()


static func normalize_endpoint(raw: String) -> String:
	## §2：空或非法 endpoint 回退 `DEFAULT_ENDPOINT`，合法时只去首尾空白。
	return raw.strip_edges() if is_valid_endpoint(raw) else DEFAULT_ENDPOINT


static func is_whitelisted_event(event_type: String) -> bool:
	## §3.3 白名单：事件类型必须以契约列出的领域前缀开头。
	if event_type.is_empty():
		return false
	for prefix in EVENT_PREFIXES:
		if event_type.begins_with(prefix):
			return true
	return false


func is_enabled() -> bool:
	return enabled


func is_recording() -> bool:
	return _recording


## 设置开关的唯一入口。关闭时立即停止记录、清空本局缓冲并删除待上传队列（§2）。
func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_reset_session()
		discard_pending()


func begin_session(meta_override: Dictionary = {}) -> Dictionary:
	## §3.2：enabled 时开始一局（进程生命周期）记录；关闭时无副作用。
	if not enabled:
		return {"ok": false, "error": "disabled"}
	_reset_session()
	meta = _sanitize_value(meta_override)
	_started_at_unix = int(Time.get_unix_time_from_system())
	started_at = _iso_utc(_started_at_unix)
	_ended_at_unix = 0
	ended_at = ""
	session_id = _generate_session_id(_started_at_unix)
	_recording = true
	return {"ok": true, "session_id": session_id, "started_at": started_at}


func record_command(command: String, ok: bool, error_code: String = "", duration_ms: int = 0, game_time: float = 0.0, params: Dictionary = {}) -> void:
	## §3.3 / §3.4：CommandBus 每条命令一条记录；关闭/未开局时 no-op；参数按白名单过滤后附带。
	if not _recording:
		return
	_command_total += 1
	if not ok:
		_failed_command_total += 1
	_sequence += 1
	var entry := {
		"seq": _sequence,
		"command": _clip(command, MAX_NAME_LENGTH),
		"ok": ok,
		"error_code": _clip(error_code, MAX_NAME_LENGTH),
		"duration_ms": maxi(0, duration_ms),
		"game_time": snappedf(game_time, 0.001),
	}
	var filtered := sanitize_command_params(params)
	if not filtered.is_empty():
		entry["params"] = filtered
	_commands.append(entry)
	_trim_front(_commands, MAX_COMMANDS)


## §3.4：命令参数只保留白名单键的标量值；嵌套对象/数组/自由文本字段丢弃，字符串按 80 字符截断。
static func sanitize_command_params(params: Dictionary) -> Dictionary:
	var result := {}
	for raw_key in params.keys():
		var key := String(raw_key)
		if not PARAM_ALLOWLIST.has(key):
			continue
		var value: Variant = params[raw_key]
		match typeof(value):
			TYPE_STRING, TYPE_STRING_NAME:
				result[key] = _clip(String(value), MAX_NAME_LENGTH)
			TYPE_BOOL:
				result[key] = bool(value)
			TYPE_INT:
				result[key] = int(value)
			TYPE_FLOAT:
				result[key] = snappedf(float(value), 0.001)
			_:
				# Dictionary / Array / Object / null：参数可能是自由文本或整块数据，不进上传载荷。
				continue
		if result.size() >= MAX_COMMAND_PARAMS:
			break
	return result


func record_event(event: Dictionary) -> void:
	## §3.3：只记录白名单领域事件；payload 截断后进 `events`。
	if not _recording:
		return
	var event_type := _clip(String(event.get("event_type", event.get("type", ""))), MAX_NAME_LENGTH)
	if not is_whitelisted_event(event_type):
		return
	var payload: Variant = event.get("payload", {})
	if not (payload is Dictionary):
		payload = {}
	_events.append({
		"event_type": event_type,
		"game_time": snappedf(float(event.get("game_time", 0.0)), 0.001),
		"payload": _sanitize_value(payload),
	})
	_trim_front(_events, MAX_EVENTS)


## §3.3：收尾时把 `AppLogger` 的 WARN/ERROR/FATAL 快照进 `errors`（保留最近 40 条）。
func capture_errors(entries: Array) -> void:
	for raw in entries:
		if not (raw is Dictionary):
			continue
		var level := String(raw.get("level", ""))
		if not ["WARN", "ERROR", "FATAL"].has(level):
			continue
		_errors.append({
			"level": level,
			"time": _clip(String(raw.get("time", "")), MAX_STRING_LENGTH),
			"message": _clip(String(raw.get("message", "")), MAX_STRING_LENGTH),
		})
	_trim_front(_errors, MAX_ERRORS)


## §3.4：结束本局，写 `user://telemetry/pending/<session_id>.json`；返回 `{ok, path, bytes, error}`。
func finalize_session(summary: Dictionary = {}, logger: AppLogger = null) -> Dictionary:
	if not _recording:
		return {"ok": false, "error": "not_recording"}
	_recording = false
	_ended_at_unix = int(Time.get_unix_time_from_system())
	ended_at = _iso_utc(_ended_at_unix)
	if logger != null:
		capture_errors(logger.get_entries(AppLogger.Level.WARN, MAX_ERRORS))
	return _write_pending(build_payload(summary))


## §3「会话载荷」：唯一的 payload 组装点（测试也用它校验 schema）。
func build_payload(summary: Dictionary = {}) -> Dictionary:
	var end_unix := _ended_at_unix if _ended_at_unix > 0 else int(Time.get_unix_time_from_system())
	var run: Variant = summary.get("run", {})
	var run_block: Dictionary = _sanitize_value(run) if run is Dictionary else {}
	run_block["commands"] = _command_total
	run_block["failed_commands"] = _failed_command_total
	if not run_block.has("has_run"):
		run_block["has_run"] = false
	var mods: Variant = summary.get("mods", meta.get("mods", []))
	var mod_block: Array = _sanitize_value(mods) if mods is Array else []
	return {
		"schema": SCHEMA,
		"session_id": session_id,
		"started_at": started_at,
		"ended_at": ended_at if not ended_at.is_empty() else _iso_utc(end_unix),
		"duration_seconds": maxi(0, end_unix - _started_at_unix),
		"game_version": String(meta.get("game_version", "")),
		"framework_version": String(meta.get("framework_version", FrameworkInfo.VERSION)),
		"content_schema": String(meta.get("content_schema", FrameworkInfo.CONTENT_SCHEMA)),
		"locale": String(meta.get("locale", "")),
		"os": String(meta.get("os", OS.get_name())),
		"run": run_block,
		"mods": mod_block,
		"commands": _commands.duplicate(true),
		"events": _events.duplicate(true),
		"errors": _errors.duplicate(true),
	}


## 纯函数：按单文件 512 KiB 预算序列化；超限先丢最旧命令，再丢最旧事件/错误（§3.6）。
func serialize_with_budget(payload: Dictionary) -> Dictionary:
	var working: Dictionary = payload.duplicate(true)
	var text := JsonUtils.canonical_stringify(working)
	var bytes := text.to_utf8_buffer().size()
	var trimmed := false
	while bytes > MAX_PENDING_BYTES:
		var changed := false
		for key in ["commands", "events", "errors"]:
			var items: Variant = working.get(key, [])
			if items is Array and (items as Array).size() > 0:
				working[key] = _drop_oldest_half(items)
				changed = true
				break
		if not changed:
			return {"ok": false, "error": "payload_too_large", "text": "", "bytes": bytes, "trimmed": trimmed}
		trimmed = true
		text = JsonUtils.canonical_stringify(working)
		bytes = text.to_utf8_buffer().size()
	return {"ok": true, "error": "", "text": text, "bytes": bytes, "trimmed": trimmed}


func pending_files() -> PackedStringArray:
	## 先进先出：session 文件名以 UTC 时间戳开头，按文件名升序即投递顺序。
	var files := PackedStringArray()
	if not DirAccess.dir_exists_absolute(pending_dir):
		return files
	var dir := DirAccess.open(pending_dir)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".json"):
			files.append(pending_dir.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


func pending_count() -> int:
	return pending_files().size()


## §2：关闭开关时删除本机待上传队列；返回删除的文件数。
func discard_pending() -> int:
	var removed := 0
	for path in pending_files():
		if DirAccess.remove_absolute(path) == OK:
			removed += 1
	if removed > 0 and DirAccess.dir_exists_absolute(pending_dir):
		DirAccess.remove_absolute(pending_dir)
	return removed


func _reset_session() -> void:
	_recording = false
	session_id = ""
	started_at = ""
	ended_at = ""
	_started_at_unix = 0
	_ended_at_unix = 0
	_command_total = 0
	_failed_command_total = 0
	_sequence = 0
	_commands.clear()
	_events.clear()
	_errors.clear()


func _write_pending(payload: Dictionary) -> Dictionary:
	if session_id.is_empty() or not _session_id_matches(session_id):
		return {"ok": false, "error": "invalid_session_id"}
	if not _ensure_pending_dir():
		return {"ok": false, "error": "pending_dir_failed"}
	var path := pending_dir.path_join(session_id + ".json")
	var serialized := serialize_with_budget(payload)
	if not bool(serialized.get("ok", false)):
		return {"ok": false, "error": String(serialized.get("error", "serialize_failed"))}
	var text := String(serialized.get("text", ""))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "pending_write_failed", "path": path}
	# store_string 写 UTF-8 无 BOM；canonical_stringify 已保证键序稳定。
	file.store_string(text)
	file.close()
	_trim_pending_queue(path)
	return {
		"ok": true,
		"error": "",
		"path": path,
		"bytes": text.to_utf8_buffer().size(),
		"trimmed": bool(serialized.get("trimmed", false)),
	}


func _ensure_pending_dir() -> bool:
	if DirAccess.dir_exists_absolute(pending_dir):
		return true
	return DirAccess.make_dir_recursive_absolute(pending_dir) == OK


func _trim_pending_queue(keep_path: String) -> void:
	## 队列上限 20：写入后若超限，删最旧（文件名时间戳最小）的文件。
	var files := pending_files()
	var removed := 0
	while files.size() > MAX_PENDING_FILES and removed < files.size():
		var oldest := files[0]
		if oldest == keep_path:
			break
		if DirAccess.remove_absolute(oldest) == OK:
			removed += 1
		files.remove_at(0)


func _generate_session_id(unix_seconds: int) -> String:
	var moment := Time.get_datetime_dict_from_unix_time(unix_seconds)
	var stamp := "%04d%02d%02dT%02d%02d%02dZ" % [
		int(moment.get("year", 1970)), int(moment.get("month", 1)), int(moment.get("day", 1)),
		int(moment.get("hour", 0)), int(moment.get("minute", 0)), int(moment.get("second", 0)),
	]
	# 同一秒内重复开关也要拿到不同的 session_id：用进程内微秒计数区分。
	var suffix := "%08x" % (int(Time.get_ticks_usec()) & 0xFFFFFFFF)
	return "%s-%s" % [stamp, suffix]


static func _session_id_matches(value: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(SESSION_ID_PATTERN) != OK:
		return false
	return regex.search(value) != null and regex.search(value).get_string(0) == value


static func _iso_utc(unix_seconds: int) -> String:
	var moment := Time.get_datetime_dict_from_unix_time(unix_seconds)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(moment.get("year", 1970)), int(moment.get("month", 1)), int(moment.get("day", 1)),
		int(moment.get("hour", 0)), int(moment.get("minute", 0)), int(moment.get("second", 0)),
	]


static func _trim_front(items: Array, limit: int) -> void:
	if limit <= 0:
		items.clear()
		return
	while items.size() > limit:
		items.pop_front()


static func _drop_oldest_half(items: Variant) -> Array:
	var source: Array = []
	if items is Array:
		source = items
	var drop := maxi(1, source.size() / 2)
	return source.slice(drop, source.size())


static func _clip(value: String, max_length: int) -> String:
	return value if value.length() <= max_length else value.substr(0, max_length)


## 递归截断字符串字段（§1：单字段 ≤300）；只复制容器，不改调用方数据。
static func _sanitize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING:
			return _clip(String(value), MAX_STRING_LENGTH)
		TYPE_STRING_NAME:
			return _clip(String(value), MAX_STRING_LENGTH)
		TYPE_DICTIONARY:
			var output := {}
			for key in (value as Dictionary).keys():
				output[String(key)] = _sanitize_value(value[key])
			return output
		TYPE_ARRAY:
			var output: Array = []
			for item in value:
				output.append(_sanitize_value(item))
			return output
		_:
			return value
