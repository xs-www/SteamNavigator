extends TestCase
## Schema 2.0 draft contracts: validate the start profile schema with the
## project SchemaValidator and keep draft types out of the active registry.

const START_PROFILE_SCHEMA := "res://schemas/v2/start_profile.schema.json"
const WORLD_PROFILE_SCHEMA := "res://schemas/v2/world_profile.schema.json"
const REGION_SCHEMA := "res://schemas/v2/region.schema.json"
const SITE_SCHEMA := "res://schemas/v2/site.schema.json"
const ROUTE_TEMPLATE_SCHEMA := "res://schemas/v2/route_template.schema.json"
const WEATHER_PROFILE_SCHEMA := "res://schemas/v2/weather_profile.schema.json"
const FACTION_SCHEMA := "res://schemas/v2/faction.schema.json"
const DISCOVERY_SCHEMA := "res://schemas/v2/discovery.schema.json"


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


func test_draft_schemas_are_planned_and_not_active() -> void:
	var parsed := JsonUtils.parse_file("res://content_types.json")
	assert_true(bool(parsed.get("ok", false)), "content_types.json parses")
	var data: Dictionary = parsed["value"]
	var planned_types: Dictionary = {}
	for system in data.get("planned", []):
		for type_name in system.get("types", []):
			planned_types[String(type_name)] = true
	var active_types: Dictionary = {}
	for content_type in ContentTypes.all():
		active_types[String(content_type)] = true
	var drafts: Dictionary = data.get("draft_schemas", {})
	assert_true(drafts.size() > 0, "draft schemas are declared")
	for type_name in drafts.keys():
		assert_true(FileAccess.file_exists("res://" + String(drafts[type_name])), "draft schema exists: %s" % type_name)
		assert_true(planned_types.has(type_name), "draft type remains planned: %s" % type_name)
		assert_false(active_types.has(type_name), "draft type is not active: %s" % type_name)
