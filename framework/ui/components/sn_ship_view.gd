class_name SNShipView
extends Control
## @static-doc
## 作用：船厂中央船体视图；正常态承载 2.5D 船体/程序化船身，改装态绘制每船**侧视**蓝图线稿、内容锚点圆点（`ship.slot_anchors` + `weapon_sockets[].blueprint.side`）、圆点到模块方框/武器贴片的折线，以及可拖放的槽位贴片与武器贴片。
##
## ## 外观来源（外部贴图 + SNSkin）
## - 舞台背景 wash、视图框/底板改用皮肤九宫格：
##   `SNSkin.style("panel_recess" / "panel_blueprint" / "frame_open")` + `draw_style_box()`；
##   皮肤缺失时退回 token 色块/描边，仍保持可读性。
## - 所有颜色取 `SNSkin.color(token)`（本文件不写十六进制），文字字体取
##   `get_theme_default_font()`；线稿、水面、船身等数据绘制保留，但颜色来自 token。
## - `set_blueprint_backdrop(true)` 时仍不画背景 wash / 视图框：底板由父级
##   `SNBlueprintPanel` 提供，开关语义与之前一致。
##
## ## 契约与约束
## - `set_ship_model()` 接收 `shipyard.view.ship`；`ship.blueprint_views.{side,top}` 是
##   已解析的线稿路径（`path`），没有线稿时回退到通用纵剖图/程序化占位。
## - 武器槽位行必须包含稳定 `socket` 与 `blueprint`；`blueprint.side` 是左上原点、
##   0..1 的 JSON Vector2，坐标基准是侧视图线稿纹理。
## - `blueprint_view_rect(view)` 返回该视图等比适配后的屏幕矩形；`blueprint_socket_rects(view)`
##   用这个矩形把归一化坐标映射为屏幕框；缺失、越界或形状错误的坐标跳过，不影响其它
##   槽位和模块拖放。没有线稿时 rect 回退为整个 Control，保持旧内容兼容。
## - **P2b（2026-10-28）单侧视 + 圆点折线**：
##   * CUTAWAY 有 `blueprint_views` 时只绘制 side（`top` 暂不绘制、不再生成武器贴片），
##     `blueprint_view_rect("side")` 独占可用区域；`blueprint_view_rect("top")` /
##     `blueprint_socket_rects("top")` 仍按旧双视图公式返回可计算坐标（兼容语义，不绘制）。
##   * `ship.slot_anchors`（键：hull / boiler / navigation_module / safety_module /
##     passenger_cabin / cargo_modules[[x,y],...]）给出普通模块槽位的侧视归一化锚点；
##     内容缺失时每个槽位回退到面板内通用锚点（不崩）。武器槽位仍用
##     `weapon_sockets[].blueprint.side`。
##   * 每个槽位（模块 + 武器）在锚点画圆点（黄铜 idle / 青色高亮），用「水平出线 + 斜线
##     到方框边缘」的折线连到自己的方框；`highlight_slots()` 与拖拽悬停时圆点、方框一起变色。
##   * 普通模块方框（`SNSlotTarget`）不再停靠底部 dock，改为贴着锚点摆放：锚点 x<0.6 放右、
##     否则放左；按 y 排序后纵向避让，必要时向外开第二条车道，全部 clamp 在侧视图矩形内，
##     互不重叠、不出界。面板小/槽位多时方框进入紧凑两行模式（隐藏第三行 hint）。
##   * 旧无 `blueprint_views` 的船继续走 `_draw_section_texture()` / `_draw_cutaway_placeholder()`
##     与原有槽位排布（含 `_draw_slot_leaders()`），回退路径不变。
## - **P2a（2026-10-28）模式隔离**：`set_module_chips_visible(bool)` /
##   `set_weapon_patches_visible(bool)`（默认均 true）分别控制普通槽位方框+圆点、
##   武器贴片+圆点的可见性与拖放接收（仍保证 `weapon_targets()` 数量 = 每个 socket 一枚）。
##   无 `blueprint_views` 的旧船忽略这两个开关，保持旧 dock 语义。
## - 武器贴片契约（2026-10-27，玩家反馈「装配后看不出装在哪 / 武器不能拖动安装」）：
##   * `set_ship_model()` 的 `model.weapon_sockets[]` 每行至少含 `socket` / `socket_class` /
##     `blueprint` / `weapon_id`；可选展示字段 `display_name`（已装武器本地化名，空槽 ""）、
##     `slot_label`（短标签，如「左舷1」）、`slot_title`（完整友好名，作 tooltip）、
##     `empty_text`、`occupied`。缺字段时按 `SNWeaponSocketTarget` 的兜底规则推导，不崩。
##   * 每个 socket 只要有 `blueprint.side` 坐标就生成一枚 side 贴片（P2b 起不再有 top 贴片）；
##     贴片始终随 CUTAWAY 可见（EXTERIOR 隐藏）。
##   * `weapon_socket_display_rects("side")` 返回与模块方框统一排布后的 ≥96×30 可读贴片矩形：
##     同一锚点/过近的槽位（如 Port_1 / Starboard_1 共用同一 side 坐标）沿垂直方向扇出，
##     互不重叠，并 clamp 在 `blueprint_view_rect("side")` 内。`blueprint_socket_rects()`
##     保持原有的 28–42 px 小框语义，不变。
##   * 拖放：贴片只接受 `{kind:"ship_weapon", weapon_id, weapon_class, source, name}`，
##     `weapon_class == socket_class` 才接受；`_drop_data` 经 `weapon_dropped` 汇总为
##     `weapon_drop_requested(payload, socket)`。`set_weapon_drop_enabled(false)` 只关闭
##     拖放接收（非武器分类 / 非装配页签），不影响贴片可见性；默认接受。
## - 有每船线稿时船厂页把整列换成 `SNBlueprintPanel` 九宫格蓝图底板；页面调用
##   `set_blueprint_backdrop(true)` 后本视图只把线稿、视图标签、圆点折线、武器贴片和槽位
##   chip 画在底板的深蓝内容区上。底板由 Theme 提供，本视图不持有底板纹理。
## - 新增公共读取 API（测试 / 屏幕用）：`slot_anchor_rects()` 返回每个槽位圆点的小矩形
##   （键 = 模块槽位 id / 武器 socket 名），`slot_chip_rects()` 返回普通模块方框矩形；
##   两者都只包含当前可见的那一组。
##
## Refit stage for the centre of the shipyard screen.
##
## Two modes share one coordinate space:
##   EXTERIOR — a side view of the current ship (procedural placeholder today).
##   CUTAWAY  — the side blueprint view from the hull's `blueprint_views`; slots are
##              drawn as anchor dots with leader lines to draggable chips. When absent,
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
## Legacy dual-view split, kept only so `blueprint_view_rect("top")` can still
## resolve coordinates after P2b stopped drawing the top view.
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
# ---------------------------------------------------------------------------
# P2b (2026-10-28): anchor dots + leader lines + chips beside their anchors.
# ---------------------------------------------------------------------------
## Normalized anchor x below this goes to the right of the dot, above it to the left.
const BLUEPRINT_CHIP_SIDE_SPLIT := 0.6
const SLOT_CHIP_MIN_WIDTH := 96.0
const SLOT_CHIP_MAX_WIDTH := 168.0
const SLOT_CHIP_WIDTH_RATIO := 0.26
const SLOT_CHIP_HEIGHT := 52.0
const SLOT_CHIP_MIN_HEIGHT := 32.0
const SLOT_CHIP_HEIGHT_RATIO := 0.16
const SLOT_CHIP_GAP := 4.0
const SLOT_CHIP_MARGIN := 2.0
## Below this chip height the slot chip drops to two compact lines (hint hidden).
const SLOT_CHIP_COMPACT_HEIGHT := 42.0
## Anchor dot radius (px) and the horizontal leader stub before the diagonal.
const ANCHOR_DOT_RADIUS := 4.0
const ANCHOR_LEADER_OUT := 12.0
## Extra horizontal lanes tried when a side column is too crowded to stack in
## one line (e.g. a freighter with 3 cargo bays + 4 weapon mounts).
const BLUEPRINT_CHIP_LANES := 3
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
## P2a (2026-10-28): module refit / weapon install are separate modes. Defaults keep
## both groups visible so existing callers and tests keep their old semantics.
var _module_chips_visible := true
var _weapon_patches_visible := true
## Unified side-view chip layout (slot anchors, module chips, weapon patches).
## Rebuilt lazily whenever the model, slots, mode or stage size changes.
var _blueprint_layout: Dictionary = {}
var _blueprint_layout_dirty := true
## Hover ids polled for the anchor-dot highlight (chips/dots turn teal together).
var _hovered_slot_ids: Array = []
var _hovered_weapon_socket := ""
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
	_weapon_layer.visible = mode == Mode.CUTAWAY and (_weapon_patches_visible or not has_blueprint_views())
	_slot_layer.visible = mode == Mode.CUTAWAY and (_module_chips_visible or not has_blueprint_views())
	_rebuild_weapon_targets()
	resized.connect(_on_stage_resized)
	set_process(true)
	if not _slots.is_empty():
		set_slots(_slots)


func _process(delta: float) -> void:
	_time += delta
	if _renderer == null or mode == Mode.EXTERIOR:
		queue_redraw()
	if mode == Mode.CUTAWAY and has_blueprint_views():
		_poll_slot_hover()


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
	_mark_blueprint_layout_dirty()
	_rebuild_weapon_targets()
	_layout_slots()
	queue_redraw()


## True when the hull ships per-view line art (side/top); otherwise the stage
## keeps the legacy generic section texture.
func has_blueprint_views() -> bool:
	return not _blueprint_textures.is_empty()


func blueprint_texture_size(view: String) -> Vector2:
	var texture: Texture2D = _blueprint_textures.get(view, null)
	return texture.get_size() if texture != null else Vector2.ZERO


## P2b: the bottom slot dock is gone (module chips sit beside their anchor), so
## this always reports 0. Kept as a public no-op-ish API for older callers.
func slot_dock_height() -> float:
	return 0.0


## Lets the screen declare that the parent column is a blueprint board. The
## cutaway then stops painting its own wash / view frame / plate, so the board's
## blue field shows through and the pale line art keeps the intended contrast.
## The board itself is a Theme stylebox; this flag only removes paint.
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


## Stage area left for line art: the whole control (P2b removed the slot dock).
func _blueprint_view_available_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


## Aspect-preserving on-screen rect of one blueprint view; falls back to the
## whole control when no line art exists so pre-art hulls keep the old mapping.
##
## P2b: when both views exist, `side` takes the whole available area (the top view
## is no longer drawn). `top` keeps the legacy dual-view formula so external
## callers can still compute its coordinates; it is only a compatibility rect.
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
	if view == "side":
		return _fit_texture(_blueprint_textures["side"], available)
	var gap: float = available.size.y * BLUEPRINT_VIEW_GAP
	var side_height: float = available.size.y * BLUEPRINT_SIDE_RATIO
	var legacy_side := Rect2(0.0, 0.0, available.size.x, side_height)
	var top_region := Rect2(0.0, side_height + gap, available.size.x, available.size.y - side_height - gap)
	var side_fit := _fit_texture(_blueprint_textures["side"], legacy_side)
	return _fit_texture_with_width(_blueprint_textures["top"], top_region, maxf(side_fit.size.x, 1.0))


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
		target.set_drop_enabled(_module_chips_visible or not has_blueprint_views())
		_slot_layer.add_child(target)
		target.visible = _module_chips_visible or not has_blueprint_views()
		_slot_targets.append(target)
	_mark_blueprint_layout_dirty()
	_layout_slots()
	# Chips and weapon patches share one side-view layout, so both re-run.
	_layout_weapon_targets()
	queue_redraw()


func set_mode(next: int) -> void:
	mode = next
	_apply_layer_visibility()
	_notify_renderer("ship_view_set_mode", [mode])
	_layout_slots()
	_layout_weapon_targets()
	queue_redraw()


## P2a: show/hide the regular module chips (and their anchor dots). Hidden chips
## are not laid out, not visible and refuse `ship_parts` drops. Weapons mode calls
## `set_module_chips_visible(false)`. Legacy hulls without line art keep chips.
func set_module_chips_visible(visible: bool) -> void:
	if _module_chips_visible == visible:
		return
	_module_chips_visible = visible
	var effective := visible or not has_blueprint_views()
	for target in _slot_targets:
		if is_instance_valid(target):
			target.set_drop_enabled(effective)
	_apply_layer_visibility()
	_layout_slots()
	queue_redraw()


func module_chips_visible() -> bool:
	return _module_chips_visible


## P2a: show/hide the ship-weapon patches (and their anchor dots). Hidden patches
## are not visible and refuse `ship_weapon` drops; `weapon_targets()` still returns
## one control per socket so the count contract does not change.
func set_weapon_patches_visible(visible: bool) -> void:
	if _weapon_patches_visible == visible:
		return
	_weapon_patches_visible = visible
	var effective := visible or not has_blueprint_views()
	for target in _weapon_targets:
		if is_instance_valid(target) and target.has_method("set_drop_enabled"):
			target.call("set_drop_enabled", _weapon_drop_enabled and effective)
	_apply_layer_visibility()
	_layout_weapon_targets()
	queue_redraw()


func weapon_patches_visible() -> bool:
	return _weapon_patches_visible


## Layer visibility helper: P2a flags drive the two chip groups in the blueprint
## path; legacy hulls without line art keep both layers on (old dock semantics).
func _apply_layer_visibility() -> void:
	var cutaway := mode == Mode.CUTAWAY
	if _slot_layer != null:
		_slot_layer.visible = cutaway and (_module_chips_visible or not has_blueprint_views())
	if _weapon_layer != null:
		_weapon_layer.visible = cutaway and (_weapon_patches_visible or not has_blueprint_views())


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


## On-screen dot frames for every visible slot / weapon anchor (P2b). Keys are
## module slot ids (`boiler_0`, `cargo_modules_1`, ...) and weapon socket names.
## Empty when the hull has no line art (legacy section path keeps its old leaders).
func slot_anchor_rects() -> Dictionary:
	var rects: Dictionary = {}
	if not has_blueprint_views():
		return rects
	_ensure_blueprint_layout()
	var dot_size := Vector2(ANCHOR_DOT_RADIUS, ANCHOR_DOT_RADIUS) * 2.0
	if _module_chips_visible:
		var slot_anchors: Dictionary = _blueprint_layout.get("slot_anchors", {})
		for raw_id in slot_anchors.keys():
			var anchor: Vector2 = slot_anchors[raw_id]
			rects[String(raw_id)] = Rect2(anchor - dot_size * 0.5, dot_size)
	if _weapon_patches_visible:
		var weapon_anchors: Dictionary = _blueprint_layout.get("weapon_anchors", {})
		for raw_id in weapon_anchors.keys():
			var anchor: Vector2 = weapon_anchors[raw_id]
			rects[String(raw_id)] = Rect2(anchor - dot_size * 0.5, dot_size)
	return rects


## On-screen rects of the regular module chips (P2b). Empty when the module chips
## are hidden (weapons mode) or when the hull has no line art (legacy path).
func slot_chip_rects() -> Dictionary:
	if not has_blueprint_views() or not _module_chips_visible:
		return {}
	_ensure_blueprint_layout()
	return (_blueprint_layout.get("slots", {}) as Dictionary).duplicate()


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
## P2b: in the single side view the patches are laid out together with the module
## chips (same unified layout, so slot boxes and weapon patches never overlap).
## Sockets sharing one side anchor (e.g. Port_1 / Starboard_1) are stacked in the
## same lane. Other views / legacy content keep the old cluster fan-out path.
func weapon_socket_display_rects(view: String = "side") -> Dictionary:
	if has_blueprint_views() and view == _blueprint_drawn_view():
		_ensure_blueprint_layout()
		return (_blueprint_layout.get("weapons", {}) as Dictionary).duplicate()
	return _legacy_weapon_display_rects(view)


## Pre-P2b fan-out path: used for the compatibility `top` rect and for hulls
## without per-view line art.
func _legacy_weapon_display_rects(view: String = "side") -> Dictionary:
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
	var effective := enabled and (_weapon_patches_visible or not has_blueprint_views())
	for target in _weapon_targets:
		if is_instance_valid(target) and target.has_method("set_drop_enabled"):
			target.set_drop_enabled(effective)


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
## Views that carry weapon patches. P2b: per-view line art only draws a single
## view (side, or top when a hull binds only top), so patches take that view.
## Legacy hulls without line art keep their single declared view.
func _weapon_views() -> Array:
	if not _blueprint_textures.is_empty():
		var drawn := _blueprint_drawn_view()
		return [drawn] if not drawn.is_empty() else ["side"]
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
			target.set_drop_enabled(_weapon_drop_enabled and (_weapon_patches_visible or not has_blueprint_views()))
			target.set_highlighted(_highlighted_slot_ids.has(socket_id))
			target.weapon_dropped.connect(_on_weapon_dropped)
			target.hovered.connect(_on_weapon_hovered)
			target.unhovered.connect(_on_weapon_unhovered)
			_weapon_layer.add_child(target)
			target.visible = mode == Mode.CUTAWAY and (_weapon_patches_visible or not has_blueprint_views())
			_weapon_targets.append(target)
	_mark_blueprint_layout_dirty()
	_layout_weapon_targets()


func _on_weapon_dropped(payload: Dictionary, socket: Dictionary) -> void:
	weapon_drop_requested.emit(payload, socket)


func _on_weapon_hovered(socket_name: String) -> void:
	_hovered_weapon_socket = socket_name
	weapon_socket_hovered.emit(socket_name)
	queue_redraw()


func _on_weapon_unhovered() -> void:
	_hovered_weapon_socket = ""
	weapon_socket_unhovered.emit()
	queue_redraw()


## Keeps the anchor dots in sync with chip hover: the dot turns teal together with
## the hovered chip (a light poll, chips have no hover signal of their own).
func _poll_slot_hover() -> void:
	var hovered: Array = []
	for target in _slot_targets:
		if is_instance_valid(target) and target.has_method("is_hovering") and bool(target.call("is_hovering")):
			hovered.append(String(target.slot.get("id", "")))
	if hovered == _hovered_slot_ids:
		return
	_hovered_slot_ids = hovered
	queue_redraw()


func _on_stage_resized() -> void:
	_mark_blueprint_layout_dirty()
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
		if not stage_ready or mode != Mode.CUTAWAY \
				or not (_weapon_patches_visible or not has_blueprint_views()):
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
# Slot chip layout.
# - P2b: with per-hull line art the chips sit beside their blueprint anchor.
# - Legacy (no line art): fixed slots in one row, cargo slots in a second row.
# ---------------------------------------------------------------------------
func _layout_slots() -> void:
	if _slot_targets.is_empty() or size.x < 80.0:
		return
	if has_blueprint_views():
		_layout_blueprint_chips()
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


## Positions the module chips on their side-view anchor layout (P2b). The layout
## itself is shared with the weapon patches, so both groups never overlap.
func _layout_blueprint_chips() -> void:
	_ensure_blueprint_layout()
	var chips: Dictionary = _blueprint_layout.get("slots", {})
	var compact := _slot_chip_compact()
	var effective_visible := mode == Mode.CUTAWAY and (_module_chips_visible or not has_blueprint_views())
	for target in _slot_targets:
		if not is_instance_valid(target):
			continue
		var slot_id := String(target.slot.get("id", ""))
		if not chips.has(slot_id):
			target.visible = false
			continue
		var rect: Rect2 = chips[slot_id]
		target.set_compact(compact)
		target.size = rect.size
		target.position = rect.position
		target.set_drop_enabled(effective_visible)
		target.visible = effective_visible


## True when the side view is short enough that chips must drop to two lines.
func _slot_chip_compact() -> bool:
	if not has_blueprint_views():
		return false
	var view_rect := blueprint_view_rect(_blueprint_drawn_view())
	if view_rect.size.y <= 0.0:
		return false
	var chip_height := clampf(view_rect.size.y * SLOT_CHIP_HEIGHT_RATIO,
		SLOT_CHIP_MIN_HEIGHT, SLOT_CHIP_HEIGHT)
	return chip_height < SLOT_CHIP_COMPACT_HEIGHT


## Legacy (no line art) chip row layout: one evenly spaced row over the section.
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
		target.visible = mode == Mode.CUTAWAY and (_module_chips_visible or not has_blueprint_views())
		x += chip_w + gap


# ---------------------------------------------------------------------------
# Unified side-view blueprint layout (P2b): anchors, module chips, weapon patches.
# Both chip groups are placed in one pass so they never overlap each other; the
# result is cached until the model / slots / size change.
# ---------------------------------------------------------------------------
func _mark_blueprint_layout_dirty() -> void:
	_blueprint_layout_dirty = true


func _ensure_blueprint_layout() -> void:
	if not _blueprint_layout_dirty:
		return
	_blueprint_layout = _compute_blueprint_chip_layout()
	_blueprint_layout_dirty = false


## Builds the cached layout:
## `{slots: {id: Rect2}, weapons: {socket: Rect2}, slot_anchors: {id: Vector2},
##   weapon_anchors: {socket: Vector2}}`.
## `side` when the hull ships it, otherwise the `top` fallback (a hull may bind
## only one view); empty when there is no line art at all.
func _blueprint_drawn_view() -> String:
	if _blueprint_textures.has("side"):
		return "side"
	if _blueprint_textures.has("top"):
		return "top"
	return ""


func _compute_blueprint_chip_layout() -> Dictionary:
	var layout := {"slots": {}, "weapons": {}, "slot_anchors": {}, "weapon_anchors": {}}
	if not has_blueprint_views() or size.x < 80.0 or size.y < 80.0:
		return layout
	var view_rect := blueprint_view_rect(_blueprint_drawn_view())
	if view_rect.size.x <= 0.0 or view_rect.size.y <= 0.0:
		return layout
	var margin := SLOT_CHIP_MARGIN
	var slot_width := clampf(view_rect.size.x * SLOT_CHIP_WIDTH_RATIO,
		SLOT_CHIP_MIN_WIDTH, SLOT_CHIP_MAX_WIDTH)
	slot_width = minf(slot_width, maxf(view_rect.size.x * 0.5, 40.0))
	var slot_height := clampf(view_rect.size.y * SLOT_CHIP_HEIGHT_RATIO,
		SLOT_CHIP_MIN_HEIGHT, SLOT_CHIP_HEIGHT)
	var entries: Array = []
	var compact := slot_height < SLOT_CHIP_COMPACT_HEIGHT
	for target in _slot_targets:
		if not is_instance_valid(target):
			continue
		var slot: Dictionary = target.slot
		var slot_id := String(slot.get("id", ""))
		if slot_id.is_empty():
			continue
		# Compact mode first, so the measured minimum matches the final chip.
		target.set_compact(compact)
		var min_height := maxf(target.get_combined_minimum_size().y, SLOT_CHIP_MIN_HEIGHT)
		var anchor := _blueprint_point_to_screen(view_rect, _slot_anchor_normalized(slot))
		layout["slot_anchors"][slot_id] = anchor
		var slot_entry_height := maxf(slot_height, min_height)
		entries.append({
			"kind": "slot", "id": slot_id, "anchor": anchor,
			"width": slot_width, "height": slot_entry_height,
			"base_height": slot_entry_height, "min_height": min_height,
		})
	var weapon_width := clampf(view_rect.size.x * WEAPON_CARD_WIDTH_RATIO,
		WEAPON_CARD_MIN_WIDTH, WEAPON_CARD_MAX_WIDTH)
	weapon_width = minf(weapon_width, maxf(view_rect.size.x - margin * 2.0, 60.0))
	var weapon_height := minf(WEAPON_CARD_HEIGHT,
		maxf(view_rect.size.y - margin * 2.0, WEAPON_CARD_MIN_HEIGHT))
	var drawn_view := _blueprint_drawn_view()
	for raw_row in _model.get("weapon_sockets", []):
		if not (raw_row is Dictionary):
			continue
		var row: Dictionary = raw_row
		var socket_id := String(row.get("socket", row.get("name", "")))
		if socket_id.is_empty():
			continue
		var normalized := _socket_blueprint_point(row, drawn_view)
		if normalized == Vector2(-1.0, -1.0):
			continue
		var anchor := _blueprint_point_to_screen(view_rect, normalized)
		layout["weapon_anchors"][socket_id] = anchor
		entries.append({
			"kind": "weapon", "id": socket_id, "anchor": anchor,
			"width": weapon_width, "height": weapon_height,
			"base_height": weapon_height, "min_height": WEAPON_CARD_MIN_HEIGHT,
		})
	# Crowded ships (freighter: 3 cargo + 4 mounts on a wide, short side view) may
	# not fit at the readable default size: retry with progressively shorter chips,
	# then fall back to a packed grid so boxes still never overlap.
	var placed := false
	for scale in [1.0, 0.9, 0.82, 0.74, 0.68]:
		for entry in entries:
			var base_height := float(entry["base_height"])
			var min_height := float(entry["min_height"])
			entry["height"] = maxf(min_height, base_height * float(scale))
		placed = _place_blueprint_entries(entries, view_rect)
		if placed:
			break
	if not placed:
		placed = _place_blueprint_grid(entries, view_rect)
	if not placed:
		# Last resort for a panel too small for every chip: keep them on screen
		# (clamped beside their anchors) rather than dropping any of them.
		_place_blueprint_entries(entries, view_rect)
	for entry in entries:
		if String(entry["kind"]) == "slot":
			layout["slots"][String(entry["id"])] = entry["rect"]
		else:
			layout["weapons"][String(entry["id"])] = entry["rect"]
	return layout


## Places every chip (module + weapon) around its own anchor: right of the dot
## when the anchor sits left of 60% of the side view, left otherwise. Chips are
## vertically nudged on collision; crowded groups fan out into extra horizontal
## lanes. Every returned rect is clamped inside the side view. Returns true when
## every chip found a fully disjoint in-bounds slot.
func _place_blueprint_entries(entries: Array, view_rect: Rect2) -> bool:
	if entries.is_empty():
		return true
	var gap := SLOT_CHIP_GAP
	var margin := SLOT_CHIP_MARGIN
	entries.sort_custom(_sort_blueprint_entries)
	var placed: Array = []
	var ok := true
	for entry in entries:
		var anchor: Vector2 = entry["anchor"]
		var width := float(entry["width"])
		var height := float(entry["height"])
		var to_the_right: bool = _anchor_normalized_x(anchor, view_rect) < BLUEPRINT_CHIP_SIDE_SPLIT
		var base_left := anchor.x + ANCHOR_LEADER_OUT if to_the_right else anchor.x - ANCHOR_LEADER_OUT - width
		var outward := width + gap
		var chosen := Rect2()
		var chosen_cost := INF
		for lane in BLUEPRINT_CHIP_LANES:
			var lane_offset := outward * float(lane)
			var raw_left := base_left + lane_offset if to_the_right else base_left - lane_offset
			var left := clampf(raw_left, view_rect.position.x + margin,
				view_rect.position.x + view_rect.size.x - margin - width)
			var candidate := Rect2(Vector2(left, anchor.y - height * 0.5), Vector2(width, height))
			var nudged := _nudge_chip_vertical(candidate, placed, view_rect, gap, margin)
			if not _rect_inside(nudged, view_rect, margin):
				continue
			var cost: float = absf(nudged.position.y - candidate.position.y) \
				+ float(lane) * height * 1.2
			if cost < chosen_cost:
				chosen = nudged
				chosen_cost = cost
			if cost < 0.5:
				break
		if chosen_cost == INF:
			# Extreme fallback (very small stage): keep the chip beside the dot and
			# clamp it back into the view; no silent crash / missing chip.
			var left := clampf(base_left, view_rect.position.x + margin,
				view_rect.position.x + view_rect.size.x - margin - width)
			var top := clampf(anchor.y - height * 0.5, view_rect.position.y + margin,
				view_rect.position.y + view_rect.size.y - margin - height)
			chosen = Rect2(Vector2(left, top), Vector2(width, height))
			ok = false
		entry["rect"] = chosen
		placed.append(chosen)
	return ok


## Guaranteed non-overlap fallback for small panels: pack every chip into a
## uniform grid inside the side view (each chip keeps its compact minimum height,
## which is still the readable two-line size). Returns false when even the grid
## cannot fit, so the caller can keep the anchor placement.
func _place_blueprint_grid(entries: Array, view_rect: Rect2) -> bool:
	if entries.is_empty():
		return true
	var gap := SLOT_CHIP_GAP
	var margin := SLOT_CHIP_MARGIN
	var cell_width := 0.0
	var cell_height := 0.0
	for entry in entries:
		entry["height"] = maxf(float(entry["min_height"]), 1.0)
		cell_width = maxf(cell_width, float(entry["width"]))
		cell_height = maxf(cell_height, float(entry["height"]))
	var usable_width := view_rect.size.x - margin * 2.0
	var usable_height := view_rect.size.y - margin * 2.0
	if usable_width < cell_width or usable_height < cell_height:
		return false
	var columns := int(floor((usable_width + gap) / (cell_width + gap)))
	columns = clampi(columns, 1, entries.size())
	var rows := int(ceil(float(entries.size()) / float(columns)))
	if float(rows) * cell_height + float(rows - 1) * gap > usable_height + 0.5:
		return false
	entries.sort_custom(_sort_blueprint_entries)
	var index := 0
	for row in rows:
		for column in columns:
			if index >= entries.size():
				return true
			var entry: Dictionary = entries[index]
			var width := float(entry["width"])
			var height := float(entry["height"])
			var cell_position := view_rect.position + Vector2(
				margin + float(column) * (cell_width + gap),
				margin + float(row) * (cell_height + gap)
			)
			entry["rect"] = Rect2(
				cell_position + Vector2((cell_width - width) * 0.5, (cell_height - height) * 0.5),
				Vector2(width, height)
			)
			index += 1
	return true


## Pushes `rect` below every already-placed chip it collides with, then flips to
## packing upward when the nudged chip would leave the view bottom.
func _nudge_chip_vertical(rect: Rect2, placed: Array, view_rect: Rect2, gap: float, margin: float) -> Rect2:
	var result := rect
	for _iteration in 32:
		var collided := false
		for raw_other in placed:
			var other: Rect2 = raw_other
			if not result.intersects(other):
				continue
			result.position.y = other.end.y + gap
			collided = true
		if not collided:
			break
	var bottom := view_rect.position.y + view_rect.size.y - margin
	if result.end.y > bottom:
		result.position.y = bottom - result.size.y
		for _iteration in 32:
			var collided := false
			for raw_other in placed:
				var other: Rect2 = raw_other
				if not result.intersects(other):
					continue
				result.position.y = other.position.y - gap - result.size.y
				collided = true
			if not collided:
				break
	return result


## Deterministic order: top to bottom, then left to right, then id.
func _sort_blueprint_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_anchor: Vector2 = a["anchor"]
	var b_anchor: Vector2 = b["anchor"]
	if not is_equal_approx(a_anchor.y, b_anchor.y):
		return a_anchor.y < b_anchor.y
	if not is_equal_approx(a_anchor.x, b_anchor.x):
		return a_anchor.x < b_anchor.x
	return String(a["id"]) < String(b["id"])


func _rect_inside(rect: Rect2, view_rect: Rect2, margin: float) -> bool:
	return rect.position.x >= view_rect.position.x + margin - 0.5 \
		and rect.end.x <= view_rect.position.x + view_rect.size.x - margin + 0.5 \
		and rect.position.y >= view_rect.position.y + margin - 0.5 \
		and rect.end.y <= view_rect.position.y + view_rect.size.y - margin + 0.5


func _anchor_normalized_x(anchor: Vector2, view_rect: Rect2) -> float:
	if view_rect.size.x <= 0.0:
		return 0.5
	return (anchor.x - view_rect.position.x) / view_rect.size.x


## Side-view normalized anchor of one module slot. Content driven via
## `ship.slot_anchors`; missing content falls back to a generic panel position so
## the chip and dot still exist (old content / SDK templates do not crash).
func _slot_anchor_normalized(slot: Dictionary) -> Vector2:
	var anchors: Variant = _model.get("slot_anchors", {})
	if anchors is Dictionary:
		var slot_key := String(slot.get("slot", ""))
		if slot_key == "cargo_modules":
			var cargo_anchors: Variant = (anchors as Dictionary).get("cargo_modules", null)
			if cargo_anchors is Array:
				var index := int(slot.get("index", 0))
				if index >= 0 and index < (cargo_anchors as Array).size():
					var point := _normalized_blueprint_point((cargo_anchors as Array)[index])
					if point != Vector2(-1.0, -1.0):
						return point
		else:
			var point := _normalized_blueprint_point((anchors as Dictionary).get(slot_key, null))
			if point != Vector2(-1.0, -1.0):
				return point
	return _fallback_slot_anchor(slot)


## Generic in-panel anchors (0..1 of the side view rect) used when content has no
## `ship.slot_anchors`; keeps every legacy hull fully usable.
func _fallback_slot_anchor(slot: Dictionary) -> Vector2:
	match String(slot.get("slot", "")):
		"hull":
			return Vector2(0.20, 0.47)
		"boiler":
			return Vector2(0.37, 0.50)
		"cargo_modules":
			var index := int(slot.get("index", 0))
			var step := 0.055 if index == 0 else 0.09
			return Vector2(0.52 + step * float(index), 0.52)
		"navigation_module":
			return Vector2(0.74, 0.42)
		"safety_module":
			return Vector2(0.63, 0.50)
		"passenger_cabin":
			return Vector2(0.85, 0.46)
		_:
			return Vector2(0.5, 0.5)


## Normalized point of a weapon socket on one blueprint view; (-1,-1) when absent.
func _socket_blueprint_point(row: Dictionary, view: String) -> Vector2:
	if view.is_empty():
		return Vector2(-1.0, -1.0)
	var blueprint: Variant = row.get("blueprint", null)
	if not (blueprint is Dictionary):
		return Vector2(-1.0, -1.0)
	return _normalized_blueprint_point((blueprint as Dictionary).get(view, null))


## Validates a `[x, y]` 0..1 JSON point; (-1,-1) when missing or malformed.
func _normalized_blueprint_point(raw_point: Variant) -> Vector2:
	if not (raw_point is Array) or (raw_point as Array).size() != 2:
		return Vector2(-1.0, -1.0)
	var point: Array = raw_point
	if not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int):
		return Vector2(-1.0, -1.0)
	var x := float(point[0])
	var y := float(point[1])
	if not is_finite(x) or not is_finite(y):
		return Vector2(-1.0, -1.0)
	if x < 0.0 or x > 1.0 or y < 0.0 or y > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(x, y)


func _blueprint_point_to_screen(view_rect: Rect2, normalized: Vector2) -> Vector2:
	return view_rect.position + Vector2(
		normalized.x * view_rect.size.x,
		normalized.y * view_rect.size.y
	)


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
		_draw_blueprint_side()
		_draw_slot_anchors()
		return
	if _section_texture != null:
		_draw_section_texture()
	else:
		_draw_cutaway_placeholder()
	# Legacy path keeps the old generic leader lines under the chip rows.
	_draw_slot_leaders()


## P2b single-view blueprint: only the side elevation (falling back to the top
## if a hull only ships a top line art). Aspect-fitted so author coordinates keep
## a 1:1 meaning with the source PNG. On a blueprint board the line art sits
## directly on the board's blue field (no boxes, no dock bar).
func _draw_blueprint_side() -> void:
	var view := _blueprint_drawn_view()
	if view.is_empty() or not _blueprint_textures.has(view):
		return
	var texture: Texture2D = _blueprint_textures[view]
	var rect := blueprint_view_rect(view)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var font := get_theme_default_font()
	var board := _uses_blueprint_board()
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


## P2b: every visible slot gets an anchor dot on the hull, connected to its chip
## with a leader that leaves the dot horizontally and then runs diagonally to the
## chip edge. Dots turn teal when the slot / socket is highlighted or hovered.
func _draw_slot_anchors() -> void:
	_ensure_blueprint_layout()
	if _module_chips_visible:
		var slot_anchors: Dictionary = _blueprint_layout.get("slot_anchors", {})
		var slot_chips: Dictionary = _blueprint_layout.get("slots", {})
		for raw_id in slot_anchors.keys():
			var slot_id := String(raw_id)
			_draw_anchor_dot(slot_anchors[raw_id],
				slot_chips.get(slot_id, Rect2()), _hovered_slot_ids.has(slot_id))
	if _weapon_patches_visible:
		var weapon_anchors: Dictionary = _blueprint_layout.get("weapon_anchors", {})
		var weapon_chips: Dictionary = _blueprint_layout.get("weapons", {})
		for raw_id in weapon_anchors.keys():
			var socket_id := String(raw_id)
			_draw_anchor_dot(weapon_anchors[raw_id],
				weapon_chips.get(socket_id, Rect2()),
				_hovered_weapon_socket == socket_id or _highlighted_slot_ids.has(socket_id))


func _draw_anchor_dot(anchor: Vector2, chip: Rect2, active: bool) -> void:
	var color := TEAL if active else BRASS
	if chip.size.x > 0.0:
		_draw_anchor_leader(anchor, chip, color)
	# Dark rim keeps the dot readable on both the pale line art and the board.
	draw_circle(anchor, ANCHOR_DOT_RADIUS + 1.5, Color(_token("bg.abyss"), 0.72))
	draw_circle(anchor, ANCHOR_DOT_RADIUS, color)
	if active:
		draw_arc(anchor, ANCHOR_DOT_RADIUS + 3.0, 0.0, TAU, 20, color, 1.5)


## Leader from the dot to the chip edge: a short horizontal stub, then a straight
## diagonal into the chip's left/right edge nearest the dot's height.
func _draw_anchor_leader(anchor: Vector2, chip: Rect2, color: Color) -> void:
	var goes_right := anchor.x < chip.position.x + chip.size.x * 0.5
	var out_x := anchor.x + ANCHOR_LEADER_OUT if goes_right else anchor.x - ANCHOR_LEADER_OUT
	var edge_x := chip.position.x if goes_right else chip.position.x + chip.size.x
	var edge_y := clampf(anchor.y, chip.position.y + 4.0, chip.position.y + chip.size.y - 4.0)
	var points := PackedVector2Array([
		anchor,
		Vector2(out_x, anchor.y),
		Vector2(edge_x, edge_y),
	])
	draw_polyline(points, Color(color, 0.9), 1.5)
	# Small brass rivet where the lead meets the box, so the connection reads.
	draw_circle(Vector2(edge_x, edge_y), 2.0, color)


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
