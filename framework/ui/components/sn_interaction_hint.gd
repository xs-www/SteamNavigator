class_name SNInteractionHint
extends Control
## @static-doc
## 作用：框架级「交互处浮出提示」：把命令成功 / 失败的一句话反馈画在最后鼠标位置旁（皮肤底板 + 语义图标 + 短淡出），挂在 Shell 的页面滚动区之外，任意页面都能复用，顶部状态 banner 仍保留。
##
## ## 场景化（P0，见 docs/specs/UI_SCENE_MIGRATION.md）
## 静态骨架在 `sn_interaction_hint.tscn`：根 `Control` 挂本脚本（`visible = false`、
## `mouse_filter = IGNORE`、根节点引用 `steam_navigator_theme.tres`），子树为
## `HintPanel(PanelContainer, IGNORE) → HintRow(HBoxContainer, separation 6, IGNORE) →
## Icon(TextureRect, 18×18, expand_mode=1, stretch_mode=5, IGNORE) +
## Message(Label, font_size 13, autowrap_mode=0, text_overrun_behavior=3, IGNORE)`。
## 层级、尺寸、间距、字号、`mouse_filter`、初始隐藏都是设计常量，只写在场景里。
##
## **实例化契约（R1）**：调用方必须
## `preload("res://framework/ui/components/sn_interaction_hint.tscn").instantiate()`，
## 禁止 `SNInteractionHint.new()`——脚本 `.new()` 没有场景子树，`_ensure_refs()` 全部解析
## 为空，提示会静默空白；节点名 `HintPanel` / `HintRow` / `Icon` / `Message` 是测试与
## Shell 的查找契约（R2），不要改名。脚本只做延迟解析（`_ensure_refs()`）、动态色调、
## `_sync_bounds()`、`place_at()` 与淡出 Tween，允许在未进树时先 `show_at()`（R3）。
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
##   `text.light`。不新增 `StyleBoxFlat`、不写十六进制色（场景里也不写颜色值，R4）。
## - 根节点与全部子树 `mouse_filter = IGNORE`：提示绝不吞掉已落在光标下的点击
##   （点击落点放下 / 右键取消必须继续生效）。
##
## ## 契约与约束
## - `show_at(at, message, is_error)` 显示并重置淡出；`hide_hint()` 立即收起；
##   `is_showing()` / `current_message()` 供测试与调试断言。
## - 消息宽度由脚本实测（`MAX_TEXT_WIDTH` = 520）：Godot 4.7 的 Label 在
##   `OVERRUN_TRIM_ELLIPSIS` 下最小宽度只报 1 px，若直接交给容器排版，面板会塌缩成
##   图标宽度、文字只剩省略号。`show_at()` 用主题字体量出文本宽度并写入
##   `Message.custom_minimum_size.x`（上限 520），所以短消息完整可读、超长消息到
##   520 px 才用省略号截断；场景里的 `text_overrun_behavior = 3` 保持不变。
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
## Upper bound for the measured message width. `OVERRUN_TRIM_ELLIPSIS` reports a
## 1 px Label minimum, so the panel would otherwise collapse to the icon width;
## the hint measures its own text and only ellipsizes past this cap.
const MAX_TEXT_WIDTH := 520.0
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
var _text_colors_applied := false


func _ready() -> void:
	# 场景根节点已经带上这些属性；保留兜底，调用方即使手工装配也不会改变契约。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	visible = false
	_ensure_refs()
	_apply_text_colors()
	_apply_tone(false)
	_sync_bounds()


## Resolves the scene subtree by name. Safe before `add_child()` / `_ready()`: the
## instantiated scene already owns these children, so `get_node_or_null` works even
## when the control is not in the tree yet (R3).
func _ensure_refs() -> void:
	if _panel == null:
		_panel = get_node_or_null("HintPanel") as PanelContainer
	if _icon == null:
		_icon = get_node_or_null("HintPanel/HintRow/Icon") as TextureRect
	if _message == null:
		_message = get_node_or_null("HintPanel/HintRow/Message") as Label


## 文字色是 `SNSkin` token，只由脚本写入（场景不复制颜色值，R4）；只应用一次。
func _apply_text_colors() -> void:
	if _text_colors_applied:
		return
	_text_colors_applied = true
	if _message != null:
		_message.add_theme_color_override("font_color", SNSkin.color("text.light"))


## Shows `message` next to the given pointer position and (re)starts the fade.
func show_at(at: Vector2, message: String, is_error: bool) -> void:
	if message.is_empty():
		hide_hint()
		return
	_ensure_refs()
	_apply_text_colors()
	_current_message = message
	_current_error = is_error
	if _message != null:
		_message.text = message
	_fit_message_width(message)
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


## `OVERRUN_TRIM_ELLIPSIS` caps a Label's reported minimum width at 1 px, so a
## container-sized panel would collapse onto the icon (45 px in a 1440×900 window).
## Measure the rendered text with the theme font instead and give the Label that
## minimum width, capped at `MAX_TEXT_WIDTH` so long messages ellipsize predictably.
func _fit_message_width(message: String) -> void:
	if _message == null:
		return
	var font := _message.get_theme_font("font")
	if font == null:
		return
	var font_size := _message.get_theme_font_size("font_size")
	var measured := font.get_string_size(
		message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	_message.custom_minimum_size.x = minf(measured.x, MAX_TEXT_WIDTH)


## Success / failure tone: semantic icon + a cloned `panel_steel` stylebox tinted
## brass / danger with fixed 10 / 6 content margins. Never mutates the cached skin box.
func _apply_tone(is_error: bool) -> void:
	if _icon != null:
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
