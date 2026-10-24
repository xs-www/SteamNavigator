extends TestCase
## @static-doc
## 作用：市场买卖领域测试：船货舱买卖、港口仓库买入 / 直卖、默认落点、非法落点与失败回滚。
##
## ## 契约与约束
## - 买进仓库不占船上重量 / 货舱，仓库直卖不动船舱；两者复用市场价格、库存与收入/支出口径。
## - 非法 `destination` / `source`、港存不足、金币不足、仓库数量不足必须失败，且 `state.hash()` 不变（命令事务不提交）。
## - 交易后状态引用会被事务提交替换，断言一律重新读取 `context.state`，不缓存 `ship` 字典。
## @end-static-doc


func _first_trade_row(view: Dictionary) -> Dictionary:
	for row in view.get("market", []):
		if float(row.get("unit_weight", 99.0)) <= 1.0 and int(row.get("stock", 0)) >= 2:
			return row
	return {}


## 可买、港存足够、按整数参考价估算得起的市场行（仓库买卖不关心载重）。
func _first_buyable_row(view: Dictionary, amount: int) -> Dictionary:
	var money := int(view.get("money", 0))
	for row in view.get("market", []):
		if not bool(row.get("buyable", true)):
			continue
		var unit_price := int(row.get("price", 0))
		if int(row.get("stock", 0)) >= amount and unit_price > 0 and unit_price * amount <= money:
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


func test_default_trade_storage_is_cargo() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 606})
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	var row := _first_trade_row(view)
	assert_true(not row.is_empty(), "found an affordable light market row")
	var item_id := String(row["item_id"])
	var buy := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 1})
	assert_true(bool(buy["ok"]), "default buy succeeds: %s" % str(buy))
	assert_eq(String(buy["data"].get("destination", "")), "cargo", "default buy lands in the ship hold")
	assert_eq(int(buy["data"].get("warehouse_amount", -1)), -1, "hold purchase does not report a warehouse amount")
	var sell := context.commands.execute(&"trade.sell", {"item_id": item_id, "amount": 1})
	assert_true(bool(sell["ok"]), "default sell succeeds: %s" % str(sell))
	assert_eq(String(sell["data"].get("source", "")), "cargo", "default sell takes from the ship hold")
	assert_eq(int(sell["data"].get("warehouse_amount", -1)), -1, "hold sale does not report a warehouse amount")


func test_buy_into_warehouse_keeps_hold() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	assert_true(bool(context.commands.execute(&"run.start", {
		"starting_scenario": "core:starting_scenario/steady",
		"seed": 444,
	})["ok"]), "run starts")
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	var row := _first_buyable_row(view, 2)
	assert_true(not row.is_empty(), "found an affordable buyable market row")
	var item_id := String(row["item_id"])
	var port_id := context.state.current_port_id()
	var money_before := context.state.money()
	var cargo_before := ShipOps.cargo_amount(context.state.ship(), item_id, true)
	var stored_before := WarehouseOps.material_amount(context.state, port_id, item_id)
	var result := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 2, "destination": "warehouse"})
	assert_true(bool(result["ok"]), "warehouse purchase succeeds: %s" % str(result))
	assert_eq(String(result["data"].get("destination", "")), "warehouse", "result reports the warehouse destination")
	assert_eq(context.state.money(), money_before - int(result["data"]["total"]), "money decreases by the purchase total")
	assert_eq(ShipOps.cargo_amount(context.state.ship(), item_id, true), cargo_before, "warehouse purchase leaves the hold untouched")
	assert_eq(WarehouseOps.material_amount(context.state, port_id, item_id), stored_before + 2, "warehouse materials increase by the purchase")
	assert_eq(int(result["data"].get("warehouse_amount", -1)), stored_before + 2, "result reports the stored warehouse amount")
	var events: Array = result.get("events", [])
	assert_eq(events.size(), 1, "warehouse purchase emits one market event")
	var payload: Dictionary = events[0]["payload"]
	assert_eq(String(payload.get("storage", "")), "warehouse", "market event reports the warehouse storage")
	assert_eq(String(payload.get("source", "")), "player", "market event keeps the player actor marker")


func test_sell_from_warehouse_keeps_hold() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	assert_true(bool(context.commands.execute(&"run.start", {
		"starting_scenario": "core:starting_scenario/steady",
		"seed": 555,
	})["ok"]), "run starts")
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	var row := _first_buyable_row(view, 3)
	assert_true(not row.is_empty(), "found an affordable buyable market row")
	var item_id := String(row["item_id"])
	var port_id := context.state.current_port_id()
	var buy := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 3, "destination": "warehouse"})
	assert_true(bool(buy["ok"]), "warehouse purchase succeeds: %s" % str(buy))
	var money_after_buy := context.state.money()
	var cargo_after_buy := ShipOps.cargo_amount(context.state.ship(), item_id, true)
	var stored_after_buy := WarehouseOps.material_amount(context.state, port_id, item_id)
	var result := context.commands.execute(&"trade.sell", {"item_id": item_id, "amount": 1, "source": "warehouse"})
	assert_true(bool(result["ok"]), "warehouse sale succeeds: %s" % str(result))
	assert_eq(String(result["data"].get("source", "")), "warehouse", "result reports the warehouse source")
	assert_eq(context.state.money(), money_after_buy + int(result["data"]["revenue"]), "money increases by the sale revenue")
	assert_eq(WarehouseOps.material_amount(context.state, port_id, item_id), stored_after_buy - 1, "warehouse materials decrease by the sale")
	assert_eq(int(result["data"].get("warehouse_amount", -1)), stored_after_buy - 1, "result reports the stored warehouse amount")
	assert_eq(ShipOps.cargo_amount(context.state.ship(), item_id, true), cargo_after_buy, "warehouse sale leaves the hold untouched")
	var events: Array = result.get("events", [])
	assert_eq(events.size(), 1, "warehouse sale emits one market event")
	var payload: Dictionary = events[0]["payload"]
	assert_eq(String(payload.get("storage", "")), "warehouse", "market event reports the warehouse source")


func test_invalid_trade_storage_fails_without_state_change() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 6060})
	var before := context.state.hash()
	var bad_buy := context.commands.execute(&"trade.buy", {"item_id": "core:item/iron_ore", "amount": 1, "destination": "hold"})
	assert_false(bool(bad_buy["ok"]), "invalid destination fails")
	assert_eq(String(bad_buy["error_code"]), "invalid_destination", "invalid destination error code")
	assert_eq(String(bad_buy["message_key"]), "ui.error.invalid_destination", "invalid destination message key")
	assert_eq(context.state.hash(), before, "invalid destination leaves state untouched")
	var bad_sell := context.commands.execute(&"trade.sell", {"item_id": "core:item/iron_ore", "amount": 1, "source": "hold"})
	assert_false(bool(bad_sell["ok"]), "invalid source fails")
	assert_eq(String(bad_sell["error_code"]), "invalid_trade_source", "invalid source error code")
	assert_eq(String(bad_sell["message_key"]), "ui.error.invalid_trade_source", "invalid source message key")
	assert_eq(context.state.hash(), before, "invalid source leaves state untouched")


func test_warehouse_trade_failures_roll_back() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 666})
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	var row := _first_buyable_row(view, 1)
	assert_true(not row.is_empty(), "found an affordable buyable market row")
	var item_id := String(row["item_id"])
	var port_id := context.state.current_port_id()
	var cargo_before := ShipOps.cargo_amount(context.state.ship(), item_id, true)
	var stored_before := WarehouseOps.material_amount(context.state, port_id, item_id)
	var before := context.state.hash()
	var stock_fail := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 999999, "destination": "warehouse"})
	assert_false(bool(stock_fail["ok"]), "oversized warehouse purchase fails")
	assert_eq(String(stock_fail["error_code"]), "insufficient_stock", "oversized warehouse purchase reports stock")
	assert_eq(context.state.hash(), before, "failed oversized warehouse purchase leaves state untouched")
	context.state.set_money(0)
	var broke_hash := context.state.hash()
	var money_fail := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 1, "destination": "warehouse"})
	assert_false(bool(money_fail["ok"]), "warehouse purchase without money fails")
	assert_eq(String(money_fail["error_code"]), "insufficient_money", "warehouse purchase without money reports money")
	assert_eq(context.state.hash(), broke_hash, "failed money warehouse purchase leaves state untouched")
	assert_eq(ShipOps.cargo_amount(context.state.ship(), item_id, true), cargo_before, "failed warehouse purchase leaves the hold untouched")
	assert_eq(WarehouseOps.material_amount(context.state, port_id, item_id), stored_before, "failed warehouse purchase stores nothing")
	var empty_sell := context.commands.execute(&"trade.sell", {"item_id": item_id, "amount": 1, "source": "warehouse"})
	assert_false(bool(empty_sell["ok"]), "selling from an empty warehouse fails")
	assert_eq(String(empty_sell["error_code"]), "insufficient_materials", "empty warehouse sale reports materials")
	assert_eq(int(empty_sell["data"].get("available", -1)), 0, "empty warehouse sale reports the available amount")
	assert_eq(context.state.hash(), broke_hash, "failed warehouse sale leaves state untouched")


func _field(rows: Array, key: String, value: Variant) -> Dictionary:
	for row in rows:
		if row is Dictionary and row.get(key) == value:
			return row
	return {}
