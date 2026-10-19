extends TestCase
## Shipyard upgrade flows under iteration-1 semantics: replacement instead of
## "slot_occupied", and contract-gated hull tiers.


const MEDIUM_UNLOCKS := ["core:hull/medium_standard", "core:cargo_module/medium_hold"]


func test_cabin_and_cargo_upgrade() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 9090})
	var port := MapOps.port(context.state.world(), context.state.current_port_id())
	assert_true(MapOps.has_facility(port, "shipyard"), "starting hub has a shipyard")
	context.state.set_money(6000)
	context.state.player()["unlocks"] = MEDIUM_UNLOCKS.duplicate()
	var hull_upgrade := context.commands.execute(&"ship.install_module", {"module_id": "core:hull/medium_standard"})
	assert_true(bool(hull_upgrade["ok"]), "medium hull installs after main_03 unlock: %s" % str(hull_upgrade))
	assert_eq(String(context.state.ship()["hull_id"]), "core:hull/medium_standard", "hull id changed")
	assert_almost_eq(float(context.state.ship()["durability"]), 140.0, 0.001, "purchased hull starts at full durability")
	var cabin := context.commands.execute(&"ship.install_module", {"module_id": "core:cabin/passenger_cabin"})
	assert_true(bool(cabin["ok"]), "cabin installs: %s" % str(cabin))
	assert_eq(ShipOps.passenger_capacity(context.registries, context.state.ship()), 4, "cabin capacity is available")
	# A single-slot module with a different module_id replaces the old one and the
	# old module moves into the current-port warehouse (no slot_occupied error).
	var navigation := context.commands.execute(&"ship.install_module", {"module_id": "core:navigation_module/chart_room"})
	assert_true(bool(navigation["ok"]), "chart room replaces the spyglass: %s" % str(navigation))
	assert_eq(String(context.state.ship()["navigation_module_id"]), "core:navigation_module/chart_room", "navigation module replaced")
	assert_eq(WarehouseOps.module_qty(context.state, context.state.current_port_id(), "core:navigation_module/spyglass"), 1, "replaced spyglass is stored at the current port")
	var second_cabin := context.commands.execute(&"ship.install_module", {"module_id": "core:cabin/passenger_cabin"})
	assert_false(bool(second_cabin["ok"]), "buying the already-installed cabin is rejected")
	assert_eq(String(second_cabin["error_code"]), "already_installed", "already_installed is the blocker for an identical module")
	var cargo := context.commands.execute(&"ship.install_module", {"module_id": "core:cargo_module/medium_hold"})
	assert_true(bool(cargo["ok"]), "second cargo module installs on medium hull: %s" % str(cargo))
	var third := context.commands.execute(&"ship.install_module", {"module_id": "core:cargo_module/small_hold"})
	assert_false(bool(third["ok"]), "installing an already-installed cargo module is rejected")


func test_small_hull_rejects_cabin() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 9191})
	context.state.set_money(6000)
	var cabin := context.commands.execute(&"ship.install_module", {"module_id": "core:cabin/passenger_cabin"})
	assert_false(bool(cabin["ok"]), "small hull has no cabin slot")


func test_craft_cost_is_loaded_for_each_tier() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub: RegistryHub = context.registries
	# Tier 2/3 recipes are unchanged.
	assert_eq(CraftOps.craft_cost(hub, "core:hull/medium_standard"), 220, "medium hull craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:boiler/performance"), 180, "performance boiler craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:cargo_module/large_hold"), 320, "large hold craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:safety_module/safety_valve"), 130, "safety valve craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:navigation_module/chart_room"), 140, "chart room craft cost")
	# Tier 1 recipes are gold only (feedback 1): materials removed, craft_cost added.
	assert_eq(CraftOps.craft_cost(hub, "core:hull/small_efficient"), 170, "small hull craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:boiler/small_efficient"), 190, "small boiler craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:boiler/standard"), 290, "standard boiler craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:cabin/passenger_cabin"), 270, "passenger cabin craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:cargo_module/small_hold"), 120, "small hold craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:navigation_module/spyglass"), 140, "spyglass craft cost")
	assert_eq(CraftOps.craft_cost(hub, "core:safety_module/lifeboat"), 130, "lifeboat craft cost")
	for module_id in [
		"core:hull/small_efficient", "core:boiler/small_efficient", "core:boiler/standard",
		"core:cabin/passenger_cabin", "core:cargo_module/small_hold",
		"core:navigation_module/spyglass", "core:safety_module/lifeboat",
	]:
		assert_empty(CraftOps.materials_required(hub, module_id), "%s needs no materials" % module_id)
		assert_true(CraftOps.money_only(hub, module_id), "%s is a money-only recipe" % module_id)
		assert_true(CraftOps.craftable(hub, module_id), "%s stays craftable without materials" % module_id)
