class_name SNItemTile
extends PanelContainer
## @static-doc
## 作用：市场 / 船只背包的单个物品图标格子：显示图标、名称、分类与价格信息与待交易数量角标；左键单击（release）待交易数量 +1（不超过 `max_pending`）、右键清空，可拖拽时把带 `kind` 与 `amount` 的载荷交给 SNDropZone。
##
## One icon tile of the direct-manipulation market screen.
##
## The tile owns only the *pending* amount (the quantity waiting on the icon);
## the hosting screen re-binds the page after a command, which resets it. A left
## click bumps the pending amount **on release** (a drag also starts with a left
## press, so incrementing on press would double-count the dragged unit); right
## click clears it; dragging emits a copy of the configured payload with
## `amount = max(pending, 1)`.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 底板取 `SNSkin.style("panel_recess")`；悬停 / 有待交易数量时改用
##   `SNSkin.style("panel_steel")` 克隆，并以 `modulate_color = SNSkin.color(...)`
##   区分（state.water = 悬停，brass.highlight = 有数量）；内外边距固定 9 / 8 / 9 / 10，
##   图标区不随状态跳动。
## - 文字颜色取 `SNSkin.color(token)`；数量角标复用 `SNBadge`（Theme 变体），
##   锁定标记用 `SNSkin.icon("status_locked")`，不写路径与十六进制色。
## - 尺寸：整格 `custom_minimum_size = (108, 132)`，图标区 58 px，文字 13 / 11；
##   行情网格 4 列（展开填充 592 px 右侧面板），背包网格 2 列。
##
## ## 契约与约束
## - `configure()` 接收 `{title, subtitle, meta, icon: Texture2D, max_pending,
##   draggable, payload: Dictionary, locked?}`；`payload` 必须带顶层 `kind`。
## - 委托货 / 不可交易行由 `draggable=false` + `locked=true` 表达，同时
##   `max_pending=0`，左键与拖拽都无效。
## - 左键只在 **release** 时 +1；拖拽起手（press → `_get_drag_data`）不改变 pending，
##   `_dragging` 期间的释放事件只复位标记、不 +1，因此「点 3 下再拖」携带 3 件。
## - `max_pending` 只反映该图标当前的**可用数量**（市场 stock / 船舱可售 / 仓库存量），
##   不预扣金币与剩余载重：数量仍可点到库存上限，金币 / 载重不足由命令层失败并在
##   状态栏报错，页面刷新后 pending 归零。这是本轮有意保留的边界，不是 bug。
## - `drag_payload()` 返回副本并把 `amount` 设为 `max(pending, 1)`，测试可直接调用；
##   `_get_drag_data()` 复用同一份载荷并挂拖拽预览。
## - `drop_host` 是「拿起 / 放下」的宿主落点（`SNDropZone`）：市场商品被拿起后，
##   点船舱 / 仓库区里的**子格子**也要放下货物，而子格子是 `MOUSE_FILTER_STOP`，
##   事件的落点点击到不了 zone。因此左键 release 先问
##   `drop_host.try_click_offer()`，被落点消费就 return（不算自己的 +1）；没有 offer
##   时行为与旧版一致（pending +1）。原生拖拽路径完全不受影响。
## @end-static-doc

signal pending_changed(pending: int)

const TILE_MIN_SIZE := Vector2(108.0, 132.0)
const ICON_HEIGHT := 58.0
const DRAG_PREVIEW_ICON := 40.0

## Payload copy configured by the host screen (top-level `kind` selects drop zones).
var payload: Dictionary = {}
## Optional click-to-drop host (`SNDropZone`) that wraps this tile. When the player
## carries goods, a left release on the tile is offered to the zone first.
var drop_host: Control = null
## Selected / pending trade amount shown on the tile.
var pending := 0
var max_pending := 0
var draggable := false
var locked := false
var item: Dictionary = {}

var _title_text := ""
var _subtitle_text := ""
var _meta_text := ""
var _icon_texture: Texture2D = null
var _title: Label = null
var _subtitle: Label = null
var _meta: Label = null
var _icon: TextureRect = null
var _badge: SNBadge = null
var _lock_mark: TextureRect = null
var _hovered := false
## True between `_get_drag_data()` and `NOTIFICATION_DRAG_END`: a drag release must
## not add a click increment on top of the already-carried amount.
var _dragging := false


## Binds the tile data. Safe before `_ready()`; the content is applied when the
## tile enters the tree.
func configure(data: Dictionary) -> void:
	_title_text = String(data.get("title", ""))
	_subtitle_text = String(data.get("subtitle", ""))
	_meta_text = String(data.get("meta", ""))
	_icon_texture = data.get("icon", null) as Texture2D
	payload = (data.get("payload", {}) as Dictionary).duplicate(true) if data.get("payload", null) is Dictionary else {}
	max_pending = maxi(0, int(data.get("max_pending", 0)))
	draggable = bool(data.get("draggable", false)) and max_pending > 0
	locked = bool(data.get("locked", false))
	item = (data.get("item", {}) as Dictionary).duplicate(true) if data.get("item", null) is Dictionary else payload.duplicate(true)
	pending = 0
	if is_node_ready():
		_apply_content()
		_apply_pending()
		_apply_style()
	_update_tooltip()


## Alias kept for callers that prefer `bind()` (screen components use `bind`).
func bind(data: Dictionary) -> void:
	configure(data)


## +1 pending amount, capped by `max_pending` (stock / sellable / warehouse qty).
func increment_pending() -> void:
	if max_pending <= 0:
		return
	if pending >= max_pending:
		return
	pending += 1
	_apply_pending()
	pending_changed.emit(pending)


## Clears the pending amount of this tile (right click).
func clear_pending() -> void:
	if pending == 0:
		return
	pending = 0
	_apply_pending()
	pending_changed.emit(pending)


## Drag payload copy: `amount` is at least 1 so a drag without prior clicks still
## carries one unit. Empty dictionary when the tile cannot be dragged.
func drag_payload() -> Dictionary:
	if not draggable or payload.is_empty():
		return {}
	var data := payload.duplicate(true)
	data["kind"] = String(payload.get("kind", ""))
	data["amount"] = maxi(pending, 1)
	data["name"] = _title_text
	return data


## Texture currently painted in the icon slot (null when content has no icon).
func icon_texture() -> Texture2D:
	return _icon.texture if _icon != null else _icon_texture


## Pending badge widget (tests assert its text / visibility).
func pending_badge() -> SNBadge:
	return _badge


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = TILE_MIN_SIZE
	mouse_default_cursor_shape = Control.CURSOR_DRAG if draggable else Control.CURSOR_POINTING_HAND
	_build()
	_apply_content()
	_apply_pending()
	_apply_style()


func _build() -> void:
	if _title != null:
		return
	var column := VBoxContainer.new()
	column.name = "Content"
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var icon_box := Control.new()
	icon_box.name = "IconBox"
	icon_box.custom_minimum_size = Vector2(0.0, ICON_HEIGHT)
	icon_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon_box)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(_icon)

	_lock_mark = TextureRect.new()
	_lock_mark.name = "LockMark"
	_lock_mark.texture = SNSkin.icon("status_locked")
	_lock_mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_lock_mark.offset_right = 18.0
	_lock_mark.offset_bottom = 18.0
	_lock_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lock_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lock_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_mark.visible = false
	icon_box.add_child(_lock_mark)

	_badge = SNBadge.new()
	_badge.name = "PendingBadge"
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left = -34.0
	_badge.offset_top = 0.0
	_badge.offset_right = 0.0
	_badge.offset_bottom = 20.0
	_badge.custom_minimum_size = Vector2(34.0, 20.0)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	icon_box.add_child(_badge)

	_title = _make_label(13, SNSkin.color("text.light"))
	_title.name = "Title"
	_subtitle = _make_label(11, SNSkin.color("text.muted"))
	_subtitle.name = "Subtitle"
	_meta = _make_label(11, SNSkin.color("state.water"))
	_meta.name = "Meta"
	column.add_child(_title)
	column.add_child(_subtitle)
	column.add_child(_meta)
	gui_input.connect(_on_gui_input)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_content() -> void:
	if _title == null:
		return
	_title.text = _title_text
	_subtitle.text = _subtitle_text
	_subtitle.visible = not _subtitle_text.is_empty()
	_meta.text = _meta_text
	_meta.visible = not _meta_text.is_empty()
	_icon.texture = _icon_texture
	_lock_mark.visible = locked
	mouse_default_cursor_shape = Control.CURSOR_DRAG if draggable else Control.CURSOR_POINTING_HAND
	_update_tooltip()


func _apply_pending() -> void:
	if _badge == null:
		return
	_badge.text = "×%d" % pending
	_badge.visible = pending > 0


func _apply_style() -> void:
	if not is_node_ready():
		return
	var highlighted := _hovered or pending > 0
	var style_id := "panel_steel" if highlighted else "panel_recess"
	var base_style: StyleBoxTexture = SNSkin.style(style_id)
	if base_style == null:
		theme_type_variation = &"SNInsetPanel"
		return
	var style := base_style.duplicate() as StyleBoxTexture
	style.content_margin_left = 9.0
	style.content_margin_top = 8.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 10.0
	if pending > 0:
		style.modulate_color = SNSkin.color("brass.highlight")
	elif _hovered:
		style.modulate_color = SNSkin.color("state.water")
	add_theme_stylebox_override("panel", style)


func _update_tooltip() -> void:
	var parts: Array[String] = []
	if not _title_text.is_empty():
		parts.append(_title_text)
	if not _subtitle_text.is_empty():
		parts.append(_subtitle_text)
	if not _meta_text.is_empty():
		parts.append(_meta_text)
	tooltip_text = " · ".join(parts)


## A left click adds one unit only on release: the same button starts a drag, and
## incrementing on press would make "click three times, then drag" carry four.
func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			if not button.pressed:
				# The release that ends a drag only resets the flag; the drag
				# payload already carries the pending amount.
				if _dragging:
					_dragging = false
					return
				# A carried stack (拿起手势) takes the click: the tile sits inside a
				# drop zone that the click has to reach.
				if _consume_click_offer():
					return
				increment_pending()
		MOUSE_BUTTON_RIGHT:
			if button.pressed:
				clear_pending()


## Asks the wrapping drop zone to place the carried stack; true when it consumed
## the click (that click must not bump this tile's own pending amount).
func _consume_click_offer() -> bool:
	if drop_host == null or not is_instance_valid(drop_host):
		return false
	if not drop_host.has_method("try_click_offer"):
		return false
	return bool(drop_host.call("try_click_offer"))


func _get_drag_data(_at_position: Vector2) -> Variant:
	var data := drag_payload()
	if data.is_empty():
		return null
	_dragging = true
	set_drag_preview(_drag_preview(data))
	return data


func _drag_preview(data: Dictionary) -> Control:
	var preview := PanelContainer.new()
	var base_style: StyleBoxTexture = SNSkin.style("panel_steel")
	if base_style != null:
		var style := base_style.duplicate() as StyleBoxTexture
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		style.modulate_color = SNSkin.color("state.water")
		preview.add_theme_stylebox_override("panel", style)
	else:
		preview.theme_type_variation = &"SNInsetPanel"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _icon_texture
	icon.custom_minimum_size = Vector2(DRAG_PREVIEW_ICON, DRAG_PREVIEW_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var title := Label.new()
	title.text = String(data.get("name", _title_text))
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", SNSkin.color("text.light"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var amount := Label.new()
	amount.text = "×%d" % int(data.get("amount", 1))
	amount.add_theme_font_size_override("font_size", 12)
	amount.add_theme_color_override("font_color", SNSkin.color("brass.highlight"))
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(amount)
	return preview


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_END:
			_dragging = false
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			_apply_style()
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			_apply_style()
