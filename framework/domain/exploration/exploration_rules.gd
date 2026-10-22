class_name ExplorationRules
extends RefCounted
## @static-doc
## 作用：读取并合并探索系统规则（`map_configs` 定义的
## `data.exploration`），把 Core JSON 的数值与框架兜底常量统一成一份纯数据字典，供
## 线索、探索预览、结算与战争迷雾半径共享。
##
## - 关键依赖：`ContentRefs.map_config_data()`、`GameState.world()`、`RegistryHub`、`WorldMap`
##
## ## 契约与约束
## - 规则只来自当前场景定义（`ContentRefs` 解析：v2 `map_configs` 优先，旧档
##   `data.exploration`；框架不写死可调数值。`DEFAULTS` 只用于
##   旧存档 / 内容缺字段的**防御兜底**，不参与调参；正常内容必须覆盖全部键。
## - 合并只覆盖 `DEFAULTS` 里已知的键，未知键被忽略；`level_weights` /
##   `credibility_range` 这类两级结构逐来源子键合并，缺一个来源不影响另一个。
## - 读取无副作用、不缓存：注册表冻结后内容不变，重复读取开销可忽略。
## - `discovery_chance` / `roll_succeeds` 是规则数学的单一真源：线索服务、探索预览与
##   结算都调用这里，避免「展示概率」和「实际判定」用两套公式。
## - `fog_radii()` 是雾半径的单一真源：`radius = min(world.w, world.h) * ratio`
##   （阶段 4.3 起比例来自 Core，不再用固定世界单位）；世界缺失时退回 400 单位的
##   历史默认世界，保证旧存档 / 测试夹具仍有确定的雾。
## - 4.4 起同一份规则还承载货物行情线索的时效（`goods_clue_expiry_hours`）、报价误差
##   （`goods_clue_price_error_ratio`）、等待 / 委托解锁概率（`wait_clue_*` /
##   `contract_clue_chance`）与 4.4.3 的调查成功率（`investigation_success_chance`），
##   线索 / 查询 / UI 都只读这一份，不在框架里写死数字。
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
	# 4.3.2 起线索获得固定 1 级，`level_weights` 不再参与获得等级；保留在内容 / schema /
	# DEFAULTS 中，留给后续线索系统迭代（内容兼容，不要删除）。
	"level_weights": {
		"rumor": [0.55, 0.35, 0.10, 0.00],
		"intel": [0.00, 0.15, 0.45, 0.40],
	},
	"credibility_range": {
		"rumor": [0.25, 0.55],
		"intel": [0.60, 0.95],
		# 4.4.2 新来源：码头消息 / 委托报酬介于两者之间。
		"wait": [0.40, 0.70],
		"contract": [0.55, 0.85],
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
	# 4.3.2 / U2：线索调查的预留消耗（4.3 恒为 0，不做资源判定、不扣钱、不推进时间）。
	# 4.4.3 起由 Core 填入真实数值（金币 / 在港小时 / 成功率）；0 / 0 / 1.0 表示保持 4.3 行为。
	"investigation_cost": 0,
	"investigation_hours": 0.0,
	"investigation_success_chance": 1.0,
	# 4.4：货物行情线索。行情在获得时冻结，按来源的有限时效（游戏小时）到期；
	# 价格区间误差 = price_error_ratio × (1 - credibility)。
	"goods_clue_expiry_hours": {
		"rumor": 24.0,
		"intel": 72.0,
		"wait": 48.0,
		"contract": 72.0,
	},
	"goods_clue_price_error_ratio": 0.15,
	# 来源是否出货物线索（0 = 只出港口位置线索）；等待默认出行情、委托默认出港口。
	"goods_clue_source_weights": {
		"rumor": 0.0,
		"intel": 0.0,
		"wait": 1.0,
		"contract": 0.0,
	},
	# 4.4.2：在港等待解锁线索——每 `wait_clue_hours_block` 小时一档，按档位复利，
	# 概率封顶 `wait_clue_max_chance`；完成委托按 `contract_clue_chance` 抽取。
	"wait_clue_hours_block": 6.0,
	"wait_clue_chance_per_block": 0.35,
	"wait_clue_max_chance": 0.85,
	"contract_clue_chance": 0.5,
}


## Returns the merged exploration rule dictionary for the current run's
## scenario definition (`map_configs`; `map_profiles` retired in C4)
## fallback handled by `ContentRefs`).
static func read(state: GameState, hub: RegistryHub) -> Dictionary:
	var rules: Dictionary = DEFAULTS.duplicate(true)
	if state == null:
		return rules
	var data := ContentRefs.map_config_data(state, hub)
	if data.is_empty():
		return rules
	var raw: Variant = data.get("exploration", null)
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
	return roll_hits(rng.randf(), chance)


## Same rule for callers that need the roll value itself (investigation returns it for
## deterministic tests): success iff `roll < chance`, chance clamped to 0..1.
static func roll_hits(roll: float, chance: float) -> bool:
	return roll < clampf(chance, 0.0, 1.0)


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
