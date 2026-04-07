extends GutTest

const GameDataScript := preload("res://autoload/game_data.gd")
var game_data


func before_each() -> void:
	game_data = GameDataScript.new()


func after_each() -> void:
	if game_data != null:
		game_data.free()
		game_data = null


func test_available_decks_load_with_master_units_and_cards() -> void:
	var deck_ids: Array[String] = game_data.get_available_deck_ids()
	assert_eq(deck_ids.size(), 3, "A demo atual deve expor 3 decks jogaveis.")

	for deck_id in deck_ids:
		var deck_data: DeckData = game_data.load_deck_data(deck_id)
		assert_not_null(deck_data, "DeckData deve carregar para %s." % deck_id)
		assert_true(deck_data is DeckData, "O recurso carregado deve ser DeckData.")
		assert_ne(deck_data.display_name.strip_edges(), "", "Deck precisa de nome visivel.")
		assert_ne(deck_data.master_data_path.strip_edges(), "", "Deck precisa de master_data_path.")
		assert_gt(deck_data.unit_pool_paths.size(), 0, "Deck precisa de ao menos uma unidade.")
		assert_gt(deck_data.card_pool_paths.size(), 0, "Deck precisa de ao menos uma carta.")

		var master_resource: Resource = load(deck_data.master_data_path)
		assert_not_null(master_resource, "Master deve carregar para %s." % deck_id)
		assert_true(master_resource is UnitData, "Master do deck deve ser UnitData.")

		for unit_path in deck_data.unit_pool_paths:
			var unit_resource: Resource = load(unit_path)
			assert_not_null(unit_resource, "Unidade deve carregar: %s" % unit_path)
			assert_true(unit_resource is UnitData, "Recurso de unidade invalido: %s" % unit_path)

		for card_path in deck_data.card_pool_paths:
			var card_resource: Resource = load(card_path)
			assert_not_null(card_resource, "Carta deve carregar: %s" % card_path)
			assert_true(card_resource is CardData, "Recurso de carta invalido: %s" % card_path)


func test_invalid_deck_selection_falls_back_to_default_deck() -> void:
	var selected: bool = game_data.set_selected_deck("deck_inexistente")
	assert_false(selected, "Deck invalido deve ser rejeitado.")
	assert_eq(game_data.get_selected_deck_id(), GameDataScript.DEFAULT_DECK_ID)
	assert_false(game_data.has_selected_deck())
