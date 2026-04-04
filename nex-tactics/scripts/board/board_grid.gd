extends Node2D
class_name BoardGrid

signal cell_clicked(coord: Vector2i)
signal unit_right_clicked(unit_state: BattleUnitState)
signal empty_right_clicked()

var cells: Dictionary = {}
var selected_coord: Vector2i = Vector2i(-1, -1)
const UNIT_ACTOR_SCENE := preload("res://scenes/units/unit_actor.tscn")

const CELL_SIZE := 64.0
const PLAYER_ZONE_COLOR := Color(0.20, 0.35, 0.70, 0.14)
const ENEMY_ZONE_COLOR := Color(0.70, 0.25, 0.25, 0.14)
const NEUTRAL_ZONE_COLOR := Color(0.25, 0.25, 0.25, 0.08)
const HIDDEN_ZONE_COLOR := Color(0.08, 0.08, 0.10, 0.90)
const GRID_LINE_COLOR := Color(0.92, 0.92, 0.94, 0.56)
const SELECTED_CELL_COLOR := Color(0.95, 0.90, 0.25, 0.65)
const DRAG_VALID_COLOR := Color(0.36, 0.95, 0.45, 0.95)
const DRAG_INVALID_COLOR := Color(0.95, 0.36, 0.36, 0.95)
const TARGET_HIGHLIGHT_COLOR := Color(0.42, 0.92, 1.0, 0.92)

var drag_hover_coord: Vector2i = Vector2i(-1, -1)
var drag_hover_active: bool = false
var drag_hover_valid: bool = false
var current_view_mode: int = GameEnums.BoardViewMode.FULL_BATTLE
var focus_team_side: int = GameEnums.TeamSide.PLAYER
var input_enabled: bool = true
var target_highlight_coords: Array[Vector2i] = []
var observed_runtime_active: bool = false
var observed_runtime_units: Array[BattleUnitState] = []
var observed_runtime_viewer_team_side: int = GameEnums.TeamSide.PLAYER
var observed_runtime_actors: Dictionary = {}
var observed_runtime_display_coords: Dictionary = {}

@onready var board_presentation_3d: BoardPresentation3D = get_node_or_null("../BoardPresentation3D") as BoardPresentation3D

func build_grid() -> void:
	cells.clear()

	for y in range(BattleConfig.BOARD_HEIGHT):
		for x in range(BattleConfig.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			var zone := -1

			if y < BattleConfig.ENEMY_ROWS:
				zone = GameEnums.TeamSide.ENEMY
			elif y >= BattleConfig.BOARD_HEIGHT - BattleConfig.PLAYER_ROWS:
				zone = GameEnums.TeamSide.PLAYER

			cells[coord] = GridCellData.new(coord, zone)

	print("Grid criado: ", cells.size(), " celulas")
	queue_redraw()

func is_valid_coord(coord: Vector2i) -> bool:
	return cells.has(coord)

func grid_to_world(coord: Vector2i) -> Vector2:
	return Vector2(coord.x + 0.5, coord.y + 0.5) * CELL_SIZE

func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(floor(world_position.x / CELL_SIZE), floor(world_position.y / CELL_SIZE))

func get_board_rect_global() -> Rect2:
	var top_left: Vector2 = get_global_transform_with_canvas() * Vector2.ZERO
	var board_size: Vector2 = Vector2(
		BattleConfig.BOARD_WIDTH * CELL_SIZE,
		BattleConfig.BOARD_HEIGHT * CELL_SIZE
	)
	return Rect2(top_left, board_size)

func get_board_rect_world() -> Rect2:
	var board_size: Vector2 = Vector2(
		BattleConfig.BOARD_WIDTH * CELL_SIZE,
		BattleConfig.BOARD_HEIGHT * CELL_SIZE
	)
	return Rect2(global_position, board_size)

func global_to_grid(global_position: Vector2) -> Vector2i:
	if not get_board_rect_global().has_point(global_position):
		return Vector2i(-1, -1)
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * global_position
	return world_to_grid(local_position)

func get_cell(coord: Vector2i) -> GridCellData:
	if not is_valid_coord(coord):
		return null
	return cells[coord]

func get_unit_at(coord: Vector2i) -> BattleUnitState:
	var cell: GridCellData = get_cell(coord)
	if not cell:
		return null
	if cell.occupant is BattleUnitState:
		return cell.occupant as BattleUnitState
	return null

func is_coord_in_player_zone(coord: Vector2i) -> bool:
	var cell: GridCellData = get_cell(coord)
	if not cell:
		return false
	return cell.zone == GameEnums.TeamSide.PLAYER

func is_coord_in_team_zone(coord: Vector2i, team_side: int) -> bool:
	var cell: GridCellData = get_cell(coord)
	if not cell:
		return false
	return cell.zone == team_side

func is_coord_visible_in_current_view(coord: Vector2i) -> bool:
	var cell: GridCellData = get_cell(coord)
	if not cell:
		return false
	return true

func is_unit_visible_in_current_view(unit_state: BattleUnitState) -> bool:
	return _is_unit_visible_in_current_view(unit_state)

func distance_between_cells(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func get_adjacent_coords(coord: Vector2i) -> Array[Vector2i]:
	var adjacent: Array[Vector2i] = []
	var candidates: Array[Vector2i] = [
		Vector2i(coord.x + 1, coord.y),
		Vector2i(coord.x - 1, coord.y),
		Vector2i(coord.x, coord.y + 1),
		Vector2i(coord.x, coord.y - 1),
	]

	for candidate in candidates:
		if is_valid_coord(candidate):
			adjacent.append(candidate)

	return adjacent

func find_step_towards(from_coord: Vector2i, target_coord: Vector2i) -> Vector2i:
	var path: Array[Vector2i] = find_path_bfs(from_coord, target_coord, [], true)
	if path.size() >= 2:
		return path[1]
	return from_coord

func find_path_bfs(
	start_coord: Vector2i,
	target_coord: Vector2i,
	forbidden_coords: Array[Vector2i] = [],
	allow_target_occupied: bool = false
) -> Array[Vector2i]:
	if not is_valid_coord(start_coord) or not is_valid_coord(target_coord):
		return []
	if start_coord == target_coord:
		return [start_coord]

	var goal_lookup: Dictionary = {target_coord: true}
	var forbidden_lookup: Dictionary = _build_coord_lookup(forbidden_coords)
	return _find_path_to_goals_bfs(start_coord, goal_lookup, forbidden_lookup, allow_target_occupied)

func find_path_to_attack_range(
	start_coord: Vector2i,
	target_coord: Vector2i,
	attack_range: int,
	forbidden_coords: Array[Vector2i] = []
) -> Array[Vector2i]:
	if not is_valid_coord(start_coord) or not is_valid_coord(target_coord):
		return []
	if distance_between_cells(start_coord, target_coord) <= attack_range:
		return [start_coord]

	var goal_lookup: Dictionary = {}
	var forbidden_lookup: Dictionary = _build_coord_lookup(forbidden_coords)
	for coord_key in cells.keys():
		var candidate: Vector2i = coord_key
		if distance_between_cells(candidate, target_coord) > attack_range:
			continue
		if forbidden_lookup.has(candidate):
			continue
		if candidate != start_coord and not is_cell_free(candidate):
			continue
		goal_lookup[candidate] = true

	if goal_lookup.is_empty():
		return []
	return _find_path_to_goals_bfs(start_coord, goal_lookup, forbidden_lookup, false)

func _find_path_to_goals_bfs(
	start_coord: Vector2i,
	goal_lookup: Dictionary,
	forbidden_lookup: Dictionary,
	allow_occupied_goals: bool
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
			if not _is_bfs_walkable(neighbor, start_coord, is_goal, allow_occupied_goals):
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
	allow_occupied_goals: bool
) -> bool:
	if not is_valid_coord(coord):
		return false
	if coord == start_coord:
		return true
	if is_goal and allow_occupied_goals:
		var goal_cell: GridCellData = get_cell(coord)
		return goal_cell != null and not goal_cell.blocked
	return is_cell_free(coord)

func _rebuild_bfs_path(came_from: Dictionary, start_coord: Vector2i, end_coord: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [end_coord]
	var current: Vector2i = end_coord
	while current != start_coord:
		if not came_from.has(current):
			return []
		current = came_from[current]
		path.push_front(current)
	return path

func _build_coord_lookup(coords: Array[Vector2i]) -> Dictionary:
	var lookup: Dictionary = {}
	for coord in coords:
		lookup[coord] = true
	return lookup

func resolve_step_towards(
	from_coord: Vector2i,
	target_coord: Vector2i,
	team_side: int = -1,
	forbidden_coords: Array[Vector2i] = [],
	prefer_wait_on_fallback: bool = false
) -> Dictionary:
	var current_distance: int = distance_between_cells(from_coord, target_coord)
	var best_advance_coord: Vector2i = Vector2i(-1, -1)
	var best_advance_score: int = 1000000
	var best_side_coord: Vector2i = Vector2i(-1, -1)
	var best_side_score: int = 1000000
	var best_fallback_coord: Vector2i = Vector2i(-1, -1)
	var best_fallback_score: int = 1000000

	for candidate in get_adjacent_coords(from_coord):
		if forbidden_coords.has(candidate):
			continue
		if not is_cell_free(candidate):
			continue

		var candidate_distance: int = distance_between_cells(candidate, target_coord)
		var candidate_score: int = _movement_candidate_score(candidate, from_coord, target_coord, team_side)
		if candidate_distance < current_distance:
			if candidate_score < best_advance_score:
				best_advance_score = candidate_score
				best_advance_coord = candidate
		elif candidate_distance == current_distance:
			if candidate_score < best_side_score:
				best_side_score = candidate_score
				best_side_coord = candidate
		else:
			if candidate_score < best_fallback_score:
				best_fallback_score = candidate_score
				best_fallback_coord = candidate

	if is_valid_coord(best_advance_coord):
		return {"coord": best_advance_coord, "move_type": "advance"}
	if is_valid_coord(best_side_coord):
		return {"coord": best_side_coord, "move_type": "sidestep"}
	if prefer_wait_on_fallback and is_valid_coord(best_fallback_coord):
		return {"coord": from_coord, "move_type": "wait"}
	if is_valid_coord(best_fallback_coord):
		return {"coord": best_fallback_coord, "move_type": "fallback"}
	return {"coord": from_coord, "move_type": "blocked"}

func _movement_candidate_score(candidate: Vector2i, from_coord: Vector2i, target_coord: Vector2i, team_side: int) -> int:
	var target_distance: int = distance_between_cells(candidate, target_coord)
	var horizontal_delta: int = abs(candidate.x - target_coord.x)
	if team_side != GameEnums.TeamSide.PLAYER and team_side != GameEnums.TeamSide.ENEMY:
		return target_distance * 100 + horizontal_delta * 4

	var forward_progress: int = from_coord.y - candidate.y if team_side == GameEnums.TeamSide.PLAYER else candidate.y - from_coord.y
	var backward_progress: int = candidate.y - from_coord.y if team_side == GameEnums.TeamSide.PLAYER else from_coord.y - candidate.y
	return (
		target_distance * 100
		+ maxi(0, backward_progress) * 10
		+ horizontal_delta * 4
		- maxi(0, forward_progress)
	)

func is_cell_free(coord: Vector2i) -> bool:
	var cell: GridCellData = get_cell(coord)
	if not cell:
		return false
	return cell.occupant == null and not cell.blocked

func occupy_cell(coord: Vector2i, occupant: Variant) -> bool:
	var cell: GridCellData = get_cell(coord)
	if not cell:
		return false
	if cell.occupant != null or cell.blocked:
		return false
	cell.occupant = occupant
	return true

func free_cell(coord: Vector2i) -> bool:
	var cell: GridCellData = get_cell(coord)
	if not cell:
		return false
	cell.occupant = null
	cell.blocked = false
	return true

func spawn_unit(state: BattleUnitState) -> bool:
	if not state or not state.alive:
		return false
	if not is_cell_free(state.coord):
		return false
	if not occupy_cell(state.coord, state):
		return false

	var unit_actor := UNIT_ACTOR_SCENE.instantiate() as UnitActor
	if not unit_actor:
		free_cell(state.coord)
		return false

	add_child(unit_actor)
	unit_actor.setup(state, CELL_SIZE, board_presentation_3d)
	unit_actor.update_from_grid_coord(state.coord, CELL_SIZE, false)
	state.actor = unit_actor
	unit_actor.visible = _is_unit_visible_in_current_view(state)

	return true

func move_unit(state: BattleUnitState, new_coord: Vector2i) -> bool:
	if not state or not state.alive:
		return false
	if not is_cell_free(new_coord):
		return false

	var old_coord := state.coord
	free_cell(old_coord)
	if not occupy_cell(new_coord, state):
		occupy_cell(old_coord, state)
		return false

	state.coord = new_coord
	if state.actor:
		state.actor.update_from_grid_coord(new_coord, CELL_SIZE, true)
	return true

func remove_unit(state: BattleUnitState, immediate: bool = false, preserve_state: bool = false) -> bool:
	if not state:
		return false

	free_cell(state.coord)
	if not preserve_state:
		state.alive = false

	if state.actor:
		if immediate or preserve_state:
			state.actor.queue_free()
		else:
			state.actor.on_death()
		state.actor = null

	return true

func _zone_color(zone: int) -> Color:
	if zone == GameEnums.TeamSide.PLAYER:
		return PLAYER_ZONE_COLOR
	if zone == GameEnums.TeamSide.ENEMY:
		return ENEMY_ZONE_COLOR
	return NEUTRAL_ZONE_COLOR

func _coord_to_rect(coord: Vector2i) -> Rect2:
	return Rect2(Vector2(coord.x, coord.y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)

func set_drag_hover(coord: Vector2i, active: bool, valid: bool) -> void:
	drag_hover_coord = coord
	drag_hover_active = active
	drag_hover_valid = valid
	if board_presentation_3d != null:
		board_presentation_3d.set_drag_hover(coord, active, valid)
	queue_redraw()

func clear_drag_hover() -> void:
	drag_hover_coord = Vector2i(-1, -1)
	drag_hover_active = false
	drag_hover_valid = false
	if board_presentation_3d != null:
		board_presentation_3d.clear_drag_hover()
	queue_redraw()

func clear_selection() -> void:
	selected_coord = Vector2i(-1, -1)
	if board_presentation_3d != null:
		board_presentation_3d.clear_selection()
	queue_redraw()

func set_selected_coord(coord: Vector2i) -> void:
	selected_coord = coord
	if board_presentation_3d != null:
		board_presentation_3d.set_selected_coord(coord)
	queue_redraw()

func set_view_mode(view_mode: int, p_focus_team_side: int = GameEnums.TeamSide.PLAYER) -> void:
	current_view_mode = view_mode
	focus_team_side = p_focus_team_side
	if board_presentation_3d != null:
		board_presentation_3d.set_view_mode(view_mode, p_focus_team_side)
	_refresh_unit_visibility()
	queue_redraw()

func set_input_enabled(value: bool) -> void:
	input_enabled = value

func set_target_highlights(coords: Array[Vector2i]) -> void:
	target_highlight_coords = []
	for coord in coords:
		if is_valid_coord(coord):
			target_highlight_coords.append(coord)
	if board_presentation_3d != null:
		board_presentation_3d.set_target_highlights(target_highlight_coords)
	queue_redraw()

func clear_target_highlights() -> void:
	target_highlight_coords.clear()
	if board_presentation_3d != null:
		board_presentation_3d.clear_target_highlights()
	queue_redraw()

func bind_observed_runtime(
	unit_states: Array[BattleUnitState],
	viewer_team_side: int = GameEnums.TeamSide.PLAYER
) -> void:
	clear_observed_runtime()
	observed_runtime_active = true
	observed_runtime_units = unit_states
	observed_runtime_viewer_team_side = viewer_team_side
	_set_runtime_unit_actor_visibility(false)
	_sync_observed_runtime_actors(false)
	_refresh_unit_visibility()
	queue_redraw()

func refresh_observed_runtime(
	animate: bool = true,
	viewer_team_side: int = -1
) -> void:
	if not observed_runtime_active:
		return
	if viewer_team_side >= 0:
		observed_runtime_viewer_team_side = viewer_team_side
	_sync_observed_runtime_actors(animate)
	_refresh_unit_visibility()
	queue_redraw()

func clear_observed_runtime() -> void:
	for actor_key in observed_runtime_actors.keys():
		_release_observed_runtime_actor(str(actor_key))
	observed_runtime_units = []
	observed_runtime_active = false
	observed_runtime_viewer_team_side = GameEnums.TeamSide.PLAYER
	_set_runtime_unit_actor_visibility(true)
	_refresh_unit_visibility()
	queue_redraw()

func is_observer_mode_active() -> bool:
	return observed_runtime_active

func get_observed_unit_at(coord: Vector2i) -> BattleUnitState:
	if not observed_runtime_active:
		return null
	for observed_state in observed_runtime_units:
		if observed_state == null or not observed_state.can_act():
			continue
		if not is_observed_unit_visible_in_current_view(observed_state):
			continue
		if get_observed_display_coord(observed_state) == coord:
			return observed_state
	return null

func set_observed_overlay_suppressed(value: bool) -> void:
	for actor_variant in observed_runtime_actors.values():
		var actor: UnitActor = actor_variant as UnitActor
		if actor == null:
			continue
		actor.set_overlay_suppressed(value)

func _refresh_unit_visibility() -> void:
	if observed_runtime_active:
		for actor_variant in observed_runtime_actors.values():
			var actor: UnitActor = actor_variant as UnitActor
			if actor == null:
				continue
			actor.visible = is_observed_unit_visible_in_current_view(actor.state)
		_set_runtime_unit_actor_visibility(false)
		return

	for coord in cells.keys():
		var occupant: BattleUnitState = get_unit_at(coord)
		if occupant == null or occupant.actor == null:
			continue
		occupant.actor.visible = _is_unit_visible_in_current_view(occupant)

func _is_unit_visible_in_current_view(unit_state: BattleUnitState) -> bool:
	if unit_state == null:
		return false
	if current_view_mode == GameEnums.BoardViewMode.FULL_BATTLE:
		return true
	return unit_state.team_side == focus_team_side

func _get_coord_from_screen_pos(screen_pos: Vector2) -> Vector2i:
	return global_to_grid(screen_pos)

func _draw() -> void:
	if board_presentation_3d != null:
		return

	var draw_overlay_details: bool = true
	for coord in cells.keys():
		var cell: GridCellData = cells[coord]
		var rect := _coord_to_rect(coord)
		var cell_color: Color = _zone_color(cell.zone)
		if not is_coord_visible_in_current_view(coord):
			cell_color = HIDDEN_ZONE_COLOR
		if not is_coord_visible_in_current_view(coord):
			draw_rect(rect, cell_color, true)
			draw_rect(rect, GRID_LINE_COLOR, false, 1.0)
		elif draw_overlay_details:
			draw_rect(rect, cell_color, true)
			draw_rect(rect, GRID_LINE_COLOR, false, 1.0)

	if not draw_overlay_details:
		return

	if is_valid_coord(selected_coord):
		if is_coord_visible_in_current_view(selected_coord):
			draw_rect(_coord_to_rect(selected_coord), SELECTED_CELL_COLOR, false, 4.0)

	for coord in target_highlight_coords:
		if is_valid_coord(coord) and is_coord_visible_in_current_view(coord):
			draw_rect(_coord_to_rect(coord), TARGET_HIGHLIGHT_COLOR, false, 4.0)

	if drag_hover_active and is_valid_coord(drag_hover_coord):
		if is_coord_visible_in_current_view(drag_hover_coord):
			var hover_color := DRAG_VALID_COLOR if drag_hover_valid else DRAG_INVALID_COLOR
			draw_rect(_coord_to_rect(drag_hover_coord), hover_color, false, 4.0)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if observed_runtime_active:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
			return
		var clicked_coord := _get_coord_from_screen_pos(mouse_event.position)

		if not is_valid_coord(clicked_coord):
			return
		if not is_coord_visible_in_current_view(clicked_coord):
			return

		set_selected_coord(clicked_coord)
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			print("Celula clicada: ", clicked_coord)
			cell_clicked.emit(clicked_coord)
		else:
			var clicked_unit: BattleUnitState = get_unit_at(clicked_coord)
			if clicked_unit != null:
				unit_right_clicked.emit(clicked_unit)
			else:
				empty_right_clicked.emit()

func _ready() -> void:
	build_grid()
	set_view_mode(GameEnums.BoardViewMode.FULL_BATTLE, GameEnums.TeamSide.PLAYER)

func _set_runtime_unit_actor_visibility(value: bool) -> void:
	for coord in cells.keys():
		var occupant: BattleUnitState = get_unit_at(coord)
		if occupant == null or occupant.actor == null:
			continue
		occupant.actor.visible = value and _is_unit_visible_in_current_view(occupant)

func _sync_observed_runtime_actors(animate: bool) -> void:
	var active_actor_keys: Dictionary = {}
	for observed_state in observed_runtime_units:
		if observed_state == null or observed_state.unit_data == null or not observed_state.can_act():
			continue

		var actor_key: String = _observed_runtime_actor_key(observed_state)
		active_actor_keys[actor_key] = true
		var display_team_side: int = get_observed_display_team_side(observed_state)

		var actor: UnitActor = observed_runtime_actors.get(actor_key, null) as UnitActor
		if actor == null:
			actor = UNIT_ACTOR_SCENE.instantiate() as UnitActor
			if actor == null:
				continue
			add_child(actor)
			actor.setup(observed_state, CELL_SIZE, board_presentation_3d)
			actor.set_display_team_side_override(display_team_side)
			observed_runtime_actors[actor_key] = actor
			observed_runtime_display_coords[actor_key] = Vector2i(-1, -1)

		var display_coord: Vector2i = get_observed_display_coord(observed_state)
		var previous_coord: Vector2i = observed_runtime_display_coords.get(actor_key, Vector2i(-1, -1))
		if previous_coord != display_coord:
			actor.update_from_grid_coord(
				display_coord,
				CELL_SIZE,
				animate and previous_coord != Vector2i(-1, -1),
				false
			)
			observed_runtime_display_coords[actor_key] = display_coord
		actor.set_display_team_side_override(display_team_side)
		actor.refresh_from_state()
		actor.visible = is_observed_unit_visible_in_current_view(observed_state)

	for actor_key_variant in observed_runtime_actors.keys():
		var actor_key: String = str(actor_key_variant)
		if active_actor_keys.has(actor_key):
			continue
		_release_observed_runtime_actor(actor_key)

func _release_observed_runtime_actor(actor_key: String) -> void:
	var actor: UnitActor = observed_runtime_actors.get(actor_key, null) as UnitActor
	if actor != null:
		actor.queue_free()
	observed_runtime_actors.erase(actor_key)
	observed_runtime_display_coords.erase(actor_key)

func _observed_runtime_actor_key(unit_state: BattleUnitState) -> String:
	if unit_state == null:
		return ""
	return str(unit_state.get_instance_id())

func get_observed_viewer_team_side() -> int:
	return observed_runtime_viewer_team_side

func get_observed_display_team_side(unit_state: BattleUnitState) -> int:
	if unit_state == null:
		return GameEnums.TeamSide.PLAYER
	return GameEnums.TeamSide.PLAYER if unit_state.team_side == observed_runtime_viewer_team_side else GameEnums.TeamSide.ENEMY

func get_observed_display_coord(unit_state: BattleUnitState) -> Vector2i:
	if unit_state == null:
		return Vector2i(-1, -1)
	if observed_runtime_viewer_team_side != GameEnums.TeamSide.ENEMY:
		return unit_state.coord
	return Vector2i(unit_state.coord.x, BattleConfig.BOARD_HEIGHT - 1 - unit_state.coord.y)

func is_observed_unit_visible_in_current_view(unit_state: BattleUnitState) -> bool:
	if unit_state == null:
		return false
	if current_view_mode == GameEnums.BoardViewMode.FULL_BATTLE:
		return true
	return get_observed_display_team_side(unit_state) == focus_team_side
