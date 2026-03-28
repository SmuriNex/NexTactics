extends RefCounted
class_name MatchPlayerState

var player_id: String = ""
var display_name: String = ""
var slot_index: int = -1
var is_local_player: bool = false
var deck_path: String = ""
var current_life: int = BattleConfig.GLOBAL_LIFE
var opponent_id_this_round: String = ""
var last_opponent_id: String = ""
var eliminated: bool = false
var board_snapshot: Dictionary = {}
var last_round_result_text: String = ""

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
	opponent_id_this_round = ""
	last_opponent_id = ""
	eliminated = false
	board_snapshot = {}
	last_round_result_text = ""
	return self

func set_board_snapshot(snapshot: Dictionary) -> void:
	board_snapshot = snapshot.duplicate(true)

func get_board_snapshot() -> Dictionary:
	return board_snapshot.duplicate(true)
