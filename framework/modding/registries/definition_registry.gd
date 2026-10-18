class_name DefinitionRegistry
extends RefCounted
## One registry per content type.
##
## Definitions become read-only by convention after freeze(). Runtime mutable
## values (stock, durability, money) live in GameState, never here.

var content_type: StringName = &""
var _definitions: Dictionary = {}
var _sources: Dictionary = {}
var _order: Array[String] = []
var _frozen: bool = false


func _init(type: StringName = &"") -> void:
	content_type = type


func register(definition: ContentDefinition, source_mod: String = "") -> Dictionary:
	if _frozen:
		return _fail("registry_frozen", "registry '%s' is frozen" % content_type)
	if definition == null:
		return _fail("invalid_definition", "definition is null")
	if definition.id.is_empty():
		return _fail("invalid_id", "definition id is empty")
	if definition.content_type != content_type:
		return _fail(
			"type_mismatch",
			"definition '%s' has type '%s' but registry expects '%s'" % [definition.id, definition.content_type, content_type]
		)
	if _definitions.has(definition.id):
		return _fail("duplicate_id", "definition id already registered: %s" % definition.id)
	_definitions[definition.id] = definition
	_sources[definition.id] = source_mod if not source_mod.is_empty() else definition.source_mod
	_order.append(definition.id)
	return {"ok": true, "error_code": "", "message": ""}


func get_by_id(id: String) -> ContentDefinition:
	return _definitions.get(id, null)


func contains(id: String) -> bool:
	return _definitions.has(id)


func get_all() -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for id in _order:
		result.append(_definitions[id])
	return result


func query(required_tags: Array) -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for id in _order:
		var definition: ContentDefinition = _definitions[id]
		if definition.has_all_tags(required_tags):
			result.append(definition)
	return result


func with_tags(required_tags: Array) -> Array[ContentDefinition]:
	return query(required_tags)


func source_of(id: String) -> String:
	return String(_sources.get(id, ""))


func ids() -> Array[String]:
	return _order.duplicate()


func size() -> int:
	return _definitions.size()


func is_frozen() -> bool:
	return _frozen


func freeze() -> void:
	_frozen = true


func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "error_code": code, "message": message}
