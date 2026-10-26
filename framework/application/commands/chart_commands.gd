class_name ChartCommands
extends RefCounted
## @static-doc
## 作用：航海图 / 航线解锁相关命令。本轮只有 `chart.buy {port_id}`：在带酒馆设施的
## 当前港花钱购买一张海图，解锁当前港 ↔ 目标港的航线（同一条无向航线两端共用
## `a|b` 规范键）。
##
## - 关键依赖：`MapOps`（当前港 / 发现状态 / 酒馆设施）、`WorldOps`（航线解锁名册）、
##   `ContentRefs.map_config_data`（Core `map_config.chart_cost`）、`Result`
##
## ## 契约与约束
## - 命令只在 `CommandBus` 的 GameState 克隆上执行；失败返回结构化
##   `Result.fail(error_code, "ui.error.*", data)`，事务不提交（不扣钱、不解锁）。
## - 门禁顺序固定（先便宜后昂贵的信息检查）：无航程 → 不在港 → 参数/未知港 →
##   同港 → 目标未发现 → 当前港无酒馆 → 航线已解锁 → 金额不足。
## - 价格来自内容（`map_config.data.chart_cost`，默认 60 金），框架不写死数值；
##   扣款同时计入统计支出（`state.record_expense`）。
## - 成功发 `chart.purchased` 事件（payload: from / to / cost / money），并写一条
##   `ui.notice.chart_purchased` 通知；海图 / 酒馆页面由 Shell 重建刷新。
## - 发现港口本身不解锁航线；本命令是三种解锁来源之一（另两种是委托自带海图与
##   剧情 `unlock_route`），见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`。
## @end-static-doc

## Fallback when the scenario content predates `chart_cost`; Core overrides it in JSON.
const DEFAULT_CHART_COST := 60


static func buy(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	var origin := state.current_port_id()
	var target := String(params.get("port_id", ""))
	if target.is_empty():
		return Result.fail("unknown_port", "ui.error.unknown_port")
	if target == origin:
		return Result.fail("same_port", "ui.error.same_port")
	if MapOps.port(state.world(), target).is_empty():
		return Result.fail("unknown_port", "ui.error.unknown_port", {"port_id": target})
	if MapOps.route_between(state.world(), origin, target).is_empty():
		return Result.fail("no_route", "ui.error.no_route", {"port_id": target})
	if not MapOps.is_discovered(state, target):
		return Result.fail("port_not_discovered", "ui.error.port_not_discovered", {"port_id": target})
	if not MapOps.has_tavern(MapOps.port(state.world(), origin)):
		return Result.fail("no_tavern", "ui.error.no_tavern")
	if WorldOps.is_route_unlocked(state, origin, target):
		return Result.fail("route_already_unlocked", "ui.error.route_already_unlocked", {
			"from": origin,
			"to": target,
		})
	var cost := chart_cost(state, hub)
	if state.money() < cost:
		return Result.fail("insufficient_money", "ui.error.insufficient_money", {
			"required": cost,
			"available": state.money(),
		})
	state.add_money(-cost)
	state.record_expense(cost)
	WorldOps.unlock_route(state, origin, target)
	state.push_notice("ui.notice.chart_purchased", {
		"port": MapOps.port_display_key(state.world(), target),
		"cost": cost,
	})
	return Result.ok({
		"from": origin,
		"to": target,
		"cost": cost,
		"money": state.money(),
	}, [{
		"type": "chart.purchased",
		"payload": {"from": origin, "to": target, "cost": cost, "money": state.money()},
	}])


## Price of one chart in the current scenario (Core `map_configs.data.chart_cost`).
## Shared by the command and `tavern.view` so the button never lies about the price.
static func chart_cost(state: GameState, hub: RegistryHub) -> int:
	var data: Dictionary = ContentRefs.map_config_data(state, hub)
	return maxi(0, int(round(float(data.get("chart_cost", DEFAULT_CHART_COST)))))
