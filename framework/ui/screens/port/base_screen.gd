class_name BaseScreen
extends VBoxContainer
## @static-doc
## 作用：Phase D3 基地页：渲染 `base.view` 与 shell 提供的可用基地点/建筑/升级/工种/
## 港口仓库物品，并把占领、建造、升级、派工、雇工、生产、存取与等待时间转成
## `command_requested` 意图；页面本身不查询、不写状态。
##
## ## 契约与约束
## - `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在 `base.view`
##   基础上补 `available_sites` / `available_buildings` / `available_upgrades` /
##   `available_roles` / `warehouse_items`。
## - 未占领只显示基地点与占领按钮；已占领显示建筑卡（施工/升级/订单/工人）、
##   仓储存取、雇工与等待按钮；停工时显示红色提示。
## - 所有按钮只 emit `command_requested(command, params)`，不在页面内执行命令或刷新。
## @end-static-doc

signal command_requested(command: StringName, params: Dictionary)

const COLOR_TEXT := Color("ece1c5")
const COLOR_MUTED := Color("9fafa7")
const COLOR_BRASS := Color("e1c487")
const COLOR_RED := Color("c36b53")

var _tr: Callable
var _model: Dictionary = {}


func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	_model = view_model
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	add_child(_heading())
	if not bool(_model.get("claimed", false)):
		var unclaimed := _panel()
		unclaimed.add_child(_label(_t("ui.base.unclaimed", "尚未占领基地。选择一个基地点开始。"), 14, COLOR_MUTED))
		add_child(unclaimed)
		var sites := HFlowContainer.new()
		sites.add_theme_constant_override("h_separation", 8)
		sites.add_theme_constant_override("v_separation", 8)
		for site in _model.get("available_sites", []):
			if site is Dictionary:
				var cost := int((site as Dictionary).get("claim_cost", 0))
				sites.add_child(_action("%s（%d 金）" % [_name((site as Dictionary).get("name_key", "")), cost],
					&"base.claim", {"base_site_id": String((site as Dictionary).get("id", ""))}))
		add_child(sites)
		add_child(_wait_row())
		return
	add_child(_summary())
	add_child(_buildings())
	add_child(_storage())
	add_child(_workers())
	add_child(_wait_row())
	if bool(_model.get("halted", false)):
		add_child(_label(_t("ui.base.halted", "维护费不足：基地已停工，请先补充金钱。"), 14, COLOR_RED))


func _heading() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label(_t("ui.base.title", "基地"), 24, COLOR_BRASS))
	var site: Dictionary = _model.get("site", {})
	var subtitle := _t("ui.base.subtitle", "建筑、工人与生产链")
	if not site.is_empty():
		subtitle = "%s · %s" % [_name(site.get("name_key", "")), String(_model.get("port_id", ""))]
	box.add_child(_label(subtitle, 14, COLOR_MUTED))
	return box


func _summary() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var badges := HFlowContainer.new()
	badges.add_theme_constant_override("h_separation", 10)
	badges.add_child(_badge("槽位 %d/%d" % [int(_model.get("slots_used", 0)), int(_model.get("slot_count", 0))]))
	badges.add_child(_badge("防御 %d" % int(_model.get("defense", 0))))
	badges.add_child(_badge("仓储 %s/%s" % [
		_fmt(float(_model.get("storage", {}).get("used_weight", 0.0))),
		_fmt(float(_model.get("storage", {}).get("capacity", 0.0))),
	]))
	badges.add_child(_badge("每 tick 支出 %s" % _fmt(float(_model.get("money_due_per_tick", 0.0)))))
	badges.add_child(_badge("工人 %d" % int(_model.get("workers", {}).get("total", 0))))
	box.add_child(badges)
	panel.add_child(box)
	return panel


func _buildings() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label(_t("ui.base.buildings", "建筑"), 18, COLOR_BRASS))
	for building in _model.get("buildings", []):
		if not (building is Dictionary):
			continue
		box.add_child(_building_card(building))
	box.add_child(_label(_t("ui.base.build", "建造新建筑"), 16, COLOR_BRASS))
	var build_row := HFlowContainer.new()
	build_row.add_theme_constant_override("h_separation", 8)
	build_row.add_theme_constant_override("v_separation", 8)
	for definition in _model.get("available_buildings", []):
		if definition is Dictionary:
			build_row.add_child(_action("%s（%d 金）" % [
				_name((definition as Dictionary).get("name_key", "")),
				int((definition as Dictionary).get("cost", 0)),
			], &"base.build", {"building_id": String((definition as Dictionary).get("id", ""))}))
	box.add_child(build_row)
	return box


func _building_card(building: Dictionary) -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var status := String(building.get("status", ""))
	var title := "%s Lv.%d · %s" % [_name(building.get("name_key", "")), int(building.get("level", 1)), _status_text(status)]
	box.add_child(_label(title, 16, COLOR_TEXT))
	if status == "building" or status == "upgrading":
		box.add_child(_label("剩余 %s h" % _fmt(float(building.get("remaining_hours", 0.0))), 13, COLOR_MUTED))
	if status == "ready":
		var order: Dictionary = building.get("order", {})
		if order.is_empty():
			var recipes: Array = building.get("recipes", [])
			if not recipes.is_empty():
				var row := HFlowContainer.new()
				row.add_theme_constant_override("h_separation", 8)
				for recipe in recipes:
					if recipe is Dictionary:
						row.add_child(_action("生产 %s" % _name((recipe as Dictionary).get("name_key", "")),
							&"base.start_production", {
								"instance_id": String(building.get("instance_id", "")),
								"recipe_id": String((recipe as Dictionary).get("recipe_id", "")),
							}))
				box.add_child(row)
		else:
			var progress := "%s · 剩余 %s h" % [
				_name(order.get("name_key", "")),
				_fmt(float(order.get("remaining_hours", 0.0))),
			]
			box.add_child(_label(progress, 13, COLOR_BRASS))
		var worker_row := HFlowContainer.new()
		worker_row.add_theme_constant_override("h_separation", 8)
		worker_row.add_child(_label("工人 %d/%d" % [
			_worker_count(building), int(building.get("worker_slots", 0)),
		], 13, COLOR_MUTED))
		if int(building.get("worker_slots", 0)) > 0:
			worker_row.add_child(_action("派 1 名 %s" % _name(building.get("worker_role_name_key", "")),
				&"base.assign_worker", {"instance_id": String(building.get("instance_id", "")), "amount": 1}))
		box.add_child(worker_row)
		var upgrade_id := _upgrade_for(String(building.get("building_id", "")), int(building.get("level", 1)))
		if not upgrade_id.is_empty() and order.is_empty():
			box.add_child(_action("升级", &"base.upgrade", {
				"instance_id": String(building.get("instance_id", "")),
				"upgrade_id": upgrade_id,
			}))
	panel.add_child(box)
	return panel


func _storage() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label(_t("ui.base.storage", "基地仓储"), 18, COLOR_BRASS))
	var storage: Dictionary = _model.get("storage", {})
	for item in storage.get("items", []):
		if item is Dictionary:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_child(_label("%s × %d" % [_name((item as Dictionary).get("name_key", "")), int((item as Dictionary).get("amount", 0))], 14, COLOR_TEXT))
			row.add_child(_action("取回 5", &"base.withdraw", {
				"item_id": String((item as Dictionary).get("item_id", "")), "amount": 5,
			}))
			box.add_child(row)
	for material in _model.get("warehouse_items", []):
		if material is Dictionary:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_child(_label("%s（港口 %d）" % [
				_name((material as Dictionary).get("name_key", "")),
				int((material as Dictionary).get("amount", 0)),
			], 13, COLOR_MUTED))
			row.add_child(_action("投入 5", &"base.deposit", {
				"item_id": String((material as Dictionary).get("item_id", "")), "amount": 5,
			}))
			box.add_child(row)
	return box


func _workers() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label(_t("ui.base.workers", "工人"), 18, COLOR_BRASS))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	for role in _model.get("available_roles", []):
		if role is Dictionary:
			row.add_child(_action("雇 1 名 %s（%d 金）" % [
				_name((role as Dictionary).get("name_key", "")),
				int((role as Dictionary).get("hire_cost", 0)),
			], &"base.hire_worker", {"role_id": String((role as Dictionary).get("id", "")), "amount": 1}))
	box.add_child(row)
	return box


func _wait_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_child(_action(_t("ui.base.wait_1", "等待 1 小时"), &"sim.advance", {"hours": 1}))
	row.add_child(_action(_t("ui.base.wait_12", "等待 12 小时"), &"sim.advance", {"hours": 12}))
	return row


func _upgrade_for(building_id: String, level: int) -> String:
	for upgrade in _model.get("available_upgrades", []):
		if upgrade is Dictionary \
				and String((upgrade as Dictionary).get("building_ref", "")) == building_id \
				and int((upgrade as Dictionary).get("from_level", 0)) == level:
			return String((upgrade as Dictionary).get("id", ""))
	return ""


func _worker_count(building: Dictionary) -> int:
	var total := 0
	for worker in building.get("workers", []):
		if worker is Dictionary:
			total += int((worker as Dictionary).get("amount", 0))
	return total


func _status_text(status: String) -> String:
	match status:
		"building":
			return _t("ui.base.status_building", "建造中")
		"upgrading":
			return _t("ui.base.status_upgrading", "升级中")
		_:
			return _t("ui.base.status_ready", "已完工")


func _action(text: String, command: StringName, params: Dictionary) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"SNGhostButton"
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(func() -> void: command_requested.emit(command, params))
	return button


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	return panel


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _badge(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNInsetPanel"
	var label := _label(text, 13, COLOR_TEXT)
	panel.add_child(label)
	return panel


func _name(key: Variant) -> String:
	return _t(String(key), String(key))


func _t(key: String, fallback: String) -> String:
	if _tr.is_valid():
		return String(_tr.call(key, fallback))
	return fallback


func _fmt(value: float) -> String:
	return "%.1f" % value if absf(value - roundf(value)) > 0.01 else "%d" % int(roundf(value))
