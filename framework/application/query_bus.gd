class_name QueryBus
extends RefCounted
## Read-only use cases returning ViewModels.
##
## Query handlers receive a temporary deep clone of GameState, so a buggy
## query cannot mutate live state through a nested dictionary reference.

var _context = null
var _handlers: Dictionary = {}


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


func execute(query_name: StringName, params: Dictionary = {}) -> Dictionary:
	if _context == null:
		return Result.fail("no_context", "ui.error.start_failed", {"query": String(query_name)})
	if not _handlers.has(query_name):
		return Result.fail("unknown_query", "ui.error.unknown_query", {"query": String(query_name)})

	var original_state: GameState = _context.state
	_context.state = original_state.clone()
	var result: Variant = _handlers[query_name].call(params, _context)
	_context.state = original_state
	if not (result is Dictionary):
		return Result.fail("invalid_result", "ui.error.internal", {"query": String(query_name)})
	if not result.has("ok"):
		return Result.ok(result)
	return result
