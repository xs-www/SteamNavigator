class_name WorldMap
extends RefCounted
## The complete world map containing landmasses, ports, regions, and connectivity.
##
## Generated once per campaign from a seed; all procedural generation uses named
## RNG streams for reproducibility.

const SCHEMA_VERSION := "1.0"

var bounds: Rect2
var landmasses: Array[Landmass]
var ports: Array[WorldPort]
var regions: Array[Region]
var connectivity_graph: Dictionary
var world_seed: int
var schema_version: String


func _init() -> void:
	bounds = Rect2()
	landmasses = []
	ports = []
	regions = []
	connectivity_graph = {}
	world_seed = 0
	schema_version = SCHEMA_VERSION


func is_empty() -> bool:
	return landmasses.is_empty() and ports.is_empty()


func get_landmass(landmass_id: String) -> Landmass:
	for landmass in landmasses:
		if landmass.id == landmass_id:
			return landmass
	return Landmass.new()


func get_port(port_id: String) -> WorldPort:
	for port in ports:
		if port.id == port_id:
			return port
	return WorldPort.new()


func get_region(region_id: String) -> Region:
	for region in regions:
		if region.id == region_id:
			return region
	return Region.new()


func get_start_port() -> WorldPort:
	for port in ports:
		if port.is_start_port:
			return port
	return WorldPort.new()


func get_ports_in_region(region_id: String) -> Array[WorldPort]:
	var result: Array[WorldPort] = []
	for port in ports:
		if port.region_id == region_id:
			result.append(port)
	return result


func get_landmasses_in_region(region_id: String) -> Array[Landmass]:
	var result: Array[Landmass] = []
	for landmass in landmasses:
		if landmass.region_id == region_id:
			result.append(landmass)
	return result


func find_landmass_containing(point: Vector2) -> Landmass:
	for landmass in landmasses:
		if landmass.contains_point(point):
			return landmass
	return Landmass.new()


func is_point_on_land(point: Vector2) -> bool:
	return not find_landmass_containing(point).is_empty()


func total_land_area() -> float:
	var total := 0.0
	for landmass in landmasses:
		total += landmass.area()
	return total


func land_coverage_ratio() -> float:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 0.0
	return total_land_area() / (bounds.size.x * bounds.size.y)


func to_dict() -> Dictionary:
	var landmasses_array := []
	for landmass in landmasses:
		landmasses_array.append(landmass.to_dict())
	var ports_array := []
	for port in ports:
		ports_array.append(port.to_dict())
	var regions_array := []
	for region in regions:
		regions_array.append(region.to_dict())
	return {
		"schema_version": schema_version,
		"world_seed": world_seed,
		"bounds": {
			"position": {"x": bounds.position.x, "y": bounds.position.y},
			"size": {"x": bounds.size.x, "y": bounds.size.y},
		},
		"landmasses": landmasses_array,
		"ports": ports_array,
		"regions": regions_array,
		"connectivity_graph": connectivity_graph.duplicate(true),
	}


static func from_dict(value: Dictionary) -> WorldMap:
	var world := WorldMap.new()
	world.schema_version = String(value.get("schema_version", SCHEMA_VERSION))
	world.world_seed = int(value.get("world_seed", 0))
	var bounds_dict: Dictionary = value.get("bounds", {})
	var pos_dict: Dictionary = bounds_dict.get("position", {})
	var size_dict: Dictionary = bounds_dict.get("size", {})
	world.bounds = Rect2(
		Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0))),
		Vector2(float(size_dict.get("x", 0.0)), float(size_dict.get("y", 0.0)))
	)
	for landmass_dict in value.get("landmasses", []):
		if landmass_dict is Dictionary:
			world.landmasses.append(Landmass.from_dict(landmass_dict))
	for port_dict in value.get("ports", []):
		if port_dict is Dictionary:
			world.ports.append(WorldPort.from_dict(port_dict))
	for region_dict in value.get("regions", []):
		if region_dict is Dictionary:
			world.regions.append(Region.from_dict(region_dict))
	world.connectivity_graph = (value.get("connectivity_graph", {}) as Dictionary).duplicate(true)
	return world
