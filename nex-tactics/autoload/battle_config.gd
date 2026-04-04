extends Node

const BOARD_WIDTH := 7
const BOARD_HEIGHT := 6
const PLAYER_ROWS := 2
const ENEMY_ROWS := 2

const STARTING_GOLD := 3
const GOLD_PER_ROUND := 2
const GLOBAL_LIFE := 100
const MAX_FIELD_UNITS := 8
const LOBBY_PLAYER_COUNT := 8
const PREP_DURATION_SECONDS := 30.0
const REVEAL_TRANSITION_SECONDS := 0.28
const COMBAT_DURATION_SCALE := 2.0
const ACTION_DELAY_ATTACK_SECONDS := 0.10 * COMBAT_DURATION_SCALE
const ACTION_DELAY_SKILL_SECONDS := 0.10 * COMBAT_DURATION_SCALE
const ACTION_DELAY_MOVE_SECONDS := 0.08 * COMBAT_DURATION_SCALE
const ACTION_DELAY_SKIP_SECONDS := 0.05 * COMBAT_DURATION_SCALE
const ACTION_DELAY_STUCK_SECONDS := 0.03 * COMBAT_DURATION_SCALE
const UNIT_MOVE_TWEEN_SECONDS := 0.10 * COMBAT_DURATION_SCALE
const UNIT_IMPACT_COLOR_SECONDS := 0.07 * COMBAT_DURATION_SCALE
const UNIT_IMPACT_RECOVER_SECONDS := 0.10 * COMBAT_DURATION_SCALE
const UNIT_EFFECT_COLOR_SECONDS := 0.10 * COMBAT_DURATION_SCALE
const UNIT_EFFECT_RECOVER_SECONDS := 0.12 * COMBAT_DURATION_SCALE
const UNIT_DEATH_FADE_SECONDS := 0.14 * COMBAT_DURATION_SCALE
const LIVE_TABLE_ACTION_STEP_SECONDS := 0.14 * COMBAT_DURATION_SCALE
const LIVE_TABLE_OBSERVED_ACTION_STEP_SECONDS := 0.08 * COMBAT_DURATION_SCALE

static func get_post_combat_base_damage(round_number: int) -> int:
	if round_number <= 2:
		return 2
	if round_number <= 4:
		return 3
	if round_number <= 6:
		return 4
	if round_number <= 8:
		return 5
	return 6

static func calculate_post_combat_damage(_result: Dictionary, round_number: int, winner_board_state: Dictionary) -> int:
	var base_damage: int = get_post_combat_base_damage(round_number)
	var survivor_count: int = maxi(1, int(winner_board_state.get("survivors", 0)))
	var total_damage: int = base_damage + survivor_count
	print("POST_DAMAGE round=%d base=%d survivors=%d total=%d" % [
		round_number,
		base_damage,
		survivor_count,
		total_damage,
	])
	return total_damage

static func adjust_unit_cost(value: int) -> int:
	match value:
		1:
			return 2
		2:
			return 3
		3:
			return 4
		_:
			return value
