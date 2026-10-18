class_name RunFactory
extends RefCounted
## Creates a fresh run from a starting build and a map profile.
##
## The framework never names concrete `core:*` IDs. It picks the first
## registered starting build / map profile / contract by type and data rules.


static func default_build(hub: RegistryHub) -> ContentDefinition:
	var builds := hub.get_all(ContentTypes.STARTING_BUILD)
	return builds[0] if not builds.is_empty() else null


static func available_builds(hub: RegistryHub) -> Array[ContentDefinition]:
	return hub.get_all(ContentTypes.STARTING_BUILD)


static func default_map_profile(hub: RegistryHub) -> ContentDefinition:
	var profiles := hub.get_all(ContentTypes.MAP_PROFILE)
	return profiles[0] if not profiles.is_empty() else null


static func create_ship(hub: RegistryHub, build: ContentDefinition) -> Dictionary:
	var data: Dictionary = build.data
	var hull_id := String(data.get("hull", ""))
	var hull := hub.get_by_id(ContentTypes.HULL, hull_id)
	var max_durability := float(hull.data.get("max_durability", 100.0)) if hull != null else 100.0
	var ratio := float(data.get("durability_ratio", 1.0))
	var ship := {
		"hull_id": hull_id,
		"boiler_id": String(data.get("boiler", "")),
		"cargo_modules": Array(data.get("cargo_modules", [])),
		"navigation_module_id": String(data.get("navigation_module", "")),
		"safety_module_id": String(data.get("safety_module", "")),
		"passenger_cabin_id": String(data.get("passenger_cabin", "")),
		"engineer_id": String(data.get("engineer", "")),
		"navigator_id": String(data.get("navigator", "")),
		"durability": max_durability * clampf(ratio, 0.1, 1.0),
		"coal": float(data.get("coal", 0.0)),
		"water": float(data.get("water", 0.0)),
		"cargo": [],
	}
	return ship


static func create_run(context, build_id: String = "", requested_seed: int = 0) -> Dictionary:
	var hub: RegistryHub = context.registries
	var build: ContentDefinition = null
	if not build_id.is_empty():
		build = hub.get_by_id(ContentTypes.STARTING_BUILD, build_id)
	if build == null:
		build = default_build(hub)
	if build == null:
		return Result.fail("no_starting_build", "ui.error.no_starting_build")
	var profile := default_map_profile(hub)
	if profile == null:
		return Result.fail("no_map_profile", "ui.error.no_map_profile")
	var seed_value := requested_seed if requested_seed != 0 else _random_seed()
	var rng := RngService.new(seed_value)

	var ship := create_ship(hub, build)
	var validation := ShipOps.validate_configuration(hub, ship)
	if not bool(validation["ok"]):
		return Result.fail("invalid_starting_build", "ui.error.invalid_starting_build", {"errors": validation["errors"]})

	var map_result := MapGenerator.generate(profile, hub, rng, ship)
	if not bool(map_result["ok"]):
		return Result.fail("map_generation_failed", "ui.error.map_generation_failed", {"reason": map_result.get("reason", "")})
	var world: Dictionary = map_result["world"]

	var build_data: Dictionary = build.data
	var player := {
		"money": int(build_data.get("money", 0)),
		"reputation": int(build_data.get("reputation", 0)),
		"unlocks": [],
		"debt": null,
	}
	if build_data.get("loan", null) is Dictionary:
		var loan: Dictionary = build_data["loan"]
		var principal := float(loan.get("principal", 0.0))
		player["debt"] = {
			"principal": principal,
			"interest_rate": float(loan.get("interest_rate", 0.1)),
			"remaining": principal * (1.0 + float(loan.get("interest_rate", 0.1))),
			"borrowed_at": 0.0,
			"due_time": float(loan.get("term_hours", 96.0)),
			"overdue": false,
		}
	var state := GameState.new()
	state.data = {
		"schema_version": GameState.SCHEMA_VERSION,
		"run": {
			"seed": seed_value,
			"game_time": 0.0,
			"started_at": Time.get_datetime_string_from_system(true),
			"starting_build": build.id,
			"map_profile": profile.id,
		},
		"player": player,
		"world": world,
		"ship": ship,
		"contracts": {},
		"market": {},
		"npcs": [],
		"intelligence": {},
		"notices": [],
		"stats": {"voyages": 0, "on_time": 0, "accidents": 0, "profit": 0},
	}
	ContractOps.ensure_structure(state)
	_initialize_markets(state, hub, profile, rng)
	state.data["npcs"] = NpcTraderSimulator.create_initial(state, hub, rng, profile.data)

	var main_offer := _generate_main_offer(state, hub, 1, rng)
	if not main_offer.is_empty():
		state.data["contracts"]["main_offer"] = main_offer
		var accepted := ContractOps.accept_offer(state, hub, String(main_offer.get("instance_id", "")))
		if not bool(accepted["ok"]):
			return Result.fail("main_contract_unsatisfiable", "ui.error.main_contract_unsatisfiable", {
				"error_code": accepted.get("error_code", ""),
				"build_id": build.id,
			})
	else:
		return Result.fail("no_main_contract", "ui.error.no_main_contract", {"sequence": 1})

	_generate_normal_offers(state, hub, rng)
	state.push_notice("ui.notice.run_started", {"build": build.name_key})
	return Result.ok({
		"state": state,
		"rng": rng,
		"build": build,
		"profile": profile,
		"seed": seed_value,
	})


static func _initialize_markets(state: GameState, hub: RegistryHub, profile: ContentDefinition, rng: RngService) -> void:
	var markets := {}
	var ports: Dictionary = state.world().get("ports", {})
	for raw_port_id in ports.keys():
		var port_id := String(raw_port_id)
		var port_data: Dictionary = ports[port_id]
		var archetype := hub.get_by_id(ContentTypes.PORT_ARCHETYPE, String(port_data.get("archetype_id", "")))
		if archetype == null:
			continue
		var port_rng := rng.stream(RngService.STREAM_GOODS_GENERATION, port_id)
		markets[port_id] = MarketOps.initialize_port_market(hub, archetype, port_rng)
	state.data["market"] = markets


static func _generate_main_offer(state: GameState, hub: RegistryHub, sequence: int, rng: RngService) -> Dictionary:
	var template := ContractOps.find_template_by_sequence(hub, sequence)
	if template == null:
		return {}
	return ContractOps.generate_offer(state, hub, template, rng, state.current_port_id())


static func _generate_normal_offers(state: GameState, hub: RegistryHub, rng: RngService) -> void:
	var templates := ContractOps.templates_by_kind(hub, "normal")
	if templates.is_empty():
		return
	var candidates: Array = []
	for template in templates:
		candidates.append({"template": template, "weight": 1.0})
	var offer_rng := rng.stream(RngService.STREAM_CONTRACT_GENERATION, "normal_offers")
	var wanted := mini(3, templates.size())
	var offers: Array = []
	for _index in wanted:
		if candidates.is_empty():
			break
		var picked: Variant = RngService.choose_weighted(offer_rng, candidates)
		if not (picked is Dictionary):
			break
		var template: ContentDefinition = picked["template"]
		candidates.erase(picked)
		var offer := ContractOps.generate_offer(state, hub, template, rng, state.current_port_id())
		if not offer.is_empty():
			offers.append(offer)
	state.data["contracts"]["offers"] = offers


static func _random_seed() -> int:
	return int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())


static func starting_build_summaries(hub: RegistryHub) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for build in available_builds(hub):
		result.append({
			"id": build.id,
			"name_key": build.name_key,
			"description_key": build.description_key,
			"money": int(build.data.get("money", 0)),
			"hull": String(build.data.get("hull", "")),
			"boiler": String(build.data.get("boiler", "")),
			"coal": float(build.data.get("coal", 0.0)),
			"water": float(build.data.get("water", 0.0)),
		})
	return result
