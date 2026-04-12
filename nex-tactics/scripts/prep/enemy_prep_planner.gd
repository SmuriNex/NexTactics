extends RefCounted
class_name EnemyPrepPlanner
const BattleConfigScript := preload("res://autoload/battle_config.gd")

const FRONTLINE_CENTER_COLUMNS: Array[int] = [3, 2, 4]
const MIDLINE_COLUMNS: Array[int] = [3, 2, 4, 1, 5]
const BACKLINE_PROTECTED_COLUMNS: Array[int] = [2, 4, 3, 1, 5]
const FLANK_COLUMNS: Array[int] = [0, 1, 5, 6]
const FALLBACK_COLUMNS: Array[int] = [3, 2, 4, 1, 5, 0, 6]
const CARD_USE_SCORE_THRESHOLD := 35
const FORMATION_REPLACE_SCORE_MARGIN := 24

func build_deploy_orders(
	board_grid: BoardGrid,
	deploy_pool: Array,
	available_gold: int,
	current_field_count: int,
	field_limit: int,
	round_number: int = 1
) -> Dictionary:
	var effective_gold_budget: int = _effective_gold_budget(available_gold, round_number)
	var effective_field_limit: int = _effective_field_limit(field_limit, round_number)
	var current_units: Array[Dictionary] = _collect_board_units(board_grid, GameEnums.TeamSide.ENEMY)
	var candidate_entries: Array[Dictionary] = _build_candidate_entries_from_deploy_pool(deploy_pool)
	var master_data: UnitData = _extract_master_unit_data(current_units)
	var deck_average_power: float = _calculate_average_candidate_power(candidate_entries)
	var purchase_result: Dictionary = build_purchase_plan(
		candidate_entries,
		current_units,
		effective_gold_budget,
		current_field_count,
		effective_field_limit,
		GameEnums.TeamSide.ENEMY,
		master_data,
		deck_average_power,
		"enemy_local"
	)
	return {
		"orders": purchase_result.get("orders", []),
		"gold_left": int(purchase_result.get("gold_left", effective_gold_budget)),
		"gold_budget": effective_gold_budget,
		"field_limit": effective_field_limit,
		"fairness_active": effective_field_limit < field_limit or effective_gold_budget < available_gold,
	}

func build_purchase_plan(
	candidate_entries: Array[Dictionary],
	current_units: Array[Dictionary],
	available_gold: int,
	current_field_count: int,
	field_limit: int,
	team_side: int,
	master_data: UnitData = null,
	deck_average_power: float = 0.0,
	debug_tag: String = ""
) -> Dictionary:
	var orders: Array[Dictionary] = []
	var remaining_gold: int = available_gold
	var remaining_field_count: int = current_field_count
	var occupied_coords: Array[Vector2i] = _collect_occupied_coords(current_units)
	var allied_units: Array[Dictionary] = []
	for unit_entry in current_units:
		allied_units.append(unit_entry.duplicate(true))

	var remaining_candidates: Array[Dictionary] = []
	for candidate in candidate_entries:
		remaining_candidates.append(candidate)

	while remaining_field_count < field_limit and not remaining_candidates.is_empty():
		var best_index: int = -1
		var best_score: int = -100000
		var best_candidate: Dictionary = {}
		for index in range(remaining_candidates.size()):
			var candidate: Dictionary = remaining_candidates[index]
			var unit_data: UnitData = candidate.get("unit_data", null)
			if unit_data == null:
				continue
			var cost = unit_data.get_effective_cost()
			if cost > remaining_gold:
				continue
			var score: int = calculate_unit_weight(
				unit_data,
				{
					"allied_units": allied_units,
					"master_data": master_data,
					"deck_average_power": deck_average_power,
				},
				{
					"current_gold": remaining_gold,
				}
			)
			if best_index == -1 or score > best_score or (score == best_score and cost < best_candidate.get("unit_data", unit_data).get_effective_cost()):
				best_index = index
				best_score = score
				best_candidate = candidate

		if best_index == -1:
			break
		if remaining_gold >= 20 and best_score < 40:
			break

		var chosen_unit: UnitData = best_candidate.get("unit_data", null)
		if chosen_unit == null:
			remaining_candidates.remove_at(best_index)
			continue
		var target_coord: Vector2i = get_best_coord_for_class(chosen_unit.class_type, occupied_coords, team_side)
		if not _is_valid_coord(target_coord):
			remaining_candidates.remove_at(best_index)
			continue

		if not debug_tag.is_empty():
			print("BOT_SCORE bot=%s unit=%s score=%d" % [debug_tag, chosen_unit.id, best_score])
			print("BOT_BUY bot=%s unit=%s cost=%d gold_before=%d" % [debug_tag, chosen_unit.id, chosen_unit.get_effective_cost(), remaining_gold])
			print("BOT_POSITION bot=%s unit=%s coord=%s" % [debug_tag, chosen_unit.id, target_coord])

		orders.append({
			"slot_index": int(best_candidate.get("slot_index", -1)),
			"unit_data": chosen_unit,
			"unit_path": str(best_candidate.get("unit_path", "")),
			"unit_name": chosen_unit.display_name,
			"cost": chosen_unit.get_effective_cost(),
			"coord": target_coord,
			"score": best_score,
		})
		occupied_coords.append(target_coord)
		allied_units.append(_build_planner_unit_entry(chosen_unit, target_coord, false, team_side))
		remaining_gold -= chosen_unit.get_effective_cost()
		remaining_field_count += 1
		remaining_candidates.remove_at(best_index)

	return {
		"orders": orders,
		"gold_left": remaining_gold,
	}

func build_formation_plan(
	candidate_entries: Array[Dictionary],
	current_units: Array[Dictionary],
	available_gold: int,
	field_limit: int,
	team_side: int,
	master_data: UnitData = null,
	deck_average_power: float = 0.0,
	debug_tag: String = ""
) -> Dictionary:
	var selected_units: Array[Dictionary] = []
	var remaining_candidates: Array[Dictionary] = []
	var remaining_gold: int = maxi(0, available_gold)
	var target_field_limit: int = maxi(0, field_limit)
	var initial_units_count: int = 0
	var fill_attempted: bool = false
	var fill_stop_reason: String = "already_at_cap"
	var fill_stop_detail: String = ""
	var slots_added: int = 0

	for unit_entry in current_units:
		var unit_data: UnitData = unit_entry.get("unit_data", null)
		if unit_data == null:
			continue
		selected_units.append(unit_entry.duplicate(true))
	initial_units_count = selected_units.size()

	var selected_ids: Dictionary = {}
	for unit_entry in selected_units:
		var unit_data: UnitData = unit_entry.get("unit_data", null)
		if unit_data == null:
			continue
		selected_ids[unit_data.id] = true

	for candidate in candidate_entries:
		var unit_data: UnitData = candidate.get("unit_data", null)
		if unit_data == null:
			continue
		if selected_ids.has(unit_data.id):
			continue
		remaining_candidates.append(candidate.duplicate(true))

	while selected_units.size() > target_field_limit:
		var weakest_index: int = _find_weakest_planned_unit_index(
			selected_units,
			master_data,
			deck_average_power,
			remaining_gold
		)
		if weakest_index < 0:
			break
		var removed_entry: Dictionary = selected_units[weakest_index]
		var removed_data: UnitData = removed_entry.get("unit_data", null)
		if removed_data != null:
			selected_ids.erase(removed_data.id)
		selected_units.remove_at(weakest_index)

	fill_attempted = selected_units.size() < target_field_limit
	if target_field_limit <= 0:
		fill_stop_reason = "invalid_field_limit"
	elif not fill_attempted:
		fill_stop_reason = "already_at_cap"

	while selected_units.size() < target_field_limit:
		var candidate_choice: Dictionary = _pick_best_candidate_for_units(
			remaining_candidates,
			selected_units,
			remaining_gold,
			master_data,
			deck_average_power
		)
		var best_index: int = int(candidate_choice.get("index", -1))
		if best_index < 0:
			var cheapest_candidate_cost: int = _cheapest_candidate_cost(remaining_candidates)
			if remaining_candidates.is_empty():
				fill_stop_reason = "no_eligible_unit"
				fill_stop_detail = "nenhuma unidade elegivel restante"
			elif cheapest_candidate_cost > remaining_gold:
				fill_stop_reason = "insufficient_gold"
				fill_stop_detail = "ouro_restante=%d menor_custo=%d" % [remaining_gold, cheapest_candidate_cost]
			else:
				fill_stop_reason = "planner_blocked_fill"
				fill_stop_detail = "candidatos_restantes=%d" % remaining_candidates.size()
			break

		var chosen_candidate: Dictionary = candidate_choice.get("candidate", {})
		var chosen_unit: UnitData = chosen_candidate.get("unit_data", null)
		if chosen_unit == null:
			remaining_candidates.remove_at(best_index)
			continue

		selected_units.append(_build_planner_unit_entry(
			chosen_unit,
			Vector2i(-1, -1),
			false,
			team_side,
			-1,
			str(chosen_candidate.get("unit_path", ""))
		))
		selected_ids[chosen_unit.id] = true
		remaining_gold -= chosen_unit.get_effective_cost()
		slots_added += 1
		remaining_candidates.remove_at(best_index)
		if not debug_tag.is_empty():
			print("BOT_FORMATION_ADD bot=%s unit=%s score=%d gold_left=%d" % [
				debug_tag,
				chosen_unit.id,
				int(candidate_choice.get("score", 0)),
				remaining_gold,
			])

	while not selected_units.is_empty():
		var replacement_choice: Dictionary = _pick_best_candidate_for_units(
			remaining_candidates,
			selected_units,
			remaining_gold,
			master_data,
			deck_average_power
		)
		var replacement_index: int = int(replacement_choice.get("index", -1))
		if replacement_index < 0:
			break
		var weakest_selected_index: int = _find_weakest_planned_unit_index(
			selected_units,
			master_data,
			deck_average_power,
			remaining_gold
		)
		if weakest_selected_index < 0:
			break

		var weakest_score: int = _score_existing_unit_for_field(
			selected_units,
			weakest_selected_index,
			master_data,
			deck_average_power,
			remaining_gold
		)
		var replacement_score: int = int(replacement_choice.get("score", -100000))
		if replacement_score <= weakest_score + FORMATION_REPLACE_SCORE_MARGIN:
			break

		var weakest_entry: Dictionary = selected_units[weakest_selected_index]
		var weakest_data: UnitData = weakest_entry.get("unit_data", null)
		var replacement_candidate: Dictionary = replacement_choice.get("candidate", {})
		var replacement_data: UnitData = replacement_candidate.get("unit_data", null)
		if replacement_data == null:
			remaining_candidates.remove_at(replacement_index)
			continue

		selected_units[weakest_selected_index] = _build_planner_unit_entry(
			replacement_data,
			Vector2i(-1, -1),
			false,
			team_side,
			-1,
			str(replacement_candidate.get("unit_path", ""))
		)
		remaining_gold -= replacement_data.get_effective_cost()
		remaining_candidates.remove_at(replacement_index)
		selected_ids.erase(weakest_data.id if weakest_data != null else "")
		selected_ids[replacement_data.id] = true
		if not debug_tag.is_empty():
			print("BOT_FORMATION_SWAP bot=%s out=%s in=%s old_score=%d new_score=%d gold_left=%d" % [
				debug_tag,
				weakest_data.id if weakest_data != null else "unknown",
				replacement_data.id,
				weakest_score,
				replacement_score,
				remaining_gold,
			])

	var laid_out_units: Array[Dictionary] = _layout_planned_units(selected_units, team_side)
	if laid_out_units.size() >= target_field_limit and target_field_limit > 0:
		fill_stop_reason = "filled_to_cap" if fill_attempted else "already_at_cap"
		fill_stop_detail = ""
	elif laid_out_units.size() < selected_units.size():
		fill_stop_reason = "layout_blocked"
		fill_stop_detail = "layout=%d selected=%d" % [laid_out_units.size(), selected_units.size()]
	return {
		"selected_units": laid_out_units,
		"gold_left": remaining_gold,
		"spent_gold": maxi(0, available_gold - remaining_gold),
		"initial_units_count": initial_units_count,
		"target_field_limit": target_field_limit,
		"fill_attempted": fill_attempted,
		"slots_added": slots_added,
		"empty_slots_remaining": maxi(0, target_field_limit - laid_out_units.size()),
		"fill_stop_reason": fill_stop_reason,
		"fill_stop_detail": fill_stop_detail,
	}

func calculate_unit_weight(unit_data: UnitData, board_state: Dictionary, gold_state: Dictionary) -> int:
	if unit_data == null:
		return -100000
	var allied_units: Array = board_state.get("allied_units", [])
	var master_data: UnitData = board_state.get("master_data", null)
	var deck_average_power: float = float(board_state.get("deck_average_power", 0.0))
	var current_gold: int = int(gold_state.get("current_gold", 0))

	var score: int = 0
	score += _synergy_weight_for_tag(unit_data.race, allied_units, "race")
	score += _synergy_weight_for_tag(unit_data.class_type, allied_units, "class_type")

	if not _has_class(allied_units, GameEnums.ClassType.TANK) and unit_data.class_type == GameEnums.ClassType.TANK:
		score += 100
	if not _has_class(allied_units, GameEnums.ClassType.SUPPORT) and unit_data.class_type == GameEnums.ClassType.SUPPORT:
		score += 60
	if not _has_ranged_damage(allied_units) and _is_ranged_damage_unit(unit_data):
		score += 40

	if master_data != null and (unit_data.race == master_data.race or unit_data.class_type == master_data.class_type):
		score += 30

	if current_gold > 10:
		score += 20
	if unit_data.get_effective_cost() <= maxi(1, int(ceil(float(current_gold) / 4.0))):
		score += 10

	var unit_power: int = _estimate_unit_power(unit_data, false)
	if deck_average_power > 0.0 and float(unit_power) > deck_average_power:
		score += 15

	return score

func get_best_coord_for_class(class_type: int, occupied_cells: Array[Vector2i], team_side: int) -> Vector2i:
	var rows: Dictionary = _rows_for_team(team_side)
	var front_row: int = int(rows.get("front", 0))
	var back_row: int = int(rows.get("back", 0))
	var preferred_coords: Array[Vector2i] = []

	match class_type:
		GameEnums.ClassType.TANK:
			preferred_coords = _coords_from_columns(FRONTLINE_CENTER_COLUMNS, front_row)
		GameEnums.ClassType.ATTACKER:
			preferred_coords = _coords_from_columns(FRONTLINE_CENTER_COLUMNS, front_row)
			preferred_coords.append_array(_coords_from_columns(MIDLINE_COLUMNS, back_row))
		GameEnums.ClassType.SUPPORT:
			preferred_coords = _coords_from_columns(BACKLINE_PROTECTED_COLUMNS, back_row)
			preferred_coords.append_array(_coords_from_columns(FRONTLINE_CENTER_COLUMNS, front_row))
		GameEnums.ClassType.SNIPER:
			preferred_coords = _coords_from_columns(BACKLINE_PROTECTED_COLUMNS, back_row)
			preferred_coords.append_array(_coords_from_columns(MIDLINE_COLUMNS, front_row))
		GameEnums.ClassType.STEALTH:
			preferred_coords = _coords_from_columns(FLANK_COLUMNS, front_row)
			preferred_coords.append_array(_coords_from_columns(FLANK_COLUMNS, back_row))
		_:
			preferred_coords = _coords_from_columns(FRONTLINE_CENTER_COLUMNS, front_row)
			preferred_coords.append_array(_coords_from_columns(BACKLINE_PROTECTED_COLUMNS, back_row))

	for coord in preferred_coords:
		if not occupied_cells.has(coord):
			return coord

	for row in [front_row, back_row]:
		for column in FALLBACK_COLUMNS:
			var fallback_coord := Vector2i(column, row)
			if not occupied_cells.has(fallback_coord):
				return fallback_coord

	return Vector2i(-1, -1)

func build_card_orders(
	card_entries: Array[Dictionary],
	allied_units: Array[Dictionary],
	enemy_units: Array[Dictionary],
	owner_team_side: int,
	debug_tag: String = ""
) -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	var board_state: Dictionary = {
		"allied_units": allied_units,
		"enemy_units": enemy_units,
		"owner_team_side": owner_team_side,
	}
	for card_entry in card_entries:
		var card_data: CardData = card_entry.get("card_data", null)
		if card_data == null:
			continue
		var evaluation_score: int = evaluate_card_use(card_data, board_state)
		if evaluation_score < CARD_USE_SCORE_THRESHOLD:
			continue
		var order: Dictionary = _resolve_card_order(card_entry, board_state, evaluation_score)
		if order.is_empty():
			continue
		orders.append(order)
		if not debug_tag.is_empty():
			print("BOT_CARD_USE bot=%s card=%s target=%s score=%d" % [
				debug_tag,
				card_data.display_name,
				str(order.get("target_label", "instant")),
				evaluation_score,
			])
	return orders

func evaluate_card_use(card_data: CardData, board_state: Dictionary) -> int:
	if card_data == null:
		return -100000
	var allied_units: Array = board_state.get("allied_units", [])
	var enemy_units: Array = board_state.get("enemy_units", [])
	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			var lowest_hp_ally: Dictionary = _pick_lowest_hp_ratio_ally(allied_units)
			if lowest_hp_ally.is_empty():
				return 0
			var hp_ratio: float = float(lowest_hp_ally.get("current_hp", 0)) / maxf(1.0, float(lowest_hp_ally.get("max_hp", 1)))
			if hp_ratio <= 0.45:
				return 85
			if hp_ratio <= 0.70:
				return 65
			if hp_ratio <= 0.90:
				return 40
			return 0
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF, GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER, GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return 60 if not _pick_highest_attack_ally(allied_units, card_data.support_effect_type == GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER).is_empty() else 0
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return 58 if not _pick_highest_attack_ally(allied_units, true).is_empty() else 0
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return 62 if not _pick_highest_attack_ally(allied_units, false).is_empty() else 0
		GameEnums.SupportCardEffectType.START_STEALTH, GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF, GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return 55 if not _pick_primary_defender(allied_units).is_empty() else 0
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return 70 if _is_valid_coord(_pick_trap_coord(enemy_units, int(board_state.get("owner_team_side", GameEnums.TeamSide.PLAYER)))) else 0
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return 65 if enemy_units.size() >= 2 else 0
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return 68 if enemy_units.size() >= 2 else 48
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return 66 if enemy_units.size() >= 2 else 42
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return 54 if not _pick_primary_defender(allied_units).is_empty() else 36
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return 45 if allied_units.size() >= 2 else 25
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return 50 if not _pick_high_value_enemy(enemy_units).is_empty() else 0
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return 60 if not _pick_high_value_enemy(enemy_units).is_empty() else 0
		_:
			return 0

func _resolve_card_order(card_entry: Dictionary, board_state: Dictionary, score: int) -> Dictionary:
	var card_data: CardData = card_entry.get("card_data", null)
	if card_data == null:
		return {}
	var allied_units: Array[Dictionary] = board_state.get("allied_units", [])
	var enemy_units: Array[Dictionary] = board_state.get("enemy_units", [])
	var owner_team_side: int = int(board_state.get("owner_team_side", GameEnums.TeamSide.PLAYER))
	var order: Dictionary = {
		"card_data": card_data,
		"card_path": str(card_entry.get("card_path", "")),
		"score": score,
	}

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			var heal_target: Dictionary = _pick_lowest_hp_ratio_ally(allied_units)
			if heal_target.is_empty():
				return {}
			order["target_type"] = "unit"
			order["target_coord"] = heal_target.get("coord", Vector2i(-1, -1))
			order["target_label"] = str(heal_target.get("display_name", "aliado"))
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF, GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			var attack_target: Dictionary = _pick_highest_attack_ally(allied_units, false)
			if attack_target.is_empty():
				return {}
			order["target_type"] = "unit"
			order["target_coord"] = attack_target.get("coord", Vector2i(-1, -1))
			order["target_label"] = str(attack_target.get("display_name", "aliado"))
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			var lifesteal_target: Dictionary = _pick_highest_attack_ally(allied_units, false)
			if lifesteal_target.is_empty():
				return {}
			order["target_type"] = "unit"
			order["target_coord"] = lifesteal_target.get("coord", Vector2i(-1, -1))
			order["target_label"] = str(lifesteal_target.get("display_name", "aliado"))
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			var magic_target: Dictionary = _pick_highest_attack_ally(allied_units, true)
			if magic_target.is_empty():
				return {}
			order["target_type"] = "unit"
			order["target_coord"] = magic_target.get("coord", Vector2i(-1, -1))
			order["target_label"] = str(magic_target.get("display_name", "aliado"))
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			var mana_target: Dictionary = _pick_highest_attack_ally(allied_units, true)
			if mana_target.is_empty():
				return {}
			order["target_type"] = "unit"
			order["target_coord"] = mana_target.get("coord", Vector2i(-1, -1))
			order["target_label"] = str(mana_target.get("display_name", "aliado"))
		GameEnums.SupportCardEffectType.START_STEALTH, GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF, GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			var defense_target: Dictionary = _pick_primary_defender(allied_units)
			if defense_target.is_empty():
				return {}
			order["target_type"] = "unit"
			order["target_coord"] = defense_target.get("coord", Vector2i(-1, -1))
			order["target_label"] = str(defense_target.get("display_name", "aliado"))
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			var trap_coord: Vector2i = _pick_trap_coord(enemy_units, owner_team_side)
			if not _is_valid_coord(trap_coord):
				return {}
			order["target_type"] = "coord"
			order["target_coord"] = trap_coord
			order["target_label"] = str(trap_coord)
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD, GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD, GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL, GameEnums.SupportCardEffectType.OPENING_REPOSITION, GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD, GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD, GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			order["target_type"] = "instant"
			var enemy_target: Dictionary = _pick_high_value_enemy(enemy_units)
			order["target_label"] = str(enemy_target.get("display_name", "instant")) if not enemy_target.is_empty() else "instant"
		_:
			return {}

	return order

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

func _build_candidate_entries_from_deploy_pool(deploy_pool: Array) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for index in range(deploy_pool.size()):
		var option = deploy_pool[index]
		if option == null or option.used or option.unit_data == null:
			continue
		candidates.append({
			"slot_index": index,
			"unit_data": option.unit_data,
			"unit_path": str(option.unit_path),
		})
	return candidates

func _collect_board_units(board_grid: BoardGrid, team_side: int) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	if board_grid == null:
		return units
	for y in range(BattleConfigScript.BOARD_HEIGHT):
		for x in range(BattleConfigScript.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			if not board_grid.is_coord_in_team_zone(coord, team_side):
				continue
			var unit_state: BattleUnitState = board_grid.get_unit_at(coord)
			if unit_state == null or unit_state.team_side != team_side:
				continue
			units.append(_build_planner_unit_entry(unit_state.unit_data, coord, unit_state.is_master, team_side, unit_state.current_hp))
	return units

func _collect_occupied_coords(units: Array[Dictionary]) -> Array[Vector2i]:
	var occupied_coords: Array[Vector2i] = []
	for unit_entry in units:
		var coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
		if _is_valid_coord(coord):
			occupied_coords.append(coord)
	return occupied_coords

func _extract_master_unit_data(units: Array[Dictionary]) -> UnitData:
	for unit_entry in units:
		if bool(unit_entry.get("is_master", false)):
			return unit_entry.get("unit_data", null)
	return null

func _calculate_average_candidate_power(candidate_entries: Array[Dictionary]) -> float:
	if candidate_entries.is_empty():
		return 0.0
	var total_power: int = 0
	var valid_count: int = 0
	for candidate in candidate_entries:
		var unit_data: UnitData = candidate.get("unit_data", null)
		if unit_data == null:
			continue
		total_power += _estimate_unit_power(unit_data, false)
		valid_count += 1
	if valid_count <= 0:
		return 0.0
	return float(total_power) / float(valid_count)

func _estimate_unit_power(unit_data: UnitData, is_master: bool) -> int:
	if unit_data == null:
		return 0
	var power: int = 0
	power += unit_data.max_hp * 2
	power += unit_data.physical_attack * 5
	power += unit_data.magic_attack * 5
	power += unit_data.physical_defense * 4
	power += unit_data.magic_defense * 4
	power += unit_data.attack_range * 3
	power += int(round(unit_data.crit_chance * 100.0))
	power += unit_data.get_effective_cost() * 12
	if unit_data.skill_data != null or unit_data.master_skill_data != null:
		power += 20
	if is_master:
		power += 45
	match unit_data.class_type:
		GameEnums.ClassType.TANK:
			power += 18
		GameEnums.ClassType.SUPPORT:
			power += 10
		GameEnums.ClassType.STEALTH:
			power += 8
		_:
			power += 12
	return power

func _synergy_weight_for_tag(tag_value: int, allied_units: Array, key: String) -> int:
	var current_count: int = 0
	for unit_entry in allied_units:
		if int(unit_entry.get(key, -1)) == tag_value:
			current_count += 1
	if current_count == 1:
		return 60
	if current_count >= 2:
		return 40
	return 0

func _has_class(allied_units: Array, class_type: int) -> bool:
	for unit_entry in allied_units:
		if int(unit_entry.get("class_type", -1)) == class_type:
			return true
	return false

func _has_ranged_damage(allied_units: Array) -> bool:
	for unit_entry in allied_units:
		if _is_ranged_damage_class(int(unit_entry.get("class_type", -1)), int(unit_entry.get("attack_range", 1))):
			return true
	return false

func _is_ranged_damage_unit(unit_data: UnitData) -> bool:
	if unit_data == null:
		return false
	return _is_ranged_damage_class(unit_data.class_type, unit_data.attack_range)

func _is_ranged_damage_class(class_type: int, attack_range: int) -> bool:
	return class_type == GameEnums.ClassType.SNIPER or attack_range >= 3

func _rows_for_team(team_side: int) -> Dictionary:
	if team_side == GameEnums.TeamSide.ENEMY:
		return {"front": BattleConfigScript.ENEMY_ROWS - 1, "back": 0}
	return {
		"front": BattleConfigScript.BOARD_HEIGHT - BattleConfigScript.PLAYER_ROWS,
		"back": BattleConfigScript.BOARD_HEIGHT - 1,
	}

func _coords_from_columns(columns: Array[int], row: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for column in columns:
		coords.append(Vector2i(column, row))
	return coords

func _build_planner_unit_entry(
	unit_data: UnitData,
	coord: Vector2i,
	is_master: bool,
	team_side: int,
	current_hp: int = -1,
	unit_path: String = ""
) -> Dictionary:
	if unit_data == null:
		return {}
	return {
		"unit_data": unit_data,
		"unit_path": unit_path,
		"unit_id": unit_data.id,
		"display_name": unit_data.display_name,
		"race": unit_data.race,
		"class_type": unit_data.class_type,
		"cost": unit_data.get_effective_cost(),
		"coord": coord,
		"team_side": team_side,
		"is_master": is_master,
		"attack_range": unit_data.attack_range,
		"physical_attack": unit_data.physical_attack,
		"magic_attack": unit_data.magic_attack,
		"physical_defense": unit_data.physical_defense,
		"magic_defense": unit_data.magic_defense,
		"max_hp": unit_data.max_hp,
		"current_hp": unit_data.max_hp if current_hp < 0 else current_hp,
	}

func _pick_best_candidate_for_units(
	candidate_entries: Array[Dictionary],
	allied_units: Array[Dictionary],
	available_gold: int,
	master_data: UnitData,
	deck_average_power: float
) -> Dictionary:
	var best_index: int = -1
	var best_score: int = -100000
	var best_candidate: Dictionary = {}
	for index in range(candidate_entries.size()):
		var candidate: Dictionary = candidate_entries[index]
		var unit_data: UnitData = candidate.get("unit_data", null)
		if unit_data == null:
			continue
		var cost: int = unit_data.get_effective_cost()
		if cost > available_gold:
			continue
		var score: int = calculate_unit_weight(
			unit_data,
			{
				"allied_units": allied_units,
				"master_data": master_data,
				"deck_average_power": deck_average_power,
			},
			{
				"current_gold": available_gold,
			}
		)
		if best_index == -1 or score > best_score or (score == best_score and cost < int(best_candidate.get("unit_data", unit_data).get_effective_cost())):
			best_index = index
			best_score = score
			best_candidate = candidate
	return {
		"index": best_index,
		"score": best_score,
		"candidate": best_candidate,
	}

func _find_weakest_planned_unit_index(
	selected_units: Array[Dictionary],
	master_data: UnitData,
	deck_average_power: float,
	available_gold: int
) -> int:
	var weakest_index: int = -1
	var weakest_score: int = 100000
	for index in range(selected_units.size()):
		var score: int = _score_existing_unit_for_field(
			selected_units,
			index,
			master_data,
			deck_average_power,
			available_gold
		)
		if weakest_index == -1 or score < weakest_score:
			weakest_index = index
			weakest_score = score
	return weakest_index

func _score_existing_unit_for_field(
	selected_units: Array[Dictionary],
	unit_index: int,
	master_data: UnitData,
	deck_average_power: float,
	available_gold: int
) -> int:
	if unit_index < 0 or unit_index >= selected_units.size():
		return -100000
	var unit_entry: Dictionary = selected_units[unit_index]
	var unit_data: UnitData = unit_entry.get("unit_data", null)
	if unit_data == null:
		return -100000
	var allied_units: Array[Dictionary] = []
	for index in range(selected_units.size()):
		if index == unit_index:
			continue
		allied_units.append(selected_units[index])
	return calculate_unit_weight(
		unit_data,
		{
			"allied_units": allied_units,
			"master_data": master_data,
			"deck_average_power": deck_average_power,
		},
		{
			"current_gold": available_gold,
		}
	)

func _layout_planned_units(selected_units: Array[Dictionary], team_side: int) -> Array[Dictionary]:
	var laid_out_units: Array[Dictionary] = []
	var sorted_units: Array[Dictionary] = []
	var occupied_coords: Array[Vector2i] = []
	for unit_entry in selected_units:
		sorted_units.append(unit_entry.duplicate(true))
	sorted_units.sort_custom(_sort_units_for_layout)

	for unit_entry in sorted_units:
		var unit_data: UnitData = unit_entry.get("unit_data", null)
		if unit_data == null:
			continue
		var target_coord: Vector2i = get_best_coord_for_class(unit_data.class_type, occupied_coords, team_side)
		if not _is_valid_coord(target_coord):
			continue
		unit_entry["coord"] = target_coord
		occupied_coords.append(target_coord)
		laid_out_units.append(unit_entry)
	return laid_out_units

func _sort_units_for_layout(a: Dictionary, b: Dictionary) -> bool:
	var priority_a: int = _layout_priority_for_class(int(a.get("class_type", GameEnums.ClassType.ATTACKER)))
	var priority_b: int = _layout_priority_for_class(int(b.get("class_type", GameEnums.ClassType.ATTACKER)))
	if priority_a != priority_b:
		return priority_a < priority_b
	var power_a: int = _estimate_unit_power(a.get("unit_data", null), bool(a.get("is_master", false)))
	var power_b: int = _estimate_unit_power(b.get("unit_data", null), bool(b.get("is_master", false)))
	if power_a != power_b:
		return power_a > power_b
	return str(a.get("display_name", "")) < str(b.get("display_name", ""))

func _layout_priority_for_class(class_type: int) -> int:
	match class_type:
		GameEnums.ClassType.TANK:
			return 0
		GameEnums.ClassType.ATTACKER:
			return 1
		GameEnums.ClassType.STEALTH:
			return 2
		GameEnums.ClassType.SUPPORT:
			return 3
		GameEnums.ClassType.SNIPER:
			return 4
		_:
			return 5

func _cheapest_candidate_cost(candidate_entries: Array[Dictionary]) -> int:
	var cheapest_cost: int = 1000000
	for candidate in candidate_entries:
		var unit_data: UnitData = candidate.get("unit_data", null)
		if unit_data == null:
			continue
		cheapest_cost = mini(cheapest_cost, unit_data.get_effective_cost())
	if cheapest_cost == 1000000:
		return -1
	return cheapest_cost

func _pick_highest_attack_ally(allied_units: Array[Dictionary], prefer_magic: bool) -> Dictionary:
	var best_target: Dictionary = {}
	var best_score: int = -100000
	for unit_entry in allied_units:
		var score: int = int(unit_entry.get("magic_attack", 0)) if prefer_magic else int(unit_entry.get("physical_attack", 0))
		score += int(unit_entry.get("physical_attack", 0)) + int(unit_entry.get("magic_attack", 0))
		if best_target.is_empty() or score > best_score:
			best_target = unit_entry
			best_score = score
	return best_target

func _pick_lowest_hp_ratio_ally(allied_units: Array[Dictionary]) -> Dictionary:
	var best_target: Dictionary = {}
	var best_ratio: float = 2.0
	for unit_entry in allied_units:
		var max_hp: float = maxf(1.0, float(unit_entry.get("max_hp", 1)))
		var ratio: float = float(unit_entry.get("current_hp", 0)) / max_hp
		if best_target.is_empty() or ratio < best_ratio:
			best_target = unit_entry
			best_ratio = ratio
	return best_target

func _pick_primary_defender(allied_units: Array[Dictionary]) -> Dictionary:
	var master_target: Dictionary = {}
	var tank_target: Dictionary = {}
	var tank_score: int = -100000
	for unit_entry in allied_units:
		if bool(unit_entry.get("is_master", false)):
			master_target = unit_entry
		if int(unit_entry.get("class_type", -1)) == GameEnums.ClassType.TANK:
			var score: int = int(unit_entry.get("max_hp", 0)) * 4
			score += int(unit_entry.get("physical_defense", 0)) * 8
			if tank_target.is_empty() or score > tank_score:
				tank_target = unit_entry
				tank_score = score
	if not tank_target.is_empty():
		return tank_target
	return master_target

func _pick_high_value_enemy(enemy_units: Array[Dictionary]) -> Dictionary:
	var best_target: Dictionary = {}
	var best_score: int = -100000
	for unit_entry in enemy_units:
		var score: int = int(unit_entry.get("cost", 0)) * 40
		score += int(unit_entry.get("max_hp", 0)) * 2
		score += int(unit_entry.get("physical_attack", 0)) * 4
		score += int(unit_entry.get("magic_attack", 0)) * 4
		if best_target.is_empty() or score > best_score:
			best_target = unit_entry
			best_score = score
	return best_target

func _pick_trap_coord(enemy_units: Array[Dictionary], owner_team_side: int) -> Vector2i:
	var high_value_enemy: Dictionary = _pick_high_value_enemy(enemy_units)
	if not high_value_enemy.is_empty():
		return high_value_enemy.get("coord", Vector2i(-1, -1))
	var target_team_side: int = GameEnums.TeamSide.PLAYER if owner_team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	var rows: Dictionary = _rows_for_team(target_team_side)
	return Vector2i(3, int(rows.get("front", 0)))

func _is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < BattleConfigScript.BOARD_WIDTH and coord.y >= 0 and coord.y < BattleConfigScript.BOARD_HEIGHT
