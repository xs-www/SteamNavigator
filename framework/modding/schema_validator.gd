class_name SchemaValidator
extends RefCounted
## A deliberately small JSON Schema validator.
##
## Supported keywords: type, properties, required, additionalProperties,
## patternProperties, items, prefixItems, minItems, maxItems, uniqueItems,
## minProperties, maxProperties, minLength, maxLength, pattern, enum, const,
## minimum, maximum, exclusiveMinimum, exclusiveMaximum, allOf, anyOf, oneOf,
## not, $ref (local pointers and sibling .schema.json files), $defs.
##
## Not supported: remote HTTP refs, if/then/else, dependencies, contains,
## propertyNames, format assertions and unevaluatedProperties. The framework
## schemas stay inside this subset on purpose.

const MAX_DEPTH := 64
const MAX_ERRORS := 200

var _errors: Array[Dictionary] = []
var _schema_cache: Dictionary = {}
var _regex_cache: Dictionary = {}


func validate(instance: Variant, schema: Dictionary, base_dir: String = "", root_schema: Dictionary = {}) -> Array[Dictionary]:
	_errors = []
	var root := root_schema if not root_schema.is_empty() else schema
	var context := {"root": root, "base_dir": base_dir, "depth": 0}
	_validate(instance, schema, "", context)
	return _errors.duplicate(true)


func validate_file(instance: Variant, schema_path: String) -> Array[Dictionary]:
	var loaded := _load_schema(schema_path)
	if not loaded["ok"]:
		return [{
			"path": "/",
			"keyword": "schema",
			"message": loaded["error"],
		}]
	var schema: Dictionary = loaded["schema"]
	return validate(instance, schema, schema_path.get_base_dir(), schema)


func _validate(value: Variant, schema: Dictionary, pointer: String, context: Dictionary) -> bool:
	if _errors.size() >= MAX_ERRORS:
		return false
	if context["depth"] > MAX_DEPTH:
		_add_error(pointer, "depth", "schema nesting exceeds %d levels" % MAX_DEPTH)
		return false

	if schema.has("$ref"):
		var resolved := _resolve_ref(String(schema["$ref"]), context)
		if not resolved["ok"]:
			_add_error(pointer, "$ref", resolved["error"])
			return false
		var child_context := {
			"root": resolved["root"],
			"base_dir": resolved["base_dir"],
			"depth": int(context["depth"]) + 1,
		}
		return _validate(value, resolved["schema"], pointer, child_context)

	var start_errors := _errors.size()
	_validate_value_keywords(value, schema, pointer)
	_validate_combinators(value, schema, pointer, context)
	match typeof(value):
		TYPE_DICTIONARY:
			_validate_object(value, schema, pointer, context)
		TYPE_ARRAY:
			_validate_array(value, schema, pointer, context)
		TYPE_STRING, TYPE_STRING_NAME:
			_validate_string(String(value), schema, pointer)
		TYPE_INT, TYPE_FLOAT:
			_validate_number(float(value), schema, pointer)
	return _errors.size() == start_errors


func _validate_value_keywords(value: Variant, schema: Dictionary, pointer: String) -> void:
	if schema.has("const") and not _values_equal(value, schema["const"]):
		_add_error(pointer, "const", "value must equal the declared constant")
	if schema.has("enum") and schema["enum"] is Array:
		var matched := false
		for candidate in schema["enum"]:
			if _values_equal(value, candidate):
				matched = true
				break
		if not matched:
			_add_error(pointer, "enum", "value is not one of the allowed values")
	if schema.has("type"):
		var type_value: Variant = schema["type"]
		if type_value is Array:
			var type_matched := false
			for candidate in type_value:
				if _matches_type(value, String(candidate)):
					type_matched = true
					break
			if not type_matched:
				_add_error(pointer, "type", "expected one of %s" % str(type_value))
		elif not _matches_type(value, String(type_value)):
			_add_error(pointer, "type", "expected %s" % String(type_value))


func _validate_combinators(value: Variant, schema: Dictionary, pointer: String, context: Dictionary) -> void:
	if schema.has("allOf") and schema["allOf"] is Array:
		for sub_schema in schema["allOf"]:
			if sub_schema is Dictionary:
				_validate(value, sub_schema, pointer, _next_context(context))
	if schema.has("anyOf") and schema["anyOf"] is Array:
		var matched := false
		for sub_schema in schema["anyOf"]:
			if sub_schema is Dictionary and _passes(value, sub_schema, pointer, context):
				matched = true
				break
		if not matched:
			_add_error(pointer, "anyOf", "value does not match any allowed schema")
	if schema.has("oneOf") and schema["oneOf"] is Array:
		var match_count := 0
		for sub_schema in schema["oneOf"]:
			if sub_schema is Dictionary and _passes(value, sub_schema, pointer, context):
				match_count += 1
		if match_count != 1:
			_add_error(pointer, "oneOf", "value matches %d schemas; exactly one is required" % match_count)
	if schema.has("not") and schema["not"] is Dictionary:
		if _passes(value, schema["not"], pointer, context):
			_add_error(pointer, "not", "value matches a forbidden schema")


func _validate_object(value: Dictionary, schema: Dictionary, pointer: String, context: Dictionary) -> void:
	if schema.has("minProperties") and value.size() < int(schema["minProperties"]):
		_add_error(pointer, "minProperties", "object has fewer than %d properties" % int(schema["minProperties"]))
	if schema.has("maxProperties") and value.size() > int(schema["maxProperties"]):
		_add_error(pointer, "maxProperties", "object has more than %d properties" % int(schema["maxProperties"]))

	var declared_properties: Dictionary = schema.get("properties", {})
	if schema.has("required") and schema["required"] is Array:
		for required_key in schema["required"]:
			if not value.has(String(required_key)):
				_add_error(_child_pointer(pointer, String(required_key)), "required", "required property is missing")

	var pattern_properties: Dictionary = schema.get("patternProperties", {})
	for key in value.keys():
		var key_text := String(key)
		var covered := false
		if declared_properties.has(key_text):
			covered = true
			var property_schema: Variant = declared_properties[key_text]
			if property_schema is Dictionary:
				_validate(value[key], property_schema, _child_pointer(pointer, key_text), _next_context(context))
		for pattern in pattern_properties.keys():
			var regex := _get_regex(String(pattern))
			if regex != null and regex.search(key_text) != null:
				covered = true
				var pattern_schema: Variant = pattern_properties[pattern]
				if pattern_schema is Dictionary:
					_validate(value[key], pattern_schema, _child_pointer(pointer, key_text), _next_context(context))
		if not covered:
			if schema.has("additionalProperties"):
				var additional: Variant = schema["additionalProperties"]
				if additional is bool and not additional:
					_add_error(_child_pointer(pointer, key_text), "additionalProperties", "property is not allowed")
				elif additional is Dictionary:
					_validate(value[key], additional, _child_pointer(pointer, key_text), _next_context(context))


func _validate_array(value: Array, schema: Dictionary, pointer: String, context: Dictionary) -> void:
	if schema.has("minItems") and value.size() < int(schema["minItems"]):
		_add_error(pointer, "minItems", "array has fewer than %d items" % int(schema["minItems"]))
	if schema.has("maxItems") and value.size() > int(schema["maxItems"]):
		_add_error(pointer, "maxItems", "array has more than %d items" % int(schema["maxItems"]))
	if schema.has("uniqueItems") and bool(schema["uniqueItems"]):
		var seen := {}
		for index in value.size():
			var fingerprint := JsonUtils.canonical_stringify(value[index])
			if seen.has(fingerprint):
				_add_error(_child_pointer(pointer, str(index)), "uniqueItems", "array items must be unique")
			seen[fingerprint] = true

	var prefix_count := 0
	if schema.has("prefixItems") and schema["prefixItems"] is Array:
		var prefixes: Array = schema["prefixItems"]
		prefix_count = mini(prefixes.size(), value.size())
		for index in prefix_count:
			if prefixes[index] is Dictionary:
				_validate(value[index], prefixes[index], _child_pointer(pointer, str(index)), _next_context(context))

	if schema.has("items"):
		var items_schema: Variant = schema["items"]
		if items_schema is Dictionary:
			for index in range(prefix_count, value.size()):
				_validate(value[index], items_schema, _child_pointer(pointer, str(index)), _next_context(context))
		elif items_schema is Array:
			var tuple_schemas: Array = items_schema
			var limit := mini(tuple_schemas.size(), value.size())
			for index in limit:
				if tuple_schemas[index] is Dictionary:
					_validate(value[index], tuple_schemas[index], _child_pointer(pointer, str(index)), _next_context(context))


func _validate_string(value: String, schema: Dictionary, pointer: String) -> void:
	if schema.has("minLength") and value.length() < int(schema["minLength"]):
		_add_error(pointer, "minLength", "string is shorter than %d characters" % int(schema["minLength"]))
	if schema.has("maxLength") and value.length() > int(schema["maxLength"]):
		_add_error(pointer, "maxLength", "string is longer than %d characters" % int(schema["maxLength"]))
	if schema.has("pattern"):
		var regex := _get_regex(String(schema["pattern"]))
		if regex == null:
			_add_error(pointer, "pattern", "invalid schema pattern: %s" % String(schema["pattern"]))
		elif regex.search(value) == null:
			_add_error(pointer, "pattern", "string does not match /%s/" % String(schema["pattern"]))


func _validate_number(value: float, schema: Dictionary, pointer: String) -> void:
	if schema.has("minimum") and value < float(schema["minimum"]):
		_add_error(pointer, "minimum", "value is below %s" % str(schema["minimum"]))
	if schema.has("maximum") and value > float(schema["maximum"]):
		_add_error(pointer, "maximum", "value is above %s" % str(schema["maximum"]))
	if schema.has("exclusiveMinimum"):
		var minimum: Variant = schema["exclusiveMinimum"]
		if minimum is bool:
			if minimum and schema.has("minimum") and value <= float(schema["minimum"]):
				_add_error(pointer, "exclusiveMinimum", "value must be greater than %s" % str(schema["minimum"]))
		elif value <= float(minimum):
			_add_error(pointer, "exclusiveMinimum", "value must be greater than %s" % str(minimum))
	if schema.has("exclusiveMaximum"):
		var maximum: Variant = schema["exclusiveMaximum"]
		if maximum is bool:
			if maximum and schema.has("maximum") and value >= float(schema["maximum"]):
				_add_error(pointer, "exclusiveMaximum", "value must be less than %s" % str(schema["maximum"]))
		elif value >= float(maximum):
			_add_error(pointer, "exclusiveMaximum", "value must be less than %s" % str(maximum))


func _matches_type(value: Variant, expected: String) -> bool:
	match expected:
		"object":
			return typeof(value) == TYPE_DICTIONARY
		"array":
			return typeof(value) == TYPE_ARRAY
		"string":
			return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
		"number":
			return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
		"integer":
			if typeof(value) == TYPE_INT:
				return true
			if typeof(value) == TYPE_FLOAT:
				return absf(float(value) - round(float(value))) < 0.000001
			return false
		"boolean":
			return typeof(value) == TYPE_BOOL
		"null":
			return value == null
		_:
			return false


func _passes(value: Variant, schema: Dictionary, pointer: String, context: Dictionary) -> bool:
	var saved_errors := _errors
	_errors = []
	var passed := _validate(value, schema, pointer, _next_context(context))
	_errors = saved_errors
	return passed


func _resolve_ref(ref: String, context: Dictionary) -> Dictionary:
	var file_part := ref
	var pointer_part := ""
	var hash_index := ref.find("#")
	if hash_index >= 0:
		file_part = ref.substr(0, hash_index)
		pointer_part = ref.substr(hash_index + 1)

	var target_root: Dictionary = context["root"]
	var target_base_dir := String(context["base_dir"])
	if not file_part.is_empty():
		var path := file_part
		if not path.begins_with("res://") and not path.begins_with("user://"):
			path = target_base_dir.path_join(file_part)
		var loaded := _load_schema(path)
		if not loaded["ok"]:
			return {"ok": false, "error": loaded["error"]}
		target_root = loaded["schema"]
		target_base_dir = path.get_base_dir()

	if pointer_part.is_empty():
		return {"ok": true, "schema": target_root, "root": target_root, "base_dir": target_base_dir}
	var pointer := pointer_part if pointer_part.begins_with("/") else "/" + pointer_part
	var result := JsonUtils.pointer_get(target_root, pointer)
	if not result["ok"]:
		return {"ok": false, "error": "unresolved $ref '%s': %s" % [ref, result["error"]]}
	if not (result["value"] is Dictionary):
		return {"ok": false, "error": "$ref '%s' does not point to a schema object" % ref}
	return {
		"ok": true,
		"schema": result["value"],
		"root": target_root,
		"base_dir": target_base_dir,
	}


func _load_schema(path: String) -> Dictionary:
	if _schema_cache.has(path):
		return _schema_cache[path]
	if not FileAccess.file_exists(path):
		var missing := {"ok": false, "error": "schema file not found: %s" % path}
		_schema_cache[path] = missing
		return missing
	var parsed := JsonUtils.parse_file(path)
	if not parsed["ok"]:
		var broken := {
			"ok": false,
			"error": "cannot parse schema %s at line %d: %s" % [path, int(parsed["line"]), parsed["error"]],
		}
		_schema_cache[path] = broken
		return broken
	if not (parsed["value"] is Dictionary):
		var not_object := {"ok": false, "error": "schema root is not an object: %s" % path}
		_schema_cache[path] = not_object
		return not_object
	var loaded := {"ok": true, "schema": parsed["value"]}
	_schema_cache[path] = loaded
	return loaded


func _get_regex(pattern: String) -> RegEx:
	if _regex_cache.has(pattern):
		return _regex_cache[pattern]
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		_regex_cache[pattern] = null
		return null
	_regex_cache[pattern] = regex
	return regex


func _next_context(context: Dictionary) -> Dictionary:
	return {
		"root": context["root"],
		"base_dir": context["base_dir"],
		"depth": int(context["depth"]) + 1,
	}


func _child_pointer(pointer: String, key: String) -> String:
	return pointer + "/" + JsonUtils.pointer_escape(key)


func _add_error(pointer: String, keyword: String, message: String) -> void:
	if _errors.size() >= MAX_ERRORS:
		return
	_errors.append({
		"path": pointer if not pointer.is_empty() else "/",
		"keyword": keyword,
		"message": message,
	})


func _values_equal(left: Variant, right: Variant) -> bool:
	var left_is_number := typeof(left) == TYPE_INT or typeof(left) == TYPE_FLOAT
	var right_is_number := typeof(right) == TYPE_INT or typeof(right) == TYPE_FLOAT
	if left_is_number and right_is_number:
		return is_equal_approx(float(left), float(right))
	if typeof(left) != typeof(right):
		return false
	if left is Array and right is Array:
		if left.size() != right.size():
			return false
		for index in left.size():
			if not _values_equal(left[index], right[index]):
				return false
		return true
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return false
		for key in left.keys():
			if not right.has(key) or not _values_equal(left[key], right[key]):
				return false
		return true
	return left == right
