class_name MapViewQuery
extends RefCounted
## @static-doc
## 作用：`map.view` 只读查询——输出港口列表与**已解锁**航线，供地图类 UI / 测试使用。
##
## ## 契约与约束
## - 港口列表带发现 / 访问 / 设施可知状态（`MapOps`），未发现港口也在列表里但带标记。
## - **航线解锁**（2026-10-26）：`routes` 只列 `WorldOps.is_route_unlocked` 为真的边。
##   物理海图是完全图，未解锁的边仍存在于世界表里，但不出现在这个「玩家可用的地图」
##   查询中（海图查询 `sea_chart.view` 才输出未测绘边 + `unlocked` 标记）。
## @end-static-doc

static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({"has_run": false, "ports": [], "routes": []})
	var state: GameState = context.state
	var world := state.world()
	var ports: Array = []
	var port_ids: Array = MapOps.ports(world).keys()
	port_ids.sort()
	for raw_port_id in port_ids:
		var port_id := String(raw_port_id)
		var port_data := MapOps.port(world, port_id)
		ports.append({
			"id": port_id,
			"name_key": String(port_data.get("name_key", port_id)),
			"x": float(port_data.get("x", 0.0)),
			"y": float(port_data.get("y", 0.0)),
			"discovered": MapOps.is_discovered(state, port_id),
			"visited": MapOps.is_visited(state, port_id),
			"facilities_known": MapOps.facilities_known(state, context.registries, port_id),
			"facilities": MapOps.visible_facilities(state, context.registries, port_id),
			"current": port_id == state.current_port_id(),
		})
	var routes: Array = []
	for route in MapOps.routes(world):
		if not (route is Dictionary):
			continue
		var a := String(route.get("a", ""))
		var b := String(route.get("b", ""))
		if not WorldOps.is_route_unlocked(state, a, b):
			continue
		routes.append({
			"a": a,
			"b": b,
			"distance": float(route.get("distance", 0.0)),
			"base_risk": float(route.get("base_risk", 0.0)),
		})
	return Result.ok({
		"has_run": true,
		"current_port_id": state.current_port_id(),
		"at_sea": state.data.get("voyage", null) is Dictionary,
		"ports": ports,
		"routes": routes,
	})
