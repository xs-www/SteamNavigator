@tool
class_name SNResourceMeter
extends VBoxContainer
## Labeled resource meter used for coal, water, durability, and cargo capacity.
##
## With loss_value <= 0 the meter renders the themed ProgressBar exactly as before.
## With loss_value > 0 it draws three segments itself: used [0, current],
## free [current, maximum] and the cap-loss band pinned to the right edge, so the
## fill ratio stays stable while the reachable limit shrinks.

enum Tone { BRASS, WATER, DANGER }

## Colors mirror assets/ui/theme/steam_navigator_theme.tres; the theme file stays untouched.
const COLOR_BRASS := Color("e1c487")
const COLOR_WATER := Color("76aaa7")
const COLOR_DANGER := Color("c36b53")
const COLOR_TRACK := Color(0.027451, 0.101961, 0.113725, 1.0)
const COLOR_TRACK_BORDER := Color(0.772549, 0.603922, 0.329412, 0.22)
const COLOR_CAP_LOSS := Color(0.62, 0.69, 0.65, 0.35)
const COLOR_CAP_LOSS_DANGER := Color(0.764706, 0.419608, 0.32549, 0.5)
const BAR_HEIGHT := 14.0

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

## Reachable limit lost to the other tank; 0 keeps the legacy themed ProgressBar.
@export_range(0.0, 100000.0, 0.1) var loss_value: float = 0.0:
	set(value):
		loss_value = maxf(0.0, value)
		_sync()

## Optional localized explanation appended to hint while a loss band is shown.
@export var loss_hint_text: String = "":
	set(value):
		loss_hint_text = value
		_sync()

var _name_label: Label
var _value_label: Label
var _progress: ProgressBar
var _loss_bar: Control
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
		_loss_bar = get_node_or_null("LossBar") as Control
		if _loss_bar == null:
			_loss_bar = _build_loss_bar()
		elif not _loss_bar.draw.is_connected(_on_loss_bar_draw):
			_loss_bar.draw.connect(_on_loss_bar_draw)
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
	_progress.custom_minimum_size.y = BAR_HEIGHT
	_progress.show_percentage = false
	add_child(_progress)
	_loss_bar = _build_loss_bar()
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.add_theme_color_override("font_color", Color("9fafa7"))
	_hint_label.add_theme_font_size_override("font_size", 10)
	add_child(_hint_label)


func _build_loss_bar() -> Control:
	var bar := Control.new()
	bar.name = "LossBar"
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.visible = false
	bar.draw.connect(_on_loss_bar_draw)
	add_child(bar)
	return bar


func _sync() -> void:
	_build_once()
	_name_label.text = label_text
	_value_label.text = "%s / %s %s" % [_format_number(current_value), _format_number(maximum_value), suffix]
	var has_loss := loss_value > 0.0
	_progress.visible = not has_loss
	_loss_bar.visible = has_loss
	if has_loss and is_inside_tree():
		_loss_bar.queue_redraw()
	_progress.max_value = maximum_value
	_progress.value = clampf(current_value, 0.0, maximum_value)
	var variations: Array[StringName] = [
		&"SNBrassProgressBar", &"SNWaterProgressBar", &"SNDangerProgressBar",
	]
	_progress.theme_type_variation = variations[int(tone)]
	_hint_label.text = hint
	if has_loss:
		var loss_text := loss_hint_text if not loss_hint_text.is_empty() else "上限损失 %s" % _format_number(loss_value)
		_hint_label.text = "%s · %s" % [hint, loss_text] if not hint.is_empty() else loss_text
	_hint_label.visible = not _hint_label.text.is_empty()


## Segment layout of the three-part bar for the given pixel width:
## {span, fill_end, empty_end, loss_start, loss_end}. The loss band is pinned to
## the right edge and its width is proportional to loss, so shrinking the
## reachable limit never inflates the fill ratio.
static func loss_bar_segments(width: float, current: float, maximum: float, loss: float) -> Dictionary:
	var span := maxf(maxf(maximum + loss, current), 0.1)
	var scale := maxf(0.0, width) / span
	var fill_end := clampf(current, 0.0, span) * scale
	var loss_width := clampf(loss, 0.0, span) * scale
	var loss_start := maxf(0.0, width - loss_width)
	return {
		"span": span,
		"fill_end": fill_end,
		"empty_end": maxf(fill_end, loss_start),
		"loss_start": loss_start,
		"loss_end": maxf(0.0, width),
	}


func _on_loss_bar_draw() -> void:
	if _loss_bar == null or not _loss_bar.visible:
		return
	var bar_size := _loss_bar.size
	if bar_size.x <= 0.0 or bar_size.y <= 0.0:
		return
	var segments := loss_bar_segments(bar_size.x, current_value, maximum_value, loss_value)
	_loss_bar.draw_rect(Rect2(Vector2.ZERO, bar_size), COLOR_TRACK)
	var fill_end := float(segments["fill_end"])
	if fill_end > 0.0:
		_loss_bar.draw_rect(Rect2(0.0, 0.0, fill_end, bar_size.y), _fill_color())
	var loss_start := float(segments["loss_start"])
	if bar_size.x - loss_start > 0.0:
		_loss_bar.draw_rect(Rect2(loss_start, 0.0, bar_size.x - loss_start, bar_size.y), _loss_color())
	_loss_bar.draw_rect(Rect2(Vector2.ZERO, bar_size), COLOR_TRACK_BORDER, false, 1.0)


func _fill_color() -> Color:
	match tone:
		Tone.WATER:
			return COLOR_WATER
		Tone.DANGER:
			return COLOR_DANGER
		_:
			return COLOR_BRASS


func _loss_color() -> Color:
	return COLOR_CAP_LOSS_DANGER if tone == Tone.DANGER else COLOR_CAP_LOSS


func _format_number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
