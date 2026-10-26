class_name SNCarryGhost
extends Control
## @static-doc
## 作用：市场「拿起 / 放下」手势的光标幽灵：把被拿起的商品图标、名称、×数量与预计消费画成跟随鼠标的浮层（点击落点放下、右键取消），由 Shell 挂在页面滚动区之外的浮层里，任何页面都可复用。
##
## ## 场景化（P0，见 docs/specs/UI_SCENE_MIGRATION.md）
## 静态骨架在 `sn_carry_ghost.tscn`：根 `Control` 挂本脚本（`visible = false`、
## `mouse_filter = IGNORE`、根节点引用 `steam_navigator_theme.tres`），子树为
## `GhostPanel(PanelContainer, IGNORE) → GhostRow(HBoxContainer, separation 8, IGNORE) →
## Icon(TextureRect, 40×40, expand_mode=1, stretch_mode=5, IGNORE) +
## Labels(VBoxContainer, separation 1, IGNORE) → Title(13) / Amount(14) /
## Cost(11, 初始隐藏) / Hint(10)`，四行都是 `Label`、`autowrap_mode=0`、`mouse_filter=IGNORE`。
## 层级、尺寸、间距、字号、初始隐藏都是设计常量，只写在场景里。
##
## **实例化契约（R1）**：调用方必须
## `preload("res://framework/ui/components/sn_carry_ghost.tscn").instantiate()`，
## 禁止 `SNCarryGhost.new()`——脚本 `.new()` 没有场景子树，`_ensure_refs()` 全部解析为空，
## 幽灵会静默空白；节点名 `GhostPanel` / `GhostRow` / `Icon` / `Labels` / `Title` /
## `Amount` / `Cost` / `Hint` 是查找契约（R2），不要改名。脚本只做延迟解析
## （`_ensure_refs()`）、固定黄铜色调、`_sync_bounds()`、`place_at()` 与跟随鼠标，
## 允许在未进树时先 `begin()`（R3）。
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
## The ghost carries the **selected amount** (`×N`) plus an optional estimated cost
## line (`预计消费 %d 金`): the market tile badge shows the remaining stock instead,
## so the two numbers never duplicate each other.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 底板取 `SNSkin.style("panel_steel")` 克隆，内容边距 10 / 6，并以
##   `modulate_color = SNSkin.color("brass.highlight")` 表示「手上拿着货」；
##   图标 40 px、四行字号写在场景里；文字色取 `text.light` / `brass.highlight` /
##   `text.muted`，全部由脚本写 token（场景里不复制颜色值，R4）。
## - 不新增 `StyleBoxFlat`、不写十六进制色、不硬编码皮肤路径。
## - 根节点与整棵子树的 `mouse_filter` 全部是 `IGNORE`：光标幽灵绝不吞鼠标事件，
##   落点点击仍由 `SNDropZone` / `SNItemTile` 处理。
##
## ## 契约与约束
## - `begin(icon, title, amount, hint, cost_text)` 开始 / 更新携带；`cost_text` 为空
##   时隐藏预计消费行（非市场页面 / 没有单价时）。`set_amount()` 只改数量
##   （归零等价于 `end()`）；`end()` 收起且停止 `_process`。
## - 预计消费行在 `×数量` 下方、字号更小；文本由 Shell 用 `ui.market.estimated_cost`
##   格式化（`unit_price × amount`），组件本身不计算金额。
## - 跟随在 `_process` 里读 `get_viewport().get_mouse_position()`，偏移固定
##   `POINTER_OFFSET`（+18, +12）并钳制在视口内；`Viewport.gui_is_dragging()` 为真
##   时隐藏——原生拖拽预览已经跟着鼠标，两个幽灵不该重叠（原生拖拽保留为兼容手势）。
## - `place_at(mouse)` 是纯函数：返回钳制后的左上角坐标。headless 测试里鼠标恒为
##   (0,0)，测试用 `place_at(Vector2.ZERO)` 断言偏移与视口钳制，不依赖真实鼠标。
## - 数量 / 金额只由宿主页面写入；本组件不校验库存 / 载重 / 金币（命令层负责失败提示）。
## @end-static-doc

## Cursor offset of the ghost's top-left corner (icon floats beside the pointer,
## not under it, so the click target stays visible).
const POINTER_OFFSET := Vector2(18.0, 12.0)
const PANEL_STYLE_ID := "panel_steel"
const BRASS_TINT_TOKEN := "brass.highlight"
const CONTENT_MARGIN := Vector2(10.0, 6.0)

var _panel: PanelContainer = null
var _icon: TextureRect = null
var _title: Label = null
var _amount: Label = null
var _cost: Label = null
var _hint: Label = null
var _carrying := false
var _amount_value := 0
var _cost_value := ""
var _skin_applied := false


func _ready() -> void:
	# 场景根节点已经带上这些属性；保留兜底，调用方即使手工装配也不会改变契约。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_ensure_refs()
	_ensure_skin()
	_sync_bounds()


## Resolves the scene subtree by name. Safe before `add_child()` / `_ready()`: the
## instantiated scene already owns these children, so `get_node_or_null` works even
## when the control is not in the tree yet (R3).
func _ensure_refs() -> void:
	if _panel == null:
		_panel = get_node_or_null("GhostPanel") as PanelContainer
	if _icon == null:
		_icon = get_node_or_null("GhostPanel/GhostRow/Icon") as TextureRect
	if _title == null:
		_title = get_node_or_null("GhostPanel/GhostRow/Labels/Title") as Label
	if _amount == null:
		_amount = get_node_or_null("GhostPanel/GhostRow/Labels/Amount") as Label
	if _cost == null:
		_cost = get_node_or_null("GhostPanel/GhostRow/Labels/Cost") as Label
	if _hint == null:
		_hint = get_node_or_null("GhostPanel/GhostRow/Labels/Hint") as Label


## 固定黄铜色调 + 文字 token 只由脚本写入（场景不复制颜色值，R4）；只应用一次。
## 底板克隆 `panel_steel` 并改成 10 / 6 内容边距，`modulate_color` 用 brass 高亮。
func _ensure_skin() -> void:
	if _skin_applied:
		return
	_skin_applied = true
	if _panel != null:
		var base_style: StyleBoxTexture = SNSkin.style(PANEL_STYLE_ID)
		if base_style != null:
			var style := base_style.duplicate() as StyleBoxTexture
			style.content_margin_left = CONTENT_MARGIN.x
			style.content_margin_top = CONTENT_MARGIN.y
			style.content_margin_right = CONTENT_MARGIN.x
			style.content_margin_bottom = CONTENT_MARGIN.y
			style.modulate_color = SNSkin.color(BRASS_TINT_TOKEN)
			_panel.add_theme_stylebox_override("panel", style)
		else:
			_panel.theme_type_variation = &"SNInsetPanel"
	if _title != null:
		_title.add_theme_color_override("font_color", SNSkin.color("text.light"))
	if _amount != null:
		_amount.add_theme_color_override("font_color", SNSkin.color("brass.highlight"))
	if _cost != null:
		_cost.add_theme_color_override("font_color", SNSkin.color("text.light"))
	if _hint != null:
		_hint.add_theme_color_override("font_color", SNSkin.color("text.muted"))


## Starts (or updates) the carried stack. An amount of zero keeps the ghost hidden;
## the caller usually follows a positive `pending` change on `SNItemTile`.
## `cost_text` is the pre-formatted estimated cost line (empty hides it).
func begin(icon: Texture2D, title: String, amount: int, hint: String = "", cost_text: String = "") -> void:
	_ensure_refs()
	_ensure_skin()
	if _icon != null:
		_icon.texture = icon
	if _title != null:
		_title.text = title
		_title.visible = not title.is_empty()
	_cost_value = cost_text
	if _cost != null:
		_cost.text = cost_text
		_cost.visible = not cost_text.is_empty()
	if _hint != null:
		_hint.text = hint
		_hint.visible = not hint.is_empty()
	_amount_value = maxi(0, amount)
	if _amount != null:
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


## Pre-formatted estimated cost line currently painted ("" when hidden). Tests
## assert Shell passes `unit_price × amount` here.
func cost_text() -> String:
	return _cost_value


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
