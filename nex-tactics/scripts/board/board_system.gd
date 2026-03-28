extends RefCounted
class_name BoardSystem

var board_grid: BoardGrid
var board_presentation_3d: BoardPresentation3D

func setup(p_board_grid: BoardGrid, p_board_presentation_3d: BoardPresentation3D = null) -> BoardSystem:
	board_grid = p_board_grid
	board_presentation_3d = p_board_presentation_3d
	return self

func screen_to_coord(screen_pos: Vector2) -> Vector2i:
	if board_presentation_3d != null:
		var coord_3d: Vector2i = board_presentation_3d.screen_to_coord(screen_pos)
		if board_grid != null and board_grid.is_valid_coord(coord_3d):
			return coord_3d
	if board_grid != null:
		return board_grid.global_to_grid(screen_pos)
	return Vector2i(-1, -1)

func is_screen_over_board(screen_pos: Vector2) -> bool:
	if board_grid == null:
		return false
	return board_grid.is_valid_coord(screen_to_coord(screen_pos))

func is_coord_visible(coord: Vector2i) -> bool:
	if board_grid == null or not board_grid.is_valid_coord(coord):
		return false
	return board_grid.is_coord_visible_in_current_view(coord)

func get_unit_at_screen(screen_pos: Vector2) -> BattleUnitState:
	if board_grid == null:
		return null
	var coord: Vector2i = screen_to_coord(screen_pos)
	if not board_grid.is_valid_coord(coord):
		return null
	return board_grid.get_unit_at(coord)

func set_selected_coord(coord: Vector2i) -> void:
	if board_grid != null:
		board_grid.set_selected_coord(coord)

func clear_selection() -> void:
	if board_grid != null:
		board_grid.clear_selection()
