class_name JsonUtils
extends RefCounted
## JSON parsing, canonical serialization and JSON Pointer helpers.

const NULL_VALUE := null


static func parse(text: String) -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK:
		return {
			"ok": false,
			"value": null,
			"error": parser.get_error_message(),
			"line": parser.get_error_line(),
		}
	return {"ok": true, "value": parser.data, "error": "", "line": 0}


static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "value": null, "error": "file not found", "line": 0}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "value": null, "error": "cannot open file", "line": 0}
	return parse(file.get_as_text())


static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func canonical_stringify(value: Variant, indent: String = "") -> String:
	return JSON.stringify(_canonicalize(value), indent, true, true)


static func _canonicalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var output := {}
			for key in value.keys():
				output[String(key)] = _canonicalize(value[key])
			return output
		TYPE_ARRAY:
			var output: Array = []
			for item in value:
				output.append(_canonicalize(item))
			return output
		TYPE_STRING_NAME:
			return String(value)
		TYPE_PACKED_STRING_ARRAY:
			return Array(value)
		TYPE_FLOAT:
			# JSON has one number type and round-tripping a double is not
			# bit-exact on every platform. Quantise to nanoseconds-scale
			# precision so save/load fingerprints match deterministically.
			var number: float = snappedf(value, 0.000000001)
			if is_finite(number) and absf(number) < 9.0e15 and is_equal_approx(number, round(number)):
				return int(round(number))
			return number
		_:
			return value


static func pointer_escape(segment: String) -> String:
	return segment.replace("~", "~0").replace("/", "~1")


static func pointer_unescape(segment: String) -> String:
	return segment.replace("~1", "/").replace("~0", "~")


static func pointer_segments(pointer: String) -> PackedStringArray:
	if pointer.is_empty() or pointer == "/":
		return PackedStringArray()
	var body := pointer.trim_prefix("/")
	var result := PackedStringArray()
	for segment in body.split("/"):
		result.append(pointer_unescape(segment))
	return result


static func pointer_get(root: Variant, pointer: String) -> Dictionary:
	var current: Variant = root
	for raw_segment in pointer_segments(pointer):
		if typeof(current) == TYPE_DICTIONARY:
			var dictionary: Dictionary = current
			if not dictionary.has(raw_segment):
				return {"ok": false, "value": null, "error": "missing key '%s'" % raw_segment}
			current = dictionary[raw_segment]
		elif typeof(current) == TYPE_ARRAY:
			var array: Array = current
			if not raw_segment.is_valid_int():
				return {"ok": false, "value": null, "error": "array index expected at '%s'" % raw_segment}
			var index := int(raw_segment)
			if index < 0 or index >= array.size():
				return {"ok": false, "value": null, "error": "array index out of bounds: %d" % index}
			current = array[index]
		else:
			return {"ok": false, "value": null, "error": "cannot traverse scalar at '%s'" % raw_segment}
	return {"ok": true, "value": current, "error": ""}


## Applies a JSON Pointer operation. `mode` is one of add / replace / remove.
static func pointer_apply(root: Variant, pointer: String, mode: String, value: Variant = null) -> Dictionary:
	if pointer.is_empty() or pointer == "/":
		return {"ok": false, "error": "root replacement is not allowed"}
	var segments := pointer_segments(pointer)
	return _apply_recursive(root, segments, 0, mode, value)


static func _apply_recursive(node: Variant, segments: PackedStringArray, index: int, mode: String, value: Variant) -> Dictionary:
	var segment := segments[index]
	var last := index == segments.size() - 1
	if typeof(node) == TYPE_DICTIONARY:
		var dictionary: Dictionary = node
		if last:
			if mode == "replace" and not dictionary.has(segment):
				return {"ok": false, "error": "replace target does not exist: %s" % segment}
			if mode == "remove":
				if not dictionary.has(segment):
					return {"ok": false, "error": "remove target does not exist: %s" % segment}
				dictionary.erase(segment)
				return {"ok": true, "error": ""}
			dictionary[segment] = value
			return {"ok": true, "error": ""}
		if not dictionary.has(segment):
			if mode == "add":
				dictionary[segment] = {}
			else:
				return {"ok": false, "error": "missing intermediate key: %s" % segment}
		return _apply_recursive(dictionary[segment], segments, index + 1, mode, value)
	if typeof(node) == TYPE_ARRAY:
		var array: Array = node
		if segment == "-" and last:
			if mode == "remove":
				return {"ok": false, "error": "cannot remove '-' array element"}
			array.append(value)
			return {"ok": true, "error": ""}
		if not segment.is_valid_int():
			return {"ok": false, "error": "array index expected: %s" % segment}
		var array_index := int(segment)
		if last:
			if mode == "add":
				if array_index < 0 or array_index > array.size():
					return {"ok": false, "error": "array add index out of bounds: %d" % array_index}
				array.insert(array_index, value)
				return {"ok": true, "error": ""}
			if array_index < 0 or array_index >= array.size():
				return {"ok": false, "error": "array index out of bounds: %d" % array_index}
			if mode == "remove":
				array.remove_at(array_index)
				return {"ok": true, "error": ""}
			array[array_index] = value
			return {"ok": true, "error": ""}
		if array_index < 0 or array_index >= array.size():
			return {"ok": false, "error": "array index out of bounds: %d" % array_index}
		return _apply_recursive(array[array_index], segments, index + 1, mode, value)
	return {"ok": false, "error": "cannot descend into scalar at '%s'" % segment}


static func format_pointer(segments: Array) -> String:
	if segments.is_empty():
		return "/"
	var parts := PackedStringArray()
	for segment in segments:
		parts.append(pointer_escape(String(segment)))
	return "/" + "/".join(parts)
