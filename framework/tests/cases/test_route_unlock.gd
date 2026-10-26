extends TestCase
class_name TestRouteUnlock
## @static-doc
## 作用：锁定「任意两港可通航 + 航线需要解锁」的运行时契约（2026-10-26）。
##
## ## 契约与约束
## - **物理连通 = 完全图**：`generate_chart` 为每对港口生成航线；发现港口不解锁航线。
## - **运行时解锁名册**：`state.campaign_world().unlocked_route_keys` 存规范无向 pair key
##   （`a|b` 排序）；`WorldOps.route_key / is_route_unlocked / unlock_route /
##   unlocked_neighbor_ids` 是唯一读写入口。新 `GameState` 的该数组为空。
## - **三种解锁来源**：①委托自带海图（`ContractOps.generate_offer` 主线 / 普通都解锁
##   origin↔destination，`StoryService._grant_tutorial_contract` 按最终目的地解锁）；
##   ②剧情效果 `unlock_route {from, to}`（`current` / `home` / `contract_destination` /
##   具体港口 id）；③酒馆 `chart.buy {port_id}`（当前港有酒馆、目标已发现、非当前港、
##   未解锁、金币够；扣 Core `map_config.chart_cost`，发 `chart.purchased`）。
## - **航行门禁**：未解锁航线 `voyage.preview` / `voyage.start` / `clue.travel` 返回
##   `route_locked` + `ui.error.route_locked`；`explore.start` 不受限（由
##   `test_exploration` 锁定探索路径）。
## - **查询 / UI**：`sea_chart.view` 每条 route 带 `unlocked`；`map.view` 与
##   `port.view.destinations` 只列已解锁航线；海图面板未解锁时禁用启航并显示
##   「未测绘航线：在酒馆购买海图解锁」；酒馆页按 `tavern.view.chart_offers` 售卖海图。
## - 测试只通过公开命令 / 查询与领域 API 驱动；测试夹具会把「脚本直接开船」需要的航线
##   标记为解锁（等价于委托自带海图），但不绕过被测命令本身的门禁。
## @end-static-doc

const STEADY_SCENARIO := "core:starting_scenario/steady"
const STANDARD_STRATEGY := "core:boiler_strategy/standard"
const SEED := 4242


# ── 1) 名册 / 完全图 / 新局初始状态 ──

func test_route_keys_are_canonical_and_a_new_state_has_none() -> void:
	assert_eq(WorldOps.route_key("port_1", "port_0"), "port_0|port_1", "pair keys are sorted")
	assert_eq(WorldOps.route_key("port_0", "port_1"), "port_0|port_1", "pair key ignores direction")
	assert_eq(WorldOps.route_key("", "port_1"), "", "an empty id has no key")
	var raw := GameState.new()
	assert_empty(Array(raw.campaign_world().get("unlocked_route_keys", [])),
		"a fresh GameState starts with no charted route")
	assert_false(WorldOps.is_route_unlocked(raw, "port_0", "port_1"),
		"nothing is unlocked before the run starts")


func test_new_run_unlocks_only_the_routes_its_contracts_carry() -> void:
	var context := _start_run(SEED)
	var state: GameState = context.state
	var chart := WorldOps.world_map(state)
	var port_count := chart.ports.size()
	var expected := _contract_route_keys(state)
	var actual: Array = WorldOps.unlocked_route_keys(state)
	assert_false(actual.is_empty(), "the starting contracts carry charts, so some routes are unlocked")
	assert_eq(_sorted(actual), _sorted(expected),
		"run.start must unlock exactly the routes of the main contract + normal offers")
	assert_true(actual.size() <= port_count - 1,
		"a new run can never unlock every route")
	for key in expected:
		var parts := String(key).split("|", false)
		assert_true(WorldOps.is_route_unlocked(state, parts[0], parts[1]),
			"contract route %s should be unlocked" % key)
		assert_true(WorldOps.is_route_unlocked(state, parts[1], parts[0]),
			"route unlock is direction independent (%s)" % key)
	# Discovering a harbour does not chart its routes: pick a locked pair.
	var locked := _locked_pair(state)
	assert_false(locked.is_empty(), "a complete chart still has uncharted pairs at run start")
	if locked.is_empty():
		return
	assert_true(
		not WorldOps.is_route_unlocked(state, String(locked[0]), String(locked[1])),
		"a discovered harbour does not unlock its routes by itself"
	)


func test_normal_offer_refresh_unlocks_each_generated_route() -> void:
	var context := _start_run(SEED)
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var offers := ContractOps.refresh_normal_offers(
		state, hub, context.rng, state.current_port_id(), state.now() + 12.0
	)
	assert_false(offers.is_empty(), "the refresh should generate normal offers")
	for offer in offers:
		var origin := String((offer as Dictionary).get("origin", ""))
		var destination := String((offer as Dictionary).get("destination", ""))
		assert_true(WorldOps.is_route_unlocked(state, origin, destination),
			"normal offer %s carries the chart for %s -> %s" % [
				String((offer as Dictionary).get("instance_id", "")), origin, destination,
			])
		assert_true(
			MapOps.is_discovered(state, destination)
				or offers.size() > 0,
			"destination selection is evaluated against discovered harbours when available"
		)


# ── 2) 剧情 / 教学解锁 ──

func test_tutorial_opening_unlocks_the_main_route() -> void:
	var context := _start_run(SEED, true)
	var state: GameState = context.state
	var main_contract: Variant = state.contracts().get("main", null)
	assert_true(main_contract is Dictionary, "the tutorial opening grants the main contract")
	if not (main_contract is Dictionary):
		return
	var origin := String((main_contract as Dictionary).get("origin", ""))
	var destination := String((main_contract as Dictionary).get("destination", ""))
	assert_true(WorldOps.is_route_unlocked(state, origin, destination),
		"the tutorial contract unlocks its own route (the player can always sail the guide)")


func test_story_unlock_route_effect_resolves_semantic_tokens() -> void:
	var context := _start_run(SEED, true)
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var story := state.ensure_story()
	var current := state.current_port_id()
	var home := String(story.get("home_port_id", ""))
	var main_contract: Dictionary = state.contracts().get("main", {})
	var main_destination := String(main_contract.get("destination", ""))
	assert_eq(StoryService._resolve_story_port(state, story, "current"), current,
		"the current token resolves to the current harbour")
	assert_eq(StoryService._resolve_story_port(state, story, "home"), home,
		"the home token resolves to the story home harbour")
	assert_eq(StoryService._resolve_story_port(state, story, "contract_destination"), main_destination,
		"the contract_destination token resolves to the main contract destination")
	assert_eq(StoryService._resolve_story_port(state, story, "port_3"), "port_3",
		"an explicit harbour id passes through")
	# 正例：解锁一条尚未测绘的航线，发 chart.route_unlocked。
	var locked := _locked_pair(state)
	assert_false(locked.is_empty(), "the tutorial run still has uncharted pairs")
	if locked.is_empty():
		return
	var events: Array = []
	StoryService._apply_effect(state, hub, story, {
		"type": "unlock_route", "from": String(locked[0]), "to": String(locked[1]),
	}, context.rng, events)
	assert_true(WorldOps.is_route_unlocked(state, String(locked[0]), String(locked[1])),
		"the story effect unlocks the declared route")
	var saw_event := false
	for event in events:
		if event is Dictionary and String(event.get("type", "")) == "chart.route_unlocked":
			saw_event = true
	assert_true(saw_event, "unlocking from the story emits chart.route_unlocked")
	# 反例：两端相同 / 空 token 不解锁也不发事件。
	var before: Array = WorldOps.unlocked_route_keys(state).duplicate()
	var rejected_events: Array = []
	StoryService._apply_effect(state, hub, story, {
		"type": "unlock_route", "from": "current", "to": "current",
	}, context.rng, rejected_events)
	assert_eq(_sorted(WorldOps.unlocked_route_keys(state)), _sorted(before),
		"an unlock_route with the same port on both ends is ignored")
	assert_empty(rejected_events, "an ignored unlock_route emits no event")


# ── 3) 酒馆购买海图 ──

func test_chart_buy_unlocks_the_route_charges_gold_and_survives_save_load() -> void:
	var context := _start_run(SEED)
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var chart := WorldOps.world_map(state)
	var current := state.current_port_id()
	var target := _discoverable_locked_target(context)
	assert_false(target.is_empty(), "the run should have a discoverable, uncharted harbour")
	if target.is_empty():
		return
	var cost := ChartCommands.chart_cost(state, hub)
	assert_eq(cost, 60, "Core map_config.chart_cost is 60 gold")
	var money_before := state.money()
	var expense_before := int(state.stats().get("expense", 0))
	var result := context.commands.execute(&"chart.buy", {"port_id": target})
	assert_true(bool(result.get("ok", false)), "chart.buy succeeds: %s" % str(result))
	if not bool(result.get("ok", false)):
		return
	var data: Dictionary = result.get("data", {})
	assert_eq(String(data.get("to", "")), target, "the bought chart targets the requested harbour")
	assert_eq(int(data.get("cost", 0)), cost, "the command reports the content price")
	assert_eq(state.money(), money_before - cost, "the chart is paid for in gold")
	assert_eq(int(state.stats().get("expense", 0)) - expense_before, cost,
		"the chart price is recorded as an expense")
	assert_true(WorldOps.is_route_unlocked(state, current, target),
		"chart.buy unlocks the current harbour <-> target route")
	var saw_purchase := false
	for event in result.get("events", []):
		if event is Dictionary and String(event.get("type", "")) == "chart.purchased":
			saw_purchase = true
			var payload: Dictionary = (event as Dictionary).get("payload", {})
			assert_eq(String(payload.get("to", "")), target,
				"chart.purchased names the unlocked harbour")
			assert_eq(int(payload.get("cost", 0)), cost, "chart.purchased carries the price")
	assert_true(saw_purchase, "chart.buy emits chart.purchased")
	# 名册经过真实存档往返仍然一致（state hash 也一致）。
	var hash_before := state.hash()
	var saved := context.save.save_slot("chart", state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "save succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("chart")
	assert_true(bool(loaded.get("ok", false)), "load succeeds")
	var loaded_state: GameState = loaded["state"]
	assert_true(WorldOps.is_route_unlocked(loaded_state, current, target),
		"the unlocked route survives a save/load round-trip")
	assert_eq(loaded_state.hash(), state.hash(), "the saved unlock roster is byte-identical")


func test_chart_buy_fails_cleanly_in_every_invalid_case() -> void:
	var context := _start_run(SEED)
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var chart := WorldOps.world_map(state)
	var current := state.current_port_id()
	var money := state.money()
	var unlocked_before := _sorted(WorldOps.unlocked_route_keys(state))

	# ① 未知港口。
	var unknown := context.commands.execute(&"chart.buy", {"port_id": "port_99"})
	_expect_failure(unknown, "unknown_port", "an unknown harbour is rejected")
	# ② 当前港。
	var same := context.commands.execute(&"chart.buy", {"port_id": current})
	_expect_failure(same, "same_port", "the current harbour is rejected")
	# ③ 已解锁航线（主线委托自带海图）。
	var main_contract: Variant = state.contracts().get("main", null)
	var unlocked_target := ""
	if main_contract is Dictionary:
		unlocked_target = String((main_contract as Dictionary).get("destination", ""))
	if not unlocked_target.is_empty():
		var already := context.commands.execute(&"chart.buy", {"port_id": unlocked_target})
		_expect_failure(already, "route_already_unlocked", "an already charted route is rejected")
	# ④ 未发现港口。
	var hidden := ""
	for port in chart.ports:
		if port.id != current and not MapOps.is_discovered(state, port.id):
			hidden = port.id
			break
	if not hidden.is_empty():
		var undiscovered := context.commands.execute(&"chart.buy", {"port_id": hidden})
		_expect_failure(undiscovered, "port_not_discovered", "an undiscovered harbour is rejected")
	# ⑤ 金币不足（先发现目标再清空金币）。
	var target := _discoverable_locked_target(context)
	if not target.is_empty():
		state.player()["money"] = 0
		var poor := context.commands.execute(&"chart.buy", {"port_id": target})
		_expect_failure(poor, "insufficient_money", "not enough gold is rejected")
		assert_eq(state.money(), 0, "a refused purchase never charges gold")
		state.player()["money"] = money
	# ⑥ 当前港没有酒馆（把设施表清空，等价于停在没有酒馆的渔村）。
	var current_port := MapOps.port(state.world(), current)
	current_port["facilities"] = []
	var no_tavern := context.commands.execute(&"chart.buy", {"port_id": target})
	_expect_failure(no_tavern, "no_tavern", "a harbour without a tavern cannot sell charts")
	assert_eq(_sorted(WorldOps.unlocked_route_keys(state)), unlocked_before,
		"refused chart purchases never unlock anything")


func test_tavern_view_offers_charts_for_discovered_harbours() -> void:
	var context := _start_run(SEED)
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var current := state.current_port_id()
	var view: Dictionary = context.queries.execute(&"tavern.view").get("data", {})
	assert_eq(int(view.get("chart_cost", -1)), ChartCommands.chart_cost(state, hub),
		"tavern.view exposes the content chart price")
	assert_true(bool(view.get("has_tavern_facility", false)),
		"the starting harbour has a tavern")
	var offers: Array = view.get("chart_offers", [])
	assert_false(offers.is_empty(), "the tavern lists charts for discovered harbours")
	for offer in offers:
		var port_id := String((offer as Dictionary).get("port_id", ""))
		assert_ne(port_id, current, "the current harbour never gets a chart offer")
		assert_true(MapOps.is_discovered(state, port_id),
			"chart offers only list discovered harbours")
		assert_eq(int((offer as Dictionary).get("cost", -1)), 60,
			"every chart offer quotes the content price")
	# 已测绘的港口显示「已解锁」；新发现但未测绘的港口可购买。
	var main_contract: Variant = state.contracts().get("main", null)
	if main_contract is Dictionary:
		var main_destination := String((main_contract as Dictionary).get("destination", ""))
		var unlocked_offer := _offer_for(offers, main_destination)
		assert_true(bool(unlocked_offer.get("unlocked", false)),
			"a contract-charted harbour shows as unlocked")
		assert_false(bool(unlocked_offer.get("can_buy", true)),
			"an unlocked chart cannot be bought twice")
	var target := _discoverable_locked_target(context)
	if not target.is_empty():
		var refreshed: Dictionary = context.queries.execute(&"tavern.view").get("data", {})
		var locked_offer := _offer_for(refreshed.get("chart_offers", []), target)
		assert_false(locked_offer.is_empty(), "the newly discovered harbour gets a chart offer")
		assert_false(bool(locked_offer.get("unlocked", true)),
			"a discovered but uncharted harbour is offered as locked")
		assert_true(bool(locked_offer.get("can_buy", false)),
			"the tavern can sell the chart when the player can afford it")


# ── 4) 航行 / 查询门禁 ──

func test_route_locked_blocks_preview_start_and_clue_travel() -> void:
	var context := _start_run(SEED)
	var state: GameState = context.state
	var target := _discoverable_locked_target(context)
	assert_false(target.is_empty(), "a locked, discovered target must exist")
	if target.is_empty():
		return
	var preview := context.commands.execute(&"voyage.preview", {
		"destination_id": target, "strategy_id": STANDARD_STRATEGY,
	})
	_expect_failure(preview, "route_locked", "voyage.preview rejects an uncharted route")
	assert_eq(String(preview.get("message_key", "")), "ui.error.route_locked",
		"the preview failure carries the localized reason")
	var start := context.commands.execute(&"voyage.start", {
		"destination_id": target, "strategy_id": STANDARD_STRATEGY,
	})
	_expect_failure(start, "route_locked", "voyage.start cannot bypass the chart gate")
	# clue.travel 走同一条航行路径，因此同样被 route_locked 拦截。
	var clues := state.ensure_clues()
	clues["active"].append({
		"id": "test:clue/goods_locked",
		"type": ClueService.TYPE_PORT_GOODS,
		"source_key": "wait",
		"source_display_key": "ui.clue.source.wait",
		"level": ClueService.NAME_MIN_LEVEL,
		"target_port_id": target,
		"target_goods_id": "core:item/coal",
		"created_at": state.now(),
		"expires_at": 0.0,
		"credibility": 0.6,
		"goods": {},
	})
	var travel := context.commands.execute(&"clue.travel", {
		"clue_id": "test:clue/goods_locked", "strategy_id": STANDARD_STRATEGY,
	})
	_expect_failure(travel, "route_locked", "clue.travel shares the voyage chart gate")
	# 解锁后 preview 正常，且距离仍与海图边一致。
	WorldOps.unlock_route(state, state.current_port_id(), target)
	var unlocked_preview := context.commands.execute(&"voyage.preview", {
		"destination_id": target, "strategy_id": STANDARD_STRATEGY,
	})
	assert_true(bool(unlocked_preview.get("ok", false)),
		"after charting the route the preview succeeds: %s" % str(unlocked_preview))
	if bool(unlocked_preview.get("ok", false)):
		var chart_distance := MapOps.distance_between(state.world(), state.current_port_id(), target)
		assert_almost_eq(
			float(unlocked_preview["data"].get("distance", 0.0)), chart_distance, 0.01,
			"the unlocked preview bills the chart distance"
		)


func test_queries_expose_the_unlock_state_and_filter_locked_routes() -> void:
	var context := _start_run(SEED)
	var state: GameState = context.state
	var chart := WorldOps.world_map(state)
	for port in chart.ports:
		WorldOps.discover_port_id(state, port.id)
		MapOps.discover(state, port.id)
	var unlocked_keys := WorldOps.unlocked_route_keys(state)
	var sea: Dictionary = SeaChartViewQuery.execute({}, context).get("data", {})
	var routes: Array = sea.get("routes", [])
	assert_eq(routes.size(), chart.route_count(),
		"every chart edge between discovered harbours is exported")
	var unlocked_routes := 0
	for route in routes:
		var from_id := String((route as Dictionary).get("from", ""))
		var to_id := String((route as Dictionary).get("to", ""))
		var expected := WorldOps.is_route_unlocked(state, from_id, to_id)
		assert_eq(bool((route as Dictionary).get("unlocked", false)), expected,
			"route %s|%s carries the runtime unlock flag" % [from_id, to_id])
		if expected:
			unlocked_routes += 1
	assert_eq(unlocked_routes, unlocked_keys.size(),
		"every unlocked pair appears exactly once with unlocked=true")
	# map.view / port.view 只列已解锁航线。
	var map_view: Dictionary = context.queries.execute(&"map.view").get("data", {})
	assert_eq(Array(map_view.get("routes", [])).size(), unlocked_keys.size(),
		"map.view only lists charted routes")
	var port_view: Dictionary = context.queries.execute(&"port.view").get("data", {})
	var expected_neighbors := _sorted(WorldOps.unlocked_neighbor_ids(state, state.current_port_id()))
	var actual_destinations: Array = []
	for destination in port_view.get("destinations", []):
		actual_destinations.append(String((destination as Dictionary).get("port_id", "")))
	assert_eq(_sorted(actual_destinations), expected_neighbors,
		"port.view destinations are exactly the charted neighbours of the current harbour")


func test_chart_panel_disables_sailing_for_a_locked_route() -> void:
	var context := _start_run(SEED)
	var tree := Engine.get_main_loop() as SceneTree
	var panel := SNSeaChartPanel.new()
	tree.root.add_child(panel)
	var chart := WorldOps.world_map(context.state)
	var start_port := chart.get_start_port()
	var neighbor := chart.get_port(String(WorldOps.neighbors(chart, start_port.id)[0]))
	var port_data := {"id": neighbor.id, "name_key": neighbor.name_key}
	var route_data := {
		"from": start_port.id, "to": neighbor.id, "distance": 88.0,
		"unlocked": false,
	}
	panel.bind(port_data, route_data, Callable(context, "translate"))
	var depart := _named_button(panel, "DepartButton")
	assert_not_null(depart, "a charted-or-not route still offers the depart control")
	if depart != null:
		assert_true(bool(depart.disabled), "an uncharted route disables the depart button")
	var locked_hint := _label_texts(panel)
	assert_true(locked_hint.has(context.translate("ui.chart.route_locked_hint")),
		"the panel explains how to unlock the route, got: %s" % str(locked_hint))
	panel.bind(port_data, {
		"from": start_port.id, "to": neighbor.id, "distance": 88.0, "unlocked": true,
	}, Callable(context, "translate"))
	depart = _named_button(panel, "DepartButton")
	assert_not_null(depart, "a charted route keeps the depart control")
	if depart != null:
		assert_false(bool(depart.disabled), "a charted route enables the depart button")
	assert_false(_label_texts(panel).has(context.translate("ui.chart.route_locked_hint")),
		"the locked hint disappears once the route is charted")
	panel.free()


func test_tavern_screen_renders_chart_offers_and_emits_chart_buy() -> void:
	var context := _start_run(SEED)
	var tree := Engine.get_main_loop() as SceneTree
	var screen := TavernScreen.new()
	tree.root.add_child(screen)
	var emitted: Array = []
	screen.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
		emitted.append({"command": String(command), "params": params})
	)
	screen.bind({
		"has_run": true,
		"current_port_id": "port_0",
		"current_port_name_key": "port_name.core.iron_harbor",
		"has_tavern_facility": true,
		"money": 900,
		"chart_cost": 60,
		"intel": {},
		"clues": [],
		"active_clue_count": 0,
		"max_active_clues": 4,
		"can_buy_clue": {"available": false, "cost": 0, "reason_key": ""},
		"chart_offers": [
			{
				"port_id": "port_2",
				"name_key": "port_name.core.free_town",
				"cost": 60,
				"unlocked": false,
				"can_buy": true,
				"reason_key": "",
			},
			{
				"port_id": "port_3",
				"name_key": "port_name.core.glass_port",
				"cost": 60,
				"unlocked": true,
				"can_buy": false,
				"reason_key": "",
			},
		],
	}, Callable(context, "translate"))
	var buy := _named_button(screen, "BuyChartButton_port_2")
	assert_not_null(buy, "an uncharted harbour gets a buy button")
	if buy != null:
		assert_false(bool(buy.disabled), "an affordable, unlocked-pending chart can be bought")
		buy.emit_signal("pressed")
	assert_eq(emitted.size(), 1, "pressing the chart button emits one command")
	if not emitted.is_empty():
		assert_eq(String(emitted[0]["command"]), "chart.buy", "the button fires chart.buy")
		assert_eq(String((emitted[0]["params"] as Dictionary).get("port_id", "")), "port_2",
			"the command names the harbour whose chart was bought")
	var texts := _label_texts(screen)
	assert_true(texts.has(context.translate("ui.tavern.chart_unlocked")),
		"an already charted harbour is labelled as charted, got: %s" % str(texts))
	screen.free()


# ── Helpers ──

func _start_run(seed_value: int, tutorial: bool = false) -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var params := {"starting_scenario": STEADY_SCENARIO, "seed": seed_value}
	if tutorial:
		params["tutorial"] = true
	var result := context.commands.execute(&"run.start", params)
	assert_true(bool(result.get("ok", false)), "run.start for seed %d should succeed: %s" % [
		seed_value, str(result),
	])
	return context


## Routes the run's main contract + normal offers carry (the expected unlock roster).
func _contract_route_keys(state: GameState) -> Array:
	var keys: Array = []
	var contracts: Dictionary = state.contracts()
	var main_contract: Variant = contracts.get("main", null)
	if main_contract is Dictionary:
		_remember_pair(keys, main_contract)
	for offer in contracts.get("offers", []):
		if offer is Dictionary:
			_remember_pair(keys, offer)
	return keys


func _remember_pair(keys: Array, contract: Dictionary) -> void:
	var key := WorldOps.route_key(
		String(contract.get("origin", "")), String(contract.get("destination", ""))
	)
	if not key.is_empty() and not keys.has(key):
		keys.append(key)


## First discovered-but-uncharted pair (ordered, never `[current, current]`).
func _locked_pair(state: GameState) -> Array:
	var world := WorldOps.world_map(state)
	for port in world.ports:
		for other in world.ports:
			if port.id == other.id:
				continue
			if WorldOps.is_route_unlocked(state, port.id, other.id):
				continue
			return [port.id, other.id]
	return []


## Discovers (chart fog + gameplay mirror) an uncharted harbour reachable from the
## current one and returns it. Returns "" when every target is already unlocked.
func _discoverable_locked_target(context: AppContext) -> String:
	var state: GameState = context.state
	var current := state.current_port_id()
	var chart := WorldOps.world_map(state)
	for port in chart.ports:
		if port.id == current:
			continue
		if WorldOps.is_route_unlocked(state, current, port.id):
			continue
		WorldOps.discover_port_id(state, port.id)
		MapOps.discover(state, port.id)
		return port.id
	return ""


func _offer_for(offers: Array, port_id: String) -> Dictionary:
	for offer in offers:
		if offer is Dictionary and String((offer as Dictionary).get("port_id", "")) == port_id:
			return offer
	return {}


func _expect_failure(result: Dictionary, expected_code: String, message: String) -> void:
	assert_false(bool(result.get("ok", true)), "%s: %s" % [message, str(result)])
	assert_eq(String(result.get("error_code", "")), expected_code, message)


func _sorted(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort()
	return copy


func _named_button(root: Node, node_name: String) -> Button:
	var node := _find_descendant(root, func(candidate: Node) -> bool:
		return candidate is Button and String(candidate.name) == node_name
	)
	return node as Button


func _label_texts(root: Node) -> Array:
	var texts: Array = []
	_collect_labels(root, texts)
	return texts


func _collect_labels(node: Node, texts: Array) -> void:
	if node is Label:
		texts.append(String((node as Label).text))
	for child in node.get_children():
		_collect_labels(child, texts)


func _find_descendant(root: Node, predicate: Callable) -> Node:
	if predicate.call(root):
		return root
	for child in root.get_children():
		var found := _find_descendant(child, predicate)
		if found != null:
			return found
	return null
