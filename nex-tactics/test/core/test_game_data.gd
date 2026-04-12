extends GutTest

const GameDataScript := preload("res://autoload/game_data.gd")
var game_data


func _load_unit(unit_path: String) -> UnitData:
	return load(unit_path) as UnitData


func _count_unit_classes(unit_paths: PackedStringArray) -> Dictionary:
	var counts: Dictionary = {}
	for unit_path in unit_paths:
		var unit_data: UnitData = _load_unit(unit_path)
		if unit_data == null:
			continue
		var class_type: int = unit_data.class_type
		counts[class_type] = int(counts.get(class_type, 0)) + 1
	return counts


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


func test_mordos_identity_now_favors_attackers_tanks_and_death_snowball() -> void:
	var deck_data: DeckData = game_data.load_deck_data(GameDataScript.DECK_ID_MORDOS)
	var master_data: UnitData = load(deck_data.master_data_path) as UnitData
	var class_counts: Dictionary = _count_unit_classes(deck_data.unit_pool_paths)

	assert_eq(master_data.race, GameEnums.Race.HUMAN, "Mordos deve continuar humano.")
	assert_eq(master_data.class_type, GameEnums.ClassType.ATTACKER, "Mordos deve assumir o papel de atacante.")
	assert_eq(int(class_counts.get(GameEnums.ClassType.TANK, 0)), 2, "O roster de Mordos deve manter dois tanques.")
	assert_le(int(class_counts.get(GameEnums.ClassType.STEALTH, 0)), 1, "Furtivo deve ser presenca secundaria em Mordos.")
	assert_le(int(class_counts.get(GameEnums.ClassType.SNIPER, 0)), 1, "Atirador deve ser presenca secundaria em Mordos.")
	assert_ge(
		int(class_counts.get(GameEnums.ClassType.ATTACKER, 0)),
		int(class_counts.get(GameEnums.ClassType.SUPPORT, 0)),
		"Mordos deve priorizar atacantes sobre suportes no roster visivel."
	)


func test_thrax_identity_is_all_human_and_centered_on_firing_lines() -> void:
	var deck_data: DeckData = game_data.load_deck_data(GameDataScript.DECK_ID_THRAX)
	var master_data: UnitData = load(deck_data.master_data_path) as UnitData
	var class_counts: Dictionary = _count_unit_classes(deck_data.unit_pool_paths)

	assert_eq(master_data.race, GameEnums.Race.HUMAN, "Thrax deve ser humano.")
	assert_eq(master_data.class_type, GameEnums.ClassType.TANK, "Thrax deve ser o mestre tanque do deck.")
	for unit_path in deck_data.unit_pool_paths:
		var unit_data: UnitData = _load_unit(unit_path)
		assert_not_null(unit_data, "Unidade de Thrax deve carregar.")
		assert_eq(unit_data.race, GameEnums.Race.HUMAN, "O deck de Thrax deve ser 100% humano.")

	assert_eq(int(class_counts.get(GameEnums.ClassType.TANK, 0)), 2, "Thrax deve manter dois tanques de roster.")
	assert_eq(int(class_counts.get(GameEnums.ClassType.SNIPER, 0)), 4, "Thrax deve empurrar a pool para quatro atiradores.")
	assert_eq(int(class_counts.get(GameEnums.ClassType.SUPPORT, 0)), 2, "Thrax deve reduzir o roster para dois suportes.")
	assert_eq(int(class_counts.get(GameEnums.ClassType.ATTACKER, 0)), 3, "Thrax deve manter poucos atacantes de apoio.")


func test_lady_of_lake_keeps_arcane_sustain_identity() -> void:
	var deck_data: DeckData = game_data.load_deck_data(GameDataScript.DECK_ID_LADY_OF_LAKE)
	var master_data: UnitData = load(deck_data.master_data_path) as UnitData

	assert_eq(master_data.race, GameEnums.Race.FAIRY, "A Dama do Lago deve permanecer fada.")
	assert_eq(master_data.class_type, GameEnums.ClassType.SUPPORT, "A Dama do Lago deve permanecer suporte.")
	assert_true(
		deck_data.description.to_lower().contains("sustain") or deck_data.description.to_lower().contains("protecao"),
		"O deck da Dama deve continuar comunicado como sustain/protecao."
	)
