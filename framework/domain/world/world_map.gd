class_name WorldMap
extends RefCounted
## @static-doc
## 作用：世界地图顶层容器，保存陆地、港口、区域、连通性、已算好的航线与本世界种子。
##
## ## 契约与约束
## - `connectivity_graph` 是无向图，A 连接 B 时 B 也连接 A。
## - `bounds` 供 UI 视口裁剪与世界坐标映射使用。
## - `world_seed` 用于验证存档和当前内容版本的兼容性。
## - `edges` 是**生成期算出、运行期只读**的航线表：每个边一条
##   `{from, to, distance, base_risk?, path}`（`path` 为 `PackedVector2Array`）。这是唯一的
##   世界拓扑：`GameState.world()` 的 `routes` 由它派生（`ChartWorldProjection.from_chart`），
##   海图、航行演出、委托与 BFS 全部读这一张表。航线算法可以随时替换，只要这个数据契约
##   不变，查询/UI 就不受影响；缺 `edges` 的旧存档由消费方自行回退计算。
## - `base_risk` 只由可玩世界生成器（`WorldGenerator.generate_chart`，范围来自
##   `route_templates.risk_range`）写入；通用生成器 / 旧存档的世界没有该键，消费方读不到
##   时应视为「未知风险」而不是 0。
## @end-static-doc

const SCHEMA_VERSION := "1.2"
## Path coordinates are stored rounded to this many decimals to keep saves small;
## far below the chart's pixel resolution.
const PATH_DECIMALS := 2

var bounds: Rect2
var landmasses: Array[Landmass]
var ports: Array[WorldPort]
var regions: Array[Region]
var connectivity_graph: Dictionary
## `{from, to, distance, path: PackedVector2Array}` per connectivity edge.
var edges: Array[Dictionary]
var world_seed: int
var schema_version: String

var _edges_by_pair: Dictionary = {}


func _init() -> void:
	bounds = Rect2()
	landmasses = []
	ports = []
	regions = []
	connectivity_graph = {}
	edges = []
	_edges_by_pair = {}
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


## Replaces the precomputed route table and rebuilds the pair index.
func set_edges(new_edges: Array[Dictionary]) -> void:
	edges = new_edges
	_rebuild_edge_index()


## Stored route for an unordered port pair, or `{}` when this world has no precomputed
## entry (old saves) — callers then fall back to `RouteCalculator.calculate_route`.
func route_for(from_port_id: String, to_port_id: String) -> Dictionary:
	return _edges_by_pair.get(_pair_key(from_port_id, to_port_id), {})


func route_count() -> int:
	return edges.size()


func _rebuild_edge_index() -> void:
	_edges_by_pair = {}
	for edge in edges:
		var from_id := String(edge.get("from", ""))
		var to_id := String(edge.get("to", ""))
		if from_id.is_empty() or to_id.is_empty():
			continue
		_edges_by_pair[_pair_key(from_id, to_id)] = edge


static func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


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
	var edges_array := []
	for edge in edges:
		edges_array.append(_edge_to_dict(edge))
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
		"edges": edges_array,
	}


## Paths are flattened to `[x0, y0, x1, y1, ...]` rounded to `PATH_DECIMALS`; object
## per point would roughly double the JSON size of the route table. `base_risk` is only
## written when the edge has it (playable worlds), so generic worlds / old saves keep the
## historical shape.
static func _edge_to_dict(edge: Dictionary) -> Dictionary:
	var path: PackedVector2Array = edge.get("path", PackedVector2Array())
	var flat: Array = []
	flat.resize(path.size() * 2)
	for index in path.size():
		flat[index * 2] = snappedf(path[index].x, pow(10.0, -PATH_DECIMALS))
		flat[index * 2 + 1] = snappedf(path[index].y, pow(10.0, -PATH_DECIMALS))
	var value := {
		"from": String(edge.get("from", "")),
		"to": String(edge.get("to", "")),
		"distance": snappedf(float(edge.get("distance", 0.0)), pow(10.0, -PATH_DECIMALS)),
		"path": flat,
	}
	if edge.has("base_risk"):
		value["base_risk"] = float(edge.get("base_risk", 0.0))
	return value


static func _edge_from_dict(value: Dictionary) -> Dictionary:
	var path := PackedVector2Array()
	var flat: Array = value.get("path", [])
	var index := 0
	while index + 1 < flat.size():
		path.append(Vector2(float(flat[index]), float(flat[index + 1])))
		index += 2
	var edge := {
		"from": String(value.get("from", "")),
		"to": String(value.get("to", "")),
		"distance": float(value.get("distance", 0.0)),
		"path": path,
	}
	if value.has("base_risk"):
		edge["base_risk"] = float(value.get("base_risk", 0.0))
	return edge


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
	# Absent in worlds generated before schema 1.1; consumers fall back to computing.
	var parsed_edges: Array[Dictionary] = []
	for edge_dict in value.get("edges", []):
		if edge_dict is Dictionary:
			parsed_edges.append(_edge_from_dict(edge_dict))
	world.set_edges(parsed_edges)
	return world
