class_name WorldOps
extends RefCounted
## Query and mutation helpers over the generated world map.
##
## Replaces MVP-era MapOps. Works with the world map dictionary stored in
## GameState.data.world_map (not the legacy GameState.data.world).

static func world_map(state: GameState) -> WorldMap:
	var world_data: Dictionary = state.data.get("world_map", {})
	if world_data.is_empty():
		return WorldMap.new()
	return WorldMap.from_dict(world_data)


static func ports(world: WorldMap) -> Array[WorldPort]:
	return world.ports


static func port(world: WorldMap, port_id: String) -> WorldPort:
	return world.get_port(port_id)


static func neighbors(world: WorldMap, port_id: String) -> Array[String]:
	var result: Array[String] = []
	var neighbor_ids: Array = world.connectivity_graph.get(port_id, [])
	for neighbor_id in neighbor_ids:
		result.append(String(neighbor_id))
	return result


static func distance_between(world: WorldMap, from_port: String, to_port: String) -> float:
	var from := world.get_port(from_port)
	var to := world.get_port(to_port)
	if from.is_empty() or to.is_empty():
		return 0.0
	return from.position.distance_to(to.position)


static func route_between(world: WorldMap, from_port: WorldPort, to_port: WorldPort) -> Dictionary:
	return RouteCalculator.calculate_route(from_port, to_port, world.landmasses)


static func has_facility(port_data: WorldPort, facility: String) -> bool:
	return port_data.facilities.has(facility)


static func is_discovered(state: GameState, port_id: String) -> bool:
	var campaign_world := state.campaign_world()
	var discovered: Array = campaign_world.get("discovered_port_ids", [])
	return discovered.has(port_id)


static func is_visited(state: GameState, port_id: String) -> bool:
	var campaign_world := state.campaign_world()
	var visited: Array = campaign_world.get("visited_port_ids", [])
	return visited.has(port_id)


static func discover_port_id(state: GameState, port_id: String) -> bool:
	if port_id.is_empty():
		return false
	var campaign_world := state.campaign_world()
	var discovered: Array = campaign_world.get("discovered_port_ids", [])
	if discovered.has(port_id):
		return false
	discovered.append(port_id)
	campaign_world["discovered_port_ids"] = discovered
	return true


static func mark_visited(state: GameState, port_id: String) -> bool:
	if port_id.is_empty():
		return false
	var campaign_world := state.campaign_world()
	var visited: Array = campaign_world.get("visited_port_ids", [])
	if visited.has(port_id):
		return false
	visited.append(port_id)
	campaign_world["visited_port_ids"] = visited
	discover_port_id(state, port_id)
	return true


static func bfs_distances(world: WorldMap, start_port_id: String) -> Dictionary:
	var distances := {start_port_id: 0}
	var queue: Array[String] = [start_port_id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		var current_distance: int = distances[current]
		for neighbor_id in neighbors(world, current):
			if not distances.has(neighbor_id):
				distances[neighbor_id] = current_distance + 1
				queue.append(neighbor_id)
	return distances


static func reachable(world: WorldMap, start_port_id: String) -> bool:
	return bfs_distances(world, start_port_id).size() == ports(world).size()


static func port_display_key(world: WorldMap, port_id: String) -> String:
	var port_data := port(world, port_id)
	return port_data.name_key if not port_data.is_empty() else port_id


static func current_port_id(state: GameState) -> String:
	return String(state.data.get("current_port_id", ""))


static func set_current_port(state: GameState, port_id: String) -> void:
	state.data["current_port_id"] = port_id


static func start_port_id(world: WorldMap) -> String:
	var start := world.get_start_port()
	return start.id if not start.is_empty() else ""


static func port_count(world: WorldMap) -> int:
	return ports(world).size()


static func landmass_count(world: WorldMap) -> int:
	return world.landmasses.size()


static func region_count(world: WorldMap) -> int:
	return world.regions.size()
