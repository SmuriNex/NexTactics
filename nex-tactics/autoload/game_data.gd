extends Node

const DECK_ID_MORDOS := "mordos"
const DECK_ID_THRAX := "thrax"
const DECK_ID_LADY_OF_LAKE := "lady_of_lake"
const DEFAULT_DECK_ID := DECK_ID_MORDOS
const DEFAULT_OPPONENT_DECK_ID := DECK_ID_MORDOS

const GAME_DISPLAY_NAME := "Warcrown"
const STUDIO_DISPLAY_NAME := "NexPoint"
const BATTLE_SCENE_PATH := "res://scenes/battle/battle_scene.tscn"
const START_SCREEN_SCENE_PATH := "res://scenes/ui/start_screen.tscn"
const DECK_SELECT_SCENE_PATH := "res://scenes/ui/deck_select_screen.tscn"

const AVAILABLE_DECK_ORDER: Array[String] = [
	DECK_ID_MORDOS,
	DECK_ID_THRAX,
	DECK_ID_LADY_OF_LAKE,
]

const AVAILABLE_DECKS := {
	DECK_ID_MORDOS: {
		"id": DECK_ID_MORDOS,
		"path": "res://data/decks/mordos_deck.tres",
	},
	DECK_ID_THRAX: {
		"id": DECK_ID_THRAX,
		"path": "res://data/decks/thrax_deck.tres",
	},
	DECK_ID_LADY_OF_LAKE: {
		"id": DECK_ID_LADY_OF_LAKE,
		"path": "res://data/decks/lady_of_lake_deck.tres",
	},
}

const DECK_PRESENTATION := {
	DECK_ID_THRAX: {
		"menu_name": "Rei Thrax",
		"factions": "Humanos da coroa, maquina militar do reino e elite de conquista.",
		"playstyle": "Ordem militar, comando, ganancia e supremacia humana.",
		"summary": "Um reino humano disciplinado e ganancioso que vence por comando rigido, poder frontal e crenca na propria superioridade.",
		"master_role": "Comandante de linha de frente e ancora do reino.",
		"master_identity": "Thrax lidera a coroa com punho de ferro, converte riqueza acumulada em poder bruto e exige supremacia humana no campo.",
	},
	DECK_ID_MORDOS: {
		"menu_name": "Mordos, o Necromante",
		"factions": "Mortos-vivos, ogros corrompidos e seguidores da necromancia.",
		"playstyle": "Attrition, corrupcao, invocacao e brutalidade progressiva.",
		"summary": "Mordos comanda uma hoste corrompida que vence por desgaste, invocacao e presenca monstruosa na linha de frente.",
		"master_role": "Conjurador de retaguarda e centro da escalada necromantica.",
		"master_identity": "Mordos e humano, mas governa mortos-vivos e ogros com pactos sombrios, acumulando almas para alongar a luta.",
	},
	DECK_ID_LADY_OF_LAKE: {
		"menu_name": "A Dama do Lago",
		"factions": "Fadas, elfos e corte encantada das aguas.",
		"playstyle": "Magia, protecao, natureza, mobilidade e controle de ritmo.",
		"summary": "Uma formacao encantada que mistura elfos e fadas para controlar o campo, sustentar aliados e vencer pelo tempo.",
		"master_role": "Mestra arcana de retaguarda e eixo de protecao da corte.",
		"master_identity": "A Dama do Lago dita o ritmo da luta com magia, lentidao, protecao e controle elegante do tabuleiro.",
	},
}

var selected_deck_id: String = DEFAULT_DECK_ID
var has_selected_deck_choice: bool = false
var _deck_cache: Dictionary = {}

func get_available_decks() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for deck_id in get_available_deck_ids():
		var deck_data: DeckData = load_deck_data(deck_id)
		if deck_data == null:
			continue
		entries.append({
			"id": deck_id,
			"path": get_deck_path(deck_id),
			"display_name": deck_data.display_name,
			"description": deck_data.description,
			"deck_data": deck_data,
		})
	return entries

func get_deck_presentation(deck_id: String) -> Dictionary:
	if DECK_PRESENTATION.has(deck_id):
		return (DECK_PRESENTATION[deck_id] as Dictionary).duplicate(true)
	return {
		"menu_name": "Deck",
		"factions": "Faccoes nao definidas.",
		"playstyle": "Estilo nao definido.",
		"summary": "Sem resumo de apresentacao.",
		"master_role": "Mestre nao definido.",
		"master_identity": "Identidade nao definida.",
	}

func get_available_deck_ids() -> Array[String]:
	return AVAILABLE_DECK_ORDER.duplicate()

func get_bot_cycle_deck_ids(preferred_player_deck_id: String = "") -> Array[String]:
	var cycle_ids: Array[String] = []
	for deck_id in AVAILABLE_DECK_ORDER:
		if not preferred_player_deck_id.is_empty() and deck_id == preferred_player_deck_id:
			continue
		cycle_ids.append(deck_id)
	if cycle_ids.is_empty():
		return get_available_deck_ids()
	return cycle_ids

func get_selected_deck() -> DeckData:
	return load_deck_data(selected_deck_id)

func get_selected_deck_id() -> String:
	return selected_deck_id

func has_selected_deck() -> bool:
	return has_selected_deck_choice

func get_selected_deck_path() -> String:
	return get_deck_path(selected_deck_id)

func set_selected_deck(deck_id: String) -> bool:
	if not AVAILABLE_DECKS.has(deck_id):
		push_warning("GameData: deck_id invalido '%s', usando %s" % [deck_id, DEFAULT_DECK_ID])
		selected_deck_id = DEFAULT_DECK_ID
		has_selected_deck_choice = false
		return false
	selected_deck_id = deck_id
	has_selected_deck_choice = true
	return true

func get_deck_path(deck_id: String) -> String:
	if AVAILABLE_DECKS.has(deck_id):
		return str(AVAILABLE_DECKS[deck_id].get("path", ""))
	return str(AVAILABLE_DECKS[DEFAULT_DECK_ID].get("path", ""))

func get_default_opponent_deck_id() -> String:
	return DEFAULT_OPPONENT_DECK_ID

func get_default_opponent_deck_path() -> String:
	return get_deck_path(DEFAULT_OPPONENT_DECK_ID)

func load_deck_data(deck_id: String) -> DeckData:
	var deck_path: String = get_deck_path(deck_id)
	if deck_path.is_empty():
		return null
	if _deck_cache.has(deck_path):
		return _deck_cache[deck_path] as DeckData

	var loaded: Resource = load(deck_path)
	if loaded is DeckData:
		var deck_data := loaded as DeckData
		_deck_cache[deck_path] = deck_data
		return deck_data

	push_error("GameData: falha ao carregar DeckData em %s" % deck_path)
	return null
