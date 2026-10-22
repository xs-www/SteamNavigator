class_name RunFactory
extends RefCounted
## Creates a fresh run from a starting build and a map profile.
##
## The framework never names concrete `core:*` IDs. It picks the first
## registered starting build / map profile / contract by type and data rules.
##
## After the abstract map, `create_run` also generates a coordinate-space twin
## world (`state.data["world_map"]`) from `_coordinate_world_profile()`: one
## landmass per port, port i on landmass i, so the twin keeps the abstract
## map's port ids (`port_0..N`), archetypes and names. The nautical chart reads
## it via `sea_chart.view`; twin generation failure only degrades the chart to
## its "no data" hint and never fails the run. `_initialize_world_fog()` seeds
## the persistent fog (coastal band + start-port lamp flower + ship vision).
##
## Stage 4.3 (U1): the twin world size comes from the map profile's
## `twin_world_size` (Core content) instead of a hardcoded 160, and the
## hand-authored 160-unit layout is scaled uniformly to it. Fog radii are
## `min(bounds.w, bounds.h) × Core ratio` via `ExplorationRules.fog_radii()`,
## so the fog-to-world proportion no longer depends on the world size.


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
	ShipModules.ensure(ship)
	return ship


static func create_run(context, build_id: String = "", requested_seed: int = 0, tutorial: bool = false) -> Dictionary:
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
		"campaign": {
			"id": "campaign_%d" % seed_value,
			"name": "Steam Navigator",
			"created_at": Time.get_datetime_string_from_system(true),
			"difficulty": "standard",
			"status": "active",
			"playtime_hours": 0.0,
		},
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
		"port_memory": {},
		"npcs": [],
		"intelligence": {},
		"notices": [],
		"stats": GameState.STATS_DEFAULTS.duplicate(true),
		"victory": null,
	}
	state.ensure_campaign()
	var setup: Dictionary = state.campaign_setup()
	if (setup.get("content_versions", {}) as Dictionary).is_empty():
		# D3: every new run snapshots the per-type content schema versions, so a
		# later load can report drift without guessing. 1.0 runs snapshot 1.0.
		setup["content_versions"] = ContentTypes.SCHEMA_VERSIONS.duplicate(true)
	var world_progress := state.campaign_world()
	world_progress["generated"] = true
	var starting_port_id := state.current_port_id()
	if not starting_port_id.is_empty():
		WorldOps.set_current_port(state, starting_port_id)
		WorldOps.discover_port_id(state, starting_port_id)
		state.mark_port_visited(starting_port_id)
	# Coordinate-space twin of the abstract map, keyed by the same port ids
	# (port_0..N), so `sea_chart.view`, discovery progress and fog stay coherent
	# with the map that is actually played. Generation failure only degrades the
	# nautical chart to its "no data" hint — it never fails the run.
	var world_map_result := WorldGenerator.generate(_coordinate_world_profile(world, profile), hub, rng, ship)
	if bool(world_map_result.get("ok", false)):
		state.data["world_map"] = world_map_result["world_map"]
		_initialize_world_fog(state, starting_port_id, hub)
	ContractOps.ensure_structure(state)
	WarehouseOps.ensure_structure(state)
	initialize_markets(state, hub, profile, rng)
	MarketMemoryService.remember(state, state.current_port_id())
	state.data["npcs"] = NpcTraderSimulator.create_initial(state, hub, rng, profile.data)

	# 4.5.2：教程局不自动接旧主线 main_01，由 Core story 的
	# `grant_tutorial_contract` 效果创建「燃料舱运煤」教学委托（内容化）。
	if not tutorial:
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

	ContractOps.generate_normal_offers(state, hub, rng, "initial:%s" % state.current_port_id())
	state.push_notice("ui.notice.run_started", {"build": build.name_key})
	if tutorial:
		# Stage 4.5: new runs start with the Core-authored story flow enabled (or
		# completed when the profile has no story), before the first UI rebuild.
		StoryService.begin(state, hub, rng)
	# C3: `auto_start` content quests are picked up at the end of run initialisation
	# (idempotent, content-driven; core ships the first-voyage guide here).
	QuestService.auto_start_state(state, hub)
	return Result.ok({
		"state": state,
		"rng": rng,
		"build": build,
		"profile": profile,
		"seed": seed_value,
		"tutorial": tutorial,
	})


## Builds the coordinate-world profile from the generated abstract map: one
## compact landmass per port, port i placed on landmass i, so the twin world
## keeps the same port ids (`port_0..N`) and the same archetype/name per id.
## The twin's connectivity is its own MST chart graph — voyage routing still
## follows the abstract map until the voyage演出 unifies the two worlds.
##
## The layout below is authored in a 160-unit world. `twin_world_size` (Core
## `map_profiles.data`) scales every centre/radius uniformly, so the same chart
## composition works at any world size (and the fog ratio stays meaningful).
static func _coordinate_world_profile(mvp_world: Dictionary, profile: ContentDefinition) -> Dictionary:
	var world_size := clampf(float(profile.data.get("twin_world_size", 160.0)), 64.0, 1024.0)
	var layout := [
		{"id": "twin_continent", "region_id": "start_coast", "archetype": "continent", "cx": 44.0, "cy": 82.0, "rx": 19.0, "ry": 30.0},
		{"id": "twin_island_east", "region_id": "start_coast", "archetype": "large_island", "cx": 108.0, "cy": 46.0, "rx": 15.0, "ry": 11.0},
		{"id": "twin_island_south", "region_id": "start_coast", "archetype": "large_island", "cx": 104.0, "cy": 118.0, "rx": 13.0, "ry": 10.0},
		{"id": "twin_islet_north", "region_id": "ocean_1", "archetype": "small_island", "cx": 66.0, "cy": 20.0, "rx": 7.0, "ry": 5.0},
		{"id": "twin_islet_west", "region_id": "ocean_1", "archetype": "small_island", "cx": 18.0, "cy": 132.0, "rx": 6.0, "ry": 4.5},
	]
	var layout_scale := world_size / 160.0
	for land_def in layout:
		for key in ["cx", "cy", "rx", "ry"]:
			(land_def as Dictionary)[key] = float((land_def as Dictionary)[key]) * layout_scale
	var ports: Dictionary = mvp_world.get("ports", {})
	var ids: Array = ports.keys()
	ids.sort_custom(func(a, b) -> bool:
		return String(a).trim_prefix("port_").to_int() < String(b).trim_prefix("port_").to_int()
	)
	var port_defs: Array = []
	for i in ids.size():
		var port_data: Dictionary = ports[ids[i]]
		var land: Dictionary = layout[mini(i, layout.size() - 1)]
		port_defs.append({
			"landmass_id": String(land["id"]),
			"coast_t": clampf(0.3 + 0.15 * float(i), 0.0, 1.0),
			"archetype_id": String(port_data.get("archetype_id", "")),
			"name_key": String(port_data.get("name_key", "")),
			"is_start": i == 0,
		})
	return {
		"world_size": world_size,
		"min_ports": ids.size(),
		"max_land_coverage": 0.45,
		"required_facility_tags": ["port.shipyard", "port.intel"],
		"required_facility_max_edges": 2,
		"regions": [
			{"id": "start_coast", "name_key": "world.region.start_coast", "tier": "coastal"},
			{"id": "ocean_1", "name_key": "world.region.ocean_1", "tier": "oceanic"},
		],
		"landmasses": layout.slice(0, maxi(1, mini(ids.size(), layout.size()))),
		"ports": port_defs,
	}


## Seeds the twin world's fog: coastal band marked, the starting harbour
## revealed (lamp flower) and ship vision applied at the berth. Radii follow the
## content fog ratios (`ExplorationRules.fog_radii`), not fixed world units.
static func _initialize_world_fog(state: GameState, start_port_id: String, hub: RegistryHub) -> void:
	var world := WorldOps.world_map(state)
	var start_port := world.get_port(start_port_id)
	if start_port.is_empty():
		return
	var radii := ExplorationRules.fog_radii(state, hub, world)
	var vision_radius := float(radii.get("vision", FogOps.DEFAULT_MIN_VISION_RADIUS))
	var reveal_radius := float(radii.get("port_reveal", FogOps.DEFAULT_PORT_REVEAL_RADIUS))
	var fog := FogOps.create_fog_grid(world, vision_radius)
	var coastal := FogOps.mark_coastal_cells(fog, world)
	FogOps.reveal_port(fog, start_port, reveal_radius)
	FogOps.update_ship_vision(fog, start_port.position, vision_radius, coastal)
	FogOps.save_fog_state(state, fog, coastal)


## Initializes every port market from the generated world's port archetypes.
## Shared by the 1.0 path (`create_run`, scenario = the `map_profiles` definition)
## and the v2 campaign path (`CampaignFactory`, scenario = the `map_configs`
## definition). Market pricing only depends on the port archetype + RNG, so both
## paths produce the same markets for the same generation seed; `scenario` is
## accepted now so a future per-scenario market tweak has one entry point.
static func initialize_markets(state: GameState, hub: RegistryHub, _scenario: ContentDefinition, rng: RngService) -> void:
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


## Backwards-compatible alias for the pre-B3 private name.
static func _initialize_markets(state: GameState, hub: RegistryHub, profile: ContentDefinition, rng: RngService) -> void:
	initialize_markets(state, hub, profile, rng)


static func _generate_main_offer(state: GameState, hub: RegistryHub, sequence: int, rng: RngService) -> Dictionary:
	var template := ContractOps.find_template_by_sequence(hub, sequence)
	if template == null:
		return {}
	return ContractOps.generate_offer(state, hub, template, rng, state.current_port_id())


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
