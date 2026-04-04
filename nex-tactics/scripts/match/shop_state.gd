extends RefCounted
class_name ShopState

var owned_card_paths: Array[String] = []
var pending_offer_paths: Array[String] = []
var pending_offer_round: int = 0
var last_claimed_round: int = 0
var ui_open: bool = false

func reset() -> void:
	owned_card_paths.clear()
	pending_offer_paths.clear()
	pending_offer_round = 0
	last_claimed_round = 0
	ui_open = false

func set_owned_cards(card_paths: Array[String]) -> void:
	owned_card_paths.clear()
	for card_path in card_paths:
		var resolved_path: String = str(card_path)
		if resolved_path.is_empty():
			continue
		if not owned_card_paths.has(resolved_path):
			owned_card_paths.append(resolved_path)

func get_owned_cards() -> Array[String]:
	return owned_card_paths.duplicate()

func has_owned_card(card_path: String) -> bool:
	return owned_card_paths.has(str(card_path))

func add_owned_card(card_path: String, claimed_round: int = -1) -> bool:
	var resolved_path: String = str(card_path)
	if resolved_path.is_empty():
		return false
	if owned_card_paths.has(resolved_path):
		if claimed_round >= 0:
			last_claimed_round = maxi(last_claimed_round, claimed_round)
		return false
	owned_card_paths.append(resolved_path)
	if claimed_round >= 0:
		last_claimed_round = maxi(last_claimed_round, claimed_round)
	return true

func begin_offer(round_number: int, offer_paths: Array[String]) -> void:
	pending_offer_paths.clear()
	for offer_path in offer_paths:
		var resolved_path: String = str(offer_path)
		if resolved_path.is_empty():
			continue
		if not pending_offer_paths.has(resolved_path):
			pending_offer_paths.append(resolved_path)
	pending_offer_round = maxi(0, round_number)
	ui_open = not pending_offer_paths.is_empty()

func clear_offer() -> void:
	pending_offer_paths.clear()
	pending_offer_round = 0
	ui_open = false
