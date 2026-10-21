extends SceneTree
## @static-doc
## 作用：探索系统（海图阶段 4.1 + 4.2 资源告急决策）的真实渲染截图工具。窗口模式
## 挂载真正的 `main.tscn`，用真实命令开一局（seed 20260421）、真实 `clue.buy` 买线索、
## 真实 `explore.start` / `explore.settle` / `explore.decide` 走完整探索演出，按
## `docs/design/EXPLORATION_SYSTEM.md` §6 的里程碑抓图：海图线索可视化
## （level 2 方向箭头 / level 3 虚线圆 / level 4 `？港名？` + 面板线索区块）、
## 探索演出（世界航线 + 到搜索区的虚线预测线 + `?` 终点 + 航程条 `？`）、
## 路线资源告急决策页（继续 / 掉头）、以及结算页探索结果区块
## （发现 / 失败漂流 / 掉头返航 / 告警后继续）。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_exploration.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/exploration/`）：
##   exploration_chart_clues.png      海图线索：方向箭头、虚线圆、`？港名？`，选中线索高亮 + 右侧面板线索区块
##   exploration_chart_investigate.png 4.3.2：选中 2 级线索时的「调查线索」按钮 +「下一级：已知航程」预告
##   exploration_depart_confirm.png   4.3.4：海图内出航确认弹窗（预估 / 锅炉策略 / 取消 / 启航）
##   exploration_chart_route.png      探索演出：世界航线 + 到 `?` 的虚线预测线 + 底部航程条目的地 `？`
##   exploration_arrival.png          第一次探索（发现）抵达结算：探索结果区块
##   exploration_result_found.png     另一次发现结算（不同港口）
##   exploration_result_failed.png    失败漂流结算：额外煤水 / 耐久损失 / 线索保留（4.3）
##   exploration_resource_alert.png   4.2 资源告急页：标题/描述/煤水耐久/继续探索/掉头返航
##   exploration_turned_back.png      4.2 / 4.3.5 掉头返航结算：港口 / 额外损耗 / 线索保留
##   exploration_alert_continue.png   4.2 告警后继续探索的结算（证明继续路径照常 settle）
##
## ## 契约与约束
## - 全程用真实领域入口：`run.start` / `clue.buy` / `ClueService.acquire`
##   （`RngService.STREAM_EXPLORATION` 命名流）/ `clue.investigate`（4.3.2 逐级升级）/
##   海图面板按钮 → 出航确认弹窗 → `explore.start` → Shell 在 `ARRIVAL_READY`
##   自动 `explore.settle`；4.2 的告警选项通过真实 `EventScreen` 按钮 →
##   `explore.decide` → `VoyagePresentation.force_arrival()`。
##   发现/失败只用契约 §2 的 `outcome_roll`（出发时抽定，0 = 必发现、0.999 = 必失败）
##   覆盖，不伪造结算结果；告警用真实 `ExplorationCalculator.preview` 的
##   `coal_required`，把出发煤量压到 `×1.05`（与 `test_voyage_flow.gd` 的告警前置一致）。
## - 开始港若是 iron_harbour（无情报站），照 `framework/tests/cases/test_exploration.gd`
##   的做法补一个 `intel` 设施，`clue.buy` 本身仍是真实命令。
## - **硬性断言**（不满足 exit 1 但已抓到的图照存）：`sea_chart.view.clues` 不含
##   `target_port_id` / `credibility` / 真实 `search_zone`；面板线索文本非空且不含
##   `ui.*` 原始键名；探索中 `SNSeaChartView._unknown_destination` 非空、航程条目的地
##   显示 `？`、船 icon 沿航线切线；`explore.settle` 后成功当前港变为目标港 / 失败
##   线索仍 active（4.3/U3，只记 attempts）、`failed` 列表不新增；结算 summary 含
##   `explore` 且结算页有 `ExploreBlock`。
## - 4.2 追加：告警页处于 `EVENT_WAIT` 且 `_presentation.skip() == NONE`（决策不可被
##   跳过）、文案全部本地化且不泄露目标港、`sea_chart.view.explore` 暴露
##   `alert_needed/alert_progress/alert_decided`；掉头后 `current_port == origin`、线索
##   仍 active、`summary.explore.result == "turned_back"`、命令日志里没有
##   `not_exploring` 也没有第二次 `explore.settle`；继续路径会正常 `explore.settle`
##   并保留 `alert_decided == "continue"`，重复回答返回 `alert_already_decided`。
## - 4.4.3：`clue.investigate` 有 Core 成功率（0.75）与成本，所以逐级升级改为
##   「重试直到目标等级」的循环（每次失败照扣 20 金 / 6h，但不升级）；升级次数以
##   `[EVIDENCE] ... attempts` 记录。
## - 先写 `res://tmp_exploration_*`，全部 8 张成功后才移入 `docs/`，失败不留半套。
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
const EVENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/event_screen.gd")

const SHOTS := [
	{"file": "exploration_chart_clues.png", "label": "海图线索（箭头 / 虚线圆 / ？港名？ + 选中面板）"},
	{"file": "exploration_chart_route.png", "label": "探索演出（虚线预测线 + ? 终点）"},
	{"file": "exploration_arrival.png", "label": "探索抵达结算（发现）"},
	{"file": "exploration_result_found.png", "label": "探索结算 · 发现"},
	{"file": "exploration_result_failed.png", "label": "探索结算 · 失败漂流"},
	{"file": "exploration_resource_alert.png", "label": "资源告急（继续探索 / 掉头返航）"},
	{"file": "exploration_turned_back.png", "label": "探索结算 · 掉头返航"},
	{"file": "exploration_alert_continue.png", "label": "告警后继续探索结算"},
	{"file": "exploration_chart_investigate.png", "label": "4.3.2 线索逐级调查（下一级预告 + 调查按钮）"},
	{"file": "exploration_depart_confirm.png", "label": "4.3.4 海图内出航确认弹窗（策略 + 预估）"},
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
	DisplayServer.window_set_title("Steam Navigator · exploration 4.1+4.2")
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

	# ── 4.3.2 shot: select the level-2 clue; the panel exposes the investigate
	# button and the next-level preview (`ui.clue.next_level` + level 3 text).
	var failed_id := String(prepared["failed"])
	screen._on_clue_clicked(failed_id)
	await _settle(6, 0.3)
	var investigate: Button = _node_named(screen, "InvestigateButton") as Button
	_assert_true(investigate != null, "the clue panel mounts the investigate button")
	if investigate != null:
		_assert_false(investigate.disabled, "a level-2 clue can still be investigated")
	var investigate_texts := _label_texts(screen)
	# 文案是模板填充后的「下一级：已知航程」，要按格式化后的字符串比较。
	var next_level_text := String(context.translate("ui.clue.next_level")) \
		% String(context.translate("ui.clue.level.3"))
	_assert_true(_texts_contain(investigate_texts, next_level_text),
		"the panel announces the next disclosure level (%s)" % next_level_text)
	_assert_true(_texts_contain(investigate_texts, String(context.translate("ui.clue.level.3"))),
		"the next level preview names level 3 (distance known)")
	await _capture(String(SHOTS[8]["file"]), String(SHOTS[8]["label"]))

	# ── 4.3.4 shot: the shared departure confirmation dialog, then confirm it and
	# run A's (found) voyage from there. ──
	var dialog_screen: Variant = await _request_departure(shell, context, String(prepared["sail"]))
	if dialog_screen == null:
		_finish()
		return
	_assert_departure_dialog(context, dialog_screen, String(prepared["sail"]))
	await _capture(String(SHOTS[9]["file"]), String(SHOTS[9]["label"]))
	var info_a := await _confirm_departure(
		shell, context, dialog_screen, String(prepared["sail"]), 0.0
	)
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

	# ── Run D (4.2 resource alert → turn back): force the Core alert, capture the
	# decision page, press the real「掉头返航」button, then the turned-back settlement.
	# 4.3/U3 起失败线索保留在 active（其目标港仍被引用、无法再生成指向它的新线索），
	# 所以 4.2 告警跑复用这条仍然有效的失败线索——这正是「失败后可再次出航」的真实路径。
	var alert_clue := _domain_clue(context, failed_id)
	if alert_clue.is_empty():
		alert_clue = _acquire_last_clue(context)
	if alert_clue.is_empty():
		_finish()
		return
	var alert_run := await _run_alert_turn_back(shell, context, alert_clue)
	if not bool(alert_run.get("ok", false)):
		_finish()
		return

	# ── Run E (4.2 alert → continue): the turned-back clue survived, so the same
	# clue proves the continue path resumes the voyage and settles normally. ──
	if not await _run_alert_continue(shell, context, String(alert_run.get("clue_id", ""))):
		_finish()
		return

	_commit_shots()
	_finish()


# ---------------------------------------------------------------------------
# Setup: run + clues (real commands / real domain services)
# ---------------------------------------------------------------------------


## Fills the clue log with one clue of each visual level (2 arrow / 3 dashed circle /
## 4 `？name？`). 4.3.2 起线索获得时固定 1 级，所以这里先买/拿到三条 1 级线索，再走
## 真实的 `clue.investigate` 分别升到 2 / 3 / 4 级（图表 shot 因此同时覆盖调查入口）。
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
	# 第三条通过领域服务拿（与前两条一样真实写入 active；不依赖随机购买成功）。
	var third := _acquire_clue(context, "intel")
	if third.is_empty():
		_fail("cannot acquire a third clue for the level fixture")
		return {"ok": false}
	_evidence_clues(context, "after clue acquisition")

	var active_ids: Array[String] = []
	for clue in ClueService.active(state):
		active_ids.append(String((clue as Dictionary).get("id", "")))
	_assert_eq(active_ids.size(), 3, "the fixture starts with three level-1 clues")
	if active_ids.size() < 3:
		return {"ok": false}

	# 4.3.2：每条线索获得时必为 1 级，调查只逐级披露（不重抽目标 / 可信度）。
	var keep := {}
	var wanted_by_id := {
		active_ids[0]: 4,
		active_ids[1]: 3,
		active_ids[2]: 2,
	}
	for clue_id in wanted_by_id.keys():
		var target_level := int(wanted_by_id[clue_id])
		_assert_eq(int(_domain_clue(context, String(clue_id)).get("level", 0)), 1,
			"clue %s is acquired at level 1" % clue_id)
		var fixed_target := String(_domain_clue(context, String(clue_id)).get("target_port_id", ""))
		var fixed_credibility := float(_domain_clue(context, String(clue_id)).get("credibility", 0.0))
		var fixed_zone: Dictionary = _domain_clue(context, String(clue_id)).get("search_zone", {})
		# 4.4.3：调查有成功率（Core 0.75），失败照扣成本但不升级；重试直到目标等级。
		var attempts := 0
		while int(_domain_clue(context, String(clue_id)).get("level", 1)) < target_level \
				and attempts < 24:
			attempts += 1
			var result := context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
			_assert_true(bool(result.get("ok", false)),
				"clue.investigate succeeds for %s: %s" % [clue_id, str(result.get("error_code", ""))])
		print("[EVIDENCE] clue %s reached level %d in %d investigation attempt(s)" % [
			clue_id, target_level, attempts,
		])
		var investigated := _domain_clue(context, String(clue_id))
		_assert_eq(int(investigated.get("level", 0)), target_level,
			"clue %s reaches level %d through investigation" % [clue_id, target_level])
		_assert_eq(String(investigated.get("target_port_id", "")), fixed_target,
			"investigation never re-rolls the target harbour")
		_assert_almost_eq(float(investigated.get("credibility", 0.0)), fixed_credibility, 0.0001,
			"investigation never re-rolls credibility")
		_assert_eq(investigated.get("search_zone", {}), fixed_zone,
			"investigation never re-rolls the search zone")
		keep[target_level] = clue_id
		print("[EVIDENCE] clue %s investigated to level %d" % [clue_id, target_level])
	_evidence_clues(context, "normalised by investigation")

	_assert_eq(keep.size(), WANTED_LEVELS.size(),
		"the clue log covers levels 2 (arrow) / 3 (circle) / 4 (name)")
	if keep.size() < WANTED_LEVELS.size():
		return {"ok": false}

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


func _acquire_clue(context: AppContext, source: String, target_port_id: String = "") -> Dictionary:
	_clue_serial += 1
	# Same named stream the domain uses (`RngService.STREAM_EXPLORATION`); a unique
	# key per call keeps the capture deterministic without touching any save file.
	var rng := context.rng.make_stream(
		RngService.STREAM_EXPLORATION, "capture:%s:%d" % [source, _clue_serial]
	)
	return ClueService.acquire(context, source, rng, target_port_id)


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


## 打开海图、点线索、按面板出航按钮 → 4.3.4 的统一确认弹窗。返回弹窗所在的屏幕
## （Shell 会因打开弹窗同步重建海图页，旧 screen 实例作废）。
func _request_departure(
	shell: Control, context: AppContext, clue_id: String
) -> Variant:
	var screen: Variant = await _open_chart(shell)
	if screen == null:
		return null
	screen._on_clue_clicked(clue_id)
	await _settle(4, 0.15)
	var panel: SNSeaChartPanel = screen._panel
	if panel == null or String(panel.get_clue().get("id", "")) != clue_id:
		_fail("the clue panel did not bind %s before sailing" % clue_id)
		return null
	var button := _button_by_text(screen, String(context.translate("ui.button.explore_clue")))
	if button == null:
		_fail("the clue panel has no explore button for %s" % clue_id)
		return null
	_assert_false(button.disabled, "the explore button is enabled for %s" % clue_id)
	button.pressed.emit()
	await _settle(6, 0.3)
	var screens := _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	_assert_eq(screens.size(), 1, "the chart page is rebuilt with the departure dialog")
	if screens.is_empty():
		return null
	var dialog_screen: Variant = screens[0]
	_assert_true(bool(dialog_screen.is_departure_open()),
		"the panel button opens the shared departure confirmation")
	return dialog_screen


## 4.3.4 确认弹窗的渲染/接线断言：标题、策略选择器（默认标准锅炉）与预估行。
func _assert_departure_dialog(context: AppContext, screen: Variant, clue_id: String) -> void:
	var texts := _label_texts(screen)
	_assert_true(texts.has(String(context.translate("ui.confirm.title.explore"))),
		"the explore dialog shows its localized title: %s" % str(texts))
	_assert_true(_texts_contain(texts, String(context.translate("ui.label.estimated_time"))),
		"the dialog shows the estimated duration")
	var picker: OptionButton = _node_named(screen, "StrategyPicker") as OptionButton
	_assert_true(picker != null, "the dialog exposes the boiler strategy picker")
	if picker != null:
		_assert_true(picker.item_count >= 2, "the picker lists every boiler strategy")
		_assert_eq(String(picker.get_item_metadata(picker.selected)), STRATEGY_ID,
			"the dialog defaults to the standard boiler strategy")
	var confirm: Button = _node_named(screen, "ConfirmButton") as Button
	_assert_true(confirm != null, "the dialog exposes the depart confirmation button")
	if confirm != null:
		_assert_false(confirm.disabled, "the feasible clue can be confirmed")
	var cancel: Button = _node_named(screen, "CancelButton") as Button
	_assert_true(cancel != null, "the dialog exposes cancel")
	print("[EVIDENCE] departure dialog clue=%s strategy=%s confirm_disabled=%s texts=%s" % [
		clue_id, String(picker.get_item_metadata(picker.selected)) if picker != null else "",
		str(confirm.disabled) if confirm != null else "n/a", str(texts),
	])


## 在确认弹窗里按下「启航」，然后把出发时抽定的 outcome_roll 覆盖成测试要的结果
## （0 = 必发现，0.999 = 必失败），返回 voyage evidence block。
func _confirm_departure(
	shell: Control, context: AppContext, screen: Variant, clue_id: String, outcome_roll: float
) -> Dictionary:
	var preview := _preview(context, clue_id)
	var confirm: Button = _node_named(screen, "ConfirmButton") as Button
	if confirm == null:
		_fail("the departure dialog has no confirm button for %s" % clue_id)
		return {"ok": false}
	confirm.pressed.emit()
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
		"alert_needed": bool(presentation.get("alert_needed", false)),
		"alert_progress": float(presentation.get("alert_progress", 0.0)),
	}
	_assert_true(String(presentation.get("kind", "")) == "explore",
		"explore.start returns an exploration presentation")
	_assert_eq(String(presentation.get("clue_id", "")), clue_id,
		"the presentation carries the clue id")
	_assert_eq(bool(shell._presentation.has_event), bool(info["alert_needed"]),
		"the presentation schedules a decision point exactly when the alert is needed")
	_assert_eq(String(shell._presentation.phase_name()), "departure_3d",
		"the 3D departure cut starts the exploration演出")
	return info


## 兼容旧调用点：打开海图 → 出航确认弹窗 → 确认 → explore.start。
func _start_exploration(
	shell: Control, context: AppContext, clue_id: String, outcome_roll: float
) -> Dictionary:
	var screen: Variant = await _request_departure(shell, context, clue_id)
	if screen == null:
		return {"ok": false}
	return await _confirm_departure(shell, context, screen, clue_id, outcome_roll)


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
	elif expected == "turned_back":
		# 4.2: the half-voyage return is a real harbour entry (same services as a
		# normal arrival) but the clue stays active for another attempt.
		_assert_eq(current, destination, "the turn-back lands in the origin harbour (%s)" % tag)
		_assert_eq(destination, String(info.get("origin", "")),
			"the turn-back destination is the departure harbour (%s)" % tag)
		_assert_true(state.is_at_port(), "the ship is in port after the turn-back (%s)" % tag)
		_assert_true(_active_has(context, clue_id),
			"the clue stays active after turning back (%s)" % tag)
		_assert_false(Array(state.ensure_clues().get("failed", [])).has(clue_id),
			"a turned-back clue is not marked failed (%s)" % tag)
		_assert_true(float(explore.get("extra_coal", 0.0)) > 0.0,
			"turning back burns extra coal (%s)" % tag)
		_assert_true(float(explore.get("extra_water", 0.0)) > 0.0,
			"turning back burns extra water (%s)" % tag)
		_assert_almost_eq(float(explore.get("durability_loss", 0.0)), 0.0, 0.0001,
			"turning back costs no durability (%s)" % tag)
		_assert_true(_texts_contain(texts, String(context.translate("ui.explore.clue_retained"))),
			"the settlement says the clue is retained (%s)" % tag)
	else:
		_assert_eq(current, destination, "the drift destination is where the ship ends up (%s)" % tag)
		# 4.3 / U3：失败不消耗线索——仍在 active、只记录尝试、结算页说「线索保留」。
		_assert_true(_active_has(context, clue_id),
			"a failed clue stays active (%s)" % tag)
		_assert_false(Array(state.ensure_clues().get("failed", [])).has(clue_id),
			"a failed clue is not moved into the failed log (%s)" % tag)
		_assert_true(int(explore.get("attempts", 0)) >= 1,
			"the failed attempt is counted (%s)" % tag)
		_assert_true(_texts_contain(texts, String(context.translate("ui.explore.clue_retained"))),
			"the settlement says the clue is retained (%s)" % tag)
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
	if expected == "turned_back":
		print("[EVIDENCE] settlement %s explore extra_coal=%.2f extra_water=%.2f clue=%s active=%s" % [
			tag, float(explore.get("extra_coal", 0.0)), float(explore.get("extra_water", 0.0)),
			clue_id, str(_active_has(context, clue_id)),
		])
	return _failures == failures_before


# ---------------------------------------------------------------------------
# 4.2 resource alert: forced Core alert → decision page → turn back / continue
# ---------------------------------------------------------------------------


## The three 4.1 clues are spent by run C; this adds one last real clue for the
## remaining undiscovered harbour so the 4.2 alert runs still have a target.
func _acquire_last_clue(context: AppContext) -> Dictionary:
	var state: GameState = context.state
	var targets := ClueService.eligible_target_ids(state)
	print("[EVIDENCE] 4.2 setup: current_port=%s undiscovered_targets=%s money=%d coal=%.1f water=%.1f" % [
		state.current_port_id(), str(targets), state.money(),
		float(state.ship().get("coal", 0.0)), float(state.ship().get("water", 0.0)),
	])
	_assert_false(targets.is_empty(), "an undiscovered target remains for the 4.2 alert runs")
	if targets.is_empty():
		return {}
	var clue := _acquire_clue(context, "intel", String(targets[0]))
	_assert_false(clue.is_empty(), "the 4.2 clue is created through ClueService.acquire")
	if not clue.is_empty():
		print("[EVIDENCE] 4.2 clue id=%s level=%d target=%s" % [
			String(clue.get("id", "")), int(clue.get("level", 0)),
			String(clue.get("target_port_id", "")),
		])
	return clue


## Real-command style forced alert (mirrors `test_voyage_flow._request_alert_exploration`):
## preview the real `coal_required`, then set the departure coal stock to
## `required * 1.05` so `explore.start` consumes more than Core's `alert_threshold`.
## Water shortages are fixed with the real `supply.buy_water` command — stock is never
## invented, only the coal figure the test fixture also pins.
func _force_resource_alert(context: AppContext, clue_id: String) -> Dictionary:
	var state: GameState = context.state
	var rules := ExplorationRules.read(state, context.registries)
	var threshold := float(rules.get("alert_threshold", 0.5))
	var preview := _preview(context, clue_id)
	var attempts := 0
	while attempts < 3:
		attempts += 1
		var needs_water := false
		for blocker in preview.get("blockers", []):
			if blocker is Dictionary \
					and String((blocker as Dictionary).get("code", "")) == "insufficient_water":
				needs_water = true
		if needs_water:
			var water_result := context.commands.execute(&"supply.buy_water", {"amount": 8})
			print("[EVIDENCE] 4.2 top-up water ok=%s error=%s" % [
				str(water_result.get("ok", false)), str(water_result.get("error_code", "")),
			])
			preview = _preview(context, clue_id)
		var coal_required := float(preview.get("coal_required", 0.0))
		_assert_true(coal_required > 0.0, "the forced-alert voyage has a real coal cost")
		if coal_required <= 0.0:
			return {}
		state.ship()["coal"] = coal_required * 1.05
		preview = _preview(context, clue_id)
		_print_preview(clue_id, preview)
		if bool(preview.get("feasible", false)):
			break
	_assert_true(bool(preview.get("feasible", false)),
		"the forced-alert voyage is still feasible (coal %.2f, water %.2f)" % [
			float(state.ship().get("coal", 0.0)), float(state.ship().get("water", 0.0)),
		])
	var coal_before := float(state.ship().get("coal", 0.0))
	var coal_required := float(preview.get("coal_required", 0.0))
	print("[EVIDENCE] 4.2 forced alert clue=%s coal=%.2f (required %.2f x1.05) threshold=%.2f consumed_share=%.3f water=%.2f" % [
		clue_id, coal_before, coal_required, threshold, coal_required / maxf(0.001, coal_before),
		float(state.ship().get("water", 0.0)),
	])
	_assert_true(coal_required >= coal_before * threshold,
		"the departure stock makes the voyage consume >= alert_threshold of its coal")
	return preview


func _drive_to_alert(shell: Control) -> bool:
	var reached := _drive_until(shell, func() -> bool:
		return shell._presentation != null \
			and String(shell._presentation.phase_name()) == "event_wait" \
			and float(shell._presentation.veil) <= 0.001 \
			and _nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT).size() == 1,
		MAX_DRIVE_SECONDS)
	if not reached:
		_fail("the exploration演出 never reached the resource-alert page")
		return false
	print("[EVIDENCE] alert reached phase=%s veil=%.3f has_event=%s progress=%.3f" % [
		String(shell._presentation.phase_name()), float(shell._presentation.veil),
		str(shell._presentation.has_event), float(shell._presentation.progress),
	])
	return true


## The 4.2 decision page (contract S2): EventScreen mounted, `EVENT_WAIT`, localized
## title/description/buttons, live ship numbers, no target leak, and `skip()` must not
## answer or bypass the decision. With `capture` it also saves shot 6.
func _assert_alert_page(
	shell: Control, context: AppContext, info: Dictionary, capture: bool
) -> Dictionary:
	var failures_before := _failures
	var screens := _nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT)
	_assert_eq(screens.size(), 1, "the resource-alert page is mounted")
	if screens.is_empty():
		return {}
	_assert_eq(String(shell._presentation.phase_name()), "event_wait",
		"the presentation waits at event_wait for the alert decision")
	_assert_true(shell._presentation_on_alert(), "the shell reports the alert decision is open")
	_assert_true(_nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT).is_empty(),
		"the chart page is not mounted behind the alert")
	_assert_true(shell._at_sea_screen == null, "the at-sea page is torn down while the alert is open")
	var alert_screen: Variant = screens[0]
	if alert_screen is Control:
		_assert_true((alert_screen as Control).size.x > 100.0 and (alert_screen as Control).size.y > 0.0,
			"the alert page has a real layout size (%s)" % str((alert_screen as Control).size))

	# S2: the演出 must not answer or skip the decision on its own.
	var skip_step: int = int(shell._presentation.skip())
	_assert_eq(skip_step, int(VoyagePresentation.Step.NONE),
		"the alert cannot be skipped away via presentation.skip()")
	_assert_eq(String(shell._presentation.phase_name()), "event_wait",
		"skip() leaves the alert decision open")

	# Localized text, both choices, and the live ship/cargo row.
	var texts := _label_texts(alert_screen)
	var joined := "\n".join(texts)
	print("[EVIDENCE] alert page labels: %s" % str(texts))
	_assert_eq(joined.find("ui."), -1, "the alert page never renders raw ui.* localization keys")
	var title := String(context.translate("ui.explore.alert.title"))
	var description := String(context.translate("ui.explore.alert.description"))
	var remaining_label := String(context.translate("ui.explore.alert.remaining"))
	var continue_text := String(context.translate("ui.explore.alert.continue"))
	var turn_back_text := String(context.translate("ui.explore.alert.turn_back"))
	_assert_true(texts.has(title), "the alert page shows the localized title (%s)" % title)
	_assert_true(texts.has(description), "the alert page explains the two choices")
	_assert_true(joined.contains(remaining_label),
		"the alert hint shows the remaining voyage instead of 'settles immediately'")
	_assert_true(_button_by_text(alert_screen, continue_text) != null,
		"the alert offers 'continue exploring' (%s)" % continue_text)
	_assert_true(_button_by_text(alert_screen, turn_back_text) != null,
		"the alert offers 'turn back' (%s)" % turn_back_text)
	var view_data: Dictionary = {}
	var port_result := context.queries.execute(&"port.view")
	if bool(port_result.get("ok", false)):
		var raw_view: Variant = port_result.get("data", null)
		if raw_view is Dictionary:
			view_data = raw_view as Dictionary
	var ship_view: Dictionary = {}
	if view_data.get("ship", null) is Dictionary:
		ship_view = view_data["ship"] as Dictionary
	var expected_stats := "耐久 %.1f / %.1f · 淡水 %.1f · 煤炭 %.1f · 金币 %d" % [
		float(ship_view.get("durability", 0.0)), float(ship_view.get("max_durability", 0.0)),
		float(ship_view.get("water", 0.0)), float(ship_view.get("coal", 0.0)),
		int(view_data.get("money", 0)),
	]
	_assert_true(texts.has(expected_stats),
		"the alert page prints the live ship/cargo numbers (%s): %s" % [expected_stats, str(texts)])

	# S1 fields: Core JSON alert point, recorded in the voyage + the query surface.
	var rules := ExplorationRules.read(context.state, context.registries)
	var expected_alert := float(rules.get("alert_progress", 0.5))
	var voyage: Variant = context.state.explore_voyage()
	_assert_true(voyage is Dictionary, "the domain still owns the exploration voyage while the alert is open")
	if voyage is Dictionary:
		_assert_true(bool((voyage as Dictionary).get("alert_needed", false)),
			"explore_voyage marks the resource alert")
		_assert_eq(String((voyage as Dictionary).get("alert_decided", "")),
			"", "the alert is still unanswered")
	_assert_true(bool(shell._presentation_explore.get("alert_needed", false)),
		"the presentation carries alert_needed")
	_assert_almost_eq(float(shell._presentation_explore.get("alert_progress", -1.0)),
		expected_alert, 0.0001, "alert_progress comes from Core JSON (%.3f)" % expected_alert)
	_assert_true(shell._presentation.has_event, "the alert is a real mid-voyage decision point")
	_assert_almost_eq(float(shell._presentation.event_progress), expected_alert, 0.0001,
		"the presentation stops at alert_progress")
	_assert_almost_eq(float(shell._presentation.progress), expected_alert, 0.001,
		"the演出 progress sits at the alert point")
	var chart_view := _chart_view(context)
	var explore_state: Dictionary = {}
	if chart_view.get("explore", null) is Dictionary:
		explore_state = chart_view["explore"] as Dictionary
	_assert_true(bool(explore_state.get("active", false)),
		"sea_chart.view reports the active exploration")
	_assert_true(bool(explore_state.get("alert_needed", false)),
		"sea_chart.view exposes alert_needed")
	_assert_almost_eq(float(explore_state.get("alert_progress", -1.0)), expected_alert, 0.0001,
		"sea_chart.view exposes alert_progress")
	_assert_eq(String(explore_state.get("alert_decided", "")), "",
		"sea_chart.view exposes the unanswered alert")

	# The target must stay unknown while the player decides.
	var target := String(info.get("target", ""))
	var target_name := _port_name(context, target)
	_assert_false(joined.contains(target), "the alert page never prints the target port id (%s)" % target)
	_assert_false(joined.contains(target_name),
		"the alert page never prints the target harbour name (%s)" % target_name)
	_assert_eq(String(shell._presentation_voyage.get("destination", "unset")), "",
		"the presentation destination is still unknown during the alert")
	var chrome_texts := _label_texts(shell._top_chrome)
	var exploring_label := "%s → %s" % [
		String(context.translate("ui.label.exploring")),
		String(context.translate("ui.label.unknown_destination")),
	]
	_assert_true(chrome_texts.has(exploring_label),
		"the top chrome stays '探索中 → ？' during the alert")
	_assert_false(chrome_texts.has(target_name),
		"the top chrome does not reveal the target harbour")

	var coal := float(context.state.ship().get("coal", 0.0))
	var water := float(context.state.ship().get("water", 0.0))
	var remaining_hours := float(shell._presentation.remaining_hours())
	print("[EVIDENCE] alert page: phase=%s progress=%.3f alert_progress=%.3f remaining=%.2fh coal=%.2f water=%.2f target_hidden=%s" % [
		String(shell._presentation.phase_name()), float(shell._presentation.progress),
		expected_alert, remaining_hours, coal, water,
		str(not joined.contains(target_name) and not joined.contains(target)),
	])
	if capture:
		await _capture(String(SHOTS[5]["file"]), String(SHOTS[5]["label"]))
	return {
		"ok": _failures == failures_before,
		"coal": coal,
		"water": water,
		"current_port": String(context.state.current_port_id()),
		"alert_progress": expected_alert,
		"remaining_hours": remaining_hours,
	}


func _press_alert_option(shell: Control, context: AppContext, option_id: String) -> bool:
	var screens := _nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT)
	if screens.is_empty():
		_fail("the resource-alert page is not mounted before choosing %s" % option_id)
		return false
	var text := String(context.translate("ui.explore.alert." + option_id))
	var button := _button_by_text(screens[0], text)
	if button == null:
		_fail("the resource-alert page has no %s button (%s)" % [option_id, text])
		return false
	print("[EVIDENCE] alert decision: pressing '%s'" % text)
	button.pressed.emit()
	return true


## 4.2 · turn back: the real「掉头返航」button must settle the domain immediately
## (`current_port == origin`, clue keeps active, extra coal/water burned), then the
## shortened arrival cut lands on a `turned_back` settlement without a second settle.
func _run_alert_turn_back(shell: Control, context: AppContext, clue: Dictionary) -> Dictionary:
	var state: GameState = context.state
	var clue_id := String(clue.get("id", ""))
	var origin := state.current_port_id()
	_force_resource_alert(context, clue_id)
	var info := await _start_exploration(shell, context, clue_id, 0.0)
	if not bool(info.get("ok", false)):
		return {"ok": false}
	_assert_true(bool(info.get("alert_needed", false)),
		"pinning the departure coal to 1.05x makes explore.start raise the resource alert")
	_assert_true(shell._presentation.has_event, "the alert run schedules the decision point")
	var log_mark := context.commands.get_execution_log(200).size()
	if not await _drive_to_alert(shell):
		return {"ok": false}
	await _settle(6, 0.3)
	var alert := await _assert_alert_page(shell, context, info, true)
	if not bool(alert.get("ok", false)):
		return {"ok": false}
	var coal_at_alert := float(alert.get("coal", 0.0))
	var water_at_alert := float(alert.get("water", 0.0))
	var destination_at_alert := String(shell._presentation_voyage.get("destination", ""))
	if not _press_alert_option(shell, context, "turn_back"):
		return {"ok": false}

	# The decision settles the half-voyage return synchronously in the domain.
	var current := state.current_port_id()
	_assert_eq(current, origin, "turning back returns to the departure harbour")
	_assert_true(state.is_at_port(), "the ship is back in port right after the decision")
	_assert_true(state.explore_voyage() == null,
		"the exploration voyage is settled by explore.decide(turn_back)")
	_assert_eq(String(shell._presentation_voyage.get("destination", "")), origin,
		"the presentation destination becomes the origin harbour")
	_assert_true(bool(shell._presentation_explore.get("returned", false)),
		"the shell records the turn-back so ARRIVAL_READY never re-settles")
	_assert_eq(String(shell._presentation.phase_name()), "arrival_approach",
		"the演出 skips the rest of the route and closes the arrival clouds")
	var coal_after := float(state.ship().get("coal", 0.0))
	var water_after := float(state.ship().get("water", 0.0))
	_assert_true(coal_after < coal_at_alert, "turning back burns extra coal")
	_assert_true(water_after < water_at_alert, "turning back burns extra water")
	_assert_true(_active_has(context, clue_id), "the clue stays active for another attempt")
	_assert_false(shell._status_is_error,
		"the turn-back leaves no error in the status bar (%s)" % shell._status_message)
	var early_explore: Dictionary = {}
	if shell._presentation_summary.get("explore", null) is Dictionary:
		early_explore = shell._presentation_summary["explore"] as Dictionary
	_assert_eq(String(early_explore.get("result", "")), "turned_back",
		"the domain summary reports turned_back immediately after the decision")
	print("[EVIDENCE] decide(turn_back): destination '%s' -> '%s' (%s), coal %.2f -> %.2f, water %.2f -> %.2f, extra_coal=%.2f extra_water=%.2f clue_active=%s" % [
		destination_at_alert, String(shell._presentation_voyage.get("destination", "")), origin,
		coal_at_alert, coal_after, water_at_alert, water_after,
		float(early_explore.get("extra_coal", 0.0)), float(early_explore.get("extra_water", 0.0)),
		str(_active_has(context, clue_id)),
	])

	if not await _drive_to_settlement(shell):
		return {"ok": false}
	await _settle(8, 0.4)
	_assert_log_since(context, log_mark, "turn_back", false)
	_assert_settlement(shell, context, info, "turned_back", "turned_back")
	await _capture(String(SHOTS[6]["file"]), String(SHOTS[6]["label"]))
	return {"ok": true, "clue_id": clue_id, "origin": origin, "target": String(info.get("target", ""))}


## 4.2 · continue: acknowledging the alert must not burn extra resources or reveal the
## destination; the voyage resumes and settles through the normal `explore.settle`.
func _run_alert_continue(shell: Control, context: AppContext, clue_id: String) -> bool:
	var state: GameState = context.state
	_force_resource_alert(context, clue_id)
	var info := await _start_exploration(shell, context, clue_id, 0.0)
	if not bool(info.get("ok", false)):
		return false
	_assert_true(bool(info.get("alert_needed", false)),
		"the continue run really raises the resource alert")
	var log_mark := context.commands.get_execution_log(200).size()
	if not await _drive_to_alert(shell):
		return false
	await _settle(6, 0.3)
	var alert := await _assert_alert_page(shell, context, info, false)
	if not bool(alert.get("ok", false)):
		return false
	var coal_at_alert := float(alert.get("coal", 0.0))
	var water_at_alert := float(alert.get("water", 0.0))
	var destination_at_alert := String(shell._presentation_voyage.get("destination", ""))
	if not _press_alert_option(shell, context, "continue"):
		return false

	# Continue only acknowledges: resources untouched, destination still unknown.
	_assert_eq(String(shell._presentation.phase_name()), "event_resume",
		"continuing resumes the演出 instead of settling it")
	_assert_eq(String(shell._presentation_voyage.get("destination", "unset")), "",
		"continuing keeps the destination unknown until arrival")
	var coal_after := float(state.ship().get("coal", 0.0))
	var water_after := float(state.ship().get("water", 0.0))
	_assert_almost_eq(coal_after, coal_at_alert, 0.0001, "continuing does not burn extra coal")
	_assert_almost_eq(water_after, water_at_alert, 0.0001, "continuing does not burn extra water")
	var voyage: Variant = state.explore_voyage()
	_assert_true(voyage is Dictionary, "the exploration keeps running after acknowledging the alert")
	if voyage is Dictionary:
		_assert_eq(String((voyage as Dictionary).get("alert_decided", "")), "continue",
			"the alert decision is recorded in the domain")
		_assert_almost_eq(float((voyage as Dictionary).get("alert_progress", 0.0)), 1.0, 0.0001,
			"the acknowledged alert is marked complete")
	var chart_explore: Dictionary = {}
	var chart_view := _chart_view(context)
	if chart_view.get("explore", null) is Dictionary:
		chart_explore = chart_view["explore"] as Dictionary
	_assert_eq(String(chart_explore.get("alert_decided", "")), "continue",
		"sea_chart.view exposes the continue decision")
	_assert_almost_eq(float(chart_explore.get("alert_progress", 0.0)), 1.0, 0.0001,
		"sea_chart.view exposes the acknowledged progress")
	# S1: a second answer is rejected by the real command bus (the voyage is still live).
	var repeat := context.commands.execute(&"explore.decide", {"choice": "continue"})
	_assert_false(bool(repeat.get("ok", true)), "a second continue answer is rejected")
	_assert_eq(String(repeat.get("error_code", "")), "alert_already_decided",
		"the repeat answer reports alert_already_decided")
	print("[EVIDENCE] decide(continue): destination '%s' -> '%s', coal %.2f -> %.2f, water %.2f -> %.2f, remaining=%.2fh" % [
		destination_at_alert, String(shell._presentation_voyage.get("destination", "")),
		coal_at_alert, coal_after, water_at_alert, water_after,
		float(alert.get("remaining_hours", 0.0)),
	])

	if not await _drive_to_settlement(shell):
		return false
	await _settle(8, 0.4)
	_assert_log_since(context, log_mark, "alert_continue", true)
	_assert_settlement(shell, context, info, "discovered", "alert_continue")
	await _capture(String(SHOTS[7]["file"]), String(SHOTS[7]["label"]))
	return true


## Command-bus evidence for the 4.2 flows: `explore.decide` must run through the real
## bus, the turn-back must never trigger a second `explore.settle` (that would report
## `not_exploring`), and the continue path must still settle normally.
func _assert_log_since(context: AppContext, mark: int, tag: String, expect_settle: bool) -> void:
	var entries := _commands_since(context, mark)
	var summary: Array[String] = []
	var not_exploring := false
	var decide_ok := false
	var settle_ok := false
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var record: Dictionary = entry
		var command := String(record.get("command", ""))
		var error_code := String(record.get("error_code", ""))
		summary.append(command if error_code.is_empty() else "%s[%s]" % [command, error_code])
		if error_code == "not_exploring":
			not_exploring = true
		if command == "explore.decide" and bool(record.get("ok", false)):
			decide_ok = true
		if command == "explore.settle" and bool(record.get("ok", false)):
			settle_ok = true
	print("[EVIDENCE] commands after %s: %s" % [tag, str(summary)])
	_assert_true(decide_ok, "the decision runs through the real explore.decide command (%s)" % tag)
	_assert_false(not_exploring, "no not_exploring error is raised during the %s path" % tag)
	if expect_settle:
		_assert_true(settle_ok, "the continue path still settles through explore.settle (%s)" % tag)
	else:
		_assert_false(settle_ok,
			"the turn-back path never runs a second explore.settle (%s)" % tag)


func _commands_since(context: AppContext, mark: int) -> Array:
	var log := context.commands.get_execution_log(200)
	var entries: Array = []
	for index in range(mark, log.size()):
		entries.append(log[index])
	return entries


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
	# 与 `AtSeaScreen.HEADING_SAMPLE` 一致（0.004），否则弯道上的采样差会被误判为艏向偏差。
	var backward := VoyagePresentation.sample_polyline(route, maxf(0.0, progress - 0.004))
	var forward := VoyagePresentation.sample_polyline(route, minf(1.0, progress + 0.004))
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


func _texts_contain(texts: Array, needle: String) -> bool:
	for text in texts:
		if String(text).contains(needle):
			return true
	return false


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
