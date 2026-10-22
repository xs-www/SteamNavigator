extends TestCase
## @static-doc
## 作用：Phase B Core 完整性规则（WORLD_SCHEMA_V2_RUNTIME §5.2/§5.3）测试：用最小可运行的
## 1.0 合成基线 + 注入的 2.0 世界/战役定义驱动 `CoreCompletenessChecker.check()`，覆盖
## presence gate、5 个硬性数量下限、4 个建议 warning、start_profile 组合解析与 capability 白名单。
##
## ## 契约与约束
## - v2 规则只在 **Core 自己** 发布至少一个 `world_profiles` 定义时启用。B4 落盘后
##   `dev_mods/core/content/world_profiles.json` 存在，Core 基线用例因此改为「gate 打开且零
##   error」；「gate 关闭」的语义仍由 `_full_hub([ContentTypes.WORLD_PROFILE])` 的合成用例覆盖。
## - 硬性 error（`content_count`）：world_profiles / map_configs / start_profiles /
##   weather_profiles / regions 各 ≥1。
## - 建议 warning（`content_count_recommended`）：route_templates / factions / sites / discoveries 各 ≥1。
## - 组合规则：start_profile 必须解析 world_profile + map_config（缺省引用回退到唯一 map config）+
##   starting_scenario；start_region_tags 至少匹配一个 regions.region_tags；map config 的
##   archetypes 数量 ≥ world_profile.port_count。
## - `content.world.v1` / `content.campaign.v1` 在 `AppContext.KNOWN_CAPABILITIES` 中，声明它们的
##   manifest 不会被 dependency_resolver 以 unsupported capability 禁用。
## @end-static-doc

const WORLD_PROFILE_ID := "core:world_profile/default_world"
const MAP_CONFIG_ID := "core:map_config/standard"
const REGION_ID := "core:region/coastal"
const WEATHER_PROFILE_ID := "core:weather_profile/temperate"
const START_PROFILE_ID := "core:start_profile/standard"
const STARTING_BUILD_ID := "core:starting_scenario/standard"
const STANDARD_HULL_ID := "core:hull/standard"
const STANDARD_BOILER_ID := "core:module/standard_boiler"
const SECOND_BOILER_ID := "core:module/second_boiler"
const STANDARD_CARGO_ID := "core:module/standard_cargo"


func test_bootstrapped_core_baseline_is_ok_with_phase_b() -> void:
	# B4 ships the nine Schema 2.0 core content files, so the Phase B presence gate is open
	# on the real core mod: bootstrap must stay `ok` with no completeness/combination error.
	var boot := bootstrap_core()
	var report: StartupReport = boot["report"]
	var context: AppContext = boot["context"]
	assert_eq(report.status_name(), "ok", "Core-only bootstrap is OK after B4: %s" % report.format_text())
	assert_true(report.errors.is_empty(), "B4 Core satisfies the Phase B completeness gate: %s" % report.format_text())
	assert_eq(
		context.registries.get_all(ContentTypes.WORLD_PROFILE).size(),
		1,
		"B4 ships core:world_profile/default_world, which opens the Phase B gate"
	)
	for content_type in [
		ContentTypes.MAP_CONFIG,
		ContentTypes.START_PROFILE,
		ContentTypes.WEATHER_PROFILE,
		ContentTypes.REGION,
	]:
		assert_true(
			context.registries.get_all(content_type).size() >= 1,
			"B4 Core ships at least one '%s' definition" % content_type
		)
	for forbidden_code in [
		"content_count",
		"no_resolvable_start_profile",
		"start_profile_world_profile_missing",
		"start_profile_map_config_missing",
		"start_profile_starting_scenario_missing",
		"map_config_archetypes_short",
		"start_region_unmatched",
	]:
		for error in report.errors:
			assert_ne(
				String(error.get("code", "")),
				forbidden_code,
				"B4 Core raises no '%s' error" % forbidden_code
			)


func test_gate_is_off_without_world_profiles() -> void:
	# Other v2 types exist but `world_profiles` does not: the whole Phase B block stays dormant.
	var hub := _full_hub([ContentTypes.WORLD_PROFILE])
	var result := _check(hub)
	assert_true(result["errors"].is_empty(), "no Phase B error without world profiles: %s" % str(result["errors"]))
	assert_true(result["warnings"].is_empty(), "no Phase B warning without world profiles")


func test_third_party_world_profile_does_not_enable_core_rules() -> void:
	# A third-party v2 world profile alone must not demand Core content before B4:
	# the gate opens only when the `core` pack itself ships world_profiles.
	var hub := _baseline_hub()
	_register(hub, ContentTypes.WORLD_PROFILE, "thirdparty:world_profile/loose", [], {
		"region_count": 2,
		"sites_per_region": 3,
		"port_count": 2,
		"start_region_tags": ["region.start"],
	}, "thirdparty")
	var result := _check(hub)
	assert_true(result["errors"].is_empty(), "third-party-only v2 content leaves Core unchanged: %s" % str(result["errors"]))
	assert_true(result["warnings"].is_empty(), "third-party-only v2 content adds no Core warnings")


func test_missing_map_config_reports_error() -> void:
	var result := _check(_full_hub([ContentTypes.MAP_CONFIG]))
	assert_true(_has_error(result, "content_count"), "missing map configs raise content_count")
	assert_true(_has_error_message(result, "map configs"), "content_count names map configs")
	assert_true(_has_error(result, "start_profile_map_config_missing"), "start profile reports its unresolvable map config")


func test_missing_start_profile_reports_error() -> void:
	var result := _check(_full_hub([ContentTypes.START_PROFILE]))
	assert_true(_has_error_message(result, "start profiles"), "missing start profiles raise content_count")
	assert_true(_has_error(result, "no_resolvable_start_profile"), "no start profile is resolvable")


func test_missing_weather_profile_reports_error() -> void:
	var result := _check(_full_hub([ContentTypes.WEATHER_PROFILE]))
	assert_true(_has_error_message(result, "weather profiles"), "missing weather profiles raise content_count")


func test_missing_region_reports_error() -> void:
	var result := _check(_full_hub([ContentTypes.REGION]))
	assert_true(_has_error_message(result, "regions"), "missing regions raise content_count")
	assert_true(_has_error(result, "start_region_unmatched"), "start region tags cannot match any region")


func test_complete_phase_b_content_has_no_errors() -> void:
	var result := _check(_full_hub())
	assert_true(result["errors"].is_empty(), "complete v2 combination is clean: %s" % str(result["errors"]))
	assert_true(result["warnings"].is_empty(), "complete v2 combination has no suggestion warnings: %s" % str(result["warnings"]))


func test_core_requires_combat_content_counts() -> void:
	var result := _check(_full_hub([ContentTypes.ENEMY_ARCHETYPE]))
	assert_true(_has_error_message(result, "enemy archetypes"), "missing enemy archetypes raise content_count")
	result = _check(_full_hub([ContentTypes.WEAPON]))
	assert_true(_has_error_message(result, "weapons"), "missing weapons raise content_count")


func test_core_requires_at_least_one_quest() -> void:
	var result := _check(_full_hub([ContentTypes.QUEST]))
	assert_true(_has_error(result, "content_count"), "missing quests raise content_count")
	assert_true(_has_error_message(result, "quests"), "content_count names quests")
	assert_true(_has_error(result, "content_count"), "a Core without quests is incomplete")


func test_phase_b_capabilities_include_quests() -> void:
	assert_contains(AppContext.KNOWN_CAPABILITIES, "content.quests.v1", "quests capability is known (C3)")


func test_suggested_content_is_warning_only() -> void:
	var result := _check(_full_hub([
		ContentTypes.ROUTE_TEMPLATE,
		ContentTypes.FACTION,
		ContentTypes.SITE,
		ContentTypes.DISCOVERY,
	]))
	assert_true(result["errors"].is_empty(), "recommended-but-missing content is not an error: %s" % str(result["errors"]))
	for label in ["route templates", "factions", "sites", "discoveries"]:
		assert_true(
			_has_warning_message(result, label),
			"missing %s is reported as a warning" % label
		)
	assert_eq(result["warnings"].size(), 4, "exactly the four suggestion warnings fire")


func test_map_config_needs_at_least_port_count_archetypes() -> void:
	var result := _check(_full_hub([], 4))
	assert_true(
		_has_error(result, "map_config_archetypes_short"),
		"map config with fewer archetypes than port_count is an error"
	)


func test_start_region_tags_must_match_a_region() -> void:
	var result := _check(_full_hub([], 5, ["region.other"]))
	assert_true(
		_has_error(result, "start_region_unmatched"),
		"start_region_tags without a matching regions.region_tags entry is an error"
	)


func test_start_profile_must_resolve_starting_scenario() -> void:
	var result := _check(_full_hub([], 5, ["region.start"], "core:starting_scenario/missing"))
	assert_true(
		_has_error(result, "start_profile_starting_scenario_missing"),
		"start profile with a dangling starting_scenario is reported"
	)
	assert_true(_has_error(result, "no_resolvable_start_profile"), "a dangling build leaves no resolvable start profile")


func test_phase_b_capabilities_are_whitelisted() -> void:
	assert_contains(AppContext.KNOWN_CAPABILITIES, "content.world.v1", "world capability is known")
	assert_contains(AppContext.KNOWN_CAPABILITIES, "content.campaign.v1", "campaign capability is known")
	assert_contains(AppContext.KNOWN_CAPABILITIES, "content.contract.passenger.v1", "existing capabilities stay whitelisted")
	assert_contains(AppContext.KNOWN_CAPABILITIES, "content.event.choice_pool.v1", "existing capabilities stay whitelisted")
	var manifest := ModManifest.from_dict({
		"id": "worldmod",
		"name": "World Mod",
		"version": "1.0.0",
		"api_version": "1.0",
		"content": ["content/world_profiles.json"],
		"capabilities": ["content.world.v1", "content.campaign.v1"],
	})
	assert_true(manifest.errors.is_empty(), "test manifest is well formed: %s" % str(manifest.errors))
	assert_empty(
		manifest.has_capabilities(_known_capabilities()),
		"declared v2 capabilities are not missing, so dependency_resolver keeps the mod enabled"
	)


func _known_capabilities() -> PackedStringArray:
	var known := PackedStringArray()
	for capability in AppContext.KNOWN_CAPABILITIES:
		known.append(String(capability))
	return known


func _check(hub: RegistryHub) -> Dictionary:
	var manifest := ModManifest.new()
	manifest.id = "core"
	manifest.required = true
	var package := ModPackage.new()
	package.id = "core"
	package.manifest = manifest
	var packages := {"core": package}
	var order: Array[String] = ["core"]
	return CoreCompletenessChecker.check(hub, packages, order)


func _full_hub(
	skip: Array = [],
	archetype_count: int = 5,
	region_tags: Array = ["region.start"],
	starting_scenario_id: String = STARTING_BUILD_ID
) -> RegistryHub:
	var hub := _baseline_hub(skip)
	if not skip.has(ContentTypes.WEATHER_PROFILE):
		_register(hub, ContentTypes.WEATHER_PROFILE, WEATHER_PROFILE_ID)
	if not skip.has(ContentTypes.REGION):
		_register(hub, ContentTypes.REGION, REGION_ID, [], {
			"kind": "coastal",
			"size": "medium",
			"port_density": 0.5,
			"site_density": 0.5,
			"weather_profile": WEATHER_PROFILE_ID,
			"region_tags": region_tags,
		})
	if not skip.has(ContentTypes.WORLD_PROFILE):
		_register(hub, ContentTypes.WORLD_PROFILE, WORLD_PROFILE_ID, [], {
			"region_count": 5,
			"sites_per_region": 6,
			"port_count": 5,
			"ruin_density": 0.2,
			"base_site_count": 2,
			"faction_count": 3,
			"weather_profile": WEATHER_PROFILE_ID,
			"start_region_tags": ["region.start"],
		})
	if not skip.has(ContentTypes.MAP_CONFIG):
		var archetypes: Array = []
		for index in range(archetype_count):
			archetypes.append("core:port_template/type_%d" % index)
		_register(hub, ContentTypes.MAP_CONFIG, MAP_CONFIG_ID, [], {
			"archetypes": archetypes,
			"port_name_keys": ["port.name.alpha", "port.name.beta", "port.name.gamma", "port.name.delta"],
			"required_facility_tags": ["port.market"],
		})
	if not skip.has(ContentTypes.START_PROFILE):
		_register(hub, ContentTypes.START_PROFILE, START_PROFILE_ID, [], {
			"world_profile": WORLD_PROFILE_ID,
			"map_config": MAP_CONFIG_ID,
			"starting_scenario": starting_scenario_id,
			"difficulty": "standard",
			"starting_port_tags": ["port.start"],
		})
	if not skip.has(ContentTypes.ROUTE_TEMPLATE):
		_register(hub, ContentTypes.ROUTE_TEMPLATE, "core:route_template/sea_lane")
	if not skip.has(ContentTypes.FACTION):
		_register(hub, ContentTypes.FACTION, "core:faction/merchant_guild")
	if not skip.has(ContentTypes.SITE):
		_register(hub, ContentTypes.SITE, "core:site/ruin")
	if not skip.has(ContentTypes.DISCOVERY):
		_register(hub, ContentTypes.DISCOVERY, "core:discovery/blueprint")
	return hub


## Minimal 2.0 content the baseline checks need; keeps every rule
## satisfied so v2 assertions are not polluted by legacy errors. `skip` may remove
## a baseline type so a missing-content rule can be exercised.
func _baseline_hub(skip: Array = []) -> RegistryHub:
	var hub := RegistryHub.new(ContentTypes.all())
	_register(hub, ContentTypes.ITEM, "core:item/coal")
	_register(hub, ContentTypes.HULL, STANDARD_HULL_ID, ["module.large"], {"tier": 1})
	_register(hub, ContentTypes.HULL, "core:hull/second", [], {"tier": 1})
	_register(hub, ContentTypes.HULL, "core:hull/third", [], {"tier": 1})
	_register(hub, ContentTypes.MODULE, STANDARD_BOILER_ID, ["module.boiler"], {
		"tier": 1, "v2_category": "boiler", "speed_mul": 1.0, "coal_rate": 0.3, "water_rate": 0.2,
	})
	_register(hub, ContentTypes.MODULE, SECOND_BOILER_ID, ["module.boiler"], {
		"tier": 1, "v2_category": "boiler", "speed_mul": 1.1, "coal_rate": 0.35, "water_rate": 0.22,
	})
	_register(hub, ContentTypes.MODULE, STANDARD_CARGO_ID, ["module.cargo"], {
		"tier": 1, "v2_category": "cargo", "capacity": 10.0,
	})
	_register(hub, ContentTypes.BOILER_STRATEGY, "core:boiler_strategy/economy", ["strategy.economy"])
	_register(hub, ContentTypes.BOILER_STRATEGY, "core:boiler_strategy/standard", ["strategy.standard"])
	_register(hub, ContentTypes.BOILER_STRATEGY, "core:boiler_strategy/fast", ["strategy.fast"])
	for index in range(4):
		_register(hub, ContentTypes.PORT_TEMPLATE, "core:port_template/type_%d" % index)
	_register(hub, ContentTypes.STARTING_SCENARIO, STARTING_BUILD_ID, [], {
		"hull": STANDARD_HULL_ID,
		"boiler": STANDARD_BOILER_ID,
		"cargo_modules": [STANDARD_CARGO_ID],
	})
	for sequence in range(1, 6):
		_register(hub, ContentTypes.CONTRACT, "core:contract/main_%02d" % sequence, [], {
			"kind": "main",
			"sequence": sequence,
		})
	_register(hub, ContentTypes.VOYAGE_EVENT, "core:voyage_event/risk", ["event.risk"])
	_register(hub, ContentTypes.VOYAGE_EVENT, "core:voyage_event/quiet")
	_register(hub, ContentTypes.CREW_ROLE, "core:crew_role/engineer", ["role.engineer"])
	_register(hub, ContentTypes.CREW_ROLE, "core:crew_role/navigator", ["role.navigator"])
	# D1 combat minimums (skippable so the missing-content rules stay testable).
	if not skip.has(ContentTypes.DAMAGE_TYPE):
		_register(hub, ContentTypes.DAMAGE_TYPE, "core:damage_type/kinetic", [], {"color": "#ffd37a"})
	if not skip.has(ContentTypes.COMBAT_ABILITY):
		_register(hub, ContentTypes.COMBAT_ABILITY, "core:combat_ability/aggressive", [], {"action": "engage"})
	if not skip.has(ContentTypes.WEAPON):
		_register(hub, ContentTypes.WEAPON, "core:weapon/deck_gun")
	if not skip.has(ContentTypes.LOOT_TABLE):
		_register(hub, ContentTypes.LOOT_TABLE, "core:loot_table/wreck", [], {"entries": []})
	if not skip.has(ContentTypes.ENCOUNTER_TABLE):
		_register(hub, ContentTypes.ENCOUNTER_TABLE, "core:encounter_table/patrol", [], {"entries": []})
	if not skip.has(ContentTypes.ENEMY_ARCHETYPE):
		for index in range(4):
			_register(hub, ContentTypes.ENEMY_ARCHETYPE, "core:enemy_archetype/enemy_%d" % index)
	if not skip.has(ContentTypes.QUEST):
		_register(hub, ContentTypes.QUEST, "core:quest/guide", ["quest.guide"], {
			"kind": "guide",
			"auto_start": false,
			"stages": [{
				"id": "one",
				"title_key": "test.quest.title",
				"objectives": [{"event": "cmd:test.one"}],
			}],
		})
	return hub


func _register(
	hub: RegistryHub,
	content_type: StringName,
	id: String,
	tags: Array = [],
	data: Dictionary = {},
	source_mod: String = "core"
) -> ContentDefinition:
	var definition := ContentDefinition.from_raw({
		"id": id,
		"name_key": "test.name",
		"enabled": true,
		"tags": tags,
		"data": data,
	}, content_type, source_mod, "content/test.json")
	var result := hub.register(definition, source_mod)
	assert_true(bool(result.get("ok", false)), "synthetic definition '%s' registers" % id)
	return definition


func _has_error(result: Dictionary, code: String) -> bool:
	for entry in result["errors"]:
		if String(entry.get("code", "")) == code:
			return true
	return false


func _has_error_message(result: Dictionary, needle: String) -> bool:
	return _entries_have_message(result["errors"], needle)


func _has_warning_message(result: Dictionary, needle: String) -> bool:
	return _entries_have_message(result["warnings"], needle)


func _entries_have_message(entries: Array, needle: String) -> bool:
	for entry in entries:
		if String(entry.get("message", "")).contains(needle):
			return true
	return false
