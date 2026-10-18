class_name SemVer
extends RefCounted
## Minimal Semantic Versioning 2.0 value object.

var major: int = 0
var minor: int = 0
var patch: int = 0
var prerelease: String = ""
var build: String = ""


static func parse(text: String) -> SemVer:
	var regex := RegEx.new()
	var compile_error := regex.compile(
		"^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z.-]+))?(?:\\+([0-9A-Za-z.-]+))?$"
	)
	if compile_error != OK:
		return null
	var match_result := regex.search(text.strip_edges())
	if match_result == null:
		return null
	var version := SemVer.new()
	version.major = int(match_result.get_string(1))
	version.minor = int(match_result.get_string(2))
	version.patch = int(match_result.get_string(3))
	version.prerelease = match_result.get_string(4)
	version.build = match_result.get_string(5)
	return version


static func is_valid(text: String) -> bool:
	return parse(text) != null


func compare_to(other: SemVer) -> int:
	if other == null:
		return 1
	if major != other.major:
		return 1 if major > other.major else -1
	if minor != other.minor:
		return 1 if minor > other.minor else -1
	if patch != other.patch:
		return 1 if patch > other.patch else -1
	if prerelease == other.prerelease:
		return 0
	if prerelease.is_empty():
		return 1
	if other.prerelease.is_empty():
		return -1
	return _compare_prerelease(prerelease, other.prerelease)


func _compare_prerelease(left: String, right: String) -> int:
	var left_parts := left.split(".")
	var right_parts := right.split(".")
	var count := mini(left_parts.size(), right_parts.size())
	for index in count:
		var a := left_parts[index]
		var b := right_parts[index]
		var a_numeric := a.is_valid_int()
		var b_numeric := b.is_valid_int()
		if a_numeric and b_numeric:
			var ai := int(a)
			var bi := int(b)
			if ai != bi:
				return 1 if ai > bi else -1
		elif a_numeric != b_numeric:
			return -1 if a_numeric else 1
		elif a != b:
			return 1 if a > b else -1
	if left_parts.size() == right_parts.size():
		return 0
	return -1 if left_parts.size() < right_parts.size() else 1


func as_text() -> String:
	var text := "%d.%d.%d" % [major, minor, patch]
	if not prerelease.is_empty():
		text += "-" + prerelease
	if not build.is_empty():
		text += "+" + build
	return text
