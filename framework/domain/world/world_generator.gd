class_name WorldGenerator
extends RefCounted
## @static-doc
## 作用：世界生成总控，协调区域、陆地、港口放置、连通性、出航角与航线预计算。
##
## ## 契约与约束
## - 同 seed、profile 与内容注册表必须得到相同世界。
## - 整世界生成最多尝试 `MAX_ATTEMPTS`（60）次；单次放置内每港最多 20 次间距重试。
## - 可证明不可满足的 profile 不进入重试：`ports` 定义数低于 `min_ports` 时直接返回
##   `too few ports`（放置只会减少港口，重试 60 次不可能成功），避免开局/测试白等。
## - `required_tags` 来自港口配置，不依赖内容注册表中的硬编码 ID。
## - 航线在生成期算好后写入 `WorldMap.edges`（`{from,to,distance,path}`），
##   运行期只读；换航线算法只需改这里，查询/UI 不受影响。
## - **港口规模**：通用生成器 `generate()` 的验收口径是单局 `MIN_PORTS..MAX_PORTS`
##   （15–20，见设计文档 §2.2 与 §12）。`_validate_world` 用 profile 的
##   `min_ports`/`max_ports`，缺省即取这两个常量；`port_defs` 少于下限直接判定失败，所以
##   「港口数不够」不会靠静默生成一张小图蒙混过关。**战役不走这条路径**：可玩世界由
##   `generate_chart()` 生成，港口数来自内容蓝图（默认 5）。
##
## ## 重点逻辑
## ### `generate_chart(...)`（**战役唯一世界生成入口**，2026-10-26 海图唯一真相）
## - 生成的就是海图：陆地 + 港口坐标 + **完全图拓扑**（`RouteCalculator.build_complete_connectivity`：
##   任意两港之间都有一条物理航线，5 港 = 10 条边），拓扑建好后再按 BFS 距离分配
##   港口 archetype（必需设施落在 `required_facility_max_edges` 内）、重算出航角、
##   逐边算贝塞尔路径，`distance` 取路径折线长度（两位小数），`base_risk` 从
##   `route_templates.risk_range` 用命名流按 pair 派生。**任一对港口算不出路径即判本次
##   尝试失败并重试，不做缺边 / 直线兜底**（海图必须每对都能通航）。
##   「能不能出航」不在这里决定：几何恒可通航，运行时由航线解锁状态
##   （`campaign_world.unlocked_route_keys`，见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`）门禁。
## - 返回 `{ok, world_map, attempt, edge_count}`；生成的 `world_map` 同时是玩法地图
##   （`ChartWorldProjection.from_chart` 派生 `GameState.world()`）。
## - **没有第二套拓扑**：战役不再调用 `MapGenerator`，也不再有 MST / 补边 / `edge_density`。
## ### `generate(...)`（通用世界生成器，15–20 港验收骨架 / `test_world_generator`）
## - 旧路径：读取 profile，依次生成区域和陆地、放置港口、验证必需设施、构建稀疏连通图
##   （MST + 2 近邻）、计算出航角，最后调 `_build_route_edges` 预计算航线表。战役不走它。
## ### `formal_profile(definition)`
## - 把内容层世界 profile 转成生成器 profile：五个区域
##   （起始沿岸 / 中部沿岸 ×2 / 远洋 / 外洋）、十一块陆地（1 大陆 + 5 大岛 + 3 小岛 +
##   2 环礁）、港口槽位按 `port_count_range` 取前 N 个，名称键来自 `port_name_keys`、
##   原型按 `archetypes` 轮转。它是 §12 验收项「15-20 港口合理分布在陆地海岸线上」
##   的可执行实现。
## ### `_place_ports_on_coastlines(...)`
## - 按 `coast_t` 在目标海岸采样并施加确定性抖动，同时守住港口最小间距。
## ### `_build_route_edges(...)`
## - 每条连通边算一次 `RouteCalculator.calculate_route`；算不出航线的边跳过并告警，
##   不让单条边拖垮整个世界生成（仅通用生成器；战役生成不做这种静默跳过）。
## @end-static-doc

const MAX_ATTEMPTS := 60
const MIN_PORT_SPACING := 15.0
const DEFAULT_WORLD_SIZE := 400.0
## 设计文档 §2.2 冻结的验收口径：单局 15–20 个港口。
const MIN_PORTS := 15
const MAX_PORTS := 20
## `formal_profile()` 的陆地骨架：id / 区域 / 原型 / 中心 / 半径（400×400 世界）。
## 全部贴在世界边界内，因为迷雾网格只覆盖 `bounds`，跨界的陆地会露出无雾水面。
const FORMAL_LANDMASSES := [
	{"id": "region_start_continent", "region_id": "start_coast", "archetype": "continent", "cx": 58.0, "cy": 208.0, "rx": 30.0, "ry": 74.0},
	{"id": "region_start_island", "region_id": "start_coast", "archetype": "large_island", "cx": 142.0, "cy": 300.0, "rx": 17.0, "ry": 13.0},
	{"id": "region_mid_island_a", "region_id": "mid_coast_1", "archetype": "large_island", "cx": 168.0, "cy": 96.0, "rx": 19.0, "ry": 15.0},
	{"id": "region_mid_island_b", "region_id": "mid_coast_1", "archetype": "large_island", "cx": 248.0, "cy": 180.0, "rx": 16.0, "ry": 13.0},
	{"id": "region_mid_island_c", "region_id": "mid_coast_2", "archetype": "large_island", "cx": 256.0, "cy": 318.0, "rx": 17.0, "ry": 13.0},
	{"id": "region_ocean_island_a", "region_id": "ocean_1", "archetype": "large_island", "cx": 338.0, "cy": 92.0, "rx": 15.0, "ry": 12.0},
	{"id": "region_ocean_islet_a", "region_id": "ocean_1", "archetype": "small_island", "cx": 330.0, "cy": 232.0, "rx": 8.0, "ry": 6.0},
	{"id": "region_ocean_islet_b", "region_id": "ocean_1", "archetype": "small_island", "cx": 214.0, "cy": 58.0, "rx": 8.0, "ry": 6.0},
	{"id": "region_ocean_islet_c", "region_id": "ocean_1", "archetype": "small_island", "cx": 108.0, "cy": 376.0, "rx": 8.0, "ry": 6.0},
	{"id": "region_ocean_atoll_a", "region_id": "ocean_2", "archetype": "atoll", "cx": 374.0, "cy": 170.0, "rx": 4.0, "ry": 3.2},
	{"id": "region_ocean_atoll_b", "region_id": "ocean_2", "archetype": "atoll", "cx": 26.0, "cy": 52.0, "rx": 4.0, "ry": 3.2},
]

## Port slots for the formal skeleton: `[landmass_index, coast_t]` per port, in
## placement order. The home continent carries the dense starting coast (6
## harbours, like §2.3's "起始沿岸区 4-5 港" plus a pair of outer berths), the
## mid-coast islands carry 2-3 each, and the open-ocean islets/atolls one each —
## small outlines cannot host two berths without breaking `MIN_PORT_SPACING`.
const FORMAL_PORT_SLOTS := [
	[0, 0.06], [0, 0.21], [0, 0.36], [0, 0.52], [0, 0.68], [0, 0.84],
	[1, 0.30], [1, 0.78],
	[2, 0.20], [2, 0.52], [2, 0.84],
	[3, 0.28], [3, 0.74],
	[4, 0.28], [4, 0.74],
	[5, 0.40],
	[6, 0.50],
	[7, 0.50],
	[8, 0.50],
	[9, 0.50],
]


static func generate(profile: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary:
	var min_ports := int(profile.get("min_ports", MIN_PORTS))
	var port_defs: Array = profile.get("ports", _default_ports())
	# A profile whose port definitions already fall below its own floor can never
	# pass `_validate_world`: placement only ever drops ports. Retrying it 60 times
	# would burn a full world build per attempt (heavy land/routes work) and still
	# fail, so report the constraint up front instead of stalling on it.
	if port_defs.size() < min_ports:
		return {
			"ok": false,
			"reason": "too few ports: %d < %d" % [port_defs.size(), min_ports],
			"attempts": 0,
			"world_map": {},
		}
	var rng := rng_service.stream(RngService.STREAM_MAP_GENERATION, "world")
	# Keep the last attempt's reason: "failed after 60 attempts" alone hides the
	# real constraint (too few ports, land coverage, facility distance, ...).
	var last_reason := "no attempt ran"
	for attempt in MAX_ATTEMPTS:
		var result := _try_generate(profile, hub, rng, ship, attempt)
		if bool(result.get("ok", false)):
			return result
		last_reason = String(result.get("reason", ""))
	return {"ok": false, "reason": last_reason, "attempts": MAX_ATTEMPTS, "world_map": {}}


## Generates the **playable campaign world**: this is the sea chart and the gameplay map
## at the same time (2026-10-26, 「海图唯一真相」).
##
## `profile` is built by `CampaignFactory._chart_world_profile` from `MapGenerationSpec`
## (port count / archetypes / name keys / start tags / facility requirements / risk range)
## plus the coordinate layout (world size, landmasses, port slots). Every harbour pair
## becomes a route; there is no topology / edge budget in the content blueprint anymore.
## Returns `{ok, world_map, attempt, edge_count}`; `world_map` is a `WorldMap.to_dict()`.
static func generate_chart(profile: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary:
	var port_defs: Array = profile.get("ports", _default_ports())
	var min_ports := int(profile.get("min_ports", port_defs.size()))
	if port_defs.size() < min_ports:
		# Placement only ever drops ports: retrying cannot satisfy the floor.
		return {
			"ok": false,
			"reason": "too few ports: %d < %d" % [port_defs.size(), min_ports],
			"attempts": 0,
			"world_map": {},
		}
	var rng := rng_service.stream(RngService.STREAM_MAP_GENERATION, "chart_world")
	var last_reason := "no attempt ran"
	for attempt in MAX_ATTEMPTS:
		var result := _try_generate_chart(profile, hub, rng, rng_service, ship, attempt)
		if bool(result.get("ok", false)):
			return result
		last_reason = String(result.get("reason", ""))
	return {"ok": false, "reason": last_reason, "attempts": MAX_ATTEMPTS, "world_map": {}}


static func _try_generate_chart(
	profile: Dictionary,
	hub: RegistryHub,
	rng: RandomNumberGenerator,
	rng_service: RngService,
	ship: Dictionary,
	attempt: int
) -> Dictionary:
	var world_size := float(profile.get("world_size", DEFAULT_WORLD_SIZE))
	var world := WorldMap.new()
	world.bounds = Rect2(Vector2.ZERO, Vector2(world_size, world_size))
	world.world_seed = rng.seed

	var region_defs: Array = profile.get("regions", _default_regions())
	var land_defs: Array = profile.get("landmasses", _default_landmasses(world_size))
	var port_defs: Array = profile.get("ports", _default_ports())

	for i in region_defs.size():
		var region_def: Dictionary = region_defs[i]
		var region := Region.new(
			String(region_def.get("id", "region_%d" % i)),
			String(region_def.get("name_key", "world.region.%d" % i)),
			Region.Tier.COASTAL if String(region_def.get("tier", "coastal")) == "coastal" else Region.Tier.OCEANIC
		)
		world.regions.append(region)

	var region_land_defs := _group_landmasses_by_region(land_defs)
	for region in world.regions:
		var region_lands: Array = region_land_defs.get(region.id, [])
		var landmasses := LandGenerator.generate_region_landmasses(region, world.bounds, region_lands, rng)
		for landmass in landmasses:
			world.landmasses.append(landmass)

	# Chart port slots carry no archetype yet: the map content is assigned after the
	# topology exists, so the required facilities can be placed within N edges of start.
	var port_placement := _place_ports_on_coastlines(world, port_defs, hub, rng)
	if not bool(port_placement.get("ok", false)):
		return {"ok": false, "reason": String(port_placement.get("reason", "port placement failed"))}
	var placed_ports: Array[WorldPort] = port_placement["ports"]
	for port in placed_ports:
		world.ports.append(port)
	if world.ports.size() < int(profile.get("min_ports", world.ports.size())):
		return {"ok": false, "reason": "too few ports: %d < %d" % [
			world.ports.size(), int(profile.get("min_ports", 0)),
		]}
	_ensure_start_port(world)

	# 1) Topology = complete graph: every harbour pair is physically sailable. Whether
	#    the player may sail it is runtime state (`unlocked_route_keys`), not geometry.
	var connectivity := RouteCalculator.build_complete_connectivity(world.ports)
	world.connectivity_graph = connectivity

	# 2) Content assignment on the finished topology (facility reachability is a graph fact).
	var assignment := _assign_chart_archetypes(world, profile, hub, rng)
	if not bool(assignment.get("ok", false)):
		return {"ok": false, "reason": String(assignment.get("reason", "archetype assignment failed"))}

	# 3) Routes: one Bezier path per edge; its polyline length is the distance.
	RouteCalculator.compute_departure_angles(world.ports, connectivity, world.landmasses)
	var built := _build_chart_edges(world, connectivity, profile, rng_service)
	if not bool(built.get("ok", false)):
		return {"ok": false, "reason": String(built.get("reason", "chart route failed"))}
	world.set_edges(built["edges"])

	var validation := _validate_chart_world(world, profile)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "reason": String(validation.get("reason", "validation failed")), "attempt": attempt}

	return {
		"ok": true,
		"reason": "",
		"world_map": world.to_dict(),
		"attempt": attempt,
		"edge_count": world.route_count(),
	}


## Places port content on the finished topology: the start harbour takes the
## `start_archetype_tags` archetype, every required facility tag is assigned to the nearest
## unassigned harbour within `required_facility_max_edges` from start, and the rest are
## distributed deterministically. Names come from `port_name_keys` by port index.
static func _assign_chart_archetypes(
	world: WorldMap, profile: Dictionary, hub: RegistryHub, rng: RandomNumberGenerator
) -> Dictionary:
	var candidates: Array[ContentDefinition] = []
	for raw_id in Array(profile.get("archetypes", [])):
		var definition := hub.get_by_id(ContentTypes.PORT_TEMPLATE, String(raw_id))
		if definition != null:
			candidates.append(definition)
	if candidates.size() < world.ports.size():
		return {"ok": false, "reason": "not enough port archetypes: %d < %d" % [
			candidates.size(), world.ports.size(),
		]}

	# `map_configs.archetypes` order is the content's start-port preference: the first
	# archetype that satisfies `start_archetype_tags` starts the campaign (Core puts
	# `iron_harbor`, the terminal hub, first). Do **not** sort before this pick.
	var start_tags: Array = profile.get("start_archetype_tags", [])
	var start_definition: ContentDefinition = candidates[0]
	if not start_tags.is_empty():
		for candidate in candidates:
			if candidate.has_all_tags(start_tags):
				start_definition = candidate
				break

	var start_port := world.get_start_port()
	if start_port.is_empty():
		return {"ok": false, "reason": "no start port found"}
	var assigned := {start_port.id: start_definition}
	var used := {start_definition.id: true}
	var distances := _bfs_distances(world.connectivity_graph, start_port.id)
	var max_edges := int(profile.get("required_facility_max_edges", 2))

	for raw_tag in Array(profile.get("required_facility_tags", [])):
		var required_tag := String(raw_tag)
		if _assigned_has_tag(assigned, required_tag):
			continue
		var chosen_definition: ContentDefinition = null
		for candidate in candidates:
			if used.has(candidate.id) or not candidate.has_tag(required_tag):
				continue
			chosen_definition = candidate
			break
		if chosen_definition == null:
			return {"ok": false, "reason": "no port archetype provides '%s'" % required_tag}
		var chosen_port := _nearest_unassigned_port(world, assigned, distances, max_edges)
		if chosen_port.is_empty():
			return {"ok": false, "reason": "required facility '%s' not within %d edges of start" % [
				required_tag, max_edges,
			]}
		assigned[chosen_port.id] = chosen_definition
		used[chosen_definition.id] = true

	var remaining: Array[ContentDefinition] = []
	for candidate in candidates:
		if not used.has(candidate.id):
			remaining.append(candidate)
	# Deterministic distribution order: sorted by id, then drawn with the world RNG.
	remaining.sort_custom(func(left: ContentDefinition, right: ContentDefinition) -> bool:
		return left.id < right.id
	)
	var name_keys: Array = profile.get("port_name_keys", [])
	for index in world.ports.size():
		var port := world.ports[index]
		var definition: ContentDefinition = null
		if assigned.has(port.id):
			definition = assigned[port.id]
		else:
			if remaining.is_empty():
				return {"ok": false, "reason": "not enough port archetypes for %d harbours" % world.ports.size()}
			var pick := rng.randi_range(0, remaining.size() - 1)
			definition = remaining[pick]
			remaining.remove_at(pick)
		port.archetype_id = definition.id
		_apply_archetype_content(port, definition)
		if index < name_keys.size():
			port.name_key = String(name_keys[index])
		elif port.name_key.is_empty():
			port.name_key = "port.name.%d" % index
	return {"ok": true, "reason": ""}


static func _assigned_has_tag(assigned: Dictionary, tag: String) -> bool:
	for definition in assigned.values():
		if (definition as ContentDefinition).has_tag(tag):
			return true
	return false


## Nearest harbour that is (a) still unassigned, (b) within `max_edges` of start.
## Ties are broken by port index so the assignment never depends on dictionary order.
static func _nearest_unassigned_port(
	world: WorldMap, assigned: Dictionary, distances: Dictionary, max_edges: int
) -> WorldPort:
	var chosen := WorldPort.new()
	var chosen_edges := 999
	for port in world.ports:
		if assigned.has(port.id):
			continue
		if not distances.has(port.id):
			continue
		var edges := int(distances[port.id])
		if edges > max_edges:
			continue
		if edges < chosen_edges or (edges == chosen_edges and port.id < chosen.id):
			chosen = port
			chosen_edges = edges
	return chosen


## One route per connectivity edge, in deterministic port-index order. The drawn Bezier
## path is authoritative: its (rounded) polyline length becomes `distance`, and
## `base_risk` comes from `profile.risk_range` through a per-pair named stream.
static func _build_chart_edges(
	world: WorldMap, connectivity: Dictionary, profile: Dictionary, rng_service: RngService
) -> Dictionary:
	var risk_range: Array = profile.get("risk_range", [0.01, 0.05])
	var risk_min := float(risk_range[0]) if risk_range.size() > 0 else 0.01
	var risk_max := float(risk_range[1]) if risk_range.size() > 1 else risk_min
	var pairs: Array = []
	for from_id in connectivity:
		for to_id in connectivity[from_id]:
			var a := String(from_id)
			var b := String(to_id)
			if a == b:
				continue
			if _port_index(a) < _port_index(b):
				pairs.append([a, b])
	pairs.sort_custom(func(left: Array, right: Array) -> bool:
		return _port_index(String(left[0])) < _port_index(String(right[0])) \
			or (_port_index(String(left[0])) == _port_index(String(right[0])) \
				and _port_index(String(left[1])) < _port_index(String(right[1])))
	)
	var edges: Array[Dictionary] = []
	for pair in pairs:
		var from_id := String(pair[0])
		var to_id := String(pair[1])
		var from_port := world.get_port(from_id)
		var to_port := world.get_port(to_id)
		if from_port.is_empty() or to_port.is_empty():
			continue
		var route := RouteCalculator.calculate_route(from_port, to_port, world.landmasses)
		var path: PackedVector2Array = route.get("bezier_path", PackedVector2Array())
		if path.size() < 2:
			return {"ok": false, "reason": "chart route %s -> %s has no sailable curve" % [from_id, to_id]}
		path = _rounded_path(path)
		var risk_rng := rng_service.stream(
			RngService.STREAM_MAP_GENERATION, "route_risk:%s|%s" % [from_id, to_id]
		)
		edges.append({
			"from": from_id,
			"to": to_id,
			"distance": snappedf(_polyline_length(path), pow(10.0, -WorldMap.PATH_DECIMALS)),
			"base_risk": risk_rng.randf_range(risk_min, maxf(risk_min, risk_max)),
			"path": path,
		})
	return {"ok": true, "edges": edges}


static func _port_index(port_id: String) -> int:
	if port_id.begins_with("port_"):
		return port_id.trim_prefix("port_").to_int()
	return 1 << 30


static func _rounded_path(path: PackedVector2Array) -> PackedVector2Array:
	var step := pow(10.0, -WorldMap.PATH_DECIMALS)
	var rounded := PackedVector2Array()
	rounded.resize(path.size())
	for index in path.size():
		rounded[index] = Vector2(snappedf(path[index].x, step), snappedf(path[index].y, step))
	return rounded


static func _polyline_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


static func _bfs_distances(connectivity: Dictionary, start_port_id: String) -> Dictionary:
	var distances := {start_port_id: 0}
	var queue: Array[String] = [start_port_id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		var current_distance: int = distances[current]
		var neighbors: Array = connectivity.get(current, [])
		for neighbor_id in neighbors:
			var neighbor := String(neighbor_id)
			if distances.has(neighbor):
				continue
			distances[neighbor] = current_distance + 1
			queue.append(neighbor)
	return distances


## Chart-world validation: port count, **complete graph** (every pair sailable), start
## branch, facility reachability and land coverage. Every check is a hard requirement of
## the playable world; a missing pair means this attempt is rejected and retried.
static func _validate_chart_world(world: WorldMap, profile: Dictionary) -> Dictionary:
	var min_ports := int(profile.get("min_ports", MIN_PORTS))
	var max_ports := int(profile.get("max_ports", MAX_PORTS))
	if world.ports.size() < min_ports:
		return {"ok": false, "reason": "too few ports: %d < %d" % [world.ports.size(), min_ports]}
	if world.ports.size() > max_ports:
		return {"ok": false, "reason": "too many ports: %d > %d" % [world.ports.size(), max_ports]}
	var start_port := world.get_start_port()
	if start_port.is_empty():
		return {"ok": false, "reason": "no start port found"}
	var port_count := world.ports.size()
	# Complete graph: n(n-1)/2 undirected pairs, each with exactly one drawn edge.
	var expected_edges := port_count * (port_count - 1) / 2
	if world.route_count() != expected_edges:
		return {"ok": false, "reason": "chart graph is not complete: %d edges, expected %d" % [
			world.route_count(), expected_edges,
		]}
	for port in world.ports:
		if world.connectivity_graph.get(port.id, []).size() != port_count - 1:
			return {"ok": false, "reason": "harbour %s is not connected to every other harbour" % port.id}
	var distances := _bfs_distances(world.connectivity_graph, start_port.id)
	if distances.size() != port_count:
		return {"ok": false, "reason": "generated chart graph is disconnected"}
	if port_count >= 2 and world.connectivity_graph.get(start_port.id, []).size() < 2:
		return {"ok": false, "reason": "start port has no real choice (degree < 2)"}
	var coverage := world.land_coverage_ratio()
	var max_coverage := float(profile.get("max_land_coverage", 0.45))
	if coverage > max_coverage:
		return {"ok": false, "reason": "land coverage too high: %.2f > %.2f" % [coverage, max_coverage]}
	var max_edges := int(profile.get("required_facility_max_edges", 2))
	for raw_tag in Array(profile.get("required_facility_tags", [])):
		if not _has_facility_within_edges(world, start_port, String(raw_tag), max_edges):
			return {"ok": false, "reason": "required facility '%s' not within %d edges of start" % [
				raw_tag, max_edges,
			]}
	return {"ok": true, "reason": ""}


## Turns one content definition into a generator profile. The content
## definition stays the single source of truth for the port count / name keys /
## archetypes; this only lays those ports out on the formal landmass skeleton.
static func formal_profile(definition: ContentDefinition) -> Dictionary:
	var data: Dictionary = definition.data
	var port_range: Array = data.get("port_count_range", [MIN_PORTS, MAX_PORTS])
	var port_count := clampi(int(port_range[0]), MIN_PORTS, mini(MAX_PORTS, FORMAL_PORT_SLOTS.size()))
	var archetypes: Array = data.get("archetypes", [])
	var name_keys: Array = data.get("port_name_keys", [])
	var ports: Array = []
	for i in port_count:
		var slot: Array = FORMAL_PORT_SLOTS[i]
		var land: Dictionary = FORMAL_LANDMASSES[int(slot[0])]
		var archetype := ""
		if not archetypes.is_empty():
			archetype = String(archetypes[i % archetypes.size()])
		# No baked-in content key: the definition owns naming. A profile that
		# forgets `port_name_keys` still yields a stable, localizable key.
		var name_key := "port_name.%s.%d" % [definition.id.get_file().get_basename(), i]
		if not name_keys.is_empty():
			name_key = String(name_keys[i % name_keys.size()])
		ports.append({
			"landmass_id": String(land["id"]),
			"coast_t": float(slot[1]),
			"archetype_id": archetype,
			"name_key": name_key,
			"is_start": i == 0,
		})
	var regions: Array = []
	for region_id in ["start_coast", "mid_coast_1", "mid_coast_2", "ocean_1", "ocean_2"]:
		regions.append({
			"id": region_id,
			"name_key": "world.region." + region_id,
			"tier": "oceanic" if region_id.begins_with("ocean") else "coastal",
		})
	var landmasses: Array = []
	for land in FORMAL_LANDMASSES:
		landmasses.append((land as Dictionary).duplicate(true))
	return {
		"world_size": DEFAULT_WORLD_SIZE,
		"min_ports": int(port_range[0]),
		"max_ports": int(port_range[1]) if port_range.size() > 1 else int(port_range[0]),
		"max_land_coverage": 0.45,
		"required_facility_tags": Array(data.get("required_facility_tags", ["port.shipyard", "port.intel"])),
		"required_facility_max_edges": int(data.get("required_facility_max_edges", 2)),
		"regions": regions,
		"landmasses": landmasses,
		"ports": ports,
	}


static func _try_generate(profile: Dictionary, hub: RegistryHub, rng: RandomNumberGenerator, ship: Dictionary, attempt: int) -> Dictionary:
	var world_size := float(profile.get("world_size", DEFAULT_WORLD_SIZE))
	var world_bounds := Rect2(Vector2.ZERO, Vector2(world_size, world_size))
	var world := WorldMap.new()
	world.bounds = world_bounds
	world.world_seed = rng.seed

	var region_defs: Array = profile.get("regions", _default_regions())
	var land_defs: Array = profile.get("landmasses", _default_landmasses(world_size))
	var port_defs: Array = profile.get("ports", _default_ports())

	for i in region_defs.size():
		var region_def: Dictionary = region_defs[i]
		var region := Region.new(
			String(region_def.get("id", "region_%d" % i)),
			String(region_def.get("name_key", "world.region.%d" % i)),
			Region.Tier.COASTAL if String(region_def.get("tier", "coastal")) == "coastal" else Region.Tier.OCEANIC
		)
		world.regions.append(region)

	var region_land_defs := _group_landmasses_by_region(land_defs)
	for region in world.regions:
		var region_lands: Array = region_land_defs.get(region.id, [])
		var landmasses := LandGenerator.generate_region_landmasses(region, world_bounds, region_lands, rng)
		for landmass in landmasses:
			world.landmasses.append(landmass)

	var port_placement := _place_ports_on_coastlines(world, port_defs, hub, rng)
	if not bool(port_placement.get("ok", false)):
		return {"ok": false, "reason": String(port_placement.get("reason", "port placement failed"))}

	var placed_ports: Array[WorldPort] = port_placement["ports"]
	for port in placed_ports:
		world.ports.append(port)

	var connectivity := RouteCalculator.build_connectivity_graph(world.ports, world.landmasses)
	world.connectivity_graph = connectivity
	RouteCalculator.compute_departure_angles(world.ports, connectivity, world.landmasses)
	# Routes are computed once here and stored on the world (schema 1.1), so the chart and
	# voyage code read a table instead of re-running pathfinding for every edge on every
	# query. Swapping the route algorithm later only changes this call.
	world.set_edges(_build_route_edges(world, connectivity))

	_ensure_start_port(world)

	var validation := _validate_world(world, profile, hub, ship)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "reason": String(validation.get("reason", "validation failed")), "attempt": attempt}

	return {"ok": true, "reason": "", "world_map": world.to_dict(), "attempt": attempt}


## Precomputes one route record per connectivity edge (`{from, to, distance, path}`).
## Edges whose route cannot be built are skipped with a warning rather than sinking the
## whole world — the chart simply does not draw them.
static func _build_route_edges(world: WorldMap, connectivity: Dictionary) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for from_id in connectivity:
		for to_id in connectivity[from_id]:
			if String(from_id) >= String(to_id):
				continue
			var from_port := world.get_port(String(from_id))
			var to_port := world.get_port(String(to_id))
			if from_port.is_empty() or to_port.is_empty():
				continue
			var route := RouteCalculator.calculate_route(from_port, to_port, world.landmasses)
			var path: PackedVector2Array = route.get("bezier_path", PackedVector2Array())
			if path.size() < 2:
				push_warning("world generator: no sailable route %s -> %s" % [from_id, to_id])
				continue
			edges.append({
				"from": String(from_id),
				"to": String(to_id),
				"distance": float(route.get("distance", 0.0)),
				"path": path,
			})
	return edges


static func _default_regions() -> Array:
	return []


static func _default_landmasses(world_size: float) -> Array:
	return []


static func _default_ports() -> Array:
	return []


static func _group_landmasses_by_region(land_defs: Array) -> Dictionary:
	var result := {}
	for def in land_defs:
		var region_id := String(def.get("region_id", ""))
		if not result.has(region_id):
			result[region_id] = []
		result[region_id].append(def)
	return result


static func _place_ports_on_coastlines(world: WorldMap, port_defs: Array, hub: RegistryHub, rng: RandomNumberGenerator) -> Dictionary:
	var ports: Array[WorldPort] = []
	var placed_positions: Array[Vector2] = []

	for i in port_defs.size():
		var def: Dictionary = port_defs[i]
		var landmass_id := String(def.get("landmass_id", ""))
		var landmass := world.get_landmass(landmass_id)
		if landmass.is_empty():
			continue

		var coast_t := float(def.get("coast_t", 0.5))
		var jitter := (rng.randf() - 0.5) * 0.08
		coast_t = clampf(coast_t + jitter, 0.0, 1.0)
		var position := landmass.sample_coastline(coast_t)

		# The configured coastline sample is the anchor; the retry only nudges
		# along that same coastline. If spacing still cannot be met the port is
		# dropped, and the world fails in `_validate_world` when the count drops
		# below `min_ports` (silently shrinking the world is not acceptable).
		if not _is_spacing_valid(position, placed_positions, MIN_PORT_SPACING):
			var found_valid := false
			for retry in 20:
				var retry_t := clampf(coast_t + (rng.randf() - 0.5) * 0.2, 0.0, 1.0)
				position = landmass.sample_coastline(retry_t)
				if _is_spacing_valid(position, placed_positions, MIN_PORT_SPACING):
					found_valid = true
					break
			if not found_valid:
				continue

		# Port ids stay tied to the placed order so the count never has holes
		# (`port_0..port_N-1`), which the run twin world and fog both rely on.
		var port := WorldPort.new("port_%d" % ports.size(), position)
		port.region_id = landmass.region_id
		port.landmass_id = landmass_id
		port.archetype_id = String(def.get("archetype_id", ""))
		port.name_key = String(def.get("name_key", ""))
		port.is_start_port = bool(def.get("is_start", false))
		
		# Apply required_tags directly from the port definition
		var required_tags: Array = def.get("required_tags", [])
		for tag in required_tags:
			if not port.tags.has(String(tag)):
				port.tags.append(String(tag))

		var archetype := hub.get_by_id(ContentTypes.PORT_TEMPLATE, port.archetype_id)
		if archetype != null:
			_apply_archetype_content(port, archetype)

		ports.append(port)
		placed_positions.append(position)

	if ports.is_empty():
		return {"ok": false, "reason": "no ports could be placed"}

	return {"ok": true, "ports": ports}


## Copies one port template's display / facility / tag content onto a placed harbour.
## Shared by the generic generator (archetype known up front) and the chart generator
## (archetype assigned after the topology exists).
static func _apply_archetype_content(port: WorldPort, archetype: ContentDefinition) -> void:
	port.description_key = archetype.description_key
	port.source_mod = archetype.source_mod
	port.banner_asset = String(archetype.data.get("banner_asset", ""))
	port.diorama = (archetype.data.get("diorama", {}) as Dictionary).duplicate(true)
	port.size = String(archetype.data.get("size", "medium"))
	for facility in Array(archetype.data.get("facilities", [])):
		if not port.facilities.has(String(facility)):
			port.facilities.append(String(facility))
	for tag in archetype.tags:
		if not port.tags.has(String(tag)):
			port.tags.append(String(tag))


static func _is_spacing_valid(position: Vector2, existing: Array[Vector2], min_spacing: float) -> bool:
	for existing_pos in existing:
		if position.distance_to(existing_pos) < min_spacing:
			return false
	return true


static func _ensure_start_port(world: WorldMap) -> void:
	for port in world.ports:
		if port.is_start_port:
			return
	if not world.ports.is_empty():
		world.ports[0].is_start_port = true


static func _validate_world(world: WorldMap, profile: Dictionary, hub: RegistryHub, ship: Dictionary) -> Dictionary:
	var min_ports := int(profile.get("min_ports", MIN_PORTS))
	var max_ports := int(profile.get("max_ports", MAX_PORTS))
	if world.ports.size() < min_ports:
		return {"ok": false, "reason": "too few ports: %d < %d" % [world.ports.size(), min_ports]}
	if world.ports.size() > max_ports:
		return {"ok": false, "reason": "too many ports: %d > %d" % [world.ports.size(), max_ports]}

	var start_port := world.get_start_port()
	if start_port.is_empty():
		return {"ok": false, "reason": "no start port found"}

	var coverage := world.land_coverage_ratio()
	var max_coverage := float(profile.get("max_land_coverage", 0.3))
	if coverage > max_coverage:
		return {"ok": false, "reason": "land coverage too high: %.2f > %.2f" % [coverage, max_coverage]}

	var required_tags: Array = profile.get("required_facility_tags", ["port.shipyard", "port.intelligence"])
	var max_edges := int(profile.get("required_facility_max_edges", 2))
	for required_tag in required_tags:
		if not _has_facility_within_edges(world, start_port, String(required_tag), max_edges):
			return {"ok": false, "reason": "required facility '%s' not within %d edges of start" % [required_tag, max_edges]}

	return {"ok": true, "reason": ""}


static func _has_facility_within_edges(world: WorldMap, start_port: WorldPort, required_tag: String, max_edges: int) -> bool:
	for port in world.ports:
		if port.has_tag(required_tag):
			var distance := _bfs_distance(world, start_port.id, port.id)
			if distance >= 0 and distance <= max_edges:
				return true
	return false


static func _bfs_distance(world: WorldMap, start_id: String, target_id: String) -> int:
	if start_id == target_id:
		return 0
	var visited := {start_id: 0}
	var queue: Array[String] = [start_id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		var current_distance: int = visited[current]
		var neighbors: Array = world.connectivity_graph.get(current, [])
		for neighbor_id in neighbors:
			var neighbor := String(neighbor_id)
			if visited.has(neighbor):
				continue
			visited[neighbor] = current_distance + 1
			if neighbor == target_id:
				return visited[neighbor]
			queue.append(neighbor)
	return -1
