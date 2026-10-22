class_name RouteAssembler
extends RefCounted
## @static-doc
## 作用：v2 战役的航路装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 7）。为抽象海图的每条边
## 按两端港口所属区域的 `kind` 过滤 `route_templates`，抽取一条可用模板并把
## `{id, kind, distance_range, risk_range, travel_time_range, bidirectional,
## encounter_table}` 写入该边的 `template` 元数据。
##
## ## 契约与约束
## - **不动几何数值**：抽象边的 `distance` / `base_risk` 保持 MapGenerator 输出（1.0
##   航行结算依赖它们）；模板只作为声明式元数据（后续切片用于遭遇 / 时间细化）。
## - 候选过滤：模板 `region_kinds` 为空 = 任意；非空时只要包含**任一端**区域的 kind
##   即可用。没有候选时写入空 `template` 字典，不删边、不失败。
## - 输出为输入 routes 的深拷贝数组，不修改 MapGenerator 的世界字典。
## - **确定性**：随机来自 `STREAM_CAMPAIGN_WORLD / "routes"` 子流；模板按 id 排序后
##   均匀抽取（模板 schema 无 weight 字段）。
## @end-static-doc


## Attaches a route template to every abstract edge.
## `regions` is the RegionAssembler instance list; `region_for_port` maps port id →
## region id. Returns a new array of route dictionaries (same order as input).
static func assemble(
	routes: Array,
	regions: Array,
	region_for_port: Dictionary,
	route_definitions: Array,
	rng: RandomNumberGenerator
) -> Array:
	var definitions := CampaignAssembly.sorted_by_id(route_definitions)
	var region_index := CampaignAssembly.index_by_id(regions)
	var result: Array = []
	for raw_route in routes:
		var route: Dictionary = (raw_route as Dictionary).duplicate(true)
		route["template"] = _pick_template(route, region_index, region_for_port, definitions, rng)
		result.append(route)
	return result


static func _pick_template(
	route: Dictionary,
	region_index: Dictionary,
	region_for_port: Dictionary,
	definitions: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	if definitions.is_empty():
		return {}
	var kind_a := _region_kind_of(String(route.get("a", "")), region_index, region_for_port)
	var kind_b := _region_kind_of(String(route.get("b", "")), region_index, region_for_port)
	var candidates: Array = []
	for definition in definitions:
		var allowed: Array = Array((definition as ContentDefinition).data.get("region_kinds", []))
		if allowed.is_empty() or allowed.has(kind_a) or allowed.has(kind_b):
			candidates.append(definition)
	if candidates.is_empty():
		return {}
	var picked: ContentDefinition = candidates[rng.randi_range(0, candidates.size() - 1)]
	var data: Dictionary = picked.data
	return {
		"id": picked.id,
		"kind": String(data.get("kind", "sea_lane")),
		"distance_range": Array(data.get("distance_range", [])).duplicate(),
		"risk_range": Array(data.get("risk_range", [])).duplicate(),
		"travel_time_range": Array(data.get("travel_time_range", [])).duplicate(),
		"bidirectional": bool(data.get("bidirectional", true)),
		"encounter_table": String(data.get("encounter_table", "")),
	}


static func _region_kind_of(port_id: String, region_index: Dictionary, region_for_port: Dictionary) -> String:
	var region_id := String(region_for_port.get(port_id, ""))
	if region_id.is_empty():
		return ""
	var region: Variant = region_index.get(region_id, null)
	if not (region is Dictionary):
		return ""
	return String((region as Dictionary).get("kind", ""))
