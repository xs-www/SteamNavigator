@tool
class_name SNResourceMeter
extends VBoxContainer
## Labeled resource meter used for coal, water, durability, and cargo capacity.

enum Tone { BRASS, WATER, DANGER }

@export var label_text: String = "煤炭":
	set(value):
		label_text = value
		_sync()

@export_range(0.0, 100000.0, 0.1) var current_value: float = 31.0:
	set(value):
		current_value = value
		_sync()

@export_range(0.1, 100000.0, 0.1) var maximum_value: float = 50.0:
	set(value):
		maximum_value = maxf(value, 0.1)
		_sync()

@export var suffix: String = "单位":
	set(value):
		suffix = value
		_sync()

@export var hint: String = "安全线 20":
	set(value):
		hint = value
		_sync()

@export var tone: Tone = Tone.BRASS:
	set(value):
		tone = value
		_sync()

var _name_label: Label
var _value_label: Label
var _progress: ProgressBar
var _hint_label: Label


func _ready() -> void:
	_build_once()
	_sync()


func _build_once() -> void:
	if get_node_or_null("Header") != null:
		_name_label = get_node("Header/Name") as Label
		_value_label = get_node("Header/Value") as Label
		_progress = get_node("Progress") as ProgressBar
		_hint_label = get_node("Hint") as Label
		return
	add_theme_constant_override("separation", 7)
	var header := HBoxContainer.new()
	header.name = "Header"
	add_child(header)
	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 13)
	header.add_child(_name_label)
	_value_label = Label.new()
	_value_label.name = "Value"
	_value_label.add_theme_color_override("font_color", Color("e1c487"))
	_value_label.add_theme_font_size_override("font_size", 13)
	header.add_child(_value_label)
	_progress = ProgressBar.new()
	_progress.name = "Progress"
	_progress.custom_minimum_size.y = 14
	_progress.show_percentage = false
	add_child(_progress)
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.add_theme_color_override("font_color", Color("9fafa7"))
	_hint_label.add_theme_font_size_override("font_size", 10)
	add_child(_hint_label)


func _sync() -> void:
	if not is_inside_tree():
		return
	_build_once()
	_name_label.text = label_text
	_value_label.text = "%s / %s %s" % [_format_number(current_value), _format_number(maximum_value), suffix]
	_progress.max_value = maximum_value
	_progress.value = clampf(current_value, 0.0, maximum_value)
	var variations: Array[StringName] = [
		&"SNBrassProgressBar", &"SNWaterProgressBar", &"SNDangerProgressBar",
	]
	_progress.theme_type_variation = variations[int(tone)]
	_hint_label.text = hint
	_hint_label.visible = not hint.is_empty()


func _format_number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
