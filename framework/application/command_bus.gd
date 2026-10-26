class_name CommandBus
extends RefCounted
## @static-doc
## 作用：命令执行器：在 GameState 深拷贝上运行用例，成功才提交、发布领域事件并可请求自动存档。
##
## ## 契约与约束
## - 处理器签名 `(params: Dictionary, context) -> Result envelope`；失败时丢弃工作副本，原始 GameState 与哈希保持不变。
## - 成功时用 `original_state.replace_with(working_state)` 写回原对象，保持外部引用有效（查询/存档持有的仍是同一个 GameState）。
## - 成功后按顺序发布 `{type, payload}` 事件，并通知 `QueryBus.invalidate_read_snapshot()`：活状态已变，页重建的共享读快照必须作废。
## - 结果带 `autosave` 且 `context.autosave_enabled` 时触发自动存档（开局/抵达/剧情/委托等节点）。
## - 保留最近 200 条执行日志（命令、成功、错误码、耗时、游戏时间）。
## - 每次执行（含未知命令的失败）向 `context.telemetry` 记一条命令记录（成功、错误码、耗时、游戏时间、
##   白名单参数摘要）；`context.telemetry` 为 null 或未开启记录时是 no-op（docs/design/TELEMETRY.md §3.3、§3.4、§5）。
##
## ## 重点逻辑
## ### `execute(command_name, params)`
## - 克隆 `context.state` 并临时替换，处理器对工作副本的修改不会泄漏到事务外。
## - 非法返回值/未知命令/无 context 统一转换为结构化 Result.fail；只有 `ok` 为真才提交。
## - telemetry 记录与 200 条执行日志同源（同一耗时/错误码），不参与事务：记录失败不影响命令结果。
## @end-static-doc
##
## Executes state-changing use cases inside a clone-and-commit transaction.
##
## Handlers receive `(params: Dictionary, context)` and return a Result
## envelope. The context sees a deep clone of GameState; only a successful
## result is committed and its domain events published.

var _context = null
var _handlers: Dictionary = {}
var _execution_log: Array[Dictionary] = []


func _init(context = null) -> void:
	_context = context


func register(command_name: StringName, handler: Callable) -> void:
	_handlers[command_name] = handler


func has(command_name: StringName) -> bool:
	return _handlers.has(command_name)


func names() -> PackedStringArray:
	var result := PackedStringArray()
	for name in _handlers.keys():
		result.append(String(name))
	result.sort()
	return result


func execute(command_name: StringName, params: Dictionary = {}) -> Dictionary:
	if _context == null:
		return Result.fail("no_context", "ui.error.start_failed", {"command": String(command_name)})
	if not _handlers.has(command_name):
		_record_telemetry(String(command_name), false, "unknown_command", 0, _context.state.now(), params)
		return Result.fail("unknown_command", "ui.error.unknown_command", {"command": String(command_name)})

	var started_at := Time.get_ticks_usec()
	var original_state: GameState = _context.state
	var working_state := original_state.clone()
	_context.state = working_state
	var result: Variant = _handlers[command_name].call(params, _context)
	if not (result is Dictionary) or not result.has("ok"):
		result = Result.fail("invalid_result", "ui.error.internal", {"command": String(command_name)})

	if bool(result["ok"]):
		original_state.replace_with(working_state)
		_context.state = original_state
		# Live state changed: drop the read-scope snapshot so the queries that
		# follow this commit (the page rebuild) see the committed data.
		if _context.queries != null:
			_context.queries.invalidate_read_snapshot()
		var events: Variant = result.get("events", [])
		if events is Array:
			_context.events.publish_many(events, _context.state.now(), "framework")
		if bool(result.get("autosave", false)) and _context.autosave_enabled:
			_context.autosave(result.get("autosave_meta", {}))
	else:
		_context.state = original_state

	var elapsed_ms := int((Time.get_ticks_usec() - started_at) / 1000)
	_execution_log.append({
		"command": String(command_name),
		"ok": bool(result.get("ok", false)),
		"error_code": String(result.get("error_code", "")),
		"duration_ms": elapsed_ms,
		"game_time": _context.state.now(),
	})
	if _execution_log.size() > 200:
		_execution_log.pop_front()
	_record_telemetry(
		String(command_name),
		bool(result.get("ok", false)),
		String(result.get("error_code", "")),
		elapsed_ms,
		_context.state.now(),
		params
	)
	return result


## 游玩日志记录点：context.telemetry 为 null（未接线/关闭）时直接跳过，绝不影响命令结果。
func _record_telemetry(command: String, ok: bool, error_code: String, duration_ms: int, game_time: float, params: Dictionary) -> void:
	if _context == null or _context.telemetry == null:
		return
	_context.telemetry.record_command(command, ok, error_code, duration_ms, game_time, params)


func get_execution_log(limit: int = 50) -> Array[Dictionary]:
	var start := maxi(0, _execution_log.size() - limit)
	return _execution_log.slice(start, _execution_log.size())
