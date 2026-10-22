class_name DiscoveryAssembler
extends RefCounted
## @static-doc
## 作用：v2 战役的图鉴装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 9）。按
## `weight / rarity / source_site_kinds / region_kinds / requires_tags` 为每个地点挂
## 发现候选（`site.discovery_ids`），并把候选对应的来源站点写进
## `campaign.codex.entries`（`{site_id, at_time:-1.0}` 表示「尚未发现」的候选来源）。
##
## ## 契约与约束
## - `campaign.codex` 形状保持 §6.3：`{discovered_ids: [], entries: {}}`。生成期
##   `discovered_ids` 恒为空；`entries` 预填候选 discovery → 来源站点（`at_time = -1.0`
##   是「未发现」哨兵），真正发现时由领域层写 `at_time` 并加入 `discovered_ids`。
## - 每个地点最多挂 `MAX_CANDIDATES_PER_SITE` 个候选；同一 discovery 可被多个地点引用时
##   `entries` 只保留第一个来源（其余仍出现在 site.discovery_ids）。
## - 过滤：`source_site_kinds` / `region_kinds` 非空时必须匹配；`requires_tags` 必须
##   同时满足**地点定义 tags ∪ 区域定义 tags**。候选为空的地点不挂 discovery_ids。
## - `weight` 与 `rarity` 共同决定候选权重（common 1.0 / uncommon 0.6 / rare 0.3 /
##   unique 0.1）；无可用候选时不抽取、不消耗随机数。
## - **确定性**：随机来自 `STREAM_CAMPAIGN_WORLD / "discoveries"` 子流；定义按 id 排序；
##   站点按数组顺序（即 `site_0..M-1`）遍历。
## @end-static-doc

const MAX_CANDIDATES_PER_SITE := 2
const RARITY_WEIGHTS := {
	"common": 1.0,
	"uncommon": 0.6,
	"rare": 0.3,
	"unique": 0.1,
}
## 未发现哨兵：生成期预填的 codex 候选来源还没有发现时间。
const UNDISCOVERED_AT_TIME := -1.0


## Attaches discovery candidates to sites and returns the initial codex block.
## `site_definitions_by_id` / `region_definitions_by_id` are lookup maps used for
## `requires_tags` evaluation only.
static func assemble(
	discovery_definitions: Array,
	sites: Array,
	regions: Array,
	site_definitions_by_id: Dictionary,
	region_definitions_by_id: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var definitions := CampaignAssembly.sorted_by_id(discovery_definitions)
	var region_index := CampaignAssembly.index_by_id(regions)
	var codex := {"discovered_ids": [], "entries": {}}
	if definitions.is_empty() or sites.is_empty():
		return {"sites": sites, "codex": codex}
	for raw_site in sites:
		var site: Dictionary = raw_site
		var eligible := _eligible_for_site(
			definitions, site, region_index, site_definitions_by_id, region_definitions_by_id
		)
		if eligible.is_empty():
			continue
		var weights := _weights_for(eligible)
		var candidate_ids: Array = []
		var picks := mini(MAX_CANDIDATES_PER_SITE, eligible.size())
		for _pick in picks:
			var definition: ContentDefinition = CampaignAssembly.pick_weighted(rng, eligible, weights)
			var index := eligible.find(definition)
			if index >= 0:
				eligible.remove_at(index)
				weights.remove_at(index)
			candidate_ids.append((definition as ContentDefinition).id)
			if not (codex["entries"] as Dictionary).has((definition as ContentDefinition).id):
				(codex["entries"] as Dictionary)[(definition as ContentDefinition).id] = {
					"site_id": String(site.get("id", "")),
					"at_time": UNDISCOVERED_AT_TIME,
				}
		site["discovery_ids"] = candidate_ids
	return {"sites": sites, "codex": codex}


static func _eligible_for_site(
	definitions: Array,
	site: Dictionary,
	region_index: Dictionary,
	site_definitions_by_id: Dictionary,
	region_definitions_by_id: Dictionary
) -> Array:
	var site_kind := String(site.get("kind", ""))
	var region_id := String(site.get("region_id", ""))
	var region: Variant = region_index.get(region_id, null)
	var region_kind := String((region as Dictionary).get("kind", "")) if region is Dictionary else ""
	var site_definition: ContentDefinition = site_definitions_by_id.get(String(site.get("definition_id", "")), null)
	var region_definition: ContentDefinition = region_definitions_by_id.get(region_id, null)
	var tags := {}
	if site_definition != null:
		for tag in site_definition.tags:
			tags[String(tag)] = true
	if region_definition != null:
		for tag in region_definition.tags:
			tags[String(tag)] = true

	var eligible: Array = []
	for definition in definitions:
		var data: Dictionary = (definition as ContentDefinition).data
		var site_kinds: Array = Array(data.get("source_site_kinds", []))
		if not site_kinds.is_empty() and not site_kinds.has(site_kind):
			continue
		var region_kinds: Array = Array(data.get("region_kinds", []))
		if not region_kinds.is_empty() and not region_kinds.has(region_kind):
			continue
		var requires_tags: Array = Array(data.get("requires_tags", []))
		var tags_ok := true
		for tag in requires_tags:
			if not tags.has(String(tag)):
				tags_ok = false
				break
		if not tags_ok:
			continue
		eligible.append(definition)
	return eligible


static func _weights_for(definitions: Array) -> Array:
	var weights: Array = []
	for definition in definitions:
		var data: Dictionary = (definition as ContentDefinition).data
		var rarity := float(RARITY_WEIGHTS.get(String(data.get("rarity", "common")), 1.0))
		weights.append(maxf(0.0001, float(data.get("weight", 1)) * rarity))
	return weights
