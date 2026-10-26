extends TestCase


func test_main_chain_offer_and_accept() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 4242})
	var port_result := context.queries.execute(&"port.view")
	var main_view: Dictionary = port_result["data"]["contracts"]["main"]
	assert_true(not main_view.is_empty(), "current main contract is exposed")
	assert_true(float(main_view["remaining_hours"]) > 0.0, "contract exposes remaining hours")
	assert_true(not String(main_view["remaining_label"]).is_empty(), "contract exposes remaining label")
	assert_true(float(main_view["estimated_hours"]) > 0.0, "contract exposes estimated voyage hours")
	assert_contains(["low", "medium", "high"], String(main_view["risk"]), "contract risk is derived")
	var destination := String(context.state.contracts()["main"]["destination"])
	var voyage := context.commands.execute(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": "core:boiler_strategy/economic",
	})
	assert_true(bool(voyage["ok"]), "voyage starts")
	if not bool(voyage["data"].get("arrived", true)):
		var option_ids: Array = voyage["data"]["event"]["option_ids"]
		context.commands.execute(&"event.choose_option", {"option_id": String(option_ids[0])})
	var offer: Dictionary = context.state.contracts().get("main_offer", {})
	assert_true(not offer.is_empty(), "main 2 offer exists")
	assert_eq(int(offer.get("sequence", 0)), 2, "offer is main sequence 2")
	var accept := context.commands.execute(&"contract.accept", {"instance_id": String(offer["instance_id"])})
	assert_true(bool(accept["ok"]), "main offer accepts: %s" % str(accept))
	assert_eq(int(context.state.contracts()["main"].get("sequence", 0)), 2, "main slot now holds sequence 2")
	assert_eq(context.state.contracts().get("main_offer", null), null, "main offer is cleared after acceptance")
	assert_true(ShipOps.cargo_amount(context.state.ship(), "core:item/contract_freight", true) > 0, "contract cargo is loaded")
	# C3：接取委托即生成 Quest 追踪实例；上一段主线的实例在完成时已标记 completed。
	var tracking := QuestOps.find_by_contract(context.state, String(offer["instance_id"]))
	assert_false(tracking.is_empty(), "accepting a contract creates its quest tracking instance")
	assert_eq(String(tracking.get("status", "")), QuestOps.STATUS_ACTIVE, "the new tracking instance is active")
	var first_contracts := Array(context.state.contracts().get("completed", []))
	assert_contains(first_contracts, "core:contract/main_01", "the first main contract completed")


func test_contract_cargo_cannot_be_sold() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 5252})
	var result := context.commands.execute(&"trade.sell", {"item_id": "core:item/contract_freight", "amount": 1})
	assert_false(bool(result["ok"]), "contract cargo cannot be sold")


## ---------------------------------------------------------------------------
## 反馈 #2：委托板只露出「目的地已发现」的普通委托；主线生成即揭示目的港。
## ---------------------------------------------------------------------------


func test_offers_only_expose_discovered_destinations() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 12345})
	var state: GameState = context.state
	var pool: Array = Array(state.contracts().get("offers", []))
	assert_eq(pool.size(), 3, "the normal offer pool keeps three instances regardless of fog")
	var current_port := state.current_port_id()
	# 回到「只发现当前港」的迷雾状态：三条普通委托的目的地全部在迷雾里。
	state.world()["discovered_ports"] = [current_port]
	state.campaign_world()["discovered_port_ids"] = [current_port]
	var view := _contracts_view(context)
	assert_empty(view["offers"], "offers into the fog are hidden from the board")
	var hidden: Dictionary = pool[0]
	var hidden_id := String(hidden.get("instance_id", ""))
	var destination := String(hidden.get("destination", ""))
	assert_false(MapOps.is_discovered(state, destination), "the fixture offer points into the fog")
	MapOps.discover(state, destination)
	WorldOps.discover_port_id(state, destination)
	view = _contracts_view(context)
	var visible_ids := _view_offer_ids(view["offers"])
	assert_true(visible_ids.has(hidden_id), "the same instance returns after its destination is discovered")
	for raw_offer in Array(view["offers"]):
		var offer: Dictionary = raw_offer
		assert_true(
			Array(state.world().get("discovered_ports", [])).has(String(offer.get("destination", ""))),
			"only discovered destinations are shown"
		)


func test_main_chain_generation_reveals_its_destination() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 4242})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var main: Dictionary = state.contracts().get("main", {})
	assert_false(main.is_empty(), "the run auto-accepts main 01")
	var main_destination := String(main.get("destination", ""))
	assert_true(
		Array(state.world().get("discovered_ports", [])).has(main_destination),
		"the played map reveals the main destination on generation"
	)
	assert_true(
		Array(state.campaign_world().get("discovered_port_ids", [])).has(main_destination),
		"the coordinate twin reveals the main destination on generation"
	)
	var template := ContractOps.find_template_by_sequence(hub, 2)
	var offer := ContractOps.generate_offer(state, hub, template, context.rng, state.current_port_id())
	assert_false(offer.is_empty(), "the next main offer generates")
	assert_true(
		Array(state.world().get("discovered_ports", [])).has(String(offer.get("destination", ""))),
		"a generated main offer never points into the fog"
	)
	# 普通 offer 不做自动揭示：只隐藏、不泄露迷雾。
	var normal_template: ContentDefinition = ContractOps.templates_by_kind(hub, "normal")[0]
	var before: Array = Array(state.world().get("discovered_ports", [])).duplicate()
	var normal_offer := ContractOps.generate_offer(state, hub, normal_template, context.rng, state.current_port_id())
	assert_false(normal_offer.is_empty(), "a normal offer generates")
	var after: Array = Array(state.world().get("discovered_ports", []))
	assert_eq(after, before, "normal offers never reveal their destination")


## ---------------------------------------------------------------------------
## 反馈 #3：第三主线起无期限（哨兵 0），准时奖励改为无条件「完成奖励」。
## ---------------------------------------------------------------------------


func test_main_03_onwards_have_no_deadline() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 20260421})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	assert_eq(FormulaRegistry.evaluate("none"), 0.0, "the none formula evaluates to the sentinel")
	var template := ContractOps.find_template_by_sequence(hub, 3)
	assert_not_null(template, "main 03 exists")
	assert_eq(String(template.data.get("deadline_formula", "")), "none", "main 03 is content-driven no-deadline")
	var reward_range: Array = Array((template.data.get("rewards", {}) as Dictionary).get("on_time_bonus", []))
	assert_true(
		not reward_range.is_empty() and int(reward_range[0]) > 0,
		"the completion bonus keeps its value (only the label changes)"
	)
	for sequence in [4, 5]:
		var later := ContractOps.find_template_by_sequence(hub, sequence)
		assert_eq(String(later.data.get("deadline_formula", "")), "none", "main %d is no-deadline" % sequence)
	var origin := state.current_port_id()
	var destination := String(MapOps.neighbors(state.world(), origin)[0])
	# 手工构造的「已接取主线」等价于真实链路：委托自带海图，航线已解锁。
	WorldOps.unlock_route(state, origin, destination)
	var distance := maxf(MapOps.distance_between(state.world(), origin, destination), 100.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var instance := ContractOps.create_instance(hub, template, origin, destination, state.now(), distance, 7001, rng)
	assert_eq(float(instance.get("deadline", -1.0)), 0.0, "main 03 stores 0.0 instead of a deadline")
	assert_true(ContractOps.is_untimed(instance), "a zero deadline means no deadline")
	# 视图：无期限（-1 / 空标签 / —）。
	state.contracts()["main"] = instance
	var main_view: Dictionary = _contracts_view(context)["main"]
	assert_false(bool(main_view.get("has_deadline", true)), "port.view marks the contract as untimed")
	assert_almost_eq(float(main_view.get("remaining_hours", 0.0)), -1.0, 0.0001, "remaining hours use the -1 sentinel")
	assert_eq(String(main_view.get("remaining_label", "x")), "", "no remaining label for an untimed contract")
	assert_eq(String(main_view.get("deadline_label", "")), "—", "deadline label is a dash")
	var main_task := _task_of_kind(context, "main")
	assert_almost_eq(float(main_task.get("remaining_hours", 0.0)), -1.0, 0.0001, "task.view uses the -1 sentinel")
	assert_eq(float(main_task.get("deadline", -1.0)), 0.0, "task.view reports no deadline")
	# voyage.preview 不再误报迟到，完成奖励计入预算。
	var preview := VoyageCalculator.preview(context, destination, "core:boiler_strategy/standard")
	assert_true(bool(preview.get("ok", false)), "the preview succeeds")
	var preview_data: Dictionary = preview["data"]
	assert_true(preview_data.get("on_time", null) == true, "an untimed contract never previews as late")
	assert_false(
		bool((preview_data["revenue_estimate"] as Dictionary).get("timed", true)),
		"the revenue estimate marks the contract untimed"
	)
	assert_eq(
		int((preview_data["revenue_estimate"] as Dictionary).get("on_time_bonus", 0)),
		int(instance.get("on_time_bonus", 0)),
		"the completion bonus is included in the estimate"
	)
	# 无期限交付：恒准时、照发完成奖励、timed=false、不计入准时率。
	var stats_before := int(state.stats().get("on_time", 0))
	var result := ContractOps.complete(state, hub, instance, state.now() + 5000.0)
	assert_true(bool(result.get("on_time", false)), "an untimed delivery is always on time")
	assert_false(bool(result.get("timed", true)), "the result reports timed=false")
	assert_false(bool(result.get("late", true)), "an untimed delivery is never late")
	assert_eq(
		int(result.get("on_time_bonus", 0)),
		int(instance.get("on_time_bonus", 0)),
		"the completion bonus is paid unconditionally"
	)
	assert_eq(
		int(result.get("payout", 0)),
		int(instance.get("base_money", 0)) + int(instance.get("on_time_bonus", 0)),
		"the payout is base money plus the completion bonus"
	)
	VoyageService.record_arrival_stats(state, [result])
	assert_eq(
		int(state.stats().get("on_time", 0)),
		stats_before,
		"untimed deliveries stay out of the on-time rate"
	)
	# 主线 01/02 仍然限时：迟到会失去准时奖励。
	var timed_template := ContractOps.find_template_by_sequence(hub, 1)
	var timed_instance := ContractOps.create_instance(hub, timed_template, origin, destination, state.now(), distance, 7002, rng)
	assert_true(float(timed_instance.get("deadline", 0.0)) > state.now(), "main 01 still carries a deadline")
	assert_false(ContractOps.is_untimed(timed_instance), "main 01 is still a timed contract")
	var late := ContractOps.complete(state, hub, timed_instance, float(timed_instance.get("deadline", 0.0)) + 1.0)
	assert_true(bool(late.get("timed", false)), "the late result is a timed contract")
	assert_false(bool(late.get("on_time", true)), "arriving after the deadline is late")
	assert_eq(int(late.get("on_time_bonus", -1)), 0, "a late timed delivery forfeits the on-time bonus")


## 旧存档兼容：不写迁移，第三主线起实例即使存了正数 deadline 也按引导（无期限）处理。
func test_legacy_main_03_deadline_is_treated_as_no_deadline() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 4242})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var template := ContractOps.find_template_by_sequence(hub, 3)
	var origin := state.current_port_id()
	var destination := String(MapOps.neighbors(state.world(), origin)[0])
	# 手工实例等同真实链路里的「委托自带海图」。
	WorldOps.unlock_route(state, origin, destination)
	var instance := ContractOps.create_instance(
		hub, template, origin, destination, state.now(), 100.0, 7101, RandomNumberGenerator.new()
	)
	# 模拟旧存档：实例里已经写了正数 deadline。
	instance["deadline"] = state.now() + 200.0
	assert_true(ContractOps.is_untimed(instance), "a legacy main 03 instance is guidance, not timed")
	state.contracts()["main"] = instance
	var main_view: Dictionary = _contracts_view(context)["main"]
	assert_false(bool(main_view.get("has_deadline", true)), "legacy main 03 shows no deadline")
	assert_almost_eq(float(main_view.get("remaining_hours", 0.0)), -1.0, 0.0001, "legacy remaining hours use the sentinel")
	var result := ContractOps.complete(state, hub, instance, state.now() + 400.0)
	assert_true(bool(result.get("on_time", false)), "a legacy untimed delivery settles on time")
	assert_false(bool(result.get("timed", true)), "the legacy instance settles as untimed")
	# 普通委托仍按存储 deadline 判迟到：不过度兼容。
	var normal_template: ContentDefinition = ContractOps.templates_by_kind(hub, "normal")[0]
	var normal := ContractOps.create_instance(
		hub, normal_template, origin, destination, state.now(), 100.0, 7102, RandomNumberGenerator.new()
	)
	normal["deadline"] = state.now() + 10.0
	assert_false(ContractOps.is_untimed(normal), "a normal contract keeps its deadline")
	assert_false(
		bool(ContractOps.complete(state, hub, normal, state.now() + 30.0).get("on_time", true)),
		"a normal contract can still be late"
	)


# ── helpers ──


func _contracts_view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"port.view")
	assert_true(bool(result.get("ok", false)), "port.view succeeds")
	var data: Dictionary = result.get("data", {})
	return data.get("contracts", {})


func _view_offer_ids(offers: Array) -> Array:
	var ids: Array = []
	for raw in offers:
		if raw is Dictionary:
			ids.append(String((raw as Dictionary).get("instance_id", "")))
	return ids


func _task_of_kind(context: AppContext, kind: String) -> Dictionary:
	var result := context.queries.execute(&"task.view")
	assert_true(bool(result.get("ok", false)), "task.view succeeds")
	var data: Dictionary = result.get("data", {})
	for raw in Array(data.get("tasks", [])):
		if raw is Dictionary and String((raw as Dictionary).get("kind", "")) == kind:
			return raw
	return {}
