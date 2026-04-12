extends GutTest

const GameDataScript := preload("res://autoload/game_data.gd")
const LobbyManagerScript := preload("res://scripts/match/lobby_manager.gd")

var lobby_manager: LobbyManager
var game_data
var deck_path := ""


func before_each() -> void:
	lobby_manager = LobbyManagerScript.new()
	game_data = GameDataScript.new()
	deck_path = game_data.get_deck_path(GameDataScript.DEFAULT_DECK_ID)
	lobby_manager.setup_demo_lobby(2, "", deck_path)
	lobby_manager.set_player_deck_path("player_1", deck_path)
	lobby_manager.set_player_deck_path("player_2", deck_path)


func after_each() -> void:
	lobby_manager = null
	if game_data != null:
		game_data.free()
		game_data = null


func _grant_master_wins(player_state: MatchPlayerState, count: int) -> void:
	for _index in range(count):
		player_state.apply_master_round_progression(true, false, true)


func test_background_lineup_respects_dynamic_field_limit_and_persists_bot_formation() -> void:
	var player_state: MatchPlayerState = lobby_manager.get_player("player_1")
	_grant_master_wins(player_state, 6)
	player_state.set_current_gold_capped(15, "test_dynamic_cap", false)

	var lineup: Dictionary = lobby_manager._build_background_lineup(player_state, 6)
	var expected_field_limit: int = player_state.get_field_unit_limit()
	var prep_debug: Dictionary = player_state.get_last_bot_prep_debug()

	assert_eq(expected_field_limit, 5, "Nivel 5 deve liberar 5 unidades alem do Mestre.")
	assert_eq(int(lineup.get("non_master_count", 0)), expected_field_limit)
	assert_eq(int(lineup.get("unit_count", 0)), expected_field_limit + 1)
	assert_eq(player_state.formation_state.get_ordered_entries(false).size(), expected_field_limit)
	assert_lt(player_state.current_gold, 15, "Bot precisa gastar ouro para preencher o campo.")
	assert_true(bool(prep_debug.get("planner_ran", false)))
	assert_eq(str(prep_debug.get("decision_source", "")), "limboai")
	assert_eq(int(prep_debug.get("field_after", 0)), expected_field_limit)
	assert_eq(str(prep_debug.get("reason", "")), "filled_to_cap")


func test_background_lineup_auto_consumes_pending_promotions() -> void:
	var player_state: MatchPlayerState = lobby_manager.get_player("player_1")
	_grant_master_wins(player_state, 3)
	player_state.set_current_gold_capped(12, "test_promotion", false)

	assert_eq(player_state.get_pending_master_promotion_count(), 1)

	var lineup: Dictionary = lobby_manager._build_background_lineup(player_state, 4)

	assert_gt(int(lineup.get("non_master_count", 0)), 0)
	assert_eq(player_state.get_pending_master_promotion_count(), 0)
	assert_gt(player_state.master_progression_state.unit_promotions.size(), 0)

func test_rebuild_bot_prep_state_exposes_reason_when_bot_cannot_close_next_slot() -> void:
	var player_state: MatchPlayerState = lobby_manager.get_player("player_1")
	_grant_master_wins(player_state, 6)
	player_state.set_current_gold_capped(1, "test_underfill_reason", false)

	var prep_result: Dictionary = lobby_manager.rebuild_bot_prep_state(player_state.player_id, 6)
	var prep_debug: Dictionary = prep_result.get("prep_debug", {})

	assert_true(bool(prep_debug.get("planner_ran", false)))
	assert_true(bool(prep_debug.get("attempted_fill", false)))
	assert_gt(int(prep_debug.get("empty_slots_remaining", 0)), 0)
	assert_eq(str(prep_debug.get("reason", "")), "insufficient_gold")
	assert_false(str(prep_debug.get("reason_detail", "")).is_empty())


func test_background_match_updates_progression_history_and_support_summary() -> void:
	var player_a: MatchPlayerState = lobby_manager.get_player("player_1")
	var player_b: MatchPlayerState = lobby_manager.get_player("player_2")
	player_a.begin_round(player_b.player_id, "test_table", "PREPARACAO")
	player_b.begin_round(player_a.player_id, "test_table", "PREPARACAO")
	player_a.set_current_gold_capped(12, "test_background_match", false)
	player_b.set_current_gold_capped(12, "test_background_match", false)
	player_a.add_owned_card_path("res://data/cards/necromancer/blinding_mist.tres")

	var lineup_a: Dictionary = lobby_manager._build_background_lineup(player_a, 4)
	var lineup_b: Dictionary = lobby_manager._build_background_lineup(player_b, 4)
	var snapshot_a: Dictionary = lobby_manager._build_table_snapshot(
		player_a,
		player_b,
		lineup_a,
		lineup_b,
		4,
		"PREPARACAO",
		""
	)
	var result: Dictionary = lobby_manager._resolve_background_match(player_a, player_b, snapshot_a, 4)

	assert_eq(int(result.get("round_number", 0)), 4)
	assert_false(str(result.get("card_summary_a", "")).is_empty(), "Support do bot precisa aparecer no resumo do combate em segundo plano.")

	lobby_manager._apply_background_match_result(player_a, player_b, result)

	assert_gt(player_a.experience_value, 0)
	assert_gt(player_b.experience_value, 0)
	assert_eq(player_a.round_history.size(), 1)
	assert_eq(player_b.round_history.size(), 1)
	assert_eq(player_a.current_round_phase, "RESULTADO")
	assert_eq(player_b.current_round_phase, "RESULTADO")


func test_live_table_result_updates_progression_history_and_phase() -> void:
	var player_a: MatchPlayerState = lobby_manager.get_player("player_1")
	var player_b: MatchPlayerState = lobby_manager.get_player("player_2")
	player_a.set_current_gold_capped(12, "test_live_table_progression", false)
	player_b.set_current_gold_capped(12, "test_live_table_progression", false)

	var pairings: Array[Dictionary] = [{
		"player_a": player_a.player_id,
		"player_b": player_b.player_id,
		"table_index": 0,
	}]
	lobby_manager.prepare_live_tables_for_round(pairings, 4)

	assert_true(lobby_manager.begin_live_tables_battle(4))
	var safeguard: int = 0
	while lobby_manager.has_active_live_tables(4) and safeguard < 200:
		lobby_manager.update_live_tables(1.0)
		safeguard += 1

	assert_true(lobby_manager.are_live_tables_resolved(4))
	assert_gt(player_a.experience_value, 0)
	assert_gt(player_b.experience_value, 0)
	assert_false(player_a.master_progression_state.last_round_xp_breakdown.is_empty())
	assert_false(player_b.master_progression_state.last_round_xp_breakdown.is_empty())
	assert_eq(player_a.round_history.size(), 1)
	assert_eq(player_b.round_history.size(), 1)
	assert_eq(player_a.current_round_phase, "RESULTADO")
	assert_eq(player_b.current_round_phase, "RESULTADO")
