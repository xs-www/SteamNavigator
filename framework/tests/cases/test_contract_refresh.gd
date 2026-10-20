extends TestCase
## Normal contract pool refresh and holding limit.
## Owned by loop-systems; see docs/specs/ITERATION_1_MVP_LOOP.md §3.5 / §5.2 / §8.

const STEADY_BUILD := "core:starting_build/steady"
const STANDARD_STRATEGY := "core:strategy/standard"


func _offer_ids(offers: Array) -> Array:
	var ids: Array = []
	for offer in offers:
		if offer is Dictionary:
			ids.append(String(offer.get("instance_id", "")))
	return ids


func _offer_signature(offers: Array) -> Array:
	var rows: Array = []
	for offer in offers:
		if not (offer is Dictionary):
			continue
		rows.append("%s|%s|%s" % [
			String(offer.get("template_id", "")),
			String(offer.get("instance_id", "")),
			String(offer.get("destination", "")),
		])
	return rows


func _cargo_offer(offers: Array) -> Dictionary:
	for offer in offers:
		if offer is Dictionary and int(offer.get("passengers", 0)) == 0:
			return offer
	return {}


func _main_destination(context: AppContext) -> String:
	var main_contract: Variant = context.state.contracts().get("main", null)
	return String(main_contract.get("destination", "")) if main_contract is Dictionary else ""


func _has_event(events: Array, type: String) -> bool:
	for event in events:
		if event is Dictionary and String(event.get("type", "")) == type:
			return true
	return false


## Starts the first voyage and resolves a pending risk event. Returns the command
## result of the last successful step.
func _travel(context: AppContext, destination: String) -> Dictionary:
	var voyage := context.commands.execute(&"voyage.start", {
		"destination_id": destination,
		"strategy_id": STANDARD_STRATEGY,
	})
	if not bool(voyage["ok"]) or bool(voyage["data"].get("arrived", true)):
		return voyage
	var option_ids: Array = voyage["data"]["event"]["option_ids"]
	var last_choice: Dictionary = {}
	for option_id in option_ids:
		var choice := context.commands.execute(&"event.choose_option", {"option_id": String(option_id)})
		last_choice = choice
		if bool(choice["ok"]) and not bool(choice["data"].get("failed", false)):
			return choice
	return last_choice


func test_initial_offers_and_port_view_limit_fields() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": 12345})
	assert_true(bool(start["ok"]), "run starts: %s" % str(start))
	var view := context.queries.execute(&"port.view")
	assert_true(bool(view["ok"]), "port view succeeds")
	var data: Dictionary = view["data"]
	var contracts: Dictionary = data["contracts"]
	var initial_ids := _offer_ids(contracts["offers"])
	assert_eq(initial_ids.size(), 3, "run starts with three normal offers")
	assert_eq(int(contracts["active_limit"]), 1, "zero reputation holds one normal contract")
	assert_eq(int(contracts["active_count"]), 0, "no normal contract is active at start")
	assert_eq(int(contracts["normal_holds"]), 0, "normal_holds mirrors active_count")
	assert_false(bool(contracts["main_chain_complete"]), "main chain is not complete at start")
	for offer in contracts["offers"]:
		assert_eq(String(offer.get("kind", "")), "normal", "initial offer is a normal contract")
	assert_true(contracts["main"] is Dictionary, "initial main contract stays active")
	var ship: Dictionary = data["ship"]
	assert_true(ship["transit_modules"] is Array, "ship view exposes transit module rows")
	assert_empty(ship["transit_modules"], "no transit modules at start")
	assert_almost_eq(float(ship["transit_weight"]), 0.0, 0.0001, "transit weight is zero at start")
	assert_true(data["victory"] is Dictionary, "port view exposes victory state")
	assert_false(bool(data["victory"]["achieved"]), "victory is not achieved at start")
	assert_almost_eq(float(data["victory"]["achieved_at"]), 0.0, 0.0001, "victory timestamp is zero")
	var stats: Dictionary = data["stats"]
	assert_eq(int(stats["income"]), 0, "stats income starts at zero")
	assert_eq(int(stats["expense"]), 0, "stats expense starts at zero")
	assert_eq(int(stats["profit"]), 0, "stats profit starts at zero")
	# Reputation changes the advertised limit on the next query.
	context.state.player()["reputation"] = 4
	var rich_view := context.queries.execute(&"port.view")
	assert_eq(int(rich_view["data"]["contracts"]["active_limit"]), 3, "port view reports the reputation limit")


func test_active_limit_formula_and_accept_rejection() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": 4242})
	assert_true(bool(start["ok"]), "run starts: %s" % str(start))
	var expectations := {0: 1, 1: 1, 2: 2, 3: 2, 4: 3, 10: 6}
	for reputation in expectations.keys():
		context.state.player()["reputation"] = int(reputation)
		assert_eq(
			ContractOps.active_limit(context.state),
			int(expectations[reputation]),
			"active limit at reputation %d" % int(reputation)
		)
	context.state.player()["reputation"] = 0
	# Unload the tutorial cargo so a normal cargo contract can be attached.
	var ship := context.state.ship()
	ship["cargo"] = []
	ship["coal"] = 0.0
	ship["water"] = 0.0
	var first := _cargo_offer(context.state.contracts().get("offers", []))
	assert_false(first.is_empty(), "pool contains a cargo-only offer")
	var accepted := context.commands.execute(&"contract.accept", {"instance_id": String(first["instance_id"])})
	assert_true(bool(accepted["ok"]), "first normal contract accepts: %s" % str(accepted))
	var limit := ContractOps.active_limit(context.state)
	assert_eq(limit, 1, "limit is one at zero reputation")
	var view := context.queries.execute(&"port.view")
	var contracts: Dictionary = view["data"]["contracts"]
	assert_eq(int(contracts["active_count"]), 1, "active count grows with the accepted normal contract")
	assert_eq(int(contracts["active_limit"]), limit, "port view exposes the current limit")
	assert_eq(int(contracts["normal_holds"]), 1, "normal_holds mirrors the active count")
	var second := _cargo_offer(contracts["offers"])
	assert_false(second.is_empty(), "another cargo offer remains in the pool")
	var rejected := context.commands.execute(&"contract.accept", {"instance_id": String(second["instance_id"])})
	assert_false(bool(rejected["ok"]), "second normal contract is rejected at the holding limit")
	assert_eq(String(rejected["error_code"]), "too_many_contracts", "rejection reports too_many_contracts")
	assert_eq(int(rejected["data"].get("limit", 0)), limit, "rejection reports the limit")
	assert_eq(context.state.contracts()["active"].size(), 1, "rejected contract does not become active")


func test_arrival_refreshes_normal_offer_pool() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": 12345})
	assert_true(bool(start["ok"]), "run starts: %s" % str(start))
	var before_ids := _offer_ids(context.state.contracts().get("offers", []))
	var before_signature := _offer_signature(context.state.contracts().get("offers", []))
	assert_eq(before_ids.size(), 3, "initial pool has three offers")
	var destination := _main_destination(context)
	assert_false(destination.is_empty(), "main contract has a destination")
	var voyage := _travel(context, destination)
	assert_true(bool(voyage["ok"]), "voyage resolves: %s" % str(voyage))
	assert_false(bool(voyage["data"].get("failed", false)), "voyage did not fail")
	assert_eq(context.state.current_port_id(), destination, "ship reached the destination")
	var summary: Dictionary = {}
	if voyage["data"].has("summary"):
		summary = voyage["data"]["summary"]
	elif voyage["data"].has("event_result"):
		summary = voyage["data"]["event_result"]
	assert_true(bool(summary.get("offers_refreshed", false)), "arrival summary reports offers_refreshed")
	assert_true(_has_event(voyage.get("events", []), "contract.offers_refreshed"), "arrival emits contract.offers_refreshed")
	var view := context.queries.execute(&"port.view")
	var contracts: Dictionary = view["data"]["contracts"]
	var after_signature := _offer_signature(contracts["offers"])
	assert_eq(after_signature.size(), 3, "arrival refills the pool with three offers")
	assert_eq(after_signature, _offer_signature(context.state.contracts().get("offers", [])), "view mirrors the refreshed pool")
	for offer_id in _offer_ids(contracts["offers"]):
		assert_false(before_ids.has(offer_id), "refreshed offer instance is new: %s" % str(offer_id))
	assert_ne(after_signature, before_signature, "the whole offer pool was replaced")
	assert_true(contracts["main_offer"] is Dictionary, "the next main offer survives the refresh")
	assert_eq(String(contracts["main_offer"]["kind"]), "main", "main offer is still a main contract")
	var main_offer_id := String(contracts["main_offer"]["instance_id"])
	assert_false(_offer_ids(contracts["offers"]).has(main_offer_id), "normal pool never contains the main offer")
	assert_true(Array(contracts["completed"]).has("core:contract/main_01"), "main chapter 1 completed on arrival")
	assert_true(int(contracts["next_main_sequence"]) >= 2, "main chain advanced")


func test_refresh_is_deterministic_for_same_seed() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub: RegistryHub = context.registries
	var first_run := RunFactory.create_run(context, STEADY_BUILD, 777)
	var second_run := RunFactory.create_run(context, STEADY_BUILD, 777)
	assert_true(bool(first_run["ok"]) and bool(second_run["ok"]), "both runs generate")
	var first_state: GameState = first_run["data"]["state"]
	var second_state: GameState = second_run["data"]["state"]
	var port_id := first_state.current_port_id()
	var first_offers := ContractOps.refresh_normal_offers(first_state, hub, RngService.new(777), port_id, 48.5)
	var second_offers := ContractOps.refresh_normal_offers(second_state, hub, RngService.new(777), port_id, 48.5)
	assert_eq(_offer_signature(first_offers), _offer_signature(second_offers), "same seed + arrival reproduce the pool")
	var later_offers := ContractOps.refresh_normal_offers(first_state, hub, RngService.new(777), port_id, 49.5)
	assert_true(later_offers.size() == 3, "a later arrival still fills three offers")
	assert_eq(first_state.contracts().get("offers", []).size(), 3, "refresh writes the pool back into state")
