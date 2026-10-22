extends TestCase
## Nautical chart phase 3 — the voyage presentation as wired into the shell.
##
## These tests drive the real shell (`main.tscn`) and the real commands, so they
## cover the hand-over points the pure model cannot: what page is mounted, when
## navigation disappears, and that the settlement screen is what the player ends
## on. Frame stepping is manual (`shell._process(dt)`), which keeps the演出
## deterministic in a headless run.
##
## 4.3.3 / U4 additionally asserts the ship is lit on the chart during the演出
## (`AtSeaScreen.get_ship_vision_radius()` / `SNSeaChartView.has_ship_vision()`)
## and that arriving — normal voyage or exploration settle — persists the fog met
## along the route into `GameState.data["fog"]`.

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const EVENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/event_screen.gd")
const SEA_CHART_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/sea_chart_screen.gd")
const SETTLEMENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/settlement_screen.gd")
const STEADY_BUILD := "core:starting_scenario/steady"
const STANDARD_STRATEGY := "core:boiler_strategy/standard"
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
	# 4.3.3 / U4：演出中船周有连续照亮（纯表现），半径来自 sea_chart.view 的
	# fog_radii.vision，与领域迷雾同源。
	assert_true(at_sea.get_ship_vision_radius() > 0.0,
		"the normal voyage lights the chart around the ship (radius %.2f)" % at_sea.get_ship_vision_radius())
	assert_true(at_sea.get_chart().has_ship_vision(), "the chart draws the soft glow around the ship")
	var chart_radii: Variant = at_sea.get_chart().view_model.get("fog_radii", {})
	if chart_radii is Dictionary:
		assert_almost_eq(
			at_sea.get_ship_vision_radius(),
			float((chart_radii as Dictionary).get("vision", 0.0)),
			0.0001,
			"the演出 glow radius is the view model's content-derived vision radius"
		)

	# 船 icon 朝向移动方向：任意进度的艏向 = 航线在该处的切线方向，海图收到的
	# heading 与航行页算出的完全一致（转弯时船头跟着航线转）。
	var path: PackedVector2Array = at_sea.get_route_path()
	for progress in [0.0, 0.25, 0.6, 1.0]:
		at_sea.set_presentation({"progress": progress})
		var expected := _route_tangent(path, progress)
		assert_almost_eq(angle_difference(at_sea.get_ship_heading(), expected), 0.0, 0.1,
			"the ship heading follows the route tangent at progress %.2f" % progress)
		assert_almost_eq(
			angle_difference(at_sea.get_chart().get_ship_heading(), at_sea.get_ship_heading()),
			0.0, 0.001,
			"the chart icon is fed the same heading as the voyage page"
		)
	# A bend on the route must actually change the heading (two points would not).
	at_sea.set_presentation({"progress": 0.25})
	var heading_a: float = at_sea.get_ship_heading()
	at_sea.set_presentation({"progress": 0.75})
	var heading_b: float = at_sea.get_ship_heading()
	assert_true(absf(angle_difference(heading_a, heading_b)) > 0.01,
		"the heading turns with the route instead of staying fixed: %f vs %f" % [heading_a, heading_b])


## Tangent direction (world radians) of a route polyline at `progress`, sampled the
## same way the at-sea page does it.
func _route_tangent(path: PackedVector2Array, progress: float) -> float:
	if path.size() < 2:
		return 0.0
	var sample := 0.004
	var backward := VoyagePresentation.sample_polyline(path, maxf(0.0, progress - sample))
	var forward := VoyagePresentation.sample_polyline(path, minf(1.0, progress + sample))
	var delta := forward - backward
	if delta.length() < 0.0001:
		return 0.0
	return atan2(delta.y, delta.x)


## F2（Shell 接线）：入港云层盖住海图之前，海图取景必须被推近。快照只在 `AT_SEA`
## 推送时，`ARRIVAL_APPROACH` 里模型算出的 `chart_zoom_scale()` 送不到海图，云层下
## 的海图会一直停在稳态取景（阶段 3 验收反馈 F2 的"入港镜像"就断了）。
func test_chart_framing_pushes_in_during_the_arrival_veil() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_start_voyage(shell, context)
	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 8.0),
		"the chart page mounts after the departure veil")
	assert_true(_drive_until(shell, func() -> bool:
		return shell._presentation != null \
			and String(shell._presentation.phase_name()) == "arrival_approach", 30.0),
		"the voyage reaches the arrival veil")
	var at_sea = _find_at_sea(shell)
	assert_not_null(at_sea, "the chart page is still mounted while the arrival clouds close")
	var max_scale := 0.0
	var frames := 0
	while shell._presentation != null \
			and String(shell._presentation.phase_name()) == "arrival_approach" \
			and frames < 120:
		shell._process(STEP_SECONDS)
		max_scale = maxf(max_scale, at_sea.get_chart().get_frame_scale())
		frames += 1
	assert_true(max_scale > 2.0,
		"the chart is pushed in before the arrival cut (max frame_scale %.2f)" % max_scale)


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


# ── 4.3.5 / U8: continuous consumption ──

## 普通航行（无途中事件）：`voyage.start` 同步结算抵达，但扣款只按实际航行小时
## `rate × duration`；演出期间顶栏读数从出发库存连续下降，而领域状态在整个演出
## 中保持不变（不在航程中逐帧写状态），演出结束后的 chrome 回到真实 state 读数。
func test_normal_voyage_charges_fuel_by_the_hour_at_arrival() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var destination := _first_destination(context)
	var preview_result := context.commands.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	assert_true(bool(preview_result.get("ok", false)), "the voyage previews")
	var preview: Dictionary = preview_result.get("data", {})
	var coal_before := float(context.state.ship().get("coal", 0.0))
	var water_before := float(context.state.ship().get("water", 0.0))
	var hours := maxf(0.0001, float(preview.get("duration_hours", 0.0)))
	var coal_rate := float(preview.get("coal_required", 0.0)) / hours
	var water_rate := float(preview.get("water_required", 0.0)) / hours

	shell._run_command(&"voyage.start", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})
	assert_not_null(shell._presentation, "the voyage hands over to the演出")
	assert_false(shell._presentation.has_event, "the fixture voyage has no event")
	# 领域结算（同步发生）按实际小时扣款：rate × duration，而不是预览整包扣除。
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)),
		maxf(0.0, coal_before - coal_rate * hours), 0.02,
		"arrival charges coal = hourly rate × actual hours")
	assert_almost_eq(float(context.state.ship().get("water", 0.0)),
		maxf(0.0, water_before - water_rate * hours), 0.02,
		"arrival charges water = hourly rate × actual hours")
	var summary: Dictionary = shell._presentation_summary
	if summary.is_empty():
		summary = shell._settlement_summary
	assert_almost_eq(float(summary.get("coal_used_actual", -1.0)), coal_rate * hours, 0.02,
		"the summary reports the actual coal consumed")
	var settled_coal := float(context.state.ship().get("coal", 0.0))

	# 演出中：顶栏读数从出发库存连续下降，但领域库存不变（只改 Label 文本）。
	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 8.0),
		"the chart page mounts")
	_drive_until(shell, func() -> bool: return shell._presentation.veil <= 0.001, 4.0)
	var first_text := _hud_coal_text(shell)
	assert_false(first_text.is_empty(), "the chrome exposes a coal value label during the演出")
	_drive_seconds(shell, 0.6)
	var second_text := _hud_coal_text(shell)
	assert_true(second_text.to_float() < first_text.to_float(),
		"the coal readout falls continuously with the voyage (%s → %s)" % [first_text, second_text])
	assert_true(_hud_water_text(shell).to_float() > 0.0, "the water readout is a live number")
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)), settled_coal, 0.0001,
		"the domain stock does not change during the演出 (presentation-only readout)")
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the演出 finishes on its own")
	assert_eq(_hud_coal_text(shell), shell._fmt(float(context.state.ship().get("coal", 0.0))),
		"after the演出 the chrome reads the settled domain stock again")


## 普通航行（有途中事件 + 延误）：`voyage.start` 只扣工资（事件让航次仍在途中），
## 演出中读数下降但库存不动；事件结算按实际小时扣款，事件延误小时一并计费。
func test_event_delay_is_included_in_the_fuel_charged_on_arrival() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var destination := _first_destination(context)
	var forced := _force_delayed_event_context(context, destination)
	assert_false(forced.is_empty(), "the fixture finds an event with a delayed option")
	if forced.is_empty():
		return
	var preview_result := context.commands.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	assert_true(bool(preview_result.get("ok", false)), "the voyage previews")
	var preview: Dictionary = preview_result.get("data", {})
	var coal_before := float(context.state.ship().get("coal", 0.0))
	var water_before := float(context.state.ship().get("water", 0.0))
	var money_before := context.state.money()
	var wages := int(preview.get("crew_wages", 0))

	shell._run_command(&"voyage.start", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})
	assert_not_null(shell._presentation, "the event leg hands over to the演出")
	var voyage: Variant = context.state.data.get("voyage", null)
	assert_true(voyage is Dictionary, "an event leg keeps the voyage in flight until the decision")
	if not (voyage is Dictionary):
		return
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)), coal_before, 0.0001,
		"departure only charges wages: coal stays on board")
	assert_almost_eq(float(context.state.ship().get("water", 0.0)), water_before, 0.0001,
		"departure only charges wages: water stays on board")
	assert_eq(context.state.money(), money_before - wages, "the crew wages are still paid at departure")
	var departure_time := float((voyage as Dictionary).get("departure_time", 0.0))
	var base_duration := float((voyage as Dictionary).get("base_duration",
		float((voyage as Dictionary).get("arrival_time", 0.0)) - departure_time))
	var coal_rate := float((voyage as Dictionary).get("coal_rate", 0.0))
	var water_rate := float((voyage as Dictionary).get("water_rate", 0.0))
	assert_almost_eq(float((voyage as Dictionary).get("departure_coal", -1.0)), coal_before, 0.0001,
		"the voyage records the departure coal stock")
	assert_almost_eq(coal_rate, float(preview.get("coal_required", 0.0))
		/ maxf(0.0001, float(preview.get("duration_hours", 0.0))), 0.0001,
		"the hourly coal rate is the planned burn / planned hours")

	# 演出中读数下降，但领域库存不动。
	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 8.0),
		"the chart page mounts")
	_drive_until(shell, func() -> bool: return shell._presentation.veil <= 0.001, 4.0)
	var first_text := _hud_coal_text(shell)
	_drive_seconds(shell, 0.5)
	assert_true(_hud_coal_text(shell).to_float() < first_text.to_float(),
		"the coal readout falls before the event decision")
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)), coal_before, 0.0001,
		"the domain stock stays untouched while the演出 runs")

	# 选一个带 `add_delay_hours` 的选项：结算按「计划时长 + 延误」计费。
	assert_true(_drive_until(shell, func() -> bool:
		return String(shell._presentation.phase_name()) == "event_wait", MAX_DRIVE_SECONDS),
		"the演出 stops at the event decision")
	shell._run_command(&"event.choose_option", {"option_id": String(forced.get("option_id", ""))})
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the remaining leg plays out after the decision")
	assert_eq(String(shell._active_screen), "settlement", "the voyage settles after the event")
	var summary: Dictionary = shell._settlement_summary
	var delay_hours := float(summary.get("delayed_hours", 0.0))
	assert_true(delay_hours > 0.0, "the chosen option really delays the voyage")
	var actual_hours := float(summary.get("arrival_time", 0.0)) - departure_time
	assert_almost_eq(actual_hours, base_duration + delay_hours, 0.001,
		"the actual voyage hours include the event delay")
	assert_almost_eq(float(summary.get("coal_used_actual", -1.0)), coal_rate * actual_hours, 0.02,
		"the arrival charge covers the actual hours, event delay included")
	assert_almost_eq(float(context.state.ship().get("coal", 0.0)),
		maxf(0.0, coal_before - coal_rate * actual_hours), 0.02,
		"arrival deducts coal for the delayed actual hours")
	assert_almost_eq(float(context.state.ship().get("water", 0.0)),
		maxf(0.0, water_before - water_rate * actual_hours), 0.02,
		"arrival deducts water for the delayed actual hours")


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


## 验收反馈 F4：海图上的船必须沿**世界航线表里的真实航线**移动，而不是起终港
## 两点直线。出发时目的港通常还没发现（`sea_chart.view` 会把它整条过滤掉），
## 所以演出数据不能取那份迷雾过滤结果；它取的是 `WorldMap.edges` 的完整航线。
func test_at_sea_ship_follows_the_world_route_not_a_straight_line() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var origin := String(context.state.current_port_id())
	_start_voyage(shell, context)
	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 8.0),
		"the chart page mounts")
	var at_sea = _find_at_sea(shell)
	var destination := String(shell._presentation_voyage.get("destination", ""))
	var world := WorldOps.world_map(context.state)
	var from_port := world.get_port(origin)
	var to_port := world.get_port(destination)
	assert_false(from_port.is_empty() or to_port.is_empty(), "the twin world knows both harbours")

	var actual: PackedVector2Array = at_sea.get_route_path()
	assert_true(actual.size() > 2,
		"the演出 uses the world route polyline (%d points), not the two-point fallback" % actual.size())
	assert_true(actual[0].distance_to(from_port.position) < 0.01,
		"the route starts at the departure harbour")
	assert_true(actual[actual.size() - 1].distance_to(to_port.position) < 0.01,
		"the route ends at the destination harbour")

	# 视角原则（验收反馈 F4）：迷雾只决定玩家在图上"看不看得见"，不决定演出用什么
	# 数据。把目的港从已发现列表里拿掉（事件航段就是这么几帧的状态：`voyage.start`
	# 还没结算抵达），重新挂一个航行页：海图查询会过滤掉目的港与航线，但演出仍
	# 必须拿到同一条完整航线。
	var campaign_world := context.state.campaign_world()
	var saved_discovered: Array = (campaign_world.get("discovered_port_ids", []) as Array).duplicate()
	campaign_world["discovered_port_ids"] = [origin]
	var expected_size := actual.size()
	shell._screen_at_sea(shell._last_port_view, shell._presentation_voyage)
	var filtered: AtSeaScreen = shell._at_sea_screen
	assert_not_null(filtered, "a filtered chart still mounts the at-sea page")
	var filtered_ids: Array = []
	for entry in filtered.get_chart().view_model.get("ports", []):
		filtered_ids.append(String((entry as Dictionary).get("id", "")))
	assert_false(filtered_ids.has(destination),
		"the fog filter really hides the undiscovered destination in this fixture")
	assert_eq(filtered.get_route_path().size(), expected_size,
		"the演出 route ignores the fog-filtered chart query and uses the world route table")
	assert_true(filtered.get_route_path()[0].distance_to(from_port.position) < 0.01,
		"the filtered演出 route still starts at the departure harbour")
	campaign_world["discovered_port_ids"] = saved_discovered

	# 任意进度都必须落在航线上（逐点最小距离 < 1 世界单位），起终两端等于港口坐标。
	for progress in [0.0, 0.17, 0.4, 0.63, 0.86, 1.0]:
		at_sea.set_presentation({"progress": progress})
		var position: Vector2 = at_sea.get_ship_world_position()
		assert_true(_distance_to_polyline(position, actual) < 1.0,
			"ship at progress %.2f stays on the route (%.2f units off)" % [
				progress, _distance_to_polyline(position, actual),
			])
	assert_true(at_sea.get_ship_world_position().distance_to(to_port.position) < 0.01,
		"progress 1 puts the marker exactly on the destination harbour")


## Shortest distance from `point` to a polyline, in world units.
func _distance_to_polyline(point: Vector2, polyline: PackedVector2Array) -> float:
	if polyline.size() < 2:
		return INF
	var best := INF
	for index in range(1, polyline.size()):
		best = minf(best, point.distance_to(
			Geometry2D.get_closest_point_to_segment(point, polyline[index - 1], polyline[index])
		))
	return best


## 探索演出 · 发现（成功结算）：海图点线索 → 面板线索区块 → 「循此线索出航」→
## 3D 离港 → 海图（虚线预测线 + `?`）→ `ARRIVAL_READY` 自动 `explore.settle` →
## 3D 入港 → 结算页出现探索结果。目的地（目标港）只有结算后才知道。
func test_explore_clue_discovers_a_port_through_the_presentation() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var clue := _acquire_fixture_clue(context)
	var target := String(clue.get("target_port_id", ""))
	var origin := String(context.state.current_port_id())
	assert_true(not target.is_empty(), "the fixture clue points at a real undiscovered harbour")
	var presentation := _request_exploration(shell, context, String(clue.get("id", "")), 0.0)
	assert_true(not presentation.is_empty(), "explore.start returns the exploration presentation")
	assert_eq(String(presentation.get("kind", "")), "explore", "the presentation says it is an exploration")
	assert_not_null(shell._presentation, "explore.start hands over to the same voyage presentation")
	assert_eq(String(shell._presentation.phase_name()), "departure_3d", "the 3D departure cut plays first")
	assert_true(shell._sea_chart_available() == false, "the chart hotkey stays disabled during the演出")

	# 海图阶段：航线终点是搜索区中心（不是港口），并画出未知终点 `?`。
	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 8.0),
		"the chart page mounts after the departure veil")
	var at_sea = _find_at_sea(shell)
	assert_true(at_sea.get_chart().has_unknown_destination(),
		"the chart draws the unknown destination marker during an exploration")
	# 4.3.3 / U4：探索演出同样在船周照亮。
	assert_true(at_sea.get_ship_vision_radius() > 0.0,
		"the exploration演出 lights the chart around the ship (radius %.2f)" % at_sea.get_ship_vision_radius())
	assert_true(at_sea.get_chart().has_ship_vision(), "the chart draws the soft glow during an exploration")
	var unknown: Dictionary = at_sea.get_unknown_destination()
	assert_eq(String(unknown.get("label_key", "")), "ui.label.unknown_destination",
		"the ? marker is localized")
	var zone: Dictionary = presentation.get("zone", {})
	assert_almost_eq(float(unknown.get("x", 0.0)), float(zone.get("x", -1.0)), 0.001,
		"the ? marker sits on the search-zone centre")
	# 顶部 chrome 的高度随未知终点一起传下去：`?` 被顶栏挡住时海图要 clamp 到可见区。
	assert_true(float(unknown.get("top_inset", 0.0)) > 0.0,
		"the shell hands the chart a top-chrome inset so ? never hides under the HUD")
	# 正在追的线索不再画线索层（它的虚线圆与 ? 终点重叠），其它线索保留。
	for entry in at_sea.get_chart().view_model.get("clues", []):
		if entry is Dictionary:
			assert_ne(String((entry as Dictionary).get("id", "")), String(clue.get("id", "")),
				"the clue being chased is filtered out of the演出 chart layer")
	var route: PackedVector2Array = at_sea.get_route_path()
	assert_true(route.size() >= 2, "the exploration route is a real polyline")
	if route.size() >= 2:
		assert_true(route[route.size() - 1].distance_to(
			Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))
		) < 1.0, "the voyage route ends at the search zone, not a harbour")
	var route_label := _label_named(at_sea, "RouteLabel")
	assert_not_null(route_label, "the voyage strip names the endpoints")
	if route_label != null:
		assert_true(String((route_label as Label).text).contains("？"),
			"the destination reads ? instead of a harbour name, got: %s" % (route_label as Label).text)
		assert_true(String((route_label as Label).text).contains(_port_name(context, origin)),
			"the origin still names the departure harbour, got: %s" % (route_label as Label).text)

	# 演出跑到抵达：Shell 在 ARRIVAL_READY 主动结算，然后才换入港镜头与结算页。
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the exploration演出 finishes on its own")
	assert_eq(String(shell._active_screen), "settlement", "arrival lands on the settlement screen")
	assert_eq(String(shell._presentation_voyage.get("destination", "")), target,
		"the explore.settle destination replaces the empty presentation destination")
	assert_true(shell._settlement_summary.has("explore"), "the settlement summary carries the explore block")
	var explore_summary: Dictionary = shell._settlement_summary.get("explore", {})
	assert_eq(String(explore_summary.get("result", "")), "discovered",
		"a roll below the discovery chance finds the port")
	assert_eq(String(explore_summary.get("port_id", "")), target, "the found port is the clue's target")
	assert_eq(String(context.state.current_port_id()), target, "the ship enters the discovered harbour")
	assert_true(ClueService.active(context.state).is_empty(), "a resolved clue leaves the active list")
	assert_true(Array(context.state.ensure_clues().get("resolved", [])).has(String(clue.get("id", ""))),
		"the clue is recorded as resolved")
	assert_true(Array(context.state.campaign_world().get("discovered_port_ids", [])).has(target),
		"the discovered harbour enters the chart's discovered set")
	_assert_settlement_shows_explore_result(shell, context, "ui.explore.result.discovered")


## 探索演出 · 失败：发现 roll 高于概率 → 线索**保留**（4.3 / U3）、漂流到最近的
## 己知港（出发港），结算页说明失败、线索保留与额外损耗；演出同样走完整套流程。
func test_explore_failure_drifts_back_and_scraps_the_clue() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var clue := _acquire_fixture_clue(context)
	var origin := String(context.state.current_port_id())
	_request_exploration(shell, context, String(clue.get("id", "")), 0.999)
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"a failed exploration still plays out and settles")
	assert_eq(String(shell._active_screen), "settlement", "a failure still lands on the settlement screen")
	var explore_summary: Dictionary = shell._settlement_summary.get("explore", {})
	assert_eq(String(explore_summary.get("result", "")), "failed",
		"a roll above the discovery chance fails the exploration")
	assert_eq(String(explore_summary.get("port_id", "")), origin,
		"the drift destination is the nearest discovered harbour (the origin)")
	assert_eq(String(context.state.current_port_id()), origin, "the ship drifts back into the origin harbour")
	# 4.3 / U3：失败不消耗线索 —— 仍在 active，failed 列表不再新增，可再次出航。
	assert_eq(ClueService.active(context.state).size(), 1, "a failed clue stays in the active log")
	assert_true(ClueService.find_clue(context.state, String(clue.get("id", ""))).get("attempts", 0) == 1,
		"the failed attempt is recorded")
	assert_false(Array(context.state.ensure_clues().get("failed", [])).has(String(clue.get("id", ""))),
		"the failed clue is not moved into the failed list")
	assert_true(float(explore_summary.get("durability_loss", 0.0)) > 0.0,
		"drifting costs durability")
	assert_true(bool(explore_summary.get("clue_retained", false)),
		"the summary tells the settlement screen the clue is kept")
	_assert_settlement_shows_explore_result(shell, context, "ui.explore.result.failed")
	var settlement_texts := _label_texts(shell._root_box)
	assert_true(_label_text_contains(shell._root_box, context.translate("ui.explore.clue_retained")),
		"the settlement screen says the clue was kept, not discarded")
	assert_false(settlement_texts.has(context.translate("ui.explore.clue_failed")),
		"the settlement screen no longer claims the clue was discarded")


## 4.3.3 / U4：探索结算是把实际航线沿途的迷雾写进存档（不是只在演出层画软圆）。
## 出发（`explore.start`）不落账；抵达 `explore.settle` 后存档里的 EXPLORED 格子
## 一定比出发前多，且海图网格仍是同一份（`state.data["fog"]`）。
func test_explore_settle_persists_fog_along_the_sailed_route() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var clue := _acquire_fixture_clue(context)
	var explored_before := _fog_explored_count(context)
	_request_exploration(shell, context, String(clue.get("id", "")), 0.0)
	# 出发只点亮演出软圆：领域迷雾此刻还没变。
	assert_eq(_fog_explored_count(context), explored_before,
		"starting an exploration must not persist route fog yet (the演出 is presentation-only)")
	assert_true(_drive_until(shell, func() -> bool: return _find_at_sea(shell) != null, 8.0),
		"the chart page mounts")
	var route: PackedVector2Array = _find_at_sea(shell).get_route_path()
	assert_true(route.size() >= 2, "the exploration has a real route polyline")
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the exploration settles")
	var explored_after := _fog_explored_count(context)
	assert_true(explored_after > explored_before,
		"settling the exploration persists route/berth fog (EXPLORED %d → %d)" % [
			explored_before, explored_after,
		])
	var loaded := FogOps.load_fog_state(context.state)
	assert_false(loaded.is_empty(), "the arrival leaves a persisted fog grid in the save")


## 4.3.3 / U4：普通航行抵达同样把沿途迷雾写进存档（不只是探索专属）。
func test_normal_voyage_arrival_persists_fog_along_the_route() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var explored_before := _fog_explored_count(context)
	var destination := _start_voyage(shell, context)
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the voyage finishes on its own")
	assert_eq(String(shell._active_screen), "settlement", "arrival lands on the settlement screen")
	assert_eq(String(context.state.current_port_id()), destination, "the ship is in the destination harbour")
	var explored_after := _fog_explored_count(context)
	assert_true(explored_after > explored_before,
		"the normal voyage's arrival persists route/berth fog (EXPLORED %d → %d)" % [
			explored_before, explored_after,
		])
	var loaded := FogOps.load_fog_state(context.state)
	assert_false(loaded.is_empty(), "a normal arrival leaves a persisted fog grid in the save")


## 存档迷雾里 EXPLORED 格子的数量；没有迷雾（legacy 存档 / 未初始化）时返回 0。
func _fog_explored_count(context: AppContext) -> int:
	var loaded := FogOps.load_fog_state(context.state)
	if loaded.is_empty():
		return 0
	var fog: FogGrid = loaded.get("fog", FogGrid.new())
	if fog.is_empty():
		return 0
	return int(fog.count_cells_by_state()[FogGrid.CellState.EXPLORED])


## 探索链路公共前置的 4.2 版本：把出发煤量压到「本程需求 × 1.05」，`explore.start`
## 就会判定煤消耗超过出发存量的一半（Core `alert_threshold`）→ `alert_needed`，
## 演出在 `alert_progress`（默认 0.5）处停下并挂出资源告急页。
func _request_alert_exploration(
	shell: Control, context: AppContext, clue: Dictionary, outcome_roll: float
) -> Dictionary:
	var clue_id := String(clue.get("id", ""))
	var preview := ExplorationCalculator.preview(context, clue_id, STANDARD_STRATEGY)
	assert_true(bool(preview.get("ok", false)), "the alert fixture previews the clue voyage")
	if not bool(preview.get("ok", false)):
		return {}
	var preview_data: Dictionary = preview.get("data", {})
	var coal_required := float(preview_data.get("coal_required", 0.0))
	assert_true(coal_required > 0.0, "the clue voyage has a coal cost")
	assert_true(float(preview_data.get("water_required", 0.0)) > 0.0,
		"the clue voyage also burns water, so turning back can cost extra water")
	context.state.ship()["coal"] = coal_required * 1.05
	return _request_exploration(shell, context, clue_id, outcome_roll)


## 4.2 资源告急 · 继续：探索演出停在告警页（不是海图页），发布本地化文案与两个
## 选项；「继续探索」只确认告警，演出回到海图走完最后半程，抵达照常 `explore.settle`。
func test_explore_resource_alert_continue_resumes_the_voyage() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var clue := _acquire_fixture_clue(context)
	var target := String(clue.get("target_port_id", ""))
	var origin := String(context.state.current_port_id())
	var presentation := _request_alert_exploration(shell, context, clue, 0.0)
	assert_true(bool(presentation.get("alert_needed", false)),
		"the fixture really raises the resource alert")
	assert_true(shell._presentation.has_event, "the alert is a mid-voyage decision point")

	assert_true(_drive_until(shell, func() -> bool:
		return _nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT).size() == 1, MAX_DRIVE_SECONDS),
		"the exploration stops at the resource-alert page (status: %s)" % shell._status_message)
	assert_eq(String(shell._presentation.phase_name()), "event_wait", "the演出 waits at the alert")
	assert_true(_find_at_sea(shell) == null, "the chart page is not mounted while the alert is open")
	var alert_screen: Control = _nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT)[0]
	var alert_texts := _label_texts(alert_screen)
	assert_contains(alert_texts, context.translate("ui.explore.alert.title"),
		"the alert page shows the localized title")
	assert_contains(alert_texts, context.translate("ui.explore.alert.description"),
		"the alert page explains the two choices")
	assert_not_null(_button_by_text(alert_screen, context.translate("ui.explore.alert.continue")),
		"the alert offers 'continue exploring'")
	assert_not_null(_button_by_text(alert_screen, context.translate("ui.explore.alert.turn_back")),
		"the alert offers 'turn back'")
	# 「选择后会立即结算」对继续探索不成立：提示行要换成剩余航程。
	assert_true(_label_text_contains(alert_screen, context.translate("ui.explore.alert.remaining")),
		"the alert hint shows the remaining voyage instead of 'settles immediately'")
	assert_eq(shell._presentation.skip(), VoyagePresentation.Step.NONE,
		"the alert cannot be skipped away or answered by the演出")
	# 顶栏在告警期间只能显示「探索中 → ？」，不能提前泄露目标港。
	assert_eq(String(shell._presentation_voyage.get("destination", "unset")), "",
		"the target harbour is still unknown while the alert is open")
	var chrome_texts := _label_texts(shell._top_chrome)
	var exploring_label := "%s → %s" % [
		context.translate("ui.label.exploring"),
		context.translate("ui.label.unknown_destination"),
	]
	assert_contains(chrome_texts, exploring_label, "the header stays 'exploring → ?' during the alert")
	assert_false(chrome_texts.has(_port_name(context, target)),
		"the alert header does not reveal the target harbour")

	var continue_button := _button_by_text(alert_screen, context.translate("ui.explore.alert.continue"))
	continue_button.pressed.emit()
	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the voyage continues after acknowledging the alert")
	assert_eq(String(shell._active_screen), "settlement", "continuing still reaches the settlement screen")
	var explore_summary: Dictionary = shell._settlement_summary.get("explore", {})
	assert_eq(String(explore_summary.get("result", "")), "discovered",
		"roll 0 finds the harbour after continuing")
	assert_eq(String(context.state.current_port_id()), target, "the ship enters the discovered harbour")
	assert_true(shell._presentation_explore.is_empty(),
		"the exploration context is cleared when the演出 ends")
	assert_false(shell._status_is_error, "no error is left in the status bar: %s" % shell._status_message)
	assert_true(not _has_logged_command(context, "explore.decide", "alert_already_decided"),
		"acknowledging the alert once is accepted")


## 4.2 资源告急 · 掉头：领域立刻结算半程返航（回出发港、线索保留、额外煤水），
## 演出放弃剩余航程直接入港；`ARRIVAL_READY` 不能再 settle（否则 `not_exploring`）。
func test_explore_resource_alert_turn_back_returns_to_the_origin() -> void:
	var bundle := _mount(4321)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var clue := _acquire_fixture_clue(context)
	var clue_id := String(clue.get("id", ""))
	var origin := String(context.state.current_port_id())
	var presentation := _request_alert_exploration(shell, context, clue, 0.0)
	assert_true(bool(presentation.get("alert_needed", false)),
		"the fixture really raises the resource alert")
	assert_true(_drive_until(shell, func() -> bool:
		return _nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT).size() == 1, MAX_DRIVE_SECONDS),
		"the exploration reaches the resource-alert page (status: %s)" % shell._status_message)
	var alert_screen: Control = _nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT)[0]
	var coal_before := float(context.state.ship().get("coal", 0.0))
	var water_before := float(context.state.ship().get("water", 0.0))
	var turn_back_button := _button_by_text(alert_screen, context.translate("ui.explore.alert.turn_back"))
	assert_not_null(turn_back_button, "the alert offers turning back")
	if turn_back_button == null:
		return
	turn_back_button.pressed.emit()

	# 决策立刻落到领域：回出发港、探索航次清空、线索保留、额外煤水已扣。
	assert_eq(String(context.state.current_port_id()), origin, "turning back returns to the origin harbour")
	assert_true(context.state.is_at_port(), "the ship is back in port")
	assert_true(context.state.explore_voyage() == null, "the exploration voyage is settled immediately")
	assert_eq(String(shell._presentation_voyage.get("destination", "")), origin,
		"the presentation destination becomes the origin harbour")
	assert_true(bool(shell._presentation_explore.get("returned", false)),
		"the exploration context records the turn-back")
	assert_eq(String(shell._presentation.phase_name()), "arrival_approach",
		"the演出 skips the rest of the route and closes the arrival clouds")
	assert_true(float(context.state.ship().get("coal", 0.0)) < coal_before,
		"turning back burns extra coal")
	assert_true(float(context.state.ship().get("water", 0.0)) < water_before,
		"turning back burns extra water")
	assert_true(_active_clue_ids(context).has(clue_id), "the clue stays active for another attempt")

	assert_true(_drive_until(shell, func() -> bool: return shell._presentation == null, MAX_DRIVE_SECONDS),
		"the return演出 finishes on its own")
	assert_eq(String(shell._active_screen), "settlement", "turning back lands on the settlement screen")
	var explore_summary: Dictionary = shell._settlement_summary.get("explore", {})
	assert_eq(String(explore_summary.get("result", "")), "turned_back",
		"the settlement summary reports the turn-back")
	assert_eq(String(explore_summary.get("port_id", "")), origin,
		"the settlement summary names the origin harbour")
	_assert_settlement_shows_explore_result(shell, context, "ui.explore.result.turned_back")
	assert_false(shell._status_is_error,
		"turning back leaves no error in the status bar: %s" % shell._status_message)
	# 掉头已在决策时结算：ARRIVAL_READY 不能再调 explore.settle（那会报 not_exploring）。
	assert_false(_has_logged_command(context, "explore.settle", ""),
		"a turn-back never runs explore.settle (it was already settled)")
	assert_false(_has_logged_command(context, "", "not_exploring"),
		"no not_exploring error is raised during the turn-back")


## 探索链路的公共前置：造一条指向最近未发现港的线索，打开海图、点线索、出航，
## 并把出发时抽定的 outcome_roll 覆盖成测试要的结果（0 = 必发现，0.999 = 必失败）。
## 返回 `explore.start` 的 presentation 块。
func _request_exploration(
	shell: Control, context: AppContext, clue_id: String, outcome_roll: float
) -> Dictionary:
	shell._active_screen = "sea_chart"
	shell._refresh()
	var screens := _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the chart page is mounted for the clue")
	if screens.is_empty():
		return {}
	var screen: Control = screens[0]
	var view_model: Dictionary = screen._view_model
	var clue_ids: Array = []
	for entry in view_model.get("clues", []):
		clue_ids.append(String((entry as Dictionary).get("id", "")))
	assert_true(clue_ids.has(clue_id), "the acquired clue reaches the chart view model: %s" % str(clue_ids))

	screen._on_clue_clicked(clue_id)
	var panel: SNSeaChartPanel = screen._panel
	assert_not_null(panel, "the chart screen mounts a panel")
	assert_eq(String(panel.get_clue().get("id", "")), clue_id,
		"clicking the clue binds it into the panel")
	var explore_button := _button_by_text(screen, context.translate("ui.button.explore_clue"))
	assert_not_null(explore_button, "the clue panel offers the explore button")
	if explore_button == null:
		return {}
	explore_button.pressed.emit()

	# 4.3.4 / U7：面板按钮只打开统一的出航确认弹窗；确认后才发 explore.start。
	screens = _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the chart page is rebuilt with the departure dialog")
	if screens.is_empty():
		return {}
	screen = screens[0]
	assert_true(bool(screen.is_departure_open()), "the explore request opens the confirmation dialog")
	var confirm_button := _button_by_text(screen, context.translate("ui.button.start_voyage"))
	assert_not_null(confirm_button, "the confirmation dialog offers the depart button")
	if confirm_button == null:
		return {}
	confirm_button.pressed.emit()

	assert_not_null(shell._presentation, "explore.start starts the presentation (status: %s)" % shell._status_message)
	assert_true(not shell._presentation_explore.is_empty(), "the shell stores the exploration presentation")
	var voyage: Variant = context.state.explore_voyage()
	assert_true(voyage is Dictionary, "explore.start writes the explore_voyage block (status: %s)" % shell._status_message)
	if voyage is Dictionary:
		(voyage as Dictionary)["outcome_roll"] = outcome_roll
	return shell._presentation_explore.duplicate(true)


## 命令执行日志里是否有匹配的记录：`command` 为空表示任意命令，`error_code` 为空
## 表示任意结果。用来断言「掉头没有触发第二次 settle」这类副作用。
func _has_logged_command(context: AppContext, command: String, error_code: String) -> bool:
	for entry in context.commands.get_execution_log(200):
		if not (entry is Dictionary):
			continue
		if not command.is_empty() \
				and String((entry as Dictionary).get("command", "")) != command:
			continue
		if not error_code.is_empty() \
				and String((entry as Dictionary).get("error_code", "")) != error_code:
			continue
		return true
	return false


func _active_clue_ids(context: AppContext) -> Array:
	var ids: Array = []
	for clue in ClueService.active(context.state):
		ids.append(String((clue as Dictionary).get("id", "")))
	return ids


## 造一条测试线索：补足金币，目标选最近的未发现港口（航线短、默认补给即可出航），
## 再走与抵达传闻相同的领域入口（`ClueService.acquire`）写入 active 列表。
## 注意不要往船上硬塞煤水：补给有重量，超过载重上限会让预览判为"重量超限"。
func _acquire_fixture_clue(context: AppContext) -> Dictionary:
	context.state.set_money(5000)
	var world := WorldOps.world_map(context.state)
	var origin := world.get_port(context.state.current_port_id())
	assert_false(origin.is_empty(), "the fixture run has a current harbour")
	var best := ""
	var best_distance := INF
	for port_id in ClueService.eligible_target_ids(context.state):
		var port := world.get_port(String(port_id))
		if port.is_empty():
			continue
		var distance := port.position.distance_to(origin.position)
		if distance < best_distance:
			best_distance = distance
			best = String(port_id)
	assert_true(not best.is_empty(), "the fixture world has an undiscovered target harbour")
	var rng := context.rng.stream(
		RngService.STREAM_EXPLORATION, "fixture:clue:%s" % str(context.state.now())
	)
	var clue := ClueService.acquire(context, "intel", rng, best)
	assert_false(clue.is_empty(), "the fixture acquires a clue through the domain service")
	return clue


func _assert_settlement_shows_explore_result(
	shell: Control, context: AppContext, result_key: String
) -> void:
	var screens := _nodes_with_script(shell._root_box, SETTLEMENT_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the settlement screen is mounted")
	if screens.is_empty():
		return
	var texts := _label_texts(screens[0])
	assert_true(texts.has(String(context.translate(result_key))),
		"the settlement screen prints the exploration result (%s), got: %s" % [result_key, str(texts)])
	assert_true(_has_explore_block(screens[0]),
		"the exploration result is its own block, not merged into the contract rows")


func _has_explore_block(root: Node) -> bool:
	if String(root.name) == "ExploreBlock":
		return true
	for child in root.get_children():
		if _has_explore_block(child):
			return true
	return false


func _label_texts(root: Node, out: Array = []) -> Array:
	for child in root.get_children():
		if child is Label:
			out.append(String((child as Label).text))
		_label_texts(child, out)
	return out


func _label_text_contains(root: Node, needle: String) -> bool:
	for text in _label_texts(root):
		if String(text).contains(needle):
			return true
	return false


func _label_named(root: Node, label_name: String) -> Node:
	if String(root.name) == label_name:
		return root
	for child in root.get_children():
		var found := _label_named(child, label_name)
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


func _port_name(context: AppContext, port_id: String) -> String:
	var world := WorldOps.world_map(context.state)
	var port := world.get_port(port_id)
	if port.is_empty():
		return port_id
	return String(context.translate(port.name_key, port_id))


func _mount(seed_value: int) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY_BUILD, "seed": seed_value})
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


## Finds a deterministic seed whose risk roll produces an event **and offers a delayed
## option** (`add_delay_hours`), so the 4.3.5 hourly charge can be checked against a
## non-zero event delay. Returns `{event, option_id}` (empty when no seed qualifies).
func _force_delayed_event_context(context: AppContext, destination: String) -> Dictionary:
	var preview := context.commands.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	if not bool(preview.get("ok", false)):
		return {}
	var preview_data: Dictionary = preview.get("data", {})
	for seed_value in range(1, 400):
		context.rng = RngService.new(seed_value)
		var picked := VoyageService._pick_event(context, preview_data, destination)
		if picked.is_empty():
			continue
		var option_id := _offered_delay_option(context, picked)
		if option_id.is_empty():
			continue
		context.rng = RngService.new(seed_value)
		return {"event": picked, "option_id": option_id}
	return {}


## The first offered option whose effects contain `add_delay_hours` (empty when none).
func _offered_delay_option(context: AppContext, event: Dictionary) -> String:
	var template := context.registries.get_by_id(
		ContentTypes.VOYAGE_EVENT, String(event.get("event_id", ""))
	)
	if template == null:
		return ""
	var offered: Array = event.get("option_ids", [])
	for option in template.data.get("options", []):
		if not (option is Dictionary):
			continue
		var option_id := String((option as Dictionary).get("id", ""))
		if not offered.has(option_id):
			continue
		for effect in (option as Dictionary).get("effects", []):
			if effect is Dictionary and String((effect as Dictionary).get("op", "")) == "add_delay_hours":
				return option_id
	return ""


## 顶栏煤 / 水读数的当前文本（Label 会随页面重建被替换，所以每次重新取引用）。
func _hud_coal_text(shell: Control) -> String:
	return _hud_resource_text(shell._hud_coal_value)


func _hud_water_text(shell: Control) -> String:
	return _hud_resource_text(shell._hud_water_value)


func _hud_resource_text(label: Variant) -> String:
	if not (label is Label) or not is_instance_valid(label):
		return ""
	return String((label as Label).text)


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
