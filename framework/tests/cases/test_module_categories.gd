extends TestCase
## @static-doc
## 作用：C1 统一模块类型 `modules` 的 category 运行时测试：`ModuleOps` 的查询 / 槽位映射 /
## utility tag 路由，以及 ship_ops / ship_commands / craft_ops / cross_reference 在真实
## Core 内容上的分类行为。
##
## ## 契约与约束
## - `ModuleOps.category_of` 读取 `data.v2_category`（boiler / cargo / utility / cabin）；
##   `SLOT_CATEGORIES` 把扁平 ship 槽位映射到 category，`accepts` 按 category 判定。
## - utility 覆盖原导航/安全模块：`module.navigation` → `navigation_module` 槽，
##   `module.safety` → `safety_module` 槽；无标签兜底第一个空 utility 槽。
## - `ship.install_module` 可用 `slot` 参数指定 utility 拖放目标；boiler / cargo / cabin
##   的槽位由 category 固定。`ship` 存档仍保留扁平槽位与 module_instances 形状。
## - 合成 fixture 只用 `modules` 定义 + `v2_category`，不依赖旧 1.0 模块类型。
## @end-static-doc

const STEADY_BUILD := "core:starting_scenario/steady"
const STEADY_HULL := "core:hull/small_efficient"
const SPYGLASS := "core:module/spyglass"
const CHART_ROOM := "core:module/chart_room"
const LIFEBOAT := "core:module/lifeboat"
const SAFETY_VALVE := "core:module/safety_valve"
const SMALL_HOLD := "core:module/small_hold"
const STANDARD_BOILER := "core:module/standard"
const PASSENGER_CABIN := "core:module/passenger_cabin"


func _run_fixture(seed_value: int = 6401) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": seed_value,
	})
	assert_true(bool(started.get("ok", false)), "run.start succeeds for the module category fixture: %s" % str(started))
	return {"context": context, "started": started}


func _synthetic_module(
	hub: RegistryHub,
	module_id: String,
	category: String,
	tags: Array = [],
	data: Dictionary = {}
) -> ContentDefinition:
	var merged := {
		"v2_category": category,
		"tier": 1,
		"weight": 1.0,
		"purchase_price": 10.0,
	}
	for key in data.keys():
		merged[String(key)] = data[key]
	var definition := ContentDefinition.from_raw({
		"id": module_id,
		"name_key": "test.%s.name" % module_id.get_slice("/", 1),
		"enabled": true,
		"tags": tags,
		"data": merged,
	}, ContentTypes.MODULE, "test", "res://framework/tests/cases/test_module_categories.gd")
	var registered := hub.register(definition, "test")
	assert_true(bool(registered.get("ok", false)), "synthetic module '%s' registers" % module_id)
	return definition


func test_core_modules_expose_categories() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub := context.registries
	var all := ModuleOps.all(hub)
	assert_true(all.size() >= 12, "core ships the merged module family: %d" % all.size())
	assert_true(ModuleOps.count(hub, "boiler") >= 2, "at least two boiler modules")
	assert_true(ModuleOps.count(hub, "cargo") >= 1, "at least one cargo module")
	assert_true(ModuleOps.count(hub, "utility") >= 1, "at least one utility module")
	assert_true(ModuleOps.count(hub, "cabin") >= 1, "at least one cabin module")
	assert_eq(ModuleOps.category_of(ModuleOps.get_by_id(hub, STANDARD_BOILER)), "boiler", "boiler category")
	assert_eq(ModuleOps.category_of(ModuleOps.get_by_id(hub, SMALL_HOLD)), "cargo", "cargo category")
	assert_eq(ModuleOps.category_of(ModuleOps.get_by_id(hub, SPYGLASS)), "utility", "navigation modules are utility")
	assert_eq(ModuleOps.category_of(ModuleOps.get_by_id(hub, PASSENGER_CABIN)), "cabin", "cabin category")
	assert_eq(ModuleOps.category_of_id(hub, "core:module/absent"), "", "unknown module has no category")
	assert_true(ModuleOps.is_module(hub, STANDARD_BOILER), "merged type ids are modules")
	assert_false(ModuleOps.is_module(hub, STEADY_HULL), "hulls stay a separate content type")


func test_slot_category_mapping_and_accepts() -> void:
	assert_eq(ModuleOps.slot_category("boiler"), "boiler", "boiler slot accepts boiler modules")
	assert_eq(ModuleOps.slot_category("cargo_modules"), "cargo", "cargo slot accepts cargo modules")
	assert_eq(ModuleOps.slot_category("navigation_module"), "utility", "navigation slot is utility")
	assert_eq(ModuleOps.slot_category("safety_module"), "utility", "safety slot is utility")
	assert_eq(ModuleOps.slot_category("passenger_cabin"), "cabin", "cabin slot accepts cabin modules")
	assert_eq(ModuleOps.slot_category("hull"), "", "hull is not a module slot")
	assert_eq(ModuleOps.ship_slot_key("navigation_module"), "navigation_module_id", "flat save key mapping")
	assert_eq(ModuleOps.instance_slot("passenger_cabin"), "cabin", "module instance slot mapping")
	assert_eq(ModuleOps.category_slots("utility"), ["navigation_module", "safety_module"], "utility owns both slots")

	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub := context.registries
	assert_true(ModuleOps.accepts(ModuleOps.get_by_id(hub, SPYGLASS), "navigation_module"), "utilities accept the navigation slot")
	assert_true(ModuleOps.accepts(ModuleOps.get_by_id(hub, LIFEBOAT), "safety_module"), "utilities accept the safety slot")
	assert_false(ModuleOps.accepts(ModuleOps.get_by_id(hub, SMALL_HOLD), "navigation_module"), "cargo modules do not accept utility slots")
	assert_false(ModuleOps.accepts(ModuleOps.get_by_id(hub, STANDARD_BOILER), "passenger_cabin"), "boilers do not accept the cabin slot")


func test_utility_slot_resolution_prefers_tags_then_free_slot() -> void:
	var hub := RegistryHub.new([ContentTypes.MODULE])
	var navigation := _synthetic_module(hub, "test:module/navigation", "utility", ["module.navigation"], {
		"risk_add": -0.01, "speed_mul": 1.0, "reveal_facilities": false,
	})
	var safety := _synthetic_module(hub, "test:module/safety", "utility", ["module.safety"], {
		"risk_add": -0.01, "damage_mul": 1.0, "repair_cost_mul": 1.0,
	})
	var untagged := _synthetic_module(hub, "test:module/untagged", "utility", [], {"risk_add": 0.0})
	var empty_ship := {}
	assert_eq(ModuleOps.slot_for(navigation, empty_ship), "navigation_module", "navigation tag routes to the navigation slot")
	assert_eq(ModuleOps.slot_for(safety, empty_ship), "safety_module", "safety tag routes to the safety slot")
	assert_eq(ModuleOps.slot_for(untagged, empty_ship), "navigation_module", "untagged utility falls back to the first empty slot")
	var navigation_filled := {"navigation_module_id": navigation.id}
	assert_eq(ModuleOps.slot_for(untagged, navigation_filled), "safety_module", "fallback skips an occupied navigation slot")
	var both_filled := {"navigation_module_id": navigation.id, "safety_module_id": safety.id}
	assert_eq(ModuleOps.slot_for(untagged, both_filled), "navigation_module", "both filled falls back to navigation")
	assert_eq(
		ModuleOps.slot_for_with_request(navigation, empty_ship, "safety_module"),
		"safety_module",
		"a drag target overrides the utility tag"
	)
	assert_eq(ModuleOps.slot_for(hub.get_by_id(ContentTypes.MODULE, "test:module/absent")), "", "unknown definition has no slot")


func test_required_category_fields_match_the_merged_schema() -> void:
	var hub := RegistryHub.new([ContentTypes.MODULE])
	var boiler := _synthetic_module(hub, "test:module/boiler", "boiler", ["module.boiler"], {
		"speed_mul": 1.0, "coal_rate": 0.3, "water_rate": 0.2,
	})
	var navigation := _synthetic_module(hub, "test:module/navigation", "utility", ["module.navigation"], {
		"risk_add": -0.01, "speed_mul": 1.0, "reveal_facilities": false,
	})
	var safety := _synthetic_module(hub, "test:module/safety", "utility", ["module.safety"], {
		"risk_add": -0.01, "damage_mul": 1.0, "repair_cost_mul": 1.0,
	})
	assert_eq(ModuleOps.required_fields(boiler), ["speed_mul", "coal_rate", "water_rate"], "boiler fields")
	assert_contains(ModuleOps.required_fields(navigation), "reveal_facilities", "navigation utility fields")
	assert_contains(ModuleOps.required_fields(safety), "repair_cost_mul", "safety utility fields")


func test_new_run_uses_category_modules_in_flat_slots() -> void:
	var fixture := _run_fixture()
	var context: AppContext = fixture["context"]
	var hub := context.registries
	var ship: Dictionary = context.state.ship()
	assert_eq(String(ship["hull_id"]), STEADY_HULL, "hull id unchanged by the module merge")
	assert_eq(String(ship["boiler_id"]), "core:module/small_efficient", "boiler slot holds a boiler category module")
	assert_eq(String(ship["navigation_module_id"]), SPYGLASS, "navigation slot holds a utility module")
	assert_eq(String(ship["safety_module_id"]), LIFEBOAT, "safety slot holds a utility module")
	assert_eq(ShipOps.cargo_module_ids(ship), ["core:module/small_hold"], "cargo slot holds a cargo module")
	assert_eq(ModuleOps.category_of_id(hub, String(ship["boiler_id"])), "boiler", "flat boiler slot is category-consistent")
	assert_eq(ModuleOps.category_of_id(hub, String(ship["navigation_module_id"])), "utility", "flat navigation slot is category-consistent")
	assert_true(bool(context.state.ship()["module_instances"].has("navigation")), "module_instances keep the navigation slot key")
	assert_true(int(ShipOps.cargo_capacity(hub, ship)) > 0.0, "cargo capacity resolves through the merged module type")
	assert_true(float(ShipOps.stats(hub, ship)["speed"]) > 0.0, "ship stats resolve boiler + hull")


func test_installing_utility_modules_routes_by_tag_and_drag_slot() -> void:
	var fixture := _run_fixture(6402)
	var context: AppContext = fixture["context"]
	var hub := context.registries
	var port_id := String(context.state.current_port_id())
	WarehouseOps.add_module(context.state, port_id, CHART_ROOM, 1)
	WarehouseOps.add_module(context.state, port_id, SAFETY_VALVE, 1)
	# main_04 unlocks the safety valve; grant it directly so the routing assertions
	# stay about category slots, not contract progression.
	(context.state.player()["unlocks"] as Array).append(SAFETY_VALVE)
	# Free coal/water weight so replacing a light navigation module with a heavier
	# chart room exercises slot routing instead of the (also valid) weight blocker.
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 0.0
	var chart := context.commands.execute(&"ship.install_module", {
		"module_id": CHART_ROOM,
		"source": "warehouse",
	})
	assert_true(bool(chart.get("ok", false)), "chart room installs: %s" % str(chart))
	assert_eq(String(context.state.ship()["navigation_module_id"]), CHART_ROOM, "navigation tag routes into the navigation slot")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, SPYGLASS), 1, "the replaced navigation module goes to the warehouse")
	var valve := context.commands.execute(&"ship.install_module", {
		"module_id": SAFETY_VALVE,
		"source": "warehouse",
	})
	assert_true(bool(valve.get("ok", false)), "safety valve installs: %s" % str(valve))
	assert_eq(String(context.state.ship()["safety_module_id"]), SAFETY_VALVE, "safety tag routes into the safety slot")
	WarehouseOps.add_module(context.state, port_id, SPYGLASS, 1)
	var dragged := context.commands.execute(&"ship.install_module", {
		"module_id": SPYGLASS,
		"source": "warehouse",
		"slot": "safety_module",
	})
	assert_true(bool(dragged.get("ok", false)), "drag target install succeeds: %s" % str(dragged))
	assert_eq(String(context.state.ship()["safety_module_id"]), SPYGLASS, "explicit drag target overrides the utility tag")
	assert_eq(String(context.state.ship()["navigation_module_id"]), CHART_ROOM, "the other utility slot is untouched")
	assert_eq(String(dragged["data"]["category"]), "utility", "install result reports the category")
	assert_eq(String(dragged["data"]["content_type"]), "modules", "install result reports the merged type")
	var uninstall := context.commands.execute(&"ship.uninstall_module", {"module_id": SPYGLASS})
	assert_true(bool(uninstall.get("ok", false)), "utility modules can be uninstalled")
	assert_eq(String(context.state.ship()["safety_module_id"]), "", "uninstall clears the safety slot")
	assert_true(String(context.state.ship()["navigation_module_id"]) == CHART_ROOM, "uninstall leaves the navigation slot intact")
	assert_true(ModuleOps.category_of_id(hub, String(uninstall["data"]["module_id"])) == "utility", "uninstall reports a utility module")


func test_craft_ops_accepts_hulls_and_merged_modules() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub := context.registries
	assert_true(CraftOps.craftable(hub, STANDARD_BOILER), "boiler module recipe is craftable")
	assert_true(CraftOps.craftable(hub, SPYGLASS), "utility module recipe is craftable")
	assert_true(CraftOps.craftable(hub, STEADY_HULL), "hull recipe is still craftable")
	assert_eq(CraftOps.craft_cost(hub, STANDARD_BOILER), 290, "boiler craft cost reads from the merged definition")
	assert_eq(CraftOps.craft_definition(hub, SPYGLASS).content_type, ContentTypes.MODULE, "module recipe resolves the merged type")
	assert_eq(CraftOps.craft_definition(hub, STEADY_HULL).content_type, ContentTypes.HULL, "hull recipe resolves the hull type")


func test_cross_reference_validator_checks_category_blocks() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub := RegistryHub.new()
	for content_type in ContentTypes.all():
		for definition in context.registries.get_all(content_type):
			hub.register(definition)
	_synthetic_module(hub, "test:module/broken_boiler", "boiler", ["module.boiler"], {})
	_synthetic_module(hub, "test:module/unknown_category", "crew", [], {})
	var result := CrossReferenceValidator.new().validate(hub)
	var boiler_codes := []
	for entry in result["errors"]:
		if String(entry.get("definition_id", "")) == "test:module/broken_boiler":
			boiler_codes.append(String(entry.get("code", "")))
	assert_eq(boiler_codes.count("module_category_field"), 3, "missing boiler fields report three category errors")
	var category_codes := []
	for entry in result["errors"]:
		if String(entry.get("definition_id", "")) == "test:module/unknown_category":
			category_codes.append(String(entry.get("code", "")))
	assert_eq(category_codes, ["module_category_unknown"], "reserved crew category has no runtime consumer")
