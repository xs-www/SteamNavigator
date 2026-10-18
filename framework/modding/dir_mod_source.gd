class_name DirModSource
extends ModSource
## A loose mod directory. Debug builds only by default.

var _root: String = ""


func _init(root: String, id: String = "") -> void:
	_root = root.rstrip("/")
	mod_id = id
	origin = _root


func exists(relative_path: String) -> bool:
	return FileAccess.file_exists(_absolute(relative_path))


func read_text(relative_path: String) -> String:
	return JsonUtils.read_text(_absolute(relative_path))


func read_bytes(relative_path: String) -> PackedByteArray:
	if not exists(relative_path):
		return PackedByteArray()
	var file := FileAccess.open(_absolute(relative_path), FileAccess.READ)
	if file == null:
		return PackedByteArray()
	return file.get_buffer(file.get_length())


func list_files() -> PackedStringArray:
	var result := PackedStringArray()
	_walk("", result, 0)
	return result


func _walk(relative_dir: String, output: PackedStringArray, depth: int) -> void:
	if depth > 16:
		return
	var directory_path := _root if relative_dir.is_empty() else _root + "/" + relative_dir
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.include_hidden = true
	directory.include_navigational = false
	for file_name in directory.get_files():
		output.append(file_name if relative_dir.is_empty() else relative_dir + "/" + file_name)
	for child_dir in directory.get_directories():
		var child_relative := child_dir if relative_dir.is_empty() else relative_dir + "/" + child_dir
		_walk(child_relative, output, depth + 1)


func get_asset_prefix() -> String:
	return _root + "/"


func get_display_name() -> String:
	return _root


func _absolute(relative_path: String) -> String:
	return _root + "/" + relative_path
