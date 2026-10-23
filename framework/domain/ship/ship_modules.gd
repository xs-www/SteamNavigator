class_name ShipModules
extends RefCounted
## Durable per-module instance state for a ship.
##
## Content Schema 2.0 ships store installed modules as unified `modules` definition
## IDs in flat slot keys (`boiler_id`, `cargo_modules`, ...). This helper adds the
## instance layer repair and combat need without changing that projection:
##
## ```json
## "module_instances": {
##   "boiler": {"instance_id": "module_1", "condition": 1.0},
##   "navigation": {"instance_id": "module_2", "condition": 1.0},
##   "safety": {...}, "cabin": {...},
##   "cargo": [{"instance_id": "module_3", "condition": 1.0}]
## }
## ```
##
## - `condition` is a 0..1 ratio; `0` means the module is disabled (installed but
##   not operational until repaired). `damage()` and `repair_all()` are the only
##   writers besides `ensure()`.
## - `instance_id` is stable for the life of one installed module, so events and
##   combat and repairs can reference a specific module instance across save/load.
## - Flat slot keys stay authoritative for *which definition* is installed; the
##   unified `modules` type maps category -> flat slot through `ModuleOps`, and
##   `ensure()` keeps the instance table aligned with the flat keys.
##
## All accessors are read-safe on legacy ships: a missing instance table reads as
## full condition instead of failing. `ensure()` is called on new runs, after
## install/uninstall and on save load.

const SINGLE_SLOTS := {
	"boiler": "boiler_id",
	"navigation": "navigation_module_id",
	"safety": "safety_module_id",
	"cabin": "passenger_cabin_id",
}
const CARGO_SLOT := "cargo"
const DEFAULT_CONDITION := 1.0


static func has_slot(ship: Dictionary, slot: String) -> bool:
	if slot == CARGO_SLOT:
		return not Array(ship.get("cargo_modules", [])).is_empty()
	if not SINGLE_SLOTS.has(slot):
		return false
	return not String(ship.get(SINGLE_SLOTS[slot], "")).is_empty()


## Aligns the instance table with the flat slot keys, creating missing entries
## and dropping entries whose slot became empty. Existing conditions and ids are
## preserved; only new modules get a fresh id and full condition.
static func ensure(ship: Dictionary) -> Dictionary:
	var current: Variant = ship.get("module_instances", null)
	if not (current is Dictionary):
		current = {}
	var table: Dictionary = current
	var serial := int(ship.get("module_serial", 0))
	for slot in SINGLE_SLOTS.keys():
		var definition_id := String(ship.get(SINGLE_SLOTS[slot], ""))
		if definition_id.is_empty():
			table.erase(slot)
			continue
		if not (table.get(slot, null) is Dictionary):
			serial += 1
			table[slot] = {"instance_id": "module_%d" % serial, "condition": DEFAULT_CONDITION}
	var cargo_ids: Array = ship.get("cargo_modules", [])
	var previous: Variant = table.get(CARGO_SLOT, null)
	var previous_list: Array = previous if previous is Array else []
	var cargo_instances: Array = []
	for index in cargo_ids.size():
		if index < previous_list.size() and previous_list[index] is Dictionary:
			cargo_instances.append(previous_list[index])
		else:
			serial += 1
			cargo_instances.append({"instance_id": "module_%d" % serial, "condition": DEFAULT_CONDITION})
	table[CARGO_SLOT] = cargo_instances
	ship["module_instances"] = table
	ship["module_serial"] = serial
	return table


static func instances(ship: Dictionary) -> Dictionary:
	var current: Variant = ship.get("module_instances", null)
	return current if current is Dictionary else {}


## One instance dictionary, or a detached full-condition default when unknown.
static func instance(ship: Dictionary, slot: String, index: int = 0) -> Dictionary:
	var table := instances(ship)
	if slot == CARGO_SLOT:
		var list: Variant = table.get(CARGO_SLOT, null)
		if list is Array and index >= 0 and index < list.size() and list[index] is Dictionary:
			return list[index]
	elif table.get(slot, null) is Dictionary:
		return table[slot]
	return {"instance_id": "", "condition": DEFAULT_CONDITION}


static func condition(ship: Dictionary, slot: String, index: int = 0) -> float:
	return clampf(float(instance(ship, slot, index).get("condition", DEFAULT_CONDITION)), 0.0, 1.0)


static func is_disabled(ship: Dictionary, slot: String, index: int = 0) -> bool:
	return condition(ship, slot, index) <= 0.0


static func set_condition(ship: Dictionary, slot: String, index: int, value: float) -> Dictionary:
	if not has_slot(ship, slot):
		return {"ok": false, "error": "unknown_slot"}
	ensure(ship)
	var target := instance(ship, slot, index)
	target["condition"] = clampf(value, 0.0, 1.0)
	return {"ok": true, "slot": slot, "index": index, "condition": float(target["condition"])}


## Applies ratio damage to one instance. Returns the resulting state; `disabled`
## is true only on the transition that reaches zero.
static func damage(ship: Dictionary, slot: String, index: int, amount: float) -> Dictionary:
	if amount <= 0.0:
		return {"ok": false, "error": "invalid_amount"}
	if not has_slot(ship, slot):
		return {"ok": false, "error": "unknown_slot"}
	ensure(ship)
	var target := instance(ship, slot, index)
	var before := clampf(float(target.get("condition", DEFAULT_CONDITION)), 0.0, 1.0)
	var after := maxf(0.0, before - amount)
	target["condition"] = after
	return {
		"ok": true,
		"slot": slot,
		"index": index,
		"instance_id": String(target.get("instance_id", "")),
		"condition": after,
		"disabled": after <= 0.0,
		"newly_disabled": before > 0.0 and after <= 0.0,
	}


## Creates a fresh instance for a single slot after a module was installed.
## Flat slot keys must already be updated.
static func install_slot(ship: Dictionary, slot: String) -> Dictionary:
	if not SINGLE_SLOTS.has(slot):
		return {}
	ensure(ship)
	var serial := int(ship.get("module_serial", 0)) + 1
	ship["module_serial"] = serial
	var fresh := {"instance_id": "module_%d" % serial, "condition": DEFAULT_CONDITION}
	ship["module_instances"][slot] = fresh
	return fresh


## Returns the instance for a cargo module appended to the flat list. `ensure()`
## creates it, so this only has to hand the last entry back.
static func append_cargo(ship: Dictionary) -> Dictionary:
	ensure(ship)
	var list: Array = ship["module_instances"][CARGO_SLOT]
	if list.is_empty():
		return {}
	return list[list.size() - 1]


## Drops the instance at a cargo index after the flat list removed that module.
## Deliberately does not call `ensure()`: the flat list is already one shorter, so
## aligning here would drop the wrong (last) instance.
static func remove_cargo(ship: Dictionary, index: int) -> void:
	var table := instances(ship)
	var list: Variant = table.get(CARGO_SLOT, null)
	if not (list is Array):
		return
	if index >= 0 and index < list.size():
		list.remove_at(index)
	table[CARGO_SLOT] = list


## Clears a single slot's instance after the flat key was emptied.
static func remove_slot(ship: Dictionary, slot: String) -> void:
	ensure(ship)
	ship["module_instances"].erase(slot)


## Restores every installed module to full condition. Returns the number of
## repaired instances (condition < 1 before the call).
static func repair_all(ship: Dictionary) -> int:
	var table := ensure(ship)
	var repaired := 0
	for slot in SINGLE_SLOTS.keys():
		if table.get(slot, null) is Dictionary:
			if float(table[slot].get("condition", DEFAULT_CONDITION)) < DEFAULT_CONDITION:
				repaired += 1
			table[slot]["condition"] = DEFAULT_CONDITION
	var cargo: Variant = table.get(CARGO_SLOT, null)
	if cargo is Array:
		for entry in cargo:
			if entry is Dictionary:
				if float(entry.get("condition", DEFAULT_CONDITION)) < DEFAULT_CONDITION:
					repaired += 1
				entry["condition"] = DEFAULT_CONDITION
	return repaired


## Instances in slot order with their flat-slot module ids, for cost, UI and
## future combat targeting. Each row: {slot, index, module_id, instance_id,
## condition, disabled}.
static func installed_rows(ship: Dictionary) -> Array:
	var rows: Array = []
	for slot in SINGLE_SLOTS.keys():
		var module_id := String(ship.get(SINGLE_SLOTS[slot], ""))
		if module_id.is_empty():
			continue
		var entry := instance(ship, slot, 0)
		rows.append({
			"slot": slot,
			"index": 0,
			"module_id": module_id,
			"instance_id": String(entry.get("instance_id", "")),
			"condition": clampf(float(entry.get("condition", DEFAULT_CONDITION)), 0.0, 1.0),
			"disabled": is_disabled(ship, slot, 0),
		})
	var cargo_ids: Array = ship.get("cargo_modules", [])
	for index in cargo_ids.size():
		var entry := instance(ship, CARGO_SLOT, index)
		rows.append({
			"slot": CARGO_SLOT,
			"index": index,
			"module_id": String(cargo_ids[index]),
			"instance_id": String(entry.get("instance_id", "")),
			"condition": clampf(float(entry.get("condition", DEFAULT_CONDITION)), 0.0, 1.0),
			"disabled": is_disabled(ship, CARGO_SLOT, index),
		})
	return rows


static func damaged_rows(ship: Dictionary) -> Array:
	var rows: Array = []
	for row in installed_rows(ship):
		if float(row["condition"]) < DEFAULT_CONDITION:
			rows.append(row)
	return rows


static func worst_condition(ship: Dictionary) -> float:
	var rows := installed_rows(ship)
	if rows.is_empty():
		return DEFAULT_CONDITION
	var worst := DEFAULT_CONDITION
	for row in rows:
		worst = minf(worst, float(row["condition"]))
	return worst
