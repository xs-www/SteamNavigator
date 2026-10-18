class_name RunStartCommand
extends RefCounted

static func execute(params: Dictionary, context) -> Dictionary:
	if context.has_run() and not bool(params.get("force", false)):
		return Result.fail("run_already_started", "ui.error.run_already_started")
	var build_id := String(params.get("build_id", ""))
	var seed := int(params.get("seed", 0))
	var created := RunFactory.create_run(context, build_id, seed)
	if not bool(created["ok"]):
		return created
	var new_state: GameState = created["data"]["state"]
	context.state.replace_with(new_state)
	context.rng = created["data"]["rng"]
	context.pre_voyage_state = null
	var build: ContentDefinition = created["data"]["build"]
	var main_contract: Variant = context.state.contracts().get("main", null)
	return {
		"ok": true,
		"error_code": "",
		"message_key": "",
		"data": {
			"build_id": build.id,
			"seed": int(created["data"]["seed"]),
			"money": context.state.money(),
			"current_port_id": context.state.current_port_id(),
			"main_contract": main_contract.duplicate(true) if main_contract is Dictionary else null,
		},
		"events": [{
			"type": "run.started",
			"payload": {
				"build_id": build.id,
				"seed": int(created["data"]["seed"]),
				"map_profile": String(context.state.world().get("map_profile_id", "")),
			},
		}],
		"autosave": true,
	}
