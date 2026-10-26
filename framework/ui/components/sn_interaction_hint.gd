class_name SNInteractionHint
extends Control
## @static-doc
## 作用：框架级「交互处浮出提示」：把命令成功 / 失败的一句话反馈画在最后鼠标位置旁（皮肤底板 + 语义图标 + 短淡出），挂在 Shell 的页面滚动区之外，任意页面都能复用，顶部状态 banner 仍保留。
##
## Floating command feedback rendered at the interaction point
## (v0.2.0-dev.3 feedback #4: the old status banner sits at the top of the page,
## but the player interacts at the bottom and has to look up).
##
## The shell owns the message text (`_set_status` already receives a localized
## string) and only injects it here; the component has no localization dependency
## and no knowledge of ports / trades, so any page can call `show_at()`.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 底板取 `SNSkin.style("panel_steel")` 克隆，内容边距 10 / 6，成功
##   `modulate_color = brass.highlight`、失败 `state.danger`；语义图标取
##   `SNSkin.icon("action_confirm")` / `SNSkin.icon("status_warning")`，文字色取
##   `text.light`。不新增 `StyleBoxFlat`、不写十六进制色。
## - 根节点与全部子树 `mouse_filter = IGNORE`：提示绝不吞掉已落在光标下的点击
##   （点击落点放下 / 右键取消必须继续生效）。
##
## ## 契约与约束
## - `show_at(at, message, is_error)` 显示并重置淡出；`hide_hint()` 立即收起；
##   `is_showing()` / `current_message()` 供测试与调试断言。
## - `place_at(at)` 是纯函数：提示出现在指针上方（+14, -height-14），X/Y 都钳制在
##   视口内；960×540 与 1440×900 都不会露出视口或压到页面外。
## - 挂载点必须是页面滚动区之外的 Shell 浮层（`HintLayer`，在转场淡出层之下），
##   `PageScroll` 不会裁切它；本组件自身 `clip_contents = false`。
## - 淡出用 `create_tween()`（HOLD_SECONDS 后 FADE_SECONDS 淡到透明再隐藏）；
##   新消息会 kill 旧 tween 并重置 alpha，连续交互不会叠加计时。
## - 显示频率由 Shell 决定：只在 run 内的港口页面、由玩家交互触发的 `_set_status`
##   调用，菜单 / 演出期间不弹。
## @end-static-doc

const PANEL_STYLE_ID := "panel_steel"
const SUCCESS_TINT_TOKEN := "brass.highlight"
const ERROR_TINT_TOKEN := "state.danger"
const SUCCESS_ICON_ID := "action_confirm"
const ERROR_ICON_ID := "status_warning"
const CONTENT_MARGIN := Vector2(10.0, 6.0)
const POINTER_OFFSET := Vector2(14.0, 14.0)
const ICON_SIZE := 18.0
const MESSAGE_FONT_SIZE := 13
## How long the hint stays fully visible, then how long the fade-out takes.
const HOLD_SECONDS := 1.6
const FADE_SECONDS := 0.35

var _panel: PanelContainer = null
var _icon: TextureRect = null
var _message: Label = null
var _showing := false
var _current_message := ""
var _current_error := false
var _fade_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	visible = false
	_build()


## Shows `message` next to the given pointer position and (re)starts the fade.
func show_at(at: Vector2, message: String, is_error: bool) -> void:
	if message.is_empty():
		hide_hint()
		return
	_build()
	_current_message = message
	_current_error = is_error
	_message.text = message
	_apply_tone(is_error)
	_showing = true
	modulate.a = 1.0
	visible = true
	_sync_bounds()
	position = place_at(at)
	_restart_fade()


## Hides immediately (page change / quit teardown).
func hide_hint() -> void:
	_showing = false
	visible = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func is_showing() -> bool:
	return _showing


func current_message() -> String:
	return _current_message


func current_error() -> bool:
	return _current_error


## Clamped top-left position for a pointer position: above the cursor, fully inside
## the viewport. Pure (no mouse read) so tests assert it deterministically.
func place_at(at: Vector2) -> Vector2:
	var bounds := _min_size()
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	var placed := at + Vector2(POINTER_OFFSET.x, -bounds.y - POINTER_OFFSET.y)
	if viewport_size.x > 0.0:
		placed.x = clampf(placed.x, 0.0, maxf(0.0, viewport_size.x - bounds.x))
	if viewport_size.y > 0.0:
		placed.y = clampf(placed.y, 0.0, maxf(0.0, viewport_size.y - bounds.y))
	return placed


func _restart_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	if not is_inside_tree():
		return
	_fade_tween = create_tween()
	_fade_tween.tween_interval(HOLD_SECONDS)
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_fade_tween.tween_callback(_on_faded)


func _on_faded() -> void:
	_showing = false
	visible = false


func _apply_tone(is_error: bool) -> void:
	_icon.texture = SNSkin.icon(ERROR_ICON_ID if is_error else SUCCESS_ICON_ID)
	if _panel == null:
		return
	var base_style: StyleBoxTexture = SNSkin.style(PANEL_STYLE_ID)
	if base_style == null:
		_panel.theme_type_variation = &"SNInsetPanel"
		return
	var style := base_style.duplicate() as StyleBoxTexture
	style.content_margin_left = CONTENT_MARGIN.x
	style.content_margin_top = CONTENT_MARGIN.y
	style.content_margin_right = CONTENT_MARGIN.x
	style.content_margin_bottom = CONTENT_MARGIN.y
	style.modulate_color = SNSkin.color(ERROR_TINT_TOKEN if is_error else SUCCESS_TINT_TOKEN)
	_panel.add_theme_stylebox_override("panel", style)


func _build() -> void:
	if _panel != null:
		return
	_panel = PanelContainer.new()
	_panel.name = "HintPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var row := HBoxContainer.new()
	row.name = "HintRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_panel.add_child(row)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	_message = Label.new()
	_message.name = "Message"
	_message.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	_message.add_theme_color_override("font_color", SNSkin.color("text.light"))
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.autowrap_mode = TextServer.AUTOWRAP_OFF
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_message)
	_apply_tone(false)
	_sync_bounds()


## The hint is parented to a plain Control overlay (no container layout), so it
## keeps itself exactly as large as its skin panel.
func _sync_bounds() -> void:
	if _panel == null:
		return
	var min_size := _panel.get_combined_minimum_size()
	_panel.position = Vector2.ZERO
	_panel.size = min_size
	custom_minimum_size = min_size
	if size != min_size:
		size = min_size


func _min_size() -> Vector2:
	return _panel.get_combined_minimum_size() if _panel != null else Vector2.ZERO
