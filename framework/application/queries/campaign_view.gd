class_name CampaignViewQuery
extends RefCounted
## @static-doc
## 作用：v2 战役运行时快照查询（`campaign.view`，Phase B B3）。只读地输出
## `setup / regions / sites / factions / codex / exploration` 六块，供 UI 与测试读取
## 当前战役身份、世界装配结果与探索进度；1.0 旧档返回同一形状的空默认块。
##
## - 关键依赖：`GameState.campaign_setup()` / `campaign_world()` / `campaign_codex()` /
##   `campaign_factions()`、`ExplorationRules.read()`、`GameState.clues()`、
##   `ContentRefs.is_v2_campaign()`
##
## ## 契约与约束
## - 只读：不写状态、不发事件、不调用 ensure 以外的变更路径。
## - 形状稳定：无 run 或 1.0 旧档也返回六个键；`regions/sites` 为 Array，
##   `setup/factions/codex/exploration` 为 Dictionary，不因档版本缺键。
## - 内容定义不进入快照：只输出实例 id / 数值 / 进度；`exploration.rules` 是
##   `ExplorationRules.read()` 合并后的纯数值字典。
## - `factions` 按 faction id 输出 `{reputation, attitude, discovered, met_at}`；
##   旧档条目经 `GameState` 的逐键惰性回填后同样齐全。
## - 1.0 兼容：`campaign.setup` 全空、`regions/sites` 为空数组、`is_v2=false`，
##   不重排 / 不重新生成世界。
## @end-static-doc


static func execute(_params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.ok(_empty())
	var world := state.campaign_world()
	var factions: Dictionary = state.campaign_factions().duplicate(true)
	for faction_id in factions.keys():
		var entry: Variant = factions[faction_id]
		if not (entry is Dictionary):
			entry = GameState.FACTION_ENTRY_DEFAULTS.duplicate(true)
			factions[faction_id] = entry
		var defaults: Dictionary = GameState.FACTION_ENTRY_DEFAULTS
		for key in defaults.keys():
			if not (entry as Dictionary).has(key):
				(entry as Dictionary)[key] = _copy_default(defaults[key])
	return Result.ok({
		"has_run": true,
		"is_v2": ContentRefs.is_v2_campaign(state),
		"setup": state.campaign_setup().duplicate(true),
		"regions": Array(world.get("regions", [])).duplicate(true),
		"sites": Array(world.get("sites", [])).duplicate(true),
		"factions": factions,
		"codex": state.campaign_codex().duplicate(true),
		"exploration": {
			"rules": ExplorationRules.read(state, context.registries),
			"clues": state.clues().duplicate(true),
		},
	})


## Shape-stable fallback: same six blocks with empty/default values.
static func _empty() -> Dictionary:
	return {
		"has_run": false,
		"is_v2": false,
		"setup": GameState.CAMPAIGN_SECTION_DEFAULTS["setup"].duplicate(true),
		"regions": [],
		"sites": [],
		"factions": {},
		"codex": {
			"discovered_ids": [],
			"entries": {},
		},
		"exploration": {
			"rules": ExplorationRules.DEFAULTS.duplicate(true),
			"clues": GameState.CLUES_DEFAULTS.duplicate(true),
		},
	}


static func _copy_default(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
