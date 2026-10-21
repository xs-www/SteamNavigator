extends TestCase
## @static-doc
## 作用：探索系统（阶段 4.1–4.4）领域层无头测试：线索生成 / 固定 1 级 / 逐级调查
## （`clue.investigate`）/ 分级裁剪 / 命名流复现、`clue.buy` 门禁、`explore.start`
## 扣费与在航标记、`explore.settle` 成功发现与失败漂流、`explore.decide` 掉头 / 继续、
## `sea_chart.view` 的线索 / 探索 / 购买视图、4.4 货物行情线索（冻结快照 / 时效 /
## `clue.list` / 旧存档 normalize），以及存档往返。
##
## ## 契约与约束
## - 每个用例用 `bootstrap_core()` + `run.start` 拿真实 Core 注册表与真实对局；
##   线索一律通过 `ClueService.acquire` 构造（不依赖随机成功），需要固定等级/可信度时
##   才在构造后改写测试用的字段。
## - 4.3.2 / U2：`acquire` 不再抽等级，新线索必为 1 级；升级只能走 `clue.investigate`
##   （在港、active、上限 4）。目标港 / 搜索区 / 可信度在获得时固定，调查只逐级披露；
##   测试逐次记录这些字段并断言不变。
## - 概率用例直接验证 `ExplorationRules.roll_succeeds` 的 0 / 1 边界与固定 seed 复现；
##   发现 / 未发现用出发时抽定的 `outcome_roll`（契约 §2）强制，而不是依赖真实随机。
## - 4.3.5 / U8：探索出航只扣工资，煤水库存留在船上（`departure_coal/water` +
##   `coal_rate/water_rate` 记入航次与 presentation）；结算按实际航行小时一次性扣款
##   （成功 arrival-departure、失败 duration+drift、掉头 duration/2，额外损耗另计）。
##   用例断言出发库存不变、各路径的实际扣减与告警仍按出发库存预判。
## - 断言取值遵守契约 §3 的 Core 数值（40 金币、漂流 6h、额外煤水 4、耐久 8 等），
##   避免测试与内容 JSON 脱节。
## @end-static-doc

const SEED := 20260421
const STRATEGY_ID := "core:strategy/standard"

var _stream_serial := 0


# ── Clue generation ──

## 4.3.2 / U2：`acquire` 不再用 `level_weights` 抽等级 —— 无论来源，新线索必为 1 级；
## 可信度仍按来源区间抽取。`level_weights` 保留在内容里供后续线索系统使用。
func test_acquire_always_starts_at_level_one_and_credibility_stays_in_source_ranges() -> void:
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
			# 4.3.2 / U2：等级不再随机，获得时固定 1 级（逐级披露由 investigate 推进）。
			assert_eq(int(clue.get("level", 0)), 1,
				"a %s clue always starts at level 1" % source)
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


# ── Clue investigation (4.3.2 / U2) ──

## 获得必为 1 级；连续调查 3 次依次到 2/3/4；每次调查只披露、不重抽目标港 / 搜索区 /
## 可信度 / 方向 / 航程区间，也不扣钱 / 不推进时间；4 级后再调查返回明确错误；
## 查询裁剪逐级正确（方向 >=2、圆圈 >=3、名称 ==4）。
func test_investigate_climbs_to_level_four_without_rerolling_the_target() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	var target := String(clue.get("target_port_id", ""))
	var reference := String(clue.get("reference_port_id", ""))
	var direction := float(clue.get("direction_angle", 0.0))
	var credibility := float(clue.get("credibility", 0.0))
	var min_hours := float(clue.get("distance_min_hours", 0.0))
	var max_hours := float(clue.get("distance_max_hours", 0.0))
	var zone: Dictionary = clue.get("search_zone", {})
	var zone_x := float(zone.get("x", 0.0))
	var zone_y := float(zone.get("y", 0.0))
	var zone_radius := float(zone.get("radius", 0.0))
	var rules := ExplorationRules.read(context.state, context.registries)
	var money_before := context.state.money()
	var time_before := context.state.now()
	assert_eq(int(clue.get("level", 0)), 1, "a new clue starts at level 1")
	for expected_level: int in [2, 3, 4]:
		var result := context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
		assert_true(bool(result.get("ok", false)),
			"investigating to level %d succeeds: %s" % [expected_level, str(result)])
		if not bool(result.get("ok", false)):
			return
		var data: Dictionary = result.get("data", {})
		assert_eq(int(data.get("level", 0)), expected_level,
			"the command reports level %d" % expected_level)
		var expected_next := expected_level + 1 if expected_level < 4 else 0
		assert_eq(int(data.get("next_level", -1)), expected_next,
			"the command reports the next disclosure level")
		assert_eq(int(data.get("cost", -1)), int(rules.get("investigation_cost", 0)),
			"the investigation cost comes from the Core rules")
		assert_almost_eq(float(data.get("hours", -1.0)),
			float(rules.get("investigation_hours", 0.0)), 0.0001,
			"the investigation hours come from the Core rules")
		var view: Dictionary = data.get("view", {})
		assert_eq(int(view.get("level", 0)), expected_level,
			"the returned view is trimmed to the new level")
		assert_false(view.has("target_port_id"), "the view never leaks the target")
		assert_false(view.has("credibility"), "the view never leaks credibility")
		assert_false(view.has("search_zone"), "the view never leaks the search zone")
		# 命令在事务克隆上执行，成功后提交会替换状态；每次重新取线索再断言字段固定。
		var current := ClueService.find_clue(context.state, clue_id)
		assert_false(current.is_empty(), "the clue stays active after investigating")
		if current.is_empty():
			return
		assert_eq(String(current.get("target_port_id", "")), target,
			"the target port never changes")
		assert_eq(String(current.get("reference_port_id", "")), reference,
			"the reference port never changes")
		assert_almost_eq(float(current.get("direction_angle", 0.0)), direction, 0.0001,
			"the direction stays fixed")
		assert_almost_eq(float(current.get("credibility", 0.0)), credibility, 0.0001,
			"credibility stays fixed")
		var current_zone: Dictionary = current.get("search_zone", {})
		assert_almost_eq(float(current_zone.get("x", 0.0)), zone_x, 0.0001,
			"the search-zone centre x stays fixed")
		assert_almost_eq(float(current_zone.get("y", 0.0)), zone_y, 0.0001,
			"the search-zone centre y stays fixed")
		assert_almost_eq(float(current_zone.get("radius", 0.0)), zone_radius, 0.0001,
			"the search-zone radius stays fixed")
		assert_almost_eq(float(current.get("distance_min_hours", 0.0)), min_hours, 0.0001,
			"the distance range stays fixed")
		assert_almost_eq(float(current.get("distance_max_hours", 0.0)), max_hours, 0.0001,
			"the distance range stays fixed")
		assert_eq(int(current.get("level", 0)), expected_level,
			"only the level changed")
		# 4.3 不做资源判定：金币 / 时间都不动。
		assert_eq(context.state.money(), money_before, "4.3 investigations never charge money")
		assert_almost_eq(context.state.now(), time_before, 0.0001,
			"4.3 investigations never advance time")
		# 领域事件只带 clue_id + level（不含目标港 / credibility / search_zone）。
		var events: Array = result.get("events", [])
		assert_true(_has_event(events, "clue.investigated"), "investigating emits clue.investigated")
		for event in events:
			if not (event is Dictionary):
				continue
			if String((event as Dictionary).get("type", "")) != "clue.investigated":
				continue
			var payload: Dictionary = (event as Dictionary).get("payload", {})
			assert_eq(String(payload.get("clue_id", "")), clue_id, "the event names the clue")
			assert_eq(int(payload.get("level", 0)), expected_level,
				"the event reports the new level")
			assert_eq(payload.size(), 2, "the event payload is only clue_id + level")
		# 查询按新等级披露。
		var entries: Array = _chart_vm(context).get("clues", [])
		assert_eq(entries.size(), 1, "the investigated clue is still on the chart")
		if entries.is_empty():
			continue
		var entry: Dictionary = entries[0]
		assert_eq(int(entry.get("level", 0)), expected_level, "the chart reports the new level")
		assert_false(entry.has("target_port_id"), "the chart view never leaks the target")
		assert_false(entry.has("credibility"), "the chart view never leaks credibility")
		assert_false(entry.has("search_zone"), "the chart view never leaks the true search zone")
		assert_almost_eq(float(entry.get("direction_angle", 0.0)), direction, 0.0001,
			"level %d keeps disclosing the fixed direction" % expected_level)
		assert_eq(entry.get("circle", null) != null, expected_level >= 3,
			"level %d circle disclosure" % expected_level)
		if expected_level >= 4:
			assert_eq(String(entry.get("name_key", "")),
				WorldOps.port_display_key(WorldOps.world_map(context.state), target),
				"level 4 discloses the target name key")
		else:
			assert_eq(String(entry.get("name_key", "")), "",
				"level %d must not disclose the name" % expected_level)
	# 4 级后再调查被明确拒绝，等级不再变化。
	var capped := context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
	assert_false(bool(capped.get("ok", true)), "investigating at level 4 fails")
	assert_eq(String(capped.get("error_code", "")), "clue_max_level",
		"the failure names the level cap")
	assert_eq(String(capped.get("message_key", "")), "ui.error.clue_max_level",
		"the level-cap failure has a localized key")
	assert_eq(int(ClueService.find_clue(context.state, clue_id).get("level", 0)), 4,
		"the level stays capped at 4")


## 门禁：无 run / 未知线索 / 已解决线索 / 不在港 都失败，且失败不改变等级。
func test_investigate_requires_a_run_a_port_and_an_active_clue() -> void:
	var no_run := bootstrap_core()
	var no_run_result: Dictionary = no_run["context"].commands.execute(
		&"clue.investigate", {"clue_id": "clue:1"}
	)
	assert_false(bool(no_run_result.get("ok", true)), "investigating without a run fails")
	assert_eq(String(no_run_result.get("error_code", "")), "no_run",
		"the failure names the missing run")

	var context := _start_run(SEED)
	var missing := context.commands.execute(&"clue.investigate", {"clue_id": "clue:missing"})
	assert_false(bool(missing.get("ok", true)), "investigating an unknown clue fails")
	assert_eq(String(missing.get("error_code", "")), "unknown_clue",
		"the failure names the missing clue")
	assert_eq(String(missing.get("message_key", "")), "ui.error.unknown_clue",
		"the missing-clue failure has a localized key")

	# 已解决 / 已作废的线索不在 active：给出「线索已失效」而不是「未知线索」。
	var resolved_clue := _acquire(context, "intel")
	assert_false(resolved_clue.is_empty(), "a clue is acquired for the resolved case")
	if not resolved_clue.is_empty():
		var resolved_id := String(resolved_clue.get("id", ""))
		ClueService.mark_resolved(context.state, resolved_id)
		var not_active := context.commands.execute(&"clue.investigate", {"clue_id": resolved_id})
		assert_false(bool(not_active.get("ok", true)), "investigating a resolved clue fails")
		assert_eq(String(not_active.get("error_code", "")), "clue_not_active",
			"the failure names the inactive clue")
		assert_eq(String(not_active.get("message_key", "")), "ui.error.clue_not_active",
			"the inactive-clue failure has a localized key")

	# 在航时不能调查；失败不改变等级。
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "a clue is acquired for the at-sea case")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	var started := context.commands.execute(
		&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID}
	)
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	var at_sea := context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
	assert_false(bool(at_sea.get("ok", true)), "investigating at sea fails")
	assert_eq(String(at_sea.get("error_code", "")), "not_at_port",
		"the failure names the port gate")
	assert_eq(String(at_sea.get("message_key", "")), "ui.error.not_at_port",
		"the at-sea failure has a localized key")
	assert_eq(int(ClueService.find_clue(context.state, clue_id).get("level", 0)), 1,
		"a refused investigation never changes the level")


## 查询暴露调查入口字段：成本 / 工时来自 Core（0）、在港且 <4 时 can_investigate、
## next_level / next_level_key 指向下一级披露；4 级时 next_level=0、key 为空；在航禁调查。
func test_chart_view_exposes_investigation_action_fields() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	var rules := ExplorationRules.read(context.state, context.registries)
	var entry := _first_clue_entry(context)
	assert_false(entry.is_empty(), "the clue reaches the chart view")
	if entry.is_empty():
		return
	assert_eq(int(entry.get("investigation_cost", -1)),
		int(rules.get("investigation_cost", 0)),
		"the investigation cost comes from the Core rules")
	assert_almost_eq(float(entry.get("investigation_hours", -1.0)),
		float(rules.get("investigation_hours", 0.0)), 0.0001,
		"the investigation hours come from the Core rules")
	assert_true(bool(entry.get("can_investigate", false)),
		"a level-1 clue in port can be investigated")
	assert_eq(int(entry.get("next_level", -1)), 2, "the next disclosure level is 2")
	assert_eq(String(entry.get("next_level_key", "")), "ui.clue.level.2",
		"the next disclosure key names level 2")

	# 调查到 3 级后：can_investigate 仍真，next_level = 4。
	context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
	context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
	entry = _first_clue_entry(context)
	assert_eq(int(entry.get("level", 0)), 3, "two investigations reach level 3")
	assert_true(bool(entry.get("can_investigate", false)), "level 3 can still be investigated")
	assert_eq(int(entry.get("next_level", -1)), 4, "the next disclosure level is 4")
	assert_eq(String(entry.get("next_level_key", "")), "ui.clue.level.4",
		"the next disclosure key names level 4")

	# 4 级：再无可披露的下一级。
	context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
	entry = _first_clue_entry(context)
	assert_eq(int(entry.get("level", 0)), 4, "three investigations reach level 4")
	assert_false(bool(entry.get("can_investigate", true)), "level 4 cannot be investigated further")
	assert_eq(int(entry.get("next_level", -1)), 0, "level 4 reports next_level 0")
	assert_eq(String(entry.get("next_level_key", "")), "", "level 4 has no next disclosure key")


## 在航时 can_investigate 为假（机制上 investigate 也会拒绝），但下一级预告仍在。
func test_chart_view_blocks_investigation_at_sea() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var started := context.commands.execute(
		&"explore.start", {"clue_id": String(clue.get("id", "")), "strategy_id": STRATEGY_ID}
	)
	assert_true(bool(started.get("ok", false)), "explore.start succeeds")
	var entry := _first_clue_entry(context)
	assert_false(entry.is_empty(), "the chased clue is still in the chart view")
	if entry.is_empty():
		return
	assert_false(bool(entry.get("can_investigate", true)), "clues cannot be investigated at sea")
	assert_eq(int(entry.get("next_level", -1)), 2,
		"the next disclosure is still reported while at sea")


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
	assert_eq(int(clue.get("level", 0)), 1, "bought intel also starts at level 1")
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

## 4.3.5 / U8：出发只扣工资——煤水库存原样留在船上，航次记录出发库存与每小时费率。
func test_explore_start_charges_only_wages_and_marks_at_sea() -> void:
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
	# 4.3.5 / U8：presentation 带出发库存与每小时费率，供 Shell 演出中插值读数。
	var presentation_hours := maxf(0.0001, float(presentation.get("total_hours", 0.0)))
	assert_almost_eq(float(presentation.get("departure_coal", -1.0)), coal_before, 0.0001,
		"presentation carries the departure coal stock")
	assert_almost_eq(float(presentation.get("departure_water", -1.0)), water_before, 0.0001,
		"presentation carries the departure water stock")
	assert_almost_eq(float(presentation.get("coal_rate", -1.0)),
		float(result_preview.get("coal_required", 0.0)) / presentation_hours, 0.0001,
		"the presentation coal rate is the planned burn per hour")
	assert_almost_eq(float(presentation.get("water_rate", -1.0)),
		float(result_preview.get("water_required", 0.0)) / presentation_hours, 0.0001,
		"the presentation water rate is the planned burn per hour")
	assert_eq(context.state.money(), money_before - int(result_preview.get("crew_wages", 0)),
		"wages are the only departure charge")
	# 4.3.5 / U8：出发不扣煤水（演出中顶栏插值，结算时按实际小时落账）。
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)), coal_before, 0.0001,
		"coal stays on board when the voyage starts")
	assert_almost_eq(float(context.state.ship().get("water", 0.0)), water_before, 0.0001,
		"water stays on board when the voyage starts")
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
		# 4.3.5 / U8：航次快照记录出发库存与每小时费率（结算按实际小时扣款）。
		assert_almost_eq(float((explore_voyage as Dictionary).get("departure_coal", -1.0)),
			coal_before, 0.0001, "the voyage records the departure coal stock")
		assert_almost_eq(float((explore_voyage as Dictionary).get("departure_water", -1.0)),
			water_before, 0.0001, "the voyage records the departure water stock")
		var voyage_hours := maxf(0.0001, float((explore_voyage as Dictionary).get("duration_hours", 0.0)))
		assert_almost_eq(float((explore_voyage as Dictionary).get("coal_rate", -1.0)),
			float(result_preview.get("coal_required", 0.0)) / voyage_hours, 0.0001,
			"the voyage coal rate comes from the preview burn / duration")
		assert_almost_eq(float((explore_voyage as Dictionary).get("water_rate", -1.0)),
			float(result_preview.get("water_required", 0.0)) / voyage_hours, 0.0001,
			"the voyage water rate comes from the preview burn / duration")
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
	# 4.3.5 / U8：出发不扣煤水，结算时按 `rate × 实际航行小时` 一次性扣。
	var coal_at_departure := float(context.state.ship().get("coal", 0.0))
	var water_at_departure := float(context.state.ship().get("water", 0.0))
	var coal_rate := float(voyage.get("coal_rate", 0.0))
	var water_rate := float(voyage.get("water_rate", 0.0))
	var voyage_hours := maxf(0.0, float(voyage.get("arrival_time", 0.0))
		- float(voyage.get("departure_time", 0.0)))
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
	# 4.3.5 / U8：抵达按实际航行小时扣煤水（出发时没扣过）。
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)),
		maxf(0.0, coal_at_departure - coal_rate * voyage_hours), 0.0001,
		"arrival deducts coal = hourly rate × actual hours")
	assert_almost_eq(float(context.state.ship().get("water", 0.0)),
		maxf(0.0, water_at_departure - water_rate * voyage_hours), 0.0001,
		"arrival deducts water = hourly rate × actual hours")
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
	var coal_rate := float(voyage.get("coal_rate", 0.0))
	var water_rate := float(voyage.get("water_rate", 0.0))
	var duration := float(voyage.get("duration_hours", 0.0))
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
	# 4.3 / U3：失败不消耗线索 —— 仍在 active，只记录尝试次数与时间。
	assert_true(_active_has(context, clue_id), "a failed clue stays in the active log")
	assert_false(_failed_has(context, clue_id), "a failed clue is not moved into the failed list")
	var kept_clue := ClueService.find_clue(context.state, clue_id)
	assert_eq(int(kept_clue.get("attempts", 0)), 1, "the failed attempt is counted")
	assert_almost_eq(float(kept_clue.get("last_attempt_at", 0.0)), arrival_time + 6.0, 0.0001,
		"the attempt time is the drift arrival time")
	var view_entry := ClueService.view_entry(context.state, kept_clue)
	assert_eq(int(view_entry.get("attempts", 0)), 1, "the clue view exposes the attempt count")
	assert_true(context.state.explore_voyage() == null, "explore_voyage is cleared")
	var summary: Dictionary = data.get("summary", {})
	var explore_summary: Dictionary = summary.get("explore", {})
	assert_eq(String(explore_summary.get("result", "")), "failed", "summary.explore reports the failure")
	assert_eq(int(explore_summary.get("attempts", 0)), 1, "summary.explore reports the attempt count")
	assert_true(bool(explore_summary.get("clue_retained", false)), "summary marks the clue as retained")
	assert_almost_eq(float(explore_summary.get("durability_loss", 0.0)), 8.0, 0.0001,
		"drifting costs the rule's durability loss")
	assert_almost_eq(float(context.state.ship().get("durability", 0.0)), durability_before - 8.0, 0.0001,
		"durability is deducted")
	assert_almost_eq(float(explore_summary.get("extra_coal", 0.0)), minf(4.0, coal_before), 0.0001,
		"drift coal is the rule value, clamped to the stock")
	assert_almost_eq(float(explore_summary.get("extra_water", 0.0)), minf(4.0, water_before), 0.0001,
		"drift water is the rule value, clamped to the stock")
	# 4.3.5 / U8：失败也真的航行了 `duration + drift_hours`，先按费率扣小时消耗，
	# 再扣漂流额外损耗（额外那笔在小时扣款后的剩余库存上钳位）。
	var drift_hours := 6.0
	var coal_after_hourly := maxf(0.0, coal_before - coal_rate * (duration + drift_hours))
	var water_after_hourly := maxf(0.0, water_before - water_rate * (duration + drift_hours))
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)),
		maxf(0.0, coal_after_hourly - float(explore_summary.get("extra_coal", 0.0))), 0.0001,
		"failure deducts hourly coal for the whole attempt plus the drift extra")
	assert_almost_eq(float(context.state.ship().get("water", 0.0)),
		maxf(0.0, water_after_hourly - float(explore_summary.get("extra_water", 0.0))), 0.0001,
		"failure deducts hourly water for the whole attempt plus the drift extra")
	assert_almost_eq(float(summary.get("arrival_time", 0.0)), arrival_time + 6.0, 0.0001,
		"drifting adds the rule's extra hours")
	assert_almost_eq(float(summary.get("delayed_hours", 0.0)), 6.0, 0.0001, "summary reports the delay")
	assert_true(_has_notice(context.state.recent_notices(6), "ui.notice.exploration_failed"),
		"the failure is announced")


## 4.3 / U3：失败后线索仍 active，可立即按同一条线索再次出航（不必重新买情报）。
func test_failed_clue_can_be_sailed_again() -> void:
	var context := _start_run(SEED)
	var clue := _acquire(context, "intel")
	assert_false(clue.is_empty(), "clue should exist")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	var preview := ExplorationCalculator.preview(context, clue_id, STRATEGY_ID)
	var preview_data: Dictionary = preview.get("data", {})
	var need_coal := float(preview_data.get("coal_required", 0.0))
	var need_water := float(preview_data.get("water_required", 0.0))
	var first := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_true(bool(first.get("ok", false)), "the first exploration starts")
	context.state.explore_voyage()["outcome_roll"] = 0.999
	var failed := context.commands.execute(&"explore.settle", {})
	assert_eq(String(failed.get("data", {}).get("result", "")), "failed", "the first attempt fails")
	# 失败后补回刚好够本程的煤水（不要超重），让第二次出航只验证「线索仍可用」
	# 而不是补给 / 载重门禁。
	context.state.ship()["coal"] = need_coal + 0.1
	context.state.ship()["water"] = need_water + 0.1
	var second := context.commands.execute(&"explore.start", {"clue_id": clue_id, "strategy_id": STRATEGY_ID})
	assert_true(bool(second.get("ok", false)),
		"a failed clue can be sailed again: %s" % str(second))
	if not bool(second.get("ok", false)):
		return
	context.state.explore_voyage()["outcome_roll"] = 0.999
	var failed_again := context.commands.execute(&"explore.settle", {})
	assert_eq(String(failed_again.get("data", {}).get("result", "")), "failed", "the retry fails too")
	var kept := ClueService.find_clue(context.state, clue_id)
	assert_false(kept.is_empty(), "the clue survives a second failure")
	assert_eq(int(kept.get("attempts", 0)), 2, "both attempts are recorded")
	assert_false(_failed_has(context, clue_id), "retries never move the clue into the failed list")


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
	# 4.3.5 / U8：出发不扣煤水，这里的库存就是出发库存；掉头在结算时一次性扣款。
	var coal_at_departure := float(context.state.ship().get("coal", 0.0))
	var water_at_departure := float(context.state.ship().get("water", 0.0))
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
	# 4.3.5 / U8：掉头 = 实际半程小时消耗 + 计划消耗 × turnback_extra_ratio。
	var coal_after_half := maxf(0.0, coal_at_departure - float(voyage.get("coal_rate", 0.0)) * duration * 0.5)
	var water_after_half := maxf(0.0, water_at_departure - float(voyage.get("water_rate", 0.0)) * duration * 0.5)
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)),
		maxf(0.0, coal_after_half - float(voyage.get("coal_used", 0.0)) * 0.25), 0.0001,
		"turning back deducts the actual half-voyage burn plus the extra ratio")
	assert_almost_eq(float(context.state.ship().get("water", 0.0)),
		maxf(0.0, water_after_half - float(voyage.get("water_used", 0.0)) * 0.25), 0.0001,
		"turning back deducts the actual half-voyage water burn plus the extra ratio")
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
	# 4.3.5 / U8：告警仍按「本段预计消耗 vs 出发库存」预判；出发时煤水没有被扣掉。
	assert_almost_eq(float(low_context.state.ship().get("coal", 0.0)), coal_required * 1.05, 0.0001,
		"the alert is decided from the departure stock, which stays on board")
	assert_almost_eq(float(voyage.get("departure_coal", -1.0)), coal_required * 1.05, 0.0001,
		"the voyage records that departure stock for the演出 readout")
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
	assert_almost_eq(float(rules.get("fog_port_reveal_ratio", -1.0)), 0.05, 0.0001,
		"port-reveal fog ratio comes from Core JSON")
	assert_almost_eq(float(rules.get("fog_vision_ratio", -1.0)), 0.05, 0.0001,
		"ship-vision fog ratio comes from Core JSON")
	var intel_weights: Array = (rules.get("level_weights", {}) as Dictionary).get("intel", [])
	assert_eq(intel_weights.size(), 4, "level weights are still the four-level vector")
	assert_almost_eq(float(intel_weights[3]) if intel_weights.size() >= 4 else -1.0, 0.40, 0.0001,
		"level_weights stay in Core for the future clue system")
	# 4.3.2 / U2：调查消耗在 Core 里预留但为 0（本片不做资源判定、不扣钱、不推进时间）。
	assert_eq(int(rules.get("investigation_cost", -1)), 0, "investigation cost is reserved at 0")
	assert_almost_eq(float(rules.get("investigation_hours", -1.0)), 0.0, 0.0001,
		"investigation hours are reserved at 0")
	assert_almost_eq(float(rules.get("investigation_success_chance", -1.0)), 1.0, 0.0001,
		"the investigation chance defaults to a guaranteed success until 4.4.3")
	# 4.4.1：货物行情线索的时效 / 价格误差也来自 Core JSON。
	var expiry: Dictionary = rules.get("goods_clue_expiry_hours", {})
	assert_almost_eq(float(expiry.get("rumor", -1.0)), 24.0, 0.0001,
		"rumour goods leads expire after 24 h")
	assert_almost_eq(float(expiry.get("intel", -1.0)), 72.0, 0.0001,
		"intel goods leads expire after 72 h")
	assert_almost_eq(float(expiry.get("wait", -1.0)), 48.0, 0.0001,
		"dockside goods leads expire after 48 h")
	assert_almost_eq(float(expiry.get("contract", -1.0)), 72.0, 0.0001,
		"contract goods leads expire after 72 h")
	assert_almost_eq(float(rules.get("goods_clue_price_error_ratio", -1.0)), 0.15, 0.0001,
		"the goods price error ratio comes from Core JSON")
	assert_almost_eq(float(rules.get("wait_clue_chance_per_block", -1.0)), 0.35, 0.0001,
		"the wait clue chance comes from Core JSON")
	assert_almost_eq(float(rules.get("contract_clue_chance", -1.0)), 0.5, 0.0001,
		"the contract clue chance comes from Core JSON")


## 4.3 / U1：雾半径 = 世界短边 × Core 比例，而不是固定世界单位。160 世界的泊位
## 揭示直径必须 ≤ 世界 10%（0.05 × 160 × 2 = 16 = 10%）；旧常量 20/24 不再参与内容路径。
func test_fog_radii_are_world_size_relative_and_content_driven() -> void:
	var context := _start_run(SEED)
	var world := WorldOps.world_map(context.state)
	assert_false(world.is_empty(), "the run generates the coordinate twin world")
	var world_side := minf(world.bounds.size.x, world.bounds.size.y)
	var profile := context.registries.get_by_id(ContentTypes.MAP_PROFILE, context.state.world().get("map_profile_id", ""))
	assert_not_null(profile, "the run's map profile resolves")
	assert_almost_eq(float(profile.data.get("twin_world_size", 0.0)), world_side, 0.0001,
		"the twin world size comes from Core content, not a framework constant")
	assert_almost_eq(world_side, 160.0, 0.0001, "the core profile currently asks for a 160-unit twin world")
	var radii := ExplorationRules.fog_radii(context.state, context.registries, world)
	var vision_radius := float(radii.get("vision", -1.0))
	var reveal_radius := float(radii.get("port_reveal", -1.0))
	assert_almost_eq(vision_radius, world_side * 0.05, 0.0001, "vision radius = world side × Core ratio")
	assert_almost_eq(reveal_radius, world_side * 0.05, 0.0001, "berth reveal radius = world side × Core ratio")
	assert_true(reveal_radius * 2.0 <= world_side * 0.10 + 0.0001,
		"the berth fog diameter stays within 10% of the world side")
	# 迷雾网格分辨率随视野半径缩放：cell_size = vision / 4。
	var fog_state := FogOps.load_fog_state(context.state)
	var fog: FogGrid = fog_state.get("fog", FogGrid.new())
	assert_false(fog.is_empty(), "the run seeds a fog grid")
	assert_almost_eq(fog.cell_size, vision_radius / 4.0, 0.0001,
		"the fog cell size scales with the content vision radius")
	# 查询层输出同一份半径，UI 软圆与领域揭示不会各算一套。
	var vm := _chart_vm(context)
	var vm_radii: Dictionary = vm.get("fog_radii", {})
	assert_almost_eq(float(vm_radii.get("vision", 0.0)), vision_radius, 0.0001,
		"sea_chart.view exports the same vision radius")
	assert_almost_eq(float(vm_radii.get("port_reveal", 0.0)), reveal_radius, 0.0001,
		"sea_chart.view exports the same port-reveal radius")


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
	var clue_id := String(clue.get("id", ""))
	# 4.3.2 / U2：调查两级后存档，等级必须随线索一起持久化（不只保留 active 状态）。
	for expected_level in [2, 3]:
		var investigated := context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
		assert_true(bool(investigated.get("ok", false)),
			"the clue investigates to level %d before saving: %s" % [expected_level, str(investigated)])
	var started := context.commands.execute(&"explore.start", {
		"clue_id": clue_id,
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
	var loaded_clue := ClueService.find_clue(loaded_state, clue_id)
	assert_false(loaded_clue.is_empty(), "the investigated clue is still active after loading")
	assert_eq(int(loaded_clue.get("level", 0)), 3,
		"the clue level survives the save round-trip")
	assert_true(loaded_state.explore_voyage() is Dictionary, "the exploration voyage survived the round-trip")
	assert_eq(String((loaded_state.data.get("voyage", {}) as Dictionary).get("kind", "")), "explore",
		"the at-sea marker survived the round-trip")


# ── 4.4.1 goods clues / expiry / clue.list ──

## 货物线索在获得时冻结行情快照、按来源表到期；视图按等级披露港口名 → 价格区间 →
## 供需 / 库存 → 精确买卖价，且任何等级都不泄露 target_port_id / credibility。
func test_goods_clue_freezes_a_snapshot_and_discloses_by_level() -> void:
	var context := _start_run(SEED)
	var target_id := _discover_other_port(context)
	assert_false(target_id.is_empty(), "a second discovered port is needed for a goods lead")
	var clue := _acquire_goods(context, "intel")
	assert_false(clue.is_empty(), "a goods clue should be acquirable")
	if clue.is_empty():
		return
	assert_eq(String(clue.get("type", "")), ClueService.TYPE_PORT_GOODS,
		"the clue type is port_goods")
	var snapshot: Dictionary = clue.get("goods_snapshot", {})
	assert_false(snapshot.is_empty(), "the market snapshot is frozen on the clue")
	assert_eq(String(clue.get("target_port_id", "")), target_id,
		"the goods clue targets an already discovered harbour")
	var rules := ExplorationRules.read(context.state, context.registries)
	var expiry_hours := float((rules.get("goods_clue_expiry_hours", {}) as Dictionary).get("intel", -1.0))
	assert_almost_eq(float(clue.get("expires_at", 0.0)), context.state.now() + expiry_hours, 0.001,
		"goods expiry = now + goods_clue_expiry_hours[source]")
	var world := WorldOps.world_map(context.state)
	var expected_name := WorldOps.port_display_key(world, target_id)
	for level: int in [1, 2, 3, 4]:
		clue["level"] = level
		var view := ClueService.view_entry(context.state, clue)
		assert_eq(String(view.get("type", "")), ClueService.TYPE_PORT_GOODS,
			"level %d view keeps the goods type" % level)
		assert_false(view.has("target_port_id"),
			"level %d goods view must not leak target_port_id" % level)
		assert_false(view.has("credibility"),
			"level %d goods view must not leak credibility" % level)
		assert_false(view.has("goods_snapshot"),
			"level %d goods view must not leak the raw snapshot" % level)
		assert_almost_eq(float(view.get("remaining_hours", -1.0)), expiry_hours, 0.001,
			"level %d reports the remaining lifetime" % level)
		var goods: Dictionary = view.get("goods", {})
		assert_eq(String(goods.get("port_name_key", "")), expected_name,
			"level %d names the port (goods clues target known harbours)" % level)
		assert_eq(goods.has("buy_price_min"), level >= 2,
			"level %d price-range disclosure" % level)
		assert_eq(goods.has("stock"), level >= 3,
			"level %d stock disclosure" % level)
		assert_eq(goods.has("buy_price"), level >= 4,
			"level %d exact-price disclosure" % level)
		if level >= 4:
			assert_eq(int(goods.get("buy_price", 0)), int(snapshot.get("buy_price", -1)),
				"the exact buy price comes from the frozen snapshot")
			assert_eq(int(goods.get("sell_price", 0)), int(snapshot.get("sell_price", -1)),
				"the exact sell price comes from the frozen snapshot")
	# sea_chart.view carries the new metadata and the list-entry counter.
	var vm := _chart_vm(context)
	var clues: Array = vm.get("clues", [])
	assert_eq(clues.size(), 1, "the goods clue reaches the chart view")
	if not clues.is_empty():
		var entry: Dictionary = clues[0]
		assert_eq(String(entry.get("type", "")), ClueService.TYPE_PORT_GOODS,
			"the chart view reports the clue type")
		assert_false(entry.has("target_port_id"), "the chart view never leaks the target port")
		assert_false(entry.has("credibility"), "the chart view never leaks credibility")
		assert_true(entry.get("goods", null) != null, "the chart view carries the goods projection")
		assert_eq(bool(entry.get("estimated", {}) == {}), true,
			"goods clues do not carry an exploration estimate")
	assert_eq(int(vm.get("expiring_clue_count", -1)), 1,
		"the chart reports one expiring clue")


## 过期线索：查询先过滤（只读），命令路径 sweep 后进 expired 历史并释放 active 名额。
func test_expired_goods_clue_is_swept_by_commands_and_frees_the_cap() -> void:
	var context := _start_run(SEED)
	_discover_other_port(context)
	var clue := _acquire_goods(context, "wait")
	assert_false(clue.is_empty(), "a goods clue should be acquirable")
	if clue.is_empty():
		return
	var clue_id := String(clue.get("id", ""))
	# 存档时间是 0，先让时间前进再制造过期（`expires_at` 必须 > 0 才是「有时效」）。
	# 命令提交会替换 context.state，因此命令之后要重新取活跃线索的引用。
	context.commands.execute(&"port.wait", {"hours": 6})
	clue = ClueService.find_clue(context.state, clue_id)
	assert_false(clue.is_empty(), "the goods clue survives the wait")
	clue["expires_at"] = context.state.now() - 1.0
	assert_eq(ClueService.active_count(context.state), 0,
		"an expired clue no longer counts toward max_active_clues")
	assert_eq(ClueService.view(context.state).size(), 0,
		"views filter expired clues before the sweep")
	var waited := context.commands.execute(&"port.wait", {"hours": 6})
	assert_true(bool(waited.get("ok", false)), "waiting in port succeeds")
	assert_eq(ClueService.active(context.state).size(), 0,
		"the command-path sweep removed the clue from active")
	var expired: Array = context.state.ensure_clues().get("expired", [])
	assert_eq(expired.size(), 1, "the full snapshot moved into the expired history")
	if not expired.is_empty() and expired[0] is Dictionary:
		var history: Dictionary = expired[0]
		assert_eq(String(history.get("id", "")), String(clue.get("id", "")),
			"the history keeps the clue id")
		assert_eq(String(history.get("type", "")), ClueService.TYPE_PORT_GOODS,
			"the history keeps the clue type")
		assert_false(history.get("goods_snapshot", null) == null,
			"the history keeps the frozen snapshot")
	assert_true(_has_event(waited.get("events", []), "clue.expired"),
		"the sweep emits clue.expired")
	assert_true(_has_notice(context.state.recent_notices(), "ui.notice.clue_expired"),
		"the sweep pushes a localized notice")


## clue.list 只读查询：active 线索的裁剪视图 + 调查入口 + 可出航标记 + 过期折叠历史。
func test_clue_list_query_returns_trimmed_clues_and_expired_history() -> void:
	var context := _start_run(SEED)
	_discover_other_port(context)
	var clue := _acquire_goods(context, "contract")
	assert_false(clue.is_empty(), "a goods clue should be acquirable")
	if clue.is_empty():
		return
	clue["level"] = 2
	var listed := context.queries.execute(&"clue.list", {})
	assert_true(bool(listed.get("ok", false)),
		"clue.list is registered through the QueryBus: %s" % str(listed))
	var data: Dictionary = listed.get("data", {})
	assert_true(bool(data.get("has_run", false)), "the list reports a live run")
	assert_eq(int(data.get("active_count", -1)), 1, "the list counts the active clue")
	var clues: Array = data.get("clues", [])
	assert_eq(clues.size(), 1, "the list carries the active clue")
	if not clues.is_empty():
		var entry: Dictionary = clues[0]
		assert_false(entry.has("target_port_id"), "the list never leaks the target port")
		assert_false(entry.has("credibility"), "the list never leaks credibility")
		assert_true(bool(entry.get("can_investigate", false)),
			"an in-port level-2 clue can be investigated")
		assert_true(bool(entry.get("can_sail", false)),
			"a goods clue for another discovered port can be sailed")
		assert_almost_eq(float(entry.get("investigation_success_chance", -1.0)), 1.0, 0.0001,
			"the investigation chance comes from Core")
		var goods: Dictionary = entry.get("goods", {})
		assert_true(goods.has("buy_price_min"), "level 2 discloses the price range")
	# 过期 + 命令清理后，列表只剩历史折叠区。先是 0 时的存档，先推进时间制造过期。
	# 命令提交会替换 context.state，所以每次命令后都重新取线索引用。
	var clue_id := String(clue.get("id", ""))
	context.commands.execute(&"port.wait", {"hours": 6})
	clue = ClueService.find_clue(context.state, clue_id)
	assert_false(clue.is_empty(), "the goods clue survives the wait")
	clue["expires_at"] = context.state.now() - 1.0
	context.commands.execute(&"port.wait", {"hours": 6})
	var after_result := context.queries.execute(&"clue.list", {})
	assert_true(bool(after_result.get("ok", false)), "clue.list still succeeds")
	var after: Dictionary = after_result.get("data", {})
	assert_eq((after.get("clues", []) as Array).size(), 0, "no active clues remain")
	var expired: Array = after.get("expired", [])
	assert_eq(expired.size(), 1, "the expired history is exposed to the list page")
	if not expired.is_empty() and expired[0] is Dictionary:
		var entry: Dictionary = expired[0]
		assert_eq(String(entry.get("type", "")), ClueService.TYPE_PORT_GOODS,
			"the expired entry keeps its type")
		assert_false(entry.has("target_port_id"), "the expired entry never leaks the target port")
		assert_false(String(entry.get("port_name_key", "")).is_empty(),
			"the expired goods entry shows the (public) port name")


## 旧存档线索惰性补齐 4.4 字段：type / target_goods_id / goods_snapshot /
## expires_at / unlock_source，且不改 schema_version；港口位置线索视图保持 4.3 形状。
func test_legacy_clue_entries_are_normalized_without_a_schema_bump() -> void:
	var state := GameState.new()
	state.data = {
		"schema_version": "2.0",
		"clues": {
			"next_id": 2,
			"active": [{
				"id": "clue:1",
				"source_key": "rumor",
				"source_display_key": "ui.clue.source.rumor",
				"target_port_id": "port_1",
				"level": 1,
				"reference_port_id": "port_0",
				"direction_angle": 0.0,
				"distance_min_hours": 0.0,
				"distance_max_hours": 0.0,
				"credibility": 0.4,
				"search_zone": {"x": 0.0, "y": 0.0, "radius": 1.0},
				"created_at": 0.0,
				"attempts": 0,
				"last_attempt_at": 0.0,
			}],
			"failed": [],
			"resolved": [],
		},
	}
	var clues: Array = ClueService.active(state)
	assert_eq(clues.size(), 1, "the legacy clue is still active")
	var clue: Dictionary = clues[0]
	assert_eq(String(clue.get("type", "")), ClueService.TYPE_PORT_LOCATION,
		"a legacy clue defaults to port_location")
	assert_eq(String(clue.get("target_goods_id", "")), "", "no goods target on a legacy clue")
	assert_true(clue.get("goods_snapshot", null) == null, "no goods snapshot on a legacy clue")
	assert_almost_eq(float(clue.get("expires_at", -1.0)), 0.0, 0.0001,
		"a legacy port clue never expires")
	assert_eq(String(clue.get("unlock_source", "")), "", "no unlock source on a legacy clue")
	assert_eq(state.schema_version(), "2.0", "normalization never bumps schema_version")
	assert_eq((state.ensure_clues().get("expired", null) as Array).size(), 0,
		"the expired history starts empty")
	var view := ClueService.view_entry(state, clue)
	assert_eq(String(view.get("type", "")), ClueService.TYPE_PORT_LOCATION,
		"the legacy view keeps the port-location shape")
	assert_true(view.get("goods", null) == null, "a port-location view has no goods block")
	assert_almost_eq(float(view.get("remaining_hours", 0.0)), -1.0, 0.0001,
		"port-location clues report no remaining lifetime")


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


## 4.4.1：建一条货物线索（真实服务 + 独立命名流）。
func _acquire_goods(context: AppContext, source: String = "wait") -> Dictionary:
	_stream_serial += 1
	var rng := context.rng.make_stream(
		RngService.STREAM_EXPLORATION, "test-goods:%d" % _stream_serial
	)
	return ClueService.acquire_goods(context, source, rng)


## 4.4.1：货物线索只指向已发现港口，测试里先真实发现一个非当前港。
func _discover_other_port(context: AppContext) -> String:
	var world := WorldOps.world_map(context.state)
	var current := context.state.current_port_id()
	for port in world.ports:
		if port.id == current:
			continue
		WorldOps.discover_port_id(context.state, port.id)
		MapOps.discover(context.state, port.id)
		return port.id
	return ""


func _chart_vm(context: AppContext) -> Dictionary:
	var result := SeaChartViewQuery.execute({"strategy_id": STRATEGY_ID}, context)
	assert_true(bool(result.get("ok", false)), "sea_chart.view should succeed")
	return result.get("data", {})


## The first level-trimmed clue entry in `sea_chart.view` (empty when there is none).
func _first_clue_entry(context: AppContext) -> Dictionary:
	var clues: Array = _chart_vm(context).get("clues", [])
	if clues.is_empty():
		return {}
	var entry: Variant = clues[0]
	if not (entry is Dictionary):
		return {}
	return entry


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
