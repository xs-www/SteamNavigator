extends TestCase


func _collect_gd_files(root: String, relative: String, output: PackedStringArray) -> void:
	var path := root if relative.is_empty() else root + "/" + relative
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		var child := file_name if relative.is_empty() else relative + "/" + file_name
		if file_name.ends_with(".gd"):
			output.append(child)
	for directory_name in directory.get_directories():
		if directory_name == "tests":
			continue
		var child := directory_name if relative.is_empty() else relative + "/" + directory_name
		_collect_gd_files(root, child, output)


func test_framework_has_no_concrete_core_ids() -> void:
	var files := PackedStringArray()
	_collect_gd_files("res://framework", "", files)
	var regex := RegEx.new()
	regex.compile("core:[a-z_]+/")
	var offenders := PackedStringArray()
	for relative_path in files:
		var text := FileAccess.get_file_as_string("res://framework/" + relative_path)
		if regex.search(text) != null:
			offenders.append(relative_path)
	assert_true(offenders.is_empty(), "framework code must not hardcode core:* IDs: %s" % ", ".join(offenders))
