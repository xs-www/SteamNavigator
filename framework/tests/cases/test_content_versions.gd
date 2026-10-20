extends TestCase
## Phase A: content schema versions are declared per content type.
##
## The runtime still loads Content Schema 1.0 only; these tests pin the new
## contract (per-type version table, per-type compiler check and patch
## re-validation) without activating any Schema 2.0 draft type.

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


func _error_codes(report: StartupReport) -> PackedStringArray:
	var codes := PackedStringArray()
	for error in report.errors:
		codes.append(String(error.get("code", "")))
	return codes


func test_every_runtime_type_declares_content_schema_1_0() -> void:
	var registry_types: Array[StringName] = ContentTypes.registry_types()
	assert_eq(ContentTypes.SCHEMA_VERSIONS.size(), registry_types.size(), "every runtime type has a schema version")
	for content_type in registry_types:
		assert_eq(ContentTypes.schema_version(content_type), "1.0", "%s declares content schema 1.0" % content_type)
	assert_eq(ContentTypes.schema_version(ContentTypes.PATCH), "1.0", "patch type declares content schema 1.0")


func test_unknown_type_has_no_declared_version() -> void:
	assert_eq(ContentTypes.schema_version(&"not_a_type"), "", "unknown types have no content schema version")
	assert_false(ContentTypes.is_known(&"not_a_type"), "unknown types are still rejected")


func test_v2_draft_types_are_not_runtime_types() -> void:
	var parsed := JsonUtils.parse_file("res://content_types.json")
	assert_true(bool(parsed.get("ok", false)), "content_types.json parses")
	var manifest: Dictionary = parsed["value"]
	var drafts: Dictionary = manifest.get("draft_schemas", {})
	assert_true(drafts.size() >= 8, "Schema 2.0 draft types are declared in the manifest")
	for draft_type in drafts.keys():
		var content_type := StringName(String(draft_type))
		assert_false(ContentTypes.is_known(content_type), "%s is not a runtime content type" % draft_type)
		assert_eq(ContentTypes.schema_version(content_type), "", "%s has no runtime schema version" % draft_type)


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
