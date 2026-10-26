class_name ChartWorldProjection
extends RefCounted
## @static-doc
## 作用：把**唯一世界**（海图 `WorldMap` / `state.data["world_map"]`）转换成玩法层使用的
## `GameState.world()` 字典（ports / routes / 起始港），让 MapOps / 委托 / 航行 / BFS
## 全部读到同一份拓扑与距离。
##
## ## 契约与约束
## - **海图是唯一真相**（2026-10-26）：`WorldMap.edges` 就是世界拓扑，本类只做形状转换，
##   不生成、不修改、不重新计算任何拓扑或距离。`GameState.world().routes[].distance`
##   ≡ `WorldMap.edges[].distance` ≡ 该边绘制路径的折线长度。
## - 输出与历史 `MapGenerator` 世界的字典形状兼容：
##   `{ports: {id: {id, name_key, description_key, archetype_id, source_mod,
##   banner_asset, diorama, facilities, tags, size, discovered, visited,
##   facilities_known, x, y}}, routes: [{a, b, distance, base_risk}],
##   discovered_ports, current_port_id, start_port_id}`。
## - 只有起始港初始为已发现 / 已访问 / 设施已知，其余港口保持迷雾状态。
## - 边顺序按港口数值编号排序（`port_0`, `port_1`, ...），与 `WorldMap.edges` 的存储顺序
##   无关，保证同 seed 输出逐字段一致。
## - `base_risk` 随边存盘（`WorldMap` 1.2）；缺失时写 0.0，只可能出现在旧海图 / 通用
##   生成器世界（战役世界总是有值）。
## @end-static-doc


## Projects the single chart world into the gameplay world dictionary.
## `world_map_data` is `WorldMap.to_dict()` (exactly what `state.data["world_map"]` holds).
static func from_chart(world_map_data: Dictionary) -> Dictionary:
	var world := WorldMap.from_dict(world_map_data)
	var start_port := world.get_start_port()
	var start_port_id := start_port.id
	var ports_data := {}
	for port in world.ports:
		ports_data[port.id] = _port_to_world_dict(port, port.id == start_port_id)
	var routes: Array = []
	var sorted_edges := _sorted_edges(world.edges)
	for edge in sorted_edges:
		routes.append({
			"a": String(edge.get("from", "")),
			"b": String(edge.get("to", "")),
			"distance": float(edge.get("distance", 0.0)),
			"base_risk": float(edge.get("base_risk", 0.0)),
		})
	return {
		"ports": ports_data,
		"routes": routes,
		"discovered_ports": [start_port_id] if not start_port_id.is_empty() else [],
		"current_port_id": start_port_id,
		"start_port_id": start_port_id,
	}


static func _port_to_world_dict(port: WorldPort, is_start: bool) -> Dictionary:
	return {
		"id": port.id,
		"name_key": port.name_key,
		"description_key": port.description_key,
		"archetype_id": port.archetype_id,
		"source_mod": port.source_mod,
		"banner_asset": port.banner_asset,
		"diorama": port.diorama.duplicate(true),
		"facilities": Array(port.facilities),
		"tags": Array(port.tags),
		"size": port.size,
		"discovered": is_start,
		"visited": is_start,
		"facilities_known": is_start,
		"x": port.position.x,
		"y": port.position.y,
	}


## Chart edges in stable port-index order, so the derived `world.routes` array is
## reproducible regardless of how the WorldMap dictionary was serialized.
static func _sorted_edges(edges: Array[Dictionary]) -> Array[Dictionary]:
	var sorted := edges.duplicate()
	sorted.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_from := _port_index(String(left.get("from", "")))
		var right_from := _port_index(String(right.get("from", "")))
		if left_from != right_from:
			return left_from < right_from
		return _port_index(String(left.get("to", ""))) < _port_index(String(right.get("to", "")))
	)
	return sorted


static func _port_index(port_id: String) -> int:
	if port_id.begins_with("port_"):
		return port_id.trim_prefix("port_").to_int()
	return 1 << 30
