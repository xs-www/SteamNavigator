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
