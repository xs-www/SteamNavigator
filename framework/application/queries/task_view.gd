class_name TaskViewQuery
extends RefCounted
## @static-doc
## 作用：任务追踪聚合查询（`task.view`，阶段 4.6 Phase A / C3 Phase B）。只读地把剧情
## 当前目标、内容 Quest 实例、主线委托、已接普通委托聚合成统一的 Task 列表，并把委托
## 拆成「备货 / 接客 / 前往 / 抵达交付」步骤、把 Quest 拆成当前 stage 的 objective 步骤，
## 供 HUD 任务条与委托页任务面板显示。
##
## - 关键依赖：`StoryViewQuery`（仅取 objective 字段）、`QuestOps`（只读实例）、
##   `QuestService.instance_view()`、`GameState.contracts()`、
##   `ShipOps.cargo_amount` / `ShipOps.passenger_capacity`、`MapOps`
##
## ## 契约与约束
## - 只读：不写状态、不发事件、不创建 `data.quests` 块；任务与步骤全部从当前状态派生。
## - 只聚合「剧情目标 + 已接委托 + 待接主线 + active content Quest」；普通可接委托池与
##   `hidden` Quest 不进入任务列表。
## - **contract 来源的 Quest 实例不重复渲染**：委托任务仍由 `data.contracts` 推导，Quest
##   只贡献 content 来源任务，避免同一委托出现两条任务。
## - 目标名 / 货物名只输出内容 key（`*_name_key`），框架不写死内容 ID。
## - 不输出 `player_sourced` 等内部 payload 字段；步骤只暴露 UI 需要的
##   `kind / done / progress / target / 名称 key`。
## - 排序：剧情 300 > Quest 250 > 主线 200 > 待接主线 150 > 普通委托 100；同优先级先比
##   Quest 的 `tracking.priority`（降序），再按 id。
## @end-static-doc

const KIND_STORY := "story"
const KIND_QUEST := "quest"
const KIND_MAIN := "main"
const KIND_MAIN_OFFER := "main_offer"
const KIND_CONTRACT := "contract"

const STEP_OBJECTIVE := "objective"
const STEP_ACCEPT := "accept"
const STEP_LOAD := "load"
const STEP_PASSENGER := "passenger"
const STEP_SAIL := "sail"
const STEP_DELIVER := "deliver"


static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok(_empty())
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var tasks: Array = []
	var story_task := _story_task(context)
	if not story_task.is_empty():
		tasks.append(story_task)
	tasks.append_array(_quest_tasks(state, hub))
	var contracts: Dictionary = state.contracts()
	var main_contract: Variant = contracts.get("main", null)
	if main_contract is Dictionary:
		var task := _contract_task(state, hub, main_contract, KIND_MAIN)
		if not task.is_empty():
			tasks.append(task)
	var main_offer: Variant = contracts.get("main_offer", null)
	if main_offer is Dictionary:
		tasks.append(_offer_task(main_offer, state.now()))
	for raw_contract in Array(contracts.get("active", [])):
		if raw_contract is Dictionary:
			var task := _contract_task(state, hub, raw_contract, KIND_CONTRACT)
			if not task.is_empty():
				tasks.append(task)
	tasks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) != int(b.get("priority", 0)):
			return int(a.get("priority", 0)) > int(b.get("priority", 0))
		if int(a.get("tracking_priority", 0)) != int(b.get("tracking_priority", 0)):
			return int(a.get("tracking_priority", 0)) > int(b.get("tracking_priority", 0))
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return Result.ok({
		"has_run": true,
		"current_port_id": state.current_port_id(),
		"current_port_name_key": MapOps.port_display_key(state.world(), state.current_port_id()),
		"at_sea": not state.is_at_port(),
		"tasks": tasks,
		"task_count": tasks.size(),
		"active_task_id": String(tasks[0].get("id", "")) if not tasks.is_empty() else "",
		"active_task": tasks[0] if not tasks.is_empty() else null,
	})


## 剧情目标作为最高优先级任务；没有 active 剧情 / 目标时返回空。
static func _story_task(context) -> Dictionary:
	var story_result := StoryViewQuery.execute({}, context)
	if not bool(story_result.get("ok", false)):
		return {}
	var story: Dictionary = story_result.get("data", {})
	if not bool(story.get("active", false)) or bool(story.get("completed", true)):
		return {}
	var objective: Variant = story.get("objective", null)
	if not (objective is Dictionary):
		return {}
	var objective_data: Dictionary = objective
	var target := int(objective_data.get("target", 0))
	var progress := clampi(int(objective_data.get("progress", 0)), 0, maxi(target, 0))
	return {
		"id": "story",
		"kind": KIND_STORY,
		"category_key": "ui.task.kind.story",
		"title_key": "ui.task.kind.story",
		"destination_id": "",
		"destination_name_key": "",
		"deadline": 0.0,
		"remaining_hours": -1.0,
		"priority": 300,
		"steps": [{
			"kind": STEP_OBJECTIVE,
			"done": target > 0 and progress >= target,
			"progress": progress,
			"target": target,
			"text_key": String(objective_data.get("text_key", "")),
			"item_name_key": "",
			"destination_name_key": "",
			"fuel_sourced": false,
		}],
		"current_step_index": 0,
		"current_step": {
			"kind": STEP_OBJECTIVE,
			"done": false,
			"progress": progress,
			"target": target,
			"text_key": String(objective_data.get("text_key", "")),
		},
	}


## Active content Quest instances as Task rows (contract-source instances are skipped:
## their委托任务 is already derived from `data.contracts`).
static func _quest_tasks(state: GameState, hub: RegistryHub) -> Array:
	var result: Array = []
	for raw_instance in QuestOps.instances(state):
		if not (raw_instance is Dictionary):
			continue
		var instance: Dictionary = raw_instance
		if not QuestOps.is_active_content(instance):
			continue
		var view := QuestService.instance_view(state, hub, instance)
		if bool(view.get("hidden", false)):
			continue
		var current_step_view: Variant = view.get("current_step", null)
		result.append({
			"id": "quest:%s" % String(view.get("instance_id", "")),
			"kind": KIND_QUEST,
			"category_key": String(view.get("category_key", QuestService.TASK_CATEGORY_KEY)),
			"title_key": String(view.get("title_key", "")),
			"destination_id": "",
			"destination_name_key": "",
			"deadline": 0.0,
			"remaining_hours": -1.0,
			"priority": int(view.get("priority", QuestService.TASK_PRIORITY)),
			"tracking_priority": int(view.get("tracking_priority", 0)),
			"quest_id": String(view.get("quest_id", "")),
			"stage_index": int(view.get("stage_index", 0)),
			"stage_count": int(view.get("stage_count", 0)),
			"steps": Array(view.get("steps", [])).duplicate(true),
			"current_step_index": int(view.get("current_step_index", -1)),
			"current_step": (current_step_view as Dictionary).duplicate(true) if current_step_view is Dictionary else null,
		})
	return result


## 待接主线的任务只有一步「接取主线委托」。
static func _offer_task(offer: Dictionary, now: float) -> Dictionary:
	var destination := String(offer.get("destination", ""))
	var step := {
		"kind": STEP_ACCEPT,
		"done": false,
		"progress": 0,
		"target": 1,
		"text_key": "ui.task.step.accept",
		"item_name_key": "",
		"destination_name_key": "",
		"fuel_sourced": false,
	}
	return {
		"id": "main_offer:%s" % String(offer.get("instance_id", "")),
		"kind": KIND_MAIN_OFFER,
		"category_key": "ui.task.kind.main_offer",
		"title_key": String(offer.get("name_key", "ui.task.kind.main_offer")),
		"destination_id": destination,
		"destination_name_key": "",
		"deadline": float(offer.get("deadline", 0.0)),
		"remaining_hours": maxf(0.0, float(offer.get("deadline", 0.0)) - now),
		"priority": 150,
		"steps": [step],
		"current_step_index": 0,
		"current_step": step,
	}


static func _contract_task(
	state: GameState, hub: RegistryHub, contract: Dictionary, kind: String
) -> Dictionary:
	var destination := String(contract.get("destination", ""))
	var steps: Array = []
	var load := _load_step(state, hub, contract)
	if not load.is_empty():
		steps.append(load)
	var passenger := _passenger_step(contract)
	if not passenger.is_empty():
		steps.append(passenger)
	steps.append(_sail_step(state, destination))
	steps.append(_deliver_step(state, destination))
	var current_index := -1
	for index in steps.size():
		if not bool((steps[index] as Dictionary).get("done", false)):
			current_index = index
			break
	var current_step: Variant = steps[current_index] if current_index >= 0 else null
	var destination_name_key := (
		MapOps.port_display_key(state.world(), destination) if not destination.is_empty() else ""
	)
	var priority := 200 if kind == KIND_MAIN else 100
	return {
		"id": "%s:%s" % [kind, String(contract.get("instance_id", ""))],
		"kind": kind,
		"category_key": "ui.task.kind.%s" % kind,
		"title_key": String(contract.get("name_key", "ui.task.kind.%s" % kind)),
		"destination_id": destination,
		"destination_name_key": destination_name_key,
		"deadline": float(contract.get("deadline", 0.0)),
		"remaining_hours": maxf(0.0, float(contract.get("deadline", 0.0)) - state.now()),
		"priority": priority,
		"steps": steps,
		"current_step_index": current_index,
		"current_step": (current_step as Dictionary).duplicate(true) if current_step is Dictionary else null,
	}


## 备货步骤：按 payload 把「船上已有 / 需求」合并成一条进度。
static func _load_step(state: GameState, hub: RegistryHub, contract: Dictionary) -> Dictionary:
	var ship := state.ship()
	var required := 0
	var available := 0
	var first_item_key := ""
	var fuel_sourced := false
	for raw_entry in Array(contract.get("cargo", [])):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var amount := int(entry.get("amount", 0))
		if amount <= 0:
			continue
		var item_id := String(entry.get("item_id", ""))
		var item_available := 0
		if bool(entry.get("fuel_sourced", false)):
			fuel_sourced = true
			item_available = int(floor(float(ship.get("coal", 0.0))))
		else:
			item_available = ShipOps.cargo_amount(ship, item_id, true)
		required += amount
		available += mini(item_available, amount)
		if first_item_key.is_empty():
			var definition := ShipOps.item_definition(hub, item_id)
			first_item_key = definition.name_key if definition != null else item_id
	if required <= 0:
		return {}
	return {
		"kind": STEP_LOAD,
		"done": available >= required,
		"progress": clampi(available, 0, required),
		"target": required,
		"text_key": "ui.task.step.load",
		"item_name_key": first_item_key,
		"destination_name_key": "",
		"fuel_sourced": fuel_sourced,
	}


## 接客步骤：委托接取成功后旅客已经在船上，因此进度直接等于目标数。
static func _passenger_step(contract: Dictionary) -> Dictionary:
	var passengers := int(contract.get("passengers", 0))
	if passengers <= 0:
		return {}
	return {
		"kind": STEP_PASSENGER,
		"done": true,
		"progress": passengers,
		"target": passengers,
		"text_key": "ui.task.step.passenger",
		"item_name_key": "",
		"destination_name_key": "",
		"fuel_sourced": false,
	}


static func _sail_step(state: GameState, destination: String) -> Dictionary:
	var at_destination := destination == state.current_port_id()
	var sailing_there := false
	var voyage: Variant = state.data.get("voyage", null)
	if voyage is Dictionary:
		sailing_there = String((voyage as Dictionary).get("destination", "")) == destination
	return {
		"kind": STEP_SAIL,
		"done": at_destination,
		"progress": 1 if sailing_there else 0,
		"target": 1,
		"text_key": "ui.task.step.sail",
		"item_name_key": "",
		"destination_name_key": MapOps.port_display_key(state.world(), destination),
		"fuel_sourced": false,
	}


static func _deliver_step(state: GameState, destination: String) -> Dictionary:
	return {
		"kind": STEP_DELIVER,
		"done": destination == state.current_port_id(),
		"progress": 0,
		"target": 1,
		"text_key": "ui.task.step.deliver",
		"item_name_key": "",
		"destination_name_key": MapOps.port_display_key(state.world(), destination),
		"fuel_sourced": false,
	}


static func _empty() -> Dictionary:
	return {
		"has_run": false,
		"current_port_id": "",
		"current_port_name_key": "",
		"at_sea": false,
		"tasks": [],
		"task_count": 0,
		"active_task_id": "",
		"active_task": null,
	}
