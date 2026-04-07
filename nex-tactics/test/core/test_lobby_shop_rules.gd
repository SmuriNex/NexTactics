extends GutTest

const LobbyManagerScript := preload("res://scripts/match/lobby_manager.gd")
const GameDataScript := preload("res://autoload/game_data.gd")

var lobby_manager: LobbyManager
var game_data
var local_player_id := "player_1"


func before_each() -> void:
	lobby_manager = LobbyManagerScript.new()
	game_data = GameDataScript.new()
	var deck_path: String = game_data.get_deck_path(GameDataScript.DEFAULT_DECK_ID)
	lobby_manager.setup_demo_lobby(2, local_player_id, deck_path)
	lobby_manager.set_player_deck_path(local_player_id, deck_path)


func after_each() -> void:
	lobby_manager = null
	if game_data != null:
		game_data.free()
		game_data = null


func test_shop_only_offers_cards_on_multiples_of_three_rounds() -> void:
	var details: Dictionary = lobby_manager.build_card_shop_offer_details(local_player_id, 2)
	assert_eq(details.get("reason", ""), "round_not_multiple_of_3")
	assert_eq(details.get("offer_paths", []).size(), 0)


func test_round_three_shop_offer_is_unique_and_belongs_to_the_deck_pool() -> void:
	var details: Dictionary = lobby_manager.build_card_shop_offer_details(local_player_id, 3)
	var offer_paths: Array[String] = details.get("offer_paths", []).duplicate()
	var valid_card_pool: Array[String] = details.get("valid_card_pool_paths", []).duplicate()

	assert_false(offer_paths.is_empty(), "Rodada 3 deve gerar oferta de cartas.")
	assert_lte(offer_paths.size(), 2, "Oferta da loja deve ter no maximo 2 opcoes.")

	var unique_paths := {}
	for offer_path in offer_paths:
		assert_true(valid_card_pool.has(offer_path), "Oferta deve vir do pool valido do deck.")
		assert_false(unique_paths.has(offer_path), "Oferta nao deve repetir carta.")
		unique_paths[offer_path] = true


func test_owned_cards_are_not_reoffered_when_other_valid_cards_exist() -> void:
	var first_details: Dictionary = lobby_manager.build_card_shop_offer_details(local_player_id, 3)
	var first_offer_paths: Array[String] = first_details.get("offer_paths", []).duplicate()
	assert_false(first_offer_paths.is_empty(), "Primeira oferta precisa existir para o teste ser util.")

	var owned_path: String = first_offer_paths[0]
	var added: bool = lobby_manager.add_owned_card_to_player(local_player_id, owned_path, 3)
	assert_true(added, "Carta escolhida deve ser adicionada ao jogador.")

	var next_details: Dictionary = lobby_manager.build_card_shop_offer_details(local_player_id, 6)
	var next_offer_paths: Array[String] = next_details.get("offer_paths", []).duplicate()

	assert_false(next_offer_paths.has(owned_path), "Carta ja possuida nao deve reaparecer se houver outras validas.")
