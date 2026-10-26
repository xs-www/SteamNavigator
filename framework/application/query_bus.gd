class_name QueryBus
extends RefCounted
## @static-doc
## 作用：只读查询执行器：在临时克隆的 GameState 上运行 ViewModel 查询，保证有 bug 的查询写不进活状态。
##
## ## 契约与约束
## - 查询失败返回结构化 Result（`unknown_query` / `no_context` / `invalid_result`），不用 null 混淆“无数据”和“错误”。
## - 处理器返回普通 Dictionary；没有 `ok` 字段时自动包装为成功。
## - 默认每个查询克隆一次 `context.state`（HEAD 开局约 11.6 ms），克隆在调用期间临时替换 `context.state`，结束后还原原对象。
## - **读作用域**（性能）：`begin_read_scope()` / `end_read_scope()` 期间所有查询共享同一份克隆快照，整页重建的 N 次查询只付一次克隆成本；嵌套调用折叠到最外层。
## - `invalidate_read_snapshot()` 由 `CommandBus` 在提交成功后调用：活状态已变，作用域内下一次查询会重新克隆，不会读到过期快照。
## - 查询仍不得依赖副作用；共享快照把“查询不写状态”这条不变量从“隔离”降级为“共享只读”，由 `test_ui_shell::test_query_read_scope_*` 守护语义。
##
## ## 重点逻辑
## ### `execute(query_name, params)`
## - 作用域内用共享快照，作用域外每次克隆；`context.state` 替换后调用处理器并在 finally 语义处还原（当前实现为顺序还原，处理器异常路径由 Result 兜底）。
## @end-static-doc
##
## Read-only use cases returning ViewModels.
##
## Query handlers receive a temporary deep clone of GameState, so a buggy
## query cannot mutate live state through a nested dictionary reference.
##
## A page rebuild may run a dozen queries back to back; cloning the whole state
## for each of them dominated the rebuild cost (11.6 ms per query on the HEAD
## state). `begin_read_scope()` / `end_read_scope()` let a caller reuse **one**
## immutable clone for every query in the burst; `invalidate_read_snapshot()`
## (called by CommandBus after a commit) drops it as soon as live state changes,
## so a query after a command never sees a stale snapshot.

var _context = null
var _handlers: Dictionary = {}
var _read_scope_depth: int = 0
var _read_snapshot: GameState = null


func _init(context = null) -> void:
	_context = context


func register(query_name: StringName, handler: Callable) -> void:
	_handlers[query_name] = handler


func has(query_name: StringName) -> bool:
	return _handlers.has(query_name)


func names() -> PackedStringArray:
	var result := PackedStringArray()
	for name in _handlers.keys():
		result.append(String(name))
	result.sort()
	return result


## Opens a read burst. Nested scopes collapse into the outermost one, so a
## helper that refreshes the page from inside a rebuild does not pay extra.
func begin_read_scope() -> void:
	_read_scope_depth += 1


## Closes a read burst; the shared snapshot is dropped with the outermost scope.
func end_read_scope() -> void:
	_read_scope_depth = maxi(0, _read_scope_depth - 1)
	if _read_scope_depth == 0:
		_read_snapshot = null


## Drops the shared snapshot (live state changed). CommandBus calls this after a
## successful commit; a still-open read scope lazily re-clones on the next query.
func invalidate_read_snapshot() -> void:
	_read_snapshot = null


func read_scope_depth() -> int:
	return _read_scope_depth


func execute(query_name: StringName, params: Dictionary = {}) -> Dictionary:
	if _context == null:
		return Result.fail("no_context", "ui.error.start_failed", {"query": String(query_name)})
	if not _handlers.has(query_name):
		return Result.fail("unknown_query", "ui.error.unknown_query", {"query": String(query_name)})

	var original_state: GameState = _context.state
	var query_state: GameState
	if _read_scope_depth > 0:
		if _read_snapshot == null:
			_read_snapshot = original_state.clone()
		query_state = _read_snapshot
	else:
		query_state = original_state.clone()
	_context.state = query_state
	var result: Variant = _handlers[query_name].call(params, _context)
	_context.state = original_state
	if not (result is Dictionary):
		return Result.fail("invalid_result", "ui.error.internal", {"query": String(query_name)})
	if not result.has("ok"):
		return Result.ok(result)
	return result
