extends GutTest

const MatchPlayerStateScript := preload("res://scripts/match/match_player_state.gd")
const BattleConfigScript := preload("res://autoload/battle_config.gd")

var player_state: MatchPlayerState


func before_each() -> void:
	player_state = MatchPlayerStateScript.new().setup("p1", "Tester", 0, true, "")


func after_each() -> void:
	player_state = null


func test_reset_economy_uses_starting_gold() -> void:
	player_state.reset_economy(BattleConfigScript.STARTING_GOLD)
	assert_eq(player_state.current_gold, BattleConfigScript.STARTING_GOLD)
	assert_eq(player_state.bonus_next_round_gold, 0)
	assert_eq(player_state.streak_value, 0)


func test_set_current_gold_is_capped_by_gold_cap() -> void:
	var applied_gold: int = player_state.set_current_gold_capped(999, "test")
	assert_eq(applied_gold, MatchPlayerStateScript.GOLD_CAP)
	assert_eq(player_state.current_gold, MatchPlayerStateScript.GOLD_CAP)


func test_calculate_round_income_includes_base_interest_streak_and_bonus() -> void:
	player_state.current_gold = 10
	player_state.win_streak = 2
	player_state.bonus_next_round_gold = 3

	var income: Dictionary = player_state.calculate_round_income()

	assert_eq(income.get("base", 0), MatchPlayerStateScript.ROUND_BASE_INCOME)
	assert_eq(income.get("interest", 0), 1)
	assert_eq(income.get("streak", 0), 1)
	assert_eq(income.get("bonus", 0), 3)
	assert_eq(income.get("total", 0), 10)


func test_apply_round_income_adds_gold_and_consumes_bonus() -> void:
	player_state.current_gold = 9
	player_state.lose_streak = 4
	player_state.bonus_next_round_gold = 2

	var income: Dictionary = player_state.apply_round_income()

	assert_eq(income.get("before_gold", 0), 9)
	assert_eq(income.get("base", 0), MatchPlayerStateScript.ROUND_BASE_INCOME)
	assert_eq(income.get("interest", 0), 0)
	assert_eq(income.get("streak", 0), 2)
	assert_eq(income.get("bonus", 0), 2)
	assert_eq(income.get("total", 0), 9)
	assert_eq(income.get("after_gold", 0), MatchPlayerStateScript.GOLD_CAP)
	assert_eq(player_state.current_gold, MatchPlayerStateScript.GOLD_CAP)
	assert_eq(player_state.bonus_next_round_gold, 0)
