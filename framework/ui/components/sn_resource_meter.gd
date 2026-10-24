@tool
class_name SNResourceMeter
extends VBoxContainer
## @static-doc
## 作用：煤水、耐久与载重共用的标签化资源存量条：无上限损失时用纹理化 Theme ProgressBar，有损失时自绘三段式条（已用 / 空余 / 右缘损失带），两套画法都取同一套皮肤纹理。
##
## - 关键依赖：`assets/ui/theme/steam_navigator_theme.tres` 的 `SNBrassProgressBar` / `SNWaterProgressBar` / `SNDangerProgressBar`；`SNSkin.style("meter_trough"/"meter_fill_amber"/"meter_fill_aqua"/"meter_fill_rust")`；`SNSkin.color(token)`。
##
## ## 契约与约束
## - 当前值显示在 [0, maximum]；`maximum_value` 下限 0.1，避免无效 ProgressBar 范围。
## - `tone` 只切换 Theme variation 与填充纹理（黄铜 / 水青 / 锈红），名称、数值、单位与安全提示保持同一信息结构。
## - `loss_value <= 0` 时继续使用主题 ProgressBar（耐久 / 载重路径不变）；`loss_value > 0` 时切换到自绘三段条：
##   填充 `[0, current]`、空余 `[current, maximum]`、贴右边缘的损失带 `[maximum, maximum + loss]`。
## - 条的总跨度为 `maximum + loss`，因此上限缩水（maximum 降、loss 升）时填充比例恒定不上升；
##   几何由静态纯函数 `loss_bar_segments()` 计算，绘制与测试共用同一来源。
## - `BAR_HEIGHT = 14`、节点名（Header/Name、Header/Value、Progress、LossBar、Hint）与既有信号/文案格式保持不变。
## - 绘制只用 `draw_style_box` + 皮肤纹理；皮肤缺失时才退回 token 颜色，不写十六进制色值，也不新建 StyleBoxFlat。
##
## ## 用法
## ```gdscript
## var meter := SNResourceMeter.new()
## meter.label_text = "淡水"
## meter.current_value = 39.0
## meter.maximum_value = 50.0
## meter.tone = SNResourceMeter.Tone.WATER
## meter.loss_value = 10.0   # 显示右缘损失带
## ```
## @end-static-doc

enum Tone { BRASS, WATER, DANGER }

const BAR_HEIGHT := 14.0

## Texture style ids per tone; order must match `Tone`.
const FILL_STYLE_IDS: Array[String] = [
	"meter_fill_amber", "meter_fill_aqua", "meter_fill_rust",
]
## Fallback color tokens per tone, used only when the skin manifest is unavailable.
const FILL_COLOR_TOKENS: Array[String] = [
	"brass.base", "state.water", "state.danger",
]
const TROUGH_STYLE_ID := "meter_trough"
const TROUGH_FALLBACK_TOKEN := "steel.recess"
const BORDER_FALLBACK_TOKEN := "brass.shadow"
const VALUE_COLOR_TOKEN := "brass.highlight"
const HINT_COLOR_TOKEN := "text.muted"
const LOSS_ALPHA := 0.45

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
var _fill_style: StyleBox
var _loss_style: StyleBox
var _loss_style_tone: int = -1


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
	_value_label.add_theme_color_override("font_color", SNSkin.color(VALUE_COLOR_TOKEN))
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
	_hint_label.add_theme_color_override("font_color", SNSkin.color(HINT_COLOR_TOKEN))
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
	var tone_index := clampi(int(tone), 0, variations.size() - 1)
	_progress.theme_type_variation = variations[tone_index]
	_fill_style = SNSkin.style(FILL_STYLE_IDS[tone_index])
	if _loss_style_tone != tone_index:
		_loss_style = null
		_loss_style_tone = tone_index
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


## The three segments use the same skin textures as the themed ProgressBar:
## trough for the empty span, tone fill for [0, current], semi-transparent rust
## for the right-edge loss band.
func _on_loss_bar_draw() -> void:
	if _loss_bar == null or not _loss_bar.visible:
		return
	var bar_size := _loss_bar.size
	if bar_size.x <= 0.0 or bar_size.y <= 0.0:
		return
	var full_rect := Rect2(Vector2.ZERO, bar_size)
	var segments := loss_bar_segments(bar_size.x, current_value, maximum_value, loss_value)
	var trough := SNSkin.style(TROUGH_STYLE_ID)
	if trough != null:
		_loss_bar.draw_style_box(trough, full_rect)
	else:
		_loss_bar.draw_rect(full_rect, SNSkin.color(TROUGH_FALLBACK_TOKEN))
	var fill_end := float(segments["fill_end"])
	if fill_end > 0.0:
		var fill_rect := Rect2(0.0, 0.0, fill_end, bar_size.y)
		if _fill_style != null:
			_loss_bar.draw_style_box(_fill_style, fill_rect)
		else:
			_loss_bar.draw_rect(fill_rect, _fill_color())
	var loss_start := float(segments["loss_start"])
	var loss_width := bar_size.x - loss_start
	if loss_width > 0.0:
		var loss_rect := Rect2(loss_start, 0.0, loss_width, bar_size.y)
		var loss_style := _loss_style_box()
		if loss_style != null:
			_loss_bar.draw_style_box(loss_style, loss_rect)
		else:
			_loss_bar.draw_rect(loss_rect, _loss_color())
	if trough == null:
		_loss_bar.draw_rect(full_rect, SNSkin.color(BORDER_FALLBACK_TOKEN), false, 1.0)


## Rust fill reused for every tone's loss band; non-danger tones dim it so the
## band reads as "unreachable capacity" rather than damage.
func _loss_style_box() -> StyleBox:
	if _loss_style != null:
		return _loss_style
	var source := SNSkin.style(FILL_STYLE_IDS[Tone.DANGER])
	if source == null:
		return null
	var clone := source.duplicate() as StyleBoxTexture
	if clone == null:
		return null
	if tone != Tone.DANGER:
		clone.modulate_color.a = LOSS_ALPHA
	_loss_style = clone
	return _loss_style


func _fill_color() -> Color:
	return SNSkin.color(FILL_COLOR_TOKENS[clampi(int(tone), 0, FILL_COLOR_TOKENS.size() - 1)])


func _loss_color() -> Color:
	var color := SNSkin.color(FILL_COLOR_TOKENS[Tone.DANGER])
	if tone != Tone.DANGER:
		color.a = LOSS_ALPHA
	return color


func _format_number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
