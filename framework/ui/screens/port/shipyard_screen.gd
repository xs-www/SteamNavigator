class_name ShipyardScreen
extends VBoxContainer
## Shipyard presentation. Rules come from shipyard.view; actions are intents.

signal command_requested(command: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const TEAL := Color("76aaa7")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")
const TYPE_ORDER := ["hulls", "boilers", "cargo_modules", "navigation_modules", "safety_modules", "cabins"]
const TYPE_LABELS := {"hulls": "船体", "boilers": "锅炉", "cargo_modules": "货舱", "navigation_modules": "导航", "safety_modules": "安全", "cabins": "客舱"}
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	add_child(_heading(_loc("ui.nav.shipyard", "Shipyard"), _loc(String(vm.get("port_name_key", "")), String(vm.get("port_id", ""))), "当前模块、港口仓库、打造与购买"))
	var has_shipyard := bool(vm.get("has_shipyard", false))
	if not has_shipyard:
		var warning := _panel(); _content(warning).add_child(_label(_loc("ui.label.shipyard_absent", ""), 15, RED)); add_child(warning)
	add_child(_victory_plan(vm))
	add_child(_ship_panel(vm, has_shipyard))
	add_child(_orders_panel(vm))
	add_child(_warehouse_panel(vm.get("warehouse", {}), has_shipyard))
	add_child(_craft_panel(vm, has_shipyard))
	_build_purchase_panels(vm.get("candidates", []))


func _ship_panel(vm: Dictionary, has_shipyard: bool) -> Control:
	var ship: Dictionary = vm.get("ship", {}); var panel := _panel(); var box := _content(panel)
	box.add_child(_label(_loc("ui.label.current_ship", ""), 18, BRASS))
	box.add_child(_label("货舱槽 %d / %d · 客舱槽 %d / %d · 导航 %s · 安全 %s" % [int(ship.get("cargo_used", 0)), int(ship.get("cargo_slots", 0)), int(ship.get("cabin_used", 0)), int(ship.get("cabin_slots", 0)), "已装" if bool(ship.get("navigation_occupied", false)) else "空", "已装" if bool(ship.get("safety_occupied", false)) else "空"], 13, TEXT))
	box.add_child(_label("重量 %s / %s · 耐久 %s / %s · 金币 %d" % [_fmt(float(ship.get("total_weight", 0.0))), _fmt(float(ship.get("max_weight", 0.0))), _fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0))), int(vm.get("money", 0))], 13, MUTED))
	box.add_child(_label(_loc("ui.label.installed_modules", "已安装模块"), 15, BRASS))
	var modules: Array = ship.get("modules", [])
	if modules.is_empty(): box.add_child(_label(_loc("ui.label.no_modules", "没有已安装模块"), 12, MUTED))
	for module in modules:
		if module is Dictionary: box.add_child(_installed_row(module, has_shipyard))
	box.add_child(_label(_loc("ui.label.transit", "随船运输模块"), 15, TEAL)); box.add_child(_label("%s %s" % [_loc("ui.label.transit_weight", "运输重量"), _fmt(float(ship.get("transit_weight", 0.0)))], 12, MUTED))
	var transit: Array = ship.get("transit_modules", [])
	if transit.is_empty(): box.add_child(_label(_loc("ui.label.no_transit_modules", "没有随船运输的模块"), 12, MUTED))
	for module in transit:
		if module is Dictionary: box.add_child(_transit_row(module, has_shipyard))
	box.add_child(_label(_loc("ui.hint.shipyard", ""), 12, MUTED)); return panel


func _installed_row(module: Dictionary, has_shipyard: bool) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); var content_type := String(module.get("content_type", ""))
	var title := _label("· %s · %s · %s" % [_loc(String(module.get("name_key", "")), String(module.get("module_id", ""))), String(TYPE_LABELS.get(content_type, content_type)), _fmt(float(module.get("weight", 0.0)))], 13, TEXT); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(title)
	var blockers: Array = module.get("uninstall_blockers", []); var required := content_type in ["hulls", "boilers"]; var can_uninstall := bool(module.get("can_uninstall", blockers.is_empty() and not required))
	if can_uninstall:
		var button := _command_button(_loc("ui.button.uninstall", "卸下"), &"ship.uninstall_module", {"module_id": String(module.get("module_id", ""))}); button.disabled = not has_shipyard; row.add_child(button)
	else:
		var reason := _blocker_text(blockers)
		if reason.is_empty():
			reason = _loc("ui.reason.required_module", "船体与锅炉不可卸下")
		row.add_child(_label(reason, 11, MUTED))
	return row


func _transit_row(module: Dictionary, has_shipyard: bool) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); var module_id := String(module.get("module_id", "")); var title := _label("· %s ×%d · %s" % [_loc(String(module.get("name_key", "")), module_id), maxi(1, int(module.get("qty", 1))), _fmt(float(module.get("weight", 0.0)))], 13, TEXT); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(title)
	var install := _command_button(_loc("ui.button.install_free", "免费安装"), &"ship.install_module", {"module_id": module_id, "source": "transit"}); install.disabled = not has_shipyard; row.add_child(install); row.add_child(_command_button(_loc("ui.button.store_module", "存入仓库"), &"warehouse.store_module", {"module_id": module_id, "qty": 1})); return row


func _warehouse_panel(warehouse: Dictionary, has_shipyard: bool) -> Control:
	var panel := _panel(); var box := _content(panel); box.add_child(_label(_loc("ui.label.warehouse", "港口仓库"), 18, BRASS)); box.add_child(_label(_loc("ui.hint.warehouse", "仓库保存当前港的模块与材料；打造时优先从仓库扣除材料。"), 12, MUTED)); box.add_child(_label(_loc("ui.label.warehouse_modules", "仓库模块"), 15, TEAL))
	var modules: Array = warehouse.get("modules", [])
	if modules.is_empty():
		box.add_child(_label(_loc("ui.error.warehouse_empty", "仓库里没有模块"), 12, MUTED))
	for module in modules:
		if module is Dictionary: box.add_child(_warehouse_module_row(module, has_shipyard))
	box.add_child(_label(_loc("ui.label.materials", "材料"), 15, TEAL))
	var materials: Array = warehouse.get("materials", [])
	if materials.is_empty():
		box.add_child(_label(_loc("ui.label.no_materials", "仓库里没有材料"), 12, MUTED))
	for material in materials:
		if material is Dictionary: box.add_child(_warehouse_material_row(material))
	return panel


func _warehouse_module_row(module: Dictionary, has_shipyard: bool) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); var module_id := String(module.get("module_id", "")); var title := _label("· %s ×%d · %s" % [_loc(String(module.get("name_key", "")), module_id), maxi(1, int(module.get("qty", 1))), _fmt(float(module.get("weight", 0.0)))], 13, TEXT); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(title)
	var blockers: Array = module.get("blockers", []); var reason := _blocker_text(blockers)
	if bool(module.get("can_install", blockers.is_empty())):
		var install := _command_button(_loc("ui.button.install_free", "免费安装"), &"ship.install_module", {"module_id": module_id, "source": "warehouse"}); install.disabled = not has_shipyard; row.add_child(install)
	elif not reason.is_empty(): row.add_child(_label(reason, 11, MUTED))
	row.add_child(_command_button(_loc("ui.button.take", "取出"), &"warehouse.take_module", {"module_id": module_id, "qty": 1})); return row


func _warehouse_material_row(material: Dictionary) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); var item_id := String(material.get("item_id", "")); var amount := int(material.get("amount", 0)); var title := _label("· %s ×%d · %s %s" % [_loc(String(material.get("name_key", "")), item_id), amount, _loc("ui.label.unit_weight", "单位重量"), _fmt(float(material.get("unit_weight", 0.0)))], 13, TEXT); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(title)
	var store_amount := mini(5, int(material.get("ship_amount", 0))); var store := _command_button("%s ×%d" % [_loc("ui.button.store_ship", "从船上存入"), store_amount], &"warehouse.store_materials", {"item_id": item_id, "amount": store_amount}); store.disabled = store_amount <= 0; row.add_child(store)
	var take_amount := mini(5, amount); var take := _command_button("%s ×%d" % [_loc("ui.button.take_ship", "取到船上"), take_amount], &"warehouse.take_materials", {"item_id": item_id, "amount": take_amount}); take.disabled = take_amount <= 0; row.add_child(take); return row


func _orders_panel(vm: Dictionary) -> Control:
	var panel := _panel(); panel.theme_type_variation = &"SNElevatedPanel"; var box := _content(panel); var orders: Array = vm.get("orders", []); var header := HBoxContainer.new(); var title := _label(_loc("ui.label.orders", ""), 18, BRASS); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title); header.add_child(_badge("%d" % orders.size(), SNBadge.Tone.NEUTRAL if orders.is_empty() else SNBadge.Tone.SUCCESS)); box.add_child(header)
	if orders.is_empty(): box.add_child(_label(_loc("ui.label.no_orders", ""), 12, MUTED))
	for order in orders:
		if not (order is Dictionary): continue
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
		var name := _label(_loc(String(order.get("name_key", "")), String(order.get("module_id", ""))), 13, TEXT); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(name)
		row.add_child(_label(_loc("ui.label.order_remaining", "") % _fmt(float(order.get("remaining_hours", 0.0))), 12, TEAL))
		if not bool(order.get("at_current_port", true)):
			row.add_child(_label(_loc(String(order.get("port_name_key", "")), String(order.get("port_id", ""))), 12, MUTED))
		box.add_child(row)
	var wait_row := HBoxContainer.new(); wait_row.add_theme_constant_override("separation", 8); wait_row.add_child(_label(_loc("ui.button.wait", ""), 13, MUTED))
	for raw_hours in vm.get("wait_options", [6, 12, 24]):
		var hours := int(raw_hours)
		if hours > 0:
			wait_row.add_child(_command_button("%d h" % hours, &"port.wait", {"hours": hours}))
	box.add_child(wait_row); box.add_child(_label(_loc("ui.hint.wait", ""), 12, MUTED)); return panel


func _craft_panel(vm: Dictionary, has_shipyard: bool) -> Control:
	var recipes: Array = vm.get("craft", []); var panel := _panel(); var box := _content(panel); var header := HBoxContainer.new(); var title := _label(_loc("ui.label.craft", "打造"), 18, BRASS); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title); header.add_child(_badge(_loc("ui.label.recipes", "配方"), SNBadge.Tone.NEUTRAL)); box.add_child(header)
	if recipes.is_empty(): box.add_child(_label(_loc("ui.label.no_recipes", "当前没有可打造的配方"), 12, MUTED))
	for recipe in recipes:
		if recipe is Dictionary: box.add_child(_craft_recipe(recipe, has_shipyard))
	return panel


func _craft_recipe(recipe: Dictionary, has_shipyard: bool) -> Control:
	var card := _panel(); var box := _content(card); var title_row := HBoxContainer.new(); var title := _label(_loc(String(recipe.get("name_key", "")), String(recipe.get("module_id", ""))), 14, TEXT); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_row.add_child(title); var content_type := String(recipe.get("content_type", "")); title_row.add_child(_label("%s · %s" % [String(TYPE_LABELS.get(content_type, content_type)), _fmt(float(recipe.get("weight", 0.0)))], 12, MUTED)); box.add_child(title_row)
	var description_key := String(recipe.get("description_key", ""))
	if not description_key.is_empty():
		box.add_child(_label(_loc(description_key, ""), 12, MUTED))
	var material_row := HBoxContainer.new(); material_row.add_theme_constant_override("separation", 12)
	for material in recipe.get("materials", []):
		if not (material is Dictionary): continue
		var owned := int(material.get("owned", 0)); var required := int(material.get("required", 0)); var enough := bool(material.get("enough", owned >= required)); material_row.add_child(_label("%s %d/%d" % [_loc(String(material.get("name_key", "")), String(material.get("item_id", ""))), owned, required], 12, GREEN if enough else RED))
	if material_row.get_child_count() > 0: box.add_child(_label(_loc("ui.label.recipe_materials", "所需材料（持有/需求）"), 11, MUTED)); box.add_child(material_row)
	elif bool(recipe.get("money_only", false)): box.add_child(_label(_loc("ui.label.money_only", ""), 12, TEAL))
	var meta := HBoxContainer.new(); meta.add_theme_constant_override("separation", 18); meta.add_child(_badge("%s %d" % [_loc("ui.label.craft_cost", "打造费用"), int(recipe.get("craft_cost", 0))], SNBadge.Tone.WARNING)); meta.add_child(_badge("%s %s h" % [_loc("ui.label.craft_time", "工时"), _fmt(float(recipe.get("craft_time_hours", 0.0)))], SNBadge.Tone.NEUTRAL)); box.add_child(meta)
	var blocker := _blocker_text(recipe.get("blockers", []))
	if not blocker.is_empty():
		box.add_child(_label(blocker, 12, RED))
	var button := _command_button(_craft_button_text(recipe), &"ship.craft_module", {"module_id": String(recipe.get("module_id", ""))}); button.disabled = not (bool(recipe.get("can_craft", false)) and has_shipyard); box.add_child(button); return card


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
		var panel := _panel(); var box := _content(panel)
		box.add_child(_label(String(TYPE_LABELS.get(content_type, content_type)), 16, BRASS))
		for candidate in group:
			box.add_child(_candidate_card(candidate))
		add_child(panel)


func _candidate_card(candidate: Dictionary) -> Control:
	var card := _panel(); var box := _content(card); var title_row := HBoxContainer.new(); var installed := bool(candidate.get("installed", false)); var title := _label(_loc(String(candidate.get("name_key", "")), String(candidate.get("module_id", ""))), 14, TEXT); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_row.add_child(title); title_row.add_child(_label("%d 金币 · %s" % [int(candidate.get("price", 0)), _fmt(float(candidate.get("weight", 0.0)))], 12, MUTED)); box.add_child(title_row)
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
	var button := _command_button(_loc("ui.label.already_installed", "") if installed else _loc("ui.button.install", ""), &"ship.install_module", {"module_id": String(candidate.get("module_id", ""))}); button.disabled = not bool(candidate.get("can_install", false)); box.add_child(button); return card


func _victory_plan(vm: Dictionary) -> Control:
	var panel := _panel(); panel.theme_type_variation = &"SNInsetPanel"; var box := _content(panel); var contracts: Dictionary = vm.get("contracts", {}); var gates: Dictionary = vm.get("victory", {}).get("conditions", {}); var main_done := int(contracts.get("main_done", 0)); var main_total := int(contracts.get("main_total", 0)); var main_complete := bool(contracts.get("main_chain_complete", gates.get("main_complete", false))); var progress := _loc("ui.victory.plan_readiness", "") % [main_done, main_total]
	box.add_child(_heading(_loc("ui.label.victory_progress", ""), _loc("ui.victory.plan_title", ""), progress)); box.add_child(_victory_step(_loc("ui.victory.plan_main", ""), main_complete, progress)); box.add_child(_victory_step(_loc("ui.victory.plan_hull", ""), bool(gates.get("large_hull", false)))); box.add_child(_victory_step(_loc("ui.victory.plan_boiler", ""), bool(gates.get("boiler", false)))); box.add_child(_victory_step(_loc("ui.victory.plan_cargo", ""), bool(gates.get("cargo", false)))); box.add_child(_victory_step(_loc("ui.victory.plan_shipyard", ""), bool(gates.get("shipyard", false))))
	if bool(gates.get("ready", false)): box.add_child(_label(_loc("ui.victory.plan_ready", ""), 13, GREEN))
	elif main_complete: box.add_child(_label(_loc("ui.victory.plan_main_done", ""), 14, BRASS))
	elif not bool(gates.get("large_hull", false)): box.add_child(_label(_loc("ui.victory.plan_locked", ""), 12, MUTED))
	box.add_child(_label(_loc("ui.victory.plan_hint", ""), 12, MUTED)); return panel


func _victory_step(text: String, done: bool, detail: String = "") -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); row.add_child(_label("✓" if done else "○", 14, GREEN if done else MUTED)); var name := _label(text, 13, TEXT if done else MUTED); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(name)
	if not detail.is_empty(): row.add_child(_label(detail, 12, MUTED))
	return row


func _craft_button_text(recipe: Dictionary) -> String:
	var hours := float(recipe.get("craft_time_hours", 0.0)); return _loc("ui.button.craft", "打造") if hours <= 0.0 else "%s · %s h" % [_loc("ui.button.craft_order", ""), _fmt(hours)]
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
	var labels := _blocker_labels(blockers); return "" if labels.is_empty() else _loc("ui.reason.prefix", "限制：") + labels
func _command_button(text: String, command: StringName, params: Dictionary) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(func(): command_requested.emit(command, params)); return button
func _badge(text: String, tone: SNBadge.Tone) -> SNBadge:
	var badge := SNBadge.new(); badge.text = text; badge.tone = tone; return badge
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_OFF; return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _fmt(value: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f") % value
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
