class_name ShipyardScreen
extends VBoxContainer
## Shipyard / refit presentation.
##
## Normal layout (图2): left = owned-ship list with a ship card texture, centre =
## live render stage, right = 组件 category panel that opens the refit view.
##
## Refit layout (图3): left = authored longitudinal-section texture, middle = the
## selected category's slot information and every operation (uninstall, drag
## install, purchase, craft), right = vertical category tabs (including 杂项 for
## craft orders, port wait and warehouse materials).
##
## The old lower panels (craft recipes, orders, warehouse, purchases, victory
## plan) are intentionally gone from this page; the overview keeps the win
## checklist and every shipyard command stays reachable inside the refit panels.
## Rules still come from shipyard.view; this screen never writes GameState.

signal command_requested(command: StringName, params: Dictionary)
signal refit_mode_changed(active: bool)
signal refit_category_changed(category: String)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const TEAL := Color("76aaa7")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")
const MODULE_TYPES := ["hulls", "boilers", "cargo_modules", "navigation_modules", "safety_modules", "cabins"]
const CATEGORY_ORDER := ["hulls", "boilers", "cargo_modules", "navigation_modules", "safety_modules", "cabins", "misc"]
const TYPE_LABELS := {"hulls": "船体", "boilers": "锅炉", "cargo_modules": "货舱", "navigation_modules": "导航", "safety_modules": "安全", "cabins": "客舱", "misc": "杂项"}
const SLOT_TITLES := {"hulls": "ui.label.slot_hull", "boilers": "ui.label.slot_boiler", "navigation_modules": "ui.label.slot_navigation", "safety_modules": "ui.label.slot_safety", "cabins": "ui.label.slot_cabin"}
const SHIP_THUMB_PATH := "res://assets/ui/shipyard/ship_thumb_ironclad.png"

var _tr: Callable
var _vm: Dictionary = {}
var _refit := false
var _category := "hulls"
var _slots: Array = []
var _stage: SNShipView
var _refit_button: SNButton
var _stage_title: Label
var _stage_hint: Label
var _hud_rows: Array = []
var _body: HBoxContainer
var _ship_thumb: Texture2D = null


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_vm = vm
	_refit = bool(vm.get("refit", false))
	var requested := String(vm.get("category", "hulls"))
	_category = requested if CATEGORY_ORDER.has(requested) else "hulls"
	_slots = _build_slots(vm)
	_ship_thumb = null
	if ResourceLoader.exists(SHIP_THUMB_PATH):
		_ship_thumb = load(SHIP_THUMB_PATH) as Texture2D
	_clear()
	_stage = null
	_stage_title = null
	_stage_hint = null
	_body = null
	_hud_rows.clear()
	add_child(_heading(
		_loc("ui.nav.shipyard", "Shipyard"),
		_loc(String(vm.get("port_name_key", "")), String(vm.get("port_id", ""))),
		_loc("ui.shipyard.detail", "当前船 · 槽位改装 · 打造与购买")
	))
	add_child(_summary_row())
	if not bool(vm.get("has_shipyard", false)):
		var warning := _panel()
		_content(warning).add_child(_label(_loc("ui.label.shipyard_absent", ""), 13, RED))
		add_child(warning)
	_body = HBoxContainer.new()
	_body.name = "ShipyardBody"
	_body.add_theme_constant_override("separation", 14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)
	_rebuild_layout()


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


func _rebuild_layout() -> void:
	if _body == null:
		return
	for child in _body.get_children():
		_body.remove_child(child)
		child.free()
	_stage = null
	_stage_title = null
	_stage_hint = null
	_hud_rows.clear()
	if _refit:
		_body.add_child(_section_panel())
		_body.add_child(_operations_panel())
		_body.add_child(_category_tabs_panel())
	else:
		_body.add_child(_ship_list_panel())
		_body.add_child(_render_panel())
		_body.add_child(_components_panel())
	_sync_refit_ui()


func _sync_refit_ui() -> void:
	if _refit_button != null:
		_refit_button.text = _loc("ui.label.refit_done", "完成改装") if _refit else _loc("ui.label.refit", "改装")
	if _stage != null and is_instance_valid(_stage):
		_stage.set_mode(SNShipView.Mode.CUTAWAY if _refit else SNShipView.Mode.EXTERIOR)


func _on_toggle_refit() -> void:
	_refit = not _refit
	refit_mode_changed.emit(_refit)
	_rebuild_layout()


## Enter refit mode on one category. Tests and the shell may call this directly.
func set_category(category: String) -> void:
	if category != "misc" and not MODULE_TYPES.has(category):
		return
	if not _refit:
		_refit = true
		refit_mode_changed.emit(true)
	_category = category
	refit_category_changed.emit(_category)
	_rebuild_layout()


func _ui_set_category(category: String) -> void:
	set_category.call_deferred(category)


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
	box.add_child(_label(_loc("ui.hint.ship_list", "当前版本只有旗舰一艘船；更多坞位会在后续版本开放。"), 11, MUTED))
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
	_stage_title = _label(_loc("ui.label.current_ship_render", "当前船只 · 实机渲染"), 16, BRASS)
	_stage_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_stage_title)
	header.add_child(_badge(_loc("ui.tag.live_render", "实机渲染"), SNBadge.Tone.NEUTRAL))
	box.add_child(header)
	_stage = _make_stage(SNShipView.Mode.EXTERIOR, Vector2(520, 340))
	box.add_child(_stage)
	_stage_hint = _label(_loc("ui.hint.live_render", "中心为实机渲染场景，后续 2.5D 场景通过 SNShipView.set_renderer() 接入。"), 11, MUTED)
	box.add_child(_stage_hint)
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
	for content_type in MODULE_TYPES:
		box.add_child(_category_row(content_type))
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


func _category_row(content_type: String) -> Control:
	var button := SNButton.new()
	button.variant = SNButton.Variant.GHOST
	button.compact = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 40)
	button.text = "   " + String(TYPE_LABELS.get(content_type, content_type))
	button.tooltip_text = _loc("ui.hint.components", "")
	button.pressed.connect(_ui_set_category.bind(content_type))
	var count := _label(_slot_count_text(_vm, content_type), 11, TEAL)
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
# Refit layout: textured section / operations / category tabs
# ---------------------------------------------------------------------------
func _section_panel() -> Control:
	var panel := _panel()
	panel.theme_type_variation = &"SNElevatedPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _content(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_stage_title = _label(_loc("ui.label.stage_cutaway", "纵剖图"), 17, BRASS)
	_stage_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_stage_title)
	header.add_child(_badge(_loc("ui.tag.section_texture", "贴图剖面"), SNBadge.Tone.SUCCESS))
	box.add_child(header)
	_stage = _make_stage(SNShipView.Mode.CUTAWAY, Vector2(620, 340))
	box.add_child(_stage)
	_stage_hint = _label(_loc("ui.hint.drag_parts", "拖动仓库或随船部件到左侧槽位即可装配或替换同槽位旧件。"), 11, MUTED)
	box.add_child(_stage_hint)
	return panel


func _operations_panel() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	panel.custom_minimum_size = Vector2(404, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _content(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _label(_category_label(_category), 17, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_badge(_category_count_text(_category), SNBadge.Tone.NEUTRAL))
	box.add_child(header)
	var hint_key := "ui.hint.operations_misc" if _category == "misc" else "ui.hint.operations"
	panel.tooltip_text = _loc(hint_key, "")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	box.add_child(scroll)
	_build_category_body(body)
	return panel


func _category_tabs_panel() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	panel.custom_minimum_size = Vector2(164, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _content(panel)
	box.add_child(_label(_loc("ui.label.category_tabs", "部件分类"), 15, BRASS))
	for content_type in CATEGORY_ORDER:
		var button := SNButton.new()
		button.variant = SNButton.Variant.PRIMARY if content_type == _category else SNButton.Variant.GHOST
		button.compact = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 38)
		button.text = "   " + _category_label(content_type)
		button.pressed.connect(_ui_set_category.bind(content_type))
		box.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	return panel


func _build_category_body(box: VBoxContainer) -> void:
	if _category == "misc":
		_build_misc_body(box)
		return
	var content_type := _category
	var slot_rows := _slot_rows_for_type(content_type)
	box.add_child(_section_label(_loc("ui.label.section_slots", "槽位")))
	if slot_rows.is_empty():
		box.add_child(_label(_loc("ui.label.no_slot_for_type", "当前船体没有该类型的槽位。"), 12, MUTED))
	for slot in slot_rows:
		box.add_child(_slot_card(slot))
	var owned := _owned_parts(content_type)
	if not owned.is_empty():
		box.add_child(_section_label(_loc("ui.label.owned_parts", "仓库 / 随船")))
		box.add_child(_label(_loc("ui.hint.drag_parts", "拖动仓库或随船部件到左侧槽位即可装配或替换同槽位旧件。"), 11, MUTED))
		for part in owned:
			box.add_child(_part_row(part))
	var candidates := _candidates_for_type(content_type)
	if not candidates.is_empty():
		box.add_child(_section_label(_loc("ui.label.buy_and_install", "购买并安装")))
		for candidate in candidates:
			box.add_child(_candidate_card(candidate))
	var recipes := _recipes_for_type(content_type)
	if not recipes.is_empty():
		box.add_child(_section_label(_loc("ui.label.craft_section", "按配方打造")))
		box.add_child(_label(_loc("ui.hint.craft_section", "打造会先产生订单，完工后进入当前港仓库。"), 11, MUTED))
		for recipe in recipes:
			box.add_child(_craft_recipe(recipe, bool(_vm.get("has_shipyard", false))))


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
	var content_type := String(slot.get("content_type", ""))
	var installed: Dictionary = slot.get("module", {})
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _label(String(slot.get("title", "")), 14, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		var effect_text := _module_effect_text(content_type, installed_row.get("effect", {}))
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
	var by_type: Dictionary = {}
	for module in ship.get("modules", []):
		if not (module is Dictionary):
			continue
		var content_type := String(module.get("content_type", ""))
		if not by_type.has(content_type):
			by_type[content_type] = []
		by_type[content_type].append(module)
	var slots: Array = []
	for content_type in ["hulls", "boilers", "navigation_modules", "safety_modules"]:
		var installed: Array = by_type.get(content_type, [])
		slots.append(_slot_row(content_type, 0, installed[0] if installed.size() > 0 else null))
	if int(ship.get("cabin_slots", 0)) >= 1:
		var cabins: Array = by_type.get("cabins", [])
		slots.append(_slot_row("cabins", 0, cabins[0] if cabins.size() > 0 else null))
	var cargo_installed: Array = by_type.get("cargo_modules", [])
	var cargo_slots := maxi(int(ship.get("cargo_slots", 0)), cargo_installed.size())
	for index in cargo_slots:
		slots.append(_slot_row("cargo_modules", index, cargo_installed[index] if index < cargo_installed.size() else null))
	return slots


func _slot_row(content_type: String, index: int, installed: Variant) -> Dictionary:
	var title_key := String(SLOT_TITLES.get(content_type, content_type))
	var title := _loc(title_key, String(TYPE_LABELS.get(content_type, content_type)))
	if content_type == "cargo_modules":
		title = _loc("ui.label.slot_cargo", "货舱槽 %d") % (index + 1)
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
	var slot := {
		"id": "%s_%d" % [content_type, index],
		"content_type": content_type,
		"index": index,
		"title": title,
		"module": {"module_id": module_id, "name": name},
		"replace_module_id": module_id,
		"fixed": content_type in ["hulls", "boilers"],
		"hint": hint,
		"condition": condition,
		"empty_text": _loc("ui.label.slot_empty", "空槽位"),
		"tooltip": tooltip if not tooltip.is_empty() else _loc("ui.hint.slot_drop", "把同槽位的仓库/随船部件拖到这里。"),
	}
	return slot


func _make_stage(mode: int, minimum: Vector2) -> SNShipView:
	var stage := SNShipView.new()
	stage.name = "ShipStage"
	stage.custom_minimum_size = minimum
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.set_ship_model(_vm.get("ship", {}))
	stage.set_slots(_slots)
	stage.slot_drop_requested.connect(_on_slot_drop)
	stage.slot_activated.connect(_on_slot_activated)
	stage.set_mode(mode)
	# 2.5D 舞台：正常态用真实 3D 船身，改装态仍走纵剖图贴图。船体模型由船体定义
	# 的 information.model 资产键解析（来自内容模组）；解析不到时自动回退程序化占位。
	var hull_model_path := String(_vm.get("ship", {}).get("hull_model_path", ""))
	if mode == SNShipView.Mode.EXTERIOR and (not hull_model_path.is_empty() or SNShipStage3D.is_supported()):
		stage.set_renderer(SNShipStage3D.new())
	return stage


# ---------------------------------------------------------------------------
# Parts HUD / operations building blocks
# ---------------------------------------------------------------------------
func _slot_rows_for_type(content_type: String) -> Array:
	var rows: Array = []
	for slot in _slots:
		if slot is Dictionary and String(slot.get("content_type", "")) == content_type:
			rows.append(slot)
	return rows


func _owned_parts(content_type: String) -> Array:
	var rows: Array = []
	for part in _part_rows_for_type(_vm, content_type):
		if part is Dictionary and ["warehouse", "transit"].has(String(part.get("source", ""))):
			rows.append(part)
	return rows


func _candidates_for_type(content_type: String) -> Array:
	var rows: Array = []
	for candidate in _vm.get("candidates", []):
		if candidate is Dictionary and String(candidate.get("content_type", "")) == content_type:
			if bool(candidate.get("installed", false)):
				continue
			rows.append(candidate)
	return rows


func _recipes_for_type(content_type: String) -> Array:
	var rows: Array = []
	for recipe in _vm.get("craft", []):
		if recipe is Dictionary and String(recipe.get("content_type", "")) == content_type:
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


func _part_rows_for_type(vm: Dictionary, content_type: String) -> Array:
	var rows: Array = []
	var ship: Dictionary = vm.get("ship", {})
	var installed: Array = []
	for module in ship.get("modules", []):
		if module is Dictionary and String(module.get("content_type", "")) == content_type:
			installed.append(module)
	for module in installed:
		var name := _loc(String(module.get("name_key", "")), String(module.get("module_id", "")))
		rows.append({
			"module_id": String(module.get("module_id", "")),
			"name": name,
			"content_type": content_type,
			"source": "installed",
			"tag": _loc("ui.tag.installed", "已装"),
			"tag_color": GREEN,
			"draggable": false,
			"meta": "%s %s" % [_loc("ui.label.weight_short", "重量"), _fmt(float(module.get("weight", 0.0)))],
			"hint": "",
		})
	var warehouse: Dictionary = vm.get("warehouse", {})
	for module in warehouse.get("modules", []):
		if not (module is Dictionary) or String(module.get("content_type", "")) != content_type:
			continue
		var name := _loc(String(module.get("name_key", "")), String(module.get("module_id", "")))
		var can_install := bool(module.get("can_install", false))
		var blockers := _blocker_text(module.get("blockers", []))
		rows.append({
			"module_id": String(module.get("module_id", "")),
			"name": name,
			"content_type": content_type,
			"source": "warehouse",
			"can_install": can_install,
			"tag": _loc("ui.tag.warehouse", "仓库"),
			"tag_color": TEAL,
			"draggable": can_install,
			"meta": "×%d · %s %s" % [maxi(1, int(module.get("qty", 1))), _loc("ui.label.weight_short", "重量"), _fmt(float(module.get("weight", 0.0)))],
			"hint": _loc("ui.hint.drag_to_slot", "拖到左侧槽位") if blockers.is_empty() else blockers,
		})
	for module in ship.get("transit_modules", []):
		if not (module is Dictionary) or String(module.get("content_type", "")) != content_type:
			continue
		var name := _loc(String(module.get("name_key", "")), String(module.get("module_id", "")))
		rows.append({
			"module_id": String(module.get("module_id", "")),
			"name": name,
			"content_type": content_type,
			"source": "transit",
			"can_install": true,
			"tag": _loc("ui.tag.transit", "随船"),
			"tag_color": TEAL,
			"draggable": true,
			"meta": "×%d · %s %s" % [maxi(1, int(module.get("qty", 1))), _loc("ui.label.weight_short", "重量"), _fmt(float(module.get("weight", 0.0)))],
			"hint": _loc("ui.hint.drag_to_slot", "拖到左侧槽位"),
		})
	for candidate in vm.get("candidates", []):
		if not (candidate is Dictionary) or String(candidate.get("content_type", "")) != content_type:
			continue
		if bool(candidate.get("installed", false)):
			continue
		var blockers := _blocker_text(candidate.get("blockers", []))
		var name := _loc(String(candidate.get("name_key", "")), String(candidate.get("module_id", "")))
		rows.append({
			"module_id": String(candidate.get("module_id", "")),
			"name": name,
			"content_type": content_type,
			"source": "purchase",
			"can_install": bool(candidate.get("can_install", false)),
			"tag": _loc("ui.tag.purchase", "购买 %d") % int(candidate.get("price", 0)),
			"tag_color": BRASS,
			"draggable": false,
			"meta": "%s · %s %s" % [TYPE_LABELS.get(content_type, content_type), _loc("ui.label.weight_short", "重量"), _fmt(float(candidate.get("weight", 0.0)))],
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
	for content_type in MODULE_TYPES:
		rows.append_array(_owned_parts(content_type))
	return rows


# ---------------------------------------------------------------------------
# Commands and interactions
# ---------------------------------------------------------------------------
func _on_slot_drop(payload: Dictionary, slot: Dictionary) -> void:
	var part: Dictionary = payload.get("part", {})
	var part_type := String(part.get("content_type", ""))
	if part_type != String(slot.get("content_type", "")):
		return
	var source := String(part.get("source", ""))
	if not ["warehouse", "transit"].has(source):
		return
	var module_id := String(part.get("module_id", ""))
	if module_id.is_empty():
		return
	var params := {"module_id": module_id, "source": source}
	var replace_id := String(slot.get("replace_module_id", ""))
	if not replace_id.is_empty() and replace_id != module_id:
		params["replace_module_id"] = replace_id
	command_requested.emit(&"ship.install_module", params)


func _on_slot_activated(slot: Dictionary) -> void:
	var accepted := String(slot.get("content_type", ""))
	if accepted != _category and MODULE_TYPES.has(accepted):
		_ui_set_category(accepted)
		return
	for row in _hud_rows:
		if row is SNPartRow:
			row.set_compatible_hint(String(row.part.get("content_type", "")) == accepted)


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
	title_row.add_child(title)
	title_row.add_child(_label("%d 金币 · %s" % [int(candidate.get("price", 0)), _fmt(float(candidate.get("weight", 0.0)))], 12, MUTED))
	box.add_child(title_row)
	var effect := _module_effect_text(String(candidate.get("content_type", "")), candidate.get("effect", {}))
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


func _craft_recipe(recipe: Dictionary, has_shipyard: bool) -> Control:
	var card := _panel()
	var box := _content(card)
	var title_row := HBoxContainer.new()
	var title := _label(_loc(String(recipe.get("name_key", "")), String(recipe.get("module_id", ""))), 14, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var content_type := String(recipe.get("content_type", ""))
	title_row.add_child(_label("%s · %s" % [String(TYPE_LABELS.get(content_type, content_type)), _fmt(float(recipe.get("weight", 0.0)))], 12, MUTED))
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


func _slot_count_text(vm: Dictionary, content_type: String) -> String:
	var ship: Dictionary = vm.get("ship", {})
	match content_type:
		"cargo_modules":
			return "%d / %d" % [int(ship.get("cargo_used", 0)), int(ship.get("cargo_slots", 0))]
		"cabins":
			return "%d / %d" % [int(ship.get("cabin_used", 0)), int(ship.get("cabin_slots", 0))]
		"navigation_modules":
			return _loc("ui.tag.installed", "已装") if bool(ship.get("navigation_occupied", false)) else "-"
		"safety_modules":
			return _loc("ui.tag.installed", "已装") if bool(ship.get("safety_occupied", false)) else "-"
		_:
			return "1 / 1"


func _category_label(category: String) -> String:
	match category:
		"hulls": return _loc("ui.category.hulls", "船体")
		"boilers": return _loc("ui.category.boilers", "锅炉")
		"cargo_modules": return _loc("ui.category.cargo_modules", "货舱")
		"navigation_modules": return _loc("ui.category.navigation_modules", "导航")
		"safety_modules": return _loc("ui.category.safety_modules", "安全")
		"cabins": return _loc("ui.category.cabins", "客舱")
		"misc": return _loc("ui.category.misc", "杂项")
		_: return category


func _category_count_text(category: String) -> String:
	if category == "misc":
		return _loc("ui.label.misc_count", "工单 / 材料")
	return "%d %s" % [_slot_rows_for_type(category).size(), _loc("ui.label.slots_unit", "槽位")]


func _module_effect_text(content_type: String, effect: Dictionary) -> String:
	match content_type:
		"hulls": return "货舱 %d · 客舱 %d · 载重 %s · 航速 %s · 耐久 %s" % [int(effect.get("cargo_slots", 0)), int(effect.get("cabin_slots", 0)), _fmt(float(effect.get("max_weight", 0.0))), _fmt(float(effect.get("base_speed", 0.0))), _fmt(float(effect.get("max_durability", 0.0)))]
		"boilers": return "航速 ×%s · 煤耗 %s/h · 水耗 %s/h" % [_fmt(float(effect.get("speed_mul", 1.0)), 2), _fmt(float(effect.get("coal_rate", 0.0)), 2), _fmt(float(effect.get("water_rate", 0.0)), 2)]
		"cargo_modules": return "容量 %s" % _fmt(float(effect.get("capacity", 0.0)))
		"navigation_modules": return "风险 %+.3f · 速度 ×%s · %s" % [float(effect.get("risk_add", 0.0)), _fmt(float(effect.get("speed_mul", 1.0)), 2), "出航前揭示设施" if bool(effect.get("reveal_facilities", false)) else "无设施揭示"]
		"safety_modules": return "风险 %+.3f · 损伤 ×%s · 维修 ×%s" % [float(effect.get("risk_add", 0.0)), _fmt(float(effect.get("damage_mul", 1.0)), 2), _fmt(float(effect.get("repair_cost_mul", 1.0)), 2)]
		"cabins": return "旅客 %d" % int(effect.get("passenger_capacity", 0))
		_: return ""


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


func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	return fallback if text.is_empty() or text == key else text


func _fmt(value: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f") % value


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
