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
const SEA_CHART_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/sea_chart_screen.gd")
const SETTLEMENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/settlement_screen.gd")
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


## 探索演出 · 失败：发现 roll 高于概率 → 线索作废、漂流到最近的己知港（出发港），
## 结算页说明失败与额外损耗；演出同样走完整套流程。
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
	assert_true(ClueService.active(context.state).is_empty(), "a failed clue leaves the active list")
	assert_true(Array(context.state.ensure_clues().get("failed", [])).has(String(clue.get("id", ""))),
		"the clue is recorded as failed instead of being deleted")
	assert_true(float(explore_summary.get("durability_loss", 0.0)) > 0.0,
		"drifting costs durability")
	_assert_settlement_shows_explore_result(shell, context, "ui.explore.result.failed")


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

	assert_not_null(shell._presentation, "explore.start starts the presentation (status: %s)" % shell._status_message)
	assert_true(not shell._presentation_explore.is_empty(), "the shell stores the exploration presentation")
	var voyage: Variant = context.state.explore_voyage()
	assert_true(voyage is Dictionary, "explore.start writes the explore_voyage block (status: %s)" % shell._status_message)
	if voyage is Dictionary:
		(voyage as Dictionary)["outcome_roll"] = outcome_roll
	return shell._presentation_explore.duplicate(true)


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
