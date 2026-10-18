extends TestCase


func test_supply_view_and_purchases() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 9191})
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 0.0
	var view := context.queries.execute(&"supply.view")
	assert_true(bool(view["ok"]), "supply view succeeds")
	var data: Dictionary = view["data"]
	assert_true(bool(data["has_supply"]), "starting port has a supply dock")
	assert_true(float(data["coal_price"]) > 0.0, "coal has a price")
	assert_true(float(data["water_price"]) > 0.0, "water has a price")
	assert_true(int(data["max_coal"]) >= 10, "weight and money allow coal")
	assert_true(int(data["max_water"]) >= 10, "weight and money allow water")
	var coal_view: Dictionary = data["coal_view"]
	assert_eq(int(coal_view["max_buy"]), int(data["max_coal"]), "coal card uses the same max-buy rule")
	assert_true(coal_view.has("fill_to"), "coal card exposes fill-to value")
	assert_true(coal_view.has("estimated_days"), "coal card exposes estimated endurance")
	assert_true(int(coal_view["fill_cost"]) >= 0, "coal card exposes fill cost")
	assert_true(Array(coal_view["blockers"]).is_empty(), "coal card has no blockers at start")
	var coal_stock_before := int(data["coal_stock"])
	var coal_price_before := float(data["coal_price"])
	assert_true(coal_stock_before >= 10, "port has coal stock")
	var coal := context.commands.execute(&"supply.buy_coal", {"amount": 10})
	assert_true(bool(coal["ok"]), "buying coal succeeds: %s" % str(coal))
	assert_almost_eq(float(context.state.ship()["coal"]), 10.0, 0.001, "coal is added")
	var after_coal_result := context.queries.execute(&"supply.view")
	var after_coal: Dictionary = after_coal_result["data"]
	assert_eq(int(after_coal["coal_stock"]), coal_stock_before - 10, "coal purchase consumes port stock")
	assert_true(float(after_coal["coal_price"]) >= coal_price_before, "coal price rises as port stock falls")
	var water := context.commands.execute(&"supply.buy_water", {"amount": 10})
	assert_true(bool(water["ok"]), "buying water succeeds: %s" % str(water))
	assert_almost_eq(float(context.state.ship()["water"]), 10.0, 0.001, "water is added")


func test_repair_quote_and_repair() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 9292})
	context.state.ship()["durability"] = 50.0
	var before_result := context.queries.execute(&"supply.view")
	var before: Dictionary = before_result["data"]
	var repair: Dictionary = before["repair"]
	assert_true(float(repair["missing"]) > 0.0, "repair quote reports missing durability")
	assert_true(int(repair["cost"]) > 0, "repair quote has a cost")
	var result := context.commands.execute(&"supply.repair", {})
	assert_true(bool(result["ok"]), "repair succeeds: %s" % str(result))
	assert_almost_eq(float(context.state.ship()["durability"]), float(repair["max_durability"]), 0.001, "durability is restored")
