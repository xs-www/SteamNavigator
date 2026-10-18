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
	assert_eq(first_state.hash(), second_state.hash(), "same seed and build reproduce the same run")


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
