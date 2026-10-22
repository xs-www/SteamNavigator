class_name CrossReferenceValidator
extends RefCounted
## Validates references between content definitions after patches are applied.
##
## Schema validation guarantees shape; this pass guarantees meaning.
## @static-doc
## 作用：Schema 之后的语义校验：材料、构筑、委托奖励、事件条件/效果、港口市场与地图配置，
## 以及 Phase B 世界/战役 9 类（world_profiles / regions / sites / route_templates /
## weather_profiles / factions / discoveries / start_profiles / map_configs）的引用完整性。
##
## ## 契约与约束
## - 硬引用缺失一律 `error`（`reference_missing`）；引用尚未 active 的 planned 类型只给
##   `warning: ref_inactive_type`，目标类型提升后这条规则升级为 `_require` 硬校验。
## - planned 目标类型没有运行时注册表，因此用本文件的 `PLANNED_REF_TYPES` 显式映射
##   （来源：`content_types.json` 的 `planned` 与 WORLD_SCHEMA_V2_RUNTIME §5.1 引用表）。
## - `factions.rival_factions[]` 允许指向同类型定义，但指向自身报 `reference_self`。
## - `map_configs.archetypes` 数量必须 ≥ 引用它的 `start_profiles.world_profile.port_count`；
##   找不到对应 world_profile 时跳过（缺失本身已由 start_profiles 检查报错）。
## - 既有检查与错误码保持不变；空的 v2 Core 内容基线不受影响。
## - C1：5 类模块合并为 `modules` 后，`starting_scenarios` 的 boiler / cargo_modules /
##   navigation_module / safety_module / passenger_cabin 按 `data.v2_category`
##   （boiler / cargo / utility / utility / cabin）解析；category 专属必填字段由
##   `_check_module_category` 承担（合并 Schema 无法表达 if/then）。
## - C3：`quests` 的 `prerequisites.quests_completed[]` 必须是已存在的 quest 定义；
##   objective 的 `event` 必须是 `cmd:*` / `ui:*` 形式（D6：不静默）；objective
##   `match` 里的实体引用键（`item_id` / `module_id` / `hull_id` / `role_id` /
##   `strategy_id`）必须解析到对应运行时注册表（`quest_match_ref_missing`，message
##   带 mod / file / entity / path），`category` 等字面过滤键跳过。
##   **设计理由**：命令 / UI 事件名是字符串总线（`CommandBus` / Shell 观测），没有可枚举的
##   运行时注册表交给内容校验器，因此这里只做格式硬校验；未知但格式合法的事件名属于
##   「内容作者拼写」问题，无法在不引入注册表快照的前提下可靠判定，故不误报。
## @end-static-doc

## Planned target types referenced by active Phase B schemas. They have no runtime
## schema/registry yet (`ContentTypes.all()` does not contain them), so a reference can
## only be reported as `ref_inactive_type` until the target type is promoted.
## Source: content_types.json `planned` (ruin_archetypes / encounter_tables / loot_tables)
## plus the WORLD_SCHEMA_V2_RUNTIME §5.1 table entry for `factions.contract_family`.
const PLANNED_REF_TYPES := {
	"ruin_archetype": "ruin_archetypes",
	"encounter_table": "encounter_tables",
	"loot_table": "loot_tables",
	"contract_family": "contract_families",
}

## C1 unified module categories and the per-category data block the merged schema
## cannot require (see schemas/v2/module.schema.json). `crew` is reserved by the
## schema but has no runtime consumer yet, so it is not a valid authored category.
const MODULE_CATEGORIES := ["boiler", "cargo", "utility", "cabin"]
const MODULE_CATEGORY_REQUIRED_FIELDS := {
	"boiler": ["speed_mul", "coal_rate", "water_rate"],
	"cargo": ["capacity"],
	"utility": ["risk_add"],
	"cabin": ["passenger_capacity"],
}
const UTILITY_TAG_FIELDS := {
	"module.navigation": ["speed_mul", "reveal_facilities"],
	"module.safety": ["damage_mul", "repair_cost_mul"],
}

## C3 quest objective `match` keys that are entity references (checked against the
## runtime registries), mirroring the story condition DSL (`condition_item_missing` /
## `condition_module_missing`). Other match keys — `category`, `kind`, `flag`, ... —
## are literal payload filters, not references, and are skipped on purpose.
const QUEST_MATCH_REFERENCE_TYPES := {
	"item_id": ContentTypes.ITEM,
	"module_id": ContentTypes.MODULE,
	"hull_id": ContentTypes.HULL,
	"role_id": ContentTypes.CREW_ROLE,
	"strategy_id": ContentTypes.BOILER_STRATEGY,
}

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []

var _hub: RegistryHub = null


func validate(hub: RegistryHub) -> Dictionary:
	errors.clear()
	warnings.clear()
	_hub = hub
	_check_modules()
	_check_combat()
	_check_starting_scenarios()
	_check_contracts()
	_check_events()
	_check_port_templates()
	_check_world_profiles()
	_check_regions()
	_check_sites()
	_check_route_templates()
	_check_weather_profiles()
	_check_factions()
	_check_discoveries()
	_check_quests()
	_check_start_profiles()
	_check_map_configs()
	return {
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
	}


func _check_combat() -> void:
	## D1 combat content: weapon damage types / craft materials, enemy AI + loot refs,
	## encounter enemy refs and loot-table entries. Enum vocabularies stay in Schema.
	for weapon in _hub.get_all(ContentTypes.WEAPON):
		var damage_type := String(weapon.data.get("damage_type", ""))
		if not damage_type.is_empty():
			_require(ContentTypes.DAMAGE_TYPE, damage_type, weapon.id, "damage_type")
		for material in weapon.data.get("materials", []):
			if material is Dictionary:
				_require_item(String(material.get("id", "")), weapon.id, "materials")
	for archetype in _hub.get_all(ContentTypes.ENEMY_ARCHETYPE):
		var ability := String(archetype.data.get("combat_ability", ""))
		if not ability.is_empty():
			_require(ContentTypes.COMBAT_ABILITY, ability, archetype.id, "combat_ability")
		var loot_table := String(archetype.data.get("loot_table", ""))
		if not loot_table.is_empty():
			_require(ContentTypes.LOOT_TABLE, loot_table, archetype.id, "loot_table")
	for table in _hub.get_all(ContentTypes.ENCOUNTER_TABLE):
		for entry in table.data.get("entries", []):
			if entry is Dictionary:
				_require(ContentTypes.ENEMY_ARCHETYPE, String(entry.get("enemy_archetype", "")), table.id, "entries.enemy_archetype")
	for loot_table in _hub.get_all(ContentTypes.LOOT_TABLE):
		for entry in loot_table.data.get("entries", []):
			if not (entry is Dictionary):
				continue
			var kind := String(entry.get("kind", ""))
			var expected := ContentTypes.ITEM
			if kind == "weapon":
				expected = ContentTypes.WEAPON
			elif kind == "module":
				expected = ContentTypes.MODULE
			_require(expected, String(entry.get("id", "")), loot_table.id, "entries.id")


func _check_modules() -> void:
	for content_type in ContentTypes.MODULE_TYPES:
		for definition in _hub.get_all(content_type):
			if content_type == ContentTypes.MODULE:
				_check_module_category(definition)
			for material in definition.data.get("materials", []):
				if not (material is Dictionary):
					continue
				var item_id := String(material.get("id", ""))
				if not _item_exists(item_id):
					_error("material_missing", "%s references missing material %s" % [definition.id, item_id], definition.id)
			for modifier in definition.data.get("modifiers", []):
				if modifier is Dictionary and not ["speed", "coal_rate", "water_rate", "risk", "repair_cost", "damage"].has(String(modifier.get("stat", ""))):
					_warn("modifier_unknown_stat", "%s has an unrecognised modifier stat '%s'" % [definition.id, modifier.get("stat", "")], definition.id)


## C1: the merged `modules` schema is a field superset and cannot express per-category
## required blocks (the project SchemaValidator has no if/then), so category semantics
## live here. Navigation/safety modules stay distinguishable through their legacy tags.
func _check_module_category(definition: ContentDefinition) -> void:
	var category := String(definition.data.get("v2_category", ""))
	if not MODULE_CATEGORIES.has(category):
		_error(
			"module_category_unknown",
			"%s has unsupported v2_category '%s'" % [definition.id, category],
			definition.id
		)
		return
	for field in MODULE_CATEGORY_REQUIRED_FIELDS.get(category, []):
		if not definition.data.has(String(field)):
			_error(
				"module_category_field",
				"%s is a %s module but lacks required field '%s'" % [definition.id, category, field],
				definition.id
			)
	if category == "utility":
		for tag in UTILITY_TAG_FIELDS.keys():
			if definition.has_tag(tag):
				for field in UTILITY_TAG_FIELDS[tag]:
					if not definition.data.has(String(field)):
						_error(
							"module_category_field",
							"%s is tagged %s but lacks required field '%s'" % [definition.id, tag, field],
							definition.id
						)
		if not definition.has_tag("module.navigation") and not definition.has_tag("module.safety"):
			_warn(
				"module_utility_tag",
				"%s is a utility module without module.navigation / module.safety; install slot falls back to the first empty utility slot" % definition.id,
				definition.id
			)


func _check_starting_scenarios() -> void:
	for build in _hub.get_all(ContentTypes.STARTING_SCENARIO):
		var hull := _require(ContentTypes.HULL, String(build.data.get("hull", "")), build.id, "hull")
		_require_module(String(build.data.get("boiler", "")), "boiler", build.id, "boiler")
		var cargo_modules: Array = build.data.get("cargo_modules", [])
		for module_id in cargo_modules:
			_require_module(String(module_id), "cargo", build.id, "cargo_modules")
		if not String(build.data.get("navigation_module", "")).is_empty():
			_require_module(String(build.data.get("navigation_module")), "utility", build.id, "navigation_module")
		if not String(build.data.get("safety_module", "")).is_empty():
			_require_module(String(build.data.get("safety_module")), "utility", build.id, "safety_module")
		if not String(build.data.get("passenger_cabin", "")).is_empty():
			_require_module(String(build.data.get("passenger_cabin")), "cabin", build.id, "passenger_cabin")
		_check_role(build, "engineer", "engineer")
		_check_role(build, "navigator", "navigator")
		if hull != null:
			if cargo_modules.size() > int(hull.data.get("cargo_slots", 0)):
				_error(
					"starting_scenario_slots",
					"%s has %d cargo modules but hull only allows %d" % [
						build.id, cargo_modules.size(), int(hull.data.get("cargo_slots", 0))
					],
					build.id
				)
			if not String(build.data.get("passenger_cabin", "")).is_empty() and int(hull.data.get("cabin_slots", 0)) < 1:
				_error("starting_scenario_cabin", "%s has a cabin but hull has no cabin slot" % build.id, build.id)


func _check_role(build: ContentDefinition, field: String, expected_kind: String) -> void:
	var role_id := String(build.data.get(field, ""))
	if role_id.is_empty():
		return
	var role := _hub.get_by_id(ContentTypes.CREW_ROLE, role_id)
	if role == null:
		_error("role_missing", "%s references missing role %s" % [build.id, role_id], build.id)
	elif String(role.data.get("kind", "")) != expected_kind:
		_error("role_kind", "%s expects a %s role but %s is %s" % [
			build.id, expected_kind, role_id, role.data.get("kind", "")
		], build.id)


func _check_contracts() -> void:
	var sequences: Dictionary = {}
	var normal_count := 0
	for contract in _hub.get_all(ContentTypes.CONTRACT):
		var data: Dictionary = contract.data
		var kind := String(data.get("kind", ""))
		if kind == "main":
			var sequence := int(data.get("sequence", 0))
			if sequence < 1 or sequence > 5:
				_error("main_sequence_range", "%s has main sequence %d outside 1..5" % [contract.id, sequence], contract.id)
			if sequences.has(sequence):
				_error("main_sequence_duplicate", "main sequence %d is declared by %s and %s" % [sequence, sequences[sequence], contract.id], contract.id)
			sequences[sequence] = contract.id
		else:
			normal_count += 1
		var formula_id := String(data.get("deadline_formula", ""))
		if not FormulaRegistry.has(formula_id):
			_error("unknown_formula", "%s references unknown deadline formula '%s'" % [contract.id, formula_id], contract.id)
		for payload in data.get("payloads", []):
			if not (payload is Dictionary):
				continue
			if String(payload.get("kind", "")) == "cargo":
				var item_id := String(payload.get("cargo_item_id", ""))
				if item_id.is_empty():
					_error("contract_cargo_item_missing", "%s cargo payload lacks cargo_item_id" % contract.id, contract.id)
				elif not _item_exists(item_id):
					_error("contract_cargo_item_unknown", "%s references unknown cargo item %s" % [contract.id, item_id], contract.id)
		var rewards: Dictionary = data.get("rewards", {})
		for unlock_id in rewards.get("unlock_ids", []):
			if not _definition_exists(String(unlock_id)):
				_error("unlock_missing", "%s unlocks missing definition %s" % [contract.id, unlock_id], contract.id)
		for prerequisite in data.get("requires_completed", []):
			if not _hub.contains(ContentTypes.CONTRACT, String(prerequisite)):
				_error("prerequisite_missing", "%s requires missing contract %s" % [contract.id, prerequisite], contract.id)
		var constraints: Dictionary = data.get("constraints", {})
		var minimum_edges := int(constraints.get("min_route_edges", 1))
		var maximum_edges := int(constraints.get("max_route_edges", 1))
		if minimum_edges > maximum_edges:
			_error("contract_edges", "%s has min_route_edges > max_route_edges" % contract.id, contract.id)
		for tag in constraints.get("required_port_tags", []):
			if not _any_port_template_tag(String(tag)):
				_error("contract_port_tag_missing", "%s requires port tag '%s' but no archetype has it" % [contract.id, tag], contract.id)
	for sequence in range(1, 6):
		if not sequences.has(sequence):
			_error("main_sequence_missing", "no main contract declared for sequence %d" % sequence, "core")
	if normal_count == 0:
		_error("normal_contract_missing", "no normal contract template is declared", "core")
	var finale := _hub.get_by_id(ContentTypes.CONTRACT, String(sequences.get(5, "")))
	if finale != null:
		var has_passenger := false
		var has_cargo := false
		for payload in finale.data.get("payloads", []):
			if payload is Dictionary and String(payload.get("kind", "")) == "passenger":
				has_passenger = true
			if payload is Dictionary and String(payload.get("kind", "")) == "cargo":
				has_cargo = true
		if not has_passenger or not has_cargo:
			_warn("finale_mix", "main_05 should combine cargo and passengers", finale.id)


func _check_events() -> void:
	var has_risk := false
	var has_opportunity := false
	for event in _hub.get_all(ContentTypes.VOYAGE_EVENT):
		var data: Dictionary = event.data
		var trigger := String(data.get("trigger", ""))
		has_risk = has_risk or trigger == "voyage_risk"
		has_opportunity = has_opportunity or trigger == "voyage_opportunity"
		_check_condition(data.get("condition", null), event.id)
		var option_ids: Dictionary = {}
		var options: Array = data.get("options", [])
		if options.size() < 2:
			_error("event_options", "%s must declare at least two options" % event.id, event.id)
		for option in options:
			if not (option is Dictionary):
				continue
			var option_id := String(option.get("id", ""))
			if option_ids.has(option_id):
				_error("event_option_duplicate", "%s has duplicate option id '%s'" % [event.id, option_id], event.id)
			option_ids[option_id] = true
			_check_condition(option.get("condition", null), event.id)
			for effect in option.get("effects", []):
				_check_effect(effect, event.id)
	if not has_risk:
		_error("risk_event_missing", "no voyage_risk event is declared", "core")
	if not has_opportunity:
		_warn("opportunity_event_missing", "no voyage_opportunity event is declared", "core")


func _check_condition(node: Variant, owner: String) -> void:
	if node == null:
		return
	if not (node is Dictionary):
		_error("condition_type", "%s condition must be an object" % owner, owner)
		return
	var state := {"count": 0}
	_check_condition_recursive(node, owner, state)


func _check_condition_recursive(node: Dictionary, owner: String, state: Dictionary) -> void:
	state["count"] = int(state["count"]) + 1
	if int(state["count"]) > 16:
		_error("condition_nodes", "%s condition exceeds 16 nodes" % owner, owner)
		return
	for key in ["all", "any"]:
		if node.has(key):
			var children: Variant = node[key]
			if children is Array:
				for child in children:
					if child is Dictionary:
						_check_condition_recursive(child, owner, state)
			return
	if node.has("not"):
		if node["not"] is Dictionary:
			_check_condition_recursive(node["not"], owner, state)
		return
	var op := String(node.get("op", ""))
	if not ConditionOpRegistry.has(op):
		_error("condition_op_unknown", "%s uses unsupported condition op '%s'" % [owner, op], owner)
		return
	match op:
		"has_item":
			var item_id := String(node.get("item_id", ""))
			if not _item_exists(item_id):
				_error("condition_item_missing", "%s condition references unknown item %s" % [owner, item_id], owner)
		"has_module":
			var module_id := String(node.get("id", ""))
			if not _module_exists(module_id):
				_error("condition_module_missing", "%s condition references unknown module %s" % [owner, module_id], owner)
		"has_module_tag":
			var tag := String(node.get("tag", ""))
			if not _any_module_tag(tag):
				_warn("condition_module_tag_unused", "%s condition uses module tag '%s' not present in any module" % [owner, tag], owner)
		"has_role":
			var role_id := String(node.get("id", ""))
			var role_kind := String(node.get("role_kind", ""))
			if not role_id.is_empty() and _hub.get_by_id(ContentTypes.CREW_ROLE, role_id) == null:
				_error("condition_role_missing", "%s condition references unknown role %s" % [owner, role_id], owner)
			if role_id.is_empty() and role_kind.is_empty():
				_error("condition_role_empty", "%s has_role condition needs id or role_kind" % owner, owner)
		"contract_completed":
			var contract_id := String(node.get("id", ""))
			if not _hub.contains(ContentTypes.CONTRACT, contract_id):
				_error("condition_contract_missing", "%s condition references unknown contract %s" % [owner, contract_id], owner)
		"port_has_tag":
			var tag := String(node.get("tag", ""))
			if not _any_port_template_tag(tag):
				_warn("condition_port_tag_unused", "%s condition uses port tag '%s' not present in any archetype" % [owner, tag], owner)


func _check_effect(effect: Variant, owner: String) -> void:
	if not (effect is Dictionary):
		_error("effect_type", "%s effect must be an object" % owner, owner)
		return
	var op := String(effect.get("op", ""))
	if not EffectOpRegistry.has(op):
		_error("effect_op_unknown", "%s uses unsupported effect op '%s'" % [owner, op], owner)
		return
	match op:
		"add_item", "remove_item":
			var item_id := String(effect.get("item_id", effect.get("id", "")))
			if not _item_exists(item_id):
				_error("effect_item_missing", "%s effect references unknown item %s" % [owner, item_id], owner)
		"unlock_definition":
			var definition_id := String(effect.get("id", ""))
			if not _definition_exists(definition_id):
				_error("effect_unlock_missing", "%s effect unlocks missing definition %s" % [owner, definition_id], owner)
		"complete_contract":
			var contract_id := String(effect.get("contract_id", ""))
			if not contract_id.is_empty() and not _hub.contains(ContentTypes.CONTRACT, contract_id):
				_error("effect_contract_missing", "%s effect references unknown contract %s" % [owner, contract_id], owner)
		"emit_notice":
			if String(effect.get("text_key", "")).is_empty():
				_error("effect_notice_key", "%s emit_notice is missing text_key" % owner, owner)


func _check_port_templates() -> void:
	for archetype in _hub.get_all(ContentTypes.PORT_TEMPLATE):
		var facilities: Array = archetype.data.get("facilities", [])
		for required_facility in ["exchange", "contracts"]:
			if not facilities.has(required_facility):
				_error("port_facility_missing", "%s must offer '%s'" % [archetype.id, required_facility], archetype.id)
		for market_entry in archetype.data.get("market", []):
			if not (market_entry is Dictionary):
				continue
			var item_id := String(market_entry.get("good", ""))
			if not _item_exists(item_id):
				_error("port_market_missing", "%s market references unknown item %s" % [archetype.id, item_id], archetype.id)
		var tag_facility_pairs := {
			"port.shipyard": "shipyard",
			"port.intel": "tavern",
		}
		for tag in tag_facility_pairs.keys():
			if archetype.has_tag(tag) and not facilities.has(tag_facility_pairs[tag]):
				_warn("port_tag_facility", "%s has tag %s but no %s facility" % [archetype.id, tag, tag_facility_pairs[tag]], archetype.id)


func _check_world_profiles() -> void:
	for profile in _hub.get_all(ContentTypes.WORLD_PROFILE):
		var data: Dictionary = profile.data
		var weather_id := String(data.get("weather_profile", ""))
		if not weather_id.is_empty():
			_require(ContentTypes.WEATHER_PROFILE, weather_id, profile.id, "weather_profile")


func _check_regions() -> void:
	for region in _hub.get_all(ContentTypes.REGION):
		var data: Dictionary = region.data
		_require(ContentTypes.WEATHER_PROFILE, String(data.get("weather_profile", "")), region.id, "weather_profile")
		for faction_id in data.get("factions", []):
			_require(ContentTypes.FACTION, String(faction_id), region.id, "factions")


func _check_sites() -> void:
	for site in _hub.get_all(ContentTypes.SITE):
		var data: Dictionary = site.data
		for field in ["ruin_archetype", "encounter_table", "loot_table"]:
			_check_planned_ref(site.id, field, String(PLANNED_REF_TYPES[field]), String(data.get(field, "")))


func _check_route_templates() -> void:
	for route_template in _hub.get_all(ContentTypes.ROUTE_TEMPLATE):
		_check_planned_ref(
			route_template.id,
			"encounter_table",
			String(PLANNED_REF_TYPES["encounter_table"]),
			String(route_template.data.get("encounter_table", ""))
		)


func _check_weather_profiles() -> void:
	## weather_profiles is a leaf target type: §5.1 declares no outgoing references for it.
	## The method stays as the registration point so the 9 Phase B checks stay symmetric and a
	## future field addition has an obvious home.
	pass


func _check_factions() -> void:
	for faction in _hub.get_all(ContentTypes.FACTION):
		var data: Dictionary = faction.data
		for item_id in data.get("trade_goods", []):
			_require_item(String(item_id), faction.id, "trade_goods")
		for rival_id in data.get("rival_factions", []):
			var rival := String(rival_id)
			if rival == faction.id:
				_error("reference_self", "%s field 'rival_factions' references itself" % faction.id, faction.id)
			elif not _hub.contains(ContentTypes.FACTION, rival):
				_error(
					"reference_missing",
					"%s field 'rival_factions' references missing %s '%s'" % [faction.id, ContentTypes.FACTION, rival],
					faction.id
				)
		var contract_family := String(data.get("contract_family", ""))
		_check_planned_ref(
			faction.id,
			"contract_family",
			String(PLANNED_REF_TYPES["contract_family"]),
			contract_family
		)


func _check_discoveries() -> void:
	for discovery in _hub.get_all(ContentTypes.DISCOVERY):
		for unlock_id in discovery.data.get("unlock_ids", []):
			if not _definition_exists(String(unlock_id)):
				_error(
					"reference_missing",
					"%s field 'unlock_ids' references missing definition '%s'" % [discovery.id, unlock_id],
					discovery.id
				)


## C3: quest chain references + objective event format + objective `match` entity
## references (D6: never silent).
## `prerequisites.quests_completed[]` is a hard quest reference; `stages[].objectives[]`
## events must use the `cmd:` / `ui:` observation namespace the runtime forwards from
## StoryService/QuestService. Command-name existence stays out of scope (no enumerable
## runtime command registry is available to content validation; see header rationale).
## `match` keys listed in `QUEST_MATCH_REFERENCE_TYPES` are resolved against their
## runtime registry (missing id → `quest_match_ref_missing` with mod/file/entity/path);
## all other match keys are literal payload filters and intentionally skipped.
func _check_quests() -> void:
	var event_pattern := RegEx.new()
	event_pattern.compile("^(cmd|ui):[a-z][a-z0-9_.-]*$")
	for quest in _hub.get_all(ContentTypes.QUEST):
		var prerequisites: Variant = quest.data.get("prerequisites", null)
		if prerequisites is Dictionary:
			for required_quest_id in Array((prerequisites as Dictionary).get("quests_completed", [])):
				var required_id := String(required_quest_id)
				if not _hub.contains(ContentTypes.QUEST, required_id):
					_error(
						"quest_prerequisite_missing",
						"%s prerequisites reference missing quest '%s'" % [quest.id, required_id],
						quest.id
					)
		var stages: Variant = quest.data.get("stages", null)
		if not (stages is Array):
			continue
		for stage_index in (stages as Array).size():
			var raw_stage: Variant = (stages as Array)[stage_index]
			if not (raw_stage is Dictionary):
				continue
			var objectives: Variant = (raw_stage as Dictionary).get("objectives", null)
			if not (objectives is Array):
				continue
			for objective_index in (objectives as Array).size():
				var raw_objective: Variant = (objectives as Array)[objective_index]
				if not (raw_objective is Dictionary):
					continue
				var event_name := String((raw_objective as Dictionary).get("event", ""))
				if event_pattern.search(event_name) == null:
					_error(
						"quest_event_invalid",
						"%s objective event '%s' must look like cmd:<command> or ui:<event>" % [quest.id, event_name],
						quest.id
					)
				_check_quest_objective_match(quest, stage_index, raw_stage as Dictionary, objective_index, raw_objective as Dictionary)


## Validates entity references inside one objective's `match` block. Only known
## reference keys are resolved; literal filters (`category`, `kind`, ...) pass through.
func _check_quest_objective_match(
	quest: ContentDefinition,
	stage_index: int,
	stage: Dictionary,
	objective_index: int,
	objective: Dictionary
) -> void:
	var raw_match: Variant = objective.get("match", null)
	if not (raw_match is Dictionary):
		return
	var matched: Dictionary = raw_match
	for raw_key in matched.keys():
		var key := String(raw_key)
		if not QUEST_MATCH_REFERENCE_TYPES.has(key):
			continue
		var target_id := String(matched[raw_key])
		if target_id.is_empty():
			continue
		var content_type: StringName = QUEST_MATCH_REFERENCE_TYPES[key]
		if _hub.contains(content_type, target_id):
			continue
		var stage_id := String(stage.get("id", ""))
		errors.append({
			"code": "quest_match_ref_missing",
			"message": "%s (mod '%s', file '%s') stage '%s' objective[%d].match.%s references missing %s '%s'" % [
				quest.id, quest.source_mod, quest.source_file, stage_id, objective_index, key, content_type, target_id
			],
			"definition_id": quest.id,
			"mod": quest.source_mod,
			"file": quest.source_file,
			"entity": String(content_type),
			"path": "data.stages[%d].objectives[%d].match.%s" % [stage_index, objective_index, key],
		})


func _check_start_profiles() -> void:
	for start_profile in _hub.get_all(ContentTypes.START_PROFILE):
		var data: Dictionary = start_profile.data
		_require(ContentTypes.WORLD_PROFILE, String(data.get("world_profile", "")), start_profile.id, "world_profile")
		_require(ContentTypes.STARTING_SCENARIO, String(data.get("starting_scenario", "")), start_profile.id, "starting_scenario")
		var map_config_id := String(data.get("map_config", ""))
		if not map_config_id.is_empty():
			# Soft reference: third-party mods may omit it (runtime falls back to the core map config);
			# only an existing-but-unknown id is an error.
			_require(ContentTypes.MAP_CONFIG, map_config_id, start_profile.id, "map_config")
		var contract_id := String(data.get("starting_contract", ""))
		if not contract_id.is_empty():
			_require(ContentTypes.CONTRACT, contract_id, start_profile.id, "starting_contract")
		for cargo_stack in data.get("starting_cargo", []):
			if not (cargo_stack is Dictionary):
				continue
			_require_item(String(cargo_stack.get("item", "")), start_profile.id, "starting_cargo")


func _check_map_configs() -> void:
	for map_config in _hub.get_all(ContentTypes.MAP_CONFIG):
		var data: Dictionary = map_config.data
		var archetypes: Array = data.get("archetypes", [])
		for archetype_id in archetypes:
			_require(ContentTypes.PORT_TEMPLATE, String(archetype_id), map_config.id, "archetypes")
		# C4: map_profiles retired; its name-key / facility / npc checks moved here.
		var name_keys: Array = data.get("port_name_keys", [])
		if name_keys.size() < archetypes.size():
			_error(
				"map_name_keys",
				"%s declares %d port name keys for %d archetypes" % [map_config.id, name_keys.size(), archetypes.size()],
				map_config.id
			)
		for tag in data.get("required_facility_tags", []):
			if not _any_port_template_tag(String(tag)):
				_error(
					"map_facility_missing",
					"%s requires port tag '%s' not present in any port template" % [map_config.id, tag],
					map_config.id
				)
		var npc_range: Array = data.get("npc_count_range", [2, 3])
		if npc_range.size() >= 2 and (int(npc_range[0]) < 2 or int(npc_range[1]) > 3):
			_warn("map_npc_count", "%s NPC count range should stay within 2-3 for MVP" % map_config.id, map_config.id)
		var default_starting_scenario := String(data.get("default_starting_scenario", ""))
		if not default_starting_scenario.is_empty():
			_require(ContentTypes.STARTING_SCENARIO, default_starting_scenario, map_config.id, "default_starting_scenario")
		for start_profile in _hub.get_all(ContentTypes.START_PROFILE):
			if String(start_profile.data.get("map_config", "")) != map_config.id:
				continue
			var world_profile_id := String(start_profile.data.get("world_profile", ""))
			if world_profile_id.is_empty():
				continue
			var world_profile := _hub.get_by_id(ContentTypes.WORLD_PROFILE, world_profile_id)
			if world_profile == null:
				# Missing world_profile is reported by _check_start_profiles; nothing to compare here.
				continue
			var port_count := int(world_profile.data.get("port_count", 0))
			if archetypes.size() < port_count:
				_error(
					"map_config_archetype_count",
					"%s provides %d archetypes but world profile %s needs %d ports" % [
						map_config.id, archetypes.size(), world_profile_id, port_count
					],
					map_config.id
				)


func _require(content_type: StringName, definition_id: String, owner: String, field: String) -> ContentDefinition:
	var definition := _hub.get_by_id(content_type, definition_id)
	if definition == null:
		_error("reference_missing", "%s field '%s' references missing %s '%s'" % [owner, field, content_type, definition_id], owner)
	return definition


## `modules` definition behind an id, additionally checked against the category the
## declaring field expects (boiler / cargo / utility / cabin).
func _require_module(module_id: String, category: String, owner: String, field: String) -> ContentDefinition:
	var definition := _hub.get_by_id(ContentTypes.MODULE, module_id)
	if definition == null:
		_error(
			"reference_missing",
			"%s field '%s' references missing %s '%s'" % [owner, field, ContentTypes.MODULE, module_id],
			owner
		)
		return null
	var actual := String(definition.data.get("v2_category", ""))
	if actual != category:
		_error(
			"module_category_mismatch",
			"%s field '%s' expects a %s module but '%s' is %s" % [owner, field, category, module_id, actual],
			owner
		)
	return definition


func _item_exists(item_id: String) -> bool:
	return _hub.contains(ContentTypes.ITEM, item_id)


func _require_item(item_id: String, owner: String, field: String) -> void:
	if not _item_exists(item_id):
		_error("reference_missing", "%s field '%s' references missing item '%s'" % [owner, field, item_id], owner)


func _check_planned_ref(owner: String, field: String, target_type: String, target_id: String) -> void:
	if target_id.is_empty():
		return
	var content_type := StringName(target_type)
	if ContentTypes.is_known(content_type):
		# The target type was promoted to active: the soft warning auto-upgrades to a hard check.
		_require(content_type, target_id, owner, field)
		return
	_warn_inactive_type(owner, field, target_type)


func _warn_inactive_type(owner: String, field: String, target_type: String) -> void:
	_warn(
		"ref_inactive_type",
		"%s field '%s' references planned content type '%s' which has no runtime registry yet" % [
			owner, field, target_type
		],
		owner
	)


func _module_exists(module_id: String) -> bool:
	for content_type in ContentTypes.MODULE_TYPES:
		if _hub.contains(content_type, module_id):
			return true
	return false


func _definition_exists(definition_id: String) -> bool:
	for content_type in ContentTypes.all():
		if _hub.contains(content_type, definition_id):
			return true
	return false


func _any_port_template_tag(tag: String) -> bool:
	for archetype in _hub.get_all(ContentTypes.PORT_TEMPLATE):
		if archetype.has_tag(tag):
			return true
	return false


func _any_module_tag(tag: String) -> bool:
	for content_type in ContentTypes.MODULE_TYPES:
		for module in _hub.get_all(content_type):
			if module.has_tag(tag):
				return true
	return false


func _error(code: String, message: String, owner: String) -> void:
	errors.append({"code": code, "message": message, "definition_id": owner})


func _warn(code: String, message: String, owner: String) -> void:
	warnings.append({"code": code, "message": message, "definition_id": owner})
