@tool
class_name SNBadge
extends Label
## Compact status tag for neutral, success, warning, and danger states.

enum Tone { NEUTRAL, SUCCESS, WARNING, DANGER }

@export var tone: Tone = Tone.NEUTRAL:
	set(value):
		tone = value
		_apply_tone()


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_tone()


func _apply_tone() -> void:
	var variations: Array[StringName] = [
		&"SNBadge", &"SNSuccessBadge", &"SNWarningBadge", &"SNDangerBadge",
	]
	theme_type_variation = variations[int(tone)]
