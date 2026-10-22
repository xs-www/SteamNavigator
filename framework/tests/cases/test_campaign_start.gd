extends TestCase
## @static-doc
## 作用：Phase B B3 运行时接线的无头测试：`run.start` 的 1.0 legacy 路径零变化、
## 可选 `start_profile` 走 `CampaignFactory` 的 v2 路径、`campaign.view` 形状稳定、
## `campaign.setup` / `campaign.world.regions|sites` / `campaign.factions` 新字段的
## 惰性默认，以及 `ContentRefs.map_config` 对 1.0 / v2 两种 state 的解析。
##
## - 关键依赖：`bootstrap_core()`、`RunStartCommand`、`CampaignFactory`、
##   `CampaignViewQuery`、`ContentRefs`、`StoryService.config()`、
##   `ExplorationRules.read()`、`test_campaign_assembly.gd` 的合成 v2 fixture
##
## ## 契约与约束
## - 1.0 legacy 用例只断言「仍能开局 + 旧 header 不变 + map_profile 解析不变」，
##   不锁 1.0 state 的完整 hash（新分区默认块会按设计惰性出现）。
## - v2 用例不依赖 B4 core 内容：优先复用 B3-A 测试文件的 public 合成 fixture；
##   fixture 不存在时用例失败并给出明确原因，而不是伪造通过。
## - resolver 用例只用公开入口（`ContentRefs` / `StoryService.config` /
##   `ExplorationRules.read`），不直接摸私有 `_profile` 辅助函数。
## @end-static-doc

const LEGACY_BUILD := "core:starting_build/steady"
const LEGACY_PROFILE := "core:map_profile/standard"
const LEGACY_PROFILE_DEF := "test:map_profile/legacy"
const V2_MAP_CONFIG_DEF := "test:map_config/v2"
const ASSEMBLY_SUITE := "res://framework/tests/cases/test_campaign_assembly.gd"


func _directory() -> String:
	return "user://test_saves/campaign_start_%d" % Time.get_ticks_usec()


func _cleanup(directory: String) -> void:
	var files := DirAccess.get_files_at(directory)
	if files != null:
		for file_name in files:
			DirAccess.remove_absolute(directory + "/" + file_name)
	DirAccess.remove_absolute(directory)


## Synthetic content definition (no schema validation: this is a runtime fixture).
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


## Copies the frozen core registries into a fresh hub and appends synthetic defs.
func _hub_with(context: AppContext, extra: Array) -> RegistryHub:
	var hub := RegistryHub.new(ContentTypes.all())
	for content_type in ContentTypes.all():
		for definition in context.registries.get_all(content_type):
			hub.register(definition)
	for definition in extra:
		hub.register(definition)
	hub.freeze_all()
	return hub


## Minimal 1.0-style state: world ids + player so queries have a run to read.
func _state_with_world(world_ids: Dictionary) -> GameState:
	var world := {
		"ports": {},
		"routes": [],
		"current_port_id": "",
		"map_profile_id": String(world_ids.get("map_profile_id", "")),
	}
	if world_ids.has("map_config_id"):
		world["map_config_id"] = String(world_ids["map_config_id"])
	if world_ids.has("world_profile_id"):
		world["world_profile_id"] = String(world_ids["world_profile_id"])
	if world_ids.has("start_profile_id"):
		world["start_profile_id"] = String(world_ids["start_profile_id"])
	return GameState.new({
		"schema_version": GameState.SCHEMA_VERSION,
		"run": {"seed": 123, "game_time": 0.0, "starting_build": LEGACY_BUILD},
		"player": {"money": 100, "reputation": 0, "unlocks": [], "debt": null},
		"world": world,
	})


func _map_config_data(state: GameState, hub: RegistryHub) -> Dictionary:
	return ContentRefs.map_config_data(state, hub)


# ---------------------------------------------------------------------------
# 1.0 legacy path
# ---------------------------------------------------------------------------


func test_legacy_run_start_keeps_shape_and_save_header() -> void:
	var directory := _directory()
	var boot := bootstrap_core({"save_directory": directory})
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"build_id": LEGACY_BUILD, "seed": 12345})
	assert_true(bool(started.get("ok", false)), "legacy run.start succeeds: %s" % str(started))
	var state: GameState = context.state
	var world := state.world()
	assert_eq(String(world.get("map_profile_id", "")), LEGACY_PROFILE, "legacy run keeps the 1.0 map profile id")
	assert_eq(String(world.get("map_config_id", "")), "", "legacy run leaves map_config_id empty")
	assert_eq(String(world.get("start_profile_id", "")), "", "legacy run leaves start_profile_id empty")
	assert_eq(String(world.get("world_profile_id", "")), "", "legacy run leaves world_profile_id empty")
	assert_eq(state.schema_version(), GameState.SCHEMA_VERSION, "state_schema is unchanged")
	var setup := state.campaign_setup()
	for key in GameState.CAMPAIGN_SECTION_DEFAULTS["setup"].keys():
		assert_true(setup.has(key), "legacy state gets the lazy setup key: %s" % key)
	assert_eq(String(setup.get("map_config_id", "")), "", "legacy setup has no map config id")
	assert_true(Array(state.campaign_world().get("regions", [])).is_empty(), "legacy world has no regions")
	assert_true(Array(state.campaign_world().get("sites", [])).is_empty(), "legacy world has no sites")
	var payload: Dictionary = Array(started.get("events", []))[0]["payload"]
	assert_eq(String(payload.get("map_profile", "")), LEGACY_PROFILE, "run.started keeps map_profile")
	assert_eq(String(payload.get("start_profile", "")), "", "run.started start_profile is empty on 1.0")
	assert_eq(String(payload.get("world_profile", "")), "", "run.started world_profile is empty on 1.0")
	assert_eq(String(payload.get("map_config", "")), "", "run.started map_config is empty on 1.0")

	var saved := context.save.save_slot("legacy", state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "legacy save succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("legacy")
	assert_true(bool(loaded.get("ok", false)), "legacy save loads: %s" % str(loaded))
	var header: Dictionary = loaded["header"]
	assert_eq(String(header.get("save_schema", "")), SaveService.SAVE_SCHEMA, "save header schema unchanged")
	assert_eq(String(header.get("state_schema", "")), GameState.SCHEMA_VERSION, "save header state schema unchanged")
	assert_eq(String(header.get("content_schema", "")), FrameworkInfo.CONTENT_SCHEMA, "save header content schema unchanged")
	_cleanup(directory)


# ---------------------------------------------------------------------------
# campaign.view shape (no run / 1.0 run / v2-shaped state)
# ---------------------------------------------------------------------------


func _assert_campaign_view_shape(view: Dictionary, label: String) -> void:
	for key in ["setup", "regions", "sites", "factions", "codex", "exploration"]:
		assert_true(view.has(key), "%s campaign.view exposes %s" % [label, key])
	assert_true(view["setup"] is Dictionary, "%s setup is a dictionary" % label)
	assert_true(view["regions"] is Array, "%s regions is an array" % label)
	assert_true(view["sites"] is Array, "%s sites is an array" % label)
	assert_true(view["factions"] is Dictionary, "%s factions is a dictionary" % label)
	assert_true(view["codex"] is Dictionary, "%s codex is a dictionary" % label)
	assert_true(view["exploration"] is Dictionary, "%s exploration is a dictionary" % label)
	var exploration: Dictionary = view["exploration"]
	assert_true(exploration.get("rules", null) is Dictionary, "%s exploration.rules is a dictionary" % label)
	assert_true(exploration.get("clues", null) is Dictionary, "%s exploration.clues is a dictionary" % label)


func test_campaign_view_is_shape_stable() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var empty := context.queries.execute(&"campaign.view")
	assert_true(bool(empty.get("ok", false)), "campaign.view answers before a run: %s" % str(empty))
	var empty_view: Dictionary = empty["data"]
	assert_false(bool(empty_view.get("has_run", true)), "no run is reported")
	_assert_campaign_view_shape(empty_view, "empty")

	var started := context.commands.execute(&"run.start", {"build_id": LEGACY_BUILD, "seed": 5150})
	assert_true(bool(started.get("ok", false)), "legacy run starts: %s" % str(started))
	var legacy := context.queries.execute(&"campaign.view")
	assert_true(bool(legacy.get("ok", false)), "campaign.view answers on a legacy run: %s" % str(legacy))
	var legacy_view: Dictionary = legacy["data"]
	assert_true(bool(legacy_view.get("has_run", false)), "legacy run is reported")
	assert_false(bool(legacy_view.get("is_v2", true)), "legacy run is not v2")
	_assert_campaign_view_shape(legacy_view, "legacy")
	assert_eq(String((legacy_view["setup"] as Dictionary).get("start_profile_id", "")), "", "legacy setup has no start profile")
	assert_true(legacy_view["regions"] is Array and (legacy_view["regions"] as Array).is_empty(), "legacy view has no regions")


func test_campaign_view_reads_v2_sections() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var state := GameState.new({
		"schema_version": GameState.SCHEMA_VERSION,
		"run": {"seed": 9001, "game_time": 3.0, "starting_build": LEGACY_BUILD},
		"player": {"money": 500, "reputation": 10, "unlocks": [], "debt": null},
		"world": {
			"ports": {},
			"routes": [],
			"current_port_id": "port_0",
			"map_profile_id": "",
			"map_config_id": V2_MAP_CONFIG_DEF,
			"world_profile_id": "test:world_profile/default",
			"start_profile_id": "test:start_profile/standard",
		},
		"campaign": {
			"id": "campaign_9001",
			"name": "Steam Navigator",
			"created_at": "",
			"difficulty": "standard",
			"status": "active",
			"playtime_hours": 0.0,
			"setup": {
				"start_profile_id": "test:start_profile/standard",
				"world_profile_id": "test:world_profile/default",
				"map_config_id": V2_MAP_CONFIG_DEF,
				"starting_build_id": LEGACY_BUILD,
				"difficulty": "standard",
				"seed": 9001,
				"content_versions": {"map_configs": "2.0"},
			},
			"world": {
				"profile_id": "test:world_profile/default",
				"generated": true,
				"regions": [{"id": "region_0", "kind": "coastal", "port_ids": ["port_0"]}],
				"sites": [{"id": "site_0", "definition_id": "test:site/ruin", "region_id": "region_0", "discovered": false}],
				"visited_region_ids": ["region_0"],
				"discovered_site_ids": [],
				"visited_port_ids": ["port_0"],
			},
			"codex": {"discovered_ids": [], "entries": {}},
			"factions": {"test:faction/guild": {"reputation": 12}},
		},
	})
	context.set_state(state)
	var result := context.queries.execute(&"campaign.view")
	assert_true(bool(result.get("ok", false)), "campaign.view reads a v2 state: %s" % str(result))
	var view: Dictionary = result["data"]
	_assert_campaign_view_shape(view, "v2")
	assert_true(bool(view.get("is_v2", false)), "v2 state is reported as v2")
	assert_eq(String((view["setup"] as Dictionary).get("start_profile_id", "")), "test:start_profile/standard", "setup keeps the start profile id")
	assert_eq((view["regions"] as Array).size(), 1, "regions are exposed")
	assert_eq((view["sites"] as Array).size(), 1, "sites are exposed")
	assert_eq(String(((view["sites"] as Array)[0] as Dictionary).get("definition_id", "")), "test:site/ruin", "site definition id is exposed")
	var faction: Dictionary = (view["factions"] as Dictionary).get("test:faction/guild", {})
	assert_eq(int(faction.get("reputation", 0)), 12, "faction reputation is exposed")
	for key in GameState.FACTION_ENTRY_DEFAULTS.keys():
		assert_true(faction.has(key), "faction entry backfills %s" % key)


# ---------------------------------------------------------------------------
# resolver: 1.0 map_profile fallback vs v2 map_config
# ---------------------------------------------------------------------------


func test_content_refs_resolves_legacy_and_v2_definitions() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var legacy_definition := _definition(LEGACY_PROFILE_DEF, ContentTypes.MAP_PROFILE, {
		"trade_margin": 0.2,
		"exploration": {"fog_vision_ratio": 0.11},
		"story": {"enabled": true, "flow_id": "legacy_flow", "stages": []},
	})
	var v2_definition := _definition(V2_MAP_CONFIG_DEF, ContentTypes.MAP_CONFIG, {
		"trade_margin": 0.35,
		"exploration": {"fog_vision_ratio": 0.22},
		"story": {"enabled": true, "flow_id": "v2_flow", "stages": []},
	})
	var hub := _hub_with(context, [legacy_definition, v2_definition])

	var legacy_state := _state_with_world({"map_profile_id": LEGACY_PROFILE_DEF})
	var legacy_resolved := ContentRefs.map_config(legacy_state, hub)
	assert_not_null(legacy_resolved, "legacy state resolves a definition")
	assert_eq(legacy_resolved.content_type, ContentTypes.MAP_PROFILE, "legacy state resolves the map_profiles fallback")
	assert_eq(String(legacy_resolved.id), LEGACY_PROFILE_DEF, "legacy state resolves the legacy id")
	assert_false(ContentRefs.is_v2_campaign(legacy_state), "legacy state is not a v2 campaign")
	assert_almost_eq(float(_map_config_data(legacy_state, hub).get("trade_margin", 0.0)), 0.2, 0.0001,
		"legacy resolver data comes from map_profiles")

	var v2_state := _state_with_world({"map_profile_id": LEGACY_PROFILE_DEF, "map_config_id": V2_MAP_CONFIG_DEF})
	var v2_resolved := ContentRefs.map_config(v2_state, hub)
	assert_not_null(v2_resolved, "v2 state resolves a definition")
	assert_eq(v2_resolved.content_type, ContentTypes.MAP_CONFIG, "v2 state resolves map_configs first")
	assert_eq(String(v2_resolved.id), V2_MAP_CONFIG_DEF, "v2 state resolves the map config id")
	assert_true(ContentRefs.is_v2_campaign(v2_state), "v2 state is reported as v2")
	assert_almost_eq(float(_map_config_data(v2_state, hub).get("trade_margin", 0.0)), 0.35, 0.0001,
		"v2 resolver data comes from map_configs, not the legacy fallback")

	# Unknown v2 id still falls back to the old map_profiles definition.
	var unknown_state := _state_with_world({"map_profile_id": LEGACY_PROFILE_DEF, "map_config_id": "test:map_config/missing"})
	var unknown_resolved := ContentRefs.map_config(unknown_state, hub)
	assert_not_null(unknown_resolved, "unknown map config falls back to the legacy profile")
	assert_eq(unknown_resolved.content_type, ContentTypes.MAP_PROFILE, "unknown map config uses the 1.0 fallback")

	# Neither id set: no scenario definition, callers use their own defaults.
	var bare_state := _state_with_world({})
	assert_true(ContentRefs.map_config(bare_state, hub) == null, "bare state resolves no scenario definition")
	assert_true(_map_config_data(bare_state, hub).is_empty(), "bare state reads empty scenario data")


func test_real_resolvers_use_the_1_0_fallback() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var legacy_definition := _definition(LEGACY_PROFILE_DEF, ContentTypes.MAP_PROFILE, {
		"trade_margin": 0.2,
		"exploration": {"fog_vision_ratio": 0.11},
		"story": {"enabled": true, "flow_id": "legacy_flow", "stages": []},
	})
	var v2_definition := _definition(V2_MAP_CONFIG_DEF, ContentTypes.MAP_CONFIG, {
		"trade_margin": 0.35,
		"exploration": {"fog_vision_ratio": 0.22},
		"story": {"enabled": true, "flow_id": "v2_flow", "stages": []},
	})
	var hub := _hub_with(context, [legacy_definition, v2_definition])

	# StoryService.config() is a real runtime resolver: 1.0 must still read the
	# story block out of the legacy map_profiles definition (D13 moved v2 only).
	var legacy_state := _state_with_world({"map_profile_id": LEGACY_PROFILE_DEF})
	assert_eq(String(StoryService.config(legacy_state, hub).get("flow_id", "")), "legacy_flow",
		"StoryService keeps reading the 1.0 story block")
	var rules_1_0 := ExplorationRules.read(legacy_state, hub)
	assert_almost_eq(float(rules_1_0.get("fog_vision_ratio", 0.0)), 0.11, 0.0001,
		"ExplorationRules keeps reading the 1.0 exploration block")

	var v2_state := _state_with_world({"map_profile_id": LEGACY_PROFILE_DEF, "map_config_id": V2_MAP_CONFIG_DEF})
	assert_eq(String(StoryService.config(v2_state, hub).get("flow_id", "")), "v2_flow",
		"StoryService reads the v2 map_configs story block")
	var rules_v2 := ExplorationRules.read(v2_state, hub)
	assert_almost_eq(float(rules_v2.get("fog_vision_ratio", 0.0)), 0.22, 0.0001,
		"ExplorationRules reads the v2 map_configs exploration block")


# ---------------------------------------------------------------------------
# v2 entry point: run.start start_profile -> CampaignFactory
# ---------------------------------------------------------------------------


## Reuses B3-A's synthetic fixture (single source of truth for minimal v2 content).
## Returns {context, start_profile_id} or an empty dictionary when unavailable.
func _campaign_fixture() -> Dictionary:
	if not ResourceLoader.exists(ASSEMBLY_SUITE):
		return {}
	var suite: Variant = load(ASSEMBLY_SUITE).new()
	if suite == null:
		return {}
	for method in ["build_synthetic_context", "synthetic_start_profile_id"]:
		if not suite.has_method(method):
			return {}
	var fixture_context: AppContext = suite.call("build_synthetic_context")
	if fixture_context == null:
		return {}
	return {
		"context": fixture_context,
		"start_profile_id": String(suite.call("synthetic_start_profile_id")),
	}


func test_run_start_with_start_profile_creates_v2_campaign() -> void:
	var fixture := _campaign_fixture()
	if fixture.is_empty():
		fail("B3-A CampaignFactory fixture is not available (%s); v2 run.start path not verified" % ASSEMBLY_SUITE)
		return
	var context: AppContext = fixture["context"]
	var start_profile_id := String(fixture["start_profile_id"])
	assert_false(start_profile_id.is_empty(), "B3-A fixture exposes a start profile id")
	var started := context.commands.execute(&"run.start", {"start_profile": start_profile_id, "seed": 31337})
	assert_true(bool(started.get("ok", false)), "v2 run.start succeeds: %s" % str(started))
	assert_true(context.has_run(), "v2 run.start commits a state")
	var state: GameState = context.state
	var setup := state.campaign_setup()
	assert_eq(String(setup.get("start_profile_id", "")), start_profile_id, "campaign.setup records the start profile")
	assert_false(String(setup.get("world_profile_id", "")).is_empty(), "campaign.setup records the world profile")
	assert_false(String(setup.get("map_config_id", "")).is_empty(), "campaign.setup records the map config")
	assert_false(String(setup.get("starting_build_id", "")).is_empty(), "campaign.setup records the starting build")
	assert_eq(int(setup.get("seed", 0)), 31337, "campaign.setup records the run seed")
	assert_true(setup.get("content_versions", null) is Dictionary, "campaign.setup snapshots content versions")
	var world := state.world()
	assert_eq(String(world.get("start_profile_id", "")), start_profile_id, "state.world records start_profile_id")
	assert_false(String(world.get("world_profile_id", "")).is_empty(), "state.world records world_profile_id")
	assert_false(String(world.get("map_config_id", "")).is_empty(), "state.world records map_config_id")
	assert_eq(String(world.get("map_profile_id", "")), "", "v2 campaigns leave map_profile_id empty")
	var payload: Dictionary = Array(started.get("events", []))[0]["payload"]
	assert_eq(String(payload.get("start_profile", "")), start_profile_id, "run.started reports the start profile")
	assert_false(String(payload.get("map_config", "")).is_empty(), "run.started reports the map config")
	assert_eq(String(payload.get("map_profile", "")), "", "run.started map_profile is empty on v2")

	var view_result := context.queries.execute(&"campaign.view")
	assert_true(bool(view_result.get("ok", false)), "campaign.view answers after a v2 run: %s" % str(view_result))
	var view: Dictionary = view_result["data"]
	_assert_campaign_view_shape(view, "v2 run")
	assert_true(bool(view.get("is_v2", false)), "v2 run view is v2")
	assert_eq(String((view["setup"] as Dictionary).get("start_profile_id", "")), start_profile_id, "campaign.view exposes the setup")
	assert_false((view["regions"] as Array).is_empty(), "campaign.view exposes generated regions")
	assert_false((view["sites"] as Array).is_empty(), "campaign.view exposes generated sites")
