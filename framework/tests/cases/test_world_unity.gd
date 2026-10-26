extends TestCase
class_name TestWorldUnity
## @static-doc
## 作用：锁定「海图唯一真相」世界契约的回归测试（2026-10-26）。
##
## ## 契约与约束
## - **唯一拓扑**：坐标海图世界（`state.data["world_map"]`）的 `connectivity_graph` 与
##   `edges` 就是世界拓扑；`GameState.world()` 的 `ports` / `routes` 由
##   `ChartWorldProjection.from_chart` 派生，集合必须与海图边完全相等（无 chart-only /
##   world-only 边，`state.world()` 不再自己生成拓扑）。
## - **完全图**（2026-10-26「任意两港可通航 + 航线需解锁」）：`generate_chart` 为每对港口
##   生成一条航线，5 港 = 10 条边；每对恰有一条边、每条边都有非空绘制路径。
## - **唯一距离**：每条海图边 `distance` == 该边绘制路径（`edges[].path`）的折线长度 ==
##   `world.routes[].distance`（两位小数同值）；`world.ports[].x/y` == 海图港口坐标；
##   `base_risk` 也出自同一条海图边。
## - `sea_chart.view` 与 `voyage.preview` 对同一对港口逐项一致：distance / duration /
##   coal / water / risk。未解锁航线 `preview` 返回 `route_locked`（见
##   `test_route_unlock`）；本套件先显式解锁全部 pair 再比较数值。
## - 同 seed 的两次开局得到逐字段相同的海图世界与派生 `world.routes`；不同 seed 不同。
## - 测试只用公开查询 / 命令与内容注册表，不改生产代码路径。
## @end-static-doc

const SEED := 4242
const STRATEGY := "core:boiler_strategy/standard"
## `run.start` treats seed 0 as "pick a random seed"; fixed seeds make the assertions real.
const OTHER_SEEDS := [12345, 111, 222, 333]


func test_chart_is_the_single_world_topology() -> void:
	var context := _start_run(SEED)
	var state: GameState = context.state
	var chart := WorldOps.world_map(state)
	var world := state.world()
	assert_true(chart.route_count() > 0, "the chart world should carry routes")
	assert_true(chart.ports.size() > 0, "the chart world should carry ports")

	# --- 1) Topology: chart edges == derived world routes, exactly. ---
	var chart_pairs := {}
	for edge in chart.edges:
		var key := _pair_key(String(edge.get("from", "")), String(edge.get("to", "")))
		assert_false(chart_pairs.has(key), "duplicate chart edge %s" % key)
		chart_pairs[key] = edge
	var world_routes: Array = MapOps.routes(world)
	assert_eq(world_routes.size(), chart.route_count(),
		"GameState.world() routes must be derived 1:1 from the chart edges")
	var world_pairs := {}
	for route in world_routes:
		var key := _pair_key(String(route.get("a", "")), String(route.get("b", "")))
		assert_false(world_pairs.has(key), "duplicate world route %s" % key)
		world_pairs[key] = route
		assert_true(chart_pairs.has(key),
			"world route %s must exist on the chart (the chart is the only topology)" % key)
	for key in chart_pairs.keys():
		assert_true(world_pairs.has(key),
			"chart edge %s must exist in GameState.world()" % key)

	# Connectivity graph is the symmetric view of the same edge set.
	for port in chart.ports:
		var expected: Array = []
		for edge in chart.edges:
			var from_id := String(edge.get("from", ""))
			var to_id := String(edge.get("to", ""))
			if from_id == port.id:
				expected.append(to_id)
			elif to_id == port.id:
				expected.append(from_id)
		var actual: Array = chart.connectivity_graph.get(port.id, [])
		assert_eq(actual.size(), expected.size(),
			"connectivity degree of %s should match the chart edge set" % port.id)
		for neighbor_id in expected:
			assert_contains(actual, neighbor_id,
				"%s should be connected to %s in the chart graph" % [port.id, neighbor_id])

	# --- 2) Distance / risk: one value per edge, shared by chart and gameplay. ---
	for edge in chart.edges:
		var key := _pair_key(String(edge.get("from", "")), String(edge.get("to", "")))
		var distance := float(edge.get("distance", 0.0))
		var path: PackedVector2Array = edge.get("path", PackedVector2Array())
		assert_true(path.size() >= 2, "chart edge %s should carry a drawn path" % key)
		assert_almost_eq(distance, _polyline_length(path), 0.05,
			"chart edge %s distance should equal its path polyline length" % key)
		var route: Dictionary = world_pairs[key]
		assert_almost_eq(distance, float(route.get("distance", 0.0)), 0.01,
			"chart edge %s distance should equal the derived world route distance" % key)
		assert_almost_eq(float(edge.get("base_risk", -1.0)), float(route.get("base_risk", -2.0)), 0.000001,
			"chart edge %s base_risk should be the one gameplay reads" % key)

	# --- 3) Geometry: the gameplay ports are the chart harbours. ---
	var world_ports: Dictionary = MapOps.ports(world)
	for port in chart.ports:
		var port_data: Dictionary = world_ports.get(port.id, {})
		assert_false(port_data.is_empty(), "GameState.world() should know %s" % port.id)
		assert_almost_eq(float(port_data.get("x", -1.0)), port.position.x, 0.001,
			"world %s.x should be the chart harbour x" % port.id)
		assert_almost_eq(float(port_data.get("y", -1.0)), port.position.y, 0.001,
			"world %s.y should be the chart harbour y" % port.id)
		assert_true(not String(port_data.get("archetype_id", "")).is_empty(),
			"chart harbour %s should have its archetype assigned" % port.id)
		assert_true(not String(port_data.get("name_key", "")).is_empty(),
			"chart harbour %s should have a name key" % port.id)


## Every harbour pair is physically sailable: the chart is a complete graph. `n` harbours
## therefore produce exactly `n(n-1)/2` routes, each with a drawn path and a distance that
## equals that path's polyline length.
func test_chart_is_a_complete_graph() -> void:
	var context := _start_run(SEED)
	var chart := WorldOps.world_map(context.state)
	var port_count := chart.ports.size()
	assert_true(port_count >= 2, "the chart world should have at least two harbours")
	var expected_edges := port_count * (port_count - 1) / 2
	assert_eq(chart.route_count(), expected_edges,
		"the chart should connect every harbour pair (%d harbours -> %d routes)" % [
			port_count, expected_edges,
		])
	var seen := {}
	for edge in chart.edges:
		var key := _pair_key(String(edge.get("from", "")), String(edge.get("to", "")))
		assert_false(seen.has(key), "duplicate chart edge %s" % key)
		seen[key] = true
		var path: PackedVector2Array = edge.get("path", PackedVector2Array())
		assert_true(path.size() >= 2, "chart edge %s should carry a drawn path" % key)
		assert_almost_eq(float(edge.get("distance", 0.0)), _polyline_length(path), 0.05,
			"chart edge %s distance should equal its path polyline length" % key)
	for index in port_count:
		for other in range(index + 1, port_count):
			var key := _pair_key(chart.ports[index].id, chart.ports[other].id)
			assert_true(seen.has(key), "chart must connect %s" % key)
	# The start harbour can reach every other harbour in one hop (real choice).
	var start_port := chart.get_start_port()
	assert_false(start_port.is_empty(), "the chart should have a start harbour")
	assert_eq(Array(chart.connectivity_graph.get(start_port.id, [])).size(), port_count - 1,
		"the start harbour should be connected to every other harbour")


func test_chart_view_and_voyage_preview_agree_field_by_field() -> void:
	var context := _start_run(SEED)
	var chart := WorldOps.world_map(context.state)
	for port in chart.ports:
		WorldOps.discover_port_id(context.state, port.id)
	# 航线解锁是运行时门禁；本用例只验证「同一张海图的数值逐项一致」，先解锁全部 pair。
	for edge in chart.edges:
		WorldOps.unlock_route(
			context.state, String(edge.get("from", "")), String(edge.get("to", ""))
		)
	var view: Dictionary = SeaChartViewQuery.execute({}, context).get("data", {})
	var routes: Array = view.get("routes", [])
	assert_eq(routes.size(), chart.route_count(),
		"the chart view should expose every chart edge once all ports are discovered")

	var checked := 0
	for route in routes:
		var from_id := String(route.get("from", ""))
		var to_id := String(route.get("to", ""))
		var label := "%s-%s" % [from_id, to_id]
		# `voyage.preview` always departs from the current harbour, so move it for the check.
		_set_current_port(context, from_id)
		var preview := VoyageCalculator.preview(context, to_id, STRATEGY)
		assert_true(bool(preview.get("ok", false)),
			"voyage.preview for chart edge %s should succeed (no no_route)" % label)
		if not bool(preview.get("ok", false)):
			continue
		var data: Dictionary = preview.get("data", {})
		assert_almost_eq(float(route.get("distance", 0.0)), float(data.get("distance", 0.0)), 0.01,
			"chart distance for %s should equal voyage.preview distance" % label)
		assert_almost_eq(float(route.get("travel_hours", 0.0)),
			float(data.get("duration_hours", 0.0)), 0.05,
			"chart duration for %s should equal voyage.preview duration" % label)
		var supplies: Dictionary = route.get("supplies", {})
		assert_almost_eq(float(supplies.get("coal_required", 0.0)),
			float(data.get("coal_required", 0.0)), 0.05,
			"chart coal for %s should equal voyage.preview coal" % label)
		assert_almost_eq(float(supplies.get("water_required", 0.0)),
			float(data.get("water_required", 0.0)), 0.05,
			"chart water for %s should equal voyage.preview water" % label)
		assert_almost_eq(float(route.get("risk_level", -2.0)),
			float(data.get("risk_score", -1.0)), 0.02,
			"chart risk for %s should equal voyage.preview risk" % label)
		checked += 1
	assert_true(checked > 0, "the chart/preview cross-check should cover every chart edge")


func test_chart_world_is_deterministic() -> void:
	var first := _start_run(SEED)
	var second := _start_run(SEED)
	var first_chart: Dictionary = first.state.data.get("world_map", {})
	var second_chart: Dictionary = second.state.data.get("world_map", {})
	assert_false(first_chart.is_empty(), "seed %d should store the chart world" % SEED)
	# Fingerprints keep a failed comparison readable (a raw JSON diff is megabytes).
	assert_eq(_fingerprint(first_chart), _fingerprint(second_chart),
		"the same seed must generate the same chart world")
	assert_eq(_fingerprint(first.state.world().get("routes", [])),
		_fingerprint(second.state.world().get("routes", [])),
		"the same seed must derive the same gameplay routes from the chart")
	for seed_value in OTHER_SEEDS:
		assert_ne(_fingerprint(_start_run(seed_value).state.data.get("world_map", {})),
			_fingerprint(first_chart),
			"seed %d should generate a different chart world" % seed_value)


# ── Helpers ──

func _start_run(seed_value: int) -> AppContext:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var result := context.commands.execute(&"run.start", {
		"starting_scenario": "core:starting_scenario/steady",
		"seed": seed_value,
	})
	assert_true(bool(result.get("ok", false)), "run.start for seed %d should succeed: %s" % [
		seed_value, str(result),
	])
	return context


func _set_current_port(context: AppContext, port_id: String) -> void:
	context.state.world()["current_port_id"] = port_id
	WorldOps.set_current_port(context.state, port_id)


static func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


static func _polyline_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


func _fingerprint(value: Variant) -> int:
	return StableHash.fnv1a_32(JsonUtils.canonical_stringify(value))
