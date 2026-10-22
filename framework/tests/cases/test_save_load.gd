extends TestCase


func test_save_and_load_state_hash() -> void:
	var boot := bootstrap_core({
		"save_directory": "user://test_saves/save_%d" % Time.get_ticks_usec(),
	})
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 7171})
	var before := context.state.hash()
	var saved := context.save.save_slot("manual", context.state, context.save_meta())
	assert_true(bool(saved["ok"]), "save succeeds: %s" % str(saved))
	assert_true(context.save.has_slot("manual"), "save slot exists")
	var loaded := context.save.load_slot("manual")
	assert_true(bool(loaded["ok"]), "load succeeds")
	var loaded_state: GameState = loaded["state"]
	assert_eq(loaded_state.hash(), before, "state hash is identical after load")
	assert_eq(QuestOps.instances(loaded_state).size(), QuestOps.instances(context.state).size(),
		"quest instances round-trip through the save")
	assert_false(QuestOps.active_content_instance(loaded_state, "core:quest/first_voyage_guide").is_empty(),
		"the auto-started guide quest survives load")
	var main_contract: Variant = context.state.contracts().get("main", null)
	if main_contract is Dictionary:
		assert_false(QuestOps.find_by_contract(loaded_state, String((main_contract as Dictionary).get("instance_id", ""))).is_empty(),
			"the accepted contract's quest tracking instance survives load")
	var header: Dictionary = loaded["header"]
	assert_eq(String(header["save_schema"]), "2.0", "save schema is recorded")
	assert_eq(String(header["state_schema"]), "2.0", "state schema is recorded")
	assert_eq(String(header["content_schema"]), FrameworkInfo.CONTENT_SCHEMA, "content schema is recorded separately")
	assert_true(Array(header["mods"]).size() >= 1, "save header records mods")
	var compatible := context.save.validate_mods(header, context.mod_summaries())
	assert_true(bool(compatible["ok"]), "current mod set is compatible")
	var missing := context.save.validate_mods(header, [])
	assert_false(bool(missing["ok"]), "missing required mod rejects the save")


func test_second_save_replaces_first() -> void:
	var boot := bootstrap_core({
		"save_directory": "user://test_saves/save_%d" % Time.get_ticks_usec(),
	})
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 7272})
	context.save.save_slot("manual", context.state, context.save_meta())
	var first_loaded: GameState = context.save.load_slot("manual")["state"]
	var first_hash := first_loaded.hash()
	context.state.add_money(123)
	var second := context.save.save_slot("manual", context.state, context.save_meta())
	assert_true(bool(second["ok"]), "second save succeeds")
	var second_loaded: GameState = context.save.load_slot("manual")["state"]
	var second_hash := second_loaded.hash()
	assert_ne(second_hash, first_hash, "second save replaced the first")
	assert_eq(second_hash, context.state.hash(), "saved state matches live state")
