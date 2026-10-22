extends TestCase
## @static-doc
## 作用：按内容类型声明 Schema 版本（Phase A）与 Phase B 世界/战役家族提升 active 的
## 回归测试：版本表、编译器按类型校验、Patch 再校验、2.0 内容真实加载与注册。
##
## ## 契约与约束
## - 每个 runtime 类型都必须有非空 schema_version；Phase B 的 9 类
##   （world_profiles / regions / sites / route_templates / weather_profiles /
##   factions / discoveries / start_profiles / map_configs）与 C1 合并后的
##   `modules` + `hulls` 为 2.0，其余运行时类型与 patches 仍为 1.0。
## - `content_types.json.draft_schemas` 是 `weapons` + 剧情模式 `story_arcs` /
##   `story_levels`，草案不得进入 `ContentTypes`。
## - 1.0 内容的 envelope 仍走 1.0 校验；goods 声明 2.0 必须报 `unsupported_schema`。
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


func _write_goods_mod(root: String, mod_id: String, schema_version: String) -> void:
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
		"content": ["content/goods.json"],
		"localization": ["localization/zh_CN.json"],
	}
	_write_file(mod_root + "/manifest.json", JsonUtils.canonical_stringify(manifest, "  "))
	var goods := {
		"schema_version": schema_version,
		"content_type": "goods",
		"definitions": [{
			"id": "%s:good/test_good" % mod_id,
			"name_key": "good.%s.test_good.name" % mod_id,
			"enabled": true,
			"data": {
				"unit_weight": 1.0,
				"base_price": 10,
				"base_stock": 10,
				"price_elasticity": 0.2,
			},
		}],
	}
	_write_file(mod_root + "/content/goods.json", JsonUtils.canonical_stringify(goods, "  "))
	var localization := {"good.%s.test_good.name" % mod_id: "Test Good"}
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
	assert_eq(ContentTypes.schema_version(ContentTypes.GOOD), "1.0", "goods stays on content schema 1.0")
	assert_eq(ContentTypes.schema_version(ContentTypes.HULL), "2.0", "hulls is a Schema 2.0 type after C1")
	assert_eq(ContentTypes.schema_version(ContentTypes.MODULE), "2.0", "the merged modules type is Schema 2.0")
	assert_eq(ContentTypes.schema_path(ContentTypes.MODULE), "res://schemas/v2/module.schema.json", "modules schema path")
	assert_eq(ContentTypes.schema_path(ContentTypes.HULL), "res://schemas/v2/hull.schema.json", "hulls schema path")
	assert_eq(ContentTypes.schema_version(ContentTypes.PATCH), "1.0", "patch type stays on content schema 1.0")


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


func test_goods_envelope_with_1_0_still_compiles() -> void:
	var root := _temp_root("ok")
	_write_goods_mod(root, TEMP_MOD_ID, "1.0")
	var boot := bootstrap_core({"scan_roots": PackedStringArray(["res://dev_mods", root])})
	var report: StartupReport = boot["report"]
	assert_true(not report.has_fatal(), "1.0 content load has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "a 1.0 content mod still loads cleanly")
	var context: AppContext = boot["context"]
	assert_not_null(
		context.registries.get_by_id(ContentTypes.GOOD, "%s:good/test_good" % TEMP_MOD_ID),
		"1.0 goods definition is registered"
	)


func test_goods_envelope_with_2_0_is_rejected_per_type() -> void:
	var root := _temp_root("v2")
	_write_goods_mod(root, TEMP_V2_MOD_ID, "2.0")
	var boot := bootstrap_core({"scan_roots": PackedStringArray(["res://dev_mods", root])})
	var report: StartupReport = boot["report"]
	var codes := _error_codes(report)
	assert_contains(codes, "unsupported_schema", "goods declaring 2.0 is rejected: %s" % report.format_text())
	var message := ""
	var mod_id := ""
	for error in report.errors:
		if String(error.get("code", "")) == "unsupported_schema":
			message = String(error.get("message", ""))
			mod_id = String(error.get("mod_id", ""))
	assert_contains(message, "goods", "the error names the content type")
	assert_contains(message, "1.0", "the error names the expected version")
	assert_eq(mod_id, TEMP_V2_MOD_ID, "the error points at the offending mod")
	assert_false(report.has_fatal(), "an unsupported version is a mod error, not a fatal startup error")


func test_patch_revalidation_uses_target_type_version() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var compiler := ContentCompiler.new(context.registries, context.localization, context.assets, context.logger)
	var iron_ore := context.registries.get_by_id(ContentTypes.GOOD, "core:good/iron_ore")
	assert_not_null(iron_ore, "core goods definition exists")
	var raw: Dictionary = iron_ore.to_raw()
	var valid_errors := compiler._validate_definition(ContentTypes.GOOD, raw)
	assert_empty(valid_errors, "patch re-validation accepts a 1.0 goods definition: %s" % str(valid_errors))
	var broken: Dictionary = raw.duplicate(true)
	broken["data"]["unit_weight"] = -1.0
	var broken_errors := compiler._validate_definition(ContentTypes.GOOD, broken)
	assert_false(broken_errors.is_empty(), "patch re-validation still reports schema errors")
	var version_errors := 0
	for error in broken_errors:
		if String(error.get("path", "")) == "/schema_version":
			version_errors += 1
	assert_eq(version_errors, 0, "the envelope uses the target type version (no version error)")
