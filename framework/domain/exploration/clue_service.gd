class_name ClueService
extends RefCounted
## @static-doc
## 作用：线索的领域服务——港口位置线索（抵达传闻 / 情报站购买）与货物行情线索
## （`port_goods`：已发现港口 + 货物 + 冻结行情快照 + 到期时间）的生成、逐级调查披露
## （`investigate`，1→2→3→4）、时效清理、按等级裁剪的只读视图、线索生命周期
## （active → resolved / expired；失败探索不再消耗线索）以及发现概率的规则计算。
##
## - 关键依赖：`GameState.data.clues`（惰性 ensure）、`WorldOps`、`MapOps`、
##   `ExplorationRules`、`ShipOps`、`VoyageCalculator`、`MarketOps`、
##   `RngService.STREAM_EXPLORATION`
##
## ## 契约与约束
## - 线索是纯数据，全部可 JSON 化；旧存档没有 `data.clues` 时由 `GameState.ensure_clues()`
##   补齐，旧线索条目由 `normalize_clue()` 惰性补 `type` / `target_goods_id` /
##   `goods_snapshot` / `expires_at` / `unlock_source`，不改 `schema_version`。
## - 港口位置线索的目标只能是坐标世界里**未发现**、且没有被其它活跃线索指向的港口；
##   没有目标时 `acquire` 返回 `{}`（不报错）。测试 / 确定性入口可以显式给
##   `target_port_id` 跳过筛选，但仍然必须存在于坐标世界。
## - 货物线索（4.4）的目标 = **已发现、非当前港**的港口 + 该港 `buyable` 的非补给货物；
##   获得时冻结 `goods_snapshot`（买价 / 卖价 / 库存 / 供需 / 记录时间），按
##   `goods_clue_expiry_hours[source]` 秒表到期；行情不随后市重抽。
## - 随机全部走命名流 `RngService.STREAM_EXPLORATION`：港口传闻 `rumor:<port>:<time>`、
##   购买 `intel:<port>:<time>`，4.4 新增来源见 §11（`wait:*` / `contract:*`）。
## - 线索**获得时固定为 level 1**（阶段 4.3.2 / U2 起不再用 `level_weights` 抽等级）；
##   等级只由 `investigate` 逐级推进（1→2→3→4，上限 4）。`level_weights` 仍保留在
##   Core / schema / `ExplorationRules.DEFAULTS` 中，留给后续线索系统（内容兼容）。
## - 同一线索的 `target_port_id` / `credibility` / 搜索区 / 方向角 / 航程区间在获得时
##   固定，调查只是**逐级披露**，绝不重抽目标。货物线索逐级披露：
##   1 级港口名 → 2 级参考价区间 → 3 级区间 + 供需 / 库存 → 4 级精确买卖价。
## - 调查消耗（4.4 起真实生效）：金币 / 在港小时 / 成功率来自 Core，失败照扣成本但不
##   升级、线索保留；`investigation_cost/hours = 0` 且 `chance = 1` 时保持 4.3 行为。
## - 查询视图裁剪：任何类型、任何等级都不输出 `target_port_id`、`credibility`、
##   真实 `search_zone` 与未披露的 `goods_snapshot` 明细；港口位置线索保持
##   `level < 4` 无 `name_key`、`level < 3` 无 `circle`、level 1 无方向。
## - 时效：`expires_at > 0 且 <= now` 的线索由**命令路径**的 `sweep_expired()` 移入
##   `data.clues.expired`（保留整条快照）并释放 `max_active_clues` 名额；查询只过滤不写。
## - `on_arrival` / `buy` / 新来源钩子永远不阻断抵达 / 出航 / 等待流程：抽不到线索时
##   只返回空结果。
## - 线索不会被删除：发现进 `resolved`、过期进 `expired`；**探索失败不消耗线索**
##   （阶段 4.3 / U3）——`mark_attempt_failed` 只累加 `attempts`、写
##   `last_attempt_at`，线索仍留在 active 且可再次 `explore.start`。旧存档 `failed`
##   列表只保留历史 id，不再写入新条目。
## @end-static-doc

const SOURCE_RUMOR := "rumor"
const SOURCE_INTEL := "intel"
const SOURCE_WAIT := "wait"
const SOURCE_CONTRACT := "contract"
const SOURCES := [SOURCE_RUMOR, SOURCE_INTEL, SOURCE_WAIT, SOURCE_CONTRACT]

## 4.4：线索类型。`port_location` = 未发现港口；`port_goods` = 已发现港口的有行情货物。
const TYPE_PORT_LOCATION := "port_location"
const TYPE_PORT_GOODS := "port_goods"
const TYPES := [TYPE_PORT_LOCATION, TYPE_PORT_GOODS]

## 视图中「距离区间」始终输出（契约 §5 的字段表），但方向只在 level >= 2 时有效。
const DIRECTION_MIN_LEVEL := 2
const CIRCLE_MIN_LEVEL := 3
const NAME_MIN_LEVEL := 4
## 货物线索的逐级披露：2 = 价格区间、3 = 供需 / 库存、4 = 精确买卖价。
const GOODS_PRICE_MIN_LEVEL := 2
const GOODS_SUPPLY_MIN_LEVEL := 3
const GOODS_EXACT_MIN_LEVEL := 4
## 无 Core 配置时的面板兜底（正常内容总会覆盖，不参与调参）。
const FALLBACK_GOODS_EXPIRY_HOURS := 48.0


## Returns the lazily-created `data.clues` block.
static func clues(state: GameState) -> Dictionary:
	return state.ensure_clues()


## Active clue dictionaries (mutable references into GameState). Old saves are normalized
## in place so every consumer can rely on the stage-4.4 keys existing.
static func active(state: GameState) -> Array:
	var active_list: Array = state.ensure_clues().get("active", [])
	for clue in active_list:
		if clue is Dictionary:
			normalize_clue(clue)
	return active_list


## Lazy upgrade of a clue created before stage 4.4. Idempotent, never bumps schema_version.
static func normalize_clue(clue: Dictionary) -> Dictionary:
	if clue.is_empty():
		return clue
	if not TYPES.has(String(clue.get("type", ""))):
		clue["type"] = TYPE_PORT_LOCATION
	if not clue.has("target_goods_id"):
		clue["target_goods_id"] = ""
	if not clue.has("goods_snapshot"):
		clue["goods_snapshot"] = null
	if not clue.has("expires_at"):
		clue["expires_at"] = 0.0
	if not clue.has("unlock_source"):
		clue["unlock_source"] = ""
	return clue


## True when the clue has a finite lifetime that has already elapsed.
static func is_expired(clue: Dictionary, at_time: float) -> bool:
	var expires_at := float(clue.get("expires_at", 0.0))
	return expires_at > 0.0 and at_time >= expires_at


## Number of active clues that are still alive at `at_time` (expired-but-not-yet-swept
## entries do not count toward `max_active_clues`).
static func active_count(state: GameState, at_time: float = -1.0) -> int:
	var now := float(state.now() if at_time < 0.0 else at_time)
	var count := 0
	for clue in active(state):
		if clue is Dictionary and not is_expired(clue, now):
			count += 1
	return count


## Command-path expiry sweep: moves timed-out clues from `active` to `expired` (keeping the
## full snapshot for the list page history) and frees their active slots. Returns the ids in
## removal order; an empty sweep is a no-op. Queries must never call this (read-only), they
## only filter via `view`.
static func sweep_expired(state: GameState, at_time: float = -1.0) -> Array[String]:
	var now := float(state.now() if at_time < 0.0 else at_time)
	var clues_data := state.ensure_clues()
	var active_list: Array = clues_data.get("active", [])
	var expired_list: Array = clues_data.get("expired", [])
	var expired_ids: Array[String] = []
	var kept: Array = []
	for clue in active_list:
		if clue is Dictionary:
			normalize_clue(clue)
			if is_expired(clue, now):
				expired_ids.append(String(clue.get("id", "")))
				expired_list.append(clue.duplicate(true))
				continue
		kept.append(clue)
	if expired_ids.is_empty():
		return expired_ids
	active_list.clear()
	active_list.append_array(kept)
	clues_data["active"] = active_list
	clues_data["expired"] = expired_list
	state.push_notice("ui.notice.clue_expired", {"count": expired_ids.size()})
	return expired_ids


static func find_clue(state: GameState, clue_id: String) -> Dictionary:
	if clue_id.is_empty():
		return {}
	for clue in active(state):
		if clue is Dictionary and String((clue as Dictionary).get("id", "")) == clue_id:
			return normalize_clue(clue)
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
	if active_count(state) >= int(rules.get("max_active_clues", 4)):
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


## 4.4.2：在港等待解锁线索的概率（纯函数，供测试 / 查询复用）。按
## `wait_clue_hours_block` 分档复利：`1 - (1 - per_block) ^ blocks`，封顶
## `wait_clue_max_chance`；不足一档返回 0。
static func wait_clue_chance(rules: Dictionary, hours: int) -> float:
	var block := maxf(1.0, float(rules.get("wait_clue_hours_block", 6.0)))
	var blocks := floorf(maxf(0.0, float(hours)) / block)
	if blocks < 1.0:
		return 0.0
	var per_block := clampf(float(rules.get("wait_clue_chance_per_block", 0.35)), 0.0, 1.0)
	var cap := clampf(float(rules.get("wait_clue_max_chance", 0.85)), 0.0, 1.0)
	return clampf(1.0 - pow(1.0 - per_block, blocks), 0.0, cap)


## 4.4.2：在港等待钩子（`port.wait` 调）。按档位复利概率抽一次，优先按来源权重出
## 货物线索（没有货物候选时退回港口位置线索），失败静默返回 `{}`。
static func on_wait(context, hours: int) -> Dictionary:
	if not context.has_run():
		return {}
	var state: GameState = context.state
	if not state.is_at_port() or state.explore_voyage() is Dictionary:
		return {}
	var rules := ExplorationRules.read(state, context.registries)
	if active_count(state) >= int(rules.get("max_active_clues", 4)):
		return {}
	var chance := wait_clue_chance(rules, hours)
	if chance <= 0.0:
		return {}
	var rng: RandomNumberGenerator = context.rng.stream(
		RngService.STREAM_EXPLORATION,
		"wait:%s:%.3f" % [state.current_port_id(), state.now()]
	)
	if not ExplorationRules.roll_succeeds(rng, chance):
		return {}
	var clue := _acquire_by_source(context, SOURCE_WAIT, rng, "wait:%d" % int(hours))
	if clue.is_empty():
		return {}
	return {"clue": clue, "events": [clue_acquired_event(clue)]}


## 4.4.2：完成委托钩子（到港服务调）。每份刚完成的委托独立抽一次
## `contract_clue_chance`，成功则按来源权重出一条线索（默认出港口位置线索）。
## 返回 `{clues, events}`；没有任何收获时返回 `{}`。
static func on_contract_completed(context, completed: Array) -> Dictionary:
	if not context.has_run() or completed.is_empty():
		return {}
	var state: GameState = context.state
	var rules := ExplorationRules.read(state, context.registries)
	var chance := clampf(float(rules.get("contract_clue_chance", 0.5)), 0.0, 1.0)
	if chance <= 0.0:
		return {}
	var clues: Array = []
	var events: Array = []
	for raw in completed:
		if not (raw is Dictionary):
			continue
		if active_count(state) >= int(rules.get("max_active_clues", 4)):
			break
		var instance_id := String((raw as Dictionary).get("instance_id", ""))
		if instance_id.is_empty():
			continue
		var rng: RandomNumberGenerator = context.rng.stream(
			RngService.STREAM_EXPLORATION,
			"contract:%s:%s" % [state.current_port_id(), instance_id]
		)
		if not ExplorationRules.roll_succeeds(rng, chance):
			continue
		var clue := _acquire_by_source(
			context, SOURCE_CONTRACT, rng, "contract:%s" % instance_id
		)
		if clue.is_empty():
			continue
		clues.append(clue)
		events.append(clue_acquired_event(clue))
	if clues.is_empty():
		return {}
	return {"clues": clues, "events": events}


## 4.4.2：来源产出的线索类型由 `goods_clue_source_weights` 决定（权重 0 = 只出港口
## 位置线索）；货物候选为空时自动退回港口位置线索。`unlock_source` 只做追溯记录。
static func _acquire_by_source(
	context, source_key: String, rng: RandomNumberGenerator, unlock_source: String
) -> Dictionary:
	var rules := ExplorationRules.read(context.state, context.registries)
	var weights: Dictionary = rules.get("goods_clue_source_weights", {})
	var goods_weight := clampf(float(weights.get(source_key, 0.0)), 0.0, 1.0)
	var clue: Dictionary = {}
	if goods_weight > 0.0 and rng.randf() < goods_weight:
		clue = acquire_goods(context, source_key, rng)
	if clue.is_empty():
		clue = acquire(context, source_key, rng)
	if not clue.is_empty() and not unlock_source.is_empty():
		clue["unlock_source"] = unlock_source
	return clue


## Buys an intel clue at the current port (requires the `intel` facility).
## Money is only charged after a clue was actually created.
static func buy(context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var state: GameState = context.state
	var expired := sweep_expired(state)
	var expired_events := expired_events_of(expired)
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port", {}, expired_events)
	var port_data := MapOps.port(state.world(), state.current_port_id())
	if not MapOps.has_facility(port_data, "intel"):
		return Result.fail("no_intel_facility", "ui.error.no_intel_facility", {}, expired_events)
	var rules := ExplorationRules.read(state, context.registries)
	if active_count(state) >= int(rules.get("max_active_clues", 4)):
		return Result.fail("clue_limit", "ui.notice.no_clue_available", {}, expired_events)
	var cost := int(rules.get("intel_clue_cost", 40))
	if state.money() < cost:
		return Result.fail(
			"insufficient_money",
			"ui.error.insufficient_money",
			{"required": cost, "money": state.money()},
			expired_events
		)
	if eligible_target_ids(state).is_empty():
		return Result.fail(
			"no_clue_available", "ui.error.no_exploration_target", {}, expired_events
		)
	var rng: RandomNumberGenerator = context.rng.stream(
		RngService.STREAM_EXPLORATION,
		"intel:%s:%.3f" % [state.current_port_id(), state.now()]
	)
	var clue := acquire(context, SOURCE_INTEL, rng)
	if clue.is_empty():
		return Result.fail(
			"no_clue_available", "ui.error.no_exploration_target", {}, expired_events
		)
	state.add_money(-cost)
	state.record_expense(cost)
	var events: Array = expired_events.duplicate()
	events.append(clue_acquired_event(clue))
	return Result.ok(
		{
			"cost": cost,
			"clue_id": String(clue.get("id", "")),
			"source_key": SOURCE_INTEL,
			"clue": view_entry(state, clue),
		},
		events
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
	if active_count(state) >= int(rules.get("max_active_clues", 4)):
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

	# 阶段 4.3.2 / U2：获得时固定 1 级；逐级揭示交给 `investigate`。
	# `level_weights` 不再参与获得等级（保留在内容 / schema 中供后续线索系统使用）。
	var level := 1
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
		"type": TYPE_PORT_LOCATION,
		"source_key": source_key,
		"source_display_key": "ui.clue.source.%s" % source_key,
		"target_port_id": target_id,
		"target_goods_id": "",
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
		# 4.3 / U3：失败探索只记录尝试，不消耗线索。
		"attempts": 0,
		"last_attempt_at": 0.0,
		# 4.4：港口位置线索永久有效；货物线索才有 `expires_at` 与行情快照。
		"goods_snapshot": null,
		"expires_at": 0.0,
		"unlock_source": "",
	}
	clues_data["next_id"] = int(clues_data.get("next_id", 1)) + 1
	active_list.append(clue)
	state.push_notice("ui.notice.clue_acquired", {"source": String(clue["source_display_key"])})
	return clue


## 4.4：创建一条货物行情线索。目标 = 已发现、非当前港的港口 + 该港 `buyable` 的普通
## 货物（不写死任何内容 ID，按注册表内容类型 + 实时市场推导）。行情在获得时冻结成
## `goods_snapshot`，按 `goods_clue_expiry_hours[source]` 到期；来源权重由调用方决定
## （`on_wait` / `on_contract_completed` / `clue.buy`）。
static func acquire_goods(
	context, source_key: String, rng: RandomNumberGenerator
) -> Dictionary:
	if not SOURCES.has(source_key) or rng == null:
		return {}
	var state: GameState = context.state
	var rules := ExplorationRules.read(state, context.registries)
	var clues_data := state.ensure_clues()
	if active_count(state) >= int(rules.get("max_active_clues", 4)):
		return {}
	var candidates := goods_candidates(context)
	if candidates.is_empty():
		return {}
	var picked: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var port_id := String(picked.get("port_id", ""))
	var good_id := String(picked.get("good_id", ""))
	var entry: Dictionary = picked.get("entry", {})
	var world := WorldOps.world_map(state)
	var port := world.get_port(port_id)
	if port.is_empty() or good_id.is_empty():
		return {}
	var reference_id := state.current_port_id()
	var credibility := _pick_credibility(rng, rules, source_key)
	var price := maxf(1.0, float(entry.get("price", 1.0)))
	var margin := _trade_margin(context)
	var buy_price := maxi(1, int(round(price)))
	var sell_price := maxi(1, int(floor(price * margin)))
	var base_price := maxf(0.001, float(entry.get("base_price", price)))
	var ratio := price / base_price
	var demand := "normal"
	if ratio >= 1.15:
		demand = "high"
	elif ratio <= 0.9:
		demand = "low"
	var expiry_hours := _goods_expiry_hours(rules, source_key)
	var clue := {
		"id": "clue:%d" % int(clues_data.get("next_id", 1)),
		"type": TYPE_PORT_GOODS,
		"source_key": source_key,
		"source_display_key": "ui.clue.source.%s" % source_key,
		"target_port_id": port_id,
		"target_goods_id": good_id,
		"level": 1,
		"reference_port_id": reference_id,
		# 货物线索不披露方向 / 搜索区（目标是已发现港口，报的是行情）。
		"direction_angle": 0.0,
		"distance_min_hours": 0.0,
		"distance_max_hours": 0.0,
		"credibility": credibility,
		"search_zone": {"x": port.position.x, "y": port.position.y, "radius": 0.0},
		"created_at": state.now(),
		"attempts": 0,
		"last_attempt_at": 0.0,
		"goods_snapshot": {
			"port_id": port_id,
			"good_id": good_id,
			"buy_price": buy_price,
			"sell_price": sell_price,
			"stock": maxi(0, int(entry.get("stock", 0))),
			"demand": demand,
			"recorded_at": state.now(),
			"price_error_ratio": clampf(
				float(rules.get("goods_clue_price_error_ratio", 0.15)), 0.0, 1.0
			),
		},
		"expires_at": state.now() + expiry_hours,
		"unlock_source": "",
	}
	clues_data["next_id"] = int(clues_data.get("next_id", 1)) + 1
	var active_list: Array = clues_data.get("active", [])
	active_list.append(clue)
	state.push_notice(
		"ui.notice.goods_clue_acquired", {"goods": _goods_name_key(context, good_id)}
	)
	return clue


## Deterministic candidate list for goods clues: every discovered port except the current
## one, every buyable non-supply good in its live market, minus pairs already referenced by
## an active goods clue. Sorted by port then item id so the named stream is reproducible.
static func goods_candidates(context) -> Array:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var discovered: Array = state.campaign_world().get("discovered_port_ids", [])
	var current := state.current_port_id()
	var referenced := {}
	for clue in active(state):
		if clue is Dictionary and String(clue.get("type", "")) == TYPE_PORT_GOODS:
			referenced[_goods_pair(clue)] = true
	var port_ids: Array = []
	for raw_port_id in discovered:
		var port_id := String(raw_port_id)
		if port_id.is_empty() or port_id == current or port_ids.has(port_id):
			continue
		port_ids.append(port_id)
	port_ids.sort()
	var market: Dictionary = state.market()
	var candidates: Array = []
	for port_id in port_ids:
		var port_market: Dictionary = market.get(port_id, {})
		var good_ids: Array = []
		for raw_item_id in port_market.keys():
			var item_id := String(raw_item_id)
			var entry: Variant = port_market[raw_item_id]
			if not (entry is Dictionary):
				continue
			if not bool((entry as Dictionary).get("buyable", true)):
				continue
			if bool((entry as Dictionary).get("is_supply", false)):
				continue
			# 只收普通货物；材料 / 补给 / 委托货箱不进入货物线索。
			if hub == null or hub.get_by_id(ContentTypes.GOOD, item_id) == null:
				continue
			if referenced.has("%s|%s" % [port_id, item_id]):
				continue
			good_ids.append(item_id)
		good_ids.sort()
		for good_id in good_ids:
			candidates.append({
				"port_id": port_id,
				"good_id": good_id,
				"entry": port_market[good_id],
			})
	return candidates


## 4.4.3：「调查线索」——在港把一条 active 线索推进一级（1→2→3→4，上限 4）。
## 每次尝试消耗 Core 的 `investigation_cost` 金币、`investigation_hours` 在港小时
## （走 `PortTimeService`，与等待同一套订单 / NPC / 债务结算），再按
## `investigation_success_chance` 判定：成功 `level + 1`，失败照扣成本但不升级，
## 线索保留可再试。目标港 / credibility / 搜索区 / 行情快照在获得时固定，调查只披露。
## `cost / hours / chance` 为 0 / 0 / 1 时行为与 4.3 一致。
static func investigate(context, clue_id: String) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var state: GameState = context.state
	var expired := sweep_expired(state)
	var expired_events := expired_events_of(expired)
	if clue_id.is_empty():
		return Result.fail("unknown_clue", "ui.error.unknown_clue", {}, expired_events)
	var clue := find_clue(state, clue_id)
	if clue.is_empty():
		# 区分「从未存在」与「已经解决 / 作废」：两者都不在 active，但提示不同。
		var clues_data := state.ensure_clues()
		if Array(clues_data.get("failed", [])).has(clue_id) \
				or Array(clues_data.get("resolved", [])).has(clue_id) \
				or _expired_has(clues_data, clue_id):
			return Result.fail(
				"clue_not_active", "ui.error.clue_not_active", {"clue_id": clue_id},
				expired_events
			)
		return Result.fail(
			"unknown_clue", "ui.error.unknown_clue", {"clue_id": clue_id}, expired_events
		)
	if is_expired(clue, state.now()):
		return Result.fail(
			"clue_expired", "ui.error.clue_expired", {"clue_id": clue_id}, expired_events
		)
	if not state.is_at_port():
		return Result.fail(
			"not_at_port", "ui.error.not_at_port", {"clue_id": clue_id}, expired_events
		)
	var level := int(clue.get("level", 1))
	if level >= NAME_MIN_LEVEL:
		return Result.fail(
			"clue_max_level",
			"ui.error.clue_max_level",
			{"clue_id": clue_id, "level": level},
			expired_events
		)
	var rules := ExplorationRules.read(state, context.registries)
	var cost := int(rules.get("investigation_cost", 0))
	var hours := float(rules.get("investigation_hours", 0.0))
	var chance := clampf(float(rules.get("investigation_success_chance", 1.0)), 0.0, 1.0)
	# 金币不足：在扣费 / 推进时间之前失败，命令事务不会落账。
	if cost > 0 and state.money() < cost:
		return Result.fail(
			"insufficient_money",
			"ui.error.insufficient_money",
			{"required": cost, "money": state.money(), "clue_id": clue_id},
			expired_events
		)
	var events: Array = expired_events.duplicate()
	if cost > 0:
		state.add_money(-cost)
		state.record_expense(cost)
	if hours > 0.0:
		var spent := PortTimeService.spend(context, hours)
		for order in spent.get("completed_orders", []):
			events.append({
				"type": "ship.module_crafted",
				"payload": {
					"order_id": String((order as Dictionary).get("order_id", "")),
					"module_id": String((order as Dictionary).get("module_id", "")),
					"content_type": String((order as Dictionary).get("content_type", "")),
					"port_id": String((order as Dictionary).get("port_id", "")),
					"warehouse_qty": int((order as Dictionary).get("warehouse_qty", 0)),
				},
			})
		events.append_array(spent.get("npc_events", []))
		events.append_array(spent.get("debt_events", []))
		# 工时可能让线索本身到期：先 sweep 再判定，避免对已失效线索升级。
		events.append_array(expired_events_of(sweep_expired(state)))
		clue = find_clue(state, clue_id)
		if clue.is_empty():
			return Result.ok(
				{
					"success": false,
					"expired": true,
					"clue_id": clue_id,
					"level": 0,
					"next_level": 0,
					"cost": cost,
					"hours": hours,
					"success_chance": chance,
					"charged": cost > 0,
					"view": {},
				},
				events
			)
	var rng: RandomNumberGenerator = context.rng.stream(
		RngService.STREAM_EXPLORATION,
		"investigate:%s:%d:%.3f" % [clue_id, level, state.now()]
	)
	var roll := rng.randf()
	var success := ExplorationRules.roll_hits(roll, chance)
	# `rule_roll` 仅供测试复现：同 seed + 同 key 的判定与 `roll_succeeds` 一致。
	var new_level := level
	if success:
		clue["level"] = level + 1
		new_level = int(clue.get("level", level + 1))
		events.append(clue_investigated_event(clue))
	else:
		state.push_notice("ui.notice.clue_investigation_failed", {
			"level": level,
			"cost": cost,
			"hours": hours,
		})
		events.append(clue_investigation_failed_event(clue, cost, hours))
	return Result.ok(
		{
			"success": success,
			"expired": false,
			"clue_id": clue_id,
			"level": new_level,
			"next_level": new_level + 1 if new_level < NAME_MIN_LEVEL else 0,
			"cost": cost,
			"hours": hours,
			"success_chance": chance,
			"charged": cost > 0,
			"roll": roll,
			"view": view_entry(state, clue),
		},
		events
	)


## 4.4.2：货物线索的「前往该港」——在领域层解析目标港（查询永远不输出
## `target_port_id`），然后复用 `VoyageService.start` 的普通航线（含预览 / 工资 /
## 事件 / 演出），线索保持 active 直到自然过期或玩家不再使用。
static func travel(context, clue_id: String, strategy_id: String) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var state: GameState = context.state
	var expired := sweep_expired(state)
	var expired_events := expired_events_of(expired)
	if clue_id.is_empty():
		return Result.fail("unknown_clue", "ui.error.unknown_clue", {}, expired_events)
	var clue := find_clue(state, clue_id)
	if clue.is_empty():
		var clues_data := state.ensure_clues()
		if Array(clues_data.get("failed", [])).has(clue_id) \
				or Array(clues_data.get("resolved", [])).has(clue_id) \
				or _expired_has(clues_data, clue_id):
			return Result.fail(
				"clue_not_active", "ui.error.clue_not_active", {"clue_id": clue_id},
				expired_events
			)
		return Result.fail(
			"unknown_clue", "ui.error.unknown_clue", {"clue_id": clue_id}, expired_events
		)
	if String(clue.get("type", TYPE_PORT_LOCATION)) != TYPE_PORT_GOODS:
		return Result.fail(
			"not_goods_clue", "ui.error.not_goods_clue", {"clue_id": clue_id}, expired_events
		)
	if is_expired(clue, state.now()):
		return Result.fail(
			"clue_expired", "ui.error.clue_expired", {"clue_id": clue_id}, expired_events
		)
	if state.explore_voyage() is Dictionary:
		return Result.fail("already_exploring", "ui.error.already_exploring", {}, expired_events)
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port", {}, expired_events)
	var target_id := String(clue.get("target_port_id", ""))
	if target_id.is_empty() or target_id == state.current_port_id():
		return Result.fail(
			"no_travel_target", "ui.error.no_travel_target", {"clue_id": clue_id},
			expired_events
		)
	var result := VoyageService.start(context, target_id, strategy_id)
	if bool(result.get("ok", false)):
		var events: Array = expired_events.duplicate()
		events.append_array(result.get("events", []))
		result["events"] = events
	return result


## 4.3 / U3：一次失败的探索尝试。线索**不离开** active，只累加尝试次数与最近
## 尝试时间（供 UI 提示与将来线索系统迭代使用）。返回累计尝试次数；线索不在
## active（旧存档 / 已解决）时返回 0 且不写状态。
static func mark_attempt_failed(state: GameState, clue_id: String, at_time: float = -1.0) -> int:
	var clue := find_clue(state, clue_id)
	if clue.is_empty():
		return 0
	var attempts := int(clue.get("attempts", 0)) + 1
	clue["attempts"] = attempts
	clue["last_attempt_at"] = float(state.now() if at_time < 0.0 else at_time)
	return attempts


static func mark_resolved(state: GameState, clue_id: String) -> bool:
	var removed := _remove_active(state, clue_id)
	if removed.is_empty():
		return false
	var clues_data := state.ensure_clues()
	var resolved: Array = clues_data.get("resolved", [])
	if not resolved.has(clue_id):
		resolved.append(clue_id)
	return true


## Read-only, level-trimmed clue view. Expired-but-not-yet-swept entries are filtered out
## (queries never write state). `estimated` is added by the caller (`sea_chart.view`)
## because it needs the ship/strategy context.
static func view(state: GameState, _context = null) -> Array:
	var result: Array = []
	var now := state.now()
	for clue in active(state):
		if clue is Dictionary and not is_expired(clue, now):
			result.append(view_entry(state, clue))
	return result


## One clue trimmed for the query layer. Never emits `target_port_id`, `credibility`,
## `search_zone` or the raw `goods_snapshot`; goods disclose a level-trimmed projection.
## Port-location clipping is unchanged from 4.3: level < 4 no name, level < 3 no circle,
## level 1 no direction.
static func view_entry(state: GameState, clue: Dictionary) -> Dictionary:
	normalize_clue(clue)
	var level := int(clue.get("level", 1))
	var type := String(clue.get("type", TYPE_PORT_LOCATION))
	var now := state.now()
	var expires_at := float(clue.get("expires_at", 0.0))
	var remaining := -1.0
	if expires_at > 0.0:
		remaining = maxf(0.0, expires_at - now)
	var entry := {
		"id": String(clue.get("id", "")),
		"type": type,
		"source_key": String(clue.get("source_key", "")),
		"source_display_key": String(clue.get("source_display_key", "")),
		"level": level,
		"target_goods_id": String(clue.get("target_goods_id", "")),
		"reference_port_id": String(clue.get("reference_port_id", "")),
		"attempts": int(clue.get("attempts", 0)),
		"last_attempt_at": float(clue.get("last_attempt_at", 0.0)),
		"expires_at": expires_at,
		"remaining_hours": remaining,
		"is_expired": is_expired(clue, now),
	}
	if type == TYPE_PORT_GOODS:
		# 货物线索：目标是已发现港口，行情按等级逐级披露；不输出方向 / 圆圈 / 名称。
		entry["direction_angle"] = 0.0
		entry["distance_min_hours"] = 0.0
		entry["distance_max_hours"] = 0.0
		entry["circle"] = null
		entry["name_key"] = ""
		entry["goods"] = _goods_view(state, clue, level)
		return entry
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
	entry["direction_angle"] = (
		float(clue.get("direction_angle", 0.0)) if level >= DIRECTION_MIN_LEVEL else 0.0
	)
	entry["distance_min_hours"] = float(clue.get("distance_min_hours", 0.0))
	entry["distance_max_hours"] = float(clue.get("distance_max_hours", 0.0))
	entry["circle"] = circle
	entry["name_key"] = name_key
	entry["goods"] = null
	return entry


## Level-trimmed goods projection. The port is known (goods clues target discovered
## harbours), so `port_name_key` shows from level 1; the price range appears at level 2,
## stock / demand at level 3 and the exact buy / sell prices at level 4.
static func _goods_view(state: GameState, clue: Dictionary, level: int) -> Dictionary:
	var snapshot: Variant = clue.get("goods_snapshot", null)
	if not (snapshot is Dictionary):
		return {}
	var data: Dictionary = snapshot
	var port_id := String(data.get("port_id", clue.get("target_port_id", "")))
	var view := {
		"port_name_key": WorldOps.port_display_key(WorldOps.world_map(state), port_id),
		"demand": "",
	}
	if level >= GOODS_PRICE_MIN_LEVEL:
		var credibility := clampf(float(clue.get("credibility", 0.5)), 0.0, 1.0)
		var error_ratio := clampf(float(data.get("price_error_ratio", 0.15)), 0.0, 1.0) \
			* (1.0 - credibility)
		view["buy_price_min"] = maxi(1, int(round(float(data.get("buy_price", 1)) * (1.0 - error_ratio))))
		view["buy_price_max"] = maxi(1, int(round(float(data.get("buy_price", 1)) * (1.0 + error_ratio))))
		view["sell_price_min"] = maxi(1, int(round(float(data.get("sell_price", 1)) * (1.0 - error_ratio))))
		view["sell_price_max"] = maxi(1, int(round(float(data.get("sell_price", 1)) * (1.0 + error_ratio))))
	if level >= GOODS_SUPPLY_MIN_LEVEL:
		view["stock"] = int(data.get("stock", 0))
		view["demand"] = String(data.get("demand", "normal"))
	if level >= GOODS_EXACT_MIN_LEVEL:
		view["buy_price"] = int(data.get("buy_price", 0))
		view["sell_price"] = int(data.get("sell_price", 0))
	return view


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


## Domain event for "a clue was investigated one level further". Target port,
## credibility and search zone stay out of the payload (only clue id + level).
static func clue_investigated_event(clue: Dictionary) -> Dictionary:
	return {
		"type": "clue.investigated",
		"payload": {
			"clue_id": String(clue.get("id", "")),
			"level": int(clue.get("level", 1)),
		},
	}


## Domain event for a failed investigation attempt: the cost was charged, the level did
## not change, and the clue stays active for another try.
static func clue_investigation_failed_event(
	clue: Dictionary, cost: int, hours: float
) -> Dictionary:
	return {
		"type": "clue.investigation_failed",
		"payload": {
			"clue_id": String(clue.get("id", "")),
			"level": int(clue.get("level", 1)),
			"cost": cost,
			"hours": hours,
		},
	}


## Domain event batch emitted when a command-path sweep drops timed-out clues.
static func clue_expired_event(clue_ids: Array[String]) -> Dictionary:
	return {
		"type": "clue.expired",
		"payload": {"clue_ids": clue_ids, "count": clue_ids.size()},
	}


## Event list for a sweep result; empty sweep -> empty list (no event noise).
static func expired_events_of(clue_ids: Array[String]) -> Array:
	return [] if clue_ids.is_empty() else [clue_expired_event(clue_ids)]


static func _expired_has(clues_data: Dictionary, clue_id: String) -> bool:
	for entry in Array(clues_data.get("expired", [])):
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == clue_id:
			return true
	return false


## `"<port>|<good>"` identity of a goods clue, used to avoid duplicate active leads.
static func _goods_pair(clue: Dictionary) -> String:
	var snapshot: Variant = clue.get("goods_snapshot", null)
	if snapshot is Dictionary:
		return "%s|%s" % [String(snapshot.get("port_id", "")), String(snapshot.get("good_id", ""))]
	return "%s|%s" % [
		String(clue.get("target_port_id", "")), String(clue.get("target_goods_id", ""))
	]


## Localized display key of a good, resolved from the registry (never a content literal).
static func _goods_name_key(context, good_id: String) -> String:
	var hub: RegistryHub = context.registries
	var definition: ContentDefinition = hub.get_by_id(ContentTypes.GOOD, good_id) if hub != null else null
	return definition.name_key if definition != null else good_id


## Trade margin of the current map profile (same value `trade.buy` / `trade.sell` use).
static func _trade_margin(context) -> float:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	if hub == null:
		return MarketOps.DEFAULT_TRADE_MARGIN
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = hub.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	if profile == null:
		return MarketOps.DEFAULT_TRADE_MARGIN
	return float(profile.data.get("trade_margin", MarketOps.DEFAULT_TRADE_MARGIN))


## Lifetime of a goods clue by source, from `goods_clue_expiry_hours` (0 disables expiry).
static func _goods_expiry_hours(rules: Dictionary, source_key: String) -> float:
	var table: Dictionary = rules.get("goods_clue_expiry_hours", {})
	return maxf(0.0, float(table.get(source_key, FALLBACK_GOODS_EXPIRY_HOURS)))


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
