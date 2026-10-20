extends TestCase
class_name TestFogSystem
## Tests for the fog of war system (Phase 1).
##
## Covers: FogGrid initialization, coordinate conversion, reveal_circle,
## update_ship_vision, coastal cell detection, alpha interpolation,
## serialization roundtrip, and FogOps integration.

const TEST_WORLD_SIZE := 400.0
const TEST_VISION_RADIUS := 32.0
const TEST_PORT_REVEAL_RADIUS := 24.0


func test_fog_grid_initializes_with_correct_dimensions() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(TEST_WORLD_SIZE, TEST_WORLD_SIZE))
	var fog := FogGrid.new(bounds, TEST_VISION_RADIUS)
	
	var expected_cell_size := TEST_VISION_RADIUS / 4.0  # 8.0
	var expected_width := ceili(TEST_WORLD_SIZE / expected_cell_size)  # 50
	var expected_height := ceili(TEST_WORLD_SIZE / expected_cell_size)  # 50
	
	assert_eq(fog.cell_size, expected_cell_size, "cell_size should be vision_radius / 4")
	assert_eq(fog.width, expected_width, "width should match")
	assert_eq(fog.height, expected_height, "height should match")
	
	# All cells should start as BLACK
	var counts := fog.count_cells_by_state()
	assert_eq(counts[FogGrid.CellState.BLACK], expected_width * expected_height, "all cells should start as BLACK")


func test_world_to_grid_conversion() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)  # cell_size = 2.0
	
	var grid_pos := fog.world_to_grid(Vector2(15.0, 25.0))
	assert_eq(grid_pos.x, 7, "x should be 15 / 2 = 7")
	assert_eq(grid_pos.y, 12, "y should be 25 / 2 = 12")
	
	# Test clamping to bounds
	var clamped := fog.world_to_grid(Vector2(150.0, -10.0))
	assert_eq(clamped.x, fog.width - 1, "should clamp to max x")
	assert_eq(clamped.y, 0, "should clamp to min y")


func test_grid_to_world_conversion() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)  # cell_size = 2.0
	
	# Grid position should map to cell center
	var world_pos := fog.grid_to_world(Vector2i(7, 12))
	assert_almost_eq(world_pos.x, 15.0, 0.001, "x should be (7 + 0.5) * 2 = 15")
	assert_almost_eq(world_pos.y, 25.0, 0.001, "y should be (12 + 0.5) * 2 = 25")


func test_reveal_circle_changes_cell_states() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)  # cell_size = 2.0, grid = 50x50
	
	var center := Vector2(50.0, 50.0)
	var radius := 10.0
	var revealed := fog.reveal_circle(center, radius, FogGrid.CellState.EXPLORED)
	
	assert_true(revealed > 0, "should reveal at least one cell")
	
	# Check center cell is EXPLORED
	var center_grid := fog.world_to_grid(center)
	var center_cell := fog.get_cell(center_grid.x, center_grid.y)
	assert_eq(center_cell["state"], FogGrid.CellState.EXPLORED, "center cell should be EXPLORED")
	
	# Check cells outside radius are still BLACK
	var outside := Vector2(80.0, 80.0)
	var outside_grid := fog.world_to_grid(outside)
	var outside_cell := fog.get_cell(outside_grid.x, outside_grid.y)
	assert_eq(outside_cell["state"], FogGrid.CellState.BLACK, "cells outside radius should stay BLACK")


func test_reveal_circle_respects_state_hierarchy() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)
	
	var center := Vector2(50.0, 50.0)
	var radius := 10.0
	
	# First reveal as EXPLORED
	fog.reveal_circle(center, radius, FogGrid.CellState.EXPLORED)
	
	# Try to "downgrade" to BLACK (should not work)
	var before := fog.get_cell(fog.world_to_grid(center).x, fog.world_to_grid(center).y)
	fog.reveal_circle(center, radius, FogGrid.CellState.BLACK)
	var after := fog.get_cell(fog.world_to_grid(center).x, fog.world_to_grid(center).y)
	assert_eq(before["state"], after["state"], "should not downgrade state")
	
	# Upgrade to VISIBLE (should work)
	fog.reveal_circle(center, radius, FogGrid.CellState.VISIBLE)
	var upgraded := fog.get_cell(fog.world_to_grid(center).x, fog.world_to_grid(center).y)
	assert_eq(upgraded["state"], FogGrid.CellState.VISIBLE, "should upgrade to VISIBLE")


func test_update_ship_vision_makes_cells_visible() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)
	
	var ship_pos := Vector2(50.0, 50.0)
	var vision_radius := 10.0
	var coastal_cells := {}  # No coastal cells for this test
	
	fog.update_ship_vision(ship_pos, vision_radius, coastal_cells)
	
	# Cells in vision should be VISIBLE
	var in_vision := fog.get_cell(fog.world_to_grid(ship_pos).x, fog.world_to_grid(ship_pos).y)
	assert_eq(in_vision["state"], FogGrid.CellState.VISIBLE, "cells in vision should be VISIBLE")
	
	# Cells outside vision should be BLACK (no coastal cells)
	var outside := Vector2(80.0, 80.0)
	var outside_cell := fog.get_cell(fog.world_to_grid(outside).x, fog.world_to_grid(outside).y)
	assert_eq(outside_cell["state"], FogGrid.CellState.BLACK, "ocean cells outside vision should be BLACK")


func test_coastal_cells_stay_explored_after_ship_leaves() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)
	
	var coastal_pos := Vector2(30.0, 30.0)
	var coastal_grid := fog.world_to_grid(coastal_pos)
	var coastal_key := "%d,%d" % [coastal_grid.x, coastal_grid.y]
	var coastal_cells := {coastal_key: true}
	
	# Ship visits coastal area
	fog.update_ship_vision(coastal_pos, 10.0, coastal_cells)
	var visited := fog.get_cell(coastal_grid.x, coastal_grid.y)
	assert_eq(visited["state"], FogGrid.CellState.VISIBLE, "coastal cell should be VISIBLE when ship is there")
	
	# Ship moves away
	var far_pos := Vector2(80.0, 80.0)
	fog.update_ship_vision(far_pos, 10.0, coastal_cells)
	
	# Coastal cell should revert to EXPLORED (not BLACK)
	var after := fog.get_cell(coastal_grid.x, coastal_grid.y)
	assert_eq(after["state"], FogGrid.CellState.EXPLORED, "coastal cell should stay EXPLORED after ship leaves")


func test_ocean_cells_revert_to_black_after_ship_leaves() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)
	
	var ocean_pos := Vector2(50.0, 50.0)
	var coastal_cells := {}  # No coastal cells
	
	# Ship visits ocean area
	fog.update_ship_vision(ocean_pos, 10.0, coastal_cells)
	var visited := fog.get_cell(fog.world_to_grid(ocean_pos).x, fog.world_to_grid(ocean_pos).y)
	assert_eq(visited["state"], FogGrid.CellState.VISIBLE, "ocean cell should be VISIBLE when ship is there")
	
	# Ship moves away
	var far_pos := Vector2(80.0, 80.0)
	fog.update_ship_vision(far_pos, 10.0, coastal_cells)
	
	# Ocean cell should revert to BLACK
	var after := fog.get_cell(fog.world_to_grid(ocean_pos).x, fog.world_to_grid(ocean_pos).y)
	assert_eq(after["state"], FogGrid.CellState.BLACK, "ocean cell should revert to BLACK after ship leaves")


func test_alpha_interpolation_smooths_values() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(20.0, 20.0))
	var fog := FogGrid.new(bounds, 4.0)  # cell_size = 1.0, grid = 20x20
	
	# Set up a sharp transition: left half BLACK, right half EXPLORED
	for y in fog.height:
		for x in fog.width:
			if x < fog.width / 2:
				fog.set_cell(x, y, FogGrid.CellState.BLACK, 1.0)
			else:
				fog.set_cell(x, y, FogGrid.CellState.EXPLORED, 0.5)
	
	# Check alpha before smoothing
	var boundary_left: float = fog.get_cell(fog.width / 2 - 1, fog.height / 2)["alpha"]
	var boundary_right: float = fog.get_cell(fog.width / 2, fog.height / 2)["alpha"]
	assert_eq(boundary_left, 1.0, "left side should be 1.0 before smoothing")
	assert_eq(boundary_right, 0.5, "right side should be 0.5 before smoothing")
	
	# Apply smoothing
	fog.smooth_alpha_interpolation()
	
	# After smoothing, boundary values should be closer together
	var smoothed_left: float = fog.get_cell(fog.width / 2 - 1, fog.height / 2)["alpha"]
	var smoothed_right: float = fog.get_cell(fog.width / 2, fog.height / 2)["alpha"]
	var diff_before := absf(boundary_left - boundary_right)
	var diff_after := absf(smoothed_left - smoothed_right)
	assert_true(diff_after < diff_before, "smoothing should reduce alpha difference at boundary")


func test_fog_grid_serialization_roundtrip() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)
	
	# Modify some cells
	fog.set_cell(10, 10, FogGrid.CellState.EXPLORED)
	fog.set_cell(20, 20, FogGrid.CellState.VISIBLE, 0.3)
	fog.reveal_circle(Vector2(50.0, 50.0), 15.0, FogGrid.CellState.EXPLORED)
	
	# Serialize and deserialize
	var data := fog.to_dict()
	var restored := FogGrid.from_dict(data)
	
	assert_eq(restored.cell_size, fog.cell_size, "cell_size should match")
	assert_eq(restored.width, fog.width, "width should match")
	assert_eq(restored.height, fog.height, "height should match")
	
	# Check specific cells
	var cell_10_10 := restored.get_cell(10, 10)
	assert_eq(cell_10_10["state"], FogGrid.CellState.EXPLORED, "cell (10,10) state should match")
	
	var cell_20_20 := restored.get_cell(20, 20)
	assert_eq(cell_20_20["state"], FogGrid.CellState.VISIBLE, "cell (20,20) state should match")
	assert_almost_eq(cell_20_20["alpha"], 0.3, 0.001, "cell (20,20) alpha should match")


func test_mark_coastal_cells_identifies_cells_near_land() -> void:
	# Create a simple world with one landmass
	var world := WorldMap.new()
	world.bounds = Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	
	var landmass := Landmass.new()
	landmass.polygon = PackedVector2Array([
		Vector2(20.0, 20.0),
		Vector2(40.0, 20.0),
		Vector2(40.0, 40.0),
		Vector2(20.0, 40.0),
	])
	world.landmasses.append(landmass)
	
	var fog := FogGrid.new(world.bounds, 8.0)
	var coastal_cells := FogOps.mark_coastal_cells(fog, world)
	
	assert_true(coastal_cells.size() > 0, "should identify at least one coastal cell")
	
	# Check that cells near the landmass are marked as coastal
	var land_edge := Vector2(22.0, 21.0)  # Just outside the top edge of the landmass (y=20)
	var grid_pos := fog.world_to_grid(land_edge)
	var key := "%d,%d" % [grid_pos.x, grid_pos.y]
	assert_true(coastal_cells.has(key), "cells near landmass should be marked as coastal")
	
	# Check that far cells are not marked
	var far_pos := Vector2(80.0, 80.0)
	var far_grid := fog.world_to_grid(far_pos)
	var far_key := "%d,%d" % [far_grid.x, far_grid.y]
	assert_false(coastal_cells.has(far_key), "cells far from landmass should not be coastal")


func test_reveal_port_clears_fog_in_radius() -> void:
	var world := WorldMap.new()
	world.bounds = Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	
	var fog := FogGrid.new(world.bounds, 8.0)
	
	var port := WorldPort.new()
	port.position = Vector2(50.0, 50.0)
	
	var revealed := FogOps.reveal_port(fog, port, TEST_PORT_REVEAL_RADIUS)
	
	assert_true(revealed > 0, "should reveal at least one cell")
	
	# Check port cell is EXPLORED
	var port_grid := fog.world_to_grid(port.position)
	var port_cell := fog.get_cell(port_grid.x, port_grid.y)
	assert_eq(port_cell["state"], FogGrid.CellState.EXPLORED, "port cell should be EXPLORED")


func test_fog_ops_save_and_load_state() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)
	fog.set_cell(10, 10, FogGrid.CellState.EXPLORED)
	
	var coastal_cells := {"10,10": true, "20,20": true}
	
	var state := GameState.new()
	FogOps.save_fog_state(state, fog, coastal_cells)
	
	# Load and verify
	var loaded := FogOps.load_fog_state(state)
	assert_true(loaded.has("fog"), "should have fog data")
	assert_true(loaded.has("coastal_cells"), "should have coastal_cells data")
	
	var loaded_fog: FogGrid = loaded["fog"]
	assert_eq(loaded_fog.get_cell(10, 10)["state"], FogGrid.CellState.EXPLORED, "loaded fog should match")
	
	var loaded_coastal: Dictionary = loaded["coastal_cells"]
	assert_true(loaded_coastal.has("10,10"), "loaded coastal_cells should match")


func test_get_visibility_at_returns_correct_alpha() -> void:
	var state := GameState.new()
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)
	
	fog.set_cell(10, 10, FogGrid.CellState.BLACK, 1.0)
	fog.set_cell(20, 20, FogGrid.CellState.EXPLORED, 0.5)
	
	FogOps.save_fog_state(state, fog, {})
	
	var alpha_black := FogOps.get_visibility_at(state, fog.grid_to_world(Vector2i(10, 10)))
	assert_almost_eq(alpha_black, 1.0, 0.001, "BLACK cell should have alpha 1.0")
	
	var alpha_explored := FogOps.get_visibility_at(state, fog.grid_to_world(Vector2i(20, 20)))
	assert_almost_eq(alpha_explored, 0.5, 0.001, "EXPLORED cell should have alpha 0.5")


func test_is_position_visible_checks_cell_state() -> void:
	var state := GameState.new()
	var bounds := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var fog := FogGrid.new(bounds, 8.0)
	
	fog.set_cell(10, 10, FogGrid.CellState.BLACK)
	fog.set_cell(20, 20, FogGrid.CellState.EXPLORED)
	fog.set_cell(30, 30, FogGrid.CellState.VISIBLE)
	
	FogOps.save_fog_state(state, fog, {})
	
	assert_false(FogOps.is_position_visible(state, fog.grid_to_world(Vector2i(10, 10))), "BLACK cell should not be visible")
	assert_true(FogOps.is_position_visible(state, fog.grid_to_world(Vector2i(20, 20))), "EXPLORED cell should be visible")
	assert_true(FogOps.is_position_visible(state, fog.grid_to_world(Vector2i(30, 30))), "VISIBLE cell should be visible")


func test_no_fog_state_means_everything_visible() -> void:
	var state := GameState.new()  # Empty state, no fog data
	
	# Without fog data, everything should be visible
	assert_almost_eq(FogOps.get_visibility_at(state, Vector2(50.0, 50.0)), 0.0, 0.001, "no fog should mean fully visible")
	assert_true(FogOps.is_position_visible(state, Vector2(50.0, 50.0)), "no fog should mean everything visible")
