class_name MapOps
extends RefCounted
## Helpers over the generated port network stored in GameState.world.

static func ports(world: Dictionary) -> Dictionary:
	return world.get("ports", {})


static func port(world: Dictionary, port_id: String) -> Dictionary:
	return ports(world).get(port_id, {})


static func routes(world: Dictionary) -> Array:
	return world.get("routes", [])


static func route_between(world: Dictionary, from_port: String, to_port: String) -> Dictionary:
	for route in routes(world):
		if not (route is Dictionary):
			continue
		var a := String(route.get("a", ""))
		var b := String(route.get("b", ""))
		if (a == from_port and b == to_port) or (a == to_port and b == from_port):
			return route
	return {}


static func distance_between(world: Dictionary, from_port: String, to_port: String) -> float:
	var route := route_between(world, from_port, to_port)
	return float(route.get("distance", 0.0))


static func neighbors(world: Dictionary, port_id: String) -> Array[String]:
	var result: Array[String] = []
	for route in routes(world):
		if not (route is Dictionary):
			continue
		var a := String(route.get("a", ""))
		var b := String(route.get("b", ""))
		if a == port_id:
			result.append(b)
		elif b == port_id:
			result.append(a)
	return result


static func has_facility(port_data: Dictionary, facility: String) -> bool:
	return Array(port_data.get("facilities", [])).has(facility)


static func is_discovered(state: GameState, port_id: String) -> bool:
	return Array(state.world().get("discovered_ports", [])).has(port_id)


static func is_visited(state: GameState, port_id: String) -> bool:
	return bool(port(state.world(), port_id).get("visited", false))


static func facilities_known(state: GameState, hub: RegistryHub, port_id: String) -> bool:
	if is_visited(state, port_id):
		return true
	var ship := state.ship()
	var stats := ShipOps.stats(hub, ship)
	if bool(stats.get("reveal_facilities", false)) and is_discovered(state, port_id):
		return true
	return bool(port(state.world(), port_id).get("facilities_known", false))


static func visible_facilities(state: GameState, hub: RegistryHub, port_id: String) -> Array[String]:
	var result: Array[String] = []
	if not facilities_known(state, hub, port_id):
		return result
	for facility in port(state.world(), port_id).get("facilities", []):
		result.append(String(facility))
	return result


static func discover(state: GameState, port_id: String, mark_visited: bool = false) -> bool:
	var world := state.world()
	var port_data := port(world, port_id)
	if port_data.is_empty():
		return false
	var newly_discovered := false
	var discovered: Array = world.get("discovered_ports", [])
	if not discovered.has(port_id):
		discovered.append(port_id)
		world["discovered_ports"] = discovered
		newly_discovered = true
	port_data["discovered"] = true
	if mark_visited:
		port_data["visited"] = true
		port_data["facilities_known"] = true
	return newly_discovered


static func bfs_distances(world: Dictionary, start_port: String) -> Dictionary:
	var distances := {start_port: 0}
	var queue: Array[String] = [start_port]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		var current_distance := int(distances[current])
		for neighbor in neighbors(world, current):
			if not distances.has(neighbor):
				distances[neighbor] = current_distance + 1
				queue.append(neighbor)
	return distances


static func reachable(world: Dictionary, start_port: String) -> bool:
	return bfs_distances(world, start_port).size() == ports(world).size()


static func port_display_key(world: Dictionary, port_id: String) -> String:
	return String(port(world, port_id).get("name_key", port_id))


static func route_risk(world: Dictionary, from_port: String, to_port: String) -> float:
	return float(route_between(world, from_port, to_port).get("base_risk", 0.0))
