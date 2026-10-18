extends TestCase


func test_main_chain_offer_and_accept() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 4242})
	var destination := String(context.state.contracts()["main"]["destination"])
	var voyage := context.commands.execute(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": "core:strategy/economic",
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
	assert_true(ShipOps.cargo_amount(context.state.ship(), "core:good/contract_freight", true) > 0, "contract cargo is loaded")


func test_contract_cargo_cannot_be_sold() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 5252})
	var result := context.commands.execute(&"trade.sell", {"item_id": "core:good/contract_freight", "amount": 1})
	assert_false(bool(result["ok"]), "contract cargo cannot be sold")
