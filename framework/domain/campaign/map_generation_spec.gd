class_name MapGenerationSpec
extends RefCounted
## @static-doc
## 作用：把 Content Schema 2.0 的 `world_profiles` / `map_configs` / `route_templates`
## 适配成 `MapGenerator.generate_spec()` 的输入字典，让 v2 战役复用 1.0 抽象海图生成器
## 而无需给生成器塞一个已退役的 map-profile 定义。
##
## ## 契约与约束
## - 输出键沿用历史生成字段：`port_count_range / archetypes /
##   port_name_keys / start_archetype_tags / required_facility_tags /
##   required_facility_max_edges / edge_count_range / distance_range / route_risk_range`，
##   因此 `MapGenerator` 的 `_build_graph` / `_try_generate` 逻辑与旧路径完全一致。
## - `port_count_range` 固定为 `[port_count, port_count]`（v2 的 world profile 是目标值，
##   不是区间）。D8：Phase B 首个切片孪生世界固定 5 陆地布局，`port_count` 超过
##   `MAX_PORTS_THIS_SLICE` 时 clamp 并 `push_warning`（B4 core 的 port_count 为 5）。
## - `edge_density` 存在时派生 `edge_count_range`：最小边 = 港口数（生成树 N-1 加一条
##   分叉边，保证"至少一个环"硬约束），最多再加 `round(density × 3)` 条；缺失时**不写**
##   该键，交由 `MapGenerator._build_graph` 的 1.0 默认逻辑 `[port_count, port_count+2]`。
## - `distance_range` / `route_risk_range` 聚合全部 active `route_templates` 的并集
##   （下界取最小、上界取最大）；没有可用模板时不写该键，沿用 1.0 默认值。
## - `start_archetype_tags`：`start_profile.starting_port_tags` 非空时优先（更具体的战役
##   起始港约束），否则用 `map_config.start_archetype_tags`。
## - 本适配器不读 GameState、不生成世界、不使用 RNG；纯内容 → 纯数据的映射。
## @end-static-doc

## Phase B 首个切片的可玩港口上限（孪生海图世界固定 5 陆地布局，见契约 D8）。
const MAX_PORTS_THIS_SLICE := 5
## `edge_density` = 1.0 时在最小边数之上追加的分叉边数量。
const EDGE_DENSITY_MAX_EXTRA := 3


## Builds the `MapGenerator.generate_spec()` input. `route_templates` may be in
## registry order: it is re-sorted by id before aggregation so the same seed and
## content yield the same bounds regardless of mod load order.
static func build(
	world_profile: ContentDefinition,
	map_config: ContentDefinition,
	route_templates: Array,
	start_profile: ContentDefinition = null
) -> Dictionary:
	var world_data: Dictionary = world_profile.data if world_profile != null else {}
	var config_data: Dictionary = map_config.data if map_config != null else {}
	var port_count := maxi(1, int(world_data.get("port_count", 5)))
	if port_count > MAX_PORTS_THIS_SLICE:
		push_warning(
			"campaign map spec: port_count %d exceeds the Phase B slice limit %d; clamped (D8)"
			% [port_count, MAX_PORTS_THIS_SLICE]
		)
		port_count = MAX_PORTS_THIS_SLICE

	var spec := {
		"port_count_range": [port_count, port_count],
		"archetypes": Array(config_data.get("archetypes", [])),
		"port_name_keys": Array(config_data.get("port_name_keys", [])),
		"required_facility_tags": Array(config_data.get("required_facility_tags", [])),
		"required_facility_max_edges": int(config_data.get("required_facility_max_edges", 2)),
	}

	var start_tags: Array = Array(config_data.get("start_archetype_tags", []))
	if start_profile != null:
		var profile_tags: Array = Array(start_profile.data.get("starting_port_tags", []))
		if not profile_tags.is_empty():
			start_tags = profile_tags
	spec["start_archetype_tags"] = start_tags

	var edge_range := _edge_count_range(port_count, world_data)
	if not edge_range.is_empty():
		spec["edge_count_range"] = edge_range

	var route_bounds := _aggregate_route_bounds(route_templates)
	if route_bounds.has("distance_range"):
		spec["distance_range"] = route_bounds["distance_range"]
	if route_bounds.has("route_risk_range"):
		spec["route_risk_range"] = route_bounds["route_risk_range"]
	return spec


## Derives the abstract map's edge budget from `world_profile.edge_density`.
## An empty array means "leave the key out and let MapGenerator use its 1.0
## default". A graph needs N-1 tree edges plus at least one extra edge (cycle).
static func _edge_count_range(port_count: int, world_data: Dictionary) -> Array:
	if not world_data.has("edge_density"):
		return []
	var density := clampf(float(world_data.get("edge_density", 1.0)), 0.0, 1.0)
	var minimum := maxi(port_count, 2)
	var maximum := minimum + int(round(density * float(EDGE_DENSITY_MAX_EXTRA)))
	return [minimum, maximum]


## Unions every active route template's distance / risk bounds so the abstract
## map can roll values any template can represent. Missing / malformed ranges are
## skipped; a completely empty result means the caller should use 1.0 defaults.
static func _aggregate_route_bounds(route_templates: Array) -> Dictionary:
	var sorted := CampaignAssembly.sorted_by_id(route_templates)
	var distance_min := INF
	var distance_max := -INF
	var risk_min := INF
	var risk_max := -INF
	for definition in sorted:
		if definition == null:
			continue
		var data: Dictionary = (definition as ContentDefinition).data
		var distance_range: Array = Array(data.get("distance_range", []))
		if distance_range.size() >= 2:
			distance_min = minf(distance_min, float(distance_range[0]))
			distance_max = maxf(distance_max, float(distance_range[1]))
		var risk_range: Array = Array(data.get("risk_range", []))
		if risk_range.size() >= 2:
			risk_min = minf(risk_min, float(risk_range[0]))
			risk_max = maxf(risk_max, float(risk_range[1]))
	var result := {}
	if distance_min != INF and distance_max != -INF:
		result["distance_range"] = [int(round(distance_min)), int(round(distance_max))]
	if risk_min != INF and risk_max != -INF:
		result["route_risk_range"] = [
			clampf(risk_min, 0.0, 1.0),
			clampf(risk_max, 0.0, 1.0),
		]
	return result
