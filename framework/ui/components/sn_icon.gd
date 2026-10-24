@tool
class_name SNIcon
extends TextureRect
## @static-doc
## 作用：皮肤图标控件：按 `SNSkin` 的 icon id 显示外部贴图图标（导航 / 资源 / 船厂 / 状态 / 行动），供程序化 UI 与展示场景复用，不在页面里拼贴图路径。
##
## - 关键依赖：`SNSkin.icon(id)`；图标清单见 `assets/ui/skin/sn_v1/skin.json` 的 `icons`。
##
## ## 契约与约束
## - `icon_id` 为空或皮肤缺图时隐藏自身，不 push_error、不阻断页面布局。
## - 纹理设置与 `SNSkin.icon_rect(id, size)` 完全一致：`EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`，
##   `custom_minimum_size = (logical_size, logical_size)`，不吃鼠标、垂直居中。
## - `logical_size` 是逻辑像素边长（默认 24），与 0.5× 导入的 128×128 源图标解耦；改外部贴图不需要改调用方。
##
## ## 用法
## ```gdscript
## var icon := SNIcon.new()
## icon.icon_id = "nav_market"
## icon.logical_size = 24.0
## row.add_child(icon)
## ```
## @end-static-doc

## Skin icon id; empty hides the control.
@export var icon_id: String = "":
	set(value):
		icon_id = value
		_apply()

## Logical edge length in UI pixels (icons are authored at 2× and imported at 0.5×).
@export_range(8.0, 64.0, 1.0) var logical_size: float = 24.0:
	set(value):
		logical_size = maxf(1.0, value)
		_apply()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply()


func _apply() -> void:
	custom_minimum_size = Vector2(logical_size, logical_size)
	var tex: Texture2D = null if icon_id.is_empty() else SNSkin.icon(icon_id)
	texture = tex
	visible = tex != null
