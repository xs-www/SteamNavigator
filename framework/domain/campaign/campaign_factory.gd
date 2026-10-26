class_name CampaignFactory
extends RefCounted
## @static-doc
## 作用：战役开局装配（WORLD_SCHEMA_V2_RUNTIME §6.2）。从 `start_profiles` 定义解析
## 世界构成 / 场景调参 / 起始场景（`starting_scenarios`），用 `WorldGenerator.generate_chart`
## 生成**唯一世界**（海图 = 玩法地图：陆地 + 港口 + **完全图拓扑** + 路径/距离/风险），
## `ChartWorldProjection.from_chart` 派生出 `GameState.world()`，再用
## Region/Site/Route/Faction/Discovery 装配器把 2.0 世界内容实例化进 `GameState`。
## `run.start` 的默认入口（`create_default_campaign`）也走这里，C4 起不再存在 1.0
## `RunFactory.create_run` 几何路径；2026-10-26 起不再调用 `MapGenerator` 生成拓扑。
##
## ## 契约与约束
## - **入口**：
##   - `create_campaign(context, start_profile_id, requested_seed=0, tutorial=false,
##     starting_scenario_id="")`：显式 start profile；第五参可覆盖起始场景。
##   - `create_default_campaign(context, starting_scenario_id="", requested_seed=0,
##     tutorial=false)`：`run.start` 无 `start_profile` 时使用，取注册表中 id 最小的
##     `start_profiles` 定义（Core 声明的标准起始档案，按 `start.standard` tag 选择）。
## - **返回**：`Result.ok({state, rng, start_profile, starting_scenario, world_profile,
##   map_config, seed})`；失败使用 `Result.fail(error_code, message_key, data)`。
## - **单一世界（海图唯一真相）**：
##   `WorldGenerator.generate_chart` 产出的 `world_map` 就是唯一世界与唯一拓扑；
##   它同时写入 `state.data["world_map"]`（海图 / 迷雾 / 演出读它）并经
##   `ChartWorldProjection.from_chart` 变成 `state.world`（MapOps / 委托 / 航行 / BFS 读它）。
##   两者不是两份数据：`routes[].distance ≡ WorldMap.edges[].distance ≡` 绘制路径折线长度。
##   **拓扑恒为完全图**（任意两港物理可通航）；可出航性由 `campaign_world.unlocked_route_keys`
##   门禁，新局该数组为空（委托 / 剧情 / 酒馆海图在装配过程中解锁各自航线）。
## - **状态形状**：
##   `data.run = {seed, game_time, started_at, starting_scenario}`；
##   `data.campaign.setup = {start_profile_id, world_profile_id, map_config_id,
##   starting_scenario_id, difficulty, seed, content_versions}`；
##   `state.world` = 海图投影世界 + `start_profile_id / world_profile_id /
##   map_config_id / starting_scenario_id`（`map_profiles` 已退役，无 map_profile_id）；
##   `data.campaign.world = {profile_id, generated, regions[], sites[],
##   visited_region_ids, discovered_site_ids, visited_port_ids, unlocked_route_keys[]}`；
##   `data.campaign.codex / factions` 由装配器写入；`data.world_map` 为同一张海图的存档形态。
## - **复用而非复制**：飞船用 `RunFactory.create_ship`；市场/补给/贷款参数入口
##   `RunFactory.initialize_markets`；迷雾用 `RunFactory._initialize_world_fog`；主线与
##   普通委托沿用 `ContractOps` 与 RunFactory 的私有 helper。
##   tutorial=true 时最后调用 `StoryService.begin`（StoryService 走 `ContentRefs` 读
##   `map_configs.story`）。
## - **确定性**（§6.4）：几何 / 拓扑 / 航线风险都来自 `STREAM_MAP_GENERATION` 的命名子流
##   （`"chart_world"`、`"route_risk:<pair>"`）；内容装配用 `STREAM_CAMPAIGN_WORLD` 的
##   `"regions"/"sites"/"routes"/"factions"/"discoveries"` 子流；注册表结果在抽取前按 id
##   排序。同 seed + 同内容 = 同世界实例。
## - **D8**：本切片 `port_count` 上限 5（`MapGenerationSpec` clamp + warning），5 块陆地
##   各放 1 港；更多港口需要更多陆地/每陆多港，当前不扩张。
## - 本类不发领域事件（`run.started` 由 run_start 负责），不写 autosave。
## @end-static-doc

const DEFAULT_DIFFICULTY := "standard"
## Loaded by path (not the global class cache): a brand-new `class_name` only enters the
## cache after an editor reimport, and headless tests must not depend on one.
const ChartWorldProjection := preload("res://framework/domain/world/chart_world_projection.gd")


## Creates a full campaign state. Returns a `Result` envelope.
## `starting_scenario_id` (optional) overrides the scenario referenced by the start
## profile — used by the `run.start` default entry so a caller can pick a scenario
## without crafting a dedicated start profile.
static func create_campaign(
	context,
	start_profile_id: String,
	requested_seed: int = 0,
	tutorial: bool = false,
	starting_scenario_id: String = ""
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

	var resolved_scenario_id := starting_scenario_id
	if resolved_scenario_id.is_empty():
		resolved_scenario_id = String(start_profile.data.get("starting_scenario", ""))
	var scenario := _resolve_definition(hub, ContentTypes.STARTING_SCENARIO, resolved_scenario_id)
	if scenario == null:
		return Result.fail("no_starting_scenario", "ui.error.no_starting_scenario", {
			"start_profile_id": start_profile.id,
			"starting_scenario_id": resolved_scenario_id,
		})

	var seed_value := requested_seed if requested_seed != 0 else RunFactory._random_seed()
	var rng := RngService.new(seed_value)

	var ship := RunFactory.create_ship(hub, scenario)
	var ship_validation := ShipOps.validate_configuration(hub, ship)
	if not bool(ship_validation.get("ok", false)):
		return Result.fail("invalid_starting_scenario", "ui.error.invalid_starting_scenario", {
			"errors": ship_validation.get("errors", []),
		})

	# 1) The chart is the single world (2026-10-26): build its playable topology and
	#    coordinate geometry in one pass. `MapGenerationSpec` still supplies the content
	#    blueprint (port count / archetypes / names / facility + edge budgets / risk range),
	#    but its topology no longer comes from `MapGenerator`.
	var spec := MapGenerationSpec.build(
		world_profile, map_config, _sorted_definitions(hub.get_all(ContentTypes.ROUTE_TEMPLATE)), start_profile
	)
	var chart_profile := _chart_world_profile(spec, map_config)
	var chart_result := WorldGenerator.generate_chart(chart_profile, hub, rng, ship)
	if not bool(chart_result.get("ok", false)):
		return Result.fail("map_generation_failed", "ui.error.map_generation_failed", {
			"reason": String(chart_result.get("reason", "")),
		})
	var world_map_data: Dictionary = chart_result["world_map"]
	# Gameplay reads the same graph: ports / routes are projected from the chart edges.
	var world: Dictionary = ChartWorldProjection.from_chart(world_map_data)

	# 2) State skeleton + campaign identity. The ids go in before any service
	#    reads the scenario through ContentRefs (markets / story / exploration).
	var state := _create_state(scenario, ship, world, seed_value, start_profile, world_profile, map_config)
	var campaign := state.campaign()
	var campaign_world := state.campaign_world()
	# The single world is stored once: the chart data IS the world map.
	state.data["world_map"] = world_map_data
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

	# 8) Fog on the single chart world (positions are final from step 1; no second world).
	RunFactory._initialize_world_fog(state, starting_port_id, hub)

	# 9) Economy / contracts / notices, mirroring the pre-C4 run pipeline.
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
	state.push_notice("ui.notice.run_started", {"scenario": scenario.name_key})
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
		"starting_scenario": scenario,
		"world_profile": world_profile,
		"map_config": map_config,
		"seed": seed_value,
	})


## Default `run.start` entry (no explicit `start_profile`): picks the content-declared
## standard start profile (`start.standard` tag; difficulty fallback; then lowest id)
## and optionally overrides its `starting_scenario` (the old starting-build selection
## becomes a scenario pick).
static func create_default_campaign(
	context,
	starting_scenario_id: String = "",
	requested_seed: int = 0,
	tutorial: bool = false
) -> Dictionary:
	var hub: RegistryHub = context.registries
	var start_profile := default_start_profile(hub)
	if start_profile == null:
		return Result.fail("no_start_profile", "ui.error.no_start_profile")
	return create_campaign(context, start_profile.id, requested_seed, tutorial, starting_scenario_id)


## Default start profile: prefer the Core-declared `start.standard` tag, then
## `difficulty == "standard"`, then the lowest id (deterministic, never a content id
## literal in framework code).
static func default_start_profile(hub: RegistryHub) -> ContentDefinition:
	if hub == null:
		return null
	var profiles := _sorted_definitions(hub.get_all(ContentTypes.START_PROFILE))
	if profiles.is_empty():
		return null
	for profile in profiles:
		if (profile as ContentDefinition).has_tag("start.standard"):
			return profile
	for profile in profiles:
		if String((profile as ContentDefinition).data.get("difficulty", "")) == DEFAULT_DIFFICULTY:
			return profile
	return profiles[0]


## Builds the run's GameState skeleton: `campaign.setup` / `content_versions`,
## the generated world + v2 ids (no retired `map_profiles` fields).
static func _create_state(
	scenario: ContentDefinition,
	ship: Dictionary,
	world: Dictionary,
	seed_value: int,
	start_profile: ContentDefinition,
	world_profile: ContentDefinition,
	map_config: ContentDefinition
) -> GameState:
	var started_at := Time.get_datetime_string_from_system(true)
	var difficulty := String(start_profile.data.get("difficulty", DEFAULT_DIFFICULTY))
	world["start_profile_id"] = start_profile.id
	world["world_profile_id"] = world_profile.id
	world["map_config_id"] = map_config.id
	world["starting_scenario_id"] = scenario.id

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
			"starting_scenario": scenario.id,
		},
		"player": _create_player(scenario, start_profile),
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
		"starting_scenario_id": scenario.id,
		"difficulty": difficulty,
		"seed": seed_value,
		"content_versions": _content_versions_snapshot(),
	}
	var campaign_world := state.campaign_world()
	campaign_world["profile_id"] = world_profile.id
	campaign_world["generated"] = true
	campaign_world["regions"] = []
	campaign_world["sites"] = []
	# A new run starts with **no charted route**: contracts / story / tavern charts
	# unlock the pairs the player may actually sail (see ROUTE_UNLOCK_SYSTEM.md).
	campaign_world["unlocked_route_keys"] = []
	return state


## Player block: start profile overrides the scenario's money / reputation; debt is
## expressed by the starting scenario's optional `loan` block. The scenario
## `map_config.loan` keeps driving the bank commands.
static func _create_player(scenario: ContentDefinition, start_profile: ContentDefinition) -> Dictionary:
	var build_data: Dictionary = scenario.data
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


## Builds the generator profile for the **single chart world** (2026-10-26).
##
## The content blueprint comes from `MapGenerationSpec` (port count / archetypes / name
## keys / start tags / required facilities / edge budget / risk range, all derived from
## `world_profiles` + `map_configs` + `route_templates`); the coordinate layout is the
## kept 5-landmass composition scaled by `map_config.twin_world_size`. One harbour per
## landmass, starting on the continent — a layout the geometry tests already validated
## (every abstract edge pair could be drawn, 0 straight-line fallbacks across 9 seeds).
static func _chart_world_profile(spec: Dictionary, map_config: ContentDefinition) -> Dictionary:
	var world_size := clampf(float(map_config.data.get("twin_world_size", 160.0)), 64.0, 1024.0)
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

	var port_range: Array = Array(spec.get("port_count_range", [4, 5]))
	var port_count := clampi(int(port_range[0]), 1, mini(layout.size(), MapGenerationSpec.MAX_PORTS_THIS_SLICE))
	var name_keys: Array = Array(spec.get("port_name_keys", []))
	var port_defs: Array = []
	for index in port_count:
		port_defs.append({
			"landmass_id": String((layout[index] as Dictionary)["id"]),
			"coast_t": clampf(0.3 + 0.15 * float(index), 0.0, 1.0),
			"name_key": String(name_keys[index]) if index < name_keys.size() else "port.name.%d" % index,
			"is_start": index == 0,
		})
	return {
		"world_size": world_size,
		"min_ports": port_count,
		"max_ports": port_count,
		"max_land_coverage": 0.45,
		"required_facility_tags": Array(spec.get("required_facility_tags", [])),
		"required_facility_max_edges": int(spec.get("required_facility_max_edges", 2)),
		"risk_range": Array(spec.get("route_risk_range", [0.01, 0.05])),
		"archetypes": Array(spec.get("archetypes", [])),
		"start_archetype_tags": Array(spec.get("start_archetype_tags", [])),
		"port_name_keys": name_keys,
		"regions": [
			{"id": "start_coast", "name_key": "world.region.start_coast", "tier": "coastal"},
			{"id": "ocean_1", "name_key": "world.region.ocean_1", "tier": "oceanic"},
		],
		"landmasses": layout.slice(0, maxi(1, port_count)),
		"ports": port_defs,
	}


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
