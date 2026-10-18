class_name EffectExecutor
extends RefCounted
## Executes declarative effects in order. A failed effect rolls back the whole
## command transaction because the caller is already on a cloned GameState.

const MAX_EFFECTS := 16


static func execute(effects: Variant, execution_context: Dictionary) -> Dictionary:
	if effects == null:
		return Result.ok({"effects": 0, "notices": [], "flags": execution_context.get("flags", {})})
	if not (effects is Array):
		return Result.fail("invalid_effects", "ui.error.internal")
	var effect_list: Array = effects
	if effect_list.size() > MAX_EFFECTS:
		return Result.fail("too_many_effects", "ui.error.internal", {"count": effect_list.size()})
	var notices: Array = execution_context.get("notices", [])
	var index := 0
	for raw_effect in effect_list:
		index += 1
		if not (raw_effect is Dictionary):
			return Result.fail("invalid_effect", "ui.error.internal", {"index": index})
		var effect: Dictionary = raw_effect
		var op := String(effect.get("op", ""))
		if op.is_empty() or not EffectOpRegistry.has(op):
			return Result.fail("unsupported_effect", "ui.error.internal", {"op": op, "index": index})
		var outcome: Variant = EffectOpRegistry.get_handler(op).call(effect, execution_context)
		if not (outcome is Dictionary) or not bool(outcome.get("ok", false)):
			var error_code := String(outcome.get("error_code", "effect_failed")) if outcome is Dictionary else "effect_failed"
			return Result.fail(error_code, "ui.error.%s" % error_code, {"op": op, "index": index})
	return Result.ok({
		"effects": effect_list.size(),
		"notices": notices,
		"flags": execution_context.get("flags", {}),
	})
