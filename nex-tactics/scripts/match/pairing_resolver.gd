extends RefCounted
class_name PairingResolver

func build_round_pairings(player_ids: Array[String], round_number: int) -> Array[Dictionary]:
	var ids: Array[String] = player_ids.duplicate()
	if ids.is_empty():
		return []

	if ids.size() % 2 != 0:
		ids.append("BYE")

	var rotation: Array[String] = ids.duplicate()
	var rotation_rounds: int = maxi(1, rotation.size() - 1)
	var round_offset: int = posmod(round_number - 1, rotation_rounds)

	for _step in range(round_offset):
		var last_id: String = rotation[rotation.size() - 1]
		rotation.remove_at(rotation.size() - 1)
		rotation.insert(1, last_id)

	var pairings: Array[Dictionary] = []
	var pair_count: int = rotation.size() / 2
	for index in range(pair_count):
		var player_a: String = rotation[index]
		var player_b: String = rotation[rotation.size() - 1 - index]
		if player_a == "BYE" or player_b == "BYE":
			continue
		pairings.append({
			"table_index": index,
			"player_a": player_a,
			"player_b": player_b,
		})

	return pairings
