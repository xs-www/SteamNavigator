extends TestCase
## @static-doc
## 作用：Phase D4 自动贸易运行时测试：策略启动/停止/切换、规则暂停与恢复、买卖航程、
## 风险日志、存档 round-trip、损坏数据规范化与确定性。
##
## ## 契约与约束
## - 内容从 Core 的 `trade_policies` / `automation_rules` 动态选取，不写死 policy id。
## - 测试直接布置已发现港口与市场库存/价格，保证利润率满足策略的 `min_margin`；
##   不依赖随机世界是否有价差。
## - 自动贸易由 `AutoTradeSystem` 在 `sim.advance` 中推进；断言货舱、利润与日志。
## @end-static-doc

const STEADY := "core:starting_scenario/steady"


func _start(seed_value: int, money: int = 5000) -> AppContext:
	var context: AppContext = bootstrap_core()["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": seed_value})
	assert_true(bool(started.get("ok", false)), "run.start succeeds: %s" % str(started))
	context.state.set_money(money)
	_discover_all_ports(context)
	_prepare_market(context)
	return context


func _discover_all_ports(context: AppContext) -> void:
	var world := context.state.world()
	var discovered: Array = Array(world.get("discovered_ports", []))
	for raw_port_id in world.get("ports", {}).keys():
		if not discovered.has(String(raw_port_id)):
			discovered.append(String(raw_port_id))
	world["discovered_ports"] = discovered


func _prepare_market(context: AppContext) -> void:
	var home_id := context.state.current_port_id()
	var target_id := _target_port(context)
	var market: Dictionary = context.state.market()
	for item_id in ["core:item/timber", "core:item/boiler_plate"]:
		var item := context.registries.get_by_id(ContentTypes.ITEM, item_id)
		if item == null:
			continue
		var home_entry := MarketOps.create_market_entry(item, 120, 1.0)
		home_entry["buyable"] = true
		market[home_id][item_id] = home_entry
		if not target_id.is_empty():
			var target_market: Dictionary = market.get(target_id, {})
			var target_entry := MarketOps.create_market_entry(item, 1, 1.0)
			target_entry["buyable"] = true
			target_market[item_id] = target_entry
			market[target_id] = target_market


func _target_port(context: AppContext) -> String:
	var world := context.state.world()
	var home_id := context.state.current_port_id()
	var fallback := ""
	for raw_port_id in world.get("ports", {}).keys():
		var port_id := String(raw_port_id)
		if port_id == home_id:
			continue
		if fallback.is_empty():
			fallback = port_id
		var port: Dictionary = world["ports"][raw_port_id]
		var tags: Array = Array(port.get("tags", []))
		if tags.has("port.trade") or tags.has("port.craft"):
			return port_id
	if not fallback.is_empty():
		var port: Dictionary = world["ports"][fallback]
		var tags: Array = Array(port.get("tags", []))
		tags.append("port.trade")
		port["tags"] = tags
	return fallback


func _policy_id(context: AppContext) -> String:
	var policies := context.registries.get_all(ContentTypes.TRADE_POLICY)
	assert_false(policies.is_empty(), "core ships trade policies")
	return policies[0].id if not policies.is_empty() else ""


func _view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"auto_trade.view")
	assert_true(bool(result.get("ok", false)), "auto_trade.view answers")
	return result.get("data", {})


func _advance(context: AppContext, hours: float) -> void:
	var result := context.commands.execute(&"sim.advance", {"hours": hours})
	assert_true(bool(result.get("ok", false)), "sim.advance succeeds: %s" % str(result))


func test_commands_and_query_are_registered() -> void:
	var context := _start(501)
	for command in [&"auto_trade.start", &"auto_trade.stop", &"auto_trade.set_policy", &"auto_trade.pause", &"auto_trade.resume"]:
		assert_true(context.commands.has(command), "%s is registered" % String(command))
	assert_true(context.queries.has(&"auto_trade.view"), "auto_trade.view is registered")
	var started := context.commands.execute(&"auto_trade.start", {"policy_id": _policy_id(context)})
	assert_true(bool(started.get("ok", false)), "starting auto trade succeeds: %s" % str(started))
	assert_true(TickScheduler.has(AutoTradeSystem.SYSTEM_ID), "starting auto trade registers the tick system")


func test_start_validates_policy_and_is_unique() -> void:
	var context := _start(502)
	var unknown := context.commands.execute(&"auto_trade.start", {"policy_id": "test:trade_policy/absent"})
	assert_eq(String(unknown.get("error_code", "")), "unknown_trade_policy", "unknown policies are rejected")
	var first := context.commands.execute(&"auto_trade.start", {"policy_id": _policy_id(context)})
	assert_true(bool(first.get("ok", false)), "the first start succeeds")
	var again := context.commands.execute(&"auto_trade.start", {"policy_id": _policy_id(context)})
	assert_eq(String(again.get("error_code", "")), "trade_running", "only one auto trade can run")


func test_buy_travel_sell_cycle() -> void:
	var context := _start(503)
	var policy_id := _policy_id(context)
	var policy := context.registries.get_by_id(ContentTypes.TRADE_POLICY, policy_id)
	var travel := maxi(1, int(round(float(policy.data.get("travel_hours", 1.0)))))
	assert_true(bool(context.commands.execute(&"auto_trade.start", {"policy_id": policy_id}).get("ok", false)), "start succeeds")
	var money_before := context.state.money()
	_advance(context, 1)
	var bought := _view(context)
	assert_eq(int(bought.get("cargo_units", 0)) > 0, true, "the first tick buys cargo: %s" % str(bought))
	assert_true(int(bought.get("spent", 0)) > 0, "the buy records spending")
	assert_true(String(bought.get("phase", "")) == "outbound", "the trader departs after buying")
	_advance(context, travel)
	var sold := _view(context)
	assert_eq(int(sold.get("cargo_units", 0)), 0, "the cargo is sold on arrival")
	assert_true(int(sold.get("earned", 0)) > 0, "the sale records income")
	assert_true(int(sold.get("profit", 0)) > 0, "a prepared profitable route earns a profit: %s" % str(sold))
	assert_true(context.state.money() > money_before, "profit reaches the player's money")
	_advance(context, travel)
	assert_eq(String(_view(context).get("phase", "")), "idle", "the trader returns home and idles")


func test_rules_pause_and_resume_the_run() -> void:
	var context := _start(504)
	var policy_id := _policy_id(context)
	var policy := context.registries.get_by_id(ContentTypes.TRADE_POLICY, policy_id)
	var paused_at := 0.0
	for rule_id in policy.data.get("rules", []):
		var rule := context.registries.get_by_id(ContentTypes.AUTOMATION_RULE, String(rule_id))
		if rule != null and String(rule.data.get("action", "")) == "pause":
			paused_at = float(rule.data.get("condition", {}).get("value", 0.0))
			break
	assert_true(paused_at > 0.0, "the policy has a money-based pause rule")
	context.state.set_money(int(paused_at))
	assert_true(bool(context.commands.execute(&"auto_trade.start", {"policy_id": policy_id}).get("ok", false)), "start succeeds")
	_advance(context, 1)
	var view := _view(context)
	assert_true(bool(view.get("paused", false)), "the low-money rule pauses the run: %s" % str(view))
	assert_eq(int(view.get("cargo_units", 0)), 0, "a paused run does not buy")
	context.state.set_money(int(paused_at) + 2000)
	_advance(context, 1)
	assert_false(bool(_view(context).get("paused", true)), "the resume rule clears the pause")


func test_set_policy_and_stop() -> void:
	var context := _start(505)
	var policies := context.registries.get_all(ContentTypes.TRADE_POLICY)
	if policies.size() < 2:
		return
	assert_true(bool(context.commands.execute(&"auto_trade.start", {"policy_id": policies[0].id}).get("ok", false)), "start succeeds")
	var paused := context.commands.execute(&"auto_trade.pause", {})
	assert_true(bool(paused.get("ok", false)), "manual pause succeeds")
	assert_true(bool(context.commands.execute(&"auto_trade.resume", {}).get("ok", false)), "manual resume succeeds")
	var switched := context.commands.execute(&"auto_trade.set_policy", {"policy_id": policies[1].id})
	assert_true(bool(switched.get("ok", false)), "switching policy while idle succeeds: %s" % str(switched))
	assert_eq(String(_view(context).get("policy_id", "")), policies[1].id, "the view reports the new policy")
	var stopped := context.commands.execute(&"auto_trade.stop", {})
	assert_true(bool(stopped.get("ok", false)), "stopping succeeds")
	assert_false(bool(_view(context).get("active", true)), "the view reports the stopped run")


func test_save_round_trip() -> void:
	var context := _start(506)
	assert_true(bool(context.commands.execute(&"auto_trade.start", {"policy_id": _policy_id(context)}).get("ok", false)), "start succeeds")
	_advance(context, 3)
	var before := _view(context)
	var saved := context.save.save_slot("trade_manual", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "saving succeeds")
	var loaded := context.save.load_slot("trade_manual")
	assert_true(bool(loaded.get("ok", false)), "loading succeeds")
	var loaded_context: AppContext = bootstrap_core()["context"]
	loaded_context.set_state(loaded["state"])
	var after := _view(loaded_context)
	assert_eq(String(after.get("policy_id", "")), String(before.get("policy_id", "")), "the policy survives")
	assert_eq(String(after.get("phase", "")), String(before.get("phase", "")), "the phase survives")
	assert_eq(int(after.get("cargo_units", -1)), int(before.get("cargo_units", -2)), "the cargo survives")


func test_malformed_trade_data_is_normalized() -> void:
	var context := _start(507)
	for variant in [
		"broken",
		42,
		["no"],
		{"active": true, "cargo": "bad", "log": "bad", "phase": "warp"},
		{"active": true, "log": null},
		{"active": true, "travel_remaining": null},
		{"active": true, "legs": null, "spent": [], "profit": {}},
		{"active": true, "cargo": {"core:item/timber": {}}},
		{"active": "false", "paused": "x"},
	]:
		context.state.data["trade"] = variant
		var result := context.queries.execute(&"auto_trade.view")
		assert_true(bool(result.get("ok", false)), "auto_trade.view tolerates malformed data")
		var view: Dictionary = result.get("data", {})
		assert_eq(typeof(view.get("phase", "")), TYPE_STRING, "the phase is normalized")
		assert_true(view.get("cargo", null) is Array, "cargo normalizes to an array")
		assert_true(view.get("log", null) is Array, "log normalizes to an array")
		assert_eq(typeof(view.get("travel_remaining", null)), TYPE_FLOAT, "travel time normalizes to a float")
		assert_eq(typeof(view.get("legs", null)), TYPE_INT, "leg counters normalize to ints")
		assert_eq(typeof(view.get("paused", null)), TYPE_BOOL, "paused normalizes to a bool")
		_advance(context, 1)
		if variant is Dictionary:
			var active_value: Variant = (variant as Dictionary).get("active", false)
			if active_value is bool and active_value:
				assert_true(context.state.data.get("trade", null) is Dictionary, "a tick keeps the normalized trade block")


## D4-FIX：`when` 必须真的控制规则触发阶段；arrival 规则不能在第 1 tick 就暂停。
func test_rule_when_gates_the_trigger_phase() -> void:
	var context := _start(509)
	var rule := context.registries.get_by_id(ContentTypes.AUTOMATION_RULE, "core:automation_rule/bulk_stop_low_money")
	assert_true(rule != null, "the low-money rule exists")
	var original := String(rule.data.get("when", "tick"))
	rule.data["when"] = "arrival"
	context.state.data["money"] = 100
	var started := context.commands.execute(&"auto_trade.start", {"policy_id": _policy_id(context)})
	assert_true(bool(started.get("ok", false)), "starting with a low balance succeeds")
	_advance(context, 1)
	assert_false(bool(_view(context).get("paused", true)), "an arrival rule does not fire on the first tick")
	rule.data["when"] = original


func test_same_seed_and_commands_are_deterministic() -> void:
	var first := _start(508)
	var second := _start(508)
	for context in [first, second]:
		context.commands.execute(&"auto_trade.start", {"policy_id": _policy_id(context)})
		_advance(context, 10)
	if first.state == null or second.state == null:
		return
	assert_eq(first.state.data.get("trade", null), second.state.data.get("trade", null),
		"same seed + same trade commands reproduce the same trade block")
