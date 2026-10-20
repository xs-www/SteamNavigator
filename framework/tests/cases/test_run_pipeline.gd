extends TestCase


func test_full_first_voyage() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 12345})
	assert_true(bool(start["ok"]), "run starts: %s" % str(start))
	var main_contract: Dictionary = context.state.contracts()["main"]
	var destination := String(main_contract["destination"])
	var preview := context.commands.execute(&"voyage.preview", {"destination_id": destination, "strategy_id": "core:strategy/standard"})
	assert_true(bool(preview["ok"]), "preview succeeds")
	var preview_data: Dictionary = preview["data"]
	assert_true(float(preview_data["duration_hours"]) > 0.0, "preview has a duration")
	assert_true(float(preview_data["coal_required"]) > 0.0, "preview has coal demand")
	assert_true(float(preview_data["water_required"]) > 0.0, "preview has water demand")
	assert_true(bool(preview_data["feasible"]), "first voyage is feasible: %s" % str(preview_data["blockers"]))
	var voyage := context.commands.execute(&"voyage.start", {"destination_id": destination, "strategy_id": "core:strategy/standard"})
	assert_true(bool(voyage["ok"]), "voyage starts: %s" % str(voyage))
	if not bool(voyage["data"].get("arrived", true)):
		var option_ids: Array = voyage["data"]["event"]["option_ids"]
		assert_eq(option_ids.size(), 2, "event offers exactly two sampled options")
		var choice := context.commands.execute(&"event.choose_option", {"option_id": String(option_ids[0])})
		assert_true(bool(choice["ok"]), "event option resolves: %s" % str(choice))
	assert_eq(context.state.current_port_id(), destination, "ship arrived at the contract destination")
	assert_eq(context.state.contracts().get("main", null), null, "main contract slot is cleared")
	assert_eq(int(context.state.contracts().get("next_main_sequence", 0)), 2, "next main sequence is queued")
	assert_not_null(context.state.contracts().get("main_offer", null), "next main contract is offered")
	assert_true(Array(context.state.contracts().get("completed", [])).has("core:contract/main_01"), "main_01 is marked complete")
	assert_true(context.state.money() > 900, "contract payout increases money")
	assert_true(context.state.now() > 0.0, "game time advanced")


func test_deterministic_run_generation() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var first := RunFactory.create_run(context, "core:starting_build/steady", 777)
	var second := RunFactory.create_run(context, "core:starting_build/steady", 777)
	assert_true(bool(first["ok"]) and bool(second["ok"]), "both generated runs are valid")
	var first_state: GameState = first["data"]["state"]
	var second_state: GameState = second["data"]["state"]
	first_state.data["run"].erase("started_at")
	second_state.data["run"].erase("started_at")
	first_state.data["campaign"].erase("created_at")
	second_state.data["campaign"].erase("created_at")
	assert_eq(first_state.hash(), second_state.hash(), "same seed and build reproduce the same run")


## run.start now stores a coordinate-space twin world keyed by the played map's
## port ids, so the nautical chart reads a real run without fixtures: same ids
## and archetypes, the start harbour discovered, visited, current and revealed
## out of the fog. A first voyage keeps the twin in step (visit + fog).
func test_run_maps_a_chart_twin_world() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 4242})
	assert_true(bool(start["ok"]), "run starts: %s" % str(start))
	var state: GameState = context.state
	var world_map_data: Dictionary = state.data.get("world_map", {})
	assert_false(world_map_data.is_empty(), "run.start stores a coordinate-space world")

	var world := WorldMap.from_dict(world_map_data)
	var played_ports: Dictionary = state.world().get("ports", {})
	assert_eq(world.ports.size(), played_ports.size(), "the twin world mirrors the played map's port count")
	for port_id in played_ports.keys():
		var twin_port := world.get_port(String(port_id))
		assert_false(twin_port.is_empty(), "the twin world keeps port id %s" % str(port_id))
		if twin_port.is_empty():
			continue
		assert_eq(String(twin_port.archetype_id), String(played_ports[port_id].get("archetype_id", "")),
			"twin port %s keeps the played archetype" % str(port_id))

	var current_port_id := String(state.current_port_id())
	var campaign_world := state.campaign_world()
	assert_true((campaign_world.get("discovered_port_ids", []) as Array).has(current_port_id),
		"the start port is discovered")
	assert_true(state.is_port_visited(current_port_id), "the start port is visited")
	assert_eq(String(WorldOps.current_port_id(state)), current_port_id, "the twin world tracks the current port")
	var start_port := world.get_start_port()
	assert_true(FogOps.is_position_visible(state, start_port.position),
		"the start harbour is revealed out of the fog")

	# The chart query consumes the real run directly — no injected fixtures.
	var result := context.queries.execute(&"sea_chart.view")
	assert_true(bool(result.get("ok", false)), "the chart query reads the real run")
	var view_model: Dictionary = result.get("data", {})
	var chart_ports: Array = view_model.get("ports", [])
	assert_true(chart_ports.size() >= 1, "the chart lists the discovered ports")
	for port_vm in chart_ports:
		if String(port_vm.get("id", "")) == current_port_id:
			assert_true(bool(port_vm.get("current", false)), "the current port is marked on the chart")

	# A voyage keeps the twin in step: the destination becomes visited + revealed.
	var destination := String(state.contracts()["main"]["destination"])
	var voyage := context.commands.execute(&"voyage.start", {"destination_id": destination, "strategy_id": "core:strategy/standard"})
	assert_true(bool(voyage["ok"]), "voyage starts: %s" % str(voyage))
	if not bool(voyage["data"].get("arrived", true)):
		var option_ids: Array = voyage["data"]["event"]["option_ids"]
		var choice := context.commands.execute(&"event.choose_option", {"option_id": String(option_ids[0])})
		assert_true(bool(choice["ok"]), "event option resolves: %s" % str(choice))
	assert_eq(state.current_port_id(), destination, "the ship arrived at the destination")
	assert_true(state.is_port_visited(destination), "the arrived port is recorded as visited")
	var arrived_port := world.get_port(destination)
	assert_false(arrived_port.is_empty(), "the arrived port exists in the twin world")
	assert_true(FogOps.is_position_visible(state, arrived_port.position),
		"the arrived harbour is revealed out of the fog")


func test_swift_build_can_start() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"build_id": "core:starting_build/swift", "seed": 888})
	assert_true(bool(start["ok"]), "swift build starts: %s" % str(start))
	var preview := context.commands.execute(&"voyage.preview", {
		"destination_id": String(context.state.contracts()["main"]["destination"]),
		"strategy_id": "core:strategy/standard",
	})
	assert_true(bool(preview["ok"]), "swift build can preview a voyage")
