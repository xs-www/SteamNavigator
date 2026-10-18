@tool
class_name SNButton
extends Button
## Steam Navigator themed button with Inspector-selectable semantic variants.

enum Variant { PRIMARY, SECONDARY, DANGER, GHOST }

@export var variant: Variant = Variant.SECONDARY:
	set(value):
		variant = value
		_apply_variant()

@export var compact: bool = false:
	set(value):
		compact = value
		_apply_size()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_variant()
	_apply_size()


func _apply_variant() -> void:
	var variations: Array[StringName] = [
		&"SNPrimaryButton", &"SNSecondaryButton", &"SNDangerButton", &"SNGhostButton",
	]
	theme_type_variation = variations[int(variant)]


func _apply_size() -> void:
	custom_minimum_size.y = 34.0 if compact else 44.0
	if compact:
		add_theme_font_size_override("font_size", 12)
	else:
		remove_theme_font_size_override("font_size")
