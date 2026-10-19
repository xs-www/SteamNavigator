extends TestCase
## Refit UI contract: the centre stage exposes a swappable 2.5D renderer, the
## cutaway lists one chip per slot, and dragging an owned free module onto a
## matching chip maps to `ship.install_module` with the replaced module.
##
## The shell scene is mounted for real (same fixture as test_ui_shell) so a
## wiring mistake in main.gd or the shipyard screen fails here.

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const SHIPYARD_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/shipyard_screen.gd")
const SHIP_VIEW_SCRIPT := preload("res://framework/ui/components/sn_ship_view.gd")
const SLOT_TARGET_SCRIPT := preload("res://framework/ui/components/sn_slot_target.gd")
const PART_ROW_SCRIPT := preload("res://framework/ui/components/sn_part_row.gd")
const STEADY_BUILD := "core:starting_build/steady"
const MODE_EXTERIOR := 0
const MODE_CUTAWAY := 1


func _mount(seed_value: int) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {
		"build_id": STEADY_BUILD,
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


func _node_with_script(root: Node, script: Script) -> Control:
	for child in root.get_children():
		if child.get_script() == script:
			return child
		var found := _node_with_script(child, script)
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


func _shipyard(bundle: Dictionary) -> Dictionary:
	var shell: Control = bundle["shell"]
	_goto(shell, "shipyard")
	var screen := _node_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	assert_not_null(screen, "the shell hosts the shipyard refit screen")
	return {"shell": shell, "screen": screen}


func test_refit_cutaway_lists_every_slot_and_switches_mode() -> void:
	var bundle := _mount(5201)
	var yard := _shipyard(bundle)
	var shell: Control = yard["shell"]
	var screen: Control = yard["screen"]
	var context: AppContext = bundle["context"]
	var stage: Control = screen._stage
	assert_not_null(stage, "the refit screen mounts the ship stage")
	assert_eq(int(stage.mode), MODE_EXTERIOR, "the ship starts in exterior view")
	var ship: Dictionary = context.queries.execute(&"shipyard.view")["data"]["ship"]
	var expected_slots := 4 + int(ship["cargo_slots"])
	if int(ship["cabin_slots"]) > 0:
		expected_slots += 1
	assert_eq(screen._slots.size(), expected_slots, "one slot per hull, boiler, navigation, safety, cargo and cabin position")
	assert_eq(stage._slot_targets.size(), expected_slots, "the cutaway instantiates one drop target per slot")
	for target in stage._slot_targets:
		assert_false(target.visible, "slot chips stay hidden until refit mode is on")
	# Refit button enters the cutaway.
	var toggle := _button_by_text(shell._root_box, shell._tr("ui.label.refit", ""))
	assert_not_null(toggle, "the refit mode has a toggle button")
	toggle.emit_signal("pressed")
	assert_true(bool(screen._refit), "pressing refit enters refit mode")
	assert_eq(int(stage.mode), MODE_CUTAWAY, "refit mode shows the longitudinal cutaway")
	var visible_chips := 0
	for target in stage._slot_targets:
		if target.visible:
			visible_chips += 1
	assert_eq(visible_chips, expected_slots, "every slot chip is visible on the cutaway")
	# The mode survives a shell refresh after a command.
	assert_true(bool(shell._shipyard_refit), "the shell remembers refit mode for the next rebuild")
	_goto(shell, "shipyard")
	var rebuilt := _node_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	assert_true(bool(rebuilt._refit), "the rebuilt shipyard re-enters refit mode")
	assert_eq(int(rebuilt._stage.mode), MODE_CUTAWAY, "the rebuilt stage is already a cutaway")
	_unmount(bundle)


func test_renderer_slot_is_swappable_for_the_future_2_5d_scene() -> void:
	var bundle := _mount(5202)
	var yard := _shipyard(bundle)
	var stage: Control = yard["screen"]._stage
	assert_true(stage.has_method("set_renderer"), "the stage exposes the 2.5D renderer hook")
	assert_false(bool(stage.has_renderer()), "the placeholder renderer is active by default")
	var provider := Control.new()
	provider.name = "FutureStage"
	stage.set_renderer(provider)
	assert_true(bool(stage.has_renderer()), "a provider node replaces the placeholder")
	assert_eq(provider.get_parent(), stage, "the provider is mounted under the stage")
	assert_eq(stage.mode, MODE_EXTERIOR, "the stage keeps driving mode through the interface")
	stage.set_mode(MODE_CUTAWAY)
	stage.set_renderer(null)
	assert_false(bool(stage.has_renderer()), "passing null restores the placeholder renderer")
	_unmount(bundle)


func test_dragging_a_warehouse_module_maps_to_install_command() -> void:
	var bundle := _mount(5203)
	var context: AppContext = bundle["context"]
	var port_id := String(context.state.current_port_id())
	# Put an owned navigation module in the current port warehouse so the HUD has
	# a free part to drag.
	var candidate := {}
	for row in context.queries.execute(&"shipyard.view")["data"]["candidates"]:
		if row is Dictionary and String(row["content_type"]) == "navigation_modules" and bool(row["can_install"]):
			candidate = row
	assert_true(not candidate.is_empty(), "the fixture offers a navigation module to own")
	var module_id := String(candidate["module_id"])
	WarehouseOps.add_module(context.state, port_id, module_id, 1)
	var yard := _shipyard(bundle)
	var screen: Control = yard["screen"]
	var nav_slot := {}
	for slot in screen._slots:
		if slot is Dictionary and String(slot.get("content_type", "")) == "navigation_modules":
			nav_slot = slot
	assert_true(not nav_slot.is_empty(), "the cutaway has a navigation slot")
	var nav_target := _slot_target_for(screen._stage, "navigation_modules")
	assert_not_null(nav_target, "the navigation slot has a drop target")
	var part := {
		"module_id": module_id,
		"name": "Fixture compass",
		"content_type": "navigation_modules",
		"source": "warehouse",
		"can_install": true,
	}
	var cargo_part := part.duplicate(true)
	cargo_part["content_type"] = "cargo_modules"
	assert_true(bool(nav_target._accepts(part)), "an owned free module of the slot's type is accepted")
	assert_false(bool(nav_target._accepts(cargo_part)), "a module for another slot type is rejected")
	var purchase_part := part.duplicate(true)
	purchase_part["source"] = "purchase"
	assert_false(bool(nav_target._accepts(purchase_part)), "purchase candidates are not drag sources")
	var captured := {}
	screen.command_requested.connect(func(command: StringName, params: Dictionary):
		captured["command"] = command
		captured["params"] = params
	)
	# The HUD renders a draggable row for the owned warehouse module.
	var draggable: Array = []
	for row in _nodes_with_script(screen, PART_ROW_SCRIPT):
		if bool(row.draggable):
			draggable.append(row)
	assert_eq(draggable.size(), 1, "the HUD lists the owned free module as a draggable row")
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


func _slot_target_for(stage: Control, content_type: String) -> Control:
	for target in stage._slot_targets:
		if target.get_script() == SLOT_TARGET_SCRIPT and String(target.slot.get("content_type", "")) == content_type:
			return target
	return null


func _nodes_with_script(root: Node, script: Script, out: Array = []) -> Array:
	for child in root.get_children():
		if child.get_script() == script:
			out.append(child)
		_nodes_with_script(child, script, out)
	return out
