class_name IntelViewQuery
extends RefCounted
## Full intelligence ViewModel: snapshot age, discovered-port markets and NPC
## prediction ranges. Unknown ports are never included.

static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({"has_run": false, "has_report": false})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var snapshot := IntelService.get_snapshot(state)
	var port_data := MapOps.port(state.world(), state.current_port_id())
	var has_intel_facility := MapOps.has_facility(port_data, "intel")
	var profile := _profile(context)
	var cost := int(profile.get("intel_cost", 25))
	var has_report := not snapshot.is_empty()
	var ports: Array = []
	if has_report:
		for port_report in snapshot.get("ports", []):
			if not (port_report is Dictionary):
				continue
			var copy: Dictionary = port_report.duplicate(true)
			for row in copy.get("market", []):
				if row is Dictionary:
					var definition := ShipOps.item_definition(hub, String(row.get("item_id", "")))
					row["item_name_key"] = definition.name_key if definition != null else String(row.get("item_id", ""))
			ports.append(copy)
	var npcs: Array = []
	if has_report:
		for npc_report in snapshot.get("npcs", []):
			if not (npc_report is Dictionary):
				continue
			var copy: Dictionary = npc_report.duplicate(true)
			var definition := ShipOps.item_definition(hub, String(copy.get("item_id", "")))
			copy["item_name_key"] = definition.name_key if definition != null else String(copy.get("item_id", ""))
			copy["action_label_key"] = "intel.action.%s" % String(copy.get("action", "deliver"))
			npcs.append(copy)
	return Result.ok({
		"has_run": true,
		"has_report": has_report,
		"generated_at": float(snapshot.get("generated_at", -1.0)),
		"generated_label": String(snapshot.get("generated_label", "")),
		"age_hours": IntelService.snapshot_age(state),
		"ports": ports,
		"npcs": npcs,
		"port_count": ports.size(),
		"npc_count": npcs.size(),
		"discovered_port_count": Array(state.world().get("discovered_ports", [])).size(),
		"has_intel_facility": has_intel_facility,
		"can_refresh": has_intel_facility and state.is_at_port() and state.money() >= cost,
		"cost": cost,
		"money": state.money(),
	})


static func _profile(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}
