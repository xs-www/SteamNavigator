extends TestCase
## Guards the single-source content type manifest against the framework's
## runtime constants. Until generators consume content_types.json directly this
## test is what prevents the two lists from drifting apart.

const MANIFEST_PATH := "res://content_types.json"


func _manifest() -> Dictionary:
	var parsed := JsonUtils.parse_file(MANIFEST_PATH)
	if not bool(parsed.get("ok", false)):
		fail("content_types.json cannot be parsed: %s" % String(parsed.get("error", "")))
		return {}
	if not (parsed.get("value") is Dictionary):
		fail("content_types.json root is not an object")
		return {}
	return parsed["value"]


func test_manifest_matches_content_types() -> void:
	var data := _manifest()
	if data.is_empty():
		return
	assert_eq(String(data.get("format", "")), "steam-navigator-content-types", "manifest format")
	assert_eq(int(data.get("format_version", 0)), 1, "manifest format version")

	var types: Array = data.get("types", [])
	var manifest_keys: Array[String] = []
	var manifest_by_key: Dictionary = {}
	for entry in types:
		if not (entry is Dictionary):
			fail("manifest type entry is not an object")
			continue
		var key := String(entry.get("key", ""))
		manifest_by_key[key] = entry
		if String(entry.get("kind", "definition")) != "definition":
			continue
		manifest_keys.append(key)
	manifest_keys.sort()

	var framework_keys: Array[String] = []
	for content_type in ContentTypes.all():
		framework_keys.append(String(content_type))
	framework_keys.sort()
	assert_eq(manifest_keys, framework_keys, "manifest keys match ContentTypes.all()")

	for key in framework_keys:
		var entry: Dictionary = manifest_by_key[key]
		var content_type := StringName(key)
		assert_eq(String(entry.get("singular", "")), ContentTypes.singular(content_type), "%s singular" % key)
		assert_eq("res://" + String(entry.get("schema", "")), ContentTypes.schema_path(content_type), "%s schema path" % key)
		assert_true(FileAccess.file_exists(ContentTypes.schema_path(content_type)), "%s schema file exists" % key)
		assert_eq(String(entry.get("kind", "")), "definition", "%s is a definition type" % key)
		assert_true(bool(entry.get("registry", false)), "%s enters the registry" % key)

	var patch: Dictionary = manifest_by_key.get("patches", {})
	assert_eq(String(patch.get("singular", "")), ContentTypes.singular(ContentTypes.PATCH), "patch singular")
	assert_eq("res://" + String(patch.get("schema", "")), ContentTypes.schema_path(ContentTypes.PATCH), "patch schema path")
	assert_eq(String(patch.get("kind", "")), "patch", "patch kind")
	assert_false(bool(patch.get("registry", true)), "patches do not use a definition registry")


func test_manifest_entries_are_unique_and_complete() -> void:
	var data := _manifest()
	if data.is_empty():
		return
	var types: Array = data.get("types", [])
	assert_true(types.size() > 0, "manifest has content types")

	var group_ids: Dictionary = {}
	for group in data.get("groups", []):
		group_ids[String(group.get("id", ""))] = true

	var module_categories: Dictionary = {}
	for category in data.get("v2_module_categories", []):
		if not (category is Dictionary):
			fail("v2 module category is not an object")
			continue
		var category_id := String(category.get("id", ""))
		assert_false(module_categories.has(category_id), "duplicate v2 module category: %s" % category_id)
		module_categories[category_id] = true

	var keys: Dictionary = {}
	var singulars: Dictionary = {}
	var schemas: Dictionary = {}
	for entry in types:
		if not (entry is Dictionary):
			continue
		var key := String(entry.get("key", ""))
		var singular := String(entry.get("singular", ""))
		var schema := String(entry.get("schema", ""))
		assert_false(keys.has(key), "duplicate content type key: %s" % key)
		assert_false(singulars.has(singular), "duplicate singular: %s" % singular)
		assert_false(schemas.has(schema), "duplicate schema path: %s" % schema)
		keys[key] = true
		singulars[singular] = true
		schemas[schema] = true
		assert_true(group_ids.has(String(entry.get("group", ""))), "%s references a declared group" % key)
		assert_true(not String(entry.get("capability", "")).is_empty(), "%s declares a capability" % key)
		assert_true(entry.get("aliases", null) is Array, "%s aliases is an array" % key)
		var target: Variant = entry.get("v2_target", null)
		assert_true(target == null or target is String, "%s v2_target is null or a string" % key)
		assert_true(not String(entry.get("default_file", "")).is_empty(), "%s declares a default file" % key)
		if entry.has("v2_category"):
			assert_true(module_categories.has(String(entry["v2_category"])), "%s references a declared v2 module category" % key)


func test_merged_modules_and_hulls_are_active_2_0() -> void:
	var data := _manifest()
	if data.is_empty():
		return
	var by_key: Dictionary = {}
	for entry in data.get("types", []):
		if entry is Dictionary:
			by_key[String(entry.get("key", ""))] = entry
	assert_eq(String(by_key.get("modules", {}).get("schema_version", "")), "2.0", "modules is an active Schema 2.0 type")
	assert_eq(String(by_key.get("modules", {}).get("capability", "")), "content.modules.v1", "modules capability")
	assert_eq(String(by_key.get("modules", {}).get("schema", "")), "schemas/v2/module.schema.json", "modules schema path")
	assert_eq(String(by_key.get("hulls", {}).get("schema_version", "")), "2.0", "hulls is an active Schema 2.0 type")
	assert_eq(String(by_key.get("hulls", {}).get("schema", "")), "schemas/v2/hull.schema.json", "hulls schema path")
	for legacy in ["boilers", "cargo_modules", "navigation_modules", "safety_modules", "cabins"]:
		assert_false(by_key.has(legacy), "%s legacy module type is retired" % legacy)


func test_merged_items_are_active_2_0() -> void:
	var data := _manifest()
	if data.is_empty():
		return
	var by_key: Dictionary = {}
	for entry in data.get("types", []):
		if entry is Dictionary:
			by_key[String(entry.get("key", ""))] = entry
	assert_eq(String(by_key.get("items", {}).get("schema_version", "")), "2.0", "items is an active Schema 2.0 type")
	assert_eq(String(by_key.get("items", {}).get("capability", "")), "content.items.v1", "items capability")
	assert_eq(String(by_key.get("items", {}).get("schema", "")), "schemas/v2/item.schema.json", "items schema path")
	assert_eq(String(by_key.get("items", {}).get("singular", "")), "item", "items singular")
	for legacy in ["goods", "materials"]:
		assert_false(by_key.has(legacy), "%s legacy type is retired" % legacy)
	assert_eq(ContentTypes.schema_version(ContentTypes.ITEM), "2.0", "runtime ITEM version matches the manifest")
	assert_eq(ContentTypes.schema_path(ContentTypes.ITEM), "res://schemas/v2/item.schema.json", "runtime ITEM schema path")


func test_planned_types_do_not_shadow_active_types() -> void:
	var data := _manifest()
	if data.is_empty():
		return
	var active: Dictionary = {}
	for entry in data.get("types", []):
		if entry is Dictionary:
			active[String(entry.get("key", ""))] = true
	var planned: Array = data.get("planned", [])
	assert_true(planned.size() > 0, "roadmap systems are listed")
	for system in planned:
		if not (system is Dictionary):
			fail("planned entry is not an object")
			continue
		assert_true(not String(system.get("capability", "")).is_empty(), "planned system declares a capability")
		for type_name in system.get("types", []):
			assert_false(active.has(String(type_name)), "planned type shadows active type: %s" % String(type_name))
