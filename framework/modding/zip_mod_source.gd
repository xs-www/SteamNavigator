class_name ZipModSource
extends ModSource
## Read-only view over a `.snavmod.zip` resource pack.
##
## The zip must contain exactly one manifest at `mods/<id>/manifest.json`.
## Content is read through ZIPReader before/without mounting; after successful
## validation the loader mounts the pack so `res://mods/<id>/...` assets work.

var _zip: ZIPReader = null
var _prefix: String = ""
var _files: PackedStringArray = PackedStringArray()
var _opened: bool = false


func _init(pack_path: String) -> void:
	origin = pack_path
	_zip = ZIPReader.new()
	var open_error := _zip.open(pack_path)
	if open_error != OK:
		error = "cannot open zip pack '%s' (error %d)" % [pack_path, open_error]
		return
	_opened = true
	for entry in _zip.get_files():
		if entry.ends_with("/"):
			continue
		_files.append(entry)
	_detect_prefix()


func _detect_prefix() -> void:
	var manifest_paths := PackedStringArray()
	for entry in _files:
		if entry == "manifest.json" or entry.ends_with("/manifest.json"):
			manifest_paths.append(entry)
	if manifest_paths.size() == 0:
		error = "zip pack has no manifest.json"
		return
	if manifest_paths.size() > 1:
		error = "zip pack contains multiple manifests; expected one mod per pack"
		return
	var manifest_path := manifest_paths[0]
	_prefix = manifest_path.trim_suffix("manifest.json")
	mod_id = _prefix.trim_suffix("/").get_file()
	if not _prefix.begins_with("mods/") or _prefix.count("/") != 2:
		error = "zip manifest path must be mods/<mod_id>/manifest.json, got '%s'" % manifest_path


func is_open() -> bool:
	return _opened and error.is_empty()


func exists(relative_path: String) -> bool:
	return _zip != null and _zip.file_exists(_prefix + relative_path)


func read_text(relative_path: String) -> String:
	var bytes := read_bytes(relative_path)
	if bytes.is_empty():
		return ""
	return bytes.get_string_from_utf8()


func read_bytes(relative_path: String) -> PackedByteArray:
	if _zip == null or not exists(relative_path):
		return PackedByteArray()
	return _zip.read_file(_prefix + relative_path)


func list_files() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in _files:
		if entry.begins_with(_prefix):
			result.append(entry.substr(_prefix.length()))
	return result


func get_asset_prefix() -> String:
	return "res://" + _prefix


func get_pack_path() -> String:
	return origin


func is_pack() -> bool:
	return true


func get_display_name() -> String:
	return origin


func close() -> void:
	if _zip != null:
		_zip.close()
		_zip = null
	_opened = false
