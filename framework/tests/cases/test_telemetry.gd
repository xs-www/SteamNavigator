extends TestCase
## @static-doc
## 作用：客户端游玩数据上传（Telemetry）契约测试：覆盖 `docs/design/TELEMETRY.md` §6 的客户端部分——默认关闭、开启后退出写出合法 `sn.telemetry.session/1` 载荷、缓冲/队列上限、命令参数白名单、关闭清队列、endpoint 回退、CommandBus 记录与上传器失败保留。
##
## ## 契约与约束
## - 断言必须直接反映 TELEMETRY.md 的 schema / 上限 / 文件名 / 默认值；不得为了让实现通过而放松期望。
## - 测试只写 `user://test_telemetry/**` 临时目录；上传器失败分支用无效 endpoint / 纯结果处理验证，禁止真实外网请求。
## - 上传器测试不等待 HTTP：`apply_response()` 是 2xx 删除/失败保留的唯一判决点，`flush()` 只验证无效 endpoint 不删文件。
## @end-static-doc

const TEMP_ROOT := "user://test_telemetry"
const SESSION_SCHEMA := "sn.telemetry.session/1"


func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while not entry.is_empty():
			var child := path.path_join(entry)
			if dir.current_is_dir():
				_cleanup(child)
			else:
				DirAccess.remove_absolute(child)
			entry = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _service(tag: String) -> TelemetryService:
	var directory := TEMP_ROOT.path_join("%s/pending" % tag)
	_cleanup(TEMP_ROOT.path_join(tag))
	var service := TelemetryService.new(directory)
	service.set_enabled(true)
	return service


func _payload_of(path: String) -> Dictionary:
	var parsed := JsonUtils.parse_file(path)
	assert_true(bool(parsed.get("ok", false)), "pending payload is valid JSON: %s" % path)
	var value: Variant = parsed.get("value", null)
	return value if value is Dictionary else {}


func _matches(pattern: String, text: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return false
	return regex.search(text) != null


func test_disabled_service_records_and_writes_nothing() -> void:
	var root := TEMP_ROOT.path_join("disabled")
	_cleanup(root)
	var service := TelemetryService.new(root.path_join("pending"))
	assert_false(service.is_enabled(), "telemetry defaults to disabled (opt-in)")
	assert_false(service.is_recording(), "a disabled service never records")
	var begun := service.begin_session({"game_version": "0.2.0"})
	assert_false(bool(begun.get("ok", false)), "begin_session is a no-op while disabled")
	service.record_command("trade.buy", true, "", 1, 2.0)
	service.record_event({"event_type": "voyage.completed", "payload": {"destination": "x"}})
	var finalized := service.finalize_session({"run": {"has_run": true}})
	assert_false(bool(finalized.get("ok", false)), "finalize_session is a no-op while disabled")
	assert_eq(service.pending_count(), 0, "disabled telemetry writes no pending files")
	assert_false(DirAccess.dir_exists_absolute(root), "disabled telemetry creates no telemetry directory")
	_cleanup(root)


func test_enabled_session_writes_a_contract_payload() -> void:
	var service := _service("payload")
	var begun := service.begin_session({
		"game_version": "0.2.0",
		"framework_version": "0.1.0",
		"content_schema": "2.0",
		"locale": "zh_CN",
		"os": "Windows",
		"mods": [{"id": "core", "version": "1.0.0"}],
	})
	assert_true(bool(begun.get("ok", false)), "enabled begin_session succeeds: %s" % str(begun))
	assert_true(_matches("^[A-Za-z0-9_-]{8,64}$", service.session_id),
		"session_id matches the server filename pattern: %s" % service.session_id)
	service.record_command("trade.buy", true, "", 2, 8.0, {"item_id": "core:item/iron_ore", "amount": 3})
	service.record_command("trade.sell", false, "money", 1, 9.5)
	service.record_event({"event_type": "voyage.completed", "game_time": 12.0, "payload": {"destination": "core:port_template/iron_harbor"}})
	service.record_event({"event_type": "ui.chart_opened", "game_time": 13.0, "payload": {}})
	var logger := AppLogger.new(AppLogger.Level.INFO, false)
	logger.warn("warning one")
	logger.error("error one")
	logger.fatal("fatal one")
	var finalized := service.finalize_session({
		"run": {"has_run": true, "seed": 12345, "port_id": "core:port_template/iron_harbor", "money": 1234, "game_hours": 42.0, "victory": false},
	}, logger)
	assert_true(bool(finalized.get("ok", false)), "finalize writes the pending file: %s" % str(finalized))
	var path := String(finalized.get("path", ""))
	assert_eq(path, service.pending_dir.path_join(service.session_id + ".json"),
		"pending file is named after the session id")
	assert_true(FileAccess.file_exists(path), "the pending file exists on disk")
	assert_eq(service.pending_count(), 1, "the queue holds the finished session")

	var payload := _payload_of(path)
	assert_eq(String(payload.get("schema", "")), SESSION_SCHEMA, "payload carries the telemetry schema id")
	assert_eq(String(payload.get("session_id", "")), service.session_id, "payload session id matches the file")
	assert_true(_matches("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", String(payload.get("started_at", ""))),
		"started_at is ISO-8601 UTC: %s" % String(payload.get("started_at", "")))
	assert_true(_matches("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", String(payload.get("ended_at", ""))),
		"ended_at is ISO-8601 UTC: %s" % String(payload.get("ended_at", "")))
	assert_true(typeof(payload.get("duration_seconds", null)) in [TYPE_INT, TYPE_FLOAT],
		"duration_seconds is numeric")
	assert_true(float(payload.get("duration_seconds", -1.0)) >= 0.0, "duration is never negative")
	assert_eq(String(payload.get("game_version", "")), "0.2.0", "game version round-trips")
	assert_eq(String(payload.get("framework_version", "")), "0.1.0", "framework version round-trips")
	assert_eq(String(payload.get("content_schema", "")), "2.0", "content schema round-trips")
	assert_eq(String(payload.get("locale", "")), "zh_CN", "locale round-trips")
	assert_eq(String(payload.get("os", "")), "Windows", "platform round-trips")
	var mods: Array = payload.get("mods", [])
	assert_eq(mods.size(), 1, "mod list is uploaded")
	if mods.size() == 1:
		assert_eq(String(mods[0].get("id", "")), "core", "mod id round-trips")
		assert_eq(String(mods[0].get("version", "")), "1.0.0", "mod version round-trips")

	var run: Dictionary = payload.get("run", {})
	assert_true(bool(run.get("has_run", false)), "run block reports the live run")
	assert_eq(int(run.get("seed", 0)), 12345, "run seed round-trips")
	assert_eq(int(run.get("money", 0)), 1234, "run money round-trips")
	assert_almost_eq(float(run.get("game_hours", 0.0)), 42.0, 0.001, "run game hours round-trip")
	assert_false(bool(run.get("victory", true)), "run victory round-trips")
	assert_eq(int(run.get("commands", 0)), 2, "run block carries the command count")
	assert_eq(int(run.get("failed_commands", 0)), 1, "run block carries the failed command count")

	var commands: Array = payload.get("commands", [])
	assert_eq(commands.size(), 2, "both executed commands are recorded")
	if commands.size() == 2:
		var first: Dictionary = commands[0]
		assert_eq(int(first.get("seq", 0)), 1, "commands keep their execution order")
		assert_eq(String(first.get("command", "")), "trade.buy", "command name is recorded")
		assert_true(bool(first.get("ok", false)), "success flag is recorded")
		assert_eq(String(first.get("error_code", "")), "", "successful command has no error code")
		assert_eq(int(first.get("duration_ms", -1)), 2, "duration is recorded in milliseconds")
		assert_almost_eq(float(first.get("game_time", 0.0)), 8.0, 0.001, "game time is recorded")
		var params: Dictionary = first.get("params", {})
		assert_eq(String(params.get("item_id", "")), "core:item/iron_ore",
			"whitelisted command params are uploaded")
		assert_eq(int(params.get("amount", 0)), 3, "numeric command params are uploaded")
		assert_false(commands[1].has("params"), "commands without whitelisted params omit the field")
		assert_false(bool(commands[1].get("ok", true)), "failed command keeps ok=false")
		assert_eq(String(commands[1].get("error_code", "")), "money", "failed command keeps its error code")

	var events: Array = payload.get("events", [])
	assert_eq(events.size(), 1, "only whitelisted domain events are recorded")
	if events.size() == 1:
		assert_eq(String(events[0].get("event_type", "")), "voyage.completed", "event type is recorded")
		assert_eq(String((events[0].get("payload", {}) as Dictionary).get("destination", "")),
			"core:port_template/iron_harbor", "event payload is recorded")
	assert_eq(Array(payload.get("errors", [])).size(), 3, "WARN/ERROR/FATAL are snapshotted")
	var errors: Array = payload.get("errors", [])
	if errors.size() == 3:
		assert_eq(String(errors[0].get("level", "")), "WARN", "warnings are kept")
		assert_eq(String(errors[1].get("level", "")), "ERROR", "errors are kept")
		assert_eq(String(errors[2].get("level", "")), "FATAL", "fatal logs are kept")

	var text := FileAccess.get_file_as_string(path)
	assert_true(text.begins_with("{"), "payload is UTF-8 JSON without BOM")
	var bytes := FileAccess.get_file_as_bytes(path).size()
	assert_true(bytes <= TelemetryService.MAX_PENDING_BYTES,
		"pending file stays within the 512 KiB budget (%d bytes)" % bytes)
	_cleanup(TEMP_ROOT.path_join("payload"))


func test_buffers_trim_to_the_contract_limits() -> void:
	var service := _service("trim")
	service.begin_session({"game_version": "0.2.0"})
	for index in 350:
		service.record_command("test.command.%03d" % index, true, "", 1, float(index))
	for index in 160:
		service.record_event({"event_type": "voyage.event_%03d" % index, "game_time": float(index), "payload": {}})
	var logger := AppLogger.new(AppLogger.Level.INFO, false)
	for index in 50:
		logger.warn("warning %d" % index)
	service.capture_errors(logger.get_entries(AppLogger.Level.WARN, 200))
	var payload := service.build_payload({"run": {"has_run": true}})
	var commands: Array = payload.get("commands", [])
	assert_eq(commands.size(), TelemetryService.MAX_COMMANDS, "commands are capped at 300")
	if commands.size() == TelemetryService.MAX_COMMANDS:
		assert_eq(String(commands[0].get("command", "")), "test.command.050", "oldest commands are dropped")
		assert_eq(String(commands[commands.size() - 1].get("command", "")), "test.command.349",
			"newest command survives trimming")
	var events: Array = payload.get("events", [])
	assert_eq(events.size(), TelemetryService.MAX_EVENTS, "events are capped at 150")
	if events.size() == TelemetryService.MAX_EVENTS:
		assert_eq(String(events[0].get("event_type", "")), "voyage.event_010", "oldest events are dropped")
	var errors: Array = payload.get("errors", [])
	assert_eq(errors.size(), TelemetryService.MAX_ERRORS, "errors are capped at 40")
	if errors.size() == TelemetryService.MAX_ERRORS:
		assert_eq(String(errors[0].get("message", "")), "warning 10", "oldest warnings are dropped")
	assert_eq(int(payload.get("run", {}).get("commands", 0)), 350,
		"run.commands is the true session count, not the capped list size")
	_cleanup(TEMP_ROOT.path_join("trim"))


func test_string_fields_are_clipped_to_contract_limits() -> void:
	var service := _service("clip")
	service.begin_session({"game_version": "0.2.0"})
	service.record_command("trade." + "x".repeat(220), false, "e".repeat(500), 3, 1.0)
	service.record_event({
		"event_type": "voyage." + "y".repeat(220),
		"game_time": 2.0,
		"payload": {"note": "z".repeat(900), "nested": {"deep": "w".repeat(400)}},
	})
	var logger := AppLogger.new(AppLogger.Level.INFO, false)
	logger.warn("m".repeat(900))
	service.capture_errors(logger.get_entries(AppLogger.Level.WARN, 10))
	var payload := service.build_payload({})
	var commands: Array = payload.get("commands", [])
	assert_eq(String(commands[0].get("command", "")).length(), TelemetryService.MAX_NAME_LENGTH,
		"command names are clipped to 80 characters")
	assert_eq(String(commands[0].get("error_code", "")).length(), TelemetryService.MAX_NAME_LENGTH,
		"error codes are clipped to 80 characters")
	var events: Array = payload.get("events", [])
	assert_eq(String(events[0].get("event_type", "")).length(), TelemetryService.MAX_NAME_LENGTH,
		"event names are clipped to 80 characters")
	var event_payload: Dictionary = events[0].get("payload", {})
	assert_eq(String(event_payload.get("note", "")).length(), TelemetryService.MAX_STRING_LENGTH,
		"payload strings are clipped to 300 characters")
	assert_eq(String((event_payload.get("nested", {}) as Dictionary).get("deep", "")).length(),
		TelemetryService.MAX_STRING_LENGTH, "nested payload strings are clipped too")
	var errors: Array = payload.get("errors", [])
	assert_eq(String(errors[0].get("message", "")).length(), TelemetryService.MAX_STRING_LENGTH,
		"error messages are clipped to 300 characters")
	_cleanup(TEMP_ROOT.path_join("clip"))


func test_command_params_are_whitelisted_and_clipped() -> void:
	var service := _service("params")
	service.begin_session({"game_version": "0.2.0"})
	# 白名单键（ID / 数值 / 枚举）保留；嵌套对象、数组、自由文本键、非白名单键一律丢弃。
	service.record_command("trade.buy", true, "", 2, 1.0, {
		"item_id": "core:item/" + "x".repeat(200),
		"amount": 3,
		"destination": "cargo",
		"slot": 2,
		"hours": 4.5,
		"data": {"secret": "nested"},
		"paths": ["user://save"],
		"note": "free text must not be uploaded",
		"money": 999,
	})
	var payload := service.build_payload({})
	var commands: Array = payload.get("commands", [])
	assert_eq(commands.size(), 1, "the parameterized command is buffered")
	if commands.size() != 1:
		_cleanup(TEMP_ROOT.path_join("params"))
		return
	var params: Dictionary = commands[0].get("params", {})
	assert_eq(String(params.get("item_id", "")).length(), TelemetryService.MAX_NAME_LENGTH,
		"string param values are clipped to 80 characters")
	assert_eq(int(params.get("amount", 0)), 3, "numeric params keep their value")
	assert_eq(String(params.get("destination", "")), "cargo", "enum-like string params are kept")
	assert_eq(int(params.get("slot", -1)), 2, "integer slot params are kept")
	assert_almost_eq(float(params.get("hours", 0.0)), 4.5, 0.001, "float duration params are kept")
	assert_false(params.has("data"), "nested object params are dropped")
	assert_false(params.has("paths"), "array params are dropped")
	assert_false(params.has("note"), "non-whitelisted free-text params are dropped")
	assert_false(params.has("money"), "non-whitelisted numeric params are dropped")
	# 超过 8 个白名单键时只保留前 8 个；没有白名单参数时整条不写 params。
	var many := {}
	var keys: Array[String] = [
		"port_id", "item_id", "module_id", "weapon_id", "hull_id", "strategy_id",
		"source", "socket", "slot", "tier", "amount", "hours",
	]
	for key in keys:
		many[key] = 1
	var filtered := TelemetryService.sanitize_command_params(many)
	assert_eq(filtered.size(), TelemetryService.MAX_COMMAND_PARAMS,
		"param summaries are capped at the contract key limit")
	assert_true(TelemetryService.sanitize_command_params({"data": {}, "note": "x"}).is_empty(),
		"a params dict with no whitelisted scalar keys sanitizes to empty")
	assert_false(TelemetryService.sanitize_command_params({"amount": 1}).has("note"),
		"the sanitizer never invents keys")
	_cleanup(TEMP_ROOT.path_join("params"))


func test_pending_queue_caps_at_twenty_and_drops_the_oldest() -> void:
	var root := TEMP_ROOT.path_join("queue")
	_cleanup(root)
	var queue_dir := root.path_join("pending")
	DirAccess.make_dir_recursive_absolute(queue_dir)
	for index in 25:
		var file := FileAccess.open(queue_dir.path_join("20260101T0000%02dZ-abcdef%02d.json" % [index, index]), FileAccess.WRITE)
		if file != null:
			file.store_string("{}")
			file.close()
	var service := TelemetryService.new(queue_dir)
	service.set_enabled(true)
	service.begin_session({"game_version": "0.2.0"})
	var finalized := service.finalize_session({"run": {"has_run": false}})
	assert_true(bool(finalized.get("ok", false)), "finalize succeeds on a full queue")
	var files := service.pending_files()
	assert_eq(files.size(), TelemetryService.MAX_PENDING_FILES, "the queue never holds more than 20 files")
	assert_true(files.has(String(finalized.get("path", ""))), "the new session is queued")
	assert_false(files.has(queue_dir.path_join("20260101T000000Z-abcdef00.json")),
		"the oldest pending file is dropped first")
	_cleanup(root)


func test_serialize_with_budget_trims_old_data_before_writing() -> void:
	var service := _service("budget")
	service.begin_session({"game_version": "0.2.0"})
	var payload := service.build_payload({"run": {"has_run": true}})
	var huge: Array = []
	for index in 300:
		huge.append({"seq": index, "command": "x".repeat(2000), "ok": true})
	payload["commands"] = huge
	payload["events"] = []
	var serialized := service.serialize_with_budget(payload)
	assert_true(bool(serialized.get("ok", false)), "oversized payload is still serialized: %s" % str(serialized))
	assert_true(bool(serialized.get("trimmed", false)), "the serializer reports the trim")
	assert_true(int(serialized.get("bytes", 0)) <= TelemetryService.MAX_PENDING_BYTES,
		"serialized payload fits the 512 KiB file budget")
	_cleanup(TEMP_ROOT.path_join("budget"))


func test_disabling_discards_the_queue_and_session_buffer() -> void:
	var service := _service("discard")
	service.begin_session({"game_version": "0.2.0"})
	service.record_command("trade.buy", true, "", 1, 1.0)
	var finalized := service.finalize_session({"run": {"has_run": true}})
	assert_true(bool(finalized.get("ok", false)), "the session is finalized")
	assert_eq(service.pending_count(), 1, "a pending file exists before disabling")
	assert_true(service.is_enabled(), "the service is enabled")
	service.set_enabled(false)
	assert_false(service.is_enabled(), "disabling turns the service off")
	assert_false(service.is_recording(), "disabling stops recording")
	assert_eq(service.pending_count(), 0, "disabling deletes the pending queue (§2)")
	var payload := service.build_payload({})
	assert_eq(Array(payload.get("commands", [])).size(), 0, "disabling discards the session buffer")
	assert_eq(Array(payload.get("events", [])).size(), 0, "disabling discards buffered events")
	_cleanup(TEMP_ROOT.path_join("discard"))


func test_endpoint_normalization_falls_back_to_the_default() -> void:
	assert_eq(TelemetryService.normalize_endpoint(""), TelemetryService.DEFAULT_ENDPOINT,
		"an empty endpoint falls back to the default")
	assert_eq(TelemetryService.normalize_endpoint("   "), TelemetryService.DEFAULT_ENDPOINT,
		"a whitespace endpoint falls back to the default")
	assert_eq(TelemetryService.normalize_endpoint("ftp://example.invalid/session"), TelemetryService.DEFAULT_ENDPOINT,
		"a non-http(s) endpoint falls back to the default")
	assert_eq(TelemetryService.normalize_endpoint("https://example.invalid/session"), "https://example.invalid/session",
		"a valid https endpoint is kept")
	assert_eq(TelemetryService.normalize_endpoint("http://127.0.0.1:4173/api/telemetry/session"),
		"http://127.0.0.1:4173/api/telemetry/session", "a local http endpoint is kept for debugging")

	var root := TEMP_ROOT.path_join("settings")
	_cleanup(root)
	var directory := root.path_join("config")
	var settings := SettingsService.load_settings(directory.path_join("config.json"), "res://config/config.json")
	assert_false(settings.telemetry(), "telemetry defaults to off in the shipped config")
	assert_eq(settings.telemetry_endpoint(), TelemetryService.DEFAULT_ENDPOINT,
		"the shipped config uses the official endpoint")
	assert_eq(settings.telemetry_token(), "", "the default token is empty")
	settings.set_telemetry(true)
	settings.set_telemetry_endpoint("not a url")
	settings.set_telemetry_token("shared-secret")
	var saved := settings.save()
	assert_true(bool(saved.get("ok", false)), "telemetry settings save: %s" % str(saved))
	var reloaded := SettingsService.load_settings(directory.path_join("config.json"), "res://config/config.json")
	assert_true(reloaded.telemetry(), "telemetry flag round-trips")
	assert_eq(reloaded.telemetry_endpoint(), TelemetryService.DEFAULT_ENDPOINT,
		"an invalid saved endpoint normalizes back to the default")
	assert_eq(reloaded.telemetry_token(), "shared-secret", "telemetry token round-trips")
	reloaded.set_telemetry_endpoint("http://127.0.0.1:4173/api/telemetry/session")
	reloaded.save()
	var again := SettingsService.load_settings(directory.path_join("config.json"), "res://config/config.json")
	assert_eq(again.telemetry_endpoint(), "http://127.0.0.1:4173/api/telemetry/session",
		"a valid endpoint round-trips")
	_cleanup(root)


func test_command_bus_records_commands_into_telemetry() -> void:
	var context := AppContext.new({"log_to_console": false})
	context.state = GameState.new()
	var service := _service("command_bus")
	service.begin_session({"game_version": "0.2.0"})
	context.telemetry = service
	context.commands.register(&"test.ok", func(_params: Dictionary, _ctx) -> Dictionary:
		return Result.ok({"value": 1})
	)
	context.commands.register(&"test.fail", func(_params: Dictionary, _ctx) -> Dictionary:
		return Result.fail("boom", "ui.error.start_failed")
	)
	var success := context.commands.execute(&"test.ok", {"amount": 2})
	assert_true(bool(success.get("ok", false)), "the successful command still returns its result")
	var failure := context.commands.execute(&"test.fail")
	assert_false(bool(failure.get("ok", true)), "the failing command still returns its failure")
	var unknown := context.commands.execute(&"test.missing")
	assert_false(bool(unknown.get("ok", true)), "unknown commands still fail")
	var payload := service.build_payload({"run": {"has_run": false}})
	var commands: Array = payload.get("commands", [])
	assert_eq(commands.size(), 3, "every execute() call is recorded, including failures")
	if commands.size() == 3:
		assert_eq(String(commands[0].get("command", "")), "test.ok", "the first record names the command")
		assert_true(bool(commands[0].get("ok", false)), "success is recorded")
		assert_eq(int((commands[0].get("params", {}) as Dictionary).get("amount", 0)), 2,
			"CommandBus forwards the command params to the whitelist filter")
		assert_eq(String(commands[1].get("error_code", "")), "boom", "handler error codes are recorded")
		assert_eq(String(commands[2].get("error_code", "")), "unknown_command",
			"unknown commands record the framework error code")
		assert_false(commands[2].has("params"), "unknown commands without params omit the field")
		for entry in commands:
			assert_true(int(entry.get("duration_ms", -1)) >= 0, "duration is a non-negative millisecond count")
			assert_true(typeof(entry.get("game_time", null)) in [TYPE_INT, TYPE_FLOAT], "game time is numeric")
	assert_eq(int(payload.get("run", {}).get("commands", 0)), 3, "run.commands counts every execute()")
	assert_eq(int(payload.get("run", {}).get("failed_commands", 0)), 2, "run.failed_commands counts failures")
	# null-safe：未接线/关闭时命令照样执行，记录点只是 no-op。
	context.telemetry = null
	assert_true(bool(context.commands.execute(&"test.ok").get("ok", false)),
		"commands run normally when no telemetry service is bound")
	_cleanup(TEMP_ROOT.path_join("command_bus"))


func test_uploader_keeps_pending_files_unless_the_response_is_2xx() -> void:
	var service := _service("uploader")
	service.begin_session({"game_version": "0.2.0"})
	var finalized := service.finalize_session({"run": {"has_run": true}})
	assert_true(bool(finalized.get("ok", false)), "the session is queued")
	var files := service.pending_files()
	assert_eq(files.size(), 1, "one pending file is queued")
	var pending := files[0]

	var server_error := TelemetryUploader.apply_response(pending, HTTPRequest.RESULT_SUCCESS, 500)
	assert_false(bool(server_error.get("deleted", true)), "5xx keeps the pending file")
	assert_true(FileAccess.file_exists(pending), "the pending file survives a 5xx")
	var client_error := TelemetryUploader.apply_response(pending, HTTPRequest.RESULT_SUCCESS, 400)
	assert_false(bool(client_error.get("deleted", true)), "4xx keeps the pending file")
	var timeout := TelemetryUploader.apply_response(pending, HTTPRequest.RESULT_TIMEOUT, 0)
	assert_false(bool(timeout.get("deleted", true)), "a timeout keeps the pending file")
	assert_true(FileAccess.file_exists(pending), "the pending file survives timeout/4xx/5xx")
	assert_false(TelemetryUploader.is_success_response(HTTPRequest.RESULT_SUCCESS, 302),
		"redirects are not a successful upload")
	assert_true(TelemetryUploader.is_success_response(HTTPRequest.RESULT_SUCCESS, 200), "200 is success")
	assert_true(TelemetryUploader.is_success_response(HTTPRequest.RESULT_SUCCESS, 201), "201 is success")
	assert_true(TelemetryUploader.is_success_response(HTTPRequest.RESULT_SUCCESS, 204), "204 is success")
	var ok := TelemetryUploader.apply_response(pending, HTTPRequest.RESULT_SUCCESS, 204)
	assert_true(bool(ok.get("deleted", false)), "204 deletes the pending file")
	assert_false(FileAccess.file_exists(pending), "the file is gone after a successful upload")

	# 无效 endpoint 的失败分支：不发请求、不删文件（测试禁止真实网络请求）。
	service.begin_session({"game_version": "0.2.0"})
	service.record_command("trade.buy", true, "", 1, 1.0)
	var requeued := service.finalize_session({"run": {"has_run": true}})
	assert_true(bool(requeued.get("ok", false)), "a second session is queued")
	var uploader := TelemetryUploader.new()
	uploader.bind(service)
	var invalid := TelemetryUploader.validate_endpoint("")
	assert_false(bool(invalid.get("ok", true)), "an empty endpoint fails validation before any request")
	var result: Variant = uploader.call("flush", "", "")
	assert_not_null(result, "flush starts and returns a coroutine state")
	assert_false(uploader.is_busy(), "an invalid endpoint never starts a request")
	assert_eq(service.pending_count(), 1, "an invalid endpoint leaves the pending file untouched")
	uploader.free()
	assert_false(TelemetryUploader.validate_endpoint("not-a-url").get("ok", true),
		"a malformed endpoint fails validation")
	_cleanup(TEMP_ROOT.path_join("uploader"))
