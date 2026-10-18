extends TestCase


func test_core_goods_schema_is_valid() -> void:
	var parsed := JsonUtils.parse_file("res://dev_mods/core/content/goods.json")
	assert_true(bool(parsed["ok"]), "goods.json parses")
	var validator := SchemaValidator.new()
	var errors := validator.validate_file(parsed["value"], ContentTypes.schema_path(ContentTypes.GOOD))
	assert_eq(errors.size(), 0, "core goods pass schema: %s" % str(errors))


func test_invalid_good_reports_pointer() -> void:
	var parsed := JsonUtils.parse_file("res://dev_mods/core/content/goods.json")
	var envelope: Dictionary = parsed["value"].duplicate(true)
	var definitions: Array = envelope["definitions"]
	var first: Dictionary = definitions[0]
	var data: Dictionary = first["data"]
	data["unit_weight"] = -1
	var validator := SchemaValidator.new()
	var errors := validator.validate_file(envelope, ContentTypes.schema_path(ContentTypes.GOOD))
	assert_true(not errors.is_empty(), "negative weight is rejected")
	var paths := PackedStringArray()
	for error in errors:
		paths.append(String(error["path"]))
	assert_contains(paths, "/definitions/0/data/unit_weight", "error points at the offending field")


func test_manifest_schema() -> void:
	var parsed := JsonUtils.parse_file("res://dev_mods/core/manifest.json")
	var validator := SchemaValidator.new()
	var errors := validator.validate_file(parsed["value"], ModManifest.MANIFEST_SCHEMA_PATH)
	assert_eq(errors.size(), 0, "core manifest passes schema")
	var bad: Dictionary = parsed["value"].duplicate(true)
	bad["id"] = "X"
	var bad_errors := validator.validate_file(bad, ModManifest.MANIFEST_SCHEMA_PATH)
	assert_true(not bad_errors.is_empty(), "invalid mod id is rejected")


func test_missing_required_field() -> void:
	var envelope := {
		"schema_version": "1.0",
		"content_type": "goods",
		"definitions": [{
			"id": "testmod:good/x",
			"name_key": "x.name",
			"enabled": true,
			"data": {},
		}],
	}
	var validator := SchemaValidator.new()
	var errors := validator.validate_file(envelope, ContentTypes.schema_path(ContentTypes.GOOD))
	assert_true(not errors.is_empty(), "missing goods fields are rejected")
