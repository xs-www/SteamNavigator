class_name OverviewScreen
extends VBoxContainer
## @static-doc
## 作用：港口总览页面场景：组合港口横幅、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录；三种呈现由 Shell 控制——裸 3D 舞台（页面只留 spacer）、详细总览抽屉（原 2D 面板覆盖舞台）与 2D 回退总览。阶段 4.3 / U6 起不再渲染旧线稿海图；2026-10-28 底部状态条与抽屉移除后，「详细总览」就是 2D 总览页本身。
##
## Port overview presentation. The shell supplies all resolved application data.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 面板保持 Theme 默认钢制 `Panel` / `SNInsetPanel`（纹理化黄铜钢板）；
##   资源条 `SNResourceMeter` 用主题 ProgressBar 纹理，徽标用 `SNBadge`。
## - 横幅压暗层取 `SNSkin.color("bg.abyss")` 后设 alpha（0.6）；文字与状态色全部取
##   `SNSkin.color(token)`（text.light / text.muted / brass.highlight / state.water /
##   state.success / state.danger），本文件无内联十六进制色与 StyleBoxFlat。
## - 尺寸约束：横幅 236 px、右列 `custom_minimum_size = (400, 0)`、左右 1.7:1、
##   快捷入口 / 等待按钮文本与信号不变；不新增节点层级。
## - 反馈 #3：主线摘要的期限行在 `has_deadline=false` 时显示「引导委托 · 无期限」，
##   奖励文案（`reward_text`，由 Shell 生成）对无期限委托显示「完成 +N」。
## @end-static-doc

signal navigation_requested(screen_id: StringName, params: Dictionary)
signal command_requested(command: StringName, params: Dictionary)
## Requested when the player switches between the 2D overview and the 3D port
## stage. The Shell owns the stage host; the page only expresses intent.
signal stage_toggle_requested

var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	var stage_available := bool(vm.get("stage_available", false))
	var stage_mode := bool(vm.get("stage_mode", false)) and stage_available
	# 3D stage mode keeps the page empty so the Shell's full-window stage shows
	# through; the compact chrome and edge signs stay outside it. 2026-10-28：底部
	# 状态条与「详细总览」抽屉移除后，2D 详细布局只作为页面态（`2D 总览`）出现。
	if stage_mode:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(spacer)
		return
	# 2D fallback / explicit 2D overview: the full detail layout is the page.
	if stage_available:
		add_child(_stage_control_row(stage_mode))
	_build_detail(vm)


## The existing detailed overview panels: port, objectives + victory plan, ship,
## quick actions, finances and the notice log. The old line-art map was removed in
## phase 4.3 / U6 — the full-screen chart is the single chart entry.
func _build_detail(vm: Dictionary) -> void:
	var hero := _port_hero(vm)
	if hero != null: add_child(hero)
	var columns := HBoxContainer.new(); columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL; add_child(columns)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.size_flags_stretch_ratio = 1.7; columns.add_child(left)
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.size_flags_stretch_ratio = 1.0; right.custom_minimum_size = Vector2(400, 0); columns.add_child(right)
	left.add_child(_port_panel(vm)); left.add_child(_objective_panel(vm)); left.add_child(_notices_panel(vm))
	right.add_child(_ship_summary_panel(vm)); right.add_child(_quick_actions_panel()); right.add_child(_finance_panel(vm))


## One row above the content: opens/closes the Shell's 3D port stage.
func _stage_control_row(stage_mode: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var button := Button.new()
	button.theme_type_variation = &"SNGhostButton"
	button.text = (
		_loc("ui.button.overview_back", "返回总览")
		if stage_mode
		else _loc("ui.button.port_stage", "俯瞰港口")
	)
	button.pressed.connect(func(): stage_toggle_requested.emit())
	row.add_child(button)
	row.add_child(_label(_loc("ui.hint.port_stage", "点击场景里的设施热点进入对应页面。"), 12, SNSkin.color("text.muted")))
	return row


func _port_hero(vm: Dictionary) -> Control:
	var banner_path := String(vm.get("banner_path", ""))
	if banner_path.is_empty(): return null
	# 港口横幅随内容模组发布（mod 包内是原始 PNG），优先用内容资源加载器。
	var texture := ContentAssetLoader.load_texture(banner_path) if not ResourceLoader.exists(banner_path) else (load(banner_path) as Texture2D)
	if texture == null: return null
	var port: Dictionary = vm.get("current_port", {})
	var hero := Control.new(); hero.custom_minimum_size = Vector2(0, 236); hero.clip_contents = true; hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new(); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); image.texture = texture; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; hero.add_child(image)
	var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); var shade_color := SNSkin.color("bg.abyss"); shade_color.a = 0.6; shade.color = shade_color; shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; hero.add_child(shade)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.add_theme_constant_override("margin_left", 30); margin.add_theme_constant_override("margin_right", 30); margin.add_theme_constant_override("margin_top", 22); margin.add_theme_constant_override("margin_bottom", 22); margin.mouse_filter = Control.MOUSE_FILTER_IGNORE; hero.add_child(margin)
	var column := VBoxContainer.new(); column.alignment = BoxContainer.ALIGNMENT_END; column.add_theme_constant_override("separation", 4); margin.add_child(column)
	column.add_child(_label("北纬 52° · 工业港", 11, SNSkin.color("brass.highlight"))); column.add_child(_label(_loc(String(port.get("name_key", "")), String(port.get("id", ""))), 46, SNSkin.color("brass.highlight")))
	var description_key := String(port.get("description_key", "")); if not description_key.is_empty(): column.add_child(_label(_loc(description_key, ""), 14, SNSkin.color("text.light")))
	var facility_row := HBoxContainer.new(); facility_row.add_theme_constant_override("separation", 6)
	for facility in vm.get("facility_labels", []): facility_row.add_child(_badge(String(facility)))
	column.add_child(facility_row); return hero


func _port_panel(vm: Dictionary) -> Control:
	var panel := _panel(); var box := _content(panel); var port: Dictionary = vm.get("current_port", {})
	box.add_child(_heading("港口", _loc(String(port.get("name_key", "")), String(port.get("id", ""))), "当前停靠"))
	var facilities: Array = vm.get("facility_labels", []); box.add_child(_label("设施: " + (", ".join(facilities) if not facilities.is_empty() else "—"), 13, SNSkin.color("text.muted")))
	box.add_child(_label("时间 %s · 金币 %d · 声誉 %d" % [String(vm.get("time_label", "")), int(vm.get("money", 0)), int(vm.get("reputation", 0))], 13, SNSkin.color("text.light")))
	if vm.get("debt", null) is Dictionary:
		var debt: Dictionary = vm["debt"]; box.add_child(_label("债务剩余 %s · 到期 %s" % [_fmt(float(debt.get("remaining", 0.0))), ClockService.format_time(float(debt.get("due_time", 0.0)))], 13, SNSkin.color("state.danger")))
	return panel


func _objective_panel(vm: Dictionary) -> Control:
	var panel := _panel(); var box := _content(panel); box.add_child(_heading("当前目标", "主线航程", "优先完成主线以推进章节"))
	var contracts: Dictionary = vm.get("contracts", {}); var active: Variant = contracts.get("main", null); var offer: Variant = contracts.get("main_offer", null); var contract: Variant = active if active is Dictionary else offer
	if contract is Dictionary:
		box.add_child(_label("%s · %s" % ["主线进行中" if active is Dictionary else "可接主线", _loc(String(contract.get("name_key", "")), String(contract.get("template_id", "")))], 14, SNSkin.color("text.light")))
		# 反馈 #3：无期限主线在摘要里显示「引导委托 · 无期限」，不显示占位截止时间。
		var deadline_text := (
			"期限 %s" % String(contract.get("deadline_label", ""))
			if bool(contract.get("has_deadline", true))
			else _loc("ui.label.contract_guidance", "引导委托") + " · " + _loc("ui.label.contract_untimed", "无期限")
		)
		box.add_child(_label("%s → %s · %s" % [_loc(String(contract.get("origin_name_key", "")), String(contract.get("origin", ""))), _loc(String(contract.get("destination_name_key", "")), String(contract.get("destination", ""))), deadline_text], 13, SNSkin.color("text.muted")))
		box.add_child(_label(String(contract.get("payload_text", "载荷：—")), 13, SNSkin.color("text.light"))); box.add_child(_label(String(contract.get("reward_text", "")), 13, SNSkin.color("text.muted")))
	else: box.add_child(_label("暂无主线委托", 13, SNSkin.color("text.muted")))
	box.add_child(_nav_button("查看全部委托", &"contracts")); box.add_child(_victory_plan(vm)); return panel


func _victory_plan(vm: Dictionary) -> Control:
	var panel := _panel(); panel.theme_type_variation = &"SNInsetPanel"; var box := _content(panel); var contracts: Dictionary = vm.get("contracts", {}); var victory: Dictionary = vm.get("victory", {}); var gates: Dictionary = victory.get("conditions", {})
	var main_done := int(contracts.get("main_done", 0)); var main_total := int(contracts.get("main_total", 0)); var main_complete := bool(contracts.get("main_chain_complete", gates.get("main_complete", false))); var ready := bool(gates.get("ready", false)); var progress := _loc("ui.victory.plan_readiness", "") % [main_done, main_total]
	box.add_child(_heading(_loc("ui.label.victory_progress", ""), _loc("ui.victory.plan_title", ""), progress)); box.add_child(_victory_step(_loc("ui.victory.plan_main", ""), main_complete, progress)); box.add_child(_victory_step(_loc("ui.victory.plan_hull", ""), bool(gates.get("large_hull", false)))); box.add_child(_victory_step(_loc("ui.victory.plan_boiler", ""), bool(gates.get("boiler", false)))); box.add_child(_victory_step(_loc("ui.victory.plan_cargo", ""), bool(gates.get("cargo", false)))); box.add_child(_victory_step(_loc("ui.victory.plan_shipyard", ""), bool(gates.get("shipyard", false))))
	if ready: box.add_child(_label(_loc("ui.victory.plan_ready", ""), 13, SNSkin.color("state.success")))
	elif main_complete: box.add_child(_label(_loc("ui.victory.plan_main_done", ""), 14, SNSkin.color("brass.highlight")))
	elif not bool(gates.get("large_hull", false)): box.add_child(_label(_loc("ui.victory.plan_locked", ""), 12, SNSkin.color("text.muted")))
	box.add_child(_label(_loc("ui.victory.plan_hint", ""), 12, SNSkin.color("text.muted"))); return panel


func _victory_step(text: String, done: bool, detail: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label("✓" if done else "○", 14, SNSkin.color("state.success") if done else SNSkin.color("text.muted")))
	var name := _label(text, 13, SNSkin.color("text.light") if done else SNSkin.color("text.muted"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	if not detail.is_empty():
		row.add_child(_label(detail, 12, SNSkin.color("text.muted")))
	return row


func _ship_summary_panel(vm: Dictionary) -> Control:
	var panel := _panel(); var box := _content(panel); var ship: Dictionary = vm.get("ship", {}); box.add_child(_heading("船只", "当前船只", "载重与消耗")); box.add_child(_label("航速 %s · 煤耗 %s/h · 水耗 %s/h" % [_fmt(float(ship.get("speed", 0.0)), 2), _fmt(float(ship.get("coal_rate", 0.0)), 2), _fmt(float(ship.get("water_rate", 0.0)), 2)], 13, SNSkin.color("text.muted")))
	var durability := SNResourceMeter.new(); durability.label_text = "耐久"; durability.current_value = float(ship.get("durability", 0.0)); durability.maximum_value = maxf(1.0, float(ship.get("max_durability", 1.0))); durability.suffix = ""; durability.hint = ""; durability.tone = SNResourceMeter.Tone.BRASS; box.add_child(durability)
	var cargo := SNResourceMeter.new(); cargo.label_text = "货舱"; cargo.current_value = float(ship.get("cargo_used", 0.0)); cargo.maximum_value = maxf(1.0, float(ship.get("cargo_capacity", 1.0))); cargo.suffix = ""; cargo.hint = "旅客 %d / %d" % [int(ship.get("passengers", 0)), int(ship.get("passenger_capacity", 0))]; cargo.tone = SNResourceMeter.Tone.WATER; box.add_child(cargo)
	box.add_child(_label("%s %s" % [_loc("ui.label.inventory_cost", ""), _fmt(float(ship.get("cargo_cost_basis", 0.0)))], 13, SNSkin.color("text.muted")))
	for module in ship.get("modules", []): box.add_child(_label("· %s" % _loc(String(module.get("name_key", "")), String(module.get("module_id", ""))), 13, SNSkin.color("text.light")))
	for stack in ship.get("cargo", []):
		var name := _loc(String(stack.get("name_key", "")), String(stack.get("item_id", "")))
		if bool(stack.get("is_contract", false)): box.add_child(_label("· %s ×%d · %s" % [name, int(stack.get("amount", 0)), _loc("ui.label.contract_cargo", "")], 13, SNSkin.color("text.muted")))
		else: box.add_child(_label("· %s ×%d · %s %s" % [name, int(stack.get("amount", 0)), _loc("ui.label.avg_cost", ""), _fmt(float(stack.get("average_cost", 0.0)))], 13, SNSkin.color("text.light")))
	box.add_child(_nav_button("前往船厂改造", &"shipyard")); return panel


func _quick_actions_panel() -> Control:
	var panel := _panel(); var box := _content(panel); box.add_child(_heading("快捷入口", "港口操作", "常用功能"))
	# 4.3.4 / U7：出航准备页已删除，快捷入口改为打开海图（出航在海图弹窗确认）。
	for action in [["market", "市场买卖"], ["contracts", "接取委托"], ["shipyard", "船只改造"], ["supply", "补给维修"], ["tavern", "酒馆情报"], ["sea_chart", "打开海图"]]: box.add_child(_nav_button(String(action[1]), StringName(action[0])))
	box.add_child(_label(_loc("ui.button.wait", ""), 13, SNSkin.color("text.muted"))); var wait_row := HBoxContainer.new(); wait_row.add_theme_constant_override("separation", 6)
	for hours in [6, 12, 24]:
		var button := Button.new(); button.text = "%d h" % hours; button.pressed.connect(_emit_wait.bind(hours)); wait_row.add_child(button)
	box.add_child(wait_row); box.add_child(_label(_loc("ui.hint.wait", ""), 11, SNSkin.color("text.muted"))); return panel


func _finance_panel(vm: Dictionary) -> Control:
	var panel := _panel(); var box := _content(panel); box.add_child(_heading("财务", "现金与债务", "")); box.add_child(_label("金币 %d" % int(vm.get("money", 0)), 15, SNSkin.color("text.light")))
	if vm.get("debt", null) is Dictionary: box.add_child(_label("已有贷款，收入将优先自动还款。", 12, SNSkin.color("text.muted")))
	else: box.add_child(_label("可借款 400，利息 10%，96 小时后到期。", 12, SNSkin.color("text.muted"))); var borrow := Button.new(); borrow.text = "借款 400"; borrow.pressed.connect(func(): command_requested.emit(&"debt.borrow", {"amount": 400})); box.add_child(borrow)
	return panel


func _notices_panel(vm: Dictionary) -> Control:
	var panel := _panel()
	var box := _content(panel)
	box.add_child(_label("航行记录", 15, SNSkin.color("text.muted")))
	var notices: Array = vm.get("notice_texts", [])
	if notices.is_empty():
		box.add_child(_label("—", 13, SNSkin.color("text.muted")))
	for notice in notices:
		box.add_child(_label("· %s" % notice, 13, SNSkin.color("text.light")))
	return panel


func _nav_button(text: String, screen_id: StringName) -> Button:
	var button := Button.new(); button.text = text; button.theme_type_variation = &"SNGhostButton"; button.pressed.connect(func(): navigation_requested.emit(screen_id, {})); return button
func _emit_wait(hours: int) -> void:
	command_requested.emit(&"port.wait", {"hours": hours})
func _badge(text: String) -> SNBadge:
	var badge := SNBadge.new(); badge.text = text; badge.tone = SNBadge.Tone.NEUTRAL; return badge
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
