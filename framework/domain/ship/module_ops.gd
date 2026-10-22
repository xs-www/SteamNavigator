class_name ModuleOps
extends RefCounted
## @static-doc
## 作用：Content Schema 2.0 统一模块类型 `modules` 的分类访问器：按 `data.v2_category`
## （boiler / cargo / utility / cabin，`crew` 预留）查询定义，并把 ship 存档的扁平槽位
## 映射到 category（boiler / cargo_modules / navigation_module / safety_module /
## passenger_cabin），供 ship_ops / ship_commands / shipyard_view / craft_ops /
## 完整性检查与船厂 UI 共用。
##
## ## 契约与约束
## - 5 类 1.0 模块已合并为单一 active 2.0 类型 `ContentTypes.MODULE`；hulls 仍是独立
##   `ContentTypes.HULL`，不属于模块目录。
## - ship 存档保持原有扁平槽位（`boiler_id` / `cargo_modules` / `navigation_module_id` /
##   `safety_module_id` / `passenger_cabin_id`）与 `module_instances` 形状，不做迁移。
## - utility 同时覆盖原导航与安全模块：定义 tags `module.navigation` / `module.safety`
##   决定购买安装的目标槽；无标签或冲突时兜底第一个空 utility 槽（先 navigation 后
##   safety）。UI 拖放时以拖放目标槽为准。
## - category 专属必填字段由语义校验器（CrossReferenceValidator）负责，因为项目
##   SchemaValidator 不支持 if/then；本文件只提供字段表。
## @end-static-doc

## Active module categories in authoring order. `crew` is reserved by the schema but
## has no runtime category yet (Phase C).
const CATEGORIES := ["boiler", "cargo", "utility", "cabin"]

## Flat ship save slot -> accepted module category.
const SLOT_CATEGORIES := {
	"boiler": "boiler",
	"cargo_modules": "cargo",
	"navigation_module": "utility",
	"safety_module": "utility",
	"passenger_cabin": "cabin",
}

## Flat ship save slot -> `ship` dictionary field.
const SLOT_KEYS := {
	"boiler": "boiler_id",
	"cargo_modules": "cargo_modules",
	"navigation_module": "navigation_module_id",
	"safety_module": "safety_module_id",
	"passenger_cabin": "passenger_cabin_id",
}

## Flat ship save slot -> `ShipModules` instance-slot name.
const INSTANCE_SLOTS := {
	"boiler": "boiler",
	"cargo_modules": "cargo",
	"navigation_module": "navigation",
	"safety_module": "safety",
	"passenger_cabin": "cabin",
}

## Category -> flat slots (utility owns the two legacy single slots).
const CATEGORY_SLOTS := {
	"boiler": ["boiler"],
	"cargo": ["cargo_modules"],
	"utility": ["navigation_module", "safety_module"],
	"cabin": ["passenger_cabin"],
}

const UTILITY_SLOTS := ["navigation_module", "safety_module"]
const NAVIGATION_TAG := "module.navigation"
const SAFETY_TAG := "module.safety"

## Category-specific data fields the merged schema cannot require by itself.
const CATEGORY_REQUIRED_FIELDS := {
	"boiler": ["speed_mul", "coal_rate", "water_rate"],
	"cargo": ["capacity"],
	"utility": ["risk_add"],
	"cabin": ["passenger_capacity"],
}

## Utility definitions keep their legacy navigation/safety number block behind tags.
const UTILITY_TAG_FIELDS := {
	NAVIGATION_TAG: ["speed_mul", "reveal_facilities"],
	SAFETY_TAG: ["damage_mul", "repair_cost_mul"],
}


static func all(hub: RegistryHub) -> Array[ContentDefinition]:
	return hub.get_all(ContentTypes.MODULE)


static func all_of_category(hub: RegistryHub, category: String) -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for definition in all(hub):
		if category_of(definition) == category:
			result.append(definition)
	return result


static func get_by_id(hub: RegistryHub, module_id: String) -> ContentDefinition:
	if module_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.MODULE, module_id)


static func is_module(hub: RegistryHub, module_id: String) -> bool:
	return get_by_id(hub, module_id) != null


static func category_of(definition: ContentDefinition) -> String:
	if definition == null:
		return ""
	return String(definition.data.get("v2_category", ""))


static func category_of_id(hub: RegistryHub, module_id: String) -> String:
	return category_of(get_by_id(hub, module_id))


static func count(hub: RegistryHub, category: String) -> int:
	return all_of_category(hub, category).size()


## Category a flat ship slot accepts ("" for unknown slots such as hull).
static func slot_category(slot: String) -> String:
	return String(SLOT_CATEGORIES.get(slot, ""))


static func category_slots(category: String) -> Array:
	return Array(CATEGORY_SLOTS.get(category, []))


## Ship dictionary field behind a flat slot, e.g. "boiler" -> "boiler_id".
static func ship_slot_key(slot: String) -> String:
	return String(SLOT_KEYS.get(slot, ""))


## ShipModules instance slot behind a flat slot, e.g. "navigation_module" -> "navigation".
static func instance_slot(slot: String) -> String:
	return String(INSTANCE_SLOTS.get(slot, ""))


static func accepts(definition: ContentDefinition, slot: String) -> bool:
	return definition != null and category_of(definition) == slot_category(slot)


static func accepts_category(category: String, slot: String) -> bool:
	return not category.is_empty() and category == slot_category(slot)


## Flat slot a module definition installs into. Hulls are not modules and return "".
## Utility modules resolve by tag, then by the first empty utility slot.
static func slot_for(definition: ContentDefinition, ship: Dictionary = {}) -> String:
	return slot_for_definition(definition, ship)


## `requested_slot` (drag target) wins only when it is a valid utility slot; for
## boiler / cargo / cabin the category fixes the slot.
static func slot_for_with_request(definition: ContentDefinition, ship: Dictionary, requested_slot: String) -> String:
	if category_of(definition) == "utility" and slot_category(requested_slot) == "utility":
		return requested_slot
	return slot_for_definition(definition, ship)


## Category-only slot resolution (used when no definition is at hand, e.g. a
## candidate filter that only knows the category). Utility falls back to the
## first empty utility slot.
static func slot_for_category(category: String, ship: Dictionary = {}) -> String:
	match category:
		"boiler":
			return "boiler"
		"cargo":
			return "cargo_modules"
		"cabin":
			return "passenger_cabin"
		"utility":
			for slot in UTILITY_SLOTS:
				if String(ship.get(ship_slot_key(slot), "")).is_empty():
					return slot
			return "navigation_module"
	return ""


static func slot_for_definition(definition: ContentDefinition, ship: Dictionary = {}) -> String:
	if definition == null:
		return ""
	var category := category_of(definition)
	if category != "utility":
		return slot_for_category(category, ship)
	if definition.has_tag(NAVIGATION_TAG) and not definition.has_tag(SAFETY_TAG):
		return "navigation_module"
	if definition.has_tag(SAFETY_TAG) and not definition.has_tag(NAVIGATION_TAG):
		return "safety_module"
	for slot in UTILITY_SLOTS:
		if String(ship.get(ship_slot_key(slot), "")).is_empty():
			return slot
	return "navigation_module"


## Required data fields for a module definition, category block plus the
## navigation/safety tag block for utility modules.
static func required_fields(definition: ContentDefinition) -> Array:
	var category := category_of(definition)
	var fields: Array = Array(CATEGORY_REQUIRED_FIELDS.get(category, [])).duplicate()
	if category == "utility":
		for tag in UTILITY_TAG_FIELDS.keys():
			if definition.has_tag(tag):
				for field in UTILITY_TAG_FIELDS[tag]:
					if not fields.has(field):
						fields.append(field)
	return fields
