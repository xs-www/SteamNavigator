extends TestCase
## @static-doc
## 作用：Phase B B3-A 战役世界装配测试（WORLD_SCHEMA_V2_RUNTIME §6.2/§6.3/§6.4）：用
## `bootstrap_core()` 的 1.0 基线 + 合成 2.0 定义驱动 `CampaignFactory.create_campaign`，
## 覆盖完整 state 形状、同 seed 确定性、不同 seed 差异、区域/地点/航路一致性、
## map_config 缺省回退与 start_profile / world_profile / map_config / starting_build
## 缺失的结构化错误、教程分支 StoryService.begin、阵营声望与态度派生。
##
## ## 契约与约束
## - **不依赖 B4 core v2 内容**：合成 hub 只抄 1.0 类型定义，再注册 `test:*` 的
##   world_profile / map_config / region / site / route_template / faction / discovery /
##   start_profile；`core:map_config/standard` 从不出现在断言里。
## - **fixture 复用**：`build_synthetic_context()` / `synthetic_hub()` /
##   `synthetic_start_profile_id()` 是非 test_ 前缀的 public 方法，B3-B 的
##   `test_campaign_start.gd` 可直接 `preload(...).new()` 复用，避免两套 fixture 漂移。
## - **确定性断言不比较时间戳**：`run.started_at` / `campaign.created_at` 是唯一非确定
##   字段，指纹里剔除；其余（world / campaign / market / npcs / contracts / world_map）
##   必须逐层相等。
## - 断言世界实例的**引用完整性**（region→port、site→region、route→template）而不是
##   固定随机结果，避免内容权重微调就把测试写死。
## @end-static-doc

const START_PROFILE_ID := "test:start_profile/standard"
const START_PROFILE_NO_MAP_CONFIG := "test:start_profile/no_map_config"
const START_PROFILE_MISSING_WORLD := "test:start_profile/missing_world"
const START_PROFILE_MISSING_MAP_CONFIG := "test:start_profile/missing_map_config"
const START_PROFILE_MISSING_BUILD := "test:start_profile/missing_build"
const WORLD_PROFILE_ID := "test:world_profile/default"
const MAP_CONFIG_ID := "test:map_config/standard"
const STARTING_BUILD_ID := "core:starting_build/steady"
const SITES_PER_REGION := 2
const REGION_COUNT := 5
const FACTION_COUNT := 3
const PORT_COUNT := 5

var _context_cache: AppContext = null


## Public fixture for sibling suites: a bootstrapped context whose registry hub is
## the 1.0 baseline + synthetic v2 definitions, with an empty GameState.
func build_synthetic_context() -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.registries = synthetic_hub(context.registries)
	context.reset_state()
	return context


## Public fixture: registry hub with the 1.0 baseline (no v2 core content) plus the
## synthetic v2 world/campaign definitions used by every campaign assembly test.
func synthetic_hub(baseline: RegistryHub = null) -> RegistryHub:
	var source: RegistryHub = baseline
	if source == null:
		source = bootstrap_core()["context"].registries
	var hub := RegistryHub.new()
	for content_type in ContentTypes.all():
		if _v2_types().has(content_type):
			continue
		for definition in source.get_all(content_type):
			hub.register(definition)
	_register_synthetic_contents(hub)
	hub.freeze_all()
	return hub


func synthetic_start_profile_id() -> String:
	return START_PROFILE_ID


func synthetic_map_config_id() -> String:
	return MAP_CONFIG_ID


func synthetic_world_profile_id() -> String:
	return WORLD_PROFILE_ID


## ---------------------------------------------------------------------------
## Fixture content
## ---------------------------------------------------------------------------

static func _v2_types() -> Array:
	return [
		ContentTypes.WORLD_PROFILE,
		ContentTypes.REGION,
		ContentTypes.SITE,
		ContentTypes.ROUTE_TEMPLATE,
		ContentTypes.WEATHER_PROFILE,
		ContentTypes.FACTION,
		ContentTypes.DISCOVERY,
		ContentTypes.START_PROFILE,
		ContentTypes.MAP_CONFIG,
	]


func _register_synthetic_contents(hub: RegistryHub) -> void:
	_define(hub, ContentTypes.WEATHER_PROFILE, "test:weather_profile/temperate", [], {
		"climate": "temperate",
		"fog_chance": 0.1,
		"storm_chance": 0.05,
		"risk_modifier": 0.0,
	})
	# 5 region prototypes covering every region_kind used by sites / routes.
	_region(hub, "test:region/start", "coastal", "medium", 0.8, ["region.start"])
	_region(hub, "test:region/coastal", "coastal", "medium", 0.6, ["region.coastal"])
	_region(hub, "test:region/archipelago", "archipelago", "small", 0.5, ["region.archipelago"])
	_region(hub, "test:region/open_sea", "open_sea", "large", 0.3, ["region.open_sea"])
	_region(hub, "test:region/industrial", "industrial", "medium", 0.7, ["region.industrial"])
	# 6 site prototypes: together they cover every region_kind above.
	_site(hub, "test:site/ruin", "ruin", 3, ["coastal", "industrial"], false, true, true)
	_site(hub, "test:site/wreck", "wreck", 2, ["archipelago", "open_sea"], false, true, false)
	_site(hub, "test:site/landmark", "landmark", 2, [], true, false, false)
	_site(hub, "test:site/encounter", "encounter", 2, ["open_sea"], true, false, true)
	_site(hub, "test:site/resource", "resource", 1, ["industrial", "coastal"], false, false, false)
	_site(hub, "test:site/base", "base_site", 1, ["coastal"], false, true, true)
	# 3 route templates; the trade route is unrestricted so every edge can match.
	_route_template(hub, "test:route_template/sea_lane", "sea_lane", [80, 160], [0.01, 0.05], [4, 10], ["coastal", "industrial"])
	_route_template(hub, "test:route_template/trade_route", "trade_route", [120, 220], [0.02, 0.08], [6, 14], [])
	_route_template(hub, "test:route_template/hazardous_shortcut", "hazardous_shortcut", [60, 120], [0.1, 0.25], [3, 8], ["open_sea", "archipelago"])
	# 3 factions with distinct starting reputations / thresholds.
	_faction(hub, "test:faction/merchants", "merchant_guild", 5, -20, 40)
	_faction(hub, "test:faction/navy", "naval", 0, -30, 30)
	_faction(hub, "test:faction/pirates", "pirates", -10, -50, 10)
	# 6 discoveries: rarity / weight / source filters / tag gate all represented.
	_discovery(hub, "test:discovery/blueprint_schematic", "blueprint", "uncommon", 4, false, ["ruin", "wreck"], ["industrial", "open_sea"], [], ["core:boiler/standard"])
	_discovery(hub, "test:discovery/relic_compass", "relic", "rare", 3, false, ["wreck", "landmark"], [], [], ["core:navigation_module/spyglass"])
	_discovery(hub, "test:discovery/lore_harbor", "lore", "common", 5, true, [], [], [], [])
	_discovery(hub, "test:discovery/species_gull", "species", "common", 3, true, ["landmark"], [], [], [])
	_discovery(hub, "test:discovery/ruin_room_boiler", "ruin_room", "uncommon", 2, false, ["ruin"], [], ["region.start"], ["core:boiler/standard"])
	_discovery(hub, "test:discovery/site_cache", "site", "common", 2, true, [], ["coastal", "archipelago"], [], [])
	# Map config: the 1.0 scenario tuning the generator needs (archetypes / names /
	# facilities) plus twin world size. No core ids beyond the 1.0 archetypes.
	_define(hub, ContentTypes.MAP_CONFIG, MAP_CONFIG_ID, [], {
		"archetypes": [
			"core:port_archetype/iron_harbor",
			"core:port_archetype/spice_port",
			"core:port_archetype/free_town",
			"core:port_archetype/fishing_village",
			"core:port_archetype/glass_port",
		],
		"port_name_keys": ["test.port.alpha", "test.port.beta", "test.port.gamma", "test.port.delta", "test.port.epsilon"],
		"start_archetype_tags": [],
		"required_facility_tags": ["port.shipyard", "port.intel"],
		"required_facility_max_edges": 2,
		"npc_count_range": [2, 3],
		"npc_cargo_range": [8, 24],
		"supply_prices": {"coal": 4, "water": 2, "repair_per_point": 6},
		"loan": {"limit": 1200, "interest_rate": 0.12, "term_hours": 96},
		"intel_cost": 25,
		"trade_margin": 0.95,
		"player_trade_impact": 0.35,
		"twin_world_size": 160.0,
	})
	_define(hub, ContentTypes.WORLD_PROFILE, WORLD_PROFILE_ID, [], {
		"region_count": REGION_COUNT,
		"sites_per_region": SITES_PER_REGION,
		"port_count": PORT_COUNT,
		"ruin_density": 0.2,
		"base_site_count": 2,
		"faction_count": FACTION_COUNT,
		"weather_profile": "test:weather_profile/temperate",
		"edge_density": 0.5,
		"start_region_tags": ["region.start"],
	})
	_start_profile(hub, START_PROFILE_ID, {
		"map_config": MAP_CONFIG_ID,
		"starting_port_tags": [],
	})
	_start_profile(hub, START_PROFILE_NO_MAP_CONFIG, {
		"starting_port_tags": [],
	})
	_start_profile(hub, START_PROFILE_MISSING_WORLD, {
		"world_profile": "test:world_profile/missing",
	})
	_start_profile(hub, START_PROFILE_MISSING_MAP_CONFIG, {
		"map_config": "test:map_config/missing",
	})
	_start_profile(hub, START_PROFILE_MISSING_BUILD, {
		"starting_build": "core:starting_build/missing",
	})


func _start_profile(hub: RegistryHub, definition_id: String, overrides: Dictionary) -> void:
	var data := {
		"world_profile": WORLD_PROFILE_ID,
		"map_config": MAP_CONFIG_ID,
		"starting_build": STARTING_BUILD_ID,
		"difficulty": "standard",
		"starting_port_tags": [],
		"starting_money": 900,
		"starting_reputation": 10,
	}
	for key in overrides.keys():
		data[String(key)] = overrides[key]
	_define(hub, ContentTypes.START_PROFILE, definition_id, [], data)


func _region(hub: RegistryHub, definition_id: String, kind: String, size: String, port_density: float, tags: Array) -> void:
	_define(hub, ContentTypes.REGION, definition_id, tags, {
		"kind": kind,
		"size": size,
		"port_density": port_density,
		"site_density": 0.6,
		"weather_profile": "test:weather_profile/temperate",
		"region_tags": tags,
	})


func _site(
	hub: RegistryHub,
	definition_id: String,
	site_kind: String,
	weight: int,
	region_kinds: Array,
	repeatable: bool,
	loot: bool,
	encounter: bool
) -> void:
	var data := {
		"site_kind": site_kind,
		"weight": weight,
		"region_kinds": region_kinds,
		"repeatable": repeatable,
	}
	if loot:
		data["loot_table"] = "test:loot_table/%s" % site_kind
	if encounter:
		data["encounter_table"] = "test:encounter_table/%s" % site_kind
	_define(hub, ContentTypes.SITE, definition_id, [], data)


func _route_template(
	hub: RegistryHub,
	definition_id: String,
	kind: String,
	distance_range: Array,
	risk_range: Array,
	travel_time_range: Array,
	region_kinds: Array
) -> void:
	_define(hub, ContentTypes.ROUTE_TEMPLATE, definition_id, [], {
		"kind": kind,
		"distance_range": distance_range,
		"risk_range": risk_range,
		"travel_time_range": travel_time_range,
		"bidirectional": true,
		"region_kinds": region_kinds,
	})


func _faction(hub: RegistryHub, definition_id: String, kind: String, starting_reputation: int, hostile_below: int, friendly_at: int) -> void:
	_define(hub, ContentTypes.FACTION, definition_id, [], {
		"kind": kind,
		"starting_reputation": starting_reputation,
		"attitude_thresholds": {"hostile_below": hostile_below, "friendly_at": friendly_at},
		"patrol_strength": 1,
	})


func _discovery(
	hub: RegistryHub,
	definition_id: String,
	kind: String,
	rarity: String,
	weight: int,
	repeatable: bool,
	source_site_kinds: Array,
	region_kinds: Array,
	requires_tags: Array,
	unlock_ids: Array
) -> void:
	_define(hub, ContentTypes.DISCOVERY, definition_id, [], {
		"kind": kind,
		"rarity": rarity,
		"weight": weight,
		"repeatable": repeatable,
		"source_site_kinds": source_site_kinds,
		"region_kinds": region_kinds,
		"requires_tags": requires_tags,
		"unlock_ids": unlock_ids,
	})


func _define(hub: RegistryHub, content_type: StringName, definition_id: String, tags: Array, data: Dictionary) -> ContentDefinition:
	var raw := {
		"id": definition_id,
		"name_key": "test.%s.name" % definition_id.get_slice("/", 1),
		"enabled": true,
		"tags": tags,
		"data": data,
	}
	var definition := ContentDefinition.from_raw(raw, content_type, "test", "res://framework/tests/cases/test_campaign_assembly.gd")
	var result := hub.register(definition, "test")
	assert_true(bool(result.get("ok", false)), "synthetic definition %s registers: %s" % [definition_id, result])
	return definition


## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------

func _context() -> AppContext:
	if _context_cache == null:
		_context_cache = build_synthetic_context()
	return _context_cache


func _create(seed_value: int, start_profile_id: String = START_PROFILE_ID, tutorial: bool = false) -> Dictionary:
	return CampaignFactory.create_campaign(_context(), start_profile_id, seed_value, tutorial)


func _ok_data(result: Dictionary, label: String) -> Dictionary:
	assert_true(bool(result.get("ok", false)), "%s succeeds: %s" % [label, result])
	return result.get("data", {}) if result.get("data", {}) is Dictionary else {}


func _state(result: Dictionary) -> GameState:
	return result["data"]["state"]


## Deterministic fingerprint: drops the only wall-clock fields (`started_at` /
## `created_at`) and keeps every generated / content-driven sub-tree.
func _fingerprint(state: GameState) -> Dictionary:
	var run: Dictionary = state.run().duplicate(true)
	run.erase("started_at")
	var campaign: Dictionary = state.campaign().duplicate(true)
	campaign.erase("created_at")
	return {
		"run": run,
		"world": state.world().duplicate(true),
		"campaign": campaign,
		"market": state.market().duplicate(true),
		"npcs": state.data.get("npcs", []).duplicate(true),
		"contracts": state.contracts().duplicate(true),
		"world_map": state.data.get("world_map", {}),
	}


func _port_ids(world: Dictionary) -> Array:
	var ids: Array = (world.get("ports", {}) as Dictionary).keys()
	ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		return String(left).trim_prefix("port_").to_int() < String(right).trim_prefix("port_").to_int()
	)
	return ids


## ---------------------------------------------------------------------------
## Tests
## ---------------------------------------------------------------------------

func test_create_campaign_returns_full_state_shape() -> void:
	var result := _create(12345)
	var data := _ok_data(result, "campaign creation")
	for key in ["state", "rng", "start_profile", "world_profile", "map_config", "seed"]:
		assert_contains(data, key, "result data contains '%s'" % key)
	assert_true(data.get("rng") is RngService, "result carries the RngService")
	assert_eq(int(data.get("seed", 0)), 12345, "requested seed is used verbatim")
	var state := _state(result)

	# Legacy run fields + explicit empty map_profile_id (v2 path).
	var run: Dictionary = state.run()
	assert_eq(int(run.get("seed", 0)), 12345, "run.seed is written")
	assert_eq(String(run.get("starting_build", "")), STARTING_BUILD_ID, "run.starting_build is written")
	assert_true(run.has("started_at"), "run.started_at is kept for the legacy shape")
	assert_eq(String(run.get("map_profile_id", "unset")), "", "v2 run leaves map_profile_id empty")

	# state.world: generated map + v2 ids.
	var world: Dictionary = state.world()
	assert_eq(String(world.get("start_profile_id", "")), START_PROFILE_ID, "world.start_profile_id")
	assert_eq(String(world.get("world_profile_id", "")), WORLD_PROFILE_ID, "world.world_profile_id")
	assert_eq(String(world.get("map_config_id", "")), MAP_CONFIG_ID, "world.map_config_id")
	assert_eq(String(world.get("map_profile_id", "unset")), "", "world.map_profile_id is empty on the v2 path")
	assert_eq((world.get("ports", {}) as Dictionary).size(), PORT_COUNT, "world has the world profile's port count")

	# campaign.setup + content version snapshot.
	var setup: Dictionary = state.campaign_setup()
	assert_eq(String(setup.get("start_profile_id", "")), START_PROFILE_ID, "setup.start_profile_id")
	assert_eq(String(setup.get("world_profile_id", "")), WORLD_PROFILE_ID, "setup.world_profile_id")
	assert_eq(String(setup.get("map_config_id", "")), MAP_CONFIG_ID, "setup.map_config_id")
	assert_eq(String(setup.get("starting_build_id", "")), STARTING_BUILD_ID, "setup.starting_build_id")
	assert_eq(String(setup.get("difficulty", "")), "standard", "setup.difficulty")
	assert_eq(int(setup.get("seed", 0)), 12345, "setup.seed")
	var versions: Dictionary = setup.get("content_versions", {})
	assert_eq(versions.size(), ContentTypes.SCHEMA_VERSIONS.size(), "content_versions snapshots every type")
	assert_eq(String(versions.get("world_profiles", "")), "2.0", "v2 types report 2.0")
	assert_eq(String(versions.get("goods", "")), "1.0", "1.0 types keep 1.0")

	# campaign.world assembly output.
	var campaign_world: Dictionary = state.campaign_world()
	assert_true(bool(campaign_world.get("generated", false)), "campaign.world.generated")
	assert_eq(String(campaign_world.get("profile_id", "")), WORLD_PROFILE_ID, "campaign.world.profile_id")
	assert_eq((campaign_world.get("regions", []) as Array).size(), REGION_COUNT, "region count")
	assert_eq((campaign_world.get("sites", []) as Array).size(), REGION_COUNT * SITES_PER_REGION, "site count")
	assert_contains(campaign_world.get("visited_port_ids", []), "port_0", "starting port is visited")

	# Codex starts empty but carries candidate sources; factions are instantiated.
	var codex: Dictionary = state.campaign_codex()
	assert_empty(codex.get("discovered_ids", []), "nothing is discovered at generation time")
	assert_false((codex.get("entries", {}) as Dictionary).is_empty(), "discovery candidates pre-seed codex entries")
	assert_eq(state.campaign_factions().size(), FACTION_COUNT, "faction count is applied")
	for faction_id in state.campaign_factions().keys():
		var entry: Dictionary = state.campaign_factions()[faction_id]
		for key in ["reputation", "attitude", "discovered", "met_at"]:
			assert_contains(entry, key, "faction %s has '%s'" % [faction_id, key])

	# Economy / NPC / twin chart world wiring.
	assert_eq(state.market().size(), PORT_COUNT, "initialize_markets created one market per port")
	assert_false((state.data.get("npcs", []) as Array).is_empty(), "NPC traders are initialized")
	assert_true(state.data.has("world_map"), "twin chart world is generated")
	var world_map: Dictionary = state.data["world_map"]
	assert_eq((world_map.get("ports", []) as Array).size(), PORT_COUNT, "twin world keeps the same port ids")

	# Starting port discovery mirrors the 1.0 pipeline.
	var start_port: Dictionary = (world.get("ports", {}) as Dictionary).get("port_0", {})
	assert_true(bool(start_port.get("discovered", false)), "starting port is discovered")
	assert_true(bool(start_port.get("visited", false)), "starting port is visited")

	# Non-tutorial runs accept the main contract like the 1.0 path.
	assert_not_null(state.contracts().get("main"), "main contract is accepted")
	assert_false(state.data.has("story"), "non-tutorial runs do not start the story flow")


func test_same_seed_is_fully_deterministic() -> void:
	var first := _create(20261022)
	var second := _create(20261022)
	assert_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "both campaigns generate")
	assert_ne(_state(first), _state(second), "each call returns a fresh GameState")
	assert_eq(_fingerprint(_state(first)), _fingerprint(_state(second)), "same seed + same content = identical world")


func test_different_seed_changes_the_generated_world() -> void:
	var first := _create(111)
	var second := _create(222)
	assert_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "both campaigns generate")
	assert_eq(int(_state(first).run().get("seed", 0)), 111, "first seed recorded")
	assert_eq(int(_state(second).run().get("seed", 0)), 222, "second seed recorded")
	assert_ne(_fingerprint(_state(first)), _fingerprint(_state(second)), "different seeds generate a different world")


func test_region_site_and_route_references_are_consistent() -> void:
	var result := _create(424242)
	var state := _state(result)
	var hub := _context().registries
	var world: Dictionary = state.world()
	var ports := _port_ids(world)
	var campaign_world: Dictionary = state.campaign_world()
	var regions: Array = campaign_world["regions"]
	var sites: Array = campaign_world["sites"]

	# Regions: ids are dense, starting region matches start_region_tags, ports covered once.
	var region_ids: Array = []
	var region_kinds := {}
	var region_by_id := {}
	var all_port_ids: Array = []
	for index in regions.size():
		var region: Dictionary = regions[index]
		assert_eq(String(region.get("id", "")), "region_%d" % index, "region ids are dense and ordered")
		region_ids.append(String(region["id"]))
		region_by_id[String(region["id"])] = region
		region_kinds[String(region.get("kind", ""))] = true
		assert_true(String(region.get("weather_profile", "")).begins_with("test:weather_profile/"), "region weather comes from content")
		all_port_ids.append_array(Array(region.get("port_ids", [])))
		if index == 0:
			var start_definition := hub.get_by_id(ContentTypes.REGION, String(region.get("definition_id", "")))
			assert_not_null(start_definition, "starting region definition resolves")
			assert_true(start_definition.has_tag("region.start"), "region_0 matches start_region_tags")
	assert_eq(all_port_ids.size(), ports.size(), "every abstract port is assigned to exactly one region")
	for port_id in ports:
		assert_contains(all_port_ids, port_id, "port %s belongs to a region" % port_id)

	# Sites: count, region back-references and region-kind filters hold.
	var site_ids: Array = []
	for site in sites:
		var entry: Dictionary = site
		site_ids.append(String(entry["id"]))
		assert_true(region_by_id.has(String(entry.get("region_id", ""))), "site %s references a known region" % entry["id"])
		assert_contains(region_ids, entry.get("region_id"), "site region id is registered")
		var site_definition := hub.get_by_id(ContentTypes.SITE, String(entry.get("definition_id", "")))
		assert_not_null(site_definition, "site definition resolves")
		var allowed: Array = Array(site_definition.data.get("region_kinds", []))
		if not allowed.is_empty():
			assert_contains(allowed, (region_by_id[String(entry["region_id"])] as Dictionary).get("kind"),
				"site %s matches its region kind" % entry["id"])
		if String(entry.get("port_id", "")) != "":
			assert_contains(ports, entry.get("port_id"), "site port reference is valid")
		assert_false(bool(entry.get("discovered", true)), "sites start undiscovered")
		assert_contains(entry, "discovery_ids", "site carries discovery candidates")
	var back_referenced: Array = []
	for region_id in region_ids:
		back_referenced.append_array(Array((region_by_id[region_id] as Dictionary).get("site_ids", [])))
	assert_eq(back_referenced.size(), sites.size(), "regions back-reference every site exactly once")
	for site_id in site_ids:
		assert_contains(back_referenced, site_id, "site %s is back-referenced by its region" % site_id)

	# Routes: every abstract edge carries a template consistent with both endpoints.
	var route_ids: Array = []
	for definition in hub.get_all(ContentTypes.ROUTE_TEMPLATE):
		route_ids.append(definition.id)
	assert_false((world.get("routes", []) as Array).is_empty(), "abstract map has routes")
	for raw_route in world.get("routes", []):
		var route: Dictionary = raw_route
		assert_contains(route, "template", "every route carries template metadata")
		var template: Dictionary = route["template"]
		if template.is_empty():
			continue
		assert_contains(route_ids, template.get("id"), "route template id is a registered template")
		assert_contains(route, "a", "route keeps its 'a' endpoint")
		assert_contains(route, "b", "route keeps its 'b' endpoint")
		assert_contains(ports, route["a"], "route endpoint a is a port id")
		assert_contains(ports, route["b"], "route endpoint b is a port id")


func test_missing_map_config_falls_back_to_available_map_config() -> void:
	var result := _create(5150, START_PROFILE_NO_MAP_CONFIG)
	var data := _ok_data(result, "campaign without explicit map_config")
	var state := _state(result)
	assert_eq(String((data.get("map_config") as ContentDefinition).id), MAP_CONFIG_ID, "fallback map config is resolved")
	assert_eq(String(state.world().get("map_config_id", "")), MAP_CONFIG_ID, "fallback id is written to state.world")
	assert_eq(String(state.campaign_setup().get("map_config_id", "")), MAP_CONFIG_ID, "fallback id is written to campaign.setup")


func test_missing_start_profile_returns_structured_error() -> void:
	var result := CampaignFactory.create_campaign(_context(), "test:start_profile/missing", 1)
	assert_false(bool(result.get("ok", true)), "unknown start profile fails")
	assert_eq(String(result.get("error_code", "")), "no_start_profile", "error code is no_start_profile")
	assert_false(String(result.get("message_key", "")).is_empty(), "failure carries a message key")
	assert_true(result.get("data") is Dictionary, "failure data is a dictionary")
	assert_true(result.get("events") is Array, "failure events is an array")

	var empty := CampaignFactory.create_campaign(_context(), "", 1)
	assert_false(bool(empty.get("ok", true)), "empty start profile id fails")
	assert_eq(String(empty.get("error_code", "")), "no_start_profile", "empty id uses the same error code")


func test_missing_world_profile_returns_structured_error() -> void:
	var result := _create(6161, START_PROFILE_MISSING_WORLD)
	assert_false(bool(result.get("ok", true)), "start profile without a resolvable world profile fails")
	assert_eq(String(result.get("error_code", "")), "no_world_profile", "error code is no_world_profile")
	assert_false(String(result.get("message_key", "")).is_empty(), "failure carries a message key")


func test_missing_map_config_or_build_reference_returns_structured_error() -> void:
	var missing_map := _create(7171, START_PROFILE_MISSING_MAP_CONFIG)
	assert_false(bool(missing_map.get("ok", true)), "explicit missing map_config fails")
	assert_eq(String(missing_map.get("error_code", "")), "unknown_map_config", "error code is unknown_map_config")

	var missing_build := _create(8181, START_PROFILE_MISSING_BUILD)
	assert_false(bool(missing_build.get("ok", true)), "missing starting build fails")
	assert_eq(String(missing_build.get("error_code", "")), "no_starting_build", "error code is no_starting_build")


func test_tutorial_branch_initializes_story_state() -> void:
	var result := _create(9191, START_PROFILE_ID, true)
	var state := _state(result)
	assert_true(state.data.has("story"), "tutorial=true calls StoryService.begin (story block exists)")
	var story: Dictionary = state.story()
	assert_true(bool(story.get("completed", false)), "missing story config leaves the tutorial completed")
	assert_false(bool(story.get("active", true)), "missing story config does not activate the flow")
	assert_true(Array(story.get("unlocked_features", [])).has(StoryService.FEATURE_MARKET), "features unlock without a story flow")
	assert_false(state.contracts().get("main") != null, "tutorial runs do not auto-accept the legacy main contract")


func test_faction_reputation_and_attitude_are_derived_from_content() -> void:
	var result := _create(31337)
	var state := _state(result)
	var factions: Dictionary = state.campaign_factions()
	assert_eq(factions.size(), FACTION_COUNT, "all synthetic factions are instantiated")
	# start_profile.starting_reputation = 10 on top of each definition's value.
	assert_eq(int((factions["test:faction/merchants"] as Dictionary).get("reputation", 0)), 15, "merchant reputation = base + faction")
	assert_eq(int((factions["test:faction/navy"] as Dictionary).get("reputation", 0)), 10, "navy reputation = base + faction")
	assert_eq(int((factions["test:faction/pirates"] as Dictionary).get("reputation", 0)), 0, "pirate reputation = base + faction")
	for faction_id in factions.keys():
		assert_eq(String((factions[faction_id] as Dictionary).get("attitude", "")), "neutral", "start reputations are neutral")
		assert_false(bool((factions[faction_id] as Dictionary).get("discovered", true)), "factions start undiscovered")
	# Attitude derivation covers every band.
	assert_eq(FactionAssembler.attitude_for(-50, {"hostile_below": -30, "friendly_at": 30}), "hostile", "below threshold is hostile")
	assert_eq(FactionAssembler.attitude_for(0, {"hostile_below": -30, "friendly_at": 30}), "neutral", "middle band is neutral")
	assert_eq(FactionAssembler.attitude_for(45, {"hostile_below": -30, "friendly_at": 30}), "friendly", "above threshold is friendly")
	assert_eq(FactionAssembler.attitude_for(0, {}), "neutral", "missing thresholds fall back to neutral")
