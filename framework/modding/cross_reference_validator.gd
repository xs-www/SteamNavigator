class_name CrossReferenceValidator
extends RefCounted
## Validates references between content definitions after patches are applied.
##
## Schema validation guarantees shape; this pass guarantees meaning.

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []

var _hub: RegistryHub = null


func validate(hub: RegistryHub) -> Dictionary:
	errors.clear()
	warnings.clear()
	_hub = hub
	_check_modules()
	_check_starting_builds()
	_check_contracts()
	_check_events()
	_check_port_archetypes()
	_check_map_profiles()
	return {
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
	}


func _check_modules() -> void:
	for content_type in ContentTypes.MODULE_TYPES:
		for definition in _hub.get_all(content_type):
			for material in definition.data.get("materials", []):
				if not (material is Dictionary):
					continue
				var item_id := String(material.get("id", ""))
				if not _item_exists(item_id):
					_error("material_missing", "%s references missing material %s" % [definition.id, item_id], definition.id)
			for modifier in definition.data.get("modifiers", []):
				if modifier is Dictionary and not ["speed", "coal_rate", "water_rate", "risk", "repair_cost", "damage"].has(String(modifier.get("stat", ""))):
					_warn("modifier_unknown_stat", "%s has an unrecognised modifier stat '%s'" % [definition.id, modifier.get("stat", "")], definition.id)


func _check_starting_builds() -> void:
	for build in _hub.get_all(ContentTypes.STARTING_BUILD):
		var hull := _require(ContentTypes.HULL, String(build.data.get("hull", "")), build.id, "hull")
		_require(ContentTypes.BOILER, String(build.data.get("boiler", "")), build.id, "boiler")
		var cargo_modules: Array = build.data.get("cargo_modules", [])
		for module_id in cargo_modules:
			_require(ContentTypes.CARGO_MODULE, String(module_id), build.id, "cargo_modules")
		if not String(build.data.get("navigation_module", "")).is_empty():
			_require(ContentTypes.NAVIGATION_MODULE, String(build.data.get("navigation_module")), build.id, "navigation_module")
		if not String(build.data.get("safety_module", "")).is_empty():
			_require(ContentTypes.SAFETY_MODULE, String(build.data.get("safety_module")), build.id, "safety_module")
		if not String(build.data.get("passenger_cabin", "")).is_empty():
			_require(ContentTypes.CABIN, String(build.data.get("passenger_cabin")), build.id, "passenger_cabin")
		_check_role(build, "engineer", "engineer")
		_check_role(build, "navigator", "navigator")
		if hull != null:
			if cargo_modules.size() > int(hull.data.get("cargo_slots", 0)):
				_error(
					"starting_build_slots",
					"%s has %d cargo modules but hull only allows %d" % [
						build.id, cargo_modules.size(), int(hull.data.get("cargo_slots", 0))
					],
					build.id
				)
			if not String(build.data.get("passenger_cabin", "")).is_empty() and int(hull.data.get("cabin_slots", 0)) < 1:
				_error("starting_build_cabin", "%s has a cabin but hull has no cabin slot" % build.id, build.id)


func _check_role(build: ContentDefinition, field: String, expected_kind: String) -> void:
	var role_id := String(build.data.get(field, ""))
	if role_id.is_empty():
		return
	var role := _hub.get_by_id(ContentTypes.ROLE, role_id)
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
			if not _any_archetype_tag(String(tag)):
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
	for event in _hub.get_all(ContentTypes.EVENT):
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
			if not role_id.is_empty() and _hub.get_by_id(ContentTypes.ROLE, role_id) == null:
				_error("condition_role_missing", "%s condition references unknown role %s" % [owner, role_id], owner)
			if role_id.is_empty() and role_kind.is_empty():
				_error("condition_role_empty", "%s has_role condition needs id or role_kind" % owner, owner)
		"contract_completed":
			var contract_id := String(node.get("id", ""))
			if not _hub.contains(ContentTypes.CONTRACT, contract_id):
				_error("condition_contract_missing", "%s condition references unknown contract %s" % [owner, contract_id], owner)
		"port_has_tag":
			var tag := String(node.get("tag", ""))
			if not _any_archetype_tag(tag):
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


func _check_port_archetypes() -> void:
	for archetype in _hub.get_all(ContentTypes.PORT_ARCHETYPE):
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
			"port.intel": "intel",
		}
		for tag in tag_facility_pairs.keys():
			if archetype.has_tag(tag) and not facilities.has(tag_facility_pairs[tag]):
				_warn("port_tag_facility", "%s has tag %s but no %s facility" % [archetype.id, tag, tag_facility_pairs[tag]], archetype.id)


func _check_map_profiles() -> void:
	for profile in _hub.get_all(ContentTypes.MAP_PROFILE):
		var data: Dictionary = profile.data
		var archetypes: Array = data.get("archetypes", [])
		for archetype_id in archetypes:
			if _hub.get_by_id(ContentTypes.PORT_ARCHETYPE, String(archetype_id)) == null:
				_error("map_archetype_missing", "%s references missing archetype %s" % [profile.id, archetype_id], profile.id)
		var port_count_range: Array = data.get("port_count_range", [4, 5])
		var maximum_ports := int(port_count_range[1]) if port_count_range.size() > 1 else int(port_count_range[0])
		if archetypes.size() < maximum_ports:
			_error("map_archetype_count", "%s needs at least %d archetypes" % [profile.id, maximum_ports], profile.id)
		var name_keys: Array = data.get("port_name_keys", [])
		if name_keys.size() < maximum_ports:
			_error("map_name_keys", "%s needs at least %d port name keys" % [profile.id, maximum_ports], profile.id)
		for tag in data.get("required_facility_tags", []):
			if not _any_archetype_tag(String(tag)):
				_error("map_facility_missing", "%s requires port tag '%s' not present in any archetype" % [profile.id, tag], profile.id)
		var default_build := String(data.get("default_starting_build", ""))
		if not default_build.is_empty() and _hub.get_by_id(ContentTypes.STARTING_BUILD, default_build) == null:
			_error("map_default_build", "%s references missing starting build %s" % [profile.id, default_build], profile.id)
		var npc_range: Array = data.get("npc_count_range", [2, 3])
		if int(npc_range[0]) < 2 or int(npc_range[1]) > 3:
			_warn("map_npc_count", "%s NPC count range should stay within 2-3 for MVP" % profile.id, profile.id)


func _require(content_type: StringName, definition_id: String, owner: String, field: String) -> ContentDefinition:
	var definition := _hub.get_by_id(content_type, definition_id)
	if definition == null:
		_error("reference_missing", "%s field '%s' references missing %s '%s'" % [owner, field, content_type, definition_id], owner)
	return definition


func _item_exists(item_id: String) -> bool:
	return _hub.contains(ContentTypes.GOOD, item_id) or _hub.contains(ContentTypes.MATERIAL, item_id)


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


func _any_archetype_tag(tag: String) -> bool:
	for archetype in _hub.get_all(ContentTypes.PORT_ARCHETYPE):
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
