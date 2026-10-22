class_name CampaignFactory
extends RefCounted
## @static-doc
## 作用：v2 战役开局装配（WORLD_SCHEMA_V2_RUNTIME §6.2）。从 `start_profiles` 定义解析
## 世界构成 / 场景调参 / 起始构筑，复用 `MapGenerator` 生成抽象海图、`WorldGenerator`
## 生成孪生坐标世界，再用 Region/Site/Route/Faction/Discovery 装配器把 2.0 世界内容实例化
## 进 `GameState`。返回与 `RunFactory.create_run` 同形的结果包，供 `run.start` 直接替换状态。
##
## ## 契约与约束
## - **入口**：`create_campaign(context, start_profile_id, requested_seed=0, tutorial=false)`。
##   仅由 `run.start` 显式携带 `start_profile` 时调用；1.0 路径完全不经过本类。
## - **返回**：`Result.ok({state, rng, start_profile, world_profile, map_config, seed})`；
##   失败使用 `Result.fail(error_code, message_key, data)`，与 RunFactory 同形。
## - **状态形状**（§6.3）：
##   `data.run = {seed, game_time, started_at, starting_build, map_profile_id:""}`；
##   `data.campaign.setup = {start_profile_id, world_profile_id, map_config_id,
##   starting_build_id, difficulty, seed, content_versions}`；
##   `state.world` = MapGenerator 世界 + `start_profile_id / world_profile_id /
##   map_config_id`（`map_profile_id` 显式留空）；
##   `data.campaign.world = {profile_id, generated, regions[], sites[],
##   visited_region_ids, discovered_site_ids, visited_port_ids}`；
##   `data.campaign.codex / factions` 由装配器写入；`data.world_map` 为孪生海图世界。
## - **复用而非复制**：飞船用 `RunFactory.create_ship`；市场/补给/贷款参数入口
##   `RunFactory.initialize_markets`；孪生世界与迷雾用 `RunFactory._coordinate_world_profile`
##   / `_initialize_world_fog`；主线与普通委托沿用 `ContractOps` 与 RunFactory 的私有 helper。
##   tutorial=true 时最后调用 `StoryService.begin`（StoryService 走 `ContentRefs` 读
##   `map_configs.story`）。
## - **确定性**（§6.4）：几何用 `STREAM_MAP_GENERATION`；新增内容全部用
##   `STREAM_CAMPAIGN_WORLD` 的 `"regions"/"sites"/"routes"/"factions"/"discoveries"`
##   子流；注册表结果在抽取前按 id 排序。同 seed + 同内容 = 同世界实例。
## - **D8**：本切片 `port_count` 上限 5（`MapGenerationSpec` clamp + warning）。
## - 本类不发领域事件（`run.started` 由 run_start 负责），不写 autosave。
## @end-static-doc

const DEFAULT_DIFFICULTY := "standard"


## Creates a full v2 campaign state. Returns a `Result` envelope.
static func create_campaign(
	context,
	start_profile_id: String,
	requested_seed: int = 0,
	tutorial: bool = false
) -> Dictionary:
	var hub: RegistryHub = context.registries
	var start_profile := _resolve_definition(hub, ContentTypes.START_PROFILE, start_profile_id)
	if start_profile == null:
		return Result.fail("no_start_profile", "ui.error.no_start_profile", {"start_profile_id": start_profile_id})

	var world_profile_id := String(start_profile.data.get("world_profile", ""))
	var world_profile := _resolve_definition(hub, ContentTypes.WORLD_PROFILE, world_profile_id)
	if world_profile == null:
		return Result.fail("no_world_profile", "ui.error.no_world_profile", {
			"start_profile_id": start_profile.id,
			"world_profile_id": world_profile_id,
		})

	var map_config_choice := _resolve_map_config(hub, start_profile.data)
	if not bool(map_config_choice.get("ok", false)):
		return map_config_choice["failure"]
	var map_config: ContentDefinition = map_config_choice["definition"]
	if bool(map_config_choice.get("fallback", false)):
		push_warning(
			"campaign: start profile '%s' has no map_config; fell back to '%s'"
			% [start_profile.id, map_config.id]
		)

	var starting_build_id := String(start_profile.data.get("starting_build", ""))
	var build := _resolve_definition(hub, ContentTypes.STARTING_BUILD, starting_build_id)
	if build == null:
		return Result.fail("no_starting_build", "ui.error.no_starting_build", {
			"start_profile_id": start_profile.id,
			"starting_build_id": starting_build_id,
		})

	var seed_value := requested_seed if requested_seed != 0 else RunFactory._random_seed()
	var rng := RngService.new(seed_value)

	var ship := RunFactory.create_ship(hub, build)
	var ship_validation := ShipOps.validate_configuration(hub, ship)
	if not bool(ship_validation.get("ok", false)):
		return Result.fail("invalid_starting_build", "ui.error.invalid_starting_build", {
			"errors": ship_validation.get("errors", []),
		})

	# 1) Abstract map geometry: v2 world profile + map config adapted to the 1.0
	#    generator input shape (old MapGenerator.generate is untouched).
	var spec := MapGenerationSpec.build(
		world_profile, map_config, _sorted_definitions(hub.get_all(ContentTypes.ROUTE_TEMPLATE)), start_profile
	)
	var map_result := MapGenerator.generate_spec(spec, hub, rng, ship)
	if not bool(map_result.get("ok", false)):
		return Result.fail("map_generation_failed", "ui.error.map_generation_failed", {
			"reason": String(map_result.get("reason", "")),
		})
	var world: Dictionary = map_result["world"]

	# 2) State skeleton + campaign identity. The ids go in before any service
	#    reads the scenario through ContentRefs (markets / story / exploration).
	var state := _create_state(build, ship, world, seed_value, start_profile, world_profile, map_config)
	var campaign := state.campaign()
	var campaign_world := state.campaign_world()
	var starting_port_id := state.current_port_id()
	if not starting_port_id.is_empty():
		WorldOps.set_current_port(state, starting_port_id)
		WorldOps.discover_port_id(state, starting_port_id)
		state.mark_port_visited(starting_port_id)

	# 3) Regions: one instance per region_count, starting region from start tags.
	var region_definitions := _sorted_definitions(hub.get_all(ContentTypes.REGION))
	var region_result := RegionAssembler.assemble(
		world_profile, world, region_definitions, rng.stream(RngService.STREAM_CAMPAIGN_WORLD, "regions")
	)
	var regions: Array = region_result["regions"]
	var region_for_port: Dictionary = region_result["region_for_port"]
	campaign_world["regions"] = regions
	if regions.is_empty():
		return Result.fail("no_regions", "ui.error.no_regions", {"world_profile_id": world_profile.id})
	var starting_region_id := String(region_for_port.get(starting_port_id, ""))
	if not starting_region_id.is_empty():
		state.mark_region_visited(starting_region_id)

	# 4) Sites: sites_per_region instances per region, back-referenced from regions.
	var site_definitions := _sorted_definitions(hub.get_all(ContentTypes.SITE))
	var sites := SiteAssembler.assemble(
		world_profile, regions, site_definitions, rng.stream(RngService.STREAM_CAMPAIGN_WORLD, "sites")
	)

	# 5) Routes: one template per abstract edge, filtered by both endpoint regions.
	var route_definitions := _sorted_definitions(hub.get_all(ContentTypes.ROUTE_TEMPLATE))
	world["routes"] = RouteAssembler.assemble(
		Array(world.get("routes", [])),
		regions,
		region_for_port,
		route_definitions,
		rng.stream(RngService.STREAM_CAMPAIGN_WORLD, "routes")
	)

	# 6) Factions: up to faction_count instances with content-seeded reputation.
	campaign["factions"] = FactionAssembler.assemble(
		world_profile,
		start_profile,
		_sorted_definitions(hub.get_all(ContentTypes.FACTION)),
		rng.stream(RngService.STREAM_CAMPAIGN_WORLD, "factions")
	)

	# 7) Discoveries / codex: candidates per site + initial codex source map.
	var discovery_result := DiscoveryAssembler.assemble(
		_sorted_definitions(hub.get_all(ContentTypes.DISCOVERY)),
		sites,
		regions,
		_definitions_by_id(site_definitions),
		_definitions_by_id(region_definitions),
		rng.stream(RngService.STREAM_CAMPAIGN_WORLD, "discoveries")
	)
	sites = discovery_result["sites"]
	campaign_world["sites"] = sites
	campaign["codex"] = discovery_result["codex"]

	# 8) Coordinate twin world + fog: same 5-landmass layout and id space as the
	#    playable abstract map, so the chart / fog / exploration stay coherent.
	_generate_twin_world(state, world, map_config, hub, rng, ship, starting_port_id)

	# 9) Economy / contracts / notices, mirroring RunFactory.create_run.
	ContractOps.ensure_structure(state)
	WarehouseOps.ensure_structure(state)
	RunFactory.initialize_markets(state, hub, map_config, rng)
	MarketMemoryService.remember(state, state.current_port_id())
	state.data["npcs"] = NpcTraderSimulator.create_initial(state, hub, rng, map_config.data)

	if not tutorial:
		var main_offer := RunFactory._generate_main_offer(state, hub, 1, rng)
		if main_offer.is_empty():
			return Result.fail("no_main_contract", "ui.error.no_main_contract", {"sequence": 1})
		state.data["contracts"]["main_offer"] = main_offer
		var accepted := ContractOps.accept_offer(state, hub, String(main_offer.get("instance_id", "")))
		if not bool(accepted.get("ok", false)):
			return Result.fail("main_contract_unsatisfiable", "ui.error.main_contract_unsatisfiable", {
				"error_code": accepted.get("error_code", ""),
				"start_profile_id": start_profile.id,
			})
	ContractOps.generate_normal_offers(state, hub, rng, "initial:%s" % state.current_port_id())
	state.push_notice("ui.notice.run_started", {"build": build.name_key})
	if tutorial:
		# StoryService resolves `map_configs.story` through ContentRefs; missing or
		# disabled story keeps the "tutorial completed, all features unlocked" fallback.
		StoryService.begin(state, hub, rng)
	# C3: `auto_start` content quests are picked up at the end of run initialisation.
	QuestService.auto_start_state(state, hub)

	return Result.ok({
		"state": state,
		"rng": rng,
		"start_profile": start_profile,
		"world_profile": world_profile,
		"map_config": map_config,
		"seed": seed_value,
	})


## Builds the run's GameState skeleton with the §6.3 shape: legacy `run` fields,
## `campaign.setup` / `content_versions`, the generated world + v2 ids.
static func _create_state(
	build: ContentDefinition,
	ship: Dictionary,
	world: Dictionary,
	seed_value: int,
	start_profile: ContentDefinition,
	world_profile: ContentDefinition,
	map_config: ContentDefinition
) -> GameState:
	var started_at := Time.get_datetime_string_from_system(true)
	var difficulty := String(start_profile.data.get("difficulty", DEFAULT_DIFFICULTY))
	world["map_profile_id"] = ""
	world["start_profile_id"] = start_profile.id
	world["world_profile_id"] = world_profile.id
	world["map_config_id"] = map_config.id

	var campaign_defaults: Dictionary = GameState.CAMPAIGN_DEFAULTS.duplicate(true)
	campaign_defaults["id"] = "campaign_%d" % seed_value
	campaign_defaults["created_at"] = started_at
	campaign_defaults["difficulty"] = difficulty

	var state := GameState.new()
	state.data = {
		"schema_version": GameState.SCHEMA_VERSION,
		"campaign": campaign_defaults,
		"run": {
			"seed": seed_value,
			"game_time": 0.0,
			"started_at": started_at,
			"starting_build": build.id,
			"map_profile_id": "",
		},
		"player": _create_player(build, start_profile),
		"world": world,
		"ship": ship.duplicate(true),
		"contracts": {},
		"market": {},
		"port_memory": {},
		"npcs": [],
		"intelligence": {},
		"notices": [],
		"stats": GameState.STATS_DEFAULTS.duplicate(true),
		"victory": null,
	}
	state.data["ship"] = ship.duplicate(true)
	state.ensure_campaign()
	var campaign := state.campaign()
	campaign["id"] = "campaign_%d" % seed_value
	campaign["created_at"] = started_at
	campaign["difficulty"] = difficulty
	campaign["setup"] = {
		"start_profile_id": start_profile.id,
		"world_profile_id": world_profile.id,
		"map_config_id": map_config.id,
		"starting_build_id": build.id,
		"difficulty": difficulty,
		"seed": seed_value,
		"content_versions": _content_versions_snapshot(),
	}
	var campaign_world := state.campaign_world()
	campaign_world["profile_id"] = world_profile.id
	campaign_world["generated"] = true
	campaign_world["regions"] = []
	campaign_world["sites"] = []
	return state


## Player block: start profile overrides the build's money / reputation; debt is
## still expressed by the 1.0 starting build's optional `loan` block (Phase C will
## merge scenarios). The scenario `map_config.loan` keeps driving the bank commands.
static func _create_player(build: ContentDefinition, start_profile: ContentDefinition) -> Dictionary:
	var build_data: Dictionary = build.data
	var profile_data: Dictionary = start_profile.data
	var player := {
		"money": int(profile_data.get("starting_money", build_data.get("money", 0))),
		"reputation": int(profile_data.get("starting_reputation", build_data.get("reputation", 0))),
		"unlocks": [],
		"debt": null,
	}
	if build_data.get("loan", null) is Dictionary:
		var loan: Dictionary = build_data["loan"]
		var principal := float(loan.get("principal", 0.0))
		var interest_rate := float(loan.get("interest_rate", 0.1))
		player["debt"] = {
			"principal": principal,
			"interest_rate": interest_rate,
			"remaining": principal * (1.0 + interest_rate),
			"borrowed_at": 0.0,
			"due_time": float(loan.get("term_hours", 96.0)),
			"overdue": false,
		}
	return player


## Generates the coordinate-space twin chart world and seeds its fog. Failure
## only degrades the chart to "no data" (same contract as the 1.0 path).
static func _generate_twin_world(
	state: GameState,
	world: Dictionary,
	map_config: ContentDefinition,
	hub: RegistryHub,
	rng: RngService,
	ship: Dictionary,
	starting_port_id: String
) -> void:
	var twin_profile := RunFactory._coordinate_world_profile(world, map_config)
	var world_map_result := WorldGenerator.generate(twin_profile, hub, rng, ship)
	if not bool(world_map_result.get("ok", false)):
		return
	state.data["world_map"] = world_map_result["world_map"]
	RunFactory._initialize_world_fog(state, starting_port_id, hub)


## Resolves the scenario config: explicit `start_profile.map_config` must exist;
## missing reference falls back to the contract's default map-config id (see
## `_default_map_config_id`), then to the first map config by id (§5.2 fallback).
static func _resolve_map_config(hub: RegistryHub, profile_data: Dictionary) -> Dictionary:
	var explicit_id := String(profile_data.get("map_config", ""))
	if not explicit_id.is_empty():
		var explicit := hub.get_by_id(ContentTypes.MAP_CONFIG, explicit_id)
		if explicit == null:
			return {
				"ok": false,
				"failure": Result.fail("unknown_map_config", "ui.error.unknown_map_config", {
					"map_config_id": explicit_id,
				}),
			}
		return {"ok": true, "definition": explicit, "fallback": false}
	var preferred_id := _default_map_config_id()
	var preferred := hub.get_by_id(ContentTypes.MAP_CONFIG, preferred_id)
	if preferred != null:
		return {"ok": true, "definition": preferred, "fallback": true}
	var all := _sorted_definitions(hub.get_all(ContentTypes.MAP_CONFIG))
	if all.is_empty():
		return {
			"ok": false,
			"failure": Result.fail("no_map_config", "ui.error.no_map_config"),
		}
	return {"ok": true, "definition": all[0], "fallback": true}


## §6.2 的缺省回退 id。框架源码禁止出现字面 `core:*` 内容 ID（`test_no_core_ids`），
## 所以 id 由内容类型单数名拼出；语义仍是契约约定的标准 map config。
static func _default_map_config_id() -> String:
	return "core:%s/standard" % String(ContentTypes.SINGULAR.get(ContentTypes.MAP_CONFIG, "map_config"))


static func _resolve_definition(hub: RegistryHub, content_type: StringName, definition_id: String) -> ContentDefinition:
	if definition_id.is_empty():
		return null
	return hub.get_by_id(content_type, definition_id)


static func _sorted_definitions(definitions: Array) -> Array:
	return CampaignAssembly.sorted_by_id(definitions)


static func _definitions_by_id(definitions: Array) -> Dictionary:
	var index := {}
	for definition in definitions:
		index[(definition as ContentDefinition).id] = definition
	return index


## Snapshot of the expected content versions per type (§7 D3): written into
## `campaign.setup.content_versions` so a save can report version drift later.
static func _content_versions_snapshot() -> Dictionary:
	var versions := {}
	for content_type in ContentTypes.SCHEMA_VERSIONS.keys():
		versions[String(content_type)] = String(ContentTypes.SCHEMA_VERSIONS[content_type])
	return versions
