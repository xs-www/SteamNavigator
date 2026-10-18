class_name CoreCompletenessChecker
extends RefCounted
## Verifies the official content pack provides everything the MVP needs.
##
## This is intentionally about presence and contracts, not balance.

static func check(hub: RegistryHub, packages: Dictionary, order: Array[String]) -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var core: Variant = packages.get("core", null)
	if not (core is ModPackage):
		errors.append({"code": "core_missing", "message": "official core mod is not loaded"})
		return {"errors": errors, "warnings": warnings}
	if not core.manifest.required:
		errors.append({"code": "core_not_required", "message": "core manifest must declare required=true"})
	if not order.has("core"):
		errors.append({"code": "core_not_enabled", "message": "core mod is not in the load order"})

	_require_count(hub, ContentTypes.GOOD, 1, "goods", errors)
	_require_count(hub, ContentTypes.HULL, 3, "hulls", errors)
	_require_count(hub, ContentTypes.BOILER, 2, "boilers", errors)
	_require_count(hub, ContentTypes.CARGO_MODULE, 1, "cargo modules", errors)
	_require_count(hub, ContentTypes.STRATEGY, 3, "boiler strategies", errors)
	_require_count(hub, ContentTypes.PORT_ARCHETYPE, 4, "port archetypes", errors)
	_require_count(hub, ContentTypes.MAP_PROFILE, 1, "map profiles", errors)
	_require_count(hub, ContentTypes.STARTING_BUILD, 1, "starting builds", errors)
	_require_count(hub, ContentTypes.CONTRACT, 5, "contracts", errors)
	_require_count(hub, ContentTypes.EVENT, 2, "events", errors)
	_require_count(hub, ContentTypes.ROLE, 2, "crew roles", errors)

	for required_tag in ["strategy.economy", "strategy.standard", "strategy.fast"]:
		if hub.query(ContentTypes.STRATEGY, [required_tag]).is_empty():
			errors.append({"code": "strategy_tag_missing", "message": "no strategy with tag '%s'" % required_tag})
	if hub.query(ContentTypes.HULL, ["module.large"]).is_empty():
		errors.append({"code": "large_hull_missing", "message": "no large hull is available for the finale reward"})
	if hub.query(ContentTypes.ROLE, ["role.engineer"]).is_empty():
		errors.append({"code": "engineer_missing", "message": "no engineer role is available"})
	if hub.query(ContentTypes.ROLE, ["role.navigator"]).is_empty():
		errors.append({"code": "navigator_missing", "message": "no navigator role is available"})
	if hub.query(ContentTypes.EVENT, ["event.risk"]).is_empty():
		errors.append({"code": "risk_events_missing", "message": "no voyage risk event is tagged event.risk"})

	var sequences: Dictionary = {}
	for contract in hub.get_all(ContentTypes.CONTRACT):
		if String(contract.data.get("kind", "")) == "main":
			sequences[int(contract.data.get("sequence", 0))] = contract.id
	for sequence in range(1, 6):
		if not sequences.has(sequence):
			errors.append({"code": "main_sequence_missing", "message": "main contract sequence %d is missing" % sequence})

	var ships: Array = []
	for build in hub.get_all(ContentTypes.STARTING_BUILD):
		var hull := hub.get_by_id(ContentTypes.HULL, String(build.data.get("hull", "")))
		var boiler := hub.get_by_id(ContentTypes.BOILER, String(build.data.get("boiler", "")))
		var cargo_modules: Array = build.data.get("cargo_modules", [])
		var has_cargo := false
		for module_id in cargo_modules:
			if hub.contains(ContentTypes.CARGO_MODULE, String(module_id)):
				has_cargo = true
		if hull != null and boiler != null and has_cargo:
			ships.append(build.id)
		else:
			warnings.append({
				"code": "starting_build_incomplete",
				"message": "starting build '%s' does not resolve to hull + boiler + cargo" % build.id,
			})
	if ships.is_empty():
		errors.append({"code": "no_runnable_starting_build", "message": "no starting build resolves to a runnable ship"})

	for content_type in ContentTypes.MODULE_TYPES:
		for module in hub.get_all(content_type):
			if int(module.data.get("tier", 0)) > 3:
				warnings.append({
					"code": "tier_out_of_range",
					"message": "%s has tier %d; MVP expects 1-3" % [module.id, int(module.data.get("tier", 0))],
				})

	return {"errors": errors, "warnings": warnings}


static func _require_count(hub: RegistryHub, content_type: StringName, minimum: int, label: String, errors: Array[Dictionary]) -> void:
	if hub.get_all(content_type).size() < minimum:
		errors.append({
			"code": "content_count",
			"message": "core must declare at least %d %s (found %d)" % [
				minimum, label, hub.get_all(content_type).size()
			],
		})
