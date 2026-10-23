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
	screen._on_slot_drop({"kind": "ship_parts", "part": part}, nav_slot)
	assert_eq(String(captured.get("command", "")), "ship.install_module", "dropping a part requests ship.install_module")
	var params: Dictionary = captured.get("params", {})
	assert_eq(String(params.get("module_id", "")), module_id, "the dragged module id is forwarded")
	assert_eq(String(params.get("source", "")), "warehouse", "the drag source becomes the install source")
	if not String(nav_slot.get("replace_module_id", "")).is_empty():
		assert_eq(String(params.get("replace_module_id", "")), String(nav_slot["replace_module_id"]), "a filled slot replaces its current module")
	assert_eq(String(context.state.ship().get("navigation_module_id", "")), module_id, "the drag installs the module on the ship")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, module_id), 0, "the installed module leaves the warehouse")
	_unmount(bundle)


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
	assert_contains(labels, "武器槽位", "the weapons category lists hull sockets")
	var first_socket := String(view["ship"]["weapon_sockets"][0]["socket"])
	var socket_visible := false
	for label_text in labels:
		if String(label_text).contains(first_socket):
			socket_visible = true
			break
	assert_true(socket_visible, "the first real hull socket is visible")
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
	assert_true(top_region.size.x > 0.0 and top_region.size.y > 0.0, "the top view has an on-screen rect")
	assert_true(top_region.position.y >= side_region.position.y + side_region.size.y, "the top view is stacked below the side view")
	assert_true(absf(side_region.size.x - top_region.size.x) < 0.5, "both views share the same width for x alignment")
	assert_true(absf(side_region.position.x - top_region.position.x) < 0.5, "both views share the same left edge for x alignment")
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
