## @static-doc
## 作用：PortStage 独立预览场景根（不接入主流程）：构建铺满窗口的 `SNStageHost`、挂载 `port_stage.tscn`、提供 preview / sparse 两份样例 ViewModel，并支持三站位切换与 town 资源根覆盖，供截图、draw call 实测与三条资产加载路径复现。
##
## - 关键依赖：`SNStageHost`、`framework/ui/stages/port_stage.tscn`
##
## ## 契约与约束
## - `set_variant("preview"|"sparse")` 不重挂舞台，只重新 bind 样例 payload；`current_variant()` 返回当前样例。
## - `set_station(station_id = "harbor", framing = "stage")` 调 `PortStage.focus_station(id, framing, true)`（立即生效，截图确定性），返回是否被接受；`station_id()`/`station_framing()`/`current_stage()` 供截图与实测工具轮询。
## - `TOWN_VISUALS` 是 26 项 dev 路径映射（10 个 `res://dev_mods/core/assets/models/props/SN_HT_*.glb` + 道具/设施）的样例；`_town_visuals()` 把其中位于松散 core props 目录的路径按 `SN_TOWN_ASSET_ROOT` 重新定根，从而让同一场景能从挂载的 `.snavmod.zip`（`res://mods/core/assets/models/props`，原始 `ContentAssetLoader` 路径）加载整套街景；框架自有资产（如 `market_stall`）保持原路径。
## - `sparse` 覆盖：无 banner（painted backdrop + 3 层远景 + 3 层雾带）、small→sparse 密度、根层 `facility_visuals`、`hull_model_path` 为空时按 `hull_tier` 回退；`preview` 的 ViewModel 仍带铁港 banner/town 数据，但 `landmark_path` 使 PortStage 进入最小门面模式（只留 terminal + 小装饰），`sparse` 保持 28 件街景。
## - 每个 variant / 站位打印设施 kinds、filler 数、backdrop、density、town_props、painted_layers、合批前后（batches、mesh/surface before→after）与投影后的设施锚点；`_print_scene_fill()` 只读统计粒子/雾/远景/前景框/三角面预算。
## - 运行：`godot --path . res://dev_scenes/port_stage/port_stage_preview.tscn`；截图 `tools/godot/capture_port_stage.gd`；实测 `tools/godot/measure_port_stage.gd`（加 `-- --core-zip` 切到 ZIP 加载路径）。
## @end-static-doc

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
##
## Stations (continuous harbour, three adjacent berths): `set_station(id,
## framing)` translates the fixed camera to `market` / `harbor` / `supply`
## (world X left → right) and moves the player ship to the matching berth.
## `framing = "stage"` is the full-window overview framing; `"panel"` is the
## offset framing used when a 620 px page panel covers the right edge. Both
## `set_variant()` and `set_station()` are callable from the screenshot tool;
## the station is applied immediately (no tween) so captures are deterministic.
##
## `SN_TOWN_ASSET_ROOT` (process environment) overrides the directory the town
## kit paths resolve from, so the same scene can be measured with the buildings
## loaded through a mounted `.snavmod.zip` (raw `ContentAssetLoader` path) instead
## of the loose `dev_mods` directory (imported-resource path):
##   SN_TOWN_ASSET_ROOT=res://mods/core/assets/models/props
## This is how the shared-texture / draw-call evidence covers the ZIP and
## release loading paths without duplicating the preview scene.

const STAGE_SCENE := "res://framework/ui/stages/port_stage.tscn"
const BANNER_PATH := "res://dev_mods/core/assets/ports/iron_harbor_banner.png"
## Pre-resolved town-kit paths (inside the loose dev core mod), mirroring what
## `port.view` resolves from `port.diorama.town` in the real game. The new
## dock-side industry slots reuse the official core-kit prop keys, so the
## preview exercises the exact same asset keys as the archetype content.
const TOWN_VISUALS := {
	"warehouse_long": "res://dev_mods/core/assets/models/props/SN_HT_Warehouse_Long.glb",
	"warehouse_short": "res://dev_mods/core/assets/models/props/SN_HT_Warehouse_Short.glb",
	"harbor_office": "res://dev_mods/core/assets/models/props/SN_HT_Harbor_Office.glb",
	"cargo_shed": "res://dev_mods/core/assets/models/props/SN_HT_Cargo_Shed.glb",
	"tavern": "res://dev_mods/core/assets/models/props/SN_HT_Tavern.glb",
	"fence_row": "res://dev_mods/core/assets/models/props/SN_HT_Fence_Row.glb",
	"dock_worker_a": "res://dev_mods/core/assets/models/props/SN_HT_Dock_Worker_A.glb",
	"dock_worker_b": "res://dev_mods/core/assets/models/props/SN_HT_Dock_Worker_B.glb",
	"rowboat": "res://dev_mods/core/assets/models/props/SN_HT_Rowboat.glb",
	"cargo_lighter": "res://dev_mods/core/assets/models/props/SN_HT_Cargo_Lighter.glb",
	"crate": "res://dev_mods/core/assets/models/props/SN_Crate.glb",
	"barrel": "res://dev_mods/core/assets/models/props/SN_Barrel.glb",
	"coal_pile": "res://dev_mods/core/assets/models/props/SN_Coal_Pile.glb",
	"timber_stack": "res://dev_mods/core/assets/models/props/SN_Timber_Stack.glb",
	"handcart": "res://dev_mods/core/assets/models/props/SN_Handcart.glb",
	"gas_lamp": "res://dev_mods/core/assets/models/props/SN_Gas_Lamp.glb",
	"market_stall": "res://assets/models/port/SN_Market_Stall.glb",
	"harbor_crane": "res://dev_mods/core/assets/models/props/SN_Harbor_Crane.glb",
	"sack_pile": "res://dev_mods/core/assets/models/props/SN_Sack_Pile.glb",
	"plate_stack": "res://dev_mods/core/assets/models/props/SN_Plate_Stack.glb",
	"ore_pile": "res://dev_mods/core/assets/models/props/SN_Ore_Pile.glb",
	"pallet": "res://dev_mods/core/assets/models/props/SN_Pallet.glb",
	"gangway": "res://dev_mods/core/assets/models/props/SN_Gangway.glb",
	"mooring_bollard": "res://dev_mods/core/assets/models/props/SN_Mooring_Bollard.glb",
	"capstan": "res://dev_mods/core/assets/models/props/SN_Capstan.glb",
	"buoy": "res://dev_mods/core/assets/models/props/SN_Buoy.glb",
}
const VARIANT_PREVIEW := "preview"
const VARIANT_SPARSE := "sparse"

var _host: SNStageHost
var _variant := VARIANT_PREVIEW
## Last station requested through `set_station()` ("" until the Lead's station
## API is used; the stage itself stays on its own default until then).
var _station_id := ""
var _station_framing := "stage"


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


## The mounted `PortStage` node (null while the stage is not ready). Used by the
## screenshot / measurement tools to poll the station transition state.
func current_stage() -> Node:
	if _host == null or not _host.has_stage():
		return null
	return _host.current_stage()


## Moves the fixed camera to one of the three adjacent berths and parks the
## player ship there. `station_id` is "market" / "harbor" / "supply"; `framing`
## is "stage" (full-window overview) or "panel" (620 px right panel reserved).
## Applies immediately (`focus_station(..., immediate = true)`) so screenshots
## and measurements do not race a tween. Returns whether the stage accepted it.
func set_station(station_id: String = "harbor", framing: String = "stage") -> bool:
	var stage := current_stage()
	if stage == null:
		push_error("PortStagePreview: stage is not mounted")
		return false
	if not stage.has_method("focus_station"):
		print("[PortStagePreview] station API missing: PortStage.focus_station() is not available yet")
		return false
	_station_id = station_id
	_station_framing = framing
	var focused := bool(stage.focus_station(station_id, framing, true))
	if not focused:
		push_warning("PortStagePreview: focus_station(%s, %s) returned false" % [station_id, framing])
	_print_station(stage, station_id, framing)
	return focused


## Station id requested by the last `set_station()` call ("" when unused).
func station_id() -> String:
	return _station_id


## Framing requested by the last `set_station()` call ("stage" by default).
func station_framing() -> String:
	return _station_framing


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


## Town-kit paths, re-rooted when `SN_TOWN_ASSET_ROOT` is set (the ZIP /
## release loading-path measurement); otherwise the loose dev core paths.
## Only paths that already live in the loose core props directory are re-rooted,
## so framework assets (e.g. the market-stall model) keep their own path.
## `SN_TOWN_COMBO=a|b` additionally swaps specific building slots to the batch-B
## prototypes (workshop row / boiler house / brick tenement) so two different
## five-building mixes can be captured from the same scene; missing prototype
## GLBs simply keep the original slot asset.
const PROTOTYPE_ROOT := "res://dev_mods/core/assets/models/props/"
const COMBO_OVERRIDES := {
	"a": {
		"warehouse_long": "SN_HT_Workshop_Row.glb",
		"tavern": "SN_HT_Boiler_House.glb",
	},
	"b": {
		"warehouse_long": "SN_HT_Workshop_Row.glb",
		"harbor_office": "SN_HT_Brick_Tenement.glb",
	},
}


func _town_visuals() -> Dictionary:
	var root := OS.get_environment("SN_TOWN_ASSET_ROOT").strip_edges()
	var out := TOWN_VISUALS.duplicate(true)
	if not root.is_empty():
		var loose_props := "res://dev_mods/core/assets/models/props/"
		for slot in out.keys():
			var path: String = out[slot]
			if path.begins_with(loose_props):
				out[slot] = root.rstrip("/") + "/" + path.get_file()
	var combo := OS.get_environment("SN_TOWN_COMBO").strip_edges().to_lower()
	if COMBO_OVERRIDES.has(combo):
		# The prototype root follows SN_TOWN_ASSET_ROOT so a ZIP-path measurement
		# keeps every building on the mounted pack (mixed loose/zip roots would
		# break the shared-texture batching and inflate the draw-call count).
		var prototype_root := PROTOTYPE_ROOT
		if not root.is_empty():
			prototype_root = root.rstrip("/") + "/"
		var overrides: Dictionary = COMBO_OVERRIDES[combo]
		for slot in overrides.keys():
			var prototype_path: String = prototype_root + String(overrides[slot])
			if FileAccess.file_exists(prototype_path):
				out[slot] = prototype_path
	return out


func _preview_payload() -> Dictionary:
	return {
		"port": {
			"id": "iron_harbor",
			"size": "medium",
			"facilities": ["exchange", "contracts", "supply", "intel", "shipyard"],
			"banner_path": BANNER_PATH,
			"town_visuals": _town_visuals(),
			"palette": {
				"stone": Color(0.14, 0.13, 0.115),
				"deck": Color(0.24, 0.17, 0.11),
				"wood": Color(0.32, 0.22, 0.13),
			},
			"facility_visuals": {},
			"landmark_path": "res://dev_mods/core/assets/models/architecture/SN_Grand_Harbour_Terminal.glb",
		},
		"ship": {
			"hull_model_path": "res://dev_mods/core/assets/models/ships/SN_Paddle_Steamer.glb",
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
			"town_visuals": _town_visuals(),
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


## Station report for the screenshot / measurement logs: requested station,
## stage-reported station + transition flag, requested vs. actual camera pose,
## ship berth X and the projected facility anchors for that framing.
func _print_station(stage: Node, station_id: String, framing: String) -> void:
	var current := String(stage.current_station()) if stage.has_method("current_station") else "?"
	var transitioning := bool(stage.is_station_transitioning()) if stage.has_method("is_station_transitioning") else false
	var station_props := int(stage.station_prop_count()) if stage.has_method("station_prop_count") else 0
	print("[PortStagePreview] station=%s framing=%s current=%s transitioning=%s station_props=%d" % [
		station_id, framing, current, str(transitioning), station_props,
	])
	var camera := stage.get_node_or_null("StageCamera") as Camera3D
	var pose := {}
	if stage.has_method("station_camera_pose"):
		var raw: Variant = stage.station_camera_pose(station_id, framing)
		if raw is Dictionary:
			pose = raw
	if not pose.is_empty():
		print("[PortStagePreview] station camera pose: position=%s target=%s fov=%.2f" % [
			_fmt_vec(pose.get("position", Vector3.ZERO)),
			_fmt_vec(pose.get("target", Vector3.ZERO)),
			float(pose.get("fov", 0.0)),
		])
	if camera != null:
		var forward := -camera.global_transform.basis.z
		var target := camera.global_position + forward * 64.0
		print("[PortStagePreview] camera actual: position=%s target=%s fov=%.2f" % [
			_fmt_vec(camera.global_position), _fmt_vec(target), camera.fov,
		])
	if stage.has_method("station_ship_position"):
		var ship_position: Vector3 = stage.station_ship_position(station_id)
		print("[PortStagePreview] station ship: position=%s x=%.3f" % [
			_fmt_vec(ship_position), ship_position.x,
		])
	var screen: Array[String] = []
	for facility in stage.facility_anchors().keys():
		var screen_pos: Vector2 = stage.facility_screen_anchor(String(facility))
		screen.append("%s=(%.3f, %.3f)" % [String(facility), screen_pos.x, screen_pos.y])
	print("[PortStagePreview] station screen anchors: " + ", ".join(screen))
	if stage.has_method("station_ids"):
		var ids: Array[String] = []
		for entry in stage.station_ids():
			ids.append(String(entry))
		print("[PortStagePreview] station ids: " + ", ".join(ids))


func _fmt_vec(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]


func _print_scene_fill(stage: Node) -> void:
	if not stage.has_method("foreground_frame"):
		return
	print("[PortStagePreview] fill: particles=%d fog_layers=%d skyline_buildings=%d skyline_cranes=%d" % [
		int(stage.atmosphere_particle_systems()),
		int(stage.atmosphere_layers()),
		int(stage.skyline_building_count()),
		int(stage.skyline_crane_count()),
	])
	if stage.has_method("town_prop_count"):
		print("[PortStagePreview] town: density=%s props=%d blockouts=%d painted_layers=%d" % [
			String(stage.town_density()) if stage.has_method("town_density") else "?",
			int(stage.town_prop_count()),
			int(stage.town_blockout_count()),
			int(stage.painted_backdrop_layer_count()) if stage.has_method("painted_backdrop_layer_count") else 0,
		])
	if stage.has_method("batch_stats"):
		var batch: Dictionary = stage.batch_stats()
		print("[PortStagePreview] static batches: batches=%d (multimesh=%d material=%d) meshes %d -> %d surfaces %d -> %d" % [
			int(batch.get("batches", 0)),
			int(batch.get("multimesh_batches", 0)),
			int(batch.get("material_batches", 0)),
			int(batch.get("meshes_before", 0)),
			int(batch.get("meshes_after", 0)),
			int(batch.get("surfaces_before", 0)),
			int(batch.get("surfaces_after", 0)),
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
