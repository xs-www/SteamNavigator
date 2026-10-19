class_name StageKit
extends RefCounted
## Shared builders for fixed-camera 2.5D stages.
##
## `ShipyardStage` and `PortStage` would otherwise copy the same environment,
## light, water and camera-framing setup. Keeping it here makes the two stage
## scenes read as "what is in this stage" instead of boilerplate.
##
## Everything is presentation: no GameState, no services, no content ids. Camera
## framing only reads a world-space AABB so hulls of different lengths share one
## composition.

const WATER_MATERIAL := "res://assets/materials/water/harbor_water.tres"
const WATER_FAR_MATERIAL := "res://assets/materials/water/harbor_water_far.tres"
const WATER_FALLBACK_COLOR := Color("18474f")

const DEFAULT_SKY_TOP := Color("0d1a24")
const DEFAULT_SKY_HORIZON := Color("8a5a38")
const DEFAULT_GROUND_HORIZON := Color("241c1a")
const DEFAULT_GROUND_BOTTOM := Color("0b0f12")
const DEFAULT_FOG_COLOR := Color("6b4a35")
const DEFAULT_AMBIENT_COLOR := Color("8fa9b4")


## Builds a WorldEnvironment under `parent`.
##
## config:
##   mode            "color" (default) or "sky"
##   background      BG_COLOR color when mode == "color"
##   sky_top / sky_horizon / ground_horizon / ground_bottom  sky palette
##   ambient_color / ambient_energy
##   fog / fog_color / fog_density / fog_sky_affect
static func add_environment(parent: Node3D, config: Dictionary = {}) -> WorldEnvironment:
	var environment := Environment.new()
	var mode := String(config.get("mode", "color"))
	if mode == "sky":
		var sky := Sky.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = _color(config.get("sky_top", DEFAULT_SKY_TOP), DEFAULT_SKY_TOP)
		sky_material.sky_horizon_color = _color(config.get("sky_horizon", DEFAULT_SKY_HORIZON), DEFAULT_SKY_HORIZON)
		sky_material.ground_horizon_color = _color(config.get("ground_horizon", DEFAULT_GROUND_HORIZON), DEFAULT_GROUND_HORIZON)
		sky_material.ground_bottom_color = _color(config.get("ground_bottom", DEFAULT_GROUND_BOTTOM), DEFAULT_GROUND_BOTTOM)
		sky_material.sky_curve = float(config.get("sky_curve", 0.12))
		sky_material.sun_angle_max = float(config.get("sun_angle_max", 8.0))
		sky.sky_material = sky_material
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = _color(config.get("background", Color("2b3c43")), Color("2b3c43"))
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = _color(config.get("ambient_color", DEFAULT_AMBIENT_COLOR), DEFAULT_AMBIENT_COLOR)
	environment.ambient_light_energy = float(config.get("ambient_energy", 0.6))
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = bool(config.get("fog", true))
	environment.fog_light_color = _color(config.get("fog_color", DEFAULT_FOG_COLOR), DEFAULT_FOG_COLOR)
	environment.fog_density = float(config.get("fog_density", 0.004))
	environment.fog_sky_affect = float(config.get("fog_sky_affect", 0.0))
	var world_environment := WorldEnvironment.new()
	world_environment.name = String(config.get("node_name", "StageEnvironment"))
	world_environment.environment = environment
	parent.add_child(world_environment)
	return world_environment


## Adds one shadow-free directional light (fixed-camera stages only need a key
## and a fill light; real-time shadows stay off to keep the 60fps budget).
static func add_directional_light(
	parent: Node3D,
	node_name: String,
	color: Color,
	energy: float,
	rotation_degrees: Vector3
) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = node_name
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = false
	light.rotation_degrees = rotation_degrees
	parent.add_child(light)
	return light


## Adds a horizontal water plane using the shared harbour shader. Falls back to
## a flat StandardMaterial when the framework material is missing.
static func add_water(
	parent: Node3D,
	material_path: String = WATER_MATERIAL,
	plane_size: float = 600.0,
	position_y: float = -0.05,
	overrides: Dictionary = {}
) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(plane_size, plane_size)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	var material := load_water_material(material_path, overrides)
	if material != null:
		water.material_override = material
	else:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = WATER_FALLBACK_COLOR
		fallback.roughness = 0.45
		fallback.metallic = 0.0
		water.material_override = fallback
	water.position = Vector3(0.0, position_y, 0.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(water)
	return water


## Duplicates the shared water material so each stage can tune shore/boat foam
## without mutating the resource every other scene uses.
static func load_water_material(material_path: String, overrides: Dictionary = {}) -> ShaderMaterial:
	if material_path.is_empty() or not ResourceLoader.exists(material_path):
		return null
	var source := load(material_path)
	if not (source is ShaderMaterial):
		return null
	var material: ShaderMaterial = (source as ShaderMaterial).duplicate(true)
	for key in overrides.keys():
		material.set_shader_parameter(String(key), overrides[key])
	return material


## Keeps the hull foam ring under a bobbing ship while hulls swap.
static func configure_boat_foam(material: ShaderMaterial, bounds: AABB) -> void:
	if material == null:
		return
	var center := bounds.get_center()
	material.set_shader_parameter("boat_center", Vector2(center.x, center.z))
	material.set_shader_parameter("boat_half_size", Vector2(
		maxf(bounds.size.x * 0.5, 1.0),
		maxf(bounds.size.z * 0.5, 1.0)
	))
	material.set_shader_parameter("boat_yaw", 0.0)


## Frames `bounds` from a fixed direction with a long lens, so every hull size
## (24 m steamer … 60 m ironclad) reads at the same composition. Models are not
## scaled — only the camera moves.
static func frame_camera(
	camera: Camera3D,
	bounds: AABB,
	direction: Vector3,
	fov: float,
	margin: float
) -> void:
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 1.0)
	var direction_normalized := direction.normalized()
	var distance := radius / tan(deg_to_rad(fov * 0.5)) * margin
	camera.position = center + direction_normalized * distance
	camera.look_at(center, Vector3.UP)


## World-space AABB of every MeshInstance3D under `root` (children included).
static func visual_aabb(root: Node) -> AABB:
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
				var mesh_box := transform_aabb(xform, mesh.get_aabb())
				bounds = mesh_box if not has_bounds else bounds.merge(mesh_box)
				has_bounds = true
		for child in node.get_children():
			stack.append({"node": child, "transform": xform})
	if not has_bounds:
		return AABB(Vector3(-6.0, -2.0, -6.0), Vector3(12.0, 5.0, 12.0))
	return bounds


static func transform_aabb(xform: Transform3D, box: AABB) -> AABB:
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


static func _color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String:
		return Color(String(value))
	return fallback
