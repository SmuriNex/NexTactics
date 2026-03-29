extends Node

const DECK_ID_MORDOS := "mordos"
const DECK_ID_THRAX := "thrax"
const DEFAULT_DECK_ID := DECK_ID_MORDOS
const DEFAULT_OPPONENT_DECK_ID := DECK_ID_MORDOS

const BATTLE_SCENE_PATH := "res://scenes/battle/battle_scene.tscn"
const DECK_SELECT_SCENE_PATH := "res://scenes/ui/deck_select_screen.tscn"

const AVAILABLE_DECK_ORDER: Array[String] = [
	DECK_ID_MORDOS,
	DECK_ID_THRAX,
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
}

var selected_deck_id: String = DEFAULT_DECK_ID
var has_selected_deck_choice: bool = false
var _deck_cache: Dictionary = {}

func get_available_decks() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for deck_id in AVAILABLE_DECK_ORDER:
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
