extends RefCounted
class_name CombatBoardState
const BattleConfigScript := preload("res://autoload/battle_config.gd")

var occupancy_by_coord: Dictionary = {}

func clear() -> void:
	occupancy_by_coord.clear()

func rebuild(unit_states: Array) -> void:
	occupancy_by_coord.clear()
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		occupancy_by_coord[_coord_key(unit_state.coord)] = unit_state

func is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < BattleConfigScript.BOARD_WIDTH and coord.y >= 0 and coord.y < BattleConfigScript.BOARD_HEIGHT

func get_unit_at(coord: Vector2i):
	return occupancy_by_coord.get(_coord_key(coord), null)

func is_cell_free(coord: Vector2i, moving_unit = null) -> bool:
	if not is_valid_coord(coord):
		return false
	var occupant = get_unit_at(coord)
	return occupant == null or occupant == moving_unit

func move_unit(unit_state, new_coord: Vector2i) -> bool:
	if unit_state == null or not unit_state.can_act():
		return false
	if not is_cell_free(new_coord, unit_state):
		return false
	occupancy_by_coord.erase(_coord_key(unit_state.coord))
	unit_state.coord = new_coord
	occupancy_by_coord[_coord_key(new_coord)] = unit_state
	return true

func remove_unit(unit_state) -> void:
	if unit_state == null:
		return
	occupancy_by_coord.erase(_coord_key(unit_state.coord))

func distance_between_cells(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func get_adjacent_coords(coord: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(coord.x, coord.y - 1),
		Vector2i(coord.x - 1, coord.y),
		Vector2i(coord.x + 1, coord.y),
		Vector2i(coord.x, coord.y + 1),
	]

func find_path_bfs(
	start_coord: Vector2i,
	target_coord: Vector2i,
	forbidden_coords: Array[Vector2i] = [],
	allow_target_occupied: bool = false,
	moving_unit = null
) -> Array[Vector2i]:
	if not is_valid_coord(start_coord) or not is_valid_coord(target_coord):
		return []
	if start_coord == target_coord:
		return [start_coord]

	var goal_lookup: Dictionary = {target_coord: true}
	var forbidden_lookup: Dictionary = _build_coord_lookup(forbidden_coords)
	return _find_path_to_goals_bfs(start_coord, goal_lookup, forbidden_lookup, allow_target_occupied, moving_unit)

func find_path_to_attack_range(
	start_coord: Vector2i,
	target_coord: Vector2i,
	attack_range: int,
	forbidden_coords: Array[Vector2i] = [],
	moving_unit = null
) -> Array[Vector2i]:
	if not is_valid_coord(start_coord) or not is_valid_coord(target_coord):
		return []
	if distance_between_cells(start_coord, target_coord) <= attack_range:
		return [start_coord]

	var goal_lookup: Dictionary = {}
	var forbidden_lookup: Dictionary = _build_coord_lookup(forbidden_coords)
	for y in range(BattleConfigScript.BOARD_HEIGHT):
		for x in range(BattleConfigScript.BOARD_WIDTH):
			var candidate := Vector2i(x, y)
			if distance_between_cells(candidate, target_coord) > attack_range:
				continue
			if forbidden_lookup.has(candidate):
				continue
			if candidate != start_coord and not is_cell_free(candidate, moving_unit):
				continue
			goal_lookup[candidate] = true

	if goal_lookup.is_empty():
		return []
	return _find_path_to_goals_bfs(start_coord, goal_lookup, forbidden_lookup, false, moving_unit)

func _find_path_to_goals_bfs(
	start_coord: Vector2i,
	goal_lookup: Dictionary,
	forbidden_lookup: Dictionary,
	allow_occupied_goals: bool,
	moving_unit = null
) -> Array[Vector2i]:
	if goal_lookup.has(start_coord):
		return [start_coord]

	var visited: Dictionary = {start_coord: true}
	var came_from: Dictionary = {}
	var frontier: Array[Vector2i] = [start_coord]
	var frontier_index: int = 0

	while frontier_index < frontier.size():
		var current: Vector2i = frontier[frontier_index]
		frontier_index += 1

		for neighbor in get_adjacent_coords(current):
			if visited.has(neighbor):
				continue
			if forbidden_lookup.has(neighbor):
				continue

			var is_goal: bool = goal_lookup.has(neighbor)
			if not _is_bfs_walkable(neighbor, start_coord, is_goal, allow_occupied_goals, moving_unit):
				continue

			visited[neighbor] = true
			came_from[neighbor] = current
			if is_goal:
				return _rebuild_bfs_path(came_from, start_coord, neighbor)
			frontier.append(neighbor)

	return []

func _is_bfs_walkable(
	coord: Vector2i,
	start_coord: Vector2i,
	is_goal: bool,
	allow_occupied_goals: bool,
	moving_unit = null
) -> bool:
	if not is_valid_coord(coord):
		return false
	if coord == start_coord:
		return true
	if is_goal and allow_occupied_goals:
		return true
	return is_cell_free(coord, moving_unit)

func _rebuild_bfs_path(came_from: Dictionary, start_coord: Vector2i, goal_coord: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal_coord]
	var current: Vector2i = goal_coord
	while current != start_coord:
		if not came_from.has(current):
			return []
		current = came_from[current]
		path.push_front(current)
	return path

func _build_coord_lookup(coords: Array[Vector2i]) -> Dictionary:
	var lookup: Dictionary = {}
	for coord in coords:
		if not is_valid_coord(coord):
			continue
		lookup[coord] = true
	return lookup

func _coord_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]
