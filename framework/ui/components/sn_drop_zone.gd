class_name SNDropZone
extends PanelContainer
## @static-doc
## 作用：图标拖拽的通用落点面板：按载荷 `kind` 过滤、命中时用 SNSkin 九宫格纹理的 `modulate_color` 高亮、放下后发出 `dropped`；拖拽结束 / 鼠标移出复位。
##
## Shared drop target for the icon-direct market interaction.
##
## The zone never decides which command runs: it only owns the "is this payload
## accepted here" rule and the highlight feedback. The hosting screen / panel
## maps the dropped payload to the trade or warehouse command.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 底板取 `SNSkin.style("panel_recess")`（可配置 `zone_style_id`），命中高亮改用
##   `SNSkin.style("panel_steel")` 克隆并设置 `modulate_color = SNSkin.color(...)`；
##   高亮内外边距与空闲态一致，落点不会因高亮跳动。
## - 透明落点（如整块市场面板）把 `zone_style_id` 设为空串：空闲态用
##   `StyleBoxEmpty`（不新增 `StyleBoxFlat`），高亮仍是皮肤纹理 + token 染色。
## - 不写十六进制色、不硬编码皮肤路径。
##
## ## 契约与约束
## - `accept_kinds` 里的 `kind` 是拖拽载荷的顶层字段（`market_item` / `cargo_item`
##   / `warehouse_item`）；未配置 or 不匹配一律返回 false，不做模糊回退。
## - `dropped` 载荷是 `duplicate(true)` 后的副本，承载方可以安全修改。
## - 高亮会在 `_drop_data`、`NOTIFICATION_DRAG_END` / `NOTIFICATION_MOUSE_EXIT` 复位；
##   Godot 只把拖拽结束通知发给拖拽来源，所以高亮期间用 `_process` 轮询
##   `Viewport.gui_is_dragging()`，拖到空处释放也不会留下残留高亮。
## - 子内容统一挂到 `content_root()` 返回的 VBox，落点自身只保留一个子节点。
##
## ## 拿起 / 放下（点击落点，feedback #1）
## - `set_offer(data)` / `clear_offer()` / `offer_active()` / `offer_payload()`：市场
##   「拿起」手势的落点状态。`set_offer` 只接受 `accept_kinds` 里的载荷（不匹配直接
##   清空），有 offer 时落点用皮肤纹理高亮，玩家点一下落点（左键 release）就
##   `try_click_offer()` → 发出 `dropped`。原生拖拽仍是兼容手势，两条路径共用
##   `dropped` 契约。
## - `_gui_input` 里先 `accept_event()` 再发 `dropped`：命令成功会触发 Shell 整页重建，
##   落点节点可能已被移出场景树，事后再 `accept_event()` 会拿不到 Viewport。
## - `_process` 只复位**拖拽**高亮，绝不清 offer；offer 由宿主页面在携带结束时清空。
## @end-static-doc

signal dropped(data: Dictionary)

const DEFAULT_STYLE_ID := "panel_recess"
const HIGHLIGHT_STYLE_ID := "panel_steel"
const DEFAULT_PADDING := Vector2(16.0, 14.0)

## Payload `kind` values this zone accepts. Empty = reject everything.
var accept_kinds: Array[String] = []
## Skin style id used while idle; empty string means a transparent panel.
var zone_style_id := DEFAULT_STYLE_ID
## Color token used to tint the skin texture while a payload hovers the zone.
var highlight_color_token := "brass.highlight"
## Content margins while idle / highlighted; both states intentionally share it.
var content_padding := DEFAULT_PADDING

var _highlighted := false
var _content: VBoxContainer = null
## Payload of the 拿起（click-to-carry）interaction while the player holds goods.
## Empty = no click offer; the zone only reacts to native drag & drop.
var _offer: Dictionary = {}


## Configures the accepted payload kinds and the idle skin style before / after
## entering the tree. Callers must fill the zone through `content_root()`.
func configure(accepted_kinds: Array, style_id: String = DEFAULT_STYLE_ID) -> void:
	accept_kinds.clear()
	for kind in accepted_kinds:
		accept_kinds.append(String(kind))
	zone_style_id = style_id
	if is_node_ready():
		_apply_style()


## Click-to-drop state for the 拿起手势 (feedback #1): a compatible payload makes
## the zone a valid "put it down here" target, highlighted with the skin sheet.
## Incompatible payloads clear the offer instead of arming a wrong drop.
func set_offer(data: Dictionary) -> void:
	if not _accepts(data):
		clear_offer()
		return
	_offer = data.duplicate(true)
	_apply_style()


func clear_offer() -> void:
	if _offer.is_empty():
		return
	_offer.clear()
	_apply_style()


func offer_active() -> bool:
	return not _offer.is_empty()


## Copy of the armed offer payload (tests / hosts that need to inspect it).
func offer_payload() -> Dictionary:
	return _offer.duplicate(true)


## Places the carried stack: emits `dropped` with the offered payload and disarms.
## Returns false when no offer is armed (a click on an idle zone does nothing).
func try_click_offer() -> bool:
	if _offer.is_empty():
		return false
	var data := _offer.duplicate(true)
	clear_offer()
	dropped.emit(data)
	return true


## Lazily builds (and returns) the single content container of the zone.
func content_root() -> VBoxContainer:
	if _content == null:
		_content = VBoxContainer.new()
		_content.name = "Content"
		_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(_content)
	return _content


## True while a compatible payload hovers the zone (used by tests / screens).
func is_highlighted() -> bool:
	return _highlighted


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()


## Skin-backed sheet. Only the texture tint changes while highlighted / armed;
## margins are pinned so the layout does not jump when a drag enters or leaves.
func _apply_style() -> void:
	var horizontal := float(content_padding.x)
	var vertical := float(content_padding.y)
	var highlighted := _highlighted or offer_active()
	var style_id := HIGHLIGHT_STYLE_ID if highlighted else zone_style_id
	if style_id.is_empty():
		# Idle transparent zone (e.g. the whole market panel): keep an empty style
		# so the page layout does not move. An *armed* transparent zone still gets
		# the skin sheet below, otherwise the sell target could never light up.
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = horizontal
		empty.content_margin_top = vertical
		empty.content_margin_right = horizontal
		empty.content_margin_bottom = vertical
		add_theme_stylebox_override("panel", empty)
		return
	var base_style: StyleBoxTexture = SNSkin.style(style_id)
	if base_style == null:
		theme_type_variation = &"SNInsetPanel"
		return
	var style := base_style.duplicate() as StyleBoxTexture
	style.content_margin_left = horizontal
	style.content_margin_top = vertical
	style.content_margin_right = horizontal
	style.content_margin_bottom = vertical
	if highlighted:
		style.modulate_color = SNSkin.color(highlight_color_token)
	add_theme_stylebox_override("panel", style)


func _set_highlighted(active: bool) -> void:
	if _highlighted == active:
		return
	_highlighted = active
	# While highlighted, poll the drag state: Godot only notifies the drag source
	# about drag end, so a drop zone left highlighted by a drag released outside
	# every target would otherwise keep the brass tint until the page rebuilds.
	set_process(active)
	_apply_style()


## Clears the highlight as soon as the drag operation is gone. Never clears the
## click offer: the host page owns that state for the whole carry.
func _process(_delta: float) -> void:
	if not is_inside_tree() or not get_viewport().gui_is_dragging():
		_set_highlighted(false)


## Left click (release) on the armed zone puts the carried stack down. The event is
## accepted *before* `dropped` runs, because a successful command rebuilds the whole
## page and this node may already be out of the tree afterwards.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
		return
	if not offer_active():
		return
	accept_event()
	try_click_offer()


func _accepts(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if accept_kinds.is_empty():
		return false
	return accept_kinds.has(String((data as Dictionary).get("kind", "")))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var accepted := _accepts(data)
	_set_highlighted(accepted)
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_highlighted(false)
	if not _accepts(data):
		return
	dropped.emit((data as Dictionary).duplicate(true))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		_set_highlighted(false)
