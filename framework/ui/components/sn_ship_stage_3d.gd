class_name SNShipStage3D
extends Control
## A real 3D ship stage behind the 2D shipyard HUD (2.5D 舞台第一个落地切片).
##
## It plugs into the existing `SNShipView.set_renderer()` contract:
##   ship_view_update(model)     — pick the hull visual by `hull_tier`
##   ship_view_set_mode(mode)    — EXTERIOR shows the 3D stage, CUTAWAY hides it
##   ship_view_highlight(ids)    — reserved for part highlighting, currently a no-op
##
## The node owns only presentation: camera, lights, water and the GLB hull. It
## never reads GameState, QueryBus or CommandBus, and the 2D slot chips / layout
## stay in SNShipView. When no official ship GLB is available the screen simply
## keeps SNShipView's procedural placeholder (no empty 3D viewport is mounted).

const MODEL_BY_TIER := {
	1: "res://assets/models/ships/SN_Paddle_Steamer.glb",
	2: "res://assets/models/ships/SN_Paddle_Freighter.glb",
	3: "res://assets/models/ships/SN_Ironclad.glb",
}
const FALLBACK_MODEL := "res://assets/models/ships/SN_Ship_Prototype.glb"
const WATER_MATERIAL := "res://assets/materials/water/harbor_water.tres"
const BACKGROUND_COLOR := Color("2b3c43")
const WATER_COLOR := Color("18474f")
const CAMERA_DIRECTION := Vector3(0.58, 0.24, 1.0)
const CAMERA_FOV := 30.0
const FRAMING_MARGIN := 0.74
const BOB_AMPLITUDE := 0.12
const BOB_SPEED := 0.9

var _container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _ship_root: Node3D
var _water_material: ShaderMaterial
var _model_path := ""
var _pending_model: Dictionary = {}
var _pending_mode := 0
var _time := 0.0


## True when at least one official ship GLB is importable in this build. The
## screen uses it to decide whether to mount the 3D stage at all.
static func is_supported() -> bool:
	for path in MODEL_BY_TIER.values():
		if ResourceLoader.exists(String(path)):
			return true
	return ResourceLoader.exists(FALLBACK_MODEL)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stage()
	set_mode_visible(_pending_mode == 0)
	_apply_model()
	set_process(true)


## True once a ship GLB instance is mounted inside the stage.
func has_ship() -> bool:
	return _ship_root != null and _ship_root.get_child_count() > 0


func model_path() -> String:
	return _model_path


# --- SNShipView renderer contract -------------------------------------------

func ship_view_update(model: Dictionary) -> void:
	_pending_model = model.duplicate(true)
	if _camera != null:
		_apply_model()


func ship_view_set_mode(mode: int) -> void:
	_pending_mode = mode
	if _container != null:
		set_mode_visible(mode == 0)


func ship_view_highlight(_slot_ids: Array) -> void:
	# Highlighting parts on the 3D hull is part of the next stage slice.
	pass


# --- Stage construction ------------------------------------------------------

func set_mode_visible(visible_stage: bool) -> void:
	if _container != null:
		_container.visible = visible_stage


func _build_stage() -> void:
	_container = SubViewportContainer.new()
	_container.name = "Stage3DContainer"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	_viewport = SubViewport.new()
	_viewport.name = "Stage3DViewport"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_container.add_child(_viewport)

	_world = Node3D.new()
	_world.name = "Stage3DWorld"
	_viewport.add_child(_world)
	_add_environment()
	_add_lights()
	_add_water()
	_add_camera()


func _add_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa9b4")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = BACKGROUND_COLOR
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.name = "Stage3DEnvironment"
	world_environment.environment = environment
	_world.add_child(world_environment)


func _add_lights() -> void:
	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_color = Color("f6dcae")
	key_light.light_energy = 1.7
	key_light.shadow_enabled = false
	key_light.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	_world.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_color = Color("7fb6c8")
	fill_light.light_energy = 0.45
	fill_light.shadow_enabled = false
	fill_light.rotation_degrees = Vector3(-26.0, -142.0, 0.0)
	_world.add_child(fill_light)


func _add_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(600.0, 600.0)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	var shader_material := _load_water_material()
	if shader_material != null:
		_water_material = shader_material
		water.material_override = shader_material
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = WATER_COLOR
		material.roughness = 0.45
		material.metallic = 0.0
		water.material_override = material
	water.position = Vector3(0.0, -0.05, 0.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(water)


## Shared harbour water shader, duplicated per stage so ship foam can follow the
## current hull. Falls back to a flat StandardMaterial when the asset is absent.
func _load_water_material() -> ShaderMaterial:
	if not ResourceLoader.exists(WATER_MATERIAL):
		return null
	var source := load(WATER_MATERIAL)
	if not (source is ShaderMaterial):
		return null
	var material: ShaderMaterial = (source as ShaderMaterial).duplicate(true)
	material.set_shader_parameter("shore_z", 100000.0)
	material.set_shader_parameter("shore_foam_width", 0.0)
	material.set_shader_parameter("boat_foam_width", 0.55)
	material.set_shader_parameter("horizon_fade_start", 90.0)
	material.set_shader_parameter("horizon_fade_end", 260.0)
	return material


## Keeps the hull foam ring under the ship while it bobs and while hulls swap.
func _configure_water(bounds: AABB) -> void:
	if _water_material == null:
		return
	var center := bounds.get_center()
	_water_material.set_shader_parameter("boat_center", Vector2(center.x, center.z))
	_water_material.set_shader_parameter("boat_half_size", Vector2(
		maxf(bounds.size.x * 0.5, 1.0),
		maxf(bounds.size.z * 0.5, 1.0)
	))
	_water_material.set_shader_parameter("boat_yaw", 0.0)


func _add_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Stage3DCamera"
	_camera.fov = CAMERA_FOV
	_camera.near = 0.5
	_camera.far = 800.0
	_camera.current = true
	_world.add_child(_camera)


# --- Ship visual -------------------------------------------------------------

func _apply_model() -> void:
	var tier := int(_pending_model.get("hull_tier", 1))
	_rebuild_ship(tier)


func _rebuild_ship(tier: int) -> void:
	var path := String(MODEL_BY_TIER.get(tier, MODEL_BY_TIER[1]))
	if not ResourceLoader.exists(path):
		path = FALLBACK_MODEL
	if path == _model_path and has_ship():
		return
	if _ship_root != null:
		_world.remove_child(_ship_root)
		_ship_root.queue_free()
	_ship_root = Node3D.new()
	_ship_root.name = "Ship"
	_world.add_child(_ship_root)
	_model_path = path
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var visual: Node3D = packed.instantiate()
	_ship_root.add_child(visual)
	_frame_camera(visual)
	_configure_water(_visual_aabb(visual))


## Frames the loaded hull from a fixed 3/4 angle with a long lens, so every
## hull size (24 m steamer … 60 m ironclad) reads at the same composition.
func _frame_camera(visual: Node3D) -> void:
	var bounds := _visual_aabb(visual)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var direction := CAMERA_DIRECTION.normalized()
	var distance := radius / tan(deg_to_rad(CAMERA_FOV * 0.5)) * FRAMING_MARGIN
	_camera.position = center + direction * distance
	_camera.look_at(center, Vector3.UP)


func _visual_aabb(root: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	var stack: Array = [{"node": root, "transform": Transform3D.IDENTITY}]
	while not stack.is_empty():
		var entry: Dictionary = stack.pop_back()
		var node: Node = entry["node"]
		var xform: Transform3D = entry["transform"]
		if node is Node3D:
			xform = xform * (node as Node3D).transform
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				var mesh_box := _transform_aabb(xform, mesh.get_aabb())
				bounds = mesh_box if not has_bounds else bounds.merge(mesh_box)
				has_bounds = true
		for child in node.get_children():
			stack.append({"node": child, "transform": xform})
	if not has_bounds:
		return AABB(Vector3(-6.0, -2.0, -6.0), Vector3(12.0, 5.0, 12.0))
	return bounds


func _transform_aabb(xform: Transform3D, box: AABB) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for index in 8:
		var corner := box.position + Vector3(
			box.size.x if index & 1 else 0.0,
			box.size.y if index & 2 else 0.0,
			box.size.z if index & 4 else 0.0
		)
		var world_corner := xform * corner
		minimum = minimum.min(world_corner)
		maximum = maximum.max(world_corner)
	return AABB(minimum, maximum - minimum)


func _process(delta: float) -> void:
	_time += delta
	if _ship_root == null or not is_visible_in_tree():
		return
	_ship_root.position.y = sin(_time * BOB_SPEED) * BOB_AMPLITUDE
	_ship_root.rotation.z = sin(_time * BOB_SPEED * 0.75) * 0.004
