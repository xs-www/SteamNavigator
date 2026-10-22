extends TestCase


func _first_trade_row(view: Dictionary) -> Dictionary:
	for row in view.get("market", []):
		if float(row.get("unit_weight", 99.0)) <= 1.0 and int(row.get("stock", 0)) >= 2:
			return row
	return {}


func test_trade_buy_and_sell() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	assert_true(bool(context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 111})["ok"]), "run starts")
	var view := context.queries.execute(&"port.view")
	var row := _first_trade_row(view["data"])
	assert_true(not row.is_empty(), "found an affordable light market row")
	var item_id := String(row["item_id"])
	var money_before := context.state.money()
	var cargo_before := int(row["cargo_amount"])
	var buy := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 2})
	assert_true(bool(buy["ok"]), "buy succeeds: %s" % str(buy))
	assert_eq(context.state.money(), money_before - int(buy["data"]["total"]), "money decreases by the purchase total")
	var after_buy_view := context.queries.execute(&"port.view")
	var after_row := _field(after_buy_view["data"]["market"], "item_id", item_id)
	assert_eq(int(after_row["cargo_amount"]), cargo_before + 2, "cargo amount increases")
	assert_true(Array(after_row["recent_prices"]).size() >= 2, "buying appends a real price-history sample")
	assert_true(float(after_row["trend_percent"]) >= 0.0, "trend percent is derived from history")
	var sell := context.commands.execute(&"trade.sell", {"item_id": item_id, "amount": 1})
	assert_true(bool(sell["ok"]), "sell succeeds: %s" % str(sell))
	var after_sell_view := context.queries.execute(&"port.view")
	var sold_row := _field(after_sell_view["data"]["market"], "item_id", item_id)
	assert_eq(int(sold_row["cargo_amount"]), cargo_before + 1, "one unit sold")


func test_failed_trade_rolls_back() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 222})
	var before := context.state.hash()
	var result := context.commands.execute(&"trade.buy", {"item_id": "core:item/iron_ore", "amount": 999999})
	assert_false(bool(result["ok"]), "oversized purchase fails")
	assert_eq(context.state.hash(), before, "failed command leaves state untouched")


func test_price_moves_with_stock() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 333})
	var view := context.queries.execute(&"port.view")
	for row in view["data"]["market"]:
		if int(row["stock"]) >= 10:
			var price_before := float(row["price"])
			var result := context.commands.execute(&"trade.buy", {"item_id": String(row["item_id"]), "amount": 5})
			if bool(result["ok"]):
				var after := context.queries.execute(&"port.view")
				var updated := _field(after["data"]["market"], "item_id", String(row["item_id"]))
				assert_true(float(updated["price"]) >= price_before, "price rises after stock falls")
				return
	fail("no market row could be bought for the price test")


func test_player_trade_price_impact_is_damped() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 3434})
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 0.0
	var view := context.queries.execute(&"port.view")
	var target := {}
	for row in view["data"]["market"]:
		if bool(row.get("buyable", true)) and String(row["item_id"]) == "core:item/sealing_compound":
			target = row
			break
	assert_true(not target.is_empty(), "found the sealing compound row")
	var entry: Dictionary = context.state.market()[context.state.current_port_id()][String(target["item_id"])]
	var price_before := float(entry["price"])
	var target_entry: Dictionary = entry.duplicate(true)
	target_entry["stock"] = int(target_entry["stock"]) - 5
	var full_price := MarketOps.compute_price(target_entry)
	var result := context.commands.execute(&"trade.buy", {"item_id": String(target["item_id"]), "amount": 5})
	assert_true(bool(result["ok"]), "purchase succeeds: %s" % str(result))
	var entry_after: Dictionary = context.state.market()[context.state.current_port_id()][String(target["item_id"])]
	var after_price := float(entry_after["price"])
	var expected := lerpf(price_before, full_price, 0.35)
	assert_almost_eq(after_price, expected, 0.01, "player trade only passes 35% of the price impulse")
	assert_true(absf(after_price - price_before) < absf(full_price - price_before), "damped move is smaller than full equilibrium")



func _field(rows: Array, key: String, value: Variant) -> Dictionary:
	for row in rows:
		if row is Dictionary and row.get(key) == value:
			return row
	return {}
