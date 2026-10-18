class_name ConditionEvaluator
extends RefCounted
## Evaluates declarative conditions. No side effects, hard node limit.

const MAX_NODES := 16


static func evaluate(condition: Variant, eval_context: Dictionary) -> Dictionary:
	if condition == null:
		return {"ok": true, "value": true, "error": ""}
	if not (condition is Dictionary):
		return {"ok": false, "value": false, "error": "condition must be an object"}
	var state := {"count": 0, "error": ""}
	var value := _evaluate_node(condition, eval_context, state)
	if not String(state["error"]).is_empty():
		return {"ok": false, "value": false, "error": state["error"]}
	return {"ok": true, "value": value, "error": ""}


static func _evaluate_node(node: Dictionary, eval_context: Dictionary, state: Dictionary) -> bool:
	state["count"] = int(state["count"]) + 1
	if int(state["count"]) > MAX_NODES:
		state["error"] = "condition exceeds %d nodes" % MAX_NODES
		return false
	if node.has("all"):
		var children: Variant = node["all"]
		if not (children is Array):
			state["error"] = "condition 'all' must be an array"
			return false
		for child in children:
			if child is Dictionary and not _evaluate_node(child, eval_context, state):
				return false
		return true
	if node.has("any"):
		var children: Variant = node["any"]
		if not (children is Array):
			state["error"] = "condition 'any' must be an array"
			return false
		for child in children:
			if child is Dictionary and _evaluate_node(child, eval_context, state):
				return true
		return false
	if node.has("not"):
		var child: Variant = node["not"]
		if not (child is Dictionary):
			state["error"] = "condition 'not' must be an object"
			return false
		return not _evaluate_node(child, eval_context, state)
	var op := String(node.get("op", ""))
	if op.is_empty():
		state["error"] = "condition node has no op"
		return false
	if not ConditionOpRegistry.has(op):
		state["error"] = "unsupported condition op: %s" % op
		return false
	var handler := ConditionOpRegistry.get_handler(op)
	var result: Variant = handler.call(node, eval_context)
	return bool(result)
