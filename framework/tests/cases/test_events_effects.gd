extends TestCase


func _eval_context(context: AppContext) -> Dictionary:
	return {
		"state": context.state,
		"hub": context.registries,
		"current_port_id": context.state.current_port_id(),
		"target_port_id": context.state.current_port_id(),
	}


func test_conditions() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 6060})
	var eval := _eval_context(context)
	assert_true(bool(ConditionEvaluator.evaluate({"op": "money_gte", "value": 0}, eval)["value"]), "money condition passes")
	assert_false(bool(ConditionEvaluator.evaluate({"op": "money_gte", "value": 9999999}, eval)["value"]), "money condition fails")
	assert_true(bool(ConditionEvaluator.evaluate({"op": "has_module", "id": "core:hull/small_efficient"}, eval)["value"]), "module condition passes")
	assert_true(bool(ConditionEvaluator.evaluate({"op": "port_has_tag", "tag": "port.hub"}, eval)["value"]), "port tag condition passes")
	assert_true(bool(ConditionEvaluator.evaluate({"all": [{"op": "money_gte", "value": 0}, {"op": "durability_gte", "value": 1}]}, eval)["value"]), "all combinator passes")
	assert_false(bool(ConditionEvaluator.evaluate({"not": {"op": "money_gte", "value": 0}}, eval)["value"]), "not combinator inverts")
	var unknown := ConditionEvaluator.evaluate({"op": "no_such_op"}, eval)
	assert_false(bool(unknown["ok"]), "unknown condition op reports an error")


func test_effects_apply_in_order() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 6161})
	var state := context.state
	state.data["voyage"] = {
		"origin": state.current_port_id(),
		"destination": state.current_port_id(),
		"arrival_time": state.now() + 10.0,
		"delay_hours": 0.0,
		"injuries": 0,
		"event": {"event_id": "core:event/boiler_overheat"},
	}
	var water_before := float(state.ship()["water"])
	var durability_before := float(state.ship()["durability"])
	var execution := {
		"state": state,
		"hub": context.registries,
		"game_time": state.now(),
		"flags": {},
		"notices": [],
		"events": [],
	}
	var result := EffectExecutor.execute([
		{"op": "remove_water", "amount": 6},
		{"op": "damage_ship", "amount": 2},
		{"op": "add_delay_hours", "amount": 1},
		{"op": "emit_notice", "text_key": "notice.core.overheat.cooled"},
	], execution)
	assert_true(bool(result["ok"]), "effect chain succeeds: %s" % str(result))
	assert_almost_eq(float(state.ship()["water"]), water_before - 6.0, 0.001, "water is consumed")
	assert_true(float(state.ship()["durability"]) < durability_before, "durability drops")
	assert_almost_eq(float(state.data["voyage"]["delay_hours"]), 1.0, 0.001, "delay is recorded")
	assert_eq(execution["notices"].size(), 1, "notice is emitted")


func test_failed_effect_reports_error() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 6262})
	var water_before := float(context.state.ship()["water"])
	var execution := {
		"state": context.state,
		"hub": context.registries,
		"game_time": context.state.now(),
		"flags": {},
		"notices": [],
		"events": [],
	}
	var result := EffectExecutor.execute([{"op": "remove_water", "amount": 99999}], execution)
	assert_false(bool(result["ok"]), "impossible effect fails")
	assert_almost_eq(float(context.state.ship()["water"]), water_before, 0.001, "failed effect did not subtract water")


func test_event_content_and_sampling() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 6363})
	var risk_event := context.registries.get_by_id(ContentTypes.EVENT, "core:event/boiler_overheat")
	assert_not_null(risk_event, "risk event exists")
	assert_eq(Array(risk_event.data["options"]).size(), 5, "risk event has five options")
	assert_true(risk_event.has_tag("event.risk"), "risk event is tagged")
	var merchant := context.registries.get_by_id(ContentTypes.EVENT, "core:event/merchant_intel")
	assert_not_null(merchant, "merchant event exists")
	assert_eq(Array(merchant.data["options"]).size(), 2, "merchant event has two options")

	var destination := String(context.state.contracts()["main"]["destination"])
	var picked := {}
	for seed_value in range(1, 30):
		context.rng = RngService.new(seed_value)
		picked = VoyageService._pick_event(context, {"risk_score": 0.9}, destination)
		if not picked.is_empty():
			break
	assert_true(not picked.is_empty(), "high risk eventually samples an event")
	if not picked.is_empty():
		assert_eq(Array(picked["option_ids"]).size(), 2, "event samples two options")
		assert_eq(Array(picked["options"]).size(), 2, "two option ViewModels are returned")
