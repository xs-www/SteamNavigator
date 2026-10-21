extends TestCase
## Victory determination, summary completeness, and run statistics.
## Owned by loop-systems; see docs/specs/ITERATION_1_MVP_LOOP.md §3.4 / §3.8 / §5.3 / §8.

const STEADY_BUILD := "core:starting_build/steady"
const STANDARD_STRATEGY := "core:strategy/standard"
const LARGE_HULL := "core:hull/large_efficient"
const SMALL_HULL := "core:hull/small_efficient"

const SUMMARY_KEYS := [
	"seed",
	"starting_build",
	"starting_build_name_key",
	"game_time",
	"voyages",
	"on_time",
	"on_time_rate",
	"accidents",
	"income",
	"expense",
	"profit",
	"money",
	"debt_remaining",
	"reputation",
	"durability",
	"max_durability",
	"hull_id",
	"hull_name_key",
	"cargo_capacity",
	"modules",
]


func _start_run(context: AppContext, seed_value: int) -> void:
	var started := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": seed_value})
	assert_true(bool(started["ok"]), "run starts: %s" % str(started))


func _main_template_ids(hub: RegistryHub) -> Array:
	var ids: Array = []
	for template in hub.get_all(ContentTypes.CONTRACT):
		if String(template.data.get("kind", "")) == "main":
			ids.append(template.id)
	return ids


func _complete_main_chain(context: AppContext) -> void:
	var ids := _main_template_ids(context.registries)
	assert_true(ids.size() >= 5, "core registers the full main chain")
	context.state.contracts()["completed"] = ids.duplicate()


func _move_to_facility(context: AppContext, facility: String, want: bool = true) -> bool:
	for raw_port_id in context.state.world().get("ports", {}).keys():
		var port_id := String(raw_port_id)
		var port_data := MapOps.port(context.state.world(), port_id)
		if MapOps.has_facility(port_data, facility) != want:
			continue
		context.state.world()["current_port_id"] = port_id
		var discovered: Array = context.state.world().get("discovered_ports", [])
		if not discovered.has(port_id):
			discovered.append(port_id)
		context.state.world()["discovered_ports"] = discovered
		return true
	return false


func _install_large_hull(context: AppContext) -> void:
	var ship := context.state.ship()
	ship["hull_id"] = LARGE_HULL
	ship["durability"] = ShipOps.durability_max(context.registries, ship)


func _has_event(events: Array, type: String) -> bool:
	for event in events:
		if event is Dictionary and String(event.get("type", "")) == type:
			return true
	return false


## Hardware + chain complete + at a shipyard, i.e. everything except calling check.
func _prepare_ready_run(context: AppContext, seed_value: int) -> void:
	_start_run(context, seed_value)
	_complete_main_chain(context)
	_install_large_hull(context)
	assert_true(_move_to_facility(context, "shipyard"), "map has a shipyard port")
	var gates := VictoryService.conditions(context.registries, context.state)
	assert_true(bool(gates["ready"]), "prepared run satisfies every victory gate: %s" % str(gates))


func test_victory_blocked_before_main_chain_complete() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_start_run(context, 9090)
	_install_large_hull(context)
	assert_true(_move_to_facility(context, "shipyard"), "map has a shipyard port")
	var gates := VictoryService.conditions(context.registries, context.state)
	assert_true(bool(gates["shipyard"]), "shipyard gate is satisfied")
	assert_false(bool(gates["main_complete"]), "main chain gate is not satisfied yet")
	assert_true(bool(gates["large_hull"]), "large hull gate is satisfied")
	assert_true(bool(gates["boiler"]), "boiler gate is satisfied")
	assert_true(bool(gates["cargo"]), "cargo gate is satisfied")
	assert_false(bool(gates["ready"]), "ready is false while the main chain is incomplete")
	var result := VictoryService.check(context.state, context.registries)
	assert_false(bool(result["newly_achieved"]), "check does not award the run")
	assert_false(VictoryService.achieved(context.state), "state has no victory")
	assert_eq(context.state.data.get("victory", null), null, "victory stays null")
	var view := context.queries.execute(&"victory.view")
	assert_true(bool(view["ok"]), "victory view succeeds")
	assert_false(bool(view["data"]["achieved"]), "victory view reports not achieved")
	assert_empty(view["data"]["summary"], "no summary before victory")


func test_victory_requires_shipyard_large_hull_boiler_and_cargo() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_start_run(context, 9091)
	_complete_main_chain(context)
	assert_true(_move_to_facility(context, "shipyard"), "map has a shipyard port")
	var hub: RegistryHub = context.registries
	var state: GameState = context.state

	# Large hull is mandatory.
	state.ship()["hull_id"] = SMALL_HULL
	assert_false(bool(VictoryService.conditions(hub, state)["large_hull"]), "small hull fails the large-hull gate")
	assert_false(bool(VictoryService.conditions(hub, state)["ready"]), "small hull is not ready")
	_install_large_hull(context)

	# A boiler is mandatory.
	var boiler_id := String(state.ship().get("boiler_id", ""))
	state.ship()["boiler_id"] = ""
	var without_boiler := VictoryService.conditions(hub, state)
	assert_false(bool(without_boiler["boiler"]), "missing boiler fails the boiler gate")
	assert_false(bool(without_boiler["ready"]), "missing boiler is not ready")
	state.ship()["boiler_id"] = boiler_id

	# At least one cargo module is mandatory.
	var cargo_modules: Array = state.ship().get("cargo_modules", []).duplicate()
	state.ship()["cargo_modules"] = []
	var without_cargo := VictoryService.conditions(hub, state)
	assert_false(bool(without_cargo["cargo"]), "no cargo module fails the cargo gate")
	assert_false(bool(without_cargo["ready"]), "no cargo module is not ready")
	state.ship()["cargo_modules"] = cargo_modules

	# The final install must happen at a shipyard.
	assert_true(_move_to_facility(context, "shipyard", false), "map has a port without a shipyard")
	var without_shipyard := VictoryService.conditions(hub, state)
	assert_false(bool(without_shipyard["shipyard"]), "non-shipyard port fails the shipyard gate")
	assert_false(bool(without_shipyard["ready"]), "non-shipyard port is not ready")
	assert_false(bool(VictoryService.check(state, hub)["newly_achieved"]), "check refuses away from a shipyard")

	# Restoring every gate makes the run ready, but nothing is awarded until check runs.
	assert_true(_move_to_facility(context, "shipyard"), "back at the shipyard")
	assert_true(bool(VictoryService.conditions(hub, state)["ready"]), "all gates satisfied")
	assert_false(VictoryService.achieved(state), "conditions alone do not award the run")


func test_victory_awards_once_with_complete_summary() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_prepare_ready_run(context, 9092)
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var first := VictoryService.check(state, hub)
	assert_true(bool(first["newly_achieved"]), "first check awards the run")
	assert_true(bool(first["achieved"]), "result reports achieved")
	assert_true(VictoryService.achieved(state), "state records the victory")
	assert_true(state.data["victory"] is Dictionary, "victory dictionary is written")
	var stored: Dictionary = state.data["victory"]
	assert_true(bool(stored["achieved"]), "stored victory is achieved")
	assert_almost_eq(float(stored["achieved_at"]), state.now(), 0.0001, "victory timestamp is game time")
	var summary: Dictionary = first["summary"]
	for key in SUMMARY_KEYS:
		assert_true(summary.has(key), "summary includes %s" % key)
	assert_eq(int(summary["seed"]), 9092, "summary carries the seed")
	assert_eq(String(summary["starting_build"]), STEADY_BUILD, "summary carries the starting build id")
	assert_true(not String(summary["starting_build_name_key"]).is_empty(), "summary carries the build name key")
	assert_almost_eq(float(summary["game_time"]), state.now(), 0.0001, "summary carries game time")
	assert_eq(int(summary["voyages"]), 0, "no voyage has happened yet")
	assert_almost_eq(float(summary["on_time_rate"]), 0.0, 0.0001, "on-time rate is zero without voyages")
	assert_eq(int(summary["profit"]), int(summary["income"]) - int(summary["expense"]), "profit equals income - expense")
	assert_eq(int(summary["money"]), state.money(), "summary carries current money")
	assert_eq(int(summary["reputation"]), int(state.player().get("reputation", 0)), "summary carries reputation")
	assert_almost_eq(float(summary["debt_remaining"]), 0.0, 0.0001, "steady build has no debt")
	assert_eq(String(summary["hull_id"]), LARGE_HULL, "summary carries the installed hull")
	assert_true(not String(summary["hull_name_key"]).is_empty(), "summary carries the hull name key")
	assert_true(float(summary["max_durability"]) > 0.0, "summary carries max durability")
	assert_true(float(summary["durability"]) > 0.0, "summary carries current durability")
	assert_true(float(summary["cargo_capacity"]) > 0.0, "summary carries cargo capacity")
	var modules: Array = summary["modules"]
	assert_true(modules.size() >= 3, "summary lists installed modules")
	for module in modules:
		assert_true(not String(module.get("content_type", "")).is_empty(), "module row has a content type")
		assert_true(not String(module.get("module_id", "")).is_empty(), "module row has a module id")
		assert_true(not String(module.get("name_key", "")).is_empty(), "module row has a name key")
	assert_eq(String(stored.get("summary", {}).get("hull_id", "")), LARGE_HULL, "summary is stored in state")

	# Idempotent: a second successful install cannot award twice.
	var achieved_at := float(stored["achieved_at"])
	var second := VictoryService.check(state, hub)
	assert_false(bool(second["newly_achieved"]), "second check does not re-award")
	assert_true(bool(second["achieved"]), "second check still reports achieved")
	assert_almost_eq(float(state.data["victory"]["achieved_at"]), achieved_at, 0.0001, "achievement time is unchanged")

	var view := context.queries.execute(&"victory.view")
	assert_true(bool(view["ok"]), "victory view succeeds")
	var view_data: Dictionary = view["data"]
	assert_true(bool(view_data["has_run"]), "victory view knows a run exists")
	assert_true(bool(view_data["achieved"]), "victory view reports achieved")
	assert_almost_eq(float(view_data["achieved_at"]), achieved_at, 0.0001, "victory view carries the timestamp")
	assert_true(not String(view_data["achieved_at_label"]).is_empty(), "victory view carries a timestamp label")
	assert_eq(int(view_data["summary"].get("seed", 0)), 9092, "victory view carries the summary")
	var port_view := context.queries.execute(&"port.view")
	assert_true(bool(port_view["data"]["victory"]["achieved"]), "port view carries victory state")
	assert_almost_eq(float(port_view["data"]["victory"]["achieved_at"]), achieved_at, 0.0001, "port view carries achieved_at")
	assert_true(bool(port_view["data"]["contracts"]["main_chain_complete"]), "port view reports the completed main chain")


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


func test_stats_track_income_expense_and_profit() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_start_run(context, 12345)
	var hub: RegistryHub = context.registries
	var state: GameState = context.state
	var stats := state.stats()
	assert_eq(int(stats["income"]), 0, "income starts at zero")
	assert_eq(int(stats["expense"]), 0, "expense starts at zero")
	assert_eq(int(stats["profit"]), 0, "profit starts at zero")

	# The first voyage settles the tutorial contract (income) and pays wages (expense).
	var main_contract: Variant = state.contracts().get("main", null)
	var destination := String(main_contract.get("destination", "")) if main_contract is Dictionary else ""
	assert_false(destination.is_empty(), "main contract has a destination")
	var preview := context.commands.execute(&"voyage.preview", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})
	assert_true(bool(preview["ok"]), "preview succeeds: %s" % str(preview))
	var wages := int(preview["data"]["crew_wages"])
	var voyage := _travel(context, destination)
	assert_true(bool(voyage["ok"]), "voyage resolves: %s" % str(voyage))
	assert_false(bool(voyage["data"].get("failed", false)), "voyage did not fail")
	assert_eq(state.current_port_id(), destination, "ship reached the contract destination")
	var journey: Dictionary = {}
	if voyage["data"].has("summary"):
		journey = voyage["data"]["summary"]
	elif voyage["data"].has("event_result"):
		journey = voyage["data"]["event_result"]
	var contract_payout := 0
	for contract_result in journey.get("contracts", []):
		contract_payout += int(contract_result.get("payout", 0))
	assert_true(contract_payout > 0, "contract payout is positive")
	stats = state.stats()
	assert_eq(int(stats["income"]), contract_payout, "contract payout records income")
	assert_eq(int(stats["expense"]), wages, "crew wages record an expense")
	assert_eq(int(stats["profit"]), contract_payout - wages, "profit is income minus expense")
	assert_eq(int(stats["voyages"]), 1, "arrival counts one voyage")

	# Buying is an expense; selling is income. Pick a good that fits free weight.
	var weight_headroom := ShipOps.max_weight(hub, state.ship()) - ShipOps.total_weight(hub, state)
	var view := context.queries.execute(&"port.view")
	var target: Dictionary = {}
	for row in view["data"]["market"]:
		if bool(row.get("buyable", true)) and int(row.get("stock", 0)) >= 1 \
				and int(row.get("price", 0)) <= state.money() \
				and float(row.get("unit_weight", 99.0)) <= weight_headroom + 0.0001:
			target = row
			break
	assert_false(target.is_empty(), "found a buyable good that fits the weight budget")
	var item_id := String(target["item_id"])
	var buy := context.commands.execute(&"trade.buy", {"item_id": item_id, "amount": 1})
	assert_true(bool(buy["ok"]), "buy succeeds: %s" % str(buy))
	var buy_total := int(buy["data"]["total"])
	stats = state.stats()
	assert_eq(int(stats["expense"]), wages + buy_total, "buy records an expense")
	assert_eq(int(stats["profit"]), int(stats["income"]) - int(stats["expense"]), "profit follows both sides")

	var sell := context.commands.execute(&"trade.sell", {"item_id": item_id, "amount": 1})
	assert_true(bool(sell["ok"]), "sell succeeds: %s" % str(sell))
	var revenue := int(sell["data"]["revenue"])
	stats = state.stats()
	assert_eq(int(stats["income"]), contract_payout + revenue, "sell records income")
	assert_eq(int(stats["profit"]), contract_payout + revenue - wages - buy_total, "profit is income minus expense")

	# Intelligence refresh is an expense.
	assert_true(_move_to_facility(context, "tavern"), "map has a tavern")
	var intel := context.commands.execute(&"intel.refresh", {})
	assert_true(bool(intel["ok"]), "price-intel refresh succeeds: %s" % str(intel))
	var intel_cost := int(intel["data"]["cost"])
	stats = state.stats()
	assert_eq(int(stats["expense"]), wages + buy_total + intel_cost, "intel refresh records an expense")

	# Borrowing principal is not income.
	var borrow := context.commands.execute(&"debt.borrow", {"amount": 100})
	assert_true(bool(borrow["ok"]), "borrow succeeds: %s" % str(borrow))
	stats = state.stats()
	assert_eq(int(stats["income"]), contract_payout + revenue, "borrowed principal is not income")
	assert_eq(int(stats["profit"]), contract_payout + revenue - wages - buy_total - intel_cost, "borrowing does not change profit")

	var final_view := context.queries.execute(&"port.view")
	var final_stats: Dictionary = final_view["data"]["stats"]
	assert_eq(int(final_stats["income"]), int(stats["income"]), "port view exposes stats income")
	assert_eq(int(final_stats["expense"]), int(stats["expense"]), "port view exposes stats expense")
	assert_eq(int(final_stats["profit"]), int(stats["profit"]), "port view exposes stats profit")


func test_shipyard_install_triggers_victory_once() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	_start_run(context, 9094)
	var state: GameState = context.state
	_complete_main_chain(context)
	assert_true(_move_to_facility(context, "shipyard"), "map has a shipyard port")
	# The main chain would have granted the large-hull unlock; state it explicitly.
	var unlocks: Array = Array(state.player().get("unlocks", []))
	if not unlocks.has(LARGE_HULL):
		unlocks.append(LARGE_HULL)
	state.player()["unlocks"] = unlocks
	state.set_money(9999)
	state.ship()["cargo"] = []
	var install := context.commands.execute(&"ship.install_module", {"module_id": LARGE_HULL})
	assert_true(bool(install["ok"]), "large hull installs at the shipyard: %s" % str(install))
	assert_eq(String(state.ship()["hull_id"]), LARGE_HULL, "large hull is on the ship")
	var victory: Dictionary = install["data"]["victory"]
	assert_true(bool(victory["newly_achieved"]), "install result reports the new victory")
	assert_true(VictoryService.achieved(state), "state records the victory")
	assert_true(_has_event(install.get("events", []), "run.victory_achieved"), "install emits run.victory_achieved")
	var price := int(install["data"]["price"])
	assert_true(price > 0, "purchase price is reported")
	assert_eq(int(state.stats()["expense"]), price, "purchase is recorded exactly once as an expense")

	# A later successful install keeps the same summary and never re-awards.
	var cabin := context.commands.execute(&"ship.install_module", {"module_id": "core:cabin/passenger_cabin"})
	assert_true(bool(cabin["ok"]), "cabin installs after victory: %s" % str(cabin))
	assert_false(bool(cabin["data"]["victory"]["newly_achieved"]), "second install does not re-award")
	assert_false(_has_event(cabin.get("events", []), "run.victory_achieved"), "no second victory event")
	var stored_summary: Dictionary = state.data["victory"]["summary"]
	assert_eq(String(stored_summary["hull_id"]), LARGE_HULL, "stored summary keeps the winning hull")
	assert_eq(int(stored_summary["seed"]), 9094, "stored summary keeps the run seed")
