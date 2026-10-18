extends TestCase


func test_cabin_and_cargo_upgrade() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 9090})
	var port := MapOps.port(context.state.world(), context.state.current_port_id())
	assert_true(MapOps.has_facility(port, "shipyard"), "starting hub has a shipyard")
	context.state.set_money(6000)
	var hull_upgrade := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/medium_standard"})
	assert_true(bool(hull_upgrade["ok"]), "medium hull installs: %s" % str(hull_upgrade))
	assert_eq(String(context.state.ship()["hull_id"]), "core:hull/medium_standard", "hull id changed")
	var cabin := context.commands.execute(&"ship.install_module", {"module_id": "core:cabin/passenger_cabin"})
	assert_true(bool(cabin["ok"]), "cabin installs: %s" % str(cabin))
	assert_eq(ShipOps.passenger_capacity(context.registries, context.state.ship()), 4, "cabin capacity is available")
	var second_cabin := context.commands.execute(&"ship.install_module", {"module_id": "core:cabin/passenger_cabin"})
	assert_false(bool(second_cabin["ok"]), "second cabin is rejected")
	var cargo := context.commands.execute(&"ship.install_module", {"module_id": "core:cargo_module/medium_hold"})
	assert_true(bool(cargo["ok"]), "second cargo module installs on medium hull")
	var third := context.commands.execute(&"ship.install_module", {"module_id": "core:cargo_module/small_hold"})
	assert_false(bool(third["ok"]), "cargo slots are enforced")


func test_small_hull_rejects_cabin() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 9191})
	context.state.set_money(6000)
	var cabin := context.commands.execute(&"ship.install_module", {"module_id": "core:cabin/passenger_cabin"})
	assert_false(bool(cabin["ok"]), "small hull has no cabin slot")
