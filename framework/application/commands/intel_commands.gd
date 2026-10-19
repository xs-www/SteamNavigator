class_name IntelCommands
extends RefCounted

static func refresh(_params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var port_data := MapOps.port(state.world(), state.current_port_id())
	if not MapOps.has_facility(port_data, "intel"):
		return Result.fail("no_intel_facility", "ui.error.no_intel_facility")
	var profile := _profile(context)
	var cost := int(profile.get("intel_cost", 25))
	if state.money() < cost:
		return Result.fail("insufficient_money", "ui.error.money", {"required": cost, "money": state.money()})
	state.add_money(-cost)
	state.record_expense(cost)
	var snapshot := IntelService.build_snapshot(state, context.registries, state.now())
	IntelService.store(state, snapshot)
	return {
		"ok": true,
		"error_code": "",
		"message_key": "",
		"data": {
			"cost": cost,
			"generated_at": snapshot["generated_at"],
			"generated_label": snapshot["generated_label"],
			"ports": snapshot["ports"].size(),
			"npcs": snapshot["npcs"].size(),
		},
		"events": [{
			"type": "intelligence.updated",
			"payload": {"generated_at": snapshot["generated_at"], "cost": cost},
		}],
	}


static func _profile(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}
