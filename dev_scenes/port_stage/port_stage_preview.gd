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
