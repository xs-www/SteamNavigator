@tool
class_name SNBadge
extends Label
## @static-doc
## 作用：紧凑状态徽标：中性、成功、警告和危险四种语义；底色、描边与文字色全部由纹理化 Theme 的 `SN*Badge` 变体提供，控件本身只做语义映射。
##
## - 关键依赖：`assets/ui/theme/steam_navigator_theme.tres` 的 `SNBadge` / `SNSuccessBadge` / `SNWarningBadge` / `SNDangerBadge`（Label 变体）。
##
## ## 契约与约束
## - 保持 `extends Label`，不改成 HBox/容器：页面与测试按文本、尺寸和 Label 类型查找徽标。
## - `Tone` 只切换 `theme_type_variation`；字号、内容边距、纹理底色由 Theme 统一，控件不写颜色。
## - 颜色不能作为状态的唯一表达，调用方必须同时给出明确文字（如「已完成」「中等风险」）。
##
## ## 用法
## ```gdscript
## var badge := SNBadge.new()
## badge.tone = SNBadge.Tone.WARNING
## badge.text = "中等风险"
## ```
## @end-static-doc

enum Tone { NEUTRAL, SUCCESS, WARNING, DANGER }

## Theme variation per tone; order must match `Tone`.
const VARIATIONS: Array[StringName] = [
	&"SNBadge", &"SNSuccessBadge", &"SNWarningBadge", &"SNDangerBadge",
]

@export var tone: Tone = Tone.NEUTRAL:
	set(value):
		tone = value
		_apply_tone()


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_tone()


func _apply_tone() -> void:
	var index := clampi(int(tone), 0, VARIATIONS.size() - 1)
	theme_type_variation = VARIATIONS[index]
