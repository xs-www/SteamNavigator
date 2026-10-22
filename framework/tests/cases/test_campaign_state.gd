extends TestCase
## CampaignState sections: lazy backfill, exploration progress and save round-trip.
##
## Sections hold runtime ids/primitives only. They are added per system so the
## persistent campaign can grow without reworking the whole state shape.

func _directory() -> String:
	return "user://test_saves/campaign_%d" % Time.get_ticks_usec()


func _cleanup(directory: String) -> void:
	var files := DirAccess.get_files_at(directory)
	if files != null:
		for file_name in files:
			DirAccess.remove_absolute(directory + "/" + file_name)
	DirAccess.remove_absolute(directory)


func test_sections_are_backfilled_lazily() -> void:
	var state := GameState.new({"schema_version": "2.0"})
	var campaign := state.campaign()
	for section_key in GameState.CAMPAIGN_SECTION_DEFAULTS.keys():
		assert_true(campaign.get(section_key, null) is Dictionary, "campaign section exists: %s" % section_key)
	assert_true(state.campaign_world().get("visited_region_ids") is Array, "world progress keeps an id list")
	assert_false(bool(state.campaign_world().get("generated", true)), "a bare state has not generated a world yet")
	assert_true(state.campaign_codex().get("discovered_ids") is Array, "codex keeps a discovery list")
	assert_eq(state.campaign_factions().size(), 0, "factions start empty")


func test_world_progress_tracking() -> void:
	var state := GameState.new({"schema_version": "2.0", "run": {"seed": 7}})
	assert_false(state.is_region_visited("core:region/north"), "regions start unvisited")
	assert_true(state.mark_region_visited("core:region/north"), "first visit records the region")
	assert_false(state.mark_region_visited("core:region/north"), "a repeat visit is not recorded twice")
	assert_true(state.is_region_visited("core:region/north"), "visited region is visible")
	assert_false(state.mark_region_visited(""), "empty ids are ignored")
	assert_true(state.mark_port_visited("core:port/iron_harbor"), "port visit is recorded")
	assert_false(state.is_port_visited("core:port/elsewhere"), "unvisited ports stay hidden")
	assert_true(state.discover_site("core:site/boiler_works"), "site discovery is recorded")
	assert_false(state.discover_site("core:site/boiler_works"), "site discovery is idempotent")
	assert_false(state.is_site_discovered("core:site/untouched"), "undiscovered sites stay hidden")
	var world := state.campaign_world()
	assert_eq(Array(world["visited_region_ids"]).size(), 1, "regions are stored once")
	assert_eq(Array(world["visited_port_ids"]).size(), 1, "ports are stored once")
	assert_eq(Array(world["discovered_site_ids"]).size(), 1, "sites are stored once")


func test_codex_discovery_is_idempotent() -> void:
	var state := GameState.new({"schema_version": "2.0"})
	assert_true(state.discover_codex("core:discovery/boiler_blueprint"), "first codex entry unlocks")
	assert_false(state.discover_codex("core:discovery/boiler_blueprint"), "the same entry is not unlocked twice")
	assert_false(state.discover_codex(""), "empty ids are ignored")
	assert_true(state.is_codex_discovered("core:discovery/boiler_blueprint"), "codex entry is readable")
	assert_eq(Array(state.campaign_codex()["discovered_ids"]).size(), 1, "codex stores one entry")


func test_faction_reputation_is_clamped() -> void:
	var state := GameState.new({"schema_version": "2.0"})
	assert_eq(state.faction_reputation("core:faction/guild"), 0, "unknown factions are neutral")
	state.set_faction_reputation("core:faction/guild", 40)
	assert_eq(state.faction_reputation("core:faction/guild"), 40, "reputation is stored")
	state.set_faction_reputation("core:faction/guild", 500)
	assert_eq(state.faction_reputation("core:faction/guild"), 100, "reputation clamps at the top")
	state.set_faction_reputation("core:faction/guild", -500)
	assert_eq(state.faction_reputation("core:faction/guild"), -100, "reputation clamps at the bottom")
	state.set_faction_reputation("", 10)
	assert_eq(state.campaign_factions().size(), 1, "empty faction ids are ignored")


func test_campaign_sections_round_trip_through_save() -> void:
	var directory := _directory()
	var boot := bootstrap_core({"save_directory": directory})
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 5150})
	assert_true(bool(start["ok"]), "run starts: %s" % str(start))
	assert_true(bool(context.state.campaign_world().get("generated", false)), "a new run marks the world generated")
	context.state.mark_region_visited("core:region/north")
	context.state.discover_site("core:site/boiler_works")
	context.state.discover_codex("core:discovery/boiler_blueprint")
	context.state.set_faction_reputation("core:faction/guild", 42)
	var before := context.state.hash()
	var saved := context.save.save_slot("manual", context.state, context.save_meta())
	assert_true(bool(saved["ok"]), "save succeeds: %s" % str(saved))
	var loaded: GameState = context.save.load_slot("manual")["state"]
	assert_eq(loaded.hash(), before, "campaign sections round-trip byte for byte")
	assert_true(loaded.is_region_visited("core:region/north"), "region progress survives load")
	assert_true(loaded.is_site_discovered("core:site/boiler_works"), "site progress survives load")
	assert_true(loaded.is_codex_discovered("core:discovery/boiler_blueprint"), "codex survives load")
	assert_eq(loaded.faction_reputation("core:faction/guild"), 42, "faction reputation survives load")
	assert_true(bool(loaded.campaign_world().get("generated", false)), "generated flag survives load")
	_cleanup(directory)
