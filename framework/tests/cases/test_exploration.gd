extends TestCase
## @static-doc
## 作用：探索系统（阶段 4.1）领域层无头测试：线索生成 / 分级裁剪 / 命名流复现、
## `clue.buy` 门禁、`explore.start` 扣费与在航标记、`explore.settle` 成功发现与失败漂流、
## `explore.decide` 掉头 / 继续、`sea_chart.view` 的线索 / 探索 / 购买视图，以及存档往返。
##
## ## 契约与约束
## - 每个用例用 `bootstrap_core()` + `run.start` 拿真实 Core 注册表与真实对局；
##   线索一律通过 `ClueService.acquire` 构造（不依赖随机成功），需要固定等级/可信度时
##   才在构造后改写测试用的字段。
## - 概率用例直接验证 `ExplorationRules.roll_succeeds` 的 0 / 1 边界与固定 seed 复现；
##   发现 / 未发现用出发时抽定的 `outcome_roll`（契约 §2）强制，而不是依赖真实随机。
## - 断言取值遵守契约 §3 的 Core 数值（40 金币、漂流 6h、额外煤水 4、耐久 8 等），
##   避免测试与内容 JSON 脱节。
## @end-static-doc

const SEED := 20260421
const STRATEGY_ID := "core:strategy/standard"

var _stream_serial := 0


# ── Clue generation ──

func test_acquire_levels_and_credibility_stay_in_source_ranges() -> void:
	var context := _start_run(SEED)
	var rules := ExplorationRules.read(context.state, context.registries)
	for source in ["rumor", "intel"]:
		var pair: Array = (rules["credibility_range"] as Dictionary)[source]
		var low := float(pair[0])
		var high := float(pair[1])
		for _index in 10:
			var clue := _acquire(context, source)
			assert_false(clue.is_empty(), "a %s clue should be acquirable" % source)
			if clue.is_empty():
				continue
			var credibility := float(clue.get("credibility", -1.0))
			assert_true(credibility >= low and credibility <= high,
				"%s credibility %.3f should stay in [%.2f, %.2f]" % [source, credibility, low, high])
			var level := int(clue.get("level", 0))
			if source == "rumor":
				assert_true(level >= 1 and level <= 3,
					"a rumour can never reveal the name (level %d)" % level)
			else:
				assert_true(level >= 2 and level <= 4,
					"bought intel always reveals at least a direction (level %d)" % level)
			assert_eq(String(clue.get("source_display_key", "")), "ui.clue.source.%s" % source,
				"clue carries its localized source key")
			# Free the slot so the max-active-clues cap does not block the loop.
			ClueService.mark_resolved(context.state, String(clue.get("id", "")))


func test_acquire_returns_empty_when_no_undiscovered_target() -> void:
	var context := _start_run(SEED)
	var world := WorldOps.world_map(context.state)
	var campaign_world := context.state.campaign_world()
	var all_ids: Array = []
	for port in world.ports:
		all_ids.append(port.id)
	campaign_world["discovered_port_ids"] = all_ids
	var rng := context.rng.make_stream(RngService.STREAM_EXPLORATION, "no-target")
	var clue := ClueService.acquire(context, "rumor", rng)
	assert_true(clue.is_empty(), "no undiscovered target means no clue")
	assert_eq(ClueService.active(context.state).size(), 0, "nothing was added")


func test_acquire_search_zone_and_distance_range_follow_credibility() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "intel clue should exist")
	var rules := ExplorationRules.read(context.state, context.registries)
	var credibility := float(clue.get("credibility", 0.0))
	var zone: Dictionary = clue.get("search_zone", {})
	var target := WorldOps.world_map(context.state).get_port(String(clue.get("target_port_id", "")))
	assert_almost_eq(
		Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0))).distance_to(target.position),
		(1.0 - credibility) * float(rules.get("search_zone_noise", 12.0)),
		0.001,
		"search centre offset is (1 - credibility) * noise"
	)
	assert_almost_eq(float(zone.get("radius", 0.0)), float(rules.get("search_zone_radius", 14.0)), 0.0001,
		"search radius comes from the map profile")
	var error_ratio := float(rules.get("distance_error_ratio", 0.35)) * (1.0 - credibility)
	var min_hours := float(clue.get("distance_min_hours", 0.0))
	var max_hours := float(clue.get("distance_max_hours", 0.0))
	var true_hours := (min_hours + max_hours) * 0.5
	assert_almost_eq(min_hours, true_hours * (1.0 - error_ratio), 0.001,
		"distance range lower bound uses the credibility error ratio")
	assert_almost_eq(max_hours, true_hours * (1.0 + error_ratio), 0.001,
		"distance range upper bound is symmetric")


# ── Clue view clipping ──

func test_clue_view_clips_secrets_by_level() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "intel clue should exist")
	var clue_id := String(clue.get("id", ""))
	var target_id := String(clue.get("target_port_id", ""))
	var direction := float(clue.get("direction_angle", 0.0))
	var world := WorldOps.world_map(context.state)
	for level in [1, 2, 3, 4]:
		clue["level"] = level
		var views := ClueService.view(context.state, context)
		assert_eq(views.size(), 1, "one active clue should produce one view")
		if views.is_empty():
			continue
		var view: Dictionary = views[0]
		assert_eq(String(view.get("id", "")), clue_id, "view keeps the public clue id")
		assert_false(view.has("target_port_id"), "level %d view must not leak target_port_id" % level)
		assert_false(view.has("credibility"), "level %d view must not leak credibility" % level)
		assert_false(view.has("search_zone"), "level %d view must not leak the true search zone" % level)
		var circle: Variant = view.get("circle", null)
		assert_eq(circle != null, level >= 3, "level %d circle disclosure" % level)
		var name_key := String(view.get("name_key", ""))
		if level >= 4:
			assert_eq(name_key, WorldOps.port_display_key(world, target_id),
				"level 4 reveals the target harbour name key")
		else:
			assert_eq(name_key, "", "level %d must not reveal the name" % level)
		if level >= 2:
			assert_almost_eq(float(view.get("direction_angle", 0.0)), direction, 0.0001,
				"level %d carries the direction" % level)
		else:
			assert_almost_eq(float(view.get("direction_angle", 0.0)), 0.0, 0.0001,
				"level 1 does not disclose a direction")


# ── Named streams / probability rule ──

func test_chance_roll_boundaries_are_deterministic() -> void:
	var zero_rng := RngService.new(777).stream(RngService.STREAM_EXPLORATION, "boundary:zero")
	for _index in 100:
		assert_false(ExplorationRules.roll_succeeds(zero_rng, 0.0), "chance 0 never triggers")
	var one_rng := RngService.new(777).stream(RngService.STREAM_EXPLORATION, "boundary:one")
	for _index in 100:
		assert_true(ExplorationRules.roll_succeeds(one_rng, 1.0), "chance 1 always triggers")
	# Same seed + same key reproduces the same decision sequence.
	var first: Array = []
	var first_rng := RngService.new(424242).stream(RngService.STREAM_EXPLORATION, "boundary:series")
	for _index in 12:
		first.append(ExplorationRules.roll_succeeds(first_rng, 0.5))
	var second: Array = []
	var second_rng := RngService.new(424242).stream(RngService.STREAM_EXPLORATION, "boundary:series")
	for _index in 12:
		second.append(ExplorationRules.roll_succeeds(second_rng, 0.5))
	assert_eq(first, second, "the exploration stream is reproducible for the same seed/key")


func test_on_arrival_rumour_is_reproducible() -> void:
	var context_a := _start_run(SEED)
	var context_b := _start_run(SEED)
	var found_a := {}
	var found_b := {}
	for step in 20:
		context_a.state.set_now(float(step))
		context_b.state.set_now(float(step))
		var result_a := ClueService.on_arrival(context_a)
		var result_b := ClueService.on_arrival(context_b)
		if not result_a.is_empty() or not result_b.is_empty():
			found_a = result_a
			found_b = result_b
			break
	assert_false(found_a.is_empty(), "a rumour should appear within 20 arrival rolls")
	assert_false(found_b.is_empty(), "the same seed must produce the same rumour")
	if found_a.is_empty() or found_b.is_empty():
		return
	assert_eq(found_a.get("clue", {}), found_b.get("clue", {}),
		"same seed + same state must produce the identical clue")
	var events: Array = found_a.get("events", [])
	assert_true(events.size() >= 1, "acquiring a clue emits clue.acquired")
	if events.size() >= 1:
		assert_eq(String((events[0] as Dictionary).get("type", "")), "clue.acquired",
			"the event type is clue.acquired")


# ── clue.buy gates ──

func test_buy_requires_intel_facility() -> void:
	var context := _start_run(SEED)
	_remove_facility(context, "intel")
	var money_before := context.state.money()
	var result := context.commands.execute(&"clue.buy", {})
	assert_false(bool(result.get("ok", true)), "buying without an intel facility must fail")
	assert_eq(String(result.get("error_code", "")), "no_intel_facility", "the failure names the facility gate")
	assert_eq(context.state.money(), money_before, "a refused purchase never charges money")


func test_buy_requires_money() -> void:
	var context := _start_run(SEED)
	_add_facility(context, "intel")
	context.state.set_money(0)
	var result := context.commands.execute(&"clue.buy", {})
	assert_false(bool(result.get("ok", true)), "buying with no money must fail")
	assert_eq(String(result.get("error_code", "")), "insufficient_money", "the failure names the money gate")
	assert_eq(ClueService.active(context.state).size(), 0, "no clue is added for free")
	assert_eq(context.state.money(), 0, "money stays untouched")


func test_buy_charges_gold_and_adds_intel_clue() -> void:
	var context := _start_run(SEED)
	# The starting iron harbour has no intel station; put one there so the purchase gate
	# (not the map layout) is what this test exercises.
	_add_facility(context, "intel")
	var rules := ExplorationRules.read(context.state, context.registries)
	var cost := int(rules.get("intel_clue_cost", 40))
	var money_before := context.state.money()
	var expense_before := int(context.state.stats().get("expense", 0))
	var result := context.commands.execute(&"clue.buy", {})
	assert_true(bool(result.get("ok", false)), "buying intel at a port with the facility succeeds")
	if not bool(result.get("ok", false)):
		return
	var data: Dictionary = result.get("data", {})
	assert_eq(int(data.get("cost", 0)), cost, "the charged cost comes from the map profile")
	assert_eq(context.state.money(), money_before - cost, "money is deducted")
	assert_eq(int(context.state.stats().get("expense", 0)), expense_before + cost, "the purchase is recorded as an expense")
	var active := ClueService.active(context.state)
	assert_eq(active.size(), 1, "one clue became active")
	if active.is_empty():
		return
	var clue: Dictionary = active[0]
	assert_eq(String(clue.get("source_key", "")), "intel", "bought clues are intel clues")
	assert_true(int(clue.get("level", 0)) >= 2, "bought intel reveals at least a direction")
	var events: Array = result.get("events", [])
	assert_true(_has_event(events, "clue.acquired"), "the purchase emits clue.acquired")
	var notices: Array = context.state.recent_notices(4)
	assert_true(_has_notice(notices, "ui.notice.clue_acquired"), "the purchase pushes a notice")


func test_buy_is_blocked_by_the_active_clue_cap() -> void:
	var context := _start_run(SEED)
	_add_facility(context, "intel")
	var rules := ExplorationRules.read(context.state, context.registries)
	var cap := int(rules.get("max_active_clues", 4))
	var target := _first_target(context)
	assert_false(target.is_empty(), "the run needs an undiscovered target")
	if target.is_empty():
		return
	# Explicit targets may repeat, so the cap can be filled even when the world has fewer
	# than `cap` hidden harbours.
	for index in cap:
		var clue := _acquire(context, "rumor", target)
		assert_false(clue.is_empty(), "filling clue slot %d succeeds" % index)
	assert_eq(ClueService.active(context.state).size(), cap, "the active log is full")
	var money_before := context.state.money()
	var result := context.commands.execute(&"clue.buy", {})
	assert_false(bool(result.get("ok", true)), "buying above the cap must fail")
	assert_eq(String(result.get("error_code", "")), "clue_limit", "the failure names the cap")
	assert_eq(context.state.money(), money_before, "no money is spent when the buy is refused")


# ── explore.start ──

func test_explore_start_deducts_resources_and_marks_at_sea() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	var clue_id := String(clue.get("id", ""))
	var preview_result := ExplorationCalculator.preview(context, clue_id, STRATEGY_ID)
	assert_true(bool(preview_result.get("ok", false)), "preview should succeed at a harbour")
	if not bool(preview_result.get("ok", false)):
		return
	var preview: Dictionary = preview_result.get("data", {})
	assert_true(bool(preview.get("feasible", false)), "a fresh run can afford the exploration")
	var money_before := context.state.money()
	var coal_before := float(context.state.ship().get("coal", 0.0))
	var water_before := float(context.state.ship().get("water", 0.0))
	var result := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_true(bool(result.get("ok", false)), "explore.start should succeed: %s" % str(result))
	if not bool(result.get("ok", false)):
		return
	var data: Dictionary = result.get("data", {})
	var result_preview: Dictionary = data.get("preview", {})
	var presentation: Dictionary = data.get("presentation", {})
	assert_eq(String(presentation.get("kind", "")), "explore", "presentation announces an exploration")
	assert_eq(String(presentation.get("clue_id", "")), clue_id, "presentation carries the clue id")
	assert_true(float(presentation.get("total_hours", 0.0)) > 0.0, "presentation carries the voyage duration")
	assert_true(float(presentation.get("arrival_time", 0.0)) > float(presentation.get("departure_time", 0.0)),
		"arrival is after departure")
	var route_path: Array = presentation.get("route_path", [])
	assert_true(route_path.size() >= 4 and route_path.size() % 2 == 0,
		"the route is a flat [x0,y0,...] path")
	assert_eq(typeof(presentation.get("alert_needed")), TYPE_BOOL, "alert_needed is a boolean")
	assert_eq(context.state.money(), money_before - int(result_preview.get("crew_wages", 0)),
		"wages are deducted")
	assert_almost_eq(
		float(context.state.ship().get("coal", 0.0)),
		maxf(0.0, coal_before - float(result_preview.get("coal_required", 0.0))),
		0.0001,
		"coal is consumed by the preview amount"
	)
	assert_almost_eq(
		float(context.state.ship().get("water", 0.0)),
		maxf(0.0, water_before - float(result_preview.get("water_required", 0.0))),
		0.0001,
		"water is consumed by the preview amount"
	)
	assert_false(context.state.is_at_port(), "the ship is no longer in port")
	var voyage_marker: Variant = context.state.data.get("voyage", null)
	assert_true(voyage_marker is Dictionary, "data.voyage carries the at-sea marker")
	if voyage_marker is Dictionary:
		assert_eq(String((voyage_marker as Dictionary).get("kind", "")), "explore", "the marker kind is explore")
	var explore_voyage: Variant = context.state.explore_voyage()
	assert_true(explore_voyage is Dictionary, "explore_voyage is written")
	if explore_voyage is Dictionary:
		assert_eq(String((explore_voyage as Dictionary).get("status", "")), "outbound", "the voyage is outbound")
		var roll := float((explore_voyage as Dictionary).get("outcome_roll", -1.0))
		assert_true(roll >= 0.0 and roll < 1.0, "the discovery roll is fixed in [0, 1)")
	assert_true(_has_event(result.get("events", []), "explore.started"), "explore.started is emitted")


func test_explore_start_infeasible_does_not_charge() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 0.0
	var money_before := context.state.money()
	var result := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_false(bool(result.get("ok", true)), "an unaffordable voyage must fail")
	assert_eq(String(result.get("error_code", "")), "explore_not_feasible", "the failure names feasibility")
	assert_eq(context.state.money(), money_before, "a refused start never charges wages")
	assert_true(context.state.is_at_port(), "the ship stays in port")
	assert_true(context.state.explore_voyage() == null, "no exploration voyage is written")
	assert_true(context.state.data.get("voyage", null) == null, "no at-sea marker is written")


func test_explore_start_twice_fails_with_already_exploring() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	var first := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_true(bool(first.get("ok", false)), "the first start succeeds")
	var second := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_false(bool(second.get("ok", true)), "starting a second exploration must fail")
	assert_eq(String(second.get("error_code", "")), "already_exploring", "the failure names the active voyage")


# ── explore.settle ──

func test_explore_settle_success_discovers_target() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	var target_id := String(clue.get("target_port_id", ""))
	assert_false(WorldOps.is_discovered(context.state, target_id), "target starts undiscovered")
	var started := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	if not bool(started.get("ok", false)):
		return
	var voyage: Dictionary = context.state.explore_voyage()
	voyage["outcome_roll"] = 0.0
	var voyages_before := int(context.state.stats().get("voyages", 0))
	var result := context.commands.execute(&"explore.settle", {})
	assert_true(bool(result.get("ok", false)), "explore.settle succeeds: %s" % str(result))
	if not bool(result.get("ok", false)):
		return
	var data: Dictionary = result.get("data", {})
	assert_eq(String(data.get("result", "")), "discovered", "the voyage discovered a harbour")
	assert_eq(String(data.get("destination", "")), target_id, "the destination is the clue target")
	assert_eq(context.state.current_port_id(), target_id, "the ship is now in the target harbour")
	assert_true(context.state.is_at_port(), "the ship is back at a port")
	assert_true(WorldOps.is_discovered(context.state, target_id), "the coordinate world learned the harbour")
	assert_true(WorldOps.is_visited(context.state, target_id), "the coordinate world records the visit")
	assert_true(MapOps.is_discovered(context.state, target_id), "the played map learned the harbour too")
	var world := WorldOps.world_map(context.state)
	assert_true(FogOps.is_position_visible(context.state, world.get_port(target_id).position),
		"the berth's fog is revealed")
	assert_false(_active_has(context, clue_id), "the clue left the active log")
	assert_true(Array(context.state.ensure_clues().get("resolved", [])).has(clue_id), "the clue is resolved")
	assert_true(context.state.explore_voyage() == null, "explore_voyage is cleared")
	assert_true(context.state.data.get("voyage", null) == null, "the at-sea marker is cleared")
	assert_eq(int(context.state.stats().get("voyages", 0)), voyages_before + 1, "one voyage was counted")
	var summary: Dictionary = data.get("summary", {})
	var explore_summary: Dictionary = summary.get("explore", {})
	assert_eq(String(explore_summary.get("result", "")), "discovered", "summary.explore reports the discovery")
	assert_eq(String(explore_summary.get("port_id", "")), target_id, "summary.explore names the harbour")
	assert_true(_has_event(result.get("events", []), "explore.finished"), "explore.finished is emitted")
	assert_true(_has_notice(context.state.recent_notices(6), "ui.notice.exploration_found"),
		"the discovery is announced")


func test_explore_settle_failure_drifts_to_nearest_discovered_port() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	var origin := context.state.current_port_id()
	var started := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	if not bool(started.get("ok", false)):
		return
	var voyage: Dictionary = context.state.explore_voyage()
	voyage["outcome_roll"] = 1.0
	var arrival_time := float(voyage.get("arrival_time", 0.0))
	var durability_before := float(context.state.ship().get("durability", 0.0))
	var coal_before := float(context.state.ship().get("coal", 0.0))
	var water_before := float(context.state.ship().get("water", 0.0))
	var result := context.commands.execute(&"explore.settle", {})
	assert_true(bool(result.get("ok", false)), "settle still succeeds as a command")
	if not bool(result.get("ok", false)):
		return
	var data: Dictionary = result.get("data", {})
	assert_eq(String(data.get("result", "")), "failed", "the voyage failed to find the harbour")
	assert_eq(String(data.get("destination", "")), origin,
		"drifting falls back to the nearest discovered harbour (the origin)")
	assert_eq(context.state.current_port_id(), origin, "the ship drifted back into the origin harbour")
	assert_true(context.state.is_at_port(), "the ship is at a port again")
	assert_true(_failed_has(context, clue_id), "the clue is marked failed but kept")
	assert_false(_active_has(context, clue_id), "the failed clue is no longer active")
	assert_true(context.state.explore_voyage() == null, "explore_voyage is cleared")
	var summary: Dictionary = data.get("summary", {})
	var explore_summary: Dictionary = summary.get("explore", {})
	assert_eq(String(explore_summary.get("result", "")), "failed", "summary.explore reports the failure")
	assert_almost_eq(float(explore_summary.get("durability_loss", 0.0)), 8.0, 0.0001,
		"drifting costs the rule's durability loss")
	assert_almost_eq(float(context.state.ship().get("durability", 0.0)), durability_before - 8.0, 0.0001,
		"durability is deducted")
	assert_almost_eq(float(explore_summary.get("extra_coal", 0.0)), minf(4.0, coal_before), 0.0001,
		"drift coal is the rule value, clamped to the stock")
	assert_almost_eq(float(explore_summary.get("extra_water", 0.0)), minf(4.0, water_before), 0.0001,
		"drift water is the rule value, clamped to the stock")
	assert_almost_eq(float(summary.get("arrival_time", 0.0)), arrival_time + 6.0, 0.0001,
		"drifting adds the rule's extra hours")
	assert_almost_eq(float(summary.get("delayed_hours", 0.0)), 6.0, 0.0001, "summary reports the delay")
	assert_true(_has_notice(context.state.recent_notices(6), "ui.notice.exploration_failed"),
		"the failure is announced")


func test_explore_settle_without_a_voyage_fails() -> void:
	var context := _start_run(SEED)
	var result := context.commands.execute(&"explore.settle", {})
	assert_false(bool(result.get("ok", true)), "settling without a voyage must fail")
	assert_eq(String(result.get("error_code", "")), "not_exploring", "the failure names the missing voyage")


## 4.2 S3：探索入港与普通抵达跑同一套到港服务（委托 / 市场记忆 / NPC / 债务 /
## 委托刷新 / 统计 / 自动存档），而不是"只解锁一个港口"。
func test_explore_settle_runs_arrival_services_and_autosaves() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var target := String(clue.get("target_port_id", ""))
	var started := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	# 让主线委托的目的地正好是被发现的港口：探索发现也应该能完成委托。
	context.state.data["contracts"]["main"]["destination"] = target
	context.state.explore_voyage()["outcome_roll"] = 0.0
	var voyages_before := int(context.state.stats().get("voyages", 0))
	var result := context.commands.execute(&"explore.settle", {})
	assert_true(bool(result.get("ok", false)), "explore.settle succeeds")
	if not bool(result.get("ok", false)):
		return
	var summary: Dictionary = result.get("data", {}).get("summary", {})
	assert_eq((summary.get("contracts", []) as Array).size() >= 1, true,
		"the discovered harbour completes a contract that targets it")
	assert_true(bool(summary.get("offers_refreshed", false)),
		"the arrival refreshes the normal offer pool")
	assert_true(MarketMemoryService.has_memory(context.state, target),
		"the discovered harbour gets a market-memory snapshot")
	assert_eq(int(context.state.stats().get("voyages", 0)), voyages_before + 1,
		"the exploration leg is counted exactly once")
	assert_true(bool(result.get("autosave", false)),
		"the exploration settlement requests an autosave like a normal arrival")


## 失败漂流到的也是真实港口，到港服务与统计同样要跑（委托是否完成由目的地匹配决定）。
func test_explore_failure_settle_runs_arrival_services() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var started := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	context.state.explore_voyage()["outcome_roll"] = 0.999
	var voyages_before := int(context.state.stats().get("voyages", 0))
	var result := context.commands.execute(&"explore.settle", {})
	assert_true(bool(result.get("ok", false)), "explore.settle succeeds")
	if not bool(result.get("ok", false)):
		return
	var summary: Dictionary = result.get("data", {}).get("summary", {})
	assert_eq(String((summary.get("explore", {}) as Dictionary).get("result", "")), "failed",
		"a high roll fails the search")
	assert_true(bool(summary.get("offers_refreshed", false)),
		"the drift harbour still refreshes its offer pool")
	assert_eq(int(context.state.stats().get("voyages", 0)), voyages_before + 1,
		"a failed exploration still counts as one voyage")
	assert_true(bool(result.get("autosave", false)),
		"a failed exploration settlement is autosaved")


## 掉头返航同样是真实入港：到港服务、统计与自动存档都要发生，只是没有发现。
func test_turn_back_runs_arrival_services_and_autosaves() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var origin := context.state.current_port_id()
	var started := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	var voyages_before := int(context.state.stats().get("voyages", 0))
	var result := context.commands.execute(&"explore.decide", {"choice": "turn_back"})
	assert_true(bool(result.get("ok", false)), "turning back succeeds")
	if not bool(result.get("ok", false)):
		return
	var summary: Dictionary = result.get("data", {}).get("summary", {})
	assert_true(bool(summary.get("offers_refreshed", false)),
		"arriving back at the origin refreshes the offer pool")
	assert_eq(int(context.state.stats().get("voyages", 0)), voyages_before + 1,
		"the aborted exploration still counts as one voyage")
	assert_true(MarketMemoryService.has_memory(context.state, origin),
		"the origin harbour gets a market-memory snapshot on return")
	assert_true(bool(result.get("autosave", false)),
		"turning back requests an autosave like a normal arrival")


# ── explore.decide ──

func test_turn_back_returns_to_origin_and_keeps_clue_active() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	var origin := context.state.current_port_id()
	var started := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	if not bool(started.get("ok", false)):
		return
	var voyage: Dictionary = context.state.explore_voyage()
	var coal_after_start := float(context.state.ship().get("coal", 0.0))
	var water_after_start := float(context.state.ship().get("water", 0.0))
	var departure_time := float(voyage.get("departure_time", 0.0))
	var duration := float(voyage.get("duration_hours", 0.0))
	var result := context.commands.execute(&"explore.decide", {"choice": "turn_back"})
	assert_true(bool(result.get("ok", false)), "turning back succeeds: %s" % str(result))
	if not bool(result.get("ok", false)):
		return
	var data: Dictionary = result.get("data", {})
	assert_true(bool(data.get("returned", false)), "the result flags a return")
	assert_eq(String(data.get("destination", "")), origin, "the destination is the origin harbour")
	assert_eq(context.state.current_port_id(), origin, "the ship is back at the origin")
	assert_true(context.state.is_at_port(), "the ship is in port")
	assert_true(context.state.explore_voyage() == null, "explore_voyage is cleared")
	assert_true(context.state.data.get("voyage", null) == null, "the at-sea marker is cleared")
	assert_true(_active_has(context, clue_id), "the clue stays active after turning back")
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)),
		maxf(0.0, coal_after_start - float(voyage.get("coal_used", 0.0)) * 0.25), 0.0001,
		"turning back burns 25% of the voyage coal again")
	assert_almost_eq(float(context.state.ship().get("water", 0.0)),
		maxf(0.0, water_after_start - float(voyage.get("water_used", 0.0)) * 0.25), 0.0001,
		"turning back burns 25% of the voyage water again")
	assert_true(context.state.now() >= departure_time + duration * 0.5 - 0.0001,
		"the clock advances half the voyage")
	var summary: Dictionary = data.get("summary", {})
	assert_eq(String((summary.get("explore", {}) as Dictionary).get("result", "")), "turned_back",
		"summary reports the turn-back")
	assert_true(_has_notice(context.state.recent_notices(6), "ui.notice.exploration_turned_back"),
		"the turn-back is announced")


func test_continue_keeps_sailing_and_marks_the_alert() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var started := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	var result := context.commands.execute(&"explore.decide", {"choice": "continue"})
	assert_true(bool(result.get("ok", false)), "continuing succeeds")
	assert_false(context.state.is_at_port(), "the ship keeps sailing")
	var voyage: Dictionary = context.state.explore_voyage()
	assert_eq(String(voyage.get("alert_decided", "")), "continue", "the alert decision is recorded")
	assert_almost_eq(float(voyage.get("alert_progress", 0.0)), 1.0, 0.0001,
		"the acknowledged alert is marked complete")


## 4.2 资源告急：出发时按 Core 的 `alert_threshold` 判断，决策点比例来自
## `alert_progress`；两者都进 `presentation`，Shell 用它在航程中途停下。
func test_alert_threshold_and_progress_come_from_the_rules() -> void:
	var normal_context := _start_run(SEED)
	var normal_clue := _acquire(normal_context, "intel")
	var normal_start := normal_context.commands.execute(&"explore.start", {
		"clue_id": String(normal_clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(normal_start.get("ok", false)), "a full hold does not block departure")
	var normal_voyage: Dictionary = normal_context.state.explore_voyage()
	assert_false(bool(normal_voyage.get("alert_needed", true)),
		"a well-stocked hold does not trigger the resource alert")

	# 只留"刚够本程 + 5%"的煤：这一程必然烧掉出发存量的一半以上 → 触发告急。
	var low_context := _start_run(SEED)
	var clue := _acquire(low_context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var preview_result := ExplorationCalculator.preview(
		low_context, String(clue.get("id", "")), STRATEGY_ID
	)
	assert_true(bool(preview_result.get("ok", false)), "the clue preview succeeds")
	var coal_required := float((preview_result.get("data", {}) as Dictionary).get("coal_required", 0.0))
	low_context.state.ship()["coal"] = coal_required * 1.05
	var started := low_context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(started.get("ok", false)), "a half-empty hold still allows departure")
	if not bool(started.get("ok", false)):
		return
	var voyage: Dictionary = low_context.state.explore_voyage()
	var rules := ExplorationRules.read(low_context.state, low_context.registries)
	assert_true(bool(voyage.get("alert_needed", false)),
		"burning more than half of the departure coal raises the alert")
	assert_almost_eq(float(voyage.get("alert_progress", 0.0)), float(rules["alert_progress"]), 0.0001,
		"the decision point comes from the Core rule, not a hardcoded 0")
	var presentation: Dictionary = (started.get("data", {}) as Dictionary).get("presentation", {})
	assert_true(bool(presentation.get("alert_needed", false)), "the presentation carries the alert flag")
	assert_almost_eq(float(presentation.get("alert_progress", 0.0)), float(rules["alert_progress"]), 0.0001,
		"the presentation carries the decision point for the演出")


## 决策只能回答一次：重复 continue 会给出明确的错误，而不是静默地再扣一次状态。
func test_continue_cannot_answer_the_alert_twice() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var started := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	var first := context.commands.execute(&"explore.decide", {"choice": "continue"})
	assert_true(bool(first.get("ok", false)), "the first answer is accepted")
	assert_true(float(((first.get("data", {}) as Dictionary).get("remaining_hours", 0.0))) > 0.0,
		"the continue result reports the remaining voyage")
	var second := context.commands.execute(&"explore.decide", {"choice": "continue"})
	assert_false(bool(second.get("ok", false)), "answering the alert twice is rejected")
	assert_eq(String(second.get("error_code", "")), "alert_already_decided",
		"the rejection names the duplicate answer")
	assert_eq(String(second.get("message_key", "")), "ui.error.alert_already_decided",
		"the rejection has a localized message key")


## 海图查询在探索途中要暴露告警状态，海图/顶栏才能显示正确的阶段。
func test_chart_view_exposes_alert_state_while_exploring() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var preview := ExplorationCalculator.preview(context, String(clue.get("id", "")), STRATEGY_ID)
	var coal_required := float((preview.get("data", {}) as Dictionary).get("coal_required", 0.0))
	context.state.ship()["coal"] = coal_required * 1.05
	var started := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	var explore: Dictionary = _chart_vm(context).get("explore", {})
	assert_true(bool(explore.get("active", false)), "the chart reports the active exploration")
	assert_true(bool(explore.get("alert_needed", false)), "the chart reports the pending alert")
	assert_true(float(explore.get("alert_progress", 0.0)) > 0.0
		and float(explore.get("alert_progress", 0.0)) < 1.0,
		"the chart reports the decision point before it is answered")
	assert_eq(String(explore.get("alert_decided", "")), "", "nothing is decided yet")


# ── sea_chart.view ──
func test_sea_chart_view_exposes_clues_explore_and_buy_state() -> void:
	var context := _start_run(SEED)
	var vm := _chart_vm(context)
	var no_intel: Dictionary = vm.get("can_buy_clue", {})
	assert_false(bool(no_intel.get("available", true)), "the iron start harbour has no intel station")
	assert_eq(String(no_intel.get("reason_key", "")), "ui.error.no_intel_facility",
		"the buy reason names the missing facility")
	_add_facility(context, "intel")
	vm = _chart_vm(context)
	var can_buy: Dictionary = vm.get("can_buy_clue", {})
	assert_true(bool(can_buy.get("available", false)), "with an intel station the buy is available")
	assert_eq(int(can_buy.get("cost", 0)), 40, "the buy cost comes from the map profile")
	assert_eq(String(can_buy.get("reason_key", "")), "", "an available buy has no reason key")
	assert_eq((vm.get("clues", []) as Array).size(), 0, "a fresh run has no clues")
	assert_false(bool((vm.get("explore", {}) as Dictionary).get("active", true)), "not exploring yet")

	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	vm = _chart_vm(context)
	var clues: Array = vm.get("clues", [])
	assert_eq(clues.size(), 1, "the active clue shows up on the chart")
	if clues.is_empty():
		return
	var entry: Dictionary = clues[0]
	assert_eq(String(entry.get("id", "")), clue_id, "the chart view carries the clue id")
	assert_false(entry.has("target_port_id"), "the chart view never leaks the target port")
	assert_false(entry.has("credibility"), "the chart view never leaks credibility")
	var estimated: Dictionary = entry.get("estimated", {})
	assert_true(bool(estimated.get("feasible", false)), "a fresh run can afford the clue voyage")
	assert_true(float(estimated.get("duration_hours", 0.0)) > 0.0, "the estimate carries a duration")
	var rules := ExplorationRules.read(context.state, context.registries)
	var expected_chance := ExplorationRules.discovery_chance(rules, float(clue.get("credibility", 0.0)))
	assert_almost_eq(float(estimated.get("discovery_chance", -1.0)), expected_chance, 0.0001,
		"the displayed discovery chance is the rule function of credibility")

	var started := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	vm = _chart_vm(context)
	var explore: Dictionary = vm.get("explore", {})
	assert_true(bool(explore.get("active", false)), "the chart reports an active exploration")
	assert_eq(String(explore.get("clue_id", "")), clue_id, "the chart names the active clue")
	var at_sea_buy: Dictionary = vm.get("can_buy_clue", {})
	assert_false(bool(at_sea_buy.get("available", true)), "clues cannot be bought at sea")
	assert_eq(String(at_sea_buy.get("reason_key", "")), "ui.error.not_at_port",
		"the reason is that the ship is not in port")


# ── Rules / save round-trip ──

func test_rules_are_read_from_the_core_map_profile() -> void:
	var context := _start_run(SEED)
	var rules := ExplorationRules.read(context.state, context.registries)
	assert_almost_eq(float(rules.get("rumor_clue_chance", -1.0)), 0.65, 0.0001,
		"rumour chance comes from dev_mods/core/content/map_profiles.json")
	assert_eq(int(rules.get("intel_clue_cost", 0)), 40, "intel clue cost comes from Core JSON")
	assert_eq(int(rules.get("max_active_clues", 0)), 4, "the clue cap comes from Core JSON")
	assert_almost_eq(float(rules.get("search_zone_radius", 0.0)), 14.0, 0.0001, "zone radius from Core JSON")
	assert_almost_eq(float(rules.get("turnback_extra_ratio", 0.0)), 0.25, 0.0001, "turn-back ratio from Core JSON")
	var intel_weights: Array = (rules.get("level_weights", {}) as Dictionary).get("intel", [])
	assert_eq(intel_weights.size(), 4, "level weights are the four-level vector")
	assert_almost_eq(float(intel_weights[3]) if intel_weights.size() >= 4 else -1.0, 0.40, 0.0001,
		"intel has a 40% chance of a level-4 name clue")


func test_game_state_backfills_the_clue_block_lazily() -> void:
	var state := GameState.new()
	state.data = {"schema_version": "2.0"}
	var hash_before := state.hash()
	var clues_data := state.clues()
	assert_eq(int(clues_data.get("next_id", 0)), 1, "next_id starts at 1")
	assert_eq((clues_data.get("active", null) as Array).size(), 0, "active starts empty")
	assert_eq((clues_data.get("failed", null) as Array).size(), 0, "failed starts empty")
	assert_eq((clues_data.get("resolved", null) as Array).size(), 0, "resolved starts empty")
	assert_eq(state.schema_version(), "2.0", "backfill never bumps schema_version")
	assert_true(state.explore_voyage() == null, "no exploration voyage on a fresh state")
	var hash_after := state.hash()
	assert_ne(hash_after, hash_before, "the first access backfills the block")
	assert_eq(state.hash(), hash_after, "later accesses are idempotent")


func test_save_load_roundtrip_preserves_exploration_state() -> void:
	var context := _start_run(SEED, {
		"save_directory": "user://test_saves/exploration_%d" % Time.get_ticks_usec(),
	})
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var started := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": STRATEGY_ID,
	})
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	var before := context.state.hash()
	var saved := context.save.save_slot("manual", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "saving an exploration state succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("manual")
	assert_true(bool(loaded.get("ok", false)), "loading the exploration state succeeds")
	var loaded_state: GameState = loaded.get("state", null)
	assert_not_null(loaded_state, "the loaded state exists")
	if loaded_state == null:
		return
	assert_eq(loaded_state.hash(), before, "state hash is identical after loading")
	var loaded_clues := loaded_state.ensure_clues()
	assert_eq((loaded_clues.get("active", []) as Array).size(), 1, "the active clue survived the round-trip")
	assert_true(loaded_state.explore_voyage() is Dictionary, "the exploration voyage survived the round-trip")
	assert_eq(String((loaded_state.data.get("voyage", {}) as Dictionary).get("kind", "")), "explore",
		"the at-sea marker survived the round-trip")


# ── Helpers ──

func _start_run(seed_value: int, extra: Dictionary = {}) -> AppContext:
	var boot := bootstrap_core(extra)
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": seed_value})
	assert_true(bool(result.get("ok", false)), "run.start should succeed: %s" % str(result))
	return context


## Builds a clue through the real service with a unique named stream, so repeated calls
## never share RNG state. Explicit targets skip the undiscovered-target filter.
func _acquire(context: AppContext, source: String = "intel", target_port_id: String = "") -> Dictionary:
	_stream_serial += 1
	var rng := context.rng.make_stream(RngService.STREAM_EXPLORATION, "test:%d" % _stream_serial)
	return ClueService.acquire(context, source, rng, target_port_id)


func _chart_vm(context: AppContext) -> Dictionary:
	var result := SeaChartViewQuery.execute({"strategy_id": STRATEGY_ID}, context)
	assert_true(bool(result.get("ok", false)), "sea_chart.view should succeed")
	return result.get("data", {})


func _first_target(context: AppContext) -> String:
	var targets := ClueService.eligible_target_ids(context.state)
	return String(targets[0]) if not targets.is_empty() else ""


func _add_facility(context: AppContext, facility: String) -> void:
	var port_data := MapOps.port(context.state.world(), context.state.current_port_id())
	var facilities: Array = port_data.get("facilities", [])
	if not facilities.has(facility):
		facilities.append(facility)


func _remove_facility(context: AppContext, facility: String) -> void:
	var port_data := MapOps.port(context.state.world(), context.state.current_port_id())
	var facilities: Array = port_data.get("facilities", [])
	facilities.erase(facility)


func _active_has(context: AppContext, clue_id: String) -> bool:
	return not ClueService.find_clue(context.state, clue_id).is_empty()


func _failed_has(context: AppContext, clue_id: String) -> bool:
	return Array(context.state.ensure_clues().get("failed", [])).has(clue_id)


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and String((event as Dictionary).get("type", "")) == event_type:
			return true
	return false


func _has_notice(notices: Array, text_key: String) -> bool:
	for notice in notices:
		if notice is Dictionary and String((notice as Dictionary).get("text_key", "")) == text_key:
			return true
	return false
