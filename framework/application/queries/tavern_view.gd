class_name TavernViewQuery
extends RefCounted
## @static-doc
## 作用：酒馆页（`tavern.view`）的只读查询——把原「情报站」的物价情报矩阵
## （`IntelViewQuery`）、港口线索（`ClueListViewQuery.clue_rows` 的等级裁剪视图）
## 与**海图（航线解锁）**报价合并成一份 ViewModel，并给出售价 / 调查成本与按钮可用性。
##
## - 关键依赖：`IntelViewQuery`、`ClueListViewQuery`、`ClueService.buy_gate`、
##   `MapOps.has_tavern`、`ChartCommands.chart_cost`、`WorldOps.is_route_unlocked`
##
## ## 契约与约束
## - 只读：由 `QueryBus` 在状态克隆上执行；不 sweep 过期线索、不写状态。
## - 线索字段裁剪完全复用 `ClueService.view_entry`：不输出 `target_port_id`、
##   `credibility`、真实搜索区或未披露的货物快照。
## - 酒馆设施判断兼容旧存档的 `intel` 设施（`MapOps.has_tavern`）。
## - 物价情报的刷新命令仍是旧的 `intel.refresh`（兼容旧入口 / 本地化键），
##   购买线索仍是 `clue.buy`，调查仍是 `clue.investigate`；查询只做展示。
## - **海图报价**（2026-10-26 航线解锁）：`chart_offers` 列出所有**已发现**、非当前港的
##   港口，每项给出 `port_id / name_key / cost / unlocked / can_buy / reason_key`；
##   费用统一取 `ChartCommands.chart_cost`（Core `map_config.chart_cost`），与
##   `chart.buy` 的扣款同源，按钮不会对不可能成功的交易报价。已解锁的港口也保留在
##   列表里（`unlocked=true`，页面显示「已测绘」）。
## @end-static-doc


static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({
			"has_run": false,
			"intel": {},
			"clues": [],
			"active_clue_count": 0,
			"chart_offers": [],
			"chart_cost": 0,
		})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
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
		"chart_cost": ChartCommands.chart_cost(state, hub),
		"chart_offers": _chart_offers(state, hub),
	})


## One row per discovered harbour the player could chart from here. Sorted by id so the
## tavern list is stable; the current harbour never appears.
static func _chart_offers(state: GameState, hub: RegistryHub) -> Array:
	var offers: Array = []
	var current := state.current_port_id()
	var has_tavern := MapOps.has_tavern(MapOps.port(state.world(), current))
	var cost := ChartCommands.chart_cost(state, hub)
	var discovered: Array = state.campaign_world().get("discovered_port_ids", [])
	var port_ids: Array = discovered.duplicate()
	port_ids.sort()
	for raw_port_id in port_ids:
		var port_id := String(raw_port_id)
		if port_id == current:
			continue
		var port_data := MapOps.port(state.world(), port_id)
		if port_data.is_empty():
			continue
		var unlocked := WorldOps.is_route_unlocked(state, current, port_id)
		var reason_key := ""
		if not has_tavern:
			reason_key = "ui.error.no_tavern"
		elif not unlocked and state.money() < cost:
			reason_key = "ui.error.insufficient_money"
		offers.append({
			"port_id": port_id,
			"name_key": MapOps.port_display_key(state.world(), port_id),
			"cost": cost,
			"unlocked": unlocked,
			"can_buy": has_tavern and not unlocked and state.money() >= cost,
			"reason_key": reason_key,
		})
	return offers
