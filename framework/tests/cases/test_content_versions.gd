extends TestCase
## @static-doc
## 作用：按内容类型声明 Schema 版本（Phase A）与 Phase B 世界/战役家族提升 active 的
## 回归测试：版本表、编译器按类型校验、Patch 再校验、2.0 内容真实加载与注册。
##
## ## 契约与约束
## - 每个 runtime 类型都必须有非空 schema_version；Phase B 的 9 类
##   （world_profiles / regions / sites / route_templates / weather_profiles /
##   factions / discoveries / start_profiles / map_configs）、C1 合并后的
##   `modules` + `hulls`、C2 合并后的 `items`、C3 新增的 `quests`、C4 的
##   `port_templates` / `starting_scenarios` 与 C4-C 的 `voyage_events` /
##   `crew_roles` / `boiler_strategies` 与 C4-D 的 `contracts` / `patches` 为 2.0；
##   `map_profiles` / `port_archetypes` / `starting_builds` / `events` / `roles` /
##   `strategies` 已退役；C4-D 后不再有 1.0 active 类型。
## - `content_types.json.draft_schemas` 是 `weapons` + 剧情模式 `story_arcs` /
##   `story_levels`，草案不得进入 `ContentTypes`。
## - 1.0 内容的 envelope 仍走 1.0 校验；`items` 声明 1.0 必须报 `unsupported_schema`
##   （C2 合并后 items 是 active 2.0 类型）。
## - 一个 2.0 `world_profiles` 内容模组必须通过 ContentCompiler、进入注册表，
##   且不产生 fatal / degraded 启动状态。
## @end-static-doc

const TEMP_MOD_ID := "cvmod_ok"
const TEMP_V2_MOD_ID := "cvmod_v2"


func _write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _temp_root(prefix: String) -> String:
	return "user://content_versions_%s_%d" % [prefix, Time.get_ticks_usec()]


func _write_item_mod(root: String, mod_id: String, schema_version: String) -> void:
	var mod_root := root + "/" + mod_id
	DirAccess.make_dir_recursive_absolute(mod_root + "/content")
	DirAccess.make_dir_recursive_absolute(mod_root + "/localization")
	var manifest := {
		"$schema": "https://steam-navigator.local/schema/mod-manifest-1.json",
		"id": mod_id,
		"name": mod_id,
		"version": "1.0.0",
		"api_version": "1.0",
		"type": "content",
		"load_priority": 10,
		"required": false,
		"dependencies": [{"id": "core", "version": ">=1.0.0 <2.0.0"}],
		"content": ["content/items.json"],
		"localization": ["localization/zh_CN.json"],
	}
	_write_file(mod_root + "/manifest.json", JsonUtils.canonical_stringify(manifest, "  "))
	var items := {
		"schema_version": schema_version,
		"content_type": "items",
		"definitions": [{
			"id": "%s:item/test_item" % mod_id,
			"name_key": "item.%s.test_item.name" % mod_id,
			"enabled": true,
			"data": {
				"crafting_material": false,
				"unit_weight": 1.0,
				"base_price": 10,
				"base_stock": 10,
				"price_elasticity": 0.2,
			},
		}],
	}
	_write_file(mod_root + "/content/items.json", JsonUtils.canonical_stringify(items, "  "))
	var localization := {"item.%s.test_item.name" % mod_id: "Test Item"}
	_write_file(mod_root + "/localization/zh_CN.json", JsonUtils.canonical_stringify(localization, "  "))


func _write_world_profile_mod(root: String, mod_id: String) -> void:
	var mod_root := root + "/" + mod_id
	DirAccess.make_dir_recursive_absolute(mod_root + "/content")
	DirAccess.make_dir_recursive_absolute(mod_root + "/localization")
	var manifest := {
		"$schema": "https://steam-navigator.local/schema/mod-manifest-1.json",
		"id": mod_id,
		"name": mod_id,
		"version": "1.0.0",
		"api_version": "1.0",
		"type": "content",
		"load_priority": 10,
		"required": false,
		"dependencies": [{"id": "core", "version": ">=1.0.0 <2.0.0"}],
		"content": ["content/world_profiles.json", "content/weather_profiles.json"],
		"localization": ["localization/zh_CN.json"],
	}
	_write_file(mod_root + "/manifest.json", JsonUtils.canonical_stringify(manifest, "  "))
	var weather_profile := {
		"schema_version": "2.0",
		"content_type": "weather_profiles",
		"definitions": [{
			"id": "%s:weather_profile/temperate" % mod_id,
			"name_key": "weather.%s.temperate.name" % mod_id,
			"enabled": true,
			"data": {
				"climate": "temperate",
				"fog_chance": 0.1,
				"storm_chance": 0.05,
				"risk_modifier": 0.0,
			},
		}],
	}
	_write_file(mod_root + "/content/weather_profiles.json", JsonUtils.canonical_stringify(weather_profile, "  "))
	var world_profile := {
		"schema_version": "2.0",
		"content_type": "world_profiles",
		"definitions": [{
			"id": "%s:world_profile/test_world" % mod_id,
			"name_key": "world.%s.test_world.name" % mod_id,
			"enabled": true,
			"data": {
				"region_count": 2,
				"sites_per_region": 3,
				"port_count": 2,
				"start_region_tags": ["region.start"],
				"weather_profile": "%s:weather_profile/temperate" % mod_id,
			},
		}],
	}
	_write_file(mod_root + "/content/world_profiles.json", JsonUtils.canonical_stringify(world_profile, "  "))
	var localization := {
		"world.%s.test_world.name" % mod_id: "Test World",
		"weather.%s.temperate.name" % mod_id: "Temperate",
	}
	_write_file(mod_root + "/localization/zh_CN.json", JsonUtils.canonical_stringify(localization, "  "))


func _error_codes(report: StartupReport) -> PackedStringArray:
	var codes := PackedStringArray()
	for error in report.errors:
		codes.append(String(error.get("code", "")))
	return codes


func test_every_runtime_type_declares_its_content_schema_version() -> void:
	var registry_types: Array[StringName] = ContentTypes.registry_types()
	assert_eq(ContentTypes.SCHEMA_VERSIONS.size(), registry_types.size(), "every runtime type has a schema version")
	for content_type in registry_types:
		assert_false(ContentTypes.schema_version(content_type).is_empty(), "%s declares a content schema version" % content_type)
	for content_type in [
		ContentTypes.WORLD_PROFILE, ContentTypes.REGION, ContentTypes.SITE,
		ContentTypes.ROUTE_TEMPLATE, ContentTypes.WEATHER_PROFILE, ContentTypes.FACTION,
		ContentTypes.DISCOVERY, ContentTypes.START_PROFILE, ContentTypes.MAP_CONFIG,
	]:
		assert_eq(ContentTypes.schema_version(content_type), "2.0", "%s is a Phase B Schema 2.0 type" % content_type)
	assert_eq(ContentTypes.schema_version(ContentTypes.ITEM), "2.0", "items is the merged Schema 2.0 family (C2)")
	assert_eq(ContentTypes.schema_path(ContentTypes.ITEM), "res://schemas/v2/item.schema.json", "items schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.QUEST), "2.0", "quests is an active Schema 2.0 type (C3)")
	assert_eq(ContentTypes.schema_path(ContentTypes.QUEST), "res://schemas/v2/quest.schema.json", "quests schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.PORT_TEMPLATE), "2.0", "port_templates is a Schema 2.0 type (C4)")
	assert_eq(ContentTypes.schema_path(ContentTypes.PORT_TEMPLATE), "res://schemas/v2/port_template.schema.json",
		"port_templates schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.STARTING_SCENARIO), "2.0",
		"starting_scenarios is a Schema 2.0 type (C4)")
	assert_eq(ContentTypes.schema_path(ContentTypes.STARTING_SCENARIO), "res://schemas/v2/starting_scenario.schema.json",
		"starting_scenarios schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.VOYAGE_EVENT), "2.0", "voyage_events is a Schema 2.0 type (C4-C)")
	assert_eq(ContentTypes.schema_path(ContentTypes.VOYAGE_EVENT), "res://schemas/v2/voyage_event.schema.json",
		"voyage_events schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.CREW_ROLE), "2.0", "crew_roles is a Schema 2.0 type (C4-C)")
	assert_eq(ContentTypes.schema_path(ContentTypes.CREW_ROLE), "res://schemas/v2/crew_role.schema.json",
		"crew_roles schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.BOILER_STRATEGY), "2.0",
		"boiler_strategies is a Schema 2.0 type (C4-C)")
	assert_eq(ContentTypes.schema_path(ContentTypes.BOILER_STRATEGY), "res://schemas/v2/boiler_strategy.schema.json",
		"boiler_strategies schema path")
	for retired in [&"map_profiles", &"port_archetypes", &"starting_builds", &"events", &"roles", &"strategies"]:
		assert_false(ContentTypes.is_known(retired), "%s is retired" % retired)
	assert_eq(ContentTypes.schema_version(ContentTypes.HULL), "2.0", "hulls is a Schema 2.0 type after C1")
	assert_eq(ContentTypes.schema_version(ContentTypes.MODULE), "2.0", "the merged modules type is Schema 2.0")
	assert_eq(ContentTypes.schema_path(ContentTypes.MODULE), "res://schemas/v2/module.schema.json", "modules schema path")
	assert_eq(ContentTypes.schema_path(ContentTypes.HULL), "res://schemas/v2/hull.schema.json", "hulls schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.CONTRACT), "2.0", "contracts is a Schema 2.0 type (C4-D)")
	assert_eq(ContentTypes.schema_path(ContentTypes.CONTRACT), "res://schemas/v2/contract.schema.json", "contracts schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.PATCH), "2.0", "patches is a Schema 2.0 type (C4-D)")
	assert_eq(ContentTypes.schema_path(ContentTypes.PATCH), "res://schemas/v2/patch.schema.json", "patches schema path")
	# C4-D closed the last 1.0 types: every declared runtime type is now 2.0.
	for content_type in ContentTypes.registry_types():
		assert_eq(ContentTypes.schema_version(content_type), "2.0", "%s has no 1.0 fallback" % content_type)
	for content_type in ContentTypes.SCHEMA_VERSIONS.keys():
		assert_eq(String(ContentTypes.SCHEMA_VERSIONS[content_type]), "2.0", "%s declares 2.0" % content_type)


func test_phase_b_world_family_is_active_with_2_0_schemas() -> void:
	var parsed := JsonUtils.parse_file("res://content_types.json")
	assert_true(bool(parsed.get("ok", false)), "content_types.json parses")
	var manifest: Dictionary = parsed["value"]
	var active: Dictionary = {}
	for entry in manifest.get("types", []):
		active[String(entry.get("key", ""))] = entry
	for key in ["world_profiles", "regions", "sites", "route_templates", "weather_profiles", "factions", "discoveries", "start_profiles", "map_configs"]:
		assert_true(active.has(key), "%s is an active content type" % key)
		var entry: Dictionary = active[key]
		assert_eq(String(entry.get("schema_version", "")), "2.0", "%s declares schema 2.0" % key)
		assert_eq(ContentTypes.schema_version(StringName(key)), "2.0", "%s runtime version" % key)
		assert_true(FileAccess.file_exists("res://" + String(entry.get("schema", ""))), "%s schema exists" % key)
		assert_eq("res://" + String(entry.get("schema", "")), ContentTypes.schema_path(StringName(key)), "%s schema path matches" % key)


func test_unknown_type_has_no_declared_version() -> void:
	assert_eq(ContentTypes.schema_version(&"not_a_type"), "", "unknown types have no content schema version")
	assert_false(ContentTypes.is_known(&"not_a_type"), "unknown types are still rejected")


func test_v2_draft_types_are_not_runtime_types() -> void:
	var parsed := JsonUtils.parse_file("res://content_types.json")
	assert_true(bool(parsed.get("ok", false)), "content_types.json parses")
	var manifest: Dictionary = parsed["value"]
	var drafts: Dictionary = manifest.get("draft_schemas", {})
	assert_eq(drafts.size(), 3, "weapons and the two Story Mode types are Schema 2.0 draft types")
	for expected in ["weapons", "story_arcs", "story_levels"]:
		assert_true(drafts.has(expected), "%s is a draft schema" % expected)
		assert_true(FileAccess.file_exists("res://" + String(drafts[expected])), "%s draft schema exists" % expected)
	for draft_type in drafts.keys():
		var content_type := StringName(String(draft_type))
		assert_false(ContentTypes.is_known(content_type), "%s is not a runtime content type" % draft_type)
		assert_eq(ContentTypes.schema_version(content_type), "", "%s has no runtime schema version" % draft_type)


func test_promoted_world_profile_content_compiles_and_registers() -> void:
	var root := _temp_root("v2_ok")
	_write_world_profile_mod(root, "cvmod_world")
	var boot := bootstrap_core({"scan_roots": PackedStringArray(["res://dev_mods", root])})
	var report: StartupReport = boot["report"]
	assert_true(not report.has_fatal(), "2.0 world profile load has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "a promoted Schema 2.0 type loads through the normal compiler: %s" % report.format_text())
	var context: AppContext = boot["context"]
	assert_not_null(
		context.registries.get_by_id(ContentTypes.WORLD_PROFILE, "cvmod_world:world_profile/test_world"),
		"2.0 world profile definition is registered"
	)


func test_item_envelope_with_2_0_still_compiles() -> void:
	var root := _temp_root("ok")
	_write_item_mod(root, TEMP_MOD_ID, "2.0")
	var boot := bootstrap_core({"scan_roots": PackedStringArray(["res://dev_mods", root])})
	var report: StartupReport = boot["report"]
	assert_true(not report.has_fatal(), "2.0 content load has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "a 2.0 items mod loads cleanly")
	var context: AppContext = boot["context"]
	assert_not_null(
		context.registries.get_by_id(ContentTypes.ITEM, "%s:item/test_item" % TEMP_MOD_ID),
		"2.0 items definition is registered"
	)


func test_item_envelope_with_1_0_is_rejected_per_type() -> void:
	var root := _temp_root("v1")
	_write_item_mod(root, TEMP_V2_MOD_ID, "1.0")
	var boot := bootstrap_core({"scan_roots": PackedStringArray(["res://dev_mods", root])})
	var report: StartupReport = boot["report"]
	var codes := _error_codes(report)
	assert_contains(codes, "unsupported_schema", "items declaring 1.0 is rejected: %s" % report.format_text())
	var message := ""
	var mod_id := ""
	for error in report.errors:
		if String(error.get("code", "")) == "unsupported_schema":
			message = String(error.get("message", ""))
			mod_id = String(error.get("mod_id", ""))
	assert_contains(message, "items", "the error names the content type")
	assert_contains(message, "2.0", "the error names the expected version")
	assert_eq(mod_id, TEMP_V2_MOD_ID, "the error points at the offending mod")
	assert_false(report.has_fatal(), "an unsupported version is a mod error, not a fatal startup error")


func test_patch_revalidation_uses_target_type_version() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var compiler := ContentCompiler.new(context.registries, context.localization, context.assets, context.logger)
	var iron_ore := context.registries.get_by_id(ContentTypes.ITEM, "core:item/iron_ore")
	assert_not_null(iron_ore, "core item definition exists")
	var raw: Dictionary = iron_ore.to_raw()
	var valid_errors := compiler._validate_definition(ContentTypes.ITEM, raw)
	assert_empty(valid_errors, "patch re-validation accepts a 2.0 item definition: %s" % str(valid_errors))
	var broken: Dictionary = raw.duplicate(true)
	broken["data"]["unit_weight"] = -1.0
	var broken_errors := compiler._validate_definition(ContentTypes.ITEM, broken)
	assert_false(broken_errors.is_empty(), "patch re-validation still reports schema errors")
	var version_errors := 0
	for error in broken_errors:
		if String(error.get("path", "")) == "/schema_version":
			version_errors += 1
	assert_eq(version_errors, 0, "the envelope uses the target type version (no version error)")
