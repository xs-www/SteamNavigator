extends TestCase
## @static-doc
## 作用：Content Schema 2.0 世界/战役 Schema 测试：SchemaValidator 合法 / 非法样本，
## Phase B 9 类提升 active，`weapons` 仍是唯一草案，`map_configs` 覆盖 31 键 exploration。
##
## ## 契约与约束
## - start_profile / world_profile / region / site / route_template / weather_profile /
##   faction / discovery / map_config 的合法 envelope 必须零错误；缺必填 / 非法 ID /
##   非法枚举 / 越界数值 / 未知 exploration 键必须报错。
## - `map_configs.exploration` 必须完整覆盖 31 键（4.1 的 19 键 + 4.2–4.5 的 12 键），
##   `twin_world_size` 范围 64–1024，`story` 走 story_flow 子 Schema。
## - Phase B 的 9 类必须出现在 `content_types.json.types`、schema_version 为 2.0、
##   Schema 文件存在且进入 `ContentTypes`；`draft_schemas` 只剩 `weapons`。
## @end-static-doc

const START_PROFILE_SCHEMA := "res://schemas/v2/start_profile.schema.json"
const WORLD_PROFILE_SCHEMA := "res://schemas/v2/world_profile.schema.json"
const REGION_SCHEMA := "res://schemas/v2/region.schema.json"
const SITE_SCHEMA := "res://schemas/v2/site.schema.json"
const ROUTE_TEMPLATE_SCHEMA := "res://schemas/v2/route_template.schema.json"
const WEATHER_PROFILE_SCHEMA := "res://schemas/v2/weather_profile.schema.json"
const FACTION_SCHEMA := "res://schemas/v2/faction.schema.json"
const DISCOVERY_SCHEMA := "res://schemas/v2/discovery.schema.json"
const MAP_CONFIG_SCHEMA := "res://schemas/v2/map_config.schema.json"


func _valid_envelope() -> Dictionary:
	return {
		"schema_version": "2.0",
		"content_type": "start_profiles",
		"definitions": [
			{
				"id": "core:start_profile/default",
				"name_key": "start.core.default.name",
				"description_key": "start.core.default.description",
				"tags": ["default", "campaign"],
				"enabled": true,
				"data": {
					"world_profile": "core:world_profile/default",
					"map_config": "core:map_config/standard",
					"starting_build": "core:starting_build/steady",
					"difficulty": "standard",
					"starting_port_tags": ["industrial"],
					"starting_money": 1000,
					"starting_reputation": 0,
					"starting_cargo": [
						{"item": "core:good/timber", "amount": 10},
					],
					"starting_contract": "core:contract/main_01",
					"notes_key": "start.core.default.notes",
				},
				"information": {"model": "model.start_profile"},
			},
		],
	}


func test_start_profile_v2_schema_accepts_valid_file() -> void:
	var validator := SchemaValidator.new()
	var errors := validator.validate_file(_valid_envelope(), START_PROFILE_SCHEMA)
	assert_empty(errors, "valid start profile passes Schema 2.0 draft")


func test_start_profile_v2_schema_rejects_invalid_data() -> void:
	var validator := SchemaValidator.new()
	var invalid := _valid_envelope()
	var definition: Dictionary = invalid["definitions"][0]
	definition["id"] = "not-a-valid-id"
	definition["data"].erase("world_profile")
	definition["data"]["difficulty"] = "impossible"
	definition["data"]["starting_cargo"] = [{"item": "not-an-id", "amount": 0}]
	var errors := validator.validate_file(invalid, START_PROFILE_SCHEMA)
	assert_true(errors.size() >= 4, "invalid start profile reports id/required/enum/cargo errors: %s" % str(errors))


func test_world_profile_v2_schema_accepts_valid_file() -> void:
	var validator := SchemaValidator.new()
	var envelope := {
		"schema_version": "2.0",
		"content_type": "world_profiles",
		"definitions": [
			{
				"id": "core:world_profile/default",
				"name_key": "world.core.default.name",
				"description_key": "world.core.default.description",
				"tags": ["default", "world"],
				"enabled": true,
				"data": {
					"region_count": 8,
					"sites_per_region": 4,
					"port_count": 12,
					"ruin_density": 0.25,
					"base_site_count": 2,
					"faction_count": 3,
					"weather_profile": "core:weather_profile/temperate",
					"start_region_tags": ["industrial", "coastal"],
				},
			},
		],
	}
	var errors := validator.validate_file(envelope, WORLD_PROFILE_SCHEMA)
	assert_empty(errors, "valid world profile passes Schema 2.0 draft")


func _world_draft_file(schema_version: String, content_type: String, definition_id: String, data: Dictionary) -> Dictionary:
	return {
		"schema_version": schema_version,
		"content_type": content_type,
		"definitions": [
			{
				"id": definition_id,
				"name_key": "%s.name" % definition_id.replace(":", ".").replace("/", "."),
				"enabled": true,
				"data": data,
			},
		],
	}


func test_world_generation_v2_drafts_accept_valid_definitions() -> void:
	var validator := SchemaValidator.new()
	var region := _world_draft_file("2.0", "regions", "core:region/industrial_coast", {
		"kind": "industrial",
		"size": "medium",
		"port_density": 0.6,
		"site_density": 0.35,
		"hostile_density": 0.2,
		"weather_profile": "core:weather_profile/temperate",
		"factions": ["core:faction/merchants_guild"],
		"region_tags": ["industrial", "coastal"],
	})
	var site := _world_draft_file("2.0", "sites", "core:site/collapsed_boiler_works", {
		"site_kind": "ruin",
		"weight": 10,
		"region_kinds": ["industrial", "coastal"],
		"ruin_archetype": "core:ruin_archetype/boiler_works",
		"loot_table": "core:loot_table/ruin_common",
		"repeatable": false,
	})
	var route := _world_draft_file("2.0", "route_templates", "core:route_template/trade_lane", {
		"kind": "trade_route",
		"distance_range": [2, 8],
		"risk_range": [0.05, 0.3],
		"travel_time_range": [4, 18],
		"bidirectional": true,
		"region_kinds": ["coastal", "archipelago"],
		"encounter_table": "core:encounter_table/sea_lane",
	})
	assert_empty(validator.validate_file(region, REGION_SCHEMA), "valid region passes Schema 2.0 draft")
	assert_empty(validator.validate_file(site, SITE_SCHEMA), "valid site passes Schema 2.0 draft")
	assert_empty(validator.validate_file(route, ROUTE_TEMPLATE_SCHEMA), "valid route template passes Schema 2.0 draft")


func test_world_actor_v2_drafts_accept_valid_definitions() -> void:
	var validator := SchemaValidator.new()
	var weather := _world_draft_file("2.0", "weather_profiles", "core:weather_profile/storm_belt", {
		"climate": "storm_belt",
		"fog_chance": 0.35,
		"storm_chance": 0.4,
		"ice_chance": 0.0,
		"base_visibility": 0.6,
		"risk_modifier": 0.12,
		"speed_modifier": -0.1,
		"coal_drain_modifier": 1.2,
		"seasons": ["spring", "autumn", "winter"],
	})
	var faction := _world_draft_file("2.0", "factions", "core:faction/merchants_guild", {
		"kind": "merchant_guild",
		"starting_reputation": 10,
		"attitude_thresholds": {"hostile_below": -25, "friendly_at": 25},
		"patrol_strength": 3,
		"trade_goods": ["core:good/timber", "core:good/coal"],
		"home_region_tags": ["industrial", "coastal"],
		"contract_family": "core:contract_family/guild_trade",
		"rival_factions": ["core:faction/pirates"],
	})
	var discovery := _world_draft_file("2.0", "discoveries", "core:discovery/boiler_works_blueprint", {
		"kind": "blueprint",
		"rarity": "rare",
		"weight": 5,
		"repeatable": false,
		"source_site_kinds": ["ruin", "wreck"],
		"region_kinds": ["industrial", "frontier"],
		"requires_tags": ["ruin", "mechanical"],
		"unlock_ids": ["core:boiler/high_pressure"],
	})
	assert_empty(validator.validate_file(weather, WEATHER_PROFILE_SCHEMA), "valid weather profile passes Schema 2.0 draft")
	assert_empty(validator.validate_file(faction, FACTION_SCHEMA), "valid faction passes Schema 2.0 draft")
	assert_empty(validator.validate_file(discovery, DISCOVERY_SCHEMA), "valid discovery passes Schema 2.0 draft")


func test_world_actor_v2_drafts_reject_invalid_definitions() -> void:
	var validator := SchemaValidator.new()
	var weather := _world_draft_file("2.0", "weather_profiles", "core:weather_profile/broken", {
		"climate": "monsoon",
		"fog_chance": 1.5,
		"storm_chance": -0.2,
		"risk_modifier": 4.0,
	})
	var faction := _world_draft_file("2.0", "factions", "core:faction/broken", {
		"kind": "merchant_guild",
		"starting_reputation": 10,
		"attitude_thresholds": {"hostile_below": -25},
		"patrol_strength": 11,
	})
	var discovery := _world_draft_file("2.0", "discoveries", "core:discovery/broken", {
		"kind": "blueprint",
		"rarity": "legendary",
		"weight": 0,
		"repeatable": "no",
	})
	var weather_errors := validator.validate_file(weather, WEATHER_PROFILE_SCHEMA)
	var faction_errors := validator.validate_file(faction, FACTION_SCHEMA)
	var discovery_errors := validator.validate_file(discovery, DISCOVERY_SCHEMA)
	assert_true(weather_errors.size() >= 3, "invalid weather profile reports enum/range errors: %s" % str(weather_errors))
	assert_true(faction_errors.size() >= 2, "invalid faction reports required/range errors: %s" % str(faction_errors))
	assert_true(discovery_errors.size() >= 3, "invalid discovery reports enum/range/type errors: %s" % str(discovery_errors))


func _map_config_file(data: Dictionary) -> Dictionary:
	return _world_draft_file("2.0", "map_configs", "core:map_config/standard", data)


func _valid_map_config_data() -> Dictionary:
	return {
		"archetypes": [
			"core:port_archetype/iron_harbor",
			"core:port_archetype/spice_port",
			"core:port_archetype/free_town",
			"core:port_archetype/fishing_village",
		],
		"port_name_keys": [
			"port_name.core.iron_harbor",
			"port_name.core.spice_port",
			"port_name.core.free_town",
			"port_name.core.fishing_village",
		],
		"start_archetype_tags": ["port.hub"],
		"required_facility_tags": ["port.shipyard", "port.intel"],
		"required_facility_max_edges": 2,
		"npc_count_range": [2, 3],
		"npc_cargo_range": [8, 24],
		"supply_prices": {"coal": 4, "water": 2, "repair_per_point": 6},
		"loan": {"limit": 400, "interest_rate": 0.1, "term_hours": 96},
		"intel_cost": 40,
		"trade_margin": 0.9,
		"player_trade_impact": 0.35,
		"default_starting_build": "core:starting_build/steady",
		"twin_world_size": 160,
		"exploration": {
			"rumor_clue_chance": 0.65,
			"intel_clue_cost": 40,
			"max_active_clues": 4,
			"level_weights": {"rumor": [0.55, 0.35, 0.1, 0], "intel": [0, 0.15, 0.45, 0.4]},
			"credibility_range": {
				"rumor": [0.25, 0.55],
				"intel": [0.6, 0.95],
				"wait": [0.4, 0.7],
				"contract": [0.55, 0.85],
			},
			"distance_error_ratio": 0.35,
			"search_zone_radius": 14,
			"search_zone_noise": 12,
			"discovery_chance_base": 0.2,
			"discovery_chance_per_credibility": 0.7,
			"risk_base": 0.08,
			"risk_per_unreliability": 0.12,
			"drift_durability_loss": 8,
			"drift_extra_coal": 4,
			"drift_extra_water": 4,
			"drift_hours": 6,
			"alert_threshold": 0.5,
			"alert_progress": 0.5,
			"turnback_extra_ratio": 0.25,
			"fog_port_reveal_ratio": 0.05,
			"fog_vision_ratio": 0.05,
			"investigation_cost": 20,
			"investigation_hours": 6,
			"investigation_success_chance": 0.75,
			"goods_clue_expiry_hours": {"rumor": 24, "intel": 72, "wait": 48, "contract": 72},
			"goods_clue_price_error_ratio": 0.15,
			"goods_clue_source_weights": {"rumor": 0, "intel": 0, "wait": 1, "contract": 0},
			"wait_clue_hours_block": 6,
			"wait_clue_chance_per_block": 0.35,
			"wait_clue_max_chance": 0.85,
			"contract_clue_chance": 0.5,
		},
		"story": {
			"flow_id": "core:story/opening",
			"enabled": true,
			"stages": [{
				"id": "opening",
				"dialogue": {"title_key": "story.core.opening.title", "body_keys": ["story.core.opening.body.1"]},
				"advance": {"mode": "confirm"},
			}],
		},
	}


func test_map_config_v2_schema_accepts_all_exploration_keys() -> void:
	var validator := SchemaValidator.new()
	var errors := validator.validate_file(_map_config_file(_valid_map_config_data()), MAP_CONFIG_SCHEMA)
	assert_empty(errors, "valid map config (31-key exploration + story) passes Schema 2.0: %s" % str(errors))
	var exploration: Dictionary = _valid_map_config_data()["exploration"]
	assert_eq(exploration.size(), 31, "map config exploration fixture covers all 31 keys")


func test_map_config_v2_schema_rejects_invalid_data() -> void:
	var validator := SchemaValidator.new()
	var invalid := _valid_map_config_data()
	invalid.erase("archetypes")
	invalid["required_facility_tags"] = ["not_a_port_tag"]
	invalid["twin_world_size"] = 8
	invalid["exploration"]["unknown_key"] = 1
	var errors := validator.validate_file(_map_config_file(invalid), MAP_CONFIG_SCHEMA)
	assert_true(errors.size() >= 4, "invalid map config reports required/pattern/range/extra-key errors: %s" % str(errors))


func test_phase_b_types_are_active_and_only_weapons_remains_draft() -> void:
	var parsed := JsonUtils.parse_file("res://content_types.json")
	assert_true(bool(parsed.get("ok", false)), "content_types.json parses")
	var data: Dictionary = parsed["value"]
	var active_types: Dictionary = {}
	for entry in data.get("types", []):
		active_types[String(entry.get("key", ""))] = entry
	var promoted := ["world_profiles", "regions", "sites", "route_templates", "weather_profiles", "factions", "discoveries", "start_profiles", "map_configs"]
	for type_name in promoted:
		assert_true(active_types.has(type_name), "%s is active" % type_name)
		var entry: Dictionary = active_types[type_name]
		assert_eq(String(entry.get("schema_version", "")), "2.0", "%s declares 2.0" % type_name)
		assert_eq(ContentTypes.schema_version(StringName(type_name)), "2.0", "%s runtime version" % type_name)
		assert_true(FileAccess.file_exists("res://" + String(entry.get("schema", ""))), "%s schema exists" % type_name)

	var drafts: Dictionary = data.get("draft_schemas", {})
	assert_eq(drafts.size(), 1, "only weapons remains a draft schema")
	assert_true(drafts.has("weapons"), "weapons remains editor-only")
	assert_true(FileAccess.file_exists("res://" + String(drafts["weapons"])), "weapons schema exists")
	assert_false(ContentTypes.is_known(&"weapons"), "weapons is not a runtime type")
