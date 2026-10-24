extends Button
## @static-doc
## 作用：2.5D 港口主界面的边缘设施招牌。纹理化 `Button` 子类：底板/悬停/按下/焦点全部来自外部皮肤
## Theme 变体（`SNPrimaryButton` / `SNPlateButton`），设施徽记来自 `SNSkin.icon()`，文字由 Theme 绘制；
## 点击、焦点、键盘激活、tooltip 与 `text` 语义仍由 `Button` 提供。
##
## ## 外部贴图来源
## - 皮肤：`assets/ui/skin/sn_v1/skin.json`（由 `tools/build_ui_skin.ps1` 从控件图集/图标图集生成）。
## - 底板：Theme 的 `SNPlateButton`（普通招牌）与 `SNPrimaryButton`（主入口/海图招牌）四态纹理。
## - 徽记：`SNSkin.icon()` 按 facility 映射到 `icons/*.png`（20 px 逻辑尺寸，`icon_max_width` 约束）。
## - 本组件不写贴图路径、不写十六进制颜色，也不再用 `_draw()` 画木纹/铁框/铆钉/箭头。
##
## ## 用法
## - Shell 在把招牌加入场景树前调用 `configure(label_text, sign_primary, sign_facility, sign_arrow)`；
##   `text` 保留完整标签（含「◀ / ▶」字形）供测试、tooltip 与无障碍使用。
## - `primary` 选择主按钮纹理，`facility` 选择徽记，`arrow_direction`（-1 左列 / 1 右列 / 0 无箭头）保留给
##   Shell 布局与测试；`show_emblem = false` 可关闭图标。
## - 皮肤/图标缺失时 `icon` 为 null，Theme 文字仍完整绘制，招牌保持可读、可点击。
##
## ## 尺寸预算
## - 最小尺寸固定 `172 × 42`（与 Shell 的 `PORT_SIGN_WIDTH/HEIGHT` 一致），字号 14、图标 ≤20 px；
##   招牌在 960×540 缩放下仍整体等比缩放，不裁字、不改尺寸。
## @end-static-doc

## Floor size shared with the Shell layout (`PORT_SIGN_WIDTH/HEIGHT`).
const SIGN_SIZE := Vector2(172.0, 42.0)
## Icon slot bound; keeps the 172 px plate readable with 2–5 character labels.
const ICON_MAX_WIDTH := 20
## Facility -> skin icon id. Unknown facilities fall back to no icon (text only).
const FACILITY_ICONS := {
	"exchange": "nav_market",
	"contracts": "nav_contracts",
	"supply": "nav_resupply",
	"intel": "nav_intelligence",
	"tavern": "nav_intelligence",
	"shipyard": "nav_shipyard",
	"sea_chart": "nav_chart",
	"voyage": "nav_chart",
}

## -1 = left column (sign sits on the window edge, arrow points right into the
## scene); 1 = right column (arrow points left). 0 hides the arrow. Kept as a
## field because the Shell layout and tests read it back.
var arrow_direction := -1
var primary := false
var facility := ""
## Toggles the facility emblem (skin icon). False keeps a text-only plate.
var show_emblem := true


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = SIGN_SIZE
	_apply_visuals()


## One-shot configuration from the Shell layout pass. Safe to call before the
## node enters the tree: `_ready()` re-applies the same visuals after the Theme
## is inherited.
func configure(label_text: String, sign_primary: bool, sign_facility: String, sign_arrow: int) -> void:
	text = label_text
	primary = sign_primary
	facility = sign_facility
	arrow_direction = sign_arrow
	_apply_visuals()


## Maps the semantic configuration onto external textures: Theme variation for
## the plate and one skin icon for the facility. Missing textures simply leave
## the inherited Theme text in charge, so the sign never becomes blank.
func _apply_visuals() -> void:
	theme_type_variation = &"SNPrimaryButton" if primary else &"SNPlateButton"
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	var icon_id := String(FACILITY_ICONS.get(facility, ""))
	var texture: Texture2D = null
	if show_emblem and not icon_id.is_empty():
		texture = SNSkin.icon(icon_id)
	icon = texture
	# Skin icons are authored on a 128 px canvas; `expand_icon` lets the Button
	# shrink them to `icon_max_width` instead of clamping the explicit 172x42
	# plate up to the texture's natural size.
	expand_icon = texture != null
	if texture != null:
		add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	else:
		remove_theme_constant_override("icon_max_width")
