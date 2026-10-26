class_name SNFocusOverlay
extends Control
## @static-doc
## 作用：框架级「强制引导」遮罩（v0.2.0-dev.3 反馈 #3）。全屏半透明遮罩只留一个
## 目标矩形可交互：遮罩用四块纹理拼出目标之外的四边（不开洞、不改 GUI 命中），
## 目标矩形上再画一圈 focus ring 与一行提示文案。剧情 / 任务等内容只声明语义目标，
## 由 Shell 解析成真实控件矩形后调用 `focus(rect, text)`。
##
## Full-window guided-focus mask (dev.3 feedback #3: only the one interaction the
## tutorial asks for should stay clickable, everything else under a dim veil). The
## component is content-agnostic: the caller resolves a semantic target into a
## screen rect and passes it in.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 四块遮罩是 `SNSkin.style("fill_aqua")` 的克隆，`modulate_color` 取
##   `SNSkin.color("bg.abyss")` 并压到 `MASK_ALPHA`；高亮边框取
##   `SNSkin.style("focus_ring")`、`brass.highlight`；提示底板取
##   `SNSkin.style("panel_steel")`，文字 `text.light`。不新增 `StyleBoxFlat`、
##   不写十六进制色、不硬编码皮肤路径。
## - 皮肤缺失（manifest 为空）时四块遮罩退回 `ColorRect` + 同一个 token 色，
##   不给业务脚本留下裸色值。
##
## ## 契约与约束
## - 根节点 `mouse_filter = IGNORE`；四块遮罩 `STOP`（吃掉目标之外的点击 /
##   滚轮 / 拖拽），目标矩形区域没有任何遮罩子节点，因此目标控件仍是该点的最上层
##   可交互控件。ring / 提示都是 `IGNORE`，不会抢目标边框附近的点击。
## - `focus(rect, text)` 的 `rect` 是**屏幕 / 全局坐标**（Shell 用
##   `Control.get_global_rect()` 直接传入）；组件内部转成自身局部坐标，并在
##   `NOTIFICATION_RESIZED` 时重新布局，`960×540` 与 `1440×900` 都不会溢出视口。
## - `clear_focus()` 立即隐藏并清空目标；`is_active()` / `get_target_rect()` /
##   `get_mask_rects()` / `get_focus_text()` 供 Shell 与无头测试断言。
## - 该组件不做剧情判定也不发命令：何时显示由 Shell 依据 `story.view.focus`
##   决定（剧情卡打开时卡片优先，遮罩不出现）。
## @end-static-doc

## Dim mask: skin nine-slice fill tinted with a semantic token (no raw hex).
const MASK_STYLE_ID := "fill_aqua"
const MASK_TINT_TOKEN := "bg.abyss"
const MASK_ALPHA := 0.68
## Highlight ring around the interactive hole.
const RING_STYLE_ID := "focus_ring"
const RING_TINT_TOKEN := "brass.highlight"
const RING_PAD := 6.0
## Hint plate under / above the hole.
const TEXT_STYLE_ID := "panel_steel"
const TEXT_STYLE_FALLBACK := "panel_recess"
const TEXT_FONT_SIZE := 13
const TEXT_MAX_WIDTH := 460.0
const TEXT_GAP := 12.0
const TEXT_SCREEN_MARGIN := 12.0
const TEXT_CONTENT_MARGIN := Vector2(12.0, 6.0)

var _target_rect := Rect2()
var _active := false
var _focus_text := ""
var _masks: Array[Control] = []
var _ring: PanelContainer = null
var _text_panel: PanelContainer = null
var _text_label: Label = null


func _init() -> void:
	# Set before `_ready` so an overlay that is inspected before entering the tree
	# already holds the pass-through contract (the hole must never be swallowed).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


## Shows the guided mask with `rect` (screen coordinates) as the only interactive
## hole and an optional one-line hint. Re-calling with a new rect only re-lays out.
func focus(rect: Rect2, text: String = "") -> void:
	_build()
	_target_rect = rect
	_focus_text = text
	_active = true
	visible = true
	if _ring != null:
		_ring.visible = true
	if _text_label != null:
		_text_label.text = text
	if _text_panel != null:
		_text_panel.visible = not text.is_empty()
	_layout()


## Hides the mask and forgets the target. Safe to call when already inactive.
func clear_focus() -> void:
	_active = false
	visible = false
	_target_rect = Rect2()
	_focus_text = ""
	for mask in _masks:
		if mask != null and is_instance_valid(mask):
			mask.visible = false
	if _ring != null and is_instance_valid(_ring):
		_ring.visible = false
	if _text_label != null:
		_text_label.text = ""
	if _text_panel != null:
		_text_panel.visible = false


func is_active() -> bool:
	return _active


## The interactive hole in this control's local coordinates (zero when inactive).
func get_target_rect() -> Rect2:
	if not _active:
		return Rect2()
	return _local_rect(_target_rect)


## The four mask pieces in this control's local coordinates, in the order
## top / bottom / left / right. Zero-size pieces are skipped.
func get_mask_rects() -> Array:
	var rects: Array = []
	for mask in _masks:
		if mask == null or not is_instance_valid(mask) or not mask.visible:
			continue
		rects.append(Rect2(mask.position, mask.size))
	return rects


func get_focus_text() -> String:
	return _focus_text


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _active:
		_layout()


func _build() -> void:
	if not _masks.is_empty():
		return
	for piece_name in ["MaskTop", "MaskBottom", "MaskLeft", "MaskRight"]:
		var mask := Control.new()
		mask.name = piece_name
		mask.mouse_filter = Control.MOUSE_FILTER_STOP
		mask.focus_mode = Control.FOCUS_NONE
		_add_mask_fill(mask)
		add_child(mask)
		_masks.append(mask)
	_ring = PanelContainer.new()
	_ring.name = "FocusRing"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style: StyleBox = SNSkin.style(RING_STYLE_ID)
	if ring_style is StyleBoxTexture:
		(ring_style as StyleBoxTexture).modulate_color = _token_color(RING_TINT_TOKEN)
		_ring.add_theme_stylebox_override("panel", ring_style)
	add_child(_ring)
	_text_panel = PanelContainer.new()
	_text_panel.name = "FocusHint"
	_text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_style: StyleBox = SNSkin.style(TEXT_STYLE_ID)
	if text_style == null:
		text_style = SNSkin.style(TEXT_STYLE_FALLBACK)
	if text_style != null:
		text_style.content_margin_left = TEXT_CONTENT_MARGIN.x
		text_style.content_margin_right = TEXT_CONTENT_MARGIN.x
		text_style.content_margin_top = TEXT_CONTENT_MARGIN.y
		text_style.content_margin_bottom = TEXT_CONTENT_MARGIN.y
		_text_panel.add_theme_stylebox_override("panel", text_style)
	_text_label = Label.new()
	_text_label.name = "FocusText"
	_text_label.text = _focus_text
	_text_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_text_label.add_theme_color_override("font_color", SNSkin.color("text.light"))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_panel.add_child(_text_label)
	_text_panel.visible = false
	add_child(_text_panel)


## One mask piece: the skin fill when the manifest is available, else a token-tinted
## ColorRect (still no raw color literals / StyleBoxFlat).
func _add_mask_fill(mask: Control) -> void:
	var tint := _token_color(MASK_TINT_TOKEN)
	tint.a = MASK_ALPHA
	var style: StyleBox = SNSkin.style(MASK_STYLE_ID)
	if style is StyleBoxTexture:
		(style as StyleBoxTexture).modulate_color = tint
		var panel := PanelContainer.new()
		panel.name = "Skin"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", style)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mask.add_child(panel)
		return
	var fill := ColorRect.new()
	fill.name = "Fallback"
	fill.color = tint
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.add_child(fill)


func _token_color(token: String) -> Color:
	var color := SNSkin.color(token)
	if color.a <= 0.0:
		color.a = 1.0
	return color


## Screen rect of the hole, clamped into the control, in local coordinates.
func _local_rect(global_rect: Rect2) -> Rect2:
	var screen := _screen_rect()
	var local := global_rect
	local.position -= get_global_rect().position
	var left := clampf(local.position.x, 0.0, screen.size.x)
	var top := clampf(local.position.y, 0.0, screen.size.y)
	var right := clampf(local.position.x + local.size.x, 0.0, screen.size.x)
	var bottom := clampf(local.position.y + local.size.y, 0.0, screen.size.y)
	return Rect2(left, top, maxf(0.0, right - left), maxf(0.0, bottom - top))


func _screen_rect() -> Rect2:
	if size.x > 0.0 and size.y > 0.0:
		return Rect2(Vector2.ZERO, size)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(TEXT_MAX_WIDTH, TEXT_MAX_WIDTH)
	return Rect2(Vector2.ZERO, viewport_size)


func _layout() -> void:
	if _masks.size() < 4:
		return
	var screen := _screen_rect()
	var hole := _local_rect(_target_rect)
	var screen_width := screen.size.x
	var screen_height := screen.size.y
	_place_mask(_masks[0], Rect2(0.0, 0.0, screen_width, hole.position.y))
	_place_mask(_masks[1], Rect2(
		0.0, hole.position.y + hole.size.y, screen_width, screen_height - hole.position.y - hole.size.y
	))
	_place_mask(_masks[2], Rect2(0.0, hole.position.y, hole.position.x, hole.size.y))
	_place_mask(_masks[3], Rect2(
		hole.position.x + hole.size.x, hole.position.y, screen_width - hole.position.x - hole.size.x, hole.size.y
	))
	if _ring != null:
		_ring.position = hole.position - Vector2(RING_PAD, RING_PAD)
		_ring.size = hole.size + Vector2(RING_PAD * 2.0, RING_PAD * 2.0)
	if _text_panel != null and _text_panel.visible:
		_layout_text(hole, screen)


func _place_mask(mask: Control, rect: Rect2) -> void:
	var clipped := Rect2(
		maxf(0.0, rect.position.x),
		maxf(0.0, rect.position.y),
		maxf(0.0, rect.size.x),
		maxf(0.0, rect.size.y)
	)
	mask.position = clipped.position
	mask.size = clipped.size
	mask.visible = clipped.size.x > 0.0 and clipped.size.y > 0.0


func _layout_text(hole: Rect2, screen: Rect2) -> void:
	var text_width := minf(TEXT_MAX_WIDTH, maxf(64.0, screen.size.x - TEXT_SCREEN_MARGIN * 2.0))
	_text_label.custom_minimum_size = Vector2(text_width, 0.0)
	_text_panel.reset_size()
	var panel_size := _text_panel.get_combined_minimum_size()
	var x := hole.position.x + (hole.size.x - panel_size.x) * 0.5
	x = clampf(x, TEXT_SCREEN_MARGIN, maxf(TEXT_SCREEN_MARGIN, screen.size.x - panel_size.x - TEXT_SCREEN_MARGIN))
	var y := hole.position.y + hole.size.y + TEXT_GAP
	if y + panel_size.y > screen.size.y - TEXT_SCREEN_MARGIN:
		y = hole.position.y - panel_size.y - TEXT_GAP
	y = clampf(y, TEXT_SCREEN_MARGIN, maxf(TEXT_SCREEN_MARGIN, screen.size.y - panel_size.y - TEXT_SCREEN_MARGIN))
	_text_panel.position = Vector2(x, y)
	_text_panel.size = panel_size
