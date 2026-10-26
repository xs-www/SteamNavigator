class_name RunFactory
extends RefCounted
## @static-doc
## 作用：开局装配的共享 helper（C4 起不再持有 1.0 `map_profiles` 几何路径）。提供
## `starting_scenarios` 读取与摘要、飞船构造（`create_ship`）、市场初始化
## （`initialize_markets`）以及战役工厂复用的迷雾 / 主线委托 / 种子 helper。
##
## ## 契约与约束
## - **入口**：`run.start` 无 `start_profile` 时统一走
##   `CampaignFactory.create_default_campaign()`（默认 start profile +
##   `starting_scenarios` 选择）；本类不再提供 `create_run()`。
## - **世界生成已迁出本类**（2026-10-26 海图唯一真相）：坐标布局在
##   `CampaignFactory._chart_world_profile`，唯一世界由 `WorldGenerator.generate_chart`
##   生成；本类只保留 `_initialize_world_fog()`（迷雾比例来自
##   `ExplorationRules.fog_radii()`）。
## - 框架永不写死具体 `core:*` 内容 ID：场景 / 世界 / 地图调参全部按注册表类型解析。
## - `create_ship(hub, scenario)` 的字段名保持扁平槽位（hull / boiler / cargo_modules /
##   navigation_module / safety_module / passenger_cabin / engineer / navigator）。
## - 本类不使用 RNG 之外的外部状态；`_random_seed()` 只供 CampaignFactory 在
##   `seed == 0` 时使用。
## @end-static-doc


## All registered `starting_scenarios`, in registry order.
static func available_scenarios(hub: RegistryHub) -> Array[ContentDefinition]:
	return hub.get_all(ContentTypes.STARTING_SCENARIO)


## Lowest-id starting scenario (deterministic default), or null.
static func default_starting_scenario(hub: RegistryHub) -> ContentDefinition:
	var scenarios := available_scenarios(hub)
	if scenarios.is_empty():
		return null
	scenarios.sort_custom(func(left: ContentDefinition, right: ContentDefinition) -> bool:
		return left.id < right.id
	)
	return scenarios[0]


## Menu-facing summaries for the starting-scenario picker.
static func starting_scenario_summaries(hub: RegistryHub) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for scenario in available_scenarios(hub):
		result.append({
			"id": scenario.id,
			"name_key": scenario.name_key,
			"description_key": scenario.description_key,
			"money": int(scenario.data.get("money", 0)),
			"hull": String(scenario.data.get("hull", "")),
			"boiler": String(scenario.data.get("boiler", "")),
			"coal": float(scenario.data.get("coal", 0.0)),
			"water": float(scenario.data.get("water", 0.0)),
		})
	return result


static func create_ship(hub: RegistryHub, scenario: ContentDefinition) -> Dictionary:
	var data: Dictionary = scenario.data
	var hull_id := String(data.get("hull", ""))
	var hull := hub.get_by_id(ContentTypes.HULL, hull_id)
	var max_durability := float(hull.data.get("max_durability", 100.0)) if hull != null else 100.0
	var ratio := float(data.get("durability_ratio", 1.0))
	var ship := {
		"hull_id": hull_id,
		"boiler_id": String(data.get("boiler", "")),
		"cargo_modules": Array(data.get("cargo_modules", [])),
		"navigation_module_id": String(data.get("navigation_module", "")),
		"safety_module_id": String(data.get("safety_module", "")),
		"passenger_cabin_id": String(data.get("passenger_cabin", "")),
		"engineer_id": String(data.get("engineer", "")),
		"navigator_id": String(data.get("navigator", "")),
		"durability": max_durability * clampf(ratio, 0.1, 1.0),
		"coal": float(data.get("coal", 0.0)),
		"water": float(data.get("water", 0.0)),
		"cargo": [],
	}
	ShipModules.ensure(ship)
	return ship


## Seeds the single chart world's fog: coastal band marked, the starting harbour
## revealed (lamp flower) and ship vision applied at the berth. Radii follow the
## content fog ratios (`ExplorationRules.fog_radii`), not fixed world units.
static func _initialize_world_fog(state: GameState, start_port_id: String, hub: RegistryHub) -> void:
	var world := WorldOps.world_map(state)
	var start_port := world.get_port(start_port_id)
	if start_port.is_empty():
		return
	var radii := ExplorationRules.fog_radii(state, hub, world)
	var vision_radius := float(radii.get("vision", FogOps.DEFAULT_MIN_VISION_RADIUS))
	var reveal_radius := float(radii.get("port_reveal", FogOps.DEFAULT_PORT_REVEAL_RADIUS))
	var fog := FogOps.create_fog_grid(world, vision_radius)
	var coastal := FogOps.mark_coastal_cells(fog, world)
	FogOps.reveal_port(fog, start_port, reveal_radius)
	FogOps.update_ship_vision(fog, start_port.position, vision_radius, coastal)
	FogOps.save_fog_state(state, fog, coastal)


## Initializes every port market from the generated world's port templates
## (`port_templates`, C4). Market pricing only depends on the template + RNG, so
## the same generation seed yields the same markets. `scenario` (the resolved
## `map_configs` definition) is accepted so a future per-scenario market tweak has
## one entry point.
static func initialize_markets(state: GameState, hub: RegistryHub, _scenario: ContentDefinition, rng: RngService) -> void:
	var markets := {}
	var ports: Dictionary = state.world().get("ports", {})
	for raw_port_id in ports.keys():
		var port_id := String(raw_port_id)
		var port_data: Dictionary = ports[port_id]
		var port_template := hub.get_by_id(ContentTypes.PORT_TEMPLATE, String(port_data.get("archetype_id", "")))
		if port_template == null:
			continue
		var port_rng := rng.stream(RngService.STREAM_GOODS_GENERATION, port_id)
		markets[port_id] = MarketOps.initialize_port_market(hub, port_template, port_rng)
	state.data["market"] = markets


static func _generate_main_offer(state: GameState, hub: RegistryHub, sequence: int, rng: RngService) -> Dictionary:
	var template := ContractOps.find_template_by_sequence(hub, sequence)
	if template == null:
		return {}
	return ContractOps.generate_offer(state, hub, template, rng, state.current_port_id())


static func _random_seed() -> int:
	return int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())
