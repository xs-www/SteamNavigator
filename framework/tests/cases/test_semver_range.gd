extends TestCase


func test_semver_parsing() -> void:
	var version := SemVer.parse("1.2.3")
	assert_not_null(version, "valid semver parses")
	assert_eq(version.major, 1, "major")
	assert_eq(version.minor, 2, "minor")
	assert_eq(version.patch, 3, "patch")
	assert_eq(version.as_text(), "1.2.3", "round trip text")
	assert_true(SemVer.parse("1.2") == null, "two-part version is invalid")
	assert_true(SemVer.parse("01.2.3") == null, "leading zero is invalid")
	assert_true(SemVer.parse("1.2.3-beta.1") != null, "prerelease parses")


func test_semver_ordering() -> void:
	assert_eq(SemVer.parse("1.2.3").compare_to(SemVer.parse("1.2.4")), -1, "patch ordering")
	assert_eq(SemVer.parse("1.3.0").compare_to(SemVer.parse("1.2.9")), 1, "minor ordering")
	assert_eq(SemVer.parse("1.2.3").compare_to(SemVer.parse("1.2.3")), 0, "equality")
	assert_eq(SemVer.parse("1.2.3-beta").compare_to(SemVer.parse("1.2.3")), -1, "prerelease below release")


func test_version_ranges() -> void:
	var range := VersionRange.parse(">=1.0.0 <2.0.0")
	assert_true(range.matches(SemVer.parse("1.5.0")), "range includes 1.5.0")
	assert_false(range.matches(SemVer.parse("2.0.0")), "range excludes 2.0.0")
	assert_false(range.matches(SemVer.parse("0.9.9")), "range excludes 0.9.9")
	var caret := VersionRange.parse("^1.2.3")
	assert_true(caret.matches(SemVer.parse("1.9.9")), "caret includes patch/minor")
	assert_false(caret.matches(SemVer.parse("2.0.0")), "caret excludes next major")
	var tilde := VersionRange.parse("~1.2.3")
	assert_true(tilde.matches(SemVer.parse("1.2.9")), "tilde includes patch")
	assert_false(tilde.matches(SemVer.parse("1.3.0")), "tilde excludes next minor")
	var any_range := VersionRange.parse("*")
	assert_true(any_range.matches(SemVer.parse("9.9.9")), "wildcard accepts anything")
	var broken := VersionRange.parse(">=")
	assert_false(broken.error.is_empty(), "invalid comparator reports error")
