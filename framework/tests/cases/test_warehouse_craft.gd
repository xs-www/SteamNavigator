extends TestCase
## Warehouse, crafting, transit and replacement flows for iteration 1.
## See docs/specs/ITERATION_1_MVP_LOOP.md §3.1-3.3, §4, §6 and §8.

const CONTRACT_FREIGHT := "core:good/contract_freight"
const MEDIUM_UNLOCKS := ["core:hull/medium_standard", "core:cargo_module/medium_hold"]
const LARGE_UNLOCKS := ["core:hull/large_efficient", "core:hull/large_performance"]


## Boots Core, starts a run and releases the starter main contract cargo so
## tests have predictable weight/capacity headroom.
func _start(seed_value: int, money: int = 5000) -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": seed_value})
	assert_true(bool(started.get("ok", false)), "run starts (seed %d): %s" % [seed_value, str(started)])
	context.state.set_money(money)
	_clear_active_contract(context)
	WarehouseOps.ensure_structure(context.state)
	return context


func _clear_active_contract(context: AppContext) -> void:
	var contracts: Dictionary = context.state.contracts()
	contracts["main"] = null
	contracts["main_offer"] = null
	var ship := context.state.ship()
	var carried := ShipOps.cargo_amount(ship, CONTRACT_FREIGHT, true)
	if carried > 0:
		ShipOps.remove_cargo(ship, CONTRACT_FREIGHT, carried, true)


func _event_types(events: Array) -> Array:
	var types: Array = []
	for event in events:
		if event is Dictionary:
			types.append(String(event.get("type", "")))
	return types


func test_run_start_initializes_warehouses_and_transit() -> void:
	var context := _start(7101)
	var world: Dictionary = context.state.world()
	var ports: Dictionary = world.get("ports", {})
	var warehouses: Dictionary = world.get("warehouses", {})
	assert_eq(warehouses.size(), ports.size(), "every port has a warehouse")
	for raw_port_id in ports.keys():
		assert_true(warehouses.has(String(raw_port_id)), "warehouse exists for %s" % String(raw_port_id))
		var entry: Dictionary = warehouses[String(raw_port_id)]
		assert_true(entry.has("modules") and entry.has("materials"), "warehouse has modules and materials sections")
	assert_true(context.state.ship().has("transit_modules"), "ship has a transit module bag")
	assert_empty(WarehouseOps.transit_modules(context.state.ship()), "transit starts empty")
	var view := context.queries.execute(&"shipyard.view")
	assert_true(bool(view["ok"]), "shipyard view succeeds")
	var data: Dictionary = view["data"]
	assert_true(data.has("warehouse"), "shipyard view exposes warehouse")
	assert_true(data.has("craft"), "shipyard view exposes craft rows")
	assert_true(data["warehouse"].has("modules") and data["warehouse"].has("materials"), "warehouse view has both sections")
	var candidate: Dictionary = data["candidates"][0]
	assert_true(candidate.has("will_replace"), "candidates expose will_replace")
	assert_true(candidate.has("unlock_template_id"), "candidates expose unlock_template_id")
	assert_true(candidate.has("craftable"), "candidates expose craftable")
	assert_true(candidate.has("money_only"), "candidates expose money_only")
	assert_true(candidate.has("craft_blockers"), "candidates expose craft_blockers")
	assert_true(data.has("orders"), "shipyard view exposes craft orders")
	assert_true(data.has("wait_options"), "shipyard view exposes wait options")
	assert_eq(data["wait_options"], [6, 12, 24], "wait options are the agreed choices")
	# A fresh context with no run still returns the full ViewModel shape for the UI.
	var fresh := bootstrap_core()
	var empty_result: Dictionary = fresh["context"].queries.execute(&"shipyard.view")
	var empty: Dictionary = empty_result["data"]
	assert_false(bool(empty["has_run"]), "no-run view reports has_run false")
	assert_true(empty.has("warehouse") and empty.has("craft"), "no-run view still exposes warehouse/craft arrays")
	assert_true(empty.has("orders") and empty.has("wait_options"), "no-run view still exposes orders/wait_options")


func test_transit_weight_counts_without_cargo_capacity() -> void:
	var context := _start(7102)
	var hub: RegistryHub = context.registries
	var port_id := context.state.current_port_id()
	WarehouseOps.add_module(context.state, port_id, "core:cargo_module/small_hold", 1)
	var weight_before := ShipOps.total_weight(hub, context.state)
	var capacity_before := ShipOps.cargo_capacity(hub, context.state.ship())
	var cargo_used_before := ShipOps.cargo_used(hub, context.state.ship())
	var taken := context.commands.execute(&"warehouse.take_module", {"module_id": "core:cargo_module/small_hold", "qty": 1})
	assert_true(bool(taken["ok"]), "taking a module from the warehouse succeeds: %s" % str(taken))
	assert_almost_eq(ShipOps.total_weight(hub, context.state), weight_before + 6.0, 0.001, "transit module weight is counted")
	assert_almost_eq(ShipOps.cargo_capacity(hub, context.state.ship()), capacity_before, 0.001, "transit does not change cargo capacity")
	assert_almost_eq(ShipOps.cargo_used(hub, context.state.ship()), cargo_used_before, 0.001, "transit does not occupy cargo")
	var view := context.queries.execute(&"shipyard.view")
	assert_almost_eq(float(view["data"]["ship"]["transit_weight"]), 6.0, 0.001, "view exposes transit weight")
	assert_eq(view["data"]["ship"]["transit_modules"].size(), 1, "view lists transit modules")
	var stored := context.commands.execute(&"warehouse.store_module", {"module_id": "core:cargo_module/small_hold", "qty": 1})
	assert_true(bool(stored["ok"]), "storing the module back succeeds: %s" % str(stored))
	assert_almost_eq(ShipOps.total_weight(hub, context.state), weight_before, 0.001, "storing removes transit weight")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, "core:cargo_module/small_hold"), 1, "module is stored again")
	assert_empty(WarehouseOps.transit_modules(context.state.ship()), "transit bag is empty again")


func test_store_and_take_materials() -> void:
	var context := _start(7103)
	var port_id := context.state.current_port_id()
	ShipOps.add_cargo(context.state.ship(), "core:good/brass", 2, "", 40.0)
	var stored := context.commands.execute(&"warehouse.store_materials", {"item_id": "core:good/brass", "amount": 2})
	assert_true(bool(stored["ok"]), "storing materials succeeds: %s" % str(stored))
	assert_eq(WarehouseOps.material_amount(context.state, port_id, "core:good/brass"), 2, "warehouse holds the materials")
	assert_eq(ShipOps.cargo_amount(context.state.ship(), "core:good/brass", false), 0, "cargo no longer holds the materials")
	var taken := context.commands.execute(&"warehouse.take_materials", {"item_id": "core:good/brass", "amount": 1})
	assert_true(bool(taken["ok"]), "taking materials succeeds: %s" % str(taken))
	assert_eq(WarehouseOps.material_amount(context.state, port_id, "core:good/brass"), 1, "warehouse amount decreases")
	assert_eq(ShipOps.cargo_amount(context.state.ship(), "core:good/brass", false), 1, "materials return to cargo")
	var too_many := context.commands.execute(&"warehouse.take_materials", {"item_id": "core:good/brass", "amount": 5})
	assert_false(bool(too_many["ok"]), "taking more than stored is rejected")
	assert_eq(String(too_many["error_code"]), "insufficient_materials", "insufficient_materials is reported")
	var over_cargo := context.commands.execute(&"warehouse.store_materials", {"item_id": "core:good/brass", "amount": 3})
	assert_false(bool(over_cargo["ok"]), "storing more than carried is rejected")
	assert_eq(String(over_cargo["error_code"]), "insufficient_cargo", "insufficient_cargo is reported")


func test_craft_consumes_warehouse_first_then_cargo_and_charges_cost() -> void:
	var context := _start(7104)
	var port_id := context.state.current_port_id()
	WarehouseOps.add_material(context.state, port_id, "core:good/brass", 2)
	WarehouseOps.add_material(context.state, port_id, "core:material/sealing_compound", 2)
	ShipOps.add_cargo(context.state.ship(), "core:good/brass", 1, "", 20.0)
	var time_before := context.state.now()
	var money_before := context.state.money()
	var expense_before := int(context.state.data["stats"].get("expense", 0))
	var result := context.commands.execute(&"ship.craft_module", {"module_id": "core:navigation_module/chart_room"})
	assert_true(bool(result["ok"]), "crafting chart room succeeds: %s" % str(result))
	# Crafting is now an order: pay and consume immediately, but do not advance
	# time and do not store the module until the order is ready.
	assert_almost_eq(context.state.now(), time_before, 0.001, "craft no longer advances time")
	assert_eq(context.state.money(), money_before - 140, "craft pays craft_cost")
	assert_eq(int(context.state.data["stats"].get("expense", 0)), expense_before + 140, "craft cost is recorded as an expense")
	assert_eq(WarehouseOps.material_amount(context.state, port_id, "core:good/brass"), 0, "warehouse brass is consumed first")
	assert_eq(WarehouseOps.material_amount(context.state, port_id, "core:material/sealing_compound"), 0, "warehouse sealing compound is consumed")
	assert_eq(ShipOps.cargo_amount(context.state.ship(), "core:good/brass", false), 0, "cargo covers the material remainder")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, "core:navigation_module/chart_room"), 0, "crafted module is not stored before the order is ready")
	assert_eq(CraftOps.orders(context.state).size(), 1, "craft queues one open order")
	assert_almost_eq(float(result["data"]["craft_time_hours"]), 5.0, 0.001, "result reports craft time")
	assert_eq(int(result["data"]["craft_cost"]), 140, "result reports craft cost")
	assert_eq(String(result["data"]["order_id"]), "order_1", "result reports the order id")
	assert_almost_eq(float(result["data"]["ready_at"]), time_before + 5.0, 0.001, "ready_at is now plus craft hours")
	assert_almost_eq(float(result["data"]["remaining_hours"]), 5.0, 0.001, "result reports hours remaining")
	var event_types := _event_types(result["events"])
	assert_contains(event_types, "ship.craft_ordered", "ordering emits ship.craft_ordered")
	assert_false(event_types.has("ship.module_crafted"), "ship.module_crafted is reserved for settlement")
	var consumed: Array = result["data"]["consumed"]
	assert_eq(String(consumed[0]["item_id"]), "core:good/brass", "first consumed row is brass")
	assert_eq(int(consumed[0]["from_warehouse"]), 2, "brass taken from warehouse")
	assert_eq(int(consumed[0]["from_cargo"]), 1, "brass remainder taken from cargo")
	# Waiting in port advances time and settles the order into the warehouse.
	var waited := context.commands.execute(&"port.wait", {"hours": 5})
	assert_true(bool(waited["ok"]), "port.wait succeeds: %s" % str(waited))
	assert_almost_eq(context.state.now(), time_before + 5.0, 0.001, "waiting advances game time")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, "core:navigation_module/chart_room"), 1, "waited order lands in the port warehouse")
	assert_empty(CraftOps.orders(context.state), "the finished order leaves the queue")
	assert_eq(Array(waited["data"]["completed_orders"]).size(), 1, "wait reports the completed order")
	assert_contains(_event_types(waited["events"]), "ship.module_crafted", "settlement emits ship.module_crafted")


func test_failed_craft_leaves_state_unchanged() -> void:
	var context := _start(7105)
	var before := context.state.hash()
	var result := context.commands.execute(&"ship.craft_module", {"module_id": "core:navigation_module/chart_room"})
	assert_false(bool(result["ok"]), "crafting without materials fails")
	assert_eq(String(result["error_code"]), "missing_materials", "missing_materials is reported")
	assert_contains(result["data"]["blockers"], "missing_materials", "failure data lists craft blockers")
	assert_eq(context.state.hash(), before, "failed craft leaves state unchanged")


func test_install_from_warehouse_is_free_and_replaces_old_module() -> void:
	var context := _start(7106)
	var hub: RegistryHub = context.registries
	var port_id := context.state.current_port_id()
	WarehouseOps.add_material(context.state, port_id, "core:good/brass", 3)
	WarehouseOps.add_material(context.state, port_id, "core:material/sealing_compound", 2)
	var crafted := context.commands.execute(&"ship.craft_module", {"module_id": "core:navigation_module/chart_room"})
	assert_true(bool(crafted["ok"]), "chart room crafts into the warehouse: %s" % str(crafted))
	# The order must be ready before it can be installed from the warehouse.
	var waited := context.commands.execute(&"port.wait", {"hours": 5})
	assert_true(bool(waited["ok"]), "waiting settles the order: %s" % str(waited))
	var money_before := context.state.money()
	var result := context.commands.execute(&"ship.install_module", {
		"module_id": "core:navigation_module/chart_room",
		"source": "warehouse",
	})
	assert_true(bool(result["ok"]), "installing from the warehouse succeeds: %s" % str(result))
	assert_eq(context.state.money(), money_before, "warehouse install is free")
	assert_eq(String(result["data"]["source"]), "warehouse", "result reports the warehouse source")
	assert_eq(int(result["data"]["price"]), 0, "warehouse install price is zero")
	assert_eq(String(context.state.ship()["navigation_module_id"]), "core:navigation_module/chart_room", "crafted module is installed")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, "core:navigation_module/chart_room"), 0, "installed module leaves the warehouse")
	assert_eq(String(result["data"]["replaced_module_id"]), "core:navigation_module/spyglass", "result reports the replaced module")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, "core:navigation_module/spyglass"), 1, "replaced module moves into the warehouse")


func test_uninstall_and_reinstall_from_transit() -> void:
	var context := _start(7107)
	var port_id := context.state.current_port_id()
	var uninstalled := context.commands.execute(&"ship.uninstall_module", {"module_id": "core:navigation_module/spyglass"})
	assert_true(bool(uninstalled["ok"]), "uninstalling a navigation module succeeds: %s" % str(uninstalled))
	assert_true(String(context.state.ship()["navigation_module_id"]).is_empty(), "navigation slot is empty")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, "core:navigation_module/spyglass"), 1, "uninstalled module is stored at the current port")
	var taken := context.commands.execute(&"warehouse.take_module", {"module_id": "core:navigation_module/spyglass", "qty": 1})
	assert_true(bool(taken["ok"]), "taking the module into transit succeeds: %s" % str(taken))
	assert_eq(WarehouseOps.transit_qty(context.state.ship(), "core:navigation_module/spyglass"), 1, "module is in transit")
	var money_before := context.state.money()
	var installed := context.commands.execute(&"ship.install_module", {
		"module_id": "core:navigation_module/spyglass",
		"source": "transit",
	})
	assert_true(bool(installed["ok"]), "installing from transit succeeds: %s" % str(installed))
	assert_eq(context.state.money(), money_before, "transit install is free")
	assert_eq(String(context.state.ship()["navigation_module_id"]), "core:navigation_module/spyglass", "module is installed again")
	assert_eq(WarehouseOps.transit_qty(context.state.ship(), "core:navigation_module/spyglass"), 0, "transit bag is emptied")


func test_uninstall_rejects_hull_and_boiler() -> void:
	var context := _start(7108)
	var before := context.state.hash()
	var hull := context.commands.execute(&"ship.uninstall_module", {"module_id": "core:hull/small_efficient"})
	assert_false(bool(hull["ok"]), "hull cannot be uninstalled")
	assert_eq(String(hull["error_code"]), "required_module", "hull reports required_module")
	var boiler := context.commands.execute(&"ship.uninstall_module", {"module_id": "core:boiler/small_efficient"})
	assert_false(bool(boiler["ok"]), "boiler cannot be uninstalled")
	assert_eq(String(boiler["error_code"]), "required_module", "boiler reports required_module")
	assert_eq(context.state.hash(), before, "rejected uninstalls leave state unchanged")


func test_replacement_moves_old_hull_into_warehouse() -> void:
	var context := _start(7109, 6000)
	var port_id := context.state.current_port_id()
	context.state.player()["unlocks"] = MEDIUM_UNLOCKS.duplicate()
	var result := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/medium_standard"})
	assert_true(bool(result["ok"]), "medium hull installs after unlock: %s" % str(result))
	assert_eq(String(context.state.ship()["hull_id"]), "core:hull/medium_standard", "new hull is installed")
	assert_almost_eq(float(context.state.ship()["durability"]), 140.0, 0.001, "purchased hull starts at full durability")
	assert_eq(String(result["data"]["replaced_module_id"]), "core:hull/small_efficient", "result reports the replaced hull")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, "core:hull/small_efficient"), 1, "old hull is stored at the current port")
	assert_eq(int(result["data"]["price"]), 1100, "purchase price is reported")
	assert_eq(context.state.money(), 4900, "purchase price is deducted")


func test_duplicate_cargo_module_allowed_while_slots_free() -> void:
	var context := _start(7113, 6000)
	context.state.player()["unlocks"] = MEDIUM_UNLOCKS.duplicate()
	var hull := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/medium_standard"})
	assert_true(bool(hull["ok"]), "medium hull installs: %s" % str(hull))
	assert_eq(ShipOps.cargo_module_ids(context.state.ship()).size(), 1, "one cargo module is installed on the new hull")
	var duplicate := context.commands.execute(&"ship.install_module", {"module_id": "core:cargo_module/small_hold"})
	assert_true(bool(duplicate["ok"]), "a duplicate cargo module installs into a free slot: %s" % str(duplicate))
	assert_eq(ShipOps.cargo_module_ids(context.state.ship()).size(), 2, "two cargo modules are installed")
	assert_eq(ShipOps.cargo_module_ids(context.state.ship()).count("core:cargo_module/small_hold"), 2, "duplicate IDs are kept as separate copies")
	var third := context.commands.execute(&"ship.install_module", {"module_id": "core:cargo_module/small_hold"})
	assert_false(bool(third["ok"]), "a duplicate cargo module is blocked once slots are full")
	assert_eq(String(third["error_code"]), "already_installed", "already_installed is the primary reason when full")
	assert_contains(third["data"]["blockers"], "cargo_slots_full", "cargo_slots_full is also reported")


func test_contract_lock_blocks_hulls_and_crafts_until_unlock() -> void:
	var context := _start(7110, 20000)
	var hub: RegistryHub = context.registries
	var port_id := context.state.current_port_id()
	assert_eq(ShipOps.unlock_contract_id(hub, "core:hull/medium_standard"), "core:contract/main_03", "medium hull is gated by main_03")
	assert_eq(ShipOps.unlock_contract_id(hub, "core:hull/large_efficient"), "core:contract/main_05", "large hull is gated by main_05")
	var medium := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/medium_standard"})
	assert_false(bool(medium["ok"]), "medium hull is contract-locked at run start")
	assert_eq(String(medium["error_code"]), "locked_by_contract", "locked_by_contract is reported for hulls")
	var large := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/large_efficient"})
	assert_false(bool(large["ok"]), "large hull is contract-locked at run start")
	assert_eq(String(large["error_code"]), "locked_by_contract", "locked_by_contract is reported for large hulls")
	WarehouseOps.add_material(context.state, port_id, "core:good/timber", 6)
	WarehouseOps.add_material(context.state, port_id, "core:material/boiler_plate", 2)
	var craft_locked := context.commands.execute(&"ship.craft_module", {"module_id": "core:cargo_module/medium_hold"})
	assert_false(bool(craft_locked["ok"]), "crafting a contract-locked module is rejected")
	assert_eq(String(craft_locked["error_code"]), "locked_by_contract", "craft reports locked_by_contract")
	context.state.player()["unlocks"] = MEDIUM_UNLOCKS.duplicate()
	var medium_unlocked := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/medium_standard"})
	assert_true(bool(medium_unlocked["ok"]), "medium hull installs once its contract unlock is owned: %s" % str(medium_unlocked))
	var large_still_locked := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/large_efficient"})
	assert_false(bool(large_still_locked["ok"]), "large hull stays locked until main_05 unlock")
	assert_eq(String(large_still_locked["error_code"]), "locked_by_contract", "large hull remains contract-gated")


func test_take_module_respects_weight_limit() -> void:
	var context := _start(7111)
	var port_id := context.state.current_port_id()
	WarehouseOps.add_module(context.state, port_id, "core:cargo_module/large_hold", 1)
	var before := context.state.hash()
	var taken := context.commands.execute(&"warehouse.take_module", {"module_id": "core:cargo_module/large_hold", "qty": 1})
	assert_false(bool(taken["ok"]), "taking a module that breaks the weight limit is rejected")
	assert_eq(String(taken["error_code"]), "weight_limit", "weight_limit is reported")
	assert_eq(context.state.hash(), before, "rejected take leaves state unchanged")


func test_failed_install_leaves_state_unchanged() -> void:
	var context := _start(7112, 0)
	context.state.player()["unlocks"] = MEDIUM_UNLOCKS.duplicate()
	var before := context.state.hash()
	var result := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/medium_standard"})
	assert_false(bool(result["ok"]), "install without money fails")
	assert_eq(String(result["error_code"]), "insufficient_money", "insufficient_money is reported")
	assert_eq(context.state.hash(), before, "failed install leaves state unchanged")
