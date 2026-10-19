extends TestCase
## Save Schema 2.0 migration: v1 payloads load as persistent campaign states.

func _directory() -> String:
	return "user://test_saves/migration_%d" % Time.get_ticks_usec()


func _cleanup(directory: String) -> void:
	var files := DirAccess.get_files_at(directory)
	if files != null:
		for file_name in files:
			DirAccess.remove_absolute(directory + "/" + file_name)
	DirAccess.remove_absolute(directory)


func _write_payload(directory: String, slot: String, payload: Dictionary) -> String:
	var path := "%s/%s.json" % [directory, slot]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JsonUtils.canonical_stringify(payload, "\t"))
	file.close()
	return path


func _legacy_payload() -> Dictionary:
	return {
		"save_schema": "1.0",
		"framework_version": "0.1.0",
		"mod_api_version": "1.0",
		"content_schema": "1.0",
		"created_at": "2026-01-01T00:00:00",
		"seed": 4242,
		"mods": [],
		"meta": {},
		"state": {
			"schema_version": "1.0",
			"run": {
				"seed": 4242,
				"game_time": 12.5,
				"started_at": "2026-01-01T00:00:00",
			},
			"player": {"money": 500},
			"world": {"current_port_id": "core:port_archetype/iron_harbor"},
			"ship": {"hull_id": "core:hull/small_efficient"},
		},
	}


func test_v1_save_migrates_to_v2_campaign() -> void:
	var directory := _directory()
	var service := SaveService.new(null, directory)
	_write_payload(directory, "legacy", _legacy_payload())
	var loaded := service.load_slot("legacy")
	assert_true(bool(loaded["ok"]), "v1 save loads: %s" % String(loaded.get("error", "")))
	var state: GameState = loaded["state"]
	assert_eq(state.schema_version(), "2.0", "state schema upgraded")
	var campaign := state.campaign()
	assert_eq(String(campaign.get("id", "")), "campaign_4242", "campaign id derives from seed")
	assert_eq(String(campaign.get("created_at", "")), "2026-01-01T00:00:00", "campaign keeps creation time")
	assert_almost_eq(float(campaign.get("playtime_hours", 0.0)), 12.5, 1e-9, "playtime seeded from run time")
	assert_true(campaign.get("world", null) is Dictionary, "campaign world section is backfilled")
	assert_false(bool(state.campaign_world().get("generated", true)), "a migrated run has no generated world yet")
	assert_true(state.ship().has("module_instances"), "legacy ship gets a module instance table on load")
	assert_false(ShipModules.has_slot(state.ship(), "boiler"), "a legacy ship without a boiler has no boiler instance")
	var header: Dictionary = loaded["header"]
	assert_eq(String(header.get("save_schema", "")), "2.0", "migrated header uses save schema 2.0")
	assert_eq(String(header.get("migrated_from", "")), "1.0", "header records the source schema")
	assert_true(bool(loaded["migrated"]), "load reports migration")
	_cleanup(directory)


func test_v2_save_round_trips_campaign_without_migration() -> void:
	var directory := _directory()
	var service := SaveService.new(null, directory)
	var state := GameState.from_dict({
		"schema_version": "2.0",
		"campaign": {
			"id": "campaign_99",
			"name": "Test Campaign",
			"created_at": "2026-02-02T00:00:00",
			"difficulty": "standard",
			"status": "active",
			"playtime_hours": 3.0,
		},
		"run": {"seed": 99, "game_time": 3.0},
		"player": {"money": 10},
	})
	state.ensure_campaign()
	var saved := service.save_slot("modern", state, {"mods": []})
	assert_true(bool(saved["ok"]), "v2 save writes: %s" % String(saved.get("error", "")))
	var loaded := service.load_slot("modern")
	assert_true(bool(loaded["ok"]), "v2 save loads")
	assert_false(bool(loaded["migrated"]), "v2 save does not report migration")
	var header: Dictionary = loaded["header"]
	assert_eq(String(header.get("save_schema", "")), "2.0", "header schema")
	assert_eq(String(header.get("state_schema", "")), "2.0", "header state schema")
	assert_eq(String(header.get("content_schema", "")), FrameworkInfo.CONTENT_SCHEMA, "header content schema")
	assert_eq(String(header.get("migrated_from", "")), "", "no migration source")
	var loaded_state: GameState = loaded["state"]
	assert_eq(loaded_state.hash(), state.hash(), "campaign state hash round-trips")
	_cleanup(directory)


func test_missing_campaign_is_backfilled_in_v2_payload() -> void:
	var directory := _directory()
	var service := SaveService.new(null, directory)
	var payload := _legacy_payload()
	payload["save_schema"] = "2.0"
	payload["state"]["schema_version"] = "2.0"
	payload["state"].erase("campaign")
	_write_payload(directory, "partial", payload)
	var loaded := service.load_slot("partial")
	assert_true(bool(loaded["ok"]), "v2 payload without campaign loads")
	var state: GameState = loaded["state"]
	assert_eq(String(state.campaign().get("id", "")), "campaign_4242", "campaign backfilled from seed")
	assert_true(Array(loaded.get("migration_warnings", [])).size() > 0, "backfill reports a warning")
	_cleanup(directory)


func test_unsupported_save_schema_is_rejected() -> void:
	var directory := _directory()
	var service := SaveService.new(null, directory)
	var payload := _legacy_payload()
	payload["save_schema"] = "3.0"
	_write_payload(directory, "future", payload)
	var loaded := service.load_slot("future")
	assert_false(bool(loaded["ok"]), "unsupported save schema is rejected")
	assert_contains(String(loaded.get("error", "")), "unsupported", "error names the schema problem")
	_cleanup(directory)
