extends Control
class_name DeckSelectScreen

const MORDOS_ACCENT := Color(0.53, 0.72, 0.44, 1.0)
const THRAX_ACCENT := Color(0.9, 0.7, 0.3, 1.0)
const LADY_OF_LAKE_ACCENT := Color(0.42, 0.8, 0.95, 1.0)
const DEFAULT_ACCENT := Color(0.7, 0.74, 0.86, 1.0)

@onready var back_button: Button = $MarginContainer/MainColumn/TopRow/BackButton
@onready var title_label: Label = $MarginContainer/MainColumn/TopRow/HeaderColumn/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/MainColumn/TopRow/HeaderColumn/SubtitleLabel
@onready var current_selection_label: Label = $MarginContainer/MainColumn/TopRow/CurrentSelectionPanel/MarginContainer/CurrentSelectionLabel
@onready var deck_list_title_label: Label = $MarginContainer/MainColumn/ContentRow/DeckListPanel/MarginContainer/DeckListColumn/DeckListTitleLabel
@onready var deck_list_subtitle_label: Label = $MarginContainer/MainColumn/ContentRow/DeckListPanel/MarginContainer/DeckListColumn/DeckListSubtitleLabel
@onready var deck_button_list: VBoxContainer = $MarginContainer/MainColumn/ContentRow/DeckListPanel/MarginContainer/DeckListColumn/DeckButtonList
@onready var deck_selection_status_label: Label = $MarginContainer/MainColumn/ContentRow/DeckListPanel/MarginContainer/DeckListColumn/DeckSelectionStatusLabel
@onready var overview_title_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/OverviewPanel/MarginContainer/OverviewColumn/OverviewTitleLabel
@onready var overview_body_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/OverviewPanel/MarginContainer/OverviewColumn/OverviewBodyLabel
@onready var master_title_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/InfoRow/MasterPanel/MarginContainer/MasterColumn/MasterTitleLabel
@onready var master_body_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/InfoRow/MasterPanel/MarginContainer/MasterColumn/MasterBodyLabel
@onready var how_to_title_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/InfoRow/HowToPanel/MarginContainer/HowToColumn/HowToTitleLabel
@onready var how_to_body_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/InfoRow/HowToPanel/MarginContainer/HowToColumn/HowToBodyLabel
@onready var units_title_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/ListsRow/UnitsPanel/MarginContainer/UnitsColumn/UnitsTitleLabel
@onready var units_list: VBoxContainer = $MarginContainer/MainColumn/ContentRow/DetailsColumn/ListsRow/UnitsPanel/MarginContainer/UnitsColumn/UnitsScroll/UnitsList
@onready var cards_title_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/ListsRow/CardsPanel/MarginContainer/CardsColumn/CardsTitleLabel
@onready var cards_list: VBoxContainer = $MarginContainer/MainColumn/ContentRow/DetailsColumn/ListsRow/CardsPanel/MarginContainer/CardsColumn/CardsScroll/CardsList
@onready var action_hint_label: Label = $MarginContainer/MainColumn/ContentRow/DetailsColumn/ActionRow/ActionHintLabel
@onready var select_button: Button = $MarginContainer/MainColumn/ContentRow/DetailsColumn/ActionRow/SelectButton

var _deck_button_group: ButtonGroup = ButtonGroup.new()
var _deck_buttons: Dictionary = {}
var _current_preview_deck_id: String = ""

func _ready() -> void:
	title_label.text = "DECK"
	subtitle_label.text = "Escolha um deck, entenda o Mestre e conheca suas unidades e cartas antes de iniciar a partida."
	deck_list_title_label.text = "Decks disponiveis"
	deck_list_subtitle_label.text = "Rei Thrax, Mordos, o Necromante, e A Dama do Lago."
	how_to_title_label.text = "Como funciona"
	how_to_body_label.text = "\n".join([
		"1. Escolha um deck e leve seu Mestre para a partida.",
		"2. No PREP, voce posiciona unidades, usa supports e administra espaco.",
		"3. O Mestre ganha XP, sobe de nivel, abre mais campo e libera promocoes durante a match.",
	])
	back_button.pressed.connect(_on_back_button_pressed)
	select_button.pressed.connect(_on_select_button_pressed)
	_build_deck_buttons()
	var initial_deck_id: String = GameData.get_selected_deck_id() if GameData.has_selected_deck() else _first_available_deck_id()
	_show_deck(initial_deck_id)

func _first_available_deck_id() -> String:
	var deck_ids: Array[String] = GameData.get_available_deck_ids()
	return deck_ids[0] if not deck_ids.is_empty() else GameData.DEFAULT_DECK_ID

func _build_deck_buttons() -> void:
	for child in deck_button_list.get_children():
		child.queue_free()
	_deck_buttons.clear()

	for deck_entry in GameData.get_available_decks():
		var deck_id: String = str(deck_entry.get("id", ""))
		var presentation: Dictionary = GameData.get_deck_presentation(deck_id)
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _deck_button_group
		button.custom_minimum_size = Vector2(0.0, 56.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_on_deck_button_pressed.bind(deck_id))
		deck_button_list.add_child(button)
		_deck_buttons[deck_id] = button
		button.text = str(presentation.get("menu_name", deck_entry.get("display_name", "Deck")))

func _show_deck(deck_id: String) -> void:
	_current_preview_deck_id = deck_id
	var deck_data: DeckData = GameData.load_deck_data(deck_id)
	if deck_data == null:
		return

	var presentation: Dictionary = GameData.get_deck_presentation(deck_id)
	var accent: Color = _accent_for_deck(deck_id)
	var master_data: UnitData = _load_unit_data(deck_data.master_data_path)

	overview_title_label.text = str(presentation.get("menu_name", deck_data.display_name))
	overview_title_label.modulate = accent
	overview_body_label.text = "\n".join([
		"Deck: %s" % deck_data.display_name,
		"Faccoes: %s" % str(presentation.get("factions", "Faccoes nao definidas.")),
		"Estilo: %s" % str(presentation.get("playstyle", "Estilo nao definido.")),
		"Resumo: %s" % str(presentation.get("summary", "Sem resumo.")),
	])

	var master_name: String = master_data.display_name if master_data != null else "Sem mestre"
	var master_role: String = str(presentation.get("master_role", "Mestre"))
	var master_identity: String = str(presentation.get("master_identity", ""))
	var master_skill_text: String = _resolve_master_identity_line(master_data)
	master_title_label.text = "Mestre: %s" % master_name
	master_body_label.text = "\n".join([
		"Papel: %s" % master_role,
		"Identidade: %s" % master_identity,
		"Habilidade/assinatura: %s" % master_skill_text,
		"Progressao: o Mestre e o centro do XP, da capacidade do campo e das promocoes da partida.",
	])

	units_title_label.text = "Unidades do deck"
	_rebuild_unit_entries(deck_data, accent)
	cards_title_label.text = "Cartas / supports"
	_rebuild_card_entries(deck_data, accent)
	_refresh_selection_state()
	_refresh_deck_buttons()

func _resolve_master_identity_line(master_data: UnitData) -> String:
	if master_data == null:
		return "Sem descricao."
	var description: String = master_data.description.strip_edges()
	if description.is_empty():
		return "Centro da progressao da partida."
	return description

func _rebuild_unit_entries(deck_data: DeckData, accent: Color) -> void:
	for child in units_list.get_children():
		child.queue_free()

	for unit_path in deck_data.unit_pool_paths:
		var unit_data: UnitData = _load_unit_data(unit_path)
		if unit_data == null:
			continue
		units_list.add_child(_build_detail_entry(
			unit_data.display_name,
			"%s | %s" % [_race_name(unit_data.race), _class_name(unit_data.class_type)],
			unit_data.description,
			accent
		))

func _rebuild_card_entries(deck_data: DeckData, accent: Color) -> void:
	for child in cards_list.get_children():
		child.queue_free()

	for card_path in deck_data.card_pool_paths:
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		cards_list.add_child(_build_detail_entry(
			card_data.display_name,
			"%s | Gratis na partida" % _card_label(card_data),
			card_data.description,
			accent
		))

func _build_detail_entry(title: String, subtitle: String, body: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title_label_local := Label.new()
	title_label_local.text = title
	title_label_local.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label_local.add_theme_font_size_override("font_size", 18)
	column.add_child(title_label_local)

	var subtitle_label_local := Label.new()
	subtitle_label_local.text = subtitle
	subtitle_label_local.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label_local.modulate = Color(0.78, 0.82, 0.89, 1.0)
	column.add_child(subtitle_label_local)

	var body_label_local := Label.new()
	body_label_local.text = _truncate(body.strip_edges(), 180)
	body_label_local.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label_local.modulate = Color(0.72, 0.76, 0.84, 1.0)
	column.add_child(body_label_local)

	return panel

func _refresh_selection_state() -> void:
	var has_selected_deck: bool = GameData.has_selected_deck()
	var is_current_selected: bool = has_selected_deck and GameData.get_selected_deck_id() == _current_preview_deck_id
	var selected_text: String = "Nenhum"
	if has_selected_deck:
		var selected_presentation: Dictionary = GameData.get_deck_presentation(GameData.get_selected_deck_id())
		selected_text = str(selected_presentation.get("menu_name", "Deck"))
	current_selection_label.text = "Selecionado: %s" % selected_text

	if is_current_selected:
		deck_selection_status_label.text = "Este deck ja esta pronto para PLAY."
		action_hint_label.text = "Volte para PLAY na tela inicial quando quiser iniciar a partida."
		select_button.text = "Deck selecionado"
		select_button.disabled = true
	else:
		deck_selection_status_label.text = "Selecione este deck para liberar PLAY na tela inicial."
		action_hint_label.text = "Confirme o deck aqui e depois use PLAY na tela inicial."
		select_button.text = "Selecionar este deck"
		select_button.disabled = false

func _refresh_deck_buttons() -> void:
	for deck_id in _deck_buttons.keys():
		var button: Button = _deck_buttons[deck_id]
		if button == null:
			continue
		var presentation: Dictionary = GameData.get_deck_presentation(deck_id)
		var base_text: String = str(presentation.get("menu_name", deck_id))
		var is_selected: bool = GameData.has_selected_deck() and GameData.get_selected_deck_id() == deck_id
		button.text = "%s%s" % [base_text, "  [SELECIONADO]" if is_selected else ""]
		button.button_pressed = deck_id == _current_preview_deck_id

func _load_unit_data(resource_path: String) -> UnitData:
	if resource_path.is_empty():
		return null
	var loaded: Resource = load(resource_path)
	return loaded as UnitData if loaded is UnitData else null

func _load_card_data(resource_path: String) -> CardData:
	if resource_path.is_empty():
		return null
	var loaded: Resource = load(resource_path)
	return loaded as CardData if loaded is CardData else null

func _card_label(card_data: CardData) -> String:
	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Suporte de vida"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN, GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return "Suporte de campo"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD, GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Suporte tatico"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF, GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER, GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return "Suporte de combate"
		_:
			return "Support"

func _race_name(race: int) -> String:
	match race:
		GameEnums.Race.HUMAN:
			return "Humano"
		GameEnums.Race.ELF:
			return "Elfo"
		GameEnums.Race.OGRE:
			return "Ogro"
		GameEnums.Race.FAIRY:
			return "Fada"
		GameEnums.Race.UNDEAD:
			return "Morto-vivo"
		GameEnums.Race.BEAST:
			return "Besta"
		_:
			return "Raca"

func _class_name(class_type: int) -> String:
	match class_type:
		GameEnums.ClassType.ATTACKER:
			return "Atacante"
		GameEnums.ClassType.TANK:
			return "Tanque"
		GameEnums.ClassType.SNIPER:
			return "Atirador"
		GameEnums.ClassType.SUPPORT:
			return "Suporte"
		GameEnums.ClassType.STEALTH:
			return "Furtivo"
		_:
			return "Classe"

func _truncate(text: String, max_length: int) -> String:
	var cleaned: String = text.strip_edges()
	if cleaned.length() <= max_length:
		return cleaned
	return "%s..." % cleaned.substr(0, max_length - 3)

func _accent_for_deck(deck_id: String) -> Color:
	match deck_id:
		GameData.DECK_ID_MORDOS:
			return MORDOS_ACCENT
		GameData.DECK_ID_THRAX:
			return THRAX_ACCENT
		GameData.DECK_ID_LADY_OF_LAKE:
			return LADY_OF_LAKE_ACCENT
		_:
			return DEFAULT_ACCENT

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(GameData.START_SCREEN_SCENE_PATH)

func _on_select_button_pressed() -> void:
	if _current_preview_deck_id.is_empty():
		return
	GameData.set_selected_deck(_current_preview_deck_id)
	_refresh_selection_state()
	_refresh_deck_buttons()

func _on_deck_button_pressed(deck_id: String) -> void:
	_show_deck(deck_id)
