class_name TavernViewQuery
extends RefCounted
## @static-doc
## 作用：酒馆页（`tavern.view`）的只读查询——把原「情报站」的物价情报矩阵
## （`IntelViewQuery`）与港口线索（`ClueListViewQuery.clue_rows` 的等级裁剪视图）
## 合并成一份 ViewModel，并给出售价 / 调查成本与按钮可用性。
##
## - 关键依赖：`IntelViewQuery`、`ClueListViewQuery`、`ClueService.buy_gate`、
##   `MapOps.has_tavern`
##
## ## 契约与约束
## - 只读：由 `QueryBus` 在状态克隆上执行；不 sweep 过期线索、不写状态。
## - 线索字段裁剪完全复用 `ClueService.view_entry`：不输出 `target_port_id`、
##   `credibility`、真实搜索区或未披露的货物快照。
## - 酒馆设施判断兼容旧存档的 `intel` 设施（`MapOps.has_tavern`）。
## - 物价情报的刷新命令仍是旧的 `intel.refresh`（兼容旧入口 / 本地化键），
##   购买线索仍是 `clue.buy`，调查仍是 `clue.investigate`；查询只做展示。
## @end-static-doc


static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({
			"has_run": false,
			"intel": {},
			"clues": [],
			"active_clue_count": 0,
		})
	var state: GameState = context.state
	var intel_result := IntelViewQuery.execute({}, context)
	var intel: Dictionary = intel_result.get("data", {}) if bool(intel_result.get("ok", false)) else {}
	var rows := ClueListViewQuery.clue_rows(context)
	var rules := ExplorationRules.read(state, context.registries)
	return Result.ok({
		"has_run": true,
		"current_port_id": state.current_port_id(),
		"current_port_name_key": MapOps.port_display_key(state.world(), state.current_port_id()),
		"has_tavern_facility": MapOps.has_tavern(
			MapOps.port(state.world(), state.current_port_id())
		),
		"intel": intel,
		"clues": rows,
		"active_clue_count": ClueService.active_count(state),
		"max_active_clues": int(rules.get("max_active_clues", 4)),
		"can_buy_clue": ClueService.buy_gate(context),
		"money": state.money(),
	})
