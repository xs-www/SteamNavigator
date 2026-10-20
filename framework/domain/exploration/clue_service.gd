class_name ClueService
extends RefCounted
## @static-doc
## 作用：港口位置线索的领域服务——生成（抵达传闻 / 酒馆购买）、按等级裁剪的只读视图、
## 线索生命周期（active → resolved / failed）以及发现概率的规则计算。
##
## - 关键依赖：`GameState.data.clues`（惰性 ensure）、`WorldOps`、`MapOps`、
##   `ExplorationRules`、`ShipOps`、`VoyageCalculator`、`RngService.STREAM_EXPLORATION`
##
## ## 契约与约束
## - 线索是纯数据，全部可 JSON 化；旧存档没有 `data.clues` 时由 `GameState.ensure_clues()`
##   补齐，不改 `schema_version`。
## - 目标只能是坐标世界里**未发现**、且没有被其它活跃线索指向的港口；没有目标时
##   `acquire` 返回 `{}`（不报错）。测试 / 确定性入口可以显式给 `target_port_id` 跳过筛选，
##   但仍然必须存在于坐标世界。
## - 随机全部走命名流 `RngService.STREAM_EXPLORATION`，key 规则见
##   `docs/design/EXPLORATION_SYSTEM.md` §4：传闻 `rumor:<port>:<time>`、
##   购买 `intel:<port>:<time>`。同 seed + 同状态必须复现。
## - 查询视图裁剪：`level < 4` 不含 `name_key`、`level < 3` 不含 `circle`；**任何等级**
##   都不输出 `target_port_id`、`credibility` 与 `search_zone` 中心误差来源。
##   等级 1 不披露方向（`direction_angle` 固定 0），2 级披露方向，3/4 级再加圆圈。
## - `on_arrival` / `buy` 永远不阻断抵达 / 出航流程：抽不到线索时只返回空结果。
## - 线索不会被删除：失效进 `failed`，发现进 `resolved`，两者都保留 id 供 UI 提示。
## @end-static-doc

const SOURCE_RUMOR := "rumor"
const SOURCE_INTEL := "intel"
const SOURCES := [SOURCE_RUMOR, SOURCE_INTEL]
## 视图中「距离区间」始终输出（契约 §5 的字段表），但方向只在 level >= 2 时有效。
const DIRECTION_MIN_LEVEL := 2
const CIRCLE_MIN_LEVEL := 3
const NAME_MIN_LEVEL := 4


## Returns the lazily-created `data.clues` block.
static func clues(state: GameState) -> Dictionary:
	return state.ensure_clues()


## Active clue dictionaries (mutable references into GameState).
static func active(state: GameState) -> Array:
	return state.ensure_clues().get("active", [])


static func find_clue(state: GameState, clue_id: String) -> Dictionary:
	if clue_id.is_empty():
		return {}
	for clue in active(state):
		if clue is Dictionary and String((clue as Dictionary).get("id", "")) == clue_id:
			return clue
	return {}


## Undiscovered coordinate-world ports not already referenced by an active clue.
## Returned in world declaration order so callers stay deterministic.
static func eligible_target_ids(state: GameState) -> Array[String]:
	var result: Array[String] = []
	var world := WorldOps.world_map(state)
	if world.is_empty():
		return result
	var discovered: Array = state.campaign_world().get("discovered_port_ids", [])
	var referenced := {}
	for clue in active(state):
		if clue is Dictionary:
			referenced[String((clue as Dictionary).get("target_port_id", ""))] = true
	for port in world.ports:
		if discovered.has(port.id) or referenced.has(port.id):
			continue
		result.append(port.id)
	return result


## Arrival hook: roll a tavern rumour from the named exploration stream.
## Returns `{}` when the roll fails, the clue cap is reached or no target exists.
## On success returns `{clue, events}` so the caller can append `clue.acquired`.
static func on_arrival(context) -> Dictionary:
	var state: GameState = context.state
	if state.explore_voyage() is Dictionary:
		return {}
	var rules := ExplorationRules.read(state, context.registries)
	if active(state).size() >= int(rules.get("max_active_clues", 4)):
		return {}
	var port_id := state.current_port_id()
	var time := state.now()
	var rng: RandomNumberGenerator = context.rng.stream(
		RngService.STREAM_EXPLORATION,
		"rumor:%s:%.3f" % [port_id, time]
	)
	if not ExplorationRules.roll_succeeds(rng, float(rules.get("rumor_clue_chance", 0.65))):
		return {}
	var clue := acquire(context, SOURCE_RUMOR, rng)
	if clue.is_empty():
		return {}
	return {"clue": clue, "events": [clue_acquired_event(clue)]}


## Buys an intel clue at the current port (requires the `intel` facility).
## Money is only charged after a clue was actually created.
static func buy(context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var state: GameState = context.state
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var port_data := MapOps.port(state.world(), state.current_port_id())
	if not MapOps.has_facility(port_data, "intel"):
		return Result.fail("no_intel_facility", "ui.error.no_intel_facility")
	var rules := ExplorationRules.read(state, context.registries)
	if active(state).size() >= int(rules.get("max_active_clues", 4)):
		return Result.fail("clue_limit", "ui.notice.no_clue_available")
	var cost := int(rules.get("intel_clue_cost", 40))
	if state.money() < cost:
		return Result.fail(
			"insufficient_money",
			"ui.error.insufficient_money",
			{"required": cost, "money": state.money()}
		)
	if eligible_target_ids(state).is_empty():
		return Result.fail("no_clue_available", "ui.error.no_exploration_target")
	var rng: RandomNumberGenerator = context.rng.stream(
		RngService.STREAM_EXPLORATION,
		"intel:%s:%.3f" % [state.current_port_id(), state.now()]
	)
	var clue := acquire(context, SOURCE_INTEL, rng)
	if clue.is_empty():
		return Result.fail("no_clue_available", "ui.error.no_exploration_target")
	state.add_money(-cost)
	state.record_expense(cost)
	return Result.ok(
		{
			"cost": cost,
			"clue_id": String(clue.get("id", "")),
			"source_key": SOURCE_INTEL,
			"clue": view_entry(state, clue),
		},
		[clue_acquired_event(clue)]
	)


## Creates one clue. `rng` must come from the caller so the whole acquisition
## (level, credibility, search-zone direction) stays on one reproducible stream.
static func acquire(context, source_key: String, rng: RandomNumberGenerator, target_port_id: String = "") -> Dictionary:
	if not SOURCES.has(source_key) or rng == null:
		return {}
	var state: GameState = context.state
	var rules := ExplorationRules.read(state, context.registries)
	var clues_data := state.ensure_clues()
	var active_list: Array = clues_data.get("active", [])
	if active_list.size() >= int(rules.get("max_active_clues", 4)):
		return {}
	var world := WorldOps.world_map(state)
	if world.is_empty():
		return {}

	var target_id := target_port_id
	if target_id.is_empty():
		var candidates := eligible_target_ids(state)
		if candidates.is_empty():
			return {}
		target_id = candidates[rng.randi_range(0, candidates.size() - 1)]
	var target := world.get_port(target_id)
	if target.is_empty():
		return {}
	var reference_id := state.current_port_id()
	var reference := world.get_port(reference_id)

	var level := _pick_level(rng, _weights_for(rules, source_key))
	var credibility := _pick_credibility(rng, rules, source_key)
	var direction_angle := 0.0
	if not reference.is_empty():
		direction_angle = (target.position - reference.position).angle()

	# Search zone: true position offset in a random direction. The magnitude is the
	# credibility error (better source -> tighter circle), the direction is random so a
	# high-credibility clue still cannot be pinpointed without sailing there.
	var noise := float(rules.get("search_zone_noise", 12.0))
	var radius := float(rules.get("search_zone_radius", 14.0))
	var offset_angle := rng.randf() * TAU
	var offset := (1.0 - credibility) * noise
	var center := target.position + Vector2(cos(offset_angle), sin(offset_angle)) * offset

	var true_hours := _true_hours(context, reference, target)
	var error_ratio := float(rules.get("distance_error_ratio", 0.35)) * (1.0 - credibility)
	var min_hours := true_hours * (1.0 - error_ratio)
	var max_hours := true_hours * (1.0 + error_ratio)

	var clue := {
		"id": "clue:%d" % int(clues_data.get("next_id", 1)),
		"type": "port_location",
		"source_key": source_key,
		"source_display_key": "ui.clue.source.%s" % source_key,
		"target_port_id": target_id,
		"level": level,
		"reference_port_id": reference_id,
		"direction_angle": direction_angle,
		"distance_min_hours": min_hours,
		"distance_max_hours": max_hours,
		"credibility": credibility,
		"search_zone": {
			"x": center.x,
			"y": center.y,
			"radius": radius,
		},
		"created_at": state.now(),
	}
	clues_data["next_id"] = int(clues_data.get("next_id", 1)) + 1
	active_list.append(clue)
	state.push_notice("ui.notice.clue_acquired", {"source": String(clue["source_display_key"])})
	return clue


static func mark_failed(state: GameState, clue_id: String) -> bool:
	var removed := _remove_active(state, clue_id)
	if removed.is_empty():
		return false
	var clues_data := state.ensure_clues()
	var failed: Array = clues_data.get("failed", [])
	if not failed.has(clue_id):
		failed.append(clue_id)
	return true


static func mark_resolved(state: GameState, clue_id: String) -> bool:
	var removed := _remove_active(state, clue_id)
	if removed.is_empty():
		return false
	var clues_data := state.ensure_clues()
	var resolved: Array = clues_data.get("resolved", [])
	if not resolved.has(clue_id):
		resolved.append(clue_id)
	return true


## Read-only, level-trimmed clue view. `estimated` is added by the caller
## (`sea_chart.view`) because it needs the ship/strategy context.
static func view(state: GameState, _context = null) -> Array:
	var result: Array = []
	for clue in active(state):
		if clue is Dictionary:
			result.append(view_entry(state, clue))
	return result


## One clue trimmed for the query layer. Never emits `target_port_id`,
## `credibility` or `search_zone` (only the already-fuzzed `circle`).
static func view_entry(state: GameState, clue: Dictionary) -> Dictionary:
	var level := int(clue.get("level", 1))
	var circle: Variant = null
	if level >= CIRCLE_MIN_LEVEL:
		var zone: Dictionary = clue.get("search_zone", {})
		circle = {
			"x": float(zone.get("x", 0.0)),
			"y": float(zone.get("y", 0.0)),
			"radius": float(zone.get("radius", 0.0)),
		}
	var name_key := ""
	if level >= NAME_MIN_LEVEL:
		name_key = WorldOps.port_display_key(
			WorldOps.world_map(state), String(clue.get("target_port_id", ""))
		)
	return {
		"id": String(clue.get("id", "")),
		"source_key": String(clue.get("source_key", "")),
		"source_display_key": String(clue.get("source_display_key", "")),
		"level": level,
		"reference_port_id": String(clue.get("reference_port_id", "")),
		"direction_angle": float(clue.get("direction_angle", 0.0)) if level >= DIRECTION_MIN_LEVEL else 0.0,
		"distance_min_hours": float(clue.get("distance_min_hours", 0.0)),
		"distance_max_hours": float(clue.get("distance_max_hours", 0.0)),
		"circle": circle,
		"name_key": name_key,
	}


## Domain event payload for "a clue entered the log". Target port stays out of events.
static func clue_acquired_event(clue: Dictionary) -> Dictionary:
	return {
		"type": "clue.acquired",
		"payload": {
			"clue_id": String(clue.get("id", "")),
			"source_key": String(clue.get("source_key", "")),
			"level": int(clue.get("level", 1)),
		},
	}


static func _remove_active(state: GameState, clue_id: String) -> Dictionary:
	if clue_id.is_empty():
		return {}
	var active_list: Array = state.ensure_clues().get("active", [])
	for index in active_list.size():
		var clue: Variant = active_list[index]
		if clue is Dictionary and String((clue as Dictionary).get("id", "")) == clue_id:
			active_list.remove_at(index)
			return clue
	return {}


static func _pick_level(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total += maxf(0.0, float(weight))
	if total <= 0.0:
		return 1
	var roll := rng.randf() * total
	for index in weights.size():
		roll -= maxf(0.0, float(weights[index]))
		if roll <= 0.0:
			return index + 1
	# Only reachable through floating-point dust; fall back to the last positive level.
	for index in range(weights.size() - 1, -1, -1):
		if float(weights[index]) > 0.0:
			return index + 1
	return 1


static func _weights_for(rules: Dictionary, source_key: String) -> Array:
	var level_weights: Dictionary = rules.get("level_weights", {})
	var weights: Variant = level_weights.get(source_key, [])
	return weights if weights is Array else []


static func _pick_credibility(rng: RandomNumberGenerator, rules: Dictionary, source_key: String) -> float:
	var ranges: Dictionary = rules.get("credibility_range", {})
	var range_value: Variant = ranges.get(source_key, [])
	if not (range_value is Array) or (range_value as Array).size() < 2:
		return 0.5
	var pair: Array = range_value
	return clampf(lerpf(float(pair[0]), float(pair[1]), rng.randf()), 0.0, 1.0)


## True hours for the distance range. The player has no strategy at clue time, so the
## standard strategy (same one the chart estimates with) is used — mirrors
## `VoyageCalculator.preview`'s speed / weight-factor arithmetic without depending on it
## for a destination that is still unknown.
static func _true_hours(context, reference: WorldPort, target: WorldPort) -> float:
	if reference.is_empty() or target.is_empty():
		return 0.0
	var speed := _default_speed(context)
	return reference.position.distance_to(target.position) / maxf(0.1, speed)


static func _default_speed(context) -> float:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var ship := state.ship()
	var stats := ShipOps.stats(hub, ship)
	if not bool(stats.get("valid", false)):
		return maxf(0.1, float(stats.get("speed", 1.0)))
	var strategy: ContentDefinition = null
	for definition in hub.get_all(ContentTypes.STRATEGY):
		if definition.has_tag("strategy.standard"):
			strategy = definition
			break
	var speed_mul := float(strategy.data.get("speed_mul", 1.0)) if strategy != null else 1.0
	var max_weight := ShipOps.max_weight(hub, ship)
	var total_weight := ShipOps.total_weight(hub, state)
	var load_ratio := total_weight / max_weight if max_weight > 0.0 else 0.0
	return maxf(
		0.1,
		float(stats.get("speed", 1.0)) * speed_mul * VoyageCalculator.weight_speed_factor(load_ratio)
	)
