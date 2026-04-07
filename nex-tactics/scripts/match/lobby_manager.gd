extends RefCounted
class_name LobbyManager

# Structural role:
# - Internal match-state backend for the local-first demo.
# - Owns player state, pairings, economy, global damage and ranking.
# - BattleManager remains the owner of the local playable loop.
# - Also preserves future-facing systems such as live tables, observer runtime
#   and multi-table simulation, which should remain supportive instead of
#   dominating the main demo flow.

const BattleConfigScript := preload("res://autoload/battle_config.gd")

const CENTER_COLUMNS: Array[int] = [3, 2, 4, 1, 5, 0, 6]
const BACKGROUND_COMBAT_MAX_ACTIONS := 240
const BACKGROUND_BOUNCE_THRESHOLD := 2
const BACKGROUND_RETARGET_COOLDOWN_TURNS := 2
const LIVE_TABLE_PREP_SECONDS := 1.2
const LIVE_TABLE_ACTION_STEP_SECONDS := BattleConfigScript.LIVE_TABLE_ACTION_STEP_SECONDS
const LIVE_TABLE_OBSERVED_ACTION_STEP_SECONDS := BattleConfigScript.LIVE_TABLE_OBSERVED_ACTION_STEP_SECONDS
const LIVE_TABLE_RESULT_HOLD_SECONDS := 0.9
const CombatInstanceScript := preload("res://scripts/match/combat_instance.gd")
const GameDataScript := preload("res://autoload/game_data.gd")

var players: Dictionary = {}
var player_order: Array[String] = []
var local_player_id: String = ""
var deck_cache: Dictionary = {}
var unit_cache: Dictionary = {}
var card_cache: Dictionary = {}
var live_tables: Dictionary = {}
var combat_instances: Dictionary = {}
var player_table_map: Dictionary = {}
var bot_prep_planner: EnemyPrepPlanner = EnemyPrepPlanner.new()
var game_data_helper = GameDataScript.new()
var elimination_order: Array[String] = []
var match_winner_id: String = ""
var match_finished: bool = false

func setup_demo_lobby(player_count: int, p_local_player_id: String, default_deck_path: String = "") -> void:
	players.clear()
	player_order.clear()
	live_tables.clear()
	combat_instances.clear()
	player_table_map.clear()
	elimination_order.clear()
	match_winner_id = ""
	match_finished = false
	local_player_id = p_local_player_id

	for index in range(player_count):
		var player_id: String = "player_%d" % [index + 1]
		var player_state: MatchPlayerState = MatchPlayerState.new().setup(
			player_id,
			"Player %d" % [index + 1],
			index,
			player_id == local_player_id,
			default_deck_path
		)
		players[player_id] = player_state
		player_order.append(player_id)
		set_player_deck_path(player_id, default_deck_path)

func assign_demo_bot_decks(deck_ids: Array[String], excluded_player_id: String = "") -> void:
	var cycle_ids: Array[String] = []
	for deck_id in deck_ids:
		var resolved_id: String = str(deck_id)
		if resolved_id.is_empty():
			continue
		cycle_ids.append(resolved_id)
	if cycle_ids.is_empty():
		cycle_ids = game_data_helper.get_available_deck_ids()
	if cycle_ids.is_empty():
		return

	var bot_index: int = 0
	for player_id in player_order:
		if player_id == excluded_player_id:
			continue
		var deck_id: String = cycle_ids[bot_index % cycle_ids.size()]
		set_player_deck_path(player_id, game_data_helper.get_deck_path(deck_id))
		bot_index += 1

func get_player_ids() -> Array[String]:
	return player_order.duplicate()

func get_active_player_ids() -> Array[String]:
	var active_ids: Array[String] = []
	for player_id in player_order:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null or player_state.eliminated:
			continue
		active_ids.append(player_id)
	return active_ids

func is_match_finished() -> bool:
	return match_finished

func get_match_winner_id() -> String:
	return match_winner_id

func get_match_winner() -> MatchPlayerState:
	return get_player(match_winner_id)

func apply_technical_byes(player_ids: Array[String], round_number: int) -> Array[Dictionary]:
	var bye_entries: Array[Dictionary] = []
	for player_id in player_ids:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null or player_state.eliminated:
			continue
		player_state.begin_round("", "", "BYE")
		player_state.set_round_phase("BYE")
		player_state.last_round_result_text = "Bye tecnico na rodada %d" % round_number
		bye_entries.append({
			"player_id": player_state.player_id,
			"player_name": player_state.display_name,
			"round_number": round_number,
		})
	return bye_entries

# Match-state backend ownership:
# Applies global consequences after a local or observed battle has already been
# decided by its caller.
func apply_post_combat_damage(
	winner_id: String,
	loser_id: String,
	damage_value: int,
	round_number: int,
	apply_reward_cards: bool = true
) -> Dictionary:
	var normalized_damage: int = clampi(damage_value, 0, 8)
	var winner_state: MatchPlayerState = get_player(winner_id)
	var loser_state: MatchPlayerState = get_player(loser_id)
	if winner_state != null and normalized_damage > 0:
		winner_state.register_damage_dealt(normalized_damage)
	if loser_state != null and normalized_damage > 0:
		loser_state.current_life = maxi(0, loser_state.current_life - normalized_damage)
	if apply_reward_cards and winner_state != null:
		_apply_round_reward_cards(winner_state, loser_state, normalized_damage)
	var eliminated_entries: Array[Dictionary] = process_eliminations_for_life_threshold(round_number)
	return {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"damage": normalized_damage,
		"eliminations": eliminated_entries,
	}

func process_eliminations_for_life_threshold(round_number: int) -> Array[Dictionary]:
	var pending_states: Array[MatchPlayerState] = []
	for player_id in player_order:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null or player_state.eliminated:
			continue
		if player_state.current_life > 0:
			continue
		pending_states.append(player_state)
	pending_states.sort_custom(_sort_pending_elimination_states)

	var eliminated_entries: Array[Dictionary] = []
	for player_state in pending_states:
		var elimination_entry: Dictionary = eliminate_player(player_state.player_id, round_number)
		if elimination_entry.is_empty():
			continue
		eliminated_entries.append(elimination_entry)

	finalize_match_if_needed(round_number)
	return eliminated_entries

func eliminate_player(player_id: String, round_number: int) -> Dictionary:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return {}
	if player_state.eliminated and player_state.placement > 0:
		return {
			"player_id": player_state.player_id,
			"player_name": player_state.display_name,
			"placement": player_state.placement,
			"round_eliminated": player_state.round_eliminated,
		}

	var placement_value: int = clampi(get_active_player_ids().size(), 1, BattleConfigScript.LOBBY_PLAYER_COUNT)
	player_state.current_life = maxi(0, player_state.current_life)
	player_state.eliminated = true
	player_state.placement = placement_value
	player_state.round_eliminated = maxi(1, round_number)
	player_state.opponent_id_this_round = ""
	player_state.current_table_id = ""
	player_state.current_round_phase = "ELIMINADO"
	player_state.set_board_snapshot(_build_eliminated_snapshot(player_state, round_number))
	player_table_map.erase(player_state.player_id)
	if not elimination_order.has(player_state.player_id):
		elimination_order.append(player_state.player_id)
	print("ELIMINATION player=%s placement=%d round=%d" % [
		player_state.display_name,
		player_state.placement,
		player_state.round_eliminated,
	])
	return {
		"player_id": player_state.player_id,
		"player_name": player_state.display_name,
		"placement": player_state.placement,
		"round_eliminated": player_state.round_eliminated,
	}

func finalize_match_if_needed(round_number: int) -> bool:
	if match_finished:
		return true
	var active_ids: Array[String] = get_active_player_ids()
	if active_ids.size() > 1:
		return false
	if active_ids.size() == 1:
		match_winner_id = active_ids[0]
		var winner_state: MatchPlayerState = get_player(match_winner_id)
		if winner_state != null:
			winner_state.eliminated = false
			winner_state.placement = 1
			winner_state.round_eliminated = -1
		match_finished = true
		print("RANKING winner=%s round=%d" % [match_winner_id, round_number])
		return true
	return false

func get_match_ranking_entries() -> Array[Dictionary]:
	var ranking_entries: Array[Dictionary] = []
	for player_id in player_order:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null:
			continue
		ranking_entries.append({
			"player_id": player_state.player_id,
			"player_name": player_state.display_name,
			"placement": player_state.placement,
			"round_eliminated": player_state.round_eliminated,
			"eliminated": player_state.eliminated,
			"life": player_state.current_life,
			"slot_index": player_state.slot_index,
			"total_damage_dealt": player_state.total_damage_dealt,
		})
	ranking_entries.sort_custom(_sort_match_ranking_entries)
	return ranking_entries

func get_final_board_unit_names(player_id: String) -> Array[String]:
	var snapshot: Dictionary = get_board_snapshot(player_id)
	var friendly_units: Array[Dictionary] = []
	for unit_variant in snapshot.get("units", []):
		var unit_entry: Dictionary = unit_variant
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) != GameEnums.TeamSide.PLAYER:
			continue
		friendly_units.append(unit_entry)
	friendly_units.sort_custom(_sort_final_snapshot_units)

	var unit_names: Array[String] = []
	for unit_entry in friendly_units:
		var unit_name: String = str(unit_entry.get("display_name", "")).strip_edges()
		if unit_name.is_empty():
			continue
		unit_names.append(unit_name)
	return unit_names

func _sort_pending_elimination_states(a: MatchPlayerState, b: MatchPlayerState) -> bool:
	if a == null:
		return false
	if b == null:
		return true
	if a.current_life != b.current_life:
		return a.current_life < b.current_life
	if a.total_damage_taken != b.total_damage_taken:
		return a.total_damage_taken > b.total_damage_taken
	return a.slot_index > b.slot_index

func _sort_match_ranking_entries(a: Dictionary, b: Dictionary) -> bool:
	var placement_a: int = int(a.get("placement", 0))
	var placement_b: int = int(b.get("placement", 0))
	if placement_a <= 0:
		placement_a = BattleConfigScript.LOBBY_PLAYER_COUNT + 1
	if placement_b <= 0:
		placement_b = BattleConfigScript.LOBBY_PLAYER_COUNT + 1
	if placement_a != placement_b:
		return placement_a < placement_b
	var life_a: int = int(a.get("life", 0))
	var life_b: int = int(b.get("life", 0))
	if life_a != life_b:
		return life_a > life_b
	return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))

func _sort_final_snapshot_units(a: Dictionary, b: Dictionary) -> bool:
	var master_a: bool = bool(a.get("is_master", false))
	var master_b: bool = bool(b.get("is_master", false))
	if master_a != master_b:
		return master_a
	var cost_a: int = int(a.get("cost", 0))
	var cost_b: int = int(b.get("cost", 0))
	if cost_a != cost_b:
		return cost_a > cost_b
	return str(a.get("display_name", "")) < str(b.get("display_name", ""))

func get_player(player_id: String) -> MatchPlayerState:
	var player_variant: Variant = players.get(player_id, null)
	if player_variant is MatchPlayerState:
		return player_variant as MatchPlayerState
	return null

func get_local_player() -> MatchPlayerState:
	return get_player(local_player_id)

func initialize_match_economy() -> void:
	for player_id in player_order:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null:
			continue
		player_state.reset_economy(BattleConfigScript.STARTING_GOLD)

func apply_round_income_for_prep(round_number: int) -> Array[Dictionary]:
	var income_entries: Array[Dictionary] = []
	if round_number <= 1:
		return income_entries

	for player_id in player_order:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null or player_state.eliminated:
			continue
		var income_breakdown: Dictionary = player_state.apply_round_income()
		income_entries.append({
			"player_id": player_state.player_id,
			"player_name": player_state.display_name,
			"income": income_breakdown,
		})
	return income_entries

func set_player_deck_path(player_id: String, deck_path: String, reset_owned_cards: bool = true) -> void:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return
	player_state.deck_path = deck_path
	if not reset_owned_cards:
		return
	player_state.set_owned_card_paths([])
	player_state.last_shop_round_claimed = 0

func set_player_owned_cards(player_id: String, card_paths: Array[String], claimed_round: int = -1) -> void:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return
	player_state.set_owned_card_paths(card_paths)
	if claimed_round >= 0:
		player_state.last_shop_round_claimed = claimed_round

func get_player_owned_cards(player_id: String) -> Array[String]:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return []
	return player_state.get_owned_card_paths()

func add_owned_card_to_player(player_id: String, card_path: String, claimed_round: int = -1) -> bool:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return false
	var added: bool = player_state.add_owned_card_path(card_path)
	if claimed_round >= 0:
		player_state.last_shop_round_claimed = claimed_round
	return added

func build_card_shop_offer_details(player_id: String, round_number: int, max_options: int = 2) -> Dictionary:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return {
			"player_id": player_id,
			"round_number": round_number,
			"offer_paths": [],
			"available_paths": [],
			"owned_paths": [],
			"raw_card_pool_paths": [],
			"valid_card_pool_paths": [],
			"invalid_card_pool_paths": [],
			"card_pool_paths": [],
			"deck_path": "",
			"card_pool_count": 0,
			"valid_card_pool_count": 0,
			"reason": "missing_player_state",
		}

	if round_number <= 0:
		return {
			"player_id": player_id,
			"round_number": round_number,
			"offer_paths": [],
			"available_paths": [],
			"owned_paths": player_state.get_owned_card_paths(),
			"raw_card_pool_paths": [],
			"valid_card_pool_paths": [],
			"invalid_card_pool_paths": [],
			"card_pool_paths": [],
			"deck_path": player_state.deck_path,
			"card_pool_count": 0,
			"valid_card_pool_count": 0,
			"reason": "invalid_round",
		}

	if round_number % 3 != 0:
		return {
			"player_id": player_id,
			"round_number": round_number,
			"offer_paths": [],
			"available_paths": [],
			"owned_paths": player_state.get_owned_card_paths(),
			"raw_card_pool_paths": [],
			"valid_card_pool_paths": [],
			"invalid_card_pool_paths": [],
			"card_pool_paths": [],
			"deck_path": player_state.deck_path,
			"card_pool_count": 0,
			"valid_card_pool_count": 0,
			"reason": "round_not_multiple_of_3",
		}

	var deck_data: DeckData = _load_deck_data(player_state.deck_path)
	if deck_data == null:
		return {
			"player_id": player_id,
			"round_number": round_number,
			"offer_paths": [],
			"available_paths": [],
			"owned_paths": player_state.get_owned_card_paths(),
			"raw_card_pool_paths": [],
			"valid_card_pool_paths": [],
			"invalid_card_pool_paths": [],
			"card_pool_paths": [],
			"deck_path": player_state.deck_path,
			"card_pool_count": 0,
			"valid_card_pool_count": 0,
			"reason": "missing_deck_data",
		}

	var owned_paths: Array[String] = player_state.get_owned_card_paths()
	var card_pool_details: Dictionary = _resolve_card_pool_paths(deck_data.card_pool_paths)
	var raw_card_pool_paths: Array[String] = card_pool_details.get("raw_paths", []).duplicate()
	var valid_card_pool_paths: Array[String] = card_pool_details.get("valid_paths", []).duplicate()
	var invalid_card_pool_paths: Array[String] = card_pool_details.get("invalid_paths", []).duplicate()
	var available_paths: Array[String] = []
	for resolved_path in valid_card_pool_paths:
		if player_state.has_owned_card_path(resolved_path):
			continue
		available_paths.append(resolved_path)

	available_paths.sort_custom(_sort_card_offer_paths.bind(player_state.slot_index, round_number))
	var offer_paths: Array[String] = _trim_card_offer_paths(available_paths, max_options)

	var reason: String = "ok"
	if offer_paths.is_empty():
		offer_paths = _trim_card_offer_paths(valid_card_pool_paths, max_options)
		if not offer_paths.is_empty():
			reason = "fallback_full_valid_pool"
		elif not raw_card_pool_paths.is_empty():
			reason = "no_valid_card_resources"
		else:
			reason = "empty_card_pool"
	elif offer_paths.size() < max_options:
		reason = "insufficient_unique_valid_cards"

	return {
		"player_id": player_id,
		"round_number": round_number,
		"offer_paths": offer_paths,
		"available_paths": available_paths,
		"owned_paths": owned_paths,
		"raw_card_pool_paths": raw_card_pool_paths,
		"valid_card_pool_paths": valid_card_pool_paths,
		"invalid_card_pool_paths": invalid_card_pool_paths,
		"card_pool_paths": raw_card_pool_paths,
		"deck_path": player_state.deck_path,
		"card_pool_count": raw_card_pool_paths.size(),
		"valid_card_pool_count": valid_card_pool_paths.size(),
		"reason": reason,
	}

func build_card_shop_offer(player_id: String, round_number: int, max_options: int = 2) -> Array[String]:
	var details: Dictionary = build_card_shop_offer_details(player_id, round_number, max_options)
	return details.get("offer_paths", []).duplicate()

func _normalize_card_pool_paths(card_pool_paths: Array) -> Array[String]:
	var normalized_paths: Array[String] = []
	for path_variant in card_pool_paths:
		var resolved_path: String = str(path_variant)
		if resolved_path.is_empty():
			continue
		if normalized_paths.has(resolved_path):
			continue
		normalized_paths.append(resolved_path)
	return normalized_paths

func _resolve_card_pool_paths(card_pool_paths: Array) -> Dictionary:
	var raw_paths: Array[String] = _normalize_card_pool_paths(card_pool_paths)
	var valid_paths: Array[String] = []
	var invalid_paths: Array[String] = []
	for resolved_path in raw_paths:
		var card_data: CardData = _load_card_data(resolved_path)
		if card_data == null:
			invalid_paths.append(resolved_path)
			continue
		valid_paths.append(resolved_path)
	return {
		"raw_paths": raw_paths,
		"valid_paths": valid_paths,
		"invalid_paths": invalid_paths,
	}

func _trim_card_offer_paths(source_paths: Array[String], max_options: int) -> Array[String]:
	var trimmed_paths: Array[String] = source_paths.duplicate()
	if max_options > 0 and trimmed_paths.size() > max_options:
		trimmed_paths.resize(max_options)
	return trimmed_paths

func grant_periodic_cards_for_round(round_number: int, excluded_player_ids: Array[String] = []) -> Array[Dictionary]:
	var granted_entries: Array[Dictionary] = []
	if round_number <= 0 or round_number % 3 != 0:
		return granted_entries

	for player_id in player_order:
		if excluded_player_ids.has(player_id):
			continue

		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null or player_state.eliminated:
			continue
		if player_state.last_shop_round_claimed >= round_number:
			continue

		var offer_details: Dictionary = build_card_shop_offer_details(player_id, round_number)
		var offer_paths: Array[String] = offer_details.get("offer_paths", []).duplicate()
		if offer_paths.is_empty():
			player_state.last_shop_round_claimed = round_number
			print("SHOP bot cancelado: player=%s round=%d reason=%s offer=%s" % [
				player_state.display_name,
				round_number,
				str(offer_details.get("reason", "insufficient_options")),
				_join_strings(offer_paths),
			])
			continue

		var chosen_path: String = _choose_background_shop_pick(player_state, offer_paths, round_number)
		if chosen_path.is_empty():
			chosen_path = offer_paths[0]
		if add_owned_card_to_player(player_id, chosen_path, round_number):
			var chosen_card: CardData = _load_card_data(chosen_path)
			granted_entries.append({
				"player_id": player_id,
				"player_name": player_state.display_name,
				"card_path": chosen_path,
				"card_name": chosen_card.display_name if chosen_card != null else chosen_path,
			})
	return granted_entries

func apply_round_pairings(pairings: Array[Dictionary]) -> void:
	for player_id in player_order:
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null:
			continue
		player_state.last_opponent_id = player_state.opponent_id_this_round
		player_state.opponent_id_this_round = ""

	for pairing in pairings:
		var player_a: String = str(pairing.get("player_a", ""))
		var player_b: String = str(pairing.get("player_b", ""))
		var state_a: MatchPlayerState = get_player(player_a)
		var state_b: MatchPlayerState = get_player(player_b)
		if state_a != null:
			state_a.opponent_id_this_round = player_b
		if state_b != null:
			state_b.opponent_id_this_round = player_a

func store_board_snapshot(player_id: String, snapshot: Dictionary) -> void:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return
	player_state.set_board_snapshot(snapshot)
	player_state.set_round_phase(str(snapshot.get("phase", player_state.current_round_phase)))

func get_board_snapshot(player_id: String) -> Dictionary:
	var player_state: MatchPlayerState = get_player(player_id)
	if player_state == null:
		return {}
	var combat_instance = get_live_combat_instance_for_player(player_id)
	if combat_instance != null:
		return combat_instance.get_observer_snapshot_for_player(player_id)
	return player_state.get_board_snapshot()

func get_table_id_for_player(player_id: String) -> String:
	if player_id.is_empty():
		return ""
	return str(player_table_map.get(player_id, ""))

func get_table_for_player(player_id: String) -> Dictionary:
	var table_id: String = get_table_id_for_player(player_id)
	if table_id.is_empty():
		return {}
	return get_table(table_id)

func get_table(table_id: String) -> Dictionary:
	if table_id.is_empty():
		return {}
	var table_variant: Variant = live_tables.get(table_id, {})
	if table_variant is Dictionary:
		return (table_variant as Dictionary).duplicate(true)
	return {}

func get_live_combat_instance(table_id: String):
	if table_id.is_empty():
		return null
	return combat_instances.get(table_id, null)

func get_runtime_for_table(table_id: String, viewer_player_id: String = "") -> Dictionary:
	var table: Dictionary = get_table(table_id)
	if table.is_empty():
		return {}

	var combat_instance = get_live_combat_instance(table_id)
	if combat_instance == null:
		return {}

	var player_a_id: String = str(table.get("player_a_id", ""))
	var player_b_id: String = str(table.get("player_b_id", ""))
	var resolved_viewer_player_id: String = viewer_player_id
	if resolved_viewer_player_id.is_empty():
		resolved_viewer_player_id = player_a_id
	var player_state: MatchPlayerState = get_player(resolved_viewer_player_id)
	var player_a_state: MatchPlayerState = get_player(player_a_id)
	var player_b_state: MatchPlayerState = get_player(player_b_id)
	var opponent_id: String = player_b_id if player_a_id == resolved_viewer_player_id else player_a_id
	var opponent_state: MatchPlayerState = get_player(opponent_id)
	var viewer_team_side: int = combat_instance.get_relative_team_for_player(resolved_viewer_player_id)

	return {
		"player_id": resolved_viewer_player_id,
		"player_name": player_state.display_name if player_state != null else resolved_viewer_player_id,
		"opponent_id": opponent_id,
		"opponent_name": opponent_state.display_name if opponent_state != null else opponent_id,
		"table_player_a_id": player_a_id,
		"table_player_a_name": player_a_state.display_name if player_a_state != null else player_a_id,
		"table_player_b_id": player_b_id,
		"table_player_b_name": player_b_state.display_name if player_b_state != null else player_b_id,
		"table_id": table_id,
		"table": table,
		"combat_instance": combat_instance,
		"unit_states": combat_instance.unit_states,
		"viewer_team_side": viewer_team_side,
		"phase": str(combat_instance.phase_name),
		"round_number": int(combat_instance.round_number),
	}

func get_observed_runtime(player_id: String) -> Dictionary:
	var table_id: String = get_table_id_for_player(player_id)
	if table_id.is_empty():
		return {}
	return get_runtime_for_table(table_id, player_id)

func prepare_live_tables_for_round(
	pairings: Array[Dictionary],
	round_number: int,
	excluded_player_ids: Array[String] = []
) -> void:
	live_tables.clear()
	combat_instances.clear()
	player_table_map.clear()

	var processed_ids: Dictionary = {}
	for pairing in pairings:
		var player_a_id: String = str(pairing.get("player_a", ""))
		var player_b_id: String = str(pairing.get("player_b", ""))
		if player_a_id.is_empty() or player_b_id.is_empty():
			continue
		var player_a: MatchPlayerState = get_player(player_a_id)
		var player_b: MatchPlayerState = get_player(player_b_id)
		if excluded_player_ids.has(player_a_id) or excluded_player_ids.has(player_b_id):
			if player_a != null:
				player_a.begin_round(player_b_id, "")
			if player_b != null:
				player_b.begin_round(player_a_id, "")
			processed_ids[player_a_id] = true
			processed_ids[player_b_id] = true
			continue

		if player_a == null or player_b == null:
			continue
		if player_a.current_life <= 0:
			player_a.eliminated = true
		if player_b.current_life <= 0:
			player_b.eliminated = true
		if player_a.eliminated or player_b.eliminated:
			player_a.begin_round(player_b_id, "")
			player_b.begin_round(player_a_id, "")
			if not player_a.eliminated:
				player_a.set_board_snapshot(_build_solo_board_snapshot(player_a, round_number))
			else:
				player_a.set_board_snapshot(_build_eliminated_snapshot(player_a, round_number))
			if not player_b.eliminated:
				player_b.set_board_snapshot(_build_solo_board_snapshot(player_b, round_number))
			else:
				player_b.set_board_snapshot(_build_eliminated_snapshot(player_b, round_number))
			processed_ids[player_a_id] = true
			processed_ids[player_b_id] = true
			continue

		var lineup_a: Dictionary = _build_background_lineup(player_a, round_number)
		var lineup_b: Dictionary = _build_background_lineup(player_b, round_number)
		var snapshot_a: Dictionary = _build_table_snapshot(
			player_a,
			player_b,
			lineup_a,
			lineup_b,
			round_number,
			"PREPARACAO",
			""
		)
		var combat_instance = CombatInstanceScript.new().setup_from_pairing(
			pairing,
			round_number,
			player_a,
			player_b,
			snapshot_a,
			LIVE_TABLE_RESULT_HOLD_SECONDS
		)
		combat_instance.owner_lobby_manager = self
		var table_id: String = combat_instance.table_id
		if table_id.is_empty():
			continue
		live_tables[table_id] = {
			"table_id": table_id,
			"table_index": combat_instance.table_index,
			"round_number": round_number,
			"player_a_id": player_a_id,
			"player_b_id": player_b_id,
		}
		combat_instances[table_id] = combat_instance
		player_table_map[player_a_id] = table_id
		player_table_map[player_b_id] = table_id
		player_a.begin_round(player_b_id, table_id)
		player_b.begin_round(player_a_id, table_id)
		_sync_combat_instance_snapshots(combat_instance)
		print("LIVE_TABLE created: %s | round=%d | %s vs %s" % [
			table_id,
			round_number,
			player_a.display_name,
			player_b.display_name,
		])
		processed_ids[player_a_id] = true
		processed_ids[player_b_id] = true

	for player_id in player_order:
		if processed_ids.has(player_id):
			continue
		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null:
			continue
		if player_state.current_life <= 0:
			player_state.eliminated = true
		player_state.begin_round("", "")
		if player_state.eliminated:
			player_state.set_board_snapshot(_build_eliminated_snapshot(player_state, round_number))
		elif not excluded_player_ids.has(player_id):
			player_state.set_board_snapshot(_build_solo_board_snapshot(player_state, round_number))

func begin_live_tables_battle(round_number: int = -1) -> bool:
	var changed: bool = false
	for table_id in combat_instances.keys():
		var combat_instance = combat_instances.get(table_id, null)
		if combat_instance == null:
			continue
		if not combat_instance.matches_round(round_number):
			continue
		if combat_instance.phase_name != "PREPARACAO":
			continue
		combat_instance.begin_battle()
		_sync_combat_instance_snapshots(combat_instance)
		print("LIVE_TABLE battle_started: %s | round=%d" % [
			combat_instance.table_id,
			combat_instance.round_number,
		])
		changed = true
	return changed

# Future-facing support ownership:
# Live-table processing exists for observer and online-ready structure, not as
# the source of truth for the local player's playable combat.
func update_live_tables(delta: float, observed_player_id: String = "") -> bool:
	var changed: bool = false
	for table_id in combat_instances.keys():
		var combat_instance = combat_instances.get(table_id, null)
		if combat_instance == null:
			continue
		if combat_instance.process_tick(delta):
			_sync_combat_instance_snapshots(combat_instance)
			changed = true
	return changed

# Future-facing support ownership:
# Only forces secondary live tables to conclude so the match backend can settle.
func force_finish_live_tables(round_number: int = -1) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for table_id in combat_instances.keys():
		var combat_instance = combat_instances.get(table_id, null)
		if combat_instance == null:
			continue
		if not combat_instance.matches_round(round_number):
			continue
		combat_instance.force_finish()
		_sync_combat_instance_snapshots(combat_instance)
		var result_entry: Dictionary = combat_instance.build_result_entry()
		if not str(result_entry.get("result_text", "")).is_empty():
			results.append(result_entry)
	return results

func is_player_in_live_table(player_id: String) -> bool:
	return player_table_map.has(player_id)

func get_live_combat_instance_for_player(player_id: String):
	return get_live_combat_instance(get_table_id_for_player(player_id))

func has_active_live_tables(round_number: int = -1) -> bool:
	for table_id in combat_instances.keys():
		var combat_instance = combat_instances.get(table_id, null)
		if combat_instance == null:
			continue
		if not combat_instance.matches_round(round_number):
			continue
		var phase_name: String = str(combat_instance.phase_name)
		if phase_name == "PREPARACAO" or phase_name == "BATALHA":
			return true
	return false

func are_live_tables_resolved(round_number: int = -1) -> bool:
	return not has_active_live_tables(round_number)

func count_live_table_phases(round_number: int = -1) -> Dictionary:
	var counts: Dictionary = {
		"PREPARACAO": 0,
		"BATALHA": 0,
		"RESULTADO": 0,
	}
	for table_id in combat_instances.keys():
		var combat_instance = combat_instances.get(table_id, null)
		if combat_instance == null:
			continue
		if not combat_instance.matches_round(round_number):
			continue
		var phase_name: String = str(combat_instance.phase_name)
		counts[phase_name] = int(counts.get(phase_name, 0)) + 1
	return counts

func _sync_combat_instance_snapshots(combat_instance) -> void:
	if combat_instance == null:
		return
	var player_a: MatchPlayerState = get_player(str(combat_instance.player_a_id))
	var player_b: MatchPlayerState = get_player(str(combat_instance.player_b_id))
	if player_a == null or player_b == null:
		return
	player_a.set_round_phase(str(combat_instance.phase_name))
	player_b.set_round_phase(str(combat_instance.phase_name))
	player_a.set_board_snapshot(combat_instance.get_observer_snapshot_for_player(player_a.player_id))
	player_b.set_board_snapshot(combat_instance.get_observer_snapshot_for_player(player_b.player_id))

func _create_live_table(
	pairing: Dictionary,
	player_a: MatchPlayerState,
	player_b: MatchPlayerState,
	round_number: int
) -> Dictionary:
	var lineup_a: Dictionary = _build_background_lineup(player_a, round_number)
	var lineup_b: Dictionary = _build_background_lineup(player_b, round_number)
	var snapshot_a: Dictionary = _build_table_snapshot(
		player_a,
		player_b,
		lineup_a,
		lineup_b,
		round_number,
		"PREPARACAO",
		""
	)

	return {
		"table_id": "round_%d_table_%d" % [
			round_number,
			int(pairing.get("table_index", player_a.slot_index + player_b.slot_index)),
		],
		"table_index": int(pairing.get("table_index", -1)),
		"round_number": round_number,
		"player_a_id": player_a.player_id,
		"player_b_id": player_b.player_id,
		"lineup_a": lineup_a,
		"lineup_b": lineup_b,
		"sim_units": _build_background_sim_units(snapshot_a),
		"phase": "PREPARACAO",
		"acting_team": GameEnums.TeamSide.PLAYER if ((player_a.slot_index + player_b.slot_index + round_number) % 2 == 0) else GameEnums.TeamSide.ENEMY,
		"player_turn_cursor": 0,
		"enemy_turn_cursor": 0,
		"action_time_accumulator": 0.0,
		"actions_taken": 0,
		"failsafe_triggered": false,
		"failsafe_reason": "",
		"applied_result": false,
		"winner_id": "",
		"loser_id": "",
		"damage": 0,
		"winner_survivors": -1,
		"loser_survivors": -1,
		"player_a_result_text": "",
		"player_b_result_text": "",
		"result_text": "",
		"result_time_remaining": LIVE_TABLE_RESULT_HOLD_SECONDS,
		"card_summary_a": "",
		"card_summary_b": "",
	}

func _build_combat_instance_from_live_table(
	table: Dictionary,
	player_a: MatchPlayerState,
	player_b: MatchPlayerState
):
	if table.is_empty() or player_a == null or player_b == null:
		return null

	var pairing: Dictionary = {
		"table_index": int(table.get("table_index", -1)),
	}
	var snapshot_a: Dictionary = _build_table_snapshot(
		player_a,
		player_b,
		table.get("lineup_a", {}),
		table.get("lineup_b", {}),
		int(table.get("round_number", 0)),
		str(table.get("phase", "PREPARACAO")),
		str(table.get("player_a_result_text", "")),
		str(table.get("card_summary_a", "")),
		[]
	)
	var combat_instance = CombatInstanceScript.new().setup_from_pairing(
		pairing,
		int(table.get("round_number", 0)),
		player_a,
		player_b,
		snapshot_a,
		LIVE_TABLE_RESULT_HOLD_SECONDS
	)
	combat_instance.owner_lobby_manager = self
	_sync_combat_instance_from_live_table(table)
	return combat_instance

func _sync_combat_instance_from_live_table(table: Dictionary) -> void:
	var table_id: String = str(table.get("table_id", ""))
	if table_id.is_empty() or not combat_instances.has(table_id):
		return
	var combat_instance = combat_instances.get(table_id, null)
	if combat_instance == null:
		return
	_sync_combat_instance_snapshots(combat_instance)

func _update_live_table(table: Dictionary, delta: float, observed_player_id: String) -> bool:
	if table.is_empty():
		return false

	var phase_name: String = str(table.get("phase", "PREPARACAO"))
	if phase_name == "PREPARACAO":
		return false
	if phase_name == "RESULTADO":
		var remaining_time: float = maxf(0.0, float(table.get("result_time_remaining", LIVE_TABLE_RESULT_HOLD_SECONDS)) - delta)
		if is_equal_approx(remaining_time, float(table.get("result_time_remaining", LIVE_TABLE_RESULT_HOLD_SECONDS))):
			return false
		table["result_time_remaining"] = remaining_time
		_sync_combat_instance_from_live_table(table)
		return true

	var changed: bool = false
	var observed_table: bool = _live_table_contains_player(table, observed_player_id)
	var step_seconds: float = LIVE_TABLE_OBSERVED_ACTION_STEP_SECONDS if observed_table else LIVE_TABLE_ACTION_STEP_SECONDS
	var accumulator: float = float(table.get("action_time_accumulator", 0.0)) + delta
	while accumulator >= step_seconds and str(table.get("phase", "PREPARACAO")) == "BATALHA":
		accumulator -= step_seconds
		if _live_table_combat_finished(table):
			break
		if not _advance_live_table_action(table):
			break
		changed = true
		if _live_table_combat_finished(table):
			break
	table["action_time_accumulator"] = accumulator

	if str(table.get("phase", "PREPARACAO")) == "BATALHA" and _live_table_combat_finished(table):
		_finalize_live_table_result(table)
		changed = true
	elif changed:
		_sync_live_table_snapshots(table)
	return changed

func _start_live_table_battle(table: Dictionary) -> void:
	if table.is_empty():
		return
	if str(table.get("phase", "PREPARACAO")) != "PREPARACAO":
		return

	var player_a: MatchPlayerState = get_player(str(table.get("player_a_id", "")))
	var player_b: MatchPlayerState = get_player(str(table.get("player_b_id", "")))
	var sim_units: Array[Dictionary] = table.get("sim_units", [])
	table["card_summary_a"] = _apply_live_table_cards_to_team(sim_units, GameEnums.TeamSide.PLAYER, player_a)
	table["card_summary_b"] = _apply_live_table_cards_to_team(sim_units, GameEnums.TeamSide.ENEMY, player_b)
	table["phase"] = "BATALHA"
	table["action_time_accumulator"] = 0.0
	table["actions_taken"] = 0
	table["result_text"] = ""
	table["failsafe_triggered"] = false
	table["failsafe_reason"] = ""
	_sync_combat_instance_from_live_table(table)
	var combat_instance = combat_instances.get(str(table.get("table_id", "")), null)
	if combat_instance != null:
		combat_instance.begin_battle()
	print("LIVE_TABLE battle_started: %s | round=%d" % [
		str(table.get("table_id", "")),
		int(table.get("round_number", 0)),
	])
	_sync_live_table_snapshots(table)

func _advance_live_table_action(table: Dictionary) -> bool:
	if table.is_empty():
		return false
	var sim_units: Array[Dictionary] = table.get("sim_units", [])
	if sim_units.is_empty():
		return false
	if _live_table_combat_finished(table):
		return false

	var acting_team: int = int(table.get("acting_team", GameEnums.TeamSide.PLAYER))
	var actor: Dictionary = _pop_live_table_actor(table, acting_team)
	if actor.is_empty():
		acting_team = _opposite_team(acting_team)
		actor = _pop_live_table_actor(table, acting_team)
		if actor.is_empty():
			return false

	var table_id: String = str(table.get("table_id", ""))
	var combat_instance = combat_instances.get(table_id, null)
	var actor_name: String = str(actor.get("display_name", "Unidade"))
	var from_coord: Vector2i = actor.get("coord", Vector2i(-1, -1))
	_background_take_action(actor, sim_units, table_id)
	if combat_instance != null:
		combat_instance.push_event("unit_action", {
			"actor": actor_name,
			"team_side": int(actor.get("team_side", GameEnums.TeamSide.PLAYER)),
			"from_coord": from_coord,
			"to_coord": actor.get("coord", Vector2i(-1, -1)),
		})
	table["acting_team"] = _opposite_team(acting_team)
	table["actions_taken"] = int(table.get("actions_taken", 0)) + 1
	_sync_combat_instance_from_live_table(table)
	_sync_live_table_snapshots(table)
	return true

func _pop_live_table_actor(table: Dictionary, team_side: int) -> Dictionary:
	var sim_units: Array[Dictionary] = table.get("sim_units", [])
	var turn_order: Array[Dictionary] = _background_team_turn_order(sim_units, team_side)
	if turn_order.is_empty():
		return {}

	var cursor_key: String = "player_turn_cursor" if team_side == GameEnums.TeamSide.PLAYER else "enemy_turn_cursor"
	var cursor: int = int(table.get(cursor_key, 0))
	if cursor < 0:
		cursor = 0
	if cursor >= turn_order.size():
		cursor = 0

	var actor: Dictionary = turn_order[cursor]
	cursor += 1
	if cursor >= turn_order.size():
		cursor = 0
	table[cursor_key] = cursor
	return actor

func _live_table_combat_finished(table: Dictionary) -> bool:
	if table.is_empty():
		return true
	var sim_units: Array[Dictionary] = table.get("sim_units", [])
	if sim_units.is_empty():
		return true
	if not _background_team_alive(sim_units, GameEnums.TeamSide.PLAYER):
		return true
	if not _background_team_alive(sim_units, GameEnums.TeamSide.ENEMY):
		return true
	return int(table.get("actions_taken", 0)) >= BACKGROUND_COMBAT_MAX_ACTIONS

func _finalize_live_table_result(table: Dictionary) -> void:
	if table.is_empty():
		return
	if bool(table.get("applied_result", false)):
		return

	var player_a: MatchPlayerState = get_player(str(table.get("player_a_id", "")))
	var player_b: MatchPlayerState = get_player(str(table.get("player_b_id", "")))
	if player_a == null or player_b == null:
		return

	var sim_units: Array[Dictionary] = table.get("sim_units", [])
	var reached_action_cap: bool = (
		int(table.get("actions_taken", 0)) >= BACKGROUND_COMBAT_MAX_ACTIONS
		and _background_team_alive(sim_units, GameEnums.TeamSide.PLAYER)
		and _background_team_alive(sim_units, GameEnums.TeamSide.ENEMY)
	)
	var winner_team: int = _background_winner_team(sim_units)
	var winner_id: String = ""
	var loser_id: String = ""
	var damage: int = 0
	var winner_survivors: int = -1
	var loser_survivors: int = -1
	var player_a_result_text: String = "Empate ao vivo contra %s" % player_b.display_name
	var player_b_result_text: String = "Empate ao vivo contra %s" % player_a.display_name

	if winner_team >= 0:
		winner_id = player_a.player_id if winner_team == GameEnums.TeamSide.PLAYER else player_b.player_id
		loser_id = player_b.player_id if winner_team == GameEnums.TeamSide.PLAYER else player_a.player_id
		winner_survivors = _count_background_survivors(sim_units, winner_team)
		loser_survivors = _count_background_survivors(sim_units, _opposite_team(winner_team))
		damage = BattleConfigScript.calculate_post_combat_damage({
			"winner_id": winner_id,
			"loser_id": loser_id,
		}, int(table.get("round_number", 0)), {
			"survivors": winner_survivors,
		})
		var resolution: Dictionary = apply_post_combat_damage(winner_id, loser_id, damage, int(table.get("round_number", 0)))
		damage = int(resolution.get("damage", damage))

		if winner_team == GameEnums.TeamSide.PLAYER:
			player_a_result_text = "%s venceu %s ao vivo e causou %d de dano" % [
				player_a.display_name,
				player_b.display_name,
				damage,
			]
			player_b_result_text = "%s perdeu para %s ao vivo e sofreu %d de dano" % [
				player_b.display_name,
				player_a.display_name,
				damage,
			]
		else:
			player_a_result_text = "%s perdeu para %s ao vivo e sofreu %d de dano" % [
				player_a.display_name,
				player_b.display_name,
				damage,
			]
			player_b_result_text = "%s venceu %s ao vivo e causou %d de dano" % [
				player_b.display_name,
				player_a.display_name,
				damage,
			]

	player_a.last_round_result_text = player_a_result_text
	player_b.last_round_result_text = player_b_result_text
	player_a.eliminated = player_a.current_life <= 0
	player_b.eliminated = player_b.current_life <= 0
	table["phase"] = "RESULTADO"
	table["applied_result"] = true
	table["failsafe_triggered"] = reached_action_cap and winner_team >= -1
	table["failsafe_reason"] = "background_action_cap" if reached_action_cap else ""
	table["winner_id"] = winner_id
	table["loser_id"] = loser_id
	table["damage"] = damage
	table["winner_survivors"] = winner_survivors
	table["loser_survivors"] = loser_survivors
	table["player_a_result_text"] = player_a_result_text
	table["player_b_result_text"] = player_b_result_text
	table["result_text"] = player_a_result_text
	table["result_time_remaining"] = LIVE_TABLE_RESULT_HOLD_SECONDS
	player_a.record_round_result(int(table.get("round_number", 0)), player_a_result_text, winner_id == player_a.player_id, damage if loser_id == player_a.player_id else 0)
	player_b.record_round_result(int(table.get("round_number", 0)), player_b_result_text, winner_id == player_b.player_id, damage if loser_id == player_b.player_id else 0)
	player_a.set_round_phase("RESULTADO")
	player_b.set_round_phase("RESULTADO")
	_sync_combat_instance_from_live_table(table)
	var combat_instance = combat_instances.get(str(table.get("table_id", "")), null)
	if combat_instance != null:
		combat_instance.begin_result(LIVE_TABLE_RESULT_HOLD_SECONDS)
		if reached_action_cap:
			combat_instance.push_event("failsafe_triggered", {
				"reason": "background_action_cap",
				"actions_taken": int(table.get("actions_taken", 0)),
			})
		combat_instance.push_event("battle_result", {
			"winner_id": winner_id,
			"loser_id": loser_id,
			"damage": damage,
			"result_text": player_a_result_text,
		})
	if reached_action_cap:
		print("FAILSAFE [LIVE_TABLE %s]: combate encerrado no limite de acoes=%d" % [
			str(table.get("table_id", "")),
			int(table.get("actions_taken", 0)),
		])
	print("LIVE_TABLE result: %s | vencedor=%s dano=%d" % [
		str(table.get("table_id", "")),
		winner_id if not winner_id.is_empty() else "EMPATE",
		damage,
	])
	_sync_live_table_snapshots(table)

func _sync_live_table_snapshots(table: Dictionary) -> void:
	if table.is_empty():
		return

	var player_a: MatchPlayerState = get_player(str(table.get("player_a_id", "")))
	var player_b: MatchPlayerState = get_player(str(table.get("player_b_id", "")))
	if player_a == null or player_b == null:
		return

	var phase_name: String = str(table.get("phase", "PREPARACAO"))
	player_a.set_round_phase(phase_name)
	player_b.set_round_phase(phase_name)
	var combat_instance = combat_instances.get(str(table.get("table_id", "")), null)
	var recent_events: Array[Dictionary] = combat_instance.get_recent_events() if combat_instance != null else []
	if phase_name == "PREPARACAO":
		player_a.set_board_snapshot(_build_table_snapshot(
			player_a,
			player_b,
			table.get("lineup_a", {}),
			table.get("lineup_b", {}),
			int(table.get("round_number", 0)),
			phase_name,
			str(table.get("player_a_result_text", "")),
			str(table.get("card_summary_a", "")),
			recent_events
		))
		player_b.set_board_snapshot(_build_table_snapshot(
			player_b,
			player_a,
			table.get("lineup_b", {}),
			table.get("lineup_a", {}),
			int(table.get("round_number", 0)),
			phase_name,
			str(table.get("player_b_result_text", "")),
			str(table.get("card_summary_b", "")),
			recent_events
		))
		return

	var sim_units: Array[Dictionary] = table.get("sim_units", [])
	player_a.set_board_snapshot(_build_snapshot_from_sim_units(
		player_a,
		player_b,
		sim_units,
		GameEnums.TeamSide.PLAYER,
		int(table.get("round_number", 0)),
		phase_name,
		str(table.get("player_a_result_text", "")),
		str(table.get("card_summary_a", "")),
		recent_events
	))
	player_b.set_board_snapshot(_build_snapshot_from_sim_units(
		player_b,
		player_a,
		sim_units,
		GameEnums.TeamSide.ENEMY,
		int(table.get("round_number", 0)),
		phase_name,
		str(table.get("player_b_result_text", "")),
		str(table.get("card_summary_b", "")),
		recent_events
	))

func _live_table_contains_player(table: Dictionary, player_id: String) -> bool:
	if player_id.is_empty():
		return false
	return str(table.get("player_a_id", "")) == player_id or str(table.get("player_b_id", "")) == player_id

func _apply_live_table_cards_to_team(sim_units: Array[Dictionary], team_side: int, owner_state: MatchPlayerState) -> String:
	if owner_state == null or sim_units.is_empty():
		return ""

	var applied_lines: Array[String] = []
	for card_path in owner_state.get_owned_card_paths():
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		var effect_text: String = _apply_live_table_card_effect(sim_units, team_side, owner_state, card_data)
		if not effect_text.is_empty():
			applied_lines.append(effect_text)
	return _join_strings(applied_lines, " | ")

func _apply_live_table_card_effect(
	sim_units: Array[Dictionary],
	team_side: int,
	owner_state: MatchPlayerState,
	card_data: CardData
) -> String:
	if card_data == null:
		return ""

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			if owner_state != null and card_data.global_life_heal > 0:
				var previous_life: int = owner_state.current_life
				owner_state.current_life = mini(BattleConfigScript.GLOBAL_LIFE, owner_state.current_life + card_data.global_life_heal)
				if owner_state.current_life > previous_life:
					return "%s curou %+d PV" % [card_data.display_name, owner_state.current_life - previous_life]
			return ""
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			var attack_target: Dictionary = _pick_live_table_ally_target(sim_units, team_side, false)
			if attack_target.is_empty():
				return ""
			attack_target["physical_attack"] = int(attack_target.get("physical_attack", 0)) + card_data.physical_attack_bonus
			attack_target["magic_attack"] = int(attack_target.get("magic_attack", 0)) + card_data.magic_attack_bonus
			return "%s em %s" % [card_data.display_name, str(attack_target.get("display_name", "aliado"))]
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			var magic_target: Dictionary = _pick_live_table_ally_target(sim_units, team_side, true)
			if magic_target.is_empty():
				return ""
			var base_magic: int = int(magic_target.get("magic_attack", 0))
			magic_target["magic_attack"] = maxi(base_magic, int(round(float(base_magic) * card_data.magic_attack_multiplier)))
			return "%s em %s" % [card_data.display_name, str(magic_target.get("display_name", "aliado"))]
		GameEnums.SupportCardEffectType.START_STEALTH:
			var stealth_target: Dictionary = _pick_live_table_ally_target(sim_units, team_side, false)
			if stealth_target.is_empty():
				return ""
			stealth_target["initiative_bonus"] = int(stealth_target.get("initiative_bonus", 0)) + 18
			stealth_target["physical_defense"] = int(stealth_target.get("physical_defense", 0)) + 2
			stealth_target["magic_defense"] = int(stealth_target.get("magic_defense", 0)) + 2
			return "%s acelerou %s" % [card_data.display_name, str(stealth_target.get("display_name", "aliado"))]
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			var affected_units: int = 0
			for unit_entry in sim_units:
				if not bool(unit_entry.get("alive", false)):
					continue
				if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) == team_side:
					continue
				var base_physical: int = int(unit_entry.get("physical_attack", 0))
				unit_entry["physical_attack"] = maxi(0, int(round(float(base_physical) * (1.0 - (card_data.physical_miss_chance * 0.45)))))
				affected_units += 1
			if affected_units > 0:
				return "%s enfraqueceu %d inimigos" % [card_data.display_name, affected_units]
			return ""
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			var master_target: Dictionary = _pick_live_table_master(sim_units, team_side)
			if master_target.is_empty():
				return ""
			master_target["magic_attack"] = int(master_target.get("magic_attack", 0)) + 2
			master_target["current_hp"] = int(master_target.get("current_hp", 0)) + 14
			master_target["max_hp"] = int(master_target.get("max_hp", 0)) + 14
			return "%s reforcou o Mestre" % card_data.display_name
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			var trap_target: Dictionary = _pick_live_table_enemy_trap_target(sim_units, team_side)
			if trap_target.is_empty():
				return ""
			trap_target["skip_turns_remaining"] = maxi(int(trap_target.get("skip_turns_remaining", 0)), maxi(1, card_data.stun_turns))
			return "%s travou %s" % [card_data.display_name, str(trap_target.get("display_name", "alvo"))]
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			var defense_target: Dictionary = _pick_live_table_ally_target(sim_units, team_side, false)
			if defense_target.is_empty():
				return ""
			var base_defense: int = int(defense_target.get("physical_defense", 0))
			defense_target["physical_defense"] = base_defense + int(ceil(float(base_defense) * (card_data.physical_defense_multiplier - 1.0)))
			return "%s protegeu %s" % [card_data.display_name, str(defense_target.get("display_name", "aliado"))]
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			var spear_target: Dictionary = _pick_live_table_ally_target(sim_units, team_side, false)
			if spear_target.is_empty():
				return ""
			var base_attack: int = int(spear_target.get("physical_attack", 0))
			spear_target["physical_attack"] = base_attack + int(ceil(float(base_attack) * (card_data.physical_attack_multiplier - 1.0)))
			spear_target["attack_range"] = int(spear_target.get("attack_range", 1)) + maxi(0, card_data.attack_range_bonus)
			return "%s fortaleceu %s" % [card_data.display_name, str(spear_target.get("display_name", "aliado"))]
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			var swirl_target: Dictionary = _pick_live_table_enemy_trap_target(sim_units, team_side)
			if swirl_target.is_empty():
				return ""
			swirl_target["initiative_bonus"] = int(swirl_target.get("initiative_bonus", 0)) - 14
			return "%s baguncou o posicionamento de %s" % [card_data.display_name, str(swirl_target.get("display_name", "alvo"))]
		_:
			return ""

func _pick_live_table_ally_target(sim_units: Array[Dictionary], team_side: int, prefer_magic: bool) -> Dictionary:
	var best_target: Dictionary = {}
	var best_score: int = -100000
	for unit_entry in sim_units:
		if not bool(unit_entry.get("alive", false)):
			continue
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) != team_side:
			continue
		var score: int = 0
		score += int(unit_entry.get("magic_attack", 0)) * 6 if prefer_magic else int(unit_entry.get("physical_attack", 0)) * 6
		score += int(unit_entry.get("magic_attack", 0)) * 2
		score += int(unit_entry.get("physical_attack", 0)) * 2
		score += int(unit_entry.get("current_hp", 0))
		if bool(unit_entry.get("is_master", false)):
			score -= 12
		if best_target.is_empty() or score > best_score:
			best_target = unit_entry
			best_score = score
	return best_target

func _pick_live_table_master(sim_units: Array[Dictionary], team_side: int) -> Dictionary:
	for unit_entry in sim_units:
		if not bool(unit_entry.get("alive", false)):
			continue
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) != team_side:
			continue
		if bool(unit_entry.get("is_master", false)):
			return unit_entry
	return {}

func _pick_live_table_enemy_trap_target(sim_units: Array[Dictionary], team_side: int) -> Dictionary:
	var best_target: Dictionary = {}
	var best_score: int = 100000
	for unit_entry in sim_units:
		if not bool(unit_entry.get("alive", false)):
			continue
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) == team_side:
			continue
		var coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
		var score: int = abs(coord.x - 3) * 10
		score += coord.y if team_side == GameEnums.TeamSide.PLAYER else (BattleConfigScript.BOARD_HEIGHT - 1 - coord.y)
		if bool(unit_entry.get("is_master", false)):
			score += 8
		if best_target.is_empty() or score < best_score:
			best_target = unit_entry
			best_score = score
	return best_target

func build_remote_round_snapshots(round_number: int, skipped_player_ids: Array[String] = []) -> void:
	var processed_ids: Dictionary = {}

	for player_id in player_order:
		if processed_ids.has(player_id):
			continue

		var player_state: MatchPlayerState = get_player(player_id)
		if player_state == null:
			continue
		if player_state.current_life <= 0:
			player_state.eliminated = true
			if not skipped_player_ids.has(player_id):
				player_state.set_board_snapshot(_build_eliminated_snapshot(player_state, round_number))
			processed_ids[player_id] = true
			continue

		var opponent_id: String = player_state.opponent_id_this_round
		var opponent_state: MatchPlayerState = get_player(opponent_id)
		if opponent_state == null or opponent_state.current_life <= 0:
			if not skipped_player_ids.has(player_id):
				player_state.set_board_snapshot(_build_solo_board_snapshot(player_state, round_number))
			processed_ids[player_id] = true
			continue

		var lineup_a: Dictionary = _build_background_lineup(player_state, round_number)
		var lineup_b: Dictionary = _build_background_lineup(opponent_state, round_number)
		if not skipped_player_ids.has(player_id):
			player_state.set_board_snapshot(_build_table_snapshot(
				player_state,
				opponent_state,
				lineup_a,
				lineup_b,
				round_number,
				"PREPARACAO",
				""
			))
		if not skipped_player_ids.has(opponent_id):
			opponent_state.set_board_snapshot(_build_table_snapshot(
				opponent_state,
				player_state,
				lineup_b,
				lineup_a,
				round_number,
				"PREPARACAO",
				""
			))

		processed_ids[player_id] = true
		processed_ids[opponent_id] = true

func resolve_background_pairings(
	pairings: Array[Dictionary],
	round_number: int,
	excluded_player_ids: Array[String] = []
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for pairing in pairings:
		var player_a_id: String = str(pairing.get("player_a", ""))
		var player_b_id: String = str(pairing.get("player_b", ""))
		if excluded_player_ids.has(player_a_id) or excluded_player_ids.has(player_b_id):
			continue

		var player_a: MatchPlayerState = get_player(player_a_id)
		var player_b: MatchPlayerState = get_player(player_b_id)
		if player_a == null or player_b == null:
			continue
		if player_a.eliminated or player_b.eliminated:
			continue

		var snapshot_a: Dictionary = player_a.get_board_snapshot()
		if snapshot_a.is_empty():
			var lineup_a: Dictionary = _build_background_lineup(player_a, round_number)
			var lineup_b: Dictionary = _build_background_lineup(player_b, round_number)
			snapshot_a = _build_table_snapshot(player_a, player_b, lineup_a, lineup_b, round_number, "PREPARACAO", "")
			player_a.set_board_snapshot(snapshot_a)
			player_b.set_board_snapshot(_build_table_snapshot(player_b, player_a, lineup_b, lineup_a, round_number, "PREPARACAO", ""))

		var result: Dictionary = _resolve_background_match(player_a, player_b, snapshot_a, round_number)
		_apply_background_match_result(player_a, player_b, result)
		results.append(result)

	return results

func _apply_background_match_result(
	player_a: MatchPlayerState,
	player_b: MatchPlayerState,
	result: Dictionary
) -> void:
	if player_a == null or player_b == null:
		return

	var loser_id: String = str(result.get("loser_id", ""))
	var damage: int = int(result.get("damage", 0))
	var winner_state: MatchPlayerState = get_player(str(result.get("winner_id", "")))
	var loser_state: MatchPlayerState = null
	if not loser_id.is_empty():
		loser_state = get_player(loser_id)
	apply_post_combat_damage(
		str(result.get("winner_id", "")),
		loser_id,
		damage,
		int(result.get("round_number", 0)),
		true
	)

	player_a.eliminated = player_a.current_life <= 0
	player_b.eliminated = player_b.current_life <= 0
	player_a.last_round_result_text = str(result.get("player_a_result_text", ""))
	player_b.last_round_result_text = str(result.get("player_b_result_text", ""))

	var snapshot_a: Dictionary = result.get("snapshot_a", player_a.get_board_snapshot())
	var snapshot_b: Dictionary = result.get("snapshot_b", player_b.get_board_snapshot())
	snapshot_a["life"] = player_a.current_life
	snapshot_b["life"] = player_b.current_life
	player_a.set_board_snapshot(snapshot_a)
	player_b.set_board_snapshot(snapshot_b)

func _build_solo_board_snapshot(player_state: MatchPlayerState, round_number: int) -> Dictionary:
	var lineup: Dictionary = _build_background_lineup(player_state, round_number)
	return _build_table_snapshot(player_state, null, lineup, {}, round_number, "PREPARACAO", "")

func _build_background_lineup(player_state: MatchPlayerState, round_number: int) -> Dictionary:
	if player_state == null:
		return {}

	var deck_data: DeckData = _load_deck_data(player_state.deck_path)
	if deck_data == null:
		return {
			"player_id": player_state.player_id,
			"player_name": player_state.display_name,
			"gold": 0,
			"gold_budget": 0,
			"units": [],
			"unit_count": 0,
			"non_master_count": 0,
			"power_rating": 0,
			"master_name": "Sem mestre",
		}

	var available_gold: int = maxi(0, player_state.current_gold)
	var effective_gold: int = _effective_gold_budget(available_gold, round_number)
	var field_limit: int = _effective_field_limit(BattleConfigScript.MAX_FIELD_UNITS, round_number)
	var units: Array[Dictionary] = []
	var total_power: int = _estimate_owned_cards_power_bonus(player_state.get_owned_card_paths())
	var planner_current_units: Array[Dictionary] = []
	var candidate_entries: Array[Dictionary] = []
	var total_candidate_power: int = 0
	var valid_candidate_count: int = 0

	var master_data: UnitData = _load_unit_data(deck_data.master_data_path)
	if master_data != null:
		var master_coord := Vector2i(3, BattleConfigScript.BOARD_HEIGHT - 1)
		units.append(_build_snapshot_unit_entry(
			master_data,
			deck_data.master_data_path,
			master_coord,
			true,
			GameEnums.TeamSide.PLAYER
		))
		planner_current_units.append({
			"unit_data": master_data,
			"unit_id": master_data.id,
			"display_name": master_data.display_name,
			"race": master_data.race,
			"class_type": master_data.class_type,
			"cost": master_data.get_effective_cost(),
			"coord": master_coord,
			"team_side": GameEnums.TeamSide.PLAYER,
			"is_master": true,
			"attack_range": master_data.attack_range,
			"physical_attack": master_data.physical_attack,
			"magic_attack": master_data.magic_attack,
			"physical_defense": master_data.physical_defense,
			"magic_defense": master_data.magic_defense,
			"max_hp": master_data.max_hp,
			"current_hp": master_data.max_hp,
		})
		total_power += _estimate_unit_power(master_data, true, player_state.slot_index, round_number)

	for unit_path_variant in deck_data.unit_pool_paths:
		var unit_path: String = str(unit_path_variant)
		if unit_path.is_empty():
			continue
		var unit_data: UnitData = _load_unit_data(unit_path)
		if unit_data == null:
			continue
		candidate_entries.append({
			"slot_index": -1,
			"unit_data": unit_data,
			"unit_path": unit_path,
		})
		total_candidate_power += _estimate_unit_power(unit_data, false, player_state.slot_index, round_number)
		valid_candidate_count += 1

	var deck_average_power: float = 0.0
	if valid_candidate_count > 0:
		deck_average_power = float(total_candidate_power) / float(valid_candidate_count)

	var purchase_result: Dictionary = bot_prep_planner.build_purchase_plan(
		candidate_entries,
		planner_current_units,
		effective_gold,
		0,
		field_limit,
		GameEnums.TeamSide.PLAYER,
		master_data,
		deck_average_power,
		player_state.player_id
	)
	var budget_gold_left: int = int(purchase_result.get("gold_left", effective_gold))
	var spent_gold: int = maxi(0, effective_gold - budget_gold_left)
	player_state.set_current_gold_capped(available_gold - spent_gold, "bot_prep_remaining", false)
	var purchase_orders: Array[Dictionary] = purchase_result.get("orders", [])
	for candidate in purchase_orders:
		var unit_data: UnitData = candidate.get("unit_data", null)
		var unit_path: String = str(candidate.get("unit_path", ""))
		if unit_data == null:
			continue
		var target_coord: Vector2i = candidate.get("coord", Vector2i(-1, -1))
		if not _is_valid_snapshot_coord(target_coord):
			continue

		units.append(_build_snapshot_unit_entry(
			unit_data,
			unit_path,
			target_coord,
			false,
			GameEnums.TeamSide.PLAYER
		))
		total_power += _estimate_unit_power(unit_data, false, player_state.slot_index, round_number)

	_apply_background_deck_passives(units, player_state.current_gold)
	return {
		"player_id": player_state.player_id,
		"player_name": player_state.display_name,
		"gold": player_state.current_gold,
		"gold_budget": effective_gold,
		"units": units,
		"unit_count": units.size(),
		"non_master_count": purchase_orders.size(),
		"power_rating": total_power,
		"master_name": str(units[0].get("display_name", "Mestre")) if not units.is_empty() else "Mestre",
	}

func _apply_background_deck_passives(units: Array[Dictionary], saved_gold: int = 0) -> void:
	var has_thrax_master: bool = false
	for unit_entry in units:
		if str(unit_entry.get("unit_id", "")) == "thrax_master":
			has_thrax_master = true
			break
	if not has_thrax_master or saved_gold <= 0:
		return

	for unit_entry in units:
		var base_attack: int = int(unit_entry.get("physical_attack", 0))
		if base_attack <= 0:
			continue
		var bonus_attack: int = int(round(float(base_attack) * float(saved_gold) * 0.01))
		if bonus_attack <= 0:
			bonus_attack = 1
		unit_entry["physical_attack"] = base_attack + bonus_attack

func _apply_round_reward_cards(winner_state: MatchPlayerState, loser_state: MatchPlayerState, damage: int) -> void:
	if winner_state == null:
		return

	var bonus_gold: int = 0
	var tribute_amount: int = 0
	for card_path in winner_state.get_owned_card_paths():
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		match card_data.support_effect_type:
			GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
				bonus_gold = maxi(bonus_gold, card_data.bonus_next_round_gold)
			GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
				tribute_amount = maxi(tribute_amount, card_data.tribute_steal_amount)

	if bonus_gold > 0:
		winner_state.add_bonus_next_round_gold(bonus_gold)

	if tribute_amount > 0 and damage > 0 and loser_state != null and loser_state.bonus_next_round_gold > 0:
		var stolen: int = mini(loser_state.bonus_next_round_gold, tribute_amount)
		loser_state.bonus_next_round_gold -= stolen
		winner_state.add_bonus_next_round_gold(stolen)

func _build_table_snapshot(
	viewer_state: MatchPlayerState,
	opponent_state: MatchPlayerState,
	viewer_lineup: Dictionary,
	opponent_lineup: Dictionary,
	round_number: int,
	phase_name: String,
	result_text: String,
	card_summary: String = "",
	recent_events: Array[Dictionary] = []
) -> Dictionary:
	var units: Array[Dictionary] = []
	var viewer_units: Array = viewer_lineup.get("units", [])
	for unit_variant in viewer_units:
		var unit_entry: Dictionary = unit_variant
		units.append(unit_entry.duplicate(true))

	var opponent_units: Array = opponent_lineup.get("units", [])
	for unit_variant in opponent_units:
		var unit_entry: Dictionary = unit_variant
		units.append(_clone_unit_entry_for_view(unit_entry, GameEnums.TeamSide.ENEMY, true))

	return {
		"player_id": viewer_state.player_id if viewer_state != null else "",
		"player_name": viewer_state.display_name if viewer_state != null else "Jogador",
		"opponent_id": opponent_state.player_id if opponent_state != null else "",
		"opponent_name": opponent_state.display_name if opponent_state != null else "Sem oponente",
		"round_number": round_number,
		"phase": phase_name,
		"life": viewer_state.current_life if viewer_state != null else 0,
		"gold": int(viewer_lineup.get("gold", 0)),
		"gold_budget": int(viewer_lineup.get("gold_budget", 0)),
		"units": units,
		"unit_count": units.size(),
		"non_master_count": int(viewer_lineup.get("non_master_count", 0)),
		"enemy_unit_count": int(opponent_lineup.get("unit_count", 0)),
		"power_rating": int(viewer_lineup.get("power_rating", 0)),
		"master_name": str(viewer_lineup.get("master_name", "Sem mestre")),
		"opponent_master_name": str(opponent_lineup.get("master_name", "Sem mestre")),
		"owned_card_count": viewer_state.get_owned_card_paths().size() if viewer_state != null else 0,
		"owned_card_names": _card_names_from_paths(viewer_state.get_owned_card_paths()) if viewer_state != null else [],
		"table_id": viewer_state.current_table_id if viewer_state != null else "",
		"streak": viewer_state.streak_value if viewer_state != null else 0,
		"player_level": viewer_state.player_level if viewer_state != null else 1,
		"card_summary": card_summary,
		"recent_events": recent_events,
		"summary": _build_snapshot_summary(units),
		"result_text": result_text,
	}

func _build_empty_snapshot(player_state: MatchPlayerState, round_number: int, phase_name: String) -> Dictionary:
	var player_name: String = player_state.display_name if player_state != null else "Jogador"
	var player_id: String = player_state.player_id if player_state != null else ""
	var life_value: int = player_state.current_life if player_state != null else 0
	return {
		"player_id": player_id,
		"player_name": player_name,
		"opponent_id": "",
		"opponent_name": "Sem oponente",
		"round_number": round_number,
		"phase": phase_name,
		"life": life_value,
		"gold": player_state.current_gold if player_state != null else 0,
		"gold_budget": player_state.current_gold if player_state != null else 0,
		"units": [],
		"unit_count": 0,
		"non_master_count": 0,
		"enemy_unit_count": 0,
		"power_rating": 0,
		"master_name": "Sem mestre",
		"opponent_master_name": "Sem mestre",
		"owned_card_count": 0,
		"owned_card_names": [],
		"table_id": player_state.current_table_id if player_state != null else "",
		"streak": player_state.streak_value if player_state != null else 0,
		"player_level": player_state.player_level if player_state != null else 1,
		"card_summary": "",
		"recent_events": [],
		"summary": "Sem unidades em campo.",
		"result_text": "",
	}

func _build_eliminated_snapshot(player_state: MatchPlayerState, round_number: int) -> Dictionary:
	var snapshot: Dictionary = _build_empty_snapshot(player_state, round_number, "ELIMINADO")
	snapshot["summary"] = "Jogador eliminado do lobby."
	snapshot["result_text"] = "KO"
	return snapshot

func _build_snapshot_unit_entry(
	unit_data: UnitData,
	unit_path: String,
	coord: Vector2i,
	is_master: bool,
	team_side: int
) -> Dictionary:
	return {
		"unit_id": unit_data.id,
		"unit_path": unit_path,
		"display_name": unit_data.display_name,
		"coord": coord,
		"team_side": team_side,
		"is_master": is_master,
		"class_label": _resolve_unit_class_label(unit_data),
		"race_name": _race_name(unit_data.race),
		"cost": unit_data.get_effective_cost(),
		"current_hp": unit_data.max_hp,
		"max_hp": unit_data.max_hp,
		"current_mana": 0,
		"mana_max": unit_data.mana_max,
		"physical_attack": unit_data.physical_attack,
		"magic_attack": unit_data.magic_attack,
		"physical_defense": unit_data.physical_defense,
		"magic_defense": unit_data.magic_defense,
		"attack_range": unit_data.attack_range,
		"crit_chance": unit_data.crit_chance,
		"mana_gain_on_attack": unit_data.mana_gain_on_attack,
		"mana_gain_on_hit": unit_data.mana_gain_on_hit,
	}

func _clone_unit_entry_for_view(unit_entry: Dictionary, relative_team_side: int, mirror_coord: bool) -> Dictionary:
	var cloned_entry: Dictionary = unit_entry.duplicate(true)
	if mirror_coord:
		var source_coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
		cloned_entry["coord"] = _mirror_coord_for_opponent_view(source_coord)
	cloned_entry["team_side"] = relative_team_side
	return cloned_entry

func _load_sorted_unit_candidates(deck_data: DeckData, player_seed: int, round_number: int) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	if deck_data == null:
		return units

	for unit_path in deck_data.unit_pool_paths:
		var unit_data: UnitData = _load_unit_data(unit_path)
		if unit_data != null:
			units.append({
				"unit_data": unit_data,
				"unit_path": unit_path,
			})

	units.sort_custom(_sort_unit_candidates.bind(player_seed, round_number))
	return units

func _sort_unit_candidates(a: Dictionary, b: Dictionary, player_seed: int, round_number: int) -> bool:
	var unit_a: UnitData = a.get("unit_data", null)
	var unit_b: UnitData = b.get("unit_data", null)
	if unit_a == null:
		return false
	if unit_b == null:
		return true

	var priority_a: int = _unit_priority(unit_a.class_type, round_number)
	var priority_b: int = _unit_priority(unit_b.class_type, round_number)
	if priority_a != priority_b:
		return priority_a < priority_b

	var effective_cost_a: int = unit_a.get_effective_cost()
	var effective_cost_b: int = unit_b.get_effective_cost()
	if round_number <= 2 and effective_cost_a != effective_cost_b:
		return effective_cost_a < effective_cost_b
	if effective_cost_a != effective_cost_b:
		return effective_cost_a > effective_cost_b

	var bias_a: int = _unit_sort_bias(unit_a.id, player_seed, round_number)
	var bias_b: int = _unit_sort_bias(unit_b.id, player_seed, round_number)
	if bias_a != bias_b:
		return bias_a < bias_b
	return unit_a.display_name < unit_b.display_name

func _unit_priority(class_type: int, round_number: int) -> int:
	if round_number <= 2:
		if class_type == GameEnums.ClassType.ATTACKER:
			return 0
		if class_type == GameEnums.ClassType.TANK:
			return 1
		if class_type == GameEnums.ClassType.SUPPORT:
			return 2
		if class_type == GameEnums.ClassType.STEALTH:
			return 3
		return 4

	if class_type == GameEnums.ClassType.TANK:
		return 0
	if class_type == GameEnums.ClassType.ATTACKER:
		return 1
	if class_type == GameEnums.ClassType.SUPPORT:
		return 2
	if class_type == GameEnums.ClassType.STEALTH:
		return 3
	return 4

func _unit_sort_bias(unit_id: String, player_seed: int, round_number: int) -> int:
	return abs(hash("%s|%d|%d" % [unit_id, player_seed, round_number])) % 17

func _choose_snapshot_coord(class_type: int, occupied_coords: Array[Vector2i], seed: int) -> Vector2i:
	var preferred_rows: Array[int] = _preferred_rows_for_class(class_type)
	var rotated_columns: Array[int] = _rotated_columns(seed)

	for row in preferred_rows:
		for column in rotated_columns:
			var coord := Vector2i(column, row)
			if not occupied_coords.has(coord):
				return coord

	for row in range(BattleConfigScript.BOARD_HEIGHT - BattleConfigScript.PLAYER_ROWS, BattleConfigScript.BOARD_HEIGHT):
		for column in rotated_columns:
			var fallback_coord := Vector2i(column, row)
			if not occupied_coords.has(fallback_coord):
				return fallback_coord

	return Vector2i(-1, -1)

func _preferred_rows_for_class(class_type: int) -> Array[int]:
	var frontline_row: int = BattleConfigScript.BOARD_HEIGHT - BattleConfigScript.PLAYER_ROWS
	var backline_row: int = BattleConfigScript.BOARD_HEIGHT - 1
	if class_type == GameEnums.ClassType.TANK:
		return [frontline_row, backline_row]
	if class_type == GameEnums.ClassType.SUPPORT or class_type == GameEnums.ClassType.SNIPER:
		return [backline_row, frontline_row]
	return [frontline_row, backline_row]

func _rotated_columns(seed: int) -> Array[int]:
	var rotated: Array[int] = CENTER_COLUMNS.duplicate()
	if rotated.is_empty():
		return rotated
	var offset: int = posmod(seed, rotated.size())
	for _step in range(offset):
		var first_value: int = rotated[0]
		rotated.remove_at(0)
		rotated.append(first_value)
	return rotated

func _is_valid_snapshot_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < BattleConfigScript.BOARD_WIDTH and coord.y >= 0 and coord.y < BattleConfigScript.BOARD_HEIGHT

func _estimate_unit_power(unit_data: UnitData, is_master: bool, player_seed: int, round_number: int) -> int:
	if unit_data == null:
		return 0

	var power: int = 0
	power += unit_data.max_hp * 2
	power += unit_data.physical_attack * 5
	power += unit_data.magic_attack * 5
	power += unit_data.physical_defense * 4
	power += unit_data.magic_defense * 4
	power += unit_data.attack_range * 3
	power += int(round(unit_data.crit_chance * 100.0))
	power += unit_data.get_effective_cost() * 12
	power += int(round(float(unit_data.mana_gain_on_attack + unit_data.mana_gain_on_hit) * 0.5))
	if unit_data.skill_data != null or unit_data.master_skill_data != null:
		power += 20
	if is_master:
		power += 45

	match unit_data.class_type:
		GameEnums.ClassType.TANK:
			power += 18
		GameEnums.ClassType.SUPPORT:
			power += 10
		GameEnums.ClassType.STEALTH:
			power += 8
		_:
			power += 12

	power += (_unit_sort_bias(unit_data.id, player_seed, round_number) % 7) - 3
	return maxi(1, power)

func _build_snapshot_summary(units: Array[Dictionary]) -> String:
	if units.is_empty():
		return "Sem unidades em campo."

	var summary_units: Array[String] = []
	for unit_entry in units:
		var display_name: String = str(unit_entry.get("display_name", "Unidade"))
		var coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
		var team_marker: String = "JOG" if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) == GameEnums.TeamSide.PLAYER else "INV"
		summary_units.append("%s [%s] @ %s" % [display_name, team_marker, coord])
	return _join_strings(summary_units)

func _resolve_background_match(
	player_a: MatchPlayerState,
	player_b: MatchPlayerState,
	snapshot_a: Dictionary,
	round_number: int
) -> Dictionary:
	var sim_units: Array[Dictionary] = _build_background_sim_units(snapshot_a)
	var acting_team: int = GameEnums.TeamSide.PLAYER if ((player_a.slot_index + player_b.slot_index + round_number) % 2 == 0) else GameEnums.TeamSide.ENEMY
	var actions_taken: int = 0
	var reached_action_cap: bool = false

	while actions_taken < BACKGROUND_COMBAT_MAX_ACTIONS:
		if not _background_team_alive(sim_units, GameEnums.TeamSide.PLAYER):
			break
		if not _background_team_alive(sim_units, GameEnums.TeamSide.ENEMY):
			break

		var team_order: Array[int] = [acting_team, _opposite_team(acting_team)]
		for team_side in team_order:
			var turn_order: Array[Dictionary] = _background_team_turn_order(sim_units, team_side)
			for unit_entry in turn_order:
				if not bool(unit_entry.get("alive", false)):
					continue
				if not _background_team_alive(sim_units, _opposite_team(team_side)):
					break
				_background_take_action(unit_entry, sim_units)
				actions_taken += 1
				if actions_taken >= BACKGROUND_COMBAT_MAX_ACTIONS:
					break
			if actions_taken >= BACKGROUND_COMBAT_MAX_ACTIONS:
				break

		acting_team = _opposite_team(acting_team)

	reached_action_cap = (
		actions_taken >= BACKGROUND_COMBAT_MAX_ACTIONS
		and _background_team_alive(sim_units, GameEnums.TeamSide.PLAYER)
		and _background_team_alive(sim_units, GameEnums.TeamSide.ENEMY)
	)

	var winner_team: int = _background_winner_team(sim_units)
	var winner_id: String = ""
	var loser_id: String = ""
	var damage: int = 0
	var winner_survivors: int = -1
	var loser_survivors: int = -1
	var player_a_result_text: String = "Empate em segundo plano contra %s" % player_b.display_name
	var player_b_result_text: String = "Empate em segundo plano contra %s" % player_a.display_name

	if winner_team >= 0:
		winner_id = player_a.player_id if winner_team == GameEnums.TeamSide.PLAYER else player_b.player_id
		loser_id = player_b.player_id if winner_team == GameEnums.TeamSide.PLAYER else player_a.player_id
		winner_survivors = _count_background_survivors(sim_units, winner_team)
		loser_survivors = _count_background_survivors(sim_units, _opposite_team(winner_team))
		damage = BattleConfigScript.calculate_post_combat_damage({
			"winner_id": winner_id,
			"loser_id": loser_id,
		}, round_number, {
			"survivors": winner_survivors,
		})

		if winner_team == GameEnums.TeamSide.PLAYER:
			player_a_result_text = "%s venceu %s em segundo plano e causou %d de dano" % [
				player_a.display_name,
				player_b.display_name,
				damage,
			]
			player_b_result_text = "%s perdeu para %s em segundo plano e sofreu %d de dano" % [
				player_b.display_name,
				player_a.display_name,
				damage,
			]
		else:
			player_a_result_text = "%s perdeu para %s em segundo plano e sofreu %d de dano" % [
				player_a.display_name,
				player_b.display_name,
				damage,
			]
			player_b_result_text = "%s venceu %s em segundo plano e causou %d de dano" % [
				player_b.display_name,
				player_a.display_name,
				damage,
			]

	return {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"damage": damage,
		"winner_survivors": winner_survivors,
		"loser_survivors": loser_survivors,
		"player_a_result_text": player_a_result_text,
		"player_b_result_text": player_b_result_text,
		"result_text": player_a_result_text,
		"failsafe_triggered": reached_action_cap,
		"failsafe_reason": "background_action_cap" if reached_action_cap else "",
		"snapshot_a": _build_snapshot_from_sim_units(player_a, player_b, sim_units, GameEnums.TeamSide.PLAYER, round_number, "RESULTADO", player_a_result_text),
		"snapshot_b": _build_snapshot_from_sim_units(player_b, player_a, sim_units, GameEnums.TeamSide.ENEMY, round_number, "RESULTADO", player_b_result_text),
	}

func _build_background_sim_units(snapshot: Dictionary) -> Array[Dictionary]:
	var sim_units: Array[Dictionary] = []
	var source_units: Array = snapshot.get("units", [])
	for unit_variant in source_units:
		var unit_entry: Dictionary = unit_variant
		sim_units.append({
			"unit_id": str(unit_entry.get("unit_id", "")),
			"unit_path": str(unit_entry.get("unit_path", "")),
			"display_name": str(unit_entry.get("display_name", "Unidade")),
			"coord": unit_entry.get("coord", Vector2i(-1, -1)),
			"team_side": int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)),
			"is_master": bool(unit_entry.get("is_master", false)),
			"class_label": str(unit_entry.get("class_label", "Classe")),
			"race_name": str(unit_entry.get("race_name", "Raca")),
			"cost": int(unit_entry.get("cost", 0)),
			"current_hp": int(unit_entry.get("current_hp", 0)),
			"max_hp": int(unit_entry.get("max_hp", 0)),
			"current_mana": int(unit_entry.get("current_mana", 0)),
			"mana_max": int(unit_entry.get("mana_max", 0)),
			"physical_attack": int(unit_entry.get("physical_attack", 0)),
			"magic_attack": int(unit_entry.get("magic_attack", 0)),
			"physical_defense": int(unit_entry.get("physical_defense", 0)),
			"magic_defense": int(unit_entry.get("magic_defense", 0)),
			"attack_range": int(unit_entry.get("attack_range", 1)),
			"crit_chance": float(unit_entry.get("crit_chance", 0.0)),
			"alive": int(unit_entry.get("current_hp", 0)) > 0,
			"last_coord": Vector2i(-1, -1),
			"previous_coord": Vector2i(-1, -1),
			"last_move_origin": Vector2i(-1, -1),
			"last_move_destination": Vector2i(-1, -1),
			"last_move_type": "",
			"last_target_key": "",
			"previous_target_key": "",
			"bounce_counter": 0,
			"retarget_cooldown_turns": 0,
			"blocked_target_key": "",
			"blocked_target_turns": 0,
			"skip_turns_remaining": 0,
			"initiative_bonus": 0,
		})
	return sim_units

func _build_snapshot_from_sim_units(
	viewer_state: MatchPlayerState,
	opponent_state: MatchPlayerState,
	sim_units: Array[Dictionary],
	viewer_team_side: int,
	round_number: int,
	phase_name: String,
	result_text: String,
	card_summary: String = "",
	recent_events: Array[Dictionary] = []
) -> Dictionary:
	var units: Array[Dictionary] = []
	var total_power: int = _estimate_owned_cards_power_bonus(viewer_state.get_owned_card_paths()) if viewer_state != null else 0
	var non_master_count: int = 0
	var enemy_unit_count: int = 0
	var master_name: String = "Sem mestre"
	var opponent_master_name: String = "Sem mestre"

	for sim_unit in sim_units:
		if not bool(sim_unit.get("alive", false)):
			continue

		var absolute_team: int = int(sim_unit.get("team_side", GameEnums.TeamSide.PLAYER))
		var relative_team: int = GameEnums.TeamSide.PLAYER if absolute_team == viewer_team_side else GameEnums.TeamSide.ENEMY
		var coord: Vector2i = sim_unit.get("coord", Vector2i(-1, -1))
		if viewer_team_side == GameEnums.TeamSide.ENEMY:
			coord = _mirror_coord_for_opponent_view(coord)

		var unit_entry: Dictionary = {
			"unit_id": str(sim_unit.get("unit_id", "")),
			"unit_path": str(sim_unit.get("unit_path", "")),
			"display_name": str(sim_unit.get("display_name", "Unidade")),
			"coord": coord,
			"team_side": relative_team,
			"is_master": bool(sim_unit.get("is_master", false)),
			"class_label": str(sim_unit.get("class_label", "Classe")),
			"race_name": str(sim_unit.get("race_name", "Raca")),
			"cost": int(sim_unit.get("cost", 0)),
			"current_hp": int(sim_unit.get("current_hp", 0)),
			"max_hp": int(sim_unit.get("max_hp", 0)),
			"current_mana": int(sim_unit.get("current_mana", 0)),
			"mana_max": int(sim_unit.get("mana_max", 0)),
			"physical_attack": int(sim_unit.get("physical_attack", 0)),
			"magic_attack": int(sim_unit.get("magic_attack", 0)),
			"physical_defense": int(sim_unit.get("physical_defense", 0)),
			"magic_defense": int(sim_unit.get("magic_defense", 0)),
			"attack_range": int(sim_unit.get("attack_range", 1)),
			"crit_chance": float(sim_unit.get("crit_chance", 0.0)),
			"mana_gain_on_attack": 0,
			"mana_gain_on_hit": 0,
		}
		if relative_team == GameEnums.TeamSide.PLAYER and bool(unit_entry.get("is_master", false)):
			master_name = str(unit_entry.get("display_name", "Mestre"))
		elif relative_team == GameEnums.TeamSide.ENEMY and bool(unit_entry.get("is_master", false)):
			opponent_master_name = str(unit_entry.get("display_name", "Mestre"))
		elif relative_team == GameEnums.TeamSide.PLAYER:
			non_master_count += 1
		else:
			enemy_unit_count += 1

		units.append(unit_entry)
		total_power += _estimate_snapshot_entry_power(unit_entry)

	return {
		"player_id": viewer_state.player_id if viewer_state != null else "",
		"player_name": viewer_state.display_name if viewer_state != null else "Jogador",
		"opponent_id": opponent_state.player_id if opponent_state != null else "",
		"opponent_name": opponent_state.display_name if opponent_state != null else "Sem oponente",
		"round_number": round_number,
		"phase": phase_name,
		"life": viewer_state.current_life if viewer_state != null else 0,
		"gold": viewer_state.current_gold if viewer_state != null else 0,
		"gold_budget": viewer_state.current_gold if viewer_state != null else 0,
		"units": units,
		"unit_count": units.size(),
		"non_master_count": non_master_count,
		"enemy_unit_count": enemy_unit_count,
		"power_rating": total_power,
		"master_name": master_name,
		"opponent_master_name": opponent_master_name,
		"owned_card_count": viewer_state.get_owned_card_paths().size() if viewer_state != null else 0,
		"owned_card_names": _card_names_from_paths(viewer_state.get_owned_card_paths()) if viewer_state != null else [],
		"table_id": viewer_state.current_table_id if viewer_state != null else "",
		"streak": viewer_state.streak_value if viewer_state != null else 0,
		"player_level": viewer_state.player_level if viewer_state != null else 1,
		"card_summary": card_summary,
		"recent_events": recent_events,
		"summary": _build_snapshot_summary(units),
		"result_text": result_text,
	}

func _background_take_action(unit_entry: Dictionary, sim_units: Array[Dictionary], log_context: String = "") -> String:
	if int(unit_entry.get("skip_turns_remaining", 0)) > 0:
		unit_entry["skip_turns_remaining"] = maxi(0, int(unit_entry.get("skip_turns_remaining", 0)) - 1)
		_background_advance_navigation_cooldowns(unit_entry)
		return "skip"
	var target: Dictionary = _find_background_target(unit_entry, sim_units)
	if target.is_empty():
		_background_advance_navigation_cooldowns(unit_entry)
		return "wait"
	var target_key: String = _background_unit_key(target)
	if target_key != str(unit_entry.get("last_target_key", "")):
		unit_entry["previous_target_key"] = str(unit_entry.get("last_target_key", ""))
		unit_entry["last_target_key"] = target_key
	if _background_in_range(unit_entry, target):
		_background_clear_blocked_target(unit_entry)
		unit_entry["bounce_counter"] = maxi(0, int(unit_entry.get("bounce_counter", 0)) - 1)
		_background_attack(unit_entry, target)
		_background_advance_navigation_cooldowns(unit_entry)
		return "attack"
	if _background_move(unit_entry, target, sim_units):
		_background_clear_blocked_target(unit_entry)
		_background_advance_navigation_cooldowns(unit_entry)
		return "move"

	var alternate_target: Dictionary = _find_background_alternate_target(unit_entry, sim_units, target)
	if not alternate_target.is_empty():
		target_key = _background_unit_key(alternate_target)
		unit_entry["previous_target_key"] = str(unit_entry.get("last_target_key", ""))
		unit_entry["last_target_key"] = target_key
		if _background_in_range(unit_entry, alternate_target):
			_background_clear_blocked_target(unit_entry)
			unit_entry["bounce_counter"] = maxi(0, int(unit_entry.get("bounce_counter", 0)) - 1)
			_background_attack(unit_entry, alternate_target)
			_background_advance_navigation_cooldowns(unit_entry)
			return "attack"
		if _background_move(unit_entry, alternate_target, sim_units):
			_background_clear_blocked_target(unit_entry)
			_background_advance_navigation_cooldowns(unit_entry)
			return "move"

	_background_remember_blocked_target(unit_entry, target_key)
	if _background_has_loop_pressure(unit_entry) and not log_context.is_empty():
		print("ANTI_LOOP [%s]: %s travou em %s e aguardara retarget" % [
			log_context,
			str(unit_entry.get("display_name", "Unidade")),
			target_key,
		])
	_background_advance_navigation_cooldowns(unit_entry)
	return "stuck"

func _background_team_turn_order(sim_units: Array[Dictionary], team_side: int) -> Array[Dictionary]:
	var turn_order: Array[Dictionary] = []
	for unit_entry in sim_units:
		if not bool(unit_entry.get("alive", false)):
			continue
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) != team_side:
			continue
		turn_order.append(unit_entry)
	turn_order.sort_custom(_sort_background_turn_order)
	return turn_order

func _sort_background_turn_order(a: Dictionary, b: Dictionary) -> bool:
	var initiative_a: int = _background_unit_initiative(a)
	var initiative_b: int = _background_unit_initiative(b)
	if initiative_a != initiative_b:
		return initiative_a > initiative_b
	var hp_a: int = int(a.get("current_hp", 0))
	var hp_b: int = int(b.get("current_hp", 0))
	if hp_a != hp_b:
		return hp_a > hp_b
	return str(a.get("display_name", "")) < str(b.get("display_name", ""))

func _background_unit_initiative(unit_entry: Dictionary) -> int:
	var initiative: int = 0
	initiative += int(unit_entry.get("attack_range", 1)) * 10
	initiative += int(unit_entry.get("physical_attack", 0))
	initiative += int(unit_entry.get("magic_attack", 0))
	initiative += int(unit_entry.get("cost", 0)) * 3
	initiative += int(unit_entry.get("initiative_bonus", 0))
	if bool(unit_entry.get("is_master", false)):
		initiative -= 6
	return initiative

func _find_background_target(unit_entry: Dictionary, sim_units: Array[Dictionary]) -> Dictionary:
	var best_target: Dictionary = {}
	var best_score: int = 1000000
	var source_coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
	var source_team: int = int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER))

	for candidate in sim_units:
		if not bool(candidate.get("alive", false)):
			continue
		if int(candidate.get("team_side", GameEnums.TeamSide.PLAYER)) == source_team:
			continue

		var candidate_coord: Vector2i = candidate.get("coord", Vector2i(-1, -1))
		var score: int = _background_distance(source_coord, candidate_coord) * 100
		score += int(candidate.get("current_hp", 0)) * 4
		score += int(candidate.get("physical_defense", 0)) * 6
		score += int(candidate.get("magic_defense", 0)) * 4
		score += _background_target_penalty(unit_entry, _background_unit_key(candidate))
		if bool(candidate.get("is_master", false)):
			score -= 12
		if best_target.is_empty() or score < best_score:
			best_target = candidate
			best_score = score

	return best_target

func _find_background_alternate_target(unit_entry: Dictionary, sim_units: Array[Dictionary], excluded_target: Dictionary) -> Dictionary:
	var best_target: Dictionary = {}
	var best_score: int = 1000000
	var excluded_key: String = _background_unit_key(excluded_target)
	for candidate in sim_units:
		if not bool(candidate.get("alive", false)):
			continue
		if int(candidate.get("team_side", GameEnums.TeamSide.PLAYER)) == int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)):
			continue
		if _background_unit_key(candidate) == excluded_key:
			continue
		if not _background_in_range(unit_entry, candidate):
			var occupied: Dictionary = {}
			for other_unit in sim_units:
				if not bool(other_unit.get("alive", false)):
					continue
				if other_unit == unit_entry:
					continue
				occupied[_coord_key(other_unit.get("coord", Vector2i(-1, -1)))] = true
			var move_plan: Dictionary = _resolve_background_step(
				unit_entry,
				unit_entry.get("coord", Vector2i(-1, -1)),
				candidate.get("coord", Vector2i(-1, -1)),
				occupied,
				_background_bounce_forbidden_coord(unit_entry, _background_unit_key(candidate)),
				true
			)
			if move_plan.get("coord", unit_entry.get("coord", Vector2i(-1, -1))) == unit_entry.get("coord", Vector2i(-1, -1)):
				continue

		var score: int = _background_distance(
			unit_entry.get("coord", Vector2i(-1, -1)),
			candidate.get("coord", Vector2i(-1, -1))
		) * 100
		score += int(candidate.get("current_hp", 0)) * 4
		score += int(candidate.get("physical_defense", 0)) * 6
		score += int(candidate.get("magic_defense", 0)) * 4
		score += _background_target_penalty(unit_entry, _background_unit_key(candidate))
		if best_target.is_empty() or score < best_score:
			best_target = candidate
			best_score = score
	return best_target

func _background_in_range(unit_entry: Dictionary, target: Dictionary) -> bool:
	return _background_distance(
		unit_entry.get("coord", Vector2i(-1, -1)),
		target.get("coord", Vector2i(-1, -1))
	) <= int(unit_entry.get("attack_range", 1))

func _background_attack(attacker: Dictionary, target: Dictionary) -> void:
	var physical_attack: int = int(attacker.get("physical_attack", 0))
	var magic_attack: int = int(attacker.get("magic_attack", 0))
	var expected_crit_bonus: int = int(round(float(physical_attack + magic_attack) * float(attacker.get("crit_chance", 0.0)) * 0.35))
	var physical_damage: int = maxi(0, physical_attack - int(target.get("physical_defense", 0)))
	var magic_damage: int = maxi(0, magic_attack - int(target.get("magic_defense", 0)))
	var total_damage: int = physical_damage + magic_damage + expected_crit_bonus
	if total_damage <= 0:
		total_damage = 1

	var next_hp: int = maxi(0, int(target.get("current_hp", 0)) - total_damage)
	target["current_hp"] = next_hp
	target["alive"] = next_hp > 0

func _background_move(unit_entry: Dictionary, target: Dictionary, sim_units: Array[Dictionary]) -> bool:
	var current_coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
	var target_coord: Vector2i = target.get("coord", Vector2i(-1, -1))
	var occupied: Dictionary = {}
	for other_unit in sim_units:
		if not bool(other_unit.get("alive", false)):
			continue
		if other_unit == unit_entry:
			continue
		occupied[_coord_key(other_unit.get("coord", Vector2i(-1, -1)))] = true

	var target_key: String = _background_unit_key(target)
	var move_plan: Dictionary = _resolve_background_step(
		unit_entry,
		current_coord,
		target_coord,
		occupied,
		_background_bounce_forbidden_coord(unit_entry, target_key),
		_background_has_loop_pressure(unit_entry)
	)
	var next_coord: Vector2i = move_plan.get("coord", current_coord)
	if next_coord == current_coord:
		return false
	var bounced_back: bool = (
		str(unit_entry.get("last_target_key", "")) == target_key
		and unit_entry.get("last_move_origin", Vector2i(-1, -1)) == next_coord
		and unit_entry.get("last_move_destination", Vector2i(-1, -1)) == current_coord
	)
	unit_entry["previous_coord"] = unit_entry.get("last_coord", Vector2i(-1, -1))
	unit_entry["last_coord"] = current_coord
	unit_entry["last_move_origin"] = current_coord
	unit_entry["last_move_destination"] = next_coord
	unit_entry["last_move_type"] = str(move_plan.get("move_type", "advance"))
	unit_entry["last_target_key"] = target_key
	if bounced_back:
		unit_entry["bounce_counter"] = int(unit_entry.get("bounce_counter", 0)) + 1
		unit_entry["retarget_cooldown_turns"] = maxi(int(unit_entry.get("retarget_cooldown_turns", 0)), BACKGROUND_RETARGET_COOLDOWN_TURNS)
	else:
		unit_entry["bounce_counter"] = maxi(0, int(unit_entry.get("bounce_counter", 0)) - 1)
	unit_entry["coord"] = next_coord
	return true

func _resolve_background_step(
	unit_entry: Dictionary,
	current_coord: Vector2i,
	target_coord: Vector2i,
	occupied: Dictionary,
	forbidden_coord: Vector2i = Vector2i(-1, -1),
	prefer_wait_on_fallback: bool = false
) -> Dictionary:
	var current_distance: int = _background_distance(current_coord, target_coord)
	var previous_coord: Vector2i = unit_entry.get("last_coord", Vector2i(-1, -1))
	var best_advance: Vector2i = Vector2i(-1, -1)
	var best_side: Vector2i = Vector2i(-1, -1)
	var best_fallback: Vector2i = Vector2i(-1, -1)
	var best_advance_score: int = 1000000
	var best_side_score: int = 1000000
	var best_fallback_score: int = 1000000

	for candidate in _background_adjacent_coords(current_coord):
		if not _is_valid_snapshot_coord(candidate):
			continue
		if occupied.has(_coord_key(candidate)):
			continue
		if forbidden_coord != Vector2i(-1, -1) and candidate == forbidden_coord:
			continue

		var candidate_distance: int = _background_distance(candidate, target_coord)
		var candidate_score: int = _background_move_score(
			candidate,
			current_coord,
			target_coord,
			int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER))
		)
		if candidate == previous_coord:
			candidate_score += 250

		if candidate_distance < current_distance:
			if candidate_score < best_advance_score:
				best_advance_score = candidate_score
				best_advance = candidate
		elif candidate_distance == current_distance:
			if candidate_score < best_side_score:
				best_side_score = candidate_score
				best_side = candidate
		else:
			if candidate_score < best_fallback_score:
				best_fallback_score = candidate_score
				best_fallback = candidate

	if _is_valid_snapshot_coord(best_advance):
		return {"coord": best_advance, "move_type": "advance"}
	if _is_valid_snapshot_coord(best_side):
		return {"coord": best_side, "move_type": "sidestep"}
	if prefer_wait_on_fallback and _is_valid_snapshot_coord(best_fallback):
		return {"coord": current_coord, "move_type": "wait"}
	if _is_valid_snapshot_coord(best_fallback):
		return {"coord": best_fallback, "move_type": "fallback"}
	return {"coord": current_coord, "move_type": "blocked"}

func _background_adjacent_coords(coord: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(coord.x + 1, coord.y),
		Vector2i(coord.x - 1, coord.y),
		Vector2i(coord.x, coord.y + 1),
		Vector2i(coord.x, coord.y - 1),
	]

func _background_move_score(candidate: Vector2i, from_coord: Vector2i, target_coord: Vector2i, team_side: int) -> int:
	var target_distance: int = _background_distance(candidate, target_coord)
	var horizontal_delta: int = abs(candidate.x - target_coord.x)
	var forward_progress: int = from_coord.y - candidate.y if team_side == GameEnums.TeamSide.PLAYER else candidate.y - from_coord.y
	var backward_progress: int = candidate.y - from_coord.y if team_side == GameEnums.TeamSide.PLAYER else from_coord.y - candidate.y
	return (
		target_distance * 100
		+ maxi(0, backward_progress) * 12
		+ horizontal_delta * 5
		- maxi(0, forward_progress)
	)

func _background_unit_key(unit_entry: Dictionary) -> String:
	return str(unit_entry.get("unit_id", ""))

func _background_target_penalty(unit_entry: Dictionary, target_key: String) -> int:
	if target_key.is_empty():
		return 0

	var penalty: int = 0
	var blocked_target_key: String = str(unit_entry.get("blocked_target_key", ""))
	var blocked_target_turns: int = int(unit_entry.get("blocked_target_turns", 0))
	if blocked_target_key == target_key and blocked_target_turns >= 2:
		penalty += 240 + ((blocked_target_turns - 2) * 60)

	var last_target_key: String = str(unit_entry.get("last_target_key", ""))
	if int(unit_entry.get("retarget_cooldown_turns", 0)) > 0 and last_target_key == target_key:
		penalty += 320
	if str(unit_entry.get("previous_target_key", "")) == target_key:
		penalty += 90
	if int(unit_entry.get("bounce_counter", 0)) >= BACKGROUND_BOUNCE_THRESHOLD and last_target_key == target_key:
		penalty += 180
	return penalty

func _background_bounce_forbidden_coord(unit_entry: Dictionary, target_key: String) -> Vector2i:
	if target_key.is_empty():
		return Vector2i(-1, -1)
	if str(unit_entry.get("last_target_key", "")) != target_key:
		return Vector2i(-1, -1)
	if unit_entry.get("coord", Vector2i(-1, -1)) != unit_entry.get("last_move_destination", Vector2i(-1, -1)):
		return Vector2i(-1, -1)
	if int(unit_entry.get("bounce_counter", 0)) >= BACKGROUND_BOUNCE_THRESHOLD:
		var previous_coord: Vector2i = unit_entry.get("previous_coord", Vector2i(-1, -1))
		if previous_coord != Vector2i(-1, -1):
			return previous_coord
	var move_type: String = str(unit_entry.get("last_move_type", ""))
	if move_type != "sidestep" and move_type != "fallback":
		return Vector2i(-1, -1)
	return unit_entry.get("last_move_origin", Vector2i(-1, -1))

func _background_remember_blocked_target(unit_entry: Dictionary, target_key: String) -> void:
	if target_key.is_empty():
		_background_clear_blocked_target(unit_entry)
		return
	if str(unit_entry.get("blocked_target_key", "")) == target_key:
		unit_entry["blocked_target_turns"] = int(unit_entry.get("blocked_target_turns", 0)) + 1
	else:
		unit_entry["blocked_target_key"] = target_key
		unit_entry["blocked_target_turns"] = 1
	if int(unit_entry.get("blocked_target_turns", 0)) >= 2:
		unit_entry["retarget_cooldown_turns"] = maxi(
			int(unit_entry.get("retarget_cooldown_turns", 0)),
			BACKGROUND_RETARGET_COOLDOWN_TURNS
		)

func _background_clear_blocked_target(unit_entry: Dictionary) -> void:
	unit_entry["blocked_target_key"] = ""
	unit_entry["blocked_target_turns"] = 0

func _background_advance_navigation_cooldowns(unit_entry: Dictionary) -> void:
	if int(unit_entry.get("retarget_cooldown_turns", 0)) > 0:
		unit_entry["retarget_cooldown_turns"] = int(unit_entry.get("retarget_cooldown_turns", 0)) - 1

func _background_has_loop_pressure(unit_entry: Dictionary) -> bool:
	return (
		int(unit_entry.get("bounce_counter", 0)) >= BACKGROUND_BOUNCE_THRESHOLD
		or int(unit_entry.get("blocked_target_turns", 0)) >= 2
	)

func _background_team_alive(sim_units: Array[Dictionary], team_side: int) -> bool:
	for unit_entry in sim_units:
		if not bool(unit_entry.get("alive", false)):
			continue
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) == team_side:
			return true
	return false

func _count_background_survivors(sim_units: Array[Dictionary], team_side: int) -> int:
	var count: int = 0
	for unit_entry in sim_units:
		if not bool(unit_entry.get("alive", false)):
			continue
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) != team_side:
			continue
		count += 1
	return count

func _background_winner_team(sim_units: Array[Dictionary]) -> int:
	var player_alive: bool = _background_team_alive(sim_units, GameEnums.TeamSide.PLAYER)
	var enemy_alive: bool = _background_team_alive(sim_units, GameEnums.TeamSide.ENEMY)
	if player_alive and not enemy_alive:
		return GameEnums.TeamSide.PLAYER
	if enemy_alive and not player_alive:
		return GameEnums.TeamSide.ENEMY

	var player_survivors: int = _count_background_survivors(sim_units, GameEnums.TeamSide.PLAYER)
	var enemy_survivors: int = _count_background_survivors(sim_units, GameEnums.TeamSide.ENEMY)
	if player_survivors != enemy_survivors:
		return GameEnums.TeamSide.PLAYER if player_survivors > enemy_survivors else GameEnums.TeamSide.ENEMY

	var player_hp_total: int = _background_team_hp_total(sim_units, GameEnums.TeamSide.PLAYER)
	var enemy_hp_total: int = _background_team_hp_total(sim_units, GameEnums.TeamSide.ENEMY)
	if player_hp_total == enemy_hp_total:
		return -1
	return GameEnums.TeamSide.PLAYER if player_hp_total > enemy_hp_total else GameEnums.TeamSide.ENEMY

func _background_team_hp_total(sim_units: Array[Dictionary], team_side: int) -> int:
	var total_hp: int = 0
	for unit_entry in sim_units:
		if not bool(unit_entry.get("alive", false)):
			continue
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) != team_side:
			continue
		total_hp += int(unit_entry.get("current_hp", 0))
	return total_hp

func _background_team_score(sim_units: Array[Dictionary], team_side: int) -> int:
	var score: int = 0
	for unit_entry in sim_units:
		if not bool(unit_entry.get("alive", false)):
			continue
		if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) != team_side:
			continue
		score += int(unit_entry.get("current_hp", 0)) * 3
		score += int(unit_entry.get("physical_attack", 0)) * 2
		score += int(unit_entry.get("magic_attack", 0)) * 2
		score += int(unit_entry.get("physical_defense", 0)) * 2
		score += int(unit_entry.get("magic_defense", 0)) * 2
		if bool(unit_entry.get("is_master", false)):
			score += 18
	return score

func _estimate_snapshot_entry_power(unit_entry: Dictionary) -> int:
	var power: int = 0
	power += int(unit_entry.get("current_hp", 0)) * 2
	power += int(unit_entry.get("physical_attack", 0)) * 5
	power += int(unit_entry.get("magic_attack", 0)) * 5
	power += int(unit_entry.get("physical_defense", 0)) * 4
	power += int(unit_entry.get("magic_defense", 0)) * 4
	power += int(unit_entry.get("attack_range", 1)) * 3
	power += int(round(float(unit_entry.get("crit_chance", 0.0)) * 100.0))
	power += int(unit_entry.get("cost", 0)) * 12
	if bool(unit_entry.get("is_master", false)):
		power += 45
	return maxi(1, power)

func _background_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _coord_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]

func _mirror_coord_for_opponent_view(coord: Vector2i) -> Vector2i:
	return Vector2i(coord.x, BattleConfigScript.BOARD_HEIGHT - 1 - coord.y)

func _opposite_team(team_side: int) -> int:
	return GameEnums.TeamSide.ENEMY if team_side == GameEnums.TeamSide.PLAYER else GameEnums.TeamSide.PLAYER

func _player_round_bias(player_state: MatchPlayerState, round_number: int) -> int:
	if player_state == null:
		return 0
	return ((player_state.slot_index * 13) + (round_number * 7)) % 11 - 5

func _effective_field_limit(field_limit: int, round_number: int) -> int:
	if round_number <= 1:
		return mini(field_limit, 1)
	if round_number == 2:
		return mini(field_limit, 2)
	if round_number == 3:
		return mini(field_limit, 3)
	return field_limit

func _effective_gold_budget(available_gold: int, round_number: int) -> int:
	if round_number <= 1:
		return mini(available_gold, 2)
	if round_number == 2:
		return mini(available_gold, 3)
	if round_number == 3:
		return mini(available_gold, 4)
	return available_gold

func _sort_card_offer_paths(a: String, b: String, player_seed: int, round_number: int) -> bool:
	var score_a: int = abs(hash("%s|%d|%d" % [a, player_seed, round_number])) % 1000
	var score_b: int = abs(hash("%s|%d|%d" % [b, player_seed, round_number])) % 1000
	if score_a != score_b:
		return score_a < score_b
	return a < b

func _choose_background_shop_pick(player_state: MatchPlayerState, offer_paths: Array[String], round_number: int) -> String:
	var best_path: String = ""
	var best_score: int = -100000
	for card_path in offer_paths:
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		var score: int = _estimate_card_pick_score(card_data, player_state.slot_index, round_number)
		if best_path.is_empty() or score > best_score:
			best_path = card_path
			best_score = score
	return best_path

func _estimate_card_pick_score(card_data: CardData, player_seed: int, round_number: int) -> int:
	if card_data == null:
		return 0

	var score: int = 10
	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			score += 24
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			score += 28
		GameEnums.SupportCardEffectType.START_STEALTH:
			score += 18
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			score += 16
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			score += 18
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			score += 20
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			score += 12
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			score += 22
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			score += 24
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			score += 20
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			score += 26
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			score += 18
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			score += 20
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			score += 22
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			score += 18
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			score += 20
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			score += 20
		_:
			score += 10

	score += abs(hash("%s|%d|%d" % [card_data.id, player_seed, round_number])) % 9
	return score

func _estimate_owned_cards_power_bonus(card_paths: Array[String]) -> int:
	var bonus: int = 0
	for card_path in card_paths:
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		bonus += 8
		match card_data.support_effect_type:
			GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
				bonus += 18
			GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
				bonus += 18
			GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
				bonus += 12
			GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
				bonus += 10
			GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
				bonus += 8
			GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
				bonus += 14
			GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
				bonus += 16
			GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
				bonus += 14
			GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
				bonus += 18
			GameEnums.SupportCardEffectType.OPENING_REPOSITION:
				bonus += 10
			GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
				bonus += 14
			GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
				bonus += 16
			GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
				bonus += 12
			GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
				bonus += 14
			GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
				bonus += 14
	return bonus

func _card_names_from_paths(card_paths: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for card_path in card_paths:
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		names.append(card_data.display_name)
	return names

func _load_deck_data(path: String) -> DeckData:
	if path.is_empty():
		return null
	if deck_cache.has(path):
		return deck_cache[path] as DeckData

	var loaded: Resource = load(path)
	if loaded is DeckData:
		deck_cache[path] = loaded
		return loaded as DeckData
	return null

func _load_unit_data(path: String) -> UnitData:
	if path.is_empty():
		return null
	if unit_cache.has(path):
		return unit_cache[path] as UnitData

	var loaded: Resource = load(path)
	if loaded is UnitData:
		unit_cache[path] = loaded
		return loaded as UnitData
	return null

func _load_card_data(path: String) -> CardData:
	if path.is_empty():
		return null
	if card_cache.has(path):
		return card_cache[path] as CardData

	var loaded: Resource = load(path)
	if loaded is CardData:
		card_cache[path] = loaded
		return loaded as CardData
	return null

func _resolve_unit_class_label(unit_data: UnitData) -> String:
	if unit_data == null:
		return "Unidade"
	if not unit_data.class_label.is_empty():
		return unit_data.class_label
	return str(unit_data.class_type)

func _race_name(race_value: int) -> String:
	match race_value:
		GameEnums.Race.HUMAN:
			return "Humano"
		GameEnums.Race.ELF:
			return "Elfo"
		GameEnums.Race.FAIRY:
			return "Fada"
		GameEnums.Race.OGRE:
			return "Ogro"
		GameEnums.Race.UNDEAD:
			return "Morto-vivo"
		GameEnums.Race.BEAST:
			return "Besta"
		_:
			return "Desconhecida"

func _join_strings(values: Array[String], separator: String = ", ") -> String:
	var result: String = ""
	for value in values:
		var clean_value: String = value.strip_edges()
		if clean_value.is_empty():
			continue
		if result.is_empty():
			result = clean_value
		else:
			result += separator + clean_value
	return result
