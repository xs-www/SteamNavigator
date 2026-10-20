extends TestCase
## Nautical chart phase 3 — voyage presentation state machine.
##
## The演出 is deliberately a pure model (`VoyagePresentation`) so these tests can
## step it frame by frame and assert exactly when each screen hand-over happens;
## the cloud veil is a pure renderer of `veil`, so it is asserted the same way.

const DELTA := 0.05


func test_plan_compresses_voyage_into_the_playback_window() -> void:
	var model := VoyagePresentation.new()
	model.plan(12.0)
	assert_eq(String(model.phase_name()), "voyage_planned", "planning lands on VOYAGE_PLANNED")
	assert_almost_eq(model.playback_seconds, 12.0 * VoyagePresentation.SECONDS_PER_GAME_HOUR, 0.001,
		"a mid-length voyage keeps the plain compression rate")
	assert_almost_eq(model.hours_per_second(), 12.0 / model.playback_seconds, 0.001,
		"the HUD rate is hours / playback seconds")

	model.plan(1000.0)
	assert_almost_eq(model.playback_seconds, VoyagePresentation.MAX_PLAYBACK_SECONDS, 0.001,
		"very long voyages are capped so the演出 never drags")
	model.plan(0.5)
	assert_almost_eq(model.playback_seconds, VoyagePresentation.MIN_PLAYBACK_SECONDS, 0.001,
		"very short voyages keep a minimum so the演出 is visible at all")


func test_departure_beat_sails_out_before_any_clouds() -> void:
	var model := VoyagePresentation.new()
	model.plan(10.0)
	model.begin_departure()
	assert_eq(String(model.phase_name()), "departure_3d", "the 3D departure beat runs first")
	assert_almost_eq(model.veil, 0.0, 0.0001, "no clouds while the ship is still leaving")
	assert_almost_eq(model.departure_3d_seconds, PortStage.VOYAGE_BEAT_SECONDS, 0.0001,
		"the state machine and the 3D stage must share one beat length")

	var halfway := _drive(model, VoyagePresentation.DEPARTURE_3D_SECONDS * 0.5)
	assert_false(halfway.has(VoyagePresentation.Step.DEPARTED),
		"the cut does not happen before the 3D beat is over")
	assert_almost_eq(model.veil, 0.0, 0.0001, "clouds still wait for the ship to leave")

	var steps := _drive(model, VoyagePresentation.DEPARTURE_3D_SECONDS * 0.5 + 0.1)
	assert_true(steps.has(VoyagePresentation.Step.DEPARTED), "the beat hands over to the clouds")
	assert_eq(String(model.phase_name()), "departure_veil", "the veil is the next phase")


func test_departure_veil_hands_over_to_the_chart() -> void:
	var model := VoyagePresentation.new()
	model.plan(10.0)
	model.begin_departure()
	assert_almost_eq(model.veil_direction, -1.0, 0.001, "leaving port uses the ascend direction")

	var steps := _drive(model, VoyagePresentation.DEPARTURE_3D_SECONDS + 1.2)
	assert_true(steps.has(VoyagePresentation.Step.AT_SEA_STARTED),
		"the veil hands over exactly once after it is fully closed")
	assert_eq(String(model.phase_name()), "at_sea", "the hand-over lands in AT_SEA")
	_drive(model, 1.0)
	assert_almost_eq(model.veil, 0.0, 0.001, "the chart is revealed after the hand-over")
	assert_true(model.progress > 0.0, "the ship starts moving only after the clouds clear")
	# The chart icon must take over where the 3D hull vanished: at the harbour the
	# ship left, i.e. progress 0 on the route.
	assert_almost_eq(model.handoff_progress, 0.0, 0.0001, "the chart starts at the harbour marker")


func test_at_sea_progress_matches_compressed_time() -> void:
	var model := VoyagePresentation.new()
	model.plan(10.0)
	_enter_at_sea(model)
	var half := model.playback_seconds * 0.5
	_drive(model, half)
	assert_almost_eq(model.progress, 0.5, 0.08, "half the playback time is half the route")
	assert_almost_eq(model.elapsed_hours(), 5.0, 0.8, "the on-screen clock runs the voyage's own hours")
	assert_true(model.remaining_hours() > 0.0, "remaining hours stay positive mid-voyage")


func test_event_interrupts_the_voyage_and_then_resumes() -> void:
	var model := VoyagePresentation.new()
	model.plan(10.0, 0.4)
	_enter_at_sea(model)

	var steps := _drive(model, 20.0)
	assert_true(steps.has(VoyagePresentation.Step.EVENT_READY), "the event point is reached")
	assert_eq(String(model.phase_name()), "event_wait", "the演出 stops for the player's decision")
	assert_almost_eq(model.progress, 0.4, 0.001, "the ship stops exactly at the event point")
	assert_true(model.event_fired, "the event is only fired once")

	var frozen := model.progress
	_drive(model, 2.0)
	assert_almost_eq(model.progress, frozen, 0.0001, "no progress while waiting for a decision")

	model.begin_event_reveal()
	_drive(model, 1.0)
	assert_almost_eq(model.veil, 0.0, 0.001, "the event scene is revealed under clearing clouds")

	model.resolve_event()
	var resumed := _drive(model, 1.5)
	assert_true(resumed.has(VoyagePresentation.Step.AT_SEA_STARTED),
		"choosing an option hands the chart back")
	assert_eq(String(model.phase_name()), "at_sea", "the voyage continues after the decision")

	var arrival := _drive(model, 30.0)
	assert_true(arrival.has(VoyagePresentation.Step.ARRIVAL_READY), "the leg still arrives")
	assert_almost_eq(model.progress, 1.0, 0.001, "the whole route was sailed")


func test_arrival_harbor_beat_finishes_the_presentation() -> void:
	var model := VoyagePresentation.new()
	model.plan(4.0)
	_enter_at_sea(model)
	var steps := _drive_until_step(model, VoyagePresentation.Step.ARRIVAL_READY, 40.0)
	assert_true(steps.has(VoyagePresentation.Step.ARRIVAL_READY), "a plain voyage arrives")
	assert_eq(String(model.phase_name()), "arrival_harbor",
		"the chart is covered and the destination harbour takes over")

	# The harbour beat is visible: the veil clears while the camera descends.
	var finished := _drive_until_step(model, VoyagePresentation.Step.DONE, 10.0)
	assert_true(finished.has(VoyagePresentation.Step.DONE), "the harbour beat ends the演出")
	assert_eq(String(model.phase_name()), "done", "the presentation is finished")
	assert_false(model.is_active(), "a finished presentation is not active")
	assert_almost_eq(model.veil, 0.0, 0.001, "the destination harbour is revealed")


func test_skip_jumps_to_arrival_when_no_event_pending() -> void:
	var model := VoyagePresentation.new()
	model.plan(30.0)
	_enter_at_sea(model)
	_drive(model, 0.5)
	assert_true(model.progress < 0.5, "the ship is still early in the voyage")

	assert_eq(model.skip(), VoyagePresentation.Step.NONE, "skip just starts the arrival veil")
	var steps := _drive_until_step(model, VoyagePresentation.Step.ARRIVAL_READY, 6.0)
	assert_true(steps.has(VoyagePresentation.Step.ARRIVAL_READY), "skipping reaches the arrival hand-over")
	assert_almost_eq(model.progress, 1.0, 0.001, "skipping still completes the route")
	var finished := _drive_until_step(model, VoyagePresentation.Step.DONE, 10.0)
	assert_true(finished.has(VoyagePresentation.Step.DONE), "the port entry still plays out")


func test_skip_still_surfaces_a_pending_event() -> void:
	var model := VoyagePresentation.new()
	model.plan(30.0, 0.6)
	_enter_at_sea(model)
	model.skip()
	var steps := _drive(model, 3.0)
	assert_true(steps.has(VoyagePresentation.Step.EVENT_READY),
		"skipping the animation must not skip the player's decision")
	assert_eq(String(model.phase_name()), "event_wait", "the event screen is still presented")
	assert_false(steps.has(VoyagePresentation.Step.ARRIVAL_READY), "arrival does not fire past an unhandled event")


func test_skip_is_ignored_while_waiting_for_the_decision() -> void:
	var model := VoyagePresentation.new()
	model.plan(10.0, 0.3)
	_enter_at_sea(model)
	_drive(model, 20.0)
	assert_eq(String(model.phase_name()), "event_wait", "the fixture reaches the decision point")
	assert_eq(model.skip(), VoyagePresentation.Step.NONE, "skip is a no-op at the decision point")
	assert_eq(String(model.phase_name()), "event_wait", "the decision still waits for the player")


func test_snapshot_exposes_the_hud_fields() -> void:
	var model := VoyagePresentation.new()
	model.plan(8.0)
	var snapshot := model.snapshot()
	for key in ["phase", "progress", "veil", "total_hours", "elapsed_hours", "remaining_hours", "hours_per_second"]:
		assert_true(snapshot.has(key), "the presentation snapshot carries %s" % key)
	assert_almost_eq(float(snapshot["total_hours"]), 8.0, 0.001, "the snapshot reports the voyage hours")
	assert_true(float(snapshot["hours_per_second"]) > 1.0, "time is compressed on screen")


func test_sample_polyline_walks_by_arc_length() -> void:
	var path := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 1)])
	assert_almost_eq(VoyagePresentation.polyline_length(path), 11.0, 0.0001, "polyline length sums its segments")
	# Half the length (5.5) lands on the first, long segment — not at the point index midpoint.
	assert_true(VoyagePresentation.sample_polyline(path, 0.5).is_equal_approx(Vector2(5.5, 0.0)),
		"the midpoint follows arc length, not point index")
	assert_true(VoyagePresentation.sample_polyline(path, 0.0).is_equal_approx(Vector2.ZERO), "t=0 is the start")
	assert_true(VoyagePresentation.sample_polyline(path, 1.0).is_equal_approx(Vector2(10, 1)), "t=1 is the end")


func test_unpack_path_reads_the_chart_flat_array() -> void:
	var points := VoyagePresentation.unpack_path([0.0, 0.0, 3.5, 4.0, 10.0, 4.0])
	assert_eq(points.size(), 3, "pairs become points")
	assert_true(points[1].is_equal_approx(Vector2(3.5, 4.0)), "each pair keeps its order")
	assert_eq(VoyagePresentation.unpack_path([1.0]).size(), 0, "a dangling coordinate is ignored")
	assert_eq(VoyagePresentation.unpack_path([]).size(), 0, "an empty path stays empty")


func test_cloud_veil_is_a_pure_renderer_of_cover() -> void:
	var veil := SNCloudVeil.new()
	assert_true(veil.is_clear(), "a fresh veil is clear")
	veil.cover = 0.5
	assert_false(veil.is_covered(), "half cover is neither covered nor clear")
	veil.cover = 1.4
	assert_almost_eq(veil.cover, 1.0, 0.0001, "cover clamps to 1")
	assert_true(veil.is_covered(), "cover 1 reads as covered")
	assert_true(veil.visible, "a covering veil must be visible")
	veil.cover = -0.3
	assert_almost_eq(veil.cover, 0.0, 0.0001, "cover clamps to 0")
	assert_true(veil.is_clear(), "cover 0 reads as clear")
	assert_false(veil.visible, "a clear veil hides itself instead of drawing nothing")
	veil.advance(1.0)
	assert_true(veil.drift > 0.0, "the drift phase advances for the cloud motion")
	veil.free()


## Steps the model until `seconds` of real time have elapsed, collecting the
## milestones it reported. Frame budget keeps a broken transition from hanging.
func _drive(model: VoyagePresentation, seconds: float) -> Array:
	var steps: Array = []
	var elapsed := 0.0
	var frames := 0
	while elapsed < seconds and frames < 4000:
		var step := model.tick(DELTA)
		if step != VoyagePresentation.Step.NONE:
			steps.append(step)
		elapsed += DELTA
		frames += 1
	return steps


## Steps until `wanted` is reported (or the budget runs out), so a test can assert
## what the phase is *at* a milestone instead of after an arbitrary duration.
func _drive_until_step(model: VoyagePresentation, wanted: VoyagePresentation.Step, max_seconds: float) -> Array:
	var steps: Array = []
	var elapsed := 0.0
	while elapsed < max_seconds:
		var step := model.tick(DELTA)
		if step != VoyagePresentation.Step.NONE:
			steps.append(step)
			if step == wanted:
				return steps
		elapsed += DELTA
	return steps


## Enters AT_SEA and waits for the departure veil to clear, so a test can start
## timing the voyage itself. Stops at the first frame where the chart is visible,
## so the helper itself does not eat a measurable slice of the route.
func _enter_at_sea(model: VoyagePresentation) -> void:
	model.begin_departure()
	var frames := 0
	while frames < 400:
		model.tick(DELTA)
		frames += 1
		if model.phase == VoyagePresentation.Phase.AT_SEA and model.veil <= 0.0001:
			return
