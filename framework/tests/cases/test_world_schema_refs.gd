extends TestCase
## @static-doc
## 作用：Phase B 世界/战役 9 类内容的跨引用校验测试：用真实 Core 基线（`bootstrap_core()`）
## 复制出的临时 `RegistryHub` 注册合成定义，驱动 `CrossReferenceValidator.validate()`，
## 覆盖硬引用缺失 error、planned 目标 `ref_inactive_type` warning、阵营自指
## `reference_self` 与 `map_configs.archetypes` 数量组合规则。
##
## ## 契约与约束
## - 测试不假设 Core 已有 v2 内容（B4 才落盘）；所有 9 类定义都是合成 ID（`test:*`）。
##   基线只借用已存在的定义（contracts / events / starting_scenarios / port_templates 等）
##   让 `validate()` 的既有检查保持干净，从而能对合成定义的 error / warning 做精确断言。
## - 硬引用缺失（`reference_missing`）：world_profiles.weather_profile、regions 的
##   weather_profile / factions[]、factions.trade_goods / rival_factions、discoveries.unlock_ids、
##   start_profiles 的 world_profile / starting_scenario / starting_contract / starting_cargo[].item /
##   map_config、map_configs 的 archetypes / default_starting_scenario。
## - sites 的 ruin_archetype / encounter_table / loot_table、route_templates.encounter_table、
##   factions.contract_family 指向 planned 类型：只出 `ref_inactive_type` warning，不出 error。
## - factions.rival_factions 允许同类型引用，但指向自身报 `reference_self`。
## - `map_configs.archetypes` 数量 < 引用它的 start_profile.world_profile.port_count 时报
##   `map_config_archetype_count`；world_profile 不存在时跳过该组合检查。
## @end-static-doc

const TEST_MOD := "test"
const TEST_FILE := "res://framework/tests/cases/test_world_schema_refs.gd"

static var _baseline_definitions: Dictionary = {}


func _baseline() -> Dictionary:
	if _baseline_definitions.is_empty():
		var boot := bootstrap_core()
		var context: AppContext = boot["context"]
		for content_type in ContentTypes.all():
			_baseline_definitions[content_type] = context.registries.get_all(content_type)
	return _baseline_definitions


func _new_hub() -> RegistryHub:
	## 复制 Core 基线（既有检查保持干净）后供各用例注册合成定义。
	var hub := RegistryHub.new()
	var definitions := _baseline()
	for content_type in definitions.keys():
		for definition in definitions[content_type]:
			hub.register(definition)
	return hub


func _define(hub: RegistryHub, content_type: StringName, definition_id: String, data: Dictionary, tags: Array = []) -> ContentDefinition:
	var raw := {
		"id": definition_id,
		"name_key": "test.%s.name" % definition_id.get_slice("/", 1),
		"enabled": true,
		"tags": tags,
		"data": data,
	}
	var definition := ContentDefinition.from_raw(raw, content_type, TEST_MOD, TEST_FILE)
	var result := hub.register(definition)
	assert_true(bool(result.get("ok", false)), "synthetic definition %s registers: %s" % [definition_id, result])
	return definition


func _result(hub: RegistryHub) -> Dictionary:
	return CrossReferenceValidator.new().validate(hub)


func _entries_for(entries: Array, definition_id: String) -> Array:
	var matches := []
	for entry in entries:
		if String(entry.get("definition_id", "")) == definition_id:
			matches.append(entry)
	return matches


func _errors_for(result: Dictionary, definition_id: String) -> Array:
	return _entries_for(result["errors"], definition_id)


func _warnings_for(result: Dictionary, definition_id: String) -> Array:
	return _entries_for(result["warnings"], definition_id)


func _codes(entries: Array) -> Array:
	var codes := []
	for entry in entries:
		codes.append(String(entry.get("code", "")))
	return codes


func _count_code(entries: Array, code: String) -> int:
	var count := 0
	for entry in entries:
		if String(entry.get("code", "")) == code:
			count += 1
	return count


func _weather_profile(hub: RegistryHub, definition_id: String = "test:weather/temperate") -> void:
	_define(hub, ContentTypes.WEATHER_PROFILE, definition_id, {
		"climate": "temperate",
		"fog_chance": 0.1,
		"storm_chance": 0.05,
		"risk_modifier": 0.0,
	})


func _faction(hub: RegistryHub, definition_id: String = "test:faction/guild") -> void:
	_define(hub, ContentTypes.FACTION, definition_id, {
		"kind": "merchant_guild",
		"starting_reputation": 0,
		"attitude_thresholds": {"hostile_below": -30, "friendly_at": 30},
		"patrol_strength": 1,
	})


func _port_template(hub: RegistryHub, definition_id: String) -> void:
	_define(hub, ContentTypes.PORT_TEMPLATE, definition_id, {
		"size": "small",
		"facilities": ["exchange", "contracts"],
		"market": [],
	}, ["port.exchange"])


func _starting_scenario(hub: RegistryHub, definition_id: String = "test:starting_scenario/standard") -> void:
	_define(hub, ContentTypes.HULL, "test:hull/small", {"cargo_slots": 1, "cabin_slots": 0})
	_define(hub, ContentTypes.MODULE, "test:module/basic_boiler", {
		"v2_category": "boiler", "speed_mul": 1.0, "coal_rate": 0.3, "water_rate": 0.2,
	})
	_define(hub, ContentTypes.MODULE, "test:module/basic_hold", {
		"v2_category": "cargo", "capacity": 10.0,
	})
	_define(hub, ContentTypes.STARTING_SCENARIO, definition_id, {
		"hull": "test:hull/small",
		"boiler": "test:module/basic_boiler",
		"cargo_modules": ["test:module/basic_hold"],
	})


func test_world_profiles_weather_profile_reference() -> void:
	var hub := _new_hub()
	_weather_profile(hub)
	_define(hub, ContentTypes.WORLD_PROFILE, "test:world/good", {
		"region_count": 2,
		"sites_per_region": 2,
		"port_count": 4,
		"weather_profile": "test:weather/temperate",
		"start_region_tags": ["test.tag.coast"],
	})
	_define(hub, ContentTypes.WORLD_PROFILE, "test:world/missing_weather", {
		"region_count": 2,
		"sites_per_region": 2,
		"port_count": 4,
		"weather_profile": "test:weather/absent",
		"start_region_tags": ["test.tag.coast"],
	})
	var result := _result(hub)
	assert_empty(
		_errors_for(result, "test:world/good"),
		"world_profile with an existing weather_profile has no error: %s" % str(_errors_for(result, "test:world/good"))
	)
	var missing := _codes(_errors_for(result, "test:world/missing_weather"))
	assert_true(missing.has("reference_missing"), "missing weather_profile is reference_missing: %s" % str(missing))


func test_regions_weather_and_faction_references() -> void:
	var hub := _new_hub()
	_weather_profile(hub)
	_faction(hub)
	_define(hub, ContentTypes.REGION, "test:region/good", {
		"kind": "coastal",
		"size": "small",
		"port_density": 0.4,
		"site_density": 0.3,
		"weather_profile": "test:weather/temperate",
		"factions": ["test:faction/guild"],
		"region_tags": ["test.tag.coast"],
	})
	_define(hub, ContentTypes.REGION, "test:region/missing_refs", {
		"kind": "coastal",
		"size": "small",
		"port_density": 0.4,
		"site_density": 0.3,
		"weather_profile": "test:weather/absent",
		"factions": ["test:faction/absent"],
		"region_tags": ["test.tag.coast"],
	})
	var result := _result(hub)
	assert_empty(_errors_for(result, "test:region/good"), "valid region has no error")
	assert_eq(
		_count_code(_errors_for(result, "test:region/missing_refs"), "reference_missing"),
		2,
		"missing region weather_profile and faction are two reference_missing errors"
	)


func test_sites_planned_references_are_warnings_only() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.SITE, "test:site/ruin", {
		"site_kind": "ruin",
		"weight": 1,
		"ruin_archetype": "test:ruin_archetype/temple",
		"encounter_table": "test:encounter_table/ruins",
		"loot_table": "test:loot_table/ruins",
	})
	var result := _result(hub)
	var warnings := _warnings_for(result, "test:site/ruin")
	assert_empty(_errors_for(result, "test:site/ruin"), "planned site references never produce an error")
	assert_eq(_count_code(warnings, "ref_inactive_type"), 3, "three planned site references warn ref_inactive_type")
	assert_empty(_codes(_warnings_for(result, "test:site/ruin")).filter(func(code): return code != "ref_inactive_type"), "site warnings are only ref_inactive_type")


func test_route_template_planned_encounter_table_is_warning_only() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.ROUTE_TEMPLATE, "test:route_template/sea_lane", {
		"kind": "sea_lane",
		"distance_range": [10, 20],
		"risk_range": [0.0, 0.1],
		"travel_time_range": [2, 4],
		"encounter_table": "test:encounter_table/sea_lane",
	})
	var result := _result(hub)
	assert_empty(_errors_for(result, "test:route_template/sea_lane"), "planned encounter_table never produces an error")
	var warnings := _warnings_for(result, "test:route_template/sea_lane")
	assert_eq(_codes(warnings), ["ref_inactive_type"], "route template only warns ref_inactive_type")


func test_weather_profiles_have_no_outgoing_references() -> void:
	var hub := _new_hub()
	_weather_profile(hub)
	var result := _result(hub)
	assert_empty(_errors_for(result, "test:weather/temperate"), "weather_profile has no cross-reference error")
	assert_empty(_warnings_for(result, "test:weather/temperate"), "weather_profile has no cross-reference warning")


func test_factions_trade_goods_and_rival_references() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.ITEM, "test:item/tea", {"base_price": 20})
	_faction(hub, "test:faction/guild")
	_faction(hub, "test:faction/navy")
	_define(hub, ContentTypes.FACTION, "test:faction/trader", {
		"kind": "merchant_guild",
		"starting_reputation": 0,
		"attitude_thresholds": {"hostile_below": -30, "friendly_at": 30},
		"patrol_strength": 1,
		"trade_goods": ["test:item/tea"],
		"rival_factions": ["test:faction/navy"],
	})
	var result := _result(hub)
	assert_empty(
		_errors_for(result, "test:faction/trader"),
		"existing trade_good and same-type rival are valid: %s" % str(_errors_for(result, "test:faction/trader"))
	)
	assert_empty(_warnings_for(result, "test:faction/trader"), "valid faction has no warning")


func test_faction_self_rival_is_reference_self() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.FACTION, "test:faction/pirates", {
		"kind": "pirates",
		"starting_reputation": -20,
		"attitude_thresholds": {"hostile_below": -30, "friendly_at": 30},
		"patrol_strength": 2,
		"rival_factions": ["test:faction/pirates"],
	})
	var result := _result(hub)
	assert_eq(
		_codes(_errors_for(result, "test:faction/pirates")),
		["reference_self"],
		"self rival is reference_self and not reference_missing"
	)


func test_faction_missing_trade_good_and_rival_are_errors() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.FACTION, "test:faction/broken", {
		"kind": "naval",
		"starting_reputation": 0,
		"attitude_thresholds": {"hostile_below": -30, "friendly_at": 30},
		"patrol_strength": 1,
		"trade_goods": ["test:item/absent"],
		"rival_factions": ["test:faction/absent"],
	})
	var result := _result(hub)
	assert_eq(
		_count_code(_errors_for(result, "test:faction/broken"), "reference_missing"),
		2,
		"missing trade_good and rival are two reference_missing errors"
	)


func test_faction_contract_family_is_inactive_type_warning() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.FACTION, "test:faction/contracts", {
		"kind": "civic",
		"starting_reputation": 0,
		"attitude_thresholds": {"hostile_below": -30, "friendly_at": 30},
		"patrol_strength": 1,
		"contract_family": "test:contract_family/harbor",
	})
	var result := _result(hub)
	assert_empty(_errors_for(result, "test:faction/contracts"), "planned contract_family never produces an error")
	assert_eq(
		_codes(_warnings_for(result, "test:faction/contracts")),
		["ref_inactive_type"],
		"contract_family warns ref_inactive_type"
	)


func test_discoveries_unlock_ids_reference_checks() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.ITEM, "test:item/relic", {"base_price": 50})
	_faction(hub, "test:faction/explorers")
	_define(hub, ContentTypes.DISCOVERY, "test:discovery/good", {
		"kind": "relic",
		"rarity": "rare",
		"weight": 1,
		"repeatable": false,
		"unlock_ids": ["test:item/relic", "test:faction/explorers"],
	})
	_define(hub, ContentTypes.DISCOVERY, "test:discovery/broken", {
		"kind": "lore",
		"rarity": "common",
		"weight": 1,
		"repeatable": true,
		"unlock_ids": ["test:item/absent"],
	})
	var result := _result(hub)
	assert_empty(_errors_for(result, "test:discovery/good"), "unlock_ids pointing at active definitions are valid")
	assert_eq(
		_codes(_errors_for(result, "test:discovery/broken")),
		["reference_missing"],
		"missing unlock_id is reference_missing"
	)


func test_start_profile_valid_without_optional_map_config() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.ITEM, "test:item/supplies", {"base_price": 10})
	_starting_scenario(hub)
	_define(hub, ContentTypes.WORLD_PROFILE, "test:world/start", {
		"region_count": 2,
		"sites_per_region": 2,
		"port_count": 4,
		"start_region_tags": ["test.tag.coast"],
	})
	_define(hub, ContentTypes.START_PROFILE, "test:start_profile/third_party", {
		"world_profile": "test:world/start",
		"starting_scenario": "test:starting_scenario/standard",
		"difficulty": "standard",
		"starting_port_tags": ["port.exchange"],
		"starting_cargo": [{"item": "test:item/supplies", "amount": 2}],
	})
	var result := _result(hub)
	assert_empty(
		_errors_for(result, "test:start_profile/third_party"),
		"start_profile without the optional map_config is valid: %s" % str(_errors_for(result, "test:start_profile/third_party"))
	)
	assert_empty(_warnings_for(result, "test:start_profile/third_party"), "omitted optional map_config does not warn")


func test_start_profile_missing_hard_references_are_errors() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.START_PROFILE, "test:start_profile/broken", {
		"world_profile": "test:world/absent",
		"starting_scenario": "test:starting_scenario/absent",
		"difficulty": "easy",
		"starting_port_tags": ["port.exchange"],
		"starting_cargo": [{"item": "test:item/absent", "amount": 1}],
		"starting_contract": "test:contract/absent",
		"map_config": "test:map_config/absent",
	})
	var result := _result(hub)
	assert_eq(
		_count_code(_errors_for(result, "test:start_profile/broken"), "reference_missing"),
		5,
		"world_profile / starting_scenario / starting_cargo item / starting_contract / map_config each report reference_missing"
	)


func test_map_config_valid_with_matching_world_profile() -> void:
	var hub := _new_hub()
	_starting_scenario(hub)
	for index in range(1, 5):
		_port_template(hub, "test:port_template/port_%d" % index)
	_define(hub, ContentTypes.WORLD_PROFILE, "test:world/four_ports", {
		"region_count": 2,
		"sites_per_region": 2,
		"port_count": 4,
		"start_region_tags": ["test.tag.coast"],
	})
	_define(hub, ContentTypes.MAP_CONFIG, "test:map_config/standard", {
		"archetypes": [
			"test:port_template/port_1",
			"test:port_template/port_2",
			"test:port_template/port_3",
			"test:port_template/port_4",
		],
		"port_name_keys": ["test.port.one", "test.port.two", "test.port.three", "test.port.four"],
		"required_facility_tags": ["port.exchange"],
		"default_starting_scenario": "test:starting_scenario/standard",
	})
	_define(hub, ContentTypes.START_PROFILE, "test:start_profile/standard", {
		"world_profile": "test:world/four_ports",
		"map_config": "test:map_config/standard",
		"starting_scenario": "test:starting_scenario/standard",
		"difficulty": "standard",
		"starting_port_tags": ["port.exchange"],
	})
	var result := _result(hub)
	assert_empty(
		_errors_for(result, "test:map_config/standard"),
		"map_config with enough archetypes is valid: %s" % str(_errors_for(result, "test:map_config/standard"))
	)
	assert_empty(_errors_for(result, "test:start_profile/standard"), "linked start_profile is valid")


func test_map_config_archetype_count_below_world_port_count_is_error() -> void:
	var hub := _new_hub()
	_starting_scenario(hub)
	for index in range(1, 5):
		_port_template(hub, "test:port_template/port_%d" % index)
	_define(hub, ContentTypes.WORLD_PROFILE, "test:world/six_ports", {
		"region_count": 2,
		"sites_per_region": 2,
		"port_count": 6,
		"start_region_tags": ["test.tag.coast"],
	})
	_define(hub, ContentTypes.MAP_CONFIG, "test:map_config/too_few", {
		"archetypes": [
			"test:port_template/port_1",
			"test:port_template/port_2",
			"test:port_template/port_3",
			"test:port_template/port_4",
		],
		"port_name_keys": ["test.port.one", "test.port.two", "test.port.three", "test.port.four"],
		"required_facility_tags": ["port.exchange"],
	})
	_define(hub, ContentTypes.START_PROFILE, "test:start_profile/six_ports", {
		"world_profile": "test:world/six_ports",
		"map_config": "test:map_config/too_few",
		"starting_scenario": "test:starting_scenario/standard",
		"difficulty": "standard",
		"starting_port_tags": ["port.exchange"],
	})
	var result := _result(hub)
	var errors := _errors_for(result, "test:map_config/too_few")
	assert_eq(_codes(errors), ["map_config_archetype_count"], "too few archetypes is a dedicated count error")
	assert_empty(_errors_for(result, "test:start_profile/six_ports"), "the count error is attributed to the map_config")


func test_map_config_count_check_skips_missing_world_profile() -> void:
	var hub := _new_hub()
	for index in range(1, 5):
		_port_template(hub, "test:port_template/port_%d" % index)
	_define(hub, ContentTypes.MAP_CONFIG, "test:map_config/orphan", {
		"archetypes": [
			"test:port_template/port_1",
			"test:port_template/port_2",
			"test:port_template/port_3",
			"test:port_template/port_4",
		],
		"port_name_keys": ["test.port.one", "test.port.two", "test.port.three", "test.port.four"],
		"required_facility_tags": ["port.exchange"],
	})
	_define(hub, ContentTypes.START_PROFILE, "test:start_profile/orphan", {
		"world_profile": "test:world/absent",
		"map_config": "test:map_config/orphan",
		"starting_scenario": "test:starting_scenario/absent",
		"difficulty": "standard",
		"starting_port_tags": ["port.exchange"],
	})
	var result := _result(hub)
	assert_eq(
		_count_code(_errors_for(result, "test:map_config/orphan"), "map_config_archetype_count"),
		0,
		"count check is skipped when the linked world_profile is missing"
	)


func test_map_config_missing_archetype_and_default_starting_scenario_are_errors() -> void:
	var hub := _new_hub()
	_define(hub, ContentTypes.MAP_CONFIG, "test:map_config/broken", {
		"archetypes": ["test:port_template/absent"],
		"port_name_keys": ["test.port.one"],
		"required_facility_tags": ["port.exchange"],
		"default_starting_scenario": "test:starting_scenario/absent",
	})
	var result := _result(hub)
	assert_eq(
		_count_code(_errors_for(result, "test:map_config/broken"), "reference_missing"),
		2,
		"missing archetype and default_starting_scenario are two reference_missing errors"
	)
