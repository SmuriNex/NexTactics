extends GutTest

const BattleConfigScript := preload("res://autoload/battle_config.gd")
const LobbyManagerScript := preload("res://scripts/match/lobby_manager.gd")
const GameDataScript := preload("res://autoload/game_data.gd")

var lobby_manager: LobbyManager
var game_data
var winner_id := "player_1"
var loser_id := "player_2"


func before_each() -> void:
	lobby_manager = LobbyManagerScript.new()
	game_data = GameDataScript.new()
	var deck_path: String = game_data.get_deck_path(GameDataScript.DEFAULT_DECK_ID)
	lobby_manager.setup_demo_lobby(2, winner_id, deck_path)
	lobby_manager.set_player_deck_path(winner_id, deck_path)
	lobby_manager.set_player_deck_path(loser_id, deck_path)


func after_each() -> void:
	lobby_manager = null
	if game_data != null:
		game_data.free()
		game_data = null


func test_post_combat_damage_formula_uses_round_base_plus_survivors() -> void:
	var damage: int = BattleConfigScript.calculate_post_combat_damage({}, 4, {"survivors": 3})
	assert_eq(damage, 6, "Rodada 4 deve causar base 3 + 3 sobreviventes.")


func test_apply_post_combat_damage_reduces_loser_life_and_clamps_to_lobby_cap() -> void:
	var raw_damage: int = BattleConfigScript.calculate_post_combat_damage({}, 9, {"survivors": 6})
	assert_eq(raw_damage, 12, "Formula crua deve continuar previsivel antes do clamp do lobby.")

	var initial_life: int = lobby_manager.get_player(loser_id).current_life
	var resolution: Dictionary = lobby_manager.apply_post_combat_damage(winner_id, loser_id, raw_damage, 9, false)

	assert_eq(resolution.get("damage", 0), 8, "Lobby deve clampiar dano pos-combate em 8.")
	assert_eq(lobby_manager.get_player(loser_id).current_life, initial_life - 8)
	assert_eq(lobby_manager.get_player(winner_id).total_damage_dealt, 8)
