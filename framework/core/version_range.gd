class_name VersionRange
extends RefCounted
## A small, deterministic version-range evaluator.
##
## Supported forms:
##   * / empty                 any version
##   1.2.3                     exact
##   =1.2.3, >1.0.0, <=2.0.0   comparators
##   >=1.0.0 <2.0.0            space/comma separated AND group
##   ^1.2.3, ~1.2.3            caret / tilde
##   >=1.0.0 <2.0.0 || 3.0.0   OR groups
##
## Expressions are intentionally not a scripting language.

var raw: String = ""
var groups: Array = []  # Array[Array[Dictionary]]: comparator groups, OR-ed.
var error: String = ""


static func parse(text: String) -> VersionRange:
	var result := VersionRange.new()
	result.raw = text.strip_edges()
	if result.raw.is_empty() or result.raw == "*":
		return result
	for or_part in result.raw.split("||"):
		var cleaned := or_part.replace(",", " ")
		var tokens := PackedStringArray()
		for token in cleaned.split(" ", false):
			if not token.is_empty():
				tokens.append(token)
		if tokens.is_empty():
			continue
		var comparators: Array = []
		for token in tokens:
			var parsed := _parse_token(token)
			if parsed.is_empty():
				result.error = "invalid version comparator: %s" % token
				return result
			comparators.append_array(parsed)
		result.groups.append(comparators)
	return result


static func _parse_token(token: String) -> Array:
	if token == "*":
		return []
	if token.begins_with("^"):
		var version := SemVer.parse(token.substr(1))
		if version == null:
			return []
		var upper := SemVer.new()
		if version.major > 0:
			upper.major = version.major + 1
		elif version.minor > 0:
			upper.minor = version.minor + 1
		else:
			upper.patch = version.patch + 1
		return [{"op": ">=", "version": version}, {"op": "<", "version": upper}]
	if token.begins_with("~"):
		var version := SemVer.parse(token.substr(1))
		if version == null:
			return []
		var upper := SemVer.new()
		upper.major = version.major
		upper.minor = version.minor + 1
		return [{"op": ">=", "version": version}, {"op": "<", "version": upper}]
	for op in [">=", "<=", ">", "<", "="]:
		if token.begins_with(op):
			var version := SemVer.parse(token.substr(op.length()))
			if version == null:
				return []
			return [{"op": op, "version": version}]
	var exact := SemVer.parse(token)
	if exact == null:
		return []
	return [{"op": "=", "version": exact}]


func matches(version: SemVer) -> bool:
	if version == null or not error.is_empty():
		return false
	if groups.is_empty():
		return true
	for comparators in groups:
		var all_match := true
		for comparator in comparators:
			if not _matches_comparator(version, comparator):
				all_match = false
				break
		if all_match:
			return true
	return false


func _matches_comparator(version: SemVer, comparator: Dictionary) -> bool:
	var target: SemVer = comparator["version"]
	var result := version.compare_to(target)
	match String(comparator["op"]):
		">=":
			return result >= 0
		"<=":
			return result <= 0
		">":
			return result > 0
		"<":
			return result < 0
		"=":
			return result == 0
		_:
			return false
