class_name AutoTradeViewQuery
extends RefCounted
## @static-doc
## 作用：`auto_trade.view` 只读查询：输出策略、阶段、母港/目标港/当前港、航程剩余、
## 自动货舱、累计花费/收入/利润与最近日志；未启动时 `active:false`，不创建
## `data.trade`。
##
## ## 契约与约束
## - 字段稳定：`active / policy_id / policy / phase / paused / home_port_id /
##   home_port_name / target_port_id / target_port_name / at_port_id / at_port_name /
##   travel_remaining / cargo[] / cargo_units / max_cargo / legs / spent / earned /
##   profit / log[]`。
## - `log[]` 条目：`{tick, event, item_id, amount, money}`，最多 8 条。
## @end-static-doc


static func execute(_params: Dictionary, context) -> Dictionary:
	return Result.ok(AutoTradeOps.view(context.state, context.registries))
