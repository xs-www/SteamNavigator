extends TestCase
## @static-doc
## 作用：C4 开局入口测试：`run.start` 的默认路径（无 start_profile）与显式 start_profile
## 路径都经 `CampaignFactory` 装配；`port_templates` / `starting_scenarios` / `map_configs`
## 是唯一内容来源，`map_profiles` 退役且 `ContentRefs` 不再回退；`campaign.view` 形状稳定；
## 存档 header 不变。
##
## - 关键依赖：`bootstrap_core()`、`CampaignFactory.create_default_campaign`、
##   `ContentRefs`、`StoryService.config()`、`ExplorationRules.read()`、`GameState`
##
## ## 契约与约束
## - C4 起没有 1.0「build + map_profile」路径：无 `start_profile` 时使用最低 id 的 start
##   profile（内容用 `start.standard` tag 声明，core 为 standard 档案）+ 可选 `starting_scenario` 覆盖。
## - `data.run` / `state.world` / `campaign.setup` 只记 `starting_scenario(_id)`，不再有
##   `map_profile_id` / `starting_build` 字段。
## - resolver 用例只用公开入口（`ContentRefs` / `StoryService.config` /
##   `ExplorationRules.read`），不依赖 dev_mods/core 之外的内容。
## @end-static-doc

const STEADY_SCENARIO := "core:starting_scenario/steady"
const SWIFT_SCENARIO := "core:starting_scenario/swift"
const STANDARD_PROFILE := "core:start_profile/standard"
const HARD_PROFILE := "core:start_profile/hard"
const CORE_MAP_CONFIG := "core:map_config/standard"
const TEST_MAP_CONFIG := "test:map_config/cfg"


func _definition(id: String, content_type: StringName, data: Dictionary) -> ContentDefinition:
	var definition := ContentDefinition.new()
	definition.id = id
	definition.content_type = content_type
	definition.name_key = "%s.name" % id
	definition.enabled = true
	definition.source_mod = "test"
	definition.data = data.duplicate(true)
	definition.raw = {"id": id, "name_key": definition.name_key, "data": definition.data.duplicate(true)}
	return definition


func _hub_with(context: AppContext, extra: Array) -> RegistryHub:
	var hub := RegistryHub.new(ContentTypes.all())
	for content_type in ContentTypes.all():
		for definition in context.registries.get_all(content_type):
			hub.register(definition)
	for definition in extra:
		hub.register(definition)
	hub.freeze_all()
	return hub


func _state_with_world(world: Dictionary) -> GameState:
	return GameState.new({
		"schema_version": GameState.SCHEMA_VERSION,
		"run": {"seed": 123, "game_time": 0.0},
		"player": {"money": 100, "reputation": 0, "unlocks": [], "debt": null},
		"world": world,
	})


# ── default run.start (no start_profile) ──


func test_default_run_start_assembles_a_campaign() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY_SCENARIO, "seed": 12345})
	assert_true(bool(started.get("ok", false)), "default run.start succeeds: %s" % str(started))
	var state: GameState = context.state
	var world := state.world()
	assert_eq(String(world.get("starting_scenario_id", "")), STEADY_SCENARIO, "world records the selected scenario")
	assert_eq(String(world.get("map_config_id", "")), CORE_MAP_CONFIG, "world records the map config")
	assert_eq(String(world.get("start_profile_id", "")), STANDARD_PROFILE, "the default start profile is used")
	assert_false(world.has("map_profile_id"), "the retired map_profile_id is never written")
	assert_false(state.run().has("map_profile_id"), "the run block has no map_profile_id")
	assert_eq(String(state.run().get("starting_scenario", "")), STEADY_SCENARIO, "run.starting_scenario is written")
	var setup := state.campaign_setup()
	assert_eq(String(setup.get("start_profile_id", "")), STANDARD_PROFILE, "setup records the start profile")
	assert_eq(String(setup.get("starting_scenario_id", "")), STEADY_SCENARIO, "setup records the scenario")
	assert_eq(String(setup.get("map_config_id", "")), CORE_MAP_CONFIG, "setup records the map config")
	assert_true(setup.get("content_versions", null) is Dictionary, "setup snapshots content versions")
	assert_true(state.campaign_world().get("regions", []) is Array, "campaign world has regions")
	var payload: Dictionary = Array(started.get("events", []))[0]["payload"]
	assert_eq(String(payload.get("starting_scenario", "")), STEADY_SCENARIO, "run.started reports the scenario")
	assert_eq(String(payload.get("map_config", "")), CORE_MAP_CONFIG, "run.started reports the map config")
	assert_false(payload.has("map_profile"), "run.started no longer reports a map profile")


func test_default_scenario_and_scenario_override() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	# No starting_scenario: the default start profile's scenario (steady) is used.
	var defaulted := context.commands.execute(&"run.start", {"seed": 2468})
	assert_true(bool(defaulted.get("ok", false)), "run.start without a scenario succeeds: %s" % str(defaulted))
	assert_eq(String(context.state.world().get("starting_scenario_id", "")), STEADY_SCENARIO,
		"the start profile's default scenario is used")

	var hard_context: AppContext = bootstrap_core()["context"]
	var overridden := hard_context.commands.execute(&"run.start", {
		"start_profile": HARD_PROFILE,
		"starting_scenario": STEADY_SCENARIO,
		"seed": 1357,
	})
	assert_true(bool(overridden.get("ok", false)), "scenario override succeeds: %s" % str(overridden))
	assert_eq(String(hard_context.state.world().get("starting_scenario_id", "")), STEADY_SCENARIO,
		"the explicit scenario override wins over the profile default")
	assert_eq(String(hard_context.state.campaign_setup().get("difficulty", "")), "hard", "the profile difficulty is kept")
	assert_eq(hard_context.state.money(), 400, "the hard profile's starting money applies instead of the scenario money")


func test_save_header_is_unchanged() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY_SCENARIO, "seed": 6174})
	assert_true(bool(started.get("ok", false)), "run starts")
	var saved := context.save.save_slot("c4_header", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "save succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("c4_header")
	assert_true(bool(loaded.get("ok", false)), "save loads")
	var header: Dictionary = loaded["header"]
	assert_eq(String(header.get("save_schema", "")), SaveService.SAVE_SCHEMA, "save schema unchanged")
	assert_eq(String(header.get("state_schema", "")), GameState.SCHEMA_VERSION, "state schema unchanged")
	assert_eq(String(header.get("content_schema", "")), FrameworkInfo.CONTENT_SCHEMA, "content schema baseline unchanged")


# ── errors ──


func test_unknown_profile_or_scenario_returns_structured_errors() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var unknown_profile := context.commands.execute(&"run.start", {"start_profile": "test:start_profile/absent"})
	assert_false(bool(unknown_profile.get("ok", false)), "unknown start profile fails")
	assert_eq(String(unknown_profile.get("error_code", "")), "no_start_profile", "unknown profile error code")
	var unknown_scenario := context.commands.execute(&"run.start", {
		"start_profile": STANDARD_PROFILE,
		"starting_scenario": "test:starting_scenario/absent",
	})
	assert_false(bool(unknown_scenario.get("ok", false)), "unknown starting scenario fails")
	assert_eq(String(unknown_scenario.get("error_code", "")), "no_starting_scenario", "unknown scenario error code")


# ── retired types ──


func test_retired_types_are_not_registered() -> void:
	for retired in [&"map_profiles", &"port_archetypes", &"starting_builds"]:
		assert_false(ContentTypes.is_known(retired), "%s is no longer a known content type" % retired)
	assert_true(ContentTypes.is_known(ContentTypes.PORT_TEMPLATE), "port_templates is registered")
	assert_true(ContentTypes.is_known(ContentTypes.STARTING_SCENARIO), "starting_scenarios is registered")
	assert_false(ContentTypes.all().has(&"map_profiles"), "map_profiles is absent from ContentTypes.all()")


# ── campaign.view ──


func _assert_campaign_view_shape(view: Dictionary, label: String) -> void:
	for key in ["setup", "regions", "sites", "factions", "codex", "exploration"]:
		assert_true(view.has(key), "%s campaign.view exposes %s" % [label, key])
	assert_true(view["setup"] is Dictionary, "%s setup is a dictionary" % label)
	assert_true(view["regions"] is Array, "%s regions is an array" % label)
	assert_true(view["sites"] is Array, "%s sites is an array" % label)
	assert_true(view["factions"] is Dictionary, "%s factions is a dictionary" % label)
	assert_true(view["codex"] is Dictionary, "%s codex is a dictionary" % label)
	assert_true(view["exploration"] is Dictionary, "%s exploration is a dictionary" % label)


func test_campaign_view_is_shape_stable() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var empty := context.queries.execute(&"campaign.view")
	assert_true(bool(empty.get("ok", false)), "campaign.view answers before a run")
	assert_false(bool((empty["data"] as Dictionary).get("has_run", true)), "no run is reported")
	_assert_campaign_view_shape(empty["data"], "empty")

	var started := context.commands.execute(&"run.start", {"starting_scenario": SWIFT_SCENARIO, "seed": 4242})
	assert_true(bool(started.get("ok", false)), "run starts: %s" % str(started))
	var result := context.queries.execute(&"campaign.view")
	assert_true(bool(result.get("ok", false)), "campaign.view answers on a run")
	var view: Dictionary = result["data"]
	_assert_campaign_view_shape(view, "run")
	assert_true(bool(view.get("is_v2", false)), "the campaign binding is reported")
	assert_eq(String((view["setup"] as Dictionary).get("starting_scenario_id", "")), SWIFT_SCENARIO,
		"campaign.view exposes the starting scenario")
	assert_false((view["regions"] as Array).is_empty(), "campaign.view exposes generated regions")
	assert_false((view["sites"] as Array).is_empty(), "campaign.view exposes generated sites")


# ── resolver: map_config only (no map_profiles fallback) ──


func test_content_refs_reads_map_config_without_fallback() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var synthetic := _definition(TEST_MAP_CONFIG, ContentTypes.MAP_CONFIG, {
		"trade_margin": 0.35,
		"exploration": {"fog_vision_ratio": 0.22},
		"story": {"enabled": true, "flow_id": "cfg_flow", "stages": []},
	})
	var hub := _hub_with(context, [synthetic])

	var resolved_state := _state_with_world({"map_config_id": TEST_MAP_CONFIG})
	var resolved := ContentRefs.map_config(resolved_state, hub)
	assert_not_null(resolved, "a bound map_config_id resolves")
	assert_eq(resolved.content_type, ContentTypes.MAP_CONFIG, "the resolver reads map_configs")
	assert_eq(String(resolved.id), TEST_MAP_CONFIG, "the resolver returns the bound config")
	assert_almost_eq(float(ContentRefs.map_config_data(resolved_state, hub).get("trade_margin", 0.0)), 0.35, 0.0001,
		"map_config_data returns the config data")
	assert_true(ContentRefs.is_v2_campaign(resolved_state), "a bound run is a campaign")

	var bare := _state_with_world({})
	assert_true(ContentRefs.map_config(bare, hub) == null, "a bare state resolves no config")
	assert_true(ContentRefs.map_config_data(bare, hub).is_empty(), "a bare state reads empty config data")

	var unknown := _state_with_world({"map_config_id": "test:map_config/absent"})
	assert_true(ContentRefs.map_config(unknown, hub) == null, "an unknown map_config_id resolves to null")

	var legacy_only := _state_with_world({"map_profile_id": "test:map_profile/legacy"})
	assert_true(ContentRefs.map_config(legacy_only, hub) == null,
		"map_profiles retired: a legacy map_profile_id no longer resolves")
	assert_false(ContentRefs.is_v2_campaign(legacy_only), "a legacy-only state is not a campaign")


func test_real_resolvers_read_the_map_config() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var synthetic := _definition(TEST_MAP_CONFIG, ContentTypes.MAP_CONFIG, {
		"exploration": {"fog_vision_ratio": 0.22},
		"story": {"enabled": true, "flow_id": "cfg_flow", "stages": []},
	})
	var hub := _hub_with(context, [synthetic])
	var state := _state_with_world({"map_config_id": TEST_MAP_CONFIG})
	assert_eq(String(StoryService.config(state, hub).get("flow_id", "")), "cfg_flow",
		"StoryService reads the map config story block")
	assert_almost_eq(float(ExplorationRules.read(state, hub).get("fog_vision_ratio", 0.0)), 0.22, 0.0001,
		"ExplorationRules reads the map config exploration block")
