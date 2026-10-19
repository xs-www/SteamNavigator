extends TestCase


func _row(rows: Array, item_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("item_id", "")) == item_id:
			return row
	return {}


func test_sell_any_good_but_buy_only_listed() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 4343})
	var view := context.queries.execute(&"port.view")
	var sell_only := {}
	for row in view["data"]["market"]:
		if not bool(row.get("buyable", true)) and int(row.get("stock", 0)) == 0:
			sell_only = row
			break
	assert_true(not sell_only.is_empty(), "port exposes sell-only goods")
	var item_id := String(sell_only["item_id"])
	var buy := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 1})
	assert_false(bool(buy["ok"]), "sell-only good cannot be bought")
	assert_eq(String(buy["error_code"]), "not_buyable", "not_buyable error is returned")
	ShipOps.add_cargo(context.state.ship(), item_id, 2, "", 0.0)
	var sell := context.commands.execute(&"trade.sell", {"item_id": item_id, "amount": 1})
	assert_true(bool(sell["ok"]), "any cargo can be sold: %s" % str(sell))
	var after := context.queries.execute(&"port.view")
	var row := _row(after["data"]["market"], item_id)
	assert_eq(int(row["stock"]), 1, "sell-only stock increases after selling")
	assert_false(bool(row["buyable"]), "the good remains sell-only")


func test_cargo_average_cost_tracks_purchases() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 4444})
	var view := context.queries.execute(&"port.view")
	var hub: RegistryHub = context.registries
	var weight_headroom := ShipOps.max_weight(hub, context.state.ship()) - ShipOps.total_weight(hub, context.state)
	var target := {}
	for row in view["data"]["market"]:
		var unit_weight := float(row.get("unit_weight", 99.0))
		# Pick a light good that also fits three units in the remaining weight
		# budget (the starting contract cargo already loads the ship).
		if bool(row.get("buyable", true)) and unit_weight <= 1.0 and int(row.get("stock", 0)) >= 5 \
				and unit_weight * 3.0 <= weight_headroom + 0.0001:
			target = row
			break
	assert_true(not target.is_empty(), "found a light buyable good")
	var item_id := String(target["item_id"])
	var first := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 2})
	assert_true(bool(first["ok"]), "first purchase succeeds")
	var first_view := context.queries.execute(&"port.view")
	var first_row := _row(first_view["data"]["market"], item_id)
	var first_avg := float(first_row["cargo_avg_cost"])
	assert_true(first_avg > 0.0, "average cost is tracked")
	assert_true(float(first_view["data"]["ship"]["cargo_cost_basis"]) > 0.0, "inventory cost basis is tracked")
	var second := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 1})
	assert_true(bool(second["ok"]), "second purchase succeeds")
	var second_view := context.queries.execute(&"port.view")
	var second_row := _row(second_view["data"]["market"], item_id)
	var second_avg := float(second_row["cargo_avg_cost"])
	assert_true(second_avg >= first_avg - 0.01, "average cost follows price changes")
	var cost_before_sell := float(second_view["data"]["ship"]["cargo_cost_basis"])
	var sell := context.commands.execute(&"trade.sell", {"item_id": item_id, "amount": 1})
	assert_true(bool(sell["ok"]), "partial sale succeeds")
	var third_view := context.queries.execute(&"port.view")
	var third_row := _row(third_view["data"]["market"], item_id)
	assert_almost_eq(float(third_row["cargo_avg_cost"]), second_avg, 0.01, "partial sale keeps average cost")
	assert_true(float(third_view["data"]["ship"]["cargo_cost_basis"]) < cost_before_sell, "partial sale reduces cost basis")


func test_port_memory_is_last_visit_snapshot() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 4545})
	var start_port := context.state.current_port_id()
	var memory := context.queries.execute(&"port.memory", {"port_id": start_port})
	assert_true(bool(memory["ok"]), "port memory query succeeds")
	var data: Dictionary = memory["data"]
	assert_true(bool(data["has_memory"]), "starting port has a memory snapshot")
	assert_eq(float(data["captured_at"]), 0.0, "snapshot is captured at run start")
	assert_true(Array(data["market"]).size() >= 8, "all ordinary goods are snapshotted")
	var supply_rows := 0
	for row in data["market"]:
		if bool(row.get("is_supply", false)):
			supply_rows += 1
	assert_eq(supply_rows, 2, "coal and water are part of the port memory")
	context.state.advance_time(5.0)
	var unchanged_result := context.queries.execute(&"port.memory", {"port_id": start_port})
	var unchanged: Dictionary = unchanged_result["data"]
	assert_eq(float(unchanged["captured_at"]), 0.0, "time passing does not refresh the snapshot")
	var target := ""
	for row in data["market"]:
		if bool(row.get("buyable", true)) and int(row.get("stock", 0)) > 0:
			target = String(row["item_id"])
			break
	assert_true(not target.is_empty(), "snapshot has a buyable row")
	context.commands.execute(&"trade.buy", {"item_id": target, "amount": 1})
	var refreshed_result := context.queries.execute(&"port.memory", {"port_id": start_port})
	var refreshed: Dictionary = refreshed_result["data"]
	assert_almost_eq(float(refreshed["captured_at"]), 5.0, 0.001, "trading refreshes the snapshot timestamp")
	var remote := ""
	for destination in context.queries.execute(&"port.view")["data"]["destinations"]:
		remote = String(destination["port_id"])
		break
	assert_true(not remote.is_empty(), "starting port has a neighbour")
	MapOps.discover(context.state, remote, true)
	MarketMemoryService.remember(context.state, remote)
	var remote_memory := context.queries.execute(&"port.memory", {"port_id": remote})
	assert_true(bool(remote_memory["data"]["has_memory"]), "visited port memory is queryable")
	assert_true(not String(remote_memory["data"]["name_key"]).is_empty(), "memory carries the port name")
