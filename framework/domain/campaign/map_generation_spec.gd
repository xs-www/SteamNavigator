class_name MapGenerationSpec
extends RefCounted
## @static-doc
## 作用：把 Content Schema 2.0 的 `world_profiles` / `map_configs` / `route_templates`
## 适配成世界生成的**内容蓝图**（港口数量 / 原型 / 名称 / 起始约束 / 风险范围）。
## 2026-10-26 起该蓝图喂给 `WorldGenerator.generate_chart`（海图即唯一世界），不再喂给
## 已退役的抽象拓扑生成器 `MapGenerator`。
##
## ## 契约与约束
## - 输出键沿用历史生成字段：`port_count_range / archetypes /
##   port_name_keys / start_archetype_tags / required_facility_tags /
##   required_facility_max_edges / distance_range / route_risk_range`；
##   `CampaignFactory._chart_world_profile` 再补上坐标布局（world size / landmasses /
##   port slots）后交给海图生成器。
## - **拓扑不在蓝图里**（2026-10-26「任意两港可通航 + 航线需解锁」）：可玩世界恒为完全图，
##   生成器不再读边预算，`world_profiles.edge_density` / `edge_count_range` 已退役。
## - `port_count_range` 固定为 `[port_count, port_count]`（v2 的 world profile 是目标值，
##   不是区间）。D8：当前海图布局固定 5 陆地（每陆 1 港），`port_count` 超过
##   `MAX_PORTS_THIS_SLICE` 时 clamp 并 `push_warning`（B4 core 的 port_count 为 5）。
## - `route_risk_range` 聚合全部 active `route_templates` 的 `risk_range` 并集（下界取
##   最小、上界取最大），海图生成器据此为每条边掷确定性 `base_risk`。`distance_range`
##   仍被聚合输出，但**不再影响世界**：海图距离由绘制路径几何决定（见
##   NAUTICAL_CHART_SYSTEM §4.1.1），该字段只作 route_template 元数据。
## - `start_archetype_tags`：`start_profile.starting_port_tags` 非空时优先（更具体的战役
##   起始港约束），否则用 `map_config.start_archetype_tags`。
## - 本适配器不读 GameState、不生成世界、不使用 RNG；纯内容 → 纯数据的映射。
## @end-static-doc

## Phase B 首个切片的可玩港口上限（海图世界固定 5 块陆地 × 每陆 1 港，见契约 D8）。
const MAX_PORTS_THIS_SLICE := 5


## Builds the content blueprint consumed by `CampaignFactory._chart_world_profile` →
## `WorldGenerator.generate_chart`. `route_templates` may be in registry order: it is
## re-sorted by id before aggregation so the same seed and content yield the same bounds
## regardless of mod load order.
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

	var route_bounds := _aggregate_route_bounds(route_templates)
	if route_bounds.has("distance_range"):
		spec["distance_range"] = route_bounds["distance_range"]
	if route_bounds.has("route_risk_range"):
		spec["route_risk_range"] = route_bounds["route_risk_range"]
	return spec


## Unions every active route template's distance / risk bounds so the chart can roll
## values any template can represent. Missing / malformed ranges are skipped; a
## completely empty result means the caller should use its own defaults.
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
