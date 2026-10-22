extends TestCase
## @static-doc
## 作用：Phase D0 确定性 tick / 模拟框架的回归测试：`data.sim` 惰性状态、暂停 /
## 恢复 / 速度 / 推进命令、`sim.view` 查询、tick 系统顺序与 `sim.tick` 领域事件、
## 同种子状态 hash 确定性、存档 round-trip 与旧档（缺 `data.sim`）惰性补齐。
##
## ## 契约与约束
## - 固定步长 1 游戏小时；`advance(hours)` 实际 tick 数 = floor(hours * speed)。
## - 暂停时不推进时间、不调用系统、不发事件；`advance` 仍返回 ok + ticks=0。
## - 系统执行顺序为 priority 升序、再 id 字典序；测试用 TickScheduler.reset()
##   隔离静态注册表，结束时也清理，避免污染其他套件。
## - 确定性用 `GameState.hash()` 比较；与现有刚启动跑测一致，比较前先删掉
##   `started_at` / `campaign.created_at` 这类真实时钟字段。
## - D0 不改变 port.wait / voyage 时间语义，本套件不覆盖它们。
## @end-static-doc

const STEADY := "core:starting_scenario/steady"


func _start(seed_value: int) -> AppContext:
	var context: AppContext = bootstrap_core()["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": seed_value})
	assert_true(bool(started.get("ok", false)), "run.start succeeds: %s" % str(started))
	return context


func _view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"sim.view")
	assert_true(bool(result.get("ok", false)), "sim.view answers: %s" % str(result))
	return result.get("data", {})


func _erase_wall_clock(state: GameState) -> void:
	state.data["run"].erase("started_at")
	var campaign: Variant = state.data.get("campaign", null)
	if campaign is Dictionary:
		(campaign as Dictionary).erase("created_at")


func test_commands_and_query_are_registered() -> void:
	var context := _start(101)
	for command in [&"sim.pause", &"sim.resume", &"sim.set_speed", &"sim.advance"]:
		assert_true(context.commands.has(command), "%s is registered" % command)
	assert_true(context.queries.has(&"sim.view"), "sim.view is registered")


func test_state_is_lazy_and_defaults_are_reported() -> void:
	var context := _start(102)
	assert_false(context.state.data.has("sim"), "run.start does not create data.sim eagerly")
	var view := _view(context)
	assert_eq(bool(view.get("paused", true)), false, "the default clock is running")
	assert_eq(float(view.get("speed", 0.0)), 1.0, "the default speed is 1x")
	assert_eq(int(view.get("tick", -1)), 0, "the default tick is 0")
	assert_eq(float(view.get("step_hours", 0.0)), SimulationService.TICK_HOURS, "the step is one game hour")
	assert_true(view.get("systems", null) is Array, "the view lists systems")
	assert_false(context.state.data.has("sim"), "sim.view never creates data.sim")
	var sim := SimulationService.ensure_state(context.state)
	assert_eq(bool(sim.get("paused", true)), false, "ensure_state backfills paused")
	assert_true(context.state.data.has("sim"), "ensure_state persists the lazy block")


func test_pause_blocks_advance_and_resume_restores_it() -> void:
	var context := _start(103)
	var paused := context.commands.execute(&"sim.pause")
	assert_true(bool(paused.get("ok", false)), "sim.pause succeeds")
	assert_eq(bool(paused["data"].get("paused", false)), true, "the view reports paused")
	var time_before := context.state.now()
	var blocked := context.commands.execute(&"sim.advance", {"hours": 5.0})
	assert_true(bool(blocked.get("ok", false)), "advancing while paused is still a successful command")
	assert_eq(int(blocked["data"].get("ticks", -1)), 0, "a paused clock advances zero ticks")
	assert_eq(context.state.now(), time_before, "a paused clock does not move game time")
	assert_empty(blocked.get("events", []), "a paused clock emits no sim.tick events")
	var resumed := context.commands.execute(&"sim.resume")
	assert_true(bool(resumed.get("ok", false)), "sim.resume succeeds")
	assert_eq(bool(resumed["data"].get("paused", true)), false, "the view reports running")
	var ran := context.commands.execute(&"sim.advance", {"hours": 3.0})
	assert_eq(int(ran["data"].get("ticks", -1)), 3, "three real hours at 1x advance three ticks")
	assert_almost_eq(context.state.now(), 3.0, 0.0001, "game time advanced by the tick count")


func test_speed_scales_ticks_and_is_validated() -> void:
	var context := _start(104)
	var fast := context.commands.execute(&"sim.set_speed", {"speed": 2.0})
	assert_true(bool(fast.get("ok", false)), "sim.set_speed succeeds")
	assert_eq(float(fast["data"].get("speed", 0.0)), 2.0, "the view reports the new speed")
	var advanced := context.commands.execute(&"sim.advance", {"hours": 2.0})
	assert_eq(int(advanced["data"].get("ticks", -1)), 4, "two real hours at 2x advance four ticks")
	assert_almost_eq(context.state.now(), 4.0, 0.0001, "game time follows the scaled tick count")
	var before := context.state.hash()
	for invalid in [0.0, -1.0, SimulationService.MAX_SPEED + 1.0]:
		var rejected := context.commands.execute(&"sim.set_speed", {"speed": invalid})
		assert_false(bool(rejected.get("ok", true)), "speed %s is rejected" % invalid)
		assert_eq(String(rejected.get("error_code", "")), "invalid_speed", "invalid speed error code")
	assert_eq(context.state.hash(), before, "rejected speed commands do not mutate state")


func test_advance_rejects_invalid_hours_and_keeps_whole_ticks() -> void:
	var context := _start(105)
	var before := context.state.hash()
	for invalid in [0.0, -3.0, SimulationService.MAX_ADVANCE_HOURS + 1.0]:
		var rejected := context.commands.execute(&"sim.advance", {"hours": invalid})
		assert_false(bool(rejected.get("ok", true)), "hours %s is rejected" % invalid)
		assert_eq(String(rejected.get("error_code", "")), "invalid_advance_hours", "invalid advance error code")
	assert_eq(context.state.hash(), before, "rejected advance commands do not mutate state")
	var fractional := context.commands.execute(&"sim.advance", {"hours": 0.5})
	assert_eq(int(fractional["data"].get("ticks", -1)), 0, "half an hour is not a whole tick")
	assert_almost_eq(context.state.now(), 0.0, 0.0001, "a sub-tick advance does not move time")
	var one_and_a_half := context.commands.execute(&"sim.advance", {"hours": 1.5})
	assert_eq(int(one_and_a_half["data"].get("ticks", -1)), 1, "1.5 hours rounds down to one whole tick")
	assert_almost_eq(context.state.now(), 1.0, 0.0001, "the leftover fraction is discarded")


func test_advance_is_deterministic_for_the_same_seed() -> void:
	TickScheduler.reset()
	var system_a := func(state: GameState, tick: int) -> void:
		state.data["d0_trace"] = state.data.get("d0_trace", [])
		(state.data["d0_trace"] as Array).append(tick)
	TickScheduler.register("deterministic", 10, system_a)
	var first := _start(106)
	var first_result := first.commands.execute(&"sim.advance", {"hours": 4.0})
	assert_eq(int(first_result["data"].get("ticks", -1)), 4, "first run advances four ticks")
	TickScheduler.reset()
	TickScheduler.register("deterministic", 10, system_a)
	var second := _start(106)
	var second_result := second.commands.execute(&"sim.advance", {"hours": 4.0})
	assert_eq(int(second_result["data"].get("ticks", -1)), 4, "second run advances four ticks")
	_erase_wall_clock(first.state)
	_erase_wall_clock(second.state)
	assert_eq(first.state.hash(), second.state.hash(), "same seed + same ticks reproduce the same state")
	assert_eq(first.state.data.get("d0_trace", []), [1, 2, 3, 4], "the system saw ticks in order")
	TickScheduler.reset()


func test_systems_run_by_priority_then_id() -> void:
	TickScheduler.reset()
	var order: Array = []
	TickScheduler.register("b", 20, func(_state: GameState, _tick: int) -> void: order.append("b"))
	TickScheduler.register("c", 10, func(_state: GameState, _tick: int) -> void: order.append("c"))
	TickScheduler.register("a", 10, func(_state: GameState, _tick: int) -> void: order.append("a"))
	assert_eq(TickScheduler.systems().size(), 3, "three systems are registered")
	var context := _start(107)
	var advanced := context.commands.execute(&"sim.advance", {"hours": 2.0})
	assert_eq(int(advanced["data"].get("ticks", -1)), 2, "two ticks run")
	assert_eq(order, ["a", "c", "b", "a", "c", "b"], "systems run priority asc then id asc")
	TickScheduler.register("a", 10, func(_state: GameState, _tick: int) -> void: order.append("a2"))
	assert_eq(TickScheduler.systems().size(), 3, "re-registering the same id replaces the system")
	order.clear()
	context.commands.execute(&"sim.advance", {"hours": 1.0})
	assert_eq(order, ["a2", "c", "b"], "the replacement callable runs in the same deterministic slot")
	TickScheduler.reset()


func test_each_tick_emits_a_sim_tick_event() -> void:
	var context := _start(108)
	context.events.clear()
	var advanced := context.commands.execute(&"sim.advance", {"hours": 2.0})
	var events: Array = advanced.get("events", [])
	assert_eq(events.size(), 2, "two ticks produce two events")
	assert_eq(String((events[0] as Dictionary).get("type", "")), "sim.tick", "the event type is sim.tick")
	assert_eq(int(((events[0] as Dictionary)["payload"] as Dictionary).get("tick", 0)), 1, "the first payload carries tick 1")
	assert_eq(int(((events[1] as Dictionary)["payload"] as Dictionary).get("tick", 0)), 2, "the second payload carries tick 2")
	var published := context.events.get_history(&"sim.tick", 10)
	assert_eq(published.size(), 2, "the CommandBus publishes both sim.tick events")
	assert_eq(String(context.events.last_event(&"sim.tick").get("event_type", "")), "sim.tick", "history keeps sim.tick")


func test_save_round_trip_persists_the_sim_block() -> void:
	var context := _start(109)
	context.commands.execute(&"sim.pause")
	context.commands.execute(&"sim.set_speed", {"speed": 4.0})
	context.commands.execute(&"sim.resume")
	context.commands.execute(&"sim.advance", {"hours": 1.0})
	var view_before := _view(context)
	assert_eq(int(view_before.get("tick", 0)), 4, "four speed-scaled ticks ran")
	var saved := context.save.save_slot("sim_manual", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "save succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("sim_manual")
	assert_true(bool(loaded.get("ok", false)), "load succeeds: %s" % str(loaded))
	var loaded_state: GameState = loaded["state"]
	var loaded_sim: Dictionary = loaded_state.data.get("sim", {})
	assert_true(loaded_sim is Dictionary, "the saved state still carries the sim block")
	assert_eq(bool(loaded_sim.get("paused", true)), false, "paused round-trips")
	assert_almost_eq(float(loaded_sim.get("speed", 0.0)), 4.0, 0.0001, "speed round-trips")
	assert_eq(int(loaded_sim.get("tick", 0)), 4, "tick round-trips")
	var loaded_context: AppContext = bootstrap_core()["context"]
	loaded_context.set_state(loaded_state)
	var view_after := _view(loaded_context)
	assert_eq(int(view_after.get("tick", 0)), 4, "the restored view keeps the tick")
	assert_eq(float(view_after.get("speed", 0.0)), 4.0, "the restored view keeps the speed")
	assert_almost_eq(float(view_after.get("game_time", 0.0)), float(view_before.get("game_time", 0.0)), 0.0001,
		"the restored view keeps game time")


func test_legacy_state_without_sim_is_backfilled_lazily() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": 110})
	assert_true(bool(started.get("ok", false)), "run starts")
	context.state.data.erase("sim")
	assert_false(context.state.data.has("sim"), "the legacy state has no sim block")
	var view := _view(context)
	assert_eq(int(view.get("tick", -1)), 0, "the legacy view reports tick 0")
	assert_eq(bool(view.get("paused", true)), false, "the legacy view reports a running clock")
	assert_false(context.state.data.has("sim"), "reading the legacy view does not persist a block")
	var paused := context.commands.execute(&"sim.pause")
	assert_true(bool(paused.get("ok", false)), "a sim command lazily creates the block")
	assert_true(context.state.data.get("sim", null) is Dictionary, "the block is persisted after the first command")
	assert_eq(bool(_view(context).get("paused", false)), true, "the persisted block drives the view")
