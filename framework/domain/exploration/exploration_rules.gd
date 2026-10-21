class_name ExplorationRules
extends RefCounted
## @static-doc
## 作用：读取并合并探索系统规则（`map_profiles` 定义的 `data.exploration`），
## 把 Core JSON 的数值与框架兜底常量统一成一份纯数据字典，供线索、探索预览、结算与
## 战争迷雾半径共享。
##
## - 关键依赖：`ContentTypes.MAP_PROFILE`、`GameState.world()`、`RegistryHub`、`WorldMap`
##
## ## 契约与约束
## - 规则只来自当前 `map_profile_id` 对应 `map_profiles` 定义的 `data.exploration`；
##   框架不写死可调数值。`DEFAULTS` 只用于旧存档 / 内容缺字段的**防御兜底**，不参与调参；
##   正常内容（core 的 `standard` profile）必须覆盖全部键。
## - 合并只覆盖 `DEFAULTS` 里已知的键，未知键被忽略；`level_weights` /
##   `credibility_range` 这类两级结构逐来源子键合并，缺一个来源不影响另一个。
## - 读取无副作用、不缓存：注册表冻结后内容不变，重复读取开销可忽略。
## - `discovery_chance` / `roll_succeeds` 是规则数学的单一真源：线索服务、探索预览与
##   结算都调用这里，避免「展示概率」和「实际判定」用两套公式。
## - `fog_radii()` 是雾半径的单一真源：`radius = min(world.w, world.h) * ratio`
##   （阶段 4.3 起比例来自 Core，不再用固定世界单位）；世界缺失时退回 400 单位的
##   历史默认世界，保证旧存档 / 测试夹具仍有确定的雾。
## @end-static-doc

## 防御兜底：数值与 `docs/design/EXPLORATION_SYSTEM.md` §3 的契约示例一致。
## 仅当当前 map profile 缺 `exploration` 块或该键时使用；正常核心内容会整块覆盖。
const DEFAULTS := {
	"rumor_clue_chance": 0.65,
	# 战争迷雾半径比例（相对世界 bound 的短边）。0.05 在 160 世界下 = 8 单位，
	# 泊位揭示直径 16 = 世界的 10%（§10.3 验收口径）。
	"fog_port_reveal_ratio": 0.05,
	"fog_vision_ratio": 0.05,
	"intel_clue_cost": 40,
	"max_active_clues": 4,
	"level_weights": {
		"rumor": [0.55, 0.35, 0.10, 0.00],
		"intel": [0.00, 0.15, 0.45, 0.40],
	},
	"credibility_range": {
		"rumor": [0.25, 0.55],
		"intel": [0.60, 0.95],
	},
	"distance_error_ratio": 0.35,
	"search_zone_radius": 14.0,
	"search_zone_noise": 12.0,
	"discovery_chance_base": 0.20,
	"discovery_chance_per_credibility": 0.70,
	"risk_base": 0.08,
	"risk_per_unreliability": 0.12,
	"drift_durability_loss": 8.0,
	"drift_extra_coal": 4.0,
	"drift_extra_water": 4.0,
	"drift_hours": 6.0,
	"alert_threshold": 0.5,
	"alert_progress": 0.5,
	"turnback_extra_ratio": 0.25,
}


## Returns the merged exploration rule dictionary for the current run's map profile.
static func read(state: GameState, hub: RegistryHub) -> Dictionary:
	var rules: Dictionary = DEFAULTS.duplicate(true)
	if state == null:
		return rules
	var profile_id := String(state.world().get("map_profile_id", ""))
	if profile_id.is_empty() or hub == null:
		return rules
	var profile: ContentDefinition = hub.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	if profile == null:
		return rules
	var raw: Variant = profile.data.get("exploration", null)
	if not (raw is Dictionary):
		return rules
	_merge(rules, raw as Dictionary)
	return rules


## 迷雾半径（世界单位）：`min(bounds.w, bounds.h) * ratio`。返回值同时给
## `sea_chart.view`（UI 画布）与领域抵达 / 航线持久化使用，避免两边各算一套。
static func fog_radii(state: GameState, hub: RegistryHub, world: WorldMap = null) -> Dictionary:
	var rules := read(state, hub)
	var world_side := 400.0
	if world != null and not world.is_empty():
		world_side = minf(world.bounds.size.x, world.bounds.size.y)
	var vision_ratio := clampf(float(rules.get("fog_vision_ratio", DEFAULTS["fog_vision_ratio"])), 0.01, 0.5)
	var reveal_ratio := clampf(float(rules.get("fog_port_reveal_ratio", DEFAULTS["fog_port_reveal_ratio"])), 0.01, 0.5)
	return {
		"vision": maxf(1.0, world_side * vision_ratio),
		"port_reveal": maxf(1.0, world_side * reveal_ratio),
	}


## Display/rule probability of discovering the target harbour for a given credibility.
## `discovery_chance_base + discovery_chance_per_credibility * credibility`, clamped.
static func discovery_chance(rules: Dictionary, credibility: float) -> float:
	var base := float(rules.get("discovery_chance_base", DEFAULTS["discovery_chance_base"]))
	var per := float(rules.get("discovery_chance_per_credibility", DEFAULTS["discovery_chance_per_credibility"]))
	return clampf(base + per * credibility, 0.0, 1.0)


## Single source of the "< chance" probability rule. Consumes exactly one `randf()`.
static func roll_succeeds(rng: RandomNumberGenerator, chance: float) -> bool:
	if rng == null:
		return false
	return rng.randf() < clampf(chance, 0.0, 1.0)


## Two-level merge: only keys that exist in `DEFAULTS` are accepted, nested dictionaries
## merge sub-key by sub-key, every other value replaces the fallback.
static func _merge(target: Dictionary, source: Dictionary) -> void:
	for raw_key in source.keys():
		var key := String(raw_key)
		if not target.has(key):
			continue
		var incoming: Variant = source[raw_key]
		var current: Variant = target[key]
		if current is Dictionary and incoming is Dictionary:
			for sub_key in (incoming as Dictionary).keys():
				if (current as Dictionary).has(sub_key):
					(current as Dictionary)[sub_key] = (incoming as Dictionary)[sub_key]
			continue
		target[key] = incoming
