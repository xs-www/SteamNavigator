extends SceneTree
## @static-doc
## 作用：探索系统（海图阶段 4.1）的真实渲染截图工具。窗口模式挂载真正的
## `main.tscn`，用真实命令开一局（seed 20260421）、真实 `clue.buy` 买线索、
## 真实 `explore.start` / `explore.settle` 走完整探索演出，按
## `docs/design/EXPLORATION_SYSTEM.md` §6 的里程碑抓图：海图线索可视化
## （level 2 方向箭头 / level 3 虚线圆 / level 4 `？港名？` + 面板线索区块）、
## 探索演出（世界航线 + 到搜索区的虚线预测线 + `?` 终点 + 航程条 `？`）、
## 结算页探索结果区块（发现 / 失败两条都拍）。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_exploration.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/exploration/`）：
##   exploration_chart_clues.png    海图线索：方向箭头、虚线圆、`？港名？`，选中线索高亮 + 右侧面板线索区块
##   exploration_chart_route.png    探索演出：世界航线 + 到 `?` 的虚线预测线 + 底部航程条目的地 `？`
##   exploration_arrival.png        第一次探索（发现）抵达结算：探索结果区块
##   exploration_result_found.png   另一次发现结算（不同港口）
##   exploration_result_failed.png  失败漂流结算：额外煤水 / 耐久损失 / 线索作废
##
## ## 契约与约束
## - 全程用真实领域入口：`run.start` / `clue.buy` / `ClueService.acquire`
##   （`RngService.STREAM_EXPLORATION` 命名流补充等级）/ 面板按钮 → `explore.start` →
##   Shell 在 `ARRIVAL_READY` 自动 `explore.settle`。发现/失败只用契约 §2 的
##   `outcome_roll`（出发时抽定，0 = 必发现、0.999 = 必失败）覆盖，不伪造结算结果。
## - 开始港若是 iron_harbour（无情报站），照 `framework/tests/cases/test_exploration.gd`
##   的做法补一个 `intel` 设施，`clue.buy` 本身仍是真实命令。
## - **硬性断言**（不满足 exit 1 但已抓到的图照存）：`sea_chart.view.clues` 不含
##   `target_port_id` / `credibility` / 真实 `search_zone`；面板线索文本非空且不含
##   `ui.*` 原始键名；探索中 `SNSeaChartView._unknown_destination` 非空、航程条目的地
##   显示 `？`、船 icon 沿航线切线；`explore.settle` 后成功当前港变为目标港 / 失败线索
##   进入 failed；结算 summary 含 `explore` 且结算页有 `ExploreBlock`。
## - 先写 `res://tmp_exploration_*`，全部 5 张成功后才移入 `docs/`，失败不留半套。
## - 纯色/近纯色画面视为"读到未绘制纹理"，判失败；写完 PNG 会读回再验一次。
## - 120 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/exploration"
const WINDOW := Vector2i(1440, 900)
const SEED := 20260421
const STEADY_BUILD := "core:starting_build/steady"
const STRATEGY_ID := "core:strategy/standard"
const WATCHDOG_SECONDS := 120.0
const TMP_PREFIX := "res://tmp_exploration_"
## Presentation clock step used when fast-forwarding the演出 (same as test_voyage_flow).
const DRIVE_STEP := 0.1
const MAX_DRIVE_SECONDS := 90.0
const MAX_CLUE_ATTEMPTS := 120
## 一张海图要同时看到三种线索图形，所以线索集必须覆盖 2 / 3 / 4 级。
const WANTED_LEVELS := [2, 3, 4]

const SEA_CHART_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/sea_chart_screen.gd")
const SETTLEMENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/settlement_screen.gd")

const SHOTS := [
	{"file": "exploration_chart_clues.png", "label": "海图线索（箭头 / 虚线圆 / ？港名？ + 选中面板）"},
	{"file": "exploration_chart_route.png", "label": "探索演出（虚线预测线 + ? 终点）"},
	{"file": "exploration_arrival.png", "label": "探索抵达结算（发现）"},
	{"file": "exploration_result_found.png", "label": "探索结算 · 发现"},
	{"file": "exploration_result_failed.png", "label": "探索结算 · 失败漂流"},
]

var _failures := 0
var _saved: Array[String] = []
var _clue_serial := 0


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_exploration: timed out (%d s)" % int(WATCHDOG_SECONDS))
	_cleanup_tmp()
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · exploration 4.1")
	await process_frame

	var context := _bootstrap()
	if context == null:
		_finish()
		return
	var started := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": SEED})
	if not bool(started.get("ok", false)):
		_fail("run.start failed: %s" % str(started))
		_finish()
		return

	var scene: PackedScene = load(MAIN_SCENE)
	if scene == null:
		_fail("cannot load " + MAIN_SCENE)
		_finish()
		return
	var shell: Control = scene.instantiate()
	root.add_child(shell)
	await _settle(8, 0.4)
	_force_chinese_locale(shell, context)
	await _settle(2, 0.0)
	_evidence_start(context)

	var prepared := _prepare_clues(context)
	if not bool(prepared.get("ok", false)):
		_finish()
		return

	# ── Shot 1: chart page with the clue layer and the selected clue panel. ──
	var selected := String(prepared["selected"])
	var screen: Variant = await _open_chart(shell)
	if screen == null:
		_finish()
		return
	screen._on_clue_clicked(selected)
	await _settle(6, 0.3)
	_assert_chart_view_contract(context, prepared)
	_assert_chart_visuals(context, screen, selected)
	await _capture(String(SHOTS[0]["file"]), String(SHOTS[0]["label"]))

	# ── Run A (found): sail the level>=3 clue, shoot the at-sea route, then the arrival. ──
	var info_a := await _start_exploration(shell, context, String(prepared["sail"]), 0.0)
	if not bool(info_a.get("ok", false)):
		_finish()
		return
	if not await _capture_route(shell, context, info_a):
		_finish()
		return
	if not await _drive_to_settlement(shell):
		_finish()
		return
	await _settle(8, 0.4)
	_assert_settlement(shell, context, info_a, "discovered", "arrival")
	await _capture(String(SHOTS[2]["file"]), String(SHOTS[2]["label"]))

	# ── Run B (failed): the level-2 (arrow) clue, forced failure + drift. ──
	var failed_id := String(prepared["failed"])
	_ensure_feasible(context, failed_id)
	var info_b := await _start_exploration(shell, context, failed_id, 0.999)
	if not bool(info_b.get("ok", false)):
		_finish()
		return
	if not await _drive_to_settlement(shell):
		_finish()
		return
	await _settle(8, 0.4)
	_assert_settlement(shell, context, info_b, "failed", "failed")
	await _capture(String(SHOTS[4]["file"]), String(SHOTS[4]["label"]))

	# ── Run C (found): the other level>=3 clue from wherever the drift left us. ──
	var found_id := String(prepared["found"])
	_ensure_feasible(context, found_id)
	var info_c := await _start_exploration(shell, context, found_id, 0.0)
	if not bool(info_c.get("ok", false)):
		_finish()
		return
	if not await _drive_to_settlement(shell):
		_finish()
		return
	await _settle(8, 0.4)
	_assert_settlement(shell, context, info_c, "discovered", "found")
	await _capture(String(SHOTS[3]["file"]), String(SHOTS[3]["label"]))

	_commit_shots()
	_finish()


# ---------------------------------------------------------------------------
# Setup: run + clues (real commands / real domain services)
# ---------------------------------------------------------------------------


## Fills the clue log with one clue of each level so the chart can show all three
## visual languages: 2 = direction arrow, 3 = dashed search circle, 4 = `？name？`.
## Returns `{ok, selected, sail, found, failed, levels}`.
func _prepare_clues(context: AppContext) -> Dictionary:
	var state: GameState = context.state
	var port_id := state.current_port_id()
	var port_data := MapOps.port(state.world(), port_id)
	var facilities: Array = port_data.get("facilities", [])
	var injected := false
	# iron_harbour (a port.hub archetype) has no intel office; the framework domain
	# tests add one for the buy gate, so the capture does the same and still buys
	# through the real `clue.buy` command.
	if not facilities.has("intel"):
		facilities.append("intel")
		injected = true
	print("[EVIDENCE] start port=%s facilities=%s intel_injected=%s" % [
		port_id, str(facilities), str(injected),
	])

	for index in 2:
		var result := context.commands.execute(&"clue.buy", {})
		if bool(result.get("ok", false)):
			var data: Dictionary = result.get("data", {})
			print("[EVIDENCE] clue.buy #%d ok cost=%d clue=%s money_after=%d level=%d" % [
				index + 1, int(data.get("cost", 0)), String(data.get("clue_id", "")),
				state.money(), int((data.get("clue", {}) as Dictionary).get("level", 0)),
			])
		else:
			_fail("clue.buy #%d failed: %s" % [index + 1, str(result.get("error_code", ""))])
	_evidence_clues(context, "after clue.buy")

	var rules := ExplorationRules.read(state, context.registries)
	var cap := int(rules.get("max_active_clues", 4))
	# Keep at most one clue per wanted level; duplicates go through the real
	# lifecycle (resolved) so the slot frees up for the missing level.
	var keep := {}
	for clue in ClueService.active(state).duplicate():
		var clue_id := String((clue as Dictionary).get("id", ""))
		var level := int((clue as Dictionary).get("level", 0))
		if WANTED_LEVELS.has(level) and not keep.has(level):
			keep[level] = clue_id
		else:
			ClueService.mark_resolved(state, clue_id)
			print("[EVIDENCE] resolved duplicate level-%d clue %s" % [level, clue_id])

	var attempts := 0
	while keep.size() < WANTED_LEVELS.size() and attempts < MAX_CLUE_ATTEMPTS:
		attempts += 1
		var wanted_level := -1
		for level in WANTED_LEVELS:
			if not keep.has(level):
				wanted_level = level
				break
		if wanted_level < 0:
			break
		if ClueService.active(state).size() >= cap:
			_fail("cannot free a clue slot while normalising the clue set")
			break
		var source := "rumor" if wanted_level == 2 else "intel"
		var clue := _acquire_clue(context, source)
		if clue.is_empty():
			continue
		var clue_id := String(clue.get("id", ""))
		var level := int(clue.get("level", 0))
		if level == wanted_level and not keep.has(level):
			keep[level] = clue_id
			print("[EVIDENCE] acquired level-%d %s clue %s (attempt %d)" % [
				level, source, clue_id, attempts,
			])
		else:
			ClueService.mark_resolved(state, clue_id)

	_assert_eq(keep.size(), WANTED_LEVELS.size(),
		"the clue log covers levels 2 (arrow) / 3 (circle) / 4 (name)")
	if keep.size() < WANTED_LEVELS.size():
		return {"ok": false}
	_evidence_clues(context, "normalised")

	# The chart shot highlights the level-4 clue (dashed circle + `？name？`), the
	# first exploration sails a level>=3 clue.
	var selected := String(keep[4])
	var candidates: Array[String] = [String(keep[4]), String(keep[3])]
	var sail := ""
	var other := ""
	for candidate in candidates:
		var preview := _ensure_feasible(context, candidate)
		if bool(preview.get("feasible", false)):
			if sail.is_empty():
				sail = candidate
			else:
				other = candidate
	_assert_true(not sail.is_empty(), "at least one level>=3 clue is feasible to sail on")
	if sail.is_empty():
		return {"ok": false}
	if other.is_empty():
		other = String(keep[3]) if sail == String(keep[4]) else String(keep[4])
		_ensure_feasible(context, other)
	_assert_true(other != sail, "the two level>=3 clues are distinct")
	return {
		"ok": true,
		"selected": selected,
		"sail": sail,
		"found": other,
		"failed": String(keep[2]),
		"levels": keep,
	}


func _acquire_clue(context: AppContext, source: String) -> Dictionary:
	_clue_serial += 1
	# Same named stream the domain uses (`RngService.STREAM_EXPLORATION`); a unique
	# key per call keeps the capture deterministic without touching any save file.
	var rng := context.rng.make_stream(
		RngService.STREAM_EXPLORATION, "capture:%s:%d" % [source, _clue_serial]
	)
	return ClueService.acquire(context, source, rng)


func _preview(context: AppContext, clue_id: String) -> Dictionary:
	var result := ExplorationCalculator.preview(context, clue_id, STRATEGY_ID)
	if not bool(result.get("ok", false)):
		return {
			"feasible": false,
			"blockers": [{
				"code": String(result.get("error_code", "")),
				"message_key": String(result.get("message_key", "")),
			}],
		}
	return result.get("data", {})


## Exploration preview; when it is not feasible, buy real supplies through the real
## `supply.*` commands (costs gold, adds weight — never invents stock) and re-check.
func _ensure_feasible(context: AppContext, clue_id: String) -> Dictionary:
	var preview := _preview(context, clue_id)
	if bool(preview.get("feasible", false)):
		_print_preview(clue_id, preview)
		return preview
	for _attempt in 3:
		var blockers: Array = preview.get("blockers", [])
		for blocker in blockers:
			if not (blocker is Dictionary):
				continue
			match String((blocker as Dictionary).get("code", "")):
				"insufficient_coal":
					var coal := context.commands.execute(&"supply.buy_coal", {"amount": 10})
					print("[EVIDENCE] top-up coal ok=%s error=%s" % [
						str(coal.get("ok", false)), str(coal.get("error_code", "")),
					])
				"insufficient_water":
					var water := context.commands.execute(&"supply.buy_water", {"amount": 8})
					print("[EVIDENCE] top-up water ok=%s error=%s" % [
						str(water.get("ok", false)), str(water.get("error_code", "")),
					])
				_:
					pass
		preview = _preview(context, clue_id)
		if bool(preview.get("feasible", false)):
			break
	_print_preview(clue_id, preview)
	return preview


func _print_preview(clue_id: String, preview: Dictionary) -> void:
	var blockers: Array = preview.get("blockers", [])
	var codes: Array = []
	for blocker in blockers:
		if blocker is Dictionary:
			codes.append(String((blocker as Dictionary).get("code", "")))
	print("[EVIDENCE] preview %s feasible=%s distance=%.1f hours=%.2f coal=%.2f/%.2f water=%.2f/%.2f wages=%d risk=%.3f discovery_chance=%.3f blockers=%s" % [
		clue_id, str(preview.get("feasible", false)),
		float(preview.get("distance", 0.0)), float(preview.get("duration_hours", 0.0)),
		float(preview.get("coal_required", 0.0)), float(preview.get("coal_available", 0.0)),
		float(preview.get("water_required", 0.0)), float(preview.get("water_available", 0.0)),
		int(preview.get("crew_wages", 0)), float(preview.get("risk_score", 0.0)),
		float(preview.get("discovery_chance", 0.0)), str(codes),
	])


func _evidence_start(context: AppContext) -> void:
	var state: GameState = context.state
	var world := WorldOps.world_map(state)
	print("[EVIDENCE] run seed=%d start_port=%s money=%d coal=%.1f water=%.1f durability=%.1f" % [
		SEED, state.current_port_id(), state.money(),
		float(state.ship().get("coal", 0.0)), float(state.ship().get("water", 0.0)),
		float(state.ship().get("durability", 0.0)),
	])
	print("[EVIDENCE] world ports=%d discovered=%s eligible_targets=%s" % [
		world.ports.size(),
		str(state.campaign_world().get("discovered_port_ids", [])),
		str(ClueService.eligible_target_ids(state)),
	])


func _evidence_clues(context: AppContext, tag: String) -> void:
	var state: GameState = context.state
	var world := WorldOps.world_map(state)
	print("[EVIDENCE] clues (%s): active=%d failed=%s resolved=%s" % [
		tag, ClueService.active(state).size(),
		str(state.ensure_clues().get("failed", [])),
		str(state.ensure_clues().get("resolved", [])),
	])
	for clue in ClueService.active(state):
		if not (clue is Dictionary):
			continue
		var entry: Dictionary = clue
		var target := String(entry.get("target_port_id", ""))
		var zone: Dictionary = entry.get("search_zone", {})
		print("[EVIDENCE]   %s level=%d source=%s target=%s level-name-key=%s credibility=%.3f dir=%.3f zone=(%.1f,%.1f,r=%.1f)" % [
			String(entry.get("id", "")), int(entry.get("level", 0)),
			String(entry.get("source_key", "")), target,
			WorldOps.port_display_key(world, target),
			float(entry.get("credibility", 0.0)), float(entry.get("direction_angle", 0.0)),
			float(zone.get("x", 0.0)), float(zone.get("y", 0.0)), float(zone.get("radius", 0.0)),
		])


# ---------------------------------------------------------------------------
# Chart page: clue layer + panel (contract §5/§6)
# ---------------------------------------------------------------------------


func _open_chart(shell: Control) -> Variant:
	shell._active_screen = "sea_chart"
	shell._refresh()
	await _settle(8, 0.35)
	var screens := _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	_assert_eq(screens.size(), 1, "the sea chart page is mounted")
	if screens.is_empty():
		return null
	return screens[0]


func _chart_view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"sea_chart.view", {"strategy_id": STRATEGY_ID})
	_assert_true(bool(result.get("ok", false)), "sea_chart.view succeeds")
	return result.get("data", {})


## Contract §5: the query trims secrets — no target id, no credibility, no raw zone
## centre; circle only from level 3, name_key only at level 4.
func _assert_chart_view_contract(context: AppContext, prepared: Dictionary) -> void:
	var view := _chart_view(context)
	var clues: Array = view.get("clues", [])
	_assert_true(clues.size() >= 3, "sea_chart.view exposes the clue layer (%d clues)" % clues.size())
	var levels := {}
	for entry in clues:
		if not (entry is Dictionary):
			continue
		var clue: Dictionary = entry
		var level := int(clue.get("level", 0))
		levels[level] = true
		_assert_false(clue.has("target_port_id"), "level %d view never leaks target_port_id" % level)
		_assert_false(clue.has("credibility"), "level %d view never leaks credibility" % level)
		_assert_false(clue.has("search_zone"), "level %d view never leaks the true search zone" % level)
		var circle: Variant = clue.get("circle", null)
		_assert_eq(circle != null, level >= 3, "level %d circle disclosure" % level)
		var name_key := String(clue.get("name_key", ""))
		if level >= 4:
			_assert_true(not name_key.is_empty(), "level 4 view reveals the harbour name key")
		else:
			_assert_eq(name_key, "", "level %d view hides the harbour name" % level)
		var estimated: Dictionary = clue.get("estimated", {})
		_assert_true(estimated.has("feasible"), "level %d view carries the feasibility estimate" % level)
		_assert_true(estimated.has("discovery_chance"), "level %d view carries the display discovery chance" % level)
		if level >= 3:
			var zone := _domain_zone(context, String(clue.get("id", "")))
			var view_circle: Dictionary = clue.get("circle", {})
			_assert_almost_eq(float(view_circle.get("x", 0.0)), float(zone.get("x", 0.0)), 0.001,
				"level %d circle x equals the fuzzed search centre" % level)
			_assert_almost_eq(float(view_circle.get("y", 0.0)), float(zone.get("y", 0.0)), 0.001,
				"level %d circle y equals the fuzzed search centre" % level)
		print("[EVIDENCE] chart clue %s level=%d source=%s direction=%.3f circle=%s name_key=%s chance=%.3f feasible=%s" % [
			String(clue.get("id", "")), level, String(clue.get("source_key", "")),
			float(clue.get("direction_angle", 0.0)), str(circle), name_key,
			float(estimated.get("discovery_chance", 0.0)), str(estimated.get("feasible", false)),
		])
	_assert_true(levels.has(2) and levels.has(3) and levels.has(4),
		"the chart sees all three clue levels (2 arrow / 3 circle / 4 name): %s" % str(levels))
	_assert_false(bool((view.get("explore", {}) as Dictionary).get("active", true)),
		"the chart reports no active exploration before sailing")
	var can_buy: Dictionary = view.get("can_buy_clue", {})
	print("[EVIDENCE] can_buy_clue=%s" % str(can_buy))
	var expected_levels: Dictionary = prepared.get("levels", {})
	_assert_eq(ClueService.active(context.state).size(), expected_levels.size(),
		"the normalised clue log is exactly the three visual levels")


func _domain_clue(context: AppContext, clue_id: String) -> Dictionary:
	return ClueService.find_clue(context.state, clue_id)


func _domain_zone(context: AppContext, clue_id: String) -> Dictionary:
	return _domain_clue(context, clue_id).get("search_zone", {})


## Renders-side assertions for shot 1: geometry for every clue, selected highlight,
## panel text (real localized content, no raw keys, no secret leakage).
func _assert_chart_visuals(context: AppContext, screen: Variant, selected_id: String) -> void:
	var chart: SNSeaChartView = screen._chart
	var panel: SNSeaChartPanel = screen._panel
	_assert_true(chart != null, "the chart screen mounts the chart view")
	_assert_true(panel != null, "the chart screen mounts the clue panel")
	if chart == null or panel == null:
		return
	_assert_true(chart.size.x > 200.0 and chart.size.y > 200.0,
		"the chart has a real layout size (%s)" % str(chart.size))
	_assert_eq(chart.get_selected_clue(), selected_id, "the clicked clue is highlighted on the chart")
	var rect := Rect2(Vector2.ZERO, chart.size)
	var view_clues: Array = chart.get_clues()
	_assert_eq(view_clues.size(), ClueService.active(context.state).size(),
		"every active clue is drawn on the chart")
	for entry in view_clues:
		if not (entry is Dictionary):
			continue
		var clue: Dictionary = entry
		var clue_id := String(clue.get("id", ""))
		var level := int(clue.get("level", 0))
		var geometry := chart.clue_screen_geometry(clue)
		print("[EVIDENCE] chart geometry %s level=%d kind=%s data=%s" % [
			clue_id, level, String(geometry.get("kind", "")), str(geometry),
		])
		match String(geometry.get("kind", "")):
			"circle":
				var center: Vector2 = geometry.get("center", Vector2.ZERO)
				var radius := float(geometry.get("radius", 0.0))
				_assert_true(radius >= 2.0, "%s draws a visible dashed circle (r=%.1f px)" % [clue_id, radius])
				_assert_true(rect.grow(2.0).has_point(center),
					"%s search circle sits inside the chart (%s)" % [clue_id, str(center)])
				var domain_target := _target_position(context, clue_id)
				var domain_zone := _domain_zone(context, clue_id)
				var offset := Vector2(
					float(domain_zone.get("x", 0.0)), float(domain_zone.get("y", 0.0))
				).distance_to(domain_target)
				_assert_true(offset > 0.05,
					"%s circle centre is fuzzed off the true harbour (%.2f world units)" % [clue_id, offset])
			"arrow":
				var start: Vector2 = geometry.get("start", Vector2.ZERO)
				var end: Vector2 = geometry.get("end", Vector2.ZERO)
				_assert_true(start.distance_to(end) >= 8.0,
					"%s draws a visible direction arrow (%.1f px)" % [clue_id, start.distance_to(end)])
				_assert_true(rect.grow(2.0).has_point(start) and rect.grow(2.0).has_point(end),
					"%s arrow stays inside the chart" % clue_id)
				var reference: Variant = _reference_screen_position(chart, clue)
				if reference != null:
					_assert_true(start.distance_to(reference) < 1.0,
						"%s arrow starts exactly on the reference harbour" % clue_id)
			_:
				_assert_eq(level, 1, "level %d clue has chart geometry" % level)

	# Level-4 name text must be `？<localized port name>？`.
	var selected_clue: Dictionary = chart.clue_by_id(selected_id)
	var selected_level := int(selected_clue.get("level", 0))
	_assert_true(selected_level >= 3, "the screenshot highlights a level>=3 clue (level %d)" % selected_level)
	var name_text := String(chart._clue_name_text(String(selected_clue.get("name_key", ""))))
	if selected_level >= 4:
		var display_key := String(selected_clue.get("name_key", ""))
		var port_name := String(context.translate(display_key))
		_assert_true(name_text.begins_with("？") and name_text.ends_with("？"),
			"the level-4 clue renders as ？port？ (%s)" % name_text)
		_assert_true(name_text.contains(port_name),
			"the ？port？ text uses the localized harbour name (%s)" % name_text)
	else:
		_assert_true(name_text.contains("?"), "the level-3 clue centre shows a ? marker")

	# Panel: bound clue + readable localized rows + the real explore button.
	_assert_eq(String(panel.get_clue().get("id", "")), selected_id,
		"the panel shows the clicked clue")
	var labels := _label_texts(panel)
	var texts: Array[String] = []
	for label in labels:
		texts.append(String(label))
	var joined := "\n".join(texts)
	print("[EVIDENCE] panel labels (%d): %s" % [texts.size(), str(texts)])
	_assert_true(texts.size() >= 6, "the clue panel has a full info block (%d labels)" % texts.size())
	var blank := 0
	for text in texts:
		if text.strip_edges().is_empty():
			blank += 1
	_assert_eq(blank, 0, "the clue panel has no blank labels")
	_assert_eq(joined.find("ui."), -1, "the panel never renders raw ui.* localization keys")
	var title := String(context.translate("ui.clue.section_title"))
	var level_text := String(context.translate("ui.clue.level.%d" % selected_level))
	var source_key := String(panel.get_clue().get("source_display_key", ""))
	if source_key.is_empty():
		source_key = "ui.clue.source." + String(panel.get_clue().get("source_key", ""))
	var source_text := String(context.translate(source_key))
	_assert_true(joined.contains(title), "the panel shows the clue section title (%s)" % title)
	_assert_true(joined.contains(level_text), "the panel shows the clue level (%s)" % level_text)
	_assert_true(joined.contains(source_text), "the panel shows the clue source (%s)" % source_text)
	var direction_angle := float(panel.get_clue().get("direction_angle", 0.0))
	if selected_level >= 2:
		var compass := SNSeaChartPanel.compass_key(direction_angle)
		var compass_text := String(context.translate("ui.clue.direction." + compass))
		_assert_true(joined.contains(compass_text),
			"the panel shows the 8-point direction (%s)" % compass_text)
	_assert_true(joined.contains("–") or joined.contains("小时") or joined.contains("hour"),
		"the panel shows the estimated distance range")
	var target_id := String(_domain_clue(context, selected_id).get("target_port_id", ""))
	_assert_false(joined.contains(target_id),
		"the panel never prints the secret target port id (%s)" % target_id)
	var explore_button := _button_by_text(screen, String(context.translate("ui.button.explore_clue")))
	_assert_true(explore_button != null, "the panel offers the explore button")
	if explore_button != null:
		_assert_false(explore_button.disabled, "the explore button is enabled for a feasible clue")
	var can_buy: Dictionary = _chart_view(context).get("can_buy_clue", {})
	if bool(can_buy.get("available", false)):
		var purchase_button := _button_by_text(
			screen, String(context.translate("ui.button.buy_clue")) % int(can_buy.get("cost", 0))
		)
		_assert_true(purchase_button != null, "the panel offers the buy-clue button")
	else:
		print("[EVIDENCE] buy-clue button hidden (reason: %s)" % String(can_buy.get("reason_key", "")))


func _target_position(context: AppContext, clue_id: String) -> Vector2:
	var clue := _domain_clue(context, clue_id)
	var world := WorldOps.world_map(context.state)
	var port := world.get_port(String(clue.get("target_port_id", "")))
	return port.position if not port.is_empty() else Vector2.ZERO


func _reference_screen_position(chart: SNSeaChartView, clue: Dictionary) -> Variant:
	var reference_id := String(clue.get("reference_port_id", ""))
	for port_data in chart.view_model.get("ports", []):
		if String((port_data as Dictionary).get("id", "")) == reference_id:
			return chart.world_to_screen(Vector2(
				float((port_data as Dictionary).get("x", 0.0)),
				float((port_data as Dictionary).get("y", 0.0))
			))
	return null


# ---------------------------------------------------------------------------
# Exploration presentation: sail → at-sea route shot → settlement
# ---------------------------------------------------------------------------


## Opens the chart page, clicks a clue, presses the real panel button and forces the
## departure-time discovery roll (contract §2). Returns the voyage evidence block.
func _start_exploration(
	shell: Control, context: AppContext, clue_id: String, outcome_roll: float
) -> Dictionary:
	var preview := _preview(context, clue_id)
	var screen: Variant = await _open_chart(shell)
	if screen == null:
		return {"ok": false}
	screen._on_clue_clicked(clue_id)
	await _settle(4, 0.15)
	var panel: SNSeaChartPanel = screen._panel
	if panel == null or String(panel.get_clue().get("id", "")) != clue_id:
		_fail("the clue panel did not bind %s before sailing" % clue_id)
		return {"ok": false}
	var button := _button_by_text(screen, String(context.translate("ui.button.explore_clue")))
	if button == null:
		_fail("the clue panel has no explore button for %s" % clue_id)
		return {"ok": false}
	_assert_false(button.disabled, "the explore button is enabled for %s" % clue_id)
	button.pressed.emit()
	if shell._presentation == null:
		_fail("explore.start did not hand over to the presentation (status: %s)" % shell._status_message)
		return {"ok": false}
	var voyage_value: Variant = context.state.explore_voyage()
	if not (voyage_value is Dictionary):
		_fail("explore.start did not write explore_voyage (status: %s)" % shell._status_message)
		return {"ok": false}
	var voyage: Dictionary = voyage_value
	voyage["outcome_roll"] = outcome_roll
	var origin := String(voyage.get("origin", ""))
	var target := String(voyage.get("target_port_id", ""))
	var presentation: Dictionary = shell._presentation_explore.duplicate(true)
	var zone: Dictionary = presentation.get("zone", {})
	print("[EVIDENCE] explore.start clue=%s origin=%s target=%s roll=%.3f hours=%.2f coal=%.2f water=%.2f origin_zone=(%.1f,%.1f)" % [
		clue_id, origin, target, outcome_roll,
		float(voyage.get("duration_hours", 0.0)),
		float(voyage.get("coal_used", 0.0)), float(voyage.get("water_used", 0.0)),
		float(zone.get("x", 0.0)), float(zone.get("y", 0.0)),
	])
	var info := {
		"ok": true,
		"clue_id": clue_id,
		"origin": origin,
		"target": target,
		"outcome_roll": outcome_roll,
		"presentation": presentation,
		"preview": preview,
	}
	_assert_true(String(presentation.get("kind", "")) == "explore",
		"explore.start returns an exploration presentation")
	_assert_eq(String(presentation.get("clue_id", "")), clue_id,
		"the presentation carries the clue id")
	_assert_eq(String(shell._presentation.phase_name()), "departure_3d",
		"the 3D departure cut starts the exploration演出")
	return info


func _capture_route(shell: Control, context: AppContext, info: Dictionary) -> bool:
	var reached := _drive_until(shell, func() -> bool:
		return shell._presentation != null \
			and String(shell._presentation.phase_name()) == "at_sea" \
			and float(shell._presentation.veil) <= 0.001 \
			and float(shell._presentation.progress) >= 0.35, MAX_DRIVE_SECONDS)
	if not reached:
		_fail("the exploration演出 never reached at_sea with progress >= 0.35")
		return false
	await _settle(8, 0.25)
	var at_sea: AtSeaScreen = shell._at_sea_screen
	if at_sea == null:
		_fail("the at-sea chart page did not mount during the exploration")
		return false
	var chart: SNSeaChartView = at_sea.get_chart()
	if chart == null:
		_fail("the at-sea page has no chart")
		return false
	var presentation: Dictionary = info.get("presentation", {})
	var zone: Dictionary = presentation.get("zone", {})
	var zone_position := Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))
	var progress := at_sea.get_progress()
	print("[EVIDENCE] at_sea progress=%.3f phase=%s veil=%.3f chart.size=%s zoom=%.2f" % [
		progress, String(shell._presentation.phase_name()), float(shell._presentation.veil),
		str(chart.size), chart.get_base_zoom(),
	])

	# Contract §6: the unknown search zone becomes a dashed prediction line + `?`.
	var unknown := at_sea.get_unknown_destination()
	_assert_true(not unknown.is_empty(), "the exploration page carries the unknown destination")
	_assert_eq(String(unknown.get("label_key", "")), "ui.label.unknown_destination",
		"the ? marker is localized")
	_assert_almost_eq(float(unknown.get("x", 0.0)), zone_position.x, 0.001,
		"the ? marker sits on the search-zone x")
	_assert_almost_eq(float(unknown.get("y", 0.0)), zone_position.y, 0.001,
		"the ? marker sits on the search-zone y")
	_assert_true(chart.has_unknown_destination(),
		"the chart draws the unknown-destination overlay (has_unknown_destination)")
	_assert_true(not (chart._unknown_destination as Dictionary).is_empty(),
		"SNSeaChartView._unknown_destination is populated during the exploration")
	var marker_screen := chart.world_to_screen(zone_position)
	var chart_rect := Rect2(Vector2.ZERO, chart.size)
	_assert_true(chart_rect.grow(2.0).has_point(marker_screen),
		"the ? marker is inside the chart rect (%s)" % str(marker_screen))
	# The floating top chrome covers the chart's top strip; record whether the `?`
	# endpoint lands under it (the at-sea chart is a full-window layer, F3).
	var chrome_height := 0.0
	if shell._top_chrome != null and is_instance_valid(shell._top_chrome):
		chrome_height = (shell._top_chrome as Control).size.y
	print("[EVIDENCE] unknown destination world=%s screen=%s top_chrome_h=%.1f under_chrome=%s" % [
		str(zone_position), str(marker_screen), chrome_height,
		str(marker_screen.y < chrome_height),
	])

	# The voyage route itself: a real polyline ending at the search zone, not a port.
	var route := at_sea.get_route_path()
	_assert_true(route.size() >= 2, "the exploration route is a real polyline (%d points)" % route.size())
	if route.size() >= 2:
		var end_gap := route[route.size() - 1].distance_to(zone_position)
		print("[EVIDENCE] route points=%d end_gap_to_zone=%.3f first=%s last=%s" % [
			route.size(), end_gap, str(route[0]), str(route[route.size() - 1]),
		])
		_assert_true(end_gap < 1.0, "the voyage route ends at the search zone (%.3f < 1)" % end_gap)
		var start_gap := route[0].distance_to(_port_position(context, String(info.get("origin", ""))))
		_assert_true(start_gap < 1.0, "the voyage route starts at the departure harbour (%.3f)" % start_gap)

	# The strip must show `？` instead of a destination harbour name.
	var route_label := _label_named(at_sea, "RouteLabel") as Label
	_assert_true(route_label != null, "the voyage strip has a route label")
	if route_label != null:
		var strip_text := route_label.text
		print("[EVIDENCE] voyage strip text=%s" % strip_text)
		_assert_true(strip_text.contains("？"), "the voyage strip destination reads ？ (%s)" % strip_text)
		_assert_true(strip_text.contains(_port_name(context, String(info.get("origin", "")))),
			"the voyage strip still names the departure harbour (%s)" % strip_text)
	var bar := _progress_bar(at_sea)
	_assert_true(bar != null, "the voyage strip has a progress bar")
	if bar != null:
		_assert_almost_eq(bar.value, progress * 100.0, 1.0,
			"the progress bar matches the presentation progress")

	# Planar ship icon still rides the route and keeps pointing along its tangent.
	var ship := at_sea.get_ship_world_position()
	var heading := at_sea.get_ship_heading()
	var expected_heading := _route_heading(route, progress)
	var off_route := _distance_to_polyline(ship, route)
	print("[EVIDENCE] ship world=%s heading=%.4f expected=%.4f deviation=%.4f rad off_route=%.3f chart_heading=%.4f" % [
		str(ship), heading, expected_heading,
		absf(angle_difference(heading, expected_heading)), off_route, chart.get_ship_heading(),
	])
	_assert_true(off_route < 1.0, "the ship icon rides the exploration polyline (%.3f < 1)" % off_route)
	_assert_true(absf(angle_difference(heading, expected_heading)) < 0.05,
		"the ship heading follows the route tangent (%.4f rad)" % absf(angle_difference(heading, expected_heading)))
	_assert_true(chart.has_ship_heading(), "the chart received the ship heading")
	_assert_almost_eq(chart.get_ship_heading(), heading, 0.0001,
		"the chart icon uses the same heading as the voyage strip")

	await _capture(String(SHOTS[1]["file"]), String(SHOTS[1]["label"]))
	return true


func _drive_to_settlement(shell: Control) -> bool:
	var reached := _drive_until(shell, func() -> bool:
		return shell._presentation == null and String(shell._active_screen) == "settlement",
		MAX_DRIVE_SECONDS)
	if not reached:
		_fail("the exploration演出 never reached the settlement screen")
		return false
	print("[EVIDENCE] settlement reached active_screen=%s presentation=%s" % [
		String(shell._active_screen), str(shell._presentation),
	])
	return true


## Contract §6 settlement wiring: summary carries `explore`, the page appends an
## `ExploreBlock`, and the domain result matches (found port / failed clue).
func _assert_settlement(
	shell: Control, context: AppContext, info: Dictionary, expected: String, tag: String
) -> bool:
	var failures_before := _failures
	var screens := _nodes_with_script(shell._root_box, SETTLEMENT_SCREEN_SCRIPT)
	_assert_eq(screens.size(), 1, "the settlement page is mounted (%s)" % tag)
	if screens.is_empty():
		return false
	var summary: Dictionary = shell._settlement_summary
	_assert_false(summary.is_empty(), "the settlement carries a summary (%s)" % tag)
	var explore: Dictionary = summary.get("explore", {}) if summary.get("explore", null) is Dictionary else {}
	_assert_false(explore.is_empty(), "the settlement summary carries the explore block (%s)" % tag)
	if not explore.is_empty():
		_assert_eq(String(explore.get("result", "")), expected,
			"summary.explore.result is %s (%s)" % [expected, tag])
	_assert_true(_node_named(screens[0], "ExploreBlock") != null,
		"the settlement page appends its own ExploreBlock (%s)" % tag)
	var texts := _label_texts(screens[0])
	var expected_text := String(context.translate("ui.explore.result." + expected))
	_assert_true(texts.has(expected_text),
		"the settlement prints the exploration result (%s): %s" % [expected_text, str(texts)])
	var destination := String(explore.get("port_id", ""))
	var current := context.state.current_port_id()
	var clue_id := String(info.get("clue_id", ""))
	var state: GameState = context.state
	_assert_eq(String(summary.get("destination", "")), destination,
		"the summary destination is the settled harbour (%s)" % tag)
	if expected == "discovered":
		_assert_eq(current, destination, "the ship enters the discovered harbour (%s)" % tag)
		_assert_eq(destination, String(info.get("target", "")),
			"the discovered harbour is the clue target (%s)" % tag)
		_assert_ne(current, String(info.get("origin", "")),
			"discovering moves the ship away from the origin (%s)" % tag)
		_assert_false(_active_has(context, clue_id),
			"the resolved clue leaves the active log (%s)" % tag)
		_assert_true(Array(state.ensure_clues().get("resolved", [])).has(clue_id),
			"the clue is recorded as resolved (%s)" % tag)
	else:
		_assert_eq(current, destination, "the drift destination is where the ship ends up (%s)" % tag)
		_assert_true(Array(state.ensure_clues().get("failed", [])).has(clue_id),
			"the failed clue is kept in the failed log (%s)" % tag)
		_assert_false(_active_has(context, clue_id),
			"the failed clue leaves the active log (%s)" % tag)
		_assert_true(float(explore.get("durability_loss", 0.0)) > 0.0,
			"drifting costs durability (%s)" % tag)
		_assert_true(float(explore.get("extra_coal", 0.0)) >= 0.0,
			"the drift coal is reported (%s)" % tag)
		_assert_true(float(summary.get("delayed_hours", 0.0)) > 0.0,
			"drifting adds the rule's extra hours (%s)" % tag)
	print("[EVIDENCE] settlement %s result=%s origin=%s destination=%s current_port=%s money=%d coal=%.1f water=%.1f durability=%.1f delayed=%.1f" % [
		tag, expected, String(info.get("origin", "")), destination, current,
		state.money(), float(state.ship().get("coal", 0.0)), float(state.ship().get("water", 0.0)),
		float(state.ship().get("durability", 0.0)), float(summary.get("delayed_hours", 0.0)),
	])
	return _failures == failures_before


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _force_chinese_locale(shell: Control, context: AppContext) -> void:
	# Screenshots must be reviewable against the zh_CN contract text; stop the saved
	# settings from overriding the locale on every rebuild.
	context.localization.set_locale("zh_CN")
	shell._settings_applied = true
	shell._refresh()


func _port_name(context: AppContext, port_id: String) -> String:
	var world := WorldOps.world_map(context.state)
	var port := world.get_port(port_id)
	if port.is_empty():
		return port_id
	return String(context.translate(port.name_key, port_id))


func _port_position(context: AppContext, port_id: String) -> Vector2:
	var world := WorldOps.world_map(context.state)
	var port := world.get_port(port_id)
	return port.position if not port.is_empty() else Vector2.ZERO


func _active_has(context: AppContext, clue_id: String) -> bool:
	return not ClueService.find_clue(context.state, clue_id).is_empty()


func _route_heading(route: PackedVector2Array, progress: float) -> float:
	if route.size() < 2:
		return 0.0
	var backward := VoyagePresentation.sample_polyline(route, maxf(0.0, progress - 0.01))
	var forward := VoyagePresentation.sample_polyline(route, minf(1.0, progress + 0.01))
	return (forward - backward).angle()


static func _distance_to_polyline(point: Vector2, polyline: PackedVector2Array) -> float:
	if polyline.size() < 2:
		return INF
	var best := INF
	for index in range(1, polyline.size()):
		best = minf(best, point.distance_to(
			Geometry2D.get_closest_point_to_segment(point, polyline[index - 1], polyline[index])
		))
	return best


func _drive_until(shell: Control, predicate: Callable, max_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < max_seconds:
		if bool(predicate.call()):
			return true
		shell._process(DRIVE_STEP)
		elapsed += DRIVE_STEP
	return bool(predicate.call())


func _bootstrap() -> AppContext:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://capture_saves/exploration",
	})
	var context := bootstrap.context
	if context == null:
		_fail("bootstrap produced no AppContext")
		return null
	AppContext.set_active(context)
	return context


func _settle(frames: int, seconds: float) -> void:
	for _index in frames:
		await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout
	for _index in 3:
		await process_frame


func _nodes_with_script(root: Node, script: Script, out: Array = []) -> Array:
	for child in root.get_children():
		if child.get_script() == script:
			out.append(child)
		_nodes_with_script(child, script, out)
	return out


func _node_named(root: Node, wanted: String) -> Node:
	if root == null:
		return null
	if String(root.name) == wanted:
		return root
	for child in root.get_children():
		var found := _node_named(child, wanted)
		if found != null:
			return found
	return null


func _label_texts(root: Node, out: Array = []) -> Array:
	for child in root.get_children():
		if child is Label:
			out.append(String((child as Label).text))
		_label_texts(child, out)
	return out


func _label_named(root: Node, wanted: String) -> Node:
	if root == null:
		return null
	if String(root.name) == wanted:
		return root
	for child in root.get_children():
		var found := _label_named(child, wanted)
		if found != null:
			return found
	return null


func _progress_bar(root: Node) -> ProgressBar:
	if root is ProgressBar:
		return root as ProgressBar
	for child in root.get_children():
		var found := _progress_bar(child)
		if found != null:
			return found
	return null


func _button_by_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and String((child as Button).text) == text:
			return child as Button
		var found := _button_by_text(child, text)
		if found != null:
			return found
	return null


# ---------------------------------------------------------------------------
# Capture / commit / assertions (same contract as capture_voyage_presentation)
# ---------------------------------------------------------------------------


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


func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if _values_equal(actual, expected):
		print("[PASS] " + message)
	else:
		_fail("%s (got %s, expected %s)" % [message, str(actual), str(expected)])


func _assert_ne(actual: Variant, unexpected: Variant, message: String) -> void:
	if _values_equal(actual, unexpected):
		_fail("%s (both are %s)" % [message, str(actual)])
	else:
		print("[PASS] " + message)


func _assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		print("[PASS] " + message)
	else:
		_fail("%s (got %.6f, expected %.6f +- %.6f)" % [message, actual, expected, tolerance])


func _values_equal(left: Variant, right: Variant) -> bool:
	var left_is_number := typeof(left) == TYPE_INT or typeof(left) == TYPE_FLOAT
	var right_is_number := typeof(right) == TYPE_INT or typeof(right) == TYPE_FLOAT
	if left_is_number and right_is_number:
		return is_equal_approx(float(left), float(right))
	return left == right


func _fail(message: String) -> void:
	_failures += 1
	push_error("capture_exploration: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	if _failures > 0:
		_cleanup_tmp()
	print("=== exploration capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
