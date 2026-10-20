class_name VoyageEstimator
extends RefCounted
## @static-doc
## 作用：把「一条航线 + 当前船况 + 锅炉策略 + 航行规则」折算成海图右侧面板需要的
## 预计航程数据（耗时、煤水消耗、风险档位）。它是 `VoyageCalculator` 的只读投影，
## 不写状态、不改存档，也不做可行性判定。
##
## ## 契约与约束
## - **公式必须与 `VoyageCalculator.preview` 一致**：航速 = 船速 × 策略 `speed_mul` ×
##   载重系数；`duration = distance / speed`；煤 = `duration × coal_rate × coal_mul`；
##   水 = `duration × (water_rate × water_mul + 乘客数 × 0.06)`。这些常量直接引用
##   `VoyageCalculator`，不复制一份，避免海图与出航预览给出两个数字。
## - **风险**：`base_risk` 只存在于抽象地图航线（`MapGenerator` 写入），坐标世界
##   `WorldMap.edges` 只存几何量；没有可用的基础风险时返回 `risk_level = -1`
##   （面板显示「无法评估」），绝不把 0 当成「无风险」。
## - `travel_hours` 与方向无关；煤水按**出发港**的船上补给计算，所以 `supplies` 只对
##   「从当前港出发」的航线有直接意义，`sea_chart.view` 负责把这条语义解释给 UI
##   （目的地面板只在选中港是邻居时才展示补给块）。
## @end-static-doc

## 补给低于 LOW_SUPPLY_RATIO 时 `supplies.low` 为 true（面板给一次提示，仍允许出航：
## 真正阻断由 `voyage.preview` 的 blockers 负责）。
const LOW_SUPPLY_RATIO := 0.5


## `estimate` 由查询层组装（船况、策略表、载重比、乘客数、当前港），
## 这里只做与领域规则一一对应的算术。
##
## 返回字段（全部可直接进 ViewModel / JSON）：
## `distance` 海图距离 · `voyage_distance` 用于算时间的距离 · `travel_hours` ·
## `arrival_hours`（相对当前游戏时间）· `speed` 有效航速 · `risk_level`（0–1，-1 未知）·
## `risk_label`（low/medium/high 或 unknown）· `risk_source`（voyage = 有基础风险，none = 未知）·
## `supplies`（煤水需求/存量/余量/是否足够）· `strategy_id` / `strategy_name_key`。
static func estimate(
	context: Dictionary,
	distance: float,
	voyage_distance: float,
	base_risk: float,
	strategy: ContentDefinition
) -> Dictionary:
	var stats: Dictionary = context.get("stats", {})
	if stats.is_empty():
		return {}
	var strategy_data: Dictionary = strategy.data if strategy != null else {}
	var strategy_speed := float(strategy_data.get("speed_mul", 1.0))
	var strategy_coal := float(strategy_data.get("coal_mul", 1.0))
	var strategy_water := float(strategy_data.get("water_mul", 1.0))
	var strategy_risk := float(strategy_data.get("risk_add", 0.0))
	var load_ratio := float(context.get("load_ratio", 0.0))
	var weight_factor := VoyageCalculator.weight_speed_factor(load_ratio)
	var speed := maxf(0.1, float(stats.get("speed", 1.0)) * strategy_speed * weight_factor)
	var duration := maxf(0.0, voyage_distance) / speed
	var ship: Dictionary = context.get("ship", {})
	var coal_required := duration * float(stats.get("coal_rate", 0.0)) * strategy_coal
	var water_required := duration * (
		float(stats.get("water_rate", 0.0)) * strategy_water
		+ float(context.get("passengers", 0)) * VoyageCalculator.PASSENGER_WATER_RATE
	)
	var coal_available := float(ship.get("coal", 0.0))
	var water_available := float(ship.get("water", 0.0))
	var game_time := float(context.get("game_time", 0.0))
	# Equipment/crew risk is `ShipOps.stats().risk_add` minus the hull's own base
	# risk (the hull is folded into the ship, not into the route).
	var equipment_risk := float(stats.get("risk_add", 0.0)) - float(context.get("hull_base_risk", 0.0))
	# Risk mirrors `VoyageCalculator._risk_breakdown` source for source: route base
	# risk + strategy + overload + low durability + equipment/crew, clamped to the
	# same band the preview clamps to, so the chart never advertises a different
	# risk than the voyage page for the same voyage.
	var risk := {}
	if base_risk >= 0.0:
		var overload := maxf(0.0, load_ratio - 0.75) * 0.08
		var low_durability := 0.0
		var maximum_durability := float(stats.get("max_durability", 0.0))
		if maximum_durability > 0.0 and float(ship.get("durability", 0.0)) / maximum_durability < 0.35:
			low_durability = 0.06
		var score := clampf(
			base_risk + strategy_risk + overload + low_durability + equipment_risk,
			0.01,
			0.7
		)
		risk = {
			"risk_level": score,
			"risk_label": VoyageCalculator.risk_label(score),
			"risk_source": "voyage",
		}
	else:
		risk = {"risk_level": -1.0, "risk_label": "unknown", "risk_source": "none"}
	return {
		"distance": distance,
		"voyage_distance": voyage_distance,
		"travel_hours": duration,
		"arrival_hours": game_time + duration,
		"speed": speed,
		"weight_factor": weight_factor,
		"strategy_id": strategy.id if strategy != null else "",
		"strategy_name_key": strategy.name_key if strategy != null else "",
		"supplies": {
			"coal_required": coal_required,
			"coal_available": coal_available,
			"coal_surplus": coal_available - coal_required,
			"water_required": water_required,
			"water_available": water_available,
			"water_surplus": water_available - water_required,
			"sufficient": coal_available + 0.0001 >= coal_required
				and water_available + 0.0001 >= water_required,
			"low": coal_available + 0.0001 < coal_required / LOW_SUPPLY_RATIO
				or water_available + 0.0001 < water_required / LOW_SUPPLY_RATIO,
		},
	}.merged(risk)
