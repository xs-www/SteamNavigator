extends TestCase
## 船厂改装界面契约（图2 正常态 / 图3 改装态重构后）。
##
## 正常态：左侧「已有船舶」船卡、中间实机渲染、右侧「组件」分类入口；
## 改装态：左侧贴图纵剖图 + 全部槽位贴片、中间当前分类的槽位/装配/购买/打造、
## 右侧竖排分类 tab（含「杂项」：打造订单 / 在港等待 / 仓库材料与模块）。
## 旧的整页下方面板（港口仓库 / 可购买模块 / 打造 / 通关条件）必须从本页消失。
##
## The shell scene is mounted for real (same fixture as test_ui_shell) so a
## wiring mistake in main.gd or the shipyard screen fails here.

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const SHIPYARD_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/shipyard_screen.gd")
const SHIP_VIEW_SCRIPT := preload("res://framework/ui/components/sn_ship_view.gd")
const SLOT_TARGET_SCRIPT := preload("res://framework/ui/components/sn_slot_target.gd")
const PART_ROW_SCRIPT := preload("res://framework/ui/components/sn_part_row.gd")
const WEAPON_ROW_SCRIPT := preload("res://framework/ui/components/sn_weapon_row.gd")
const WEAPON_SOCKET_CARD_SCRIPT := preload("res://framework/ui/components/sn_weapon_socket_card.gd")
const STEADY_BUILD := "core:starting_scenario/steady"
const MODE_EXTERIOR := 0
const MODE_CUTAWAY := 1
const SHIP_THUMB_SIZE := Vector2(210, 118)
const MODULE_CATEGORIES := ["hulls", "boiler", "cargo", "utility", "cabin", "weapons"]
## Section titles of the deleted lower panels, by localization key. None of them
## may be rendered on the new shipyard page, in normal or refit mode.
const LEGACY_SECTION_KEYS := [
	"ui.label.parts_hud",
	"ui.label.warehouse",
	"ui.label.available_modules",
	"ui.label.craft",
	"ui.label.recipes",
	"ui.victory.plan_title",
	"ui.label.victory_progress",
]


func _mount(seed_value: int) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": seed_value,
	})
	assert_true(bool(started.get("ok", false)), "run.start succeeds in the refit fixture: %s" % str(started))
	var scene: PackedScene = load(MAIN_SCENE)
	assert_not_null(scene, "the playable shell scene loads")
	var shell: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shell)
	return {"context": context, "shell": shell, "tree": tree}


func _unmount(bundle: Dictionary) -> void:
	var shell: Control = bundle["shell"]
	if shell.get_parent() != null:
		shell.get_parent().remove_child(shell)
	shell.free()


func _goto(shell: Control, screen: String) -> void:
	shell._active_screen = screen
	shell._refresh()


## Mounts the shipyard page and returns the screen instance; caller checks null.
func _shipyard(bundle: Dictionary) -> Control:
	var shell: Control = bundle["shell"]
	_goto(shell, "shipyard")
	var screen := _node_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	assert_not_null(screen, "the shell hosts the new shipyard screen")
	return screen


func _expected_slot_count(context: AppContext) -> int:
	var ship: Dictionary = context.queries.execute(&"shipyard.view")["data"]["ship"]
	var count := 4 + int(ship["cargo_slots"])
	if int(ship["cabin_slots"]) > 0:
		count += 1
	return count


func _node_with_script(root: Node, script: Script) -> Control:
	for child in root.get_children():
		if child.get_script() == script:
			return child
		var found := _node_with_script(child, script)
		if found != null:
			return found
	return null


func _nodes_with_script(root: Node, script: Script, out: Array = []) -> Array:
	for child in root.get_children():
		if child.get_script() == script:
			out.append(child)
		_nodes_with_script(child, script, out)
	return out


## Every Control that selects a Theme variation by name (e.g. the blueprint board).
func _nodes_with_variation(root: Node, variation: StringName, out: Array = []) -> Array:
	for child in root.get_children():
		if child is Control and (child as Control).theme_type_variation == variation:
			out.append(child)
		_nodes_with_variation(child, variation, out)
	return out


func _label_texts(root: Node, out: Array = []) -> Array:
	for child in root.get_children():
		if child is Label:
			out.append(String((child as Label).text))
		_label_texts(child, out)
	return out


func _button_with_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and String((child as Button).text).strip_edges() == text:
			return child
		var found := _button_with_text(child, text)
		if found != null:
			return found
	return null


func _button_by_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and String((child as Button).text) == text:
			return child
		var found := _button_by_text(child, text)
		if found != null:
			return found
	return null


func _button_count_with_text(root: Node, text: String) -> int:
	var count := 0
	for child in root.get_children():
		if child is Button and String((child as Button).text).strip_edges() == text:
			count += 1
		count += _button_count_with_text(child, text)
	return count


## The owned-ship card always reserves a thumbnail area: the authored TextureRect
## once the art is imported, or the localized placeholder panel before that.
func _ship_thumb_area(root: Node) -> Control:
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.custom_minimum_size == SHIP_THUMB_SIZE and (control is TextureRect or control is PanelContainer):
				return control
		var found := _ship_thumb_area(child)
		if found != null:
			return found
	return null


func _texture_rects(root: Node, out: Array[TextureRect] = []) -> Array[TextureRect]:
	for child in root.get_children():
		if child is TextureRect:
			out.append(child as TextureRect)
		_texture_rects(child, out)
	return out


## Localized titles of the deleted lower panels must be absent everywhere on the
## page; if a key stops existing the assertion fails instead of silently passing.
func _assert_no_legacy_sections(shell: Control) -> void:
	var texts := _label_texts(shell._root_box)
	for key in LEGACY_SECTION_KEYS:
		var title: String = shell._tr(key, "")
		assert_false(title.is_empty(), "%s is still localized so the legacy-label scan can run" % key)
		assert_false(texts.has(title), "the deleted lower panel '%s' (%s) is gone from the shipyard page" % [title, key])


func test_normal_mode_shows_owned_ship_render_and_component_categories() -> void:
	var bundle := _mount(5201)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	var stage: Variant = screen.get("_stage")
	assert_not_null(stage, "normal mode mounts the live render stage")
	assert_eq(int(stage.mode), MODE_EXTERIOR, "normal mode shows the exterior ship view")
	var expected := _expected_slot_count(context)
	assert_eq(screen.get("_slots").size(), expected, "one slot per hull, boiler, navigation, safety, cargo and cabin position")
	assert_eq(stage._slot_targets.size(), expected, "the stage keeps one drop target per slot")
	for target in stage._slot_targets:
		assert_false(target.visible, "slot chips stay hidden until refit mode")
	assert_false(bool(screen.get("_refit")), "the page starts in normal mode")
	var labels := _label_texts(shell._root_box)
	assert_contains(labels, shell._tr("ui.label.ship_list", "已有船舶"), "the owned-ship list is titled 已有船舶")
	assert_contains(labels, shell._tr("ui.label.components", "组件"), "the right column is titled 组件")
	assert_contains(labels, shell._tr("ui.tag.current_ship", "当前"), "the ship card marks the flagship as current")
	var hull: ContentDefinition = context.registries.get_by_id(
		ContentTypes.HULL,
		String(context.queries.execute(&"shipyard.view")["data"]["ship"]["hull_id"])
	)
	assert_not_null(hull, "the ironclad hull definition is registered")
	if hull != null:
		assert_contains(labels, context.translate(String(hull.name_key), ""), "the ship card names the hull")
	for category in MODULE_CATEGORIES:
		var category_label: String = shell._tr("ui.category.%s" % category, "")
		assert_false(category_label.is_empty(), "the %s category has a localized label" % category)
		assert_not_null(_button_with_text(shell._root_box, category_label), "the components column offers the %s category" % category)
	assert_not_null(_ship_thumb_area(shell._root_box), "the owned-ship card reserves its thumbnail area")
	_assert_no_legacy_sections(shell)
	assert_eq(_nodes_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT).size(), 1, "the page hosts exactly one shipyard screen")
	_unmount(bundle)


func test_refit_mode_switches_to_cutaway_and_remembers_mode_and_category() -> void:
	var bundle := _mount(5202)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	var refit_button: Variant = screen.get("_refit_button")
	assert_true(refit_button is Button, "the refit toggle is a real button")
	if refit_button is Button:
		(refit_button as Button).emit_signal("pressed")
	assert_true(bool(screen.get("_refit")), "pressing 改装 enters refit mode")
	assert_eq(String(screen.get("_category")), "hulls", "refit opens on the hulls category")
	assert_true(bool(shell._shipyard_refit), "the shell remembers refit mode for the next rebuild")
	var stage: Variant = screen.get("_stage")
	assert_not_null(stage, "refit mode mounts the cross-section stage")
	assert_eq(int(stage.mode), MODE_CUTAWAY, "refit shows the longitudinal cutaway")
	var visible_chips := 0
	for target in stage._slot_targets:
		if target.visible:
			visible_chips += 1
	assert_eq(visible_chips, _expected_slot_count(context), "every slot chip is visible on the cutaway")
	# The refit page rebuilds the toggle inside the operations dock header.
	var refit_done_button: Variant = screen.get("_refit_button")
	assert_true(refit_done_button is Button, "refit mode keeps a refit toggle")
	if refit_done_button is Button:
		assert_eq(String((refit_done_button as Button).text), shell._tr("ui.label.refit_done", "完成改装"), "the toggle now offers 完成改装")
	var labels := _label_texts(shell._root_box)
	assert_contains(labels, shell._tr("ui.label.category_tabs", "部件分类"), "refit shows the category picker")
	assert_not_null(_button_with_text(shell._root_box, shell._tr("ui.category.misc", "杂项")), "the category picker includes 杂项")
	assert_contains(labels, shell._tr("ui.label.section_slots", "槽位"), "the hulls category lists its slot")
	# Buying and crafting live in their own tabs: the install tab must not mix
	# them, and the craft tab must show the recipe section once selected.
	assert_false(labels.has(shell._tr("ui.label.craft_section", "按配方打造")), "the install tab does not mix craft entries")
	assert_not_null(_button_with_text(shell._root_box, shell._tr("ui.tab.buy", "购买")), "the dock offers a separate buy tab")
	screen.set_tab("craft")
	assert_contains(_label_texts(shell._root_box), shell._tr("ui.label.craft_section", "按配方打造"), "the craft tab lists the recipes")
	assert_false(_label_texts(shell._root_box).has(shell._tr("ui.label.section_slots", "槽位")), "the craft tab does not repeat the install cards")
	screen.set_tab("install")
	_assert_no_legacy_sections(shell)
	# Category switching is synchronous and reported to the shell.
	screen.set_category("cargo")
	assert_eq(String(screen.get("_category")), "cargo", "set_category switches the operation panel")
	assert_eq(String(shell._shipyard_category), "cargo", "the shell stores the refit category")
	assert_true(bool(screen.get("_refit")), "switching category keeps refit mode")
	assert_contains(_label_texts(shell._root_box), shell._tr("ui.label.slot_cargo", "货舱槽 %d") % 1, "the cargo category lists cargo slot cards")
	# A full shell rebuild restores both refit mode and the selected category.
	_goto(shell, "shipyard")
	var rebuilt := _node_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	assert_not_null(rebuilt, "the shell rebuilds the shipyard screen")
	if rebuilt != null:
		assert_true(bool(rebuilt.get("_refit")), "the rebuilt shipyard re-enters refit mode")
		assert_eq(String(rebuilt.get("_category")), "cargo", "the rebuilt shipyard restores the category")
		var rebuilt_stage: Variant = rebuilt.get("_stage")
		assert_eq(int(rebuilt_stage.mode), MODE_CUTAWAY, "the rebuilt stage is already a cutaway")
	_unmount(bundle)


func test_damaged_module_shows_a_condition_badge() -> void:
	var bundle := _mount(5210)
	var context: AppContext = bundle["context"]
	var shell: Control = bundle["shell"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	assert_false(_has_condition_badge(shell, shell._tr("ui.label.status", "状态")), "a healthy ship shows no condition badge")
	ShipModules.damage(context.state.ship(), "boiler", 0, 0.5)
	_goto(shell, "shipyard")
	var damaged_screen := _node_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	if damaged_screen != null:
		var refit_button: Variant = damaged_screen.get("_refit_button")
		if refit_button is Button:
			(refit_button as Button).emit_signal("pressed")
		damaged_screen.set_category("boiler")
	var expected := "%s %d%%" % [shell._tr("ui.label.status", "状态"), 50]
	assert_contains(_label_texts(shell._root_box), expected, "a damaged boiler shows its condition badge")
	_unmount(bundle)


func _has_condition_badge(shell: Control, status_label: String) -> bool:
	for text in _label_texts(shell._root_box):
		if String(text).begins_with(status_label + " "):
			return true
	return false


func test_cutaway_uses_the_authored_section_texture() -> void:
	assert_eq(String(SHIP_VIEW_SCRIPT.SECTION_TEXTURE_PATH), "res://assets/ui/shipyard/ship_section.png", "the cross-section texture path is the authored PNG")
	assert_true(ResourceLoader.exists(SHIP_VIEW_SCRIPT.SECTION_TEXTURE_PATH), "the authored cross-section PNG is imported")
	var bundle := _mount(5203)
	var shell: Control = bundle["shell"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	var refit_button: Variant = screen.get("_refit_button")
	if refit_button is Button:
		(refit_button as Button).emit_signal("pressed")
	var stage: Variant = screen.get("_stage")
	assert_not_null(stage, "refit mode mounts the cross-section stage")
	assert_true(bool(stage.has_section_texture()), "the cutaway loaded the authored section texture instead of the placeholder")
	var texture_size: Vector2 = stage.section_texture_size()
	assert_true(texture_size.x > 0.0 and texture_size.y > 0.0, "the section texture reports a real pixel size: %s" % str(texture_size))
	_unmount(bundle)


## 改装蓝图底板：`docs/design/ui_controls_v1/blueprint_panel/` 记录的九宫格在 Godot
## 里的落点。底板 = Theme variation + StyleBoxTexture（取图区域 0.5 倍），改装态左列
## 换成该材质、舞台只画线稿；正常态与无 blueprint_views 的旧船仍用普通面板。
func test_refit_blueprint_board_uses_the_nine_slice_panel() -> void:
	var bundle := _mount(5211)
	var shell: Control = bundle["shell"]
	var ui_theme: Theme = shell.theme
	assert_not_null(ui_theme, "the shell applies the shared UI theme")
	if ui_theme != null:
		assert_eq(String(ui_theme.get_type_variation_base(&"SNBlueprintPanel")), "PanelContainer",
			"SNBlueprintPanel is a PanelContainer variation")
		var style: Variant = ui_theme.get_stylebox(&"panel", &"SNBlueprintPanel")
		assert_true(style is StyleBoxTexture, "the blueprint board is a nine-slice StyleBoxTexture")
		if style is StyleBoxTexture:
			var board := style as StyleBoxTexture
			assert_not_null(board.texture, "the board stylebox binds the authored panel PNG")
			if board.texture != null:
				assert_eq(board.texture.resource_path, "res://assets/ui/shipyard/blueprint_panel.png",
					"the board uses the runtime half-scale crop of the authored panel")
				assert_eq(board.texture.get_size(), Vector2(841, 299),
					"the asset is the 1682x598 layout.json region at 0.5 scale")
			# layout.json：九宫格 L/T/R/B 112/108/112/108 → 56/54；安全区 132/124 → 66/62。
			assert_true(is_equal_approx(board.texture_margin_left, 56.0), "left slice margin is half of 112")
			assert_true(is_equal_approx(board.texture_margin_top, 54.0), "top slice margin is half of 108")
			assert_true(is_equal_approx(board.texture_margin_right, 56.0), "right slice margin matches the left one")
			assert_true(is_equal_approx(board.texture_margin_bottom, 54.0), "bottom slice margin matches the top one")
			assert_true(is_equal_approx(board.content_margin_left, 66.0), "content safe inset is half of 132")
			assert_true(is_equal_approx(board.content_margin_top, 62.0), "content safe inset is half of 124")
			assert_true(board.content_margin_left > board.texture_margin_left,
				"the safe area still leaves space between the frame and the content")
			assert_true(board.content_margin_top > board.texture_margin_top,
				"the safe area still leaves space between the frame and the content")
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	assert_eq(_nodes_with_variation(shell._root_box, &"SNBlueprintPanel").size(), 0,
		"normal mode keeps the elevated panel instead of the blueprint board")
	var normal_stage: Variant = screen.get("_stage")
	assert_false(bool(normal_stage.uses_blueprint_backdrop()),
		"the exterior stage never paints onto a board")
	var refit_button: Variant = screen.get("_refit_button")
	if refit_button is Button:
		(refit_button as Button).emit_signal("pressed")
	var boards := _nodes_with_variation(shell._root_box, &"SNBlueprintPanel")
	assert_eq(boards.size(), 1, "refit mode swaps exactly one column onto the nine-slice board")
	var refit_stage: Variant = screen.get("_stage")
	assert_not_null(refit_stage, "refit mode mounts the cutaway stage")
	if refit_stage != null:
		assert_true(bool(refit_stage.has_blueprint_views()), "the fixture hull ships line art for the board")
		assert_true(bool(refit_stage.uses_blueprint_backdrop()),
			"the line-art stage leaves the frame and blue field to the board")
		if not boards.is_empty():
			var board_node: Control = boards[0]
			var stage_control := refit_stage as Control
			assert_true(board_node.size.x >= stage_control.size.x, "the board wraps the stage horizontally")
			assert_true(board_node.size.y >= stage_control.size.y, "the board wraps the stage vertically")
	_unmount(bundle)


func test_ship_card_uses_the_authored_thumbnail() -> void:
	var bundle := _mount(5208)
	var shell: Control = bundle["shell"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	var thumb: Texture2D = screen.get("_ship_thumb")
	assert_not_null(thumb, "the owned-ship card loaded the authored ship thumbnail")
	if thumb != null:
		var matching := 0
		for rect in _texture_rects(shell._root_box):
			if rect.texture == thumb:
				matching += 1
		assert_eq(matching, 1, "the owned-ship card draws the authored thumbnail")
		assert_false(_label_texts(shell._root_box).has(shell._tr("ui.label.ship_thumb_missing", "")), "the placeholder text is gone once the thumbnail exists")
	_unmount(bundle)


func test_renderer_slot_is_swappable_for_the_future_2_5d_scene() -> void:
	var bundle := _mount(5204)
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	var stage: Control = screen.get("_stage")
	assert_true(stage.has_method("set_renderer"), "the stage exposes the 2.5D renderer hook")
	if SNShipStage3D.is_supported():
		assert_true(bool(stage.has_renderer()), "the 3D ship stage is mounted by default when ship GLBs exist")
		var renderer: Node = stage.get("_renderer")
		if renderer is SNShipStage3D:
			assert_true(bool(renderer.has_ship()), "the 3D stage mounts a hull model")
			assert_true(bool(renderer.has_stage()), "the 3D host mounts a LocationStage scene")
			assert_eq(String(renderer.stage_id()), "shipyard", "the shipyard stage reports its stage id")
			stage.set_mode(MODE_CUTAWAY)
			assert_false(bool(renderer.is_stage_visible()), "cutaway mode hides the 3D stage behind the section texture")
			stage.set_mode(MODE_EXTERIOR)
			assert_true(bool(renderer.is_stage_visible()), "exterior mode shows the 3D stage again")
	else:
		assert_false(bool(stage.has_renderer()), "without ship GLBs the procedural placeholder stays active")
	var provider := Control.new()
	provider.name = "FutureStage"
	stage.set_renderer(provider)
	assert_true(bool(stage.has_renderer()), "a provider node replaces the placeholder")
	assert_eq(provider.get_parent(), stage, "the provider is mounted under the stage")
	assert_eq(int(stage.get("mode")), MODE_EXTERIOR, "the stage keeps driving mode through the interface")
	stage.set_mode(MODE_CUTAWAY)
	stage.set_renderer(null)
	assert_false(bool(stage.has_renderer()), "passing null restores the placeholder renderer")
	provider.free()
	_unmount(bundle)


func test_dragging_a_warehouse_module_maps_to_install_command() -> void:
	var bundle := _mount(5205)
	var context: AppContext = bundle["context"]
	var shell: Control = bundle["shell"]
	var port_id := String(context.state.current_port_id())
	# Put an owned navigation module in the current port warehouse so the refit
	# operations panel has a free part to drag.
	var candidate := {}
	for row in context.queries.execute(&"shipyard.view")["data"]["candidates"]:
		if row is Dictionary and String(row.get("category", "")) == "utility" and bool(row["can_install"]):
			candidate = row
			break
	assert_true(not candidate.is_empty(), "the fixture offers a utility module to own")
	var module_id := String(candidate["module_id"])
	WarehouseOps.add_module(context.state, port_id, module_id, 1)
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	# The parts HUD for a category lives in the refit operations panel now.
	screen.set_category("utility")
	assert_eq(String(screen.get("_category")), "utility", "the utility category opens")
	var nav_slot := {}
	for slot in screen.get("_slots"):
		if slot is Dictionary and String(slot.get("slot", "")) == "navigation_module":
			nav_slot = slot
	assert_true(not nav_slot.is_empty(), "the cutaway has a navigation slot")
	var stage: Variant = screen.get("_stage")
	var nav_target := _slot_target_for(stage, "navigation_module")
	assert_not_null(nav_target, "the navigation slot has a drop target")
	var part := {
		"module_id": module_id,
		"name": "Fixture compass",
		"category": "utility",
		"source": "warehouse",
		"can_install": true,
	}
	var cargo_part := part.duplicate(true)
	cargo_part["category"] = "cargo"
	assert_true(bool(nav_target._accepts(part)), "an owned free module of the slot's category is accepted")
	assert_false(bool(nav_target._accepts(cargo_part)), "a module for another category is rejected")
	var purchase_part := part.duplicate(true)
	purchase_part["source"] = "purchase"
	assert_false(bool(nav_target._accepts(purchase_part)), "purchase candidates are not drag sources")
	var captured := {}
	screen.command_requested.connect(func(command: StringName, params: Dictionary):
		captured["command"] = command
		captured["params"] = params
	)
	# The operations panel renders a draggable row for the owned warehouse module.
	var draggable: Array = []
	for row in screen.get("_hud_rows"):
		if row.get_script() == PART_ROW_SCRIPT and bool(row.draggable):
			draggable.append(row)
	assert_eq(draggable.size(), 1, "the operations panel lists the owned free module as a draggable row")
	assert_eq(String(draggable[0].part.get("module_id", "")), module_id, "the draggable row is the warehouse module")
	assert_eq(String(draggable[0].part.get("source", "")), "warehouse", "the row reports its drag source")
	# Real drag payload from SNPartRow, dropped through the slot target (the same
	# `_can_drop_data` / `_drop_data` pair the viewport calls for a mouse drop).
	# Regression: the target used to forward only the inner `part`, so the page's
	# `payload.get("part")` lookup was empty and every real drop silently did nothing.
	var payload := {"kind": "ship_parts", "part": (draggable[0].part as Dictionary).duplicate(true)}
	assert_true(bool(nav_target.call("_can_drop_data", Vector2.ZERO, payload)),
		"the slot target accepts the SNPartRow drag payload")
	nav_target.call("_drop_data", Vector2.ZERO, payload)
	assert_eq(String(captured.get("command", "")), "ship.install_module", "dropping a part requests ship.install_module")
	var params: Dictionary = captured.get("params", {})
	assert_eq(String(params.get("module_id", "")), module_id, "the dragged module id is forwarded")
	assert_eq(String(params.get("source", "")), "warehouse", "the drag source becomes the install source")
	if not String(nav_slot.get("replace_module_id", "")).is_empty():
		assert_eq(String(params.get("replace_module_id", "")), String(nav_slot["replace_module_id"]), "a filled slot replaces its current module")
	assert_eq(String(context.state.ship().get("navigation_module_id", "")), module_id, "the drag installs the module on the ship")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, module_id), 0, "the installed module leaves the warehouse")
	_unmount(bundle)


## 回归：真实拖拽链路要同时覆盖「空槽位安装」与「已装配槽位替换」。旧实现的槽位
## 贴片只把内层 part 交给页面，页面按 `payload.part` 解析得到空字典后静默返回，
## 两种拖放都没有命令；直接调页面函数的旧测试用手搓 payload 把这个问题遮住了。
func test_drag_drop_installs_into_empty_slot_and_replaces_filled_slot() -> void:
	var bundle := _mount(5207)
	var context: AppContext = bundle["context"]
	var port_id := String(context.state.current_port_id())
	var starting_nav := String(context.state.ship().get("navigation_module_id", ""))
	assert_true(not starting_nav.is_empty(), "the fixture ship starts with a navigation module")
	var uninstalled := context.commands.execute(&"ship.uninstall_module", {"module_id": starting_nav})
	assert_true(bool(uninstalled.get("ok", false)), "the starting navigation module can be uninstalled to empty its slot: %s" % str(uninstalled))
	# Free some hull weight as well: the chart room is heavier than the spyglass,
	# and a full hold would block the empty-slot install with `weight_limit`.
	var cargo_modules: Array = Array(context.state.ship().get("cargo_modules", []))
	if not cargo_modules.is_empty():
		var cargo_removed := context.commands.execute(&"ship.uninstall_module", {"module_id": String(cargo_modules[0])})
		assert_true(bool(cargo_removed.get("ok", false)), "a cargo module can be uninstalled to free weight: %s" % str(cargo_removed))
	# Take another utility module straight from the content registry: the market
	# candidate list depends on the generated run / port stock, but the drop path
	# only needs an owned free module definition.
	var new_module := _utility_module_id(context, starting_nav)
	assert_true(not new_module.is_empty(), "the content registry offers another utility module")
	WarehouseOps.add_module(context.state, port_id, new_module, 1)

	# 1) Empty slot: dropping the warehouse module installs it without a replacement.
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	screen.set_category("utility")
	var target := _slot_target_for(screen.get("_stage"), "navigation_module")
	assert_not_null(target, "the navigation slot has a drop target")
	var empty_part := _warehouse_part(screen, new_module)
	assert_true(not empty_part.is_empty(), "the operations panel lists the replacement module as a draggable warehouse row")
	var empty_captured := {}
	screen.command_requested.connect(func(command: StringName, params: Dictionary):
		empty_captured["command"] = command
		empty_captured["params"] = params
	)
	target.call("_drop_data", Vector2.ZERO, {"kind": "ship_parts", "part": empty_part})
	assert_eq(String(empty_captured.get("command", "")), "ship.install_module", "dropping onto an empty slot installs")
	var empty_params: Dictionary = empty_captured.get("params", {})
	assert_eq(String(empty_params.get("module_id", "")), new_module, "the empty-slot drop forwards the module id")
	assert_eq(String(empty_params.get("slot", "")), "navigation_module", "the empty-slot drop names the target slot")
	assert_false(empty_params.has("replace_module_id"), "an empty slot must not send a replacement id")
	assert_eq(String(context.state.ship().get("navigation_module_id", "")), new_module, "the module lands in the empty slot")

	# 2) Filled slot: dropping the previous module back replaces the new one and
	#    returns it to the warehouse.
	screen = _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	screen.set_category("utility")
	target = _slot_target_for(screen.get("_stage"), "navigation_module")
	assert_not_null(target, "the rebuilt page still exposes the navigation slot target")
	var replace_part := _warehouse_part(screen, starting_nav)
	assert_true(not replace_part.is_empty(), "the replaced module is back in the warehouse and draggable")
	var replace_captured := {}
	screen.command_requested.connect(func(command: StringName, params: Dictionary):
		replace_captured["command"] = command
		replace_captured["params"] = params
	)
	target.call("_drop_data", Vector2.ZERO, {"kind": "ship_parts", "part": replace_part})
	assert_eq(String(replace_captured.get("command", "")), "ship.install_module", "dropping onto a filled slot installs")
	var replace_params: Dictionary = replace_captured.get("params", {})
	assert_eq(String(replace_params.get("module_id", "")), starting_nav, "the replacement drop forwards the new module id")
	assert_eq(String(replace_params.get("replace_module_id", "")), new_module, "a filled slot sends the module being replaced")
	assert_eq(String(context.state.ship().get("navigation_module_id", "")), starting_nav, "the replacement lands in the slot")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, new_module), 1, "the replaced module returns to the warehouse")
	_unmount(bundle)


## Part payload of a draggable warehouse row for `module_id`, as SNPartRow produces it.
func _warehouse_part(screen: Control, module_id: String) -> Dictionary:
	for row in screen.get("_hud_rows"):
		if row.get_script() != PART_ROW_SCRIPT or not bool(row.draggable):
			continue
		var part: Dictionary = row.part
		if String(part.get("module_id", "")) == module_id and String(part.get("source", "")) == "warehouse":
			return part.duplicate(true)
	return {}


## Any registered utility module id other than `exclude` (registry-driven fixture).
func _utility_module_id(context: AppContext, exclude: String) -> String:
	for definition in context.registries.get_all(ContentTypes.MODULE):
		if definition == null:
			continue
		var module_id := String(definition.id)
		if module_id != exclude and ModuleOps.category_of(definition) == "utility":
			return module_id
	return ""


func _slot_target_for(stage: Node, slot_name: String) -> Control:
	for target in stage._slot_targets:
		if target.get_script() == SLOT_TARGET_SCRIPT and String(target.slot.get("slot", "")) == slot_name:
			return target
	return null


func test_category_navigation_switches_operations_and_misc_hosts_actions() -> void:
	var bundle := _mount(5206)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var view: Dictionary = context.queries.execute(&"shipyard.view")["data"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	# Cargo: one operation card per cargo slot under a category-titled panel.
	screen.set_category("cargo")
	var labels := _label_texts(shell._root_box)
	assert_contains(labels, shell._tr("ui.category.cargo", "货舱"), "the operation panel is titled by category")
	for index in int(view["ship"]["cargo_slots"]):
		assert_contains(labels, shell._tr("ui.label.slot_cargo", "货舱槽 %d") % (index + 1), "the cargo category lists cargo slot %d" % (index + 1))
	assert_not_null(_button_with_text(shell._root_box, shell._tr("ui.category.misc", "杂项")), "the category tabs stay reachable from cargo")
	# Boiler: the boiler slot card belongs to its own category.
	screen.set_category("boiler")
	assert_contains(_label_texts(shell._root_box), shell._tr("ui.label.slot_boiler", "锅炉槽"), "the boiler category shows the boiler slot")
	# Weapons: hull sockets live in the install tab, purchase actions in the buy tab.
	screen.set_category("weapons")
	labels = _label_texts(shell._root_box)
	assert_contains(labels, shell._tr("ui.label.weapon_sockets", "武器槽位"), "the weapons category lists hull sockets")
	# Player feedback 2026-10-27: the dock must not print backend socket ids.
	var first_socket_title := String(screen.call("_weapon_socket_title", view["ship"]["weapon_sockets"][0]))
	assert_contains(labels, first_socket_title, "the first real hull socket is visible with its player-facing mount name")
	assert_false(String("\n".join(labels)).contains("SN_Socket_Weapon_"), "no backend socket id is printed in the dock")
	assert_false(labels.has("购买并安装"), "the install tab does not list purchase cards")
	screen.set_tab("buy")
	assert_contains(_label_texts(shell._root_box), "购买并安装", "the buy tab exposes shipyard purchase actions")
	screen.set_tab("install")
	# Misc: everything that used to live in the deleted lower panels.
	screen.set_category("misc")
	labels = _label_texts(shell._root_box)
	assert_contains(labels, shell._tr("ui.label.orders", "打造订单"), "杂项 hosts the craft orders")
	assert_contains(labels, shell._tr("ui.button.wait", "在港等待"), "杂项 hosts the port wait")
	assert_contains(labels, shell._tr("ui.label.materials", "材料"), "杂项 hosts the warehouse materials")
	assert_contains(labels, shell._tr("ui.label.warehouse_modules", "仓库模块"), "杂项 hosts the warehouse modules")
	for raw_hours in view.get("wait_options", [6, 12, 24]):
		var hours := int(raw_hours)
		if hours > 0:
			assert_not_null(_button_with_text(shell._root_box, "%d h" % hours), "杂项 offers the %d h port wait" % hours)
	assert_false(labels.has(shell._tr("ui.label.craft_section", "按配方打造")), "craft buttons live in the module categories, not in 杂项")
	assert_false(labels.has(shell._tr("ui.label.section_slots", "槽位")), "杂项 shows operations, not slot cards")
	# Craft entry stays in the module type's category, inside the craft tab.
	screen.set_category("hulls")
	screen.set_tab("craft")
	assert_contains(_label_texts(shell._root_box), shell._tr("ui.label.craft_section", "按配方打造"), "the hulls category keeps the craft section")
	_unmount(bundle)


## 2026-10-28 玩家反馈：武器装配与常规改装分离。操作坞分类只保留 6 个常规分类
## （3×2 等宽对齐），舰载武器由坞头「部件改装 / 武器装配」模式切换单独进入；
## 武器模式只有装配 / 购买，没有打造页签，`set_category("weapons")` 仍然兼容。
func test_refit_dock_splits_weapon_install_from_regular_refit() -> void:
	var bundle := _mount(5214)
	var shell: Control = bundle["shell"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	var refit_button: Variant = screen.get("_refit_button")
	if refit_button is Button:
		(refit_button as Button).emit_signal("pressed")
	assert_false(bool(screen.call("is_weapon_mode")), "the dock opens in regular module mode")
	# 1) Regular categories: six equal-width buttons in a 3x2 grid, no 武器 entry.
	var picker := _node_named(shell._root_box, "CategoryPicker")
	assert_not_null(picker, "regular mode shows the module category picker")
	if picker != null:
		var grid := picker as GridContainer
		assert_eq(grid.get_child_count(), 6, "the picker lists exactly the six regular categories")
		assert_eq(int(grid.columns), 3, "six categories use a tidy 3-column grid")
		for category in ["hulls", "boiler", "cargo", "utility", "cabin", "misc"]:
			var label: String = shell._tr("ui.category.%s" % category, "")
			assert_not_null(_button_with_text(grid, label), "the picker offers %s" % category)
			for child in grid.get_children():
				if child is Button and String((child as Button).text) == label:
					assert_eq(
						(child as Control).size_flags_horizontal,
						Control.SIZE_EXPAND_FILL,
						"%s expands to its grid column so every plate shares one width" % category
					)
		assert_eq(
			_button_count_with_text(grid, shell._tr("ui.category.weapons", "武器")),
			0,
			"weapons are not a regular category button"
		)
	# 2) The dock header carries the two dock modes.
	var mode_row := _node_named(shell._root_box, "RefitModeSwitch")
	assert_not_null(mode_row, "the dock exposes a module / weapon mode switch")
	var modules_mode: Button = null
	var weapons_mode: Button = null
	if mode_row != null:
		assert_eq(mode_row.get_child_count(), 2, "the mode switch has exactly two plates")
		modules_mode = _button_with_text(mode_row, shell._tr("ui.label.refit_mode_modules", ""))
		weapons_mode = _button_with_text(mode_row, shell._tr("ui.label.refit_mode_weapons", ""))
		assert_not_null(modules_mode, "the mode switch offers 部件改装")
		assert_not_null(weapons_mode, "the mode switch offers 武器装配")
		for button in [modules_mode, weapons_mode]:
			if button != null:
				assert_eq(
					button.size_flags_horizontal,
					Control.SIZE_EXPAND_FILL,
					"both mode plates share the dock width"
				)
				assert_false(button.pressed.get_connections().is_empty(), "the mode plate is wired")
	# 3) Weapon mode: sockets + install / buy only, no category grid, no craft tab.
	screen.set_weapon_mode()
	assert_true(bool(screen.call("is_weapon_mode")), "set_weapon_mode enters the dedicated weapon dock")
	assert_eq(String(screen.get("_category")), "weapons", "weapon mode is the compatible weapons category")
	assert_eq(String(shell._shipyard_category), "weapons", "the shell stores the weapon dock mode")
	assert_true(
		_node_named(shell._root_box, "CategoryPicker") == null,
		"weapon mode hides the regular category grid"
	)
	var weapon_labels := _label_texts(shell._root_box)
	assert_contains(weapon_labels, shell._tr("ui.label.weapon_sockets", "武器槽位"), "weapon mode lists the hull mounts")
	assert_contains(weapon_labels, shell._tr("ui.hint.weapon_refit_mode", ""), "weapon mode explains the split")
	assert_not_null(_button_with_text(shell._root_box, shell._tr("ui.tab.install", "装配")), "weapon mode keeps the install tab")
	assert_not_null(_button_with_text(shell._root_box, shell._tr("ui.tab.buy", "购买")), "weapon mode keeps the buy tab")
	assert_true(
		_button_with_text(shell._root_box, shell._tr("ui.tab.craft", "打造")) == null,
		"weapon mode does not offer the module craft tab"
	)
	# Craft is rejected while in weapon mode instead of rendering an empty panel.
	screen.set_tab("craft")
	assert_ne(String(screen.get("_tab")), "craft", "a module-only tab cannot be selected in weapon mode")
	screen.set_tab("buy")
	assert_contains(_label_texts(shell._root_box), "购买并安装", "the weapon buy tab still lists purchase actions")
	# 4) Returning to module mode restores the last regular category.
	screen.set_category("cargo")
	assert_false(bool(screen.call("is_weapon_mode")), "choosing a regular category leaves weapon mode")
	screen.set_weapon_mode()
	screen.set_module_mode()
	assert_eq(String(screen.get("_category")), "cargo", "module mode returns to the last regular category")
	assert_not_null(_node_named(shell._root_box, "CategoryPicker"), "returning restores the category grid")
	_unmount(bundle)


## 新版改装页：左侧蓝图 / 中间 3D 窗口 / 右侧操作坞，舰船整体数据进坞，
## 购买与打造是独立页签，且不再出现测试向文案（改装蓝图 / 蓝图线稿 / 贴图剖面）。
func test_refit_page_shows_ship_data_and_separate_operation_tabs() -> void:
	var bundle := _mount(5212)
	var shell: Control = bundle["shell"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	var refit_button: Variant = screen.get("_refit_button")
	if refit_button is Button:
		(refit_button as Button).emit_signal("pressed")
	var body: Variant = screen.get("_body")
	assert_not_null(body, "the refit page owns a body row")
	if body != null:
		assert_eq((body as Control).get_child_count(), 3, "the refit page is blueprint / 3D window / dock")
		assert_not_null(_node_named(body, "StageWindow"), "the middle column keeps an open window onto the 3D scene")
		assert_not_null(_node_named(body, "RefitDock"), "the right column is the operations dock")
	var labels := _label_texts(shell._root_box)
	for key in ["ui.label.stage_blueprint", "ui.tag.blueprint_lineart", "ui.tag.section_texture", "ui.shipyard.detail"]:
		var text := String(shell._tr(key, ""))
		assert_false(text.is_empty(), "%s stays localized for the regression scan" % key)
		assert_false(labels.has(text), "the refit page no longer shows the test label '%s'" % text)
	for key in ["ui.label.ship_stats", "ui.label.weight_short", "ui.label.durability_short"]:
		assert_contains(labels, shell._tr(key, ""), "the dock shows the ship data field %s" % key)
	for tab_key in ["ui.tab.install", "ui.tab.buy", "ui.tab.craft"]:
		assert_not_null(_button_with_text(shell._root_box, shell._tr(tab_key, "")), "the dock offers the %s tab" % tab_key)
	assert_eq(String(screen.get("_tab")), "install", "the dock opens on the install tab")
	assert_contains(labels, shell._tr("ui.label.category_tabs", "部件分类"), "the dock keeps the category picker")
	_unmount(bundle)


func _node_named(root: Node, node_name: String) -> Node:
	for child in root.get_children():
		if String(child.name) == node_name:
			return child
		var found := _node_named(child, node_name)
		if found != null:
			return found
	return null


func test_weapon_sockets_project_blueprint_positions_into_stage_frames() -> void:
	var bundle := _mount(5209)
	var context: AppContext = bundle["context"]
	var view: Dictionary = context.queries.execute(&"shipyard.view")["data"]
	var sockets: Array = view["ship"]["weapon_sockets"]
	assert_false(sockets.is_empty(), "the fixture hull exposes weapon sockets")
	for socket in sockets:
		assert_true(socket is Dictionary, "every weapon socket row is a dictionary")
		if not (socket is Dictionary):
			continue
		var blueprint: Variant = socket.get("blueprint", null)
		assert_true(blueprint is Dictionary, "%s projects its blueprint position" % String(socket.get("socket", "")))
		if blueprint is Dictionary:
			for blueprint_view in ["side", "top"]:
				var point: Variant = blueprint.get(blueprint_view, null)
				assert_true(point is Array and point.size() == 2, "%s has a %s Vector2" % [String(socket.get("socket", "")), blueprint_view])
				if point is Array and point.size() == 2:
					assert_true(float(point[0]) >= 0.0 and float(point[0]) <= 1.0, "%s x is normalized" % blueprint_view)
					assert_true(float(point[1]) >= 0.0 and float(point[1]) <= 1.0, "%s y is normalized" % blueprint_view)
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	screen.set_category("weapons")
	var stage: Control = screen.get("_stage")
	assert_true(bool(stage.has_blueprint_views()), "the core hull binds per-view line art")
	var side_texture_size: Vector2 = stage.blueprint_texture_size("side")
	var top_texture_size: Vector2 = stage.blueprint_texture_size("top")
	assert_true(side_texture_size.x > 0.0 and side_texture_size.y > 0.0, "the side line art loaded: %s" % str(side_texture_size))
	assert_true(top_texture_size.x > 0.0 and top_texture_size.y > 0.0, "the top line art loaded: %s" % str(top_texture_size))
	var side_region: Rect2 = stage.blueprint_view_rect("side")
	var top_region: Rect2 = stage.blueprint_view_rect("top")
	assert_true(side_region.size.x > 0.0 and side_region.size.y > 0.0, "the side view has an on-screen rect")
	# P2b（2026-10-28）：改装蓝图只绘制侧视图，可用高度全部给 side、底部槽位 dock
	# 取消；`blueprint_view_rect("top")` / `blueprint_socket_rects("top")` 仍按旧的
	# 双视图公式返回可计算矩形（内容坐标校验兼容），但 top 上不再生成武器贴片。
	assert_true(top_region.size.x > 0.0 and top_region.size.y > 0.0, "the top view keeps a computable legacy rect")
	assert_false(
		stage.call("weapon_target", String(sockets[0].get("socket", "")), "top") != null,
		"the side-only blueprint no longer carries weapon patches on the top view"
	)
	assert_true(
		float(stage.call("slot_dock_height")) > 0.0,
		"the side-only blueprint reserves a bottom call-out band for the slot boxes"
	)
	assert_true(
		side_region.end.y <= float((stage.call("chip_band_rect") as Rect2).position.y) + 0.5,
		"the line art stays above the call-out band"
	)
	var side_rects: Dictionary = stage.blueprint_socket_rects("side")
	var top_rects: Dictionary = stage.blueprint_socket_rects("top")
	assert_eq(side_rects.size(), sockets.size(), "side blueprint draws one frame per hull weapon socket")
	assert_eq(top_rects.size(), sockets.size(), "top blueprint resolves the same authored sockets")
	for rect in side_rects.values():
		assert_true(side_region.encloses(rect), "every side socket frame stays inside the side view rect")
	for rect in top_rects.values():
		assert_true(top_region.encloses(rect), "every top socket frame stays inside the top view rect")
	var first: Dictionary = sockets[0]
	var first_blueprint: Dictionary = first.get("blueprint", {})
	var first_side: Array = first_blueprint.get("side", [])
	if first_side.size() == 2:
		var expected_center: Vector2 = side_region.position + Vector2(
			float(first_side[0]) * side_region.size.x,
			float(first_side[1]) * side_region.size.y
		)
		var frame: Rect2 = side_rects[String(first.get("socket", ""))]
		assert_true(frame.get_center().distance_to(expected_center) < 0.5,
			"socket frames map through the line-art rect")
	assert_eq(stage.get("_highlighted_slot_ids").size(), sockets.size(), "opening the weapons category highlights every socket frame")
	_unmount(bundle)


## 玩家反馈（2026-10-27）：武器装配后要知道装在哪；右侧不能显示后端 socket ID；
## 左侧贴片的数据要随装配变化；仓库武器要能拖到炮位上安装。
func test_weapon_sockets_show_player_mount_names_and_drag_install() -> void:
	var bundle := _mount(5310)
	var context: AppContext = bundle["context"]
	var shell: Control = bundle["shell"]
	var fixture := _weapon_install_fixture(context)
	assert_false(fixture.is_empty(), "the fixture finds a warehouse weapon that fits an empty hull mount")
	if fixture.is_empty():
		_unmount(bundle)
		return
	var socket: Dictionary = fixture["socket"]
	var socket_name := String(socket.get("socket", ""))
	var socket_class := String(socket.get("socket_class", ""))
	var weapon_id := String(fixture["weapon_id"])
	var weapon_name := String(shell._tr(String(fixture["name_key"]), weapon_id))
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	screen.set_category("weapons")
	var expected_title := String(screen.call("_weapon_socket_title", socket))
	var labels := _label_texts(shell._root_box)
	assert_contains(labels, expected_title, "the socket card shows a player-facing mount name")
	assert_false(String("\n".join(labels)).contains("SN_Socket_Weapon_"), "backend socket ids are not player-facing")
	assert_true(String("\n".join(labels)).contains(weapon_name), "the warehouse weapon row shows the localized weapon name")
	assert_contains(expected_title, shell._tr("ui.weapon_socket." + ("starboard" if socket_name.to_lower().contains("starboard") else "port" if socket_name.to_lower().contains("port") else "bow" if socket_name.to_lower().contains("bow") else "stern"), ""),
		"the mount name names the hull side")
	assert_contains(expected_title, shell._tr("ui.weapon_class." + socket_class.to_lower(), ""), "the mount name names the weapon class")
	assert_false(expected_title.contains("SN_Socket_Weapon_"), "the friendly mount name does not leak the backend id")
	# Empty mount card before the install.
	var empty_text := String(shell._tr("ui.label.slot_empty", "空槽位"))
	var target_card: Variant = _weapon_socket_card(shell._root_box, socket_name)
	assert_not_null(target_card, "the mount has a socket card")
	if target_card == null:
		_unmount(bundle)
		return
	assert_eq(String(target_card.call("weapon_text")), empty_text, "the empty socket card shows the empty state")
	# Warehouse weapon row is a real drag source with the weapon payload contract.
	var weapon_row: Variant = _weapon_row_for(shell._root_box, weapon_id)
	assert_not_null(weapon_row, "the warehouse weapon is listed as a draggable row")
	if weapon_row == null:
		_unmount(bundle)
		return
	assert_true(bool(weapon_row.get("draggable")), "the warehouse weapon row is draggable")
	var payload := weapon_row.call("drag_payload") as Dictionary
	assert_eq(String(payload.get("kind", "")), "ship_weapon", "the drag payload uses the weapon kind")
	assert_eq(String(payload.get("weapon_class", "")), socket_class, "the payload carries the weapon class for the socket gate")
	var mismatch := payload.duplicate(true)
	mismatch["weapon_class"] = "NoSuchClass"
	assert_false(bool(target_card.call("_can_drop_data", Vector2.ZERO, mismatch)),
		"a mismatched weapon class cannot be dropped on the mount")
	assert_true(bool(target_card.call("_can_drop_data", Vector2.ZERO, payload)),
		"a compatible weapon is accepted by the mount card")
	# Blueprint patches: readable per-mount cards (two lines), non-overlapping even
	# when two sockets share one authored blueprint anchor (Port/Starboard).
	var stage: Variant = screen.get("_stage")
	var blueprint_target: Variant = stage.call("weapon_target", socket_name, "side")
	assert_not_null(blueprint_target, "the blueprint exposes a weapon patch for the mount")
	var short_label := String(screen.call("_weapon_socket_short_label", socket_name))
	var display_rects: Dictionary = stage.call("weapon_socket_display_rects", "side")
	var sockets_count := int(Array(screen.call("_enriched_weapon_sockets")).size())
	assert_eq(display_rects.size(), sockets_count, "the blueprint draws one patch per weapon socket")
	# P2b：侧视单视图后每枚 socket 只有一枚 side 贴片（top 系列 API 仍可计算）。
	assert_eq(stage.call("weapon_targets").size(), sockets_count, "the side-only blueprint carries one weapon patch per socket")
	assert_true(stage.call("weapon_target", socket_name, "top") == null, "the top view carries no weapon patch")
	var side_region: Rect2 = stage.call("blueprint_view_rect", "side")
	var band: Rect2 = stage.call("chip_band_rect")
	var placed_rects: Array = display_rects.values()
	for index in placed_rects.size():
		assert_true(band.encloses(placed_rects[index]), "every weapon patch sits inside the call-out band")
		assert_false((placed_rects[index] as Rect2).intersects(side_region),
			"the weapon patches no longer sit on the ship drawing")
		for other_index in range(index + 1, placed_rects.size()):
			assert_false((placed_rects[index] as Rect2).intersects(placed_rects[other_index] as Rect2),
				"weapon patches stay disjoint instead of overlapping")
	if blueprint_target != null:
		assert_false(bool(blueprint_target.call("accepts_payload", mismatch)),
			"a mismatched weapon class cannot be dropped on the blueprint patch")
		assert_true(bool(blueprint_target.call("accepts_payload", payload)),
			"a compatible weapon is accepted by the blueprint patch")
		assert_eq(String(blueprint_target.call("slot_label")), short_label, "the patch paints the short mount label")
		assert_false(bool(blueprint_target.call("is_occupied")), "the patch starts empty")
		assert_eq(String(blueprint_target.call("display_text")), empty_text, "the empty patch paints the empty state")
	# Real drop through the blueprint patch -> install command -> ship loadout.
	var captured: Array = []
	screen.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
		captured.append({"command": String(command), "params": params.duplicate(true)})
	)
	if blueprint_target != null:
		blueprint_target.call("_drop_data", Vector2.ZERO, payload)
	else:
		target_card.call("_drop_data", Vector2.ZERO, payload)
	assert_eq(captured.size(), 1, "the drop publishes one install command")
	if captured.size() == 1:
		assert_eq(String(captured[0]["command"]), "ship.install_weapon", "dropping a weapon requests ship.install_weapon")
		var params: Dictionary = captured[0]["params"]
		assert_eq(String(params.get("socket", "")), socket_name, "the drop names the mount socket")
		assert_eq(String(params.get("weapon_id", "")), weapon_id, "the drop forwards the weapon id")
		assert_eq(String(params.get("source", "")), "warehouse", "the drop installs from the warehouse")
	var installed := false
	for row in Array(context.state.ship().get("weapon_loadout", [])):
		if row is Dictionary and String(row.get("socket", "")) == socket_name and String(row.get("weapon_id", "")) == weapon_id:
			installed = true
	assert_true(installed, "the weapon is written to the ship loadout")
	# Rebuilt page: dock + blueprint model now say where the weapon is mounted.
	screen = _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	screen.set_category("weapons")
	var rebuilt_card: Variant = _weapon_socket_card(shell._root_box, socket_name)
	assert_not_null(rebuilt_card, "the rebuilt page keeps the mount card")
	if rebuilt_card != null:
		assert_eq(String(rebuilt_card.call("weapon_text")), weapon_name,
			"the mount card shows the mounted weapon name after install")
	var rebuilt_stage: Variant = screen.get("_stage")
	var model: Dictionary = rebuilt_stage.get("_model")
	var stage_socket := {}
	for raw_socket in model.get("weapon_sockets", []):
		if raw_socket is Dictionary and String((raw_socket as Dictionary).get("socket", "")) == socket_name:
			stage_socket = raw_socket
	assert_false(stage_socket.is_empty(), "the stage model contains the mount")
	if not stage_socket.is_empty():
		assert_true(bool(stage_socket.get("occupied", false)), "the blueprint mount data flips to occupied after install")
		assert_eq(String(stage_socket.get("display_name", "")), weapon_name, "the blueprint mount paints the localized weapon name")
		assert_eq(String(stage_socket.get("slot_title", "")), expected_title, "the blueprint mount keeps its player-facing name")
	# The rebuilt patch itself flips to occupied and paints the weapon name: this is
	# what the player reads to know where the weapon went.
	var rebuilt_target: Variant = rebuilt_stage.call("weapon_target", socket_name, "side")
	assert_not_null(rebuilt_target, "the rebuilt blueprint keeps the weapon patch")
	if rebuilt_target != null:
		assert_true(bool(rebuilt_target.call("is_occupied")), "the blueprint patch flips to occupied after install")
		assert_eq(String(rebuilt_target.call("display_text")), weapon_name, "the blueprint patch paints the mounted weapon name")
		assert_eq(String(rebuilt_target.call("slot_label")), short_label, "the blueprint patch keeps its mount label")
	var rebuilt_labels := _label_texts(shell._root_box)
	assert_false(String("\n".join(rebuilt_labels)).contains("SN_Socket_Weapon_"), "the rebuilt dock still hides backend socket ids")
	assert_true(String("\n".join(rebuilt_labels)).contains(weapon_name), "the rebuilt dock shows the installed weapon name")
	_unmount(bundle)


func _weapon_socket_card(root: Node, socket_name: String) -> Control:
	for node in _nodes_with_script(root, WEAPON_SOCKET_CARD_SCRIPT):
		var row: Dictionary = node.get("socket")
		if String(row.get("socket", "")) == socket_name:
			return node
	return null


func _weapon_row_for(root: Node, weapon_id: String) -> Control:
	for node in _nodes_with_script(root, WEAPON_ROW_SCRIPT):
		var payload: Dictionary = node.get("payload")
		if String(payload.get("weapon_id", "")) == weapon_id:
			return node
	return null


## Free hull weight and pick a registered weapon that a hull mount accepts. Returns
## `{socket, weapon_id, weapon_class, name_key}` or `{}` when no fixture fits.
func _weapon_install_fixture(context: AppContext) -> Dictionary:
	var hub: RegistryHub = context.registries
	var state: GameState = context.state
	var port_id := String(state.current_port_id())
	for module_id in Array(state.ship().get("cargo_modules", [])).duplicate():
		context.commands.execute(&"ship.uninstall_module", {"module_id": String(module_id)})
	var safety_id := String(state.ship().get("safety_module_id", ""))
	if not safety_id.is_empty():
		context.commands.execute(&"ship.uninstall_module", {"module_id": safety_id})
	for raw_socket in WeaponOps.sockets(hub, state.ship()):
		if not (raw_socket is Dictionary):
			continue
		var socket: Dictionary = raw_socket
		var socket_name := String(socket.get("name", socket.get("socket", "")))
		if socket_name.is_empty():
			continue
		for weapon in WeaponOps.all(hub):
			if not WeaponOps.accepts(socket, weapon):
				continue
			var weight := float(weapon.data.get("weight", 0.0))
			if ShipOps.total_weight(hub, state) + weight > ShipOps.max_weight(hub, state.ship()) + 0.0001:
				continue
			WarehouseOps.add_weapon(state, port_id, String(weapon.id), 1)
			var blockers := WeaponOps.install_blockers(hub, state, String(weapon.id), socket_name, "warehouse")
			if blockers.is_empty():
				return {
					"socket": {
						"socket": socket_name,
						"socket_class": String(socket.get("socket_class", "")),
						"socket_index": int(socket.get("socket_index", 0)),
						"weapon_id": "",
					},
					"weapon_id": String(weapon.id),
					"weapon_class": WeaponOps.weapon_class(weapon),
					"name_key": String(weapon.name_key),
				}
			WarehouseOps.remove_weapon(state, port_id, String(weapon.id), 1)
	return {}


func test_shipyard_page_has_no_legacy_lower_panels() -> void:
	var bundle := _mount(5207)
	var shell: Control = bundle["shell"]
	var screen := _shipyard(bundle)
	if screen == null:
		_unmount(bundle)
		return
	# Requirement 1: the old full-width lower panels are gone in every mode.
	_assert_no_legacy_sections(shell)
	screen.set_category("hulls")
	_assert_no_legacy_sections(shell)
	screen.set_category("misc")
	_assert_no_legacy_sections(shell)
	# The page is three columns plus the heading/summary rows, not a long stack.
	var body: Variant = screen.get("_body")
	assert_not_null(body, "the shipyard page owns a single body row")
	assert_eq(body.get_child_count(), 3, "the page lays out exactly three columns")
	_unmount(bundle)
