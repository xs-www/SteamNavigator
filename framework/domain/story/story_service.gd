class_name StoryService
extends RefCounted
## @static-doc
## 作用：新手剧情 / 教学系统的领域状态机。读取当前 map profile 的
## `data.story`（Core JSON）阶段表，维护 `GameState.data.story` 的进度、事件计数、
## 标志、功能 / 商品 / 模块解锁，并分发「发现委托目的港」等剧情效果。
##
## - 关键依赖：`GameState.ensure_story()`、`ContentTypes.MAP_PROFILE`、`WorldOps`、
##   `MapOps`、`GameState.contracts()`
##
## ## 契约与约束
## - 剧情步骤 / 文案 / 解锁 / 数值全部来自 Core JSON；框架只认识 feature 键
##   （`FEATURES`）与效果类型，不写死内容 ID。
## - `data.story` 惰性 ensure：旧存档没有该块时视为「已看完 / 已跳过」，功能全开、
##   不弹剧情（`completed=true`），不改 `schema_version`。
## - 阶段推进：`mode=confirm` 由 `story.advance` 推进；条件型阶段在
##   `story.observe(event, data)` 中按 `event / counter / at_least / flag / all`
##   评估，可一次跨多个阶段。未知效果只 warning，不崩。
## - 跳过教程必须解锁 `skip_unlocks` 里的全部功能并执行
##   `discover_contract_destination`，保证跳过不会卡死。
## - 查询（`story.view`）只输出公开字段；counters / flags 只暴露剧情效果需要的
##   `lock_actions` 语义，不泄露内部数值。
## @end-static-doc

## 框架功能键（不是内容 ID）：与 Shell 的导航 / 入口一一对应。
const FEATURE_OVERVIEW := "overview"
const FEATURE_SUPPLY := "supply"
const FEATURE_CHART := "chart"
const FEATURE_MARKET := "market"
const FEATURE_CONTRACTS := "contracts"
const FEATURE_CLUES := "clues"
const FEATURE_TAVERN := "tavern"
const FEATURE_SHIPYARD := "shipyard"
const FEATURES := [
	FEATURE_OVERVIEW, FEATURE_SUPPLY, FEATURE_CHART, FEATURE_MARKET,
	FEATURE_CONTRACTS, FEATURE_CLUES, FEATURE_TAVERN, FEATURE_SHIPYARD,
]

const EVENT_STAGE_ENTERED := "story.stage_entered"
const EVENT_COMPLETED := "story.completed"
const EVENT_FEATURE_UNLOCKED := "story.feature_unlocked"


## Reads the story block of the current map profile (`{}` when the profile has none).
static func config(state: GameState, hub: RegistryHub) -> Dictionary:
	if state == null or hub == null:
		return {}
	var profile_id := String(state.world().get("map_profile_id", ""))
	if profile_id.is_empty():
		return {}
	var profile: ContentDefinition = hub.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	if profile == null:
		return {}
	var raw: Variant = profile.data.get("story", null)
	return raw if raw is Dictionary else {}


## Initializes a fresh run's story state from Core JSON. Also used by `skip` fallback.
static func begin(state: GameState, hub: RegistryHub) -> void:
	var cfg := config(state, hub)
	var story := state.ensure_story()
	if cfg.is_empty() or not bool(cfg.get("enabled", false)):
		story["active"] = false
		story["completed"] = true
		story["unlocked_features"] = FEATURES.duplicate()
		return
	story["flow_id"] = String(cfg.get("flow_id", ""))
	story["stage_index"] = -1
	story["active"] = true
	story["completed"] = false
	story["skipped"] = false
	story["seen"] = []
	story["counters"] = {}
	story["flags"] = {}
	story["unlocked_features"] = []
	story["unlocked_items"] = Array(cfg.get("start_items", [])).duplicate()
	story["unlocked_modules"] = Array(cfg.get("start_modules", [])).duplicate()
	for feature in Array(cfg.get("start_unlocks", [])):
		_unlock_feature(story, String(feature))
	_enter_stage(state, hub, story, cfg, 0)


## Read-only ViewModel consumed by the Shell (story card / objective / gating).
static func view(context) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var cfg := config(state, hub)
	var story := state.ensure_story()
	var enabled := not cfg.is_empty() and bool(cfg.get("enabled", false))
	var result := {
		"enabled": enabled,
		"active": bool(story.get("active", false)),
		"completed": bool(story.get("completed", true)),
		"skipped": bool(story.get("skipped", false)),
		"flow_id": String(story.get("flow_id", "")),
		"stage_index": int(story.get("stage_index", -1)),
		"stage_id": "",
		"card": null,
		"objective": null,
		"unlocked_features": Array(story.get("unlocked_features", [])).duplicate(),
		"unlocked_items": Array(story.get("unlocked_items", [])).duplicate(),
		"unlocked_modules": Array(story.get("unlocked_modules", [])).duplicate(),
		"lock_actions": [],
		"can_skip": bool(story.get("active", false)) and not bool(story.get("completed", true)),
	}
	# 未启用 / 已结束 / 旧存档：功能全开（Shell 不做门禁）。
	if not enabled or not bool(story.get("active", false)) or bool(story.get("completed", true)):
		result["unlocked_features"] = FEATURES.duplicate()
		return result
	var stages: Array = cfg.get("stages", [])
	var index := int(story.get("stage_index", -1))
	if index < 0 or index >= stages.size():
		return result
	var stage: Dictionary = stages[index]
	result["stage_id"] = String(stage.get("id", ""))
	var seen: Array = story.get("seen", [])
	if stage.has("dialogue") and not seen.has(String(stage.get("id", ""))):
		var dialogue: Dictionary = stage.get("dialogue", {})
		result["card"] = {
			"title_key": String(dialogue.get("title_key", "")),
			"body_keys": Array(dialogue.get("body_keys", [])).duplicate(),
			"advance_label_key": "ui.story.continue",
			"skip_label_key": "ui.story.skip",
		}
	var objective: Variant = stage.get("objective", null)
	if objective is Dictionary:
		var progress := _objective_progress(stage, story)
		result["objective"] = {
			"text_key": String((objective as Dictionary).get("text_key", "")),
			"progress": progress,
			"target": int((objective as Dictionary).get("target", 0)),
		}
	result["lock_actions"] = Array(stage.get("lock_actions", [])).duplicate()
	return result


## Player pressed "continue" on a story card (`mode=confirm` stages only).
static func advance(context) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var cfg := config(state, hub)
	var story := state.ensure_story()
	if not bool(story.get("active", false)) or bool(story.get("completed", true)):
		return Result.fail("story_inactive", "ui.error.story_inactive")
	var stages: Array = cfg.get("stages", [])
	var index := int(story.get("stage_index", -1))
	if index < 0 or index >= stages.size():
		return Result.fail("story_inactive", "ui.error.story_inactive")
	var stage: Dictionary = stages[index]
	var advance_cfg: Dictionary = stage.get("advance", {})
	if String(advance_cfg.get("mode", "")) != "confirm":
		# 非 confirm 阶段（有目标）的剧情卡只是「读一下」：继续 = 收起卡片，
		# 目标条出现；阶段仍按事件 / 计数推进。
		_mark_seen(story, stage)
		return Result.ok({"view": view(context)}, [])
	var events: Array = []
	_mark_seen(story, stage)
	_enter_stage(state, hub, story, cfg, index + 1, events)
	var result := Result.ok({"view": view(context)}, events)
	if bool(story.get("completed", false)):
		result["autosave"] = true
	return result


## Skip the whole tutorial: unlock everything configured and never soft-lock the run.
static func skip(context) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var cfg := config(state, hub)
	var story := state.ensure_story()
	if not bool(story.get("active", false)) or bool(story.get("completed", true)):
		return Result.fail("story_inactive", "ui.error.story_inactive")
	story["active"] = false
	story["completed"] = true
	story["skipped"] = true
	for feature in Array(cfg.get("skip_unlocks", FEATURES)):
		_unlock_feature(story, String(feature))
	if Array(cfg.get("skip_unlocks", [])).is_empty():
		for feature in FEATURES:
			_unlock_feature(story, feature)
	_apply_effect(state, hub, story, {"type": "discover_contract_destination"})
	var events: Array = [{
		"type": EVENT_COMPLETED,
		"payload": {"flow_id": String(story.get("flow_id", "")), "skipped": true},
	}]
	var result := Result.ok({"view": view(context)}, events)
	result["autosave"] = true
	return result


## Shell forwards successful commands / UI events here. Returns an advanced story result
## (`ok` with no events when nothing matched).
static func observe(context, event: String, data: Dictionary = {}) -> Dictionary:
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var cfg := config(state, hub)
	var story := state.ensure_story()
	if event.is_empty() or not bool(story.get("active", false)) or bool(story.get("completed", true)):
		return Result.ok({})
	var stages: Array = cfg.get("stages", [])
	var index := int(story.get("stage_index", -1))
	if index < 0 or index >= stages.size():
		return Result.ok({})
	var stage: Dictionary = stages[index]
	var advance_cfg: Dictionary = stage.get("advance", {})
	if String(advance_cfg.get("mode", "")) == "confirm":
		return Result.ok({})
	var conditions: Array = []
	if advance_cfg.has("all"):
		conditions = Array(advance_cfg.get("all", []))
	else:
		conditions = [advance_cfg]
	if conditions.is_empty():
		return Result.ok({})
	var events: Array = []
	if not _conditions_met(story, conditions, event, data):
		return Result.ok({"view": view(context)})
	_mark_seen(story, stage)
	_enter_stage(state, hub, story, cfg, index + 1, events)
	var result := Result.ok({"view": view(context)}, events)
	if bool(story.get("completed", false)):
		result["autosave"] = true
	return result


# ---------------------------------------------------------------------------
# Stage transitions / requirements
# ---------------------------------------------------------------------------


static func _enter_stage(
	state: GameState, hub: RegistryHub, story: Dictionary, cfg: Dictionary,
	index: int, events: Array = []
) -> void:
	var stages: Array = cfg.get("stages", [])
	if index < 0 or index >= stages.size():
		_complete(story, cfg, events)
		return
	var stage: Dictionary = stages[index]
	story["stage_index"] = index
	for feature in Array(stage.get("unlock_features", [])):
		if _unlock_feature(story, String(feature)):
			events.append(_feature_event(String(feature)))
	for item_id in Array(stage.get("unlock_items", [])):
		_unlock_list_entry(story, "unlocked_items", String(item_id))
	for module_id in Array(stage.get("unlock_modules", [])):
		_unlock_list_entry(story, "unlocked_modules", String(module_id))
	for effect in Array(stage.get("effects", [])):
		if effect is Dictionary:
			_apply_effect(state, hub, story, effect as Dictionary)
	events.append({
		"type": EVENT_STAGE_ENTERED,
		"payload": {
			"flow_id": String(story.get("flow_id", "")),
			"stage_index": index,
			"stage_id": String(stage.get("id", "")),
		},
	})


static func _complete(story: Dictionary, cfg: Dictionary, events: Array = []) -> void:
	story["active"] = false
	story["completed"] = true
	var unlocks: Array = cfg.get("skip_unlocks", FEATURES)
	if unlocks.is_empty():
		unlocks = FEATURES
	for feature in unlocks:
		_unlock_feature(story, String(feature))
	events.append({
		"type": EVENT_COMPLETED,
		"payload": {"flow_id": String(story.get("flow_id", "")), "skipped": false},
	})


static func _conditions_met(story: Dictionary, conditions: Array, event: String, data: Dictionary) -> bool:
	# Accumulate every counter referenced by this event exactly once, then evaluate.
	var seen_counters := {}
	var amount := 1
	if data.has("amount"):
		amount = int(data.get("amount", 1))
	for raw in conditions:
		if not (raw is Dictionary):
			continue
		var condition: Dictionary = raw
		if String(condition.get("event", "")) != event:
			continue
		var counter := String(condition.get("counter", ""))
		if counter.is_empty() or seen_counters.has(counter):
			continue
		seen_counters[counter] = true
		var counters: Dictionary = story.get("counters", {})
		counters[counter] = int(counters.get(counter, 0)) + amount
		story["counters"] = counters
	for raw in conditions:
		if not (raw is Dictionary):
			return false
		var condition: Dictionary = raw
		var expected_event := String(condition.get("event", ""))
		if not expected_event.is_empty() and expected_event != event:
			return false
		var counter := String(condition.get("counter", ""))
		if not counter.is_empty():
			var at_least := int(condition.get("at_least", 1))
			if int((story.get("counters", {}) as Dictionary).get(counter, 0)) < at_least:
				return false
		var flag := String(condition.get("flag", ""))
		if not flag.is_empty() and not bool((story.get("flags", {}) as Dictionary).get(flag, false)):
			return false
		var not_flag := String(condition.get("not_flag", ""))
		if not not_flag.is_empty() and bool((story.get("flags", {}) as Dictionary).get(not_flag, false)):
			return false
	return true


static func _objective_progress(stage: Dictionary, story: Dictionary) -> int:
	var advance_cfg: Dictionary = stage.get("advance", {})
	var conditions: Array = []
	if advance_cfg.has("all"):
		conditions = Array(advance_cfg.get("all", []))
	else:
		conditions = [advance_cfg]
	for raw in conditions:
		if not (raw is Dictionary):
			continue
		var counter := String((raw as Dictionary).get("counter", ""))
		if not counter.is_empty():
			return int((story.get("counters", {}) as Dictionary).get(counter, 0))
	return 0


# ---------------------------------------------------------------------------
# Effects / helpers
# ---------------------------------------------------------------------------


static func _apply_effect(state: GameState, hub: RegistryHub, story: Dictionary, effect: Dictionary) -> void:
	var type := String(effect.get("type", ""))
	match type:
		"unlock_features":
			for feature in Array(effect.get("features", [])):
				_unlock_feature(story, String(feature))
		"set_flag":
			var flags: Dictionary = story.get("flags", {})
			flags[String(effect.get("flag", ""))] = bool(effect.get("value", true))
			story["flags"] = flags
		"clear_flag":
			var clear_flags: Dictionary = story.get("flags", {})
			clear_flags.erase(String(effect.get("flag", "")))
			story["flags"] = clear_flags
		"discover_contract_destination":
			_discover_contract_destination(state, hub)
		"complete_story":
			_complete(story, config(state, hub))
		_:
			push_warning("StoryService: unknown effect type '%s' (ignored)" % type)


## Reveals the auto-accepted main contract destination on both the played and the
## coordinate map. This is the guaranteed first-voyage affordance (and the skip
## safety net): the contract paper names the harbour.
static func _discover_contract_destination(state: GameState, _hub: RegistryHub) -> void:
	var main_contract: Variant = state.contracts().get("main", null)
	if not (main_contract is Dictionary):
		return
	var destination := String((main_contract as Dictionary).get("destination", ""))
	if destination.is_empty():
		return
	MapOps.discover(state, destination)
	WorldOps.discover_port_id(state, destination)


static func _unlock_feature(story: Dictionary, feature: String) -> bool:
	if feature.is_empty() or not FEATURES.has(feature):
		return false
	var unlocked: Array = story.get("unlocked_features", [])
	if unlocked.has(feature):
		return false
	unlocked.append(feature)
	story["unlocked_features"] = unlocked
	return true


static func _unlock_list_entry(story: Dictionary, key: String, value: String) -> void:
	if value.is_empty():
		return
	var entries: Array = story.get(key, [])
	if not entries.has(value):
		entries.append(value)
		story[key] = entries


static func _mark_seen(story: Dictionary, stage: Dictionary) -> void:
	var stage_id := String(stage.get("id", ""))
	if stage_id.is_empty():
		return
	var seen: Array = story.get("seen", [])
	if not seen.has(stage_id):
		seen.append(stage_id)
		story["seen"] = seen


static func _feature_event(feature: String) -> Dictionary:
	return {"type": EVENT_FEATURE_UNLOCKED, "payload": {"feature": feature}}
