class_name WorldPort
extends RefCounted
## @static-doc
## 作用：表示锚定在陆地海岸线上的世界港口及其设施、连通性信息。
##
## ## 契约与约束
## - `departure_angle` 由 `RouteCalculator.compute_departure_angles()` 根据邻居质心计算。
## - `connectivity` 只存储直接连通的港口。
## - `facilities` 和 `tags` 供内容系统过滤与查询。
## @end-static-doc

var id: String
var position: Vector2
var region_id: String
var archetype_id: String
var size: String
var facilities: Array[String]
var diorama: Dictionary
var departure_angle: float
var landmass_id: String
var is_start_port: bool
var tags: Array[String]
var name_key: String
var description_key: String
var source_mod: String
var banner_asset: String


func _init(p_id: String = "", p_position: Vector2 = Vector2.ZERO) -> void:
	id = p_id
	position = p_position
	region_id = ""
	archetype_id = ""
	size = "medium"
	facilities = []
	diorama = {}
	departure_angle = 0.0
	landmass_id = ""
	is_start_port = false
	tags = []
	name_key = ""
	description_key = ""
	source_mod = ""
	banner_asset = ""


func is_empty() -> bool:
	return id.is_empty()


func has_facility(facility: String) -> bool:
	return facilities.has(facility)


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func has_all_tags(required_tags: Array) -> bool:
	for tag in required_tags:
		if not tags.has(String(tag)):
			return false
	return true


func distance_to(other: WorldPort) -> float:
	return position.distance_to(other.position)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"position": {"x": position.x, "y": position.y},
		"region_id": region_id,
		"archetype_id": archetype_id,
		"size": size,
		"facilities": Array(facilities),
		"diorama": diorama.duplicate(true),
		"departure_angle": departure_angle,
		"landmass_id": landmass_id,
		"is_start_port": is_start_port,
		"tags": Array(tags),
		"name_key": name_key,
		"description_key": description_key,
		"source_mod": source_mod,
		"banner_asset": banner_asset,
	}


static func from_dict(value: Dictionary) -> WorldPort:
	var port := WorldPort.new()
	port.id = String(value.get("id", ""))
	var pos_dict: Dictionary = value.get("position", {})
	port.position = Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0)))
	port.region_id = String(value.get("region_id", ""))
	port.archetype_id = String(value.get("archetype_id", ""))
	port.size = String(value.get("size", "medium"))
	var facilities_array: Array = value.get("facilities", [])
	port.facilities = []
	for facility in facilities_array:
		port.facilities.append(String(facility))
	port.diorama = (value.get("diorama", {}) as Dictionary).duplicate(true)
	port.departure_angle = float(value.get("departure_angle", 0.0))
	port.landmass_id = String(value.get("landmass_id", ""))
	port.is_start_port = bool(value.get("is_start_port", false))
	var tags_array: Array = value.get("tags", [])
	port.tags = []
	for tag in tags_array:
		port.tags.append(String(tag))
	port.name_key = String(value.get("name_key", ""))
	port.description_key = String(value.get("description_key", ""))
	port.source_mod = String(value.get("source_mod", ""))
	port.banner_asset = String(value.get("banner_asset", ""))
	return port
