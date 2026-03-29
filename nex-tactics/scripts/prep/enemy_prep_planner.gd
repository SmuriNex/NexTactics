extends RefCounted
class_name EnemyPrepPlanner

const CENTER_COLUMNS: Array[int] = [3, 2, 4, 1, 5, 0, 6]
const FRONTLINE_CLASSES: Array[int] = [
	GameEnums.ClassType.TANK,
]
const MIDLINE_CLASSES: Array[int] = [
	GameEnums.ClassType.ATTACKER,
]
const BACKLINE_CLASSES: Array[int] = [
	GameEnums.ClassType.STEALTH,
	GameEnums.ClassType.SNIPER,
	GameEnums.ClassType.SUPPORT,
]

func build_deploy_orders(
	board_grid: BoardGrid,
	deploy_pool: Array,
	available_gold: int,
	current_field_count: int,
	field_limit: int,
	round_number: int = 1
) -> Dictionary:
	var occupied_coords: Array[Vector2i] = _collect_occupied_enemy_coords(board_grid)
	var deploy_orders: Array[Dictionary] = []
	var effective_gold_budget: int = _effective_gold_budget(available_gold, round_number)
	var remaining_gold: int = effective_gold_budget
	var remaining_field_count: int = current_field_count
	var effective_field_limit: int = _effective_field_limit(field_limit, round_number)
	var slot_indexes: Array[int] = _sorted_slot_indexes(deploy_pool, round_number)

	for slot_index in slot_indexes:
		if remaining_field_count >= effective_field_limit:
			break
		if slot_index < 0 or slot_index >= deploy_pool.size():
			continue

		var option = deploy_pool[slot_index]
		if option == null or option.used:
			continue
		if option.unit_data == null:
			continue
		if option.unit_data.cost > remaining_gold:
			continue

		var target_coord: Vector2i = _choose_enemy_coord(
			board_grid,
			option.unit_data.class_type,
			occupied_coords
		)
		if not board_grid.is_valid_coord(target_coord):
			continue

		deploy_orders.append({
			"slot_index": slot_index,
			"coord": target_coord,
			"unit_name": option.unit_data.display_name,
			"cost": option.unit_data.cost,
		})
		occupied_coords.append(target_coord)
		remaining_gold -= option.unit_data.cost
		remaining_field_count += 1

	return {
		"orders": deploy_orders,
		"gold_left": remaining_gold,
		"gold_budget": effective_gold_budget,
		"field_limit": effective_field_limit,
		"fairness_active": effective_field_limit < field_limit or effective_gold_budget < available_gold,
	}

func _effective_field_limit(field_limit: int, round_number: int) -> int:
	if round_number <= 1:
		return mini(field_limit, 1)
	if round_number == 2:
		return mini(field_limit, 2)
	if round_number == 3:
		return mini(field_limit, 3)
	return field_limit

func _effective_gold_budget(available_gold: int, round_number: int) -> int:
	if round_number <= 1:
		return mini(available_gold, 2)
	if round_number == 2:
		return mini(available_gold, 3)
	if round_number == 3:
		return mini(available_gold, 4)
	return available_gold

func _sorted_slot_indexes(deploy_pool: Array, round_number: int) -> Array[int]:
	var slot_indexes: Array[int] = []
	for index in range(deploy_pool.size()):
		slot_indexes.append(index)
	slot_indexes.sort_custom(_sort_slot_indexes.bind(deploy_pool, round_number))
	return slot_indexes

func _sort_slot_indexes(a: int, b: int, deploy_pool: Array, round_number: int) -> bool:
	var option_a = deploy_pool[a]
	var option_b = deploy_pool[b]
	if option_a == null:
		return false
	if option_b == null:
		return true

	var priority_a: int = _class_priority(option_a.unit_data.class_type, round_number)
	var priority_b: int = _class_priority(option_b.unit_data.class_type, round_number)
	if priority_a != priority_b:
		return priority_a < priority_b
	if round_number <= 2 and option_a.unit_data.cost != option_b.unit_data.cost:
		return option_a.unit_data.cost < option_b.unit_data.cost
	if option_a.unit_data.cost != option_b.unit_data.cost:
		return option_a.unit_data.cost > option_b.unit_data.cost
	return option_a.unit_data.display_name < option_b.unit_data.display_name

func _class_priority(class_type: int, round_number: int) -> int:
	if round_number <= 2:
		if MIDLINE_CLASSES.has(class_type):
			return 0
		if FRONTLINE_CLASSES.has(class_type):
			return 1
		if BACKLINE_CLASSES.has(class_type):
			return 2
		return 3
	if FRONTLINE_CLASSES.has(class_type):
		return 0
	if MIDLINE_CLASSES.has(class_type):
		return 1
	if BACKLINE_CLASSES.has(class_type):
		return 2
	return 3

func _choose_enemy_coord(board_grid: BoardGrid, class_type: int, occupied_coords: Array[Vector2i]) -> Vector2i:
	var preferred_rows: Array[int] = _preferred_rows_for_class(class_type)
	for row in preferred_rows:
		for column in CENTER_COLUMNS:
			var coord := Vector2i(column, row)
			if _is_free_enemy_coord(board_grid, coord, occupied_coords):
				return coord

	for row in range(BattleConfig.ENEMY_ROWS):
		for column in CENTER_COLUMNS:
			var fallback_coord := Vector2i(column, row)
			if _is_free_enemy_coord(board_grid, fallback_coord, occupied_coords):
				return fallback_coord

	return Vector2i(-1, -1)

func _preferred_rows_for_class(class_type: int) -> Array[int]:
	if FRONTLINE_CLASSES.has(class_type):
		return [BattleConfig.ENEMY_ROWS - 1, 0]
	if MIDLINE_CLASSES.has(class_type):
		return [0, BattleConfig.ENEMY_ROWS - 1]
	return [0, BattleConfig.ENEMY_ROWS - 1]

func _is_free_enemy_coord(board_grid: BoardGrid, coord: Vector2i, occupied_coords: Array[Vector2i]) -> bool:
	if board_grid == null:
		return false
	if not board_grid.is_valid_coord(coord):
		return false
	if not board_grid.is_coord_in_team_zone(coord, GameEnums.TeamSide.ENEMY):
		return false
	if occupied_coords.has(coord):
		return false
	return board_grid.is_cell_free(coord)

func _collect_occupied_enemy_coords(board_grid: BoardGrid) -> Array[Vector2i]:
	var occupied_coords: Array[Vector2i] = []
	if board_grid == null:
		return occupied_coords

	for y in range(BattleConfig.ENEMY_ROWS):
		for x in range(BattleConfig.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			var unit_state: BattleUnitState = board_grid.get_unit_at(coord)
			if unit_state != null and unit_state.team_side == GameEnums.TeamSide.ENEMY:
				occupied_coords.append(coord)
	return occupied_coords
