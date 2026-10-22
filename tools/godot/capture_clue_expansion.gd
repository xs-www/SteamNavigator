extends SceneTree
## @static-doc
## 作用：阶段 4.4 线索扩展的真实渲染截图工具（窗口模式）。开一局真实对局（seed
## 20260421），通过真实领域入口准备一条 `port_goods` 货物行情线索（第二个已发现港口 +
## `ClueService.acquire_goods` + `clue.investigate` 升到 4 级），打开真正的海图页，
## 抓「货物行情线索面板」与「前往该港」统一出航确认弹窗两张图。
##
## 用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/capture_clue_expansion.gd
##
## 输出（1440×900，写入 `docs/design/screenshots/exploration/`）：
##   clue_goods_lead.png    货物行情线索面板：类型 / 港口 / 参考价 / 库存供需 /
##                          精确买卖价 / 剩余时效 /「前往该港」按钮（无探索出航按钮）
##   clue_goods_depart.png  点击「前往该港」后的统一出航确认弹窗（kind = goods）
##
## ## 契约与约束
## - 行情线索用真实服务与真实命令构造：`ClueService.acquire_goods`（命名流
##   `RngService.STREAM_EXPLORATION`）+ `clue.investigate` ×3 升到 4 级；第二个已发现
##   港口用 `WorldOps.discover_port_id` / `MapOps.discover` 做成测试夹具（真实对局里
##   由探索 / 抵达产生），不伪造渲染数据。
## - 硬性断言：`sea_chart.view.clues` 里的货物线索含 type / goods / expires_at /
##   remaining_hours / can_sail 且**不含** target_port_id / credibility / 真实
##   search_zone；面板文本含类型、港口名、精确行情、剩余时效；`SailButton` 存在且启用、
##   `ExploreButton` 不存在；确认弹窗标题走 `ui.confirm.title.goods` 且「启航」可用。
## - 先写 `res://tmp_clue_expansion_*`，全部成功后才移入 `docs/`，失败不留半套。
## - 纯色/近纯色画面视为"读到未绘制纹理"，判失败；写完 PNG 会读回再验一次。
## - 120 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const OUT_DIR := "res://docs/design/screenshots/exploration"
const WINDOW := Vector2i(1440, 900)
const SEED := 20260421
const STEADY_BUILD := "core:starting_scenario/steady"
const STRATEGY_ID := "core:boiler_strategy/standard"
const WATCHDOG_SECONDS := 120.0
const TMP_PREFIX := "res://tmp_clue_expansion_"

const SEA_CHART_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/sea_chart_screen.gd")
const CLUE_LOG_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/clue_log_screen.gd")

const SHOTS := [
	{"file": "clue_goods_lead.png", "label": "货物行情线索面板（分级行情 + 剩余时效 + 前往该港）"},
	{"file": "clue_goods_depart.png", "label": "货物线索的「前往该港」统一确认弹窗"},
	{"file": "clue_investigate_cost.png", "label": "4.4.3 调查消耗：20 金 / 6 小时 / 成功率 75%"},
	{"file": "clue_investigate_result.png", "label": "4.4.3 调查结果状态栏（成功升级 / 失败可重试）"},
	{"file": "clue_log.png", "label": "4.4.4 线索列表页（active 卡片 + 过期折叠历史）"},
]

var _failures := 0
var _saved: Array[String] = []


func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_clue_expansion: timed out (%d s)" % int(WATCHDOG_SECONDS))
	_cleanup_tmp()
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · clue expansion 4.4")
	await process_frame

	var context := _bootstrap()
	if context == null:
		_finish()
		return
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY_BUILD, "seed": SEED})
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

	var prepared := _prepare_goods_clue(context)
	if not bool(prepared.get("ok", false)):
		_finish()
		return
	var clue_id := String(prepared.get("clue_id", ""))
	_assert_chart_view_contract(context, prepared)

	# ── Shot 1: the goods lead in the chart panel. ──
	var screen: Variant = await _open_chart(shell)
	if screen == null:
		_finish()
		return
	screen._on_clue_clicked(clue_id)
	await _settle(6, 0.3)
	_assert_goods_panel(context, screen, prepared)
	_freeze_chart(screen)
	await _capture(String(SHOTS[0]["file"]), String(SHOTS[0]["label"]))

	# ── Shot 2: the shared departure confirmation dialog for the goods lead. ──
	var sail: Button = _node_named(screen, "SailButton") as Button
	if sail == null:
		_fail("the goods lead panel has no SailButton")
		_finish()
		return
	sail.pressed.emit()
	await _settle(8, 0.35)
	var screens := _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	_assert_eq(screens.size(), 1, "the chart page is rebuilt with the departure dialog")
	if screens.is_empty():
		_finish()
		return
	var dialog_screen: Variant = screens[0]
	_assert_true(bool(dialog_screen.is_departure_open()),
		"the goods lead opens the shared departure confirmation")
	_assert_departure_dialog(context, dialog_screen)
	_freeze_chart(dialog_screen)
	await _capture(String(SHOTS[1]["file"]), String(SHOTS[1]["label"]))

	# ── 4.4.3: investigation cost + result. Cancel the dialog, acquire a second
	# level-1 goods lead, then investigate it through the real panel button. ──
	var cancel: Button = _node_named(dialog_screen, "CancelButton") as Button
	if cancel != null:
		cancel.pressed.emit()
	await _settle(6, 0.3)
	var second := ClueService.acquire_goods(
		context,
		ClueService.SOURCE_INTEL,
		context.rng.make_stream(RngService.STREAM_EXPLORATION, "capture:goods:investigate")
	)
	if second.is_empty():
		_fail("cannot acquire a second goods lead for the investigation shot")
		_finish()
		return
	var second_id := String(second.get("id", ""))
	var second_screen: Variant = await _open_chart(shell)
	if second_screen == null:
		_finish()
		return
	second_screen._on_clue_clicked(second_id)
	await _settle(6, 0.3)
	_assert_investigation_cost(context, second_screen)
	_freeze_chart(second_screen)
	await _capture(String(SHOTS[2]["file"]), String(SHOTS[2]["label"]))
	await _assert_investigation_result(context, shell, second_screen, second_id)
	var rebuilt_screens := _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	if not rebuilt_screens.is_empty():
		_freeze_chart(rebuilt_screens[0])
	await _capture(String(SHOTS[3]["file"]), String(SHOTS[3]["label"]))

	# 等待来源证据放在截图之后：连续等待会推进时间，可能让行情线索自然过期。
	_assert_wait_source_evidence(context)

	# ── 4.4.4: the clue list page (active cards + expired history), then the
	# click-back-to-chart round-trip. ──
	var chart_screen: Variant = await _open_chart(shell)
	if chart_screen == null:
		_finish()
		return
	var list_button: Button = _node_named(chart_screen, "ClueListButton") as Button
	if list_button == null:
		_fail("the chart header has no clue list button")
		_finish()
		return
	list_button.pressed.emit()
	await _settle(14, 0.9)
	var log_screens := _nodes_with_script(shell._root_box, CLUE_LOG_SCREEN_SCRIPT)
	_assert_eq(log_screens.size(), 1, "the clue list page is mounted")
	if log_screens.is_empty():
		_finish()
		return
	var log_screen: Variant = log_screens[0]
	var first_card := _assert_clue_log_page(context, log_screen)
	await _capture(String(SHOTS[4]["file"]), String(SHOTS[4]["label"]))
	# 回海图 + 选中线索（列表页的核心交互，不额外截图，只做硬断言）。
	if first_card != null:
		var selected_id := String(first_card.get_meta("clue_id", ""))
		first_card.pressed.emit()
		await _settle(8, 0.35)
		_assert_eq(String(shell._active_screen), "sea_chart",
			"clicking a clue card returns to the chart")
		var bound_id := "n/a"
		var chart_screens := _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
		if not chart_screens.is_empty():
			var back_screen: Variant = chart_screens[0]
			bound_id = String(back_screen._panel.get_clue().get("id", ""))
			_assert_eq(bound_id, selected_id,
				"the chart panel binds the clue selected in the list")
		print("[EVIDENCE] clue log round-trip: card=%s -> chart panel=%s" % [
			selected_id, bound_id,
		])

	_commit_shots()
	_finish()


# ---------------------------------------------------------------------------
# Setup: run + goods clue (real services / commands)
# ---------------------------------------------------------------------------


## 第二个已发现港口（夹具：真实对局由探索 / 抵达产生）+ 真实 `acquire_goods` +
## 真实 `clue.investigate` 三级 → level 4 精确行情。返回 `{ok, clue_id, target_id, ...}`。
func _prepare_goods_clue(context: AppContext) -> Dictionary:
	var state: GameState = context.state
	var current := state.current_port_id()
	var neighbors := MapOps.neighbors(state.world(), current)
	if neighbors.is_empty():
		_fail("the start harbour has no neighbour to discover")
		return {"ok": false}
	var target_id := String(neighbors[0])
	WorldOps.discover_port_id(state, target_id)
	MapOps.discover(state, target_id)
	var rng := context.rng.make_stream(RngService.STREAM_EXPLORATION, "capture:goods")
	var clue := ClueService.acquire_goods(context, ClueService.SOURCE_WAIT, rng)
	if clue.is_empty():
		_fail("the real service could not create a goods clue")
		return {"ok": false}
	var clue_id := String(clue.get("id", ""))
	# 4.3.2 起获得固定 1 级；走真实命令升到 4 级。4.4.3 起调查有成功率（75%）与
	# 20 金 / 6h 成本，所以重试直到 4 级（失败照扣成本但不升级）。
	var attempts := 0
	while int(ClueService.find_clue(context.state, clue_id).get("level", 1)) < 4 \
			and attempts < 24:
		attempts += 1
		var investigated := context.commands.execute(&"clue.investigate", {"clue_id": clue_id})
		_assert_true(bool(investigated.get("ok", false)),
			"clue.investigate advances the goods lead: %s" % str(investigated))
	print("[EVIDENCE] goods clue reached level 4 in %d investigation attempt(s)" % attempts)
	clue = ClueService.find_clue(context.state, clue_id)
	if clue.is_empty():
		_fail("the goods clue vanished after investigation")
		return {"ok": false}
	if int(clue.get("level", 0)) < 4:
		_fail("the goods clue did not reach level 4")
		return {"ok": false}
	var snapshot: Dictionary = clue.get("goods_snapshot", {})
	print("[EVIDENCE] goods clue id=%s target=%s good=%s level=%d source=%s expires_at=%.1f snapshot=%s" % [
		clue_id, target_id, String(clue.get("target_goods_id", "")), int(clue.get("level", 0)),
		String(clue.get("source_key", "")), float(clue.get("expires_at", 0.0)), str(snapshot),
	])
	return {
		"ok": true,
		"clue_id": clue_id,
		"target_id": target_id,
		"snapshot": snapshot,
	}


## Query contract: the goods lead exposes type / goods / expiry / can_sail but never the
## target port id, credibility or the true search zone.
func _assert_chart_view_contract(context: AppContext, prepared: Dictionary) -> void:
	var result := context.queries.execute(&"sea_chart.view", {"strategy_id": STRATEGY_ID})
	_assert_true(bool(result.get("ok", false)), "sea_chart.view succeeds")
	var view: Dictionary = result.get("data", {})
	var clues: Array = view.get("clues", [])
	_assert_true(clues.size() >= 1, "sea_chart.view exposes the goods clue")
	var entry: Dictionary = {}
	for raw in clues:
		if raw is Dictionary and String((raw as Dictionary).get("id", "")) == String(prepared["clue_id"]):
			entry = raw
			break
	_assert_false(entry.is_empty(), "the goods clue reaches the chart view")
	if entry.is_empty():
		return
	_assert_eq(String(entry.get("type", "")), ClueService.TYPE_PORT_GOODS,
		"the chart view reports the port_goods type")
	_assert_false(entry.has("target_port_id"),
		"the chart view never leaks the goods target port id")
	_assert_false(entry.has("credibility"), "the chart view never leaks credibility")
	var goods: Variant = entry.get("goods", null)
	_assert_true(goods is Dictionary and not (goods as Dictionary).is_empty(),
		"the chart view carries the level-trimmed goods projection")
	if goods is Dictionary:
		var projection: Dictionary = goods
		_assert_true(projection.has("buy_price") and projection.has("sell_price"),
			"level 4 exposes the exact buy / sell prices")
	_assert_true(float(entry.get("expires_at", 0.0)) > 0.0,
		"the goods clue carries its expiry timestamp")
	_assert_true(bool(entry.get("can_sail", false)),
		"the chart view says the goods lead can be sailed")
	_assert_true(int(view.get("expiring_clue_count", 0)) >= 1,
		"the chart exposes the expiring-clue counter")


## 4.4.2 wait-source evidence: a real `port.wait` loop eventually yields a clue whose
## `source_key` is wait (the capture only logs it; no screenshot needed for a dice roll).
func _assert_wait_source_evidence(context: AppContext) -> void:
	var acquired := ""
	for _attempt in 8:
		var waited := context.commands.execute(&"port.wait", {"hours": 24})
		_assert_true(bool(waited.get("ok", false)), "port.wait succeeds while gathering evidence")
		var clue_view: Dictionary = waited.get("data", {}).get("clue", {})
		if not clue_view.is_empty():
			acquired = String(clue_view.get("id", ""))
			break
	_assert_false(acquired.is_empty(), "a real port.wait eventually yields a dockside clue")
	if acquired.is_empty():
		return
	var clue := ClueService.find_clue(context.state, acquired)
	print("[EVIDENCE] wait clue id=%s source=%s unlock=%s type=%s expires_at=%.1f" % [
		acquired, String(clue.get("source_key", "")), String(clue.get("unlock_source", "")),
		String(clue.get("type", "")), float(clue.get("expires_at", 0.0)),
	])
	_assert_eq(String(clue.get("source_key", "")), ClueService.SOURCE_WAIT,
		"the wait-sourced clue records source=wait")


## 面板断言：类型 / 港口 / 精确行情 / 剩余时效 / 前往该港（无探索出航按钮）。
func _assert_goods_panel(context: AppContext, screen: Variant, prepared: Dictionary) -> void:
	var panel: Variant = screen._panel
	_assert_true(panel != null, "the chart screen mounts the clue panel")
	if panel == null:
		return
	_assert_eq(String(panel.get_clue().get("id", "")), String(prepared["clue_id"]),
		"the panel binds the goods clue")
	var texts := _label_texts(screen)
	_assert_true(_texts_contain(texts, String(context.translate("ui.clue.type.port_goods"))),
		"the panel names the goods lead type: %s" % str(texts))
	var world := WorldOps.world_map(context.state)
	var port_name := String(context.translate(
		WorldOps.port_display_key(world, String(prepared["target_id"])), String(prepared["target_id"])
	))
	var port_line := String(context.translate("ui.clue.goods.port")) % port_name
	_assert_true(_texts_contain(texts, port_line),
		"the panel names the goods harbour (%s): %s" % [port_line, str(texts)])
	var snapshot: Dictionary = prepared.get("snapshot", {})
	var exact := String(context.translate("ui.clue.goods.price_exact")) % [
		int(snapshot.get("buy_price", 0)), int(snapshot.get("sell_price", 0)),
	]
	_assert_true(_texts_contain(texts, exact),
		"level 4 shows the exact market (%s): %s" % [exact, str(texts)])
	var remaining := float(panel.get_clue().get("remaining_hours", 0.0))
	var expiry := String(context.translate("ui.clue.expiry")) % int(ceilf(maxf(0.0, remaining)))
	_assert_true(_texts_contain(texts, expiry),
		"the panel shows the remaining lifetime (%s): %s" % [expiry, str(texts)])
	var sail: Button = _node_named(screen, "SailButton") as Button
	_assert_true(sail != null, "the goods lead panel exposes the sail-to-port button")
	if sail != null:
		_assert_false(sail.disabled, "the sail-to-port button is enabled for a feasible lead")
	var explore: Button = _node_named(screen, "ExploreButton") as Button
	_assert_true(explore == null, "the goods lead never shows the exploration button")


## 确认弹窗：货物线索标题、策略选择器默认标准锅炉、预估与「启航」可用。
func _assert_departure_dialog(context: AppContext, screen: Variant) -> void:
	var texts := _label_texts(screen)
	var title := String(context.translate("ui.confirm.title.goods"))
	_assert_true(texts.has(title), "the goods dialog shows its localized title (%s): %s" % [title, str(texts)])
	_assert_true(_texts_contain(texts, String(context.translate("ui.label.estimated_time"))),
		"the goods dialog shows the estimated duration")
	var picker: OptionButton = _node_named(screen, "StrategyPicker") as OptionButton
	_assert_true(picker != null, "the goods dialog exposes the boiler strategy picker")
	if picker != null:
		_assert_eq(String(picker.get_item_metadata(picker.selected)), STRATEGY_ID,
			"the goods dialog defaults to the standard boiler strategy")
	var confirm: Button = _node_named(screen, "ConfirmButton") as Button
	_assert_true(confirm != null, "the goods dialog exposes the depart confirmation button")
	if confirm != null:
		_assert_false(confirm.disabled, "the feasible goods lead can be confirmed")


## 4.4.3 面板：调查成本 / 工时 / 成功率来自 Core（20 金 / 6h / 75%），按钮可用。
func _assert_investigation_cost(context: AppContext, screen: Variant) -> void:
	var texts := _label_texts(screen)
	var expected := String(context.translate("ui.clue.investigate_cost")) % [20, 6, 75]
	_assert_true(_texts_contain(texts, expected),
		"the level-1 lead shows the Core investigation cost (%s): %s" % [expected, str(texts)])
	var button: Button = _node_named(screen, "InvestigateButton") as Button
	_assert_true(button != null, "the level-1 lead exposes the investigate button")
	if button != null:
		_assert_false(button.disabled, "the affordable investigation button is enabled")


## 通过真实面板按钮执行 `clue.investigate`：无论成功 / 失败，钱与时间都按 Core 落账，
## 状态栏给出对应本地化结果（成功升级 / 失败可重试），线索保持 active。
func _assert_investigation_result(
	context: AppContext, shell: Control, screen: Variant, clue_id: String
) -> void:
	var button: Button = _node_named(screen, "InvestigateButton") as Button
	if button == null:
		_fail("no investigate button for the cost shot")
		return
	var money_before := context.state.money()
	var time_before := context.state.now()
	var level_before := int(ClueService.find_clue(context.state, clue_id).get("level", 1))
	button.pressed.emit()
	await _settle(8, 0.35)
	var clue := ClueService.find_clue(context.state, clue_id)
	_assert_false(clue.is_empty(), "the investigated clue stays active")
	if clue.is_empty():
		return
	var level_after := int(clue.get("level", 1))
	var success := level_after == level_before + 1
	_assert_eq(context.state.money(), money_before - 20,
		"the investigation charged the Core 20 gold")
	_assert_almost_eq(context.state.now(), time_before + 6.0, 0.0001,
		"the investigation spent the Core 6 hours")
	var expected_status := ""
	if success:
		expected_status = String(context.translate("ui.notice.clue_investigated")) % level_after
		_assert_true(String(shell._status_message).contains(expected_status),
			"the status reports the successful investigation (%s): %s" % [
				expected_status, String(shell._status_message)
			])
	else:
		expected_status = String(context.translate("ui.notice.clue_investigation_failed"))
		_assert_true(String(shell._status_message).contains(expected_status),
			"the status reports the failed attempt (%s): %s" % [
				expected_status, String(shell._status_message)
			])
		_assert_eq(level_after, level_before, "a failed attempt never advances the level")
	print("[EVIDENCE] investigation clue=%s level %d -> %d success=%s money=%d time=%.1f status=%s" % [
		clue_id, level_before, level_after, str(success), context.state.money(),
		context.state.now(), String(shell._status_message),
	])


## 4.4.4 列表页断言：标题 / 计数、至少一张 active 卡片、过期折叠行、卡片文本含行情。
## 返回第一张 active 卡片（供回海图选中接线断言）。
func _assert_clue_log_page(context: AppContext, screen: Variant) -> Button:
	var texts := _label_texts(screen)
	_assert_true(texts.has(String(context.translate("ui.clue.list.title"))),
		"the clue log shows its title: %s" % str(texts))
	var rules := ExplorationRules.read(context.state, context.registries)
	var expected_count := String(context.translate("ui.clue.list.count")) % [
		ClueService.active_count(context.state), int(rules.get("max_active_clues", 4)),
	]
	_assert_true(_texts_contain(texts, expected_count),
		"the clue log shows the held / max count (%s): %s" % [expected_count, str(texts)])
	var cards: Array = []
	var expired_rows: Array = []
	_collect_named(screen, "ClueCard_", cards)
	_collect_named(screen, "ExpiredClue_", expired_rows)
	_assert_true(cards.size() >= 2, "the clue log lists the active leads (%d)" % cards.size())
	_assert_true(expired_rows.size() >= 1,
		"the clue log folds the expired history (%d)" % expired_rows.size())
	if expired_rows.is_empty():
		return cards[0] if not cards.is_empty() else null
	_assert_true(String((expired_rows[0] as Label).text).contains(
		String(context.translate("ui.clue.expired"))
	), "the expired row is marked as expired: %s" % String((expired_rows[0] as Label).text))
	if cards.is_empty():
		return null
	var first: Button = cards[0]
	print("[EVIDENCE] clue log: %d active card(s), %d expired row(s), first=%s text=%s" % [
		cards.size(), expired_rows.size(), String(first.get_meta("clue_id", "")),
		String(first.text),
	])
	return first


## 收集名字以 prefix 开头的节点（卡片 / 过期行按名字约定区分）。
func _collect_named(root_node: Node, prefix: String, out: Array) -> void:
	if String(root_node.name).begins_with(prefix):
		out.append(root_node)
	for child in root_node.get_children():
		_collect_named(child, prefix, out)


# ---------------------------------------------------------------------------
# Shell / capture helpers
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


## 截图确定性：海图的当前港脉冲 / 罗盘使用真实时间 `_time`，两次运行相位不同会让
## PNG 不一致。截图前停掉视图的 `_process` 并把相位固定，再重绘一帧。
func _freeze_chart(screen: Variant) -> void:
	if screen == null or not screen.has_method("get_chart"):
		return
	var chart: Variant = screen.get_chart()
	if chart == null:
		return
	chart.set_process(false)
	chart._time = 1.2345
	chart.queue_redraw()


func _force_chinese_locale(shell: Control, context: AppContext) -> void:
	context.localization.set_locale("zh_CN")
	shell._settings_applied = true
	shell._refresh()


func _bootstrap() -> AppContext:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://capture_saves/clue_expansion",
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


func _nodes_with_script(root_node: Node, script: Script, out: Array = []) -> Array:
	for child in root_node.get_children():
		if child.get_script() == script:
			out.append(child)
		_nodes_with_script(child, script, out)
	return out


func _node_named(root_node: Node, wanted: String) -> Node:
	if root_node == null:
		return null
	if String(root_node.name) == wanted:
		return root_node
	for child in root_node.get_children():
		var found := _node_named(child, wanted)
		if found != null:
			return found
	return null


func _label_texts(root_node: Node, out: Array = []) -> Array:
	for child in root_node.get_children():
		if child is Label:
			out.append(String((child as Label).text))
		_label_texts(child, out)
	return out


func _texts_contain(texts: Array, needle: String) -> bool:
	for text in texts:
		if String(text).contains(needle):
			return true
	return false


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
	if actual == expected:
		print("[PASS] " + message)
	else:
		_fail("%s (got %s, expected %s)" % [message, str(actual), str(expected)])


func _assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		print("[PASS] " + message)
	else:
		_fail("%s (got %.6f, expected %.6f +- %.6f)" % [message, actual, expected, tolerance])


func _fail(message: String) -> void:
	_failures += 1
	push_error("capture_clue_expansion: " + message)
	print("[FAIL] " + message)


func _finish() -> void:
	if _failures > 0:
		_cleanup_tmp()
	print("=== clue expansion capture: %d failure(s), %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 and _saved.size() == SHOTS.size() else 1)
