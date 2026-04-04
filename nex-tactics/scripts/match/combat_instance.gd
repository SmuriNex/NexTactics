extends RefCounted
class_name CombatInstance
const BattleConfigScript := preload("res://autoload/battle_config.gd")

const MAX_RECENT_EVENTS := 16
const LOGIC_TICK_RATE := 30.0
const LOGIC_TICK_INTERVAL := 1.0 / LOGIC_TICK_RATE
const MAX_ACTIONS := 240
const TARGET_STUCK_RETARGET_LIMIT := 3
const TARGET_LOCK_REFRESH_TURNS := 2

const CombatBoardStateScript := preload("res://scripts/match/combat_board_state.gd")

var table_id: String = ""
var table_index: int = -1
var round_number: int = 0
var player_a_id: String = ""
var player_b_id: String = ""
var player_a_name: String = ""
var player_b_name: String = ""
var player_a_state: MatchPlayerState = null
var player_b_state: MatchPlayerState = null

var phase_name: String = "PREPARACAO"
var tick_accumulator: float = 0.0
var action_time_accumulator: float = 0.0
var action_interval_seconds: float = BattleConfigScript.LIVE_TABLE_ACTION_STEP_SECONDS
var acting_team: int = GameEnums.TeamSide.PLAYER
var player_turn_cursor: int = 0
var enemy_turn_cursor: int = 0
var actions_taken: int = 0

var board_state: CombatBoardState = CombatBoardStateScript.new()
var unit_states: Array[BattleUnitState] = []
var recent_events: Array[Dictionary] = []

var applied_result: bool = false
var winner_id: String = ""
var loser_id: String = ""
var damage: int = 0
var winner_survivors: int = -1
var loser_survivors: int = -1
var player_a_result_text: String = ""
var player_b_result_text: String = ""
var result_text: String = ""
var result_time_remaining: float = 0.0
var player_a_card_summary: String = ""
var player_b_card_summary: String = ""
var failsafe_triggered: bool = false
var failsafe_reason: String = ""

var observer_cache_a: Dictionary = {}
var observer_cache_b: Dictionary = {}
var pending_periodic_magic_fields: Dictionary = {}
var pending_first_ally_death_summons: Dictionary = {}
var first_death_resolved: bool = false
var owner_lobby_manager: LobbyManager = null

func setup_from_pairing(
	pairing: Dictionary,
	p_round_number: int,
	player_a: MatchPlayerState,
	player_b: MatchPlayerState,
	initial_snapshot_a: Dictionary,
	p_result_hold_seconds: float
) -> CombatInstance:
	table_id = "round_%d_table_%d" % [
		p_round_number,
		int(pairing.get("table_index", player_a.slot_index + player_b.slot_index)),
	]
	table_index = int(pairing.get("table_index", -1))
	round_number = p_round_number
	player_a_state = player_a
	player_b_state = player_b
	player_a_id = player_a.player_id if player_a != null else ""
	player_b_id = player_b.player_id if player_b != null else ""
	player_a_name = player_a.display_name if player_a != null else "Player A"
	player_b_name = player_b.display_name if player_b != null else "Player B"
	result_time_remaining = p_result_hold_seconds
	action_interval_seconds = BattleConfigScript.LIVE_TABLE_ACTION_STEP_SECONDS
	acting_team = GameEnums.TeamSide.PLAYER if ((player_a.slot_index + player_b.slot_index + round_number) % 2 == 0) else GameEnums.TeamSide.ENEMY
	_seed_unit_states_from_snapshot(initial_snapshot_a)
	begin_prep()
	push_event("table_created", {
		"summary": "%s vs %s" % [player_a_name, player_b_name],
	})
	print("COMBAT_INSTANCE created table=%s round=%d players=%s vs %s" % [
		table_id,
		round_number,
		player_a_name,
		player_b_name,
	])
	return self

func matches_round(target_round: int) -> bool:
	return target_round <= 0 or round_number == target_round

func contains_player(player_id: String) -> bool:
	if player_id.is_empty():
		return false
	return player_a_id == player_id or player_b_id == player_id

func get_relative_team_for_player(player_id: String) -> int:
	return GameEnums.TeamSide.PLAYER if player_id == player_a_id else GameEnums.TeamSide.ENEMY

func get_card_summary_for_player(player_id: String) -> String:
	return player_a_card_summary if player_id == player_a_id else player_b_card_summary

func get_result_text_for_player(player_id: String) -> String:
	return player_a_result_text if player_id == player_a_id else player_b_result_text

func get_observer_snapshot_for_player(player_id: String) -> Dictionary:
	if player_id == player_b_id:
		return observer_cache_b.duplicate(true)
	return observer_cache_a.duplicate(true)

func is_active() -> bool:
	return phase_name == "PREPARACAO" or phase_name == "BATALHA"

func begin_prep() -> void:
	phase_name = "PREPARACAO"
	applied_result = false
	winner_id = ""
	loser_id = ""
	damage = 0
	winner_survivors = -1
	loser_survivors = -1
	player_a_result_text = ""
	player_b_result_text = ""
	result_text = ""
	player_a_card_summary = ""
	player_b_card_summary = ""
	failsafe_triggered = false
	failsafe_reason = ""
	player_turn_cursor = 0
	enemy_turn_cursor = 0
	tick_accumulator = 0.0
	action_time_accumulator = 0.0
	actions_taken = 0
	recent_events.clear()
	pending_periodic_magic_fields.clear()
	pending_first_ally_death_summons.clear()
	first_death_resolved = false
	for unit_state in unit_states:
		if unit_state == null:
			continue
		unit_state.reset_for_new_round()
	board_state.rebuild(unit_states)
	_refresh_observer_caches()
	print("TABLE phase=PREP table=%s round=%d" % [table_id, round_number])

func begin_battle() -> void:
	if phase_name != "PREPARACAO":
		return
	phase_name = "BATALHA"
	tick_accumulator = 0.0
	action_time_accumulator = 0.0
	actions_taken = 0
	failsafe_triggered = false
	failsafe_reason = ""
	player_turn_cursor = 0
	enemy_turn_cursor = 0
	player_a_card_summary = _apply_cards_to_team(GameEnums.TeamSide.PLAYER, player_a_state)
	player_b_card_summary = _apply_cards_to_team(GameEnums.TeamSide.ENEMY, player_b_state)
	board_state.rebuild(unit_states)
	push_event("battle_started", {
		"summary": "%s vs %s" % [player_a_name, player_b_name],
	})
	_refresh_observer_caches()
	print("TABLE phase=BATTLE table=%s round=%d" % [table_id, round_number])

func begin_result(result_hold_seconds: float) -> void:
	phase_name = "RESULTADO"
	result_time_remaining = result_hold_seconds
	_refresh_observer_caches()

func process_tick(delta: float) -> bool:
	if phase_name == "RESULTADO":
		if result_time_remaining <= 0.0:
			return false
		result_time_remaining = maxf(0.0, result_time_remaining - delta)
		return false
	if phase_name != "BATALHA":
		return false

	var changed: bool = false
	tick_accumulator += delta
	while tick_accumulator >= LOGIC_TICK_INTERVAL:
		tick_accumulator -= LOGIC_TICK_INTERVAL
		if _process_logic_tick():
			changed = true
		if phase_name != "BATALHA":
			break

	if changed:
		_refresh_observer_caches()
	return changed

func force_finish() -> void:
	if phase_name == "PREPARACAO":
		begin_battle()
	while phase_name == "BATALHA":
		if not _process_logic_tick():
			break
	_refresh_observer_caches()

func push_event(event_type: String, payload: Dictionary = {}) -> void:
	var event_entry: Dictionary = payload.duplicate(true)
	event_entry["type"] = event_type
	event_entry["table_id"] = table_id
	event_entry["round_number"] = round_number
	recent_events.append(event_entry)
	if recent_events.size() > MAX_RECENT_EVENTS:
		recent_events.remove_at(0)

func get_recent_events() -> Array[Dictionary]:
	var events_copy: Array[Dictionary] = []
	for event_entry in recent_events:
		events_copy.append(event_entry.duplicate(true))
	return events_copy

func build_result_entry() -> Dictionary:
	return {
		"table_id": table_id,
		"player_a_id": player_a_id,
		"player_b_id": player_b_id,
		"winner_id": winner_id,
		"loser_id": loser_id,
		"damage": damage,
		"result_text": result_text,
	}

func _seed_unit_states_from_snapshot(snapshot: Dictionary) -> void:
	unit_states.clear()
	var snapshot_units: Array = snapshot.get("units", [])
	for unit_variant in snapshot_units:
		var unit_entry: Dictionary = unit_variant
		var unit_path: String = str(unit_entry.get("unit_path", ""))
		var unit_data: UnitData = _load_unit_data(unit_path)
		if unit_data == null:
			continue
		var coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
		var unit_state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
			unit_data,
			int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)),
			coord,
			bool(unit_entry.get("is_master", false)),
			coord
		)
		unit_state.current_hp = int(unit_entry.get("current_hp", unit_data.max_hp))
		unit_state.current_mana = int(unit_entry.get("current_mana", 0))
		unit_state.bonus_physical_attack = int(unit_entry.get("physical_attack", unit_data.physical_attack)) - unit_data.physical_attack
		unit_state.bonus_magic_attack = int(unit_entry.get("magic_attack", unit_data.magic_attack)) - unit_data.magic_attack
		unit_state.bonus_physical_defense = int(unit_entry.get("physical_defense", unit_data.physical_defense)) - unit_data.physical_defense
		unit_state.bonus_magic_defense = int(unit_entry.get("magic_defense", unit_data.magic_defense)) - unit_data.magic_defense
		var range_bonus: int = int(unit_entry.get("attack_range", unit_state.get_attack_range())) - unit_state.get_attack_range()
		if range_bonus > 0:
			unit_state.apply_attack_range_bonus(range_bonus, 99)
		unit_state.alive = unit_state.current_hp > 0
		unit_state.remember_position_sample(coord)
		unit_states.append(unit_state)
	board_state.rebuild(unit_states)

func _process_logic_tick() -> bool:
	if phase_name != "BATALHA":
		return false
	if _is_combat_finished():
		_finalize_result()
		return true

	action_time_accumulator += LOGIC_TICK_INTERVAL
	if action_time_accumulator < action_interval_seconds:
		return false

	action_time_accumulator -= action_interval_seconds
	var changed: bool = _process_next_action()
	if _is_combat_finished():
		_finalize_result()
		return true
	if actions_taken >= MAX_ACTIONS:
		failsafe_triggered = true
		failsafe_reason = "combat_action_cap"
		_finalize_result()
		return true
	return changed

func _process_next_action() -> bool:
	_trigger_periodic_magic_fields()
	var acting_unit: BattleUnitState = _pop_next_actor(acting_team)
	if acting_unit == null:
		acting_team = _opposite_team(acting_team)
		acting_unit = _pop_next_actor(acting_team)
		if acting_unit == null:
			return false

	var changed: bool = _process_unit_turn(acting_unit)
	acting_team = _opposite_team(acting_team)
	if changed:
		actions_taken += 1
	return changed

func _pop_next_actor(team_side: int) -> BattleUnitState:
	var turn_order: Array[BattleUnitState] = _build_turn_order_for_team(team_side)
	if turn_order.is_empty():
		return null

	var use_player_cursor: bool = team_side == GameEnums.TeamSide.PLAYER
	var cursor: int = player_turn_cursor if use_player_cursor else enemy_turn_cursor
	if cursor < 0:
		cursor = 0
	if cursor >= turn_order.size():
		cursor = 0

	var actor: BattleUnitState = turn_order[cursor]
	cursor += 1
	if cursor >= turn_order.size():
		cursor = 0
	if use_player_cursor:
		player_turn_cursor = cursor
	else:
		enemy_turn_cursor = cursor
	return actor

func _build_turn_order_for_team(team_side: int) -> Array[BattleUnitState]:
	var turn_order: Array[BattleUnitState] = []
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		turn_order.append(unit_state)
	turn_order.sort_custom(_sort_turn_order)
	return turn_order

func _sort_turn_order(a: BattleUnitState, b: BattleUnitState) -> bool:
	var initiative_a: int = _unit_initiative(a)
	var initiative_b: int = _unit_initiative(b)
	if initiative_a != initiative_b:
		return initiative_a > initiative_b
	if a.current_hp != b.current_hp:
		return a.current_hp > b.current_hp
	return a.get_display_name() < b.get_display_name()

func _unit_initiative(unit_state: BattleUnitState) -> int:
	if unit_state == null:
		return 0
	var initiative: int = 0
	initiative += unit_state.get_attack_range() * 10
	initiative += unit_state.get_physical_attack_value()
	initiative += unit_state.get_magic_attack_value()
	initiative += unit_state.unit_data.cost * 3 if unit_state.unit_data != null else 0
	initiative += unit_state.action_charge
	if unit_state.is_master:
		initiative -= 6
	return initiative

func _process_unit_turn(acting_unit: BattleUnitState) -> bool:
	if acting_unit == null or not acting_unit.can_act():
		return false

	if acting_unit.has_turn_skip():
		acting_unit.consume_skip_turn()
		acting_unit.advance_turn_effects()
		push_event("unit_wait", {
			"actor": acting_unit.get_display_name(),
			"reason": "skip_turn",
		})
		return true

	var target_lock_turns: int = _get_target_lock_turns_for_unit(acting_unit)
	if acting_unit.should_force_retarget(TARGET_STUCK_RETARGET_LIMIT):
		var previous_target: BattleUnitState = acting_unit.current_target
		var blocked_key: String = _unit_runtime_key(previous_target)
		if not blocked_key.is_empty():
			acting_unit.remember_blocked_target(blocked_key)
		acting_unit.clear_target_lock()
		var replacement_target: BattleUnitState = _find_target_for_unit(acting_unit)
		if replacement_target != null and replacement_target != previous_target:
			acting_unit.set_current_target(replacement_target, target_lock_turns)
			_log_tactical_debug("RETARGET", [
				"reason=stuck",
				"unit=%s" % acting_unit.get_display_name(),
				"from=%s" % (previous_target.get_display_name() if previous_target != null else ""),
				"to=%s" % replacement_target.get_display_name(),
				"stuck=%d" % acting_unit.stuck_counter,
			])
			push_event("retarget", {
				"actor": acting_unit.get_display_name(),
				"target": replacement_target.get_display_name(),
				"stuck": acting_unit.stuck_counter,
			})
			acting_unit.clear_stuck()
			acting_unit.advance_turn_effects()
			return true
		acting_unit.mark_stuck()
		acting_unit.advance_turn_effects()
		_log_wait_debug(acting_unit, "retarget_pending", previous_target)
		push_event("unit_wait", {
			"actor": acting_unit.get_display_name(),
			"reason": "retarget_pending",
		})
		return true

	var target: BattleUnitState = _resolve_locked_target_for_unit(acting_unit)
	if target == null:
		acting_unit.mark_stuck()
		acting_unit.advance_turn_effects()
		_log_wait_debug(acting_unit, "missing_target")
		push_event("unit_wait", {
			"actor": acting_unit.get_display_name(),
			"reason": "missing_target",
		})
		return true

	var target_key: String = _unit_runtime_key(target)
	acting_unit.set_current_target(target, target_lock_turns)
	if _is_target_in_range(acting_unit, target):
		_perform_attack(acting_unit, target)
		acting_unit.clear_stuck()
		acting_unit.clear_blocked_target()
		acting_unit.advance_turn_effects()
		return true

	if _perform_move_towards_target(acting_unit, target):
		acting_unit.clear_stuck()
		acting_unit.clear_blocked_target()
		acting_unit.advance_turn_effects()
		return true

	acting_unit.remember_blocked_target(target_key)
	acting_unit.mark_stuck()
	acting_unit.advance_turn_effects()
	_log_wait_debug(acting_unit, "path_blocked", target)
	push_event("unit_wait", {
		"actor": acting_unit.get_display_name(),
		"reason": "path_blocked",
		"target": target.get_display_name(),
	})
	return true

func _resolve_locked_target_for_unit(acting_unit: BattleUnitState) -> BattleUnitState:
	if acting_unit == null:
		return null
	var previous_target: BattleUnitState = acting_unit.current_target
	if acting_unit.has_valid_current_target() and acting_unit.current_target.team_side != acting_unit.team_side:
		return acting_unit.current_target
	acting_unit.clear_target_lock()
	var new_target: BattleUnitState = _find_target_for_unit(acting_unit)
	if new_target != null:
		acting_unit.set_current_target(new_target, _get_target_lock_turns_for_unit(acting_unit))
		_log_target_resolution(acting_unit, new_target, previous_target, "reacquire")
	return new_target

func _find_target_for_unit(source: BattleUnitState) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_score: int = 1000000
	for include_stealthed in [false, true]:
		for candidate in unit_states:
			if candidate == null or not candidate.can_act():
				continue
			if candidate.team_side == source.team_side:
				continue
			if not include_stealthed and candidate.is_stealthed():
				continue
			var score: int = _score_target_for_unit(source, candidate)
			if best_target == null or score < best_score:
				best_target = candidate
				best_score = score
		if best_target != null:
			return best_target
	return null

func _score_target_for_unit(source: BattleUnitState, candidate: BattleUnitState) -> int:
	var distance: int = board_state.distance_between_cells(source.coord, candidate.coord)
	var target_key: String = _unit_runtime_key(candidate)
	var routing_penalty: int = source.get_blocked_target_penalty(target_key) + source.get_recent_target_penalty(target_key)
	var score: int = distance * 100 + candidate.current_hp * 4
	if source.is_tank_unit():
		score = distance * 1000 + candidate.current_hp * 8 + candidate.get_defense_value() * 4
	elif source.is_attacker_unit():
		if distance <= source.get_attack_range():
			score = candidate.current_hp * 100 + distance * 10 + candidate.get_defense_value() * 4
		else:
			score = 100000 + distance * 100 + candidate.current_hp * 6 + candidate.get_defense_value() * 3
	elif source.is_support_unit():
		var anchor_ally: BattleUnitState = _find_support_priority_ally(source)
		var anchor_distance: int = 0 if anchor_ally == null else board_state.distance_between_cells(anchor_ally.coord, candidate.coord)
		score = anchor_distance * 700 + distance * 100 + candidate.current_hp * 4
	elif source.is_stealth_unit():
		var role_bucket: int = 2
		if candidate.is_support_unit():
			role_bucket = 0
		elif candidate.is_ranged_unit():
			role_bucket = 1
		var backline_bonus: int = _get_backline_depth_for_targeting(source.team_side, candidate.coord)
		score = role_bucket * 100000 + candidate.current_hp * 120 + candidate.get_defense_value() * 10 - (distance * 25) - (backline_bonus * 120)
	elif source.is_sniper_unit():
		if distance <= source.get_attack_range():
			score = -(distance * 1000) + candidate.current_hp * 20 + candidate.get_defense_value() * 5
		else:
			score = 50000 - (distance * 500) + candidate.current_hp * 20 + candidate.get_defense_value() * 5
	return score + routing_penalty

func _log_tactical_debug(tag: String, parts: Array[String]) -> void:
	var message: String = tag
	for part in parts:
		if part.is_empty():
			continue
		message += " " + part
	print("TABLE %s" % message)

func _log_target_resolution(
	source: BattleUnitState,
	new_target: BattleUnitState,
	previous_target: BattleUnitState,
	reason: String
) -> void:
	if source == null or new_target == null:
		return
	if previous_target == null:
		_log_tactical_debug("TARGET_ACQUIRED", [
			"unit=%s" % source.get_display_name(),
			"target=%s" % new_target.get_display_name(),
			"reason=%s" % reason,
		])
	elif previous_target != new_target:
		_log_tactical_debug("TARGET_SWITCH", [
			"unit=%s" % source.get_display_name(),
			"from=%s" % previous_target.get_display_name(),
			"to=%s" % new_target.get_display_name(),
			"reason=%s" % reason,
		])

func _log_wait_debug(source: BattleUnitState, reason: String, target: BattleUnitState = null) -> void:
	if source == null:
		return
	var parts: Array[String] = [
		"unit=%s" % source.get_display_name(),
		"reason=%s" % reason,
	]
	if target != null:
		parts.append("target=%s" % target.get_display_name())
	parts.append("stuck=%d" % source.stuck_counter)
	parts.append("lock=%d" % source.target_lock_timer)
	_log_tactical_debug("WAIT", parts)

func _get_target_lock_turns_for_unit(unit_state: BattleUnitState) -> int:
	if unit_state == null:
		return TARGET_LOCK_REFRESH_TURNS
	if unit_state.is_tank_unit() or unit_state.is_stealth_unit():
		return TARGET_LOCK_REFRESH_TURNS + 1
	return TARGET_LOCK_REFRESH_TURNS

func _find_ally_with_highest_attack_value(team_side: int, exclude_unit: BattleUnitState = null) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state == exclude_unit:
			continue
		var attack_value: int = unit_state.get_attack_value()
		if attack_value > best_value:
			best_value = attack_value
			best_target = unit_state
	return best_target

func _find_support_priority_ally(source: BattleUnitState) -> BattleUnitState:
	if source == null:
		return null
	var injured_ally: BattleUnitState = null
	var lowest_hp: int = 1000000
	for candidate in unit_states:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side != source.team_side or candidate == source:
			continue
		if candidate.current_hp < lowest_hp:
			lowest_hp = candidate.current_hp
			injured_ally = candidate
	if injured_ally != null and injured_ally.unit_data != null and injured_ally.current_hp < injured_ally.unit_data.max_hp:
		return injured_ally
	return _find_ally_with_highest_attack_value(source.team_side, source)

func _get_backline_depth_for_targeting(attacker_team_side: int, coord: Vector2i) -> int:
	if attacker_team_side == GameEnums.TeamSide.PLAYER:
		return BattleConfigScript.BOARD_HEIGHT - coord.y
	return coord.y + 1

func _get_nearest_enemy_distance_from_coord(team_side: int, coord: Vector2i) -> int:
	var best_distance: int = 1000000
	for candidate in unit_states:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side == team_side:
			continue
		var distance: int = board_state.distance_between_cells(coord, candidate.coord)
		if distance < best_distance:
			best_distance = distance
	return best_distance

func _get_tactical_move_type(acting_unit: BattleUnitState) -> String:
	if acting_unit == null:
		return "advance"
	if acting_unit.is_support_unit():
		return "support"
	if acting_unit.is_stealth_unit():
		return "flank"
	if acting_unit.is_sniper_unit():
		return "kite"
	return "advance"

func _score_tactical_goal_coord(
	acting_unit: BattleUnitState,
	target: BattleUnitState,
	candidate_coord: Vector2i,
	path_length: int
) -> int:
	var path_cost: int = maxi(0, path_length - 1) * 18
	var distance_to_target: int = board_state.distance_between_cells(candidate_coord, target.coord)
	var nearest_enemy_distance: int = _get_nearest_enemy_distance_from_coord(acting_unit.team_side, candidate_coord)
	if acting_unit.is_support_unit():
		var anchor_ally: BattleUnitState = _find_support_priority_ally(acting_unit)
		var ally_distance: int = 0 if anchor_ally == null else board_state.distance_between_cells(candidate_coord, anchor_ally.coord)
		var pressure_penalty: int = 0 if nearest_enemy_distance >= 2 else 500 + ((2 - nearest_enemy_distance) * 250)
		return pressure_penalty + ally_distance * 40 + path_cost + distance_to_target * 5
	if acting_unit.is_sniper_unit():
		var range_gap: int = abs(distance_to_target - acting_unit.get_attack_range())
		var pressure_penalty: int = 0 if nearest_enemy_distance >= 2 else 420 + ((2 - nearest_enemy_distance) * 220)
		return range_gap * 180 + pressure_penalty + path_cost
	if acting_unit.is_stealth_unit():
		var backline_depth: int = _get_backline_depth_for_targeting(acting_unit.team_side, candidate_coord)
		var lateral_offset: int = abs(candidate_coord.x - target.coord.x)
		return path_cost + distance_to_target * 20 - (backline_depth * 80) - (lateral_offset * 35)
	return path_cost + distance_to_target * 10

func _find_tactical_goal_coord_for_target(
	acting_unit: BattleUnitState,
	target: BattleUnitState,
	desired_range: int,
	forbidden_coords: Array[Vector2i]
) -> Vector2i:
	if acting_unit == null or target == null:
		return Vector2i(-1, -1)
	if not acting_unit.is_support_unit() and not acting_unit.is_stealth_unit() and not acting_unit.is_sniper_unit():
		return Vector2i(-1, -1)

	var best_coord: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1000000
	for y in range(BattleConfigScript.BOARD_HEIGHT):
		for x in range(BattleConfigScript.BOARD_WIDTH):
			var candidate_coord := Vector2i(x, y)
			if board_state.distance_between_cells(candidate_coord, target.coord) > desired_range:
				continue
			if forbidden_coords.has(candidate_coord):
				continue
			if candidate_coord != acting_unit.coord and not board_state.is_cell_free(candidate_coord, acting_unit):
				continue
			var path: Array[Vector2i] = []
			if candidate_coord == acting_unit.coord:
				path.append(acting_unit.coord)
			else:
				path = board_state.find_path_bfs(acting_unit.coord, candidate_coord, forbidden_coords, false, acting_unit)
			if path.is_empty():
				continue
			var score: int = _score_tactical_goal_coord(acting_unit, target, candidate_coord, path.size())
			if best_coord == Vector2i(-1, -1) or score < best_score:
				best_coord = candidate_coord
				best_score = score
	return best_coord

func _resolve_move_plan_for_target(
	acting_unit: BattleUnitState,
	target_coord: Vector2i,
	target_key: String,
	desired_range: int,
	target_unit: BattleUnitState = null
) -> Dictionary:
	var forbidden_coords: Array[Vector2i] = []
	var bounce_coord: Vector2i = acting_unit.get_bounce_forbidden_coord(target_key)
	if board_state.is_valid_coord(bounce_coord):
		forbidden_coords.append(bounce_coord)

	if target_unit != null and target_unit.team_side != acting_unit.team_side:
		var tactical_goal: Vector2i = _find_tactical_goal_coord_for_target(acting_unit, target_unit, desired_range, forbidden_coords)
		if board_state.is_valid_coord(tactical_goal):
			var tactical_path: Array[Vector2i] = []
			if tactical_goal == acting_unit.coord:
				tactical_path.append(acting_unit.coord)
			else:
				tactical_path = board_state.find_path_bfs(acting_unit.coord, tactical_goal, forbidden_coords, false, acting_unit)
			if tactical_path.size() >= 2:
				return {
					"coord": tactical_path[1],
					"move_type": _get_tactical_move_type(acting_unit),
					"avoided_coord": bounce_coord,
				}

	var path: Array[Vector2i] = board_state.find_path_to_attack_range(
		acting_unit.coord,
		target_coord,
		desired_range,
		forbidden_coords,
		acting_unit
	)
	if path.size() >= 2:
		return {
			"coord": path[1],
			"move_type": "advance",
			"avoided_coord": bounce_coord,
		}
	return {
		"coord": acting_unit.coord,
		"move_type": "wait",
		"avoided_coord": bounce_coord,
	}

func _perform_move_towards_target(acting_unit: BattleUnitState, target: BattleUnitState) -> bool:
	var target_key: String = _unit_runtime_key(target)
	var move_plan: Dictionary = _resolve_move_plan_for_target(
		acting_unit,
		target.coord,
		target_key,
		acting_unit.get_attack_range(),
		target
	)
	var next_coord: Vector2i = move_plan.get("coord", acting_unit.coord)
	var move_type: String = str(move_plan.get("move_type", "advance"))
	if next_coord == acting_unit.coord:
		_log_wait_debug(acting_unit, "path_blocked", target)
		return false
	var from_coord: Vector2i = acting_unit.coord
	if board_state.move_unit(acting_unit, next_coord):
		acting_unit.remember_navigation_move(target_key, move_type, from_coord, next_coord)
		_log_tactical_debug("MOVE", [
			"unit=%s" % acting_unit.get_display_name(),
			"type=%s" % move_type,
			"from=%s" % from_coord,
			"to=%s" % next_coord,
			"target=%s" % target.get_display_name(),
		])
		push_event("unit_move", {
			"actor": acting_unit.get_display_name(),
			"from_coord": from_coord,
			"to_coord": next_coord,
		})
		return true
	return false

func _is_target_in_range(attacker: BattleUnitState, target: BattleUnitState) -> bool:
	return board_state.distance_between_cells(attacker.coord, target.coord) <= attacker.get_attack_range()

func _perform_attack(attacker: BattleUnitState, target: BattleUnitState) -> void:
	if attacker == null or target == null:
		return
	var damage_result: Dictionary = _calculate_damage_result(attacker, target)
	var damage_value: int = int(damage_result.get("damage", 0))
	var target_died: bool = bool(damage_result.get("target_died", false))
	var mana_from_attack: int = attacker.gain_mana(attacker.get_mana_gain_on_attack())
	var mana_from_hit: int = target.gain_mana(target.get_mana_gain_on_hit())
	push_event("unit_attack", {
		"actor": attacker.get_display_name(),
		"target": target.get_display_name(),
		"damage": damage_value,
		"target_hp": target.current_hp,
		"critical": bool(damage_result.get("critical", false)),
	})
	if mana_from_attack > 0 or mana_from_hit > 0:
		push_event("mana_update", {
			"actor": attacker.get_display_name(),
			"target": target.get_display_name(),
		})
	if target_died:
		_handle_unit_death(target, attacker)

func _calculate_damage_result(attacker: BattleUnitState, target: BattleUnitState) -> Dictionary:
	var critical: bool = randf() <= attacker.get_crit_chance()
	var physical_attack: int = attacker.get_physical_attack_value()
	var magic_attack: int = attacker.get_magic_attack_value()
	var physical_damage: int = maxi(1, physical_attack - int(round(float(target.get_physical_defense_value()) * 0.45)))
	var magic_damage: int = maxi(0, magic_attack - int(round(float(target.get_magic_defense_value()) * 0.35)))
	physical_damage = int(round(float(physical_damage) * target.get_received_physical_damage_multiplier()))
	var total_damage: int = physical_damage + magic_damage
	if critical:
		total_damage = int(round(float(total_damage) * 1.65))
	var applied_damage: int = target.take_damage(maxi(1, total_damage))
	return {
		"damage": applied_damage,
		"critical": critical,
		"target_died": target.is_dead(),
	}

func _handle_unit_death(target: BattleUnitState, attacker: BattleUnitState = null) -> void:
	if target == null:
		return
	_resolve_first_ally_death_summon(target)
	board_state.remove_unit(target)
	push_event("unit_die", {
		"actor": target.get_display_name(),
		"killer": attacker.get_display_name() if attacker != null else "",
	})
	if target.is_summoned_token:
		unit_states.erase(target)
		push_event("token_cleanup", {
			"actor": target.get_display_name(),
		})

func _trigger_periodic_magic_fields() -> void:
	var expired_team_sides: Array[int] = []
	for team_side_variant in pending_periodic_magic_fields.keys():
		var owner_team_side: int = int(team_side_variant)
		var field_state: Dictionary = pending_periodic_magic_fields.get(owner_team_side, {})
		if field_state.is_empty():
			expired_team_sides.append(owner_team_side)
			continue
		if actions_taken < int(field_state.get("next_trigger_action", 0)):
			continue
		var target_team_side: int = _opposite_team(owner_team_side)
		var enemy_targets: Array[BattleUnitState] = []
		for unit_state in unit_states:
			if unit_state == null or not unit_state.can_act():
				continue
			if unit_state.team_side != target_team_side:
				continue
			enemy_targets.append(unit_state)
		if enemy_targets.is_empty():
			expired_team_sides.append(owner_team_side)
			continue
		var target: BattleUnitState = enemy_targets[randi() % enemy_targets.size()]
		target.take_damage(maxi(1, int(field_state.get("damage_amount", 1))))
		push_event("field_tick", {
			"actor": str(field_state.get("card_name", "Campo magico")),
			"target": target.get_display_name(),
			"damage": int(field_state.get("damage_amount", 1)),
		})
		if target.is_dead():
			_handle_unit_death(target)
		var remaining_triggers: int = maxi(0, int(field_state.get("remaining_triggers", 0)) - 1)
		if remaining_triggers <= 0:
			expired_team_sides.append(owner_team_side)
			continue
		field_state["remaining_triggers"] = remaining_triggers
		field_state["next_trigger_action"] = actions_taken + maxi(1, int(field_state.get("interval_turns", 1)))
		pending_periodic_magic_fields[owner_team_side] = field_state
	for team_side in expired_team_sides:
		pending_periodic_magic_fields.erase(team_side)

func _resolve_first_ally_death_summon(dead_unit: BattleUnitState) -> void:
	if dead_unit == null or first_death_resolved:
		return
	first_death_resolved = true
	var summon_state: Dictionary = pending_first_ally_death_summons.get(dead_unit.team_side, {})
	pending_first_ally_death_summons.clear()
	if summon_state.is_empty():
		return
	var unit_path: String = str(summon_state.get("unit_path", ""))
	var summon_data: UnitData = _load_unit_data(unit_path)
	if summon_data == null:
		return
	if _team_has_live_unit_id(dead_unit.team_side, summon_data.id):
		return
	var spawn_coord: Vector2i = _pick_opening_reposition_coord(dead_unit.team_side, dead_unit)
	if not board_state.is_valid_coord(spawn_coord):
		return
	var summon_state_unit: BattleUnitState = _spawn_token_for_team(
		unit_path,
		dead_unit.team_side,
		spawn_coord,
		float(summon_state.get("hp_ratio", 1.0)),
		dead_unit.unit_data.id if dead_unit.unit_data != null else summon_data.id
	)
	if summon_state_unit == null:
		return
	push_event("conditional_summon", {
		"actor": str(summon_state.get("card_name", "Canto da Sereia")),
		"target": summon_state_unit.get_display_name(),
	})

func _team_has_live_unit_id(team_side: int, unit_id: String) -> bool:
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state.unit_data != null and unit_state.unit_data.id == unit_id:
			return true
	return false

func _spawn_token_for_team(unit_path: String, team_side: int, coord: Vector2i, hp_ratio: float, source_unit_id: String) -> BattleUnitState:
	var unit_data: UnitData = _load_unit_data(unit_path)
	if unit_data == null or not board_state.is_valid_coord(coord):
		return null
	if not board_state.is_cell_free(coord):
		return null
	var summon_data: UnitData = unit_data.duplicate(true) as UnitData
	var unit_state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
		summon_data,
		team_side,
		coord,
		false,
		coord
	)
	unit_state.current_hp = clampi(
		maxi(1, int(round(float(unit_state.unit_data.max_hp) * clampf(hp_ratio, 0.1, 1.0)))),
		1,
		unit_state.unit_data.max_hp
	)
	unit_state.mark_as_summoned_token(source_unit_id)
	if not board_state.move_unit(unit_state, coord):
		board_state.rebuild(unit_states)
		if not board_state.move_unit(unit_state, coord):
			return null
	unit_states.append(unit_state)
	board_state.rebuild(unit_states)
	return unit_state

func _is_combat_finished() -> bool:
	return (
		_count_living_team(GameEnums.TeamSide.PLAYER) <= 0
		or _count_living_team(GameEnums.TeamSide.ENEMY) <= 0
		or actions_taken >= MAX_ACTIONS
	)

func _count_living_team(team_side: int) -> int:
	var count: int = 0
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		count += 1
	return count

func _team_hp_total(team_side: int) -> int:
	var total_hp: int = 0
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		total_hp += unit_state.current_hp
	return total_hp

func _finalize_result() -> void:
	if applied_result:
		return

	var winner_team: int = _resolve_winner_team()
	winner_id = ""
	loser_id = ""
	damage = 0
	winner_survivors = -1
	loser_survivors = -1
	player_a_result_text = "Empate ao vivo contra %s" % player_b_name
	player_b_result_text = "Empate ao vivo contra %s" % player_a_name
	result_text = player_a_result_text

	if winner_team >= 0:
		winner_id = player_a_id if winner_team == GameEnums.TeamSide.PLAYER else player_b_id
		loser_id = player_b_id if winner_team == GameEnums.TeamSide.PLAYER else player_a_id
		winner_survivors = _count_living_team(winner_team)
		loser_survivors = _count_living_team(_opposite_team(winner_team))
		damage = BattleConfigScript.calculate_post_combat_damage({
			"winner_id": winner_id,
			"loser_id": loser_id,
		}, round_number, {
			"survivors": winner_survivors,
		})

		if owner_lobby_manager != null:
			var resolution: Dictionary = owner_lobby_manager.apply_post_combat_damage(
				winner_id,
				loser_id,
				damage,
				round_number,
				true
			)
			damage = int(resolution.get("damage", damage))
		else:
			var loser_state: MatchPlayerState = _state_for_player(loser_id)
			if loser_state != null:
				loser_state.current_life = maxi(0, loser_state.current_life - damage)
				loser_state.eliminated = loser_state.current_life <= 0
			_apply_round_reward_cards(_state_for_player(winner_id), _state_for_player(loser_id), damage)
		if winner_team == GameEnums.TeamSide.PLAYER:
			player_a_result_text = "%s venceu %s ao vivo e causou %d de dano" % [player_a_name, player_b_name, damage]
			player_b_result_text = "%s perdeu para %s ao vivo e sofreu %d de dano" % [player_b_name, player_a_name, damage]
		else:
			player_a_result_text = "%s perdeu para %s ao vivo e sofreu %d de dano" % [player_a_name, player_b_name, damage]
			player_b_result_text = "%s venceu %s ao vivo e causou %d de dano" % [player_b_name, player_a_name, damage]
		result_text = player_a_result_text

	if player_a_state != null:
		player_a_state.last_round_result_text = player_a_result_text
		player_a_state.eliminated = player_a_state.current_life <= 0
		player_a_state.record_round_result(round_number, player_a_result_text, winner_id == player_a_id, damage if loser_id == player_a_id else 0)
		player_a_state.set_round_phase("RESULTADO")
	if player_b_state != null:
		player_b_state.last_round_result_text = player_b_result_text
		player_b_state.eliminated = player_b_state.current_life <= 0
		player_b_state.record_round_result(round_number, player_b_result_text, winner_id == player_b_id, damage if loser_id == player_b_id else 0)
		player_b_state.set_round_phase("RESULTADO")

	applied_result = true
	begin_result(BattleConfigScript.LIVE_TABLE_ACTION_STEP_SECONDS)
	push_event("result_ready", {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"damage": damage,
		"failsafe": failsafe_triggered,
	})
	_refresh_observer_caches()
	print("TABLE result table=%s winner=%s damage=%d failsafe=%s" % [
		table_id,
		winner_id if not winner_id.is_empty() else "EMPATE",
		damage,
		"yes" if failsafe_triggered else "no",
	])

func _resolve_winner_team() -> int:
	var player_alive: int = _count_living_team(GameEnums.TeamSide.PLAYER)
	var enemy_alive: int = _count_living_team(GameEnums.TeamSide.ENEMY)
	if player_alive > 0 and enemy_alive <= 0:
		return GameEnums.TeamSide.PLAYER
	if enemy_alive > 0 and player_alive <= 0:
		return GameEnums.TeamSide.ENEMY
	if player_alive != enemy_alive:
		return GameEnums.TeamSide.PLAYER if player_alive > enemy_alive else GameEnums.TeamSide.ENEMY
	var player_hp: int = _team_hp_total(GameEnums.TeamSide.PLAYER)
	var enemy_hp: int = _team_hp_total(GameEnums.TeamSide.ENEMY)
	if player_hp == enemy_hp:
		return -1
	return GameEnums.TeamSide.PLAYER if player_hp > enemy_hp else GameEnums.TeamSide.ENEMY

func _refresh_observer_caches() -> void:
	observer_cache_a = _build_observer_snapshot_for_viewer(player_a_state, player_b_state, GameEnums.TeamSide.PLAYER)
	observer_cache_b = _build_observer_snapshot_for_viewer(player_b_state, player_a_state, GameEnums.TeamSide.ENEMY)

func _build_observer_snapshot_for_viewer(
	viewer_state: MatchPlayerState,
	opponent_state: MatchPlayerState,
	viewer_team_side: int
) -> Dictionary:
	var units: Array[Dictionary] = []
	var non_master_count: int = 0
	var enemy_unit_count: int = 0
	var master_name: String = "Sem mestre"
	var opponent_master_name: String = "Sem mestre"
	var power_rating: int = 0
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		var absolute_team: int = unit_state.team_side
		var relative_team: int = GameEnums.TeamSide.PLAYER if absolute_team == viewer_team_side else GameEnums.TeamSide.ENEMY
		var coord: Vector2i = unit_state.coord
		if viewer_team_side == GameEnums.TeamSide.ENEMY:
			coord = _mirror_coord(coord)
		units.append({
			"unit_id": unit_state.unit_data.id if unit_state.unit_data != null else "",
			"unit_path": unit_state.unit_data.resource_path if unit_state.unit_data != null else "",
			"display_name": unit_state.get_display_name(),
			"coord": coord,
			"team_side": relative_team,
			"is_master": unit_state.is_master,
			"class_label": unit_state.get_class_name(),
			"race_name": unit_state.get_race_name(),
			"cost": unit_state.unit_data.get_effective_cost() if unit_state.unit_data != null else 0,
			"current_hp": unit_state.current_hp,
			"max_hp": maxi(unit_state.unit_data.max_hp if unit_state.unit_data != null else unit_state.current_hp, unit_state.current_hp),
			"current_mana": unit_state.current_mana,
			"mana_max": unit_state.get_mana_max(),
			"physical_attack": unit_state.get_physical_attack_value(),
			"magic_attack": unit_state.get_magic_attack_value(),
			"physical_defense": unit_state.get_physical_defense_value(),
			"magic_defense": unit_state.get_magic_defense_value(),
			"attack_range": unit_state.get_attack_range(),
			"crit_chance": unit_state.get_crit_chance(),
			"mana_gain_on_attack": unit_state.get_mana_gain_on_attack(),
			"mana_gain_on_hit": unit_state.get_mana_gain_on_hit(),
		})
		power_rating += unit_state.get_attack_value() + unit_state.get_defense_value()
		if relative_team == GameEnums.TeamSide.PLAYER and unit_state.is_master:
			master_name = unit_state.get_display_name()
		elif relative_team == GameEnums.TeamSide.ENEMY and unit_state.is_master:
			opponent_master_name = unit_state.get_display_name()
		elif relative_team == GameEnums.TeamSide.PLAYER:
			non_master_count += 1
		else:
			enemy_unit_count += 1

	return {
		"player_id": viewer_state.player_id if viewer_state != null else "",
		"player_name": viewer_state.display_name if viewer_state != null else "Jogador",
		"opponent_id": opponent_state.player_id if opponent_state != null else "",
		"opponent_name": opponent_state.display_name if opponent_state != null else "Sem oponente",
		"round_number": round_number,
		"phase": phase_name,
		"life": viewer_state.current_life if viewer_state != null else 0,
		"gold": viewer_state.current_gold if viewer_state != null else 0,
		"gold_budget": viewer_state.current_gold if viewer_state != null else 0,
		"units": units,
		"unit_count": units.size(),
		"non_master_count": non_master_count,
		"enemy_unit_count": enemy_unit_count,
		"power_rating": power_rating,
		"master_name": master_name,
		"opponent_master_name": opponent_master_name,
		"owned_card_count": viewer_state.get_owned_card_paths().size() if viewer_state != null else 0,
		"owned_card_names": _card_names_from_paths(viewer_state.get_owned_card_paths()) if viewer_state != null else [],
		"table_id": table_id,
		"streak": viewer_state.streak_value if viewer_state != null else 0,
		"player_level": viewer_state.player_level if viewer_state != null else 1,
		"card_summary": player_a_card_summary if viewer_team_side == GameEnums.TeamSide.PLAYER else player_b_card_summary,
		"recent_events": get_recent_events(),
		"summary": _build_snapshot_summary(units),
		"result_text": player_a_result_text if viewer_team_side == GameEnums.TeamSide.PLAYER else player_b_result_text,
	}

func _apply_cards_to_team(team_side: int, owner_state: MatchPlayerState) -> String:
	if owner_state == null:
		return ""
	var applied_lines: Array[String] = []
	for card_path in owner_state.get_owned_card_paths():
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		var effect_text: String = _apply_card_effect_to_team(team_side, owner_state, card_data)
		if effect_text.is_empty():
			continue
		applied_lines.append(effect_text)
		push_event("card_applied", {
			"owner_player_id": owner_state.player_id,
			"card": card_data.display_name,
			"summary": effect_text,
		})
	return _join_strings(applied_lines, " | ")

func _apply_card_effect_to_team(team_side: int, owner_state: MatchPlayerState, card_data: CardData) -> String:
	if card_data == null:
		return ""

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			if owner_state == null or card_data.global_life_heal <= 0:
				return ""
			var previous_life: int = owner_state.current_life
			owner_state.current_life = mini(BattleConfigScript.GLOBAL_LIFE, owner_state.current_life + card_data.global_life_heal)
			var healed_amount: int = owner_state.current_life - previous_life
			if healed_amount <= 0:
				return ""
			return "%s curou %+d PV" % [card_data.display_name, healed_amount]
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			var attack_target: BattleUnitState = _pick_ally_target(team_side, false)
			if attack_target == null:
				return ""
			attack_target.add_round_stat_bonus(
				card_data.physical_attack_bonus,
				card_data.magic_attack_bonus,
				card_data.physical_defense_bonus,
				card_data.magic_defense_bonus
			)
			return "%s em %s" % [card_data.display_name, attack_target.get_display_name()]
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			var magic_target: BattleUnitState = _pick_ally_target(team_side, true)
			if magic_target == null:
				return ""
			var magic_bonus: int = int(ceil(float(magic_target.get_magic_attack_value()) * (card_data.magic_attack_multiplier - 1.0)))
			if magic_bonus <= 0:
				return ""
			magic_target.add_round_stat_bonus(0, magic_bonus, 0, 0)
			return "%s ampliou %s" % [card_data.display_name, magic_target.get_display_name()]
		GameEnums.SupportCardEffectType.START_STEALTH:
			var stealth_target: BattleUnitState = _pick_ally_target(team_side, false)
			if stealth_target == null:
				return ""
			stealth_target.apply_stealth(maxi(1, card_data.stealth_turns))
			return "%s ocultou %s" % [card_data.display_name, stealth_target.get_display_name()]
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			var affected_units: int = 0
			for unit_state in unit_states:
				if unit_state == null or not unit_state.can_act():
					continue
				if unit_state.team_side == team_side:
					continue
				unit_state.apply_physical_miss_chance(
					clampf(card_data.physical_miss_chance, 0.0, 1.0),
					maxi(1, card_data.effect_duration_turns)
				)
				affected_units += 1
			if affected_units <= 0:
				return ""
			return "%s enfraqueceu %d inimigos" % [card_data.display_name, affected_units]
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			var pact_target: BattleUnitState = _pick_master(team_side)
			if pact_target == null:
				pact_target = _pick_ally_target(team_side, true)
			if pact_target == null:
				return ""
			pact_target.apply_blood_pact(maxf(0.0, card_data.mana_ratio_transfer_on_death))
			pact_target.add_round_stat_bonus(0, 2, 0, 0)
			return "%s reforcou %s" % [card_data.display_name, pact_target.get_display_name()]
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			var trap_target: BattleUnitState = _pick_enemy_trap_target(team_side)
			if trap_target == null:
				return ""
			trap_target.apply_turn_skip(maxi(1, card_data.stun_turns))
			trap_target.apply_mana_gain_multiplier(clampf(card_data.mana_gain_multiplier, 0.0, 1.0), maxi(1, card_data.stun_turns))
			return "%s travou %s" % [card_data.display_name, trap_target.get_display_name()]
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "%s ficou aguardando a vitoria" % card_data.display_name
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "%s ficou aguardando dano ao Mestre" % card_data.display_name
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			var defense_target: BattleUnitState = _pick_ally_target(team_side, false)
			if defense_target == null:
				return ""
			var defense_bonus: int = int(ceil(float(defense_target.get_physical_defense_value()) * (card_data.physical_defense_multiplier - 1.0)))
			if defense_bonus <= 0:
				return ""
			defense_target.add_round_stat_bonus(0, 0, defense_bonus, 0)
			return "%s protegeu %s" % [card_data.display_name, defense_target.get_display_name()]
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			var spear_target: BattleUnitState = _pick_ally_target(team_side, false)
			if spear_target == null:
				return ""
			var attack_bonus: int = int(ceil(float(spear_target.get_physical_attack_value()) * (card_data.physical_attack_multiplier - 1.0)))
			spear_target.add_round_stat_bonus(attack_bonus, 0, 0, 0)
			spear_target.apply_attack_range_bonus(maxi(0, card_data.attack_range_bonus), maxi(1, card_data.effect_duration_turns))
			return "%s fortaleceu %s" % [card_data.display_name, spear_target.get_display_name()]
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			var mana_target: BattleUnitState = _pick_ally_target(team_side, true)
			if mana_target == null:
				return ""
			mana_target.apply_mana_gain_multiplier(maxf(1.0, card_data.mana_gain_multiplier), maxi(1, card_data.effect_duration_turns))
			return "%s acelerou a mana de %s" % [card_data.display_name, mana_target.get_display_name()]
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			var lifesteal_target: BattleUnitState = _pick_ally_target(team_side, false)
			if lifesteal_target == null:
				return ""
			lifesteal_target.apply_lifesteal_ratio(maxf(0.0, card_data.lifesteal_ratio), maxi(1, card_data.effect_duration_turns))
			return "%s reforcou %s com roubo de vida" % [card_data.display_name, lifesteal_target.get_display_name()]
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			var displaced_target: BattleUnitState = _pick_enemy_trap_target(team_side)
			if displaced_target == null:
				return ""
			var destination: Vector2i = _pick_opening_reposition_coord(team_side, displaced_target)
			if not board_state.is_valid_coord(destination) or destination == displaced_target.coord:
				return ""
			if not board_state.move_unit(displaced_target, destination):
				return ""
			return "%s reposicionou %s" % [card_data.display_name, displaced_target.get_display_name()]
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			var slowed_count: int = 0
			for unit_state in unit_states:
				if unit_state == null or not unit_state.can_act():
					continue
				if unit_state.team_side == team_side:
					continue
				unit_state.apply_action_charge_multiplier(clampf(card_data.action_charge_multiplier, 0.1, 1.0), maxi(1, card_data.effect_duration_turns))
				slowed_count += 1
			return "%s desacelerou %d inimigos" % [card_data.display_name, slowed_count] if slowed_count > 0 else ""
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			pending_periodic_magic_fields[team_side] = {
				"interval_turns": maxi(1, card_data.periodic_interval_turns),
				"next_trigger_action": maxi(1, card_data.periodic_interval_turns),
				"remaining_triggers": maxi(1, card_data.effect_repeat_count),
				"damage_amount": maxi(1, card_data.damage_amount),
				"card_name": card_data.display_name,
			}
			return "%s ficou ativo sobre o campo inimigo" % card_data.display_name
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			if card_data.summon_unit_path.is_empty():
				return ""
			pending_first_ally_death_summons[team_side] = {
				"unit_path": card_data.summon_unit_path,
				"hp_ratio": clampf(card_data.summon_current_hp_ratio, 0.1, 1.0),
				"card_name": card_data.display_name,
			}
			return "%s ficou aguardando a primeira baixa aliada" % card_data.display_name
		_:
			return ""

func _pick_ally_target(team_side: int, prefer_magic: bool) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_score: int = -100000
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		var score: int = 0
		score += unit_state.get_magic_attack_value() * 6 if prefer_magic else unit_state.get_physical_attack_value() * 6
		score += unit_state.get_magic_attack_value() * 2
		score += unit_state.get_physical_attack_value() * 2
		score += unit_state.current_hp
		if unit_state.is_master:
			score -= 12
		if best_target == null or score > best_score:
			best_target = unit_state
			best_score = score
	return best_target

func _pick_master(team_side: int) -> BattleUnitState:
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state.is_master:
			return unit_state
	return null

func _pick_enemy_trap_target(team_side: int) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_score: int = 100000
	for unit_state in unit_states:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side == team_side:
			continue
		var coord: Vector2i = unit_state.coord
		var score: int = abs(coord.x - 3) * 10
		score += coord.y if team_side == GameEnums.TeamSide.PLAYER else (BattleConfigScript.BOARD_HEIGHT - 1 - coord.y)
		if unit_state.is_master:
			score += 8
		if best_target == null or score < best_score:
			best_target = unit_state
			best_score = score
	return best_target

func _pick_opening_reposition_coord(owner_team_side: int, target: BattleUnitState) -> Vector2i:
	if target == null:
		return Vector2i(-1, -1)
	var free_coords: Array[Vector2i] = []
	for y in range(BattleConfigScript.BOARD_HEIGHT):
		for x in range(BattleConfigScript.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			if not board_state.is_valid_coord(coord):
				continue
			var in_team_zone: bool = coord.y >= BattleConfigScript.BOARD_HEIGHT - BattleConfigScript.PLAYER_ROWS if owner_team_side == GameEnums.TeamSide.PLAYER else coord.y < BattleConfigScript.ENEMY_ROWS
			if not in_team_zone:
				continue
			if not board_state.is_cell_free(coord, target):
				continue
			free_coords.append(coord)
	if free_coords.is_empty():
		return Vector2i(-1, -1)
	free_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a: int = board_state.distance_between_cells(a, target.coord)
		var distance_b: int = board_state.distance_between_cells(b, target.coord)
		if distance_a != distance_b:
			return distance_a < distance_b
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return free_coords[0]

func _apply_round_reward_cards(winner_state: MatchPlayerState, loser_state: MatchPlayerState, damage_value: int) -> void:
	if winner_state == null:
		return
	var bonus_gold: int = 0
	var tribute_amount: int = 0
	for card_path in winner_state.get_owned_card_paths():
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		match card_data.support_effect_type:
			GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
				bonus_gold = maxi(bonus_gold, card_data.bonus_next_round_gold)
			GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
				tribute_amount = maxi(tribute_amount, card_data.tribute_steal_amount)
	if bonus_gold > 0:
		winner_state.add_bonus_next_round_gold(bonus_gold)
	if tribute_amount > 0 and damage_value > 0 and loser_state != null and loser_state.bonus_next_round_gold > 0:
		var stolen: int = mini(loser_state.bonus_next_round_gold, tribute_amount)
		loser_state.bonus_next_round_gold -= stolen
		winner_state.add_bonus_next_round_gold(stolen)

func _state_for_player(player_id: String) -> MatchPlayerState:
	if player_id == player_a_id:
		return player_a_state
	if player_id == player_b_id:
		return player_b_state
	return null

func _load_unit_data(unit_path: String) -> UnitData:
	if unit_path.is_empty():
		return null
	var resource: Resource = load(unit_path)
	return resource as UnitData

func _load_card_data(card_path: String) -> CardData:
	if card_path.is_empty():
		return null
	var resource: Resource = load(card_path)
	return resource as CardData

func _unit_runtime_key(unit_state: BattleUnitState) -> String:
	if unit_state == null or unit_state.unit_data == null:
		return ""
	return "%s|%d|%d" % [
		unit_state.unit_data.id,
		unit_state.team_side,
		unit_state.get_instance_id(),
	]

func _mirror_coord(coord: Vector2i) -> Vector2i:
	return Vector2i(coord.x, BattleConfigScript.BOARD_HEIGHT - 1 - coord.y)

func _opposite_team(team_side: int) -> int:
	return GameEnums.TeamSide.ENEMY if team_side == GameEnums.TeamSide.PLAYER else GameEnums.TeamSide.PLAYER

func _card_names_from_paths(card_paths: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for card_path in card_paths:
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		names.append(card_data.display_name)
	return names

func _build_snapshot_summary(units: Array[Dictionary]) -> String:
	if units.is_empty():
		return "Mesa sem pecas visiveis."
	var player_count: int = 0
	var enemy_count: int = 0
	var player_hp: int = 0
	var enemy_hp: int = 0
	for unit_entry in units:
		var team_side: int = int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER))
		var hp: int = int(unit_entry.get("current_hp", 0))
		if team_side == GameEnums.TeamSide.PLAYER:
			player_count += 1
			player_hp += hp
		else:
			enemy_count += 1
			enemy_hp += hp
	return "Aliados %d (%d PV) | Inimigos %d (%d PV)" % [player_count, player_hp, enemy_count, enemy_hp]

func _join_strings(values: Array[String], separator: String = ", ") -> String:
	var result: String = ""
	for value in values:
		if value.is_empty():
			continue
		if result.is_empty():
			result = value
		else:
			result += separator + value
	return result
