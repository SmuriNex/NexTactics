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
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings_screen.tscn"

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
	"pt_BR": {
		DECK_ID_THRAX: {
			"menu_name": "Rei Thrax",
			"factions": "Humanos da coroa, maquina militar do reino e elite de conquista.",
			"playstyle": "Defesa frontal, linha de fogo, riqueza e supremacia humana.",
			"summary": "Um reino humano disciplinado que vence por formacoes organizadas, tiro coordenado e ouro convertido em poder militar.",
			"master_role": "Tanque real e ancora da linha de frente.",
			"master_identity": "Thrax transforma ouro guardado em ataque para a tropa, armadura para a coroa e chama todo o odio inimigo para si.",
		},
		DECK_ID_MORDOS: {
			"menu_name": "Mordos, o Necromante",
			"factions": "Mortos-vivos, ogros corrompidos e seguidores da necromancia.",
			"playstyle": "Sacrificio, mortes em cadeia, pressao agressiva e snowball necromantico.",
			"summary": "Mordos comanda uma hoste kamikaze que fica mais perigosa a cada queda, afoga o campo em esqueletos e acelera o caos.",
			"master_role": "Atacante humano e motor da escalada por mortes.",
			"master_identity": "Mordos e humano, mas usa mortos-vivos e ogros corrompidos como combustivel para transformar cada morte em forca imediata.",
		},
		DECK_ID_LADY_OF_LAKE: {
			"menu_name": "A Dama do Lago",
			"factions": "Fadas, elfos e corte encantada das aguas.",
			"playstyle": "Sustain, magia, protecao e controle de ritmo.",
			"summary": "Uma corte encantada que continua vencendo por sobreviver mais, proteger aliados chave e controlar o tempo da luta.",
			"master_role": "Mestra arcana de retaguarda e eixo de protecao da corte.",
			"master_identity": "A Dama do Lago ainda sustenta o time com magia, lentidao e protecao, mas agora suas curas exigem mais janela para decidir a luta.",
		},
	},
	"en": {
		DECK_ID_THRAX: {
			"menu_name": "King Thrax",
			"factions": "Crown humans, royal war machine, and conquest elites.",
			"playstyle": "Frontline defense, firing lines, wealth, and human supremacy.",
			"summary": "A disciplined human kingdom that wins through organized formations, coordinated ranged pressure, and gold turned into military power.",
			"master_role": "Royal tank and frontline anchor.",
			"master_identity": "Thrax turns saved gold into power for the army, extra armor for himself, and dares the whole enemy team to focus him.",
		},
		DECK_ID_MORDOS: {
			"menu_name": "Mordos the Necromancer",
			"factions": "Undead, corrupted ogres, and necromantic followers.",
			"playstyle": "Sacrifice, chain deaths, aggressive pressure, and necromantic snowball.",
			"summary": "Mordos commands a kamikaze host that gets stronger with every death, floods the board with skeletons, and thrives in chaos.",
			"master_role": "Human attacker and death-snowball engine.",
			"master_identity": "Mordos is human, but he treats undead and corrupted ogres as fuel, turning every death into immediate strength.",
		},
		DECK_ID_LADY_OF_LAKE: {
			"menu_name": "The Lady of the Lake",
			"factions": "Fairies, elves, and the enchanted water court.",
			"playstyle": "Sustain, magic, protection, and tempo control.",
			"summary": "An enchanted court that still wins by surviving longer, protecting key allies, and controlling the pace of battle.",
			"master_role": "Arcane backline master and protective axis of the court.",
			"master_identity": "The Lady of the Lake still sustains her team with magic, slow effects, and protection, but her healing now takes longer to swing a fight.",
		},
	},
	"es": {
		DECK_ID_THRAX: {
			"menu_name": "Rey Thrax",
			"factions": "Humanos de la corona, maquina militar del reino y elite de conquista.",
			"playstyle": "Defensa frontal, linea de fuego, riqueza y supremacia humana.",
			"summary": "Un reino humano disciplinado que gana con formaciones ordenadas, disparo coordinado y oro convertido en poder militar.",
			"master_role": "Tanque real y ancla de la primera linea.",
			"master_identity": "Thrax convierte el oro guardado en ataque para la tropa, armadura para la corona y atrae todo el odio enemigo hacia si.",
		},
		DECK_ID_MORDOS: {
			"menu_name": "Mordos el Nigromante",
			"factions": "No-muertos, ogros corruptos y seguidores de la nigromancia.",
			"playstyle": "Sacrificio, muertes en cadena, presion agresiva y snowball necromantico.",
			"summary": "Mordos dirige una horda kamikaze que se vuelve mas peligrosa con cada muerte, llena el campo de esqueletos y acelera el caos.",
			"master_role": "Atacante humano y motor de escalada por muertes.",
			"master_identity": "Mordos es humano, pero usa no-muertos y ogros corruptos como combustible para convertir cada muerte en fuerza inmediata.",
		},
		DECK_ID_LADY_OF_LAKE: {
			"menu_name": "La Dama del Lago",
			"factions": "Hadas, elfos y corte encantada de las aguas.",
			"playstyle": "Sustain, magia, proteccion y control del ritmo.",
			"summary": "Una corte encantada que sigue ganando por sobrevivir mas, proteger aliados clave y administrar el tiempo del combate.",
			"master_role": "Maestra arcana de retaguardia y eje protector de la corte.",
			"master_identity": "La Dama del Lago sigue sosteniendo al equipo con magia, lentitud y proteccion, pero ahora su curacion tarda mas en decidir la pelea.",
		},
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

func get_deck_presentation(deck_id: String, locale: String = "pt_BR") -> Dictionary:
	var locale_key: String = locale if DECK_PRESENTATION.has(locale) else "pt_BR"
	var locale_entries: Dictionary = DECK_PRESENTATION.get(locale_key, {})
	if locale_entries.has(deck_id):
		return (locale_entries[deck_id] as Dictionary).duplicate(true)
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
