class_name RuinOps
extends RefCounted
## @static-doc
## 作用：Phase D5 遗迹远征的纯结构/计算层：生成确定性房间序列、掷危险、结算事件效果、
## 结算战利品与遗物，并输出只读 `expedition.view` 数据。
##
## ## 契约与约束
## - `data.expedition` 只在 `expedition.start` 后存在；`data.relics` 保存永久遗物 id 列表，
##   `data.expedition_serial` 是新远征序号。
## - 房间序列由 ruin_archetypes 的 `room_tags` 过滤 room_templates，按 `weight` 权重抽取；
##   随机种子 = run seed + ruin id + serial，同序号可复现。
## - 危险表按权重抽 type/amount；durability 扣当前船耐久，money 扣钱，cargo 从船货舱扣除，
##   无货时转为等值耐久损失。
## - 事件选项只执行 `add_money` / `damage_ship` / `add_item` 三个操作码（Core 内容只用这三个）。
## - 完成时按 loot_table 的 money_range 与 entries 发奖（item 进当前港仓库，其他类型折算金币），
##   并从 `relic_pool` 抽 1 件遗物写入 `data.relics`。
## @end-static-doc

const EXPEDITION_KEY := "expedition"
const RELICS_KEY := "relics"
const SERIAL_KEY := "expedition_serial"
const DEFAULT_EXPEDITION := {
	"active": false,
	"ruin_id": "",
	"phase": "room",
	"room_index": 0,
	"rooms": [],
	"pending_event": "",
	"loot_money": 0,
	"loot_items": {},
	"log": [],
}


static func has_expedition(state: GameState) -> bool:
	if state == null:
		return false
	var raw: Variant = state.data.get(EXPEDITION_KEY, null)
	return raw is Dictionary and bool((raw as Dictionary).get("active", false))


static func ensure_structure(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var raw: Variant = state.data.get(EXPEDITION_KEY, null)
	if not (raw is Dictionary) or not bool((raw as Dictionary).get("active", false)):
		return {}
	var expedition := _normalize(raw)
	state.data[EXPEDITION_KEY] = expedition
	return expedition


static func ruin_definition(hub: RegistryHub, id: String) -> ContentDefinition:
	return hub.get_by_id(ContentTypes.RUIN_ARCHETYPE, id) if hub != null and not id.is_empty() else null


static func room_definition(hub: RegistryHub, id: String) -> ContentDefinition:
	return hub.get_by_id(ContentTypes.ROOM_TEMPLATE, id) if hub != null and not id.is_empty() else null


static func event_definition(hub: RegistryHub, id: String) -> ContentDefinition:
	return hub.get_by_id(ContentTypes.EXPEDITION_EVENT, id) if hub != null and not id.is_empty() else null


static func hazard_definition(hub: RegistryHub, id: String) -> ContentDefinition:
	return hub.get_by_id(ContentTypes.HAZARD_TABLE, id) if hub != null and not id.is_empty() else null


static func relic_definition(hub: RegistryHub, id: String) -> ContentDefinition:
	return hub.get_by_id(ContentTypes.RELIC, id) if hub != null and not id.is_empty() else null


static func generate_rooms(hub: RegistryHub, ruin: ContentDefinition, seed_value: int, serial: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("expedition:%d:%s:%d" % [seed_value, ruin.id, serial])
	var tags: Array = Array(ruin.data.get("room_tags", []))
	var candidates: Array = []
	for template in hub.get_all(ContentTypes.ROOM_TEMPLATE):
		if _matches_any(template.tags, tags):
			candidates.append(template)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(left: ContentDefinition, right: ContentDefinition) -> bool: return left.id < right.id)
	var weights: Array = []
	for candidate in candidates:
		weights.append(maxi(1, int(candidate.data.get("weight", 1))))
	var rooms: Array = []
	for _index in maxi(2, int(ruin.data.get("room_count", 2))):
		var template: ContentDefinition = _pick_weighted(rng, candidates, weights)
		if template == null:
			continue
		rooms.append({
			"template_id": template.id,
			"event_id": String(template.data.get("event_ref", "")),
			"hazard_table": String(template.data.get("hazard_table", ruin.data.get("hazard_table", ""))),
			"loot_table": String(template.data.get("loot_table", "")),
		})
	return rooms


## Local weighted pick over definition arrays; `RngService.choose_weighted` expects a
## field name, so ruins keep their own explicit weights.
static func _pick_weighted(rng: RandomNumberGenerator, entries: Array, weights: Array) -> ContentDefinition:
	if entries.is_empty():
		return null
	var total := 0
	for weight in weights:
		total += maxi(0, int(weight))
	if total <= 0:
		return entries[rng.randi_range(0, entries.size() - 1)] as ContentDefinition
	var roll := rng.randi_range(1, total)
	var running := 0
	for index in entries.size():
		running += maxi(0, int(weights[index]))
		if roll <= running:
			return entries[index] as ContentDefinition
	return entries[entries.size() - 1] as ContentDefinition


static func roll_hazard(state: GameState, hub: RegistryHub, table_id: String, serial: int, room_index: int) -> Dictionary:
	var table := hazard_definition(hub, table_id)
	if table == null:
		return {}
	var entries: Array = Array(table.data.get("entries", []))
	if entries.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hazard:%d:%s:%d" % [serial, table_id, room_index])
	var weights: Array = []
	for entry in entries:
		weights.append(maxi(1, int((entry as Dictionary).get("weight", 1))))
	var picked: Variant = _pick_weighted_entry(rng, entries, weights)
	if not (picked is Dictionary):
		return {}
	var kind := String((picked as Dictionary).get("type", "durability"))
	var range: Array = Array((picked as Dictionary).get("amount_range", [1, 1]))
	var low := int(range[0]) if range.size() > 0 else 1
	var high := int(range[1]) if range.size() > 1 else low
	var amount := maxi(0, rng.randi_range(mini(low, high), maxi(low, high)))
	var result := {"type": kind, "amount": amount, "text_key": String((picked as Dictionary).get("text_key", ""))}
	match kind:
		"durability":
			_damage_ship(state, amount)
		"money":
			var paid := mini(amount, state.money())
			state.add_money(-paid)
			state.record_expense(paid)
			result["amount"] = paid
		"cargo":
			var lost := _lose_cargo(state, amount)
			if lost <= 0:
				_damage_ship(state, amount * 2)
				result["type"] = "durability"
				result["amount"] = amount * 2
			else:
				result["amount"] = lost
	return result


static func apply_event_effect(state: GameState, hub: RegistryHub, effect: Dictionary) -> Dictionary:
	var op := String(effect.get("op", ""))
	match op:
		"add_money":
			var amount := int(effect.get("amount", 0))
			state.add_money(amount)
			if amount > 0:
				state.record_income(amount)
			else:
				state.record_expense(-amount)
			return {"op": op, "amount": amount}
		"damage_ship":
			var amount := int(effect.get("amount", 0))
			_damage_ship(state, amount)
			return {"op": op, "amount": amount}
		"add_item":
			var item_id := String(effect.get("item_id", ""))
			var amount := int(effect.get("amount", 1))
			if not item_id.is_empty() and amount > 0:
				WarehouseOps.add_material(state, state.current_port_id(), item_id, amount)
			return {"op": op, "item_id": item_id, "amount": amount}
	return {"op": op, "ignored": true}


static func grant_completion(state: GameState, hub: RegistryHub, ruin: ContentDefinition, expedition: Dictionary) -> Dictionary:
	var result := {"money": 0, "items": {}, "relic_id": ""}
	var loot := hub.get_by_id(ContentTypes.LOOT_TABLE, String(ruin.data.get("loot_table", "")))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("expedition_loot:%d:%s" % [int(state.data.get(SERIAL_KEY, 0)), ruin.id])
	if loot != null:
		var money_range: Array = Array(loot.data.get("money_range", [0, 0]))
		if money_range.size() >= 2:
			result["money"] = rng.randi_range(int(money_range[0]), int(money_range[1]))
		for entry in loot.data.get("entries", []):
			if not (entry is Dictionary):
				continue
			var kind := String((entry as Dictionary).get("kind", ""))
			var definition_id := String((entry as Dictionary).get("id", ""))
			var range: Array = Array((entry as Dictionary).get("amount_range", [1, 1]))
			var amount := rng.randi_range(int(range[0]), int(range[1])) if range.size() >= 2 else 1
			if kind == "item":
				var items: Dictionary = result["items"]
				items[definition_id] = int(items.get(definition_id, 0)) + amount
				result["items"] = items
			else:
				# Non-item loot is salvaged into money so no entry is silently dropped.
				var definition := hub.get_by_id(kind_to_type(kind), definition_id)
				var value := int(round(float(definition.data.get("purchase_price", 25.0)))) if definition != null else 25
				result["money"] = int(result["money"]) + value * amount
	var relic_pool: Array = Array(ruin.data.get("relic_pool", []))
	if not relic_pool.is_empty():
		var relic_id := String(relic_pool[rng.randi_range(0, relic_pool.size() - 1)])
		result["relic_id"] = relic_id
	return result


static func _pick_weighted_entry(rng: RandomNumberGenerator, entries: Array, weights: Array) -> Variant:
	if entries.is_empty():
		return null
	var total := 0
	for weight in weights:
		total += maxi(0, int(weight))
	if total <= 0:
		return entries[rng.randi_range(0, entries.size() - 1)]
	var roll := rng.randi_range(1, total)
	var running := 0
	for index in entries.size():
		running += maxi(0, int(weights[index]))
		if roll <= running:
			return entries[index]
	return entries[entries.size() - 1]


static func kind_to_type(kind: String) -> StringName:
	match kind:
		"weapon":
			return ContentTypes.WEAPON
		"module":
			return ContentTypes.MODULE
		"hull":
			return ContentTypes.HULL
	return ContentTypes.ITEM


static func view(state: GameState, hub: RegistryHub = null) -> Dictionary:
	var raw: Variant = state.data.get(EXPEDITION_KEY, null) if state != null else null
	var expedition := _normalize(raw)
	var ruin := ruin_definition(hub, String(expedition.get("ruin_id", "")))
	var rooms: Array = expedition.get("rooms", [])
	var room_index := int(expedition.get("room_index", 0))
	var current_room: Dictionary = rooms[room_index] if room_index >= 0 and room_index < rooms.size() else {}
	var template := room_definition(hub, String(current_room.get("template_id", "")))
	var event_id := String(expedition.get("pending_event", ""))
	var event := event_definition(hub, event_id)
	var options: Array = []
	if event != null:
		for option in event.data.get("options", []):
			if option is Dictionary:
				options.append({
					"text_key": String((option as Dictionary).get("text_key", "")),
				})
	var room_rows: Array = []
	for index in rooms.size():
		var entry: Dictionary = rooms[index]
		var room_template := room_definition(hub, String(entry.get("template_id", "")))
		room_rows.append({
			"index": index,
			"template_id": String(entry.get("template_id", "")),
			"name_key": room_template.name_key if room_template != null else String(entry.get("template_id", "")),
			"event_id": String(entry.get("event_id", "")),
			"loot_table": String(entry.get("loot_table", "")),
		})
	var relics: Array = []
	var raw_relics: Variant = state.data.get(RELICS_KEY, []) if state != null else []
	if raw_relics is Array:
		for relic_id in raw_relics:
			if relic_id is String:
				relics.append(relic_id)
	return {
		"active": bool(expedition.get("active", false)),
		"ruin_id": String(expedition.get("ruin_id", "")),
		"ruin": _definition_view(ruin),
		"phase": String(expedition.get("phase", "room")),
		"room_index": room_index,
		"room_count": rooms.size(),
		"rooms": room_rows,
		"current_room": {
			"template_id": String(current_room.get("template_id", "")),
			"name_key": template.name_key if template != null else String(current_room.get("template_id", "")),
		},
		"event_id": event_id,
		"event": _definition_view(event),
		"event_options": options,
		"loot_money": int(expedition.get("loot_money", 0)),
		"loot_items": _items_view(hub, expedition.get("loot_items", {})),
		"log": (expedition.get("log", []) as Array).duplicate(true),
		"relics": relics,
	}


static func _definition_view(definition: ContentDefinition) -> Dictionary:
	if definition == null:
		return {}
	return {"id": definition.id, "name_key": definition.name_key, "text_key": String(definition.data.get("text_key", ""))}


static func _items_view(hub: RegistryHub, items: Dictionary) -> Array:
	var rows: Array = []
	var ids: Array = items.keys()
	ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	for item_id in ids:
		var item := hub.get_by_id(ContentTypes.ITEM, String(item_id)) if hub != null else null
		rows.append({"item_id": String(item_id), "name_key": item.name_key if item != null else String(item_id), "amount": int(items[item_id])})
	return rows


static func _matches_any(definition_tags: PackedStringArray, required: Array) -> bool:
	for tag in required:
		if definition_tags.has(String(tag)):
			return true
	return false


static func _damage_ship(state: GameState, amount: int) -> void:
	if amount <= 0:
		return
	var ship := state.ship()
	var durability := maxf(0.0, float(ship.get("durability", 0.0)) - float(amount))
	ship["durability"] = durability


static func _lose_cargo(state: GameState, amount: int) -> int:
	var ship := state.ship()
	var cargo: Array = Array(ship.get("cargo", []))
	var lost := 0
	for index in range(cargo.size()):
		if lost >= amount:
			break
		var stack: Dictionary = cargo[index]
		var have := int(stack.get("amount", 0))
		var take := mini(amount - lost, have)
		stack["amount"] = have - take
		lost += take
		if int(stack["amount"]) <= 0:
			cargo.remove_at(index)
			break
	ship["cargo"] = cargo
	return lost


static func _normalize(raw: Variant) -> Dictionary:
	var expedition: Dictionary = DEFAULT_EXPEDITION.duplicate(true)
	if not (raw is Dictionary):
		return expedition
	var source: Dictionary = raw
	expedition["active"] = _safe_bool(source.get("active", false), false)
	expedition["ruin_id"] = _safe_string(source.get("ruin_id", ""))
	var phase := _safe_string(source.get("phase", "room"), "room")
	expedition["phase"] = phase if ["room", "event", "finished"].has(phase) else "room"
	expedition["room_index"] = maxi(0, _safe_int(source.get("room_index", 0), 0))
	expedition["pending_event"] = _safe_string(source.get("pending_event", ""))
	expedition["loot_money"] = maxi(0, _safe_int(source.get("loot_money", 0), 0))
	var items: Dictionary = {}
	var raw_items: Variant = source.get("loot_items", {})
	if raw_items is Dictionary:
		for raw_item_id in (raw_items as Dictionary).keys():
			var amount := _safe_int((raw_items as Dictionary)[raw_item_id], 0)
			if amount > 0:
				items[String(raw_item_id)] = amount
	expedition["loot_items"] = items
	var rooms: Array = []
	for entry in source.get("rooms", []):
		if entry is Dictionary and not _safe_string((entry as Dictionary).get("template_id", "")).is_empty():
			rooms.append({
				"template_id": _safe_string((entry as Dictionary).get("template_id", "")),
				"event_id": _safe_string((entry as Dictionary).get("event_id", "")),
				"hazard_table": _safe_string((entry as Dictionary).get("hazard_table", "")),
				"loot_table": _safe_string((entry as Dictionary).get("loot_table", "")),
			})
	expedition["rooms"] = rooms
	var log: Array = []
	for entry in source.get("log", []):
		if entry is Dictionary and log.size() < 12:
			log.append(entry.duplicate(true))
	expedition["log"] = log
	return expedition


static func _safe_string(value: Variant, fallback: String = "") -> String:
	return value if value is String else fallback


static func _safe_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(value)
	return fallback


static func _safe_bool(value: Variant, fallback: bool = false) -> bool:
	return value if value is bool else fallback
