extends Control
## Standalone preview for the 2.5D `PortStage` skeleton — not part of the main
## flow. It builds an `SNStageHost` that fills the window, mounts
## `framework/ui/stages/port_stage.tscn` and forwards one of two sample
## ViewModels:
##
##   preview  iron_harbor, all five facilities, banner backdrop, tier-1 hull
##   sparse   spice_port (small), only exchange/contracts/supply, no banner,
##            facility_visuals GLB overrides at the ViewModel root, tier-1 hull
##
## Run it directly:
##   godot --path . res://dev_scenes/port_stage/port_stage_preview.tscn
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_port_stage.gd
##
## The `sparse` variant exists to exercise the empty-slot rule (missing
## facilities must render as cargo filler only, never as an anchor or hotspot)
## and the "no banner" L1 fallback (sky + fog + shoreline silhouettes, no black
## box).

const STAGE_SCENE := "res://framework/ui/stages/port_stage.tscn"
const BANNER_PATH := "res://dev_mods/core/assets/ports/iron_harbor_banner.png"
const VARIANT_PREVIEW := "preview"
const VARIANT_SPARSE := "sparse"

var _host: SNStageHost
var _variant := VARIANT_PREVIEW


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host = SNStageHost.new()
	_host.name = "StageHost"
	_host.auto_load = false
	add_child(_host)
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.load_stage(STAGE_SCENE)
	_apply_variant(_variant)


## Switches the sample payload without remounting the stage (used by the
## screenshot tool to grab both variants from one process).
func set_variant(variant_name: String) -> void:
	_variant = variant_name
	if _host != null:
		_apply_variant(_variant)


func current_variant() -> String:
	return _variant


func _apply_variant(variant_name: String) -> void:
	if _host == null or not _host.has_stage():
		push_error("PortStagePreview: stage is not mounted")
		return
	_host.bind_view_model(_payload_for(variant_name))
	_print_state(variant_name)


func _payload_for(variant_name: String) -> Dictionary:
	if variant_name == VARIANT_SPARSE:
		return _sparse_payload()
	return _preview_payload()


func _preview_payload() -> Dictionary:
	return {
		"port": {
			"id": "iron_harbor",
			"size": "medium",
			"facilities": ["exchange", "contracts", "supply", "intel", "shipyard"],
			"banner_path": BANNER_PATH,
			"palette": {
				"stone": Color(0.14, 0.13, 0.115),
				"deck": Color(0.24, 0.17, 0.11),
				"wood": Color(0.32, 0.22, 0.13),
			},
			"facility_visuals": {},
			"landmark_path": "",
		},
		"ship": {
			"hull_model_path": "res://assets/models/ships/SN_Paddle_Steamer.glb",
			"hull_tier": 1,
		},
	}


func _sparse_payload() -> Dictionary:
	# Root-level facility_visuals + tier fallback + missing banner: the second
	# screenshot doubles as evidence for those three branches.
	return {
		"port": {
			"id": "spice_port",
			"size": "small",
			"facilities": ["exchange", "contracts", "supply"],
			"banner_path": "",
			"palette": {
				"stone": Color(0.17, 0.15, 0.125),
				"deck": Color(0.26, 0.19, 0.12),
			},
			"landmark_path": "",
		},
		"facility_visuals": {
			"exchange": "res://assets/models/port/SN_Market_Stall.glb",
			"contracts": "res://assets/models/port/SN_Notice_Board.glb",
			"supply": "res://assets/models/port/SN_Water_Tank.glb",
		},
		"ship": {
			"hull_model_path": "",
			"hull_tier": 1,
		},
	}


func _print_state(variant_name: String) -> void:
	var stage: Node = _host.current_stage()
	if stage == null:
		return
	var kinds: Array[String] = []
	for facility in ["exchange", "contracts", "supply", "intel", "shipyard"]:
		kinds.append("%s=%s" % [facility, String(stage.facility_visual_kind(facility))])
	print("[PortStagePreview] variant=%s  facilities=%d  fillers=%d  backdrop=%s  banner=%s  ship=%s" % [
		variant_name,
		int(stage.facility_count()),
		int(stage.filler_count()),
		str(bool(stage.has_backdrop())),
		String(stage.loaded_banner_path()),
		str(bool(stage.has_ship())),
	])
	print("[PortStagePreview] kinds: " + ", ".join(kinds))
	var anchors: Dictionary = stage.facility_anchors()
	var screen: Array[String] = []
	for facility in anchors.keys():
		var screen_pos: Vector2 = stage.facility_screen_anchor(String(facility))
		screen.append("%s=(%.3f, %.3f)" % [String(facility), screen_pos.x, screen_pos.y])
	print("[PortStagePreview] screen anchors: " + ", ".join(screen))
	_print_scene_fill(stage)


func _print_scene_fill(stage: Node) -> void:
	if not stage.has_method("foreground_frame"):
		return
	print("[PortStagePreview] fill: particles=%d fog_layers=%d skyline_buildings=%d skyline_cranes=%d" % [
		int(stage.atmosphere_particle_systems()),
		int(stage.atmosphere_layers()),
		int(stage.skyline_building_count()),
		int(stage.skyline_crane_count()),
	])
	var frame: Node3D = stage.foreground_frame()
	var camera: Camera3D = stage.get_node_or_null("StageCamera") as Camera3D
	if frame == null or camera == null:
		return
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var min_uv := Vector2(1.0, 1.0)
	var max_uv := Vector2(0.0, 0.0)
	for child in frame.get_children():
		if not (child is MeshInstance3D) or (child as MeshInstance3D).mesh == null:
			continue
		var mesh_instance := child as MeshInstance3D
		var box: AABB = mesh_instance.mesh.get_aabb()
		for index in 8:
			var corner := box.position + Vector3(
				box.size.x if index & 1 else 0.0,
				box.size.y if index & 2 else 0.0,
				box.size.z if index & 4 else 0.0
			)
			var projected := camera.unproject_position(mesh_instance.global_transform * corner)
			var uv := Vector2(projected.x / viewport_size.x, projected.y / viewport_size.y)
			min_uv = min_uv.min(uv)
			max_uv = max_uv.max(uv)
	print("[PortStagePreview] foreground frame screen uv: min=(%.3f, %.3f) max=(%.3f, %.3f)" % [
		min_uv.x, min_uv.y, max_uv.x, max_uv.y
	])
	var budget := {"meshes": 0, "tris": 0, "particles": 0}
	_count_meshes(stage, budget)
	print("[PortStagePreview] budget: draw_meshes=%d particles=%d tris=%d" % [
		int(budget["meshes"]), int(budget["particles"]), int(budget["tris"])
	])
	var breakdown: Array[String] = []
	for child in stage.get_children():
		var count := _count_meshes(child, {"meshes": 0, "tris": 0, "particles": 0})
		if count > 0:
			breakdown.append("%s=%d" % [String(child.name), count])
	print("[PortStagePreview] mesh breakdown: " + ", ".join(breakdown))
	var sky_root := stage.get_node_or_null("FallbackBackdrop")
	if sky_root != null:
		for child in sky_root.get_children():
			if child is MeshInstance3D:
				var mesh_instance := child as MeshInstance3D
				var material := mesh_instance.material_override as StandardMaterial3D
				var size_text := ""
				if mesh_instance.mesh is QuadMesh:
					size_text = str((mesh_instance.mesh as QuadMesh).size)
				var center_uv := camera.unproject_position(mesh_instance.global_position)
				print("[PortStagePreview] fallback child %s visible=%s size=%s bb=%s uv=(%.3f, %.3f)" % [
					String(mesh_instance.name), str(mesh_instance.visible), size_text,
					str(int(material.billboard_mode)) if material != null else "?",
					center_uv.x / viewport_size.x, center_uv.y / viewport_size.y
				])


func _count_meshes(node: Node, budget: Dictionary) -> int:
	var count := 0
	if node is MultiMeshInstance3D:
		var multi_instance := node as MultiMeshInstance3D
		count += 1
		budget["meshes"] = int(budget["meshes"]) + 1
		var multi := multi_instance.multimesh
		if multi != null and multi.mesh != null:
			budget["tris"] = int(budget["tris"]) + _mesh_triangles(multi.mesh) * multi.instance_count
	elif node is GPUParticles3D:
		budget["particles"] = int(budget["particles"]) + 1
	elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		count += 1
		budget["meshes"] = int(budget["meshes"]) + 1
		budget["tris"] = int(budget["tris"]) + _mesh_triangles((node as MeshInstance3D).mesh)
	for child in node.get_children():
		count += _count_meshes(child, budget)
	return count


func _mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
			total += int((indices as PackedInt32Array).size() / 3)
		else:
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			if vertices is PackedVector3Array:
				total += int((vertices as PackedVector3Array).size() / 3)
	return total
