class_name SNCarryGhost
extends Control
## @static-doc
## 作用：市场「拿起 / 放下」手势的光标幽灵：把被拿起的商品图标、名称与 ×数量画成跟随鼠标的浮层（点击落点放下、右键取消），由 Shell 挂在页面滚动区之外的浮层里，任何页面都可复用。
##
## Pointer-follow ghost for the direct-manipulation market interaction
## (v0.2.0-dev.3 feedback #1: the icon must float on the cursor while the player
## carries the goods, and the count follows the pointer).
##
## The page owns the *pending* amount (`SNItemTile`) and decides when a payload is
## picked up; this control only paints the carried stack next to the cursor. It is
## mounted on a shell overlay outside the `PageScroll`, so the page margins and
## the scroll container can never clip it.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 底板取 `SNSkin.style("panel_steel")` 克隆，内容边距 10 / 6，并以
##   `modulate_color = SNSkin.color("brass.highlight")` 表示「手上拿着货」；
##   图标 40 px，文字色取 `text.light` / `brass.highlight` / `text.muted`。
## - 不新增 `StyleBoxFlat`、不写十六进制色、不硬编码皮肤路径。
## - 根节点与整棵子树的 `mouse_filter` 全部是 `IGNORE`：光标幽灵绝不吞鼠标事件，
##   落点点击仍由 `SNDropZone` / `SNItemTile` 处理。
##
## ## 契约与约束
## - `begin(icon, title, amount, hint)` 开始 / 更新携带；`set_amount()` 只改数量
##   （归零等价于 `end()`）；`end()` 收起且停止 `_process`。
## - 跟随在 `_process` 里读 `get_viewport().get_mouse_position()`，偏移固定
##   `POINTER_OFFSET`（+18, +12）并钳制在视口内；`Viewport.gui_is_dragging()` 为真
##   时隐藏——原生拖拽预览已经跟着鼠标，两个幽灵不该重叠（原生拖拽保留为兼容手势）。
## - `place_at(mouse)` 是纯函数：返回钳制后的左上角坐标。headless 测试里鼠标恒为
##   (0,0)，测试用 `place_at(Vector2.ZERO)` 断言偏移与视口钳制，不依赖真实鼠标。
## - 数量只由宿主页面写入；本组件不校验库存 / 载重 / 金币（命令层负责失败提示）。
## @end-static-doc

## Cursor offset of the ghost's top-left corner (icon floats beside the pointer,
## not under it, so the click target stays visible).
const POINTER_OFFSET := Vector2(18.0, 12.0)
const ICON_SIZE := 40.0
const CONTENT_MARGIN := Vector2(10.0, 6.0)
const TITLE_FONT_SIZE := 13
const AMOUNT_FONT_SIZE := 14
const HINT_FONT_SIZE := 10

var _panel: PanelContainer = null
var _icon: TextureRect = null
var _title: Label = null
var _amount: Label = null
var _hint: Label = null
var _carrying := false
var _amount_value := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build()


## Starts (or updates) the carried stack. An amount of zero keeps the ghost hidden;
## the caller usually follows a positive `pending` change on `SNItemTile`.
func begin(icon: Texture2D, title: String, amount: int, hint: String = "") -> void:
	_build()
	_icon.texture = icon
	_title.text = title
	_title.visible = not title.is_empty()
	_hint.text = hint
	_hint.visible = not hint.is_empty()
	_amount_value = maxi(0, amount)
	_amount.text = "×%d" % _amount_value
	_carrying = _amount_value > 0
	visible = _carrying
	set_process(_carrying)
	_sync_bounds()
	if _carrying:
		position = place_at(_current_mouse())


## Updates only the carried count (the icon / title stay); zero ends the carry.
func set_amount(amount: int) -> void:
	if _amount == null:
		return
	_amount_value = maxi(0, amount)
	_amount.text = "×%d" % _amount_value
	if _amount_value == 0:
		end()
		return
	_carrying = true
	visible = _carrying
	set_process(_carrying)


## Puts the ghost away and stops following the mouse.
func end() -> void:
	_carrying = false
	_amount_value = 0
	visible = false
	set_process(false)


func is_carrying() -> bool:
	return _carrying


func amount() -> int:
	return _amount_value


## Texture currently painted in the 40 px icon slot (tests assert the carried
## item's resolved icon travels with the ghost).
func carried_icon() -> Texture2D:
	return _icon.texture if _icon != null else null


## Clamped top-left position for a given pointer position. Pure: no viewport mouse
## read, so the headless tests can assert it deterministically.
func place_at(mouse: Vector2) -> Vector2:
	var bounds := _min_size()
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	var placed := mouse + POINTER_OFFSET
	if viewport_size.x > 0.0:
		placed.x = clampf(placed.x, 0.0, maxf(0.0, viewport_size.x - bounds.x))
	if viewport_size.y > 0.0:
		placed.y = clampf(placed.y, 0.0, maxf(0.0, viewport_size.y - bounds.y))
	return placed


func _process(_delta: float) -> void:
	if not _carrying:
		return
	# A native drag preview already follows the cursor; showing the ghost too
	# would stack two copies of the same icon.
	if is_inside_tree() and get_viewport().gui_is_dragging():
		visible = false
		return
	visible = true
	_sync_bounds()
	position = place_at(_current_mouse())


func _build() -> void:
	if _panel != null:
		return
	_panel = PanelContainer.new()
	_panel.name = "GhostPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style: StyleBoxTexture = SNSkin.style("panel_steel")
	if base_style != null:
		var style := base_style.duplicate() as StyleBoxTexture
		style.content_margin_left = CONTENT_MARGIN.x
		style.content_margin_top = CONTENT_MARGIN.y
		style.content_margin_right = CONTENT_MARGIN.x
		style.content_margin_bottom = CONTENT_MARGIN.y
		style.modulate_color = SNSkin.color("brass.highlight")
		_panel.add_theme_stylebox_override("panel", style)
	else:
		_panel.theme_type_variation = &"SNInsetPanel"
	add_child(_panel)

	var row := HBoxContainer.new()
	row.name = "GhostRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_panel.add_child(row)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	var column := VBoxContainer.new()
	column.name = "Labels"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)

	_title = _label("", TITLE_FONT_SIZE, SNSkin.color("text.light"))
	_title.name = "Title"
	_amount = _label("", AMOUNT_FONT_SIZE, SNSkin.color("brass.highlight"))
	_amount.name = "Amount"
	_hint = _label("", HINT_FONT_SIZE, SNSkin.color("text.muted"))
	_hint.name = "Hint"
	column.add_child(_title)
	column.add_child(_amount)
	column.add_child(_hint)
	_sync_bounds()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Keeps the root Control exactly as large as the skin panel: the ghost is parented
## to a plain Control overlay (no container layout), so it sizes itself.
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


func _current_mouse() -> Vector2:
	if is_inside_tree():
		return get_viewport().get_mouse_position()
	return Vector2.ZERO
