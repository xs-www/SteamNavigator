extends SceneTree
## @static-doc
## 作用：航行演出（海图系统阶段 3）的真实渲染截图工具。窗口模式挂载真正的
## `main.tscn`，用真实命令开一局、真实发出 `voyage.start`，然后按演出自身的
## 里程碑抓图：离港转艏 / 3D 离港 / 高位镜头 / 出航云层 / 海图近景 / 海图稳态 /
## 海图航行 / 入港推近 / 3D 入港 / 抵达结算。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_voyage_presentation.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/voyage_presentation/`）：
##   voyage_departure_turn.png    离港早期：船艏已原地转向出海方向，船还在泊位（F1）
##   voyage_departure_3d.png      3D 离港：船沿出海方向驶离泊位、镜头上升
##   voyage_departure_high.png    离港末段：≈83° 近垂直高位镜头（F2）
##   voyage_departure_clouds.png  出航云层盖住高位镜头
##   voyage_chart_near.png        海图刚接管、云层仍在散开：近景（F2，frame_scale > 2）
##   voyage_chart_steady.png      云层散尽：稳态取景铺满整窗（F2/F3，frame_scale ≈ 1）
##   voyage_at_sea.png            航行中：船 icon 压在金色航线折线上（F4）
##   voyage_arrival_approach.png  入港云层下：海图取景正在推近（F2，veil ≥ 0.6，frame_scale > 2）
##   voyage_arrival_3d.png        3D 入港：镜头下降、船从海侧驶入泊位
##   voyage_arrival.png           抵达结算页
##
## ## 契约与约束
## - 不想猜帧数：按演出自身的状态（阶段名 / `_presentation.veil` / 舞台
##   `voyage_progress()` / `ship_yaw()` / `camera_pitch_deg()` / 海图
##   `get_frame_scale()`）轮询里程碑，拿不到就以退出码 1 结束。
## - **硬性数值断言**（验收反馈 F1–F4 的回归锁）：
##   F1 离港 beat 20%–30% 位移 < 0.1 m 且艏向明显偏离驻泊 yaw；离港末帧艏向 =
##      出海方向（< 0.05 rad）；入港首帧艏向与之相同（接缝），末段回到驻泊 yaw。
##   F2 离港末帧相机俯角 ≥ 80°；海图接管近景 `frame_scale > 2`，稳态 ≈ 1；入港前
##      海图推近 `frame_scale > 2`。
##   F3 航行页海图尺寸铺满窗口（宽 ≥ 窗口宽-1，高 ≥ 窗口高-顶栏-航程条），不在
##      ScrollContainer 内；稳态 base_zoom = 小世界 cover（真实对局 160×160 世界
##      → ×9，不受手动缩放 ZOOM_MAX 限制），世界矩形覆盖整个 chart，航线不被裁。
##   F4 演出航线 > 2 点、两端 = 起终港世界坐标（< 0.01）、任意进度船位离折线
##      < 1 世界单位。
## - 先写 `res://tmp_voyage_*`，全部成功后才移入 `docs/`，失败不留半套。
## - 纯色/近纯色画面视为"读到未绘制纹理"，判失败；写完 PNG 会读回再验一次。
## - 120 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/voyage_presentation"
const WINDOW := Vector2i(1440, 900)
const SEED := 4321
const WATCHDOG_SECONDS := 120.0
const READY_TIMEOUT_SECONDS := 20.0
const TMP_PREFIX := "res://tmp_voyage_"

## F1: the opening share of the beat must turn the bow without making way.
const EARLY_SAMPLE_MIN := 0.20
const EARLY_SAMPLE_MAX := 0.30
const EARLY_MAX_SHIFT_METERS := 0.1
## F1: heading must equal the outbound bearing this closely at the cut.
const YAW_TOLERANCE := 0.05
## F2: the high departure shot is near vertical; the chart takeover is a near shot.
const DEPARTURE_MIN_PITCH_DEG := 80.0
const HIGH_SHOT_MIN_PITCH_DEG := 75.0
const CHART_NEAR_MIN_SCALE := 2.0
const CHART_STEADY_TOLERANCE := 0.01
## F4: the ship icon must sit on the route polyline within one world unit.
const ROUTE_MAX_DISTANCE := 1.0
const ROUTE_ENDPOINT_TOLERANCE := 0.01

const SHOTS := [
	{"file": "voyage_departure_turn.png", "label": "F1 离港转艏（船艏朝海、船在泊位）"},
	{"file": "voyage_departure_3d.png", "label": "3D 离港（沿海向驶离 + 镜头上升）"},
	{"file": "voyage_departure_high.png", "label": "F2 离港末段高位镜头"},
	{"file": "voyage_departure_clouds.png", "label": "出航云层"},
	{"file": "voyage_chart_near.png", "label": "F2 海图刚接管近景"},
	{"file": "voyage_chart_steady.png", "label": "F3 海图稳态铺满整窗"},
	{"file": "voyage_at_sea.png", "label": "F4 海图航行（船在航线折线上）"},
	{"file": "voyage_arrival_approach.png", "label": "F2 入港云层下海图推近"},
	{"file": "voyage_arrival_3d.png", "label": "3D 入港（镜头下降 + 船驶入）"},
	{"file": "voyage_arrival.png", "label": "抵达结算"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_voyage_presentation: timed out (%d s)" % int(WATCHDOG_SECONDS))
	_cleanup_tmp()
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · voyage presentation")
	await process_frame

	var context := _bootstrap()
	if context == null:
		_finish()
		return
	var started := context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": SEED})
	if not bool(started.get("ok", false)):
		_fail("run.start failed: %s" % str(started))
		_finish()
		return
	var main_contact: Variant = context.state.contracts().get("main", null)
	if not (main_contact is Dictionary):
		_fail("the run has no main contract to sail on")
		_finish()
		return
	var destination := String((main_contact as Dictionary).get("destination", ""))

	var scene: PackedScene = load(MAIN_SCENE)
	var shell: Control = scene.instantiate()
	root.add_child(shell)
	await _settle(6, 0.3)

	shell._run_command(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": "core:boiler_strategy/standard",
	})

	var departed_yaw := 0.0
	var outbound_yaw := 0.0
	var departure := await _run_departure(shell)
	if not bool(departure.get("ok", false)):
		_finish()
		return
	departed_yaw = float(departure.get("departed_yaw", 0.0))
	outbound_yaw = float(departure.get("outbound_yaw", 0.0))

	await _run_at_sea(shell, context)
	await _run_arrival(shell, departed_yaw)

	_commit_shots()
	_finish()


# ---------------------------------------------------------------------------
# F1/F2 — 3D departure beat: turn the bow, sail out, climb to the high shot.
# ---------------------------------------------------------------------------


## Plays and asserts the whole departure cut. Returns
## `{"ok": bool, "departed_yaw": float, "outbound_yaw": float}`.
func _run_departure(shell: Control) -> Dictionary:
	if not await _wait_until(func() -> bool:
			return _phase(shell) == "departure_3d" and _port_stage(shell) != null,
			READY_TIMEOUT_SECONDS, "departure beat"):
		return {"ok": false}
	var stage: PortStage = _port_stage(shell)
	if stage == null:
		_fail("F1/F2: no PortStage mounted for the departure cut")
		return {"ok": false}

	var berth := stage.ship_position()
	var moor_yaw := stage.ship_yaw()
	var outbound_yaw := _outbound_yaw_towards(stage, berth)
	var turn_span := absf(angle_difference(moor_yaw, outbound_yaw))
	print("[EVIDENCE] F1 baseline berth=%s moor_yaw=%.1f deg outbound_yaw=%.1f deg turn=%.1f deg" % [
		str(berth), rad_to_deg(moor_yaw), rad_to_deg(outbound_yaw), rad_to_deg(turn_span),
	])
	_assert_true(turn_span > 0.5,
		"F1 the departure really has a turn to make (%.1f deg > 28.6 deg)" % rad_to_deg(turn_span))

	var early_done := false
	var turn_shot := false
	var departure_shot := false
	var high_shot := false
	var high_pitch := 0.0
	# The stage's own `_process` resumes the station wheel the moment the beat
	# clears `_voyage_mode`, which snaps the hull from `SEA_HANDOFF` back onto its
	# berth inside the same frame (under the cloud veil). The "last beat frame"
	# therefore has to be sampled while the phase is still `departure_3d`, not
	# after the transition.
	var last_beat_progress := 0.0
	var last_beat_yaw := stage.ship_yaw()
	var last_beat_position := stage.ship_position()
	while _phase(shell) == "departure_3d":
		var progress := float(stage.voyage_progress())
		last_beat_progress = progress
		last_beat_yaw = stage.ship_yaw()
		last_beat_position = stage.ship_position()
		if not early_done and progress >= EARLY_SAMPLE_MIN:
			early_done = true
			var shifted := stage.ship_position().distance_to(berth)
			var deviated := absf(angle_difference(stage.ship_yaw(), moor_yaw))
			print("[EVIDENCE] F1 early (20%%-30%%) progress=%.3f shift=%.4f m yaw=%.1f deg deviation=%.1f deg (%.0f%% of the turn)" % [
				progress, shifted, rad_to_deg(stage.ship_yaw()),
				rad_to_deg(deviated), 100.0 * deviated / maxf(0.001, turn_span),
			])
			_assert_true(progress <= EARLY_SAMPLE_MAX,
				"F1 early sample lands inside 20%%-30%% (progress %.3f)" % progress)
			_assert_true(shifted < EARLY_MAX_SHIFT_METERS,
				"F1 the bow turns before any way is made (%.4f m < 0.1 m)" % shifted)
			_assert_true(deviated > turn_span * 0.3 and deviated > 0.1,
				"F1 the bow has clearly left the mooring yaw (%.1f deg, > 30%% of the turn)" % rad_to_deg(deviated))
		if not turn_shot and absf(angle_difference(stage.ship_yaw(), outbound_yaw)) < YAW_TOLERANCE \
				and progress < 0.7:
			turn_shot = true
			print("[EVIDENCE] F1 turn shot progress=%.3f yaw=%.1f deg (off outbound %.3f rad) shift=%.2f m pitch=%.1f deg" % [
				progress, rad_to_deg(stage.ship_yaw()),
				absf(angle_difference(stage.ship_yaw(), outbound_yaw)),
				stage.ship_position().distance_to(berth), stage.camera_pitch_deg(),
			])
			await _capture(String(SHOTS[0]["file"]), String(SHOTS[0]["label"]))
			continue
		if not departure_shot and progress >= 0.60:
			departure_shot = true
			print("[EVIDENCE] F1 sail-out shot progress=%.3f shift=%.2f m pitch=%.1f deg" % [
				progress, stage.ship_position().distance_to(berth), stage.camera_pitch_deg(),
			])
			await _capture(String(SHOTS[1]["file"]), String(SHOTS[1]["label"]))
			continue
		if not high_shot and progress >= 0.90:
			high_shot = true
			high_pitch = stage.camera_pitch_deg()
			print("[EVIDENCE] F2 high shot progress=%.3f pitch=%.2f deg height=%.1f m" % [
				progress, high_pitch, stage.camera_position().y,
			])
			_assert_true(high_pitch >= HIGH_SHOT_MIN_PITCH_DEG,
				"F2 the late departure shot is near vertical (%.1f deg >= 75 deg)" % high_pitch)
			await _capture(String(SHOTS[2]["file"]), String(SHOTS[2]["label"]))
			continue
		await process_frame

	if not early_done:
		_fail("F1 early 20%%-30%% milestone was never sampled")
	if not turn_shot:
		_fail("F1 turn milestone was never reached (the bow never met the outbound bearing)")
	if not departure_shot:
		_fail("F1 sail-out milestone was never reached")
	if not high_shot:
		_fail("F2 high shot milestone was never reached")

	# F1: the beat's last sampled frame must point straight out to sea and sit on
	# the sea handoff. Sampled inside the loop (the phase check is the exact beat
	# boundary), then re-checked after a few `_process` frames to prove the stage
	# now *holds* the hull there instead of dragging it back to the berth.
	var handoff_gap := last_beat_position.distance_to(PortStage.SEA_HANDOFF)
	print("[EVIDENCE] F1 departure last frame progress=%.3f yaw=%.2f deg outbound=%.2f deg diff=%.4f rad handoff_gap=%.3f m" % [
		last_beat_progress, rad_to_deg(last_beat_yaw), rad_to_deg(outbound_yaw),
		absf(angle_difference(last_beat_yaw, outbound_yaw)), handoff_gap,
	])
	_assert_true(absf(angle_difference(last_beat_yaw, outbound_yaw)) < YAW_TOLERANCE,
		"F1 the departure cut ends pointing straight out to sea (%.3f rad < 0.05)" % absf(angle_difference(last_beat_yaw, outbound_yaw)))
	_assert_true(handoff_gap < 1.0,
		"F1 the last departure frame is on the sea handoff (%.3f m < 1 m)" % handoff_gap)
	# F2: the camera pose survives the beat (nothing else drives it until arrival).
	var end_pitch := stage.camera_pitch_deg()
	print("[EVIDENCE] F2 departure end pitch=%.2f deg height=%.1f m" % [end_pitch, stage.camera_position().y])
	_assert_true(end_pitch >= DEPARTURE_MIN_PITCH_DEG,
		"F2 the departure cut ends almost vertical (%.1f deg >= 80 deg)" % end_pitch)
	# F1 hold (Lead 的 `_voyage_hold` 修复): after the cut the station wheel must not
	# drag the hull back to its berth under the veil — the handoff pose is the seam
	# between the 3D cut and the chart marker.
	await _settle(4, 0.0)
	var held_position := stage.ship_position()
	var held_yaw := stage.ship_yaw()
	var holding := stage.is_voyage_holding_handoff()
	print("[EVIDENCE] F1 handoff hold: holding=%s position=%s yaw=%.2f deg gap=%.4f m" % [
		str(holding), str(held_position), rad_to_deg(held_yaw),
		held_position.distance_to(PortStage.SEA_HANDOFF),
	])
	_assert_true(holding,
		"F1 the stage holds the handoff after the cut instead of resuming the station wheel")
	_assert_true(held_position.distance_to(PortStage.SEA_HANDOFF) < 0.01,
		"F1 the held hull stays on the sea handoff (%.4f m)" % held_position.distance_to(PortStage.SEA_HANDOFF))
	_assert_true(absf(angle_difference(held_yaw, outbound_yaw)) < YAW_TOLERANCE,
		"F1 the held hull keeps pointing out to sea (%.3f rad)" % absf(angle_difference(held_yaw, outbound_yaw)))

	# Shot 4 — clouds covering that high shot, halfway through the veil.
	if await _wait_until(func() -> bool:
			return shell._cloud_veil != null and float(shell._cloud_veil.cover) >= 0.45,
			READY_TIMEOUT_SECONDS, "departure veil"):
		await _settle(2, 0.0)
		await _capture(String(SHOTS[3]["file"]), String(SHOTS[3]["label"]))

	return {"ok": true, "departed_yaw": last_beat_yaw, "outbound_yaw": outbound_yaw}


# ---------------------------------------------------------------------------
# F2/F3/F4 — chart page: near shot at takeover, steady cover framing, route.
# ---------------------------------------------------------------------------


func _run_at_sea(shell: Control, context: AppContext) -> void:
	if not await _wait_until(func() -> bool:
			return shell._at_sea_screen != null and _phase(shell) == "at_sea",
			READY_TIMEOUT_SECONDS, "at-sea chart page"):
		return
	var at_sea: AtSeaScreen = shell._at_sea_screen
	if at_sea == null:
		_fail("F2/F3/F4: the at-sea page did not mount")
		return
	var chart: SNSeaChartView = at_sea.get_chart()
	if chart == null:
		_fail("F2/F3/F4: the at-sea page has no chart")
		return

	# F2 near shot: right after the chart takes over (clouds still clearing) the
	# presentation framing must already be a close-up that then pulls back.
	var near_scale := -1.0
	var near_veil := -1.0
	var valid_frames := 0
	while valid_frames < 5:
		await process_frame
		if not is_instance_valid(at_sea) or at_sea.get_chart() == null:
			break
		chart = at_sea.get_chart()
		if chart.size.x <= 1.0:
			continue
		valid_frames += 1
		near_scale = chart.get_frame_scale()
		near_veil = float(shell._presentation.veil) if shell._presentation != null else -1.0
		if near_scale > CHART_NEAR_MIN_SCALE:
			break
	print("[EVIDENCE] F2 chart takeover frame_scale=%.2f veil=%.2f chart.size=%s" % [
		near_scale, near_veil, str(chart.size),
	])
	_assert_true(near_scale > CHART_NEAR_MIN_SCALE,
		"F2 the chart takes over as a close-up (frame_scale %.2f > 2)" % near_scale)
	_assert_true(near_veil >= 0.5,
		"F2 the close-up is captured while the clouds are still clearing (veil %.2f >= 0.5)" % near_veil)

	# The takeover numbers above are the hard F2 evidence; the photo itself is
	# taken a few frames later (veil ~0.65) so the chart is actually readable
	# through the clearing clouds while the near framing is still in effect.
	var photo_scale := near_scale
	var photo_veil := near_veil
	if await _wait_until(func() -> bool:
			return shell._presentation != null \
				and _phase(shell) == "at_sea" \
				and float(shell._presentation.veil) <= 0.65,
			10.0, "near chart photo window"):
		if is_instance_valid(at_sea) and at_sea.get_chart() != null:
			photo_scale = at_sea.get_chart().get_frame_scale()
			photo_veil = float(shell._presentation.veil)
		print("[EVIDENCE] F2 near chart photo frame_scale=%.2f veil=%.2f" % [photo_scale, photo_veil])
		_assert_true(photo_scale > CHART_NEAR_MIN_SCALE,
			"F2 the near chart photo is still a close-up (frame_scale %.2f > 2 at veil %.2f)" % [
				photo_scale, photo_veil,
			])
	await _capture(String(SHOTS[4]["file"]), String(SHOTS[4]["label"]))

	# F2/F3 steady: once the veil is gone the framing settles at exactly 1x and
	# the whole chart page fills the window.
	if not await _wait_until(func() -> bool:
			return shell._presentation != null \
				and _phase(shell) == "at_sea" \
				and float(shell._presentation.veil) <= 0.001 \
				and float(shell._presentation.progress) >= 0.12,
			30.0, "steady chart framing"):
		return
	await _settle(2, 0.0)
	if not is_instance_valid(at_sea) or at_sea.get_chart() == null:
		_fail("F3: the at-sea page vanished before the steady framing check")
		return
	chart = at_sea.get_chart()
	var steady_scale := chart.get_frame_scale()
	print("[EVIDENCE] F2 steady frame_scale=%.4f base_zoom=%.3f" % [steady_scale, chart.get_base_zoom()])
	_assert_true(absf(steady_scale - 1.0) <= CHART_STEADY_TOLERANCE,
		"F2 the framing settles back to exactly 1x (%.4f)" % steady_scale)
	_assert_chart_fills_window(shell, at_sea, chart)
	_check_route(context, shell, at_sea, "steady")
	await _capture(String(SHOTS[5]["file"]), String(SHOTS[5]["label"]))

	# F4 shot: ship partway along the route, icon on the drawn golden polyline.
	if not await _wait_until(func() -> bool:
			return shell._presentation != null and float(shell._presentation.progress) >= 0.35,
			READY_TIMEOUT_SECONDS, "at-sea progress"):
		return
	await _settle(2, 0.0)
	if not is_instance_valid(at_sea) or at_sea.get_chart() == null:
		_fail("F4: the at-sea page vanished before the sailing check")
		return
	_check_route(context, shell, at_sea, "sailing")
	_check_route_at_progresses(at_sea)
	await _capture(String(SHOTS[6]["file"]), String(SHOTS[6]["label"]))


## F3: the at-sea chart is a full-window water plane under the floating chrome,
## never a letterboxed square inside the scrolling page stack.
func _assert_chart_fills_window(shell: Control, at_sea: AtSeaScreen, chart: SNSeaChartView) -> void:
	var chart_size := chart.size
	var chrome_height := 0.0
	if shell._top_chrome != null and is_instance_valid(shell._top_chrome):
		chrome_height = (shell._top_chrome as Control).size.y
	var strip_height := maxf(0.0, at_sea.size.y - chart_size.y)
	print("[EVIDENCE] F3 window=%s at_sea.size=%s chart.size=%s chrome_h=%.1f strip_h=%.1f" % [
		str(Vector2(WINDOW)), str(at_sea.size), str(chart_size), chrome_height, strip_height,
	])
	_assert_true(chart_size.x >= float(WINDOW.x) - 1.0,
		"F3 the chart fills the window width (%.1f >= %d)" % [chart_size.x, WINDOW.x - 1])
	_assert_true(chart_size.y >= float(WINDOW.y) - chrome_height - strip_height - 1.0,
		"F3 the chart fills the height above the voyage strip (%.1f >= %.1f)" % [
			chart_size.y, float(WINDOW.y) - chrome_height - strip_height - 1.0,
		])
	_assert_true(at_sea.size.x >= float(WINDOW.x) - 1.0 and at_sea.size.y >= float(WINDOW.y) - 1.0,
		"F3 the at-sea page itself is a full-window layer (%s)" % str(at_sea.size))

	var scroll_ancestor := ""
	var node: Node = chart
	while node != null:
		if node is ScrollContainer:
			scroll_ancestor = String(node.name)
		node = node.get_parent()
	_assert_true(scroll_ancestor.is_empty(),
		"F3 the chart is not clipped by a ScrollContainer" if scroll_ancestor.is_empty()
		else "F3 the chart sits inside ScrollContainer '%s'" % scroll_ancestor)
	_assert_true(chart.is_presentation_mode(), "F3 the chart uses the presentation (cover) framing")

	# 小世界 cover（验收反馈 F3）：真实对局的 `world_bounds` 只有 160×160，铺满
	# 1440 px 需要 ×9；演出取景的上限是 `PRESENTATION_ZOOM_MAX`，不受手动缩放的
	# `ZOOM_MAX=5` 限制，否则小世界又会缩回中间一块方形。
	var world: Dictionary = chart.view_model.get("world_bounds", {})
	var world_rect := Rect2(
		float(world.get("x", 0.0)), float(world.get("y", 0.0)),
		float(world.get("w", 400.0)), float(world.get("h", 400.0))
	)
	var cover_zoom := maxf(
		chart_size.x / maxf(1.0, world_rect.size.x),
		chart_size.y / maxf(1.0, world_rect.size.y)
	)
	var base_zoom := chart.get_base_zoom()
	var route := at_sea.get_route_path()
	print("[EVIDENCE] F3 world_bounds=%s chart.size=%s cover_zoom=%.3f base_zoom=%.3f zoom_max=%.1f presentation_zoom_max=%.1f route_points=%d" % [
		str(world_rect), str(chart_size), cover_zoom, base_zoom,
		SNSeaChartView.ZOOM_MAX, SNSeaChartView.PRESENTATION_ZOOM_MAX, route.size(),
	])
	_assert_true(absf(base_zoom - cover_zoom) <= cover_zoom * 0.01,
		"F3 the small world is scaled to cover the whole window (base_zoom %.3f vs cover %.3f, <1%% error)" % [
			base_zoom, cover_zoom,
		])
	_assert_true(base_zoom > SNSeaChartView.ZOOM_MAX,
		"F3 the presentation fit ignores the manual zoom cap (%.2f > ZOOM_MAX %.1f)" % [
			base_zoom, SNSeaChartView.ZOOM_MAX,
		])
	var top_left := chart.world_to_screen(world_rect.position)
	var bottom_right := chart.world_to_screen(world_rect.end)
	print("[EVIDENCE] F3 world corners on screen: top_left=%s bottom_right=%s chart_rect=(0,0,%s)" % [
		str(top_left), str(bottom_right), str(chart_size),
	])
	_assert_true(top_left.x <= 2.0 and top_left.y <= 2.0 \
			and bottom_right.x >= chart_size.x - 2.0 and bottom_right.y >= chart_size.y - 2.0,
		"F3 the mapped world covers the whole chart rect (corners %s .. %s within +-2 px)" % [
			str(top_left), str(bottom_right),
		])

	# The route (including both harbours) must never be the thing cover crops.
	var cropped := 0
	for point in route:
		var screen := chart.world_to_screen(point)
		if screen.x < -0.5 or screen.y < -0.5 \
				or screen.x > chart_size.x + 0.5 or screen.y > chart_size.y + 0.5:
			cropped += 1
	_assert_true(cropped == 0,
		"F3 the cover framing keeps the whole route on screen (%d cropped)" % cropped)


## F4: the presentation route comes from the world route table, and the ship
## icon actually rides it instead of a straight origin→destination line.
func _check_route(context: AppContext, shell: Control, at_sea: AtSeaScreen, tag: String) -> void:
	var route := at_sea.get_route_path()
	var ship := at_sea.get_ship_world_position()
	var distance := _distance_to_polyline(ship, route)
	print("[EVIDENCE] F4 (%s) route_points=%d progress=%.3f ship=%s distance_to_route=%.4f" % [
		tag, route.size(), at_sea.get_progress(), str(ship), distance,
	])
	_assert_true(route.size() > 2,
		"F4 the voyage follows the world route polyline (%d points > 2)" % route.size())
	_assert_true(distance < ROUTE_MAX_DISTANCE,
		"F4 the ship icon lies on the charted route (%.3f < 1 world unit)" % distance)

	var origin := String(shell._presentation_voyage.get("origin", ""))
	var destination := String(shell._presentation_voyage.get("destination", ""))
	var world_map: Variant = context.state.data.get("world_map", null)
	if not (world_map is Dictionary) or (world_map as Dictionary).is_empty():
		_fail("F4: the run has no world map to compare the route endpoints against")
		return
	var world := WorldMap.from_dict(world_map)
	var from_port := world.get_port(origin)
	var to_port := world.get_port(destination)
	if from_port.is_empty() or to_port.is_empty():
		_fail("F4: the world map does not know %s -> %s" % [origin, destination])
		return
	var from_position := Vector2(from_port.position)
	var to_position := Vector2(to_port.position)
	if route.is_empty():
		return
	var start_gap := route[0].distance_to(from_position)
	var end_gap := route[route.size() - 1].distance_to(to_position)
	print("[EVIDENCE] F4 (%s) start_gap=%.4f end_gap=%.4f" % [tag, start_gap, end_gap])
	_assert_true(start_gap < ROUTE_ENDPOINT_TOLERANCE,
		"F4 the route starts exactly on the departure harbour icon (%.4f)" % start_gap)
	_assert_true(end_gap < ROUTE_ENDPOINT_TOLERANCE,
		"F4 the route ends exactly on the destination harbour icon (%.4f)" % end_gap)


## F4: the icon must stay on the polyline at *any* progress, not just where the
## live animation happens to be sampled.
func _check_route_at_progresses(at_sea: AtSeaScreen) -> void:
	var route := at_sea.get_route_path()
	if route.size() < 2:
		return
	var worst := 0.0
	var worst_progress := 0.0
	for progress in [0.0, 0.17, 0.4, 0.63, 0.86, 1.0]:
		at_sea.set_presentation({"progress": progress})
		var distance := _distance_to_polyline(at_sea.get_ship_world_position(), route)
		if distance > worst:
			worst = distance
			worst_progress = progress
	print("[EVIDENCE] F4 arbitrary progress worst distance=%.4f at progress=%.2f" % [worst, worst_progress])
	_assert_true(worst < ROUTE_MAX_DISTANCE,
		"F4 the ship stays on the route at every progress (worst %.3f at %.2f)" % [worst, worst_progress])


# ---------------------------------------------------------------------------
# F1/F2 — 3D arrival beat: seam heading, then bow back to the mooring yaw.
# ---------------------------------------------------------------------------


func _run_arrival(shell: Control, departed_yaw: float) -> void:
	if not await _wait_until(func() -> bool:
			return _phase(shell) == "arrival_approach",
			READY_TIMEOUT_SECONDS * 2.0, "arrival approach"):
		return

	# F2 inverse: the chart pushes in while the arrival clouds cover it. The shell
	# now feeds `set_presentation()` through `_presentation_on_chart()` (which
	# includes ARRIVAL_APPROACH), so the chart's frame_scale must follow
	# `VoyagePresentation.chart_zoom_scale()` instead of freezing at 1x.
	var arrival_scale := -1.0
	var arrival_veil := -1.0
	var model_scale_max := 0.0
	var chart_scale_max := 0.0
	var approach_shot := false
	while _phase(shell) == "arrival_approach":
		await process_frame
		if shell._presentation == null:
			break
		model_scale_max = maxf(model_scale_max, float(shell._presentation.chart_zoom_scale()))
		if shell._at_sea_screen != null and is_instance_valid(shell._at_sea_screen):
			var chart: SNSeaChartView = shell._at_sea_screen.get_chart()
			if chart != null:
				chart_scale_max = maxf(chart_scale_max, chart.get_frame_scale())
			var veil := float(shell._presentation.veil)
			if not approach_shot and veil >= 0.60:
				approach_shot = true
				arrival_scale = chart.get_frame_scale() if chart != null else -1.0
				arrival_veil = veil
				print("[EVIDENCE] F2 arrival push-in photo frame_scale=%.2f veil=%.2f (model chart_zoom_scale=%.2f)" % [
					arrival_scale, arrival_veil, float(shell._presentation.chart_zoom_scale()),
				])
				_assert_true(arrival_scale > CHART_NEAR_MIN_SCALE,
					"F2 the chart pushes back in before arrival (frame_scale %.2f > 2 at veil %.2f)" % [
						arrival_scale, arrival_veil,
					])
				await _capture(String(SHOTS[7]["file"]), String(SHOTS[7]["label"]))
				continue
	print("[EVIDENCE] F2 arrival push-in max over ARRIVAL_APPROACH: chart_frame_scale=%.2f model_chart_zoom_scale=%.2f" % [
		chart_scale_max, model_scale_max,
	])
	_assert_true(approach_shot,
		"F2 the arrival push-in photo milestone was reached")
	_assert_true(chart_scale_max > CHART_NEAR_MIN_SCALE and model_scale_max > CHART_NEAR_MIN_SCALE,
		"F2 the chart framing follows the arrival push-in for the whole veil (chart max %.2f, model max %.2f, both > 2)" % [
			chart_scale_max, model_scale_max,
		])

	if not await _wait_until(func() -> bool:
			return _phase(shell) == "arrival_harbor" and _port_stage(shell) != null,
			READY_TIMEOUT_SECONDS, "3D arrival beat"):
		return
	var stage: PortStage = _port_stage(shell)
	if stage == null:
		_fail("F1/F2: no PortStage mounted for the arrival cut")
		return

	# F1 seam: the first arrival frame faces exactly the way departure vanished.
	var first_yaw := stage.ship_yaw()
	var first_pitch := stage.camera_pitch_deg()
	var seam := absf(angle_difference(first_yaw, departed_yaw))
	print("[EVIDENCE] F1 arrival first frame yaw=%.2f deg departed=%.2f deg seam=%.4f rad first_pitch=%.1f deg" % [
		rad_to_deg(first_yaw), rad_to_deg(departed_yaw), seam, first_pitch,
	])
	_assert_true(seam < YAW_TOLERANCE,
		"F1 the arrival opens on the exact heading the departure vanished with (%.3f rad < 0.05)" % seam)
	_assert_true(first_pitch >= DEPARTURE_MIN_PITCH_DEG,
		"F2 the arrival opens on the near-vertical high shot (%.1f deg >= 80 deg)" % first_pitch)
	# The arrival beat takes the hull back from the held handoff (Lead 的 hold 修复)：
	# `begin_arrival()` 必须清掉 hold，否则站点轮会继续压着船不动。
	print("[EVIDENCE] F1 arrival hold cleared: holding=%s" % str(stage.is_voyage_holding_handoff()))
	_assert_true(not stage.is_voyage_holding_handoff(),
		"F1 the arrival beat clears the departure handoff hold")

	var moor_yaw := stage.station_ship_yaw(stage.current_station())
	var last_yaw := first_yaw
	var last_progress := 0.0
	var last_pitch := first_pitch
	var arrival_shot := false
	while _phase(shell) == "arrival_harbor" and is_instance_valid(stage):
		var progress := float(stage.voyage_progress())
		last_progress = progress
		last_yaw = stage.ship_yaw()
		last_pitch = stage.camera_pitch_deg()
		if not arrival_shot and progress >= 0.45:
			arrival_shot = true
			await _capture(String(SHOTS[8]["file"]), String(SHOTS[8]["label"]))
			continue
		await process_frame
	print("[EVIDENCE] F1 arrival end progress=%.3f yaw=%.2f deg moor_yaw=%.2f deg diff=%.4f rad pitch=%.1f deg" % [
		last_progress, rad_to_deg(last_yaw), rad_to_deg(moor_yaw),
		absf(angle_difference(last_yaw, moor_yaw)), last_pitch,
	])
	_assert_true(absf(angle_difference(last_yaw, moor_yaw)) < YAW_TOLERANCE,
		"F1 the arrival swings the bow back onto the mooring yaw (%.3f rad < 0.05)" % absf(angle_difference(last_yaw, moor_yaw)))
	_assert_true(arrival_shot, "F1 the 3D arrival shot was captured")

	# Shot 10 — arrival settled, veil gone.
	if await _wait_until(func() -> bool:
			return shell._presentation == null and String(shell._active_screen) == "settlement",
			READY_TIMEOUT_SECONDS * 2.0, "arrival settlement"):
		await _settle(2, 0.0)
		await _capture(String(SHOTS[9]["file"]), String(SHOTS[9]["label"]))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _phase(shell: Control) -> String:
	if shell._presentation == null:
		return ""
	return String(shell._presentation.phase_name())


func _port_stage(shell: Control) -> PortStage:
	if not is_instance_valid(shell):
		return null
	var stage: Variant = shell._port_stage()
	if stage is PortStage:
		return stage as PortStage
	return null


## Heading from the berth toward `SEA_HANDOFF` on XZ. The model's bow points at +X
## at yaw 0 and Godot's positive Y rotation turns +X toward -Z, so a direction
## (dx, dz) maps to `atan2(-dz, dx)`.
func _outbound_yaw_towards(stage: PortStage, berth: Vector3) -> float:
	var delta := PortStage.SEA_HANDOFF - Vector3(berth.x, 0.0, berth.z)
	if Vector2(delta.x, delta.z).length() < 0.001:
		return stage.ship_yaw()
	return atan2(-delta.z, delta.x)


func _bootstrap() -> AppContext:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://preview_saves/voyage_presentation",
	})
	var context := bootstrap.context
	if context == null:
		_fail("bootstrap produced no AppContext")
		return null
	AppContext.set_active(context)
	return context


func _wait_until(predicate: Callable, timeout_seconds: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			print("[INFO] reached milestone: %s" % label)
			return true
		await process_frame
	_fail("milestone '%s' was never reached within %.0f s" % [label, timeout_seconds])
	return false


func _settle(frames: int, seconds: float) -> void:
	for i in frames:
		await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout
	for i in 3:
		await process_frame


func _capture(file_name: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport texture: " + label)
		return
	if image.get_width() != WINDOW.x or image.get_height() != WINDOW.y:
		_fail("capture size %dx%d does not match %dx%d (%s)" % [
			image.get_width(), image.get_height(), WINDOW.x, WINDOW.y, label,
		])
		return
	if _is_flat(image):
		_fail("flat image (nothing was drawn): " + label)
		return
	var absolute := ProjectSettings.globalize_path(TMP_PREFIX + file_name)
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("cannot save temp PNG %s (error=%d)" % [absolute, save_error])
		return
	# Read the file back: proves the PNG on disk decodes to a real frame, not a
	# blank texture that happened to pass the in-memory check.
	var read_back := Image.load_from_file(absolute)
	if read_back == null or read_back.is_empty():
		_fail("cannot read back the saved PNG: " + absolute)
		return
	if read_back.get_size() != image.get_size():
		_fail("read-back PNG size %s does not match %s (%s)" % [
			str(read_back.get_size()), str(image.get_size()), label,
		])
		return
	if _is_flat(read_back):
		_fail("read-back PNG is flat (nothing was drawn): " + label)
		return
	_saved.append(file_name)
	print("[PASS] captured %s -> %s" % [label, absolute])


func _is_flat(image: Image) -> bool:
	var colors := {}
	var step_x := maxi(1, image.get_width() / 24)
	var step_y := maxi(1, image.get_height() / 15)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			colors[image.get_pixel(x, y).to_rgba32()] = true
			if colors.size() > 8:
				return false
	return true


func _commit_shots() -> void:
	if _saved.size() != SHOTS.size():
		_cleanup_tmp()
		return
	var absolute_dir := ProjectSettings.globalize_path(OUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		_fail("cannot create output directory %s (error=%d)" % [absolute_dir, dir_error])
		_cleanup_tmp()
		return
	for file_name in _saved:
		var tmp_abs := ProjectSettings.globalize_path(TMP_PREFIX + file_name)
		var final_abs := absolute_dir.path_join(file_name)
		if FileAccess.file_exists(final_abs):
			DirAccess.remove_absolute(final_abs)
		var move_error := DirAccess.rename_absolute(tmp_abs, final_abs)
		if move_error != OK:
			_fail("cannot move %s -> %s (error=%d)" % [tmp_abs, final_abs, move_error])
		else:
			print("[PASS] saved %s" % final_abs)


func _cleanup_tmp() -> void:
	for shot in SHOTS:
		var tmp_abs := ProjectSettings.globalize_path(TMP_PREFIX + String(shot["file"]))
		if FileAccess.file_exists(tmp_abs):
			DirAccess.remove_absolute(tmp_abs)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	push_error("capture_voyage_presentation: " + message)
	print("[FAIL] " + message)


## Shortest distance from `point` to a polyline, in world units.
static func _distance_to_polyline(point: Vector2, polyline: PackedVector2Array) -> float:
	if polyline.size() < 2:
		return INF
	var best := INF
	for index in range(1, polyline.size()):
		best = minf(best, point.distance_to(
			Geometry2D.get_closest_point_to_segment(point, polyline[index - 1], polyline[index])
		))
	return best


static func _bounds_of_points(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for index in range(1, points.size()):
		rect = rect.expand(points[index])
	return rect


func _finish() -> void:
	if _failures > 0:
		_cleanup_tmp()
	print("=== voyage presentation capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
