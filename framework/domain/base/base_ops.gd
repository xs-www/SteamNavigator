class_name BaseOps
extends RefCounted
## @static-doc
## 作用：Phase D3 基地（base）的纯结构与计算层：规范化 `data.base`、解析基地/建筑/
## 升级/配方/工人工种引用、计算仓储、防御、每 tick 支出、生产速度，并给出只读
## `base.view` 数据。持久状态只记录基地实例（站点、建筑、工人、仓储、生产订单），
## 不复制内容定义。
##
## ## 契约与约束
## - `data.base` 只在 `base.claim` 成功后存在：`{site_id, site_archetype_id, port_id,
##   buildings[], storage{}, workers{}, next_building, unpaid_ticks, halted}`。
## - 建筑实例：`{instance_id, building_ref, level, status, remaining_hours,
##   workers{role:qty}, order{recipe_id, remaining_hours, total_hours}}`；
##   status = `building` / `ready` / `upgrading`。
## - 仓储是 `{item_id: amount}`；容量 = 站点容量 + 已完工建筑的 `storage_capacity` +
##   等级修正，单位与 item.data.unit_weight 一致。
## - 生产速度 = 建筑等级修正乘积 ×（1 + Σ 已分配工人的 speed_bonus）；工人不足
##   `workers_required` 时订单不推进，但仍支付工资与维护费。
## - 损坏数据一律规范化或跳过，`view()` 绝不抛引擎错误且不写状态。
## @end-static-doc

const BASE_KEY := "base"
const DEFAULT_BUILDING := {
	"instance_id": "",
	"building_ref": "",
	"level": 1,
	"status": "building",
	"remaining_hours": 0.0,
	"workers": {},
	"order": {},
	"upgrade_ref": "",
}
const DEFAULT_BASE := {
	"site_id": "base",
	"site_archetype_id": "",
	"port_id": "",
	"buildings": [],
	"storage": {},
	"workers": {},
	"next_building": 1,
	"unpaid_ticks": 0,
	"upkeep_debt": 0.0,
	"halted": false,
}
const VALID_STATUS := ["building", "ready", "upgrading"]


static func has_base(state: GameState) -> bool:
	if state == null:
		return false
	var raw: Variant = state.data.get(BASE_KEY, null)
	return raw is Dictionary and not String((raw as Dictionary).get("site_archetype_id", "")).is_empty()


## Returns the live base block, or `{}` when the player has not claimed a base.
static func ensure_structure(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var raw: Variant = state.data.get(BASE_KEY, null)
	if not (raw is Dictionary) or String((raw as Dictionary).get("site_archetype_id", "")).is_empty():
		return {}
	var base := _normalize(raw)
	state.data[BASE_KEY] = base
	return base


## Read-only view. Never writes `data.base`; malformed stored values are normalized in
## a copy so the query always answers.
static func view(state: GameState, hub: RegistryHub = null) -> Dictionary:
	var raw: Variant = state.data.get(BASE_KEY, null) if state != null else null
	if not (raw is Dictionary) or String((raw as Dictionary).get("site_archetype_id", "")).is_empty():
		return {"claimed": false}
	var base := _normalize(raw)
	var site := site_definition(hub, String(base.get("site_archetype_id", "")))
	var storage := storage_view(hub, base)
	var workers := workers_view(hub, base)
	var buildings: Array = []
	for entry in base.get("buildings", []):
		if entry is Dictionary:
			buildings.append(building_view(hub, base, entry))
	return {
		"claimed": true,
		"site_id": String(base.get("site_id", "")),
		"site_archetype_id": String(base.get("site_archetype_id", "")),
		"site": _site_view(site),
		"port_id": String(base.get("port_id", "")),
		"slot_count": slot_count(hub, base),
		"slots_used": (base.get("buildings", []) as Array).size(),
		"buildings": buildings,
		"storage": storage,
		"workers": workers,
		"defense": defense(hub, base),
		"maintenance_per_tick": maintenance_per_tick(hub, base),
		"upkeep_per_tick": upkeep_per_tick(hub, base),
		"wages_per_tick": wages_per_tick(hub, base),
		"money_due_per_tick": money_due_per_tick(hub, base),
		"halted": bool(base.get("halted", false)),
		"unpaid_ticks": int(base.get("unpaid_ticks", 0)),
		"upkeep_debt": float(base.get("upkeep_debt", 0.0)),
	}


static func site_definition(hub: RegistryHub, site_id: String) -> ContentDefinition:
	if hub == null or site_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.BASE_SITE, site_id)


static func building_definition(hub: RegistryHub, building_id: String) -> ContentDefinition:
	if hub == null or building_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.BUILDING, building_id)


static func recipe_definition(hub: RegistryHub, recipe_id: String) -> ContentDefinition:
	if hub == null or recipe_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.PRODUCTION_RECIPE, recipe_id)


static func upgrade_definition(hub: RegistryHub, upgrade_id: String) -> ContentDefinition:
	if hub == null or upgrade_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.BUILDING_UPGRADE, upgrade_id)


static func worker_role_definition(hub: RegistryHub, role_id: String) -> ContentDefinition:
	if hub == null or role_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.WORKER_ROLE, role_id)


static func building_entry(base: Dictionary, instance_id: String) -> Dictionary:
	for entry in base.get("buildings", []):
		if entry is Dictionary and String((entry as Dictionary).get("instance_id", "")) == instance_id:
			return entry
	return {}


static func next_instance_id(base: Dictionary) -> String:
	var next_id := maxi(1, int(base.get("next_building", 1)))
	return "bld_%d" % next_id


static func slot_count(hub: RegistryHub, base: Dictionary) -> int:
	var site := site_definition(hub, String(base.get("site_archetype_id", "")))
	return maxi(1, int(site.data.get("slot_count", 1))) if site != null else 1


static func item_unit_weight(hub: RegistryHub, item_id: String) -> float:
	if hub == null:
		return 1.0
	var item := hub.get_by_id(ContentTypes.ITEM, item_id)
	return maxf(0.0, float(item.data.get("unit_weight", 1.0))) if item != null else 1.0


static func storage_used(hub: RegistryHub, storage: Dictionary) -> float:
	var total := 0.0
	for raw_item_id in storage.keys():
		var item_id := String(raw_item_id)
		var amount := maxi(0, int(storage[raw_item_id]))
		total += item_unit_weight(hub, item_id) * float(amount)
	return total


static func storage_capacity(hub: RegistryHub, base: Dictionary) -> float:
	var site := site_definition(hub, String(base.get("site_archetype_id", "")))
	var capacity := float(site.data.get("storage_capacity", 0.0)) if site != null else 0.0
	for entry in base.get("buildings", []):
		if not (entry is Dictionary):
			continue
		var building: Dictionary = entry
		if String(building.get("status", "")) != "ready":
			continue
		var definition := building_definition(hub, String(building.get("building_ref", "")))
		if definition == null:
			continue
		capacity += float(definition.data.get("storage_capacity", 0.0))
		capacity += _level_bonus(hub, definition, int(building.get("level", 1)), "storage_capacity")
	return maxf(0.0, capacity)


static func defense(hub: RegistryHub, base: Dictionary) -> int:
	var site := site_definition(hub, String(base.get("site_archetype_id", "")))
	var total := int(site.data.get("defense", 0)) if site != null else 0
	for entry in base.get("buildings", []):
		if not (entry is Dictionary):
			continue
		var building: Dictionary = entry
		if String(building.get("status", "")) != "ready":
			continue
		var definition := building_definition(hub, String(building.get("building_ref", "")))
		if definition == null:
			continue
		total += int(definition.data.get("defense", 0))
		total += int(_level_bonus(hub, definition, int(building.get("level", 1)), "defense"))
	return maxi(0, total)


static func maintenance_per_tick(hub: RegistryHub, base: Dictionary) -> float:
	var site := site_definition(hub, String(base.get("site_archetype_id", "")))
	return float(site.data.get("maintenance_per_tick", 0.0)) if site != null else 0.0


static func upkeep_per_tick(hub: RegistryHub, base: Dictionary) -> float:
	var total := 0.0
	for entry in base.get("buildings", []):
		if entry is Dictionary:
			var definition := building_definition(hub, String((entry as Dictionary).get("building_ref", "")))
			if definition != null:
				total += float(definition.data.get("upkeep_per_tick", 0.0))
	return total


static func wages_per_tick(hub: RegistryHub, base: Dictionary) -> float:
	var total := 0.0
	for raw_role_id in (base.get("workers", {}) as Dictionary).keys():
		var role := worker_role_definition(hub, String(raw_role_id))
		if role != null:
			total += float(role.data.get("wage_per_tick", 0.0)) * float(int((base.get("workers", {}) as Dictionary).get(raw_role_id, 0)))
	for entry in base.get("buildings", []):
		if not (entry is Dictionary):
			continue
		var assigned: Dictionary = (entry as Dictionary).get("workers", {})
		for raw_role_id in assigned.keys():
			var role := worker_role_definition(hub, String(raw_role_id))
			if role != null:
				total += float(role.data.get("wage_per_tick", 0.0)) * float(int(assigned[raw_role_id]))
	return total


static func money_due_per_tick(hub: RegistryHub, base: Dictionary) -> float:
	return maintenance_per_tick(hub, base) + upkeep_per_tick(hub, base) + wages_per_tick(hub, base)


static func assigned_worker_count(entry: Dictionary) -> int:
	var total := 0
	for raw_role_id in (entry.get("workers", {}) as Dictionary).keys():
		total += int((entry.get("workers", {}) as Dictionary)[raw_role_id])
	return total


static func production_speed(hub: RegistryHub, base: Dictionary, entry: Dictionary) -> float:
	var definition := building_definition(hub, String(entry.get("building_ref", "")))
	if definition == null:
		return 1.0
	var speed := 1.0
	for upgrade in hub.get_all(ContentTypes.BUILDING_UPGRADE):
		if String(upgrade.data.get("building_ref", "")) != definition.id:
			continue
		if int(upgrade.data.get("to_level", 0)) > int(entry.get("level", 1)):
			continue
		for modifier in upgrade.data.get("modifiers", []):
			if modifier is Dictionary and String((modifier as Dictionary).get("stat", "")) == "production_speed":
				speed = _apply_modifier(speed, String((modifier as Dictionary).get("op", "")), float((modifier as Dictionary).get("value", 0.0)))
	var assigned: Dictionary = entry.get("workers", {})
	for raw_role_id in assigned.keys():
		var role := worker_role_definition(hub, String(raw_role_id))
		if role != null:
			speed *= 1.0 + float(role.data.get("speed_bonus", 0.0)) * float(int(assigned[raw_role_id]))
	return maxf(0.01, speed)


static func storage_view(hub: RegistryHub, base: Dictionary) -> Dictionary:
	var rows: Array = []
	var storage: Dictionary = base.get("storage", {})
	var item_ids: Array = storage.keys()
	item_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	var used := 0.0
	for raw_item_id in item_ids:
		var item_id := String(raw_item_id)
		var amount := int(storage[raw_item_id])
		if amount <= 0:
			continue
		var unit_weight := item_unit_weight(hub, item_id)
		used += unit_weight * float(amount)
		var item := hub.get_by_id(ContentTypes.ITEM, item_id) if hub != null else null
		rows.append({
			"item_id": item_id,
			"name_key": item.name_key if item != null else item_id,
			"amount": amount,
			"unit_weight": unit_weight,
		})
	return {
		"items": rows,
		"used_weight": used,
		"capacity": storage_capacity(hub, base),
	}


static func workers_view(hub: RegistryHub, base: Dictionary) -> Dictionary:
	var pool: Dictionary = base.get("workers", {})
	var rows: Array = []
	var role_ids: Array = pool.keys()
	role_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	var total := 0
	for raw_role_id in role_ids:
		var amount := int(pool[raw_role_id])
		if amount <= 0:
			continue
		total += amount
		var role := worker_role_definition(hub, String(raw_role_id))
		rows.append({
			"role_id": String(raw_role_id),
			"name_key": role.name_key if role != null else String(raw_role_id),
			"amount": amount,
			"wage_per_tick": float(role.data.get("wage_per_tick", 0.0)) if role != null else 0.0,
		})
	var assigned := 0
	for entry in base.get("buildings", []):
		if entry is Dictionary:
			assigned += assigned_worker_count(entry as Dictionary)
	return {"pool": rows, "pool_total": total, "assigned_total": assigned, "total": total + assigned}


static func building_view(hub: RegistryHub, base: Dictionary, entry: Dictionary) -> Dictionary:
	var definition := building_definition(hub, String(entry.get("building_ref", "")))
	var order: Dictionary = entry.get("order", {})
	var order_view: Dictionary = {}
	if not order.is_empty():
		var recipe := recipe_definition(hub, String(order.get("recipe_id", "")))
		order_view = {
			"recipe_id": String(order.get("recipe_id", "")),
			"name_key": recipe.name_key if recipe != null else String(order.get("recipe_id", "")),
			"remaining_hours": float(order.get("remaining_hours", 0.0)),
			"total_hours": float(order.get("total_hours", 0.0)),
		}
	var workers: Dictionary = entry.get("workers", {})
	var worker_rows: Array = []
	for raw_role_id in workers.keys():
		if int(workers[raw_role_id]) <= 0:
			continue
		var role := worker_role_definition(hub, String(raw_role_id))
		worker_rows.append({
			"role_id": String(raw_role_id),
			"name_key": role.name_key if role != null else String(raw_role_id),
			"amount": int(workers[raw_role_id]),
		})
	var recipe_rows: Array = []
	if definition != null:
		for raw_recipe_id in definition.data.get("recipes", []):
			var recipe := recipe_definition(hub, String(raw_recipe_id))
			if recipe != null:
				recipe_rows.append({
					"recipe_id": recipe.id,
					"name_key": recipe.name_key,
					"workers_required": int(recipe.data.get("workers_required", 0)),
				})
	return {
		"instance_id": String(entry.get("instance_id", "")),
		"building_id": String(entry.get("building_ref", "")),
		"name_key": definition.name_key if definition != null else String(entry.get("building_ref", "")),
		"category": String(definition.data.get("category", "")) if definition != null else "",
		"level": int(entry.get("level", 1)),
		"status": String(entry.get("status", "building")),
		"remaining_hours": float(entry.get("remaining_hours", 0.0)),
		"upgrade_ref": String(entry.get("upgrade_ref", "")),
		"worker_slots": int(definition.data.get("worker_slots", 0)) if definition != null else 0,
		"worker_role": String(definition.data.get("worker_role", "")) if definition != null else "",
		"worker_role_name_key": _definition_name_key(hub, ContentTypes.WORKER_ROLE, String(definition.data.get("worker_role", ""))) if definition != null else "",
		"workers": worker_rows,
		"order": order_view,
		"recipes": recipe_rows,
		"production_speed": production_speed(hub, base, entry),
		"upkeep_per_tick": float(definition.data.get("upkeep_per_tick", 0.0)) if definition != null else 0.0,
	}


static func _definition_name_key(hub: RegistryHub, content_type: StringName, definition_id: String, fallback: String = "") -> String:
	if hub == null or definition_id.is_empty():
		return fallback
	var definition := hub.get_by_id(content_type, definition_id)
	return definition.name_key if definition != null else fallback


static func _site_view(site: ContentDefinition) -> Dictionary:
	if site == null:
		return {}
	return {
		"id": site.id,
		"name_key": site.name_key,
		"slot_count": int(site.data.get("slot_count", 0)),
		"storage_capacity": float(site.data.get("storage_capacity", 0.0)),
		"maintenance_per_tick": float(site.data.get("maintenance_per_tick", 0.0)),
		"defense": int(site.data.get("defense", 0)),
	}


static func _level_bonus(hub: RegistryHub, building: ContentDefinition, level: int, stat: String) -> float:
	var total := 0.0
	for upgrade in hub.get_all(ContentTypes.BUILDING_UPGRADE):
		if String(upgrade.data.get("building_ref", "")) != building.id:
			continue
		if int(upgrade.data.get("to_level", 0)) > level:
			continue
		for modifier in upgrade.data.get("modifiers", []):
			if modifier is Dictionary and String((modifier as Dictionary).get("stat", "")) == stat:
				total = _apply_modifier(total, String((modifier as Dictionary).get("op", "")), float((modifier as Dictionary).get("value", 0.0)))
	return total


static func _apply_modifier(current: float, op: String, value: float) -> float:
	match op:
		"add":
			return current + value
		"mul":
			return current * value
		"set":
			return value
	return current


static func _normalize(raw: Dictionary) -> Dictionary:
	var base: Dictionary = DEFAULT_BASE.duplicate(true)
	base["site_archetype_id"] = _safe_string(raw.get("site_archetype_id", ""))
	base["site_id"] = _safe_string(raw.get("site_id", "base"), "base")
	base["port_id"] = _safe_string(raw.get("port_id", ""))
	base["next_building"] = maxi(1, int(raw.get("next_building", 1)))
	base["unpaid_ticks"] = maxi(0, int(raw.get("unpaid_ticks", 0)))
	base["upkeep_debt"] = maxf(0.0, float(raw.get("upkeep_debt", 0.0)))
	base["halted"] = bool(raw.get("halted", false))
	var raw_storage: Variant = raw.get("storage", {})
	var storage: Dictionary = {}
	if raw_storage is Dictionary:
		for raw_item_id in (raw_storage as Dictionary).keys():
			var amount := int((raw_storage as Dictionary)[raw_item_id])
			if amount > 0:
				storage[String(raw_item_id)] = amount
	base["storage"] = storage
	var raw_workers: Variant = raw.get("workers", {})
	var workers: Dictionary = {}
	if raw_workers is Dictionary:
		for raw_role_id in (raw_workers as Dictionary).keys():
			var amount := int((raw_workers as Dictionary)[raw_role_id])
			if amount > 0:
				workers[String(raw_role_id)] = amount
	base["workers"] = workers
	var buildings: Array = []
	var seen: Dictionary = {}
	var raw_buildings: Variant = raw.get("buildings", [])
	if raw_buildings is Array:
		for raw_entry in raw_buildings:
			if not (raw_entry is Dictionary):
				continue
			var entry := _normalize_building(raw_entry)
			if entry.is_empty() or seen.has(entry["instance_id"]):
				continue
			seen[entry["instance_id"]] = true
			buildings.append(entry)
	base["buildings"] = buildings
	return base


static func _normalize_building(raw: Dictionary) -> Dictionary:
	var instance_id := _safe_string(raw.get("instance_id", ""))
	var building_ref := _safe_string(raw.get("building_ref", ""))
	if instance_id.is_empty() or building_ref.is_empty():
		return {}
	var entry: Dictionary = DEFAULT_BUILDING.duplicate(true)
	entry["instance_id"] = instance_id
	entry["building_ref"] = building_ref
	entry["level"] = clampi(int(raw.get("level", 1)), 1, 3)
	var status := _safe_string(raw.get("status", "building"))
	entry["status"] = status if VALID_STATUS.has(status) else "building"
	entry["remaining_hours"] = maxf(0.0, float(raw.get("remaining_hours", 0.0)))
	entry["upgrade_ref"] = _safe_string(raw.get("upgrade_ref", ""))
	var raw_workers: Variant = raw.get("workers", {})
	var workers: Dictionary = {}
	if raw_workers is Dictionary:
		for raw_role_id in (raw_workers as Dictionary).keys():
			var amount := int((raw_workers as Dictionary)[raw_role_id])
			if amount > 0:
				workers[String(raw_role_id)] = amount
	entry["workers"] = workers
	var raw_order: Variant = raw.get("order", {})
	if raw_order is Dictionary and not _safe_string((raw_order as Dictionary).get("recipe_id", "")).is_empty():
		entry["order"] = {
			"recipe_id": _safe_string((raw_order as Dictionary).get("recipe_id", "")),
			"remaining_hours": maxf(0.0, float((raw_order as Dictionary).get("remaining_hours", 0.0))),
			"total_hours": maxf(0.0, float((raw_order as Dictionary).get("total_hours", 0.0))),
		}
	return entry


static func _safe_string(value: Variant, fallback: String = "") -> String:
	return value if value is String else fallback

