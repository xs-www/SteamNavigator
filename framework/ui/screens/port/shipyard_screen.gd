class_name ShipyardScreen
extends VBoxContainer
## @static-doc
## 作用：船厂页两种布局共用一页：正常态为「已有船舶卡片 / 面板内 3D 船体舞台 / 组件分类入口」；改装态是画在连续港区 `shipyard` 站位上的船厂工作台——左侧九宫格蓝图底板、中间 3D 窗口、右侧半透明操作坞（舰船数据卡 + 七项分类 + 装配/购买/打造三个独立页签）。规则仍来自 `shipyard.view`，页面不写 `GameState`。
##
## - 关键依赖：`SNShipView`、`SNPartRow`、`SNBadge`、`SNButton`、`SNSectionHeader`、`SNSkin`、`steam_navigator_theme.tres`
##
## ## 外观来源（外部贴图 + SNSkin）
## - 面板仍由 Theme variation 绘制：正常态 `SNInsetPanel` / `SNElevatedPanel`，改装态 `SNBlueprintPanel`（左列）+ `SNGlassPanel`（右列操作坞）；页面不内联手搓 stylebox。
## - 文字与状态色一律取 `SNSkin.color(token)`，本文件不写十六进制颜色；图标取 `SNSkin.icon(id)`。
## - 分类按钮与操作页签用 `Button.icon` + `icon_max_width`（16–18）直接挂皮肤图标，不新增包装容器，按钮 `text` 保持不变（测试与 tooltip 按文字查找）。
## - 分类映射：hulls/boiler/cargo/cabin → shipyard_hull/boiler/cargo/cabin，utility → shipyard_navigation，weapons/misc → nav_shipyard；页签 install/buy/craft → action_confirm/resource_coins/action_add。
## - 槽位卡图标 id 通过槽位描述里的 `icon` 字段交给 `SNSlotTarget`（是否渲染由该组件决定，页面不改它）。
##
## ## 契约与约束
## - `bind(vm, translate)` 接收 Shell 组合后的 shipyard.view（含 refit/category/ship.hull_name/warehouse/candidates/craft/orders/wait_options），不访问 AppContext、QueryBus、CommandBus 或注册表；`_build_page()` 每次整体重建，可重复 bind。
## - `_build_page()` 先把旧根节点 `remove_child` 后 `queue_free`（不是立即 free），所以操作坞里的「完成改装」按钮可以在自己的 `pressed` 信号里重建整页；绑定/切模式/切分类/切页签都走这一个入口。
## - `CATEGORY_ORDER` = 船体/锅炉/货舱/通用/客舱/武器/杂项；`TAB_ORDER` = 装配(install)/购买(buy)/打造(craft)。`set_category` 只接受声明值，未在改装态时先置 refit 并发 `refit_mode_changed(true)`，同时把页签重置为装配；`set_tab` 只切页签（相同值 no-op）。
## - `_body` 固定三列：正常态 `_ship_list_panel / _render_panel / _components_panel`；改装态 `_blueprint_panel / _stage_window / _refit_dock_panel`（`StageWindow` 空 Control、`RefitDock` 操作坞）。正常态保留章节标题与摘要行，改装态不显示标题/摘要行。
## - 改装态画在 3D 港区舞台上：Shell 的 `STAGE_SCREENS` 含 `shipyard→shipyard` 且只在 `_shipyard_refit` 时显示；`_stage_window()` 是可让 3D 透出的空 Control（MOUSE_FILTER_IGNORE），蓝图板/操作坞用 `size_flags_stretch_ratio` 1.2 / 0.25 分配宽度。
## - 左列蓝图：`SNBlueprintPanel` + `SNShipView(CUTAWAY)`（`set_blueprint_backdrop(true)`），侧视/俯视等比绘制、武器框按 `weapon_sockets[].blueprint` 映射，槽位贴片停靠蓝图底部 dock。
## - 右列操作坞：顶部为当前分类标题 + 槽位计数徽标 + `_refit_button`（正常态在摘要行、改装态在坞头，文案 改装/完成改装）；`_ship_data_card()` 显示船名与重量·耐久·货舱槽·客舱槽·武器·剩余货舱；`_category_picker()` 两行七项分类；`_tab_row()` 三个页签。
## - 装配页：当前分类的槽位卡 + 仓库/随船可拖行（`SNPartRow`，登记在 `_hud_rows`）+ 拖放提示；`_highlight_category_slots()` 把可安装槽位贴片高亮成青色（武器分类高亮蓝图武器框），购买/打造页清空高亮。拖放命令仍是 `ship.install_module{module_id, source, slot?, replace_module_id?}`。`_on_slot_drop(payload, slot)` 同时接受完整拖拽载荷（`{kind:"ship_parts", part}`，真实拖放链路）与裸 part 字典（旧调用方）；空槽不带 `replace_module_id`，已占槽带被替换的模块 ID。
## - 购买页：`candidates`（武器分类用 `weapon_candidates`）；打造页：`craft` 配方 + `ship.craft_module`。两者与装配列表完全分离；socket/module 长名用 `_clip_title()` 省略号截断，避免撑宽固定宽度操作坞。
## - `杂项` 分类不显示页签，直接展示打造订单 / 在港等待（6/12/24 h `port.wait`）/ 仓库材料 / 仓库模块；页面不重复通关条件清单（只在总览页）。
## - 所有 can_install/can_uninstall/can_craft、blockers、价格与工时来自 shipyard.view；页面只翻译原因、禁用按钮与组织布局。
## - 武器分类（2026-10-27 玩家反馈）：右侧安装页用 `SNWeaponSocketCard`（本地化炮位名 + 已装武器名 + 卸下 + `ship_weapon` 拖放落点），仓库武器 / 购买候选用可拖行的 `SNWeaponRow`；蓝图上的炮位贴片由 `SNShipView` 承载（`set_weapon_drop_enabled(true)` 时接受同一 `ship_weapon` 载荷）。页面把 socket 标准名（`SN_Socket_Weapon_Port_1` 等）翻译成「左舷 1 号炮位 · 轻型」一类玩家文案并注入 stage 模型（`slot_label` / `slot_title` / `display_name` / `empty_text` / `occupied`），**不在界面上显示后端 socket ID**。拖放落到贴片或槽位卡后统一发 `ship.install_weapon{socket, weapon_id, source}`。
## - 固定尺寸保持：正常态 258 / 弹性 / 300；改装态 560 / 140 / 432；船卡缩略图 210×118；分类按钮 116×34 / 30 / 32；页签 32；蓝图板参数由 Theme 提供（841×299、56/54、66/62）不得改。
## @end-static-doc

signal command_requested(command: StringName, params: Dictionary)
signal refit_mode_changed(active: bool)
signal refit_category_changed(category: String)

const CATEGORY_ORDER := ["hulls", "boiler", "cargo", "utility", "cabin", "weapons", "misc"]
const MODULE_CATEGORIES := ["hulls", "boiler", "cargo", "utility", "cabin", "weapons"]
const TYPE_LABELS := {"hulls": "船体", "boiler": "锅炉", "cargo": "货舱", "utility": "通用", "cabin": "客舱", "weapons": "武器", "misc": "杂项"}
const SLOT_TITLES := {"hull": "ui.label.slot_hull", "boiler": "ui.label.slot_boiler", "navigation_module": "ui.label.slot_navigation", "safety_module": "ui.label.slot_safety", "passenger_cabin": "ui.label.slot_cabin"}
## Refit slots: flat ship slot key + the UI category it belongs to + instance name.
const SLOT_DEFS := [
	{"slot": "hull", "category": "hulls", "instance": "hull"},
	{"slot": "boiler", "category": "boiler", "instance": "boiler"},
	{"slot": "navigation_module", "category": "utility", "instance": "navigation"},
	{"slot": "safety_module", "category": "utility", "instance": "safety"},
	{"slot": "passenger_cabin", "category": "cabin", "instance": "cabin"},
]
const CARGO_CATEGORY := "cargo"
## Weapon UI components (preloaded instead of relying on the global class cache:
## new class_name files are only registered after an editor import scan).
const WEAPON_ROW_SCRIPT := preload("res://framework/ui/components/sn_weapon_row.gd")
const WEAPON_SOCKET_CARD_SCRIPT := preload("res://framework/ui/components/sn_weapon_socket_card.gd")
## Operations dock tabs: install what you own, buy a new module, or craft one.
## Requirement: buying and crafting must not share one scrolling list.
const TAB_ORDER := ["install", "buy", "craft"]
const SHIP_THUMB_PATH := "res://assets/ui/shipyard/ship_thumb_ironclad.png"
## Skin icon ids for the seven category buttons. `utility` has no dedicated
## icon, so it borrows the navigation one; `misc` borrows the shipyard tool icon.
const CATEGORY_ICONS := {
	"hulls": "shipyard_hull",
	"boiler": "shipyard_boiler",
	"cargo": "shipyard_cargo",
	"cabin": "shipyard_cabin",
	"utility": "shipyard_navigation",
	"weapons": "nav_shipyard",
	"misc": "nav_shipyard",
}
## Operation dock tabs: confirm install, spend coins to buy, add a craft order.
const TAB_ICONS := {
	"install": "action_confirm",
	"buy": "resource_coins",
	"craft": "action_add",
}
## Slot-chip icons. They travel with each slot descriptor (`icon` key) so the
## chip component can render them once it exposes an icon API; this page never
## assumes that component's internals.
const SLOT_ICONS := {
	"hull": "shipyard_hull",
	"boiler": "shipyard_boiler",
	"navigation_module": "shipyard_navigation",
	"safety_module": "shipyard_safety",
	"passenger_cabin": "shipyard_cabin",
	"cargo_modules": "shipyard_cargo",
}
## GLB socket names are backend IDs (`SN_Socket_Weapon_Port_1`); the operations
## dock must show player-facing mount names instead. The standard name tokens map
## to localization keys; unknown tokens fall back to a numbered "weapon slot".
const WEAPON_SOCKET_POSITIONS := [
	{"token": "starboard", "key": "ui.weapon_socket.starboard", "fallback": "右舷"},
	{"token": "port", "key": "ui.weapon_socket.port", "fallback": "左舷"},
	{"token": "bow", "key": "ui.weapon_socket.bow", "fallback": "舰首"},
	{"token": "stern", "key": "ui.weapon_socket.stern", "fallback": "舰尾"},
]
const WEAPON_CLASS_KEYS := {
	"light": "ui.weapon_class.light",
	"medium": "ui.weapon_class.medium",
	"heavy": "ui.weapon_class.heavy",
	"side": "ui.weapon_class.side",
	"tower": "ui.weapon_class.tower",
}

## Colour tokens come from `skin.json` (UI Foundation Spec V1 §7) so the page
## never hard-codes a business colour. Instance members are resolved once per
## page build instead of re-reading the manifest on every label.
var TEXT: Color = SNSkin.color("text.light")
var MUTED: Color = SNSkin.color("text.muted")
var BRASS: Color = SNSkin.color("brass.highlight")
var TEAL: Color = SNSkin.color("state.water")
var RED: Color = SNSkin.color("state.danger")
var GREEN: Color = SNSkin.color("state.success")

var _tr: Callable
var _vm: Dictionary = {}
var _refit := false
var _category := "hulls"
var _tab := "install"
var _slots: Array = []
var _stage: SNShipView
var _refit_button: SNButton
var _stage_title: Label
var _hud_rows: Array = []
## Draggable weapon rows of the current weapons install / buy tab (tests + future
## highlight wiring). Other categories never populate it.
var _weapon_rows: Array = []
var _body: HBoxContainer
var _ship_thumb: Texture2D = null


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_vm = vm
	_refit = bool(vm.get("refit", false))
	# Fill the page viewport so the refit dock keeps the 3D window open to the
	# bottom of the screen instead of shrinking to its minimum height.
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var requested := String(vm.get("category", "hulls"))
	_category = requested if CATEGORY_ORDER.has(requested) else "hulls"
	_slots = _build_slots(vm)
	_ship_thumb = null
	if ResourceLoader.exists(SHIP_THUMB_PATH):
		_ship_thumb = load(SHIP_THUMB_PATH) as Texture2D
	_build_page()


## Rebuilds the whole page for the current mode. Old nodes are detached and
## queued for deletion instead of freed immediately, so a button may rebuild the
## page from its own `pressed` signal without freeing itself mid-emit.
func _build_page() -> void:
	_clear()
	_stage = null
	_stage_title = null
	_body = null
	_refit_button = null
	_hud_rows.clear()
	_weapon_rows.clear()
	if _refit:
		_build_refit_page()
	else:
		_build_normal_page()
	_sync_refit_ui()


# ---------------------------------------------------------------------------
# Page chrome
# ---------------------------------------------------------------------------
func _summary_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var stats := _label(_ship_stats_text(_vm), 13, MUTED)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stats)
	_refit_button = SNButton.new()
	_refit_button.variant = SNButton.Variant.PRIMARY
	_refit_button.compact = true
	_refit_button.custom_minimum_size = Vector2(116, 34)
	_refit_button.pressed.connect(_on_toggle_refit)
	row.add_child(_refit_button)
	return row


## Normal mode keeps the list/render/components columns over the normal page.
func _build_normal_page() -> void:
	add_child(_heading(
		_loc("ui.nav.shipyard", "Shipyard"),
		_loc(String(_vm.get("port_name_key", "")), String(_vm.get("port_id", ""))),
		_loc("ui.shipyard.detail", "当前船 · 槽位改装 · 打造与购买")
	))
	add_child(_summary_row())
	if not bool(_vm.get("has_shipyard", false)):
		var warning := _panel()
		_content(warning).add_child(_label(_loc("ui.label.shipyard_absent", ""), 13, RED))
		add_child(warning)
	_body = _body_row()
	add_child(_body)
	_body.add_child(_ship_list_panel())
	_body.add_child(_render_panel())
	_body.add_child(_components_panel())


## Refit mode is drawn over the shipyard's 3D station: the framed blueprint on
## the left, an open window onto the 3D scene in the middle and the translucent
## operations dock on the right. The page heading and the money / durability /
## weight summary line belong to the normal mode only; the refit page takes its
## numbers from the ship data card inside the dock.
func _build_refit_page() -> void:
	_body = _body_row()
	add_child(_body)
	_body.add_child(_blueprint_panel())
	_body.add_child(_stage_window())
	_body.add_child(_refit_dock_panel())


func _body_row() -> HBoxContainer:
	var body := HBoxContainer.new()
	body.name = "ShipyardBody"
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return body


func _sync_refit_ui() -> void:
	if _refit_button != null:
		_refit_button.text = _loc("ui.label.refit_done", "完成改装") if _refit else _loc("ui.label.refit", "改装")
	if _stage != null and is_instance_valid(_stage):
		_stage.set_mode(SNShipView.Mode.CUTAWAY if _refit else SNShipView.Mode.EXTERIOR)


func _on_toggle_refit() -> void:
	_refit = not _refit
	refit_mode_changed.emit(_refit)
	_build_page()


## Enter refit mode on one category. Tests and the shell may call this directly.
func set_category(category: String) -> void:
	if not CATEGORY_ORDER.has(category):
		return
	if not _refit:
		_refit = true
		refit_mode_changed.emit(true)
	_category = category
	_tab = "install"
	refit_category_changed.emit(_category)
	_build_page()


func _ui_set_category(category: String) -> void:
	set_category.call_deferred(category)


## Switches the operations dock tab (`install` / `buy` / `craft`). Tests and the
## shell may call this directly; unknown values are ignored.
func set_tab(tab: String) -> void:
	if not TAB_ORDER.has(tab) or tab == _tab:
		return
	_tab = tab
	_build_page()


func _ui_set_tab(tab: String) -> void:
	set_tab.call_deferred(tab)


## Attaches a skin icon to a button without adding a wrapper node. `SNButton`
## clears the `icon_max_width` theme constant in its own `_ready`, so the
## override is applied once the button enters the tree (immediately if it is
## already ready). The button text stays untouched.
func _apply_button_icon(button: Button, icon_id: String, max_width: int) -> void:
	var texture := SNSkin.icon(icon_id)
	if texture == null:
		return
	button.icon = texture
	if button.is_node_ready():
		button.add_theme_constant_override("icon_max_width", max_width)
		return
	var apply_width := func() -> void:
		button.add_theme_constant_override("icon_max_width", max_width)
	button.ready.connect(apply_width, CONNECT_ONE_SHOT)


# ---------------------------------------------------------------------------
# Normal layout: owned ships / live render / components
# ---------------------------------------------------------------------------
func _ship_list_panel() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	panel.custom_minimum_size = Vector2(258, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _content(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _label(_loc("ui.label.ship_list", "已有船舶"), 17, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_badge(_loc("ui.label.ship_list_count", "1 / 1"), SNBadge.Tone.NEUTRAL))
	box.add_child(header)
	box.add_child(_ship_card())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label(_ship_slot_summary(_vm), 11, MUTED))
	return panel


func _ship_card() -> Control:
	var card := _panel()
	card.theme_type_variation = &"SNElevatedPanel"
	var box := _content(card)
	if _ship_thumb != null:
		var thumb := TextureRect.new()
		thumb.texture = _ship_thumb
		thumb.custom_minimum_size = Vector2(210, 118)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.clip_contents = true
		box.add_child(thumb)
	else:
		var thumb_placeholder := PanelContainer.new()
		thumb_placeholder.theme_type_variation = &"SNInsetPanel"
		thumb_placeholder.custom_minimum_size = Vector2(210, 118)
		var placeholder_label := _label(_loc("ui.label.ship_thumb_missing", "船舶缩略图"), 12, MUTED)
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		thumb_placeholder.add_child(placeholder_label)
		box.add_child(thumb_placeholder)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var ship: Dictionary = _vm.get("ship", {})
	var hull_name := String(ship.get("hull_name", ""))
	if hull_name.is_empty():
		hull_name = _loc(String(ship.get("hull_id", "")), String(ship.get("hull_id", "")))
	var name_label := _label(hull_name, 16, TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	name_row.add_child(_badge(_loc("ui.tag.current_ship", "当前"), SNBadge.Tone.SUCCESS))
	box.add_child(name_row)
	box.add_child(_stat_line(_loc("ui.label.weight", "重量"), "%s / %s" % [
		_fmt(float(ship.get("total_weight", 0.0))), _fmt(float(ship.get("max_weight", 0.0)))
	]))
	box.add_child(_stat_line(_loc("ui.label.durability", "耐久"), "%s / %s" % [
		_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0)))
	]))
	box.add_child(_stat_line(_loc("ui.label.cargo_slots", "货舱"), "%d / %d" % [
		int(ship.get("cargo_used", 0)), int(ship.get("cargo_slots", 0))
	]))
	box.add_child(_stat_line(_loc("ui.label.cabin_slots", "客舱"), "%d / %d" % [
		int(ship.get("cabin_used", 0)), int(ship.get("cabin_slots", 0))
	]))
	var worst := clampf(float(ship.get("worst_module_condition", 1.0)), 0.0, 1.0)
	if worst < 1.0:
		box.add_child(_stat_line(_loc("ui.label.damaged_modules", "受损部件"), "%d · %d%%" % [
			int(ship.get("damaged_modules", 0)), int(round(worst * 100.0)),
		]))
	return card


func _stat_line(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _label(label_text, 12, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_label(value_text, 13, TEXT))
	return row


func _render_panel() -> Control:
	var panel := _panel()
	panel.theme_type_variation = &"SNElevatedPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _content(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_stage_title = _label(_loc("ui.label.current_ship", "当前船只"), 16, BRASS)
	_stage_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_stage_title)
	box.add_child(header)
	_stage = _make_stage(SNShipView.Mode.EXTERIOR, Vector2(520, 340))
	box.add_child(_stage)
	return panel


func _components_panel() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _content(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _label(_loc("ui.label.components", "组件"), 17, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_badge(_loc("ui.label.draggable_count", "%d 可拖") % _draggable_count(), SNBadge.Tone.SUCCESS if _draggable_count() > 0 else SNBadge.Tone.NEUTRAL))
	box.add_child(header)
	box.add_child(_label(_loc("ui.hint.components", "点击分类进入改装，查看槽位、仓库/随船部件、购买与打造。"), 11, MUTED))
	for category in MODULE_CATEGORIES:
		box.add_child(_category_row(category))
	var guide := PanelContainer.new()
	guide.theme_type_variation = &"SNInsetPanel"
	var guide_box := _content(guide)
	guide_box.add_child(_label(_loc("ui.label.refit_flow", "改装流程"), 13, TEAL))
	guide_box.add_child(_wrap_label(_loc("ui.hint.refit_flow", "① 选择分类进入改装\n② 查看槽位与已装模块\n③ 装配、购买或打造"), 11, MUTED))
	box.add_child(guide)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label(_ship_slot_summary(_vm), 11, MUTED))
	return panel


func _category_row(category: String) -> Control:
	var button := SNButton.new()
	button.variant = SNButton.Variant.GHOST
	button.compact = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 40)
	button.text = "   " + String(TYPE_LABELS.get(category, category))
	button.tooltip_text = _loc("ui.hint.components", "")
	_apply_button_icon(button, String(CATEGORY_ICONS.get(category, "")), 18)
	button.pressed.connect(_ui_set_category.bind(category))
	var count := _label(_slot_count_text(_vm, category), 11, TEAL)
	count.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	count.offset_left = -120
	count.offset_right = -14
	count.offset_top = 13
	count.offset_bottom = 29
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	return button


# ---------------------------------------------------------------------------
# Refit layout: blueprint board / 3D window / operations dock
# ---------------------------------------------------------------------------
## Left column: the nine-slice blueprint board with the per-hull side/top line
## art and the slot chips (drag targets). No title or badge: the page reads as a
## working blueprint instead of a test bench.
func _blueprint_panel() -> Control:
	var panel := _panel()
	panel.theme_type_variation = &"SNBlueprintPanel"
	panel.custom_minimum_size = Vector2(560, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.2
	var box := _content(panel)
	_stage = _make_stage(SNShipView.Mode.CUTAWAY, Vector2(520, 380), true)
	box.add_child(_stage)
	return panel


## Middle column: an empty window. The 3D shipyard station shows through it, so
## the page never paints an opaque backdrop over the 3D scene.
func _stage_window() -> Control:
	var window := Control.new()
	window.name = "StageWindow"
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.custom_minimum_size = Vector2(140, 0)
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.size_flags_stretch_ratio = 1.0
	return window


## Right column: translucent dock with the ship data card, the category picker,
## the install / buy / craft tabs and the tab body.
func _refit_dock_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "RefitDock"
	panel.theme_type_variation = &"SNGlassPanel"
	panel.custom_minimum_size = Vector2(432, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.25
	var box := _content(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _label(_category_label(_category), 17, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_badge(_category_count_text(_category), SNBadge.Tone.NEUTRAL))
	_refit_button = SNButton.new()
	_refit_button.variant = SNButton.Variant.PRIMARY
	_refit_button.compact = true
	_refit_button.custom_minimum_size = Vector2(96, 32)
	_refit_button.pressed.connect(_on_toggle_refit)
	header.add_child(_refit_button)
	box.add_child(header)
	box.add_child(_ship_data_card())
	box.add_child(_section_label(_loc("ui.label.category_tabs", "部件分类")))
	box.add_child(_category_picker())
	if _category != "misc":
		box.add_child(_tab_row())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	box.add_child(scroll)
	_build_tab_body(body)
	_highlight_category_slots()
	return panel


## Ship-wide numbers live here in the dock instead of a summary line over the
## blueprint: hull name plus weight / durability / cargo / cabin / weapon counts.
func _ship_data_card() -> Control:
	var card := _panel()
	card.theme_type_variation = &"SNInsetPanel"
	var box := _content(card)
	var ship: Dictionary = _vm.get("ship", {})
	var hull_name := String(ship.get("hull_name", ""))
	if hull_name.is_empty():
		hull_name = _loc(String(ship.get("hull_id", "")), String(ship.get("hull_id", "")))
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	var name_label := _label(hull_name, 15, TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	var damaged := int(ship.get("damaged_modules", 0))
	if damaged > 0:
		title_row.add_child(_badge("%s %d" % [_loc("ui.label.damaged_modules", "受损部件"), damaged], SNBadge.Tone.WARNING))
	box.add_child(title_row)
	box.add_child(_label(_loc("ui.label.ship_stats", "船体数据"), 11, TEAL))
	var sockets: Array = ship.get("weapon_sockets", [])
	var mounted := 0
	for socket in sockets:
		if socket is Dictionary and not String(socket.get("weapon_id", "")).is_empty():
			mounted += 1
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	_stat_cell(grid, _loc("ui.label.weight_short", "重量"), "%s / %s" % [
		_fmt(float(ship.get("total_weight", 0.0))), _fmt(float(ship.get("max_weight", 0.0))),
	])
	_stat_cell(grid, _loc("ui.label.durability_short", "耐久"), "%s / %s" % [
		_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0))),
	])
	_stat_cell(grid, _loc("ui.label.cargo_slots", "货舱槽"), "%d / %d" % [
		int(ship.get("cargo_used", 0)), int(ship.get("cargo_slots", 0)),
	])
	_stat_cell(grid, _loc("ui.label.cabin_slots", "客舱槽"), "%d / %d" % [
		int(ship.get("cabin_used", 0)), int(ship.get("cabin_slots", 0)),
	])
	_stat_cell(grid, _loc("ui.category.weapons", "武器"), "%d / %d" % [mounted, sockets.size()])
	_stat_cell(grid, _loc("ui.label.free_capacity", "剩余货舱"), "%s / %s" % [
		_fmt(float(ship.get("free_cargo_capacity", 0.0))), _fmt(float(ship.get("cargo_capacity", 0.0))),
	])
	box.add_child(grid)
	return card


func _stat_cell(grid: GridContainer, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := _label(label_text, 11, MUTED)
	title.custom_minimum_size = Vector2(64, 0)
	row.add_child(title)
	var value := _label(value_text, 12, TEXT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	grid.add_child(row)


## Seven part categories in a compact two-row grid (no separate tab column).
func _category_picker() -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for category in CATEGORY_ORDER:
		var button := SNButton.new()
		button.variant = SNButton.Variant.PRIMARY if category == _category else SNButton.Variant.SECONDARY
		button.compact = true
		button.custom_minimum_size = Vector2(0, 30)
		button.text = _category_label(category)
		_apply_button_icon(button, String(CATEGORY_ICONS.get(category, "")), 16)
		button.pressed.connect(_ui_set_category.bind(category))
		grid.add_child(button)
	return grid


func _tab_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "RefitTabs"
	row.add_theme_constant_override("separation", 6)
	for tab in TAB_ORDER:
		var button := SNButton.new()
		button.variant = SNButton.Variant.PRIMARY if tab == _tab else SNButton.Variant.SECONDARY
		button.compact = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 32)
		button.text = _tab_label(tab)
		_apply_button_icon(button, String(TAB_ICONS.get(tab, "")), 16)
		button.pressed.connect(_ui_set_tab.bind(tab))
		row.add_child(button)
	return row


func _tab_label(tab: String) -> String:
	match tab:
		"buy":
			return _loc("ui.tab.buy", "购买")
		"craft":
			return _loc("ui.tab.craft", "打造")
		_:
			return _loc("ui.tab.install", "装配")


func _build_tab_body(box: VBoxContainer) -> void:
	if _category == "misc":
		_build_misc_body(box)
		return
	match _tab:
		"buy":
			_build_buy_body(box)
		"craft":
			_build_craft_body(box)
		_:
			_build_install_body(box)


## Install: current slots plus the warehouse / on-board modules that can be
## dragged onto the blueprint's slot chips.
func _build_install_body(box: VBoxContainer) -> void:
	if _category == "weapons":
		_build_weapon_install_body(box)
		return
	var slot_rows := _slot_rows_for_category(_category)
	box.add_child(_section_label(_loc("ui.label.section_slots", "槽位")))
	if slot_rows.is_empty():
		box.add_child(_label(_loc("ui.label.no_slot_for_type", "当前船体没有该类型的槽位。"), 12, MUTED))
	for slot in slot_rows:
		box.add_child(_slot_card(slot))
	var owned := _owned_parts(_category)
	box.add_child(_section_label(_loc("ui.label.owned_parts", "仓库 / 随船")))
	if owned.is_empty():
		box.add_child(_label(_loc("ui.label.no_owned_parts", "仓库和随船都没有该分类的部件。"), 11, MUTED))
	else:
		box.add_child(_label(_loc("ui.hint.drag_install", "把仓库或随船部件拖到左侧蓝图的槽位即可装配。"), 11, MUTED))
		for part in owned:
			box.add_child(_part_row(part))


func _build_buy_body(box: VBoxContainer) -> void:
	if _category == "weapons":
		_build_weapon_buy_body(box)
		return
	var candidates := _candidates_for_category(_category)
	box.add_child(_section_label(_loc("ui.label.buy_and_install", "购买并安装")))
	if candidates.is_empty():
		box.add_child(_label(_loc("ui.label.no_candidates", "当前没有可购买的模块"), 12, MUTED))
	for candidate in candidates:
		box.add_child(_candidate_card(candidate))


func _build_craft_body(box: VBoxContainer) -> void:
	var recipes := _recipes_for_category(_category)
	box.add_child(_section_label(_loc("ui.label.craft_section", "按配方打造")))
	box.add_child(_label(_loc("ui.hint.craft_section", "打造会先产生订单，完工后进入当前港仓库。"), 11, MUTED))
	if recipes.is_empty():
		box.add_child(_label(_loc("ui.label.no_recipes", "当前没有可打造的配方"), 12, MUTED))
	var has_shipyard := bool(_vm.get("has_shipyard", false))
	for recipe in recipes:
		box.add_child(_craft_recipe(recipe, has_shipyard))


## Highlight the slot chips that accept the current category, so a drag has an
## obvious target. Weapons highlight their blueprint socket frames instead.
func _highlight_category_slots() -> void:
	if _stage == null or not is_instance_valid(_stage):
		return
	if _tab != "install" or _category == "misc":
		_stage.highlight_slots([])
		return
	if _category == "weapons":
		_stage.highlight_slots(_weapon_socket_ids())
		return
	var ids: Array = []
	for slot in _slot_rows_for_category(_category):
		ids.append(String(slot.get("id", "")))
	_stage.highlight_slots(ids)


## ---------------------------------------------------------------------------
## Weapons: player-facing mount labels + drag install (2026-10-27 feedback)
## ---------------------------------------------------------------------------

## Only the weapons install tab accepts weapon drops on the blueprint chips.
func _weapon_drag_enabled() -> bool:
	return _refit and _category == "weapons" and _tab == "install"


## Ship model handed to `SNShipView`: every weapon socket is enriched with the
## localized mount label / mounted weapon name the blueprint chips paint. The
## backend keys (`socket`, `weapon_id`, ...) stay untouched for commands.
func _stage_ship_model() -> Dictionary:
	var model: Dictionary = (_vm.get("ship", {}) as Dictionary).duplicate(true)
	model["weapon_sockets"] = _enriched_weapon_sockets()
	return model


## `shipyard.view.ship.weapon_sockets` + localized mount / weapon display fields.
func _enriched_weapon_sockets() -> Array:
	var rows: Array = []
	for raw_socket in _vm.get("ship", {}).get("weapon_sockets", []):
		if not (raw_socket is Dictionary):
			continue
		var socket: Dictionary = (raw_socket as Dictionary).duplicate(true)
		var socket_name := String(socket.get("socket", ""))
		var weapon_id := String(socket.get("weapon_id", ""))
		socket["slot_label"] = _weapon_socket_short_label(socket_name)
		socket["socket_label"] = socket["slot_label"]
		socket["slot_title"] = _weapon_socket_title(socket)
		socket["display_name"] = _loc(String(socket.get("name_key", "")), weapon_id) if not weapon_id.is_empty() else ""
		socket["empty_text"] = _loc("ui.label.slot_empty", "空槽位")
		socket["installed_tag"] = _loc("ui.tag.installed", "已装")
		socket["uninstall_text"] = _loc("ui.button.uninstall", "卸下")
		socket["weight_label"] = _loc("ui.label.weight_short", "重量")
		socket["damage_label"] = _loc("ui.label.weapon_socket_damage", "伤害")
		socket["drop_hint"] = _loc("ui.hint.weapon_socket_drop", "把仓库武器拖到这里")
		socket["occupied"] = not weapon_id.is_empty()
		rows.append(socket)
	return rows


## Short blueprint-chip label: 左舷1 / 右舷2 / 舰尾 / 舰首 / 武器槽位 3.
func _weapon_socket_short_label(socket_name: String) -> String:
	var position := _weapon_socket_position(socket_name)
	var number := _weapon_socket_number(socket_name)
	if position.is_empty():
		return _loc("ui.weapon_socket.slot", "武器槽位")
	if number <= 0:
		return position
	return _loc("ui.weapon_socket.short", "%s%d") % [position, number]


## Player-facing mount name: 左舷 1 号炮位 · 轻型.
func _weapon_socket_title(socket: Dictionary) -> String:
	var socket_name := String(socket.get("socket", ""))
	var position := _weapon_socket_position(socket_name)
	var number := _weapon_socket_number(socket_name)
	var slot_text := ""
	if position.is_empty():
		slot_text = _loc("ui.weapon_socket.slot", "武器槽位")
		var index := int(socket.get("socket_index", -1))
		if index >= 0:
			slot_text = "%s %d" % [slot_text, index + 1]
	elif number > 0:
		slot_text = _loc("ui.weapon_socket.title", "%s %d 号炮位") % [position, number]
	else:
		slot_text = _loc("ui.weapon_socket.title_no_index", "%s炮位") % position
	var class_label := _weapon_class_label(String(socket.get("socket_class", "")))
	return slot_text if class_label.is_empty() else "%s · %s" % [slot_text, class_label]


## Mount title from a backend socket name only (warehouse buttons / buy rows).
func _weapon_socket_title_by_name(socket_name: String) -> String:
	for raw_socket in _enriched_weapon_sockets():
		if raw_socket is Dictionary and String((raw_socket as Dictionary).get("socket", "")) == socket_name:
			return String((raw_socket as Dictionary).get("slot_title", ""))
	return _weapon_socket_title({"socket": socket_name})


func _weapon_socket_position(socket_name: String) -> String:
	var lower := socket_name.to_lower()
	for entry in WEAPON_SOCKET_POSITIONS:
		if lower.contains(String(entry["token"])):
			return _loc(String(entry["key"]), String(entry["fallback"]))
	return ""


## Trailing `_N` of the standard socket name (0 when the mount has no index).
func _weapon_socket_number(socket_name: String) -> int:
	var underscore := socket_name.rfind("_")
	if underscore < 0 or underscore + 1 >= socket_name.length():
		return 0
	var suffix := socket_name.substr(underscore + 1)
	return suffix.to_int() if suffix.is_valid_int() else 0


func _weapon_class_label(weapon_class: String) -> String:
	var key := weapon_class.to_lower()
	if key.is_empty():
		return ""
	var loc_key := String(WEAPON_CLASS_KEYS.get(key, ""))
	return _loc(loc_key, weapon_class) if not loc_key.is_empty() else weapon_class


func _weapon_payload(weapon: Dictionary, source: String, name: String) -> Dictionary:
	return {
		"kind": "ship_weapon",
		"weapon_id": String(weapon.get("weapon_id", "")),
		"weapon_class": String(weapon.get("weapon_class", "")),
		"source": source,
		"name": name,
	}


## A weapon dropped on a blueprint mount / socket card: the command layer re-checks
## class, warehouse qty, weight and money; the page only forwards the intent.
func _on_weapon_drop(payload: Dictionary, socket: Dictionary) -> void:
	if String(payload.get("kind", "")) != "ship_weapon":
		return
	var weapon_id := String(payload.get("weapon_id", ""))
	var socket_name := String(socket.get("socket", ""))
	var source := String(payload.get("source", "warehouse"))
	if weapon_id.is_empty() or socket_name.is_empty():
		return
	if not ["warehouse", "purchase"].has(source):
		source = "warehouse"
	command_requested.emit(&"ship.install_weapon", {
		"socket": socket_name,
		"weapon_id": weapon_id,
		"source": source,
	})


## Weapons install tab: one friendly socket card per mount + draggable warehouse rows.
func _build_weapon_install_body(box: VBoxContainer) -> void:
	box.add_child(_section_label(_loc("ui.label.weapon_sockets", "武器槽位")))
	var sockets := _enriched_weapon_sockets()
	if sockets.is_empty():
		box.add_child(_label(_loc("ui.label.no_weapon_sockets", "当前船体没有舰载武器槽位。"), 12, MUTED))
	else:
		box.add_child(_label(_loc("ui.hint.weapon_drag_install", ""), 11, MUTED))
		for socket in sockets:
			var card: Variant = WEAPON_SOCKET_CARD_SCRIPT.new()
			card.configure(socket)
			var socket_name := String(socket.get("socket", ""))
			card.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
				command_requested.emit(command, params)
			)
			card.weapon_dropped.connect(_on_weapon_drop)
			card.hovered.connect(func(_hovered_socket: String) -> void: _highlight_weapon_socket(socket_name))
			card.unhovered.connect(_highlight_all_weapon_sockets)
			box.add_child(card)
	var warehouse_weapons: Array = _vm.get("warehouse", {}).get("weapons", [])
	if not warehouse_weapons.is_empty():
		box.add_child(_section_label(_loc("ui.label.warehouse_weapons", "仓库武器")))
		for weapon in warehouse_weapons:
			if weapon is Dictionary:
				box.add_child(_warehouse_weapon_row(weapon as Dictionary))


func _build_weapon_buy_body(box: VBoxContainer) -> void:
	box.add_child(_section_label(_loc("ui.label.buy_and_install", "购买并安装")))
	var candidates: Array = _vm.get("weapon_candidates", [])
	if candidates.is_empty():
		box.add_child(_label(_loc("ui.label.no_weapon_candidates", "当前没有可购买的武器"), 12, MUTED))
	for candidate in candidates:
		if candidate is Dictionary:
			box.add_child(_weapon_candidate_row(candidate as Dictionary))


func _build_misc_body(box: VBoxContainer) -> void:
	# Craft orders + port wait used to live in the deleted lower panels.
	box.add_child(_section_label(_loc("ui.label.orders", "船厂工单")))
	var orders: Array = _vm.get("orders", [])
	if orders.is_empty():
		box.add_child(_label(_loc("ui.label.no_orders", "当前没有进行中的船厂工单"), 12, MUTED))
	for order in orders:
		if order is Dictionary:
			box.add_child(_order_row(order))
	var wait_row := HBoxContainer.new()
	wait_row.add_theme_constant_override("separation", 8)
	wait_row.add_child(_label(_loc("ui.button.wait", "在港等待"), 13, MUTED))
	for raw_hours in _vm.get("wait_options", [6, 12, 24]):
		var hours := int(raw_hours)
		if hours > 0:
			wait_row.add_child(_command_button("%d h" % hours, &"port.wait", {"hours": hours}))
	box.add_child(wait_row)
	box.add_child(_label(_loc("ui.hint.wait", ""), 11, MUTED))
	# Warehouse materials: store/take used to live in the deleted warehouse panel.
	box.add_child(_section_label(_loc("ui.label.materials", "仓库材料")))
	var warehouse: Dictionary = _vm.get("warehouse", {})
	var materials: Array = warehouse.get("materials", [])
	if materials.is_empty():
		box.add_child(_label(_loc("ui.label.no_materials", "仓库里没有材料"), 12, MUTED))
	for material in materials:
		if material is Dictionary:
			box.add_child(_warehouse_material_row(material))
	# Warehouse modules keep their take/install entry even outside their category.
	box.add_child(_section_label(_loc("ui.label.warehouse_modules", "仓库模块")))
	var modules: Array = warehouse.get("modules", [])
	if modules.is_empty():
		box.add_child(_label(_loc("ui.error.warehouse_empty", "仓库里没有模块"), 12, MUTED))
	for module in modules:
		if module is Dictionary:
			box.add_child(_warehouse_module_row(module, bool(_vm.get("has_shipyard", false))))


func _order_row(order: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name := _label(_loc(String(order.get("name_key", "")), String(order.get("module_id", ""))), 13, TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(_label(_loc("ui.label.order_remaining", "") % _fmt(float(order.get("remaining_hours", 0.0))), 12, TEAL))
	if not bool(order.get("at_current_port", true)):
		row.add_child(_label(_loc(String(order.get("port_name_key", "")), String(order.get("port_id", ""))), 11, MUTED))
	return row


func _slot_card(slot: Dictionary) -> Control:
	var card := _panel()
	card.theme_type_variation = &"SNInsetPanel"
	var box := _content(card)
	var category := String(slot.get("category", ""))
	var installed: Dictionary = slot.get("module", {})
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _label(String(slot.get("title", "")), 14, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_title(title)
	header.add_child(title)
	if bool(slot.get("fixed", false)):
		header.add_child(_badge(_loc("ui.tag.fixed_slot", "固定槽"), SNBadge.Tone.WARNING))
	box.add_child(header)
	var module_id := String(installed.get("module_id", ""))
	if module_id.is_empty():
		box.add_child(_label(_loc("ui.label.slot_empty", "空槽位"), 14, MUTED))
		box.add_child(_label(String(slot.get("tooltip", "")), 11, MUTED))
		return card
	box.add_child(_label(String(installed.get("name", module_id)), 15, TEXT))
	var condition := clampf(float(slot.get("condition", 1.0)), 0.0, 1.0)
	if condition < 1.0:
		var tone := SNBadge.Tone.DANGER if condition <= 0.0 else SNBadge.Tone.WARNING
		var status_text := "%s %d%%" % [_loc("ui.label.status", "状态"), int(round(condition * 100.0))]
		box.add_child(_badge(status_text, tone))
	var installed_row := _installed_row(module_id)
	if not installed_row.is_empty():
		var effect_text := _module_effect_text(category, installed_row.get("effect", {}))
		if not effect_text.is_empty():
			box.add_child(_wrap_label(_loc("ui.label.effect", "") + "：" + effect_text, 11, TEAL))
		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 8)
		var meta := _label("%s %s · tier %d" % [
			_loc("ui.label.weight_short", "重量"),
			_fmt(float(installed_row.get("weight", 0.0))),
			int(installed_row.get("tier", 1)),
		], 11, MUTED)
		meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(meta)
		var uninstall := _compact_command_button(_loc("ui.button.uninstall", "卸下"), &"ship.uninstall_module", {"module_id": module_id})
		var blockers: Array = installed_row.get("uninstall_blockers", [])
		uninstall.disabled = not bool(installed_row.get("can_uninstall", false))
		action_row.add_child(uninstall)
		box.add_child(action_row)
		var reason := _blocker_text(blockers)
		if not reason.is_empty():
			box.add_child(_wrap_label(reason, 11, MUTED))
	return card


func _installed_row(module_id: String) -> Dictionary:
	var ship: Dictionary = _vm.get("ship", {})
	for row in ship.get("modules", []):
		if row is Dictionary and String(row.get("module_id", "")) == module_id:
			return row
	return {}


# ---------------------------------------------------------------------------
# Slot model
# ---------------------------------------------------------------------------
func _build_slots(vm: Dictionary) -> Array:
	var ship: Dictionary = vm.get("ship", {})
	var by_slot: Dictionary = {}
	for module in ship.get("modules", []):
		if not (module is Dictionary):
			continue
		var slot_name := String(module.get("slot", ""))
		if not by_slot.has(slot_name):
			by_slot[slot_name] = []
		by_slot[slot_name].append(module)
	var slots: Array = []
	for slot_def in SLOT_DEFS:
		var slot_name := String(slot_def["instance"])
		if slot_name == "cabin" and int(ship.get("cabin_slots", 0)) < 1:
			continue
		var installed: Array = by_slot.get(slot_name, [])
		slots.append(_slot_row(slot_def, 0, installed[0] if installed.size() > 0 else null))
	var cargo_installed: Array = by_slot.get("cargo", [])
	var cargo_slots := maxi(int(ship.get("cargo_slots", 0)), cargo_installed.size())
	for index in cargo_slots:
		slots.append(_cargo_slot_row(index, cargo_installed[index] if index < cargo_installed.size() else null))
	return slots


func _slot_row(slot_def: Dictionary, index: int, installed: Variant) -> Dictionary:
	var slot_name := String(slot_def["slot"])
	var title := _loc(String(SLOT_TITLES.get(slot_name, slot_name)), String(TYPE_LABELS.get(String(slot_def["category"]), slot_name)))
	return _make_slot_row(slot_name, String(slot_def["category"]), index, title, installed, slot_name in ["hull", "boiler"])


func _cargo_slot_row(index: int, installed: Variant) -> Dictionary:
	var title := _loc("ui.label.slot_cargo", "货舱槽 %d") % (index + 1)
	return _make_slot_row("cargo_modules", CARGO_CATEGORY, index, title, installed, false)


func _make_slot_row(slot_name: String, category: String, index: int, title: String, installed: Variant, fixed: bool) -> Dictionary:
	var module_id := ""
	var name := ""
	var hint := ""
	var tooltip := ""
	var condition := 1.0
	if installed is Dictionary:
		module_id = String(installed.get("module_id", ""))
		name = _loc(String(installed.get("name_key", "")), module_id)
		hint = "· " + _fmt(float(installed.get("weight", 0.0)))
		tooltip = _loc(String(installed.get("description_key", "")), "")
		condition = clampf(float(installed.get("condition", 1.0)), 0.0, 1.0)
	return {
		"id": "%s_%d" % [slot_name, index],
		"slot": slot_name,
		"category": category,
		"index": index,
		"icon": String(SLOT_ICONS.get(slot_name, CATEGORY_ICONS.get(category, ""))),
		"title": title,
		"module": {"module_id": module_id, "name": name},
		"replace_module_id": module_id,
		"fixed": fixed,
		"hint": hint,
		"condition": condition,
		"empty_text": _loc("ui.label.slot_empty", "空槽位"),
		"tooltip": tooltip if not tooltip.is_empty() else _loc("ui.hint.slot_drop", "把同槽位的仓库/随船部件拖到这里。"),
	}


## `blueprint_backdrop` tells the stage that the column already paints the
## nine-slice blueprint board, so the cutaway must not add its own dark boxes.
func _make_stage(mode: int, minimum: Vector2, blueprint_backdrop: bool = false) -> SNShipView:
	var stage := SNShipView.new()
	stage.name = "ShipStage"
	stage.custom_minimum_size = minimum
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.set_ship_model(_stage_ship_model())
	stage.set_blueprint_backdrop(blueprint_backdrop)
	stage.set_slots(_slots)
	stage.slot_drop_requested.connect(_on_slot_drop)
	stage.slot_activated.connect(_on_slot_activated)
	# Weapon mounts own their own drop contract (`ship_weapon` payload, socket-class
	# gate); the blueprint chips and the right-hand socket cards both forward here.
	if stage.has_signal("weapon_drop_requested"):
		stage.weapon_drop_requested.connect(_on_weapon_drop)
	stage.set_mode(mode)
	if stage.has_method("set_weapon_drop_enabled"):
		stage.set_weapon_drop_enabled(_weapon_drag_enabled())
	if _category == "weapons":
		stage.highlight_slots(_weapon_socket_ids())
	# 2.5D 舞台：正常态用真实 3D 船身，改装态仍走纵剖图贴图。船体模型由船体定义
	# 的 information.model 资产键解析（来自内容模组）；解析不到时自动回退程序化占位。
	var hull_model_path := String(_vm.get("ship", {}).get("hull_model_path", ""))
	if mode == SNShipView.Mode.EXTERIOR and (not hull_model_path.is_empty() or SNShipStage3D.is_supported()):
		stage.set_renderer(SNShipStage3D.new())
	return stage


func _weapon_socket_ids() -> Array:
	var ids: Array = []
	for socket in _vm.get("ship", {}).get("weapon_sockets", []):
		if socket is Dictionary:
			var socket_id := String(socket.get("socket", ""))
			if not socket_id.is_empty():
				ids.append(socket_id)
	return ids


func _highlight_weapon_socket(socket_id: String) -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.highlight_slots([socket_id])


func _highlight_all_weapon_sockets() -> void:
	if _stage != null and is_instance_valid(_stage) and _category == "weapons":
		_stage.highlight_slots(_weapon_socket_ids())


# ---------------------------------------------------------------------------
# Parts HUD / operations building blocks
# ---------------------------------------------------------------------------
func _slot_rows_for_category(category: String) -> Array:
	var rows: Array = []
	for slot in _slots:
		if slot is Dictionary and String(slot.get("category", "")) == category:
			rows.append(slot)
	return rows


func _owned_parts(category: String) -> Array:
	var rows: Array = []
	for part in _part_rows_for_category(_vm, category):
		if part is Dictionary and ["warehouse", "transit"].has(String(part.get("source", ""))):
			rows.append(part)
	return rows


func _candidates_for_category(category: String) -> Array:
	var rows: Array = []
	for candidate in _vm.get("candidates", []):
		if candidate is Dictionary and String(candidate.get("category", "")) == category:
			if bool(candidate.get("installed", false)):
				continue
			rows.append(candidate)
	return rows


func _recipes_for_category(category: String) -> Array:
	var rows: Array = []
	for recipe in _vm.get("craft", []):
		if recipe is Dictionary and String(recipe.get("category", "")) == category:
			rows.append(recipe)
	return rows


func _part_row(part: Dictionary) -> SNPartRow:
	var row := SNPartRow.new()
	row.configure(
		part,
		String(part.get("tag", "")),
		part.get("tag_color", MUTED),
		String(part.get("meta", "")),
		String(part.get("hint", "")),
		bool(part.get("draggable", false))
	)
	row.activated.connect(_on_part_activated)
	_hud_rows.append(row)
	return row


func _part_rows_for_category(vm: Dictionary, category: String) -> Array:
	var rows: Array = []
	var ship: Dictionary = vm.get("ship", {})
	var installed: Array = []
	for module in ship.get("modules", []):
		if module is Dictionary and String(module.get("category", "")) == category:
			installed.append(module)
	for module in installed:
		var name := _loc(String(module.get("name_key", "")), String(module.get("module_id", "")))
		rows.append({
			"module_id": String(module.get("module_id", "")),
			"name": name,
			"category": category,
			"source": "installed",
			"tag": _loc("ui.tag.installed", "已装"),
			"tag_color": GREEN,
			"draggable": false,
			"meta": "%s %s" % [_loc("ui.label.weight_short", "重量"), _fmt(float(module.get("weight", 0.0)))],
			"hint": "",
		})
	var warehouse: Dictionary = vm.get("warehouse", {})
	for module in warehouse.get("modules", []):
		if not (module is Dictionary) or String(module.get("category", "")) != category:
			continue
		var name := _loc(String(module.get("name_key", "")), String(module.get("module_id", "")))
		var can_install := bool(module.get("can_install", false))
		var blockers := _blocker_text(module.get("blockers", []))
		rows.append({
			"module_id": String(module.get("module_id", "")),
			"name": name,
			"category": category,
			"source": "warehouse",
			"can_install": can_install,
			"tag": _loc("ui.tag.warehouse", "仓库"),
			"tag_color": TEAL,
			"draggable": can_install,
			"meta": "×%d · %s %s" % [maxi(1, int(module.get("qty", 1))), _loc("ui.label.weight_short", "重量"), _fmt(float(module.get("weight", 0.0)))],
			"hint": _loc("ui.hint.drag_to_slot", "拖到左侧槽位") if blockers.is_empty() else blockers,
		})
	for module in ship.get("transit_modules", []):
		if not (module is Dictionary) or String(module.get("category", "")) != category:
			continue
		var name := _loc(String(module.get("name_key", "")), String(module.get("module_id", "")))
		rows.append({
			"module_id": String(module.get("module_id", "")),
			"name": name,
			"category": category,
			"source": "transit",
			"can_install": true,
			"tag": _loc("ui.tag.transit", "随船"),
			"tag_color": TEAL,
			"draggable": true,
			"meta": "×%d · %s %s" % [maxi(1, int(module.get("qty", 1))), _loc("ui.label.weight_short", "重量"), _fmt(float(module.get("weight", 0.0)))],
			"hint": _loc("ui.hint.drag_to_slot", "拖到左侧槽位"),
		})
	for candidate in vm.get("candidates", []):
		if not (candidate is Dictionary) or String(candidate.get("category", "")) != category:
			continue
		if bool(candidate.get("installed", false)):
			continue
		var blockers := _blocker_text(candidate.get("blockers", []))
		var name := _loc(String(candidate.get("name_key", "")), String(candidate.get("module_id", "")))
		rows.append({
			"module_id": String(candidate.get("module_id", "")),
			"name": name,
			"category": category,
			"source": "purchase",
			"can_install": bool(candidate.get("can_install", false)),
			"tag": _loc("ui.tag.purchase", "购买 %d") % int(candidate.get("price", 0)),
			"tag_color": BRASS,
			"draggable": false,
			"meta": "%s · %s %s" % [TYPE_LABELS.get(category, category), _loc("ui.label.weight_short", "重量"), _fmt(float(candidate.get("weight", 0.0)))],
			"hint": _loc("ui.hint.click_buy", "点击购买并安装") if blockers.is_empty() else blockers,
		})
	return rows


func _draggable_count() -> int:
	var count := 0
	for part in _owned_parts_for_all():
		if bool(part.get("draggable", false)):
			count += 1
	return count


func _owned_parts_for_all() -> Array:
	var rows: Array = []
	for category in MODULE_CATEGORIES:
		rows.append_array(_owned_parts(category))
	return rows


# ---------------------------------------------------------------------------
# Commands and interactions
# ---------------------------------------------------------------------------
func _on_slot_drop(payload: Dictionary, slot: Dictionary) -> void:
	# Accepts both the full drag payload (`{kind, part}` — what SNSlotTarget forwards
	# for a real mouse drop) and a bare part dictionary (older callers / tests).
	var part: Dictionary = payload.get("part", payload)
	var part_category := String(part.get("category", ""))
	if part_category != String(slot.get("category", "")):
		return
	var source := String(part.get("source", ""))
	if not ["warehouse", "transit"].has(source):
		return
	var module_id := String(part.get("module_id", ""))
	if module_id.is_empty():
		return
	var params := {"module_id": module_id, "source": source}
	var flat_slot := String(slot.get("slot", ""))
	if not flat_slot.is_empty() and flat_slot != "hull":
		params["slot"] = flat_slot
	var replace_id := String(slot.get("replace_module_id", ""))
	if not replace_id.is_empty() and replace_id != module_id:
		params["replace_module_id"] = replace_id
	command_requested.emit(&"ship.install_module", params)


func _on_slot_activated(slot: Dictionary) -> void:
	var accepted := String(slot.get("category", ""))
	if accepted != _category and MODULE_CATEGORIES.has(accepted):
		_ui_set_category(accepted)
		return
	for row in _hud_rows:
		if row is SNPartRow:
			row.set_compatible_hint(String(row.part.get("category", "")) == accepted)


func _on_part_activated(part: Dictionary) -> void:
	if String(part.get("source", "")) != "purchase":
		return
	command_requested.emit(&"ship.install_module", {"module_id": String(part.get("module_id", ""))})


# ---------------------------------------------------------------------------
# Purchases / crafting / warehouse (moved from the deleted lower panels)
# ---------------------------------------------------------------------------
func _candidate_card(candidate: Dictionary) -> Control:
	var card := _panel()
	var box := _content(card)
	var title_row := HBoxContainer.new()
	var installed := bool(candidate.get("installed", false))
	var title := _label(_loc(String(candidate.get("name_key", "")), String(candidate.get("module_id", ""))), 14, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_title(title)
	title_row.add_child(title)
	title_row.add_child(_label("%d 金币 · %s" % [int(candidate.get("price", 0)), _fmt(float(candidate.get("weight", 0.0)))], 12, MUTED))
	box.add_child(title_row)
	var effect := _module_effect_text(String(candidate.get("category", "")), candidate.get("effect", {}))
	if not effect.is_empty():
		box.add_child(_wrap_label(_loc("ui.label.effect", "") + "：" + effect, 11, TEAL))
	var blocker := _blocker_text(candidate.get("blockers", []))
	if not blocker.is_empty():
		box.add_child(_wrap_label(blocker, 11, MUTED if installed else RED))
	var button := _compact_command_button(_loc("ui.label.already_installed", "") if installed else _loc("ui.button.install", ""), &"ship.install_module", {"module_id": String(candidate.get("module_id", ""))})
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.disabled = not bool(candidate.get("can_install", false))
	box.add_child(button)
	return card


## Weapon purchase candidate as a draggable row: mount target is part of the row
## (click installs there) but dragging may land on any class-compatible mount.
func _weapon_candidate_row(candidate: Dictionary) -> Control:
	var weapon_id := String(candidate.get("weapon_id", ""))
	var name := _loc(String(candidate.get("name_key", "")), weapon_id)
	var socket_name := String(candidate.get("socket", ""))
	var socket_title := _weapon_socket_title_by_name(socket_name)
	var class_label := _weapon_class_label(String(candidate.get("weapon_class", "")))
	var can_install := bool(candidate.get("can_install", false))
	var hint := _loc("ui.hint.weapon_drag_to_slot", "拖到左侧炮位") if can_install \
		else _blocker_text(candidate.get("blockers", []))
	var row: Variant = WEAPON_ROW_SCRIPT.new()
	row.configure({
		"title": name,
		"tag": _loc("ui.tag.purchase", "购买 %d") % int(candidate.get("price", 0)),
		"tag_color": BRASS,
		"meta": "%s → %s · %s %s · %s %s" % [
			class_label,
			socket_title,
			_loc("ui.label.weight_short", "重量"), _fmt(float(candidate.get("weight", 0.0))),
			_loc("ui.label.weapon_socket_damage", "伤害"), _fmt(float(candidate.get("damage", 0.0))),
		],
		"hint": hint,
		"draggable": can_install,
		"payload": _weapon_payload(candidate, "purchase", name),
		"actions": [{
			"text": _loc("ui.button.install", "购买并安装"),
			"command": &"ship.install_weapon",
			"params": {"socket": socket_name, "weapon_id": weapon_id, "source": "purchase"},
			"disabled": not can_install,
		}],
	})
	row.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
		command_requested.emit(command, params)
	)
	row.mouse_entered.connect(func() -> void: _highlight_weapon_socket(socket_name))
	row.mouse_exited.connect(_highlight_all_weapon_sockets)
	_weapon_rows.append(row)
	return row


## Warehouse weapon as a draggable row: explicit "装到 左舷1" buttons stay for
## click install, and dragging the row puts the weapon on a blueprint mount / card.
func _warehouse_weapon_row(weapon: Dictionary) -> Control:
	var weapon_id := String(weapon.get("weapon_id", ""))
	var name := _loc(String(weapon.get("name_key", "")), weapon_id)
	var qty := maxi(1, int(weapon.get("qty", 1)))
	var class_label := _weapon_class_label(String(weapon.get("weapon_class", "")))
	var actions: Array = []
	var can_drag := false
	var hint := ""
	for option in weapon.get("install_options", []):
		if not (option is Dictionary):
			continue
		var socket_name := String((option as Dictionary).get("socket", ""))
		var disabled := not bool((option as Dictionary).get("can_install", false))
		actions.append({
			"text": _loc("ui.button.install_to", "装到 %s") % _weapon_socket_short_label(socket_name),
			"command": &"ship.install_weapon",
			"params": {"socket": socket_name, "weapon_id": weapon_id, "source": "warehouse"},
			"disabled": disabled,
		})
		if not disabled:
			can_drag = true
		elif hint.is_empty():
			hint = _blocker_text((option as Dictionary).get("blockers", []))
	if can_drag:
		hint = _loc("ui.hint.weapon_drag_to_slot", "拖到左侧炮位")
	elif not hint.is_empty():
		hint = _blocker_text(weapon.get("blockers", [])) if weapon.has("blockers") else hint
	var row: Variant = WEAPON_ROW_SCRIPT.new()
	row.configure({
		"title": "%s ×%d" % [name, qty],
		"tag": _loc("ui.tag.warehouse", "仓库"),
		"tag_color": TEAL,
		"meta": "%s · %s %s" % [
			class_label,
			_loc("ui.label.weight_short", "重量"), _fmt(float(weapon.get("weight", 0.0))),
		],
		"hint": hint,
		"draggable": can_drag,
		"payload": _weapon_payload(weapon, "warehouse", name),
		"actions": actions,
	})
	row.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
		command_requested.emit(command, params)
	)
	_weapon_rows.append(row)
	return row


func _craft_recipe(recipe: Dictionary, has_shipyard: bool) -> Control:
	var card := _panel()
	var box := _content(card)
	var title_row := HBoxContainer.new()
	var title := _label(_loc(String(recipe.get("name_key", "")), String(recipe.get("module_id", ""))), 14, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_title(title)
	title_row.add_child(title)
	var category := String(recipe.get("category", ""))
	title_row.add_child(_label("%s · %s" % [String(TYPE_LABELS.get(category, category)), _fmt(float(recipe.get("weight", 0.0)))], 12, MUTED))
	box.add_child(title_row)
	var material_row := HBoxContainer.new()
	material_row.add_theme_constant_override("separation", 12)
	for material in recipe.get("materials", []):
		if not (material is Dictionary):
			continue
		var owned := int(material.get("owned", 0))
		var required := int(material.get("required", 0))
		var enough := bool(material.get("enough", owned >= required))
		material_row.add_child(_label("%s %d/%d" % [_loc(String(material.get("name_key", "")), String(material.get("item_id", ""))), owned, required], 12, GREEN if enough else RED))
	if material_row.get_child_count() > 0:
		box.add_child(_label(_loc("ui.label.recipe_materials", "所需材料（持有/需求）"), 11, MUTED))
		box.add_child(material_row)
	elif bool(recipe.get("money_only", false)):
		box.add_child(_label(_loc("ui.label.money_only", ""), 12, TEAL))
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 18)
	meta.add_child(_badge("%s %d" % [_loc("ui.label.craft_cost", "打造费用"), int(recipe.get("craft_cost", 0))], SNBadge.Tone.WARNING))
	meta.add_child(_badge("%s %s h" % [_loc("ui.label.craft_time", "工时"), _fmt(float(recipe.get("craft_time_hours", 0.0)))], SNBadge.Tone.NEUTRAL))
	box.add_child(meta)
	var blocker := _blocker_text(recipe.get("blockers", []))
	if not blocker.is_empty():
		box.add_child(_label(blocker, 12, RED))
	var button := _command_button(_craft_button_text(recipe), &"ship.craft_module", {"module_id": String(recipe.get("module_id", ""))})
	button.disabled = not (bool(recipe.get("can_craft", false)) and has_shipyard)
	box.add_child(button)
	return card


func _warehouse_module_row(module: Dictionary, has_shipyard: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var module_id := String(module.get("module_id", ""))
	var title := _label("· %s ×%d · %s" % [_loc(String(module.get("name_key", "")), module_id), maxi(1, int(module.get("qty", 1))), _fmt(float(module.get("weight", 0.0)))], 13, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_title(title)
	row.add_child(title)
	var blockers: Array = module.get("blockers", [])
	var reason := _blocker_text(blockers)
	if bool(module.get("can_install", blockers.is_empty())):
		var install := _command_button(_loc("ui.button.install_free", "免费安装"), &"ship.install_module", {"module_id": module_id, "source": "warehouse"})
		install.disabled = not has_shipyard
		row.add_child(install)
	elif not reason.is_empty():
		row.add_child(_label(reason, 11, MUTED))
	row.add_child(_command_button(_loc("ui.button.take", "取出"), &"warehouse.take_module", {"module_id": module_id, "qty": 1}))
	return row


func _warehouse_material_row(material: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var item_id := String(material.get("item_id", ""))
	var amount := int(material.get("amount", 0))
	var title := _label("· %s ×%d · %s %s" % [_loc(String(material.get("name_key", "")), item_id), amount, _loc("ui.label.unit_weight", "单位重量"), _fmt(float(material.get("unit_weight", 0.0)))], 13, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var store_amount := mini(5, int(material.get("ship_amount", 0)))
	var store := _command_button("%s ×%d" % [_loc("ui.button.store_ship", "从船上存入"), store_amount], &"warehouse.store_materials", {"item_id": item_id, "amount": store_amount})
	store.disabled = store_amount <= 0
	row.add_child(store)
	var take_amount := mini(5, amount)
	var take := _command_button("%s ×%d" % [_loc("ui.button.take_ship", "取到船上"), take_amount], &"warehouse.take_materials", {"item_id": item_id, "amount": take_amount})
	take.disabled = take_amount <= 0
	row.add_child(take)
	return row


# ---------------------------------------------------------------------------
# Text helpers
# ---------------------------------------------------------------------------
func _ship_stats_text(vm: Dictionary) -> String:
	var ship: Dictionary = vm.get("ship", {})
	return "%s %s / %s · %s %s / %s · %s %d" % [
		_loc("ui.label.weight_short", "重量"), _fmt(float(ship.get("total_weight", 0.0))), _fmt(float(ship.get("max_weight", 0.0))),
		_loc("ui.label.durability_short", "耐久"), _fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0))),
		_loc("ui.label.money", "金币"), int(vm.get("money", 0)),
	]


func _ship_slot_summary(vm: Dictionary) -> String:
	var ship: Dictionary = vm.get("ship", {})
	return _loc("ui.label.hull_slots", "货舱 %d/%d · 客舱 %d/%d · 导航 %s · 安全 %s") % [
		int(ship.get("cargo_used", 0)), int(ship.get("cargo_slots", 0)),
		int(ship.get("cabin_used", 0)), int(ship.get("cabin_slots", 0)),
		_loc("ui.tag.installed", "已装") if bool(ship.get("navigation_occupied", false)) else _loc("ui.tag.empty", "空"),
		_loc("ui.tag.installed", "已装") if bool(ship.get("safety_occupied", false)) else _loc("ui.tag.empty", "空"),
	]


func _slot_count_text(vm: Dictionary, category: String) -> String:
	var ship: Dictionary = vm.get("ship", {})
	match category:
		"cargo":
			return "%d / %d" % [int(ship.get("cargo_used", 0)), int(ship.get("cargo_slots", 0))]
		"cabin":
			return "%d / %d" % [int(ship.get("cabin_used", 0)), int(ship.get("cabin_slots", 0))]
		"utility":
			var used := (1 if bool(ship.get("navigation_occupied", false)) else 0) \
				+ (1 if bool(ship.get("safety_occupied", false)) else 0)
			return "%d / 2" % used
		"weapons":
			var sockets: Array = ship.get("weapon_sockets", [])
			var mounted := 0
			for socket in sockets:
				if socket is Dictionary and not String(socket.get("weapon_id", "")).is_empty():
					mounted += 1
			return "%d / %d" % [mounted, sockets.size()]
		_:
			return "1 / 1"


func _category_label(category: String) -> String:
	match category:
		"hulls": return _loc("ui.category.hulls", "船体")
		"boiler": return _loc("ui.category.boiler", "锅炉")
		"cargo": return _loc("ui.category.cargo", "货舱")
		"utility": return _loc("ui.category.utility", "通用")
		"cabin": return _loc("ui.category.cabin", "客舱")
		"weapons": return "武器"
		"misc": return _loc("ui.category.misc", "杂项")
		_: return category


func _category_count_text(category: String) -> String:
	if category == "misc":
		return _loc("ui.label.misc_count", "工单 / 材料")
	if category == "weapons":
		return "%d 槽位" % Array(_vm.get("ship", {}).get("weapon_sockets", [])).size()
	return "%d %s" % [_slot_rows_for_category(category).size(), _loc("ui.label.slots_unit", "槽位")]


func _module_effect_text(category: String, effect: Dictionary) -> String:
	match category:
		"hulls": return "货舱 %d · 客舱 %d · 载重 %s · 航速 %s · 耐久 %s" % [int(effect.get("cargo_slots", 0)), int(effect.get("cabin_slots", 0)), _fmt(float(effect.get("max_weight", 0.0))), _fmt(float(effect.get("base_speed", 0.0))), _fmt(float(effect.get("max_durability", 0.0)))]
		"boiler": return "航速 ×%s · 煤耗 %s/h · 水耗 %s/h" % [_fmt(float(effect.get("speed_mul", 1.0)), 2), _fmt(float(effect.get("coal_rate", 0.0)), 2), _fmt(float(effect.get("water_rate", 0.0)), 2)]
		"cargo": return "容量 %s" % _fmt(float(effect.get("capacity", 0.0)))
		"utility": return _utility_effect_text(effect)
		"cabin": return "旅客 %d" % int(effect.get("passenger_capacity", 0))
		_: return ""


## Utility definitions carry the union of the legacy navigation/safety numbers; show
## the block their tags/data actually populate.
func _utility_effect_text(effect: Dictionary) -> String:
	var parts := PackedStringArray()
	if effect.has("risk_add"):
		parts.append("风险 %+.3f" % float(effect.get("risk_add", 0.0)))
	if effect.has("speed_mul"):
		parts.append("速度 ×%s" % _fmt(float(effect.get("speed_mul", 1.0)), 2))
	if effect.has("reveal_facilities"):
		parts.append("出航前揭示设施" if bool(effect.get("reveal_facilities", false)) else "无设施揭示")
	if effect.has("damage_mul"):
		parts.append("损伤 ×%s" % _fmt(float(effect.get("damage_mul", 1.0)), 2))
	if effect.has("repair_cost_mul"):
		parts.append("维修 ×%s" % _fmt(float(effect.get("repair_cost_mul", 1.0)), 2))
	return " · ".join(parts)


func _craft_button_text(recipe: Dictionary) -> String:
	var hours := float(recipe.get("craft_time_hours", 0.0))
	return _loc("ui.button.craft", "打造") if hours <= 0.0 else "%s · %s h" % [_loc("ui.button.craft_order", ""), _fmt(hours)]


func _blocker_labels(blockers: Array) -> String:
	var parts := PackedStringArray()
	for raw_code in blockers:
		var code := String(raw_code)
		if code == "already_installed":
			continue
		var text := _loc("ui.reason.%s" % code, "")
		if not text.is_empty() and not parts.has(text):
			parts.append(text)
	return ", ".join(parts)


func _blocker_text(blockers: Array) -> String:
	var labels := _blocker_labels(blockers)
	return "" if labels.is_empty() else _loc("ui.reason.prefix", "限制：") + labels


# ---------------------------------------------------------------------------
# Small builders
# ---------------------------------------------------------------------------
func _command_button(text: String, command: StringName, params: Dictionary) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func(): command_requested.emit(command, params))
	return button


func _compact_command_button(text: String, command: StringName, params: Dictionary) -> SNButton:
	var button := SNButton.new()
	button.variant = SNButton.Variant.SECONDARY
	button.compact = true
	button.text = text
	button.pressed.connect(func(): command_requested.emit(command, params))
	return button


func _badge(text: String, tone: SNBadge.Tone) -> SNBadge:
	var badge := SNBadge.new()
	badge.text = text
	badge.tone = tone
	return badge


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _section_label(text: String) -> Label:
	var label := _label(text, 15, TEAL)
	label.custom_minimum_size = Vector2(0, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new()
	header.eyebrow = eyebrow
	header.title = title
	header.detail = detail
	return header


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Descriptions and effect lines inside the operations column may wrap so the
## fixed-width column never grows when a category has a long module line.
func _wrap_label(text: String, size: int, color: Color) -> Label:
	var label := _label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## Long ids (socket / module / recipe names) must ellipsize instead of widening
## the fixed-width operations dock.
func _clip_title(label: Label) -> void:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	return fallback if text.is_empty() or text == key else text


func _fmt(value: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f") % value


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
