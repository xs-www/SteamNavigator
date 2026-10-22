class_name MapGenerator
extends RefCounted
## Procedural branch network of 4-5 ports.
##
## Hard constraints are checked per attempt:
##   * at least one cycle (a real branch, not a linear chain);
##   * every port reachable from the start;
##   * required facilities within `required_facility_max_edges`;
##   * starting coal/water can reach at least one neighbour.

const MAX_ATTEMPTS := 60


## Schema-2.0 entry point: identical constraints and world shape as the retired
## 1.0 `generate()`, but the generator input is a plain spec dictionary instead of a
## `map_profiles` definition. `CampaignFactory` builds it through `MapGenerationSpec`.
##
## Recognised spec keys mirror the retired 1.0 generation fields:
## `port_count_range / archetypes / port_name_keys / start_archetype_tags /
## required_facility_tags / required_facility_max_edges / edge_count_range /
## distance_range / route_risk_range`. Missing optional keys keep the historical
## defaults. Geometry randomness uses `STREAM_MAP_GENERATION / "map"`.
static func generate_spec(spec: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary:
	var rng := rng_service.stream(RngService.STREAM_MAP_GENERATION, "map")
	for attempt in MAX_ATTEMPTS:
		var result := _try_generate(spec, hub, rng, ship, attempt)
		if bool(result.get("ok", false)):
			return result
	return {"ok": false, "reason": "map generation failed after %d attempts" % MAX_ATTEMPTS, "world": {}}


static func _try_generate(profile_data: Dictionary, hub: RegistryHub, rng: RandomNumberGenerator, ship: Dictionary, attempt: int) -> Dictionary:
	var port_range: Array = profile_data.get("port_count_range", [4, 5])
	var port_count := rng.randi_range(int(port_range[0]), int(port_range[1]))
	var archetype_ids: Array = profile_data.get("archetypes", [])
	if archetype_ids.size() < port_count:
		return {"ok": false, "reason": "not enough archetypes"}
	var archetypes: Array[ContentDefinition] = []
	for archetype_id in archetype_ids:
		var definition := hub.get_by_id(ContentTypes.PORT_TEMPLATE, String(archetype_id))
		if definition != null:
			archetypes.append(definition)
	if archetypes.size() < port_count:
		return {"ok": false, "reason": "archetype lookup failed"}

	var start_tags: Array = profile_data.get("start_archetype_tags", [])
	var start_archetype: ContentDefinition = null
	for candidate in archetypes:
		if candidate.has_all_tags(start_tags):
			start_archetype = candidate
			break
	if start_archetype == null:
		start_archetype = archetypes[0]

	var graph := _build_graph(port_count, profile_data, rng)
	if not bool(graph["ok"]):
		return {"ok": false, "reason": graph["reason"]}

	var assigned: Dictionary = {0: start_archetype}
	var distances := _bfs(graph["routes"], 0, port_count)
	var required_tags: Array = profile_data.get("required_facility_tags", [])
	var max_edges := int(profile_data.get("required_facility_max_edges", 2))
	for required_tag in required_tags:
		if _any_assigned_has_tag(assigned, String(required_tag)):
			continue
		var chosen_node := -1
		var chosen_definition: ContentDefinition = null
		for candidate in archetypes:
			if not candidate.has_tag(String(required_tag)):
				continue
			for node in range(port_count):
				if assigned.has(node) or int(distances.get(node, 999)) > max_edges:
					continue
				if chosen_node == -1 or int(distances[node]) < int(distances.get(chosen_node, 999)):
					chosen_node = node
					chosen_definition = candidate
		if chosen_node == -1:
			return {"ok": false, "reason": "required facility '%s' is too far from start" % required_tag}
		assigned[chosen_node] = chosen_definition

	var remaining: Array[String] = []
	for archetype in archetypes:
		remaining.append(archetype.id)
	remaining.sort()
	for node in range(1, port_count):
		if assigned.has(node):
			continue
		var picked := remaining[rng.randi_range(0, remaining.size() - 1)]
		assigned[node] = hub.get_by_id(ContentTypes.PORT_TEMPLATE, picked)

	var name_keys: Array = profile_data.get("port_name_keys", [])
	var ports := {}
	for node in range(port_count):
		var archetype: ContentDefinition = assigned[node]
		var name_key := String(name_keys[node]) if node < name_keys.size() else "port.name.%d" % node
		var angle := (TAU * float(node) / float(port_count)) + rng.randf_range(-0.25, 0.25)
		var radius := 250.0 + rng.randf_range(-35.0, 35.0)
		ports["port_%d" % node] = {
			"id": "port_%d" % node,
			"name_key": name_key,
			"description_key": archetype.description_key,
			"archetype_id": archetype.id,
			"source_mod": archetype.source_mod,
			"banner_asset": String(archetype.data.get("banner_asset", "")),
			"diorama": (archetype.data.get("diorama", {}) as Dictionary).duplicate(true),
			"facilities": Array(archetype.data.get("facilities", [])),
			"tags": Array(archetype.tags),
			"size": String(archetype.data.get("size", "medium")),
			"discovered": node == 0,
			"visited": node == 0,
			"facilities_known": node == 0,
			"x": cos(angle) * radius,
			"y": sin(angle) * radius,
		}

	var world := {
		"ports": ports,
		"routes": graph["routes"],
		"discovered_ports": ["port_0"],
		"current_port_id": "port_0",
		"start_port_id": "port_0",
	}
	if not _starting_supplies_reach_neighbor(world, hub, ship, profile_data):
		return {"ok": false, "reason": "starting supplies cannot reach a neighbour"}
	return {"ok": true, "reason": "", "world": world, "attempt": attempt}


static func _build_graph(port_count: int, profile_data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var edge_range: Array = profile_data.get("edge_count_range", [port_count, port_count + 2])
	var minimum_edges := maxi(int(edge_range[0]), port_count - 1)
	var maximum_edges := maxi(minimum_edges, int(edge_range[1]))
	var target_edges := rng.randi_range(minimum_edges, maximum_edges)
	var distance_range: Array = profile_data.get("distance_range", [90, 220])
	var risk_range: Array = profile_data.get("route_risk_range", [0.01, 0.05])
	var edges: Dictionary = {}
	var routes: Array = []

	var nodes: Array[int] = []
	for node in port_count:
		nodes.append(node)
	# Deterministic subtree rooted at port 0: each new node connects to a
	# random already-connected node. Use our own Fisher-Yates, never the
	# global RNG, so a run is reproducible.
	var order := _shuffled(nodes, rng)
	var connected: Array[int] = [0]
	for node in order:
		if node == 0:
			continue
		var parent := connected[rng.randi_range(0, connected.size() - 1)]
		_add_edge(edges, routes, parent, node, distance_range, risk_range, rng)
		connected.append(node)
		if not connected.has(0):
			connected.append(0)

	var guard := 0
	while routes.size() < target_edges and guard < 200:
		guard += 1
		var left := rng.randi_range(0, port_count - 1)
		var right := rng.randi_range(0, port_count - 1)
		if left == right:
			continue
		_add_edge(edges, routes, left, right, distance_range, risk_range, rng)

	# Guarantee the start port has a real choice.
	if _degree(routes, 0) < 2:
		for node in range(1, port_count):
			_add_edge(edges, routes, 0, node, distance_range, risk_range, rng)
			if _degree(routes, 0) >= 2:
				break

	var distances := _bfs(routes, 0, port_count)
	if distances.size() != port_count:
		return {"ok": false, "reason": "generated graph is disconnected"}
	if routes.size() <= port_count - 1:
		return {"ok": false, "reason": "generated graph has no branch cycle"}
	return {"ok": true, "reason": "", "routes": routes}


static func _add_edge(edges: Dictionary, routes: Array, left: int, right: int, distance_range: Array, risk_range: Array, rng: RandomNumberGenerator) -> void:
	var key := "%d:%d" % [mini(left, right), maxi(left, right)]
	if edges.has(key):
		return
	edges[key] = true
	var minimum_distance := int(distance_range[0])
	var maximum_distance := int(distance_range[1]) if distance_range.size() > 1 else minimum_distance
	var distance := rng.randi_range(mini(minimum_distance, maximum_distance), maxi(minimum_distance, maximum_distance))
	var minimum_risk := float(risk_range[0])
	var maximum_risk := float(risk_range[1]) if risk_range.size() > 1 else minimum_risk
	var risk := rng.randf_range(minimum_risk, maximum_risk)
	routes.append({
		"a": "port_%d" % mini(left, right),
		"b": "port_%d" % maxi(left, right),
		"distance": distance,
		"base_risk": risk,
	})


static func _degree(routes: Array, node: int) -> int:
	var port_id := "port_%d" % node
	var total := 0
	for route in routes:
		if String(route.get("a", "")) == port_id or String(route.get("b", "")) == port_id:
			total += 1
	return total


static func _bfs(routes: Array, start_node: int, port_count: int) -> Dictionary:
	var adjacency := {}
	for node in port_count:
		adjacency[node] = []
	for route in routes:
		var left := String(route["a"]).trim_prefix("port_")
		var right := String(route["b"]).trim_prefix("port_")
		var left_index := int(left)
		var right_index := int(right)
		adjacency[left_index].append(right_index)
		adjacency[right_index].append(left_index)
	var distances := {start_node: 0}
	var queue: Array[int] = [start_node]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor in adjacency[current]:
			if not distances.has(neighbor):
				distances[neighbor] = int(distances[current]) + 1
				queue.append(neighbor)
	return distances


static func _shuffled(values: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var result := values.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: int = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temporary
	return result


static func _any_assigned_has_tag(assigned: Dictionary, tag: String) -> bool:
	for node in assigned.keys():
		var archetype: ContentDefinition = assigned[node]
		if archetype.has_tag(tag):
			return true
	return false


static func _starting_supplies_reach_neighbor(world: Dictionary, hub: RegistryHub, ship: Dictionary, profile_data: Dictionary) -> bool:
	var stats := ShipOps.stats(hub, ship)
	var strategies := hub.query(ContentTypes.STRATEGY, ["strategy.economy"])
	var strategy: ContentDefinition = strategies[0] if not strategies.is_empty() else null
	var speed_mul := float(strategy.data.get("speed_mul", 1.0)) if strategy != null else 1.0
	var coal_mul := float(strategy.data.get("coal_mul", 1.0)) if strategy != null else 1.0
	var water_mul := float(strategy.data.get("water_mul", 1.0)) if strategy != null else 1.0
	for neighbor in MapOps.neighbors(world, "port_0"):
		var distance := MapOps.distance_between(world, "port_0", neighbor)
		var speed := float(stats["speed"]) * speed_mul
		var duration := distance / maxf(0.1, speed)
		var coal := duration * float(stats["coal_rate"]) * coal_mul
		var water := duration * float(stats["water_rate"]) * water_mul
		if coal <= float(ship.get("coal", 0.0)) and water <= float(ship.get("water", 0.0)):
			return true
	return false
