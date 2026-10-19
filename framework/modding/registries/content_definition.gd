class_name ContentDefinition
extends RefCounted
## An immutable-by-convention content definition loaded from a mod.

var id: String = ""
var content_type: StringName = &""
var name_key: String = ""
var description_key: String = ""
var tags: PackedStringArray = PackedStringArray()
var enabled: bool = true
var information: Dictionary = {}
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
	var raw_information: Variant = raw_definition.get("information", {})
	definition.information = raw_information.duplicate(true) if raw_information is Dictionary else {}
	var raw_data: Variant = raw_definition.get("data", {})
	definition.data = raw_data.duplicate(true) if raw_data is Dictionary else {}
	definition.source_mod = mod_id
	definition.source_file = file
	definition.raw = raw_definition.duplicate(true)
	if definition.information.is_empty():
		definition.raw.erase("information")
	else:
		definition.raw["information"] = definition.information
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
	if information.is_empty():
		copy.erase("information")
	else:
		copy["information"] = information.duplicate(true)
	copy["data"] = data.duplicate(true)
	return copy


func get_data_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)


func get_information_value(key: String, fallback: Variant = null) -> Variant:
	return information.get(key, fallback)


func asset_uri(field: String) -> String:
	var asset_key := String(information.get(field, "")).strip_edges()
	if asset_key.is_empty():
		return ""
	if asset_key.begins_with("asset://"):
		return asset_key
	return "asset://%s/%s" % [source_mod, asset_key]
