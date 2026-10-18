extends TestCase


func _walk(root: String, relative: String, output: PackedStringArray) -> void:
	var path := root if relative.is_empty() else root + "/" + relative
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		var child := file_name if relative.is_empty() else relative + "/" + file_name
		if file_name.ends_with(".import") or file_name.ends_with(".uid"):
			continue
		output.append(child)
	for directory_name in directory.get_directories():
		var child := directory_name if relative.is_empty() else relative + "/" + directory_name
		_walk(root, child, output)


func _clear_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(directory_path + "/" + file_name)


func _pack_core_to_zip(pack_path: String) -> bool:
	var directory_path := pack_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory_path)
	_clear_directory(directory_path)
	if FileAccess.file_exists(pack_path):
		DirAccess.remove_absolute(pack_path)
	var files := PackedStringArray()
	_walk("res://dev_mods/core", "", files)
	var packer := ZIPPacker.new()
	if packer.open(pack_path) != OK:
		return false
	for relative_path in files:
		var bytes := FileAccess.get_file_as_bytes("res://dev_mods/core/" + relative_path)
		if packer.start_file("mods/core/" + relative_path) != OK:
			packer.close()
			return false
		packer.write_file(bytes)
		packer.close_file()
	packer.close()
	return true


func test_core_loads_from_zip_pack() -> void:
	var pack_path := "user://test_packs/core-1.0.0.snavmod.zip"
	assert_true(_pack_core_to_zip(pack_path), "core pack is created")
	assert_true(FileAccess.file_exists(pack_path), "pack file exists")
	var bootstrap := Bootstrap.new()
	var report := bootstrap.run({
		"scan_roots": PackedStringArray(["user://test_packs"]),
		"allow_loose": false,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://test_saves/zip_%d" % Time.get_ticks_usec(),
	})
	assert_true(not report.has_fatal(), "zip core bootstrap has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "zip core bootstrap is OK")
	assert_eq(report.mods.size(), 1, "one zipped mod loaded")
	assert_eq(String(report.mods[0]["id"]), "core", "zip mod id is core")
	assert_true(String(report.mods[0]["source"]).ends_with(".zip"), "source is the zip pack")
	assert_true(report.content_total() >= 45, "zip core provides the full content set")


func test_zip_namespace_is_enforced() -> void:
	var bad_path := "user://test_packs_bad/bad-1.0.0.snavmod.zip"
	DirAccess.make_dir_recursive_absolute(bad_path.get_base_dir())
	_clear_directory(bad_path.get_base_dir())
	if FileAccess.file_exists(bad_path):
		DirAccess.remove_absolute(bad_path)
	var packer := ZIPPacker.new()
	packer.open(bad_path)
	packer.start_file("manifest.json")
	packer.write_file("{}".to_utf8_buffer())
	packer.close_file()
	packer.close()
	var bootstrap := Bootstrap.new()
	var report := bootstrap.run({
		"scan_roots": PackedStringArray(["user://test_packs_bad"]),
		"allow_loose": false,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
	})
	var messages := PackedStringArray()
	for error in report.errors:
		messages.append(String(error.get("message", "")))
	assert_true(
		"\n".join(messages).contains("namespace") or "\n".join(messages).contains("manifest"),
		"malformed zip is rejected with a meaningful error"
	)
