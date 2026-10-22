class_name SiteAssembler
extends RefCounted
## @static-doc
## 作用：v2 战役的地点装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 6）。每个区域按
## `world_profiles.sites_per_region` 生成地点实例，按 `weight` + `region_kinds` 过滤抽取
## `sites` 定义，写入实例 id / region / port / kind / loot / encounter 引用，并把
## `site_ids` 回填到所属区域。
##
## ## 契约与约束
## - 输出实例形状（写进 `campaign.world.sites[]`）：
##   `{id, definition_id, region_id, port_id, kind, discovered:false, repeatable,
##   loot_table, encounter_table}`；实例 id 为 `site_0..site_M-1`（跨区域连续编号）。
## - 每个区域**恰好** `sites_per_region` 个（本切片按任务契约的固定数量；内容侧的
##   `site_density` 留给后续切片在「区域地图」层细化）。
## - 候选过滤：`sites.region_kinds` 为空 = 任意区域；非空时必须含该区域 `kind`。
##   若区域类型把所有候选都过滤掉，退化为全量候选（内容缺失不静默失败），仍无候选
##   则跳过该区域。
## - `port_id`：区域内港口按 id 数值排序后轮转（`site_index % port_ids.size()`）；
##   区域没有港口时留空字符串。
## - **确定性**：随机来自 `STREAM_CAMPAIGN_WORLD / "sites"` 子流；定义数组按 id 排序；
##   每个地点一次加权 randf，抽取顺序固定（区域顺序 → 地点序号）。
## @end-static-doc


## Assembles site instances for every region. `regions` must already carry
## `port_ids` + `site_ids` (RegionAssembler output) and is mutated in place for
## the `site_ids` back-reference; the returned array is the canonical list.
static func assemble(
	world_profile: ContentDefinition,
	regions: Array,
	site_definitions: Array,
	rng: RandomNumberGenerator
) -> Array:
	var definitions := CampaignAssembly.sorted_by_id(site_definitions)
	if definitions.is_empty() or regions.is_empty():
		return []
	var world_data: Dictionary = world_profile.data if world_profile != null else {}
	var sites_per_region := maxi(0, int(world_data.get("sites_per_region", 0)))
	if sites_per_region == 0:
		return []

	var sites: Array = []
	for region in regions:
		var region_entry: Dictionary = region
		var region_kind := String(region_entry.get("kind", "coastal"))
		var candidates := _candidates_for_region(definitions, region_kind)
		var weights := _weights_for(candidates)
		var port_ids: Array = Array(region_entry.get("port_ids", [])).duplicate()
		port_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
			return String(left).trim_prefix("port_").to_int() < String(right).trim_prefix("port_").to_int()
		)
		for site_index in sites_per_region:
			if candidates.is_empty():
				break
			var definition: ContentDefinition = CampaignAssembly.pick_weighted(rng, candidates, weights)
			var data: Dictionary = definition.data
			var site_id := "site_%d" % sites.size()
			var port_id := ""
			if not port_ids.is_empty():
				port_id = String(port_ids[site_index % port_ids.size()])
			sites.append({
				"id": site_id,
				"definition_id": definition.id,
				"region_id": String(region_entry.get("id", "")),
				"port_id": port_id,
				"kind": String(data.get("site_kind", "ruin")),
				"discovered": false,
				"repeatable": bool(data.get("repeatable", false)),
				"loot_table": String(data.get("loot_table", "")),
				"encounter_table": String(data.get("encounter_table", "")),
			})
			(region_entry["site_ids"] as Array).append(site_id)
	return sites


static func _candidates_for_region(definitions: Array, region_kind: String) -> Array:
	var candidates: Array = []
	for definition in definitions:
		var allowed: Array = Array((definition as ContentDefinition).data.get("region_kinds", []))
		if allowed.is_empty() or allowed.has(region_kind):
			candidates.append(definition)
	return candidates if not candidates.is_empty() else definitions.duplicate()


static func _weights_for(definitions: Array) -> Array:
	var weights: Array = []
	for definition in definitions:
		weights.append(maxf(0.0001, float((definition as ContentDefinition).data.get("weight", 1))))
	return weights
