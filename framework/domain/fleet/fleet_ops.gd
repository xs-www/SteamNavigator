class_name FleetOps
extends RefCounted
## @static-doc
## 作用：Phase D2 舰队（fleet）的纯结构助手：惰性维护 `data.fleet`、解析旗舰条目、
## 编队槽位、引用与视图数据。持久状态只记录「队伍编成」（ship_id / archetype_id /
## captain_id / formation_slot / condition）与 doctrine / formation 选择，**不复制**
## 当前单船 `data.ship` 的模块 / 耐久 / 货舱状态。
##
## ## 契约与约束
## - `data.fleet = {flagship: "flagship", ships: [{ship_id, archetype_id, captain_id,
##   formation_slot, condition}], doctrine_id, formation_id}`；flagship 条目固定
##   `ship_id = "flagship"` 且永远存在。
## - 旗舰的 `archetype_id` 由当前 `data.ship.hull_id` 反查 `ship_archetypes.hull_ref`
##   得到（不写死内容 id）；hull 升级后 ensure 会重新同步。
## - 其余船是「名册条目」，只保存编队元数据；最多 `MAX_SHIPS` 艘（含旗舰）。
## - formation slot 是 formations 定义里的字符串 slot id；空串表示未分配。
## - `view()` 只读，缺 `data.fleet` 时返回默认视图而不写状态；`ensure_structure()`
##   才会持久化/修复块。
## @end-static-doc

const FLEET_KEY := "fleet"
const FLAGSHIP_ID := "flagship"
const MAX_SHIPS := 5
const DEFAULT_SHIP := {
	"ship_id": "",
	"archetype_id": "",
	"captain_id": "",
	"formation_slot": "",
	"condition": 1.0,
}
const DEFAULT_FLEET := {
	"flagship": FLAGSHIP_ID,
	"ships": [],
	"doctrine_id": "",
	"formation_id": "",
}


## Lazily creates / repairs `data.fleet` and returns the live dictionary.
static func ensure_structure(state: GameState, hub: RegistryHub = null) -> Dictionary:
	if state == null:
		return DEFAULT_FLEET.duplicate(true)
	var current: Variant = state.data.get(FLEET_KEY, null)
	if not (current is Dictionary):
		current = DEFAULT_FLEET.duplicate(true)
		state.data[FLEET_KEY] = current
	var fleet: Dictionary = current
	fleet["flagship"] = FLAGSHIP_ID
	if not (fleet.get("ships", null) is Array):
		fleet["ships"] = []
	if fleet["ships"].is_empty():
		fleet["ships"].append(_make_flagship_entry(state, hub))
	else:
		# The flagship entry is structural: keep it first and unique.
		var ships: Array = fleet["ships"]
		var flagship_entry: Dictionary = {}
		for ship in ships:
			if ship is Dictionary and String((ship as Dictionary).get("ship_id", "")) == FLAGSHIP_ID:
				flagship_entry = ship
				break
		if flagship_entry.is_empty():
			flagship_entry = _make_flagship_entry(state, hub)
			ships.insert(0, flagship_entry)
		else:
			_repair_ship_entry(flagship_entry)
			_sync_flagship_archetype(flagship_entry, state, hub)
		fleet["ships"] = ships
	for key in ["doctrine_id", "formation_id"]:
		if not fleet.has(key):
			fleet[key] = ""
	return fleet


## Read-only view of the current fleet. Never writes `data.fleet`.
static func view(state: GameState, hub: RegistryHub = null) -> Dictionary:
	var fleet := _structural_fleet(state)
	var ships: Array = []
	for entry in fleet.get("ships", []):
		if not (entry is Dictionary):
			continue
		var ship: Dictionary = entry
		var archetype_id := String(ship.get("archetype_id", ""))
		var captain_id := String(ship.get("captain_id", ""))
		var is_flagship := String(ship.get("ship_id", "")) == FLAGSHIP_ID
		if is_flagship:
			archetype_id = flagship_archetype_id(state, hub)
		ships.append({
			"ship_id": String(ship.get("ship_id", "")),
			"is_flagship": is_flagship,
			"archetype_id": archetype_id,
			"archetype_name_key": _definition_name_key(hub, ContentTypes.SHIP_ARCHETYPE, archetype_id, archetype_id),
			"captain_id": captain_id,
			"captain_name_key": _definition_name_key(hub, ContentTypes.CAPTAIN, captain_id, captain_id),
			"formation_slot": String(ship.get("formation_slot", "")),
			"condition": float(ship.get("condition", 1.0)),
		})
	var formation_id := String(fleet.get("formation_id", ""))
	var doctrine_id := String(fleet.get("doctrine_id", ""))
	var formation := _definition(hub, ContentTypes.FORMATION, formation_id)
	var doctrine := _definition(hub, ContentTypes.FLEET_DOCTRINE, doctrine_id)
	return {
		"flagship_id": FLAGSHIP_ID,
		"ship_count": ships.size(),
		"max_ships": max_ships(hub, formation_id),
		"ships": ships,
		"formation_id": formation_id,
		"formation": _formation_view(formation),
		"doctrine_id": doctrine_id,
		"doctrine": _doctrine_view(doctrine),
	}


## The current ship's hull resolves to a ship archetype (flagship only).
static func flagship_archetype_id(state: GameState, hub: RegistryHub = null) -> String:
	if state == null or hub == null:
		return ""
	var hull_id := String(state.ship().get("hull_id", ""))
	if hull_id.is_empty():
		return ""
	for definition in _sorted(hub.get_all(ContentTypes.SHIP_ARCHETYPE)):
		if String(definition.data.get("hull_ref", "")) == hull_id:
			return definition.id
	return ""


## Max ships allowed by the fleet: framework cap, further limited by the current
## formation's optional `max_ships`.
static func max_ships(hub: RegistryHub = null, formation_id: String = "") -> int:
	var cap := MAX_SHIPS
	var formation := _definition(hub, ContentTypes.FORMATION, formation_id)
	if formation != null:
		cap = mini(cap, int(formation.data.get("max_ships", MAX_SHIPS)))
	return cap


static func formation_slot_ids(hub: RegistryHub, formation_id: String) -> Array[String]:
	var ids: Array[String] = []
	var formation := _definition(hub, ContentTypes.FORMATION, formation_id)
	if formation == null:
		return ids
	for raw in formation.data.get("slots", []):
		if raw is Dictionary:
			var slot_id := String((raw as Dictionary).get("id", ""))
			if not slot_id.is_empty():
				ids.append(slot_id)
	return ids


static func formation_slot(hub: RegistryHub, formation_id: String, slot_id: String) -> Dictionary:
	var formation := _definition(hub, ContentTypes.FORMATION, formation_id)
	if formation == null:
		return {}
	for raw in formation.data.get("slots", []):
		if raw is Dictionary and String((raw as Dictionary).get("id", "")) == slot_id:
			return (raw as Dictionary).duplicate(true)
	return {}


## Ship entry behind a `ship_id`, or `{}`.
static func ship_entry(fleet: Dictionary, ship_id: String) -> Dictionary:
	for entry in fleet.get("ships", []):
		if entry is Dictionary and String((entry as Dictionary).get("ship_id", "")) == ship_id:
			return entry
	return {}


static func is_valid_slot_id(slot_id: String) -> bool:
	var regex := RegEx.create_from_string("^[a-z][a-z0-9_]{0,31}$")
	return not slot_id.is_empty() and regex.search(slot_id) != null


## Smallest free deterministic `ship_<n>` id (flagship is not numeric).
static func next_ship_id(fleet: Dictionary) -> String:
	var used: Dictionary = {}
	for entry in fleet.get("ships", []):
		if entry is Dictionary:
			used[String((entry as Dictionary).get("ship_id", ""))] = true
	var index := 1
	while used.has("ship_%d" % index):
		index += 1
	return "ship_%d" % index


static func _structural_fleet(state: GameState) -> Dictionary:
	var fleet: Dictionary = DEFAULT_FLEET.duplicate(true)
	if state != null and state.data.get(FLEET_KEY, null) is Dictionary:
		fleet = (state.data[FLEET_KEY] as Dictionary).duplicate(true)
	for key in DEFAULT_FLEET.keys():
		if not fleet.has(key):
			fleet[key] = DEFAULT_FLEET[key]
	if not (fleet.get("ships", null) is Array) or (fleet["ships"] as Array).is_empty():
		fleet["ships"] = [DEFAULT_SHIP.duplicate(true)]
		(fleet["ships"][0] as Dictionary)["ship_id"] = FLAGSHIP_ID
	for entry in fleet["ships"]:
		if entry is Dictionary:
			for key in DEFAULT_SHIP.keys():
				if not (entry as Dictionary).has(key):
					(entry as Dictionary)[key] = DEFAULT_SHIP[key]
	return fleet


static func _make_flagship_entry(state: GameState, hub: RegistryHub) -> Dictionary:
	var entry := DEFAULT_SHIP.duplicate(true)
	entry["ship_id"] = FLAGSHIP_ID
	entry["condition"] = 1.0
	_sync_flagship_archetype(entry, state, hub)
	return entry


static func _repair_ship_entry(entry: Dictionary) -> void:
	for key in DEFAULT_SHIP.keys():
		if not entry.has(key):
			entry[key] = DEFAULT_SHIP[key]


static func _sync_flagship_archetype(entry: Dictionary, state: GameState, hub: RegistryHub) -> void:
	if hub == null:
		return
	if String(entry.get("ship_id", "")) != FLAGSHIP_ID:
		return
	var archetype_id := flagship_archetype_id(state, hub)
	if not archetype_id.is_empty():
		entry["archetype_id"] = archetype_id


static func _definition(hub: RegistryHub, content_type: StringName, definition_id: String) -> ContentDefinition:
	if hub == null or definition_id.is_empty():
		return null
	return hub.get_by_id(content_type, definition_id)


static func _definition_name_key(hub: RegistryHub, content_type: StringName, definition_id: String, fallback: String) -> String:
	var definition := _definition(hub, content_type, definition_id)
	return definition.name_key if definition != null else fallback


static func _formation_view(formation: ContentDefinition) -> Dictionary:
	if formation == null:
		return {}
	return {
		"id": formation.id,
		"name_key": formation.name_key,
		"slots": Array(formation.data.get("slots", [])).duplicate(true),
		"max_ships": int(formation.data.get("max_ships", MAX_SHIPS)),
		"bonuses": Array(formation.data.get("bonuses", [])).duplicate(true),
	}


static func _doctrine_view(doctrine: ContentDefinition) -> Dictionary:
	if doctrine == null:
		return {}
	var data: Dictionary = doctrine.data
	return {
		"id": doctrine.id,
		"name_key": doctrine.name_key,
		"engagement": String(data.get("engagement", "")),
		"retreat": String(data.get("retreat", "")),
		"escort": String(data.get("escort", "")),
		"target_priority": String(data.get("target_priority", "")),
		"supply_policy": String(data.get("supply_policy", "")),
		"formation": String(data.get("formation", "")),
	}


static func _sorted(definitions: Array[ContentDefinition]) -> Array[ContentDefinition]:
	var sorted := definitions.duplicate()
	sorted.sort_custom(func(left: ContentDefinition, right: ContentDefinition) -> bool: return left.id < right.id)
	return sorted
