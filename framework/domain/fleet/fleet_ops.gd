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
## - 容量：有 formation 时默认按 `formation.slots.size()`，显式 `max_ships` 优先；
##   无 formation 时用 `MAX_SHIPS`。
## - formation slot 是 formations 定义里的字符串 slot id；空串表示未分配。role 为
##   `flagship` 的槽位只允许旗舰使用；每艘船一个槽位，槽位互斥。
## - 损坏数据（`data.fleet` 不是字典、ships 不是数组、条目/字段类型不对）一律规范化
##   为默认块或跳过，`view()` 绝不抛引擎错误；`view()` 只读不写状态。
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
	var fleet := _normalize_fleet(state.data.get(FLEET_KEY, null), state, hub)
	state.data[FLEET_KEY] = fleet
	return fleet


## Read-only view of the current fleet. Never writes `data.fleet`, and tolerates any
## malformed stored shape.
static func view(state: GameState, hub: RegistryHub = null) -> Dictionary:
	var fleet := _normalize_fleet(state.data.get(FLEET_KEY, null) if state != null else null, state, hub)
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
			"condition": _safe_float(ship.get("condition", 1.0), 1.0),
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


## Max ships allowed by the fleet: framework cap MAX_SHIPS; with a formation the
## default is the formation's slot count unless it declares `max_ships`.
static func max_ships(hub: RegistryHub = null, formation_id: String = "") -> int:
	var cap := MAX_SHIPS
	var formation := _definition(hub, ContentTypes.FORMATION, formation_id)
	if formation != null:
		if formation.data.has("max_ships"):
			cap = mini(MAX_SHIPS, int(formation.data.get("max_ships", MAX_SHIPS)))
		else:
			cap = mini(MAX_SHIPS, (formation.data.get("slots", []) as Array).size())
	return maxi(1, cap)


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
	if formation == null or slot_id.is_empty():
		return {}
	for raw in formation.data.get("slots", []):
		if raw is Dictionary and String((raw as Dictionary).get("id", "")) == slot_id:
			return (raw as Dictionary).duplicate(true)
	return {}


static func formation_slot_role(hub: RegistryHub, formation_id: String, slot_id: String) -> String:
	return String(formation_slot(hub, formation_id, slot_id).get("role", ""))


## Slot ids whose role is `flagship`; only the flagship may occupy them.
static func flagship_slot_ids(hub: RegistryHub, formation_id: String) -> Array[String]:
	var ids: Array[String] = []
	var formation := _definition(hub, ContentTypes.FORMATION, formation_id)
	if formation == null:
		return ids
	for raw in formation.data.get("slots", []):
		if raw is Dictionary and String((raw as Dictionary).get("role", "")) == "flagship":
			var slot_id := String((raw as Dictionary).get("id", ""))
			if not slot_id.is_empty():
				ids.append(slot_id)
	return ids


## Ship entry behind a `ship_id`, or `{}`.
static func ship_entry(fleet: Dictionary, ship_id: String) -> Dictionary:
	for entry in fleet.get("ships", []):
		if entry is Dictionary and String((entry as Dictionary).get("ship_id", "")) == ship_id:
			return entry
	return {}


static func is_valid_slot_id(slot_id: String) -> bool:
	if slot_id.is_empty():
		return false
	var regex := RegEx.create_from_string("^[a-z][a-z0-9_]{0,31}$")
	return regex.search(slot_id) != null


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


## Normalizes any stored value into a valid fleet block (flagship first, sane types).
static func _normalize_fleet(raw: Variant, state: GameState, hub: RegistryHub) -> Dictionary:
	var fleet: Dictionary = DEFAULT_FLEET.duplicate(true)
	var source: Dictionary = raw if raw is Dictionary else {}
	for key in ["doctrine_id", "formation_id"]:
		fleet[key] = _safe_string(source.get(key, ""), "")
	var raw_ships: Variant = source.get("ships", null)
	var ships: Array = []
	var seen: Dictionary = {}
	var flagship_entry: Dictionary = {}
	if raw_ships is Array:
		for raw_entry in raw_ships:
			var entry := _normalize_ship(raw_entry)
			if entry.is_empty():
				continue
			var ship_id := String(entry["ship_id"])
			if seen.has(ship_id):
				continue
			seen[ship_id] = true
			if ship_id == FLAGSHIP_ID:
				if flagship_entry.is_empty():
					flagship_entry = entry
				continue
			ships.append(entry)
	if flagship_entry.is_empty():
		flagship_entry = _make_flagship_entry(state, hub)
	else:
		_sync_flagship_archetype(flagship_entry, state, hub)
	ships.insert(0, flagship_entry)
	fleet["ships"] = ships
	fleet["flagship"] = FLAGSHIP_ID
	return fleet


static func _normalize_ship(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var ship: Dictionary = raw
	var ship_id := _safe_string(ship.get("ship_id", ""), "")
	if ship_id.is_empty():
		return {}
	var entry := DEFAULT_SHIP.duplicate(true)
	entry["ship_id"] = ship_id
	entry["archetype_id"] = _safe_string(ship.get("archetype_id", ""), "")
	entry["captain_id"] = _safe_string(ship.get("captain_id", ""), "")
	entry["formation_slot"] = _safe_string(ship.get("formation_slot", ""), "")
	entry["condition"] = clampf(_safe_float(ship.get("condition", 1.0), 1.0), 0.0, 1.0)
	return entry


static func _make_flagship_entry(state: GameState, hub: RegistryHub) -> Dictionary:
	var entry := DEFAULT_SHIP.duplicate(true)
	entry["ship_id"] = FLAGSHIP_ID
	entry["condition"] = 1.0
	_sync_flagship_archetype(entry, state, hub)
	return entry


static func _sync_flagship_archetype(entry: Dictionary, state: GameState, hub: RegistryHub) -> void:
	if hub == null:
		return
	if String(entry.get("ship_id", "")) != FLAGSHIP_ID:
		return
	var archetype_id := flagship_archetype_id(state, hub)
	if not archetype_id.is_empty():
		entry["archetype_id"] = archetype_id


static func _safe_string(value: Variant, fallback: String) -> String:
	return value if value is String else fallback


static func _safe_float(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		var number := float(value)
		return number if is_finite(number) else fallback
	return fallback


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
	var slots: Array = formation.data.get("slots", [])
	return {
		"id": formation.id,
		"name_key": formation.name_key,
		"slots": slots.duplicate(true),
		"max_ships": int(formation.data.get("max_ships", slots.size())),
		"bonuses": (formation.data.get("bonuses", []) as Array).duplicate(true),
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
