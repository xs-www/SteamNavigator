class_name RegistryHub
extends RefCounted
## Owns all content-type registries and freezes them as one unit.

var _registries: Dictionary = {}
var _frozen: bool = false


func _init(content_types: Array[StringName] = []) -> void:
	var types := content_types
	if types.is_empty():
		types = ContentTypes.all()
	for content_type in types:
		_registries[content_type] = DefinitionRegistry.new(content_type)


func registry(content_type: StringName) -> DefinitionRegistry:
	return _registries.get(content_type, null)


func register(definition: ContentDefinition, source_mod: String = "") -> Dictionary:
	var target := registry(definition.content_type)
	if target == null:
		return {
			"ok": false,
			"error_code": "unknown_content_type",
			"message": "no registry for content type '%s'" % definition.content_type,
		}
	return target.register(definition, source_mod)


func get_by_id(content_type: StringName, id: String) -> ContentDefinition:
	var target := registry(content_type)
	return target.get_by_id(id) if target != null else null


func contains(content_type: StringName, id: String) -> bool:
	var target := registry(content_type)
	return target.contains(id) if target != null else false


func get_all(content_type: StringName) -> Array[ContentDefinition]:
	var target := registry(content_type)
	return target.get_all() if target != null else []


func query(content_type: StringName, required_tags: Array) -> Array[ContentDefinition]:
	var target := registry(content_type)
	return target.query(required_tags) if target != null else []


func freeze_all() -> void:
	for content_type in _registries.keys():
		_registries[content_type].freeze()
	_frozen = true


func is_frozen() -> bool:
	return _frozen


func counts() -> Dictionary:
	var result := {}
	for content_type in _registries.keys():
		result[String(content_type)] = _registries[content_type].size()
	return result


func total_count() -> int:
	var total := 0
	for content_type in _registries.keys():
		total += _registries[content_type].size()
	return total
