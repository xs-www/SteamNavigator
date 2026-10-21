extends TestCase
## @static-doc
## 作用：新手剧情 / 教学系统（阶段 4.5.1）领域层无头测试：`run.start tutorial=true`
## 初始化剧情、功能解锁 / 门禁 ViewModel、剧情卡继续、`story.observe` 事件计数推进、
## `story.skip` 保底解锁与主委托目的港揭示、非教程局 / 旧存档不门禁、存档往返。
##
## ## 契约与约束
## - 用真实 Core 注册表：剧情步骤 / 文案 / 解锁 / 数值必须来自
##   `dev_mods/core/content/map_profiles.json` 的 `story` 块，测试不写死框架步骤。
## - `run.start` 的 `tutorial` 默认 false（测试 / 旧入口不弹剧情）；Shell 的
##   「开始新航行」显式传 true，生产局每局默认进入剧情。
## - 跳过 / 完成必须解锁配置里的全部功能并执行 `discover_contract_destination`，
##   避免跳过教程后无目的港可出航。
## @end-static-doc

const SEED := 20260421
const BUILD_ID := "core:starting_build/steady"


func test_tutorial_run_starts_story_and_locks_features() -> void:
	var context := _start_tutorial(SEED)
	var story := context.state.story()
	assert_true(bool(story.get("active", false)), "a tutorial run activates the story")
	assert_false(bool(story.get("completed", true)), "the story is not completed before playing it")
	assert_eq(int(story.get("stage_index", -1)), 0, "the tutorial starts at the first stage")
	assert_eq(String(story.get("flow_id", "")), "core:story/opening", "the Core flow id is recorded")
	var view := _view(context)
	assert_eq(String(view.get("stage_id", "")), "opening", "the first stage is active")
	assert_not_null(view.get("card", null), "the opening stage shows a story card")
	assert_true(bool(view.get("can_skip", false)), "the tutorial can be skipped")
	var unlocked: Array = view.get("unlocked_features", [])
	assert_true(unlocked.has("overview"), "the opening stage unlocks the overview")
	assert_false(unlocked.has("supply"), "supply stays locked until the next stage")
	assert_false(unlocked.has("chart"), "the chart stays locked in the opening")


func test_tutorial_run_discovers_the_main_contract_destination() -> void:
	var context := _start_tutorial(SEED)
	var main_contract: Variant = context.state.contracts().get("main", null)
	assert_true(main_contract is Dictionary, "a tutorial run auto-accepts the main contract")
	if not (main_contract is Dictionary):
		return
	var destination := String((main_contract as Dictionary).get("destination", ""))
	assert_false(destination.is_empty(), "the main contract has a destination")
	assert_true(Array(context.state.campaign_world().get("discovered_port_ids", [])).has(destination),
		"the coordinate world discovers the contract destination")
	assert_true(Array(context.state.world().get("discovered_ports", [])).has(destination),
		"the abstract map discovers the contract destination")


func test_non_tutorial_run_is_not_gated() -> void:
	var context := _start_run(SEED)
	var story := context.state.story()
	assert_false(bool(story.get("active", false)), "a non-tutorial run has no active story")
	assert_true(bool(story.get("completed", true)), "a non-tutorial run is treated as story-complete")
	var view := _view(context)
	assert_false(bool(view.get("active", false)), "the view reports no active story")
	assert_eq((view.get("unlocked_features", []) as Array).size(), StoryService.FEATURES.size(),
		"without a running story every feature stays unlocked")
	assert_true(view.get("card", null) == null, "no story card is shown")


func test_advance_unlocks_supply_and_shows_objective() -> void:
	var context := _start_tutorial(SEED)
	var advanced := context.commands.execute(&"story.advance", {})
	assert_true(bool(advanced.get("ok", false)), "the opening card can be continued: %s" % str(advanced))
	var view := _view(context)
	assert_eq(String(view.get("stage_id", "")), "supply_brief", "the next stage is the supply briefing")
	assert_true((view.get("unlocked_features", []) as Array).has("supply"), "supply is unlocked")
	var objective: Variant = view.get("objective", null)
	assert_not_null(objective, "the supply stage has a non-blocking objective")
	if objective is Dictionary:
		assert_eq(int((objective as Dictionary).get("target", 0)), 2, "the objective comes from Core JSON")
		assert_eq(int((objective as Dictionary).get("progress", 0)), 0, "no coal has been bought yet")


func test_observe_counts_events_and_advances_stories() -> void:
	var context := _start_tutorial(SEED)
	context.commands.execute(&"story.advance", {})
	var bought := context.commands.execute(&"supply.buy_coal", {"amount": 2})
	assert_true(bool(bought.get("ok", false)), "buying coal succeeds at the starting harbour: %s" % str(bought))
	var observed := context.commands.execute(&"story.observe", {
		"event": "cmd:supply.buy_coal",
		"data": {"amount": 2},
	})
	assert_true(bool(observed.get("ok", false)), "the purchase observation succeeds: %s" % str(observed))
	var view := _view(context)
	assert_eq(String(view.get("stage_id", "")), "chart_brief", "2 coal advances the supply stage")
	assert_true((view.get("unlocked_features", []) as Array).has("chart"), "the chart unlocks after provisioning")
	assert_not_null(view.get("card", null), "the chart briefing shows its own card")


func test_skip_unlocks_everything_and_keeps_the_run_playable() -> void:
	var context := _start_tutorial(SEED)
	var skipped := context.commands.execute(&"story.skip", {})
	assert_true(bool(skipped.get("ok", false)), "skipping the tutorial succeeds: %s" % str(skipped))
	var view := _view(context)
	assert_true(bool(view.get("completed", false)), "the story is completed")
	assert_true(bool(view.get("skipped", false)), "the story is marked as skipped")
	assert_false(bool(view.get("can_skip", false)), "a finished tutorial cannot be skipped again")
	assert_eq((view.get("unlocked_features", []) as Array).size(), StoryService.FEATURES.size(),
		"skipping unlocks every configured feature")
	var main_contract: Variant = context.state.contracts().get("main", null)
	if main_contract is Dictionary:
		var destination := String((main_contract as Dictionary).get("destination", ""))
		assert_true(Array(context.state.campaign_world().get("discovered_port_ids", [])).has(destination),
			"skipping still reveals the main contract destination")


func test_story_survives_a_save_load_roundtrip() -> void:
	var context := _start_tutorial(SEED, {
		"save_directory": "user://test_saves/story_%d" % Time.get_ticks_usec(),
	})
	context.commands.execute(&"story.advance", {})
	context.commands.execute(&"supply.buy_coal", {"amount": 2})
	context.commands.execute(&"story.observe", {
		"event": "cmd:supply.buy_coal",
		"data": {"amount": 2},
	})
	var before := context.state.hash()
	var saved := context.save.save_slot("manual", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "saving the story state succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("manual")
	assert_true(bool(loaded.get("ok", false)), "loading the story state succeeds")
	var loaded_state: GameState = loaded.get("state", null)
	assert_not_null(loaded_state, "the loaded state exists")
	if loaded_state == null:
		return
	assert_eq(loaded_state.hash(), before, "the story state hash is identical after loading")
	context.state.replace_with(loaded_state)
	var loaded_view := _view(context)
	assert_eq(String(loaded_view.get("stage_id", "")), "chart_brief", "the story stage survives the round-trip")
	assert_true((loaded_view.get("unlocked_features", []) as Array).has("chart"),
		"unlocked features survive the round-trip")


func test_old_save_without_story_block_stays_open() -> void:
	var context := _start_run(SEED)
	context.state.data.erase("story")
	var view := _view(context)
	var story := context.state.ensure_story()
	assert_false(bool(story.get("active", false)), "a missing story block backfills as inactive")
	assert_true(bool(story.get("completed", true)), "a missing story block backfills as completed")
	assert_eq((view.get("unlocked_features", []) as Array).size(), StoryService.FEATURES.size(),
		"old saves keep every feature unlocked")


# ── helpers ──


func _start_run(seed_value: int, extra: Dictionary = {}) -> AppContext:
	var boot := bootstrap_core(extra)
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {"build_id": BUILD_ID, "seed": seed_value})
	assert_true(bool(result.get("ok", false)), "run.start should succeed: %s" % str(result))
	return context


func _start_tutorial(seed_value: int, extra: Dictionary = {}) -> AppContext:
	var boot := bootstrap_core(extra)
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {
		"build_id": BUILD_ID,
		"seed": seed_value,
		"tutorial": true,
	})
	assert_true(bool(result.get("ok", false)), "tutorial run.start should succeed: %s" % str(result))
	return context


func _view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"story.view")
	return result.get("data", {}) if bool(result.get("ok", false)) else {}
