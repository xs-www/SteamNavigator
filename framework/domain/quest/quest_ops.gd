class_name QuestOps
extends RefCounted
## @static-doc
## 作用：`data.quests` 持久任务状态的纯数据操作层（C3）。负责惰性 ensure、实例字段
## 规范化、按 id / 委托实例查找、新建实例与完成标记；不读取内容注册表、不发事件，
## 状态机语义在 `QuestService`，任务追踪展示在 `task.view`。
##
## - 关键依赖：`GameState.data`、`Result`（无；本类只返回数据）
##
## ## 契约与约束
## - 状态形状（任务契约）：`{schema_version: 1, instances: [{instance_id, source:
##   "content"|"contract", quest_id, contract_instance_id, stage_index, counters, flags,
##   status: "active"|"completed", started_at, completed_at}]}`；`data.quests` 惰性 ensure，
##   **不改 `state.schema_version`**，旧档无该块 = 没有任务。
## - 只存引用与进度（quest_id / contract_instance_id / counters / flags），不复制内容
##   定义的 payload、目的地、时限或奖励。
## - `ensure()` 是唯一写入口（命令事务内调用）；查询侧用 `instances()` / `find_*`
##   只读访问，缺失时返回空数组 / 空字典，不创建块。
## - `instance_id` 确定性：内容任务 `"<quest_id>#<n>"`（同任务第 n 次接取），委托追踪
##   `"contract:<contract_instance_id>"`；同 seed + 同操作序列可复现。
## - 进度字段（counters / flags / stage_index）逐键回填，读档后行为与旧档一致。
## @end-static-doc

const SECTION := "quests"
const SCHEMA_VERSION := 1

const SOURCE_CONTENT := "content"
const SOURCE_CONTRACT := "contract"

const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"

const SECTION_DEFAULTS := {
	"schema_version": SCHEMA_VERSION,
	"instances": [],
}

const INSTANCE_DEFAULTS := {
	"instance_id": "",
	"source": SOURCE_CONTENT,
	"quest_id": "",
	"contract_instance_id": "",
	"stage_index": 0,
	"counters": {},
	"flags": {},
	"status": STATUS_ACTIVE,
	"started_at": 0.0,
	"completed_at": 0.0,
}


## Creates / repairs `data.quests` in place and returns the section. Only called on
## the mutable command transaction state; queries use `instances()`.
static func ensure(state: GameState) -> Dictionary:
	var current: Variant = state.data.get(SECTION, null)
	if not (current is Dictionary):
		current = SECTION_DEFAULTS.duplicate(true)
		state.data[SECTION] = current
	var section: Dictionary = current
	if not section.has("schema_version"):
		section["schema_version"] = SCHEMA_VERSION
	var raw_instances: Variant = section.get("instances", null)
	if not (raw_instances is Array):
		section["instances"] = []
	for instance in section["instances"]:
		if instance is Dictionary:
			ensure_instance_fields(instance as Dictionary)
	return section


## Read-only accessor: never creates the block.
static func instances(state: GameState) -> Array:
	var current: Variant = state.data.get(SECTION, null)
	if not (current is Dictionary):
		return []
	var raw: Variant = (current as Dictionary).get("instances", null)
	return raw if raw is Array else []


## Normalizes one instance dictionary in place (missing fields lazily backfilled).
static func ensure_instance_fields(instance: Dictionary) -> Dictionary:
	for key in INSTANCE_DEFAULTS.keys():
		if not instance.has(key):
			instance[key] = _copy_default(INSTANCE_DEFAULTS[key])
	if not (instance.get("counters", null) is Dictionary):
		instance["counters"] = {}
	if not (instance.get("flags", null) is Dictionary):
		instance["flags"] = {}
	instance["stage_index"] = maxi(0, int(instance.get("stage_index", 0)))
	var status := String(instance.get("status", ""))
	if status != STATUS_ACTIVE and status != STATUS_COMPLETED:
		instance["status"] = STATUS_ACTIVE
	return instance


static func _copy_default(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


## Finds one instance by its stable instance id.
static func find_instance(state: GameState, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for instance in instances(state):
		if instance is Dictionary and String((instance as Dictionary).get("instance_id", "")) == instance_id:
			return instance
	return {}


## All instances of one content quest, oldest first.
static func find_by_quest(state: GameState, quest_id: String) -> Array:
	var result: Array = []
	if quest_id.is_empty():
		return result
	for instance in instances(state):
		if instance is Dictionary and String((instance as Dictionary).get("quest_id", "")) == quest_id:
			result.append(instance)
	return result


## Active instance of one content quest (contract instances never share quest ids).
static func active_content_instance(state: GameState, quest_id: String) -> Dictionary:
	for instance in find_by_quest(state, quest_id):
		if String((instance as Dictionary).get("status", "")) == STATUS_ACTIVE:
			return instance
	return {}


## Completed content quest ids, in completion order.
static func completed_quest_ids(state: GameState) -> Array:
	var result: Array = []
	for instance in instances(state):
		if not (instance is Dictionary):
			continue
		if String(instance.get("source", "")) != SOURCE_CONTENT:
			continue
		if String(instance.get("status", "")) != STATUS_COMPLETED:
			continue
		var quest_id := String(instance.get("quest_id", ""))
		if not quest_id.is_empty() and not result.has(quest_id):
			result.append(quest_id)
	return result


## Contract-source instance tracking one accepted contract ({} when untracked).
static func find_by_contract(state: GameState, contract_instance_id: String) -> Dictionary:
	if contract_instance_id.is_empty():
		return {}
	for instance in instances(state):
		if instance is Dictionary \
				and String((instance as Dictionary).get("contract_instance_id", "")) == contract_instance_id:
			return instance
	return {}


## Deterministic id for the next content-quest instance: "<quest_id>#<n>".
static func next_content_instance_id(state: GameState, quest_id: String) -> String:
	var count := find_by_quest(state, quest_id).size()
	return "%s#%d" % [quest_id, count + 1]


## Creates (and appends) a content-source instance starting at stage 0.
static func create_content_instance(state: GameState, quest_id: String, now: float = 0.0) -> Dictionary:
	ensure(state)
	var instance := INSTANCE_DEFAULTS.duplicate(true)
	instance["instance_id"] = next_content_instance_id(state, quest_id)
	instance["source"] = SOURCE_CONTENT
	instance["quest_id"] = quest_id
	instance["started_at"] = now
	(state.data[SECTION]["instances"] as Array).append(instance)
	return instance


## Creates (and appends) the tracking instance for one accepted contract. Idempotent.
static func create_contract_instance(state: GameState, contract_instance_id: String, quest_id: String, now: float = 0.0) -> Dictionary:
	var existing := find_by_contract(state, contract_instance_id)
	if not existing.is_empty():
		return existing
	ensure(state)
	var instance := INSTANCE_DEFAULTS.duplicate(true)
	instance["instance_id"] = "contract:%s" % contract_instance_id
	instance["source"] = SOURCE_CONTRACT
	instance["quest_id"] = quest_id
	instance["contract_instance_id"] = contract_instance_id
	instance["started_at"] = now
	(state.data[SECTION]["instances"] as Array).append(instance)
	return instance


## Marks an instance completed once; returns true only on the first transition.
static func mark_completed(instance: Dictionary, now: float = 0.0) -> bool:
	if instance.is_empty():
		return false
	if String(instance.get("status", "")) == STATUS_COMPLETED:
		return false
	instance["status"] = STATUS_COMPLETED
	instance["completed_at"] = now
	return true


## True when the instance is active content progress (contract tracking does not
## advance from content objectives).
static func is_active_content(instance: Dictionary) -> bool:
	return String(instance.get("source", "")) == SOURCE_CONTENT \
		and String(instance.get("status", "")) == STATUS_ACTIVE
