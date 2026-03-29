extends RefCounted
class_name CombatInstance

const MAX_RECENT_EVENTS := 10

var table_id: String = ""
var table_index: int = -1
var round_number: int = 0
var player_a_id: String = ""
var player_b_id: String = ""
var player_a_name: String = ""
var player_b_name: String = ""
var phase_name: String = "PREPARACAO"
var acting_team: int = GameEnums.TeamSide.PLAYER
var player_turn_cursor: int = 0
var enemy_turn_cursor: int = 0
var action_time_accumulator: float = 0.0
var actions_taken: int = 0
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
var lineup_a: Dictionary = {}
var lineup_b: Dictionary = {}
var sim_units: Array[Dictionary] = []
var recent_events: Array[Dictionary] = []

func setup_from_pairing(
	pairing: Dictionary,
	p_round_number: int,
	player_a: MatchPlayerState,
	player_b: MatchPlayerState,
	p_lineup_a: Dictionary,
	p_lineup_b: Dictionary,
	p_sim_units: Array[Dictionary],
	p_acting_team: int,
	p_result_hold_seconds: float
) -> CombatInstance:
	table_id = "round_%d_table_%d" % [
		p_round_number,
		int(pairing.get("table_index", player_a.slot_index + player_b.slot_index)),
	]
	table_index = int(pairing.get("table_index", -1))
	round_number = p_round_number
	player_a_id = player_a.player_id if player_a != null else ""
	player_b_id = player_b.player_id if player_b != null else ""
	player_a_name = player_a.display_name if player_a != null else "Player A"
	player_b_name = player_b.display_name if player_b != null else "Player B"
	lineup_a = p_lineup_a.duplicate(true)
	lineup_b = p_lineup_b.duplicate(true)
	sim_units = p_sim_units.duplicate(true)
	acting_team = p_acting_team
	result_time_remaining = p_result_hold_seconds
	return self

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
	player_turn_cursor = 0
	enemy_turn_cursor = 0
	action_time_accumulator = 0.0
	actions_taken = 0
	recent_events.clear()

func begin_battle() -> void:
	phase_name = "BATALHA"
	action_time_accumulator = 0.0
	actions_taken = 0
	push_event("battle_started", {
		"summary": "%s vs %s" % [player_a_name, player_b_name],
	})

func begin_result(result_hold_seconds: float) -> void:
	phase_name = "RESULTADO"
	result_time_remaining = result_hold_seconds

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
