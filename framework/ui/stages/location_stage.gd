class_name LocationStage
extends Node3D
## Contract for one 2.5D fixed-camera stage mounted by `SNStageHost`.
##
## A stage owns its content: camera, lights, environment, water, props and the
## local idle animation. It is presentation only — `bind()` reads a resolved
## ViewModel and never touches GameState, QueryBus or CommandBus.
##
## Lifecycle, driven by the host:
##   enter(payload)   stage switched in  — start local animation, apply payload
##   bind(view_model) refresh from application data (safe to call repeatedly)
##   exit()           stage switched out — stop local animation, drop local state
##
## `portal_requested` only expresses player intent (e.g. "open the market"); the
## host re-emits it and the UI Shell / a future StageDirector decides where to
## navigate. 2D hotspots stay in the page: they can use `hotspot_anchors()` and
## project those world points with the stage camera instead of doing 3D raycasts.

signal portal_requested(target_id: String)

## Stable id used by stage switching (`shipyard`, `port`, …). The scene usually
## overrides the export; the host falls back to the node name when it is empty.
@export var stage_id: String = ""


func enter(_payload: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func bind(_view_model: Dictionary = {}) -> void:
	pass


## True when the stage has something usable to draw. Hosts/pages use this to
## decide whether to fall back to the 2D banner. Procedural stages return true
## even when optional content assets are missing.
func has_visual() -> bool:
	return true


## World-space anchors for 2D hotspots, keyed by facility / portal id. World
## space keeps pages free of stage internals; they project these points with the
## stage camera while laying out their Control hotspots.
func hotspot_anchors() -> Dictionary:
	return {}
