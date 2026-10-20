class_name FogOps
extends RefCounted
## @static-doc
## 作用：战争迷雾高层操作，把 FogGrid 与 WorldMap、GameState 接合。
##
## ## 契约与约束
## - `mark_coastal_cells` 把距海岸线 `COASTAL_CELLS` 个格子内的单元识别为海岸单元
##   （单位是迷雾格子，不是世界单位：`cell_size` 由视野半径决定，固定世界距离会错配）。
## - `reveal_port` 使用 `FogGrid.reveal_circle` 揭示已发现港口周边。
## - `save_fog_state` / `load_fog_state` 持久化迷雾网格与海岸单元集合。
## - `reveal_arrival` 是抵达钩子：揭示泊位并应用船视，首次调用时惰性建网格。
## - `get_visibility_at` / `is_position_visible` 是只读查询。
## @end-static-doc

## 海岸带宽度（迷雾格子数）。设计文档 §3.2 规定“距海岸线 N 个格子内”，
## 因此这里以格数为准，换算成本地距离时乘以 `cell_size`。
const COASTAL_CELLS := 2
## 领域层默认视野/港口揭示半径。`sea_chart.view` 查询与运行时初始化共用，
## 避免领域代码反向依赖应用层查询取常量。
const DEFAULT_MIN_VISION_RADIUS := 20.0
const DEFAULT_PORT_REVEAL_RADIUS := 24.0


static func create_fog_grid(world: WorldMap, min_vision_radius: float) -> FogGrid:
	return FogGrid.new(world.bounds, min_vision_radius)


static func mark_coastal_cells(fog: FogGrid, world: WorldMap) -> Dictionary:
	## Identify cells near coastlines and mark them as coastal.
	## Returns a dictionary of coastal cell keys: { "x,y": true }
	var coastal_cells := {}
	
	for landmass in world.landmasses:
		# For each landmass, find grid cells near its polygon edges
		for i in landmass.polygon.size():
			var p0: Vector2 = landmass.polygon[i]
			var p1: Vector2 = landmass.polygon[(i + 1) % landmass.polygon.size()]

			# Sample points along the edge (half a cell apart for a continuous band).
			var edge_length := p0.distance_to(p1)
			var num_samples := maxi(1, ceili(edge_length / (fog.cell_size * 0.5)))
			var band := float(COASTAL_CELLS) * fog.cell_size
			var radius_cells := COASTAL_CELLS

			for s in num_samples:
				var t := float(s) / float(num_samples)
				var point := p0.lerp(p1, t)
				var grid_pos := fog.world_to_grid(point)

				# Mark cells within COASTAL_CELLS of the sampled coastline point.
				for dy in range(-radius_cells, radius_cells + 1):
					for dx in range(-radius_cells, radius_cells + 1):
						var gx := grid_pos.x + dx
						var gy := grid_pos.y + dy
						if gx >= 0 and gx < fog.width and gy >= 0 and gy < fog.height:
							var world_pos := fog.grid_to_world(Vector2i(gx, gy))
							if point.distance_to(world_pos) <= band:
								var key := "%d,%d" % [gx, gy]
								coastal_cells[key] = true

	return coastal_cells


static func reveal_port(fog: FogGrid, port: WorldPort, port_reveal_radius: float) -> int:
	## Reveal fog around a discovered port (lamp flower effect).
	## Returns the number of cells revealed.
	return fog.reveal_circle(port.position, port_reveal_radius, FogGrid.CellState.EXPLORED)


static func update_ship_vision(fog: FogGrid, ship_pos: Vector2, vision_radius: float, coastal_cells: Dictionary) -> void:
	## Update fog state based on ship position and vision radius.
	## Coastal cells stay EXPLORED, ocean cells revert to BLACK.
	fog.update_ship_vision(ship_pos, vision_radius, coastal_cells)


static func save_fog_state(state: GameState, fog: FogGrid, coastal_cells: Dictionary) -> void:
	## Save fog grid and coastal cell data to GameState.
	if not state.data.has("fog"):
		state.data["fog"] = {}
	state.data["fog"]["grid"] = fog.to_dict()
	state.data["fog"]["coastal_cells"] = coastal_cells


static func load_fog_state(state: GameState) -> Dictionary:
	## Load fog grid and coastal cell data from GameState.
	## Returns { "fog": FogGrid, "coastal_cells": Dictionary } or empty if no fog data.
	if not state.data.has("fog"):
		return {}
	
	var fog_data: Dictionary = state.data["fog"]
	var fog: FogGrid = FogGrid.from_dict(fog_data.get("grid", {}))
	var coastal_cells: Dictionary = fog_data.get("coastal_cells", {})
	
	return {
		"fog": fog,
		"coastal_cells": coastal_cells,
	}


static func get_visibility_at(state: GameState, world_pos: Vector2) -> float:
	## Get fog alpha at a world position (0.0 = fully visible, 1.0 = fully hidden).
	var fog_state := load_fog_state(state)
	if fog_state.is_empty():
		return 0.0  # No fog = fully visible
	
	var fog: FogGrid = fog_state["fog"]
	return fog.get_alpha_at(world_pos)


static func is_position_visible(state: GameState, world_pos: Vector2) -> bool:
	## Check if a world position is visible (not in black fog).
	var fog_state := load_fog_state(state)
	if fog_state.is_empty():
		return true  # No fog = everything visible
	
	var fog: FogGrid = fog_state["fog"]
	var grid_pos := fog.world_to_grid(world_pos)
	return fog.is_cell_visible(grid_pos.x, grid_pos.y)


static func reveal_all_coastal(fog: FogGrid, world: WorldMap) -> int:
	## Debug/test helper: reveal all coastal cells as EXPLORED.
	var coastal_cells := mark_coastal_cells(fog, world)
	var revealed := 0

	for key in coastal_cells:
		var parts: PackedStringArray = key.split(",")
		var gx := int(parts[0])
		var gy := int(parts[1])
		var cell: Dictionary = fog.get_cell(gx, gy)
		if cell["state"] == FogGrid.CellState.BLACK:
			fog.set_cell(gx, gy, FogGrid.CellState.EXPLORED)
			revealed += 1

	return revealed


## Arrival hook for the coordinate-space world: reveal the port circle (lamp
## flower) and apply ship vision at the berth. Creates the persistent fog state
## on first use, so callers do not need to care whether fog was initialized yet.
static func reveal_arrival(state: GameState, world: WorldMap, port: WorldPort) -> void:
	var fog_state := load_fog_state(state)
	var fog: FogGrid = fog_state.get("fog", FogGrid.new())
	var coastal: Dictionary = fog_state.get("coastal_cells", {})
	if fog.is_empty():
		fog = create_fog_grid(world, DEFAULT_MIN_VISION_RADIUS)
		coastal = mark_coastal_cells(fog, world)
	reveal_port(fog, port, DEFAULT_PORT_REVEAL_RADIUS)
	update_ship_vision(fog, port.position, DEFAULT_MIN_VISION_RADIUS, coastal)
	save_fog_state(state, fog, coastal)
