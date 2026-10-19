class_name GameState
extends RefCounted
## The complete mutable run state.
##
## GameState is a plain-data wrapper so it can be deep-cloned per command
## transaction, serialized directly, and fingerprinted for determinism tests.
## Content definitions never live here; only IDs and runtime values do.

const SCHEMA_VERSION := "1.0"

## Default run statistics. `profit` is always derived as `income - expense`.
const STATS_DEFAULTS := {
	"voyages": 0,
	"on_time": 0,
	"accidents": 0,
	"income": 0,
	"expense": 0,
	"profit": 0,
}

var data: Dictionary = {}


func _init(initial_data: Dictionary = {}) -> void:
	data = initial_data


func clone() -> GameState:
	return GameState.new(data.duplicate(true))


func replace_with(other: GameState) -> void:
	data = other.data.duplicate(true)


func to_dict() -> Dictionary:
	return data.duplicate(true)


static func from_dict(value: Dictionary) -> GameState:
	return GameState.new(value.duplicate(true))


func is_empty() -> bool:
	return data.is_empty()


func hash() -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JsonUtils.canonical_stringify(data).to_utf8_buffer())
	return context.finish().hex_encode()


func schema_version() -> String:
	return String(data.get("schema_version", ""))


func run() -> Dictionary:
	return data.get("run", {})


func player() -> Dictionary:
	return data.get("player", {})


func world() -> Dictionary:
	return data.get("world", {})


func ship() -> Dictionary:
	return data.get("ship", {})


func market() -> Dictionary:
	return data.get("market", {})


func contracts() -> Dictionary:
	return data.get("contracts", {})


## Returns the run statistics, creating/repairing them lazily so old saves and
## partially initialized test states never need a migration pass.
func stats() -> Dictionary:
	return ensure_stats()


func ensure_stats() -> Dictionary:
	var current: Variant = data.get("stats", null)
	if not (current is Dictionary):
		current = STATS_DEFAULTS.duplicate(true)
		data["stats"] = current
	var stats_data: Dictionary = current
	for key in STATS_DEFAULTS.keys():
		if not stats_data.has(key):
			stats_data[key] = STATS_DEFAULTS[key]
	stats_data["profit"] = int(stats_data.get("income", 0)) - int(stats_data.get("expense", 0))
	return stats_data


func record_income(amount: int) -> void:
	if amount <= 0:
		return
	var stats_data := ensure_stats()
	stats_data["income"] = int(stats_data.get("income", 0)) + amount
	stats_data["profit"] = int(stats_data["income"]) - int(stats_data.get("expense", 0))


func record_expense(amount: int) -> void:
	if amount <= 0:
		return
	var stats_data := ensure_stats()
	stats_data["expense"] = int(stats_data.get("expense", 0)) + amount
	stats_data["profit"] = int(stats_data.get("income", 0)) - int(stats_data["expense"])


func now() -> float:
	return float(run().get("game_time", 0.0))


func set_now(value: float) -> void:
	if not data.has("run"):
		data["run"] = {}
	data["run"]["game_time"] = maxf(0.0, value)


func advance_time(hours: float) -> void:
	set_now(now() + maxf(0.0, hours))


func money() -> int:
	return int(player().get("money", 0))


func set_money(value: int) -> void:
	if not data.has("player"):
		data["player"] = {}
	data["player"]["money"] = value


func add_money(amount: int) -> void:
	set_money(money() + amount)


func current_port_id() -> String:
	return String(world().get("current_port_id", ""))


func is_at_port() -> bool:
	return not current_port_id().is_empty() and data.get("voyage", null) == null


func seed() -> int:
	return int(run().get("seed", 0))


func push_notice(text_key: String, params: Dictionary = {}) -> void:
	if not data.has("notices"):
		data["notices"] = []
	var notices: Array = data["notices"]
	notices.append({
		"text_key": text_key,
		"params": params.duplicate(true),
		"game_time": now(),
	})
	if notices.size() > 50:
		notices.pop_front()


func recent_notices(limit: int = 10) -> Array:
	var notices: Array = data.get("notices", [])
	var start := maxi(0, notices.size() - limit)
	return notices.slice(start, notices.size())


func get_value(path: Array, fallback: Variant = null) -> Variant:
	var current: Variant = data
	for segment in path:
		if current is Dictionary and current.has(segment):
			current = current[segment]
		elif current is Array and String(segment).is_valid_int():
			var index := int(segment)
			if index < 0 or index >= current.size():
				return fallback
			current = current[index]
		else:
			return fallback
	return current
