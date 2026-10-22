class_name QuestService
extends RefCounted
## @static-doc
## 作用：抽象任务（Quest）状态机（C3）。把 `quests` 2.0 内容定义（stage 链 + 目标 DSL）
## 实例化进 `data.quests`，按 `cmd:*` / `ui:*` 事件推进 counter、跨 stage 前进并完成；
## 委托接取时生成 contract 来源的追踪实例，委托完成时标记该实例 completed。
##
## - 关键依赖：`ContentTypes.QUEST`、`QuestOps`、`GameState.ensure_story()`（前置 flag）、
##   `ContentDefinition`、`Result`
##
## ## 契约与约束
## - **Contract 独立**：quest 不复制委托 payload / 目的地 / 时限 / 奖励；contract 来源
##   实例只存 `contract_instance_id` 作追踪引用，进度与结算仍由 `ContractOps` 负责。
## - 起点：`start(context, quest_id)` 校验定义存在、`repeatable`、重复接取与
##   `prerequisites.quests_completed / flags`（flag 读 `data.story.flags`）；
##   成功返回 `autosave:true`（任务进度需要落盘）。
## - **auto_start**：`auto_start_state(state, hub)` 在 run 初始化末尾（1.0 `RunFactory` 与
##   v2 `CampaignFactory`）启动所有 enabled 且 `data.auto_start == true` 的 content quest；
##   幂等（已 active / 已完成 / 前置不满足只记入 `skipped`，绝不失败开局），定义按 id 排序。
## - 推进：`observe(context, event, data)` 只作用于 active **content** 实例；目标复用剧情
##   DSL（`event` / `counter` / `at_least` / `match`），`payload.amount` 累加到 counter，
##   无 counter 的目标使用隐式出现次数计数；本 stage 全部 objective 达标才前进。
##   **一次 observe 对同一 counter 只累加一次 amount**（多个 objective 共享 counter 不双加）。
##   成功返回 `autosave:true`。
## - 完成：最后一个 stage 达标或 `complete()` 手动完成；重复完成/接取返回结构化失败。
##   `complete()` 拒绝 `source == "contract"` 的追踪实例（`quest_source_forbidden`），
##   委托实例的生命周期由 `ContractOps` 驱动。
## - 事件：`quest.started` / `quest.updated` / `quest.completed`（payload 只含实例引用与
##   stage 序号，不含内容 payload）。
## - 存档：状态只在 `data.quests`（`QuestOps` 惰性 ensure），不改 `state.schema_version`；
##   旧档无块 = 无任务，行为不变。
## - `instance_view()` 给 `task.view` / 命令返回用：标题与 steps 全部来自内容 key，不写死 ID。
## @end-static-doc

const EVENT_STARTED := "quest.started"
const EVENT_UPDATED := "quest.updated"
const EVENT_COMPLETED := "quest.completed"

## `task.view` 中内容任务的固定优先级（story 300 > quest 250 > main 200 > contract 100）。
const TASK_PRIORITY := 250
const TASK_KIND := "quest"
const TASK_CATEGORY_KEY := "ui.task.kind.quest"

const STEP_KIND := "objective"


# ---------------------------------------------------------------------------
# Content helpers
# ---------------------------------------------------------------------------


static func definition(hub: RegistryHub, quest_id: String) -> ContentDefinition:
	if hub == null or quest_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.QUEST, quest_id)


static func stages_of(hub: RegistryHub, quest_id: String) -> Array:
	var quest := definition(hub, quest_id)
	if quest == null:
		return []
	var raw: Variant = quest.data.get("stages", [])
	return raw if raw is Array else []


## Read-only current stage dictionary for an instance ({} when the quest is done).
static func current_stage(hub: RegistryHub, instance: Dictionary) -> Dictionary:
	var stages := stages_of(hub, String(instance.get("quest_id", "")))
	var index := int(instance.get("stage_index", 0))
	if index < 0 or index >= stages.size():
		return {}
	var stage: Variant = stages[index]
	return stage if stage is Dictionary else {}


# ---------------------------------------------------------------------------
# Commands (called inside a CommandBus transaction)
# ---------------------------------------------------------------------------


static func start(context, quest_id: String) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var result := start_state(context.state, context.registries, quest_id)
	if bool(result.get("ok", false)):
		result["autosave"] = true
	return result


## Context-free start used by `start()` and the run-initialisation `auto_start_state()`.
static func start_state(state: GameState, hub: RegistryHub, quest_id: String) -> Dictionary:
	var quest := definition(hub, quest_id)
	if quest == null or not quest.enabled:
		return Result.fail("unknown_quest", "ui.error.unknown_quest", {"quest_id": quest_id})
	var data: Dictionary = quest.data
	if not QuestOps.active_content_instance(state, quest_id).is_empty():
		return Result.fail("quest_already_active", "ui.error.quest_already_active", {"quest_id": quest_id})
	var completed := QuestOps.completed_quest_ids(state)
	if not bool(data.get("repeatable", false)) and completed.has(quest_id):
		return Result.fail("quest_already_completed", "ui.error.quest_already_completed", {"quest_id": quest_id})
	var unmet := _unmet_prerequisites(state, data)
	if not unmet.is_empty():
		return Result.fail("quest_prerequisites", "ui.error.quest_prerequisites", unmet)
	var instance := QuestOps.create_content_instance(state, quest_id, state.now())
	var events: Array = [{
		"type": EVENT_STARTED,
		"payload": {
			"instance_id": String(instance.get("instance_id", "")),
			"quest_id": quest_id,
			"source": QuestOps.SOURCE_CONTENT,
		},
	}]
	return Result.ok({
		"instance": instance.duplicate(true),
		"view": instance_view(state, hub, instance),
	}, events)


## Starts every enabled content quest with `data.auto_start == true` (C3 `auto_start`
## runtime, called at the end of run initialisation). Idempotent: already active /
## completed (non-repeatable) / prerequisite-blocked quests are reported as skipped
## instead of failing the run. Iterates definitions by id for deterministic order.
static func auto_start_state(state: GameState, hub: RegistryHub) -> Dictionary:
	var started: Array = []
	var skipped: Array = []
	var events: Array = []
	if state == null or hub == null:
		return Result.ok({"started": started, "skipped": skipped}, events)
	var quest_ids: Array[String] = []
	for quest in hub.get_all(ContentTypes.QUEST):
		quest_ids.append(quest.id)
	quest_ids.sort()
	for quest_id in quest_ids:
		var quest := definition(hub, quest_id)
		if quest == null or not quest.enabled or not bool(quest.data.get("auto_start", false)):
			continue
		if not QuestOps.active_content_instance(state, quest_id).is_empty():
			skipped.append({"quest_id": quest_id, "reason": "already_active"})
			continue
		if not bool(quest.data.get("repeatable", false)) and QuestOps.completed_quest_ids(state).has(quest_id):
			skipped.append({"quest_id": quest_id, "reason": "already_completed"})
			continue
		if not _unmet_prerequisites(state, quest.data).is_empty():
			skipped.append({"quest_id": quest_id, "reason": "prerequisites"})
			continue
		var result := start_state(state, hub, quest_id)
		if bool(result.get("ok", false)):
			started.append(String((result["data"]["instance"] as Dictionary).get("instance_id", "")))
			events.append_array(Array(result.get("events", [])))
		else:
			skipped.append({"quest_id": quest_id, "reason": String(result.get("error_code", ""))})
	return Result.ok({"started": started, "skipped": skipped, "count": started.size()}, events)


## Command-shaped wrapper for `auto_start_state` (e.g. future debug commands / tests).
static func auto_start(context) -> Dictionary:
	if context == null or not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var result := auto_start_state(context.state, context.registries)
	if bool(result.get("ok", false)) and not Array(result.get("data", {}).get("started", [])).is_empty():
		result["autosave"] = true
	return result


## Manual completion (system hooks / debugging). The normal path is `observe()`.
static func complete(context, instance_id: String) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var instance := QuestOps.find_instance(state, instance_id)
	if instance.is_empty():
		return Result.fail("quest_instance_not_found", "ui.error.quest_instance_not_found", {"instance_id": instance_id})
	# Contract 追踪实例的生命周期由 ContractOps 驱动，不能手动完成。
	if String(instance.get("source", "")) == QuestOps.SOURCE_CONTRACT:
		return Result.fail("quest_source_forbidden", "ui.error.quest_source_forbidden", {
			"instance_id": instance_id,
			"source": QuestOps.SOURCE_CONTRACT,
		})
	if String(instance.get("status", "")) != QuestOps.STATUS_ACTIVE:
		return Result.fail("quest_not_active", "ui.error.quest_not_active", {"instance_id": instance_id})
	QuestOps.mark_completed(instance, state.now())
	var result := Result.ok({
		"instance": instance.duplicate(true),
		"view": instance_view(state, hub, instance),
	}, [{
		"type": EVENT_COMPLETED,
		"payload": {
			"instance_id": String(instance.get("instance_id", "")),
			"quest_id": String(instance.get("quest_id", "")),
			"source": String(instance.get("source", "")),
		},
	}])
	result["autosave"] = true
	return result


## Advances every active content quest whose current stage objectives match the
## observed `cmd:*` / `ui:*` event. Unknown events never fail.
static func observe(context, event: String, data: Dictionary = {}) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var result := {"advanced": false, "progressed": false, "completed": []}
	if event.is_empty() or not _has_active_content(state):
		var idle := Result.ok(result)
		idle["autosave"] = true
		return idle
	var events: Array = []
	for raw_instance in QuestOps.instances(state):
		if not (raw_instance is Dictionary):
			continue
		var instance: Dictionary = raw_instance
		if not QuestOps.is_active_content(instance):
			continue
		var quest_id := String(instance.get("quest_id", ""))
		var quest := definition(hub, quest_id)
		if quest == null:
			continue
		var stages: Array = quest.data.get("stages", []) if quest.data.get("stages", []) is Array else []
		var index := int(instance.get("stage_index", 0))
		if index < 0 or index >= stages.size():
			# Content shrank below the saved stage index: finish instead of stalling.
			_finish(state, instance, events)
			result["advanced"] = true
			result["progressed"] = true
			continue
		var stage: Dictionary = stages[index]
		var stage_state := _observe_stage(instance, stage, event, data)
		if not bool(stage_state.get("changed", false)) and not bool(stage_state.get("done", false)):
			continue
		result["progressed"] = true
		if not bool(stage_state.get("done", false)):
			continue
		instance["stage_index"] = index + 1
		result["advanced"] = true
		if int(instance["stage_index"]) >= stages.size():
			_finish(state, instance, events)
			result["completed"].append(String(instance.get("instance_id", "")))
		else:
			events.append(_updated_event(instance))
	var observed := Result.ok(result, events)
	observed["autosave"] = true
	return observed


# ---------------------------------------------------------------------------
# Contract coupling (called from ContractOps / StoryService on the command state)
# ---------------------------------------------------------------------------


## Creates the tracking instance for a freshly accepted contract. Idempotent.
static func track_contract(state: GameState, contract: Dictionary) -> Dictionary:
	if state == null or contract.is_empty():
		return {}
	var contract_instance_id := String(contract.get("instance_id", ""))
	if contract_instance_id.is_empty():
		return {}
	var quest_id := String(contract.get("template_id", contract.get("name_key", "")))
	return QuestOps.create_contract_instance(state, contract_instance_id, quest_id, state.now())


## Marks the tracking instance of a completed contract as completed.
static func complete_contract_by_instance(state: GameState, contract_instance_id: String, completed_at: float = 0.0) -> Dictionary:
	if state == null or contract_instance_id.is_empty():
		return {}
	var instance := QuestOps.find_by_contract(state, contract_instance_id)
	if instance.is_empty():
		return {}
	QuestOps.mark_completed(instance, completed_at)
	return instance


# ---------------------------------------------------------------------------
# Views (read-only; used by commands and task.view)
# ---------------------------------------------------------------------------


## One content quest instance as a Task-compatible view. Contract-source instances
## are intentionally not exposed as quest tasks (task.view keeps deriving those from
## the accepted contract to avoid double rendering).
static func instance_view(state: GameState, hub: RegistryHub, instance: Dictionary) -> Dictionary:
	var quest_id := String(instance.get("quest_id", ""))
	var quest := definition(hub, quest_id)
	var stages: Array = quest.data.get("stages", []) if quest != null and quest.data.get("stages", []) is Array else []
	var index := clampi(int(instance.get("stage_index", 0)), 0, maxi(stages.size() - 1, 0))
	var stage: Dictionary = stages[index] if index < stages.size() else {}
	var tracking: Dictionary = {}
	if quest != null and quest.data.get("tracking", null) is Dictionary:
		tracking = quest.data["tracking"]
	var label_key := String(tracking.get("label_key", ""))
	var category_key := label_key if not label_key.is_empty() else TASK_CATEGORY_KEY
	var title_key := String(stage.get("title_key", ""))
	if title_key.is_empty() and quest != null:
		title_key = quest.name_key
	var steps: Array = []
	var objectives: Array = stage.get("objectives", []) if stage.get("objectives", []) is Array else []
	for objective_index in objectives.size():
		var raw_objective: Variant = objectives[objective_index]
		if not (raw_objective is Dictionary):
			continue
		var objective: Dictionary = raw_objective
		var target := maxi(1, int(objective.get("at_least", 1)))
		var progress := mini(target, _objective_progress(instance, stage, objective_index, objective))
		var objective_text_key := String(objective.get("text_key", ""))
		if objective_text_key.is_empty():
			objective_text_key = title_key
		steps.append({
			"kind": STEP_KIND,
			"done": progress >= target,
			"progress": progress,
			"target": target,
			"text_key": objective_text_key,
			"item_name_key": "",
			"destination_name_key": "",
			"fuel_sourced": false,
		})
	var current_index := -1
	for step_index in steps.size():
		if not bool((steps[step_index] as Dictionary).get("done", false)):
			current_index = step_index
			break
	return {
		"instance_id": String(instance.get("instance_id", "")),
		"source": String(instance.get("source", "")),
		"quest_id": quest_id,
		"status": String(instance.get("status", "")),
		"stage_index": index,
		"stage_count": stages.size(),
		"stage_id": String(stage.get("id", "")),
		"kind": String(quest.data.get("kind", "")) if quest != null else "",
		"title_key": title_key,
		"category_key": category_key,
		"hidden": bool(tracking.get("hidden", false)),
		"priority": TASK_PRIORITY,
		"tracking_priority": int(tracking.get("priority", 0)),
		"steps": steps,
		"current_step_index": current_index,
		"current_step": (steps[current_index] as Dictionary).duplicate(true) if current_index >= 0 else null,
	}


## Read-only list of active content quest views (hidden ones included).
static func active_instances(state: GameState, hub: RegistryHub = null) -> Array:
	var result: Array = []
	for instance in QuestOps.instances(state):
		if not (instance is Dictionary) or not QuestOps.is_active_content(instance):
			continue
		if hub != null:
			result.append(instance_view(state, hub, instance))
		else:
			result.append((instance as Dictionary).duplicate(true))
	return result


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------


## Cheap read-only check so callers (Shell) can skip a command transaction when
## nothing can advance.
static func has_active_content(state: GameState) -> bool:
	return _has_active_content(state)


static func _has_active_content(state: GameState) -> bool:
	for instance in QuestOps.instances(state):
		if instance is Dictionary and QuestOps.is_active_content(instance):
			return true
	return false


static func _updated_event(instance: Dictionary) -> Dictionary:
	return {
		"type": EVENT_UPDATED,
		"payload": {
			"instance_id": String(instance.get("instance_id", "")),
			"quest_id": String(instance.get("quest_id", "")),
			"stage_index": int(instance.get("stage_index", 0)),
		},
	}


static func _finish(state: GameState, instance: Dictionary, events: Array) -> void:
	if not QuestOps.mark_completed(instance, state.now()):
		return
	events.append({
		"type": EVENT_COMPLETED,
		"payload": {
			"instance_id": String(instance.get("instance_id", "")),
			"quest_id": String(instance.get("quest_id", "")),
			"source": String(instance.get("source", "")),
		},
	})


## Increments counters for matching objectives. Returns `{changed, done}` where
## `changed` means an objective counter moved and `done` means the whole stage is
## now satisfied (all objectives at/above their target).
##
## One observed event adds `amount` to each distinct matched counter exactly once,
## even when several objectives share that counter (D-fix: no double counting).
static func _observe_stage(instance: Dictionary, stage: Dictionary, event: String, data: Dictionary) -> Dictionary:
	var objectives: Array = stage.get("objectives", []) if stage.get("objectives", []) is Array else []
	var counters: Dictionary = instance.get("counters", {})
	var matched_counters: Array[String] = []
	var amount := 1
	if data.has("amount"):
		amount = maxi(1, int(data.get("amount", 1)))
	for objective_index in objectives.size():
		var raw_objective: Variant = objectives[objective_index]
		if not (raw_objective is Dictionary):
			continue
		var objective: Dictionary = raw_objective
		var expected_event := String(objective.get("event", ""))
		if expected_event != event:
			continue
		if not _matches(objective, data):
			continue
		var counter := _counter_key(stage, objective_index, objective)
		if not matched_counters.has(counter):
			matched_counters.append(counter)
	var changed := not matched_counters.is_empty()
	for counter in matched_counters:
		counters[counter] = int(counters.get(counter, 0)) + amount
	if changed:
		instance["counters"] = counters
	return {"changed": changed, "done": _objectives_met(instance, stage)}


static func _objectives_met(instance: Dictionary, stage: Dictionary) -> bool:
	var objectives: Array = stage.get("objectives", []) if stage.get("objectives", []) is Array else []
	if objectives.is_empty():
		return true
	var counters: Dictionary = instance.get("counters", {})
	for objective_index in objectives.size():
		var raw_objective: Variant = objectives[objective_index]
		if not (raw_objective is Dictionary):
			continue
		var objective: Dictionary = raw_objective
		var counter := _counter_key(stage, objective_index, objective)
		var target := maxi(1, int(objective.get("at_least", 1)))
		if int(counters.get(counter, 0)) < target:
			return false
	return true


## Explicit `counter` is shared between objectives on purpose; objectives without
## one use a stable implicit key so repeated events can still satisfy at_least > 1.
static func _counter_key(stage: Dictionary, objective_index: int, objective: Dictionary) -> String:
	var counter := String(objective.get("counter", ""))
	if not counter.is_empty():
		return counter
	return "_objective:%s:%d" % [String(stage.get("id", "stage")), objective_index]


static func _objective_progress(instance: Dictionary, stage: Dictionary, objective_index: int, objective: Dictionary) -> int:
	var counters: Dictionary = instance.get("counters", {})
	return int(counters.get(_counter_key(stage, objective_index, objective), 0))


static func _matches(objective: Dictionary, data: Dictionary) -> bool:
	var expected: Variant = objective.get("match", null)
	if not (expected is Dictionary):
		return true
	for key in (expected as Dictionary).keys():
		if String(data.get(key, "")) != String((expected as Dictionary)[key]):
			return false
	return true


static func _unmet_prerequisites(state: GameState, quest_data: Dictionary) -> Dictionary:
	var raw: Variant = quest_data.get("prerequisites", null)
	if not (raw is Dictionary):
		return {}
	var prerequisites: Dictionary = raw
	var missing_quests: Array = []
	var completed := QuestOps.completed_quest_ids(state)
	for quest_id in Array(prerequisites.get("quests_completed", [])):
		if not completed.has(String(quest_id)):
			missing_quests.append(String(quest_id))
	var missing_flags: Array = []
	var story_flags: Dictionary = state.ensure_story().get("flags", {})
	for flag in Array(prerequisites.get("flags", [])):
		if not bool(story_flags.get(String(flag), false)):
			missing_flags.append(String(flag))
	if missing_quests.is_empty() and missing_flags.is_empty():
		return {}
	return {"quests": missing_quests, "flags": missing_flags}
