class_name WorldOps
extends RefCounted
## @static-doc
## 作用：世界地图查询与状态变更接口，替代 MVP 时期的 MapOps。
##
## ## 契约与约束
## - 世界结构查询只读，不修改 WorldMap。
## - 发现与访问状态通过 `GameState.campaign_world()` 保存。
## - `find_path` 使用 BFS，只按边数寻路；`distance_between` 返回直线距离。
## - `route_between` 在港口不连通时可以返回空路径。
##
## ## 航线解锁（2026-10-26「任意两港可通航 + 航线需解锁」）
## - **物理连通 = 完全图**（`WorldGenerator.generate_chart` 为每对港口生成一条航线）；
##   **能否出航是运行时状态**，与几何无关。
## - `campaign_world.unlocked_route_keys` 存规范 pair key（`a|b`，按字符串排序），
##   是新局唯一「已测绘航线」真源；缺该键的旧存档按空数组惰性补齐（不解锁任何航线）。
## - 解锁 API：`route_key(a, b)` / `is_route_unlocked(state, a, b)` /
##   `unlock_route(state, a, b)` / `unlocked_neighbor_ids(state, port_id)`。
##   解锁来源见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`：委托自带海图、剧情 `unlock_route`
##   效果、酒馆 `chart.buy`；**单纯发现 / 访问港口不解锁航线**。
## - `unlocked_neighbor_ids` 只返回与 `port_id` 相邻且已解锁的港口 id（按 id 排序），
##   供航行目的地 / 海图筛选使用；当前港自身永远不出来。
## @end-static-doc

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
	## Prefer the route table computed at generation time; fall back to computing it for
	## worlds generated before schema 1.1 (saves that carry no `edges`).
	var stored := world.route_for(from_port.id, to_port.id)
	if not stored.is_empty():
		return stored
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


## Canonical unordered pair key: `a|b` with the two ids sorted lexicographically.
## Both ends of a route always resolve to the same key, so direction never matters.
static func route_key(a: String, b: String) -> String:
	if a.is_empty() or b.is_empty():
		return ""
	return a + "|" + b if a < b else b + "|" + a


## All unlocked route keys of the run. Missing key (pre-route-unlock saves) = no
## unlocked route, never "everything unlocked".
static func unlocked_route_keys(state: GameState) -> Array:
	var campaign_world := state.campaign_world()
	var keys: Variant = campaign_world.get("unlocked_route_keys", [])
	if not (keys is Array):
		return []
	return keys


static func is_route_unlocked(state: GameState, from_port: String, to_port: String) -> bool:
	var key := route_key(from_port, to_port)
	if key.is_empty():
		return false
	return unlocked_route_keys(state).has(key)


## Marks one route as charted (unlocked). Returns true only for a newly unlocked route,
## so callers can emit an event / notice exactly once. Invalid ids and the same-port
## pair are ignored.
static func unlock_route(state: GameState, from_port: String, to_port: String) -> bool:
	if from_port.is_empty() or to_port.is_empty() or from_port == to_port:
		return false
	var key := route_key(from_port, to_port)
	var campaign_world := state.campaign_world()
	var keys: Array = campaign_world.get("unlocked_route_keys", [])
	if keys.has(key):
		return false
	keys.append(key)
	campaign_world["unlocked_route_keys"] = keys
	return true


## Neighbour ids of `port_id` whose route is charted (unlocked), sorted by id so the
## result never depends on world/edge order.
static func unlocked_neighbor_ids(state: GameState, port_id: String) -> Array[String]:
	var result: Array[String] = []
	if port_id.is_empty():
		return result
	for key in unlocked_route_keys(state):
		var parts := String(key).split("|", false)
		if parts.size() != 2:
			continue
		var a := String(parts[0])
		var b := String(parts[1])
		var neighbor := ""
		if a == port_id:
			neighbor = b
		elif b == port_id:
			neighbor = a
		else:
			continue
		if not result.has(neighbor):
			result.append(neighbor)
	result.sort()
	return result


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
