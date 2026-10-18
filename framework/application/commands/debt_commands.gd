class_name DebtCommands
extends RefCounted

static func borrow(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var profile := _profile(context)
	var loan_config: Dictionary = profile.get("loan", {})
	var limit := float(loan_config.get("limit", 300.0))
	var interest_rate := float(loan_config.get("interest_rate", 0.1))
	var term_hours := float(loan_config.get("term_hours", 96.0))
	var requested := float(params.get("amount", limit))
	var result := DebtService.borrow(state, requested, limit, interest_rate, term_hours)
	if bool(result["ok"]):
		result["events"] = [{
			"type": "debt.borrowed",
			"payload": {
				"principal": result["data"].get("principal", 0.0),
				"total_due": result["data"].get("total_due", 0.0),
				"due_time": result["data"].get("due_time", 0.0),
			},
		}]
	return result


static func _profile(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}
