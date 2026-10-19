class_name SNStageHost
extends SubViewportContainer
## Hosts exactly one `LocationStage` inside its own SubViewport, so 2D HUD and
## hotspots can sit on top of the 3D stage while the 3D keeps a private World3D.
##
## Responsibilities:
##   - viewport / world creation and render-pause when the host is hidden;
##   - stage scene loading, mounting, unmounting and lifecycle (enter/bind/exit);
##   - re-emitting `portal_requested` and `fallback_requested`.
##
## Stage content (camera, lights, water, props) belongs to the LocationStage
## scene, not here. The host is also the current `SNShipView` renderer backend
## through `SNShipStage3D`, so the same container serves the shipyard today and
## the port stage next.

signal stage_mounted(stage: Node, stage_id: String)
signal stage_unmounted(stage_id: String)
signal portal_requested(target_id: String)
signal fallback_requested(reason: String)

const STAGE_WORLD_NAME := "StageWorld"
const DEFAULT_VIEWPORT_SIZE := Vector2i(1440, 900)

## Scene loaded automatically on `_ready` (optional; a caller may mount a stage
## instance directly with `mount_stage` instead).
@export var stage_scene_path: String = ""
## True when the 3D viewport should composite over whatever 2D sits behind it.
@export var transparent_background := false
## 3D viewport resolution divisor (`SubViewportContainer.stretch_shrink`): 1 is
## full UI resolution, 2 renders at half size. Rendering is not gameplay, so a
## lower divisor is a cheap quality lever on slow machines.
@export var render_shrink := 1
## Load `stage_scene_path` when the host enters the tree.
@export var auto_load := true

var _viewport: SubViewport
var _world: Node3D
var _stage: Node
var _stage_id := ""
var _view_model: Dictionary = {}
var _pending_payload: Dictionary = {}
var _stage_visible := true
var _built := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	stretch_shrink = maxi(1, render_shrink)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_host()
	if auto_load and not stage_scene_path.is_empty():
		load_stage(stage_scene_path, _pending_payload)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply_render_state()


func _exit_tree() -> void:
	if is_instance_valid(_stage) and _stage.has_method("exit"):
		_stage.exit()


## --- Host API ---------------------------------------------------------------

## Loads a stage scene by path and mounts it. Returns false and emits
## `fallback_requested` when the scene is missing, fails to load, or its root is
## not a `LocationStage`; the caller then keeps its 2D fallback.
func load_stage(path: String, payload: Dictionary = {}) -> bool:
	if not _built:
		# Called before `_ready`: remember the request and honour it in _ready.
		stage_scene_path = path
		_pending_payload = payload.duplicate(true)
		auto_load = true
		return false
	if path.is_empty():
		_emit_fallback("stage_scene_empty")
		return false
	if not ResourceLoader.exists(path):
		_emit_fallback("stage_scene_missing:%s" % path)
		return false
	var packed := load(path)
	if not (packed is PackedScene):
		_emit_fallback("stage_scene_invalid:%s" % path)
		return false
	var instance: Node = (packed as PackedScene).instantiate()
	if not (instance is LocationStage):
		push_error("SNStageHost: stage root is not a LocationStage: %s" % path)
		instance.free()
		_emit_fallback("stage_not_location_stage:%s" % path)
		return false
	return mount_stage(instance, payload)


## Mounts an already-instantiated stage, replacing the current one. The host
## calls `enter(payload)` then `bind(view_model)` in that order.
func mount_stage(stage: Node, payload: Dictionary = {}) -> bool:
	if not _built:
		push_error("SNStageHost: mount_stage() requires the host to be in the tree")
		return false
	if stage == null or not (stage is LocationStage):
		_emit_fallback("stage_not_location_stage")
		return false
	unmount_stage()
	_stage = stage
	_stage_id = String((stage as LocationStage).stage_id)
	if _stage_id.is_empty():
		_stage_id = String(stage.name)
	(stage as LocationStage).portal_requested.connect(_on_stage_portal_requested)
	_world.add_child(stage)
	(stage as LocationStage).enter(payload)
	(stage as LocationStage).bind(_view_model)
	_apply_render_state()
	stage_mounted.emit(_stage, _stage_id)
	return true


## Unmounts the current stage (calling `exit()` first) and frees it.
func unmount_stage() -> void:
	if not is_instance_valid(_stage):
		_stage = null
		return
	var old_stage := _stage
	var old_id := _stage_id
	_stage = null
	_stage_id = ""
	if old_stage.has_method("exit"):
		old_stage.exit()
	if old_stage.get_parent() != null:
		old_stage.get_parent().remove_child(old_stage)
	old_stage.free()
	stage_unmounted.emit(old_id)


## Cache the latest application ViewModel and forward it to the mounted stage.
func bind_view_model(view_model: Dictionary) -> void:
	_view_model = view_model.duplicate(true)
	if is_instance_valid(_stage) and _stage.has_method("bind"):
		_stage.bind(_view_model)


func has_stage() -> bool:
	return is_instance_valid(_stage)


func current_stage() -> Node:
	return _stage


func stage_id() -> String:
	return _stage_id


func view_model() -> Dictionary:
	return _view_model


func stage_world() -> Node3D:
	return _world


func stage_viewport() -> SubViewport:
	return _viewport


## Shows/hides the 3D stage and pauses its rendering + processing while hidden.
func set_stage_visible(value: bool) -> void:
	_stage_visible = value
	visible = value
	_apply_render_state()


func is_stage_visible() -> bool:
	return _stage_visible


## --- Internals --------------------------------------------------------------

func _build_host() -> void:
	if _built:
		return
	_viewport = SubViewport.new()
	_viewport.name = "StageViewport"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = transparent_background
	_viewport.gui_disable_input = true
	_viewport.size = DEFAULT_VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_world = Node3D.new()
	_world.name = STAGE_WORLD_NAME
	_viewport.add_child(_world)
	_built = true


## One 3D stage at a time: hide the host and stop the viewport/script work as
## soon as it is not visible, instead of rendering a background stage.
func _apply_render_state() -> void:
	if _viewport == null:
		return
	var active := _stage_visible and is_inside_tree() and is_visible_in_tree()
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_WHEN_VISIBLE if active else SubViewport.UPDATE_DISABLED
	)
	if is_instance_valid(_stage):
		_stage.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _on_stage_portal_requested(target_id: String) -> void:
	portal_requested.emit(target_id)


func _emit_fallback(reason: String) -> void:
	fallback_requested.emit(reason)
