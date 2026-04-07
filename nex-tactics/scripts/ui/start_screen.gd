extends Control
class_name StartScreen

@onready var studio_label: Label = $BackgroundMargin/MainColumn/HeaderColumn/StudioLabel
@onready var title_label: Label = $BackgroundMargin/MainColumn/HeaderColumn/TitleLabel
@onready var subtitle_label: Label = $BackgroundMargin/MainColumn/HeaderColumn/SubtitleLabel
@onready var deck_status_title_label: Label = $BackgroundMargin/MainColumn/DeckStatusPanel/MarginContainer/DeckStatusColumn/DeckStatusTitleLabel
@onready var deck_name_label: Label = $BackgroundMargin/MainColumn/DeckStatusPanel/MarginContainer/DeckStatusColumn/DeckNameLabel
@onready var master_name_label: Label = $BackgroundMargin/MainColumn/DeckStatusPanel/MarginContainer/DeckStatusColumn/MasterNameLabel
@onready var deck_summary_label: Label = $BackgroundMargin/MainColumn/DeckStatusPanel/MarginContainer/DeckStatusColumn/DeckSummaryLabel
@onready var play_button: Button = $BackgroundMargin/MainColumn/ActionsRow/PlayButton
@onready var deck_button: Button = $BackgroundMargin/MainColumn/ActionsRow/DeckButton
@onready var menu_button: Button = $BackgroundMargin/MainColumn/ActionsRow/MenuButton
@onready var message_label: Label = $BackgroundMargin/MainColumn/MessageLabel

func _ready() -> void:
	studio_label.text = GameData.STUDIO_DISPLAY_NAME
	title_label.text = GameData.GAME_DISPLAY_NAME
	subtitle_label.text = "Auto-battler tatico local-first. Escolha um deck, domine o Mestre e leve sua coroa para a guerra."
	deck_status_title_label.text = "Deck Atual"
	play_button.pressed.connect(_on_play_button_pressed)
	deck_button.pressed.connect(_on_deck_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	_refresh_screen()

func _refresh_screen() -> void:
	var has_deck: bool = GameData.has_selected_deck()
	play_button.disabled = not has_deck
	play_button.tooltip_text = "" if has_deck else "Escolha um deck antes de iniciar."

	if not has_deck:
		deck_name_label.text = "Nenhum deck escolhido"
		master_name_label.text = "Abra DECK para conhecer os tres exercitos."
		deck_summary_label.text = "PLAY fica liberado assim que um deck for selecionado."
		message_label.text = "Escolha um deck antes de iniciar."
		return

	var deck_id: String = GameData.get_selected_deck_id()
	var deck_data: DeckData = GameData.get_selected_deck()
	var presentation: Dictionary = GameData.get_deck_presentation(deck_id)
	var master_name: String = _resolve_master_name(deck_data)
	deck_name_label.text = str(presentation.get("menu_name", deck_data.display_name))
	master_name_label.text = "Mestre: %s" % master_name
	deck_summary_label.text = "%s\n%s" % [
		str(presentation.get("factions", "")),
		str(presentation.get("summary", "")),
	]
	message_label.text = "PLAY inicia a partida com o deck escolhido."

func _resolve_master_name(deck_data: DeckData) -> String:
	if deck_data == null or deck_data.master_data_path.is_empty():
		return "Sem mestre"
	var loaded: Resource = load(deck_data.master_data_path)
	if loaded is UnitData:
		var unit_data := loaded as UnitData
		if not unit_data.display_name.is_empty():
			return unit_data.display_name
	return "Sem mestre"

func _on_play_button_pressed() -> void:
	if not GameData.has_selected_deck():
		message_label.text = "Escolha um deck antes de iniciar."
		return
	get_tree().change_scene_to_file(GameData.BATTLE_SCENE_PATH)

func _on_deck_button_pressed() -> void:
	get_tree().change_scene_to_file(GameData.DECK_SELECT_SCENE_PATH)

func _on_menu_button_pressed() -> void:
	message_label.text = "MENU: Em breve."
