class_name FactionAssembler
extends RefCounted
## @static-doc
## 作用：v2 战役的阵营装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 8）。按
## `world_profiles.faction_count` 从 active `factions` 定义中实例化 ≤N 个阵营，写
## `campaign.factions`：初始声望 = `start_profiles.starting_reputation` +
## `factions.starting_reputation`，`attitude` 由 `attitude_thresholds` 派生。
##
## ## 契约与约束
## - 输出形状（每个 faction id 一项，与 `GameState.FACTION_ENTRY_DEFAULTS` 一致）：
##   `{reputation, attitude, discovered:false, met_at:0.0}`。
## - `reputation` clamp 到 [-100, 100]；`attitude`：`reputation < hostile_below` →
##   `"hostile"`；`reputation >= friendly_at` → `"friendly"`；否则 `"neutral"`。
##   （阈值来自内容；缺失时用 -30 / 30 的防御兜底，不写死在框架数值里参与调参。）
## - 定义数量 > faction_count 时用确定性无放回抽样；≤ 时按 id 顺序全取。
## - **确定性**：随机来自 `STREAM_CAMPAIGN_WORLD / "factions"` 子流；定义按 id 排序。
## - 1.0 旧档不经过本装配器；`ensure_campaign_sections()` 会给旧条目惰性补齐字段。
## @end-static-doc

const DEFAULT_HOSTILE_BELOW := -30
const DEFAULT_FRIENDLY_AT := 30


## Builds `campaign.factions` for a v2 campaign. `world_profile` supplies
## `faction_count`; `start_profile` supplies the base reputation.
static func assemble(
	world_profile: ContentDefinition,
	start_profile: ContentDefinition,
	faction_definitions: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	var definitions := CampaignAssembly.sorted_by_id(faction_definitions)
	if definitions.is_empty():
		return {}
	var world_data: Dictionary = world_profile.data if world_profile != null else {}
	var faction_count := maxi(0, int(world_data.get("faction_count", definitions.size())))
	var chosen: Array = []
	if faction_count >= definitions.size():
		chosen = definitions.duplicate()
	else:
		chosen = CampaignAssembly.sample_distinct(rng, definitions, faction_count)

	var base_reputation := 0
	if start_profile != null:
		base_reputation = int(start_profile.data.get("starting_reputation", 0))

	var factions := {}
	for definition in chosen:
		var data: Dictionary = (definition as ContentDefinition).data
		var reputation := clampi(base_reputation + int(data.get("starting_reputation", 0)), -100, 100)
		factions[(definition as ContentDefinition).id] = {
			"reputation": reputation,
			"attitude": attitude_for(reputation, data.get("attitude_thresholds", {})),
			"discovered": false,
			"met_at": 0.0,
		}
	return factions


## Maps a reputation value to the content-defined attitude band.
static func attitude_for(reputation: int, raw_thresholds: Variant) -> String:
	var thresholds: Dictionary = raw_thresholds if raw_thresholds is Dictionary else {}
	var hostile_below := int(thresholds.get("hostile_below", DEFAULT_HOSTILE_BELOW))
	var friendly_at := int(thresholds.get("friendly_at", DEFAULT_FRIENDLY_AT))
	if reputation < hostile_below:
		return "hostile"
	if reputation >= friendly_at:
		return "friendly"
	return "neutral"
