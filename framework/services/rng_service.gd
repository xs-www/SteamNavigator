class_name RngService
extends RefCounted
## Named, reproducible random streams.
##
## Each stream is derived from (base seed, stream name, context key). Systems
## never share a stream, so adding a cosmetic roll cannot change market or
## risk outcomes for the same seed and command sequence.

const STREAM_MAP_GENERATION := &"map_generation"
const STREAM_GOODS_GENERATION := &"goods_generation"
const STREAM_NPC_TRADE := &"npc_trade"
const STREAM_CONTRACT_GENERATION := &"contract_generation"
const STREAM_VOYAGE_RISK := &"voyage_risk"
const STREAM_VOYAGE_EVENT := &"voyage_event"
const STREAM_EVENT_OPTIONS := &"event_options"
## Exploration clues / discovery rolls. Kept separate from voyage streams so adding a
## rumour roll can never shift normal voyage outcomes for the same seed.
const STREAM_EXPLORATION := &"exploration"
## Phase B campaign world assembly (regions / sites / routes / factions / discoveries).
## Separate from map generation so v2 world detail rolls cannot shift the 1.0 map.
const STREAM_CAMPAIGN_WORLD := &"campaign_world"
## Phase D1 combat auto-resolve (weapon hits / encounter composition / loot rolls).
const STREAM_COMBAT := &"combat"

const STREAM_NAMES := [
	STREAM_MAP_GENERATION,
	STREAM_GOODS_GENERATION,
	STREAM_NPC_TRADE,
	STREAM_CONTRACT_GENERATION,
	STREAM_VOYAGE_RISK,
	STREAM_VOYAGE_EVENT,
	STREAM_EVENT_OPTIONS,
	STREAM_EXPLORATION,
	STREAM_CAMPAIGN_WORLD,
	STREAM_COMBAT,
]

var base_seed: int = 0

var _streams: Dictionary = {}


func _init(seed_value: int = 1) -> void:
	base_seed = seed_value


func stream(stream_name: StringName, context_key: String = "") -> RandomNumberGenerator:
	var key := "%s::%s" % [String(stream_name), context_key]
	if _streams.has(key):
		return _streams[key]
	var generator := RandomNumberGenerator.new()
	generator.seed = StableHash.seed_from(base_seed, stream_name, context_key)
	_streams[key] = generator
	return generator


func make_stream(stream_name: StringName, context_key: String = "") -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = StableHash.seed_from(base_seed, stream_name, context_key)
	return generator


func derive_seed(stream_name: StringName, context_key: String = "") -> int:
	return StableHash.seed_from(base_seed, stream_name, context_key)


static func choose_weighted(generator: RandomNumberGenerator, items: Array, weight_key: String = "weight") -> Variant:
	if items.is_empty():
		return null
	var total := 0.0
	for item in items:
		var weight := _weight_of(item, weight_key)
		if weight > 0.0:
			total += weight
	if total <= 0.0:
		return null
	var roll := generator.randf() * total
	for item in items:
		var weight := _weight_of(item, weight_key)
		if weight <= 0.0:
			continue
		roll -= weight
		if roll <= 0.0:
			return item
	return items[items.size() - 1]


static func sample_without_replacement(generator: RandomNumberGenerator, items: Array, count: int) -> Array:
	var pool := items.duplicate()
	var result: Array = []
	var wanted := mini(count, pool.size())
	for _index in wanted:
		var picked_index := generator.randi_range(0, pool.size() - 1)
		result.append(pool[picked_index])
		pool.remove_at(picked_index)
	return result


static func _weight_of(item: Variant, weight_key: String) -> float:
	if item is Dictionary:
		return float(item.get(weight_key, 1.0))
	return 1.0
