## @static-doc
## 作用：PortStage 真实渲染预算实测（窗口 1440×900）：挂载 `port_stage_preview.tscn`，依次采样 `preview`、`sparse` 与三个站位（market/harbor/supply，stage 构图），优先用 `RenderingServer.get_rendering_info()` 读取整帧 draw calls / primitives，并输出场景 mesh/MultiMesh/粒子/surface/triangle 分析、舞台分层 surface、`batch_stats()`、`town_density()`、`station_prop_count()`、`painted_backdrop_layer_count()` 与「排除玩家船后的 stage draws」。
##
## - 关键依赖：`dev_scenes/port_stage/port_stage_preview.tscn`、`RenderingServer`、`PortStage.batch_stats()`
##
## ## 契约与约束
## - 必须窗口模式才能读到真实 draw calls；headless 时打印明确说明并走 mesh/surface 分析口径，不视为失败、不挂窗口。
## - 采样 6 帧取峰值，避免 resize / 首帧低值；成功条件为 5 个样本（preview/sparse/market/harbor/supply）都完成测量，否则退出码 1。
## - 预算阈值 120 draws / 60,000 tris；每个站位单独输出 ≤120 / ≤60k 判定与一行汇总，超出只报告 OVER 不改变退出码（测量工具不替代验收）。注意 60k 是整场景 tri 口径；§5.1 的「同屏城镇建筑 ≤60k / LOD1 组合 ≤20k」需用 5 栋 GLB 求和另行复算。
## - `-- --core-zip` 会把 `dev_mods/core` 打成 `.snavmod.zip` 并挂载，把 `SN_TOWN_ASSET_ROOT` 指向 `res://mods/core/assets/models/props`，从而以原始 `ContentAssetLoader` 路径实测 ZIP 加载；`-- --core-zip=PATH` 挂载既有包（如 `dist/mods/core-1.0.0.snavmod.zip`）。不传时仍是松散 `dev_mods`（导入资源路径）。
## - 180 s watchdog；只读场景，不修改游戏状态或源码。
## - 输出包含总 draw calls（含已合并玩家船）与 stage 自身（excl. hull），便于区分舞台预算与不可批的船体开销。
## @end-static-doc

extends SceneTree
## Real-render budget measurement for the 2.5D `PortStage` sample scene.
##
## Usage (windowed, 1440x900 — the display server must render real frames):
##   & <godot> --path . --resolution 1440x900 --script res://tools/godot/measure_port_stage.gd
##
## The script mounts `dev_scenes/port_stage/port_stage_preview.tscn`, waits for
## the stage to settle, then measures:
##
##   1. `variant=preview` (town kit + painted banner) and `variant=sparse`
##      (small port, no banner) — the historical baseline, now on the default
##      `harbor` / `stage` station;
##   2. one sample per berth (`station=market`, `station=harbor`,
##      `station=supply`) on the preview payload, `stage` framing, with the
##      camera driven by the Lead's `focus_station()` API.
##
## Per sample it reports:
##   - renderer draw calls / primitives, when the active renderer reports them
##     (`RenderingServer.get_rendering_info`; GL Compatibility exposes them on
##     desktop builds, other backends may answer 0);
##   - the scene-side analysis fallback: MeshInstance3D count, MultiMesh batch
##     count/instances and the summed triangle count, which stays available even
##     when the renderer cannot answer;
##   - the stage's own batches (`PortStage.batch_stats()`), town density/prop
##     counts and painted-backdrop layer count;
##   - surfaces grouped by the stage's layer roots (facilities / harbor town /
##     shoreline / player ship / water / foreground ...), i.e. where the draw
##     budget goes.
##
## Each berth is evaluated against the project budget: ≤120 draw calls and
## ≤60k triangles. A final `[measure] SUMMARY` line aggregates the results.
##
## Exit code 0 means all 5 samples were measured (budget overruns are reported,
## not treated as tool failures). Any mount/read failure — including the station
## API not being landed yet — exits with code 1; a watchdog quits instead of
## hanging when the frame loop stalls.

const PREVIEW_SCENE := "res://dev_scenes/port_stage/port_stage_preview.tscn"
const WINDOW := Vector2i(1440, 900)
const SETTLE_FRAMES := 90
const SETTLE_SECONDS := 1.0
const SWITCH_FRAMES := 30
const SWITCH_SECONDS := 0.5
const STATION_FRAMES := 20
const STATION_SECONDS := 0.35
const STATION_TIMEOUT_SECONDS := 8.0
const SAMPLE_FRAMES := 6
const WATCHDOG_SECONDS := 240.0
const DRAW_CALL_BUDGET := 120
const TRIANGLE_BUDGET := 60000
## Slots expected from the "continuous harbour + three adjacent berths" design.
const STATIONS := ["market", "harbor", "supply"]
const STATION_FRAMING := "stage"
## preview + sparse + one sample per berth.
const EXPECTED_MEASUREMENTS := 2 + 3

var _failures := 0
var _measured := 0
var _finished := false
## One entry per sample: label / draw_calls / primitives / triangles / surfaces.
var _rows: Array[Dictionary] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	push_error("measure_port_stage: flow timed out after %d s" % int(WATCHDOG_SECONDS))
	print("=== port stage measure: TIMEOUT after %d s ===" % int(WATCHDOG_SECONDS))
	quit(1)


func _run() -> void:
	var headless := DisplayServer.get_name() == "headless"
	if headless:
		print("[measure] NOTE: headless display server — real draw-call stats are unavailable;")
		print("[measure]       falling back to mesh/batch/triangle analysis only.")
	else:
		DisplayServer.window_set_size(WINDOW)
		DisplayServer.window_set_title("Steam Navigator · port stage measure")
	if not _setup_town_asset_root():
		_finish()
		return
	await process_frame
	await process_frame

	var packed := load(PREVIEW_SCENE) as PackedScene
	if packed == null:
		_fail("cannot load preview scene: " + PREVIEW_SCENE)
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await _settle(SETTLE_FRAMES, SETTLE_SECONDS)

	# Baseline samples: the legacy camera is the `harbor` / `stage` station, so
	# focus it explicitly when the station API exists (otherwise keep the old
	# fixed-camera measurement).
	if _has_station_api(scene):
		await _focus_station(scene, "harbor", STATION_FRAMING)
	await _measure(scene, "variant=preview")

	if not scene.has_method("set_variant"):
		_fail("preview scene has no set_variant(); cannot measure the sparse variant")
	else:
		print("[measure] switching to variant=sparse")
		scene.set_variant("sparse")
		await _settle(SWITCH_FRAMES, SWITCH_SECONDS)
		if _has_station_api(scene):
			await _focus_station(scene, "harbor", STATION_FRAMING)
		await _measure(scene, "variant=sparse")

	# Per-station samples on the preview payload.
	if not scene.has_method("set_variant"):
		_fail("preview scene has no set_variant(); cannot restore the preview payload for station samples")
	elif not _has_station_api(scene):
		_fail("PortStage station API is missing (station_ids/current_station/focus_station/is_station_transitioning) — Lead change pending")
	else:
		print("[measure] switching back to variant=preview for station samples")
		scene.set_variant("preview")
		await _settle(SWITCH_FRAMES, SWITCH_SECONDS)
		for station in _station_ids(scene):
			var focused := await _focus_station(scene, station, STATION_FRAMING)
			if not focused:
				continue
			await _measure(scene, "station=%s" % station)

	scene.queue_free()
	await process_frame
	_finish()


## True when the mounted stage exposes the full station contract.
func _has_station_api(scene: Node) -> bool:
	if not scene.has_method("current_stage"):
		return false
	var stage: Variant = scene.current_stage()
	if stage == null:
		return false
	for method in ["station_ids", "current_station", "focus_station", "is_station_transitioning"]:
		if not stage.has_method(method):
			print("[measure] station API missing: PortStage.%s()" % method)
			return false
	return true


## Station order comes from the stage when available, falling back to the
## documented market → harbor → supply (world X left → right).
func _station_ids(scene: Node) -> Array[String]:
	var ids: Array[String] = []
	var stage: Variant = scene.current_stage() if scene.has_method("current_stage") else null
	if stage != null and stage.has_method("station_ids"):
		for entry in stage.station_ids():
			var station := String(entry)
			if not station.is_empty() and not ids.has(station):
				ids.append(station)
	if ids.is_empty():
		for station in STATIONS:
			ids.append(String(station))
	return ids


## Drives `focus_station(..., immediate = true)` and waits until the stage no
## longer reports a transition; a settle pass covers the water shader/ship bob.
func _focus_station(scene: Node, station_id: String, framing: String) -> bool:
	var stage: Variant = scene.current_stage() if scene.has_method("current_stage") else null
	if stage == null:
		_fail("stage is not mounted; cannot focus station " + station_id)
		return false
	if not stage.has_method("focus_station"):
		_fail("PortStage.focus_station() is missing — Lead change pending")
		return false
	var accepted := false
	if scene.has_method("set_station"):
		# Exercise the preview scene's own set_station() path (it prints the
		# station/camera/ship state before the sample is taken).
		accepted = bool(scene.set_station(station_id, framing))
	else:
		accepted = bool(stage.focus_station(station_id, framing, true))
	if not accepted:
		_fail("station=%s framing=%s was rejected by the stage" % [station_id, framing])
		return false
	var deadline := Time.get_ticks_msec() + int(STATION_TIMEOUT_SECONDS * 1000.0)
	var settled := false
	while Time.get_ticks_msec() < deadline:
		var transitioning := bool(stage.is_station_transitioning()) if stage.has_method("is_station_transitioning") else false
		if not transitioning:
			settled = true
			break
		await process_frame
	if not settled:
		_fail("station=%s did not finish its transition within %.1fs" % [station_id, STATION_TIMEOUT_SECONDS])
		return false
	await _settle(STATION_FRAMES, STATION_SECONDS)
	if stage.has_method("current_station"):
		var current := String(stage.current_station())
		if current != station_id:
			_fail("station=%s requested but current_station()=%s" % [station_id, current])
			return false
	print("[measure] station focus ready: %s framing=%s" % [station_id, framing])
	return true


func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	await create_timer(seconds).timeout
	for i in 3:
		await process_frame


func _measure(scene: Node, label: String) -> void:
	print("[measure] sampling " + label)
	var headless := DisplayServer.get_name() == "headless"
	# Sample a few finished frames and keep the peak: the counter is reset by the
	# renderer each frame, and the first read after a resize can be low. Headless
	# has no draw frames, so it falls back to plain frames (stats stay 0).
	var draw_calls := 0
	var primitives := 0
	for i in SAMPLE_FRAMES:
		if headless:
			await process_frame
		else:
			await RenderingServer.frame_post_draw
		draw_calls = maxi(draw_calls, _rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives = maxi(primitives, _rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))

	var stats := {
		"mesh_instances": 0,
		"multimesh_batches": 0,
		"multimesh_instances": 0,
		"particles": 0,
		"surfaces": 0,
		"triangles": 0,
	}
	_collect_scene_stats(scene, stats)
	_measured += 1
	var triangles := int(stats["triangles"])
	var surfaces := int(stats["surfaces"])
	_rows.append({
		"label": label,
		"draw_calls": draw_calls,
		"primitives": primitives,
		"triangles": triangles,
		"surfaces": surfaces,
	})

	var renderer := RenderingServer.get_current_rendering_driver_name() if RenderingServer.has_method("get_current_rendering_driver_name") else "unknown"
	print("=== port stage measure: %s renderer=%s ===" % [label, renderer])
	if draw_calls > 0:
		print(
			"[measure] renderer draw_calls=%d primitives=%d (total frame, merged player hull included; RenderingServer.get_rendering_info)"
			% [draw_calls, primitives]
		)
	else:
		print("[measure] renderer draw_calls=unavailable (renderer reported 0; use scene analysis below)")
	print(
		"[measure] scene mesh_instances=%d multimesh_batches=%d multimesh_instances=%d particles=%d surfaces=%d triangles=%d"
		% [
			int(stats["mesh_instances"]), int(stats["multimesh_batches"]),
			int(stats["multimesh_instances"]), int(stats["particles"]),
			surfaces, triangles,
		]
	)
	_print_stage_report(scene)
	_print_draw_contributors(scene)
	_print_group_breakdown(scene)
	_evaluate_budget(label, draw_calls, primitives, triangles, surfaces)


func _print_stage_report(scene: Node) -> void:
	var host := scene.get_node_or_null("StageHost")
	if host == null or not host.has_method("current_stage"):
		print("[measure] stage: not mounted — cannot read PortStage accessors")
		return
	var stage: Variant = host.current_stage()
	if stage == null:
		print("[measure] stage: not mounted")
		return
	var parts: Array[String] = []
	if stage.has_method("current_station"):
		parts.append("station=%s" % String(stage.current_station()))
	if stage.has_method("station_prop_count"):
		parts.append("station_props=%d" % int(stage.station_prop_count()))
	if stage.has_method("camera_shift_x"):
		parts.append("camera_shift_x=%.2f" % float(stage.camera_shift_x()))
	if stage.has_method("town_density"):
		parts.append("density=%s" % String(stage.town_density()))
	if stage.has_method("town_prop_count"):
		parts.append("town_props=%d" % int(stage.town_prop_count()))
	if stage.has_method("town_blockout_count"):
		parts.append("blockouts=%d" % int(stage.town_blockout_count()))
	if stage.has_method("skyline_building_count"):
		parts.append("skyline_buildings=%d" % int(stage.skyline_building_count()))
	if stage.has_method("skyline_crane_count"):
		parts.append("skyline_cranes=%d" % int(stage.skyline_crane_count()))
	if stage.has_method("painted_backdrop_layer_count"):
		parts.append("painted_layers=%d" % int(stage.painted_backdrop_layer_count()))
	if stage.has_method("atmosphere_layers"):
		parts.append("fog_layers=%d" % int(stage.atmosphere_layers()))
	if stage.has_method("batch_stats"):
		var batch: Dictionary = stage.batch_stats()
		parts.append("batches=%d meshes_before=%d meshes_after=%d surfaces_before=%d surfaces_after=%d" % [
			int(batch.get("batches", 0)),
			int(batch.get("meshes_before", 0)),
			int(batch.get("meshes_after", 0)),
			int(batch.get("surfaces_before", 0)),
			int(batch.get("surfaces_after", 0)),
		])
		parts.append("ship_batches=%d ship_meshes=%d->%d ship_fallback=%s" % [
			int(batch.get("ship_batches", 0)),
			int(batch.get("ship_meshes_before", 0)),
			int(batch.get("ship_meshes_after", 0)),
			str(bool(batch.get("ship_fallback", false))),
		])
	print("[measure] stage " + ", ".join(parts))


func _evaluate_budget(label: String, draw_calls: int, primitives: int, triangles: int, surfaces: int) -> void:
	var draw_ok := draw_calls <= 0 or draw_calls <= DRAW_CALL_BUDGET
	var tri_ok := triangles <= TRIANGLE_BUDGET
	var draw_text := "unavailable (renderer reported 0)"
	if draw_calls > 0:
		draw_text = "%d (≤%d? %s)" % [draw_calls, DRAW_CALL_BUDGET, "YES" if draw_ok else "NO"]
	var tri_text := "%d (≤%dk? %s)" % [triangles, int(TRIANGLE_BUDGET / 1000), "YES" if tri_ok else "NO"]
	print("[measure] %s budget: draw_calls=%s  tris=%s  analysis_surfaces=%d" % [
		label, draw_text, tri_text, surfaces,
	])
	if draw_calls <= 0 and primitives <= 0:
		print("[measure] %s: renderer did not expose draw calls; analysis口径 = surfaces=%d / mesh_instances" % [label, surfaces])


## Renders the single-line aggregate the Lead asked for: one entry per sample,
## then a station-focused verdict.
func _print_summary() -> void:
	var parts: Array[String] = []
	var station_rows: Array[Dictionary] = []
	for row in _rows:
		var label := String(row["label"])
		var draws := int(row["draw_calls"])
		var tris := int(row["triangles"])
		var draw_text := ("%d/120" % draws) if draws > 0 else "?/120"
		parts.append("%s draws=%s tris=%d/60000" % [label, draw_text, tris])
		if label.begins_with("station="):
			station_rows.append(row)
	print("[measure] SUMMARY " + "; ".join(parts))
	if station_rows.is_empty():
		print("[measure] SUMMARY stations: not measured (station API missing)")
		return
	var draws_within := 0
	var tris_within := 0
	var station_parts: Array[String] = []
	for row in station_rows:
		var draws := int(row["draw_calls"])
		var tris := int(row["triangles"])
		var draw_ok := draws <= 0 or draws <= DRAW_CALL_BUDGET
		var tri_ok := tris <= TRIANGLE_BUDGET
		if draw_ok:
			draws_within += 1
		if tri_ok:
			tris_within += 1
		station_parts.append("%s draw_calls=%s(≤%d? %s) tris=%d(≤%dk? %s)" % [
			String(row["label"]),
			("%d" % draws) if draws > 0 else "unavailable",
			DRAW_CALL_BUDGET,
			"YES" if draw_ok else "NO",
			tris,
			int(TRIANGLE_BUDGET / 1000),
			"YES" if tri_ok else "NO",
		])
	print("[measure] SUMMARY stations: " + " | ".join(station_parts))
	print("[measure] SUMMARY station budgets: draws %d/%d within ≤%d, tris %d/%d within ≤%dk → both budgets met: %s" % [
		draws_within, station_rows.size(), DRAW_CALL_BUDGET,
		tris_within, station_rows.size(), int(TRIANGLE_BUDGET / 1000),
		"YES" if draws_within == station_rows.size() and tris_within == station_rows.size() else "NO",
	])


## RenderingServer.get_rendering_info returns -1/0 when the backend cannot answer.
func _rendering_info(info: int) -> int:
	var value := int(RenderingServer.get_rendering_info(info))
	return value if value > 0 else 0


## Surfaces are the best static proxy for draw calls, so the report names the
## nodes that still own the most of them (top 10).
func _print_draw_contributors(scene: Node) -> void:
	var rows: Array[Dictionary] = []
	_collect_draw_rows(scene, rows, scene)
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["surfaces"]) > int(right["surfaces"])
	)
	var shown: Array[String] = []
	for index in mini(rows.size(), 10):
		var row: Dictionary = rows[index]
		shown.append("%s=%d" % [String(row["path"]), int(row["surfaces"])])
	if not shown.is_empty():
		print("[measure] draw contributors: " + ", ".join(shown))


func _collect_draw_rows(node: Node, rows: Array[Dictionary], scene_root: Node) -> void:
	var surfaces := 0
	if node is MultiMeshInstance3D:
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh != null:
			surfaces = multi.mesh.get_surface_count()
	elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		surfaces = (node as MeshInstance3D).mesh.get_surface_count()
	if surfaces > 0 and node != scene_root:
		rows.append({"path": String(scene_root.get_path_to(node)), "surfaces": surfaces})
	for child in node.get_children():
		_collect_draw_rows(child, rows, scene_root)


## Surfaces grouped by the stage's own layer roots, so the measurement says
## where the draw budget goes (Content/Facilities + Content/HarborTown stay the
## static-batching targets; the player ship, water and foreground are excluded).
func _print_group_breakdown(scene: Node) -> void:
	var host := scene.get_node_or_null("StageHost")
	if host == null or not host.has_method("current_stage"):
		return
	var stage: Variant = host.current_stage()
	if stage == null:
		return
	var parts: Array[String] = []
	var ship_surfaces := 0
	for child in stage.get_children():
		if not (child is Node3D):
			continue
		if String(child.name) == "Content":
			for layer in child.get_children():
				var layer_count := _surfaces_under(layer)
				if String(layer.name) == "PlayerShip":
					ship_surfaces = layer_count
				if layer_count > 0:
					parts.append("%s=%d" % [String(layer.name), layer_count])
			continue
		var count := _surfaces_under(child)
		if count > 0:
			parts.append("%s=%d" % [String(child.name), count])
	if not parts.is_empty():
		print("[measure] stage surfaces by layer: " + ", ".join(parts))
		var total := 0
		for part in parts:
			total += int(String(part).get_slice("=", 1))
		print(
			"[measure] stage draws excluding player hull: surfaces=%d (batched player hull=%d, total=%d)"
			% [total - ship_surfaces, ship_surfaces, total]
		)


func _surfaces_under(node: Node) -> int:
	var total := 0
	if node is MultiMeshInstance3D:
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh != null:
			total += multi.mesh.get_surface_count()
	elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += (node as MeshInstance3D).mesh.get_surface_count()
	for child in node.get_children():
		total += _surfaces_under(child)
	return total


## Scene-side census (the analysis fallback when the renderer does not expose
## draw calls): mesh nodes, MultiMesh batches/instances, particles, surfaces and
## instanced triangles.
func _collect_scene_stats(node: Node, stats: Dictionary) -> void:
	if node is MultiMeshInstance3D:
		var multi_instance := node as MultiMeshInstance3D
		var multi := multi_instance.multimesh
		stats["multimesh_batches"] = int(stats["multimesh_batches"]) + 1
		if multi != null and multi.mesh != null:
			stats["multimesh_instances"] = int(stats["multimesh_instances"]) + multi.instance_count
			var surfaces := multi.mesh.get_surface_count()
			stats["surfaces"] = int(stats["surfaces"]) + surfaces
			stats["triangles"] = int(stats["triangles"]) + _mesh_triangles(multi.mesh) * multi.instance_count
	elif node is GPUParticles3D:
		stats["particles"] = int(stats["particles"]) + 1
	elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance := node as MeshInstance3D
		var mesh := instance.mesh
		stats["mesh_instances"] = int(stats["mesh_instances"]) + 1
		stats["surfaces"] = int(stats["surfaces"]) + mesh.get_surface_count()
		stats["triangles"] = int(stats["triangles"]) + _mesh_triangles(mesh)
	for child in node.get_children():
		_collect_scene_stats(child, stats)


func _mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
			total += int((indices as PackedInt32Array).size() / 3)
		else:
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			if vertices is PackedVector3Array:
				total += int((vertices as PackedVector3Array).size() / 3)
	return total


## Optional loading-path mode: `--core-zip` packs the loose dev core into a
## `.snavmod.zip`, mounts it and points the town kit at `res://mods/core/...` —
## the raw `ContentAssetLoader` path a release build uses. `--core-zip=PATH`
## mounts an existing pack instead of packing. Without either flag the scene
## keeps the loose `dev_mods` paths (the imported-resource path).
func _setup_town_asset_root() -> bool:
	var zip_argument := ""
	for argument in OS.get_cmdline_user_args():
		if argument == "--core-zip":
			zip_argument = "pack"
		elif argument.begins_with("--core-zip="):
			zip_argument = argument.trim_prefix("--core-zip=")
	var root := "res://dev_mods/core/assets/models/props"
	if not zip_argument.is_empty():
		var pack_path := "user://measure_port_stage/core-1.0.0.snavmod.zip"
		if zip_argument == "pack":
			if not _pack_core(pack_path):
				_fail("cannot pack dev_mods/core into " + pack_path)
				return false
		else:
			pack_path = zip_argument
		if not ProjectSettings.load_resource_pack(pack_path, false):
			_fail("cannot mount core pack: " + pack_path)
			return false
		root = "res://mods/core/assets/models/props"
		print("[measure] loading path: ZIP pack (%s)" % pack_path)
	OS.set_environment("SN_TOWN_ASSET_ROOT", root)
	print("[measure] town asset root: " + root)
	return true


func _pack_core(pack_path: String) -> bool:
	var directory := DirAccess.open("res://dev_mods/core")
	if directory == null:
		return false
	DirAccess.make_dir_recursive_absolute(pack_path.get_base_dir())
	if FileAccess.file_exists(pack_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pack_path))
	var files := PackedStringArray()
	_walk_pack("res://dev_mods/core", "", files)
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


func _walk_pack(root: String, relative: String, output: PackedStringArray) -> void:
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
		_walk_pack(root, child, output)


func _fail(message: String) -> void:
	_failures += 1
	print("[measure] FAIL: " + message)


func _finish() -> void:
	_finished = true
	_print_summary()
	print("=== port stage measure: %d/%d sample(s) measured, %d failure(s) ===" % [
		_measured, EXPECTED_MEASUREMENTS, _failures,
	])
	quit(0 if _failures == 0 and _measured == EXPECTED_MEASUREMENTS else 1)
