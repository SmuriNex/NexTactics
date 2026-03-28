extends RefCounted
class_name LobbyManager

const CENTER_COLUMNS: Array[int] = [3, 2, 4, 1, 5, 0, 6]

var players: Dictionary = {}
var player_order: Array[String] = []
var local_player_id: String = ""
var deck_cache: Dictionary = {}
var unit_cache: Dictionary = {}

func setup_demo_lobby(player_count: int, p_local_player_id: String, default_deck_path: String = "") -> void:
	players.clear()
	player_order.clear()
	local_player_id = p_local_player_id

	for index in range(player_count):
		var player_id: String = "player_%d" % [index + 1]
		var player_state: MatchPlayerState = MatchPlayerState.new().setup(
			player_id,
			"Player %d" % [index + 1],
			index,
			player_id == local_player_id,
			default_deck_path
		)
		players[player_id] = player_state
		player_order.append(player_id)

func get_player_ids() -> Array[String]:
	return player_order.duplicate()

func get_active_player_ids() -> Array[String]:
	var active_ids: Array[String] = []
	for player_id in player_order:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null or player_state.eliminated:
			continue
		active_ids.append(player_id)
	return active_ids

func get_player(player_id: String) -> MatchPlayerState:
	var player_variant: Variant = players.get(player_id, null)
	if player_variant is MatchPlayerState:
		return player_variant as MatchPlayerState
	return null

func get_local_player() -> MatchPlayerState:
	return get_player(local_player_id)

func apply_round_pairings(pairings: Array[Dictionary]) -> void:
	for player_id in player_order:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null:
			continue
		player_state.last_opponent_id = player_state.opponent_id_this_round
		player_state.opponent_id_this_round = ""

	for pairing in pairings:
		var player_a: String = str(pairing.get("player_a", ""))
		var player_b: String = str(pairing.get("player_b", ""))
		var state_a: MatchPlayerState = get_player(player_a)
		var state_b: MatchPlayerState = get_player(player_b)
		if state_a != null:
			state_a.opponent_id_this_round = player_b
		if state_b != null:
			state_b.opponent_id_this_round = player_a

func store_board_snapshot(player_id: String, snapshot: Dictionary) -> void:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return
	player_state.set_board_snapshot(snapshot)

func get_board_snapshot(player_id: String) -> Dictionary:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return {}
	return player_state.get_board_snapshot()

func build_remote_round_snapshots(round_number: int, skipped_player_ids: Array[String] = []) -> void:
	for player_id in player_order:
		if skipped_player_ids.has(player_id):
			continue

		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null:
			continue
		if player_state.current_life <= 0:
			player_state.eliminated = true
			player_state.set_board_snapshot(_build_eliminated_snapshot(player_state, round_number))
			continue

		player_state.set_board_snapshot(_build_background_board_snapshot(player_state, round_number))

func resolve_background_pairings(
	pairings: Array[Dictionary],
	round_number: int,
	excluded_player_ids: Array[String] = []
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for pairing in pairings:
		var player_a_id: String = str(pairing.get("player_a", ""))
		var player_b_id: String = str(pairing.get("player_b", ""))
		if excluded_player_ids.has(player_a_id) or excluded_player_ids.has(player_b_id):
			continue

		var player_a: MatchPlayerState = get_player(player_a_id)
		var player_b: MatchPlayerState = get_player(player_b_id)
		if player_a == null or player_b == null:
			continue
		if player_a.eliminated or player_b.eliminated:
			continue

		var snapshot_a: Dictionary = player_a.get_board_snapshot()
		if snapshot_a.is_empty():
			snapshot_a = _build_background_board_snapshot(player_a, round_number)
			player_a.set_board_snapshot(snapshot_a)

		var snapshot_b: Dictionary = player_b.get_board_snapshot()
		if snapshot_b.is_empty():
			snapshot_b = _build_background_board_snapshot(player_b, round_number)
			player_b.set_board_snapshot(snapshot_b)

		var result: Dictionary = _resolve_background_match(player_a, player_b, snapshot_a, snapshot_b, round_number)
		_apply_background_match_result(player_a, player_b, result)
		results.append(result)

	return results

func _apply_background_match_result(
	player_a: MatchPlayerState,
	player_b: MatchPlayerState,
	result: Dictionary
) -> void:
	if player_a == null or player_b == null:
		return

	var winner_id: String = str(result.get("winner_id", ""))
	var loser_id: String = str(result.get("loser_id", ""))
	var damage: int = int(result.get("damage", 0))
	var result_text: String = str(result.get("result_text", ""))

	if winner_id.is_empty() or loser_id.is_empty():
		player_a.last_round_result_text = "Empate contra %s" % player_b.display_name
		player_b.last_round_result_text = "Empate contra %s" % player_a.display_name
		player_a.set_board_snapshot(_decorate_snapshot_with_result(player_a, player_a.get_board_snapshot(), "RESULTADO", player_a.last_round_result_text, -1))
		player_b.set_board_snapshot(_decorate_snapshot_with_result(player_b, player_b.get_board_snapshot(), "RESULTADO", player_b.last_round_result_text, -1))
		return

	var winner_state: MatchPlayerState = get_player(winner_id)
	var loser_state: MatchPlayerState = get_player(loser_id)
	if winner_state == null or loser_state == null:
		return

	loser_state.current_life = maxi(0, loser_state.current_life - damage)
	loser_state.eliminated = loser_state.current_life <= 0
	winner_state.eliminated = winner_state.current_life <= 0

	winner_state.last_round_result_text = result_text
	loser_state.last_round_result_text = "%s | Vida restante %d" % [
		str(result.get("loser_text", "")),
		loser_state.current_life,
	]

	var winner_survivors: int = int(result.get("winner_survivors", -1))
	var loser_survivors: int = int(result.get("loser_survivors", -1))
	winner_state.set_board_snapshot(_decorate_snapshot_with_result(
		winner_state,
		winner_state.get_board_snapshot(),
		"RESULTADO",
		winner_state.last_round_result_text,
		winner_survivors
	))
	loser_state.set_board_snapshot(_decorate_snapshot_with_result(
		loser_state,
		loser_state.get_board_snapshot(),
		"RESULTADO",
		loser_state.last_round_result_text,
		loser_survivors
	))

func _build_background_board_snapshot(player_state: MatchPlayerState, round_number: int) -> Dictionary:
	if player_state == null:
		return {}

	var deck_data: DeckData = _load_deck_data(player_state.deck_path)
	if deck_data == null:
		return _build_empty_snapshot(player_state, round_number, "SEM DECK")

	var available_energy: int = BattleConfig.STARTING_ENERGY + ((round_number - 1) * BattleConfig.ENERGY_PER_ROUND)
	var effective_energy: int = _effective_energy_budget(available_energy, round_number)
	var field_limit: int = _effective_field_limit(BattleConfig.MAX_FIELD_UNITS, round_number)
	var remaining_energy: int = effective_energy
	var occupied_coords: Array[Vector2i] = []
	var units: Array[Dictionary] = []
	var total_power: int = 0

	var master_data: UnitData = _load_unit_data(deck_data.master_unit_path)
	if master_data != null:
		var master_coord := Vector2i(3, BattleConfig.BOARD_HEIGHT - 1)
		var master_entry: Dictionary = _build_snapshot_unit_entry(master_data, master_coord, true)
		units.append(master_entry)
		occupied_coords.append(master_coord)
		total_power += _estimate_unit_power(master_data, true, player_state.slot_index, round_number)

	var unit_candidates: Array[UnitData] = _load_sorted_unit_candidates(deck_data, player_state.slot_index, round_number)
	var non_master_count: int = 0
	for unit_data in unit_candidates:
		if unit_data == null:
			continue
		if non_master_count >= field_limit:
			break
		if unit_data.cost > remaining_energy:
			continue

		var target_coord: Vector2i = _choose_snapshot_coord(
			unit_data.class_type,
			occupied_coords,
			player_state.slot_index + round_number
		)
		if not _is_valid_snapshot_coord(target_coord):
			continue

		units.append(_build_snapshot_unit_entry(unit_data, target_coord, false))
		occupied_coords.append(target_coord)
		remaining_energy -= unit_data.cost
		non_master_count += 1
		total_power += _estimate_unit_power(unit_data, false, player_state.slot_index, round_number)

	return {
		"player_id": player_state.player_id,
		"player_name": player_state.display_name,
		"round_number": round_number,
		"phase": "PREPARACAO",
		"life": player_state.current_life,
		"energy": available_energy,
		"energy_budget": effective_energy,
		"units": units,
		"unit_count": units.size(),
		"non_master_count": non_master_count,
		"power_rating": total_power,
		"master_name": str(units[0].get("display_name", "Mestre")) if not units.is_empty() else "Mestre",
		"summary": _build_snapshot_summary(units),
		"result_text": "",
	}

func _build_empty_snapshot(player_state: MatchPlayerState, round_number: int, phase_name: String) -> Dictionary:
	var player_name: String = player_state.display_name if player_state != null else "Jogador"
	var player_id: String = player_state.player_id if player_state != null else ""
	var life_value: int = player_state.current_life if player_state != null else 0
	return {
		"player_id": player_id,
		"player_name": player_name,
		"round_number": round_number,
		"phase": phase_name,
		"life": life_value,
		"energy": 0,
		"energy_budget": 0,
		"units": [],
		"unit_count": 0,
		"non_master_count": 0,
		"power_rating": 0,
		"master_name": "Sem mestre",
		"summary": "Sem unidades em campo.",
		"result_text": "",
	}

func _build_eliminated_snapshot(player_state: MatchPlayerState, round_number: int) -> Dictionary:
	var snapshot: Dictionary = _build_empty_snapshot(player_state, round_number, "ELIMINADO")
	snapshot["summary"] = "Jogador eliminado do lobby."
	snapshot["result_text"] = "KO"
	return snapshot

func _build_snapshot_unit_entry(unit_data: UnitData, coord: Vector2i, is_master: bool) -> Dictionary:
	return {
		"unit_id": unit_data.id,
		"display_name": unit_data.display_name,
		"coord": coord,
		"is_master": is_master,
		"class_label": _resolve_unit_class_label(unit_data),
		"race_name": _race_name(unit_data.race),
		"cost": unit_data.cost,
	}

func _load_sorted_unit_candidates(deck_data: DeckData, player_seed: int, round_number: int) -> Array[UnitData]:
	var units: Array[UnitData] = []
	if deck_data == null:
		return units

	for unit_path in deck_data.unit_paths:
		var unit_data: UnitData = _load_unit_data(unit_path)
		if unit_data != null:
			units.append(unit_data)

	units.sort_custom(_sort_unit_candidates.bind(player_seed, round_number))
	return units

func _sort_unit_candidates(a: UnitData, b: UnitData, player_seed: int, round_number: int) -> bool:
	if a == null:
		return false
	if b == null:
		return true

	var priority_a: int = _unit_priority(a.class_type, round_number)
	var priority_b: int = _unit_priority(b.class_type, round_number)
	if priority_a != priority_b:
		return priority_a < priority_b

	if round_number <= 2 and a.cost != b.cost:
		return a.cost < b.cost
	if a.cost != b.cost:
		return a.cost > b.cost

	var bias_a: int = _unit_sort_bias(a.id, player_seed, round_number)
	var bias_b: int = _unit_sort_bias(b.id, player_seed, round_number)
	if bias_a != bias_b:
		return bias_a < bias_b
	return a.display_name < b.display_name

func _unit_priority(class_type: int, round_number: int) -> int:
	if round_number <= 2:
		if class_type == GameEnums.ClassType.ATTACKER:
			return 0
		if class_type == GameEnums.ClassType.TANK:
			return 1
		if class_type == GameEnums.ClassType.SUPPORT:
			return 2
		if class_type == GameEnums.ClassType.STEALTH:
			return 3
		return 4

	if class_type == GameEnums.ClassType.TANK:
		return 0
	if class_type == GameEnums.ClassType.ATTACKER:
		return 1
	if class_type == GameEnums.ClassType.SUPPORT:
		return 2
	if class_type == GameEnums.ClassType.STEALTH:
		return 3
	return 4

func _unit_sort_bias(unit_id: String, player_seed: int, round_number: int) -> int:
	return abs(hash("%s|%d|%d" % [unit_id, player_seed, round_number])) % 17

func _choose_snapshot_coord(class_type: int, occupied_coords: Array[Vector2i], seed: int) -> Vector2i:
	var preferred_rows: Array[int] = _preferred_rows_for_class(class_type)
	var rotated_columns: Array[int] = _rotated_columns(seed)

	for row in preferred_rows:
		for column in rotated_columns:
			var coord := Vector2i(column, row)
			if not occupied_coords.has(coord):
				return coord

	for row in range(BattleConfig.BOARD_HEIGHT - BattleConfig.PLAYER_ROWS, BattleConfig.BOARD_HEIGHT):
		for column in rotated_columns:
			var fallback_coord := Vector2i(column, row)
			if not occupied_coords.has(fallback_coord):
				return fallback_coord

	return Vector2i(-1, -1)

func _preferred_rows_for_class(class_type: int) -> Array[int]:
	var frontline_row: int = BattleConfig.BOARD_HEIGHT - BattleConfig.PLAYER_ROWS
	var backline_row: int = BattleConfig.BOARD_HEIGHT - 1
	if class_type == GameEnums.ClassType.TANK:
		return [frontline_row, backline_row]
	if class_type == GameEnums.ClassType.SUPPORT or class_type == GameEnums.ClassType.SNIPER:
		return [backline_row, frontline_row]
	return [frontline_row, backline_row]

func _rotated_columns(seed: int) -> Array[int]:
	var rotated: Array[int] = CENTER_COLUMNS.duplicate()
	if rotated.is_empty():
		return rotated
	var offset: int = posmod(seed, rotated.size())
	for _step in range(offset):
		var first_value: int = rotated[0]
		rotated.remove_at(0)
		rotated.append(first_value)
	return rotated

func _is_valid_snapshot_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < BattleConfig.BOARD_WIDTH and coord.y >= 0 and coord.y < BattleConfig.BOARD_HEIGHT

func _estimate_unit_power(unit_data: UnitData, is_master: bool, player_seed: int, round_number: int) -> int:
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
	power += unit_data.cost * 12
	power += int(round(float(unit_data.mana_gain_on_attack + unit_data.mana_gain_on_hit) * 0.5))
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

	power += (_unit_sort_bias(unit_data.id, player_seed, round_number) % 7) - 3
	return maxi(1, power)

func _build_snapshot_summary(units: Array[Dictionary]) -> String:
	if units.is_empty():
		return "Sem unidades em campo."

	var summary_units: Array[String] = []
	for unit_entry in units:
		var display_name: String = str(unit_entry.get("display_name", "Unidade"))
		var coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
		summary_units.append("%s @ %s" % [display_name, coord])
	return _join_strings(summary_units)

func _resolve_background_match(
	player_a: MatchPlayerState,
	player_b: MatchPlayerState,
	snapshot_a: Dictionary,
	snapshot_b: Dictionary,
	round_number: int
) -> Dictionary:
	var power_a: int = int(snapshot_a.get("power_rating", 0)) + _player_round_bias(player_a, round_number)
	var power_b: int = int(snapshot_b.get("power_rating", 0)) + _player_round_bias(player_b, round_number)
	var unit_count_a: int = int(snapshot_a.get("non_master_count", 0))
	var unit_count_b: int = int(snapshot_b.get("non_master_count", 0))
	var power_diff: int = power_a - power_b

	if abs(power_diff) <= 18 and abs(unit_count_a - unit_count_b) <= 1:
		return {
			"winner_id": "",
			"loser_id": "",
			"damage": 0,
			"winner_survivors": -1,
			"loser_survivors": -1,
			"result_text": "Empate em segundo plano contra %s" % player_b.display_name,
			"loser_text": "Empate em segundo plano contra %s" % player_a.display_name,
		}

	var winner_state: MatchPlayerState = player_a if power_diff >= 0 else player_b
	var loser_state: MatchPlayerState = player_b if power_diff >= 0 else player_a
	var winner_snapshot: Dictionary = snapshot_a if power_diff >= 0 else snapshot_b
	var loser_snapshot: Dictionary = snapshot_b if power_diff >= 0 else snapshot_a
	var winner_units: int = maxi(1, int(winner_snapshot.get("non_master_count", 0)))
	var loser_units: int = maxi(1, int(loser_snapshot.get("non_master_count", 0)))
	var survivor_count: int = clampi(1 + int(floor(float(abs(power_diff)) / 55.0)), 1, winner_units)
	var loser_survivors: int = clampi(loser_units - survivor_count, 0, loser_units)

	return {
		"winner_id": winner_state.player_id,
		"loser_id": loser_state.player_id,
		"damage": survivor_count,
		"winner_survivors": survivor_count,
		"loser_survivors": loser_survivors,
		"result_text": "%s venceu %s em segundo plano e causou %d de dano" % [
			winner_state.display_name,
			loser_state.display_name,
			survivor_count,
		],
		"loser_text": "%s perdeu para %s em segundo plano e sofreu %d de dano" % [
			loser_state.display_name,
			winner_state.display_name,
			survivor_count,
		],
	}

func _decorate_snapshot_with_result(
	player_state: MatchPlayerState,
	source_snapshot: Dictionary,
	phase_name: String,
	result_text: String,
	keep_non_master_count: int
) -> Dictionary:
	var snapshot: Dictionary = source_snapshot.duplicate(true)
	snapshot["phase"] = phase_name
	snapshot["life"] = player_state.current_life if player_state != null else int(snapshot.get("life", 0))
	snapshot["result_text"] = result_text

	if keep_non_master_count >= 0:
		var units: Array[Dictionary] = []
		var source_units: Array = snapshot.get("units", [])
		var kept_non_master: int = 0
		for unit_variant in source_units:
			var unit_entry: Dictionary = unit_variant
			if bool(unit_entry.get("is_master", false)):
				units.append(unit_entry)
				continue
			if kept_non_master >= keep_non_master_count:
				continue
			units.append(unit_entry)
			kept_non_master += 1
		snapshot["units"] = units
		snapshot["unit_count"] = units.size()
		snapshot["non_master_count"] = kept_non_master
		snapshot["summary"] = _build_snapshot_summary(units)

	return snapshot

func _player_round_bias(player_state: MatchPlayerState, round_number: int) -> int:
	if player_state == null:
		return 0
	return ((player_state.slot_index * 13) + (round_number * 7)) % 11 - 5

func _effective_field_limit(field_limit: int, round_number: int) -> int:
	if round_number <= 1:
		return mini(field_limit, 1)
	if round_number == 2:
		return mini(field_limit, 2)
	if round_number == 3:
		return mini(field_limit, 3)
	return field_limit

func _effective_energy_budget(available_energy: int, round_number: int) -> int:
	if round_number <= 1:
		return mini(available_energy, 2)
	if round_number == 2:
		return mini(available_energy, 3)
	if round_number == 3:
		return mini(available_energy, 4)
	return available_energy

func _load_deck_data(path: String) -> DeckData:
	if path.is_empty():
		return null
	if deck_cache.has(path):
		return deck_cache[path] as DeckData

	var loaded: Resource = load(path)
	if loaded is DeckData:
		deck_cache[path] = loaded
		return loaded as DeckData
	return null

func _load_unit_data(path: String) -> UnitData:
	if path.is_empty():
		return null
	if unit_cache.has(path):
		return unit_cache[path] as UnitData

	var loaded: Resource = load(path)
	if loaded is UnitData:
		unit_cache[path] = loaded
		return loaded as UnitData
	return null

func _resolve_unit_class_label(unit_data: UnitData) -> String:
	if unit_data == null:
		return "Unidade"
	if not unit_data.class_label.is_empty():
		return unit_data.class_label
	return str(unit_data.class_type)

func _race_name(race_value: int) -> String:
	match race_value:
		GameEnums.Race.HUMAN:
			return "Humano"
		GameEnums.Race.ELF:
			return "Elfo"
		GameEnums.Race.FAIRY:
			return "Fada"
		GameEnums.Race.OGRE:
			return "Ogro"
		GameEnums.Race.UNDEAD:
			return "Morto-vivo"
		GameEnums.Race.BEAST:
			return "Besta"
		_:
			return "Desconhecida"

func _join_strings(values: Array[String], separator: String = ", ") -> String:
	var result: String = ""
	for value in values:
		var clean_value: String = value.strip_edges()
		if clean_value.is_empty():
			continue
		if result.is_empty():
			result = clean_value
		else:
			result += separator + clean_value
	return result
