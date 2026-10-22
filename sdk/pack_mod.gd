extends SceneTree
## @static-doc
## 作用：把松散模组目录打包成 `<mod_id>-<version>.snavmod.zip`；`--release` 在打包前强制跑一遍真实 runtime 校验。
##
## ## 用法
## ```text
## # 普通打包（行为与旧版一致，不做发布门禁）
## godot --headless --path . --script res://sdk/pack_mod.gd -- \
##     --source=dev_mods/core --out=dist/mods
##
## # 正式发布：先按 runtime 语义校验，存在未激活草案或任何 error 时拒绝打包
## godot --headless --path . --script res://sdk/pack_mod.gd -- \
##     --source=dev_mods/core --out=dist/mods --release
## ```
##
## ## 契约与约束
## - 不加 `--release` 时保持旧行为：只校验 manifest 可读且含 id/version，然后按原结构打包。
## - `--release` 复用 `SdkValidationCore.run_runtime`：Core 从 `dev_mods` 加载；第三方模组先复制到
##   `user://` 隔离目录，再按真实 Bootstrap 校验，避免同目录下其它示例模组影响结果。
## - 未激活草案内容（`inactive_content_type`）或任何 error / fatal 都会让退出码为 1，且不写出 zip。
## - `.snavmod.zip` 内部结构固定为 `mods/<mod_id>/...`；跳过 `.import` / `.uid` / `.tmp` 与隐藏目录。
## - 发布签名 / 哈希不在本脚本内处理。
## @end-static-doc

const SKIP_SUFFIXES := [".import", ".uid", ".tmp"]


func _initialize() -> void:
	var source := "dev_mods/core"
	var output_dir := "dist/mods"
	var release := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.trim_prefix("--source=")
		elif argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
		elif argument == "--release":
			release = true
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
	if release and not _validate_release(source_path, mod_id):
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


## Release gate: real runtime load (core + this mod only), then refuse to pack on any error.
func _validate_release(source_path: String, mod_id: String) -> bool:
	var roots := PackedStringArray(["res://dev_mods"])
	var stage_root := ""
	if mod_id != DependencyResolver.CORE_ID:
		stage_root = SdkValidationCore.stage_mod(source_path, mod_id)
		roots.append(stage_root)
	var report: StartupReport = SdkValidationCore.run_runtime(roots)
	FrameworkRuntime.shutdown()
	SdkValidationCore.cleanup_stage(stage_root)
	if report.has_fatal() or not report.errors.is_empty():
		for entry in report.errors:
			printerr("[%s] %s (mod=%s file=%s path=%s)" % [
				String(entry.get("code", "")),
				String(entry.get("message", "")),
				String(entry.get("mod", "")),
				String(entry.get("file", "")),
				String(entry.get("path", "")),
			])
		printerr("release validation failed: %d error(s); refusing to pack '%s'" % [report.errors.size(), mod_id])
		return false
	print("release validation: ok (mode: runtime)")
	return true


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
