extends TestCase
## Craft orders (feedback 4) and port.wait: tier-1 money-only recipes, order
## settlement while waiting in port and across a voyage, validation errors and
## old-save backfill. See docs/specs/ITERATION_1_MVP_LOOP.md §3.2, §4 and §9.

const BUILD := "core:starting_build/steady"
const STRATEGY := "core:strategy/standard"
const CONTRACT_FREIGHT := "core:good/contract_freight"
const TIER1_MODULES := [
	"core:hull/small_efficient",
	"core:boiler/small_efficient",
	"core:boiler/standard",
	"core:cabin/passenger_cabin",
	"core:cargo_module/small_hold",
	"core:navigation_module/spyglass",
	"core:safety_module/lifeboat",
]
const SMALL_HOLD := "core:cargo_module/small_hold"
const SPYGLASS := "core:navigation_module/spyglass"
const CHART_ROOM := "core:navigation_module/chart_room"


## Boots Core, starts a run, sets a predictable wallet and releases the starter
## main contract cargo so weight/capacity never surprise these tests.
func _start(seed_value: int, money: int = 5000) -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"build_id": BUILD, "seed": seed_value})
	assert_true(bool(started.get("ok", false)), "run starts (seed %d): %s" % [seed_value, str(started)])
	context.state.set_money(money)
	var contracts: Dictionary = context.state.contracts()
	contracts["main"] = null
	contracts["main_offer"] = null
	var ship := context.state.ship()
	var carried := ShipOps.cargo_amount(ship, CONTRACT_FREIGHT, true)
	if carried > 0:
		ShipOps.remove_cargo(ship, CONTRACT_FREIGHT, carried, true)
	WarehouseOps.ensure_structure(context.state)
	return context


func _event_types(events: Array) -> Array:
	var types: Array = []
	for event in events:
		if event is Dictionary:
			types.append(String(event.get("type", "")))
	return types


func _craft_row(view: Dictionary, module_id: String) -> Dictionary:
	for row in view.get("craft", []):
		if row is Dictionary and String(row.get("module_id", "")) == module_id:
			return row
	return {}


func test_tier1_recipes_are_money_only() -> void:
	var boot := bootstrap_core()
	var hub: RegistryHub = boot["context"].registries
	for module_id in TIER1_MODULES:
		assert_empty(CraftOps.materials_required(hub, module_id), "%s needs no materials" % module_id)
		assert_true(CraftOps.craftable(hub, module_id), "%s is craftable without materials" % module_id)
		assert_true(CraftOps.money_only(hub, module_id), "%s is a money-only recipe" % module_id)
	assert_false(CraftOps.money_only(hub, CHART_ROOM), "the tier-2 chart room still consumes materials")
	assert_true(CraftOps.craftable(hub, CHART_ROOM), "the tier-2 chart room stays craftable")
	assert_false(CraftOps.craftable(hub, ""), "an unknown module is not craftable")
	assert_false(CraftOps.money_only(hub, ""), "an unknown module is not money only")
	var context := _start(7300)
	var blockers := CraftOps.craft_blockers(context.registries, context.state, SPYGLASS)
	assert_false(blockers.has("not_craftable"), "a money-only recipe is never not_craftable")
	assert_false(blockers.has("missing_materials"), "a money-only recipe never misses materials")
	assert_empty(blockers, "a money-only recipe has no blockers with enough gold")


func test_money_only_craft_queues_order_and_wait_settles_it() -> void:
	var context := _start(7301)
	var port_id := context.state.current_port_id()
	var time_before := context.state.now()
	var money_before := context.state.money()
	var expense_before := int(context.state.data["stats"].get("expense", 0))
	var result := context.commands.execute(&"ship.craft_module", {"module_id": SMALL_HOLD})
	assert_true(bool(result["ok"]), "money-only craft succeeds without materials: %s" % str(result))
	assert_almost_eq(context.state.now(), time_before, 0.001, "craft does not advance time")
	assert_eq(context.state.money(), money_before - 120, "money-only craft charges craft_cost")
	assert_eq(int(context.state.data["stats"].get("expense", 0)), expense_before + 120, "craft cost is recorded as an expense")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, SMALL_HOLD), 0, "the module is not stored yet")
	assert_eq(CraftOps.orders(context.state).size(), 1, "an order is queued")
	assert_contains(_event_types(result["events"]), "ship.craft_ordered", "ship.craft_ordered is emitted")

	var view := context.queries.execute(&"shipyard.view")
	var data: Dictionary = view["data"]
	assert_eq(Array(data["orders"]).size(), 1, "the view lists the open order")
	var order: Dictionary = data["orders"][0]
	assert_eq(String(order["order_id"]), "order_1", "the order id is exposed")
	assert_eq(String(order["module_id"]), SMALL_HOLD, "the order module id is exposed")
	assert_true(bool(order["at_current_port"]), "the order belongs to the current port")
	assert_almost_eq(float(order["remaining_hours"]), 3.0, 0.001, "remaining hours start at the craft time")
	assert_true(not String(order["name_key"]).is_empty(), "the order carries a module name key")
	assert_true(not String(order["port_name_key"]).is_empty(), "the order carries a port name key")
	var recipe := _craft_row(data, SMALL_HOLD)
	assert_true(bool(recipe["money_only"]), "the craft row marks the recipe money only")
	assert_empty(recipe["materials"], "the craft row keeps an empty materials plan")
	assert_true(bool(recipe["can_craft"]), "a money-only recipe can be crafted")

	var waited := context.commands.execute(&"port.wait", {"hours": 3})
	assert_true(bool(waited["ok"]), "port.wait succeeds: %s" % str(waited))
	assert_almost_eq(context.state.now(), time_before + 3.0, 0.001, "waiting advances game time")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, SMALL_HOLD), 1, "the module lands in the warehouse after the wait")
	assert_empty(CraftOps.orders(context.state), "the finished order leaves the queue")
	assert_eq(Array(waited["data"]["completed_orders"]).size(), 1, "the wait reports the completed order")
	assert_almost_eq(float(waited["data"]["game_time"]), time_before + 3.0, 0.001, "the wait reports the new game time")
	assert_true(not String(waited["data"]["time_label"]).is_empty(), "the wait reports a formatted time label")
	assert_contains(_event_types(waited["events"]), "port.waited", "port.waited is emitted")
	assert_contains(_event_types(waited["events"]), "ship.module_crafted", "settlement emits ship.module_crafted")
	var after := context.queries.execute(&"shipyard.view")
	assert_empty(Array(after["data"]["orders"]), "the view no longer lists a finished order")


func test_money_only_craft_without_gold_reports_insufficient_money() -> void:
	var context := _start(7302, 0)
	var before := context.state.hash()
	var result := context.commands.execute(&"ship.craft_module", {"module_id": SPYGLASS})
	assert_false(bool(result["ok"]), "crafting without gold fails")
	assert_eq(String(result["error_code"]), "insufficient_money", "insufficient_money is reported")
	assert_false(Array(result["data"]["blockers"]).has("missing_materials"), "a money-only recipe never reports missing_materials")
	assert_eq(context.state.hash(), before, "a failed craft leaves state unchanged")


func test_order_is_delivered_after_a_voyage() -> void:
	var context := _start(7303)
	var origin := context.state.current_port_id()
	var crafted := context.commands.execute(&"ship.craft_module", {"module_id": SPYGLASS})
	assert_true(bool(crafted["ok"]), "spyglass order is placed: %s" % str(crafted))
	var ready_at := float(crafted["data"]["ready_at"])
	var destination := _neighbor_with_longest_voyage(context, origin)
	assert_true(not destination.is_empty(), "the origin port has a route out")
	if destination.is_empty():
		return
	var duration := _preview_duration(context, destination)
	assert_true(duration > ready_at - context.state.now(), "the voyage outlasts the order (%.1fh)" % duration)
	_sail(context, destination)
	assert_ne(context.state.current_port_id(), origin, "the ship left the origin port")
	assert_true(context.state.now() >= ready_at, "arrival happens after the order was due")
	assert_eq(WarehouseOps.module_qty(context.state, origin, SPYGLASS), 1, "the order is delivered to the port that accepted it")
	assert_empty(CraftOps.orders(context.state), "the order queue is empty after arrival")


func test_port_wait_rejects_invalid_hours_and_wrong_state() -> void:
	var context := _start(7304)
	assert_true(context.commands.has(&"port.wait"), "port.wait is registered")
	var before := context.state.hash()
	for hours in [0, -5, 241, 1000]:
		var rejected := context.commands.execute(&"port.wait", {"hours": hours})
		assert_false(bool(rejected["ok"]), "hours %d is rejected" % hours)
		assert_eq(String(rejected["error_code"]), "invalid_hours", "invalid_hours is reported for %d" % hours)
	assert_eq(context.state.hash(), before, "rejected waits leave state unchanged")
	context.state.data["voyage"] = {"destination": "", "status": "at_sea"}
	var at_sea := context.commands.execute(&"port.wait", {"hours": 6})
	assert_false(bool(at_sea["ok"]), "waiting while at sea is rejected")
	assert_eq(String(at_sea["error_code"]), "not_at_port", "not_at_port is reported")
	context.state.data.erase("voyage")
	assert_eq(context.state.hash(), before, "no rejected wait changed state")


func test_old_save_without_order_fields_is_backfilled() -> void:
	var context := _start(7305)
	context.state.data.erase("shipyard_orders")
	context.state.data.erase("order_serial")
	CraftOps.ensure_orders(context.state)
	assert_true(context.state.data["shipyard_orders"] is Array, "the order list is created")
	assert_true(context.state.data.has("order_serial"), "the serial field is backfilled on an old save")
	assert_eq(int(context.state.data.get("order_serial", -1)), 0, "the serial starts at zero")
	var view := context.queries.execute(&"shipyard.view")
	assert_true(bool(view["ok"]), "the shipyard view works on a backfilled save")
	assert_true(view["data"].has("orders"), "orders are exposed on a backfilled save")
	var crafted := context.commands.execute(&"ship.craft_module", {"module_id": SMALL_HOLD})
	assert_true(bool(crafted["ok"]), "crafting works after a backfill: %s" % str(crafted))
	assert_eq(String(crafted["data"]["order_id"]), "order_1", "order ids restart from the backfilled serial")
	# A JSON-loaded float serial is normalized back to an int.
	context.state.data["order_serial"] = 7.0
	CraftOps.ensure_orders(context.state)
	assert_eq(typeof(context.state.data["order_serial"]), TYPE_INT, "a float serial becomes an int")
	assert_eq(int(context.state.data["order_serial"]), 7, "the serial keeps its value")
	var next := context.commands.execute(&"ship.craft_module", {"module_id": SPYGLASS})
	assert_eq(String(next["data"]["order_id"]), "order_8", "the next order continues the serial")


func test_order_state_survives_save_and_load() -> void:
	var context := _start(7306)
	context.commands.execute(&"ship.craft_module", {"module_id": SMALL_HOLD})
	var before := context.state.hash()
	var saved := context.save.save_slot("manual", context.state, context.save_meta())
	assert_true(bool(saved["ok"]), "saving a state with an open order succeeds: %s" % str(saved))
	var loaded: Dictionary = context.save.load_slot("manual")
	assert_true(bool(loaded["ok"]), "loading a state with an open order succeeds")
	var loaded_state: GameState = loaded["state"]
	assert_eq(loaded_state.hash(), before, "the order state hash survives save/load")
	assert_eq(CraftOps.orders(loaded_state).size(), 1, "the open order is restored")
	# The restored (JSON float) serial and ready_at still settle correctly.
	context.set_state(loaded_state)
	var waited := context.commands.execute(&"port.wait", {"hours": 12})
	assert_true(bool(waited["ok"]), "waiting after a reload succeeds: %s" % str(waited))
	assert_eq(WarehouseOps.module_qty(loaded_state, loaded_state.current_port_id(), SMALL_HOLD), 1, "the restored order settles")


func test_wait_outcome_is_reproducible_for_the_same_seed() -> void:
	var first := _start(7307)
	var second := _start(7307)
	for context in [first, second]:
		context.commands.execute(&"ship.craft_module", {"module_id": SMALL_HOLD})
		var waited: Dictionary = context.commands.execute(&"port.wait", {"hours": 12})
		assert_true(bool(waited["ok"]), "the scripted wait succeeds")
	assert_eq(
		JsonUtils.canonical_stringify(first.state.market()),
		JsonUtils.canonical_stringify(second.state.market()),
		"NPC market movement is reproducible for the same seed"
	)
	assert_eq(
		JsonUtils.canonical_stringify(Array(first.state.data.get("npcs", []))),
		JsonUtils.canonical_stringify(Array(second.state.data.get("npcs", []))),
		"NPC routes are reproducible for the same seed"
	)
	assert_eq(first.state.money(), second.state.money(), "spending is identical")
	assert_almost_eq(first.state.now(), second.state.now(), 0.001, "the game clock is identical")
	assert_eq(WarehouseOps.module_qty(first.state, first.state.current_port_id(), SMALL_HOLD), 1, "the order settles in the first run")
	assert_eq(WarehouseOps.module_qty(second.state, second.state.current_port_id(), SMALL_HOLD), 1, "the order settles in the second run")


## ---------------------------------------------------------------------------
## Voyage helpers (mirroring the scripted full-clear pattern)
## ---------------------------------------------------------------------------

func _neighbor_with_longest_voyage(context: AppContext, origin: String) -> String:
	var best := ""
	var best_duration := -1.0
	for neighbor in MapOps.neighbors(context.state.world(), origin):
		var duration := _preview_duration(context, String(neighbor))
		if duration > best_duration:
			best_duration = duration
			best = String(neighbor)
	return best


func _preview_duration(context: AppContext, destination: String) -> float:
	var preview := context.queries.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STRATEGY,
	})
	if not bool(preview.get("ok", false)):
		return 0.0
	return float(preview["data"].get("duration_hours", 0.0))


func _sail(context: AppContext, destination: String) -> void:
	_prepare_supplies(context, destination)
	var voyage: Dictionary = context.commands.execute(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": STRATEGY,
	})
	assert_true(bool(voyage.get("ok", false)), "voyage to %s starts: %s" % [destination, str(voyage)])
	if not bool(voyage.get("ok", false)):
		return
	if not bool(voyage["data"].get("arrived", false)):
		_resolve_event(context)
	assert_eq(context.state.current_port_id(), destination, "arrived at %s" % destination)


func _prepare_supplies(context: AppContext, destination: String) -> void:
	var preview: Dictionary = context.queries.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STRATEGY,
	})
	if not bool(preview.get("ok", false)):
		return
	_buy_supply(context, "coal", float(preview["data"].get("coal_required", 0.0)) + 4.0)
	_buy_supply(context, "water", float(preview["data"].get("water_required", 0.0)) + 4.0)


func _buy_supply(context: AppContext, kind: String, wanted: float) -> void:
	var current := float(context.state.ship().get(kind, 0.0))
	if current >= wanted:
		return
	var amount := int(ceil(wanted - current))
	var command := &"supply.buy_coal" if kind == "coal" else &"supply.buy_water"
	var result: Dictionary = context.commands.execute(command, {"amount": amount})
	if not bool(result.get("ok", false)) and context.state.money() > 0:
		# Supplies can be scarce; a smaller top-up is still better than none.
		context.commands.execute(command, {"amount": 1})


func _resolve_event(context: AppContext) -> void:
	var voyage: Variant = context.state.data.get("voyage", null)
	assert_true(voyage is Dictionary, "a pending event exists")
	if not (voyage is Dictionary):
		return
	var event: Variant = voyage.get("event", null)
	assert_true(event is Dictionary, "the voyage exposes the triggered event")
	if not (event is Dictionary):
		return
	var offered: Array = event.get("option_ids", [])
	var preferred := ["stop_repair", "decline", "water_cooling", "force_continue", "jettison_cargo", "paid_repair", "buy_intel"]
	var order: Array = []
	for option_id in preferred:
		if offered.has(option_id):
			order.append(option_id)
	for option_id in offered:
		if not order.has(option_id):
			order.append(option_id)
	for option_id in order:
		var chosen: Dictionary = context.commands.execute(&"event.choose_option", {"option_id": String(option_id)})
		if bool(chosen.get("ok", false)) and not bool(chosen["data"].get("failed", false)):
			return
	fail("no event option resolved the voyage event: %s" % str(offered))