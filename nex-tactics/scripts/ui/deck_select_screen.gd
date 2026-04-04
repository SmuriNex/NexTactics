extends Control
class_name DeckSelectScreen

const MORDOS_ACCENT := Color(0.43, 0.73, 0.47, 1.0)
const THRAX_ACCENT := Color(0.88, 0.68, 0.28, 1.0)
const LADY_OF_LAKE_ACCENT := Color(0.35, 0.78, 0.93, 1.0)
const DEFAULT_ACCENT := Color(0.58, 0.66, 0.86, 1.0)

@onready var title_label: Label = $MarginContainer/CenterContainer/MainColumn/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/CenterContainer/MainColumn/SubtitleLabel
@onready var deck_grid: GridContainer = $MarginContainer/CenterContainer/MainColumn/DeckGrid

func _ready() -> void:
	title_label.text = "Escolha seu deck"
	subtitle_label.text = "Selecione um comandante para abrir a partida."
	_rebuild_deck_cards()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_grid_columns()

func _rebuild_deck_cards() -> void:
	for child in deck_grid.get_children():
		child.queue_free()

	for deck_entry in GameData.get_available_decks():
		deck_grid.add_child(_build_deck_card(deck_entry))

	_update_grid_columns()

func _build_deck_card(deck_entry: Dictionary) -> PanelContainer:
	var deck_id: String = str(deck_entry.get("id", ""))
	var display_name: String = str(deck_entry.get("display_name", "Deck"))
	var description: String = str(deck_entry.get("description", "Sem descricao."))
	var deck_variant: Variant = deck_entry.get("deck_data", null)
	var deck_data: DeckData = deck_variant as DeckData
	var master_name: String = _resolve_master_name(deck_data)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _build_panel_style(_accent_for_deck(deck_id)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var badge := Label.new()
	badge.text = deck_id.to_upper()
	badge.add_theme_font_size_override("font_size", 12)
	badge.modulate = _accent_for_deck(deck_id)
	content.add_child(badge)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 28)
	content.add_child(name_label)

	var master_label := Label.new()
	master_label.text = "Mestre: %s" % master_name
	master_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	master_label.modulate = Color(0.84, 0.86, 0.91, 1.0)
	content.add_child(master_label)

	var description_label := Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.modulate = Color(0.76, 0.79, 0.86, 1.0)
	content.add_child(description_label)

	var select_button := Button.new()
	select_button.text = "Selecionar"
	select_button.custom_minimum_size = Vector2(0.0, 42.0)
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.pressed.connect(_on_deck_selected.bind(deck_id))
	content.add_child(select_button)

	return panel

func _resolve_master_name(deck_data: DeckData) -> String:
	if deck_data == null or deck_data.master_data_path.is_empty():
		return "Sem mestre"

	var loaded: Resource = load(deck_data.master_data_path)
	if loaded is UnitData:
		var unit_data := loaded as UnitData
		if not unit_data.display_name.is_empty():
			return unit_data.display_name
	return "Sem mestre"

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

func _build_panel_style(accent_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent_color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 8
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style

func _update_grid_columns() -> void:
	if deck_grid == null:
		return
	var viewport_width: float = get_viewport_rect().size.x
	var deck_count: int = maxi(1, deck_grid.get_child_count())
	if viewport_width < 920.0:
		deck_grid.columns = 1
	elif viewport_width < 1380.0 or deck_count <= 2:
		deck_grid.columns = 2
	else:
		deck_grid.columns = mini(3, deck_count)

func _on_deck_selected(deck_id: String) -> void:
	GameData.set_selected_deck(deck_id)
	get_tree().change_scene_to_file(GameData.BATTLE_SCENE_PATH)
