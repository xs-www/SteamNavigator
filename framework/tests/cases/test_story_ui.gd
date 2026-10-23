extends TestCase
## @static-doc
## 作用：阶段 4.5.1 新手剧情 UI 冒烟测试：教程局挂出剧情卡 / 目标条、导航与海图入口
## 按功能解锁过滤、剧情卡继续推进阶段、跳过教程的确认页与全解锁。
##
## ## 契约与约束
## - 用真实 `main.tscn` 与真实 Core 内容；教程局通过 `run.start tutorial=true` 建立，
##   非教程局用于对照（不弹卡、不门禁）。
## - 只驱动 Shell 的公开信号 / 命令，不断言内部节点布局尺寸；卡片按钮按节点名
##   `ContinueButton` / `SkipButton` / `SkipConfirmButton` 查找。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const NEW_GAME_SCENE := "res://framework/ui/screens/menu/new_game_screen.tscn"
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
	# 直接挂海图页（避免 await 页面淡入），打开 → 关闭分别推进剧情。
	shell._active_screen = "sea_chart"
	shell._refresh()
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
	assert_eq(_nav_buttons(shell).size(), 8, "every nav screen is unlocked")
	assert_not_null(shell.find_child("ChartButton", true, false), "the chart entry is available")
	_unmount(bundle)


func test_non_tutorial_shell_has_no_card_and_no_gating() -> void:
	var bundle := _mount(false)
	var shell: Control = bundle["shell"]
	assert_true(shell._story_card == null, "a non-tutorial run has no story card")
	assert_eq(_nav_buttons(shell).size(), 8, "a non-tutorial run keeps every nav screen")
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
