class_name MapViewQuery
extends RefCounted

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
		routes.append({
			"a": String(route.get("a", "")),
			"b": String(route.get("b", "")),
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
