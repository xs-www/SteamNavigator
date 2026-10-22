extends TestCase
## @static-doc
## 作用：存档 Schema 2.0 迁移与内容版本表（B5）测试：v1 payload 升级、v2 往返、
## `campaign.setup.content_versions` 快照/推断/漂移警告，以及旧档不重排世界。
##
## ## 契约与约束
## - 1.0 payload 加载后 save_schema/state_schema → 2.0，campaign 元数据/分区回填，
##   缺表时用当前注册表补齐（C4 起 map_profiles 退役，不再做 1.0 类型推断）。
## - v2 缺失 `content_versions` 时加载补齐并产生 warning；已有版本与运行时不一致时
##   只产生 `content version drift` warning，存档仍可读。
## - 新存档必须写全 `ContentTypes.SCHEMA_VERSIONS` 快照；v2 战役的
##   `map_config_id` / `world_profile_id` / `start_profile_id` / `starting_scenario_id` 往返保持。
## - 同一存档多次加载 world/hash 不变（不重新生成世界）；3.0 等未知版本拒绝。
## @end-static-doc

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
				"starting_scenario": "core:starting_scenario/steady",
			},
			"player": {"money": 500},
			"world": {
				"current_port_id": "core:port_template/iron_harbor",
					},
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
	var versions: Dictionary = state.campaign_setup().get("content_versions", {})
	assert_eq(String(versions.get("starting_scenarios", "")), "2.0", "missing starting_scenarios is filled with the current registry version")
	assert_false(versions.has("map_profiles"), "the retired map_profiles type is never recorded")
	assert_eq(String(versions.get("world_profiles", "")), "2.0", "missing types are filled from the current registry")
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
	SaveMigrations.prepare_for_save(state.data)
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


func test_new_save_snapshots_content_versions() -> void:
	var directory := _directory()
	var service := SaveService.new(null, directory)
	var state := GameState.from_dict({
		"schema_version": "2.0",
		"campaign": {"id": "campaign_7"},
		"run": {"seed": 7, "starting_scenario": "core:starting_scenario/steady"},
		"player": {"money": 10},
	})
	state.ensure_campaign()
	var saved := service.save_slot("snapshot", state)
	assert_true(bool(saved["ok"]), "save writes: %s" % String(saved.get("error", "")))
	var parsed := JsonUtils.parse_file(directory + "/snapshot.json")
	assert_true(bool(parsed["ok"]), "save file parses")
	var versions: Dictionary = parsed["value"]["state"]["campaign"]["setup"]["content_versions"]
	for type_key in ContentTypes.SCHEMA_VERSIONS.keys():
		assert_eq(
			String(versions.get(String(type_key), "")),
			String(ContentTypes.SCHEMA_VERSIONS[type_key]),
			"saved content_versions snapshots %s" % type_key
		)
	_cleanup(directory)


func test_v2_save_without_content_versions_is_backfilled() -> void:
	var directory := _directory()
	var service := SaveService.new(null, directory)
	var payload := _legacy_payload()
	payload["save_schema"] = "2.0"
	payload["state"]["schema_version"] = "2.0"
	payload["state"]["campaign"] = {"id": "campaign_4242"}
	_write_payload(directory, "partial_versions", payload)
	var loaded := service.load_slot("partial_versions")
	assert_true(bool(loaded["ok"]), "v2 payload without content_versions loads")
	var versions: Dictionary = loaded["state"].campaign_setup().get("content_versions", {})
	assert_eq(String(versions.get("starting_scenarios", "")), "2.0", "backfill fills starting_scenarios from the registry")
	assert_false(versions.has("map_profiles"), "backfill never records the retired map_profiles type")
	_cleanup(directory)


func test_content_version_drift_warns_without_reordering_the_world() -> void:
	var directory := _directory()
	var service := SaveService.new(null, directory)
	var payload := _legacy_payload()
	payload["save_schema"] = "2.0"
	payload["state"]["schema_version"] = "2.0"
	payload["state"]["campaign"] = {
		"id": "campaign_4242",
		"setup": {"content_versions": {"items": "1.0"}},
	}
	_write_payload(directory, "drift", payload)
	var first := service.load_slot("drift")
	var second := service.load_slot("drift")
	assert_true(bool(first["ok"]), "a save with drifted content versions still loads")
	assert_true(bool(second["ok"]), "the same save loads again")
	var warnings: Array = first.get("migration_warnings", [])
	var has_drift := false
	for warning in warnings:
		if String(warning).contains("content version drift") and String(warning).contains("items"):
			has_drift = true
	assert_true(has_drift, "drift is reported as a warning: %s" % str(warnings))
	assert_eq(
		String(first["state"].world().get("current_port_id", "")),
		String(second["state"].world().get("current_port_id", "")),
		"loading a drifted save never re-generates the world"
	)
	_cleanup(directory)


func test_v2_campaign_save_round_trips_content_versions_and_ids() -> void:
	var directory := _directory()
	var service := SaveService.new(null, directory)
	var state := GameState.from_dict({
		"schema_version": "2.0",
		"campaign": {"id": "campaign_11"},
		"run": {"seed": 11, "starting_scenario": "core:starting_scenario/steady"},
		"player": {"money": 10},
		"world": {
			"current_port_id": "port_0",
			"start_profile_id": "core:start_profile/standard",
			"world_profile_id": "core:world_profile/default_world",
			"map_config_id": "core:map_config/standard",
		},
	})
	state.ensure_campaign()
	state.campaign_setup()["start_profile_id"] = "core:start_profile/standard"
	state.campaign_setup()["world_profile_id"] = "core:world_profile/default_world"
	state.campaign_setup()["map_config_id"] = "core:map_config/standard"
	SaveMigrations.prepare_for_save(state.data)
	var saved := service.save_slot("v2_roundtrip", state)
	assert_true(bool(saved["ok"]), "v2 save writes")
	var loaded := service.load_slot("v2_roundtrip")
	assert_true(bool(loaded["ok"]), "v2 save loads")
	var loaded_state: GameState = loaded["state"]
	assert_eq(String(loaded_state.world().get("map_config_id", "")), "core:map_config/standard", "map config id persists")
	assert_false(loaded_state.world().has("map_profile_id"), "v2 campaigns carry no retired map_profile_id")
	var versions: Dictionary = loaded_state.campaign_setup().get("content_versions", {})
	assert_eq(String(versions.get("map_configs", "")), "2.0", "v2 content versions persist")
	assert_eq(loaded_state.hash(), state.hash(), "v2 campaign state hash round-trips")
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
