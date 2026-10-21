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
## - 4.5.4 效果：`grant_clue`（目标 `next_unknown` 时确定性选最近的未发现港并记忆，
##   第二次授予复用同一目标；等级 / 来源来自 Core）、`set_market_price_bias`
##   （把指定商品在起始港 / 其它港的库存与价格 bias 归位，保证教学价差稳定）、
##   `guarantee_explore_success`（只对刚授予的剧情线索生效，探索成功即消费）。
## - 4.5.5 效果：`add_facility`（给当前港补设施，第三港保证有船厂）、`upgrade_hull`
##   （换成 Core 指定、带客舱位的船体，旧船进仓库）；`module_filter()` 给船厂提供
##   `unlocked_modules` 裁剪，剧情期间只露出教学模块。
## - 跳过教程必须解锁 `skip_unlocks` 里的全部功能并执行
##   `discover_contract_destination`，保证跳过不会卡死；跳过不会设置保底探索。
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
static func begin(state: GameState, hub: RegistryHub, rng: RngService = null) -> void:
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
	story["home_port_id"] = state.current_port_id()
	story["seen"] = []
	story["counters"] = {}
	story["flags"] = {}
	story["unlocked_features"] = []
	story["unlocked_items"] = Array(cfg.get("start_items", [])).duplicate()
	story["unlocked_modules"] = Array(cfg.get("start_modules", [])).duplicate()
	for feature in Array(cfg.get("start_unlocks", [])):
		_unlock_feature(story, String(feature))
	_enter_stage(state, hub, story, cfg, 0, [], rng)


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
		"preferred_strategy": "",
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
	result["preferred_strategy"] = String(stage.get("preferred_strategy", ""))
	return result


## 4.5.3：市场商品裁剪。剧情进行中时只允许 `unlocked_items` 中的贸易货物出现
## （水煤走补给区块，不在 `market` 行里）；非剧情局返回 `active=false`（不过滤）。
static func market_filter(state: GameState, hub: RegistryHub) -> Dictionary:
	var cfg := config(state, hub)
	var story := state.ensure_story()
	if cfg.is_empty() or not bool(cfg.get("enabled", false)) \
			or not bool(story.get("active", false)) or bool(story.get("completed", true)):
		return {"active": false, "items": []}
	return {"active": true, "items": Array(story.get("unlocked_items", [])).duplicate()}


## 4.5.5：船厂模块裁剪。剧情进行中时只允许 `unlocked_modules` 里的模块出现在
## 购买 / 打造 / 仓库安装候选中（当前已装模块仍然可卸下 / 查看）；非剧情局不过滤。
static func module_filter(state: GameState, hub: RegistryHub) -> Dictionary:
	var cfg := config(state, hub)
	var story := state.ensure_story()
	if cfg.is_empty() or not bool(cfg.get("enabled", false)) \
			or not bool(story.get("active", false)) or bool(story.get("completed", true)):
		return {"active": false, "items": []}
	return {"active": true, "items": Array(story.get("unlocked_modules", [])).duplicate()}


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
	_enter_stage(state, hub, story, cfg, index + 1, events, context.rng)
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
	_enter_stage(state, hub, story, cfg, index + 1, events, context.rng)
	var result := Result.ok({"view": view(context)}, events)
	if bool(story.get("completed", false)):
		result["autosave"] = true
	return result


# ---------------------------------------------------------------------------
# Stage transitions / requirements
# ---------------------------------------------------------------------------


static func _enter_stage(
	state: GameState, hub: RegistryHub, story: Dictionary, cfg: Dictionary,
	index: int, events: Array = [], rng: RngService = null
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
			_apply_effect(state, hub, story, effect as Dictionary, rng)
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
		if not _condition_matches_data(condition, data):
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
		var event_matches := expected_event.is_empty() or expected_event == event
		var data_matches := _condition_matches_data(condition, data)
		if not event_matches or not data_matches:
			# 组合条件（如「4 煤 + 2 水」）按不同事件分别观测：当前事件 / 数据不匹配时，
			# 只要该条件的计数已达标（之前观测过），就视为已满足。
			var done_counter := String(condition.get("counter", ""))
			if not done_counter.is_empty() \
					and int((story.get("counters", {}) as Dictionary).get(done_counter, 0)) >= int(condition.get("at_least", 1)):
				continue
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


static func _condition_matches_data(condition: Dictionary, data: Dictionary) -> bool:
	var expected: Variant = condition.get("match", null)
	if not (expected is Dictionary):
		return true
	for key in (expected as Dictionary).keys():
		if String(data.get(key, "")) != String((expected as Dictionary)[key]):
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


static func _apply_effect(state: GameState, hub: RegistryHub, story: Dictionary, effect: Dictionary, rng: RngService = null) -> void:
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
		"grant_tutorial_contract":
			_grant_tutorial_contract(state, hub, effect, rng)
		"set_ship_fuel":
			# 4.5.2 教学幕：老船几乎空舱，逼玩家先去补给页买煤。
			state.ship()["coal"] = maxf(0.0, float(effect.get("amount", 0.0)))
		"grant_clue":
			# 4.5.4：酒馆自动 / 剧情给线索。目标港与等级由 Core 声明；同一段剧情
			# 的第二次授予复用第一次选定的目标港（`story_target_port_id`），
			# 保证「第一条线索 → 第二条 L3 线索」指向同一座未发现港口。
			_grant_clue(state, hub, story, effect, rng)
		"set_market_price_bias":
			# 4.5.4：把起始港 / 其它港的同两种货拉开价差，保证教学来回可盈利。
			_set_market_price_bias(state, story, effect)
		"guarantee_explore_success":
			# 4.5.4：下一次「剧情线索」的探索结算必定成功（只对发线索时的那条
			# 线索生效；跳过教程不会设置这个 flag）。
			var guarantee_flags: Dictionary = story.get("flags", {})
			guarantee_flags["guaranteed_explore_clue_id"] = String(
				guarantee_flags.get("story_clue_id", "")
			)
			story["flags"] = guarantee_flags
		"add_facility":
			# 4.5.5：第三港由 Core 指定补上船厂设施（程序生成的原型可能没有）。
			_add_port_facility(state, String(effect.get("facility", "")))
		"upgrade_hull":
			# 4.5.5：船厂替玩家换一艘带客舱位的船（旧船存入当前港仓库）。
			_upgrade_hull(state, hub, effect)
		"complete_story":
			_complete(story, config(state, hub))
		_:
			push_warning("StoryService: unknown effect type '%s' (ignored)" % type)


## 4.5.4：`grant_clue` —— 酒馆自动 / 剧情线索。`port: "next_unknown"` 时优先复用
## 本段剧情已选定的 `story_target_port_id`，否则从 `ClueService.eligible_target_ids`
## 里按「离当前港最近 + id」确定性选一座未发现港口；显式港口 id 直接使用。
## `source` / `level` 也来自 Core，框架不认识内容 ID。
static func _grant_clue(
	state: GameState, hub: RegistryHub, story: Dictionary, effect: Dictionary,
	rng: RngService
) -> void:
	if rng == null:
		push_warning("StoryService: grant_clue needs an RngService")
		return
	var flags: Dictionary = story.get("flags", {})
	var target := String(effect.get("port", "next_unknown"))
	if target == "next_unknown":
		target = String(flags.get("story_target_port_id", ""))
		if target.is_empty():
			target = _nearest_unknown_port(state)
			if target.is_empty():
				push_warning("StoryService: grant_clue has no unknown port target")
				return
			flags["story_target_port_id"] = target
			story["flags"] = flags
	if target.is_empty():
		push_warning("StoryService: grant_clue needs a target port")
		return
	var source := String(effect.get("source", "rumor"))
	var clue_stream: RandomNumberGenerator = rng.stream(
		RngService.STREAM_EXPLORATION,
		"story:%s:%d" % [target, int(story.get("stage_index", 0))]
	)
	var clue := ClueService.acquire(
		_EffectContext.new(state, hub), source, clue_stream, target
	)
	if clue.is_empty():
		push_warning("StoryService: cannot acquire story clue for '%s'" % target)
		return
	var level := clampi(int(effect.get("level", 1)), 1, ClueService.NAME_MIN_LEVEL)
	clue["level"] = level
	flags["story_clue_id"] = String(clue.get("id", ""))
	story["flags"] = flags


## The unknown coordinate-world harbour closest to the current port (ties broken by
## id) so the story's rumour always points at a reproducible target.
static func _nearest_unknown_port(state: GameState) -> String:
	var world := WorldOps.world_map(state)
	if world.is_empty():
		return ""
	var reference := world.get_port(state.current_port_id())
	var candidates := ClueService.eligible_target_ids(state)
	candidates.sort()
	var best := ""
	var best_distance := INF
	for port_id in candidates:
		var target := world.get_port(port_id)
		if target.is_empty():
			continue
		var distance := (
			reference.position.distance_to(target.position)
			if not reference.is_empty()
			else 0.0
		)
		if distance < best_distance - 0.0001:
			best_distance = distance
			best = port_id
	return best


## 4.5.4：同两种货在起始港与其它港之间拉开价格。`home_bias` 抬高起始港卖价，
## `other_bias` 压低其它港买价；写入市场条目的 `price_bias` 后重算价格，后续
## NPC / 玩家交易仍走正常定价。
static func _set_market_price_bias(
	state: GameState, story: Dictionary, effect: Dictionary
) -> void:
	var item_ids: Array = effect.get("item_ids", [])
	if item_ids.is_empty():
		return
	var home := String(story.get("home_port_id", ""))
	if home.is_empty():
		home = state.current_port_id()
	var home_bias := float(effect.get("home_bias", 1.0))
	var other_bias := float(effect.get("other_bias", 1.0))
	# 教学市场：把这两种货的库存归位到基准，价格只由 bias 决定，玩家看到的价差
	# 不会因随机库存被抵消（试玩 / 回归都稳定可盈利）。起始港原本可能只是
	# 「只收不卖」的卖货点（`buyable=false`），这里同时把它变成可双向交易，
	# `price_bias` 才会作用在两端。
	var reset_stock := bool(effect.get("reset_stock", false))
	var make_buyable := bool(effect.get("make_buyable", false))
	for raw_port_id in state.market().keys():
		var port_id := String(raw_port_id)
		var factor := home_bias if port_id == home else other_bias
		if is_equal_approx(factor, 1.0) and not reset_stock and not make_buyable:
			continue
		var market: Dictionary = state.market()[port_id]
		for raw_item_id in item_ids:
			var item_id := String(raw_item_id)
			var entry: Variant = market.get(item_id, null)
			if not (entry is Dictionary):
				continue
			var market_entry: Dictionary = entry
			if make_buyable:
				market_entry["buyable"] = true
			if reset_stock:
				market_entry["stock"] = int(market_entry.get("base_stock", market_entry.get("stock", 1)))
			market_entry["price_bias"] = float(market_entry.get("price_bias", 1.0)) * factor
			MarketOps.recalc(market_entry)


## 4.5.4：当前剧情线索若带「保底探索成功」，返回它的线索 id（否则空串）。
static func guaranteed_explore_clue_id(state: GameState) -> String:
	if state == null:
		return ""
	var story := state.ensure_story()
	return String((story.get("flags", {}) as Dictionary).get("guaranteed_explore_clue_id", ""))


## 4.5.4：探索成功结算时消费保底 flag。只对授予保底时的那条线索生效并清除，
## 避免同一条 flag 影响后续普通探索。
static func consume_guaranteed_explore_success(state: GameState, clue_id: String) -> bool:
	if state == null or clue_id.is_empty():
		return false
	var story := state.ensure_story()
	var flags: Dictionary = story.get("flags", {})
	if String(flags.get("guaranteed_explore_clue_id", "")) != clue_id:
		return false
	flags.erase("guaranteed_explore_clue_id")
	story["flags"] = flags
	return true


## 效果分发只拿到 state / hub；线索生成仍走 `ClueService` 的只读上下文依赖
## （state + registries），不需要完整 AppContext。
class _EffectContext:
	extends RefCounted
	var state: GameState
	var registries: RegistryHub

	func _init(p_state: GameState, p_registries: RegistryHub) -> void:
		state = p_state
		registries = p_registries


## 4.5.5：把 Core 指定的设施补到当前港（第三港可能是没有船厂的渔村 / 香料港）。
static func _add_port_facility(state: GameState, facility: String) -> void:
	if facility.is_empty():
		return
	var port := MapOps.port(state.world(), state.current_port_id())
	if port.is_empty():
		return
	var facilities: Array = Array(port.get("facilities", []))
	if facilities.has(facility):
		return
	facilities.append(facility)
	port["facilities"] = facilities


## 4.5.5：剧情换船——保留已有货舱 / 锅炉等模块，把船体换成 Core 指定的、
## 带客舱位的船体；旧船体存入当前港仓库，耐久重置为新船上限。
static func _upgrade_hull(state: GameState, hub: RegistryHub, effect: Dictionary) -> void:
	var hull_id := String(effect.get("hull_id", ""))
	if hull_id.is_empty():
		return
	var hull: ContentDefinition = hub.get_by_id(ContentTypes.HULL, hull_id)
	if hull == null:
		push_warning("StoryService: unknown upgrade hull '%s'" % hull_id)
		return
	var ship := state.ship()
	var old_hull_id := String(ship.get("hull_id", ""))
	if old_hull_id == hull_id:
		return
	ship["hull_id"] = hull_id
	ship["durability"] = ShipOps.durability_max(hub, ship)
	if bool(effect.get("store_old", true)) and not old_hull_id.is_empty():
		WarehouseOps.add_module(state, state.current_port_id(), old_hull_id, 1)
	ShipModules.install_slot(ship, "hull")


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


## 4.5.2：用 Core 指定的教学委托模板替换开局自动主线（燃料舱运煤）。内容决定
## 模板 / 货物 / 数量 / 时限，框架只负责生成、接取与存入 `contracts.main`。
static func _grant_tutorial_contract(state: GameState, hub: RegistryHub, effect: Dictionary, rng: RngService) -> void:
	if rng == null:
		push_warning("StoryService: grant_tutorial_contract needs an RngService")
		return
	var template_id := String(effect.get("template_id", ""))
	var template: ContentDefinition = hub.get_by_id(ContentTypes.CONTRACT, template_id)
	if template == null:
		push_warning("StoryService: unknown tutorial contract template '%s'" % template_id)
		return
	var offer := ContractOps.generate_offer(state, hub, template, rng, state.current_port_id())
	if offer.is_empty():
		push_warning("StoryService: cannot generate tutorial contract '%s'" % template_id)
		return
	# 4.5.3：第二主线需要「送回起始港」。`destination: home` 用剧情开始时记录的
	# 起始港 id 覆盖随机目的地，距离 / 时限随之重算。
	var destination := String(effect.get("destination", ""))
	if destination == "home":
		var home := String(state.ensure_story().get("home_port_id", ""))
		if home.is_empty():
			home = state.current_port_id()
		var home_distance := MapOps.distance_between(state.world(), state.current_port_id(), home)
		if home_distance > 0.0:
			offer["destination"] = home
			offer["distance"] = home_distance
	# Core story 只覆盖「交付什么 / 怎么交付 / 时限 / 文案」，主线段落仍沿用现有
	# main_01 模板（不新增一条并列主线，避免破坏 5 段主线计数与通关回归）。
	var item_id := String(effect.get("cargo_item_id", ""))
	var amount := int(effect.get("amount", 0))
	if not item_id.is_empty() and amount > 0:
		var provider := String(effect.get("provider", ""))
		var entry := {"item_id": item_id, "amount": amount}
		if provider == "player":
			entry["player_sourced"] = true
		elif provider == "fuel":
			entry["fuel_sourced"] = true
		var item_definition := ShipOps.item_definition(hub, item_id)
		var unit_weight := float(item_definition.data.get("unit_weight", 1.0)) if item_definition != null else 1.0
		offer["cargo"] = [entry]
		offer["cargo_weight"] = float(amount) * unit_weight
		offer["player_sourced"] = not provider.is_empty()
	# 4.5.5：第三主线仍是 main_03 段（保持 5 段主线计数），但内容改成送 1 名旅客：
	# 清空模板的货箱、写入旅客人数。`passengers` 由 Core 给出，框架不写死 1。
	if effect.has("passengers"):
		offer["passengers"] = int(effect.get("passengers", 0))
		offer["cargo"] = []
		offer["cargo_weight"] = 0.0
		offer["player_sourced"] = false
	var name_key := String(effect.get("name_key", ""))
	if not name_key.is_empty():
		offer["name_key"] = name_key
	var description_key := String(effect.get("description_key", ""))
	if not description_key.is_empty():
		offer["description_key"] = description_key
	var formula_id := String(effect.get("deadline_formula", ""))
	if not formula_id.is_empty():
		var hours := FormulaRegistry.evaluate(formula_id, {
			"distance": float(offer.get("distance", 0.0)),
			"cargo_weight": float(offer.get("cargo_weight", 0.0)),
			"passengers": int(offer.get("passengers", 0)),
		})
		if hours > 0.0:
			offer["deadline"] = state.now() + hours
	var attached := ContractOps.attach(state, hub, offer)
	if not bool(attached.get("ok", false)):
		push_warning("StoryService: cannot attach tutorial contract '%s': %s" % [
			template_id, str(attached.get("error_code", "")),
		])
		return
	var contracts: Dictionary = state.contracts()
	contracts["main"] = offer
	contracts["main_offer"] = null


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
