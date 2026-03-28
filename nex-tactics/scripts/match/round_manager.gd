extends RefCounted
class_name RoundManager

var pairing_resolver: PairingResolver = PairingResolver.new()
var current_round: int = 1
var current_pairings: Array[Dictionary] = []

func build_pairings(player_ids: Array[String], round_number: int) -> Array[Dictionary]:
	current_round = maxi(1, round_number)
	current_pairings = pairing_resolver.build_round_pairings(player_ids, current_round)
	return current_pairings.duplicate()

func get_opponent_for_player(player_id: String) -> String:
	for pairing in current_pairings:
		var player_a: String = str(pairing.get("player_a", ""))
		var player_b: String = str(pairing.get("player_b", ""))
		if player_a == player_id:
			return player_b
		if player_b == player_id:
			return player_a
	return ""

func get_current_pairings() -> Array[Dictionary]:
	return current_pairings.duplicate(true)
