class_name FormulaRegistry
extends RefCounted
## @static-doc
## 作用：框架拥有的安全期限公式注册表，供委托数据引用。
##
## ## 契约与约束
## - 内容只能引用 ID，不能提供表达式源码。
## - 公式参数：distance / cargo_weight / passengers；返回小时数，未知 ID 返回 -1。
## - 默认公式覆盖 tutorial_first/trade/craft、passenger、finale 与 normal 两类。
## - `distance` 参数是海图世界该边的权威距离（绘制路径折线长度），公式按「里程 / 目标
##   航速」换算时限；`tutorial_express` 的隐含航速 13.5 夹在标准与极速之间，短航线下限
##   只有 0.5h，保住「标准迟到 / 极速准时」的教学契约（不再用固定 6h 下限）。
## - `none` 恒返回 0，表示「无期限委托」（第三主线起，反馈 #3）；`<= 0` 由
##   `ContractOps.create_instance` 落成无期限哨兵。
## @end-static-doc

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
	# 海图距离统一为绘制折线长度后里程尺度变小（约 25–200，旧随机 90–220），所以这里
	# **不能**再用固定 6h 下限：短航线（< 81 海里）会被下限抬到「标准也准时」，破坏
	# 「标准迟到 / 极速准时」的教学契约。下限只保留 0.5h 防御，时限与距离严格成比例。
	register("tutorial_express", func(params: Dictionary) -> float:
		return maxf(0.5, float(params.get("distance", 100.0)) / 13.5)
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
	# 反馈 #3：无期限委托（第三主线起）。求值 0 是「无期限」哨兵；内容显式写
	# `"deadline_formula": "none"`，不写死框架里的主线序号。
	register("none", func(_params: Dictionary) -> float:
		return 0.0
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
