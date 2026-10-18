class_name ContentDefinition
extends RefCounted
## An immutable-by-convention content definition loaded from a mod.

var id: String = ""
var content_type: StringName = &""
var name_key: String = ""
var description_key: String = ""
var tags: PackedStringArray = PackedStringArray()
var enabled: bool = true
var data: Dictionary = {}
var source_mod: String = ""
var source_file: String = ""
var patched_by: PackedStringArray = PackedStringArray()
var raw: Dictionary = {}


static func from_raw(raw_definition: Dictionary, type: StringName, mod_id: String, file: String) -> ContentDefinition:
	var definition := ContentDefinition.new()
	definition.id = String(raw_definition.get("id", ""))
	definition.content_type = type
	definition.name_key = String(raw_definition.get("name_key", ""))
	definition.description_key = String(raw_definition.get("description_key", ""))
	definition.tags = PackedStringArray(raw_definition.get("tags", []))
	definition.enabled = bool(raw_definition.get("enabled", true))
	var raw_data: Variant = raw_definition.get("data", {})
	definition.data = raw_data if raw_data is Dictionary else {}
	definition.source_mod = mod_id
	definition.source_file = file
	definition.raw = raw_definition.duplicate(true)
	definition.raw["data"] = definition.data
	return definition


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func has_all_tags(required_tags: Array) -> bool:
	for tag in required_tags:
		if not tags.has(String(tag)):
			return false
	return true


func to_raw() -> Dictionary:
	var copy := raw.duplicate(true)
	copy["id"] = id
	copy["name_key"] = name_key
	if not description_key.is_empty():
		copy["description_key"] = description_key
	copy["tags"] = Array(tags)
	copy["enabled"] = enabled
	copy["data"] = data.duplicate(true)
	return copy


func get_data_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)
