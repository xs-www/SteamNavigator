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
const ROLE := &"roles"
const STRATEGY := &"strategies"
const PORT_ARCHETYPE := &"port_archetypes"
const MAP_PROFILE := &"map_profiles"
const STARTING_BUILD := &"starting_builds"
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
const EVENT := &"events"
const PATCH := &"patches"

const SCHEMA_PATHS := {
	ITEM: "res://schemas/v2/item.schema.json",
	HULL: "res://schemas/v2/hull.schema.json",
	MODULE: "res://schemas/v2/module.schema.json",
	ROLE: "res://schemas/role.schema.json",
	STRATEGY: "res://schemas/strategy.schema.json",
	PORT_ARCHETYPE: "res://schemas/port_archetype.schema.json",
	MAP_PROFILE: "res://schemas/map_profile.schema.json",
	STARTING_BUILD: "res://schemas/starting_build.schema.json",
	WORLD_PROFILE: "res://schemas/v2/world_profile.schema.json",
	REGION: "res://schemas/v2/region.schema.json",
	SITE: "res://schemas/v2/site.schema.json",
	ROUTE_TEMPLATE: "res://schemas/v2/route_template.schema.json",
	WEATHER_PROFILE: "res://schemas/v2/weather_profile.schema.json",
	FACTION: "res://schemas/v2/faction.schema.json",
	DISCOVERY: "res://schemas/v2/discovery.schema.json",
	START_PROFILE: "res://schemas/v2/start_profile.schema.json",
	MAP_CONFIG: "res://schemas/v2/map_config.schema.json",
	CONTRACT: "res://schemas/contract.schema.json",
	EVENT: "res://schemas/event.schema.json",
	PATCH: "res://schemas/patch.schema.json",
}

const SCHEMA_VERSIONS := {
	ITEM: "2.0",
	HULL: "2.0",
	MODULE: "2.0",
	ROLE: "1.0",
	STRATEGY: "1.0",
	PORT_ARCHETYPE: "1.0",
	MAP_PROFILE: "1.0",
	STARTING_BUILD: "1.0",
	WORLD_PROFILE: "2.0",
	REGION: "2.0",
	SITE: "2.0",
	ROUTE_TEMPLATE: "2.0",
	WEATHER_PROFILE: "2.0",
	FACTION: "2.0",
	DISCOVERY: "2.0",
	START_PROFILE: "2.0",
	MAP_CONFIG: "2.0",
	CONTRACT: "1.0",
	EVENT: "1.0",
	PATCH: "1.0",
}

const SINGULAR := {
	ITEM: "item",
	HULL: "hull",
	MODULE: "module",
	ROLE: "role",
	STRATEGY: "strategy",
	PORT_ARCHETYPE: "port_archetype",
	MAP_PROFILE: "map_profile",
	STARTING_BUILD: "starting_build",
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
	EVENT: "event",
	PATCH: "patch",
}

const MODULE_TYPES := [HULL, MODULE]


static func all() -> Array[StringName]:
	var types: Array[StringName] = [
		ITEM, HULL, MODULE, ROLE, STRATEGY,
		PORT_ARCHETYPE, MAP_PROFILE, STARTING_BUILD, WORLD_PROFILE, REGION,
		SITE, ROUTE_TEMPLATE, WEATHER_PROFILE, FACTION, DISCOVERY,
		START_PROFILE, MAP_CONFIG, CONTRACT, EVENT,
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
