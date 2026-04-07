extends RefCounted
class_name MatchPlayerState
const BattleConfigScript := preload("res://autoload/battle_config.gd")
const MasterProgressionStateScript := preload("res://scripts/match/master_progression_state.gd")

const GOLD_CAP := 15
const ROUND_BASE_INCOME := 5

var player_id: String = ""
var display_name: String = ""
var slot_index: int = -1
var is_local_player: bool = false
var deck_path: String = ""
var current_life: int = BattleConfigScript.GLOBAL_LIFE
var _current_gold: int = 0
var current_gold: int:
	get:
		return _current_gold
	set(value):
		_current_gold = clampi(value, 0, GOLD_CAP)
var bonus_next_round_gold: int = 0
var banked_gold: int:
	get:
		return bonus_next_round_gold
	set(value):
		bonus_next_round_gold = maxi(0, value)
var master_progression_state: MasterProgressionState = MasterProgressionStateScript.new()
var experience_value: int = 0
var player_level: int = 1
var win_streak: int = 0
var lose_streak: int = 0
var streak_value: int = 0
var last_income_base: int = 0
var last_income_interest: int = 0
var last_income_streak: int = 0
var last_income_bonus: int = 0
var last_income_total: int = 0
var opponent_id_this_round: String = ""
var last_opponent_id: String = ""
var eliminated: bool = false
var placement: int = 0
var round_eliminated: int = -1
var total_damage_dealt: int = 0
var total_damage_taken: int = 0
var board_snapshot: Dictionary = {}
var last_round_result_text: String = ""
var round_history: Array[Dictionary] = []
var current_table_id: String = ""
var current_round_phase: String = "LOBBY"
var formation_state: FormationState = FormationState.new()
var shop_state: ShopState = ShopState.new()
var owned_card_paths: Array[String]:
	get:
		return shop_state.get_owned_cards()
	set(value):
		shop_state.set_owned_cards(value)
var last_shop_round_claimed: int:
	get:
		return shop_state.last_claimed_round
	set(value):
		shop_state.last_claimed_round = maxi(0, value)

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
	current_life = BattleConfigScript.GLOBAL_LIFE
	current_gold = 0
	bonus_next_round_gold = 0
	master_progression_state.reset()
	_sync_master_progression_fields()
	win_streak = 0
	lose_streak = 0
	streak_value = 0
	_reset_income_tracking()
	opponent_id_this_round = ""
	last_opponent_id = ""
	eliminated = false
	placement = 0
	round_eliminated = -1
	total_damage_dealt = 0
	total_damage_taken = 0
	board_snapshot = {}
	last_round_result_text = ""
	round_history.clear()
	current_table_id = ""
	current_round_phase = "LOBBY"
	formation_state.clear()
	shop_state.reset()
	return self

func set_board_snapshot(snapshot: Dictionary) -> void:
	board_snapshot = snapshot.duplicate(true)

func get_board_snapshot() -> Dictionary:
	return board_snapshot.duplicate(true)

func register_damage_dealt(value: int) -> int:
	if value <= 0:
		return total_damage_dealt
	total_damage_dealt += value
	return total_damage_dealt

func register_damage_taken(value: int) -> int:
	if value <= 0:
		return total_damage_taken
	total_damage_taken += value
	return total_damage_taken

func begin_round(opponent_id: String, table_id: String, phase_name: String = "PREPARACAO") -> void:
	opponent_id_this_round = opponent_id
	current_table_id = table_id
	current_round_phase = phase_name

func set_round_phase(phase_name: String) -> void:
	current_round_phase = phase_name

func reset_economy(starting_gold: int) -> void:
	current_gold = 0
	set_current_gold_capped(starting_gold, "match_start", false)
	bonus_next_round_gold = 0
	win_streak = 0
	lose_streak = 0
	streak_value = 0
	_reset_income_tracking()

func set_current_gold_capped(value: int, source_label: String = "", log_cap: bool = true) -> int:
	var normalized_value: int = maxi(0, value)
	if normalized_value > GOLD_CAP:
		if log_cap:
			print("ECON_CAP applied before=%d after=%d player=%s source=%s" % [
				normalized_value,
				GOLD_CAP,
				display_name,
				source_label if not source_label.is_empty() else "direct",
			])
		normalized_value = GOLD_CAP
	current_gold = normalized_value
	return current_gold

func add_current_gold(amount: int, source_label: String = "") -> int:
	return set_current_gold_capped(current_gold + amount, source_label)

func add_bonus_next_round_gold(amount: int) -> int:
	if amount <= 0:
		return bonus_next_round_gold
	bonus_next_round_gold = maxi(0, bonus_next_round_gold + amount)
	return bonus_next_round_gold

func calculate_round_income() -> Dictionary:
	var streak_count: int = maxi(win_streak, lose_streak)
	var interest_income: int = int(floor(float(current_gold) / 10.0))
	var streak_income: int = _streak_income_value(streak_count)
	var bonus_income: int = maxi(0, bonus_next_round_gold)
	return {
		"base": ROUND_BASE_INCOME,
		"interest": interest_income,
		"streak": streak_income,
		"bonus": bonus_income,
		"total": ROUND_BASE_INCOME + interest_income + streak_income + bonus_income,
	}

func apply_round_income() -> Dictionary:
	var income: Dictionary = calculate_round_income()
	var before_gold: int = current_gold
	last_income_base = int(income.get("base", 0))
	last_income_interest = int(income.get("interest", 0))
	last_income_streak = int(income.get("streak", 0))
	last_income_bonus = int(income.get("bonus", 0))
	last_income_total = int(income.get("total", 0))

	print("ECON_CURRENT_GOLD_BEFORE player=%s value=%d" % [display_name, before_gold])
	print("ECON_BASE player=%s value=%d" % [display_name, last_income_base])
	print("ECON_INTEREST player=%s value=%d" % [display_name, last_income_interest])
	print("ECON_STREAK player=%s value=%d" % [display_name, last_income_streak])
	print("ECON_BONUS player=%s value=%d" % [display_name, last_income_bonus])
	print("ECON_TOTAL player=%s value=%d" % [display_name, last_income_total])

	set_current_gold_capped(before_gold + last_income_total, "round_income")
	bonus_next_round_gold = 0
	print("ECON_CURRENT_GOLD_AFTER player=%s value=%d" % [display_name, current_gold])

	return {
		"base": last_income_base,
		"interest": last_income_interest,
		"streak": last_income_streak,
		"bonus": last_income_bonus,
		"total": last_income_total,
		"before_gold": before_gold,
		"after_gold": current_gold,
	}

func record_round_result(round_number: int, result_text: String, did_win: bool, damage_value: int) -> void:
	last_round_result_text = result_text
	if did_win:
		win_streak += 1
		lose_streak = 0
	elif damage_value > 0:
		lose_streak += 1
		win_streak = 0
	else:
		win_streak = 0
		lose_streak = 0
	_sync_streak_value()
	register_damage_taken(damage_value)

	round_history.append({
		"round_number": round_number,
		"opponent_id": opponent_id_this_round,
		"table_id": current_table_id,
		"phase": current_round_phase,
		"result_text": result_text,
		"did_win": did_win,
		"damage": damage_value,
		"life_after": current_life,
		"placement": placement,
	})
	if round_history.size() > 12:
		round_history.remove_at(0)

func apply_master_round_progression(did_win: bool, did_lose: bool, master_survived: bool) -> Dictionary:
	var result: Dictionary = master_progression_state.apply_round_result(did_win, did_lose, master_survived)
	_sync_master_progression_fields()
	return result

func get_field_capacity_total() -> int:
	return master_progression_state.get_field_capacity_total()

func get_field_unit_limit() -> int:
	return master_progression_state.get_field_unit_limit()

func has_pending_master_promotion() -> bool:
	return master_progression_state.has_pending_promotion()

func get_pending_master_promotion_count() -> int:
	return master_progression_state.get_pending_promotion_count()

func apply_master_promotion_to_unit(unit_id: String, class_type: int, display_name: String = "") -> Dictionary:
	var result: Dictionary = master_progression_state.apply_unit_promotion(unit_id, class_type, display_name)
	_sync_master_progression_fields()
	return result

func get_unit_promotion_bonus(unit_id: String) -> Dictionary:
	return master_progression_state.get_unit_promotion_bonus(unit_id)

func get_master_status_text() -> String:
	return master_progression_state.build_master_status_text()

func get_master_feedback_text() -> String:
	return master_progression_state.build_feedback_text()

func get_master_level() -> int:
	return player_level

func get_master_xp_total() -> int:
	return experience_value

func set_owned_card_paths(card_paths: Array[String]) -> void:
	owned_card_paths = card_paths

func get_owned_card_paths() -> Array[String]:
	return owned_card_paths

func has_owned_card_path(card_path: String) -> bool:
	return shop_state.has_owned_card(card_path)

func add_owned_card_path(card_path: String) -> bool:
	return shop_state.add_owned_card(card_path)

func _reset_income_tracking() -> void:
	last_income_base = 0
	last_income_interest = 0
	last_income_streak = 0
	last_income_bonus = 0
	last_income_total = 0

func _sync_streak_value() -> void:
	if win_streak > 0:
		streak_value = win_streak
		return
	if lose_streak > 0:
		streak_value = -lose_streak
		return
	streak_value = 0

func _streak_income_value(streak_count: int) -> int:
	if streak_count >= 6:
		return 3
	if streak_count >= 4:
		return 2
	if streak_count >= 2:
		return 1
	return 0

func _sync_master_progression_fields() -> void:
	experience_value = master_progression_state.xp_total
	player_level = master_progression_state.level
