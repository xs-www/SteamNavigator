class_name ContentTypes
extends RefCounted
## AUTO-GENERATED from content_types.json; do not edit by hand.
## Regenerate: node tools/gen_content_types.mjs
##
## A content file's `content_type` selects both its registry and its JSON
## schema. Framework code never refers to concrete content IDs.

const GOOD := &"goods"
const MATERIAL := &"materials"
const HULL := &"hulls"
const BOILER := &"boilers"
const CARGO_MODULE := &"cargo_modules"
const NAVIGATION_MODULE := &"navigation_modules"
const SAFETY_MODULE := &"safety_modules"
const CABIN := &"cabins"
const ROLE := &"roles"
const STRATEGY := &"strategies"
const PORT_ARCHETYPE := &"port_archetypes"
const MAP_PROFILE := &"map_profiles"
const STARTING_BUILD := &"starting_builds"
const CONTRACT := &"contracts"
const EVENT := &"events"
const PATCH := &"patches"

const SCHEMA_PATHS := {
	GOOD: "res://schemas/good.schema.json",
	MATERIAL: "res://schemas/material.schema.json",
	HULL: "res://schemas/hull.schema.json",
	BOILER: "res://schemas/boiler.schema.json",
	CARGO_MODULE: "res://schemas/cargo_module.schema.json",
	NAVIGATION_MODULE: "res://schemas/navigation_module.schema.json",
	SAFETY_MODULE: "res://schemas/safety_module.schema.json",
	CABIN: "res://schemas/cabin.schema.json",
	ROLE: "res://schemas/role.schema.json",
	STRATEGY: "res://schemas/strategy.schema.json",
	PORT_ARCHETYPE: "res://schemas/port_archetype.schema.json",
	MAP_PROFILE: "res://schemas/map_profile.schema.json",
	STARTING_BUILD: "res://schemas/starting_build.schema.json",
	CONTRACT: "res://schemas/contract.schema.json",
	EVENT: "res://schemas/event.schema.json",
	PATCH: "res://schemas/patch.schema.json",
}

const SINGULAR := {
	GOOD: "good",
	MATERIAL: "material",
	HULL: "hull",
	BOILER: "boiler",
	CARGO_MODULE: "cargo_module",
	NAVIGATION_MODULE: "navigation_module",
	SAFETY_MODULE: "safety_module",
	CABIN: "cabin",
	ROLE: "role",
	STRATEGY: "strategy",
	PORT_ARCHETYPE: "port_archetype",
	MAP_PROFILE: "map_profile",
	STARTING_BUILD: "starting_build",
	CONTRACT: "contract",
	EVENT: "event",
	PATCH: "patch",
}

const MODULE_TYPES := [HULL, BOILER, CARGO_MODULE, NAVIGATION_MODULE, SAFETY_MODULE, CABIN]


static func all() -> Array[StringName]:
	var types: Array[StringName] = [
		GOOD, MATERIAL, HULL, BOILER, CARGO_MODULE,
		NAVIGATION_MODULE, SAFETY_MODULE, CABIN, ROLE, STRATEGY,
		PORT_ARCHETYPE, MAP_PROFILE, STARTING_BUILD, CONTRACT, EVENT,
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


static func singular(content_type: StringName) -> String:
	return String(SINGULAR.get(content_type, ""))


static func from_singular(singular_name: String) -> StringName:
	for content_type in SINGULAR.keys():
		if SINGULAR[content_type] == singular_name:
			return content_type
	return &""
