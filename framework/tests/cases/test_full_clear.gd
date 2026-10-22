extends TestCase
## End-to-end MVP clear: five main contracts -> unlock large hull -> assemble
## the minimum viable large ship at a shipyard -> victory.
##
## This is a deterministic, player-like scripted run. It only uses the public
## CommandBus/QueryBus surface, so it also guards the playable loop the UI uses.
## Bot efficiency is intentionally modest: the MVP target is 9-12 voyages for a
## human, the bot is allowed a few extra normal contracts as a money buffer.

const BUILD := "core:starting_scenario/steady"
const STRATEGY := "core:strategy/standard"
const MEDIUM_HULL := "core:hull/medium_standard"
const LARGE_HULL := "core:hull/large_efficient"
const CABIN := "core:module/passenger_cabin"
const VOYAGE_LIMIT := 16
const LIQUIDITY_FLOOR := 700


func test_full_clear_seed_4242() -> void:
	var context := _play_full_clear(4242)
	if context == null:
		return
	_assert_victory(context, true)


## A second pass over a few seeds keeps the loop from depending on one lucky map.
func test_full_clear_multiple_seeds() -> void:
	for seed in [111, 222, 333, 444, 555, 666, 777, 888]:
		var context := _play_full_clear(seed)
		if context == null:
			continue
		_assert_victory(context, false)


func _play_full_clear(seed: int) -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started: Dictionary = context.commands.execute(&"run.start", {"starting_scenario": BUILD, "seed": seed})
	assert_true(bool(started.get("ok", false)), "seed %d: run starts: %s" % [seed, str(started)])
	if not bool(started.get("ok", false)):
		return null
	assert_true(context.has_run(), "seed %d: run has state" % seed)

	# Chapter 1-3: main chain only. Main offers are generated one hop from the
	# port where the previous chapter completed, so each is a short trip.
	for sequence in [1, 2, 3]:
		_complete_main_step(context, sequence)

	var unlocks: Array = context.state.player().get("unlocks", [])
	assert_contains(unlocks, MEDIUM_HULL, "seed %d: main 3 unlocks the medium hull" % seed)
	assert_contains(unlocks, "core:module/medium_hold", "seed %d: main 3 unlocks the medium cargo hold" % seed)

	# Mid-game build: passengers need a cabin slot, which only the medium hull has.
	# Keep a cash buffer so the chapter-4/5 detours can always pay wages and supplies.
	_navigate_to_facility(context, "shipyard")
	_earn_until(context, 2150)
	_install(context, MEDIUM_HULL, "seed %d: medium hull" % seed)
	_ensure_liquidity(context, 500)
	_install(context, CABIN, "seed %d: passenger cabin" % seed)

	# Chapter 4-5 require the mid-game build. The main contract stays active
	# while the bot detours to the shipyard, so acceptance happens first when
	# the offer exists; _complete_main_step accepts it before navigating.
	for sequence in [4, 5]:
		_complete_main_step(context, sequence)

	assert_true(VictoryService.main_chain_complete(context.registries, context.state), "seed %d: all main chapters are complete" % seed)

	# Final build: large hull + existing boiler + existing cargo hold at a
	# shipyard is the minimum viable configuration from the GDD.
	_navigate_to_facility(context, "shipyard")
	# Purchase price plus a travel/supply buffer: earning exactly 2600 leaves the
	# bot short after paying for the final trip to the shipyard.
	_earn_until(context, 3000)
	_navigate_to_facility(context, "shipyard")
	var large: Dictionary = context.commands.execute(&"ship.install_module", {"module_id": LARGE_HULL})
	assert_true(bool(large.get("ok", false)), "seed %d: large hull installs: %s" % [seed, str(large)])
	return context


func _assert_victory(context: AppContext, detailed: bool) -> void:
	var seed := context.state.seed()
	var victory: Variant = context.state.data.get("victory", null)
	assert_true(victory is Dictionary, "seed %d: victory state is written" % seed)
	if not (victory is Dictionary):
		return
	assert_true(bool(victory.get("achieved", false)), "seed %d: run is marked cleared" % seed)
	var summary: Dictionary = victory.get("summary", {})
	if detailed:
		for field in [
			"seed", "starting_scenario", "game_time", "voyages", "on_time",
			"on_time_rate", "accidents", "income", "expense", "profit",
			"money", "debt_remaining", "durability", "max_durability",
			"hull_id", "hull_name_key", "modules",
		]:
			assert_true(summary.has(field), "seed %d: victory summary exposes %s" % [seed, field])
	assert_eq(String(summary.get("hull_id", "")), LARGE_HULL, "seed %d: summary records the large hull" % seed)
	assert_true(int(summary.get("voyages", 99)) <= VOYAGE_LIMIT, "seed %d: clear finishes within the voyage budget (%s)" % [seed, str(summary.get("voyages", 99))])

	var victory_view: Dictionary = context.queries.execute(&"victory.view")
	assert_true(bool(victory_view.get("ok", false)), "seed %d: victory view succeeds" % seed)
	assert_true(bool(victory_view["data"].get("achieved", false)), "seed %d: victory view reports the clear" % seed)


## ---------------------------------------------------------------------------
## Main chain helpers
## ---------------------------------------------------------------------------

func _complete_main_step(context: AppContext, expected_sequence: int) -> void:
	_accept_main_offer_if_needed(context)
	var contracts: Dictionary = context.state.contracts()
	var main: Variant = contracts.get("main", null)
	assert_true(main is Dictionary, "main %d is active" % expected_sequence)
	if not (main is Dictionary):
		return
	assert_eq(int(main.get("sequence", 0)), expected_sequence, "main sequence is %d" % expected_sequence)
	var destination := String(main.get("destination", ""))
	# The main offer was generated at the port where the previous chapter ended.
	# Accepting it from another port can leave the ship already standing at the
	# contract destination, and contracts only settle on an arrival. Take a short
	# round trip so the run still behaves like a real arrival.
	if context.state.current_port_id() == destination:
		var neighbors := MapOps.neighbors(context.state.world(), destination)
		assert_false(neighbors.is_empty(), "destination port has a route out")
		if not neighbors.is_empty():
			_sail(context, neighbors[0])
	_navigate_to(context, destination)
	assert_eq(context.state.contracts().get("main", null), null, "main %d settles on arrival" % expected_sequence)
	var completed: Array = context.state.contracts().get("completed", [])
	assert_true(completed.size() >= expected_sequence, "main %d is recorded as completed" % expected_sequence)


func _accept_main_offer_if_needed(context: AppContext) -> void:
	var contracts: Dictionary = context.state.contracts()
	if contracts.get("main", null) is Dictionary:
		return
	var offer: Variant = contracts.get("main_offer", null)
	assert_true(offer is Dictionary, "a main offer is available")
	if not (offer is Dictionary):
		return
	var accept: Dictionary = context.commands.execute(&"contract.accept", {"instance_id": String(offer.get("instance_id", ""))})
	assert_true(bool(accept.get("ok", false)), "main offer accepts: %s" % str(accept))


## ---------------------------------------------------------------------------
## Normal contract money buffer
## ---------------------------------------------------------------------------

func _earn_until(context: AppContext, target_money: int) -> void:
	var guard := 0
	while context.state.money() < target_money and guard < 8:
		guard += 1
		_ensure_liquidity(context, target_money)
		if context.state.money() >= target_money:
			return
		if not _complete_one_normal_contract(context):
			# Fall back to the loan when normal offers cannot be completed.
			_ensure_liquidity(context, target_money)
			if context.state.money() >= target_money:
				return
	assert_true(context.state.money() >= target_money, "money buffer reaches %d (have %d)" % [target_money, context.state.money()])


func _ensure_liquidity(context: AppContext, floor: int = LIQUIDITY_FLOOR) -> void:
	if context.state.money() >= floor:
		return
	if context.state.player().get("debt", null) == null:
		var borrow: Dictionary = context.commands.execute(&"debt.borrow", {"amount": 400})
		assert_true(bool(borrow.get("ok", false)), "loan covers the liquidity gap: %s" % str(borrow))
		return
	_complete_one_normal_contract(context)


func _complete_one_normal_contract(context: AppContext) -> bool:
	var contracts: Dictionary = context.state.contracts()
	var offers: Array = contracts.get("offers", [])
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var accept: Dictionary = context.commands.execute(&"contract.accept", {"instance_id": String(offer.get("instance_id", ""))})
		if not bool(accept.get("ok", false)):
			continue
		var destination := String(offer.get("destination", ""))
		_navigate_to(context, destination)
		return true
	return false


## ---------------------------------------------------------------------------
## Navigation helpers
## ---------------------------------------------------------------------------

func _navigate_to_facility(context: AppContext, facility: String) -> void:
	var state: GameState = context.state
	if MapOps.has_facility(MapOps.port(state.world(), state.current_port_id()), facility):
		return
	for port_id in state.world().get("ports", {}).keys():
		if MapOps.has_facility(MapOps.port(state.world(), String(port_id)), facility):
			_navigate_to(context, String(port_id))
			return
	fail("map has no port with facility %s" % facility)


func _navigate_to(context: AppContext, target_port: String) -> void:
	var guard := 0
	while context.state.current_port_id() != target_port and guard < 8:
		guard += 1
		var path := _path_to(context.state.world(), context.state.current_port_id(), target_port)
		assert_true(path.size() >= 2, "route to %s exists" % target_port)
		if path.size() < 2:
			return
		var next_port := path[1]
		_sail(context, next_port)


func _path_to(world: Dictionary, from_port: String, to_port: String) -> Array[String]:
	var result: Array[String] = []
	if from_port == to_port:
		result.append(from_port)
		return result
	var previous := {from_port: ""}
	var queue: Array[String] = [from_port]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for neighbor in MapOps.neighbors(world, current):
			if previous.has(neighbor):
				continue
			previous[neighbor] = current
			if neighbor == to_port:
				var cursor := to_port
				var reversed: Array[String] = []
				while cursor != from_port:
					reversed.append(cursor)
					cursor = String(previous[cursor])
				reversed.append(from_port)
				reversed.reverse()
				result.assign(reversed)
				return result
			queue.append(neighbor)
	return result


func _sail(context: AppContext, destination: String) -> void:
	# Wages are charged at departure; keep the loan as the last soft-lock guard.
	if context.state.money() < 250 and context.state.player().get("debt", null) == null:
		context.commands.execute(&"debt.borrow", {"amount": 400})
	_prepare_voyage(context, destination)
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


func _resolve_event(context: AppContext) -> void:
	var voyage: Variant = context.state.data.get("voyage", null)
	assert_true(voyage is Dictionary, "pending event exists")
	if not (voyage is Dictionary):
		return
	var event: Variant = voyage.get("event", null)
	assert_true(event is Dictionary, "voyage exposes the triggered event")
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


func _prepare_voyage(context: AppContext, destination: String) -> void:
	var preview: Dictionary = context.queries.execute(&"voyage.preview", {
		"destination_id": destination,
		"strategy_id": STRATEGY,
	})
	assert_true(bool(preview.get("ok", false)), "voyage preview for %s succeeds: %s" % [destination, str(preview)])
	if not bool(preview.get("ok", false)):
		return
	var p: Dictionary = preview["data"]
	_buy_supply(context, "coal", float(p.get("coal_required", 0.0)) + 4.0)
	_buy_supply(context, "water", float(p.get("water_required", 0.0)) + 4.0)
	# A damaged ship cannot finish the run; repair when it is cheap enough.
	if float(context.state.ship().get("durability", 0.0)) < float(context.state.ship().get("max_durability", 1.0)) * 0.35:
		context.commands.execute(&"supply.repair", {})


func _buy_supply(context: AppContext, kind: String, wanted: float) -> void:
	var current := float(context.state.ship().get(kind, 0.0))
	if current >= wanted:
		return
	var amount := int(ceil(wanted - current))
	var command := &"supply.buy_coal" if kind == "coal" else &"supply.buy_water"
	var result: Dictionary = context.commands.execute(command, {"amount": amount})
	if not bool(result.get("ok", false)):
		# Try a smaller purchase when money is tight; feasibility assertions below
		# will surface a real supply shortfall.
		var affordable := int(floor(float(context.state.money()) / maxf(1.0, float(context.state.market().get(
			context.state.current_port_id(), {}).get("core:item/%s" % kind, {}).get("price", 4.0)))))
		if affordable > 0:
			context.commands.execute(command, {"amount": mini(affordable, amount)})


func _install(context: AppContext, module_id: String, label: String) -> void:
	var result: Dictionary = context.commands.execute(&"ship.install_module", {"module_id": module_id})
	assert_true(bool(result.get("ok", false)), "%s installs: %s" % [label, str(result)])
