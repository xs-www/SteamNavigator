extends TestCase
## Explicit patch behavior and conflict reporting.

func _write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _make_patch_mod(root: String, mod_id: String, price: int, texture_key: String = "icon.coal") -> void:
	var mod_root := root + "/" + mod_id
	DirAccess.make_dir_recursive_absolute(mod_root + "/content")
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
		"content": ["content/patches.json"],
	}
	_write_file(mod_root + "/manifest.json", JsonUtils.canonical_stringify(manifest, "  "))
	var patches := {
		"schema_version": "1.0",
		"content_type": "patches",
		"definitions": [{
			"target": "core:item/iron_ore",
			"operations": [
				{"op": "replace", "path": "/data/base_price", "value": price},
				{"op": "add", "path": "/information", "value": {"texture": texture_key}},
			],
		}],
	}
	_write_file(mod_root + "/content/patches.json", JsonUtils.canonical_stringify(patches, "  "))


func _temp_root() -> String:
	return "user://patch_tests_%d" % Time.get_ticks_usec()


func test_patch_applies_to_core_definition() -> void:
	var root := _temp_root()
	_make_patch_mod(root, "patch_a", 50)
	var bootstrap := Bootstrap.new()
	var report := bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods", root]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
	})
	assert_true(not report.has_fatal(), "patch load has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "single patch loads cleanly")
	var context: AppContext = AppContext.get_active()
	var iron_ore := context.registries.get_by_id(ContentTypes.ITEM, "core:item/iron_ore")
	assert_not_null(iron_ore, "patched definition still exists")
	assert_eq(int(iron_ore.data["base_price"]), 50, "patch replaces the value")
	assert_eq(String(iron_ore.information.get("texture", "")), "icon.coal", "patch updates parsed information")
	assert_eq(iron_ore.asset_uri("texture"), "asset://core/icon.coal", "patched bare asset key keeps the target namespace")
	assert_true(iron_ore.patched_by.has("patch_a"), "patch source is recorded")


func test_conflicting_patches_are_reported() -> void:
	var root := _temp_root()
	_make_patch_mod(root, "patch_a", 50)
	_make_patch_mod(root, "patch_b", 60)
	var bootstrap := Bootstrap.new()
	var report := bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods", root]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
	})
	assert_false(report.has_fatal(), "patch conflict is not a fatal startup error")
	var codes := PackedStringArray()
	for error in report.errors:
		codes.append(String(error.get("code", "")))
	assert_contains(codes, "patch_conflict", "conflicting patch is reported instead of silently winning")

	var invalid_root := _temp_root()
	_make_patch_mod(invalid_root, "patch_missing_asset", 50, "icon.missing")
	var invalid_bootstrap := Bootstrap.new()
	var invalid_report := invalid_bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods", invalid_root]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
	})
	var invalid_codes := PackedStringArray()
	for error in invalid_report.errors:
		invalid_codes.append(String(error.get("code", "")))
	assert_contains(invalid_codes, "entity_asset_missing", "missing information assets are rejected during compilation")
