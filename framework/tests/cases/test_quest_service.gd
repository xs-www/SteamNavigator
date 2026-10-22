extends TestCase
## @static-doc
## 作用：C3 抽象任务（Quest）运行时测试：`data.quests` 惰性状态 + 存档 round-trip、
## `QuestService` 状态机（auto_start / start / observe / complete / prerequisites /
## repeatable）、counter 去重、contract 实例保护、CrossReferenceValidator 的 quest 引用/
## 事件格式校验，委托接取生成 contract 追踪实例与完成联动，以及 `task.view` 的 quest 聚合。
##
## - 关键依赖：`bootstrap_core()`、`QuestOps`、`QuestService`、`ContentTypes.QUEST`、
##   `ContractOps.complete`、`TaskViewQuery`、`SaveService`
##
## ## 契约与约束
## - 用真实 Core 的 `core:quest/first_voyage_guide`（3 stage / guide）验证完整推进；
##   需要 prerequisites / repeatable 等边界时用「core 基线 + 合成 quest 定义」的 hub，
##   不改 dev_mods/core。
## - contract 来源实例只做追踪：不复制委托 payload，不重复出现在 task.view。
## - 旧档无 `data.quests` 块时行为不变（无任务、不 bump schema_version）。
## @end-static-doc

const SEED := 20260421
const STEADY_BUILD := "core:starting_build/steady"
const GUIDE_QUEST := "core:quest/first_voyage_guide"


# ── data.quests persistence ──


func test_quests_block_is_lazy_and_survives_save() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var fresh := GameState.new({"schema_version": GameState.SCHEMA_VERSION})
	assert_true(QuestOps.instances(fresh).is_empty(), "a state without quests reads no instances")
	assert_false(fresh.data.has("quests"), "read-only access never creates the block")
	QuestOps.ensure(fresh)
	assert_true(fresh.data["quests"] is Dictionary, "ensure creates the quests block")
	assert_eq(int((fresh.data["quests"] as Dictionary).get("schema_version", 0)), 1, "quests block version is 1")
	assert_eq(fresh.schema_version(), GameState.SCHEMA_VERSION, "adding quests never bumps state schema")

	var started := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": SEED})
	assert_true(bool(started.get("ok", false)), "run starts: %s" % str(started))
	# C3 auto_start: core's first-voyage guide is already active right after the run starts.
	var auto_instance := QuestOps.active_content_instance(context.state, GUIDE_QUEST)
	assert_false(auto_instance.is_empty(), "the auto_start guide quest starts with the run")
	var before := context.state.hash()
	var saved := context.save.save_slot("quests", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "save succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("quests")
	assert_true(bool(loaded.get("ok", false)), "load succeeds: %s" % str(loaded))
	var loaded_state: GameState = loaded["state"]
	assert_eq(loaded_state.hash(), before, "quest progress round-trips byte for byte")
	assert_eq(QuestOps.instances(loaded_state).size(), QuestOps.instances(context.state).size(), "instances survive load")
	var instance := QuestOps.active_content_instance(loaded_state, GUIDE_QUEST)
	assert_false(instance.is_empty(), "the active quest survives load")


func test_old_state_without_quests_has_no_quest_tasks() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": SEED})
	assert_true(bool(started.get("ok", false)), "run starts")
	# Simulate an old save: drop the block entirely.
	context.state.data.erase("quests")
	var result := context.queries.execute(&"task.view")
	assert_true(bool(result.get("ok", false)), "task.view answers on an old state")
	for task in (result["data"] as Dictionary).get("tasks", []):
		assert_ne(String((task as Dictionary).get("kind", "")), "quest", "no quest task without a quests block")
	assert_false(context.state.data.has("quests"), "task.view is read-only")


# ── contract coupling ──


func test_contract_accept_creates_tracking_instance() -> void:
	var context := _start_run()
	var main_contract: Variant = context.state.contracts().get("main", null)
	assert_true(main_contract is Dictionary, "the run auto-accepts a main contract")
	var contract_id := String((main_contract as Dictionary).get("instance_id", ""))
	var instance := QuestOps.find_by_contract(context.state, contract_id)
	assert_false(instance.is_empty(), "accepting a contract creates its quest tracking instance")
	assert_eq(String(instance.get("source", "")), QuestOps.SOURCE_CONTRACT, "the instance is contract-sourced")
	assert_eq(String(instance.get("quest_id", "")), String((main_contract as Dictionary).get("template_id", "")),
		"the tracking instance references the contract template")
	assert_eq(String(instance.get("status", "")), QuestOps.STATUS_ACTIVE, "the tracking instance is active")
	assert_eq(String(instance.get("contract_instance_id", "")), contract_id, "the instance stores the contract reference")
	# Idempotent: re-tracking the same contract never duplicates the instance.
	var count := QuestOps.instances(context.state).size()
	QuestService.track_contract(context.state, main_contract as Dictionary)
	assert_eq(QuestOps.instances(context.state).size(), count, "contract tracking is idempotent")


func test_contract_completion_marks_tracking_instance_completed() -> void:
	var context := _start_run()
	var main_contract: Dictionary = context.state.contracts()["main"]
	var contract_id := String(main_contract.get("instance_id", ""))
	var result := ContractOps.complete(context.state, context.registries, main_contract, 5.0)
	assert_true(bool((result as Dictionary).get("instance_id", "") != ""), "the contract completes")
	var instance := QuestOps.find_by_contract(context.state, contract_id)
	assert_eq(String(instance.get("status", "")), QuestOps.STATUS_COMPLETED, "the tracking instance completes with the contract")
	assert_almost_eq(float(instance.get("completed_at", 0.0)), 5.0, 0.0001, "the completion time is stored")


# ── QuestService state machine ──


func test_guide_quest_advances_stages_and_completes() -> void:
	var context := _start_run()
	var instance := QuestOps.active_content_instance(context.state, GUIDE_QUEST)
	assert_false(instance.is_empty(), "the guide quest auto-starts with the run")
	var duplicate := context.commands.execute(&"quest.start", {"quest_id": GUIDE_QUEST})
	assert_false(bool(duplicate.get("ok", false)), "the same quest cannot be started twice")
	assert_eq(String(duplicate.get("error_code", "")), "quest_already_active", "duplicate reports quest_already_active")

	# Stage 0: buy 4 coal (match item_id) and 2 water (match item_id). Command
	# payloads are replayed directly so the test does not depend on cargo weight.
	var coal_observed := context.commands.execute(&"quest.observe", {
		"event": "cmd:supply.buy_coal", "data": {"item_id": "core:item/coal", "amount": 4},
	})
	assert_true(bool(coal_observed.get("ok", false)), "quest.observe succeeds")
	assert_true(bool(coal_observed.get("autosave", false)), "quest.observe asks for an autosave")
	var instance_after_coal := QuestOps.active_content_instance(context.state, GUIDE_QUEST)
	assert_eq(int(instance_after_coal.get("stage_index", -1)), 0, "one of two stage-0 objectives is not enough")
	assert_eq(int((instance_after_coal.get("counters", {}) as Dictionary).get("coal_bought", 0)), 4, "coal counter accumulates")
	var observed := context.commands.execute(&"quest.observe", {
		"event": "cmd:supply.buy_water", "data": {"item_id": "core:item/water", "amount": 2},
	})
	assert_true(bool(observed.get("data", {}).get("advanced", false)), "stage 0 completes when both objectives are met")
	instance = QuestOps.find_instance(context.state, String(instance.get("instance_id", "")))
	assert_eq(int(instance.get("stage_index", -1)), 1, "the quest advances to stage 1")

	# Stage 1: start a voyage.
	var voyage := context.commands.execute(&"voyage.start", {"destination_id": String(context.state.contracts()["main"]["destination"])})
	observed = context.commands.execute(&"quest.observe", {
		"event": "cmd:voyage.start", "data": voyage.get("data", {}),
	})
	assert_true(bool(observed.get("data", {}).get("advanced", false)), "stage 1 completes on voyage.start")
	# Stage 2: arrival settles.
	observed = context.commands.execute(&"quest.observe", {"event": "ui:arrival_settled", "data": {}})
	assert_true(bool(observed.get("data", {}).get("advanced", false)), "stage 2 completes on arrival")
	instance = QuestOps.find_instance(context.state, String(instance.get("instance_id", "")))
	assert_eq(String(instance.get("status", "")), QuestOps.STATUS_COMPLETED, "the quest completes after its last stage")
	var completed_events := 0
	for event in Array(observed.get("events", [])):
		if String((event as Dictionary).get("type", "")) == QuestService.EVENT_COMPLETED:
			completed_events += 1
	assert_true(completed_events >= 1, "quest.completed is emitted")


func test_complete_command_completes_once() -> void:
	var context := _start_run()
	var auto_instance := QuestOps.active_content_instance(context.state, GUIDE_QUEST)
	var instance_id := String(auto_instance.get("instance_id", ""))
	var completed := context.commands.execute(&"quest.complete", {"instance_id": instance_id})
	assert_true(bool(completed.get("ok", false)), "quest.complete succeeds: %s" % str(completed))
	var again := context.commands.execute(&"quest.complete", {"instance_id": instance_id})
	assert_false(bool(again.get("ok", false)), "completing twice fails")
	assert_eq(String(again.get("error_code", "")), "quest_not_active", "second completion reports quest_not_active")


func test_unknown_quest_and_missing_parameters() -> void:
	var context := _start_run()
	var unknown := context.commands.execute(&"quest.start", {"quest_id": "test:quest/absent"})
	assert_false(bool(unknown.get("ok", false)), "unknown quest fails")
	assert_eq(String(unknown.get("error_code", "")), "unknown_quest", "unknown quest error code")
	var missing := context.commands.execute(&"quest.start", {})
	assert_eq(String(missing.get("error_code", "")), "missing_quest_id", "missing quest id is reported")
	var no_event := context.commands.execute(&"quest.observe", {})
	assert_eq(String(no_event.get("error_code", "")), "missing_event", "missing observe event is reported")


# ── prerequisites / repeatable (synthetic quest definitions on a copied hub) ──


func test_prerequisites_and_repeatable() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var alpha := _quest_definition("test:quest/alpha", {
		"kind": "guide",
		"stages": [{
			"id": "one",
			"title_key": "test.quest.alpha.stage",
			"objectives": [{"event": "cmd:test.one", "counter": "one_done", "at_least": 2}],
		}],
	})
	var beta := _quest_definition("test:quest/beta", {
		"kind": "guide",
		"prerequisites": {"quests_completed": ["test:quest/alpha"]},
		"stages": [{
			"id": "one",
			"title_key": "test.quest.beta.stage",
			"objectives": [{"event": "cmd:test.two", "counter": "two_done", "at_least": 1}],
		}],
	})
	var flagged := _quest_definition("test:quest/flagged", {
		"kind": "system",
		"prerequisites": {"flags": ["test.quest.unlocked"]},
		"stages": [{
			"id": "one",
			"title_key": "test.quest.flagged.stage",
			"objectives": [{"event": "cmd:test.three", "counter": "three_done", "at_least": 1}],
		}],
	})
	var repeating := _quest_definition("test:quest/repeating", {
		"kind": "system",
		"repeatable": true,
		"stages": [{
			"id": "one",
			"title_key": "test.quest.repeating.stage",
			"objectives": [{"event": "cmd:test.four", "counter": "four_done", "at_least": 1}],
		}],
	})
	context.registries = _hub_with(context.registries, [alpha, beta, flagged, repeating])
	var started := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": SEED})
	assert_true(bool(started.get("ok", false)), "run starts on the synthetic hub: %s" % str(started))

	var beta_result := context.commands.execute(&"quest.start", {"quest_id": "test:quest/beta"})
	assert_false(bool(beta_result.get("ok", false)), "beta cannot start before alpha is completed")
	assert_eq(String(beta_result.get("error_code", "")), "quest_prerequisites", "prerequisite failure code")
	var flag_result := context.commands.execute(&"quest.start", {"quest_id": "test:quest/flagged"})
	assert_eq(String(flag_result.get("error_code", "")), "quest_prerequisites", "flag prerequisite failure code")

	var alpha_start := context.commands.execute(&"quest.start", {"quest_id": "test:quest/alpha"})
	assert_true(bool(alpha_start.get("ok", false)), "alpha starts: %s" % str(alpha_start))
	assert_true(bool(alpha_start.get("autosave", false)), "quest.start asks for an autosave")
	# at_least = 2: one event is progress, the second completes it.
	context.commands.execute(&"quest.observe", {"event": "cmd:test.one", "data": {}})
	var alpha_instance := QuestOps.active_content_instance(context.state, "test:quest/alpha")
	assert_eq(int((alpha_instance.get("counters", {}) as Dictionary).get("one_done", 0)), 1, "partial progress is countable")
	context.commands.execute(&"quest.observe", {"event": "cmd:test.one", "data": {}})
	assert_true(QuestOps.active_content_instance(context.state, "test:quest/alpha").is_empty(), "alpha completes")
	assert_contains(QuestOps.completed_quest_ids(context.state), "test:quest/alpha", "alpha is recorded as completed")

	var beta_start := context.commands.execute(&"quest.start", {"quest_id": "test:quest/beta"})
	assert_true(bool(beta_start.get("ok", false)), "beta starts after alpha completes: %s" % str(beta_start))
	context.state.ensure_story()["flags"]["test.quest.unlocked"] = true
	var flagged_start := context.commands.execute(&"quest.start", {"quest_id": "test:quest/flagged"})
	assert_true(bool(flagged_start.get("ok", false)), "flagged starts once the story flag is set: %s" % str(flagged_start))

	# repeatable: complete, then start again.
	var repeat_start := context.commands.execute(&"quest.start", {"quest_id": "test:quest/repeating"})
	var repeat_instance := String(repeat_start["data"]["instance"].get("instance_id", ""))
	context.commands.execute(&"quest.observe", {"event": "cmd:test.four", "data": {}})
	assert_eq(String(QuestOps.find_instance(context.state, repeat_instance).get("status", "")), QuestOps.STATUS_COMPLETED, "repeating quest completes")
	var repeat_again := context.commands.execute(&"quest.start", {"quest_id": "test:quest/repeating"})
	assert_true(bool(repeat_again.get("ok", false)), "a repeatable quest can start again")
	assert_ne(String(repeat_again["data"]["instance"].get("instance_id", "")), repeat_instance, "instances get fresh ids")


# ── task.view aggregation ──


func test_task_view_aggregates_content_quests_without_duplicating_contracts() -> void:
	var context := _start_run()
	var before := _task_view(context)
	# C3: run start auto-starts the core guide quest, so the contract task + quest task exist.
	assert_eq((before.get("tasks", []) as Array).size(), 2, "the auto-started quest joins the main contract task")
	var data := before
	var tasks: Array = data.get("tasks", [])
	var quest_task := _task_of_kind(data, "quest")
	assert_false(quest_task.is_empty(), "task.view exposes the auto-started quest")
	assert_eq(int(quest_task.get("priority", 0)), 250, "quest priority sits between story and main")
	assert_eq(String(quest_task.get("category_key", "")), "quest.tracking.guide", "the category key comes from content tracking")
	assert_false(String(quest_task.get("title_key", "")).is_empty(), "the stage title key is exposed")
	assert_eq(int(quest_task.get("stage_index", -1)), 0, "the current stage is exposed")
	var steps: Array = quest_task.get("steps", [])
	assert_eq(steps.size(), 2, "stage 0 has two objectives")
	var first_step: Dictionary = steps[0]
	assert_eq(String(first_step.get("kind", "")), "objective", "quest steps are objective steps")
	assert_eq(int(first_step.get("target", 0)), 4, "the objective target comes from content")
	var current: Dictionary = quest_task.get("current_step", {})
	assert_eq(int(current.get("progress", -1)), 0, "the current objective starts at zero progress")
	# Buying coal updates the counter and therefore the derived task progress.
	context.commands.execute(&"quest.observe", {
		"event": "cmd:supply.buy_coal", "data": {"item_id": "core:item/coal", "amount": 2},
	})
	quest_task = _task_of_kind(_task_view(context), "quest")
	assert_eq(int((quest_task.get("current_step", {}) as Dictionary).get("progress", -1)), 2, "task progress follows the quest counters")
	# Contract-source instances never render as a second task.
	var contract_instance := QuestOps.find_by_contract(
		context.state, String(context.state.contracts()["main"].get("instance_id", ""))
	)
	assert_false(contract_instance.is_empty(), "the main contract has a tracking instance")
	var contract_instance_id := String(contract_instance.get("instance_id", ""))
	for task in (data.get("tasks", []) as Array):
		assert_ne(String((task as Dictionary).get("id", "")), "quest:%s" % contract_instance_id,
			"contract-source quest instances are not rendered as quest tasks")


# ── auto_start / counter dedupe / guards / content validation ──


func test_auto_start_is_idempotent_and_content_driven() -> void:
	var context := _start_run()
	var guide := QuestOps.active_content_instance(context.state, GUIDE_QUEST)
	assert_false(guide.is_empty(), "the core guide auto-starts with the run")
	assert_eq(String(guide.get("instance_id", "")), "%s#1" % GUIDE_QUEST, "the auto-start instance uses the first deterministic id")
	assert_eq(String(guide.get("source", "")), QuestOps.SOURCE_CONTENT, "auto-start creates a content instance")
	assert_true(QuestOps.active_content_instance(context.state, "core:quest/shipyard_refit").is_empty(),
		"quests with auto_start:false stay manual")
	# The HUD/task tracker sees the quest right after run.start, before any manual command.
	var quest_task := _task_of_kind(_task_view(context), "quest")
	assert_false(quest_task.is_empty(), "the auto-started quest is visible to task.view at run start")
	# auto_start is idempotent: re-running it never duplicates the instance.
	var before_count := QuestOps.instances(context.state).size()
	var again := QuestService.auto_start(context)
	assert_true(bool(again.get("ok", false)), "auto_start succeeds when re-run")
	assert_true(Array((again.get("data", {}) as Dictionary).get("started", [])).is_empty(), "re-running auto_start starts nothing")
	assert_eq(QuestOps.instances(context.state).size(), before_count, "auto_start never duplicates instances")
	# Manual content quests still start through the command and request an autosave.
	var manual := context.commands.execute(&"quest.start", {"quest_id": "core:quest/shipyard_refit"})
	assert_true(bool(manual.get("ok", false)), "a manual quest starts: %s" % str(manual))
	assert_true(bool(manual.get("autosave", false)), "quest.start requests an autosave")


func test_one_observe_adds_a_shared_counter_once() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	# Two objectives share the same explicit counter: a single event must add its
	# amount once, otherwise the stage would complete after one event instead of two.
	var dedupe := _quest_definition("test:quest/dedupe", {
		"kind": "guide",
		"stages": [{
			"id": "one",
			"title_key": "test.quest.dedupe.stage",
			"objectives": [
				{"event": "cmd:test.shared", "counter": "shared", "at_least": 2},
				{"event": "cmd:test.shared", "counter": "shared", "at_least": 2},
			],
		}],
	})
	context.registries = _hub_with(context.registries, [dedupe])
	var started := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": SEED})
	assert_true(bool(started.get("ok", false)), "run starts on the synthetic hub: %s" % str(started))
	var quest_start := context.commands.execute(&"quest.start", {"quest_id": "test:quest/dedupe"})
	assert_true(bool(quest_start.get("ok", false)), "dedupe quest starts: %s" % str(quest_start))
	context.commands.execute(&"quest.observe", {"event": "cmd:test.shared", "data": {"amount": 1}})
	var instance := QuestOps.active_content_instance(context.state, "test:quest/dedupe")
	assert_eq(int((instance.get("counters", {}) as Dictionary).get("shared", 0)), 1,
		"one event increments a shared counter exactly once")
	assert_eq(int(instance.get("stage_index", -1)), 0, "one event is not enough for target 2")
	context.commands.execute(&"quest.observe", {"event": "cmd:test.shared", "data": {"amount": 1}})
	instance = QuestOps.find_instance(context.state, String(instance.get("instance_id", "")))
	assert_eq(int((instance.get("counters", {}) as Dictionary).get("shared", 0)), 2, "the second event reaches the target")
	assert_true(QuestOps.active_content_instance(context.state, "test:quest/dedupe").is_empty(), "the quest completes")


func test_quest_complete_rejects_contract_instances() -> void:
	var context := _start_run()
	var main_contract: Dictionary = context.state.contracts()["main"]
	var tracking := QuestOps.find_by_contract(context.state, String(main_contract.get("instance_id", "")))
	assert_false(tracking.is_empty(), "the accepted contract is tracked")
	var result := context.commands.execute(&"quest.complete", {"instance_id": String(tracking.get("instance_id", ""))})
	assert_false(bool(result.get("ok", false)), "contract-source quests cannot be completed manually")
	assert_eq(String(result.get("error_code", "")), "quest_source_forbidden", "the guard reports quest_source_forbidden")
	assert_eq(String(QuestOps.find_instance(context.state, String(tracking.get("instance_id", ""))).get("status", "")),
		QuestOps.STATUS_ACTIVE, "the contract tracking instance stays active")


func test_quest_validator_reports_dangling_references_and_bad_events() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var dangling := _quest_definition("test:quest/dangling", {
		"kind": "guide",
		"prerequisites": {"quests_completed": ["test:quest/absent"]},
		"stages": [{
			"id": "one",
			"title_key": "test.quest.dangling.stage",
			"objectives": [{"event": "trade.buy", "counter": "x", "at_least": 1}],
		}],
	})
	var hub := _hub_with(context.registries, [dangling])
	var validator := CrossReferenceValidator.new()
	var report := validator.validate(hub)
	var codes := PackedStringArray()
	for error in report.get("errors", []):
		codes.append(String((error as Dictionary).get("code", "")))
	assert_contains(codes, "quest_prerequisite_missing", "a dangling quest prerequisite is an error")
	assert_contains(codes, "quest_event_invalid", "an objective event without cmd:/ui: prefix is an error")
	# Core's own quests raise no quest-level validation errors.
	var quest_errors := 0
	for error in report.get("errors", []):
		if String((error as Dictionary).get("code", "")).begins_with("quest_"):
			quest_errors += 1
	assert_eq(quest_errors, 2, "only the two synthetic problems are reported")
	for error in report.get("errors", []):
		assert_ne(String((error as Dictionary).get("owner", "")), GUIDE_QUEST, "core guide passes quest validation")


# ── helpers ──


func _task_view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"task.view")
	assert_true(bool(result.get("ok", false)), "task.view succeeds")
	return result.get("data", {}) if bool(result.get("ok", false)) else {}


func _task_of_kind(data: Dictionary, kind: String) -> Dictionary:
	for task in Array(data.get("tasks", [])):
		if task is Dictionary and String((task as Dictionary).get("kind", "")) == kind:
			return task
	return {}


func _start_run() -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {
		"build_id": STEADY_BUILD,
		"seed": SEED,
	})
	assert_true(bool(result.get("ok", false)), "run.start should succeed: %s" % str(result))
	return context


func _quest_definition(quest_id: String, data: Dictionary) -> ContentDefinition:
	var definition := ContentDefinition.new()
	definition.id = quest_id
	definition.content_type = ContentTypes.QUEST
	definition.name_key = "%s.name" % quest_id
	definition.enabled = true
	definition.source_mod = "test"
	definition.data = data.duplicate(true)
	definition.raw = {"id": quest_id, "name_key": definition.name_key, "data": definition.data.duplicate(true)}
	return definition


func _hub_with(baseline: RegistryHub, quests: Array) -> RegistryHub:
	var hub := RegistryHub.new(ContentTypes.all())
	for content_type in ContentTypes.all():
		for definition in baseline.get_all(content_type):
			hub.register(definition)
	for definition in quests:
		hub.register(definition)
	hub.freeze_all()
	return hub
