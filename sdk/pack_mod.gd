extends SceneTree
## Packs a loose mod directory into `<mod_id>-<version>.snavmod.zip`.
##
## Usage:
##   godot --headless --path . --script res://sdk/pack_mod.gd -- \
##       --source=dev_mods/core --out=dist/mods

const SKIP_SUFFIXES := [".import", ".uid", ".tmp"]


func _initialize() -> void:
	var source := "dev_mods/core"
	var output_dir := "dist/mods"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.trim_prefix("--source=")
		elif argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	var source_path := _resolve(source)
	var manifest_parsed := JsonUtils.parse_file(source_path + "/manifest.json")
	if not bool(manifest_parsed["ok"]):
		printerr("cannot read manifest: %s" % manifest_parsed["error"])
		quit(1)
		return
	var manifest: Dictionary = manifest_parsed["value"]
	var mod_id := String(manifest.get("id", ""))
	var version := String(manifest.get("version", ""))
	if mod_id.is_empty() or version.is_empty():
		printerr("manifest is missing id or version")
		quit(1)
		return
	var files := PackedStringArray()
	_walk(source_path, "", files)
	DirAccess.make_dir_recursive_absolute(_resolve(output_dir))
	var pack_path := "%s/%s-%s.snavmod.zip" % [_resolve(output_dir), mod_id, version]
	if FileAccess.file_exists(pack_path):
		DirAccess.remove_absolute(pack_path)
	var packer := ZIPPacker.new()
	var open_error := packer.open(pack_path)
	if open_error != OK:
		printerr("cannot open output pack (error %d): %s" % [open_error, pack_path])
		quit(1)
		return
	var packed := 0
	for relative_path in files:
		var bytes := FileAccess.get_file_as_bytes(source_path + "/" + relative_path)
		var entry := "mods/%s/%s" % [mod_id, relative_path]
		if packer.start_file(entry) != OK:
			printerr("cannot add file: %s" % entry)
			packer.close()
			quit(1)
			return
		packer.write_file(bytes)
		packer.close_file()
		packed += 1
	packer.close()
	print("packed %d files -> %s" % [packed, pack_path])
	quit(0)


func _walk(root: String, relative: String, output: PackedStringArray) -> void:
	var directory_path := root if relative.is_empty() else root + "/" + relative
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		var skip := false
		for suffix in SKIP_SUFFIXES:
			if file_name.ends_with(suffix):
				skip = true
		if skip:
			continue
		output.append(file_name if relative.is_empty() else relative + "/" + file_name)
	for directory_name in directory.get_directories():
		if directory_name.begins_with("."):
			continue
		_walk(root, directory_name if relative.is_empty() else relative + "/" + directory_name, output)


func _resolve(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	return "res://" + path.trim_prefix("/")
