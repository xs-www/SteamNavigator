extends TestCase
## @static-doc
## 作用：新手剧情 UI 冒烟测试：教程局挂出剧情卡 / 目标条、导航与海图入口按功能
## 解锁过滤、剧情卡继续推进阶段、跳过教程的确认页与全解锁；dev.3 #1 的触发时机
## 回归（真实航海驱动：出航收出航指示、抵达才推抵达剧情、事件只上报一次）与
## dev.3 #3 的框架级强制引导遮罩（组件遮罩契约 + Shell 在剧情阶段挂载 / 解析目标 /
## 推进后清除）；2026-10-28 P0 反馈的引导框错位回归（页面/顶栏重建后遮罩目标洞
## 必须追到真实「市场」按钮、提示板保持一行高、四块遮罩贴在目标四边）。
##
## ## 契约与约束
## - 用真实 `main.tscn` 与真实 Core 内容；教程局通过 `run.start tutorial=true` 建立，
##   非教程局用于对照（不弹卡、不门禁）。
## - 只驱动 Shell 的公开信号 / 命令，不断言内部节点布局尺寸；卡片按钮按节点名
##   `ContinueButton` / `SkipButton` / `SkipConfirmButton` 查找。
## - 时间线回归用真实 `voyage.start → _process 逐帧 → _finish_presentation` 驱动，
##   并用 `story.observe` 命令执行日志计数证明「一次玩家动作只上报一次 UI 事件」。
## - 测试跑在单帧里，不能 await；需要「等布局稳定」时用 `Container.NOTIFICATION_SORT_CHILDREN`
##   同步推完挂起的容器排版，再让遮罩 `refresh_target()` 做一帧自愈 tick。
## - 组件测试同时守护皮肤合约：遮罩对 `SNSkin.style()` 的共享 StyleBox 只改 `duplicate()`
##   克隆，不能把 tint / content_margin 污染到全局主题缓存。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const NEW_GAME_SCENE := "res://framework/ui/screens/menu/new_game_screen.tscn"
const FOCUS_OVERLAY_SCRIPT := preload("res://framework/ui/components/sn_focus_overlay.gd")
const STEADY_BUILD := "core:starting_scenario/steady"


func test_tutorial_shell_mounts_card_and_locks_features() -> void:
	var bundle := _mount(true)
	var shell: Control = bundle["shell"]
	assert_not_null(shell._story_card, "the tutorial mounts a story card")
	assert_true(bool(shell._story_card_open), "the story card blocks the page")
	var story_label := shell.find_child("StoryTitle", true, false) as Label
	assert_not_null(story_label, "the card renders a localized title")
	assert_false(String(story_label.text).is_empty(), "the title is translated, not a raw key")
	var nav := _nav_buttons(shell)
	assert_eq(nav.size(), 1, "the opening stage only exposes the overview nav button")
	assert_true(_needs_supply_locked(shell), "supply is not reachable before the briefing")
	var chart_button := shell.find_child("ChartButton", true, false)
	assert_true(chart_button == null, "the chart entry stays hidden in the opening stage")
	_unmount(bundle)


func test_continue_unlocks_market_then_buying_advances_to_the_chart() -> void:
	var bundle := _mount(true)
	var shell: Control = bundle["shell"]
	var continue_button := shell.find_child("ContinueButton", true, false) as Button
	assert_not_null(continue_button, "the opening card has a continue button")
	continue_button.pressed.emit()
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_brief", "continue enters the supply briefing")
	assert_true((shell._story_vm.get("unlocked_features", []) as Array).has("market"),
		"the market nav unlocks")
	assert_eq(_nav_buttons(shell).size(), 2, "overview + market are now in the nav")
	var dismiss := shell.find_child("ContinueButton", true, false) as Button
	assert_not_null(dismiss, "the objective briefing card can be dismissed")
	dismiss.pressed.emit()
	assert_true(shell._story_card == null, "dismissing the briefing hides the card")
	assert_not_null(shell._story_objective, "the non-blocking objective appears after the briefing")
	var objective_label := shell.find_child("ObjectiveLabel", true, false) as Label
	assert_not_null(objective_label, "the objective renders its localized text")
	assert_false(String(objective_label.text).is_empty(), "the objective text is translated")
	# 4.5.3：补给区块就在市场页里。
	shell._active_screen = "market"
	shell._refresh()
	var supply_block := shell.find_child("MarketSupply", true, false)
	assert_not_null(supply_block, "the market page hosts the supply section")
	assert_true(supply_block.get_child_count() >= 2, "the supply section renders coal and water cards")
	# 4.5.2：先买 4 煤 + 2 水 → 补给受限、解锁海图；看海图并关闭 → 恢复补给；
	# 再买 6 煤 → 出航阶段（默认极速），全程仍锁海图以外的功能。
	shell._run_command(&"supply.buy_coal", {"amount": 4})
	shell._run_command(&"supply.buy_water", {"amount": 2})
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_hold", "4 coal + 2 water enter the supply hold")
	assert_true((shell._story_vm.get("unlocked_features", []) as Array).has("chart"),
		"the chart unlocks after provisioning")
	assert_true(Array(shell._story_vm.get("lock_actions", [])).has("supply.buy"),
		"the supply hold locks buying")
	var coal_before := float(shell._context.state.ship().get("coal", 0.0))
	shell._run_command(&"supply.buy_coal", {"amount": 1})
	assert_almost_eq(float(shell._context.state.ship().get("coal", 0.0)), coal_before, 0.001,
		"the locked supply command does not change the bunkers")
	var hold_dismiss := shell.find_child("ContinueButton", true, false) as Button
	assert_not_null(hold_dismiss, "the hold card can be dismissed")
	hold_dismiss.pressed.emit()
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_hold", "dismissing does not advance the stage")
	# 走真实的「打开海图」动作（`ui:chart_opened` 只在玩家动作时上报，页面重建不上报），
	# 打开 → 关闭分别推进剧情。
	shell._on_nav("sea_chart")
	_sync_after_transition(shell)
	assert_eq(String(shell._story_vm.get("stage_id", "")), "chart_brief", "opening the chart advances the story")
	shell._on_sea_chart_closed()
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_finish", "closing the chart restores supplies")
	# 关掉转场并回到稳定页面，继续测试补给恢复后的目标卡。
	shell._transitioning = false
	shell._pending_transition = false
	shell._active_screen = "overview"
	shell._refresh()
	if shell._story_card != null:
		var finish_dismiss := shell.find_child("ContinueButton", true, false) as Button
		assert_not_null(finish_dismiss, "the finish card can be dismissed")
		finish_dismiss.pressed.emit()
	var finish_objective := shell.find_child("ObjectiveLabel", true, false) as Label
	assert_not_null(finish_objective, "the finish stage shows its non-blocking objective")
	if finish_objective != null:
		assert_true(finish_objective.text.contains("8/10"),
			"the objective reports the current bunker (8/10), got: %s" % finish_objective.text)
		assert_true(finish_objective.text.contains("还差 2"),
			"the objective tells the player exactly how much coal is still missing")
	shell._run_command(&"supply.buy_coal", {"amount": 2})
	assert_eq(String(shell._story_vm.get("stage_id", "")), "depart_brief", "10 coal reaches the departure stage")
	assert_eq(String(shell._story_vm.get("preferred_strategy", "")), "fast", "the departure stage prefers Fast")
	assert_eq(shell._chart_departure_strategy(), "core:boiler_strategy/fast", "the departure dialog defaults to Fast")
	_unmount(bundle)


func test_skip_confirmation_unlocks_everything_and_removes_the_card() -> void:
	var bundle := _mount(true)
	var shell: Control = bundle["shell"]
	var skip_button := shell.find_child("SkipButton", true, false) as Button
	assert_not_null(skip_button, "the card offers a skip button")
	skip_button.pressed.emit()
	var confirm_button := shell.find_child("SkipConfirmButton", true, false) as Button
	assert_not_null(confirm_button, "skipping asks for confirmation first")
	confirm_button.pressed.emit()
	assert_true(bool(shell._story_vm.get("completed", false)), "the tutorial is completed")
	assert_true(bool(shell._story_vm.get("skipped", false)), "the tutorial records that it was skipped")
	assert_true(shell._story_card == null, "no card remains after skipping")
	assert_eq(_nav_buttons(shell).size(), _unlocked_nav_count(shell), "every published nav screen is unlocked")
	assert_not_null(shell.find_child("ChartButton", true, false), "the chart entry is available")
	_unmount(bundle)


func test_non_tutorial_shell_has_no_card_and_no_gating() -> void:
	var bundle := _mount(false)
	var shell: Control = bundle["shell"]
	assert_true(shell._story_card == null, "a non-tutorial run has no story card")
	assert_eq(_nav_buttons(shell).size(), _unlocked_nav_count(shell), "a non-tutorial run keeps every published nav screen")
	assert_not_null(shell.find_child("ChartButton", true, false), "the chart entry is available")
	# 4.6 Phase A / C3：没有剧情时 HUD 显示聚合任务追踪（C3 起 auto_start 指引任务
	# 优先于主线），而不是剧情目标条。
	var tracker := shell.find_child("TaskTracker", true, false)
	assert_not_null(tracker, "the HUD shows the aggregated task tracker")
	assert_true(shell.find_child("StoryObjective", true, false) == null, "no story objective is shown")
	var step_label := shell.find_child("TaskStep", true, false) as Label
	assert_not_null(step_label, "the tracker renders its current step")
	var active_task: Dictionary = shell._task_vm.get("active_task", {})
	assert_false(active_task.is_empty(), "the tracker has an active task")
	assert_eq(String(active_task.get("kind", "")), "quest",
		"the auto-started guide quest is the active HUD task (priority 250 > main 200)")
	if step_label != null:
		assert_false(step_label.text.is_empty(), "the active quest step is rendered, got: %s" % step_label.text)
		assert_true(step_label.text.contains("4"), "the guide objective progress is rendered, got: %s" % step_label.text)
	# 委托页顶部有完整的任务追踪面板与步骤。
	shell._transitioning = false
	shell._pending_transition = false
	shell._active_screen = "contracts"
	shell._refresh()
	var texts := _label_texts(shell)
	assert_true(_has_text(texts, "任务追踪") or _has_text(texts, "Task Tracker"),
		"the contracts page hosts the task tracker panel")
	_unmount(bundle)


func _has_text(texts: Array, needle: String) -> bool:
	for text in texts:
		if String(text).contains(needle):
			return true
	return false


func test_new_game_screen_hides_build_picker_in_tutorial_mode() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var scene: PackedScene = load(NEW_GAME_SCENE)
	assert_not_null(scene, "the new-game scene loads")
	var screen: Control = scene.instantiate()
	var vm := {
		"scenarios": [{"id": "core:starting_scenario/steady", "name_key": "build.core.steady.name"}],
		"tutorial_mode": true,
		"selected_scenario": "",
		"seed_text": "",
		"content_total": 1,
		"registry_frozen": true,
		"mods": [],
	}
	screen.bind(vm, Callable(context, "translate"))
	assert_eq(_option_buttons(screen).size(), 0,
		"the tutorial new-game form has no build picker")
	var texts: Array = _label_texts(screen)
	var has_note := false
	for text in texts:
		if String(text).contains("新手剧情") or String(text).contains("Tutorial run"):
			has_note = true
	assert_true(has_note, "the tutorial new-game form explains the fixed teaching ship")
	screen.free()
	# 非教程局仍保留构筑选择。
	var normal: Control = scene.instantiate()
	vm["tutorial_mode"] = false
	normal.bind(vm, Callable(context, "translate"))
	assert_eq(_option_buttons(normal).size(), 1,
		"a non-tutorial new-game form keeps the build picker")
	normal.free()


## dev.3 #1 回归 T1 / T2：真实航海驱动 —— 出航只收掉「出航指示」，抵达剧情只在
## 抵达结算时推进一次；结算页反复重建（剧情卡继续 / resize / 状态刷新）不再重复
## 上报 `ui:arrival_settled`。
func test_first_voyage_advances_the_arrival_story_once_at_arrival() -> void:
	var bundle := _mount(true)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_walk_act0(shell)
	assert_eq(String(shell._story_vm.get("stage_id", "")), "depart_brief",
		"the first act ends on the departure brief")
	var observes_before := _story_observe_count(context)
	var main_contract: Dictionary = context.state.contracts().get("main", {})
	var destination := String(main_contract.get("destination", ""))
	shell._run_command(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": "core:boiler_strategy/fast",
	})
	assert_not_null(shell._presentation, "departing hands over to the voyage presentation")
	assert_eq(String(shell._story_vm.get("stage_id", "")), "first_arrival",
		"departure retires the departure beat; the arrival story must not be current yet")
	assert_true(shell._story_card == null, "no story card appears at departure")
	var saw_arrival_story := false
	var elapsed := 0.0
	# 离港云层（DEPARTURE_VEIL）里来一次页面重建：不能掉回上一页（旧实现会重挂
	# 海图页并重发 `ui:chart_opened`），也不能上报任何剧情事件。
	while shell._presentation != null \
			and String(shell._presentation.phase_name()) != "departure_veil" and elapsed < 12.0:
		shell._process(0.1)
		elapsed += 0.1
	assert_eq(String(shell._presentation.phase_name()), "departure_veil",
		"the departure beat reaches the cloud veil")
	var observes_at_veil := _story_observe_count(context)
	shell._refresh()
	assert_eq(_story_observe_count(context), observes_at_veil,
		"a rebuild during the departure veil reports no story UI event")
	assert_true(shell._at_sea_screen == null,
		"the chart page is not mounted while the departure veil is rising")
	while shell._presentation != null and elapsed < 60.0:
		shell._process(0.1)
		elapsed += 0.1
		if String(shell._story_vm.get("stage_id", "")) == "second_port":
			saw_arrival_story = true
			assert_true(shell._presentation == null,
				"the arrival story only appears after the presentation has finished")
	assert_true(saw_arrival_story, "the arrival beat fires the second-port story on arrival")
	assert_eq(String(shell._story_vm.get("stage_id", "")), "second_port",
		"the first voyage ends in the second-port act")
	assert_eq(_story_observe_count(context) - observes_before, 2,
		"one departure observe + exactly one arrival observe (no rebuild duplicates)")
	var stage_before := String(shell._story_vm.get("stage_id", ""))
	var observes_after_arrival := _story_observe_count(context)
	for _index in 3:
		shell._refresh()
	assert_eq(_story_observe_count(context), observes_after_arrival,
		"rebuilding the settlement page reports no extra ui:arrival_settled")
	assert_eq(String(shell._story_vm.get("stage_id", "")), stage_before,
		"rebuilding the settlement page does not advance the story")
	_unmount(bundle)


## dev.3 #1 回归 T3：海图打开 / 关闭各只在玩家动作时上报一次；页面重建（改策略 /
## 开确认弹窗 / resize）不再重复上报 `ui:chart_opened`。
func test_chart_events_are_reported_once_per_player_action() -> void:
	var bundle := _mount(true)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_walk_to_supply_hold(shell)
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_hold",
		"provisioning enters the chart hold")
	var observes_before := _story_observe_count(context)
	shell._on_nav("sea_chart")
	assert_eq(String(shell._story_vm.get("stage_id", "")), "chart_brief",
		"opening the chart advances the hold stage")
	_sync_after_transition(shell)
	for _index in 2:
		shell._refresh()
	assert_eq(_story_observe_count(context) - observes_before, 1,
		"opening the chart reports ui:chart_opened exactly once, rebuilds report nothing")
	shell._on_sea_chart_closed()
	_sync_after_transition(shell)
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_finish",
		"closing the chart restores supplies")
	assert_eq(_story_observe_count(context) - observes_before, 2,
		"closing the chart reports ui:chart_closed exactly once")
	_unmount(bundle)


## 2026-10-28 P0 回归：页面 / 顶栏重建后容器还没排版完，引导框不能停在重建瞬间的
## 旧矩形（反馈：框在左上角、按钮在右上角）。关闭 supply_brief 剧情卡后等布局稳定，
## 遮罩洞（局部→全局换算）必须与真实「市场」按钮矩形一致、提示板保持一行高度，
## 四块遮罩分别贴在目标的上 / 下 / 左 / 右。
func test_focus_overlay_tracks_the_market_nav_after_rebuild() -> void:
	var bundle := _mount(true)
	var shell: Control = bundle["shell"]
	var continue_button := shell.find_child("ContinueButton", true, false) as Button
	assert_not_null(continue_button, "the opening card can be continued")
	continue_button.pressed.emit()
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_brief",
		"continue enters the supply briefing")
	assert_true(_dismiss_story_card(shell), "the supply briefing card can be dismissed")
	var overlay: Control = shell._story_focus
	assert_not_null(overlay, "dismissing the card mounts the guided mask on the overview")
	assert_true(bool(overlay.call("is_active")), "the mask is active on the supply briefing")
	# 无头测试跑在单帧里，不能 `await process_frame`：用容器自己的
	# `NOTIFICATION_SORT_CHILDREN` 把重建后排版同步推完（与引擎 deferred sort 等价），
	# 再让遮罩做一帧自愈 tick —— 这正是窗口模式下 deferred 重同步 / 逐帧自愈做的事。
	for _pass in 3:
		_force_container_layout(shell)
	assert_true(overlay.has_method("refresh_target"),
		"the overlay can re-read its bound target after the layout settled")
	overlay.call("refresh_target")
	var target: Control = shell._resolve_story_focus_target("market_supply")
	assert_not_null(target, "the market focus target resolves to the nav entry")
	assert_true(target is Button, "the market focus target is the real nav button")
	var nav := shell.find_child("Nav", true, false) as Control
	assert_true(nav != null and nav.is_ancestor_of(target),
		"the resolved target is mounted inside the rebuilt nav row")
	var target_rect := target.get_global_rect()
	assert_true(target_rect.size.x > 0.0 and target_rect.size.y > 0.0,
		"the rebuilt market button has a real layout rect: %s" % target_rect)
	var hole: Rect2 = overlay.call("get_target_rect")
	var hole_global := Rect2(overlay.get_global_rect().position + hole.position, hole.size)
	assert_true(_rect_near(hole_global, target_rect, 8.0),
		"the focus hole follows the market button once layout settles (hole=%s target=%s)" % [hole_global, target_rect])
	var hint := overlay.get_node_or_null("FocusHint") as Control
	assert_not_null(hint, "the hint plate is mounted")
	assert_true(hint.size.y <= 80.0,
		"the hint plate stays a compact strip, not a tall panel (height=%f)" % hint.size.y)
	var masks: Array = overlay.call("get_mask_rects")
	assert_eq(masks.size(), 4, "four mask pieces are visible around the whole-window hole")
	var sides := _mask_sides(masks, hole)
	for side in ["top", "bottom", "left", "right"]:
		assert_true(sides.has(side),
			"a mask strips the %s side of the target (mask rects=%s)" % [side, str(masks)])
	_unmount(bundle)


## dev.3 #3 回归：强制引导遮罩 —— supply_brief 先指向市场入口、进市场后指向补给
## 区块；遮罩只留目标可交互，推进阶段后自动清除。
func test_guided_focus_masks_the_supply_block_and_clears_on_advance() -> void:
	var bundle := _mount(true)
	var shell: Control = bundle["shell"]
	var continue_button := shell.find_child("ContinueButton", true, false) as Button
	assert_not_null(continue_button, "the opening card can be continued")
	continue_button.pressed.emit()
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_brief",
		"continue enters the supply briefing")
	assert_true(shell._story_focus == null,
		"the story card wins: no mask while the briefing card is open")
	assert_true(_dismiss_story_card(shell), "the supply briefing card can be dismissed")
	assert_not_null(shell._story_focus, "dismissing the card mounts the guided mask")
	var overlay: Control = shell._story_focus
	assert_true(bool(overlay.call("is_active")), "the mask is active on the supply briefing")
	var market_nav := _nav_button(shell, "market")
	assert_not_null(market_nav, "the market entry is in the nav once the briefing unlocks it")
	assert_true(_rect_close(overlay.call("get_target_rect"), market_nav.get_global_rect()),
		"on the overview the focus resolves to the market entry")
	# 进入市场：同一阶段把同一语义目标重新解析成真正的补给区块。
	shell._on_nav("market")
	_sync_after_transition(shell)
	overlay = shell._story_focus
	assert_not_null(overlay, "the mask is rebuilt together with the page")
	var supply_block := shell.find_child("MarketSupply", true, false) as Control
	assert_not_null(supply_block, "the market page hosts the supply block")
	assert_true(bool(overlay.call("is_active")), "the mask is still active inside the market")
	var hole: Rect2 = overlay.call("get_target_rect")
	assert_true(_rect_close(hole, supply_block.get_global_rect()),
		"inside the market the focus resolves to the supply block")
	# 四块遮罩拼边；目标横跨整行时左右两块宽度为 0 会被隐藏，所以按「已拼出的边」
	# 断言覆盖率，而组件本身必须建出四块。
	var mask_pieces := 0
	for child in overlay.get_children():
		if String(child.name).begins_with("Mask"):
			mask_pieces += 1
	assert_eq(mask_pieces, 4, "four mask pieces are built around the interactive hole")
	var mask_rects: Array = overlay.call("get_mask_rects")
	assert_false(mask_rects.is_empty(), "the mask covers the page outside the supply block")
	var center := hole.position + hole.size * 0.5
	for mask_rect in mask_rects:
		assert_false((mask_rect as Rect2).has_point(center), "no mask covers the supply block")
	# 买齐 4 煤 2 水 → 进入补给受限：卡片优先，遮罩清除。
	shell._run_command(&"supply.buy_coal", {"amount": 4})
	shell._run_command(&"supply.buy_water", {"amount": 2})
	assert_eq(String(shell._story_vm.get("stage_id", "")), "supply_hold",
		"provisioning advances the hold stage")
	assert_true(shell._story_focus == null or not bool(shell._story_focus.call("is_active")),
		"advancing the stage clears the supply mask")
	_unmount(bundle)


## dev.3 #3 组件契约：全屏遮罩只留目标矩形可点；目标矩形之外四块遮罩全部 STOP，
## 目标内部没有任何遮罩子节点（控件照常收到点击）；窗口尺寸变化后重新排版且不溢出。
func test_focus_overlay_component_masks_everything_but_the_target() -> void:
	var overlay: Control = FOCUS_OVERLAY_SCRIPT.new()
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the overlay root never blocks the interactive hole")
	assert_false(bool(overlay.call("is_active")), "a fresh overlay is inactive")
	# 2026-10-28 P0：`SNSkin.style()` 返回按 id 缓存的共享 StyleBox；遮罩只能改克隆，
	# 不能把 tint / content_margin 写回全局主题（否则其他面板跟着变）。
	var shared_ring := SNSkin.style("focus_ring")
	var ring_tint_before: Variant = null
	if shared_ring is StyleBoxTexture:
		ring_tint_before = (shared_ring as StyleBoxTexture).modulate_color
	var shared_text := SNSkin.style("panel_steel")
	if shared_text == null:
		shared_text = SNSkin.style("panel_recess")
	var text_margins_before: Variant = null
	if shared_text != null:
		text_margins_before = Vector4(
			shared_text.content_margin_left, shared_text.content_margin_top,
			shared_text.content_margin_right, shared_text.content_margin_bottom
		)
	overlay.size = Vector2(960, 540)
	var target := Rect2(120, 90, 260, 64)
	overlay.call("focus", target, "click here")
	assert_true(bool(overlay.call("is_active")), "focus() activates the overlay")
	if shared_ring is StyleBoxTexture:
		assert_eq((shared_ring as StyleBoxTexture).modulate_color, ring_tint_before,
			"the ring tints its own StyleBox clone, leaving the shared skin cache untouched")
	if shared_text != null:
		assert_eq(Vector4(
			shared_text.content_margin_left, shared_text.content_margin_top,
			shared_text.content_margin_right, shared_text.content_margin_bottom
		), text_margins_before,
			"the hint plate overrides content margins on a clone, leaving the shared skin cache untouched")
	overlay.visible = true
	assert_eq(String(overlay.call("get_focus_text")), "click here", "the hint text is exposed")
	var hole: Rect2 = overlay.call("get_target_rect")
	assert_true(_rect_close(hole, target), "the hole is the requested target rect")
	var masks: Array = overlay.call("get_mask_rects")
	assert_eq(masks.size(), 4, "four mask pieces cover everything outside the hole")
	var center := target.position + target.size * 0.5
	for mask_rect in masks:
		assert_false((mask_rect as Rect2).has_point(center), "no mask covers the target")
	for point in [Vector2(2, 2), Vector2(958, 2), Vector2(2, 538), Vector2(958, 538),
			Vector2(600, 20), Vector2(600, 500), Vector2(20, 300)]:
		assert_true(_mask_covers_point(masks, point), "everything outside the hole is masked (%s)" % point)
	for child in overlay.get_children():
		if String(child.name).begins_with("Mask"):
			assert_eq(Control.MOUSE_FILTER_STOP, (child as Control).mouse_filter,
				"mask pieces eat clicks outside the hole")
			if SNSkin.is_available():
				assert_not_null(child.get_node_or_null("Skin"),
					"the mask is a SNSkin nine-slice fill, not a flat rectangle")
	# 1440×900：重新排版，遮罩不溢出、目标矩形不变。
	overlay.size = Vector2(1440, 900)
	overlay.notification(Control.NOTIFICATION_RESIZED)
	assert_true(_rect_close(overlay.call("get_target_rect"), target),
		"resizing keeps the same interactive hole")
	for mask_rect in overlay.call("get_mask_rects"):
		var rect := mask_rect as Rect2
		assert_true(rect.position.x >= 0.0 and rect.position.y >= 0.0, "masks stay inside the screen")
		assert_true(rect.end.x <= 1440.0 and rect.end.y <= 900.0, "masks stay inside the screen")
	overlay.call("clear_focus")
	assert_false(bool(overlay.call("is_active")), "clear_focus() deactivates the overlay")
	assert_false(overlay.visible, "clear_focus() hides the overlay")
	assert_true((overlay.call("get_mask_rects") as Array).is_empty(), "no mask remains after clearing")
	overlay.free()


# ── helpers ──


func _mount(tutorial: bool) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": 20260421,
		"tutorial": tutorial,
	})
	assert_true(bool(started.get("ok", false)), "run.start succeeds in the story UI fixture: %s" % str(started))
	var scene: PackedScene = load(MAIN_SCENE)
	assert_not_null(scene, "the playable shell scene loads")
	var shell: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shell)
	assert_true(shell.is_inside_tree(), "the shell fixture is inside the scene tree")
	return {"context": context, "shell": shell, "tree": tree}


func _unmount(bundle: Dictionary) -> void:
	var shell: Control = bundle["shell"]
	if shell.get_parent() != null:
		shell.get_parent().remove_child(shell)
	shell.free()


func _nav_buttons(shell: Control) -> Array:
	var nav := shell.find_child("Nav", true, false)
	if nav == null:
		return []
	var buttons: Array = []
	for child in nav.get_children():
		if child is Button:
			buttons.append(child)
	return buttons


## Nav button count once every story feature is unlocked: published `SCREENS`
## pages (unpublished systems in `HIDDEN_NAV_SCREENS` have no entry) + the chart
## toggle. Derived from the shell constants so adding / unhiding a page keeps the
## tutorial tests honest instead of hard-coding a number.
func _unlocked_nav_count(shell: Control) -> int:
	var constants: Dictionary = shell.get_script().get_script_constant_map()
	var screens: Array = Array(constants.get("SCREENS", []))
	var hidden: Array = Array(constants.get("HIDDEN_NAV_SCREENS", []))
	var visible := 0
	for screen in screens:
		if not hidden.has(String(screen)):
			visible += 1
	return visible + 1


func _needs_supply_locked(shell: Control) -> bool:
	# The market page (which now hosts supplies) is gated through the story VM;
	# the nav must not expose it while the feature is locked.
	var before := String(shell._active_screen)
	shell._on_nav("market")
	return String(shell._active_screen) == before


func _option_buttons(root_node: Node, out: Array = []) -> Array:
	for child in root_node.get_children():
		if child is OptionButton:
			out.append(child)
		_option_buttons(child, out)
	return out


func _label_texts(root_node: Node, out: Array = []) -> Array:
	for child in root_node.get_children():
		if child is Label:
			out.append(String((child as Label).text))
		_label_texts(child, out)
	return out


# ── story timing / guided-focus helpers (dev.3 #1 / #3) ──


## Walks Act 0 with the same actions a player takes and stops on `depart_brief`
## (10 coal aboard, departure instructions dismissed).
func _walk_act0(shell: Control) -> void:
	var continue_button := shell.find_child("ContinueButton", true, false) as Button
	assert_not_null(continue_button, "the opening card has a continue button")
	continue_button.pressed.emit()
	_dismiss_story_card(shell)
	shell._run_command(&"supply.buy_coal", {"amount": 4})
	shell._run_command(&"supply.buy_water", {"amount": 2})
	# 海图：打开 → 关闭（supply_hold → chart_brief → supply_finish）。
	shell._on_nav("sea_chart")
	_sync_after_transition(shell)
	shell._on_sea_chart_closed()
	_sync_after_transition(shell)
	shell._active_screen = "overview"
	shell._refresh()
	_dismiss_story_card(shell)
	shell._run_command(&"supply.buy_coal", {"amount": 2})
	_dismiss_story_card(shell)


## Continues the tutorial only as far as the chart-hold stage (4 coal + 2 water),
## leaving the chart unopened.
func _walk_to_supply_hold(shell: Control) -> void:
	var continue_button := shell.find_child("ContinueButton", true, false) as Button
	assert_not_null(continue_button, "the opening card has a continue button")
	continue_button.pressed.emit()
	_dismiss_story_card(shell)
	shell._run_command(&"supply.buy_coal", {"amount": 4})
	shell._run_command(&"supply.buy_water", {"amount": 2})


## The real navigation path starts a page fade (`_refresh(true)`); headless tests
## cannot wait for its tween, so settle it and rebuild synchronously.
func _sync_after_transition(shell: Control) -> void:
	shell._transitioning = false
	shell._pending_transition = false
	shell._refresh()


func _dismiss_story_card(shell: Control) -> bool:
	if shell._story_card == null:
		return false
	var button := shell.find_child("ContinueButton", true, false) as Button
	if button == null:
		return false
	button.pressed.emit()
	return true


## Number of `story.observe` commands executed so far (the Shell forwards every
## command / UI story event through it), used to prove one-shot UI events.
func _story_observe_count(context: AppContext) -> int:
	var count := 0
	for entry in context.commands.get_execution_log(200):
		if String((entry as Dictionary).get("command", "")) == "story.observe":
			count += 1
	return count


func _nav_button(shell: Control, screen: String) -> Button:
	var nav := shell.find_child("Nav", true, false)
	if nav == null:
		return null
	var wanted := String(shell.call("_tr", "ui.nav.%s" % screen, screen))
	for child in nav.get_children():
		if child is Button and String((child as Button).text) == wanted:
			return child
	return null


func _rect_close(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 2.0 \
		and abs(a.size.x - b.size.x) <= 2.0 \
		and abs(a.size.y - b.size.y) <= 2.0


## P0 回归用：同步推完重建后挂起的容器排版。引擎里 Container 的 deferred sort 就是
## `NOTIFICATION_SORT_CHILDREN`；逐个 Container 手动发一次等于立刻「等一帧布局」。
func _force_container_layout(node: Node) -> void:
	if node is Container:
		(node as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		_force_container_layout(child)


## Hole / target tolerance check used by the P0 regression (the plan allows ≤ 8 px).
func _rect_near(a: Rect2, b: Rect2, tolerance: float) -> bool:
	return a.position.distance_to(b.position) <= tolerance \
		and absf(a.size.x - b.size.x) <= tolerance \
		and absf(a.size.y - b.size.y) <= tolerance


## Classifies the four mask pieces around `hole` (local coords) into top / bottom /
## left / right by which side of the hole they strip.
func _mask_sides(masks: Array, hole: Rect2) -> Array:
	var sides: Array = []
	for mask in masks:
		var rect := mask as Rect2
		if rect.end.y <= hole.position.y + 1.0:
			sides.append("top")
		elif rect.position.y >= hole.end.y - 1.0:
			sides.append("bottom")
		elif rect.end.x <= hole.position.x + 1.0:
			sides.append("left")
		elif rect.position.x >= hole.end.x - 1.0:
			sides.append("right")
	return sides


func _mask_covers_point(masks: Array, point: Vector2) -> bool:
	for mask_rect in masks:
		if (mask_rect as Rect2).has_point(point):
			return true
	return false
