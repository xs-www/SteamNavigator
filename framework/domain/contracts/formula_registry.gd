class_name FormulaRegistry
extends RefCounted
## Framework-owned safe formula IDs. Content may reference these IDs but may
## never supply executable expressions.

static var _formulas: Dictionary = {}
static var _initialized: bool = false


static func ensure_defaults() -> void:
	if _initialized:
		return
	_initialized = true
	register("tutorial_first", func(params: Dictionary) -> float:
		return 20.0 + float(params.get("distance", 100.0)) / 14.0 * 1.5
	)
	# 4.5.2：首航限时只够「快速航行」准时（标准速度会迟到，快速 ×1.28 可赶上）。
	# 分母 13.5 给快速航速留约 7% 余量，同时仍明显短于标准航速。
	register("tutorial_express", func(params: Dictionary) -> float:
		return maxf(6.0, float(params.get("distance", 100.0)) / 13.5)
	)
	register("tutorial_trade", func(params: Dictionary) -> float:
		return 26.0 + float(params.get("distance", 100.0)) / 14.0 * 1.6
	)
	register("tutorial_craft", func(params: Dictionary) -> float:
		return 30.0 + float(params.get("distance", 100.0)) / 15.0 * 1.6
	)
	register("passenger_run", func(params: Dictionary) -> float:
		return 26.0 + float(params.get("distance", 100.0)) / 14.0 * 1.7 + float(params.get("passengers", 0)) * 3.0
	)
	register("balanced_finale", func(params: Dictionary) -> float:
		return 34.0 + float(params.get("distance", 100.0)) / 13.0 * 1.6 \
			+ float(params.get("cargo_weight", 0.0)) * 0.4 \
			+ float(params.get("passengers", 0)) * 4.0
	)
	register("normal_standard", func(params: Dictionary) -> float:
		return 20.0 + float(params.get("distance", 100.0)) / 14.0 * 1.8
	)
	register("normal_urgent", func(params: Dictionary) -> float:
		return 12.0 + float(params.get("distance", 100.0)) / 16.0 * 1.2
	)


static func register(formula_id: String, formula: Callable) -> void:
	_formulas[formula_id] = formula


static func has(formula_id: String) -> bool:
	ensure_defaults()
	return _formulas.has(formula_id)


static func evaluate(formula_id: String, params: Dictionary = {}) -> float:
	ensure_defaults()
	if not _formulas.has(formula_id):
		return -1.0
	var value: Variant = _formulas[formula_id].call(params)
	return float(value)


static func ids() -> PackedStringArray:
	ensure_defaults()
	var result := PackedStringArray()
	for key in _formulas.keys():
		result.append(String(key))
	result.sort()
	return result


static func clear_runtime() -> void:
	_formulas.clear()
	_initialized = false
