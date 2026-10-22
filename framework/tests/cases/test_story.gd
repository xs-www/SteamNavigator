extends TestCase
## @static-doc
## 作用：新手剧情 / 教学系统（阶段 4.5.1 – 4.5.5）领域层无头测试：`run.start tutorial=true`
## 初始化剧情、功能解锁 / 门禁 ViewModel、剧情卡继续、`story.observe` 事件计数推进、
## `story.skip` 保底解锁与主委托目的港揭示、非教程局 / 旧存档不门禁、存档往返；
## 第二主线买卖回运；酒馆自动 / 购买线索、两港价差、第三件货、第二条 L3 线索与
## 保底探索成功发现第三港；第三港换船、船厂只卖 1 人客舱、卸货舱 / 装客舱、
## 第三主线旅客与教学完成。
##
## ## 契约与约束
## - 用真实 Core 注册表：剧情步骤 / 文案 / 解锁 / 数值必须来自
##   `dev_mods/core/content/map_profiles.json` 的 `story` 块，测试不写死框架步骤。
## - `run.start` 的 `tutorial` 默认 false（测试 / 旧入口不弹剧情）；Shell 的
##   「开始新航行」显式传 true，生产局每局默认进入剧情。
## - 跳过 / 完成必须解锁配置里的全部功能并执行 `discover_contract_destination`，
##   避免跳过教程后无目的港可出航；跳过不会设置保底探索 flag。
## @end-static-doc

const SEED := 20260421
const BUILD_ID := "core:starting_build/steady"


func test_tutorial_run_starts_story_and_locks_features() -> void:
	var context := _start_tutorial(SEED)
	var story := context.state.story()
	assert_true(bool(story.get("active", false)), "a tutorial run activates the story")
	assert_false(bool(story.get("completed", true)), "the story is not completed before playing it")
	assert_eq(int(story.get("stage_index", -1)), 0, "the tutorial starts at the first stage")
	assert_eq(String(story.get("flow_id", "")), "core:story/opening", "the Core flow id is recorded")
	var view := _view(context)
	assert_eq(String(view.get("stage_id", "")), "opening", "the first stage is active")
	assert_not_null(view.get("card", null), "the opening stage shows a story card")
	assert_true(bool(view.get("can_skip", false)), "the tutorial can be skipped")
	var unlocked: Array = view.get("unlocked_features", [])
	assert_true(unlocked.has("overview"), "the opening stage unlocks the overview")
	assert_false(unlocked.has("supply"), "supply stays locked until the next stage")
	assert_false(unlocked.has("chart"), "the chart stays locked in the opening")


func test_tutorial_run_discovers_the_main_contract_destination() -> void:
	var context := _start_tutorial(SEED)
	var main_contract: Variant = context.state.contracts().get("main", null)
	assert_true(main_contract is Dictionary, "a tutorial run auto-accepts the main contract")
	if not (main_contract is Dictionary):
		return
	var destination := String((main_contract as Dictionary).get("destination", ""))
	assert_false(destination.is_empty(), "the main contract has a destination")
	assert_true(Array(context.state.campaign_world().get("discovered_port_ids", [])).has(destination),
		"the coordinate world discovers the contract destination")
	assert_true(Array(context.state.world().get("discovered_ports", [])).has(destination),
		"the abstract map discovers the contract destination")


func test_non_tutorial_run_is_not_gated() -> void:
	var context := _start_run(SEED)
	var story := context.state.story()
	assert_false(bool(story.get("active", false)), "a non-tutorial run has no active story")
	assert_true(bool(story.get("completed", true)), "a non-tutorial run is treated as story-complete")
	var view := _view(context)
	assert_false(bool(view.get("active", false)), "the view reports no active story")
	assert_eq((view.get("unlocked_features", []) as Array).size(), StoryService.FEATURES.size(),
		"without a running story every feature stays unlocked")
	assert_true(view.get("card", null) == null, "no story card is shown")


func test_advance_unlocks_market_and_shows_objective() -> void:
	var context := _start_tutorial(SEED)
	var advanced := context.commands.execute(&"story.advance", {})
	assert_true(bool(advanced.get("ok", false)), "the opening card can be continued: %s" % str(advanced))
	var view := _view(context)
	assert_eq(String(view.get("stage_id", "")), "supply_brief", "the next stage is the supply briefing")
	assert_true((view.get("unlocked_features", []) as Array).has("market"), "the market is unlocked")
	var objective: Variant = view.get("objective", null)
	assert_not_null(objective, "the supply stage has a non-blocking objective")
	if objective is Dictionary:
		assert_eq(int((objective as Dictionary).get("target", 0)), 4, "the objective comes from Core JSON")
		assert_eq(int((objective as Dictionary).get("progress", 0)), 0, "no coal has been bought yet")
	# 4.5.3：补给并入市场；Act 0 市场只有补给区块，没有贸易货物。
	var port_view: Dictionary = context.queries.execute(&"port.view")["data"]
	assert_eq((port_view.get("market", []) as Array).size(), 0,
		"the Act 0 market exposes no trade goods yet")


## 4.5.2 幕 0：买齐 4 煤 + 2 水 → 补给受限 + 解锁海图；看海图 → 关闭 → 恢复补给；
## 买够 10 煤 → 出航阶段（默认策略由剧情指定为 fast）。
func test_observe_walks_the_first_voyage_act() -> void:
	var context := _start_tutorial(SEED)
	context.commands.execute(&"story.advance", {})
	var coal := context.commands.execute(&"supply.buy_coal", {"amount": 4})
	assert_true(bool(coal.get("ok", false)), "buying 4 coal succeeds: %s" % str(coal))
	context.commands.execute(&"story.observe", {"event": "cmd:supply.buy_coal", "data": {"amount": 4}})
	var view := _view(context)
	assert_eq(String(view.get("stage_id", "")), "supply_brief", "water is still required")
	var water := context.commands.execute(&"supply.buy_water", {"amount": 2})
	assert_true(bool(water.get("ok", false)), "buying 2 water succeeds: %s" % str(water))
	context.commands.execute(&"story.observe", {"event": "cmd:supply.buy_water", "data": {"amount": 2}})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "supply_hold", "4 coal + 2 water enter the supply hold")
	assert_true((view.get("unlocked_features", []) as Array).has("chart"), "the chart unlocks on the hold")
	assert_true(Array(view.get("lock_actions", [])).has("supply.buy"), "supply buying is locked")
	assert_not_null(view.get("card", null), "the hold shows its story card")
	context.commands.execute(&"story.observe", {"event": "ui:chart_opened", "data": {}})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "chart_brief", "opening the chart advances")
	context.commands.execute(&"story.observe", {"event": "ui:chart_closed", "data": {}})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "supply_finish", "closing the chart restores supplies")
	assert_false(Array(view.get("lock_actions", [])).has("supply.buy"), "supply buying is unlocked again")
	var finish_objective: Variant = view.get("objective", null)
	assert_not_null(finish_objective, "the finish stage shows its objective")
	if finish_objective is Dictionary:
		assert_eq(int((finish_objective as Dictionary).get("progress", 0)), 8,
			"the objective starts from the current bunkers (4 opening + 4 bought)")
		assert_eq(int((finish_objective as Dictionary).get("target", 0)), 10,
			"the objective asks for a 10-coal bunker")
	var more_coal := context.commands.execute(&"supply.buy_coal", {"amount": 2})
	assert_true(bool(more_coal.get("ok", false)), "buying the remaining coal succeeds: %s" % str(more_coal))
	context.commands.execute(&"story.observe", {"event": "cmd:supply.buy_coal", "data": more_coal.get("data", {})})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "depart_brief", "10 coal total reaches the departure stage")
	assert_eq(String(view.get("preferred_strategy", "")), "fast", "the departure stage prefers Fast")
	assert_true(bool(view.get("active", false)), "the tutorial is still running")


## 4.5.3 第二幕：第二港市场只开放 2 种贸易货物；第二主线把 6 件纺织品送回起始港，
## 余下 2 件在起始港卖出后教学第二章收尾。
func test_second_mainline_buys_market_goods_and_returns_home() -> void:
	var context := _start_tutorial(SEED)
	_walk_to_second_port(context)
	var view := _view(context)
	assert_eq(String(view.get("stage_id", "")), "second_port", "arrival enters the second-port act")
	var unlocked_features: Array = view.get("unlocked_features", [])
	assert_true(unlocked_features.has("market"), "the market is available")
	assert_true(unlocked_features.has("contracts"), "the contracts page is unlocked")
	var unlocked_items: Array = view.get("unlocked_items", [])
	assert_true(unlocked_items.has("core:item/spices") and unlocked_items.has("core:item/textiles"),
		"Act 1 unlocks exactly the two tutorial goods")
	var main_contract: Variant = context.state.contracts().get("main", null)
	assert_true(main_contract is Dictionary, "the second mainline contract exists")
	if not (main_contract is Dictionary):
		return
	var contract: Dictionary = main_contract
	assert_eq(String(contract.get("template_id", "")), "core:contract/main_02", "main_02 template drives Act 1")
	assert_eq(String(contract.get("destination", "")), String(context.state.story().get("home_port_id", "")),
		"the second mainline returns to the starting harbour")
	var goods_entry := {}
	for entry in contract.get("cargo", []):
		if String((entry as Dictionary).get("item_id", "")) == "core:item/textiles":
			goods_entry = entry
	assert_eq(int(goods_entry.get("amount", 0)), 6, "six textiles are delivered")
	assert_true(bool(goods_entry.get("player_sourced", false)), "the goods are bought by the player")
	var port_view: Dictionary = context.queries.execute(&"port.view")["data"]
	assert_eq((port_view.get("market", []) as Array).size(), 2, "only the two unlocked goods are on the market")
	var bought := context.commands.execute(&"trade.buy", {"item_id": "core:item/textiles", "amount": 8})
	assert_true(bool(bought.get("ok", false)), "buying 8 textiles succeeds: %s" % str(bought))
	context.commands.execute(&"story.observe", {
		"event": "cmd:trade.buy",
		"data": {"item_id": "core:item/textiles", "amount": 8},
	})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "second_depart", "8 textiles complete the purchase objective")
	# 回起始港：先移动当前港，再模拟 Shell 的抵达结算事件。
	var home := String(context.state.story().get("home_port_id", ""))
	context.state.world()["current_port_id"] = home
	context.state.mark_port_visited(home)
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "back_first", "returning home enters the delivery stage")
	var sold := context.commands.execute(&"trade.sell", {"item_id": "core:item/textiles", "amount": 2})
	assert_true(bool(sold.get("ok", false)), "selling the remaining goods succeeds: %s" % str(sold))
	context.commands.execute(&"story.observe", {
		"event": "cmd:trade.sell",
		"data": {"item_id": "core:item/textiles", "amount": 2},
	})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "chapter_wrap", "selling the leftovers wraps the chapter")
	var wrapped := context.commands.execute(&"story.advance", {})
	assert_true(bool(wrapped.get("ok", false)), "the chapter wrap can be confirmed")
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "tavern_open", "4.5.4 continues into the tavern act")
	assert_false(bool(view.get("completed", false)), "the tutorial keeps going after Act 1")


## 4.5.4 第三幕：酒馆自动给第一条线索并拉开两港价差；刷新物价情报后解锁第三
## 种货；跑一个来回拿到 L3 第二条线索 + 保底探索，发现第三港。
func test_tavern_clue_guaranteed_explore_and_third_port() -> void:
	var context := _start_tutorial(SEED)
	_walk_to_tavern(context)
	var view := _view(context)
	assert_eq(String(view.get("stage_id", "")), "tavern_open", "the tavern act starts at tavern_open")
	var unlocked: Array = view.get("unlocked_features", [])
	assert_true(unlocked.has("tavern"), "the tavern feature unlocks")
	assert_true(unlocked.has("clues"), "the clue feature unlocks with the tavern")
	var active_clues := ClueService.active(context.state)
	assert_eq(active_clues.size(), 1, "the tavern automatically grants the first port clue")
	var first_clue: Dictionary = active_clues[0] if not active_clues.is_empty() else {}
	assert_eq(int(first_clue.get("level", 0)), 1, "the first tavern rumour starts at level 1")
	assert_eq(String(first_clue.get("type", "")), ClueService.TYPE_PORT_LOCATION,
		"the first clue points at an unknown harbour")
	var target := String(first_clue.get("target_port_id", ""))
	assert_false(target.is_empty(), "the story clue has a concrete target")
	assert_eq(target, String((context.state.story().get("flags", {}) as Dictionary).get("story_target_port_id", "")),
		"the target port is remembered for the second clue")
	assert_false(Array(context.state.campaign_world().get("discovered_port_ids", [])).has(target),
		"the clue target is still undiscovered when granted")
	_assert_price_spread(context, target)
	# 第一条线索后：酒馆刷新物价情报 → 第三种货上架。
	var advanced := context.commands.execute(&"story.advance", {})
	assert_true(bool(advanced.get("ok", false)), "the tavern card can be continued: %s" % str(advanced))
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "tavern_intro", "the tavern briefing follows its card")
	var refresh := context.commands.execute(&"intel.refresh", {})
	assert_true(bool(refresh.get("ok", false)), "refreshing price intel at the home tavern succeeds: %s" % str(refresh))
	context.commands.execute(&"story.observe", {"event": "cmd:intel.refresh", "data": refresh.get("data", {})})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "third_good", "the price intel refresh unlocks the third good")
	var unlocked_items: Array = view.get("unlocked_items", [])
	assert_true(unlocked_items.has("core:item/timber"), "the third good is content-driven")
	var port_view: Dictionary = context.queries.execute(&"port.view")["data"]
	var has_timber := false
	for row in port_view.get("market", []):
		if String((row as Dictionary).get("item_id", "")) == "core:item/timber":
			has_timber = true
	assert_true(has_timber, "the third good appears in the home market")
	# 跑一个来回（离港 + 抵达）→ 第二条 L3 线索 + 保底探索成功。
	context.commands.execute(&"story.observe", {"event": "cmd:voyage.start", "data": {"destination_id": target}})
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "second_clue", "one round trip reaches the second clue")
	var clues := ClueService.active(context.state)
	assert_eq(clues.size(), 2, "the second lead is a second clue entry")
	var second_clue: Dictionary = clues[1] if clues.size() > 1 else {}
	assert_eq(int(second_clue.get("level", 0)), 3, "the second lead reveals the direction (level 3)")
	assert_eq(String(second_clue.get("target_port_id", "")), target,
		"both story clues point at the same uncharted harbour")
	var flags: Dictionary = context.state.story().get("flags", {})
	assert_eq(String(flags.get("guaranteed_explore_clue_id", "")), String(second_clue.get("id", "")),
		"the second clue arms the guaranteed exploration success")
	context.commands.execute(&"story.advance", {})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "explore_third", "the card hands over to the exploration stage")
	_sail_after_the_story_clue(context, second_clue, target)
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "third_port", "the guaranteed exploration reaches the third harbour")
	assert_true((view.get("unlocked_features", []) as Array).has("shipyard"),
		"the third harbour unlocks the shipyard for the next act")
	assert_true(Array(context.state.campaign_world().get("discovered_port_ids", [])).has(target),
		"the third port is discovered in the coordinate world")
	assert_true(Array(context.state.world().get("discovered_ports", [])).has(target),
		"the third port is discovered on the played map")
	assert_eq(String(context.state.current_port_id()), target, "the ship arrives at the third harbour")
	assert_eq(String((context.state.story().get("flags", {}) as Dictionary).get("guaranteed_explore_clue_id", "")), "",
		"the guaranteed success flag is consumed by the successful settlement")
	# 4.5.5：第三港换船 + 只上架 1 人客舱 → 卸货舱 → 装客舱 → 送 1 名旅客。
	assert_eq(String(context.state.ship().get("hull_id", "")), "core:hull/medium_standard",
		"the third-port shipyard retrofits a cabin-capable hull")
	assert_true(MapOps.has_facility(MapOps.port(context.state.world(), target), "shipyard"),
		"the third harbour gains a shipyard from the Core story")
	assert_true((view.get("unlocked_modules", []) as Array).has("core:module/small_cabin"),
		"the story unlocks the one-passenger cabin")
	var yard: Dictionary = context.queries.execute(&"shipyard.view")["data"]
	var cabin_only := true
	for candidate in yard.get("candidates", []):
		if String((candidate as Dictionary).get("module_id", "")) != "core:module/small_cabin":
			cabin_only = false
	assert_true(cabin_only, "the tutorial shipyard only lists the small cabin")
	assert_eq((yard.get("candidates", []) as Array).size(), 1, "exactly one shipyard module is offered")
	context.commands.execute(&"story.advance", {})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "refit_unload", "third-port card hands over to the refit")
	var uninstalled := context.commands.execute(&"ship.uninstall_module", {
		"module_id": "core:module/small_hold",
	})
	assert_true(bool(uninstalled.get("ok", false)), "unloading the cargo hold succeeds: %s" % str(uninstalled))
	context.commands.execute(&"story.observe", {
		"event": "cmd:ship.uninstall_module",
		"data": uninstalled.get("data", {}),
	})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "refit_cabin", "unloading the hold advances to the cabin step")
	context.state.set_money(5000)
	var installed := context.commands.execute(&"ship.install_module", {
		"module_id": "core:module/small_cabin",
	})
	assert_true(bool(installed.get("ok", false)), "installing the small cabin succeeds: %s" % str(installed))
	context.commands.execute(&"story.observe", {
		"event": "cmd:ship.install_module",
		"data": installed.get("data", {}),
	})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "passenger_run", "the cabin advances to the passenger run")
	var passenger_contract: Variant = context.state.contracts().get("main", null)
	assert_true(passenger_contract is Dictionary, "the third mainline passenger contract is granted")
	if passenger_contract is Dictionary:
		assert_eq(String((passenger_contract as Dictionary).get("template_id", "")), "core:contract/main_03",
			"the passenger mainline keeps the main_03 chain slot")
		assert_eq(int((passenger_contract as Dictionary).get("passengers", 0)), 1,
			"exactly one passenger is carried")
		assert_true(((passenger_contract as Dictionary).get("cargo", []) as Array).is_empty(),
			"the passenger mainline has no cargo payload")
		assert_eq(int(ShipOps.passenger_capacity(context.registries, context.state.ship())), 1,
			"the small cabin seats one passenger")
	assert_eq(String(context.state.ship().get("passenger_cabin_id", "")), "core:module/small_cabin",
		"the small cabin is fitted")
	context.commands.execute(&"story.observe", {"event": "cmd:voyage.start", "data": {}})
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	view = _view(context)
	assert_eq(String(view.get("stage_id", "")), "story_complete", "delivering the passenger reaches the finale")
	var finished := context.commands.execute(&"story.advance", {})
	assert_true(bool(finished.get("ok", false)), "the tutorial finale can be confirmed")
	view = _view(context)
	assert_true(bool(view.get("completed", false)), "the tutorial is completed")
	assert_eq((view.get("unlocked_features", []) as Array).size(), StoryService.FEATURES.size(),
		"completing the tutorial unlocks every remaining feature")
	assert_false(bool(StoryService.module_filter(context.state, context.registries).get("active", true)),
		"the shipyard module filter turns off after the tutorial")


func test_skip_does_not_arm_the_guaranteed_exploration() -> void:
	var context := _start_tutorial(SEED)
	var skipped := context.commands.execute(&"story.skip", {})
	assert_true(bool(skipped.get("ok", false)), "the tutorial can still be skipped: %s" % str(skipped))
	var flags: Dictionary = context.state.story().get("flags", {})
	assert_false(flags.has("guaranteed_explore_clue_id"),
		"skipping never arms the story's guaranteed exploration success")
	assert_true(bool(context.state.story().get("skipped", false)), "the skip is recorded")


func test_main_contract_needs_player_supplied_coal_before_departure() -> void:
	var context := _start_tutorial(SEED)
	var main_contract: Variant = context.state.contracts().get("main", null)
	assert_true(main_contract is Dictionary, "the tutorial auto-accepts the main contract")
	if not (main_contract is Dictionary):
		return
	var contract: Dictionary = main_contract
	assert_true(bool(contract.get("player_sourced", false)), "main_01 asks for player-supplied cargo")
	var coal_entry := {}
	for entry in contract.get("cargo", []):
		if String((entry as Dictionary).get("item_id", "")) == "core:item/coal":
			coal_entry = entry
	assert_eq(int(coal_entry.get("amount", 0)), 10, "the contract requires 10 coal")
	assert_true(bool(coal_entry.get("fuel_sourced", false)), "the coal entry is delivered from the bunkers")
	var missing := ContractOps.missing_player_cargo(context.state, contract)
	assert_false(missing.is_empty(), "the cargo is missing right after accepting")
	var destination := String(contract.get("destination", ""))
	var blocked := context.commands.execute(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": "core:strategy/standard",
	})
	assert_eq(String(blocked.get("error_code", "")), "missing_contract_cargo",
		"departure is blocked until the cargo is aboard")
	var bought := context.commands.execute(&"supply.buy_coal", {"amount": 10})
	assert_true(bool(bought.get("ok", false)), "buying 10 coal succeeds: %s" % str(bought))
	assert_true(ContractOps.missing_player_cargo(context.state, contract).is_empty(),
		"the self-supplied cargo is complete")
	var standard_preview := VoyageCalculator.preview(context, destination, "core:strategy/standard")
	var fast_preview := VoyageCalculator.preview(context, destination, "core:strategy/fast")
	assert_true(bool(standard_preview.get("ok", false)), "the standard preview succeeds")
	assert_true(bool(fast_preview.get("ok", false)), "the fast preview succeeds")
	var deadline := float(contract.get("deadline", 0.0))
	var now := context.state.now()
	var standard_arrival := float(standard_preview["data"].get("arrival_time", now))
	var fast_arrival := float(fast_preview["data"].get("arrival_time", now))
	assert_true(standard_arrival > deadline, "standard speed arrives after the tutorial deadline")
	assert_true(fast_arrival <= deadline, "fast speed arrives on time for the tutorial contract")


func test_skip_unlocks_everything_and_keeps_the_run_playable() -> void:
	var context := _start_tutorial(SEED)
	var skipped := context.commands.execute(&"story.skip", {})
	assert_true(bool(skipped.get("ok", false)), "skipping the tutorial succeeds: %s" % str(skipped))
	var view := _view(context)
	assert_true(bool(view.get("completed", false)), "the story is completed")
	assert_true(bool(view.get("skipped", false)), "the story is marked as skipped")
	assert_false(bool(view.get("can_skip", false)), "a finished tutorial cannot be skipped again")
	assert_eq((view.get("unlocked_features", []) as Array).size(), StoryService.FEATURES.size(),
		"skipping unlocks every configured feature")
	var main_contract: Variant = context.state.contracts().get("main", null)
	if main_contract is Dictionary:
		var destination := String((main_contract as Dictionary).get("destination", ""))
		assert_true(Array(context.state.campaign_world().get("discovered_port_ids", [])).has(destination),
			"skipping still reveals the main contract destination")


func test_story_survives_a_save_load_roundtrip() -> void:
	var context := _start_tutorial(SEED, {
		"save_directory": "user://test_saves/story_%d" % Time.get_ticks_usec(),
	})
	context.commands.execute(&"story.advance", {})
	context.commands.execute(&"supply.buy_coal", {"amount": 4})
	context.commands.execute(&"story.observe", {"event": "cmd:supply.buy_coal", "data": {"amount": 4}})
	context.commands.execute(&"supply.buy_water", {"amount": 2})
	context.commands.execute(&"story.observe", {"event": "cmd:supply.buy_water", "data": {"amount": 2}})
	var before := context.state.hash()
	var saved := context.save.save_slot("manual", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "saving the story state succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("manual")
	assert_true(bool(loaded.get("ok", false)), "loading the story state succeeds")
	var loaded_state: GameState = loaded.get("state", null)
	assert_not_null(loaded_state, "the loaded state exists")
	if loaded_state == null:
		return
	assert_eq(loaded_state.hash(), before, "the story state hash is identical after loading")
	context.state.replace_with(loaded_state)
	var loaded_view := _view(context)
	assert_eq(String(loaded_view.get("stage_id", "")), "supply_hold", "the story stage survives the round-trip")
	assert_true((loaded_view.get("unlocked_features", []) as Array).has("chart"),
		"unlocked features survive the round-trip")


func test_old_save_without_story_block_stays_open() -> void:
	var context := _start_run(SEED)
	context.state.data.erase("story")
	var view := _view(context)
	var story := context.state.ensure_story()
	assert_false(bool(story.get("active", false)), "a missing story block backfills as inactive")
	assert_true(bool(story.get("completed", true)), "a missing story block backfills as completed")
	assert_eq((view.get("unlocked_features", []) as Array).size(), StoryService.FEATURES.size(),
		"old saves keep every feature unlocked")


# ── helpers ──


## Advances the 4.5.2 first act through its Core-authored stages up to the second port.
func _walk_to_second_port(context: AppContext) -> void:
	context.commands.execute(&"story.advance", {})
	context.commands.execute(&"supply.buy_coal", {"amount": 4})
	context.commands.execute(&"story.observe", {"event": "cmd:supply.buy_coal", "data": {"amount": 4}})
	context.commands.execute(&"supply.buy_water", {"amount": 2})
	context.commands.execute(&"story.observe", {"event": "cmd:supply.buy_water", "data": {"amount": 2}})
	context.commands.execute(&"story.observe", {"event": "ui:chart_opened", "data": {}})
	context.commands.execute(&"story.observe", {"event": "ui:chart_closed", "data": {}})
	var finish_coal := context.commands.execute(&"supply.buy_coal", {"amount": 2})
	context.commands.execute(&"story.observe", {"event": "cmd:supply.buy_coal", "data": finish_coal.get("data", {})})
	# 模拟抵达第二港：Shell 在到港后才会发 `ui:arrival_settled`，此时当前港已是
	# 第二港，第二主线才会以它为起点生成。
	var first_contract: Dictionary = context.state.contracts().get("main", {})
	var second_port := String(first_contract.get("destination", ""))
	context.state.world()["current_port_id"] = second_port
	context.state.mark_port_visited(second_port)
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})


## 4.5.4：停在「酒馆开门」阶段。先按第二幕走完回港卖货，再确认 chapter_wrap。
func _walk_to_tavern(context: AppContext) -> void:
	_walk_to_second_port(context)
	var bought := context.commands.execute(&"trade.buy", {"item_id": "core:item/textiles", "amount": 8})
	assert_true(bool(bought.get("ok", false)), "buying the Act 1 cargo succeeds: %s" % str(bought))
	context.commands.execute(&"story.observe", {
		"event": "cmd:trade.buy",
		"data": {"item_id": "core:item/textiles", "amount": 8},
	})
	var home := String(context.state.story().get("home_port_id", ""))
	context.state.world()["current_port_id"] = home
	context.state.mark_port_visited(home)
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})
	var sold := context.commands.execute(&"trade.sell", {"item_id": "core:item/textiles", "amount": 2})
	assert_true(bool(sold.get("ok", false)), "selling the leftover textiles succeeds: %s" % str(sold))
	context.commands.execute(&"story.observe", {
		"event": "cmd:trade.sell",
		"data": {"item_id": "core:item/textiles", "amount": 2},
	})
	context.commands.execute(&"story.advance", {})


## 4.5.4：起始港卖价高于第二港买价（Core `set_market_price_bias`），来回有利可图。
func _assert_price_spread(context: AppContext, _story_target: String) -> void:
	var home := String(context.state.story().get("home_port_id", ""))
	var main: Variant = context.state.contracts().get("main", null)
	assert_true(main is Dictionary, "the second mainline contract exists for the price check")
	if not (main is Dictionary):
		return
	var other := String((main as Dictionary).get("origin", ""))
	assert_false(other.is_empty() or other == home, "the Act 1 route has a distinct origin harbour")
	for item_id in ["core:item/textiles", "core:item/spices"]:
		var home_entry := MarketOps.entry_for(context.state, home, item_id)
		var other_entry := MarketOps.entry_for(context.state, other, item_id)
		assert_false(home_entry.is_empty() or other_entry.is_empty(),
			"both tutorial goods trade in the two Act 1 harbours (%s)" % item_id)
		if home_entry.is_empty() or other_entry.is_empty():
			continue
		var home_price := float(home_entry.get("price", 0.0))
		var other_price := float(other_entry.get("price", 0.0))
		assert_true(home_price > other_price * 1.2,
			"the home harbour pays clearly more for %s (%.1f vs %.1f)" % [
				item_id, home_price, other_price,
			])
		var sell_at_home := int(floor(home_price * MarketOps.DEFAULT_TRADE_MARGIN))
		var buy_at_other := int(ceil(other_price))
		assert_true(sell_at_home > buy_at_other,
			"buying %s at the second harbour and selling at home is profitable" % item_id)


## 4.5.4：备足补给后循剧情线索出航，把 outcome roll 固定成必失败值以证明「保底成功」。
func _sail_after_the_story_clue(
	context: AppContext, clue: Dictionary, target: String
) -> void:
	context.state.set_money(5000)
	context.commands.execute(&"supply.buy_coal", {"amount": 30})
	context.commands.execute(&"supply.buy_water", {"amount": 10})
	var started := context.commands.execute(&"explore.start", {
		"clue_id": String(clue.get("id", "")),
		"strategy_id": "core:strategy/standard",
	})
	assert_true(bool(started.get("ok", false)), "sailing after the story clue succeeds: %s" % str(started))
	context.commands.execute(&"story.observe", {"event": "cmd:explore.start", "data": started.get("data", {})})
	var voyage: Variant = context.state.explore_voyage()
	assert_true(voyage is Dictionary, "the exploration voyage is recorded")
	if voyage is Dictionary:
		(voyage as Dictionary)["outcome_roll"] = 1.0
	var settled := context.commands.execute(&"explore.settle", {})
	assert_true(bool(settled.get("ok", false)), "the exploration settles: %s" % str(settled))
	assert_eq(String(settled.get("data", {}).get("result", "")), "discovered",
		"the guaranteed exploration succeeds even with a failing outcome roll")
	assert_eq(String(settled.get("data", {}).get("destination", "")), target,
		"the guaranteed exploration reaches the clue target")
	context.commands.execute(&"story.observe", {"event": "ui:arrival_settled", "data": {}})


func _start_run(seed_value: int, extra: Dictionary = {}) -> AppContext:
	var boot := bootstrap_core(extra)
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {"build_id": BUILD_ID, "seed": seed_value})
	assert_true(bool(result.get("ok", false)), "run.start should succeed: %s" % str(result))
	return context


func _start_tutorial(seed_value: int, extra: Dictionary = {}) -> AppContext:
	var boot := bootstrap_core(extra)
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {
		"build_id": BUILD_ID,
		"seed": seed_value,
		"tutorial": true,
	})
	assert_true(bool(result.get("ok", false)), "tutorial run.start should succeed: %s" % str(result))
	return context


func _view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"story.view")
	return result.get("data", {}) if bool(result.get("ok", false)) else {}
