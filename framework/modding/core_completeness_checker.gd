class_name CoreCompletenessChecker
extends RefCounted
## Verifies the official content pack provides everything the MVP needs.
##
## This is intentionally about presence and contracts, not balance.
## @static-doc
## 作用：检查官方 core 包是否提供 MVP 所需的最少内容与构筑，并在 Core 自己发布 Content
## Schema 2.0 世界内容后追加 Phase B 完整性规则（WORLD_SCHEMA_V2_RUNTIME §5.2）。
##
## ## 契约与约束
## - 要求 core 存在、required=true 且进入加载顺序。
## - 1.0 基线：最低数量（3 船体、≥2 boiler 模块、≥1 cargo 模块、3 策略、4 港口原型
##   （`port_templates`）、≥1 起始场景（`starting_scenarios`）、5 主线、2 事件、2 岗位、
##   ≥1 quest 等）、必需标签、主线 sequence 1–5、至少一套可解析为
##   hull + boiler 模块 + cargo 模块的初始场景。模块数量按统一 `modules` 类型的
##   `data.v2_category` 切片计数；utility / cabin 不设硬下限。`map_profiles` 已退役，
##   地图调参完整性由 `map_configs` 规则承担。
## - Phase B 规则用 presence gate：**Core 来源**的 `world_profiles` 至少 1 条才启用，保证 B4
##   之前 Core 没有 v2 内容时基线不红，第三方单独提供的 v2 世界内容也不会触发 Core 规则。
## - 硬性：world_profiles / map_configs / start_profiles / weather_profiles / regions 各 ≥1。
## - 建议（warning）：route_templates / factions / sites / discoveries 各 ≥1。
## - 组合：至少一个 start_profile 解析 world_profile + map_config + starting_scenario；##   start_region_tags 命中至少一个 regions.region_tags；map_config.archetypes 数量 ≥
##   对应 world_profile.port_count。
## - D1 战斗家族（weapons / damage_types / combat_abilities / enemy_archetypes /
##   encounter_tables / loot_tables）的最低数量只统计 `source_mod == "core"` 的定义，
##   第三方单独提供的战斗内容不能替代 Core 自己的完整性门槛。
## - D2 舰队家族（ship_archetypes / captains / formations / fleet_doctrines）的
##   最低数量同样只统计 Core 来源；没有舰队内容时启动保持基线，第三方内容不能替代
##   Core 的舰队门槛。引用合法性（hull / modules / weapons / formation / captain
##   可指挥船型 / ship_archetype.weapon_sockets 与 hull socket 名和 class）由
##   `CrossReferenceValidator._check_fleet` 负责硬校验。
## @end-static-doc

static func check(hub: RegistryHub, packages: Dictionary, order: Array[String]) -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var core: Variant = packages.get("core", null)
	if not (core is ModPackage):
		errors.append({"code": "core_missing", "message": "official core mod is not loaded"})
		return {"errors": errors, "warnings": warnings}
	if not core.manifest.required:
		errors.append({"code": "core_not_required", "message": "core manifest must declare required=true"})
	if not order.has("core"):
		errors.append({"code": "core_not_enabled", "message": "core mod is not in the load order"})

	_require_count(hub, ContentTypes.ITEM, 1, "items", errors)
	_require_count(hub, ContentTypes.HULL, 3, "hulls", errors)
	_require_module_category_count(hub, "boiler", 2, "boilers", errors)
	_require_module_category_count(hub, "cargo", 1, "cargo modules", errors)
	_require_count(hub, ContentTypes.BOILER_STRATEGY, 3, "boiler strategies", errors)
	_require_count(hub, ContentTypes.PORT_TEMPLATE, 4, "port templates", errors)
	_require_count(hub, ContentTypes.STARTING_SCENARIO, 1, "starting scenarios", errors)
	_require_count(hub, ContentTypes.CONTRACT, 5, "contracts", errors)
	# C3: the abstraction quest layer ships at least one core quest (guide/system).
	_require_count(hub, ContentTypes.QUEST, 1, "quests", errors)
	_require_count(hub, ContentTypes.VOYAGE_EVENT, 2, "voyage events", errors)
	_require_count(hub, ContentTypes.CREW_ROLE, 2, "crew roles", errors)
	# D1 combat family: at least one weapon/damage type/ability/table, and the four
	# shipped combat_kit enemy archetypes. Counts only definitions owned by the core
	# pack (same source-filter discipline as the Phase B presence gate): a third-party
	# mod shipping combat content must not satisfy Core's own completeness gate.
	_require_core_count(hub, ContentTypes.WEAPON, 1, "weapons", errors)
	_require_core_count(hub, ContentTypes.DAMAGE_TYPE, 1, "damage types", errors)
	_require_core_count(hub, ContentTypes.COMBAT_ABILITY, 1, "combat abilities", errors)
	_require_core_count(hub, ContentTypes.ENEMY_ARCHETYPE, 4, "enemy archetypes", errors)
	_require_core_count(hub, ContentTypes.ENCOUNTER_TABLE, 1, "encounter tables", errors)
	_require_core_count(hub, ContentTypes.LOOT_TABLE, 1, "loot tables", errors)
	# D2 fleet family minimums.
	_require_core_count(hub, ContentTypes.SHIP_ARCHETYPE, 1, "ship archetypes", errors)
	_require_core_count(hub, ContentTypes.CAPTAIN, 1, "captains", errors)
	_require_core_count(hub, ContentTypes.FORMATION, 1, "formations", errors)
	_require_core_count(hub, ContentTypes.FLEET_DOCTRINE, 1, "fleet doctrines", errors)
	# D3 base family minimums + a production chain reaching shipbuilding material.
	_require_core_count(hub, ContentTypes.BASE_SITE, 1, "base sites", errors)
	_require_core_count(hub, ContentTypes.BUILDING, 3, "buildings", errors)
	_require_core_count(hub, ContentTypes.BUILDING_UPGRADE, 3, "building upgrades", errors)
	_require_core_count(hub, ContentTypes.PRODUCTION_RECIPE, 2, "production recipes", errors)
	_require_core_count(hub, ContentTypes.WORKER_ROLE, 2, "worker roles", errors)
	var base_chain_ok := false
	for recipe in hub.get_all(ContentTypes.PRODUCTION_RECIPE):
		if String(recipe.source_mod) != "core":
			continue
		for stack in recipe.data.get("outputs", []):
			if not (stack is Dictionary):
				continue
			var output := hub.get_by_id(ContentTypes.ITEM, String((stack as Dictionary).get("item", "")))
			if output != null and output.tags.has("material.shipbuilding"):
				base_chain_ok = true
				break
		if base_chain_ok:
			break
	if not base_chain_ok:
		errors.append({
			"code": "base_production_chain_missing",
			"message": "core has no production recipe whose output is tagged material.shipbuilding",
		})

	for required_tag in ["strategy.economy", "strategy.standard", "strategy.fast"]:
		if hub.query(ContentTypes.BOILER_STRATEGY, [required_tag]).is_empty():
			errors.append({"code": "strategy_tag_missing", "message": "no strategy with tag '%s'" % required_tag})
	if hub.query(ContentTypes.HULL, ["module.large"]).is_empty():
		errors.append({"code": "large_hull_missing", "message": "no large hull is available for the finale reward"})
	if hub.query(ContentTypes.CREW_ROLE, ["role.engineer"]).is_empty():
		errors.append({"code": "engineer_missing", "message": "no engineer role is available"})
	if hub.query(ContentTypes.CREW_ROLE, ["role.navigator"]).is_empty():
		errors.append({"code": "navigator_missing", "message": "no navigator role is available"})
	if hub.query(ContentTypes.VOYAGE_EVENT, ["event.risk"]).is_empty():
		errors.append({"code": "risk_events_missing", "message": "no voyage risk event is tagged event.risk"})

	var sequences: Dictionary = {}
	for contract in hub.get_all(ContentTypes.CONTRACT):
		if String(contract.data.get("kind", "")) == "main":
			sequences[int(contract.data.get("sequence", 0))] = contract.id
	for sequence in range(1, 6):
		if not sequences.has(sequence):
			errors.append({"code": "main_sequence_missing", "message": "main contract sequence %d is missing" % sequence})

	var ships: Array = []
	for build in hub.get_all(ContentTypes.STARTING_SCENARIO):
		var hull := hub.get_by_id(ContentTypes.HULL, String(build.data.get("hull", "")))
		var boiler_id := String(build.data.get("boiler", ""))
		var boiler := ModuleOps.get_by_id(hub, boiler_id)
		var has_boiler := boiler != null and ModuleOps.category_of(boiler) == "boiler"
		var cargo_modules: Array = build.data.get("cargo_modules", [])
		var has_cargo := false
		for module_id in cargo_modules:
			var cargo := ModuleOps.get_by_id(hub, String(module_id))
			if cargo != null and ModuleOps.category_of(cargo) == "cargo":
				has_cargo = true
		if hull != null and has_boiler and has_cargo:
			ships.append(build.id)
		else:
			warnings.append({
				"code": "starting_scenario_incomplete",
				"message": "starting scenario '%s' does not resolve to hull + boiler + cargo" % build.id,
			})
	if ships.is_empty():
		errors.append({"code": "no_runnable_starting_scenario", "message": "no starting scenario resolves to a runnable ship"})

	for content_type in [ContentTypes.HULL, ContentTypes.MODULE]:
		for module in hub.get_all(content_type):
			if int(module.data.get("tier", 0)) > 3:
				warnings.append({
					"code": "tier_out_of_range",
					"message": "%s has tier %d; MVP expects 1-3" % [module.id, int(module.data.get("tier", 0))],
				})

	_check_phase_b(hub, errors, warnings)
	return {"errors": errors, "warnings": warnings}


static func _require_count(hub: RegistryHub, content_type: StringName, minimum: int, label: String, errors: Array[Dictionary]) -> void:
	if hub.get_all(content_type).size() < minimum:
		errors.append({
			"code": "content_count",
			"message": "core must declare at least %d %s (found %d)" % [
				minimum, label, hub.get_all(content_type).size()
			],
		})


## Number of definitions of `content_type` shipped by the `core` pack itself.
static func _core_count(hub: RegistryHub, content_type: StringName) -> int:
	var count := 0
	for definition in hub.get_all(content_type):
		if definition.source_mod == "core":
			count += 1
	return count


## Like `_require_count`, but ignores third-party definitions: these minimums are
## about what the official pack must provide, not what is globally available.
static func _require_core_count(hub: RegistryHub, content_type: StringName, minimum: int, label: String, errors: Array[Dictionary]) -> void:
	var found := _core_count(hub, content_type)
	if found < minimum:
		errors.append({
			"code": "content_count",
			"message": "core must declare at least %d %s (found %d)" % [minimum, label, found],
		})


## Unified `modules` type count sliced by `data.v2_category`.
static func _require_module_category_count(hub: RegistryHub, category: String, minimum: int, label: String, errors: Array[Dictionary]) -> void:
	var found := ModuleOps.count(hub, category)
	if found < minimum:
		errors.append({
			"code": "content_count",
			"message": "core must declare at least %d %s (found %d)" % [minimum, label, found],
		})


static func _recommend_count(hub: RegistryHub, content_type: StringName, minimum: int, label: String, warnings: Array[Dictionary]) -> void:
	if hub.get_all(content_type).size() < minimum:
		warnings.append({
			"code": "content_count_recommended",
			"message": "core should declare at least %d %s (found %d)" % [
				minimum, label, hub.get_all(content_type).size()
			],
		})


## Phase B (Content Schema 2.0) completeness rules.
##
## Gated on the presence of at least one `world_profiles` definition shipped by
## the `core` pack: until the Core content pack ships v2 world content (B4) the
## legacy baseline must stay green, and a third-party v2 world profile alone
## must not impose Core completeness requirements before Core has its own.
static func _check_phase_b(hub: RegistryHub, errors: Array[Dictionary], warnings: Array[Dictionary]) -> void:
	if not _core_ships_world_profiles(hub):
		return
	_require_count(hub, ContentTypes.WORLD_PROFILE, 1, "world profiles", errors)
	_require_count(hub, ContentTypes.MAP_CONFIG, 1, "map configs", errors)
	_require_count(hub, ContentTypes.START_PROFILE, 1, "start profiles", errors)
	_require_count(hub, ContentTypes.WEATHER_PROFILE, 1, "weather profiles", errors)
	_require_count(hub, ContentTypes.REGION, 1, "regions", errors)

	_recommend_count(hub, ContentTypes.ROUTE_TEMPLATE, 1, "route templates", warnings)
	_recommend_count(hub, ContentTypes.FACTION, 1, "factions", warnings)
	_recommend_count(hub, ContentTypes.SITE, 1, "sites", warnings)
	_recommend_count(hub, ContentTypes.DISCOVERY, 1, "discoveries", warnings)

	_check_phase_b_combinations(hub, errors)


## Presence gate for the Phase B block: only Core's own v2 world content turns
## the completeness rules on (B4). Third-party world profiles alone stay inert.
static func _core_ships_world_profiles(hub: RegistryHub) -> bool:
	for definition in hub.get_all(ContentTypes.WORLD_PROFILE):
		if definition.source_mod == "core":
			return true
	return false


## Cross-type combination rules for the v2 campaign start:
## a start profile must resolve world profile + map config + starting build,
## its start region tags must match a region, and the map config must provide
## at least as many port archetypes as the world profile declares ports.
static func _check_phase_b_combinations(hub: RegistryHub, errors: Array[Dictionary]) -> void:
	var start_profiles := hub.get_all(ContentTypes.START_PROFILE)
	start_profiles.sort_custom(func(a: ContentDefinition, b: ContentDefinition) -> bool: return a.id < b.id)
	var resolved: Array[Dictionary] = []
	for start_profile in start_profiles:
		var world_profile_id := String(start_profile.data.get("world_profile", ""))
		var world_profile := hub.get_by_id(ContentTypes.WORLD_PROFILE, world_profile_id)
		if world_profile == null:
			errors.append({
				"code": "start_profile_world_profile_missing",
				"message": "start profile '%s' references missing world profile '%s'" % [start_profile.id, world_profile_id],
			})
			continue
		var map_config := _resolve_start_map_config(hub, start_profile)
		if map_config == null:
			errors.append({
				"code": "start_profile_map_config_missing",
				"message": "start profile '%s' declares no resolvable map config" % start_profile.id,
			})
			continue
		var starting_scenario_id := String(start_profile.data.get("starting_scenario", ""))
		if not hub.contains(ContentTypes.STARTING_SCENARIO, starting_scenario_id):
			errors.append({
				"code": "start_profile_starting_scenario_missing",
				"message": "start profile '%s' references missing starting scenario '%s'" % [start_profile.id, starting_scenario_id],
			})
			continue
		resolved.append({
			"world_profile": world_profile,
			"map_config": map_config,
		})

	if resolved.is_empty():
		errors.append({
			"code": "no_resolvable_start_profile",
			"message": "no start profile resolves to world_profile + map_config + starting_scenario",
		})
		return

	if not _has_matching_start_region(hub, resolved):
		errors.append({
			"code": "start_region_unmatched",
			"message": "no resolved world profile start_region_tags match a regions.region_tags entry",
		})

	for combination in resolved:
		var map_config: ContentDefinition = combination["map_config"]
		var world_profile: ContentDefinition = combination["world_profile"]
		var archetypes: Variant = map_config.data.get("archetypes", [])
		var archetype_count: int = archetypes.size() if archetypes is Array else 0
		var port_count := int(world_profile.data.get("port_count", 0))
		if port_count > 0 and archetype_count < port_count:
			errors.append({
				"code": "map_config_archetypes_short",
				"message": "map config '%s' declares %d archetypes but world profile '%s' needs %d ports" % [
					map_config.id, archetype_count, world_profile.id, port_count
				],
			})


## Resolves the map config a start profile points at, falling back to the only
## registered map config when the optional reference is omitted (contract §4.2:
## core content must provide one, third-party content may omit it).
static func _resolve_start_map_config(hub: RegistryHub, start_profile: ContentDefinition) -> ContentDefinition:
	var map_config_id := String(start_profile.data.get("map_config", ""))
	if not map_config_id.is_empty():
		return hub.get_by_id(ContentTypes.MAP_CONFIG, map_config_id)
	var candidates := hub.get_all(ContentTypes.MAP_CONFIG)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: ContentDefinition, b: ContentDefinition) -> bool: return a.id < b.id)
	return candidates[0]


static func _has_matching_start_region(hub: RegistryHub, resolved: Array[Dictionary]) -> bool:
	var region_tags: Dictionary = {}
	for region in hub.get_all(ContentTypes.REGION):
		for tag in region.data.get("region_tags", []):
			region_tags[String(tag)] = true
	for combination in resolved:
		var world_profile: ContentDefinition = combination["world_profile"]
		for tag in world_profile.data.get("start_region_tags", []):
			if region_tags.has(String(tag)):
				return true
	return false
