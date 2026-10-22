class_name RegionAssembler
extends RefCounted
## @static-doc
## 作用：v2 战役的区域装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 5）。按
## `world_profiles.region_count` 生成区域实例，起始区域由 `start_region_tags` 匹配，
## 其余按 `kind / size` 权重抽取；每个抽象港口归属一个 `region_id`，区域天气取
## `regions.weather_profile`（缺失时回退 `world_profiles.weather_profile`）。
##
## ## 契约与约束
## - 输出实例形状（写进 `campaign.world.regions[]`）：
##   `{id, definition_id, kind, size, weather_profile, port_ids, site_ids}`。
##   实例 id 为 `region_0..region_N-1`，`region_0` 固定是起始区域。
## - 起始区域 = 按 id 排序后第一个 `has_all_tags(start_region_tags)` 的区域定义；
##   没有匹配时不失败（内容问题留给 Completeness 校验），退化为排序后的第一个定义。
## - 区域定义数量 < `region_count` 时允许重复实例化同一原型（每个实例仍是独立 id）。
## - 港口归属：`port_0`（起始港）固定归 `region_0`；其余港口按各区域的
##   `port_density` 加权抽取。权重为 0 的区域仍保留极小权重 0.01，避免"有区域没港口"。
## - **确定性**：所有随机来自调用方传入的 `STREAM_CAMPAIGN_WORLD / "regions"` 子流；
##   定义数组先按 id 排序，港口按 id 数值排序。抽取序列固定（每个区域一次 randf，
##   每个非起始港口一次 randf）。
## @end-static-doc

## 区域 proto 的 `kind` 权重：越适合生成内容的海域越容易被抽中。
const KIND_WEIGHTS := {
	"coastal": 1.0,
	"archipelago": 1.0,
	"open_sea": 1.2,
	"industrial": 0.9,
	"frontier": 0.8,
}
## `size` 权重：大区域承担更多港口 / 地点。
const SIZE_WEIGHTS := {
	"small": 1.0,
	"medium": 1.5,
	"large": 2.0,
}
const MIN_PORT_DENSITY_WEIGHT := 0.01


## Assembles region instances for one campaign.
## `world` is the MapGenerator world (only `ports` is read).
## Returns `{regions: Array, region_for_port: Dictionary}`.
static func assemble(
	world_profile: ContentDefinition,
	world: Dictionary,
	region_definitions: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	var definitions := CampaignAssembly.sorted_by_id(region_definitions)
	if definitions.is_empty():
		return {"regions": [], "region_for_port": {}}
	var world_data: Dictionary = world_profile.data if world_profile != null else {}
	var region_count := maxi(1, int(world_data.get("region_count", 5)))
	var fallback_weather := String(world_data.get("weather_profile", ""))
	var start_tags: Array = Array(world_data.get("start_region_tags", []))
	var start_definition := _find_start_definition(definitions, start_tags)

	var regions: Array = []
	var region_definitions_by_index: Array = []
	for index in region_count:
		var definition: ContentDefinition = start_definition if index == 0 else _pick_region_definition(definitions, rng)
		region_definitions_by_index.append(definition)
		var data: Dictionary = definition.data
		regions.append({
			"id": "region_%d" % index,
			"definition_id": definition.id,
			"kind": String(data.get("kind", "coastal")),
			"size": String(data.get("size", "medium")),
			"weather_profile": String(data.get("weather_profile", fallback_weather)),
			"port_ids": [],
			"site_ids": [],
		})

	var region_for_port := _assign_ports(regions, region_definitions_by_index, world, rng)
	return {"regions": regions, "region_for_port": region_for_port}


static func _find_start_definition(definitions: Array, start_tags: Array) -> ContentDefinition:
	if not start_tags.is_empty():
		for definition in definitions:
			if (definition as ContentDefinition).has_all_tags(start_tags):
				return definition
	return definitions[0]


static func _pick_region_definition(definitions: Array, rng: RandomNumberGenerator) -> ContentDefinition:
	var weights: Array = []
	for definition in definitions:
		var data: Dictionary = (definition as ContentDefinition).data
		var kind_weight := float(KIND_WEIGHTS.get(String(data.get("kind", "coastal")), 1.0))
		var size_weight := float(SIZE_WEIGHTS.get(String(data.get("size", "medium")), 1.0))
		weights.append(maxf(0.0001, kind_weight * size_weight))
	return CampaignAssembly.pick_weighted(rng, definitions, weights)


## Assigns every abstract port to exactly one region instance. The starting
## harbour anchors `region_0`; the rest are distributed by `port_density`.
static func _assign_ports(
	regions: Array,
	region_definitions_by_index: Array,
	world: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var region_for_port := {}
	var ports: Dictionary = world.get("ports", {})
	var port_ids: Array = ports.keys()
	port_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		return String(left).trim_prefix("port_").to_int() < String(right).trim_prefix("port_").to_int()
	)
	if port_ids.is_empty() or regions.is_empty():
		return region_for_port
	var first_port := String(port_ids[0])
	(regions[0] as Dictionary)["port_ids"].append(first_port)
	region_for_port[first_port] = String((regions[0] as Dictionary)["id"])

	var weights: Array = []
	for definition in region_definitions_by_index:
		var density := float((definition as ContentDefinition).data.get("port_density", 0.5))
		weights.append(maxf(MIN_PORT_DENSITY_WEIGHT, density))
	for index in range(1, port_ids.size()):
		var region: Dictionary = CampaignAssembly.pick_weighted(rng, regions, weights)
		var port_id := String(port_ids[index])
		region["port_ids"].append(port_id)
		region_for_port[port_id] = String(region["id"])
	return region_for_port
