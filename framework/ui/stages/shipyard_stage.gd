class_name ShipyardStage
extends LocationStage
## Fixed 3/4 camera ship stage used by the shipyard's EXTERIOR mode.
##
## The hull comes from the mounted content mod (`information.model` resolved to
## `hull_model_path`); the hardcoded tier mapping is only a dev fallback for
## builds that still carry `res://assets/models/ships`. When no hull is
## available the stage stays empty and the shipyard keeps `SNShipView`'s
## procedural placeholder.
##
## Stage 5 (ShipVisualAssembler): when the ship ViewModel carries a resolved
## `visual` plan the stage assembles hull + rig kit + weapons through
## `ShipVisualAssembler`; a failed plan falls back to the legacy
## `hull_model_path` / tier / prototype chain, so old saves and missing content
## keep the previous single-hull behaviour.
##
## This file is the migration of the first 2.5D slice: environment, lights,
## water, camera framing and bobbing live here, while `SNStageHost` owns the
## viewport / lifecycle.

const MODEL_BY_TIER := {
	1: "res://assets/models/ships/SN_Paddle_Steamer.glb",
	2: "res://assets/models/ships/SN_Paddle_Freighter.glb",
	3: "res://assets/models/ships/SN_Ironclad.glb",
}
const FALLBACK_MODEL := "res://assets/models/ships/SN_Ship_Prototype.glb"
const BACKGROUND_COLOR := Color("2b3c43")
const WATER_COLOR := Color("18474f")
const CAMERA_DIRECTION := Vector3(0.58, 0.24, 1.0)
const CAMERA_FOV := 30.0
const FRAMING_MARGIN := 0.74
const BOB_AMPLITUDE := 0.12
const BOB_SPEED := 0.9

var _ship_root: Node3D
var _camera: Camera3D
var _water_material: ShaderMaterial
var _model_path := ""
var _ship_view: Dictionary = {}
var _time := 0.0
var _plan_signature := ""
var _assembly_report: Dictionary = {}


func _ready() -> void:
	if stage_id.is_empty():
		stage_id = "shipyard"
	_build_environment()
	_add_water()
	_add_camera()
	_apply_model()
	set_process(true)


func enter(_payload: Dictionary = {}) -> void:
	set_process(true)


func exit() -> void:
	set_process(false)


func bind(view_model: Dictionary = {}) -> void:
	var ship: Variant = view_model.get("ship", view_model)
	_ship_view = ship.duplicate(true) if ship is Dictionary else {}
	_apply_model()


## True once a ship GLB instance is mounted inside the stage.
func has_ship() -> bool:
	return _ship_root != null and _ship_root.get_child_count() > 0


func model_path() -> String:
	return _model_path


## Assembler report of the current ship (`{}` for the legacy single-hull path):
## `hull_asset` / `fallback` / `rig` / `weapons` / `triangles`.
func assembly_report() -> Dictionary:
	return _assembly_report.duplicate(true)


## Rig assembly verdict (`mode` = replace/baked, `mounted`, `skipped`, `hidden`).
func rig_report() -> Dictionary:
	var rig: Variant = _assembly_report.get("rig", {})
	return (rig as Dictionary).duplicate(true) if rig is Dictionary else {}


## Weapon mount handles of the current ship (empty on the legacy path). The
## stage does not batch hulls, so these stay valid for the ship's lifetime.
func weapon_mounts() -> Array:
	var weapons: Variant = _assembly_report.get("weapons", {})
	if not (weapons is Dictionary):
		return []
	var mounts: Variant = (weapons as Dictionary).get("mounts", [])
	return mounts if mounts is Array else []


# --- Construction ------------------------------------------------------------

func _build_environment() -> void:
	StageKit.add_environment(self, {
		"mode": "color",
		"background": BACKGROUND_COLOR,
		"ambient_color": Color("8fa9b4"),
		"ambient_energy": 0.6,
		"fog": true,
		"fog_color": BACKGROUND_COLOR,
		"fog_density": 0.004,
	})
	StageKit.add_directional_light(self, "KeyLight", Color("f6dcae"), 1.7, Vector3(-52.0, 38.0, 0.0))
	StageKit.add_directional_light(self, "FillLight", Color("7fb6c8"), 0.45, Vector3(-26.0, -142.0, 0.0))


func _add_water() -> void:
	var overrides := {
		"shore_z": 100000.0,
		"shore_foam_width": 0.0,
		"boat_foam_width": 0.55,
		"horizon_fade_start": 90.0,
		"horizon_fade_end": 260.0,
	}
	var water := StageKit.add_water(self, StageKit.WATER_MATERIAL, 600.0, -0.05, overrides)
	_water_material = water.material_override as ShaderMaterial


func _add_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "StageCamera"
	_camera.fov = CAMERA_FOV
	_camera.near = 0.5
	_camera.far = 800.0
	_camera.current = true
	add_child(_camera)


# --- Ship visual -------------------------------------------------------------

func _apply_model() -> void:
	# Prefer the resolved visual plan (hull + rig kit + weapons). The legacy
	# path is kept for old ViewModels / saves without a `visual` block.
	var plan_value: Variant = _ship_view.get("visual", null)
	if plan_value is Dictionary:
		var plan: Dictionary = plan_value
		var hull_value: Variant = plan.get("hull", {})
		if hull_value is Dictionary:
			var hull_plan: Dictionary = hull_value
			if not String(hull_plan.get("model_path", "")).is_empty():
				_rebuild_ship_from_plan(plan)
				return
	# The shipyard view resolves the hull definition's `information.model` asset
	# key to a physical path inside the mounted content mod. The tier mapping is
	# only a fallback for dev builds that still carry PCK models.
	var path := String(_ship_view.get("hull_model_path", ""))
	if path.is_empty():
		path = _fallback_path_for_tier(int(_ship_view.get("hull_tier", 1)))
	_rebuild_ship(path)


func _fallback_path_for_tier(tier: int) -> String:
	var path := String(MODEL_BY_TIER.get(tier, MODEL_BY_TIER[1]))
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		return path
	return FALLBACK_MODEL


func _rebuild_ship_from_plan(plan: Dictionary) -> void:
	var signature := str(plan)
	if signature == _plan_signature and has_ship():
		return
	_plan_signature = signature
	_clear_ship_root()
	_ship_root = Node3D.new()
	_ship_root.name = "Ship"
	add_child(_ship_root)
	var result := ShipVisualAssembler.assemble(plan, _ship_root)
	var visual_value: Variant = result.get("visual", null)
	if not (visual_value is Node3D):
		# The planned hull could not be instantiated: fall back to the legacy
		# tier / prototype chain so the stage still shows a ship.
		_plan_signature = ""
		_assembly_report = {}
		_clear_ship_root()
		_rebuild_ship(_fallback_path_for_tier(int(_ship_view.get("hull_tier", 1))))
		return
	var visual: Node3D = visual_value
	var report_value: Variant = result.get("report", {})
	var report: Dictionary = report_value if report_value is Dictionary else {}
	_assembly_report = report
	_model_path = String(report.get("hull_path", ""))
	_frame_ship(visual)


func _rebuild_ship(path: String) -> void:
	if path == _model_path and has_ship():
		return
	_clear_ship_root()
	_ship_root = Node3D.new()
	_ship_root.name = "Ship"
	add_child(_ship_root)
	_model_path = path
	_plan_signature = ""
	_assembly_report = {}
	var visual := ContentAssetLoader.instantiate_model(path)
	if visual == null and ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		visual = packed.instantiate() as Node3D if packed != null else null
	if visual == null:
		return
	_ship_root.add_child(visual)
	_frame_ship(visual)


func _clear_ship_root() -> void:
	if _ship_root == null:
		return
	if _ship_root.get_parent() == self:
		remove_child(_ship_root)
	_ship_root.queue_free()
	_ship_root = null


func _frame_ship(visual: Node3D) -> void:
	var bounds := StageKit.visual_aabb(visual)
	StageKit.frame_camera(_camera, bounds, CAMERA_DIRECTION, CAMERA_FOV, FRAMING_MARGIN)
	StageKit.configure_boat_foam(_water_material, bounds)


func _process(delta: float) -> void:
	_time += delta
	if _ship_root == null or not is_visible_in_tree():
		return
	_ship_root.position.y = sin(_time * BOB_SPEED) * BOB_AMPLITUDE
	_ship_root.rotation.z = sin(_time * BOB_SPEED * 0.75) * 0.004
