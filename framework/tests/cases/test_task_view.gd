extends TestCase
## @static-doc
## 作用：任务追踪聚合查询（`task.view`，阶段 4.6 Phase A）测试：剧情目标 / 待接主线 /
## 已接主线的 Task 形状、委托步骤（接取 / 备货 / 前往 / 交付）与优先级排序。
##
## ## 契约与约束
## - 只读聚合：测试只调用 `run.start` / `contract.accept` / `supply.buy_coal`
##   等现有命令，再断言 `task.view` 派生结果；不写任务状态。
## - 普通可接委托池不生成 Task；只有 main_offer / main / active 进入列表。
## - 任务名 / 货物名输出内容 key，测试不依赖具体中文文案。
## @end-static-doc

const SEED := 20260421
const STEADY_BUILD := "core:starting_scenario/steady"


func test_task_view_without_a_run_is_empty() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := context.queries.execute(&"task.view")
	assert_true(bool(result.get("ok", false)), "task.view succeeds without a run")
	var data: Dictionary = result.get("data", {})
	assert_false(bool(data.get("has_run", true)), "no run means no tasks")
	assert_eq((data.get("tasks", []) as Array).size(), 0, "task list is empty")


func test_pending_main_offer_is_a_task() -> void:
	var context := _start_run()
	# 新局默认自动接主线；把当前主线转成待接 offer 以验证 offer 任务。
	var contracts: Dictionary = context.state.contracts()
	var main_contract: Variant = contracts.get("main", null)
	assert_true(main_contract is Dictionary, "the run has an accepted main contract")
	contracts["main_offer"] = (main_contract as Dictionary).duplicate(true)
	contracts["main"] = null
	var data := _task_view(context)
	var tasks: Array = data.get("tasks", [])
	assert_eq(tasks.size(), 2, "the auto-started quest and the pending main offer are tracked")
	var task := _task(data, "main_offer")
	assert_false(task.is_empty(), "the pending offer is a main offer task")
	assert_eq(String(task.get("category_key", "")), "ui.task.kind.main_offer", "the category is content-keyed")
	var steps: Array = task.get("steps", [])
	assert_eq(steps.size(), 1, "an offer has a single accept step")
	assert_eq(String((steps[0] as Dictionary).get("kind", "")), "accept", "the offer step is accept")
	assert_false(bool((steps[0] as Dictionary).get("done", true)), "the offer is not accepted yet")
	assert_eq(String(data.get("active_task_id", "")), String(_task(data, "quest").get("id", "")),
		"the auto-started quest outranks the pending main offer")


func test_main_contract_derives_load_sail_and_deliver_steps() -> void:
	var context := _start_run()
	var data := _task_view(context)
	var task := _task(data, "main")
	assert_false(task.is_empty(), "the accepted main contract is tracked")
	var steps: Array = task.get("steps", [])
	assert_true(_has_step(steps, "load"), "a fuel contract starts with the load step")
	assert_true(_has_step(steps, "sail"), "the task points at the destination")
	var load := _step(steps, "load")
	assert_eq(String(load.get("item_name_key", "")).is_empty(), false, "the load step names its item")
	# 普通（非玩家自备）委托货箱在接取时自动装船，因此备货步骤立即完成。
	assert_true(bool(load.get("done", false)), "auto-loaded contract cargo completes the load step")
	assert_eq(int(load.get("progress", 0)), int(load.get("target", 0)), "load progress reaches the target")
	assert_eq(String((task.get("current_step", {}) as Dictionary).get("kind", "")), "sail",
		"the current step is sailing to the destination")
	assert_eq(String((task.get("current_step", {}) as Dictionary).get("destination_name_key", "")).is_empty(), false,
		"the sail step names the destination")
	var destination := String(task.get("destination_id", ""))
	assert_false(destination.is_empty(), "the contract task exposes its destination id")
	# 抵达目的港后，航行与交付步骤都完成。
	context.state.world()["current_port_id"] = destination
	context.state.mark_port_visited(destination)
	data = _task_view(context)
	task = _task(data, "main")
	steps = task.get("steps", [])
	var sail := _step(steps, "sail")
	assert_true(bool(sail.get("done", false)), "the sail step completes at the destination")
	var deliver := _step(steps, "deliver")
	assert_true(bool(deliver.get("done", false)), "the deliver step is ready at the destination")
	assert_true(task.get("current_step", null) == null, "all steps are complete at the destination")


func test_story_objective_is_the_highest_priority_task() -> void:
	var context := _start_tutorial()
	context.commands.execute(&"story.advance", {})
	var data := _task_view(context)
	var tasks: Array = data.get("tasks", [])
	assert_true(not tasks.is_empty(), "the tutorial objective is tracked")
	var first: Dictionary = tasks[0]
	assert_eq(String(first.get("kind", "")), "story", "the story objective outranks contracts")
	assert_eq(int(first.get("priority", 0)), 300, "the story priority is the highest")
	var step: Dictionary = first.get("current_step", {})
	assert_eq(String(step.get("kind", "")), "objective", "the story task carries an objective step")
	assert_eq(int(step.get("target", 0)), 4, "the objective target comes from story.view")
	assert_false(String(step.get("text_key", "")).is_empty(), "the objective text key is preserved")


func test_active_contract_is_tracked_but_the_offer_pool_is_not() -> void:
	var context := _start_run()
	# 普通可接委托池不进入任务列表。
	var offers: Array = context.state.contracts().get("offers", [])
	assert_true(not offers.is_empty(), "the run has normal offers")
	var before := (_task_view(context).get("tasks", []) as Array).size()
	assert_eq(before, 2, "the auto-started guide quest and the main contract are tasks; offers are not")
	# 先清空自动装船的主线货箱 / 主线槽位，避免载重与主线占用影响普通委托。
	context.state.contracts()["main"] = null
	context.state.ship()["cargo"] = []
	var accepted := false
	for raw_offer in offers:
		if not (raw_offer is Dictionary):
			continue
		var result := context.commands.execute(&"contract.accept", {
			"instance_id": String((raw_offer as Dictionary).get("instance_id", "")),
		})
		if bool(result.get("ok", false)):
			accepted = true
			break
	assert_true(accepted, "a normal contract can be accepted")
	var tasks: Array = _task_view(context).get("tasks", [])
	assert_eq(tasks.size(), 2, "the accepted normal contract joins the still-active quest task")
	var kinds := []
	for task in tasks:
		if task is Dictionary:
			kinds.append(String((task as Dictionary).get("kind", "")))
	assert_true(kinds.has("contract"), "the normal contract is tracked as a contract task")


func test_content_quest_is_tracked_between_story_and_contracts() -> void:
	var context := _start_run()
	# C3 auto_start: the core guide is already tracked when the run starts.
	var data := _task_view(context)
	var tasks: Array = data.get("tasks", [])
	assert_eq(tasks.size(), 2, "the auto-started quest joins the accepted main contract")
	var quest_task := _task(data, "quest")
	assert_false(quest_task.is_empty(), "task.view exposes the content quest")
	assert_eq(int(quest_task.get("priority", 0)), 250, "quest priority sits between story and main")
	assert_eq(String(quest_task.get("category_key", "")), "quest.tracking.guide", "the quest category is content-keyed")
	assert_eq(int(quest_task.get("stage_index", -1)), 0, "the quest exposes its current stage")
	var current: Dictionary = quest_task.get("current_step", {})
	assert_eq(String(current.get("kind", "")), "objective", "quest steps reuse the objective step kind")
	assert_eq(int(current.get("target", 0)), 4, "the objective target comes from quest content")
	assert_false(String(current.get("text_key", "")).is_empty(), "the objective text key is preserved")
	# contract 来源实例不重复渲染：任务列表里仍只有主委托这一条委托任务。
	var contract_tasks := 0
	for task in tasks:
		if String((task as Dictionary).get("kind", "")) == "main":
			contract_tasks += 1
	assert_eq(contract_tasks, 1, "contract-source quest instances do not double-render the contract")


# ── helpers ──


func _task_view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"task.view")
	assert_true(bool(result.get("ok", false)), "task.view succeeds")
	return result.get("data", {}) if bool(result.get("ok", false)) else {}


func _task(data: Dictionary, kind: String) -> Dictionary:
	for task in Array(data.get("tasks", [])):
		if task is Dictionary and String((task as Dictionary).get("kind", "")) == kind:
			return task
	return {}


func _step(steps: Array, kind: String) -> Dictionary:
	for step in steps:
		if step is Dictionary and String((step as Dictionary).get("kind", "")) == kind:
			return step
	return {}


func _has_step(steps: Array, kind: String) -> bool:
	return not _step(steps, kind).is_empty()


func _start_run() -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": SEED,
	})
	assert_true(bool(result.get("ok", false)), "run.start should succeed: %s" % str(result))
	return context


func _start_tutorial() -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": SEED,
		"tutorial": true,
	})
	assert_true(bool(result.get("ok", false)), "tutorial run.start should succeed: %s" % str(result))
	return context
