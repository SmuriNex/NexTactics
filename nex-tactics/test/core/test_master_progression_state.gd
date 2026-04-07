extends GutTest

const MasterProgressionStateScript := preload("res://scripts/match/master_progression_state.gd")
const MatchPlayerStateScript := preload("res://scripts/match/match_player_state.gd")
const BattleUnitStateScript := preload("res://scripts/battle/battle_unit_state.gd")
const UnitDataScript := preload("res://scripts/data/unit_data.gd")

var progression_state: MasterProgressionState


func before_each() -> void:
	progression_state = MasterProgressionStateScript.new()


func after_each() -> void:
	progression_state = null


func test_initial_state_matches_demo_table() -> void:
	assert_eq(progression_state.level, 1)
	assert_eq(progression_state.xp_total, 0)
	assert_eq(progression_state.get_field_capacity_total(), 4)
	assert_eq(progression_state.get_field_unit_limit(), 3)
	assert_false(progression_state.has_pending_promotion())


func test_progression_reaches_level_five_at_approved_threshold() -> void:
	progression_state.xp_total = 18
	progression_state._resolve_level_from_xp()

	assert_eq(progression_state.level, 5)
	assert_eq(progression_state.get_field_capacity_total(), 6)
	assert_eq(progression_state.get_field_unit_limit(), 5)


func test_recovery_activates_after_three_losses_and_bonus_starts_on_next_loss() -> void:
	progression_state.apply_round_result(false, true, false)
	progression_state.apply_round_result(false, true, false)
	var third_loss: Dictionary = progression_state.apply_round_result(false, true, false)
	var fourth_loss: Dictionary = progression_state.apply_round_result(false, true, false)

	assert_true(bool(third_loss.get("recovery_active", false)))
	assert_eq(int(third_loss.get("recovery_bonus_xp", 0)), 0)
	assert_eq(int(fourth_loss.get("recovery_bonus_xp", 0)), 1)


func test_win_ends_recovery_and_resets_loss_streak() -> void:
	progression_state.apply_round_result(false, true, false)
	progression_state.apply_round_result(false, true, false)
	progression_state.apply_round_result(false, true, false)

	var result: Dictionary = progression_state.apply_round_result(true, false, true)

	assert_false(bool(result.get("recovery_active", true)))
	assert_eq(int(result.get("consecutive_losses_after", -1)), 0)


func test_promotion_is_granted_on_level_three_and_applies_class_bonus() -> void:
	progression_state.apply_round_result(true, false, true)
	progression_state.apply_round_result(true, false, true)
	progression_state.apply_round_result(true, false, true)

	assert_eq(progression_state.level, 3)
	assert_eq(progression_state.get_pending_promotion_count(), 1)

	var promotion_result: Dictionary = progression_state.apply_unit_promotion("unit_a", GameEnums.ClassType.TANK, "Guardiao")

	assert_true(bool(promotion_result.get("ok", false)))
	assert_eq(progression_state.get_pending_promotion_count(), 0)
	assert_eq(int(progression_state.get_unit_promotion_bonus("unit_a").get("hp_bonus", 0)), 12)
	assert_eq(int(progression_state.get_unit_promotion_bonus("unit_a").get("physical_defense_bonus", 0)), 1)


func test_match_player_state_mirrors_master_progression_fields() -> void:
	var player_state: MatchPlayerState = MatchPlayerStateScript.new().setup("p1", "Tester", 0, true, "")

	player_state.apply_master_round_progression(true, false, true)
	player_state.apply_master_round_progression(true, false, true)

	assert_eq(player_state.player_level, 2)
	assert_eq(player_state.experience_value, 6)
	assert_eq(player_state.get_field_capacity_total(), 5)
	assert_eq(player_state.get_field_unit_limit(), 4)


func test_progression_reaches_level_nine_at_adjusted_demo_threshold() -> void:
	progression_state.xp_total = 47
	progression_state._resolve_level_from_xp()

	assert_eq(progression_state.level, 9)
	assert_eq(progression_state.get_field_capacity_total(), 9)
	assert_eq(progression_state.get_field_unit_limit(), 8)


func test_feedback_mentions_recovery_bonus_when_active() -> void:
	progression_state.apply_round_result(false, true, false)
	progression_state.apply_round_result(false, true, false)
	progression_state.apply_round_result(false, true, false)
	progression_state.apply_round_result(false, true, false)

	var feedback_text: String = progression_state.build_feedback_text()

	assert_true(feedback_text.contains("Recuperacao +1"))


func test_battle_unit_state_keeps_permanent_promotion_after_round_reset() -> void:
	var unit_data: UnitData = UnitDataScript.new()
	unit_data.id = "test_attacker"
	unit_data.display_name = "Teste"
	unit_data.class_type = GameEnums.ClassType.ATTACKER
	unit_data.max_hp = 20
	unit_data.physical_attack = 4

	var unit_state: BattleUnitState = BattleUnitStateScript.new().setup_from_unit_data(
		unit_data,
		GameEnums.TeamSide.PLAYER,
		Vector2i(0, 0)
	)
	unit_state.apply_permanent_stat_bonus(12, 2, 0, 1, 0)
	unit_state.current_hp = 7
	unit_state.reset_for_new_round()

	assert_eq(unit_state.get_max_hp_value(), 32)
	assert_eq(unit_state.current_hp, 32)
	assert_eq(unit_state.get_physical_attack_value(), 7)
	assert_eq(unit_state.get_physical_defense_value(), 2)
