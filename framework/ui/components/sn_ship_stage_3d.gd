class_name SNShipStage3D
extends SNStageHost
## Adapter that plugs the generic 3D stage host into the shipyard's existing
## `SNShipView.set_renderer()` contract:
##   ship_view_update(model)     — forward the ship ViewModel to ShipyardStage
##   ship_view_set_mode(mode)    — EXTERIOR shows the 3D stage, CUTAWAY hides it
##   ship_view_highlight(ids)    — reserved for part highlighting, currently a no-op
##
## `SNStageHost` owns the viewport/world/lifecycle; `ShipyardStage` owns the
## camera, lights, water and hull. This node stays a thin Control so the 2D slot
## chips, drag & drop and HUD in `SNShipView` keep working unchanged.
##
## The node owns only presentation: it never reads GameState, QueryBus or
## CommandBus. When no ship GLB is available the shipyard simply keeps
## `SNShipView`'s procedural placeholder (no empty viewport is mounted).

const SHIPYARD_STAGE_SCENE := "res://framework/ui/stages/shipyard_stage.tscn"
const MODEL_BY_TIER := {
	1: "res://assets/models/ships/SN_Paddle_Steamer.glb",
	2: "res://assets/models/ships/SN_Paddle_Freighter.glb",
	3: "res://assets/models/ships/SN_Ironclad.glb",
}
const FALLBACK_MODEL := "res://assets/models/ships/SN_Ship_Prototype.glb"

var _pending_model: Dictionary = {}
var _pending_mode := SNShipView.Mode.EXTERIOR
var _highlighted_slots: Array = []


## True when a fallback ship GLB is available locally (dev/PCK). Normally the
## shipyard resolves the hull's own mod asset (`hull_model_path`) instead.
static func is_supported() -> bool:
	for path in MODEL_BY_TIER.values():
		if FileAccess.file_exists(String(path)) or ResourceLoader.exists(String(path)):
			return true
	return FileAccess.file_exists(FALLBACK_MODEL) or ResourceLoader.exists(FALLBACK_MODEL)


func _ready() -> void:
	super._ready()
	load_stage(SHIPYARD_STAGE_SCENE)
	set_stage_visible(_pending_mode == SNShipView.Mode.EXTERIOR)
	_apply_pending_model()
	set_process(true)


## True once a ship GLB instance is mounted inside the stage.
func has_ship() -> bool:
	var stage := current_stage()
	return stage != null and stage.has_method("has_ship") and bool(stage.has_ship())


func model_path() -> String:
	var stage := current_stage()
	return String(stage.model_path()) if stage != null and stage.has_method("model_path") else ""


# --- SNShipView renderer contract -------------------------------------------

func ship_view_update(model: Dictionary) -> void:
	_pending_model = model.duplicate(true)
	_apply_pending_model()


func ship_view_set_mode(mode: int) -> void:
	_pending_mode = mode
	set_stage_visible(mode == SNShipView.Mode.EXTERIOR)


func ship_view_highlight(slot_ids: Array) -> void:
	_highlighted_slots = slot_ids.duplicate()
	# Highlighting parts on the 3D hull is part of the next stage slice.
	var stage := current_stage()
	if stage != null and stage.has_method("ship_view_highlight"):
		stage.ship_view_highlight(_highlighted_slots)


func _apply_pending_model() -> void:
	var stage := current_stage()
	if stage == null or not stage.has_method("bind"):
		return
	stage.bind({"ship": _pending_model.duplicate(true)})
