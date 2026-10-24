class_name SNShipView
extends Control
## @static-doc
## 作用：船厂中央船体视图；正常态承载 2.5D 船体/程序化船身，改装态绘制每船侧视/俯视蓝图线稿、模块拖放槽位，以及 hull `weapon_sockets[].blueprint` 驱动的武器槽位框和高亮。
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
## - CUTAWAY 同时绘制 side（上方）与 top（下方）两个视图；槽位框空槽为灰、已装武器为
##   黄铜、`highlight_slots()` 命中的 socket 为青色高亮；购买/安装命令仍由船厂页面发出。
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
	resized.connect(_layout_slots)
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
	queue_redraw()


func set_mode(next: int) -> void:
	mode = next
	for target in _slot_targets:
		if target is SNSlotTarget:
			target.visible = mode == Mode.CUTAWAY
	_notify_renderer("ship_view_set_mode", [mode])
	_layout_slots()
	queue_redraw()


func highlight_slots(slot_ids: Array) -> void:
	_highlighted_slot_ids = slot_ids.duplicate()
	for target in _slot_targets:
		if target is SNSlotTarget:
			target.set_compatible_hint(slot_ids.has(String(target.slot.get("id", ""))))
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
	_draw_blueprint_weapon_slots()
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


## Draws non-interactive weapon socket frames over the blueprint. Purchase and
## install actions stay in the weapons panel; this layer only gives spatial
## feedback and uses highlight_slots() for the active/compatible state.
func _draw_blueprint_weapon_slots() -> void:
	var sockets_by_id: Dictionary = {}
	for raw_socket in _model.get("weapon_sockets", []):
		if raw_socket is Dictionary:
			var socket: Dictionary = raw_socket
			sockets_by_id[String(socket.get("socket", socket.get("name", "")))] = socket
	# With per-view line art both views are visible, so draw the socket frames in
	# each. Legacy generic-section hulls keep the old single-view behaviour.
	var views_to_draw: Array = ["side"]
	if has_blueprint_views():
		views_to_draw = ["side", "top"]
	else:
		var legacy_view := String(_model.get("blueprint_view", "side"))
		if legacy_view in ["side", "top"]:
			views_to_draw = [legacy_view]
	for view in views_to_draw:
		var socket_rects := blueprint_socket_rects(String(view))
		for socket_id in socket_rects.keys():
			var rect: Rect2 = socket_rects[socket_id]
			var highlighted := _highlighted_slot_ids.has(String(socket_id))
			var socket: Dictionary = sockets_by_id.get(socket_id, {})
			var occupied := not String(socket.get("weapon_id", "")).is_empty()
			var color := BRASS if occupied else MUTED
			if highlighted:
				color = TEAL
			draw_rect(rect, Color(color, 0.18 if highlighted else 0.08), true)
			draw_rect(rect, color, false, 2.5 if highlighted else 1.5)
			var notch := minf(rect.size.x, rect.size.y) * 0.22
			draw_line(rect.get_center() - Vector2(notch, 0.0), rect.get_center() + Vector2(notch, 0.0), color, 1.0)
			draw_line(rect.get_center() - Vector2(0.0, notch), rect.get_center() + Vector2(0.0, notch), color, 1.0)


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
