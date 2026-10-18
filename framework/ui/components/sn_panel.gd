@tool
class_name SNPanel
extends PanelContainer
## Framed surface matching the shared Theme panel variants.

enum Variant { BASE, ELEVATED, INSET }

@export var variant: Variant = Variant.BASE:
	set(value):
		variant = value
		_apply_variant()


func _ready() -> void:
	_apply_variant()


func _apply_variant() -> void:
	var variations: Array[StringName] = [&"SNPanel", &"SNElevatedPanel", &"SNInsetPanel"]
	theme_type_variation = variations[int(variant)]
