class_name PortStage
extends LocationStage
## Fixed-camera 2.5D port stage: quay, facilities, shore skyline, water and the
## player's moored ship in one 3/4 long-lens frame.
##
## Lifecycle: `_ready()` builds the static stage once (environment, lights,
## water, quay, camera). `bind()` only rebuilds the data-driven layers under
## `_content`:
##   L1  backdrop      banner texture, otherwise nothing (sky + fog + silhouettes)
##   L2  shoreline     deterministic BoxMesh silhouettes seeded by `port.id`
##   L3  facilities    anchors from `port.facilities`; missing ones get fillers
##   L5  player ship   `ship.hull_model_path`, tier fallback, bobbing in `_process`
## Repeated binds with the same ViewModel are no-ops, so the host can forward
## every application update without leaking nodes.
##
## `bind()` ViewModel (every field optional):
##   port.id               String  deterministic shoreline variation
##   port.size             String  "small" | "medium" | "large" -> 0.9/1.0/1.15
##   port.facilities       Array[String], subset of FACILITY_ORDER
##   port.banner_path      String  resolved L1 backdrop texture path
##   port.palette          Dictionary  stone/deck/wood/wood_dark/metal/iron/canvas/
##                                   brass plus per-facility sign colours
##   port.facility_visuals Dictionary  facility -> resolved GLB path (String or
##                                   Array[String]); may live at the root instead
##   port.landmark_path    String  optional single custom landmark model
##   ship.hull_model_path  String  resolved player hull GLB
##   ship.hull_tier        int     dev fallback when hull_model_path is empty
##
## Presentation only: no GameState, QueryBus or CommandBus; every path arrives
## pre-resolved in the ViewModel.

const FACILITY_ORDER := ["exchange", "contracts", "supply", "intel", "shipyard"]

## `port.size` -> uniform scale applied to the facility group parent.
const SIZE_SCALE := {"small": 0.9, "medium": 1.0, "large": 1.15}

const DOCK_TOP := 2.2
## Thin deck slab on piles: the quay reads as a trestle pier instead of a solid
## box floating on the water.
const DOCK_SIZE := Vector3(54.0, 0.6, 12.0)
const DOCK_CENTER := Vector3(0.0, 1.9, -6.0)
const DECK_SIZE := Vector3(54.0, 0.1, 12.0)
## Shore shelf behind the quay: the L2 silhouette row stands on it, so the
## skyline never floats directly on the water plane.
## Shore shelf behind the quay, wider/deeper than the frame so no cut edge or
## painted banner water is ever exposed beside it; the silhouette row stands on
## it and the quay reads as one shore instead of a floating box.
const SHORE_SIZE := Vector3(500.0, 1.3, 110.0)
const SHORE_CENTER := Vector3(0.0, -0.55, -65.0)
const SHORE_TOP := 0.1

const CAMERA_POS := Vector3(46.0, 28.0, 64.0)
const CAMERA_TARGET := Vector3(0.0, 12.0, -8.0)
const CAMERA_FOV := 30.0

## The hull is drawn at true scale: the camera backs off far enough that even a
## 60 m ironclad stays in the lower-left foreground without covering facility
## signs, while a 24 m paddle steamer reads as a complete moored ship.
const SHIP_SPAWN := Vector3(-13.5, 0.0, 9.0)
const SHIP_YAW_DEG := 20.0
const SHIP_SCALE := 1.0
const BOB_AMPLITUDE := 0.12
const BOB_SPEED := 0.9

const MODEL_BY_TIER := {
	1: "res://assets/models/ships/SN_Paddle_Steamer.glb",
	2: "res://assets/models/ships/SN_Paddle_Freighter.glb",
	3: "res://assets/models/ships/SN_Ironclad.glb",
}
const FALLBACK_MODEL := "res://assets/models/ships/SN_Ship_Prototype.glb"

## Local positions inside the scaled facility group; y is the quay top because
## the group itself sits on `DOCK_TOP`.
const SLOT_POSITIONS := {
	"exchange": Vector3(-16.0, 0.0, -3.0),
	"contracts": Vector3(-8.0, 0.0, -4.0),
	"supply": Vector3(0.0, 0.0, -3.0),
	"intel": Vector3(7.0, 0.0, -4.0),
	"shipyard": Vector3(14.5, 0.0, -4.5),
}
## Shipyard may carry two pieces (dry dock + gantry); the second rides behind
## and on top of the dry dock so the pivot stays on the quay top.
const SHIPYARD_PIECE_OFFSETS := [Vector3.ZERO, Vector3(0.0, 2.6, -2.0)]

const SIGN_YAW_DEG := 30.0
const SIGN_COLORS := {
	"exchange": Color(0.95, 0.63, 0.25),
	"contracts": Color(0.84, 0.72, 0.42),
	"supply": Color(0.34, 0.72, 0.66),
	"intel": Color(0.38, 0.62, 0.90),
	"shipyard": Color(0.88, 0.38, 0.24),
}

const SKY_TOP := Color(0.06, 0.11, 0.16)
const SKY_HORIZON := Color(0.68, 0.43, 0.26)
## Below-horizon sky hemisphere mirrors the warm fog band: if a few pixels of it
## ever show past the water/backdrop edge they read as haze, not a black band.
const SKY_GROUND_HORIZON := Color(0.77, 0.54, 0.35)
const SKY_GROUND_BOTTOM := Color(0.42, 0.28, 0.19)
const FOG_COLOR := Color(0.60, 0.40, 0.27)
const AMBIENT_COLOR := Color(0.56, 0.66, 0.72)
## L1 backdrop: oversized and pushed far back so its quad always covers the
## whole 1440x900 frame (the 120 m version used to leave sky visible on the
## left). `BACKDROP_POSITION.y` keeps the painted waterline below the quay.
const BACKDROP_SIZE := Vector2(260.0, 76.0)
const BACKDROP_POSITION := Vector3(-70.0, 12.0, -70.0)
const NEAR_WATER_SIZE := 600.0
const FAR_WATER_SIZE := 2400.0
## Fallback "sky wall": a dusk gradient card sitting just behind the far shore
## edge. It hides the endless water sheet behind the shore, so the no-backdrop
## variant gets a continuous warm haze horizon instead of the procedural sky's
## ground hemisphere or a hard waterline. Hidden whenever a painted L1 backdrop
## is mounted (the backdrop itself is the sky there).
const SKY_CARD_SIZE := Vector2(340.0, 100.0)
const SKY_CARD_POSITION := Vector3(-135.0, 25.0, -56.0)

const MATERIAL_DEFAULTS := {
	"stone": [Color(0.15, 0.14, 0.12), 0.92, 0.0],
	"deck": [Color(0.23, 0.16, 0.10), 0.88, 0.0],
	"wood": [Color(0.31, 0.22, 0.13), 0.86, 0.0],
	"wood_dark": [Color(0.16, 0.11, 0.07), 0.9, 0.0],
	"metal": [Color(0.20, 0.22, 0.24), 0.55, 0.45],
	"iron": [Color(0.11, 0.12, 0.13), 0.6, 0.5],
	"canvas": [Color(0.55, 0.46, 0.33), 0.95, 0.0],
	"brass": [Color(0.52, 0.38, 0.16), 0.42, 0.65],
}

const LANDMARK_POS := Vector3(-25.0, DOCK_TOP, -15.5)

var _static_built := false
var _content: Node3D
var _facilities_root: Node3D
var _camera: Camera3D
var _water_material: ShaderMaterial
var _materials: Dictionary = {}

var _port: Dictionary = {}
var _visuals: Dictionary = {}
var _palette: Dictionary = {}
var _facilities: Array[String] = []
var _facilities_present: Dictionary = {}
var _anchors: Dictionary = {}
var _kinds: Dictionary = {}
var _filler_count := 0
var _scale := 1.0
var _size := "medium"
var _backdrop: MeshInstance3D
var _has_backdrop := false
var _banner_path := ""
var _loaded_banner_path := ""
var _landmark: Node3D
var _shore_shelf: MeshInstance3D
var _sky_card: MeshInstance3D
var _ship_root: Node3D
var _ship_base := SHIP_SPAWN
var _ship_yaw := deg_to_rad(SHIP_YAW_DEG)
var _signature := ""
var _enter_payload: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	if stage_id.is_empty():
		stage_id = "port"
	_ensure_static()
	set_process(true)


func enter(payload: Dictionary = {}) -> void:
	if payload.has("port") or payload.has("ship") or payload.has("facility_visuals"):
		_enter_payload = payload.duplicate(true)
	set_process(true)


func exit() -> void:
	set_process(false)


func bind(view_model: Dictionary = {}) -> void:
	_ensure_static()
	var data := view_model
	if not _has_stage_data(data) and not _enter_payload.is_empty():
		data = _enter_payload
	var port_value: Variant = data.get("port", {})
	var port: Dictionary = port_value if port_value is Dictionary else {}
	var ship_value: Variant = data.get("ship", {})
	var ship: Dictionary = ship_value if ship_value is Dictionary else {}
	var root_visuals: Variant = data.get("facility_visuals", {})
	var signature := str(port) + "|" + str(ship) + "|" + str(root_visuals)
	if signature == _signature:
		return
	_signature = signature
	_apply_view_model(port, ship, data)


## --- Contract queries -------------------------------------------------------

## Procedural stage: always drawable, even when every content asset is missing.
func has_visual() -> bool:
	return true


func has_backdrop() -> bool:
	return _has_backdrop


## Path of the L1 backdrop texture that actually loaded (`""` when absent).
func loaded_banner_path() -> String:
	return _loaded_banner_path


func facility_count() -> int:
	return _facilities.size()


## Number of empty facility slots that received cargo filler instead of an
## anchor (one per missing facility in FACILITY_ORDER).
func filler_count() -> int:
	return _filler_count


## "model" (facility_visuals GLB mounted), "billboard" (procedural anchor) or
## "missing" (facility absent — only cargo filler exists, never a hotspot).
func facility_visual_kind(facility: String) -> String:
	return String(_kinds.get(facility, "missing"))


## World-space anchor per present facility (facility id -> Vector3).
func facility_anchors() -> Dictionary:
	var result := {}
	if _facilities_root == null:
		return result
	for facility in _facilities:
		if not _anchors.has(facility):
			continue
		var anchor: Node3D = _anchors[facility]
		result[facility] = _facilities_root.to_global(anchor.position)
	return result


## Same anchors projected through the stage camera and normalised to 0..1, so
## 2D hotspots can be laid out without touching 3D internals. ZERO when absent.
func facility_screen_anchor(facility: String) -> Vector2:
	if not _anchors.has(facility) or _camera == null:
		return Vector2.ZERO
	if _facilities_root == null or not is_inside_tree():
		return Vector2.ZERO
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var anchor: Node3D = _anchors[facility]
	var screen_pos := _camera.unproject_position(_facilities_root.to_global(anchor.position))
	return Vector2(screen_pos.x / viewport_size.x, screen_pos.y / viewport_size.y)


func has_ship() -> bool:
	return _ship_root != null and is_instance_valid(_ship_root) and _ship_root.get_child_count() > 0


## Emits the player intent; the host / page decides where it leads.
func request_portal(facility: String) -> void:
	portal_requested.emit(facility)


func hotspot_anchors() -> Dictionary:
	return facility_anchors()


# --- Frame loop -------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if _ship_root == null or not is_instance_valid(_ship_root):
		return
	if not is_visible_in_tree():
		return
	_ship_root.position = _ship_base + Vector3(0.0, sin(_time * BOB_SPEED) * BOB_AMPLITUDE, 0.0)
	_ship_root.rotation = Vector3(0.0, _ship_yaw, sin(_time * BOB_SPEED * 0.75) * 0.004)


# --- Static construction ----------------------------------------------------

func _ensure_static() -> void:
	if _static_built:
		return
	_static_built = true
	_build_materials()
	_build_environment()
	_add_sky_card()
	_add_water()
	_add_quay()
	_add_camera()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)


func _build_materials() -> void:
	_materials.clear()
	for key in MATERIAL_DEFAULTS.keys():
		var spec: Array = MATERIAL_DEFAULTS[key]
		var material := StandardMaterial3D.new()
		material.resource_name = "Port_" + String(key)
		material.albedo_color = spec[0]
		material.roughness = float(spec[1])
		material.metallic = float(spec[2])
		_materials[String(key)] = material


func _material(key: String) -> StandardMaterial3D:
	return _materials.get(key, null) as StandardMaterial3D


func _build_environment() -> void:
	var world_environment := StageKit.add_environment(self, {
		"mode": "sky",
		"sky_top": SKY_TOP,
		"sky_horizon": SKY_HORIZON,
		"ground_horizon": SKY_GROUND_HORIZON,
		"ground_bottom": SKY_GROUND_BOTTOM,
		"sky_curve": 0.10,
		"sun_angle_max": 10.0,
		"ambient_color": AMBIENT_COLOR,
		"ambient_energy": 0.55,
		"fog": true,
		"fog_color": FOG_COLOR,
		"fog_density": 0.0035,
		"fog_sky_affect": 0.08,
		"node_name": "StageEnvironment",
	})
	var environment := world_environment.environment
	if environment != null:
		# Depth (linear) fog instead of the default exponential curve: the quay
		# stays readable while the shore silhouettes and backdrop melt together.
		environment.fog_mode = Environment.FOG_MODE_DEPTH
		environment.fog_depth_begin = 70.0
		environment.fog_depth_end = 450.0
		environment.fog_depth_curve = 1.0
	# One warm key + one cool fill; fixed stages never pay for real-time shadows.
	StageKit.add_directional_light(self, "KeyLight", Color(1.0, 0.79, 0.55), 1.6, Vector3(-52.0, 38.0, 0.0))
	StageKit.add_directional_light(self, "FillLight", Color(0.48, 0.63, 0.82), 0.5, Vector3(-26.0, -142.0, 0.0))


func _add_water() -> void:
	var near_overrides := {
		"shore_z": 0.0,
		"shore_span": 120.0,
		"shore_foam_width": 2.8,
		"foam_strength": 0.55,
		"boat_center": Vector2(0.0, 10000.0),
		"boat_half_size": Vector2(1.0, 1.0),
		"boat_yaw": 0.0,
		"boat_foam_width": 0.7,
		"horizon_fade_start": 130.0,
		"horizon_fade_end": 420.0,
		"horizon_color": FOG_COLOR,
	}
	var near_water := StageKit.add_water(self, StageKit.WATER_MATERIAL, NEAR_WATER_SIZE, 0.0, near_overrides)
	near_water.name = "NearWater"
	_water_material = near_water.material_override as ShaderMaterial
	# The far sheet only outputs the horizon/fog colour; at 2400 m it reaches the
	# horizon line, so no sky-ground band is left visible behind the backdrop.
	var far_water := StageKit.add_water(self, StageKit.WATER_FAR_MATERIAL, FAR_WATER_SIZE, -0.2)
	far_water.name = "FarWater"
	var far_material := far_water.material_override as ShaderMaterial
	if far_material != null:
		far_material.set_shader_parameter("horizon_color", FOG_COLOR)


func _add_sky_card() -> void:
	# Dusk gradient painted onto one far quad. Acting as the fallback L1 haze, it
	# replaces the procedural sky's ground hemisphere and hides the endless far
	# water sheet behind the shore, so no hard horizon line ever shows.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.55, 0.72, 1.0])
	gradient.colors = PackedColorArray([SKY_TOP, SKY_TOP, SKY_HORIZON, FOG_COLOR, FOG_COLOR])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 256
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var material := StandardMaterial3D.new()
	material.resource_name = "Port_SkyCard"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = SKY_CARD_SIZE
	var card := MeshInstance3D.new()
	card.name = "SkyCard"
	card.mesh = quad
	card.material_override = material
	card.position = SKY_CARD_POSITION
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card)
	_sky_card = card


func _add_quay() -> void:
	# Dark shore shelf behind the quay: the silhouette row stands on solid
	# ground and the quay reads as one shore instead of a floating box.
	var shore_material := StandardMaterial3D.new()
	shore_material.resource_name = "Port_Shore"
	shore_material.albedo_color = Color(0.085, 0.082, 0.074)
	shore_material.roughness = 0.95
	shore_material.metallic = 0.0
	_shore_shelf = _add_box(self, SHORE_SIZE, SHORE_CENTER, shore_material, Vector3.ZERO, "ShoreShelf")
	_add_box(self, DOCK_SIZE, DOCK_CENTER, _material("stone"), Vector3.ZERO, "DockPlatform")
	_add_box(self, DECK_SIZE, Vector3(0.0, 2.15, -6.0), _material("deck"), Vector3.ZERO, "DockDeck")
	_add_box(self, Vector3(54.0, 0.3, 0.34), Vector3(0.0, 1.66, -0.2), _material("wood_dark"), Vector3.ZERO, "DeckEdgeBeam")
	# Trestle piles under the front edge, driven into the water.
	for x in [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]:
		_add_cylinder(self, 0.3, 0.34, 3.6, Vector3(x, 0.4, 0.55), _material("wood_dark"), "Pile")
		_add_box(self, Vector3(0.8, 0.5, 0.8), Vector3(x, 1.5, 0.55), _material("wood_dark"), Vector3.ZERO, "PileCap")
	_add_box(self, Vector3(54.0, 0.35, 0.35), Vector3(0.0, 1.32, 0.5), _material("wood_dark"), Vector3.ZERO, "Waler")
	# Timber stringers break up the long quay face.
	for x in [-18.0, -6.0, 6.0, 18.0]:
		_add_box(self, Vector3(0.6, 0.6, 0.35), Vector3(x, 1.9, -0.15), _material("wood_dark"), Vector3.ZERO, "")
	for index in range(-3, 4):
		_add_bollard(float(index) * 7.0, -1.1)
	for x in [-18.0, -2.0, 13.0, 25.0]:
		_add_lamp(float(x), -1.7)


func _add_bollard(x: float, z: float) -> void:
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.26
	body_mesh.bottom_radius = 0.30
	body_mesh.height = 0.7
	body_mesh.radial_segments = 12
	_add_mesh(self, body_mesh, Vector3(x, DOCK_TOP + 0.35, z), _material("metal"), Vector3.ZERO, "")
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.34
	cap_mesh.bottom_radius = 0.34
	cap_mesh.height = 0.14
	cap_mesh.radial_segments = 12
	_add_mesh(self, cap_mesh, Vector3(x, DOCK_TOP + 0.77, z), _material("iron"), Vector3.ZERO, "")


func _add_lamp(x: float, z: float) -> void:
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 4.2
	pole_mesh.radial_segments = 8
	_add_mesh(self, pole_mesh, Vector3(x, DOCK_TOP + 2.1, z), _material("iron"), Vector3.ZERO, "")
	var glow_material := _make_unshaded(Color(1.0, 0.68, 0.36), 1.6)
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.42, 0.46, 0.42)
	_add_mesh(self, glow_mesh, Vector3(x, DOCK_TOP + 4.55, z), glow_material, Vector3.ZERO, "")
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.56, 0.1, 0.56)
	_add_mesh(self, cap_mesh, Vector3(x, DOCK_TOP + 4.83, z), _material("iron"), Vector3.ZERO, "")


func _add_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "StageCamera"
	_camera.fov = CAMERA_FOV
	_camera.near = 0.5
	_camera.far = 1200.0
	add_child(_camera)
	_camera.position = CAMERA_POS
	_camera.look_at(CAMERA_TARGET, Vector3.UP)
	_camera.current = true


# --- Dynamic rebuild (bind) -------------------------------------------------

func _has_stage_data(data: Dictionary) -> bool:
	return data.has("port") or data.has("ship") or data.has("facility_visuals")


func _apply_view_model(port: Dictionary, ship: Dictionary, root_data: Dictionary) -> void:
	_port = port.duplicate(true)
	_size = String(_port.get("size", "medium")).to_lower()
	if not SIZE_SCALE.has(_size):
		_size = "medium"
	_scale = float(SIZE_SCALE.get(_size, 1.0))
	var palette_value: Variant = _port.get("palette", {})
	_palette = palette_value if palette_value is Dictionary else {}
	var visuals_value: Variant = _port.get("facility_visuals", null)
	if not (visuals_value is Dictionary):
		visuals_value = root_data.get("facility_visuals", {})
	_visuals = visuals_value if visuals_value is Dictionary else {}
	_banner_path = String(_port.get("banner_path", ""))
	_apply_palette()
	_clear_dynamic()
	_facilities_root = Node3D.new()
	_facilities_root.name = "Facilities"
	_facilities_root.position = Vector3(0.0, DOCK_TOP, 0.0)
	_facilities_root.scale = Vector3.ONE * _scale
	_content.add_child(_facilities_root)
	_rebuild_backdrop()
	# L2 silhouettes are the no-backdrop fallback only: a painted skyline plus
	# black boxes on top of it reads as floating rectangles.
	_rebuild_shoreline()
	_apply_sky_card_visibility()
	_rebuild_facilities()
	_rebuild_landmark()
	_rebuild_ship(ship)


func _clear_dynamic() -> void:
	_facilities.clear()
	_facilities_present.clear()
	_anchors.clear()
	_kinds.clear()
	_filler_count = 0
	_backdrop = null
	_has_backdrop = false
	_loaded_banner_path = ""
	_landmark = null
	_ship_root = null
	_facilities_root = null
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.free()


func _apply_palette() -> void:
	for key in MATERIAL_DEFAULTS.keys():
		var material := _material(String(key))
		if material != null:
			material.albedo_color = _palette_color(String(key), material.albedo_color)


func _palette_color(key: String, fallback: Color) -> Color:
	var value: Variant = _palette.get(key, null)
	if value is Color:
		return value
	if value is String:
		return Color(String(value))
	return fallback


func _sign_color(facility: String) -> Color:
	var fallback: Color = SIGN_COLORS.get(facility, Color(0.9, 0.7, 0.35))
	var value: Variant = _palette.get(facility, null)
	if value is Color:
		return value
	if value is String:
		return Color(String(value))
	return fallback


## Deterministic 0..1 value from the port id hash (no RandomNumberGenerator, so
## the same port always gets the same shoreline).
func _hash01(seed_value: int, index: int, salt: int) -> float:
	var value := seed_value ^ (index * 374761393) ^ (salt * 668265263)
	value = (value ^ (value >> 13)) * 1274126177
	value = value ^ (value >> 16)
	return float(value & 0xFFFFFF) / 16777215.0


func _make_unshaded(color: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# --- L2 shoreline silhouettes ----------------------------------------------

## Fallback layers only exist when there is no painted L1 backdrop: the shore
## shelf and silhouette row would cover the banner's lower half, and the sky card
## would sit in front of it. With a banner the pier stands directly against the
## painted city/water, which is the intended "L1 backdrop first" reading.
func _apply_sky_card_visibility() -> void:
	var use_fallback := not _has_backdrop
	if _sky_card != null:
		_sky_card.visible = use_fallback
	if _shore_shelf != null:
		_shore_shelf.visible = use_fallback


func _rebuild_shoreline() -> void:
	# A painted L1 backdrop already carries the skyline: stacking dark boxes in
	# front of it reads as floating rectangles, so L2 is a no-backdrop fallback.
	if _has_backdrop:
		return
	var shoreline := Node3D.new()
	shoreline.name = "Shoreline"
	_content.add_child(shoreline)
	var port_id := String(_port.get("id", "port"))
	var seed_value := port_id.hash()
	# Faded blue-grey, not pure black: dusk fog should still show a little depth.
	var near_tone := _make_unshaded(Color(0.075, 0.095, 0.115))
	var far_tone := _make_unshaded(Color(0.10, 0.12, 0.14))
	# Deliberately loose row: wide gaps and varied heights avoid a black wall.
	for index in 9:
		var r1 := _hash01(seed_value, index, 11)
		var r2 := _hash01(seed_value, index, 23)
		var r3 := _hash01(seed_value, index, 37)
		var width := 3.8 + r1 * 3.2
		var height := 3.0 + r2 * 6.0
		var depth := 3.0 + r3 * 3.0
		var x := -36.0 + float(index) * 9.2 + (r2 - 0.5) * 2.0
		var z := -27.0 - r3 * 5.0
		var tone := near_tone if index % 2 == 0 else far_tone
		_add_box(shoreline, Vector3(width, height, depth), Vector3(x, SHORE_TOP + height * 0.5, z), tone, Vector3.ZERO, "")
		if index % 3 == 1:
			# A low pitched roof keeps a couple of buildings readable as roofs.
			_add_box(shoreline, Vector3(width * 0.8, 1.1, depth * 0.9), Vector3(x, SHORE_TOP + height + 0.4, z), far_tone, Vector3(0.0, 0.0, 45.0), "")
		if index % 4 == 2:
			# One chimney silhouette only.
			_add_box(shoreline, Vector3(0.8, 2.2, 0.8), Vector3(x + width * 0.25, SHORE_TOP + height + 1.0, z - 0.4), near_tone, Vector3.ZERO, "")
	# Two crane silhouettes keep the shoreline reading as a working harbour.
	for index in 2:
		var cx := -24.0 + float(index) * 26.0 + _hash01(seed_value, index, 53) * 6.0
		var cz := -30.0
		_add_box(shoreline, Vector3(0.8, 9.5, 0.8), Vector3(cx, SHORE_TOP + 4.75, cz), far_tone, Vector3.ZERO, "")
		_add_box(shoreline, Vector3(0.7, 0.7, 8.0), Vector3(cx, SHORE_TOP + 8.6, cz + 2.9), far_tone, Vector3.ZERO, "")
		_add_box(shoreline, Vector3(0.18, 2.2, 0.18), Vector3(cx, SHORE_TOP + 7.4, cz + 6.2), far_tone, Vector3.ZERO, "")


# --- L1 backdrop ------------------------------------------------------------

func _rebuild_backdrop() -> void:
	_banner_path = String(_port.get("banner_path", ""))
	var texture: Texture2D = null
	if not _banner_path.is_empty():
		texture = _load_texture(_banner_path)
	if texture == null:
		# Deliberately no black box: keep sky + fog + L2 silhouettes/shore instead.
		return
	var material := StandardMaterial3D.new()
	material.resource_name = "Port_Backdrop"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	# Tint the painted skyline into the same dusk grade as the 3D foreground so
	# it does not read as a bright sticker.
	material.albedo_color = Color(0.72, 0.68, 0.64)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = BACKDROP_SIZE
	var backdrop := MeshInstance3D.new()
	backdrop.name = "Backdrop"
	backdrop.mesh = quad
	backdrop.material_override = material
	backdrop.position = BACKDROP_POSITION
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_content.add_child(backdrop)
	_backdrop = backdrop
	_has_backdrop = true
	_loaded_banner_path = _banner_path


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			return resource as Texture2D
	return ContentAssetLoader.load_texture(path)


# --- L3 facilities ----------------------------------------------------------

func _rebuild_facilities() -> void:
	var raw: Variant = _port.get("facilities", [])
	var present: Array = []
	if raw is Array:
		for item in raw:
			var facility := String(item)
			if FACILITY_ORDER.has(facility) and not present.has(facility):
				present.append(facility)
	for facility in FACILITY_ORDER:
		var slot: Vector3 = SLOT_POSITIONS[facility]
		if present.has(facility):
			_facilities.append(facility)
			_facilities_present[facility] = true
			var anchor := Node3D.new()
			anchor.name = "Facility_" + String(facility)
			anchor.position = slot
			_facilities_root.add_child(anchor)
			_anchors[facility] = anchor
			_kinds[facility] = _build_facility_visual(String(facility), anchor)
		else:
			var filler := Node3D.new()
			filler.name = "Filler_" + String(facility)
			filler.position = slot
			_facilities_root.add_child(filler)
			_build_filler(String(facility), filler)
			_filler_count += 1


func _build_facility_visual(facility: String, anchor: Node3D) -> String:
	var paths := _facility_visual_paths(facility)
	if not paths.is_empty():
		var built := 0
		for index in paths.size():
			var visual := _instantiate_visual(paths[index])
			if visual == null:
				continue
			if facility == "shipyard" and index < SHIPYARD_PIECE_OFFSETS.size():
				visual.position += SHIPYARD_PIECE_OFFSETS[index]
			anchor.add_child(visual)
			built += 1
		if built > 0:
			return "model"
	_build_facility_billboard(facility, anchor)
	return "billboard"


func _facility_visual_paths(facility: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = _visuals.get(facility, null)
	if raw is String and not String(raw).is_empty():
		result.append(String(raw))
	elif raw is Array:
		for item in raw:
			if item is String and not String(item).is_empty():
				result.append(String(item))
	return result


func _instantiate_visual(path: String) -> Node3D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var instance := packed.instantiate()
			if instance is Node3D:
				return instance as Node3D
			if instance != null:
				instance.free()
			return null
	return ContentAssetLoader.instantiate_model(path)


func _build_facility_billboard(facility: String, anchor: Node3D) -> void:
	match facility:
		"exchange":
			_billboard_exchange(anchor)
		"contracts":
			_billboard_contracts(anchor)
		"supply":
			_billboard_supply(anchor)
		"intel":
			_billboard_intel(anchor)
		"shipyard":
			_billboard_shipyard(anchor)
		_:
			_add_box(anchor, Vector3(2.0, 2.0, 2.0), Vector3(0.0, 1.0, 0.0), _material("wood"), Vector3.ZERO, "Anchor")


## Market stall: counter + canopy + warm amber sign.
func _billboard_exchange(root: Node3D) -> void:
	var wood := _material("wood")
	var dark := _material("wood_dark")
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(0.18, 2.5, 0.18), Vector3(side * 2.05, 1.25, -1.0), wood, Vector3.ZERO, "")
	_add_box(root, Vector3(4.4, 0.9, 1.1), Vector3(0.0, 0.45, 0.4), dark, Vector3.ZERO, "Counter")
	_add_box(root, Vector3(4.5, 0.12, 1.3), Vector3(0.0, 0.96, 0.4), wood, Vector3.ZERO, "CounterTop")
	_add_box(root, Vector3(4.8, 0.16, 2.8), Vector3(0.0, 2.62, -0.1), _material("canvas"), Vector3(-9.0, 0.0, 0.0), "Canopy")
	_add_box(root, Vector3(4.9, 0.1, 0.28), Vector3(0.0, 2.5, 1.24), dark, Vector3(-9.0, 0.0, 0.0), "")
	_add_sign(root, _sign_color("exchange"), Vector2(3.5, 1.0), Vector3(0.0, 3.15, 1.42))
	_add_crate(root, Vector3(-1.7, 0.0, 1.9), 0.9)
	_add_crate(root, Vector3(1.6, 0.0, 2.0), 0.75)
	_add_barrel(root, Vector3(2.2, 0.0, 1.1))


## Notice board: two posts, a paper-covered board and a brass sign.
func _billboard_contracts(root: Node3D) -> void:
	var dark := _material("wood_dark")
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(0.2, 2.65, 0.2), Vector3(side * 1.12, 1.32, 0.0), dark, Vector3.ZERO, "")
	_add_box(root, Vector3(2.7, 1.7, 0.16), Vector3(0.0, 1.8, 0.0), dark, Vector3.ZERO, "NoticeBoard")
	var paper := _make_unshaded(Color(0.80, 0.76, 0.62))
	for index in 3:
		_add_box(root, Vector3(0.48, 0.62, 0.03), Vector3(-0.8 + float(index) * 0.8, 1.85, 0.10), paper, Vector3(0.0, 0.0, 3.0 + float(index) * 4.0), "")
	_add_box(root, Vector3(2.95, 0.16, 0.55), Vector3(0.0, 2.72, 0.0), _material("wood"), Vector3.ZERO, "BoardCap")
	_add_sign(root, _sign_color("contracts"), Vector2(2.7, 0.8), Vector3(0.0, 3.05, 0.2))
	_add_lamp_post(root, Vector3(1.85, 0.0, 0.25))


## Water tank: riveted tank, conical roof, outlet pipe and a teal sign.
func _billboard_supply(root: Node3D) -> void:
	_add_box(root, Vector3(4.5, 0.35, 4.5), Vector3(0.0, 0.18, 0.0), _material("stone"), Vector3.ZERO, "TankBase")
	_add_cylinder(root, 1.95, 1.95, 3.3, Vector3(0.0, 1.95, 0.0), _material("metal"), "Tank")
	_add_cylinder(root, 0.0, 2.15, 1.15, Vector3(0.0, 4.16, 0.0), _material("iron"), "TankRoof")
	for side in [-1.0, 1.0]:
		_add_cylinder(root, 0.09, 0.09, 3.0, Vector3(side * 1.55, 1.6, 1.55), _material("iron"), "Leg")
	_add_cylinder(root, 0.16, 0.16, 1.9, Vector3(-1.55, 1.2, 1.55), _material("brass"), "Pipe")
	_add_sign(root, _sign_color("supply"), Vector2(2.5, 0.9), Vector3(0.0, 2.5, 2.05))
	_add_crate(root, Vector3(-3.2, 0.0, 1.3), 0.8)
	_add_crate(root, Vector3(3.1, 0.0, 1.6), 0.95)


## Signal tower: thin tall tower, crossarm, aerial and a cool blue sign.
func _billboard_intel(root: Node3D) -> void:
	_add_box(root, Vector3(2.9, 0.45, 2.9), Vector3(0.0, 0.22, 0.0), _material("stone"), Vector3.ZERO, "TowerBase")
	_add_box(root, Vector3(1.9, 7.6, 1.9), Vector3(0.0, 4.25, 0.0), _material("metal"), Vector3.ZERO, "Tower")
	_add_box(root, Vector3(3.9, 0.22, 0.22), Vector3(0.0, 7.55, 0.3), _material("iron"), Vector3.ZERO, "CrossArm")
	_add_cylinder(root, 0.06, 0.08, 2.4, Vector3(0.0, 9.15, 0.3), _material("iron"), "Aerial")
	_add_box(root, Vector3(0.34, 0.34, 0.34), Vector3(0.0, 8.0, 0.3), _make_unshaded(Color(1.0, 0.72, 0.38), 1.8), Vector3.ZERO, "SignalLamp")
	_add_sign(root, _sign_color("intel"), Vector2(2.2, 0.75), Vector3(0.0, 5.1, 1.05))
	_add_barrel(root, Vector3(-2.0, 0.0, 1.4))


## Shipyard: dry dock basin + gantry frame + rust red sign.
func _billboard_shipyard(root: Node3D) -> void:
	var stone := _material("stone")
	var iron := _material("iron")
	# Dry dock: low basin with raised side walls and keel blocks.
	_add_box(root, Vector3(15.0, 0.5, 6.4), Vector3(0.0, 0.25, 0.4), stone, Vector3.ZERO, "DryDockFloor")
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(15.0, 1.1, 0.9), Vector3(0.0, 0.55, 0.4 + side * 3.1), _material("wood_dark"), Vector3.ZERO, "DryDockWall")
	for index in 3:
		_add_box(root, Vector3(1.4, 0.7, 0.9), Vector3(-4.2 + float(index) * 4.2, 0.85, 0.4), _material("wood"), Vector3.ZERO, "KeelBlock")
	# Gantry straddling the dock.
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(0.7, 8.4, 0.7), Vector3(side * 5.2, 4.2, -2.6), iron, Vector3.ZERO, "GantryLeg")
		_add_box(root, Vector3(0.3, 0.3, 3.0), Vector3(side * 5.2, 4.0, -1.2), iron, Vector3.ZERO, "")
	_add_box(root, Vector3(11.6, 0.75, 0.9), Vector3(0.0, 8.4, -2.6), iron, Vector3.ZERO, "GantryBeam")
	_add_box(root, Vector3(0.5, 0.5, 2.4), Vector3(0.0, 7.0, -2.6), iron, Vector3.ZERO, "Hoist")
	_add_box(root, Vector3(0.08, 2.4, 0.08), Vector3(1.3, 5.8, -2.6), iron, Vector3.ZERO, "Cable")
	_add_box(root, Vector3(0.5, 0.4, 0.5), Vector3(1.3, 4.5, -2.6), _material("brass"), Vector3.ZERO, "Hook")
	_add_sign(root, _sign_color("shipyard"), Vector2(4.4, 1.1), Vector3(0.0, 8.35, -2.0))


# --- Empty slots ------------------------------------------------------------

func _build_filler(facility: String, root: Node3D) -> void:
	var seed_value := String(_port.get("id", "port")).hash() ^ ((FACILITY_ORDER.find(facility) + 1) * 7919)
	_add_box(root, Vector3(3.4, 0.08, 2.6), Vector3(0.0, 0.04, 0.0), _material("wood_dark"), Vector3.ZERO, "FillerPallet")
	var wood := _material("wood")
	var count := 2 + int(_hash01(seed_value, 1, 5) * 2.0)
	for index in count:
		var size := 0.7 + _hash01(seed_value, index, 13) * 0.8
		var pos := Vector3(
			(_hash01(seed_value, index, 17) - 0.5) * 2.6,
			size * 0.5,
			(_hash01(seed_value, index, 19) - 0.5) * 1.8
		)
		var rotation := Vector3(0.0, _hash01(seed_value, index, 29) * 40.0, 0.0)
		_add_box(root, Vector3(size, size * 0.85, size), pos, wood, rotation, "FillerCrate")
	_add_barrel(root, Vector3(1.4, 0.0, 1.2))
	if _hash01(seed_value, 2, 31) > 0.45:
		_add_box(root, Vector3(1.9, 0.55, 1.5), Vector3(-1.1, 0.28, 1.3), _material("canvas"), Vector3(0.0, -20.0, 0.0), "FillerSacks")


# --- Landmark ---------------------------------------------------------------

func _rebuild_landmark() -> void:
	var path := String(_port.get("landmark_path", ""))
	if path.is_empty():
		return
	var visual := _instantiate_visual(path)
	if visual == null:
		return
	var landmark := Node3D.new()
	landmark.name = "Landmark"
	landmark.position = LANDMARK_POS
	visual.position = Vector3.ZERO
	landmark.add_child(visual)
	_content.add_child(landmark)
	_landmark = landmark


# --- L5 player ship ---------------------------------------------------------

func _rebuild_ship(ship: Dictionary) -> void:
	var path := String(ship.get("hull_model_path", ""))
	if path.is_empty():
		path = _fallback_path_for_tier(int(ship.get("hull_tier", 1)))
	var visual := _instantiate_visual(path)
	if visual == null:
		_disable_boat_foam()
		return
	var root := Node3D.new()
	root.name = "PlayerShip"
	root.position = SHIP_SPAWN
	root.scale = Vector3.ONE * SHIP_SCALE
	root.rotation = Vector3(0.0, _ship_yaw, 0.0)
	_content.add_child(root)
	_ship_root = root
	_ship_base = SHIP_SPAWN
	root.add_child(visual)
	var bounds := StageKit.visual_aabb(root)
	if _water_material != null:
		StageKit.configure_boat_foam(_water_material, bounds)
		_water_material.set_shader_parameter("boat_yaw", _ship_yaw)
		_water_material.set_shader_parameter("boat_foam_width", 0.8)


func _fallback_path_for_tier(tier: int) -> String:
	var path := String(MODEL_BY_TIER.get(tier, MODEL_BY_TIER[1]))
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		return path
	return FALLBACK_MODEL


func _disable_boat_foam() -> void:
	if _water_material == null:
		return
	_water_material.set_shader_parameter("boat_center", Vector2(0.0, 10000.0))
	_water_material.set_shader_parameter("boat_half_size", Vector2(1.0, 1.0))
	_water_material.set_shader_parameter("boat_yaw", 0.0)


# --- Primitive helpers ------------------------------------------------------

func _add_box(parent: Node3D, size: Vector3, position3d: Vector3, material: Material, rotation_degrees: Vector3 = Vector3.ZERO, node_name: String = "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, mesh, position3d, material, rotation_degrees, node_name)


func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, position3d: Vector3, material: Material, node_name: String = "") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	return _add_mesh(parent, mesh, position3d, material, Vector3.ZERO, node_name)


func _add_mesh(parent: Node3D, mesh: Mesh, position3d: Vector3, material: Material, rotation_degrees: Vector3, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if not node_name.is_empty():
		instance.name = node_name
	instance.mesh = mesh
	if material != null:
		instance.material_override = material
	instance.position = position3d
	instance.rotation_degrees = rotation_degrees
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_sign(parent: Node3D, color: Color, size: Vector2, position3d: Vector3) -> void:
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(size.x + 0.16, size.y + 0.16, 0.1)
	var frame := _add_mesh(
		parent,
		frame_mesh,
		position3d + Vector3(0.0, 0.0, -0.06),
		_material("iron"),
		Vector3(0.0, SIGN_YAW_DEG, 0.0),
		"SignFrame"
	)
	frame.rotation_degrees = Vector3(0.0, SIGN_YAW_DEG, 0.0)
	var quad := QuadMesh.new()
	quad.size = size
	var material := _make_unshaded(color, 1.15)
	var sign_instance := _add_mesh(parent, quad, position3d, material, Vector3(0.0, SIGN_YAW_DEG, 0.0), "Sign")
	sign_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_crate(parent: Node3D, position3d: Vector3, size: float) -> void:
	_add_box(parent, Vector3(size, size, size), position3d + Vector3(0.0, size * 0.5, 0.0), _material("wood"), Vector3(0.0, 12.0, 0.0), "")


func _add_barrel(parent: Node3D, position3d: Vector3) -> void:
	_add_cylinder(parent, 0.38, 0.42, 0.95, position3d + Vector3(0.0, 0.475, 0.0), _material("metal"), "")
	_add_cylinder(parent, 0.44, 0.44, 0.08, position3d + Vector3(0.0, 0.86, 0.0), _material("iron"), "")


func _add_lamp_post(parent: Node3D, position3d: Vector3) -> void:
	_add_cylinder(parent, 0.06, 0.09, 3.2, position3d + Vector3(0.0, 1.6, 0.0), _material("iron"), "")
	_add_box(parent, Vector3(0.3, 0.34, 0.3), position3d + Vector3(0.0, 3.3, 0.0), _make_unshaded(Color(1.0, 0.68, 0.36), 1.5), Vector3.ZERO, "")
