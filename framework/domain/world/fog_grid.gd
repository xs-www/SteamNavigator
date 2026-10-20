class_name FogGrid
extends RefCounted
## @static-doc
## 作用：战争迷雾网格，维护未探索、已探索海岸与当前可见三种状态。
##
## ## 契约与约束
## - 单元尺寸由最小视野半径推导：`cell_size = min_vision_radius / 4`。
## - 船只离开后，海岸单元保持 `EXPLORED`，普通海洋单元回到 `BLACK`。
## - 相邻单元之间通过 alpha 插值平滑过渡。
## - 序列化必须保留 `cell_size`、宽高和全部单元状态。
## @end-static-doc

enum CellState {
	BLACK,      # Unexplored, fully opaque
	EXPLORED,   # Coastal cells visited by ship, semi-transparent (permanent)
	VISIBLE,    # Current ship vision, fully transparent (temporary)
}

var cell_size: float
var width: int
var height: int
var cells: Array[Array]  # cells[y][x] = { state: CellState, alpha: float }


func _init(world_bounds: Rect2 = Rect2(), min_vision_radius: float = 4.0) -> void:
	cell_size = maxf(1.0, min_vision_radius / 4.0)
	width = ceili(world_bounds.size.x / cell_size)
	height = ceili(world_bounds.size.y / cell_size)
	
	# Initialize all cells as BLACK
	cells.resize(height)
	for y in height:
		cells[y] = []
		cells[y].resize(width)
		for x in width:
			cells[y][x] = {"state": CellState.BLACK, "alpha": 1.0}


func is_empty() -> bool:
	return cells.is_empty()


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx := int(world_pos.x / cell_size)
	var gy := int(world_pos.y / cell_size)
	return Vector2i(clampi(gx, 0, width - 1), clampi(gy, 0, height - 1))


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		(grid_pos.x + 0.5) * cell_size,
		(grid_pos.y + 0.5) * cell_size
	)


func get_cell(gx: int, gy: int) -> Dictionary:
	if gx < 0 or gx >= width or gy < 0 or gy >= height:
		return {"state": CellState.BLACK, "alpha": 1.0}
	return cells[gy][gx]


func set_cell(gx: int, gy: int, state: CellState, alpha: float = -1.0) -> void:
	if gx < 0 or gx >= width or gy < 0 or gy >= height:
		return
	if alpha < 0.0:
		alpha = _default_alpha_for_state(state)
	cells[gy][gx] = {"state": state, "alpha": alpha}


func reveal_circle(center: Vector2, radius: float, state: CellState = CellState.EXPLORED) -> int:
	var center_grid := world_to_grid(center)
	var radius_cells := ceili(radius / cell_size)
	var revealed := 0
	
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			var gx := center_grid.x + dx
			var gy := center_grid.y + dy
			if gx < 0 or gx >= width or gy < 0 or gy >= height:
				continue
			
			# Check if within circular radius
			var world_pos := grid_to_world(Vector2i(gx, gy))
			if center.distance_to(world_pos) <= radius:
				var current: Dictionary = get_cell(gx, gy)
				# Only upgrade state (BLACK -> EXPLORED -> VISIBLE)
				if current["state"] < state:
					set_cell(gx, gy, state)
					revealed += 1
	
	return revealed


func update_ship_vision(ship_pos: Vector2, vision_radius: float, coastal_cells: Dictionary) -> void:
	# First, revert all VISIBLE cells to their previous state
	for y in height:
		for x in width:
			var cell: Dictionary = cells[y][x]
			if cell["state"] == CellState.VISIBLE:
				# Check if this is a coastal cell that should stay EXPLORED
				var key := "%d,%d" % [x, y]
				if coastal_cells.has(key):
					set_cell(x, y, CellState.EXPLORED)
				else:
					# Ocean cell: revert to BLACK
					set_cell(x, y, CellState.BLACK)
	
	# Then, reveal cells around ship
	var center_grid := world_to_grid(ship_pos)
	var radius_cells := ceili(vision_radius / cell_size)
	
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			var gx := center_grid.x + dx
			var gy := center_grid.y + dy
			if gx < 0 or gx >= width or gy < 0 or gy >= height:
				continue
			
			var world_pos := grid_to_world(Vector2i(gx, gy))
			if ship_pos.distance_to(world_pos) <= vision_radius:
				set_cell(gx, gy, CellState.VISIBLE)


func smooth_alpha_interpolation() -> void:
	# Apply Gaussian-like smoothing to alpha values
	var temp_cells: Array[Array] = []
	temp_cells.resize(height)
	
	for y in height:
		temp_cells[y] = []
		temp_cells[y].resize(width)
		
		for x in width:
			var current: Dictionary = cells[y][x]
			var sum_alpha: float = current["alpha"]
			var count: int = 1
			
			# Sample 4 neighbors
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx >= 0 and nx < width and ny >= 0 and ny < height:
					sum_alpha += cells[ny][nx]["alpha"]
					count += 1
			
			# Blend current with average of neighbors (70% current, 30% neighbors)
			var neighbor_avg: float = sum_alpha / float(count)
			var smoothed: float = current["alpha"] * 0.7 + neighbor_avg * 0.3
			temp_cells[y][x] = {"state": current["state"], "alpha": smoothed}
	
	# Apply smoothed values
	cells = temp_cells


func get_alpha_at(world_pos: Vector2) -> float:
	var grid_pos := world_to_grid(world_pos)
	return get_cell(grid_pos.x, grid_pos.y)["alpha"]


func is_cell_visible(gx: int, gy: int) -> bool:
	var cell: Dictionary = get_cell(gx, gy)
	return cell["state"] != CellState.BLACK


func count_cells_by_state() -> Dictionary:
	var counts := {
		CellState.BLACK: 0,
		CellState.EXPLORED: 0,
		CellState.VISIBLE: 0,
	}
	for y in height:
		for x in width:
			var state: int = cells[y][x]["state"]
			counts[state] += 1
	return counts


func _default_alpha_for_state(state: CellState) -> float:
	match state:
		CellState.BLACK:
			return 1.0
		CellState.EXPLORED:
			return 0.5
		CellState.VISIBLE:
			return 0.0
		_:
			return 1.0


func to_dict() -> Dictionary:
	var cells_data := []
	for y in height:
		var row := []
		for x in width:
			var cell: Dictionary = cells[y][x]
			row.append({"state": cell["state"], "alpha": cell["alpha"]})
		cells_data.append(row)
	
	return {
		"cell_size": cell_size,
		"width": width,
		"height": height,
		"cells": cells_data,
	}


static func from_dict(data: Dictionary) -> FogGrid:
	var grid := FogGrid.new()
	grid.cell_size = float(data.get("cell_size", 8.0))
	grid.width = int(data.get("width", 0))
	grid.height = int(data.get("height", 0))
	
	grid.cells.resize(grid.height)
	var cells_data: Array = data.get("cells", [])
	for y in grid.height:
		grid.cells[y] = []
		grid.cells[y].resize(grid.width)
		if y < cells_data.size():
			var row: Array = cells_data[y]
			for x in grid.width:
				if x < row.size():
					var cell: Dictionary = row[x]
					grid.cells[y][x] = {
						"state": int(cell.get("state", CellState.BLACK)),
						"alpha": float(cell.get("alpha", 1.0))
					}
				else:
					grid.cells[y][x] = {"state": CellState.BLACK, "alpha": 1.0}
		else:
			for x in grid.width:
				grid.cells[y][x] = {"state": CellState.BLACK, "alpha": 1.0}
	
	return grid
