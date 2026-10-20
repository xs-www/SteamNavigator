class_name Region
extends RefCounted
## An administrative region (coastal or oceanic) containing landmasses and ports.

enum Tier {
	COASTAL,
	OCEANIC,
}

var id: String
var name_key: String
var tier: Tier
var landmass_ids: Array[String]


func _init(p_id: String = "", p_name_key: String = "", p_tier: Tier = Tier.COASTAL) -> void:
	id = p_id
	name_key = p_name_key
	tier = p_tier
	landmass_ids = []


func is_empty() -> bool:
	return id.is_empty()


func add_landmass(landmass_id: String) -> void:
	if not landmass_ids.has(landmass_id):
		landmass_ids.append(landmass_id)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name_key": name_key,
		"tier": Tier.keys()[tier],
		"landmass_ids": Array(landmass_ids),
	}


static func from_dict(value: Dictionary) -> Region:
	var region := Region.new()
	region.id = String(value.get("id", ""))
	region.name_key = String(value.get("name_key", ""))
	var tier_name := String(value.get("tier", "COASTAL"))
	var tier_index := Tier.keys().find(tier_name)
	region.tier = Tier.COASTAL if tier_index < 0 else tier_index as Tier
	var landmass_array: Array = value.get("landmass_ids", [])
	region.landmass_ids = []
	for landmass_id in landmass_array:
		region.landmass_ids.append(String(landmass_id))
	return region
