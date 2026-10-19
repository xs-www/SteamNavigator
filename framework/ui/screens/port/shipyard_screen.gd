class_name ShipyardScreen
extends VBoxContainer
## Shipyard / refit presentation.
##
## Layout: centre = SNShipView (current ship; cutaway once 改装 is on) with one
## draggable slot per hull/boiler/cargo/navigation/safety/cabin position, right =
## parts HUD grouping every module by slot type (installed / port warehouse /
## transit / purchasable). Dragging an owned free module onto a matching slot
## emits `ship.install_module` with the slot's replaced module so the domain
## rules (ShipOps.install_blockers) stay authoritative.
##
## Rules still come from shipyard.view; this screen never writes GameState.

signal command_requested(command: StringName, params: Dictionary)
signal refit_mode_changed(active: bool)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const TEAL := Color("76aaa7")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")
const TYPE_ORDER := ["hulls", "boilers", "cargo_modules", "navigation_modules", "safety_modules", "cabins"]
const TYPE_LABELS := {"hulls": "船体", "boilers": "锅炉", "cargo_modules": "货舱", "navigation_modules": "导航", "safety_modules": "安全", "cabins": "客舱"}
const SLOT_TITLES := {"hulls": "ui.label.slot_hull", "boilers": "ui.label.slot_boiler", "navigation_modules": "ui.label.slot_navigation", "safety_modules": "ui.label.slot_safety", "cabins": "ui.label.slot_cabin"}

var _tr: Callable
var _vm: Dictionary = {}
var _refit := false
var _slots: Array = []
var _stage: SNShipView
var _refit_button: SNButton
var _stage_title: Label
var _stage_hint: Label
var _hud_rows: Array = []


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_vm = vm
	_refit = bool(vm.get("refit", false))
	_clear()
	add_child(_heading(_loc("ui.nav.shipyard", "Shipyard"), _loc(String(vm.get("port_name_key", "")), String(vm.get("port_id", ""))), "当前船、槽位改装、打造与购买"))
	if not bool(vm.get("has_shipyard", false)):
		var warning := _panel()
		_content(warning).add_child(_label(_loc("ui.label.shipyard_absent", ""), 15, RED))
		add_child(warning)
	add_child(_stage_row(vm))
	add_child(_victory_plan(vm))
	add_child(_orders_panel(vm))
	add_child(_warehouse_panel(vm.get("warehouse", {}), bool(vm.get("has_shipyard", false))))
	add_child(_craft_panel(vm, bool(vm.get("has_shipyard", false))))
	_build_purchase_panels(vm.get("candidates", []))


# ---------------------------------------------------------------------------
# Centre stage + right parts HUD
# ---------------------------------------------------------------------------
func _stage_row(vm: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_stage_title = _label("", 18, BRASS)
	_stage_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_stage_title)
	_refit_button = SNButton.new()
	_refit_button.variant = SNButton.Variant.PRIMARY
	_refit_button.compact = true
	_refit_button.pressed.connect(_on_toggle_refit)
	top.add_child(_refit_button)
	left.add_child(top)
	left.add_child(_label(_ship_stats_text(vm), 12, MUTED))
	_stage = SNShipView.new()
	_stage.name = "ShipStage"
	_stage.custom_minimum_size = Vector2(520, 390)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.set_ship_model(vm.get("ship", {}))
	_slots = _build_slots(vm)
	_stage.set_slots(_slots)
	_stage.slot_drop_requested.connect(_on_slot_drop)
	_stage.slot_activated.connect(_on_slot_activated)
	left.add_child(_stage)
	_stage_hint = _label("", 11, MUTED)
	left.add_child(_stage_hint)
	row.add_child(left)
	row.add_child(_parts_hud(vm))
	_sync_refit_ui()
	return row


func _parts_hud(vm: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNElevatedPanel"
	panel.custom_minimum_size = Vector2(372, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _content(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _label(_loc("ui.label.parts_hud", "部件 / 槽位"), 18, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	box.add_child(header)
	box.add_child(_label(_ship_slot_summary(vm), 12, MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	box.add_child(scroll)
	_hud_rows.clear()
	for content_type in TYPE_ORDER:
		var group_rows := _part_rows_for_type(vm, content_type)
		if group_rows.is_empty():
			continue
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 3)
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var group_header := HBoxContainer.new()
		var label := _label(String(TYPE_LABELS.get(content_type, content_type)), 14, BRASS)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group_header.add_child(label)
		group_header.add_child(_label(_slot_count_text(vm, content_type), 11, MUTED))
		group.add_child(group_header)
		for part in group_rows:
			var row := SNPartRow.new()
			row.configure(part, String(part.get("tag", "")), part.get("tag_color", MUTED), String(part.get("meta", "")), String(part.get("hint", "")), bool(part.get("draggable", false)))
			row.activated.connect(_on_part_activated)
			group.add_child(row)
			_hud_rows.append(row)
		body.add_child(group)
	body.add_child(_label(_loc("ui.hint.drag_parts", "拖动仓库或随船部件到纵剖图槽位，即可装配或替换同槽位旧件。"), 11, MUTED))
	var draggable_count := 0
	for row in _hud_rows:
		if row is SNPartRow and bool(row.draggable):
			draggable_count += 1
	header.add_child(_badge(
		_loc("ui.label.draggable_count", "%d 可拖") % draggable_count,
		SNBadge.Tone.SUCCESS if draggable_count > 0 else SNBadge.Tone.NEUTRAL
	))
	return panel


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
			"hint": _loc("ui.hint.drag_to_slot", "拖到中央槽位") if blockers.is_empty() else blockers,
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
			"hint": _loc("ui.hint.drag_to_slot", "拖到中央槽位"),
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
	if installed is Dictionary:
		module_id = String(installed.get("module_id", ""))
		name = _loc(String(installed.get("name_key", "")), module_id)
		hint = "· " + _fmt(float(installed.get("weight", 0.0)))
		tooltip = _loc(String(installed.get("description_key", "")), "")
	var slot := {
		"id": "%s_%d" % [content_type, index],
		"content_type": content_type,
		"index": index,
		"title": title,
		"module": {"module_id": module_id, "name": name},
		"replace_module_id": module_id,
		"fixed": content_type in ["hulls", "boilers"],
		"hint": hint,
		"empty_text": _loc("ui.label.slot_empty", "空槽位"),
		"tooltip": tooltip if not tooltip.is_empty() else _loc("ui.hint.slot_drop", "把同槽位的仓库/随船部件拖到这里。"),
	}
	return slot


func _sync_refit_ui() -> void:
	if _stage == null:
		return
	_stage.set_mode(SNShipView.Mode.CUTAWAY if _refit else SNShipView.Mode.EXTERIOR)
	if _refit_button != null:
		_refit_button.text = _loc("ui.label.refit_done", "完成改装") if _refit else _loc("ui.label.refit", "改装")
	_stage_title.text = "%s · %s" % [_loc("ui.label.current_ship", "当前船"), _loc("ui.label.stage_cutaway", "纵剖图") if _refit else _loc("ui.label.stage_exterior", "船体侧视")]
	_stage_hint.text = _loc("ui.hint.drag_parts", "拖动仓库或随船部件到纵剖图槽位，即可装配或替换同槽位旧件。") if _refit else _loc("ui.hint.refit_click", "点击「改装」查看纵剖图与槽位；2.5D 场景可通过 SNShipView.set_renderer() 接入。")

func _on_toggle_refit() -> void:
	_refit = not _refit
	_sync_refit_ui()
	refit_mode_changed.emit(_refit)


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
	for row in _hud_rows:
		if row is SNPartRow:
			row.set_compatible_hint(String(row.part.get("content_type", "")) == accepted)


func _on_part_activated(part: Dictionary) -> void:
	if String(part.get("source", "")) != "purchase":
		return
	command_requested.emit(&"ship.install_module", {"module_id": String(part.get("module_id", ""))})


# ---------------------------------------------------------------------------
# Legacy detail panels (orders, warehouse, craft, purchases)
# ---------------------------------------------------------------------------
func _warehouse_panel(warehouse: Dictionary, has_shipyard: bool) -> Control:
	var panel := _panel()
	var box := _content(panel)
	box.add_child(_label(_loc("ui.label.warehouse", "港口仓库"), 18, BRASS))
	box.add_child(_label(_loc("ui.hint.warehouse", "仓库保存当前港的模块与材料；打造时优先从仓库扣除材料。"), 12, MUTED))
	box.add_child(_label(_loc("ui.label.warehouse_modules", "仓库模块"), 15, TEAL))
	var modules: Array = warehouse.get("modules", [])
	if modules.is_empty():
		box.add_child(_label(_loc("ui.error.warehouse_empty", "仓库里没有模块"), 12, MUTED))
	for module in modules:
		if module is Dictionary:
			box.add_child(_warehouse_module_row(module, has_shipyard))
	box.add_child(_label(_loc("ui.label.materials", "材料"), 15, TEAL))
	var materials: Array = warehouse.get("materials", [])
	if materials.is_empty():
		box.add_child(_label(_loc("ui.label.no_materials", "仓库里没有材料"), 12, MUTED))
	for material in materials:
		if material is Dictionary:
			box.add_child(_warehouse_material_row(material))
	return panel


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


func _orders_panel(vm: Dictionary) -> Control:
	var panel := _panel()
	panel.theme_type_variation = &"SNElevatedPanel"
	var box := _content(panel)
	var orders: Array = vm.get("orders", [])
	var header := HBoxContainer.new()
	var title := _label(_loc("ui.label.orders", ""), 18, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_badge("%d" % orders.size(), SNBadge.Tone.NEUTRAL if orders.is_empty() else SNBadge.Tone.SUCCESS))
	box.add_child(header)
	if orders.is_empty():
		box.add_child(_label(_loc("ui.label.no_orders", ""), 12, MUTED))
	for order in orders:
		if not (order is Dictionary):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name := _label(_loc(String(order.get("name_key", "")), String(order.get("module_id", ""))), 13, TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(_label(_loc("ui.label.order_remaining", "") % _fmt(float(order.get("remaining_hours", 0.0))), 12, TEAL))
		if not bool(order.get("at_current_port", true)):
			row.add_child(_label(_loc(String(order.get("port_name_key", "")), String(order.get("port_id", ""))), 12, MUTED))
		box.add_child(row)
	var wait_row := HBoxContainer.new()
	wait_row.add_theme_constant_override("separation", 8)
	wait_row.add_child(_label(_loc("ui.button.wait", ""), 13, MUTED))
	for raw_hours in vm.get("wait_options", [6, 12, 24]):
		var hours := int(raw_hours)
		if hours > 0:
			wait_row.add_child(_command_button("%d h" % hours, &"port.wait", {"hours": hours}))
	box.add_child(wait_row)
	box.add_child(_label(_loc("ui.hint.wait", ""), 12, MUTED))
	return panel


func _craft_panel(vm: Dictionary, has_shipyard: bool) -> Control:
	var recipes: Array = vm.get("craft", [])
	var panel := _panel()
	var box := _content(panel)
	var header := HBoxContainer.new()
	var title := _label(_loc("ui.label.craft", "打造"), 18, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_badge(_loc("ui.label.recipes", "配方"), SNBadge.Tone.NEUTRAL))
	box.add_child(header)
	if recipes.is_empty():
		box.add_child(_label(_loc("ui.label.no_recipes", "当前没有可打造的配方"), 12, MUTED))
	for recipe in recipes:
		if recipe is Dictionary:
			box.add_child(_craft_recipe(recipe, has_shipyard))
	return panel


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
	var description_key := String(recipe.get("description_key", ""))
	if not description_key.is_empty():
		box.add_child(_label(_loc(description_key, ""), 12, MUTED))
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


func _build_purchase_panels(candidates: Array) -> void:
	add_child(_label(_loc("ui.label.available_modules", "可购买模块"), 20, BRASS))
	if candidates.is_empty():
		var empty := _panel()
		_content(empty).add_child(_label(_loc("ui.label.no_candidates", "当前没有可购买的模块"), 12, MUTED))
		add_child(empty)
		return
	for content_type in TYPE_ORDER:
		var group: Array = []
		for candidate in candidates:
			if candidate is Dictionary and String(candidate.get("content_type", "")) == content_type:
				group.append(candidate)
		if group.is_empty():
			continue
		var panel := _panel()
		var box := _content(panel)
		box.add_child(_label(String(TYPE_LABELS.get(content_type, content_type)), 16, BRASS))
		for candidate in group:
			box.add_child(_candidate_card(candidate))
		add_child(panel)


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
	var description_key := String(candidate.get("description_key", ""))
	if not description_key.is_empty():
		box.add_child(_label(_loc(description_key, ""), 12, MUTED))
	var effect := _module_effect_text(String(candidate.get("content_type", "")), candidate.get("effect", {}))
	if not effect.is_empty():
		box.add_child(_label(_loc("ui.label.effect", "") + "：" + effect, 12, TEAL))
	var unlock_name := String(candidate.get("unlock_name", ""))
	if not unlock_name.is_empty():
		box.add_child(_label("%s：%s" % [_loc("ui.label.unlock_source", "解锁来源"), unlock_name], 12, TEAL))
	var will_replace_raw: Variant = candidate.get("will_replace", false)
	var will_replace := bool(will_replace_raw) if will_replace_raw is bool else not String(will_replace_raw).is_empty()
	if will_replace:
		var replace_hint := _loc("ui.hint.will_replace", "将替换同槽位旧件，旧件存入当前港仓库。")
		var replacement_name := String(candidate.get("replacement_name", ""))
		if not replacement_name.is_empty():
			replace_hint += " · " + replacement_name
		box.add_child(_label(replace_hint, 12, TEAL))
	var craft_blockers: Array = candidate.get("craft_blockers", [])
	if bool(candidate.get("craftable", false)):
		box.add_child(_label(_loc("ui.hint.craftable", "可用材料打造"), 12, GREEN))
	elif not craft_blockers.is_empty():
		box.add_child(_label("%s · %s" % [_loc("ui.label.craft", "打造"), _blocker_labels(craft_blockers)], 12, MUTED))
	var blocker := _blocker_text(candidate.get("blockers", []))
	if not blocker.is_empty():
		box.add_child(_label(blocker, 12, MUTED if installed else RED))
	var button := _command_button(_loc("ui.label.already_installed", "") if installed else _loc("ui.button.install", ""), &"ship.install_module", {"module_id": String(candidate.get("module_id", ""))})
	button.disabled = not bool(candidate.get("can_install", false))
	box.add_child(button)
	return card


func _victory_plan(vm: Dictionary) -> Control:
	var panel := _panel()
	panel.theme_type_variation = &"SNInsetPanel"
	var box := _content(panel)
	var contracts: Dictionary = vm.get("contracts", {})
	var gates: Dictionary = vm.get("victory", {}).get("conditions", {})
	var main_done := int(contracts.get("main_done", 0))
	var main_total := int(contracts.get("main_total", 0))
	var main_complete := bool(contracts.get("main_chain_complete", gates.get("main_complete", false)))
	var progress := _loc("ui.victory.plan_readiness", "") % [main_done, main_total]
	box.add_child(_heading(_loc("ui.label.victory_progress", ""), _loc("ui.victory.plan_title", ""), progress))
	box.add_child(_victory_step(_loc("ui.victory.plan_main", ""), main_complete, progress))
	box.add_child(_victory_step(_loc("ui.victory.plan_hull", ""), bool(gates.get("large_hull", false))))
	box.add_child(_victory_step(_loc("ui.victory.plan_boiler", ""), bool(gates.get("boiler", false))))
	box.add_child(_victory_step(_loc("ui.victory.plan_cargo", ""), bool(gates.get("cargo", false))))
	box.add_child(_victory_step(_loc("ui.victory.plan_shipyard", ""), bool(gates.get("shipyard", false))))
	if bool(gates.get("ready", false)):
		box.add_child(_label(_loc("ui.victory.plan_ready", ""), 13, GREEN))
	elif main_complete:
		box.add_child(_label(_loc("ui.victory.plan_main_done", ""), 14, BRASS))
	elif not bool(gates.get("large_hull", false)):
		box.add_child(_label(_loc("ui.victory.plan_locked", ""), 12, MUTED))
	box.add_child(_label(_loc("ui.victory.plan_hint", ""), 12, MUTED))
	return panel


func _victory_step(text: String, done: bool, detail: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label("✓" if done else "○", 14, GREEN if done else MUTED))
	var name := _label(text, 13, TEXT if done else MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	if not detail.is_empty():
		row.add_child(_label(detail, 12, MUTED))
	return row


func _craft_button_text(recipe: Dictionary) -> String:
	var hours := float(recipe.get("craft_time_hours", 0.0))
	return _loc("ui.button.craft", "打造") if hours <= 0.0 else "%s · %s h" % [_loc("ui.button.craft_order", ""), _fmt(hours)]


func _module_effect_text(content_type: String, effect: Dictionary) -> String:
	match content_type:
		"hulls": return "货舱 %d · 客舱 %d · 载重 %s · 航速 %s · 耐久 %s" % [int(effect.get("cargo_slots", 0)), int(effect.get("cabin_slots", 0)), _fmt(float(effect.get("max_weight", 0.0))), _fmt(float(effect.get("base_speed", 0.0))), _fmt(float(effect.get("max_durability", 0.0)))]
		"boilers": return "航速 ×%s · 煤耗 %s/h · 水耗 %s/h" % [_fmt(float(effect.get("speed_mul", 1.0)), 2), _fmt(float(effect.get("coal_rate", 0.0)), 2), _fmt(float(effect.get("water_rate", 0.0)), 2)]
		"cargo_modules": return "容量 %s" % _fmt(float(effect.get("capacity", 0.0)))
		"navigation_modules": return "风险 %+.3f · 速度 ×%s · %s" % [float(effect.get("risk_add", 0.0)), _fmt(float(effect.get("speed_mul", 1.0)), 2), "出航前揭示设施" if bool(effect.get("reveal_facilities", false)) else "无设施揭示"]
		"safety_modules": return "风险 %+.3f · 损伤 ×%s · 维修 ×%s" % [float(effect.get("risk_add", 0.0)), _fmt(float(effect.get("damage_mul", 1.0)), 2), _fmt(float(effect.get("repair_cost_mul", 1.0)), 2)]
		"cabins": return "旅客 %d" % int(effect.get("passenger_capacity", 0))
		_: return ""


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


func _command_button(text: String, command: StringName, params: Dictionary) -> Button:
	var button := Button.new()
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


func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	return fallback if text.is_empty() or text == key else text


func _fmt(value: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f") % value


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
