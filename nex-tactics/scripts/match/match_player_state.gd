extends RefCounted
class_name MatchPlayerState

var player_id: String = ""
var display_name: String = ""
var slot_index: int = -1
var is_local_player: bool = false
var deck_path: String = ""
var current_life: int = BattleConfig.GLOBAL_LIFE
var banked_gold: int = 0
var experience_value: int = 0
var player_level: int = 1
var streak_value: int = 0
var opponent_id_this_round: String = ""
var last_opponent_id: String = ""
var eliminated: bool = false
var board_snapshot: Dictionary = {}
var board_units: Array[Dictionary] = []
var bench_units: Array[Dictionary] = []
var last_round_result_text: String = ""
var round_history: Array[Dictionary] = []
var current_table_id: String = ""
var current_round_phase: String = "LOBBY"
var owned_card_paths: Array[String] = []
var last_shop_round_claimed: int = 0

func setup(
	p_player_id: String,
	p_display_name: String,
	p_slot_index: int,
	p_is_local_player: bool = false,
	p_deck_path: String = ""
) -> MatchPlayerState:
	player_id = p_player_id
	display_name = p_display_name
	slot_index = p_slot_index
	is_local_player = p_is_local_player
	deck_path = p_deck_path
	current_life = BattleConfig.GLOBAL_LIFE
	banked_gold = 0
	experience_value = 0
	player_level = 1
	streak_value = 0
	opponent_id_this_round = ""
	last_opponent_id = ""
	eliminated = false
	board_snapshot = {}
	board_units.clear()
	bench_units.clear()
	last_round_result_text = ""
	round_history.clear()
	current_table_id = ""
	current_round_phase = "LOBBY"
	owned_card_paths.clear()
	last_shop_round_claimed = 0
	return self

func set_board_snapshot(snapshot: Dictionary) -> void:
	board_snapshot = snapshot.duplicate(true)
	board_units.clear()
	var snapshot_units: Array = board_snapshot.get("units", [])
	for unit_variant in snapshot_units:
		var unit_entry: Dictionary = unit_variant
		board_units.append(unit_entry.duplicate(true))

func get_board_snapshot() -> Dictionary:
	return board_snapshot.duplicate(true)

func begin_round(opponent_id: String, table_id: String, phase_name: String = "PREPARACAO") -> void:
	opponent_id_this_round = opponent_id
	current_table_id = table_id
	current_round_phase = phase_name

func set_round_phase(phase_name: String) -> void:
	current_round_phase = phase_name

func record_round_result(round_number: int, result_text: String, did_win: bool, damage_value: int) -> void:
	last_round_result_text = result_text
	if did_win:
		streak_value = streak_value + 1 if streak_value >= 0 else 1
	elif damage_value > 0:
		streak_value = streak_value - 1 if streak_value <= 0 else -1
	else:
		streak_value = 0

	round_history.append({
		"round_number": round_number,
		"opponent_id": opponent_id_this_round,
		"table_id": current_table_id,
		"phase": current_round_phase,
		"result_text": result_text,
		"did_win": did_win,
		"damage": damage_value,
		"life_after": current_life,
	})
	if round_history.size() > 12:
		round_history.remove_at(0)

func set_owned_card_paths(card_paths: Array[String]) -> void:
	owned_card_paths.clear()
	for card_path in card_paths:
		var resolved_path: String = str(card_path)
		if resolved_path.is_empty():
			continue
		if not owned_card_paths.has(resolved_path):
			owned_card_paths.append(resolved_path)

func get_owned_card_paths() -> Array[String]:
	return owned_card_paths.duplicate()

func has_owned_card_path(card_path: String) -> bool:
	return owned_card_paths.has(card_path)

func add_owned_card_path(card_path: String) -> bool:
	var resolved_path: String = str(card_path)
	if resolved_path.is_empty():
		return false
	if owned_card_paths.has(resolved_path):
		return false
	owned_card_paths.append(resolved_path)
	return true
