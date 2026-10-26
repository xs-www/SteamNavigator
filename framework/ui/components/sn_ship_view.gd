class_name SNShipView
extends Control
## @static-doc
## 作用：船厂中央船体视图；正常态承载 2.5D 船体/程序化船身，改装态绘制每船侧视/俯视蓝图线稿、模块拖放槽位，以及 hull `weapon_sockets[].blueprint` 驱动、可读可拖放的武器槽位贴片（`SNWeaponSocketTarget`）。
##
## ## 外观来源（外部贴图 + SNSkin）
## - 舞台背景 wash、每视图框/底板与底部槽位坞条改用皮肤九宫格：
##   `SNSkin.style("panel_recess" / "panel_blueprint" / "frame_open")` + `draw_style_box()`；
##   皮肤缺失时退回 token 色块/描边，仍保持可读性。
## - 所有颜色取 `SNSkin.color(token)`（本文件不写十六进制），文字字体取
##   `get_theme_default_font()`；线稿、水面、船身等数据绘制保留，但颜色来自 token。
## - `set_blueprint_backdrop(true)` 时仍不画背景 wash / 视图框 / 坞条：底板由父级
##   `SNBlueprintPanel` 提供，开关语义与之前一致。
##
## ## 契约与约束
## - `set_ship_model()` 接收 `shipyard.view.ship`；`ship.blueprint_views.{side,top}` 是
##   已解析的线稿路径（`path`），没有线稿时回退到通用纵剖图/程序化占位。
## - 武器槽位行必须包含稳定 `socket` 与 `blueprint`，后者的 `side` / `top` 是左上原点、
##   0..1 的 JSON Vector2，坐标基准是各自视图的线稿纹理。
## - `blueprint_view_rect(view)` 返回该视图等比适配后的屏幕矩形；
##   `blueprint_socket_rects(view)` 用这个矩形把归一化坐标映射为屏幕框；缺失、越界或
##   形状错误的坐标跳过，不影响其它槽位和模块拖放。没有线稿时 rect 回退为整个 Control，
##   保持旧内容兼容。
## - CUTAWAY 同时绘制 side（上方）与 top（下方）两个视图；武器槽位改由贴片控件绘制：
##   空槽为暗色凹槽 + muted 文字、已装为黄铜底板 + 亮色文字、`highlight_slots()` 命中的
##   socket 只换青色描边（不覆盖已装/空槽差异）；购买/安装命令仍由船厂页面发出。
## - 武器贴片契约（2026-10-27，玩家反馈「装配后看不出装在哪 / 武器不能拖动安装」）：
##   * `set_ship_model()` 的 `model.weapon_sockets[]` 每行至少含 `socket` / `socket_class` /
##     `blueprint` / `weapon_id`；可选展示字段 `display_name`（已装武器本地化名，空槽 ""）、
##     `slot_label`（短标签，如「左舷1」）、`slot_title`（完整友好名，作 tooltip）、
##     `empty_text`、`occupied`。缺字段时按 `SNWeaponSocketTarget` 的兜底规则推导，不崩。
##   * 每个 socket 只要在 side / top 某一视图有 `blueprint` 坐标，就在该视图生成一枚贴片；
##     贴片始终随 CUTAWAY 可见（EXTERIOR 隐藏）。
##   * `weapon_socket_display_rects(view)` 从 `blueprint_socket_rects(view)` 的锚点派生
##     ≥96×30 的可读贴片矩形：锚点相同/过近的槽位（如 Port_1 / Starboard_1 共用同一
##     side 坐标）沿垂直方向扇出，互不重叠，并 clamp 在 `blueprint_view_rect(view)` 内。
##     `blueprint_socket_rects()` 保持原有的 28–42 px 小框语义，不变。
##   * 拖放：贴片只接受 `{kind:"ship_weapon", weapon_id, weapon_class, source, name}`，
##     `weapon_class == socket_class` 才接受；`_drop_data` 经 `weapon_dropped` 汇总为
##     `weapon_drop_requested(payload, socket)`。`set_weapon_drop_enabled(false)` 只关闭
##     拖放接收（非武器分类 / 非装配页签），不影响贴片可见性；默认接受。
## - 有每船线稿时船厂页把整列换成 `SNBlueprintPanel` 九宫格蓝图底板；页面调用
##   `set_blueprint_backdrop(true)` 后本视图只把线稿、视图标签、武器槽位框和槽位 chip
##   画在底板的深蓝内容区上。底板由 Theme 提供，本视图不持有底板纹理。
## - `set_renderer()` / `set_slots()` / `set_blueprint_backdrop()` / `highlight_slots()` /
##   `blueprint_view_rect()` / `blueprint_socket_rects()` 与 `SNSlotTarget` 槽位契约完全
##   不变；本文件只替换绘制来源，不改命中、拖放与渲染器转发逻辑。
##
## Refit stage for the centre of the shipyard screen.
##
## Two modes share one coordinate space:
##   EXTERIOR — a side view of the current ship (procedural placeholder today).
##   CUTAWAY  — dual blueprint views from the hull's `blueprint_views`; when absent,
##              the authored longitudinal section (assets/ui/shipyard/ship_section.png)
##              or the procedural fallback is used. SNSlotTarget chips stay on top so
##              owned free modules can be dragged straight onto a slot.
##
## ## 2.5D integration contract
## `set_renderer(node)` swaps the procedural placeholder for a real renderer.
## The node is added as a child filling this control and must expose:
##   func ship_view_update(model: Dictionary) -> void
##   func ship_view_set_mode(mode: int) -> void
##   func ship_view_highlight(slot_ids: Array) -> void
## Slot chips, drag & drop, and hit layout stay here, so a future 2.5D scene
## only has to draw the hull and can ignore input entirely. Passing null
## restores the built-in placeholder. Nothing in the screen depends on how the
## ship is drawn, so the swap needs no screen change.
## @end-static-doc

signal slot_drop_requested(payload: Dictionary, slot: Dictionary)
signal slot_activated(slot: Dictionary)
## A weapon patch accepted a `ship_weapon` drag payload. The screen owns the
## command intent (`ship.install_weapon`); the stage only reports the socket row.
signal weapon_drop_requested(payload: Dictionary, socket: Dictionary)
## Hover over a weapon patch / left it (right-hand cards mirror the highlight).
signal weapon_socket_hovered(socket_name: String)
signal weapon_socket_unhovered

## Preloaded instead of referencing the global `SNWeaponSocketTarget` class name:
## tests run against `.godot/global_script_class_cache.cfg`, which is only refreshed
## by an editor import, so a freshly added class_name file may not resolve yet.
const WEAPON_TARGET_SCRIPT: Script = preload("res://framework/ui/components/sn_weapon_socket_target.gd")

enum Mode { EXTERIOR, CUTAWAY }

## Skin colour tokens (UI Foundation Spec V1 §7). Values are resolved from
## `skin.json` once per stage instance; data drawing keeps its own geometry.
static var _token_cache: Dictionary = {}

static func _token(token: String) -> Color:
	if _token_cache.has(token):
		return _token_cache[token]
	var value := SNSkin.color(token)
	_token_cache[token] = value
	return value

const SLOT_H := 62.0
const CARGO_SLOT_H := 58.0
const BLUEPRINT_SOCKET_MIN_SIZE := Vector2(28.0, 20.0)
const BLUEPRINT_SOCKET_MAX_SIZE := Vector2(42.0, 30.0)
const BLUEPRINT_SIDE_RATIO := 0.52
const BLUEPRINT_VIEW_GAP := 0.02
## Readable weapon patch layout. The old non-interactive socket frames were
## 28-42 px; a patch must fit two text lines (slot label + weapon / empty text)
## so the player can read the loadout on the blueprint.
const WEAPON_CARD_MIN_WIDTH := 96.0
const WEAPON_CARD_MAX_WIDTH := 156.0
const WEAPON_CARD_HEIGHT := 36.0
const WEAPON_CARD_MIN_HEIGHT := 26.0
const WEAPON_CARD_WIDTH_RATIO := 0.24
const WEAPON_CARD_GAP := 4.0
const WEAPON_CARD_MARGIN := 2.0
const SLOT_DOCK_MARGIN := 8.0
const SLOT_DOCK_GAP := 8.0
## Refit cross-section texture. Replace this PNG to reskin the whole cutaway;
## the screen and slot logic never depend on how the section is drawn.
const SECTION_TEXTURE_PATH := "res://assets/ui/shipyard/ship_section.png"

## Token-backed colours for the procedural line art and skin fallbacks.
var TEXT: Color = _token("text.light")
var MUTED: Color = _token("text.muted")
var BRASS: Color = _token("brass.highlight")
var TEAL: Color = _token("state.water")
var HULL_DARK: Color = _token("steel.base")
var HULL_MID: Color = _token("steel.raised")
var WATER: Color = _token("steel.recess")

var mode: int = Mode.EXTERIOR
var _model: Dictionary = {}
var _slots: Array = []
var _slot_targets: Array = []
var _renderer: Node = null
var _slot_layer: Control
var _weapon_layer: Control
## One `SNWeaponSocketTarget` per (socket, blueprint view); rebuilt on model change.
var _weapon_targets: Array = []
## Page-owned gate for weapon drag & drop (weapons category + install tab only).
## Visibility of the patches does not depend on it.
var _weapon_drop_enabled := true
var _section_texture: Texture2D = null
var _blueprint_textures: Dictionary = {}
var _blueprint_meta: Dictionary = {}
var _time := 0.0
var _highlighted_slot_ids: Array = []
## True when the shipyard column already paints the nine-slice blueprint board
## (`assets/ui/shipyard/blueprint_panel.png`); the cutaway then draws only line
## art, labels and chips on top of that board instead of its own dark backdrop.
var _blueprint_backdrop := false
## Path -> Texture2D; content is frozen after load, so per-hull line art can be
## decoded once even though the shipyard rebuilds the stage on every command.
static var _blueprint_texture_cache: Dictionary = {}


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(520, 400)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_load_section_texture()
	_slot_layer = Control.new()
	_slot_layer.name = "SlotLayer"
	_slot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot_layer)
	_slot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Weapon patches live on their own layer above the line art. The layer itself
	# never eats input, but the patch Controls inside it do (hover + drop).
	_weapon_layer = Control.new()
	_weapon_layer.name = "WeaponLayer"
	_weapon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_weapon_layer)
	_weapon_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_weapon_layer.visible = mode == Mode.CUTAWAY
	_rebuild_weapon_targets()
	resized.connect(_on_stage_resized)
	set_process(true)
	if not _slots.is_empty():
		set_slots(_slots)


func _process(delta: float) -> void:
	_time += delta
	if _renderer == null or mode == Mode.EXTERIOR:
		queue_redraw()


## Swap the visual backend. See the 2.5D integration contract above.
func set_renderer(node: Node) -> void:
	if _renderer != null and is_instance_valid(_renderer):
		remove_child(_renderer)
		_renderer.queue_free()
	_renderer = node
	if _renderer != null:
		add_child(_renderer)
		move_child(_renderer, 0)
		if _renderer is Control:
			(_renderer as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			(_renderer as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notify_renderer("ship_view_update", [_model])
		_notify_renderer("ship_view_set_mode", [mode])
	queue_redraw()


func has_renderer() -> bool:
	return _renderer != null and is_instance_valid(_renderer)


## True once the authored cross-section PNG is imported and available.
func has_section_texture() -> bool:
	return _section_texture != null


func section_texture_size() -> Vector2:
	return _section_texture.get_size() if _section_texture != null else Vector2.ZERO


func _load_section_texture() -> void:
	if not ResourceLoader.exists(SECTION_TEXTURE_PATH):
		return
	_section_texture = load(SECTION_TEXTURE_PATH) as Texture2D


func set_ship_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	_load_blueprint_textures()
	_notify_renderer("ship_view_update", [_model])
	_rebuild_weapon_targets()
	queue_redraw()


## True when the hull ships per-view line art (side/top); otherwise the stage
## keeps the legacy generic section texture.
func has_blueprint_views() -> bool:
	return not _blueprint_textures.is_empty()


func blueprint_texture_size(view: String) -> Vector2:
	var texture: Texture2D = _blueprint_textures.get(view, null)
	return texture.get_size() if texture != null else Vector2.ZERO


## Bottom dock reserved for SNSlotTarget chips; line art never draws under it.
func slot_dock_height() -> float:
	if not has_blueprint_views() or _slot_targets.is_empty():
		return 0.0
	var rows := 1 if _slot_targets.size() <= 6 else 2
	return SLOT_DOCK_MARGIN + float(rows) * SLOT_H + float(rows - 1) * SLOT_DOCK_GAP + 6.0


## Lets the screen declare that the parent column is a blueprint board. The
## cutaway then stops painting its own wash, per-view boxes and dock bar, so the
## board's blue field shows through and the pale line art keeps the intended
## contrast. The board itself is a Theme stylebox; this flag only removes paint.
func set_blueprint_backdrop(enabled: bool) -> void:
	if _blueprint_backdrop == enabled:
		return
	_blueprint_backdrop = enabled
	queue_redraw()


func uses_blueprint_backdrop() -> bool:
	return _blueprint_backdrop


## Cutaway drawn straight onto the board: only meaningful when line art exists.
func _uses_blueprint_board() -> bool:
	return _blueprint_backdrop and has_blueprint_views()


## Stage area left for line art: the whole control minus the slot dock.
func _blueprint_view_available_rect() -> Rect2:
	return Rect2(0.0, 0.0, size.x, maxf(0.0, size.y - slot_dock_height()))


## Aspect-preserving on-screen rect of one blueprint view; falls back to the
## whole control when no line art exists so pre-art hulls keep the old mapping.
func blueprint_view_rect(view: String) -> Rect2:
	if _blueprint_textures.is_empty():
		return Rect2(Vector2.ZERO, size)
	if not _blueprint_textures.has(view):
		return Rect2(Vector2.ZERO, size)
	var available := _blueprint_view_available_rect()
	if available.size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var has_side: bool = _blueprint_textures.has("side")
	var has_top: bool = _blueprint_textures.has("top")
	if not (has_side and has_top):
		return _fit_texture(_blueprint_textures[view], available)
	var gap: float = available.size.y * BLUEPRINT_VIEW_GAP
	var side_height: float = available.size.y * BLUEPRINT_SIDE_RATIO
	var top_height: float = available.size.y - side_height - gap
	var side_region := Rect2(0.0, 0.0, available.size.x, side_height)
	var top_region := Rect2(0.0, side_height + gap, available.size.x, top_height)
	var region: Rect2 = side_region if view == "side" else top_region
	# Both generated views share the same world-x framing; displaying them at the
	# same width keeps a given world x at the same horizontal screen position.
	var side_fit := _fit_texture(_blueprint_textures["side"], side_region)
	var top_fit := _fit_texture(_blueprint_textures["top"], top_region)
	var shared_width: float = minf(side_fit.size.x, top_fit.size.x)
	if shared_width <= 0.0:
		return _fit_texture(_blueprint_textures[view], region)
	return _fit_texture_with_width(_blueprint_textures[view], region, shared_width)


## Fits a texture into a region using a caller-provided display width (and
## clamps it back to the region height when the aspect would overflow).
func _fit_texture_with_width(texture: Texture2D, region: Rect2, width: float) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or width <= 0.0:
		return Rect2(region.position, Vector2.ZERO)
	var height: float = width * texture_size.y / texture_size.x
	if height > region.size.y:
		height = region.size.y
		width = height * texture_size.x / texture_size.y
	var fitted := Vector2(width, height)
	return Rect2(region.position + (region.size - fitted) * 0.5, fitted)


func _fit_texture(texture: Texture2D, region: Rect2) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(region.position, Vector2.ZERO)
	var fit_scale: float = minf(region.size.x / texture_size.x, region.size.y / texture_size.y)
	var fitted_size := texture_size * fit_scale
	return Rect2(region.position + (region.size - fitted_size) * 0.5, fitted_size)


func _load_blueprint_textures() -> void:
	_blueprint_textures.clear()
	_blueprint_meta.clear()
	var views: Variant = _model.get("blueprint_views", {})
	if not (views is Dictionary):
		return
	for view in ["side", "top"]:
		var entry: Variant = (views as Dictionary).get(view, null)
		if not (entry is Dictionary):
			continue
		var asset_path := String((entry as Dictionary).get("path", ""))
		if asset_path.is_empty():
			continue
		var texture: Texture2D = _blueprint_texture_cache.get(asset_path, null)
		if texture == null:
			if ResourceLoader.exists(asset_path):
				texture = load(asset_path) as Texture2D
			if texture == null:
				texture = ContentAssetLoader.load_texture(asset_path)
			if texture != null:
				_blueprint_texture_cache[asset_path] = texture
		if texture == null:
			continue
		_blueprint_textures[view] = texture
		_blueprint_meta[view] = entry


## Replace the slot descriptors. Each descriptor: id, category, slot, index,
## title, module (Dictionary or null), replace_module_id, fixed.
func set_slots(slots: Array) -> void:
	_slots = slots.duplicate(true)
	if _slot_layer == null:
		return
	for target in _slot_targets:
		if is_instance_valid(target):
			_slot_layer.remove_child(target)
			target.queue_free()
	_slot_targets.clear()
	for slot in _slots:
		if not (slot is Dictionary):
			continue
		var target := SNSlotTarget.new()
		target.configure(slot)
		target.part_dropped.connect(_on_slot_drop)
		target.slot_activated.connect(func(slot_data: Dictionary): slot_activated.emit(slot_data))
		_slot_layer.add_child(target)
		target.visible = mode == Mode.CUTAWAY
		_slot_targets.append(target)
	_layout_slots()
	# The slot dock changes `slot_dock_height()`, which shrinks the blueprint
	# views, so the weapon patches must be re-derived after every slot rebuild.
	_layout_weapon_targets()
	queue_redraw()


func set_mode(next: int) -> void:
	mode = next
	for target in _slot_targets:
		if target is SNSlotTarget:
			target.visible = mode == Mode.CUTAWAY
	if _weapon_layer != null:
		_weapon_layer.visible = mode == Mode.CUTAWAY
	_notify_renderer("ship_view_set_mode", [mode])
	_layout_slots()
	_layout_weapon_targets()
	queue_redraw()


func highlight_slots(slot_ids: Array) -> void:
	_highlighted_slot_ids = slot_ids.duplicate()
	for target in _slot_targets:
		if target is SNSlotTarget:
			target.set_compatible_hint(slot_ids.has(String(target.slot.get("id", ""))))
	# Weapon socket ids share the same call: the weapons category highlights every
	# patch, hovering a socket card highlights just that one.
	for target in _weapon_targets:
		if is_instance_valid(target) and target.has_method("set_highlighted"):
			target.set_highlighted(slot_ids.has(String(target.row.get("socket", ""))))
	_notify_renderer("ship_view_highlight", [slot_ids])
	queue_redraw()


## Returns the on-screen frame of every weapon socket that defines a coordinate
## for the requested blueprint view. Coordinates are normalized against that
## view's line-art image; when no line art is bound the whole control is used so
## legacy content keeps its previous mapping.
func blueprint_socket_rects(view: String = "side") -> Dictionary:
	var rects: Dictionary = {}
	if size.x <= 0.0 or size.y <= 0.0:
		return rects
	var view_rect := blueprint_view_rect(view)
	if view_rect.size.x <= 0.0 or view_rect.size.y <= 0.0:
		return rects
	var frame_size := Vector2(
		clampf(view_rect.size.x * 0.045, BLUEPRINT_SOCKET_MIN_SIZE.x, BLUEPRINT_SOCKET_MAX_SIZE.x),
		clampf(view_rect.size.y * 0.055, BLUEPRINT_SOCKET_MIN_SIZE.y, BLUEPRINT_SOCKET_MAX_SIZE.y)
	)
	for raw_socket in _model.get("weapon_sockets", []):
		if not (raw_socket is Dictionary):
			continue
		var socket: Dictionary = raw_socket
		var blueprint: Variant = socket.get("blueprint", {})
		if not (blueprint is Dictionary):
			continue
		var point: Variant = (blueprint as Dictionary).get(view, null)
		if not (point is Array) or (point as Array).size() != 2:
			continue
		var normalized := Vector2(float(point[0]), float(point[1]))
		if normalized.x < 0.0 or normalized.x > 1.0 or normalized.y < 0.0 or normalized.y > 1.0:
			continue
		var socket_id := String(socket.get("socket", socket.get("name", "")))
		if socket_id.is_empty():
			continue
		var center := view_rect.position + Vector2(
			normalized.x * view_rect.size.x,
			normalized.y * view_rect.size.y
		)
		rects[socket_id] = Rect2(center - frame_size * 0.5, frame_size)
	return rects


## Readable on-screen frames for the weapon patches, keyed by socket id.
##
## Same anchors as `blueprint_socket_rects(view)` (which keeps its original
## 28-42 px frame contract), but expanded into >=96x30 patches that fit the two
## text lines. Sockets whose anchors are identical or too close (e.g. Port_1 /
## Starboard_1 sharing one side-view coordinate) are fanned out vertically inside
## their cluster so no two patches overlap, and every frame is clamped into
## `blueprint_view_rect(view)`.
func weapon_socket_display_rects(view: String = "side") -> Dictionary:
	var rects: Dictionary = {}
	if size.x <= 0.0 or size.y <= 0.0:
		return rects
	var view_rect := blueprint_view_rect(view)
	if view_rect.size.x <= 0.0 or view_rect.size.y <= 0.0:
		return rects
	var anchors := blueprint_socket_rects(view)
	if anchors.is_empty():
		return rects
	var card_width := clampf(view_rect.size.x * WEAPON_CARD_WIDTH_RATIO,
		WEAPON_CARD_MIN_WIDTH, WEAPON_CARD_MAX_WIDTH)
	card_width = minf(card_width, maxf(view_rect.size.x - WEAPON_CARD_MARGIN * 2.0, 40.0))
	var card_height := minf(WEAPON_CARD_HEIGHT,
		maxf(view_rect.size.y - WEAPON_CARD_MARGIN * 2.0, WEAPON_CARD_MIN_HEIGHT))
	var entries: Array = []
	for raw_id in anchors.keys():
		var socket_id := String(raw_id)
		entries.append({"socket": socket_id, "anchor": (anchors[socket_id] as Rect2).get_center()})
	var placed: Array = []
	for raw_cluster in _weapon_card_clusters(entries, card_width, card_height):
		var cluster: Dictionary = raw_cluster
		var members: Array = cluster["members"]
		members.sort_custom(_sort_weapon_cards)
		var count := members.size()
		var total_height := float(count) * card_height + float(count - 1) * WEAPON_CARD_GAP
		var center: Vector2 = cluster["center"]
		var left := _clamp_span(center.x - card_width * 0.5,
			view_rect.position.x + WEAPON_CARD_MARGIN,
			view_rect.end.x - WEAPON_CARD_MARGIN - card_width)
		var top := _clamp_span(center.y - total_height * 0.5,
			view_rect.position.y + WEAPON_CARD_MARGIN,
			view_rect.end.y - WEAPON_CARD_MARGIN - total_height)
		for index in count:
			var member: Dictionary = members[index]
			placed.append({
				"socket": String(member["socket"]),
				"rect": Rect2(
					Vector2(left, top + float(index) * (card_height + WEAPON_CARD_GAP)),
					Vector2(card_width, card_height)
				),
			})
	_weapon_cards_separate(placed, view_rect)
	for entry in placed:
		rects[String(entry["socket"])] = entry["rect"]
	return rects


## Enables / disables weapon drag & drop on every patch. The patches stay
## visible: the shipyard only calls this with the weapons category + install tab
## state, so a weapon row dropped elsewhere cannot install by accident.
func set_weapon_drop_enabled(enabled: bool) -> void:
	_weapon_drop_enabled = enabled
	for target in _weapon_targets:
		if is_instance_valid(target) and target.has_method("set_drop_enabled"):
			target.set_drop_enabled(enabled)


func is_weapon_drop_enabled() -> bool:
	return _weapon_drop_enabled


## Live weapon patch controls (test / screen access, one per socket + view).
func weapon_targets() -> Array:
	return _weapon_targets.duplicate()


## One patch by socket id, optionally scoped to a blueprint view.
func weapon_target(socket_id: String, view: String = "") -> Control:
	for target in _weapon_targets:
		if not is_instance_valid(target):
			continue
		if String(target.row.get("socket", "")) != socket_id:
			continue
		if not view.is_empty() and String(target.view) != view:
			continue
		return target as Control
	return null


# ---------------------------------------------------------------------------
# Weapon patch rebuild / clustering / layout.
# ---------------------------------------------------------------------------
## Views that carry weapon patches: both blueprint views when per-view line art
## exists, otherwise the legacy single `blueprint_view` (same rule the old
## non-interactive frames used).
func _weapon_views() -> Array:
	var views: Array = []
	if not _blueprint_textures.is_empty():
		for view in ["side", "top"]:
			if _blueprint_textures.has(view):
				views.append(view)
		return views
	var legacy := String(_model.get("blueprint_view", "side"))
	return [legacy] if legacy in ["side", "top"] else ["side"]


func _socket_has_blueprint(row: Dictionary, view: String) -> bool:
	var blueprint: Variant = row.get("blueprint", {})
	if not (blueprint is Dictionary):
		return false
	var point: Variant = (blueprint as Dictionary).get(view, null)
	return point is Array and (point as Array).size() == 2


func _rebuild_weapon_targets() -> void:
	if _weapon_layer == null:
		return
	for target in _weapon_targets:
		if is_instance_valid(target):
			_weapon_layer.remove_child(target)
			target.queue_free()
	_weapon_targets.clear()
	var rows: Array = []
	for raw_row in _model.get("weapon_sockets", []):
		if raw_row is Dictionary:
			rows.append(raw_row)
	for view in _weapon_views():
		for raw_row in rows:
			var row: Dictionary = raw_row
			var socket_id := String(row.get("socket", row.get("name", "")))
			if socket_id.is_empty() or not _socket_has_blueprint(row, String(view)):
				continue
			var config: Dictionary = row.duplicate(true)
			config["view"] = String(view)
			var target: Variant = WEAPON_TARGET_SCRIPT.new()
			target.name = "WeaponSocket_%s_%s" % [String(view), socket_id]
			target.configure(config)
			target.set_drop_enabled(_weapon_drop_enabled)
			target.set_highlighted(_highlighted_slot_ids.has(socket_id))
			target.weapon_dropped.connect(_on_weapon_dropped)
			target.hovered.connect(_on_weapon_hovered)
			target.unhovered.connect(_on_weapon_unhovered)
			_weapon_layer.add_child(target)
			target.visible = mode == Mode.CUTAWAY
			_weapon_targets.append(target)
	_layout_weapon_targets()


func _on_weapon_dropped(payload: Dictionary, socket: Dictionary) -> void:
	weapon_drop_requested.emit(payload, socket)


func _on_weapon_hovered(socket_name: String) -> void:
	weapon_socket_hovered.emit(socket_name)


func _on_weapon_unhovered() -> void:
	weapon_socket_unhovered.emit()


func _on_stage_resized() -> void:
	_layout_slots()
	_layout_weapon_targets()


func _layout_weapon_targets() -> void:
	if _weapon_targets.is_empty():
		return
	var stage_ready := size.x >= 80.0 and size.y >= 80.0
	var rects_by_view: Dictionary = {}
	if stage_ready:
		for view in _weapon_views():
			rects_by_view[String(view)] = weapon_socket_display_rects(String(view))
	for target in _weapon_targets:
		if not is_instance_valid(target):
			continue
		if not stage_ready or mode != Mode.CUTAWAY:
			target.visible = false
			continue
		var rects: Dictionary = rects_by_view.get(String(target.view), {})
		var socket_id := String(target.row.get("socket", ""))
		if not rects.has(socket_id):
			target.visible = false
			continue
		var rect: Rect2 = rects[socket_id]
		target.position = rect.position
		target.size = rect.size
		target.visible = true


## Groups anchors whose patches would overlap, so the cluster can be fanned out.
func _weapon_card_clusters(entries: Array, card_width: float, card_height: float) -> Array:
	var clusters: Array = []
	for entry in entries:
		var anchor: Vector2 = entry["anchor"]
		var joined := false
		for raw_cluster in clusters:
			var cluster: Dictionary = raw_cluster
			var center: Vector2 = cluster["center"]
			if absf(anchor.x - center.x) < card_width and absf(anchor.y - center.y) < card_height:
				var members: Array = cluster["members"]
				members.append(entry)
				cluster["center"] = (center * float(members.size() - 1) + anchor) / float(members.size())
				joined = true
				break
		if not joined:
			clusters.append({"center": anchor, "members": [entry]})
	return clusters


## Deterministic order inside a fan: top to bottom, then left to right, then id.
func _sort_weapon_cards(a: Dictionary, b: Dictionary) -> bool:
	var a_anchor: Vector2 = a["anchor"]
	var b_anchor: Vector2 = b["anchor"]
	if not is_equal_approx(a_anchor.y, b_anchor.y):
		return a_anchor.y < b_anchor.y
	if not is_equal_approx(a_anchor.x, b_anchor.x):
		return a_anchor.x < b_anchor.x
	return String(a["socket"]) < String(b["socket"])


## Clamps one axis of the fanned column into [low, high]; when the span does not
## fit at all it is centred instead of pinned to one edge.
func _clamp_span(value: float, low: float, high: float) -> float:
	if high <= low:
		return (low + high) * 0.5
	return clampf(value, low, high)


## Resolves residual overlaps between fanned clusters by nudging the later patch
## down (or up when the view bottom is reached) until every patch is disjoint.
func _weapon_cards_separate(placed: Array, view_rect: Rect2) -> void:
	if placed.size() < 2:
		return
	for _iteration in 6:
		var moved := false
		for index in placed.size():
			var first: Dictionary = placed[index]
			var first_rect: Rect2 = first["rect"]
			for other_index in range(index + 1, placed.size()):
				var second: Dictionary = placed[other_index]
				var second_rect: Rect2 = second["rect"]
				if not first_rect.intersects(second_rect):
					continue
				var shift := first_rect.end.y - second_rect.position.y + WEAPON_CARD_GAP
				var moved_rect := Rect2(second_rect.position + Vector2(0.0, shift), second_rect.size)
				if moved_rect.end.y > view_rect.end.y - WEAPON_CARD_MARGIN:
					var up_shift := first_rect.position.y - WEAPON_CARD_GAP - second_rect.end.y
					moved_rect = Rect2(second_rect.position + Vector2(0.0, up_shift), second_rect.size)
					if moved_rect.position.y < view_rect.position.y + WEAPON_CARD_MARGIN:
						moved_rect.position.y = view_rect.position.y + WEAPON_CARD_MARGIN
				second["rect"] = moved_rect
				moved = true
		if not moved:
			return


func _on_slot_drop(payload: Dictionary, slot: Dictionary) -> void:
	slot_drop_requested.emit(payload, slot)


func _notify_renderer(method: StringName, args: Array) -> void:
	if _renderer != null and is_instance_valid(_renderer) and _renderer.has_method(method):
		_renderer.callv(method, args)


# ---------------------------------------------------------------------------
# Slot chip layout: fixed slots in one row, cargo slots in a second row.
# ---------------------------------------------------------------------------
func _layout_slots() -> void:
	if _slot_targets.is_empty() or size.x < 80.0:
		return
	if has_blueprint_views():
		_layout_slot_dock()
		return
	var fixed: Array = []
	var cargo: Array = []
	for target in _slot_targets:
		if String(target.slot.get("category", "")) == "cargo":
			cargo.append(target)
		else:
			fixed.append(target)
	var w := size.x
	var h := size.y
	_place_row(fixed, 16.0, w - 32.0, h * 0.60, SLOT_H, 8.0)
	_place_row(cargo, w * 0.12, w * 0.76, h * 0.82, CARGO_SLOT_H, 8.0)


## Bottom dock for the interactive module chips: one row up to six slots, two
## rows above that. The blueprint views reserve this height so the deck plan is
## never hidden behind the chips.
func _layout_slot_dock() -> void:
	var count := _slot_targets.size()
	var rows := 1 if count <= 6 else 2
	var per_row := int(ceil(float(count) / float(rows)))
	var dock_top := size.y - slot_dock_height() + SLOT_DOCK_MARGIN
	for row in rows:
		var start := row * per_row
		var end := mini(count, start + per_row)
		if start >= end:
			continue
		var slice := _slot_targets.slice(start, end)
		_place_row(slice, 12.0, size.x - 24.0, dock_top + float(row) * (SLOT_H + SLOT_DOCK_GAP), SLOT_H, 6.0)


func _place_row(targets: Array, left: float, span: float, top: float, chip_h: float, gap: float) -> void:
	var count := targets.size()
	if count == 0:
		return
	var chip_w := minf(148.0, (span - gap * float(count - 1)) / float(count))
	chip_w = maxf(84.0, chip_w)
	var total := chip_w * float(count) + gap * float(count - 1)
	var x := left + maxf(0.0, (span - total) * 0.5)
	for target in targets:
		target.custom_minimum_size = Vector2(chip_w, chip_h)
		target.size = Vector2(chip_w, chip_h)
		target.position = Vector2(x, top)
		target.visible = mode == Mode.CUTAWAY
		x += chip_w + gap


func _chip_anchor(slot: Dictionary, cargo_count: int) -> Vector2:
	var w := size.x
	var h := size.y
	match String(slot.get("slot", "")):
		"hull":
			return Vector2(w * 0.20, h * 0.47)
		"boiler":
			return Vector2(w * 0.37, h * 0.50)
		"cargo":
			var step := 0.055 if cargo_count <= 1 else 0.09
			return Vector2(w * (0.52 + step * float(int(slot.get("index", 0)))), h * 0.52)
		"navigation":
			return Vector2(w * 0.74, h * 0.42)
		"safety":
			return Vector2(w * 0.63, h * 0.50)
		"cabin":
			return Vector2(w * 0.85, h * 0.46)
		_:
			return Vector2(w * 0.5, h * 0.5)


func _draw() -> void:
	if size.x < 80.0 or size.y < 80.0:
		return
	if not (mode == Mode.CUTAWAY and _uses_blueprint_board()):
		_draw_backdrop()
	if mode == Mode.CUTAWAY:
		_draw_cutaway()
	else:
		_draw_exterior()


## Stage backdrop: the recessed steel plate from the skin replaces the old
## hard-coded translucent rectangle. The token fallback keeps the view readable
## before the skin is imported.
func _draw_backdrop() -> void:
	_draw_skin_box("panel_recess", Rect2(Vector2.ZERO, size), Color(_token("bg.abyss"), 0.55))


## Draws one skin nine-slice into `rect`; falls back to a token-coloured fill or
## outline when the style (or the whole skin) is unavailable. The stylebox is
## read from SNSkin, never constructed here.
func _draw_skin_box(style_id: String, rect: Rect2, fallback: Color, filled: bool = true) -> void:
	var box := SNSkin.style(style_id)
	if box != null:
		draw_style_box(box, rect)
		return
	if filled:
		draw_rect(rect, fallback, true)
	else:
		draw_rect(rect, fallback, false, 1.0)


func _draw_exterior() -> void:
	var w := size.x
	var h := size.y
	var water_y := h * 0.76
	draw_rect(Rect2(0.0, water_y, w, h - water_y), WATER)
	_draw_waves(water_y, w, h)
	var hull := PackedVector2Array([
		Vector2(w * 0.10, water_y - h * 0.16),
		Vector2(w * 0.90, water_y - h * 0.19),
		Vector2(w * 0.83, water_y),
		Vector2(w * 0.18, water_y),
	])
	draw_colored_polygon(hull, HULL_DARK)
	_draw_polyline_closed(hull, BRASS, 2.0)
	draw_line(Vector2(w * 0.10, water_y - h * 0.16), Vector2(w * 0.90, water_y - h * 0.19), BRASS, 3.0)
	# Cabin superstructure.
	var cabin := Rect2(w * 0.34, water_y - h * 0.32, w * 0.30, h * 0.14)
	draw_rect(cabin, HULL_MID)
	draw_rect(cabin, BRASS, false, 1.5)
	# Funnel and animated smoke.
	var funnel := Rect2(w * 0.56, water_y - h * 0.46, w * 0.035, h * 0.15)
	draw_rect(funnel, HULL_MID)
	draw_rect(funnel, BRASS, false, 1.5)
	for index in 3:
		var phase := fmod(_time * 0.45 + float(index) / 3.0, 1.0)
		var center := Vector2(funnel.get_center().x - phase * w * 0.05, funnel.position.y - phase * h * 0.16)
		var alpha := 0.32 * (1.0 - phase)
		draw_circle(center, 4.0 + phase * 12.0, Color(_token("text.light"), alpha))
	# Mast + flag.
	draw_line(Vector2(w * 0.72, water_y - h * 0.19), Vector2(w * 0.72, water_y - h * 0.42), BRASS, 2.0)
	var flag := PackedVector2Array([
		Vector2(w * 0.72, water_y - h * 0.42),
		Vector2(w * 0.80, water_y - h * 0.39),
		Vector2(w * 0.72, water_y - h * 0.36),
	])
	draw_colored_polygon(flag, TEAL)
	# Paddle wheel at the stern.
	var wheel_center := Vector2(w * 0.17, water_y - h * 0.035)
	var radius := h * 0.075
	draw_circle(wheel_center, radius, HULL_MID)
	draw_arc(wheel_center, radius, 0.0, TAU, 32, BRASS, 1.5)
	for spoke in 8:
		var angle := _time * 0.9 + float(spoke) * TAU / 8.0
		draw_line(wheel_center, wheel_center + Vector2(cos(angle), sin(angle)) * radius, BRASS, 1.0)
	# Portholes.
	for index in 4:
		draw_circle(Vector2(w * (0.28 + float(index) * 0.10), water_y - h * 0.075), 3.0, BRASS)
	# Cargo tags on deck for each installed cargo module.
	var modules: Array = _model.get("modules", [])
	var cargo_total := 0
	for module in modules:
		if module is Dictionary and String(module.get("category", "")) == "cargo":
			cargo_total += 1
	for index in cargo_total:
		draw_rect(Rect2(w * (0.62 + float(index) * 0.045), water_y - h * 0.245, w * 0.03, h * 0.045), BRASS, false, 1.5)


func _draw_cutaway() -> void:
	if has_blueprint_views():
		_draw_blueprint_views()
	elif _section_texture != null:
		_draw_section_texture()
	else:
		_draw_cutaway_placeholder()
	# Weapon socket patches are child Controls (`_weapon_layer`), not line art:
	# they own the occupied/empty states and the `ship_weapon` drop contract.
	if not has_blueprint_views():
		_draw_slot_leaders()


## Dual-view blueprint: the side elevation on top, the deck plan below, both
## aspect-fitted so author coordinates keep a 1:1 meaning with the source PNG.
## On a blueprint board the two views sit directly on the board's blue field (no
## boxes, no dock bar); without a board the legacy stage backdrop is kept.
func _draw_blueprint_views() -> void:
	var font := get_theme_default_font()
	var board := _uses_blueprint_board()
	if not board:
		_draw_blueprint_dock_bar()
	for view in ["side", "top"]:
		if not _blueprint_textures.has(view):
			continue
		var texture: Texture2D = _blueprint_textures[view]
		var rect := blueprint_view_rect(view)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if not board:
			# Blueprint plate below the line art, open frame above it: both come
			# from the skin, so re-skinning the PNG is enough.
			_draw_skin_box("panel_blueprint", rect.grow(2.0), Color(_token("blueprint.base"), 0.55))
		draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.96))
		if not board:
			_draw_skin_box("frame_open", rect, Color(TEAL, 0.28), false)
		var label := "侧视 SIDE" if view == "side" else "俯视 TOP"
		draw_string(font, rect.position + Vector2(8.0, 15.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(TEAL, 0.82))
	var has_side: bool = _blueprint_textures.has("side")
	var has_top: bool = _blueprint_textures.has("top")
	if has_side and has_top:
		var available := _blueprint_view_available_rect()
		var divider_y: float = available.position.y + available.size.y * (BLUEPRINT_SIDE_RATIO + BLUEPRINT_VIEW_GAP * 0.5)
		draw_line(Vector2(available.position.x + 8.0, divider_y), Vector2(available.end.x - 8.0, divider_y), Color(TEAL, 0.18), 1.0)


## Legacy dark strip behind the slot chips; the board's field replaces it.
func _draw_blueprint_dock_bar() -> void:
	var dock := slot_dock_height()
	if dock <= 0.0:
		return
	var dock_rect := Rect2(0.0, size.y - dock, size.x, dock)
	_draw_skin_box("panel_recess", dock_rect, Color(_token("steel.recess"), 0.82))
	draw_line(Vector2(8.0, dock_rect.position.y), Vector2(size.x - 8.0, dock_rect.position.y), Color(TEAL, 0.22), 1.0)


## Authored PNG section, cropped to cover the stage while keeping its aspect.
## The whole refit view is a texture: no runtime hull/section geometry here.
func _draw_section_texture() -> void:
	var texture_size := _section_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var destination := Rect2(Vector2.ZERO, size)
	var cover_scale := maxf(destination.size.x / texture_size.x, destination.size.y / texture_size.y)
	var source_size := destination.size / cover_scale
	var source_position := (texture_size - source_size) * 0.5
	draw_texture_rect_region(_section_texture, destination, Rect2(source_position, source_size))
	draw_rect(destination, Color(_token("bg.abyss"), 0.18))


## Procedural fallback used only before the section texture is imported.
func _draw_cutaway_placeholder() -> void:
	var w := size.x
	var h := size.y
	var deck_y := h * 0.30
	var keel_y := h * 0.56
	var left := w * 0.07
	var right := w * 0.93
	var hull := PackedVector2Array([
		Vector2(left, deck_y),
		Vector2(right, deck_y),
		Vector2(right - w * 0.05, keel_y),
		Vector2(left + w * 0.04, keel_y),
	])
	draw_colored_polygon(hull, HULL_DARK)
	var inner := PackedVector2Array([
		Vector2(left + w * 0.012, deck_y + h * 0.012),
		Vector2(right - w * 0.012, deck_y + h * 0.012),
		Vector2(right - w * 0.058, keel_y - h * 0.012),
		Vector2(left + w * 0.050, keel_y - h * 0.012),
	])
	draw_colored_polygon(inner, HULL_MID)
	_draw_polyline_closed(hull, BRASS, 2.0)
	draw_line(Vector2(left, deck_y), Vector2(right, deck_y), BRASS, 3.0)
	var cabin := Rect2(w * 0.36, deck_y - h * 0.115, w * 0.26, h * 0.115)
	draw_rect(cabin, HULL_MID)
	draw_rect(cabin, BRASS, false, 1.5)
	var funnel := Rect2(w * 0.565, deck_y - h * 0.185, w * 0.032, h * 0.07)
	draw_rect(funnel, HULL_MID)
	draw_rect(funnel, BRASS, false, 1.5)
	draw_line(Vector2(w * 0.72, deck_y), Vector2(w * 0.72, deck_y - h * 0.15), BRASS, 2.0)
	var flag := PackedVector2Array([
		Vector2(w * 0.72, deck_y - h * 0.15),
		Vector2(w * 0.80, deck_y - h * 0.125),
		Vector2(w * 0.72, deck_y - h * 0.10),
	])
	draw_colored_polygon(flag, TEAL)
	var sections := [0.18, 0.36, 0.54, 0.70, 0.86]
	for fraction in sections:
		var x := left + (right - left) * float(fraction)
		draw_line(Vector2(x, deck_y + 2.0), Vector2(x, keel_y - 2.0), Color(TEAL, 0.35), 1.0)
	var boiler_center := Vector2(left + (right - left) * 0.30, (deck_y + keel_y) * 0.55)
	draw_circle(boiler_center, h * 0.055, HULL_MID)
	draw_arc(boiler_center, h * 0.055, 0.0, TAU, 24, BRASS, 1.5)
	var wheel_center := Vector2(left + (right - left) * 0.10, keel_y - h * 0.02)
	draw_circle(wheel_center, h * 0.055, HULL_MID)
	draw_arc(wheel_center, h * 0.055, 0.0, TAU, 24, TEAL, 1.5)
	draw_line(Vector2(left, keel_y), Vector2(right, keel_y), TEAL, 1.0)


## Leader lines from slot chips towards their compartment in the texture.
func _draw_slot_leaders() -> void:
	if _slot_targets.is_empty():
		return
	var cargo_count := 0
	for target in _slot_targets:
		if String(target.slot.get("category", "")) == "cargo":
			cargo_count += 1
	for target in _slot_targets:
		var anchor := _chip_anchor(target.slot, cargo_count)
		var start := Vector2(target.position.x + target.size.x * 0.5, target.position.y)
		draw_line(start, anchor, Color(TEAL, 0.28), 1.0)
		draw_circle(anchor, 3.0, Color(BRASS, 0.6))


func _draw_waves(water_y: float, w: float, h: float) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for index in steps + 1:
		var x := w * float(index) / float(steps)
		var y := water_y + sin(_time * 1.4 + float(index) * 0.7) * h * 0.004
		points.append(Vector2(x, y))
	draw_polyline(points, Color(TEAL, 0.25), 1.5)
	var far := PackedVector2Array()
	for index in steps + 1:
		var x := w * float(index) / float(steps)
		var y := water_y + h * 0.035 + sin(_time * 1.1 + float(index) * 0.5) * h * 0.005
		far.append(Vector2(x, y))
	draw_polyline(far, Color(TEAL, 0.14), 1.0)


func _draw_polyline_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width)
