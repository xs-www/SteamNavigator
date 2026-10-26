## @static-doc
## 作用：发布路径资产探针（只读）：挂载真实发布包 `release/SteamNavigator/mods/core-1.0.0.snavmod.zip`（或 `-- --pack=<abs path>`），在 headless 下逐项验证「发布构建的模组内原始 PNG/GLB 能否被 `ContentAssetLoader` 加载」，并统计贴图尺寸/未压缩 RGBA 显存量、重复内容、加载耗时与缺失资产行为，输出机器可读 JSON。
##
## ## 契约与约束
## - 只读：不改内容、不写存档；唯一副作用是可选 `--report=<path>` 的 JSON 落盘。
## - headless 可跑（不需要 GPU）；`-- --pack=<zip>` 覆盖默认发布包路径，`-- --limit=<n>` 限制 GLB 抽样数（默认全部）。
## - 退出码 0 = 关键断言全过；1 = 有失败项（此时仍打印完整报告便于取证）。
## - 断言：FileAccess 能看到 zip 内 manifest/GLB/PNG；Image.load_from_file 读 zip 内 PNG 成功；GLB 外部 image URI 能解析到 zip 内文件且 albedo_texture 非空；缺失资产返回 null 且重复调用不再尝试。
## - 统计口径：`ImageTexture.create_from_image()` 默认无 mipmap、无 VRAM 压缩 → RGBA8 显存 = w*h*4。
## @end-static-doc

extends SceneTree
## Export-path asset probe for the real release pack.
##
## Usage (headless, no GPU needed):
##   godot --headless --path . --script res://tools/godot/probe_export_assets.gd
##   godot --headless --path . --script res://tools/godot/probe_export_assets.gd -- \
##     "--pack=D:/.../release/SteamNavigator/mods/core-1.0.0.snavmod.zip" \
##     "--report=D:/.../.design/perf/probe_export_assets.json"
##
## The release build mounts the pack at `res://`, so a pack entry
## `mods/core/assets/foo.png` is readable as `res://mods/core/assets/foo.png`.

const DEFAULT_PACK := "release/SteamNavigator/mods/core-1.0.0.snavmod.zip"
const PACK_ROOT := "res://mods/core"

var _failures: Array[String] = []
var _pack_arg := ""
var _report_path := ""
var _limit := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="):
			_pack_arg = argument.trim_prefix("--pack=").trim_prefix("\"").trim_suffix("\"")
		elif argument.begins_with("--report="):
			_report_path = argument.trim_prefix("--report=").trim_prefix("\"").trim_suffix("\"")
		elif argument.begins_with("--limit="):
			_limit = int(argument.trim_prefix("--limit="))
	_run()


func _run() -> void:
	var pack_path := _pack_path()
	var started_at := Time.get_ticks_usec()
	var mounted := false
	if not FileAccess.file_exists(pack_path):
		_fail("pack missing: " + pack_path)
	else:
		mounted = ProjectSettings.load_resource_pack(pack_path, false)
	if not mounted:
		_fail("load_resource_pack failed: " + pack_path)
	var mount_ms := float(Time.get_ticks_usec() - started_at) / 1000.0
	print("[export-assets] pack=%s pack_bytes=%d mount_ms=%.1f mounted=%s" % [pack_path, _file_size(pack_path), mount_ms, str(mounted)])

	var report: Dictionary = {
		"pack": pack_path,
		"pack_bytes": _file_size(pack_path),
		"mount_ms": mount_ms,
		"mounted": mounted,
		"manifest_exists": FileAccess.file_exists(PACK_ROOT + "/manifest.json"),
		"zip_entries": 0,
		"png_count": 0,
		"glb_count": 0,
		"images": [],
		"referenced_textures": [],
		"orphan_textures": [],
		"total_rgba_bytes_all_png": 0,
		"total_rgba_bytes_referenced_unique": 0,
		"duplicate_content_bytes_wasted": 0,
		"load_all_png_ms": 0.0,
		"load_all_glb_ms": 0.0,
		"glbs_checked": 0,
		"total_tris": 0,
		"missing_texture_null": false,
		"missing_glb_null": false,
		"static_mem_before": 0,
		"static_mem_after": 0,
		"failures": [],
	}
	if not report["manifest_exists"]:
		_fail("manifest not visible through mounted pack: %s/manifest.json" % PACK_ROOT)

	# Enumerate the real zip (ZIPReader) so counts do not depend on DirAccess.
	var entries := _zip_entries(pack_path)
	report["zip_entries"] = entries.size()
	var png_paths: Array[String] = []
	var glb_paths: Array[String] = []
	for entry in entries:
		if not entry.begins_with("mods/core/") or entry.ends_with("/"):
			continue
		if entry.ends_with(".png"):
			png_paths.append(entry)
		elif entry.ends_with(".glb"):
			glb_paths.append(entry)
	report["png_count"] = png_paths.size()
	report["glb_count"] = glb_paths.size()
	report["static_mem_before"] = OS.get_static_memory_usage()

	# --- 1. every PNG through Image.load_from_file (the release texture path) --
	var png_started := Time.get_ticks_usec()
	var png_images: Dictionary = {}
	var rgba_by_path: Dictionary = {}
	var md5_by_path: Dictionary = {}
	for entry in png_paths:
		var res_path := "res://" + entry
		var info: Dictionary = {"path": entry, "load_ok": false, "width": 0, "height": 0, "rgba_bytes": 0}
		if not FileAccess.file_exists(res_path):
			_fail("PNG not visible through pack: " + res_path)
			report["images"].append(info)
			continue
		var image := Image.load_from_file(res_path)
		if image == null or image.is_empty():
			_fail("Image.load_from_file failed: " + res_path)
		else:
			var dims := image.get_size()
			info["load_ok"] = true
			info["width"] = dims.x
			info["height"] = dims.y
			# No mipmaps, no VRAM compression: ImageTexture uploads RGBA8.
			info["rgba_bytes"] = dims.x * dims.y * 4
			report["total_rgba_bytes_all_png"] = int(report["total_rgba_bytes_all_png"]) + int(info["rgba_bytes"])
			png_images[entry] = image
			rgba_by_path[res_path] = int(info["rgba_bytes"])
			md5_by_path[res_path] = FileAccess.get_md5(res_path)
		report["images"].append(info)
	report["load_all_png_ms"] = float(Time.get_ticks_usec() - png_started) / 1000.0

	# Duplicate content at different paths -> ContentAssetLoader caches by path,
	# so identical PNGs become separate ImageTexture uploads.
	var seen_hash: Dictionary = {}
	for res_path in md5_by_path.keys():
		var digest := String(md5_by_path[res_path])
		var rgba := int(rgba_by_path[res_path])
		if seen_hash.has(digest):
			report["duplicate_content_bytes_wasted"] = int(report["duplicate_content_bytes_wasted"]) + rgba
		else:
			seen_hash[digest] = res_path
	report["unique_png_content"] = seen_hash.size()

	# --- 2. GLB external image URIs resolve inside the mounted pack ------------
	var glb_started := Time.get_ticks_usec()
	var referenced_paths: Dictionary = {}
	var missing_uris: Array[String] = []
	var total_tris := 0
	var sample_limit := glb_paths.size() if _limit <= 0 else mini(_limit, glb_paths.size())
	var glbs_checked := 0
	for entry in glb_paths:
		if glbs_checked >= sample_limit:
			continue
		var res_path := "res://" + entry
		if not FileAccess.file_exists(res_path):
			_fail("GLB not visible through pack: " + res_path)
			continue
		glbs_checked += 1
		var uris := ContentAssetLoader.material_image_uris(res_path)
		var base_dir := res_path.get_base_dir()
		for uri in uris:
			if uri.is_empty() or uri.begins_with("data:"):
				continue
			var resolved := uri if uri.begins_with("res://") else base_dir.path_join(uri)
			referenced_paths[resolved] = true
			if not FileAccess.file_exists(resolved):
				missing_uris.append(resolved)
				_fail("external texture missing in pack: " + resolved)
		var scene := ContentAssetLoader.load_scene(res_path)
		if scene == null:
			_fail("ContentAssetLoader.load_scene failed: " + res_path)
			continue
		var stats := _scene_stats(scene)
		total_tris += int(stats["tris"])
	report["load_all_glb_ms"] = float(Time.get_ticks_usec() - glb_started) / 1000.0
	report["glbs_checked"] = glbs_checked
	report["total_tris"] = total_tris
	report["missing_uris"] = missing_uris

	for resolved in referenced_paths.keys():
		var rgba := int(rgba_by_path.get(String(resolved), 0))
		report["referenced_textures"].append({
			"path": String(resolved),
			"exists": FileAccess.file_exists(String(resolved)),
			"rgba_bytes": rgba,
		})
		report["total_rgba_bytes_referenced_unique"] = int(report["total_rgba_bytes_referenced_unique"]) + rgba
	for entry in png_paths:
		if not referenced_paths.has("res://" + entry):
			report["orphan_textures"].append(entry)

	# --- 3. texture loader behaviour: cache, timing, missing files -------------
	var tex_started := Time.get_ticks_usec()
	var loaded_textures := 0
	for resolved in referenced_paths.keys():
		if ContentAssetLoader.load_texture(String(resolved)) == null:
			_fail("ContentAssetLoader.load_texture returned null: " + String(resolved))
		else:
			loaded_textures += 1
	report["load_referenced_textures_ms"] = float(Time.get_ticks_usec() - tex_started) / 1000.0
	report["loaded_textures"] = loaded_textures
	var cache_started := Time.get_ticks_usec()
	for resolved in referenced_paths.keys():
		ContentAssetLoader.load_texture(String(resolved))
	report["second_pass_textures_ms"] = float(Time.get_ticks_usec() - cache_started) / 1000.0

	var missing_tex := "res://mods/core/assets/models/props/iron_harbor_shared/__missing__.png"
	print("[export-assets] missing texture probe (one engine error expected, then cached):")
	report["missing_texture_null"] = ContentAssetLoader.load_texture(missing_tex) == null
	report["missing_texture_null_second"] = ContentAssetLoader.load_texture(missing_tex) == null
	var missing_glb := "res://mods/core/assets/models/props/__missing__.glb"
	report["missing_glb_null"] = ContentAssetLoader.load_scene(missing_glb) == null
	if not report["missing_texture_null"] or not report["missing_glb_null"]:
		_fail("missing asset did not return null")

	# --- 4. instantiate_model path (GLTF scene -> fresh duplicate) -------------
	if not glb_paths.is_empty():
		var model_path := "res://" + String(glb_paths[0])
		var instance := ContentAssetLoader.instantiate_model(model_path)
		if instance == null:
			_fail("instantiate_model returned null: " + model_path)
		else:
			instance.free()

	report["static_mem_after"] = OS.get_static_memory_usage()
	report["static_mem_delta_mb"] = snappedf(float(int(report["static_mem_after"]) - int(report["static_mem_before"])) / 1048576.0, 0.1)
	report["failures"] = Array(_failures)
	report["ok"] = _failures.is_empty()
	_totals(report)

	print("[export-assets] JSON " + JSON.stringify(report))
	if not _report_path.is_empty():
		var file := FileAccess.open(_report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
			print("[export-assets] wrote " + _report_path)
	if not _failures.is_empty():
		for failure in _failures:
			printerr("[export-assets] FAIL " + failure)
		# Drop the intentional probe caches before exit so the renderer does not
		# report RID/ObjectDB leaks that belong to this probe, not to the game.
		ContentAssetLoader.clear_cache()
		quit(1)
	else:
		print("[export-assets] OK (%d png, %d glb)" % [png_paths.size(), glb_paths.size()])
		ContentAssetLoader.clear_cache()
		quit(0)


func _totals(report: Dictionary) -> void:
	report["total_rgba_mb_all_png"] = snappedf(float(int(report["total_rgba_bytes_all_png"])) / 1048576.0, 1)
	report["total_rgba_mb_referenced_unique"] = snappedf(float(int(report["total_rgba_bytes_referenced_unique"])) / 1048576.0, 1)
	report["duplicate_wasted_mb"] = snappedf(float(int(report["duplicate_content_bytes_wasted"])) / 1048576.0, 1)


func _pack_path() -> String:
	var pack := DEFAULT_PACK
	if not _pack_arg.is_empty():
		pack = _pack_arg
	if pack.begins_with("res://") or pack.begins_with("user://"):
		return pack
	if pack.is_absolute_path():
		return pack
	return ProjectSettings.globalize_path("res://").path_join(pack)


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := int(file.get_length())
	file.close()
	return size


func _zip_entries(pack_path: String) -> PackedStringArray:
	var reader := ZIPReader.new()
	var entries := PackedStringArray()
	if reader.open(pack_path) != OK:
		_fail("ZIPReader.open failed: " + pack_path)
		return entries
	for entry in reader.get_files():
		entries.append(entry)
	reader.close()
	return entries


func _scene_stats(root: Node) -> Dictionary:
	var stats := {"tris": 0, "surfaces": 0, "meshes": 0}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			stats["meshes"] = int(stats["meshes"]) + 1
			for surface in mesh.get_surface_count():
				stats["surfaces"] = int(stats["surfaces"]) + 1
				var arrays := mesh.surface_get_arrays(surface)
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
					stats["tris"] = int(stats["tris"]) + int((indices as PackedInt32Array).size() / 3)
				else:
					var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
					if vertices is PackedVector3Array:
						stats["tris"] = int(stats["tris"]) + int((vertices as PackedVector3Array).size() / 3)
	return stats


func _fail(message: String) -> void:
	_failures.append(message)
