extends TestCase


func test_core_loads_cleanly() -> void:
	var boot := bootstrap_core()
	var report: StartupReport = boot["report"]
	assert_true(not report.has_fatal(), "core bootstrap has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "core-only bootstrap is OK")
	assert_true(report.registry_frozen, "registry is frozen after load")
	assert_true(report.disabled_mods.is_empty(), "no mod is disabled")
	assert_eq(report.mods.size(), 1, "one mod loaded")
	assert_eq(String(report.mods[0]["id"]), "core", "loaded mod is core")
	assert_true(report.content_total() >= 45, "core provides a substantial content set")
	assert_eq(int(report.content_counts.get("goods", 0)), 9, "goods count includes coal and water")
	assert_eq(int(report.content_counts.get("hulls", 0)), 4, "hull count")
	assert_eq(int(report.content_counts.get("contracts", 0)), 9, "contract count")


func test_registry_accessible_after_freeze() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	assert_not_null(context.registries.get_by_id(ContentTypes.GOOD, "core:good/iron_ore"), "iron ore is registered")
	assert_not_null(context.registries.get_by_id(ContentTypes.HULL, "core:hull/medium_standard"), "medium hull is registered")
	assert_not_null(context.registries.get_by_id(ContentTypes.CONTRACT, "core:contract/main_05"), "finale contract is registered")
	assert_true(context.commands.has(&"run.start"), "run.start command is registered")
	assert_true(context.queries.has(&"port.view"), "port.view query is registered")
	assert_true(context.localization.has_key("good.core.iron_ore.name"), "localization loaded")
	assert_eq(context.assets.count(), 89, "all Core image and model assets are registered (incl. batch-A/B LOD1 building keys and the three crane props)")
	var coal := context.registries.get_by_id(ContentTypes.GOOD, "core:good/coal")
	assert_eq(String(coal.information.get("texture", "")), "icon.coal", "Core goods expose parsed texture information")
	assert_eq(coal.asset_uri("model"), "asset://core/model.good.coal", "Core goods expose namespaced model URIs")
	assert_true(context.assets.has(coal.asset_uri("texture")), "Core texture URI resolves")
	assert_true(context.assets.has(coal.asset_uri("model")), "Core model URI resolves")
	var hull := context.registries.get_by_id(ContentTypes.HULL, "core:hull/large_efficient")
	assert_eq(hull.asset_uri("model"), "asset://core/model.ship.paddle_freighter", "Core hull model is parsed")
	assert_true(context.assets.has(hull.asset_uri("model")), "Core hull model URI resolves")


func test_starting_builds_are_runnable() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	for build in RunFactory.available_builds(context.registries):
		var ship := RunFactory.create_ship(context.registries, build)
		var validation := ShipOps.validate_configuration(context.registries, ship)
		assert_true(bool(validation["ok"]), "starting build %s is valid: %s" % [build.id, validation["errors"]])
		assert_true(ShipOps.max_weight(context.registries, ship) > 0.0, "starting build %s has a weight limit" % build.id)


func test_third_party_mod_uses_public_api() -> void:
	var boot := bootstrap_core({
		"scan_roots": PackedStringArray(["res://dev_mods", "res://sdk/examples"]),
	})
	var report: StartupReport = boot["report"]
	assert_true(not report.has_fatal(), "third-party load has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "core + example mod loads cleanly")
	assert_true(report.mods.size() >= 2, "example mod is loaded")
	var context: AppContext = boot["context"]
	var boiler := context.registries.get_by_id(ContentTypes.BOILER, "example_boilers:boiler/compound_efficient")
	assert_not_null(boiler, "example boiler is registered through the normal registry")
	assert_eq(context.localization.tr_key(boiler.name_key), "复合式高效锅炉", "example localization is loaded")
