class_name ContentTypes
extends RefCounted
## AUTO-GENERATED from content_types.json; do not edit by hand.
## Regenerate: node tools/gen_content_types.mjs
##
## A content file's `content_type` selects both its registry and its JSON
## schema. Framework code never refers to concrete content IDs.

const ITEM := &"items"
const HULL := &"hulls"
const MODULE := &"modules"
const CREW_ROLE := &"crew_roles"
const BOILER_STRATEGY := &"boiler_strategies"
const PORT_TEMPLATE := &"port_templates"
const STARTING_SCENARIO := &"starting_scenarios"
const WORLD_PROFILE := &"world_profiles"
const REGION := &"regions"
const SITE := &"sites"
const ROUTE_TEMPLATE := &"route_templates"
const WEATHER_PROFILE := &"weather_profiles"
const FACTION := &"factions"
const DISCOVERY := &"discoveries"
const START_PROFILE := &"start_profiles"
const MAP_CONFIG := &"map_configs"
const CONTRACT := &"contracts"
const QUEST := &"quests"
const VOYAGE_EVENT := &"voyage_events"
const PATCH := &"patches"
const WEAPON := &"weapons"
const DAMAGE_TYPE := &"damage_types"
const COMBAT_ABILITY := &"combat_abilities"
const ENEMY_ARCHETYPE := &"enemy_archetypes"
const ENCOUNTER_TABLE := &"encounter_tables"
const LOOT_TABLE := &"loot_tables"
const SHIP_ARCHETYPE := &"ship_archetypes"
const CAPTAIN := &"captains"
const FORMATION := &"formations"
const FLEET_DOCTRINE := &"fleet_doctrines"

const SCHEMA_PATHS := {
	ITEM: "res://schemas/v2/item.schema.json",
	HULL: "res://schemas/v2/hull.schema.json",
	MODULE: "res://schemas/v2/module.schema.json",
	CREW_ROLE: "res://schemas/v2/crew_role.schema.json",
	BOILER_STRATEGY: "res://schemas/v2/boiler_strategy.schema.json",
	PORT_TEMPLATE: "res://schemas/v2/port_template.schema.json",
	STARTING_SCENARIO: "res://schemas/v2/starting_scenario.schema.json",
	WORLD_PROFILE: "res://schemas/v2/world_profile.schema.json",
	REGION: "res://schemas/v2/region.schema.json",
	SITE: "res://schemas/v2/site.schema.json",
	ROUTE_TEMPLATE: "res://schemas/v2/route_template.schema.json",
	WEATHER_PROFILE: "res://schemas/v2/weather_profile.schema.json",
	FACTION: "res://schemas/v2/faction.schema.json",
	DISCOVERY: "res://schemas/v2/discovery.schema.json",
	START_PROFILE: "res://schemas/v2/start_profile.schema.json",
	MAP_CONFIG: "res://schemas/v2/map_config.schema.json",
	CONTRACT: "res://schemas/v2/contract.schema.json",
	QUEST: "res://schemas/v2/quest.schema.json",
	VOYAGE_EVENT: "res://schemas/v2/voyage_event.schema.json",
	PATCH: "res://schemas/v2/patch.schema.json",
	WEAPON: "res://schemas/v2/weapon.schema.json",
	DAMAGE_TYPE: "res://schemas/v2/damage_type.schema.json",
	COMBAT_ABILITY: "res://schemas/v2/combat_ability.schema.json",
	ENEMY_ARCHETYPE: "res://schemas/v2/enemy_archetype.schema.json",
	ENCOUNTER_TABLE: "res://schemas/v2/encounter_table.schema.json",
	LOOT_TABLE: "res://schemas/v2/loot_table.schema.json",
	SHIP_ARCHETYPE: "res://schemas/v2/ship_archetype.schema.json",
	CAPTAIN: "res://schemas/v2/captain.schema.json",
	FORMATION: "res://schemas/v2/formation.schema.json",
	FLEET_DOCTRINE: "res://schemas/v2/fleet_doctrine.schema.json",
}

const SCHEMA_VERSIONS := {
	ITEM: "2.0",
	HULL: "2.0",
	MODULE: "2.0",
	CREW_ROLE: "2.0",
	BOILER_STRATEGY: "2.0",
	PORT_TEMPLATE: "2.0",
	STARTING_SCENARIO: "2.0",
	WORLD_PROFILE: "2.0",
	REGION: "2.0",
	SITE: "2.0",
	ROUTE_TEMPLATE: "2.0",
	WEATHER_PROFILE: "2.0",
	FACTION: "2.0",
	DISCOVERY: "2.0",
	START_PROFILE: "2.0",
	MAP_CONFIG: "2.0",
	CONTRACT: "2.0",
	QUEST: "2.0",
	VOYAGE_EVENT: "2.0",
	PATCH: "2.0",
	WEAPON: "2.0",
	DAMAGE_TYPE: "2.0",
	COMBAT_ABILITY: "2.0",
	ENEMY_ARCHETYPE: "2.0",
	ENCOUNTER_TABLE: "2.0",
	LOOT_TABLE: "2.0",
	SHIP_ARCHETYPE: "2.0",
	CAPTAIN: "2.0",
	FORMATION: "2.0",
	FLEET_DOCTRINE: "2.0",
}

const SINGULAR := {
	ITEM: "item",
	HULL: "hull",
	MODULE: "module",
	CREW_ROLE: "crew_role",
	BOILER_STRATEGY: "boiler_strategy",
	PORT_TEMPLATE: "port_template",
	STARTING_SCENARIO: "starting_scenario",
	WORLD_PROFILE: "world_profile",
	REGION: "region",
	SITE: "site",
	ROUTE_TEMPLATE: "route_template",
	WEATHER_PROFILE: "weather_profile",
	FACTION: "faction",
	DISCOVERY: "discovery",
	START_PROFILE: "start_profile",
	MAP_CONFIG: "map_config",
	CONTRACT: "contract",
	QUEST: "quest",
	VOYAGE_EVENT: "voyage_event",
	PATCH: "patch",
	WEAPON: "weapon",
	DAMAGE_TYPE: "damage_type",
	COMBAT_ABILITY: "combat_ability",
	ENEMY_ARCHETYPE: "enemy_archetype",
	ENCOUNTER_TABLE: "encounter_table",
	LOOT_TABLE: "loot_table",
	SHIP_ARCHETYPE: "ship_archetype",
	CAPTAIN: "captain",
	FORMATION: "formation",
	FLEET_DOCTRINE: "fleet_doctrine",
}

const MODULE_TYPES := [HULL, MODULE]


static func all() -> Array[StringName]:
	var types: Array[StringName] = [
		ITEM, HULL, MODULE, CREW_ROLE, BOILER_STRATEGY,
		PORT_TEMPLATE, STARTING_SCENARIO, WORLD_PROFILE, REGION, SITE,
		ROUTE_TEMPLATE, WEATHER_PROFILE, FACTION, DISCOVERY, START_PROFILE,
		MAP_CONFIG, CONTRACT, QUEST, VOYAGE_EVENT, WEAPON,
		DAMAGE_TYPE, COMBAT_ABILITY, ENEMY_ARCHETYPE, ENCOUNTER_TABLE, LOOT_TABLE,
		SHIP_ARCHETYPE, CAPTAIN, FORMATION, FLEET_DOCTRINE,
	]
	return types


static func registry_types() -> Array[StringName]:
	var types := all()
	types.append(PATCH)
	return types


static func is_known(content_type: StringName) -> bool:
	return SCHEMA_PATHS.has(content_type)


static func is_module(content_type: StringName) -> bool:
	return MODULE_TYPES.has(content_type)


static func is_patch(content_type: StringName) -> bool:
	return content_type == PATCH


static func schema_path(content_type: StringName) -> String:
	return String(SCHEMA_PATHS.get(content_type, ""))


static func schema_version(content_type: StringName) -> String:
	return String(SCHEMA_VERSIONS.get(content_type, ""))


static func singular(content_type: StringName) -> String:
	return String(SINGULAR.get(content_type, ""))


static func from_singular(singular_name: String) -> StringName:
	for content_type in SINGULAR.keys():
		if SINGULAR[content_type] == singular_name:
			return content_type
	return &""
