extends TestCase
## Nautical chart phase 3 — the voyage presentation as wired into the shell.
##
## These tests drive the real shell (`main.tscn`) and the real commands, so they
## cover the hand-over points the pure model cannot: what page is mounted, when
## navigation disappears, and that the settlement screen is what the player ends
## on. Frame stepping is manual (`shell._process(dt)`), which keeps the演出
## deterministic in a headless run.

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const EVENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/event_screen.gd")
const STEADY_BUILD := "core:starting_build/steady"
const STANDARD_STRATEGY := "core:strategy/standard"
const STEP_SECONDS := 0.1
## Upper bound on simulated seconds per phase; a stuck演出 fails here instead of
## hanging the suite.
const MAX_DRIVE_SECONDS := 60.0


func test_voyage_start_sails_out_in_3d_then_crosses_into_the_chart() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var origin := String(context.state.current_port_id())
	var destination := _start_voyage(shell, context)

	assert_not_null(shell._presentation, "voyage.start hands over to the presentation")
	assert_eq(String(shell._presentation.phase_name()), "departure_3d",
		"the harbour is shown in 3D while the ship sails out, before any clouds")
	assert_false(shell._sea_chart_available(), "the chart hotkey is disabled while the演出 runs")
	assert_true(_find_at_sea(shell) == null, "the chart page is not mounted during the 3D cut")
	assert_not_null(_find_stage(shell), "the 3D harbour stage is mounted for the departure cut")
	assert_eq(String(_find_stage(shell).voyage_mode()), "depart",
		"the stage is playing the departure beat")

	# The hull is really sailing out: it moves away from the berth while the
	# camera climbs, and it is nowhere near the chart yet.
	var stage_before := _find_stage(shell).ship_position()
	var camera_before := _find_stage(shell).camera_position()
	_drive_seconds(shell, 0.9)
	var stage_mid := _find_stage(shell).ship_position()
	assert_true(stage_mid.z > stage_before.z, "the hull gains sea room during the beat")
	assert_true(_find_stage(shell).camera_position().y > camera_before.y,
		"the camera climbs away from the quay")

	# Once the beat ends the clouds cover the high shot and the chart takes over.
	var veil: SNCloudVeil = shell._cloud_veil
	assert_not_null(veil, "the cloud veil is created for the departure")
	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 8.0),
		"the presentation mounts the chart page after the departure veil")
	var at_sea = _find_at_sea(shell)
	assert_not_null(at_sea.get_chart(), "the at-sea page carries a real chart view")
	assert_true(String(destination) != "", "the fixture has a destination")

	assert_true(_drive_until(shell, func() -> bool: return veil.cover <= 0.001, 4.0),
		"the clouds clear once the chart is in place")
	assert_eq(String(shell._presentation.phase_name()), "at_sea", "the演出 is now sailing")
	assert_true(origin != "", "the run started in a harbour")


## The design rule for the cut: where the 3D hull disappears must be where the
## chart's ship marker appears. The 3D side is `PortStage.SEA_HANDOFF` (the hull is
## exactly there when the departure beat ends); the chart side is the harbour
## marker the route starts at — the same port, so the two views agree.
func test_chart_ship_starts_where_the_stage_ship_vanished() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var origin := String(context.state.current_port_id())
	_start_voyage(shell, context)

	# Let the 3D beat finish; the shell hands the screen to the chart right after.
	var stage = _find_stage(shell)
	assert_not_null(stage, "the departure cut has a 3D stage")
	assert_true(_drive_until(shell, func() -> bool:
		return String(shell._presentation.phase_name()) == "departure_veil", 8.0),
		"the 3D beat ends before the clouds close")
	assert_true(stage.ship_position().is_equal_approx(PortStage.SEA_HANDOFF),
		"the hull is exactly at the sea handoff when it disappears: %s" % str(stage.ship_position()))
	assert_false(stage.is_voyage_transitioning(), "the beat finished, the hull is not mid-animation")

	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 8.0),
		"the chart takes over")
	var at_sea = _find_at_sea(shell)
	var chart_vm: Dictionary = at_sea.get_chart().view_model
	var origin_position := Vector2.ZERO
	for entry in chart_vm.get("ports", []):
		if String((entry as Dictionary).get("id", "")) == origin:
			origin_position = Vector2(
				float((entry as Dictionary).get("x", 0.0)),
				float((entry as Dictionary).get("y", 0.0))
			)
	assert_false(origin_position.is_equal_approx(Vector2.ZERO),
		"the departure harbour is on the chart")
	assert_true(at_sea.get_ship_world_position().is_equal_approx(origin_position),
		"the chart marker starts exactly on the harbour the 3D hull left (%s vs %s)" % [
			str(at_sea.get_ship_world_position()), str(origin_position),
		])


func test_at_sea_ship_advances_along_the_route() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_start_voyage(shell, context)
	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 6.0),
		"the chart page mounts")
	var at_sea = _find_at_sea(shell)
	# Let the veil finish clearing so the clock starts.
	_drive_until(shell, func() -> bool: return shell._presentation.veil <= 0.001, 4.0)
	var first_position: Vector2 = at_sea.get_ship_world_position()
	var first_progress: float = at_sea.get_progress()
	_drive_seconds(shell, 1.0)
	assert_true(at_sea.get_progress() > first_progress, "the voyage strip advances")
	assert_false(at_sea.get_ship_world_position().is_equal_approx(first_position),
		"the ship icon moves along the route instead of sitting at the origin")
	assert_true(at_sea.get_chart().has_ship_position(), "the chart receives the animated ship position")


func test_voyage_ends_on_the_settlement_screen_and_clears_the_presentation() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_start_voyage(shell, context)
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the演出 finishes on its own")
	assert_eq(String(shell._active_screen), "settlement", "arrival lands on the settlement screen")
	assert_false(shell._settlement_summary.is_empty(), "the settlement screen has the voyage summary")
	assert_true(shell._cloud_veil == null or shell._cloud_veil.cover <= 0.001,
		"the veil is clear again after arrival")
	assert_true(shell._sea_chart_available(), "navigation comes back once the voyage is over")


func test_skip_finishes_the_voyage_early() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_start_voyage(shell, context)
	_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 6.0)
	_drive_until(shell, func() -> bool: return shell._presentation.veil <= 0.001, 4.0)
	# How much of the route still lay ahead when the player skipped.
	var progress_at_skip: float = shell._presentation.progress
	assert_true(progress_at_skip < 0.9, "the fixture skips before the voyage is nearly over")
	shell._on_skip_presentation()
	var frames := 0
	while shell._presentation != null and frames < 200:
		shell._process(STEP_SECONDS)
		frames += 1
	assert_true(shell._presentation == null, "skipping still reaches the end of the演出")
	assert_eq(String(shell._active_screen), "settlement", "a skipped voyage still settles")
	# Skipping jumps the progress to the arrival veil instead of playing the rest.
	assert_true(frames * STEP_SECONDS < 6.0,
		"skipping must not take the full remaining voyage time (%d frames)" % frames)


func test_event_decision_pauses_then_resumes_the_voyage() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var destination := _first_destination(context)
	var event := _force_event_context(context, destination)
	if event.is_empty():
		# The core content must always be able to offer a risk event; if this ever
		# stops being true the assertion explains why instead of silently skipping.
		assert_true(false, "core events should be samplable for a measurable risk")
		return
	shell._run_command(&"voyage.start", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})
	assert_not_null(shell._presentation, "the演出 starts even when an event is pending")
	assert_true(shell._presentation.has_event, "the presentation knows an event is coming")

	assert_true(_drive_until(shell, func() -> bool: return String(shell._presentation.phase_name()) == "event_wait", MAX_DRIVE_SECONDS),
		"the演出 stops at the event point")
	var progress_at_event: float = shell._presentation.progress
	assert_true(progress_at_event > 0.0 and progress_at_event < 1.0,
		"the ship stops partway, not at the origin or the destination")
	assert_eq(_nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT).size(), 1,
		"the event choice screen is what the player sees")
	assert_true(_find_at_sea(shell) == null, "the chart page is gone while the decision is open")
	assert_eq(shell._presentation.skip(), VoyagePresentation.Step.NONE,
		"skip cannot decide for the player")

	var option_ids: Array = event.get("option_ids", [])
	assert_true(option_ids.size() > 0, "the event offers at least one option")
	shell._run_command(&"event.choose_option", {"option_id": String(option_ids[0])})
	if shell._presentation == null:
		# A `fail_voyage` option restores the pre-voyage snapshot: the演出 is
		# dropped and the player is back in port instead of a settlement screen.
		assert_eq(String(shell._active_screen), "overview", "a failed voyage returns to port")
		return
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the remaining leg plays out after the decision")
	assert_eq(String(shell._active_screen), "settlement", "the voyage settles after the event")
	assert_true(shell._settlement_summary.has("destination"),
		"the settlement summary belongs to the voyage that was sailed")


func _mount(seed_value: int) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": seed_value})
	assert_true(bool(started.get("ok", false)), "run.start succeeds in the voyage fixture: %s" % str(started))
	var scene: PackedScene = load(MAIN_SCENE)
	assert_not_null(scene, "the shell scene loads")
	var shell: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shell)
	assert_true(shell.is_inside_tree(), "the shell fixture is inside the scene tree")
	return {"context": context, "shell": shell, "tree": tree}


func _first_destination(context: AppContext) -> String:
	var main_contract: Variant = context.state.contracts().get("main", null)
	if main_contract is Dictionary:
		return String((main_contract as Dictionary).get("destination", ""))
	return ""


## Fires `voyage.start` and returns the destination. Navigation to the voyage page
## is not needed: the presentation is command-driven, exactly like the shell does.
func _start_voyage(shell: Control, context: AppContext) -> String:
	var destination := _first_destination(context)
	assert_true(destination != "", "the run has a main contract destination")
	shell._run_command(&"voyage.start", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})
	return destination


## Finds a deterministic seed whose risk roll produces an event, so the event leg
## of the演出 is exercised with real domain data instead of a fabricated voyage.
func _force_event_context(context: AppContext, destination: String) -> Dictionary:
	var preview := context.commands.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	if not bool(preview.get("ok", false)):
		return {}
	var preview_data: Dictionary = preview.get("data", {})
	for seed_value in range(1, 200):
		context.rng = RngService.new(seed_value)
		var picked := VoyageService._pick_event(context, preview_data, destination)
		if picked.is_empty():
			continue
		# Keep that rng so `voyage.start` samples the same event.
		context.rng = RngService.new(seed_value)
		return picked
	return {}


func _find_at_sea(shell: Control) -> AtSeaScreen:
	return shell._at_sea_screen


## The live `PortStage` mounted by the shell (null when the 3D cut has no stage).
func _find_stage(shell: Control) -> PortStage:
	return shell._port_stage()


func _drive_seconds(shell: Control, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		shell._process(STEP_SECONDS)
		elapsed += STEP_SECONDS


func _drive_until(shell: Control, predicate: Callable, max_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < max_seconds:
		if bool(predicate.call()):
			return true
		shell._process(STEP_SECONDS)
		elapsed += STEP_SECONDS
	return bool(predicate.call())


func _nodes_with_script(root: Node, script: Script, out: Array = []) -> Array:
	for child in root.get_children():
		if child.get_script() == script:
			out.append(child)
		_nodes_with_script(child, script, out)
	return out
