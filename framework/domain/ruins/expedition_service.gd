class_name ExpeditionService
extends RefCounted
## @static-doc
## 作用：Phase D5 遗迹远征的领域用例：开始远征、进入房间、选择事件选项、撤退与结算。
## 状态只落在 `data.expedition`（临时远征）与 `data.relics`（永久遗物）。
##
## ## 契约与约束
## - `start` 要求人在港口、没有进行中的远征，遗迹原型存在；生成确定性房间序列。
## - `enter` 结算当前房间危险；有事件则停下等待 `choose`，否则前进/结算。
## - `choose` 只接受当前事件的选项下标；执行操作码后继续前进。
## - 完成时按 loot_table 发钱/物品到当前港仓库，并从 relic_pool 抽 1 件遗物加入
##   `data.relics`；撤退结束远征但不发完成奖励。
## - 领域事件：`expedition.started` / `expedition.room_entered` / `expedition.event_choice` /
##   `expedition.completed` / `expedition.retreated`。
## @end-static-doc


static func start(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if RuinOps.has_expedition(state):
		return Result.fail("expedition_running", "ui.error.expedition_running")
	var ruin_id := String(params.get("ruin_id", ""))
	var ruin := RuinOps.ruin_definition(hub, ruin_id)
	if ruin == null:
		return Result.fail("unknown_ruin", "ui.error.unknown_ruin", {"ruin_id": ruin_id})
	var serial := int(state.data.get(RuinOps.SERIAL_KEY, 0)) + 1
	state.data[RuinOps.SERIAL_KEY] = serial
	var rooms := RuinOps.generate_rooms(hub, ruin, int(state.run().get("seed", 0)), serial)
	if rooms.is_empty():
		return Result.fail("ruin_has_no_rooms", "ui.error.ruin_has_no_rooms", {"ruin_id": ruin_id})
	var expedition: Dictionary = RuinOps.DEFAULT_EXPEDITION.duplicate(true)
	expedition["active"] = true
	expedition["ruin_id"] = ruin.id
	expedition["rooms"] = rooms
	expedition["phase"] = "room"
	state.data[RuinOps.EXPEDITION_KEY] = expedition
	return Result.ok({
		"expedition": RuinOps.view(state, hub),
	}, [{
		"type": "expedition.started",
		"payload": {"ruin_id": ruin.id, "rooms": rooms.size()},
	}])


static func enter(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary:
	var expedition := RuinOps.ensure_structure(state)
	if expedition.is_empty():
		return Result.fail("no_expedition", "ui.error.no_expedition")
	if String(expedition.get("phase", "")) != "room":
		return Result.fail("expedition_not_at_room", "ui.error.expedition_not_at_room")
	var index := int(expedition.get("room_index", 0))
	var rooms: Array = expedition.get("rooms", [])
	if index < 0 or index >= rooms.size():
		return Result.fail("expedition_not_at_room", "ui.error.expedition_not_at_room")
	var room: Dictionary = rooms[index]
	var hazard := RuinOps.roll_hazard(state, hub, String(room.get("hazard_table", "")), int(state.data.get(RuinOps.SERIAL_KEY, 0)), index)
	if not hazard.is_empty():
		_append_log(expedition, "hazard", String(hazard.get("type", "")), int(hazard.get("amount", 0)))
		expedition["log"] = expedition.get("log", [])
	var event_id := String(room.get("event_id", ""))
	if not event_id.is_empty():
		expedition["pending_event"] = event_id
		expedition["phase"] = "event"
		state.data[RuinOps.EXPEDITION_KEY] = expedition
		return Result.ok({
			"expedition": RuinOps.view(state, hub),
			"hazard": hazard,
		}, [{
			"type": "expedition.room_entered",
			"payload": {"index": index, "event_id": event_id, "hazard": hazard},
		}])
	return _advance(state, hub, expedition, [{
		"type": "expedition.room_entered",
		"payload": {"index": index, "hazard": hazard},
	}])


static func choose(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var expedition := RuinOps.ensure_structure(state)
	if expedition.is_empty():
		return Result.fail("no_expedition", "ui.error.no_expedition")
	if String(expedition.get("phase", "")) != "event":
		return Result.fail("expedition_not_at_event", "ui.error.expedition_not_at_event")
	var event := RuinOps.event_definition(hub, String(expedition.get("pending_event", "")))
	if event == null:
		return Result.fail("unknown_expedition_event", "ui.error.unknown_expedition_event")
	var options: Array = Array(event.data.get("options", []))
	var option_index := int(params.get("option_index", -1))
	if option_index < 0 or option_index >= options.size():
		return Result.fail("invalid_event_option", "ui.error.invalid_event_option", {"option_index": option_index})
	var option: Dictionary = options[option_index]
	var effect_result := RuinOps.apply_event_effect(state, hub, option.get("effect", {}))
	_append_log(expedition, "event", String(option.get("text_key", "")), 0)
	expedition["pending_event"] = ""
	expedition["phase"] = "room"
	return _advance(state, hub, expedition, [{
		"type": "expedition.event_choice",
		"payload": {"event_id": event.id, "option_index": option_index, "effect": effect_result},
	}])


static func retreat(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary:
	var expedition := RuinOps.ensure_structure(state)
	if expedition.is_empty():
		return Result.fail("no_expedition", "ui.error.no_expedition")
	expedition["active"] = false
	expedition["phase"] = "finished"
	_append_log(expedition, "retreated", "", 0)
	state.data[RuinOps.EXPEDITION_KEY] = expedition
	return Result.ok({
		"expedition": RuinOps.view(state, hub),
	}, [{"type": "expedition.retreated", "payload": {}}])


static func _advance(state: GameState, hub: RegistryHub, expedition: Dictionary, events: Array) -> Dictionary:
	var next_index := int(expedition.get("room_index", 0)) + 1
	var rooms: Array = expedition.get("rooms", [])
	if next_index >= rooms.size():
		return _complete(state, hub, expedition, events)
	expedition["room_index"] = next_index
	expedition["phase"] = "room"
	state.data[RuinOps.EXPEDITION_KEY] = expedition
	return Result.ok({
		"expedition": RuinOps.view(state, hub),
	}, events)


static func _complete(state: GameState, hub: RegistryHub, expedition: Dictionary, events: Array) -> Dictionary:
	var ruin := RuinOps.ruin_definition(hub, String(expedition.get("ruin_id", "")))
	var reward := {"money": 0, "items": {}, "relic_id": ""}
	if ruin != null:
		reward = RuinOps.grant_completion(state, hub, ruin, expedition)
	var money := int(reward.get("money", 0))
	if money > 0:
		state.add_money(money)
		state.record_income(money)
	var items: Dictionary = reward.get("items", {})
	for item_id in items.keys():
		WarehouseOps.add_material(state, state.current_port_id(), String(item_id), int(items[item_id]))
	var relic_id := String(reward.get("relic_id", ""))
	var relics: Array = Array(state.data.get(RuinOps.RELICS_KEY, []))
	if not relic_id.is_empty() and not relics.has(relic_id):
		relics.append(relic_id)
	state.data[RuinOps.RELICS_KEY] = relics
	expedition["phase"] = "finished"
	expedition["active"] = false
	expedition["loot_money"] = money
	expedition["loot_items"] = items
	_append_log(expedition, "completed", relic_id, money)
	state.data[RuinOps.EXPEDITION_KEY] = expedition
	events.append({
		"type": "expedition.completed",
		"payload": {"ruin_id": String(expedition.get("ruin_id", "")), "money": money, "relic_id": relic_id},
	})
	return Result.ok({
		"expedition": RuinOps.view(state, hub),
		"reward": reward,
	}, events)


static func _append_log(expedition: Dictionary, event: String, detail: String, amount: int) -> void:
	var log: Array = expedition.get("log", [])
	log.append({"event": event, "detail": detail, "amount": amount})
	while log.size() > 12:
		log.pop_front()
	expedition["log"] = log
