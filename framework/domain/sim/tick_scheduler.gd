class_name TickScheduler
extends RefCounted
## @static-doc
## 作用：SimulationService 的确定性 tick 系统注册表。系统用 `(id, priority,
## callable)` 注册，每次 tick 按 **priority 升序、再 id 字典序** 执行，保证同一
## 种子 / 同一注册集合下的推进结果可复现（不依赖 Dictionary 迭代顺序）。
##
## ## 契约与约束
## - `register()` 允许重复调用：同一 `system_id` 覆盖旧系统，避免热重载 / 测试
##   重复注册导致同名系统执行两次。
## - callable 参数自适应：支持 `() / (state) / (state, tick) / (state, tick, context)`
##   四种签名；D0 默认把 `context` 一起传给需要它的系统。
## - `reset()` 清空注册表，仅供启动装配与测试使用；生产代码不应在 tick 中途重置。
## - 系统本身必须确定性且不改写 `data.sim`（tick/paused/speed 由 SimulationService
##   维护）；异常由调用方承担，调度器不做 try/catch。
## @end-static-doc

static var _systems: Array[Dictionary] = []


## Registers (or replaces) one tick system. Empty ids / invalid callables are
## ignored so tests can safely register optional hooks.
static func register(system_id: String, priority: int, callable: Callable) -> void:
	if system_id.is_empty() or not callable.is_valid():
		return
	unregister(system_id)
	_systems.append({
		"id": system_id,
		"priority": priority,
		"callable": callable,
	})
	_systems.sort_custom(_compare_entries)


static func unregister(system_id: String) -> void:
	for index in range(_systems.size() - 1, -1, -1):
		if String(_systems[index]["id"]) == system_id:
			_systems.remove_at(index)


static func reset() -> void:
	_systems.clear()


static func has(system_id: String) -> bool:
	for entry in _systems:
		if String(entry["id"]) == system_id:
			return true
	return false


## Read-only descriptor of the current registration order (id / priority only;
## callables stay private so ViewModels never leak them).
static func systems() -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	for entry in _sorted_entries():
		descriptors.append({
			"id": String(entry["id"]),
			"priority": int(entry["priority"]),
		})
	return descriptors


## Runs every registered system once for one simulation tick.
static func run(state: GameState, tick: int, context = null) -> void:
	for entry in _sorted_entries():
		var callable: Callable = entry["callable"]
		if not callable.is_valid():
			continue
		var argc := callable.get_argument_count()
		if argc >= 3:
			callable.call(state, tick, context)
		elif argc == 2:
			callable.call(state, tick)
		elif argc == 1:
			callable.call(state)
		else:
			callable.call()


static func _sorted_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in _systems:
		entries.append(entry)
	entries.sort_custom(_compare_entries)
	return entries


static func _compare_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_priority := int(left["priority"])
	var right_priority := int(right["priority"])
	if left_priority != right_priority:
		return left_priority < right_priority
	return String(left["id"]) < String(right["id"])
