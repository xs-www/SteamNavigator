extends TestCase
## Module instance layer: identity + condition per installed module, aligned with
## the flat slot keys, damaged by effects and restored by repair.

func _directory() -> String:
	return "user://test_saves/modules_%d" % Time.get_ticks_usec()


func _cleanup(directory: String) -> void:
	var files := DirAccess.get_files_at(directory)
	if files != null:
		for file_name in files:
			DirAccess.remove_absolute(directory + "/" + file_name)
	DirAccess.remove_absolute(directory)


func _legacy_ship() -> Dictionary:
	return {
		"hull_id": "core:hull/small_efficient",
		"boiler_id": "core:module/basic",
		"cargo_modules": ["core:module/basic"],
		"navigation_module_id": "",
		"safety_module_id": "",
		"passenger_cabin_id": "",
		"durability": 100.0,
		"coal": 30.0,
		"water": 30.0,
		"cargo": [],
	}


func test_new_run_creates_module_instances() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 7101})
	assert_true(bool(start["ok"]), "run starts: %s" % str(start))
	var ship := context.state.ship()
	var table := ShipModules.instances(ship)
	assert_true(table.has("boiler"), "the boiler has an instance")
	assert_eq(Array(table.get("cargo", [])).size(), ShipOps.cargo_module_ids(ship).size(), "cargo instances match installed cargo")
	var ids: Dictionary = {}
	for row in ShipModules.installed_rows(ship):
		assert_almost_eq(float(row["condition"]), 1.0, 1e-9, "a new run ships at full condition")
		assert_false(String(row["instance_id"]).is_empty(), "each instance has a stable id")
		assert_false(ids.has(String(row["instance_id"])), "instance ids are unique")
		ids[String(row["instance_id"])] = true
	assert_true(int(ship.get("module_serial", 0)) >= ids.size(), "the serial counter covers every instance")


func test_legacy_ship_is_backfilled() -> void:
	var ship := _legacy_ship()
	var table := ShipModules.ensure(ship)
	assert_almost_eq(ShipModules.condition(ship, "boiler"), 1.0, 1e-9, "legacy boiler starts at full condition")
	assert_eq(Array(table["cargo"]).size(), 1, "legacy cargo gets one instance")
	assert_eq(int(ship.get("module_serial", 0)), 2, "backfill assigns one serial per module")
	var first_id := String(table["boiler"]["instance_id"])
	ShipModules.ensure(ship)
	assert_eq(String(table["boiler"]["instance_id"]), first_id, "a second ensure keeps instance ids stable")
	assert_eq(int(ship.get("module_serial", 0)), 2, "a second ensure does not add serials")


func test_damage_and_repair_conditions() -> void:
	var ship := _legacy_ship()
	ShipModules.ensure(ship)
	var hit := ShipModules.damage(ship, "boiler", 0, 0.4)
	assert_true(bool(hit["ok"]), "damage applies")
	assert_almost_eq(float(hit["condition"]), 0.6, 1e-9, "condition drops by the damage ratio")
	assert_false(bool(hit["disabled"]), "a damaged module is still operational")
	var broke := ShipModules.damage(ship, "boiler", 0, 0.9)
	assert_almost_eq(float(broke["condition"]), 0.0, 1e-9, "condition clamps at zero")
	assert_true(bool(broke["disabled"]), "zero condition disables the module")
	assert_true(bool(broke["newly_disabled"]), "the transition reports newly disabled")
	var again := ShipModules.damage(ship, "boiler", 0, 0.2)
	assert_false(bool(again["newly_disabled"]), "a second hit does not repeat the transition")
	assert_eq(int(ShipModules.repair_all(ship)), 1, "repair counts the damaged instance")
	assert_almost_eq(ShipModules.condition(ship, "boiler"), 1.0, 1e-9, "repair restores full condition")
	assert_false(bool(ShipModules.damage(ship, "boiler", 0, 0.0)["ok"]), "zero damage is rejected")
	assert_false(bool(ShipModules.damage(ship, "hull", 0, 0.1)["ok"]), "hull has no module instance slot")


func test_cargo_instances_stay_aligned() -> void:
	var ship := _legacy_ship()
	ShipModules.ensure(ship)
	var first_id := String(ShipModules.installed_rows(ship)[1]["instance_id"])
	ship["cargo_modules"] = Array(ship["cargo_modules"]) + ["core:module/basic"]
	ShipModules.ensure(ship)
	assert_eq(Array(ShipModules.instances(ship)["cargo"]).size(), 2, "a new cargo module gets an instance")
	ship["cargo_modules"] = [String(ship["cargo_modules"][1])]
	ShipModules.remove_cargo(ship, 0)
	ShipModules.ensure(ship)
	assert_eq(Array(ShipModules.instances(ship)["cargo"]).size(), 1, "removing cargo keeps the table aligned")
	assert_ne(String(ShipModules.instances(ship)["cargo"][0]["instance_id"]), String(first_id), "the surviving module keeps its own instance")


func test_install_slot_resets_condition() -> void:
	var ship := _legacy_ship()
	ShipModules.ensure(ship)
	ShipModules.damage(ship, "boiler", 0, 0.5)
	var old_id := String(ShipModules.instances(ship)["boiler"]["instance_id"])
	ship["boiler_id"] = "core:module/efficient"
	ShipModules.install_slot(ship, "boiler")
	assert_almost_eq(ShipModules.condition(ship, "boiler"), 1.0, 1e-9, "a swapped-in module starts at full condition")
	assert_ne(String(ShipModules.instances(ship)["boiler"]["instance_id"]), old_id, "a replacement gets a new instance id")


func test_damage_module_effect_opcode() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 7202})
	assert_true(EffectOpRegistry.has("damage_module"), "damage_module is a registered effect op")
	var execution := {
		"state": context.state,
		"hub": context.registries,
		"game_time": context.state.now(),
		"flags": {},
		"notices": [],
		"events": [],
	}
	var result := EffectExecutor.execute([{"op": "damage_module", "slot": "boiler", "amount": 0.3}], execution)
	assert_true(bool(result["ok"]), "damage_module succeeds: %s" % str(result))
	assert_almost_eq(ShipModules.condition(context.state.ship(), "boiler"), 0.7, 1e-9, "the boiler instance takes the damage")
	assert_eq(Array(execution["events"]).size(), 1, "a module damage event is emitted")
	assert_eq(String(execution["events"][0]["type"]), "ship.module_damaged", "event type names the module damage")
	var invalid := EffectExecutor.execute([{"op": "damage_module", "slot": "hull", "amount": 0.3}], execution)
	assert_false(bool(invalid["ok"]), "hull is not a module slot")
	assert_eq(String(invalid["error_code"]), "unknown_module_slot", "invalid slots report a stable error code")


func test_repair_cost_includes_module_damage() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 7303})
	var hub: RegistryHub = context.registries
	var ship := context.state.ship()
	var baseline := MarketOps.repair_cost(hub, context.state, 6.0)
	assert_almost_eq(float(baseline["module_points"]), 0.0, 1e-9, "a fresh ship owes no module repairs")
	ShipModules.damage(ship, "boiler", 0, 0.5)
	var damaged := MarketOps.repair_cost(hub, context.state, 6.0)
	assert_almost_eq(float(damaged["durability_missing"]), float(baseline["durability_missing"]), 1e-9, "module damage does not fake hull damage")
	assert_true(float(damaged["module_points"]) > 0.0, "damaged modules add repair points")
	assert_true(int(damaged["cost"]) > int(baseline["cost"]), "the repair quote grows with module damage")


func test_conditions_survive_save_load() -> void:
	var directory := _directory()
	var boot := bootstrap_core({"save_directory": directory})
	var context: AppContext = boot["context"]
	var start := context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 7404})
	assert_true(bool(start["ok"]), "run starts: %s" % str(start))
	ShipModules.damage(context.state.ship(), "boiler", 0, 0.45)
	var instance_id := String(ShipModules.instances(context.state.ship())["boiler"]["instance_id"])
	var before := context.state.hash()
	var saved := context.save.save_slot("manual", context.state, context.save_meta())
	assert_true(bool(saved["ok"]), "save succeeds: %s" % str(saved))
	var loaded: GameState = context.save.load_slot("manual")["state"]
	assert_almost_eq(ShipModules.condition(loaded.ship(), "boiler"), 0.55, 1e-9, "module condition survives save/load")
	assert_eq(String(ShipModules.instances(loaded.ship())["boiler"]["instance_id"]), instance_id, "instance id survives save/load")
	assert_eq(loaded.hash(), before, "damaged module state round-trips byte for byte")
	_cleanup(directory)
