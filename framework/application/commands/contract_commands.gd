class_name ContractCommands
extends RefCounted

static func accept(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var instance_id := String(params.get("instance_id", ""))
	if instance_id.is_empty():
		return Result.fail("missing_instance_id", "ui.error.missing_instance_id")
	var result := ContractOps.accept_offer(state, context.registries, instance_id)
	if not bool(result["ok"]):
		return result
	var contract: Dictionary = result["data"]["contract"]
	return {
		"ok": true,
		"error_code": "",
		"message_key": "",
		"data": {
			"instance_id": instance_id,
			"slot": result["data"]["slot"],
			"contract": contract.duplicate(true),
		},
		"events": [{
			"type": "contract.accepted",
			"payload": {
				"instance_id": instance_id,
				"template_id": String(contract.get("template_id", "")),
				"slot": result["data"]["slot"],
				"destination": String(contract.get("destination", "")),
				"deadline": float(contract.get("deadline", 0.0)),
			},
		}],
	}
