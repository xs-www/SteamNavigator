class_name DomainEventBus
extends RefCounted
## Publishes committed domain facts with a stable envelope.

signal event_published(event: Dictionary)

const MAX_HISTORY := 500
const SCHEMA_VERSION := "1.0"

var max_history: int = MAX_HISTORY

var _history: Array[Dictionary] = []
var _sequence: int = 0


func publish(event_type: StringName, payload: Dictionary = {}, game_time: float = 0.0, source: String = "framework") -> Dictionary:
	_sequence += 1
	var event := {
		"event_id": "evt-%08d" % _sequence,
		"event_type": String(event_type),
		"game_time": game_time,
		"source": source,
		"payload": payload.duplicate(true),
		"schema_version": SCHEMA_VERSION,
	}
	_history.append(event)
	while _history.size() > max_history:
		_history.pop_front()
	event_published.emit(event.duplicate(true))
	return event


func publish_many(events: Array, game_time: float = 0.0, source: String = "framework") -> Array[Dictionary]:
	var published: Array[Dictionary] = []
	for raw_event in events:
		if not (raw_event is Dictionary):
			continue
		var event_type := String(raw_event.get("event_type", raw_event.get("type", "unknown")))
		var payload: Variant = raw_event.get("payload", {})
		if not (payload is Dictionary):
			payload = {}
		published.append(publish(event_type, payload, game_time, source))
	return published


func get_history(event_type: StringName = &"", limit: int = 100) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event in _history:
		if event_type == &"" or event["event_type"] == String(event_type):
			filtered.append(event.duplicate(true))
	var start := maxi(0, filtered.size() - limit)
	return filtered.slice(start, filtered.size())


func last_event(event_type: StringName = &"") -> Dictionary:
	var history := get_history(event_type, 1)
	return history[0] if not history.is_empty() else {}


func has_event(event_type: StringName) -> bool:
	return not get_history(event_type, 1).is_empty()


func count() -> int:
	return _history.size()


func clear() -> void:
	_history.clear()
	_sequence = 0
