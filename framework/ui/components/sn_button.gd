@tool
class_name SNButton
extends Button
## @static-doc
## 作用：可复用语义按钮：在 Inspector 中选择主操作、次操作、危险或幽灵样式，并可挂一枚皮肤图标；外观全部来自外部贴图驱动的 Theme variation，代码不写颜色与 StyleBox。
##
## - 关键依赖：`assets/ui/theme/steam_navigator_theme.tres` 的 `SNPrimaryButton` / `SNSecondaryButton` / `SNDangerButton` / `SNGhostButton` / `SNCompactButton`；`SNSkin.icon(id)` 取图标。
##
## ## 契约与约束
## - `variant`（PRIMARY/SECONDARY/DANGER/GHOST）与 `compact` 是既有公开 API，枚举顺序与含义不变。
## - `compact=true` 使用 `SNCompactButton` 小铭牌纹理，最小高度约 31 px；非 compact 保持 44 px。
## - `icon_id` 可选：非空时把 `SNSkin.icon(icon_id)` 赋给 `Button.icon` 并统一 `icon_max_width=20`；空串只清理由 icon_id 设置的图标，不覆盖外部直接赋值的 `Button.icon`。不新增包装容器，文字/节点结构不变，现有调用无需改动。
## - 图标缺失（皮肤未就绪）时保留无图标按钮，不报错。
## - 不做尺寸位移/动画；hover/pressed/focus 由 Theme 状态样式负责。
##
## ## 用法
## ```gdscript
## var button := SNButton.new()
## button.variant = SNButton.Variant.PRIMARY
## button.icon_id = "action_confirm"
## button.text = "确认"
## ```
## @end-static-doc

enum Variant { PRIMARY, SECONDARY, DANGER, GHOST }

const ICON_MAX_WIDTH := 20
const HEIGHT_DEFAULT := 44.0
const HEIGHT_COMPACT := 31.0

@export var variant: Variant = Variant.SECONDARY:
	set(value):
		variant = value
		_apply_variant()

@export var compact: bool = false:
	set(value):
		compact = value
		_apply_variant()
		_apply_size()

## Optional skin icon id (`SNSkin.icon(id)`); empty keeps the text-only button.
@export var icon_id: String = "":
	set(value):
		icon_id = value
		_apply_icon()

## True while `icon` was assigned from `icon_id`; lets an empty id clear only our own icon
## instead of clobbering a texture an external caller assigned to `Button.icon`.
var _icon_from_id := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_variant()
	_apply_size()
	_apply_icon()


func _apply_variant() -> void:
	var variations: Array[StringName] = [
		&"SNPrimaryButton", &"SNSecondaryButton", &"SNDangerButton", &"SNGhostButton",
	]
	theme_type_variation = &"SNCompactButton" if compact else variations[int(variant)]


func _apply_size() -> void:
	custom_minimum_size.y = HEIGHT_COMPACT if compact else HEIGHT_DEFAULT
	if compact:
		add_theme_font_size_override("font_size", 12)
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
