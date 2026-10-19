extends SceneTree
## Real-render budget measurement for the 2.5D `PortStage` sample scene.
##
## Usage (windowed, 1440x900 — the display server must render real frames):
##   & <godot> --path . --resolution 1440x900 --script res://tools/godot/measure_port_stage.gd
##
## The script mounts `dev_scenes/port_stage/port_stage_preview.tscn`, waits for
## the stage to settle, then reports the `preview` (town kit + painted banner)
## and `sparse` (small port, no banner) variants:
##
##   - renderer draw calls / primitives, when the active renderer reports them
##     (`RenderingServer.get_rendering_info`; GL Compatibility exposes them on
##     desktop builds, other backends may answer 0);
##   - the scene-side analysis fallback: MeshInstance3D count, MultiMesh batch
##     count/instances and the summed triangle count, which stays available even
##     when the renderer cannot answer;
##   - the stage's own batches (`PortStage.batch_stats()`), town density/prop
##     counts and painted-backdrop layer count.
##
## Exit code 0 means both variants were measured (budget overruns are reported,
## not treated as tool failures). Any mount/read failure exits with code 1; a
## watchdog quits instead of hanging when the frame loop stalls.

const PREVIEW_SCENE := "res://dev_scenes/port_stage/port_stage_preview.tscn"
const WINDOW := Vector2i(1440, 900)
const SETTLE_FRAMES := 90
const SETTLE_SECONDS := 1.0
const SWITCH_FRAMES := 30
const SWITCH_SECONDS := 0.5
const SAMPLE_FRAMES := 6
const WATCHDOG_SECONDS := 180.0
const DRAW_CALL_BUDGET := 120
const TRIANGLE_BUDGET := 60000

var _failures := 0
var _measured := 0
var _finished := false


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
	await _measure(scene, "preview")

	if not scene.has_method("set_variant"):
		_fail("preview scene has no set_variant(); cannot measure the sparse variant")
	else:
		print("[measure] switching to variant=sparse")
		scene.set_variant("sparse")
		await _settle(SWITCH_FRAMES, SWITCH_SECONDS)
		await _measure(scene, "sparse")

	scene.queue_free()
	await process_frame
	_finish()


func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	await create_timer(seconds).timeout
	for i in 3:
		await process_frame


func _measure(scene: Node, variant: String) -> void:
	print("[measure] sampling variant=" + variant)
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

	var renderer := RenderingServer.get_current_rendering_driver_name() if RenderingServer.has_method("get_current_rendering_driver_name") else "unknown"
	print("=== port stage measure: variant=%s renderer=%s ===" % [variant, renderer])
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
			int(stats["surfaces"]), int(stats["triangles"]),
		]
	)
	_print_stage_report(scene)
	_print_draw_contributors(scene)
	_print_group_breakdown(scene)
	_evaluate_budget(variant, draw_calls, primitives, int(stats["triangles"]), int(stats["surfaces"]))


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
		parts.append("batches=%d meshes_before=%d meshes_after=%d" % [
			int(batch.get("batches", 0)),
			int(batch.get("meshes_before", 0)),
			int(batch.get("meshes_after", 0)),
		])
		parts.append("ship_batches=%d ship_meshes=%d->%d ship_fallback=%s" % [
			int(batch.get("ship_batches", 0)),
			int(batch.get("ship_meshes_before", 0)),
			int(batch.get("ship_meshes_after", 0)),
			str(bool(batch.get("ship_fallback", false))),
		])
	print("[measure] stage " + ", ".join(parts))


func _evaluate_budget(variant: String, draw_calls: int, primitives: int, triangles: int, surfaces: int) -> void:
	var draw_text := "unavailable"
	if draw_calls > 0:
		draw_text = "%d (%s %d)" % [draw_calls, "within" if draw_calls <= DRAW_CALL_BUDGET else "OVER", DRAW_CALL_BUDGET]
	print("[measure] %s budget: draw_calls=%s  triangles=%d (%s %d)  analysis_surfaces=%d" % [
		variant,
		draw_text,
		triangles,
		"within" if triangles <= TRIANGLE_BUDGET else "OVER",
		TRIANGLE_BUDGET,
		surfaces,
	])
	if draw_calls <= 0 and primitives <= 0:
		print("[measure] %s: renderer did not expose draw calls; analysis口径 = surfaces=%d / mesh_instances" % [variant, surfaces])


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


func _fail(message: String) -> void:
	_failures += 1
	print("[measure] FAIL: " + message)


func _finish() -> void:
	_finished = true
	print("=== port stage measure: %d variant(s) measured, %d failure(s) ===" % [_measured, _failures])
	quit(0 if _failures == 0 and _measured == 2 else 1)
