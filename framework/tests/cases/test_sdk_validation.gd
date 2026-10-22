extends TestCase
## @static-doc
## 作用：SDK Schema 2.0 兼容回归：用真实子进程跑 `sdk/validate.gd` / `sdk/pack_mod.gd`，
## 覆盖 runtime / draft 两种模式、草案拒绝、退出码与 JSON 输出形状。
##
## ## 契约与约束
## - 所有断言面向真实 CLI：`OS.execute(OS.get_executable_path(), ...)` 以 `--headless` 启动
##   `res://sdk/validate.gd` / `res://sdk/pack_mod.gd`，不直接调用内部实现。
## - 仓库内示例 / 模板只读（`sdk/examples/**`、`sdk/templates/**`）；运行期 fixture 写在
##   `user://sdk_test_*`，每个用例结束清理。
## - runtime 必须：1.0 兼容、混合 1.0 + 2.0 可加载、未激活草案被显式拒绝
##   （`inactive_content_type`，带 `mod` / `file` / `path` 字段）。
## - draft 必须：草案 / 混合模组可静态校验；Schema 错误与“按类型版本”错误能被发现。
## - `pack_mod --release` 必须拒绝未激活草案与校验 error；不带 `--release` 保持旧行为。
## @end-static-doc

const VALIDATE_SCRIPT := "res://sdk/validate.gd"
const PACK_SCRIPT := "res://sdk/pack_mod.gd"
const ROLES_EXAMPLE := "sdk/examples/example_roles_1_0"
const MIXED_EXAMPLE := "sdk/examples/example_mixed_roles_items"
const DRAFT_WEAPONS_TEMPLATE := "sdk/templates/draft_weapons_pack"
const STORY_TEMPLATE := "sdk/templates/story_pack_iron_tide"


# ---------------------------------------------------------------------------
# CLI / fixture helpers
# ---------------------------------------------------------------------------

func _run_sdk(script_path: String, extra_args: PackedStringArray) -> Dictionary:
	var output := []
	var arguments := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", script_path,
		"--",
	])
	arguments.append_array(extra_args)
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	var lines := PackedStringArray()
	for line in output:
		lines.append(String(line))
	var text := "\n".join(lines)
	return {"exit": exit_code, "text": text, "json": _extract_json(text)}


func _extract_json(text: String) -> Variant:
	var start := text.find("{")
	var end := text.rfind("}")
	if start < 0 or end <= start:
		return null
	return JSON.parse_string(text.substr(start, end - start + 1))


func _json_of(result: Dictionary, label: String) -> Dictionary:
	var parsed: Variant = result["json"]
	assert_true(parsed is Dictionary, "%s: expected a JSON object in output:\n%s" % [label, String(result["text"])])
	if not (parsed is Dictionary):
		return {}
	return parsed


func _error_codes(json: Dictionary) -> PackedStringArray:
	var codes := PackedStringArray()
	for entry in json.get("errors", []):
		if entry is Dictionary:
			codes.append(String(entry.get("code", "")))
	return codes


func _error_with_code(json: Dictionary, code: String) -> Dictionary:
	for entry in json.get("errors", []):
		if entry is Dictionary and String(entry.get("code", "")) == code:
			return entry
	return {}


func _mod_ids(json: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in json.get("mods", []):
		if entry is Dictionary:
			ids.append(String(entry.get("id", "")))
	return ids


func _counts(json: Dictionary) -> Dictionary:
	var counts: Variant = json.get("content_counts", {})
	return counts if counts is Dictionary else {}


func _temp_root(name: String) -> String:
	var root := "user://sdk_test_%s" % name
	SdkValidationCore.cleanup_stage(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	return root


func _clean(root: String) -> void:
	SdkValidationCore.cleanup_stage(root)


func _write_json(root: String, relative_path: String, value: Dictionary) -> void:
	var absolute := root + "/" + relative_path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(absolute.get_base_dir()))
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	assert_not_null(file, "cannot write fixture file %s" % absolute)
	if file == null:
		return
	file.store_string(JsonUtils.canonical_stringify(value, "  "))
	file.close()


func _manifest(mod_id: String, content_files: Array, capabilities: Array = []) -> Dictionary:
	return {
		"$schema": "https://steam-navigator.local/schema/mod-manifest-1.json",
		"id": mod_id,
		"name": mod_id,
		"version": "0.1.0",
		"api_version": "1.0",
		"type": "content",
		"load_priority": 10,
		"required": false,
		"dependencies": [{"id": "core", "version": ">=1.0.0 <2.0.0"}],
		"optional_dependencies": [],
		"conflicts": [],
		"content": content_files,
		"localization": [],
		"assets": {},
		"authors": ["sdk tests"],
		"license": "CC-BY-4.0",
		"description": "SDK validation fixture",
		"capabilities": capabilities,
	}


func _write_mod(root: String, mod_id: String, content: Dictionary, capabilities: Array = []) -> String:
	var mod_root := root + "/" + mod_id
	var content_files := []
	for relative_path in content.keys():
		content_files.append(String(relative_path))
	_write_json(mod_root, "manifest.json", _manifest(mod_id, content_files, capabilities))
	for relative_path in content.keys():
		_write_json(mod_root, String(relative_path), content[relative_path])
	return mod_root


func _weapon_envelope(mod_id: String, damage: int = 12) -> Dictionary:
	return {
		"schema_version": "2.0",
		"content_type": "weapons",
		"definitions": [{
			"id": "%s:weapon/test_gun" % mod_id,
			"name_key": "weapon.%s.test_gun.name" % mod_id,
			"tags": ["weapon.direct"],
			"enabled": true,
			"data": {
				"kind": "direct",
				"damage": damage,
				"range": 245,
				"min_range": 0,
				"cooldown": 1.65,
				"accuracy": 0.72,
				"projectile_speed": 360,
				"splash": 0,
				"arc_deg": 260,
				"salvo": 1,
				"weapon_class": "Light",
				"assembly_profile": "yaw_pitch",
				"tier": 1,
				"weight": 9,
				"purchase_price": 380,
			},
		}],
	}


func _item_envelope(mod_id: String, schema_version: String = "2.0", base_price: int = 10) -> Dictionary:
	return {
		"schema_version": schema_version,
		"content_type": "items",
		"definitions": [{
			"id": "%s:item/test_item" % mod_id,
			"name_key": "item.%s.test_item.name" % mod_id,
			"enabled": true,
			"data": {
				"crafting_material": false,
				"unit_weight": 1.0,
				"base_price": base_price,
				"base_stock": 10,
				"price_elasticity": 0.2,
			},
		}],
	}


func _patch_envelope(schema_version: String, definitions: Array) -> Dictionary:
	return {
		"schema_version": schema_version,
		"content_type": "patches",
		"definitions": definitions,
	}


# ---------------------------------------------------------------------------
# validate.gd
# ---------------------------------------------------------------------------

func test_default_mode_is_runtime_and_validates_core() -> void:
	var result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray(["--json"]))
	assert_eq(int(result["exit"]), 0, "core runtime validation must exit 0")
	var json := _json_of(result, "core runtime")
	assert_eq(String(json.get("mode", "")), "runtime", "no --mode must stay on the backward-compatible runtime default")
	assert_eq(String(json.get("status", "")), "ok", "core must load cleanly")
	assert_empty(json.get("errors", []), "core must have no validation errors")
	assert_true(int(_counts(json).get("items", 0)) > 0, "core items must be counted")


func test_mod_root_core_does_not_duplicate_the_default_scan_root() -> void:
	# `--mod-root=dev_mods/core` normalizes to its parent `res://dev_mods`, which is
	# already the default root. Roots must be deduplicated instead of scanning core twice
	# (which used to surface a fatal duplicate_mod_id).
	for mod_root in PackedStringArray(["dev_mods/core", "dev_mods"]):
		var result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
			"--mod-root=%s" % mod_root, "--mode=runtime", "--json",
		]))
		assert_eq(int(result["exit"]), 0, "--mod-root=%s must validate core once" % mod_root)
		var json := _json_of(result, "core root %s" % mod_root)
		assert_eq(String(json.get("status", "")), "ok", "--mod-root=%s must not degrade" % mod_root)
		assert_empty(json.get("errors", []), "--mod-root=%s must not report duplicate roots" % mod_root)
		assert_false(_error_codes(json).has("duplicate_mod_id"), "core must not be scanned twice")
		var scanned: Array = json.get("scanned_roots", [])
		assert_eq(scanned.size(), 1, "only the deduplicated core root is scanned")


func test_runtime_accepts_1_0_and_mixed_version_mods() -> void:
	# A mod that stays on Content Schema 1.0 with a still-active type.
	var one := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s" % ROLES_EXAMPLE, "--mode=runtime", "--json",
	]))
	assert_eq(int(one["exit"]), 0, "1.0 example must pass runtime validation")
	var one_json := _json_of(one, "runtime 1.0 example")
	assert_eq(String(one_json.get("mode", "")), "runtime", "explicit runtime mode")
	assert_contains(_mod_ids(one_json), "example_roles_1_0", "the 1.0 example mod must be loaded")
	assert_true(int(_counts(one_json).get("roles", 0)) >= 3, "the 1.0 role definition must be registered next to core")

	# A mixed mod: roles stays 1.0 while the active items type is 2.0.
	var mixed := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s" % MIXED_EXAMPLE, "--mode=runtime", "--json",
	]))
	assert_eq(int(mixed["exit"]), 0, "mixed-version example must pass runtime validation")
	var mixed_json := _json_of(mixed, "runtime mixed example")
	assert_contains(_mod_ids(mixed_json), "example_mixed_roles_items", "the mixed mod must be loaded")
	assert_true(int(_counts(mixed_json).get("items", 0)) >= 13, "the 2.0 item must be registered")
	assert_true(int(_counts(mixed_json).get("roles", 0)) >= 3, "the 1.0 role must be registered at the same time")

	# Per-type versions come from ContentTypes, not a global gate.
	assert_eq(ContentTypes.schema_version(ContentTypes.ROLE), "1.0", "roles is still a 1.0 type")
	assert_eq(ContentTypes.schema_version(ContentTypes.ITEM), "2.0", "items is a 2.0 type")
	var roles_file := JsonUtils.parse_file("res://%s/content/roles.json" % MIXED_EXAMPLE)
	var items_file := JsonUtils.parse_file("res://%s/content/items.json" % MIXED_EXAMPLE)
	assert_eq(String(roles_file["value"]["schema_version"]), "1.0", "the mixed mod keeps roles on 1.0")
	assert_eq(String(items_file["value"]["schema_version"]), "2.0", "the mixed mod writes items with 2.0")


func test_runtime_rejects_unactivated_draft_content() -> void:
	var root := _temp_root("runtime_draft")
	_write_mod(root, "sdk_draft_mod", {"content/weapons.json": _weapon_envelope("sdk_draft_mod")})
	var result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s/sdk_draft_mod" % root, "--mode=runtime", "--json",
	]))
	assert_eq(int(result["exit"]), 1, "runtime validation must reject draft content")
	var json := _json_of(result, "runtime draft rejection")
	assert_false(bool(json.get("ok", true)), "the rejection must be a failed result")
	var issue := _error_with_code(json, "inactive_content_type")
	assert_true(not issue.is_empty(), "the draft rejection needs an explicit inactive_content_type error")
	assert_eq(String(issue.get("mod", "")), "sdk_draft_mod", "the structured error carries the mod id")
	assert_eq(String(issue.get("file", "")), "content/weapons.json", "the structured error carries the content file")
	assert_eq(String(issue.get("path", "")), "/content_type", "the structured error carries the JSON pointer")
	assert_true(String(issue.get("message", "")).contains("weapons"), "the message names the draft content type")
	assert_false(_error_codes(json).has("unknown_content_type"), "the generic compiler error is replaced by the explicit draft error")
	_clean(root)


func test_draft_mode_validates_draft_story_and_mixed_mods() -> void:
	var weapons := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s" % DRAFT_WEAPONS_TEMPLATE, "--mode=draft", "--json",
	]))
	assert_eq(int(weapons["exit"]), 0, "the weapons draft template must pass draft validation")
	var weapons_json := _json_of(weapons, "draft weapons template")
	assert_eq(String(weapons_json.get("mode", "")), "draft", "explicit draft mode")
	assert_empty(weapons_json.get("errors", []), "draft validation must not error on a valid draft mod")
	assert_true(int(_counts(weapons_json).get("weapons", 0)) >= 1, "draft validation counts weapons definitions")

	var story := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s" % STORY_TEMPLATE, "--mode=draft", "--json",
	]))
	assert_eq(int(story["exit"]), 0, "the story draft template must pass draft validation")
	var story_json := _json_of(story, "draft story template")
	assert_true(int(_counts(story_json).get("story_arcs", 0)) >= 1, "story arcs are counted in draft mode")
	assert_true(int(_counts(story_json).get("story_levels", 0)) >= 1, "story levels are counted in draft mode")

	var mixed := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s" % MIXED_EXAMPLE, "--mode=draft", "--json",
	]))
	assert_eq(int(mixed["exit"]), 0, "mixed-version mods must also pass draft validation")
	assert_empty(_json_of(mixed, "draft mixed example").get("errors", []), "mixed mod has no static schema errors")


func test_draft_mode_reports_schema_and_per_type_version_errors() -> void:
	var schema_root := _temp_root("draft_schema_error")
	_write_mod(schema_root, "sdk_bad_weapon", {"content/weapons.json": _weapon_envelope("sdk_bad_weapon", 999)})
	var schema_result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s/sdk_bad_weapon" % schema_root, "--mode=draft", "--json",
	]))
	assert_eq(int(schema_result["exit"]), 1, "an invalid draft definition must fail draft validation")
	var schema_json := _json_of(schema_result, "draft schema error")
	var schema_error := _error_with_code(schema_json, "schema_error")
	assert_true(not schema_error.is_empty(), "draft mode must surface schema_error")
	assert_eq(String(schema_error.get("file", "")), "content/weapons.json", "schema error points at the content file")
	assert_true(String(schema_error.get("path", "")).contains("damage"), "schema error keeps the JSON pointer to the bad field")

	# Per-type versions: items is an active 2.0 type, so a file declared 1.0 must be rejected
	# with different diagnostics in the static (draft) and runtime readers.
	var version_root := _temp_root("draft_version_error")
	_write_mod(version_root, "sdk_bad_version", {
		"content/items.json": _item_envelope("sdk_bad_version", "1.0"),
	}, ["content.items.v1"])
	var draft_result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s/sdk_bad_version" % version_root, "--mode=draft", "--json",
	]))
	assert_eq(int(draft_result["exit"]), 1, "a per-type version mismatch must fail draft validation")
	var mismatch := _error_with_code(_json_of(draft_result, "draft version mismatch"), "schema_version_mismatch")
	assert_true(not mismatch.is_empty(), "draft validation reports schema_version_mismatch")
	assert_eq(String(mismatch.get("path", "")), "/schema_version", "the version error points at the envelope")
	var runtime_result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s/sdk_bad_version" % version_root, "--mode=runtime", "--json",
	]))
	assert_eq(int(runtime_result["exit"]), 1, "the runtime must also reject the version mismatch")
	assert_true(
		_error_codes(_json_of(runtime_result, "runtime version mismatch")).has("unsupported_schema"),
		"the runtime compiler reports unsupported_schema for a per-type version mismatch"
	)
	_clean(schema_root)
	_clean(version_root)


func test_patch_envelope_is_checked_against_the_target_type_version() -> void:
	var root := _temp_root("patch_target_version")
	_write_mod(root, "sdk_patch_mod", {
		"content/patches.json": _patch_envelope("1.0", [
			{"target": "core:role/engineer_basic", "operations": [{"op": "replace", "path": "/data/wage_per_voyage", "value": 45}]},
			{"target": "core:item/iron_ore", "operations": [{"op": "replace", "path": "/data/base_price", "value": 45}]},
		]),
	})
	var result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s/sdk_patch_mod" % root, "--mode=runtime", "--json",
	]))
	assert_eq(int(result["exit"]), 0, "a 1.0 patch envelope may target both 1.0 roles and 2.0 items")
	var json := _json_of(result, "patch target version")
	assert_empty(json.get("errors", []), "patch re-validation uses the target type version, not the patch envelope version")

	# The patch envelope itself must stay on the patches type version (1.0).
	var bad_root := _temp_root("patch_bad_envelope")
	_write_mod(bad_root, "sdk_patch_bad", {
		"content/patches.json": _patch_envelope("2.0", [
			{"target": "core:role/engineer_basic", "operations": [{"op": "replace", "path": "/data/wage_per_voyage", "value": 45}]},
		]),
	})
	var bad_result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray([
		"--mod-root=%s/sdk_patch_bad" % bad_root, "--mode=runtime", "--json",
	]))
	assert_eq(int(bad_result["exit"]), 1, "a patch file with the wrong envelope version must be rejected")
	assert_true(
		_error_codes(_json_of(bad_result, "patch bad envelope")).has("unsupported_schema"),
		"patches expects Content Schema 1.0, so 2.0 is unsupported_schema"
	)
	_clean(root)
	_clean(bad_root)


func test_unknown_mode_is_a_usage_error() -> void:
	var result := _run_sdk(VALIDATE_SCRIPT, PackedStringArray(["--mode=nope", "--json"]))
	assert_eq(int(result["exit"]), 2, "unknown --mode must exit with the usage code 2")
	assert_true(String(result["text"]).contains("--mode"), "the usage error must name --mode")


# ---------------------------------------------------------------------------
# pack_mod.gd
# ---------------------------------------------------------------------------

func test_pack_release_rejects_draft_content_and_plain_pack_allows_it() -> void:
	var root := _temp_root("pack_draft")
	_write_mod(root, "sdk_pack_draft", {"content/weapons.json": _weapon_envelope("sdk_pack_draft")}, ["content.combat.v1"])
	var out := "user://sdk_test_pack_draft_out"
	SdkValidationCore.cleanup_stage(out)
	var release := _run_sdk(PACK_SCRIPT, PackedStringArray([
		"--source=%s/sdk_pack_draft" % root, "--out=%s" % out, "--release",
	]))
	assert_eq(int(release["exit"]), 1, "pack --release must reject unactivated draft content")
	assert_true(
		String(release["text"]).contains("inactive_content_type"),
		"pack --release prints the structured draft rejection:\n%s" % String(release["text"])
	)
	assert_false(
		FileAccess.file_exists("%s/sdk_pack_draft-0.1.0.snavmod.zip" % out),
		"a rejected release must not write a zip"
	)
	# Backward compatibility: plain packing still only packs.
	var plain := _run_sdk(PACK_SCRIPT, PackedStringArray([
		"--source=%s/sdk_pack_draft" % root, "--out=%s" % out,
	]))
	assert_eq(int(plain["exit"]), 0, "plain packing must keep the legacy behavior")
	assert_true(
		FileAccess.file_exists("%s/sdk_pack_draft-0.1.0.snavmod.zip" % out),
		"plain packing still writes the zip"
	)
	_clean(root)
	SdkValidationCore.cleanup_stage(out)


func test_pack_release_rejects_validation_errors() -> void:
	var root := _temp_root("pack_errors")
	_write_mod(root, "sdk_pack_bad", {"content/items.json": _item_envelope("sdk_pack_bad", "2.0", 0)}, ["content.items.v1"])
	var out := "user://sdk_test_pack_error_out"
	SdkValidationCore.cleanup_stage(out)
	var result := _run_sdk(PACK_SCRIPT, PackedStringArray([
		"--source=%s/sdk_pack_bad" % root, "--out=%s" % out, "--release",
	]))
	assert_eq(int(result["exit"]), 1, "pack --release must reject a mod with validation errors")
	assert_false(
		FileAccess.file_exists("%s/sdk_pack_bad-0.1.0.snavmod.zip" % out),
		"a rejected release must not write a zip"
	)
	_clean(root)
	SdkValidationCore.cleanup_stage(out)


func test_pack_release_keeps_the_snavmod_zip_layout() -> void:
	var out := "user://sdk_test_pack_layout_out"
	SdkValidationCore.cleanup_stage(out)
	var result := _run_sdk(PACK_SCRIPT, PackedStringArray([
		"--source=%s" % MIXED_EXAMPLE, "--out=%s" % out, "--release",
	]))
	assert_eq(int(result["exit"]), 0, "pack --release must accept a runtime-valid mixed mod")
	var pack_path := "%s/example_mixed_roles_items-1.0.0.snavmod.zip" % out
	assert_true(FileAccess.file_exists(pack_path), "release packing must write the zip")
	var reader := ZIPReader.new()
	var open_error := reader.open(pack_path)
	assert_eq(open_error, OK, "the release zip must be readable")
	if open_error == OK:
		var entries := reader.get_files()
		assert_true(entries.has("mods/example_mixed_roles_items/manifest.json"), "pack layout keeps mods/<id>/manifest.json")
		assert_true(entries.has("mods/example_mixed_roles_items/content/roles.json"), "pack layout keeps content files")
		assert_true(entries.has("mods/example_mixed_roles_items/content/items.json"), "pack layout keeps every content file")
		assert_false(entries.has("manifest.json"), "the zip must not flatten the manifest to its root")
		reader.close()
	SdkValidationCore.cleanup_stage(out)
