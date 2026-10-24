@tool
class_name SNNavButton
extends Button
## @static-doc
## 作用：主导航 / 侧牌用的图标导航按钮：皮肤图标 + 原样文字，`active` 表达当前页选中态，`primary` / `compact` 选择黄铜主操作或小铭牌语义；外观全部来自 Theme variation。
##
## - 关键依赖：`assets/ui/theme/steam_navigator_theme.tres` 的 `SNPrimaryButton` / `SNGhostButton` / `SNCompactButton`；`SNSkin.icon(id)`。
##
## ## 契约与约束
## - 只负责外观与图标：`text` 原样保留，绝不改写文本、信号、`pressed`/`toggle_mode` 语义；导航命令仍由 Shell 决定。
## - 变体优先级：`active` 或 `primary` → `SNPrimaryButton`（选中黄铜铭牌），否则 `compact` → `SNCompactButton`，否则 `SNGhostButton`。
## - 不强制 `custom_minimum_size`：尺寸由 Shell 布局决定（当前主导航 64×36，侧牌 172×42），避免替换后产生布局位移。
## - `compact` 时字号 13（与 Shell 既有导航一致）；非 compact 交给 Theme 默认字号。
## - 图标缺失（皮肤未就绪）时保持纯文字按钮可用；`icon_max_width = 18` 防止图标挤占文字。
## - 本控件不依赖 Shell；Shell 是否迁移到它由 Shell 任务决定，本任务只在 showcase 中演示。
##
## ## 用法
## ```gdscript
## var nav := SNNavButton.new()
## nav.icon_id = "nav_market"
## nav.text = "市场"
## nav.compact = true
## nav.active = true
## ```
## @end-static-doc

const ICON_MAX_WIDTH := 18
const COMPACT_FONT_SIZE := 13

## Skin icon id shown before the text.
@export var icon_id: String = "":
	set(value):
		icon_id = value
		_apply_icon()

## Current-page state: uses the brass primary plate as the selected look.
@export var active: bool = false:
	set(value):
		active = value
		_apply_variant()

## Primary semantic for a non-active high-emphasis nav entry.
@export var primary: bool = false:
	set(value):
		primary = value
		_apply_variant()

## Small-plate nav / side-sign sizing.
@export var compact: bool = false:
	set(value):
		compact = value
		_apply_variant()
		_apply_font_size()

var _icon_from_id := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_variant()
	_apply_font_size()
	_apply_icon()


func _apply_variant() -> void:
	if active or primary:
		theme_type_variation = &"SNPrimaryButton"
	elif compact:
		theme_type_variation = &"SNCompactButton"
	else:
		theme_type_variation = &"SNGhostButton"


func _apply_font_size() -> void:
	if compact:
		add_theme_font_size_override("font_size", COMPACT_FONT_SIZE)
	else:
		remove_theme_font_size_override("font_size")


func _apply_icon() -> void:
	if icon_id.is_empty():
		if _icon_from_id:
			icon = null
			_icon_from_id = false
		remove_theme_constant_override("icon_max_width")
		return
	var texture := SNSkin.icon(icon_id)
	_icon_from_id = true
	icon = texture
	if texture != null:
		add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	else:
		remove_theme_constant_override("icon_max_width")
