extends CanvasLayer
class_name BattleHUD

const SupportCardWidgetScene := preload("res://scenes/ui/support_card_widget.tscn")
const SupportCardVisualsScript := preload("res://scripts/ui/support_card_visuals.gd")

# Presentation layer for the playable demo:
# This HUD serves the main local loop first, while observer, elimination and
# final-screen overlays remain secondary presentation concerns.

signal player_sidebar_entry_pressed(player_id: String)
signal return_to_local_board_pressed
signal card_shop_option_selected(card_path: String)
signal elimination_watch_requested
signal elimination_back_requested
signal play_again_requested
signal master_promotion_drag_started(screen_pos: Vector2)
signal master_promotion_drag_moved(screen_pos: Vector2)
signal master_promotion_drag_released(screen_pos: Vector2)
signal master_promotion_drag_canceled
signal support_sidebar_card_pressed(slot_index: int)
signal support_sidebar_card_right_clicked(slot_index: int)


@onready var round_label: Label = $PanelContainer/MarginContainer/VBoxContainer/RoundLabel
@onready var player_life_label: Label = $PanelContainer/MarginContainer/VBoxContainer/PlayerLifeLabel
@onready var gold_label: Label = $PanelContainer/MarginContainer/VBoxContainer/GoldLabel
@onready var state_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StateLabel
@onready var opponent_label: Label = $PanelContainer/MarginContainer/VBoxContainer/OpponentLabel
@onready var status_panel_container: PanelContainer = $PanelContainer
@onready var observer_banner_panel_container: PanelContainer = $ObserverBannerPanelContainer
@onready var observer_banner_label: Label = $ObserverBannerPanelContainer/MarginContainer/HBoxContainer/ObserverBannerLabel
@onready var observer_return_button: Button = $ObserverBannerPanelContainer/MarginContainer/HBoxContainer/ObserverReturnButton
@onready var support_sidebar_panel_container: PanelContainer = $SupportSidebarPanelContainer
@onready var support_sidebar_title_label: Label = $SupportSidebarPanelContainer/MarginContainer/VBoxContainer/SupportSidebarTitleLabel
@onready var support_sidebar_subtitle_label: Label = $SupportSidebarPanelContainer/MarginContainer/VBoxContainer/SupportSidebarSubtitleLabel
@onready var support_sidebar_cards_vbox: VBoxContainer = $SupportSidebarPanelContainer/MarginContainer/VBoxContainer/SupportSidebarScroll/SupportSidebarCardsVBox
@onready var info_panel_container: PanelContainer = $InfoPanelContainer
@onready var unit_info_title_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/HeaderPanel/MarginContainer/VBoxContainer/HeaderRow/UnitInfoTitleLabel
@onready var unit_info_cost_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/HeaderPanel/MarginContainer/VBoxContainer/HeaderRow/UnitInfoCostLabel
@onready var unit_info_subtitle_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/HeaderPanel/MarginContainer/VBoxContainer/UnitInfoSubtitleLabel
@onready var primary_section_title_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/PrimarySectionPanel/MarginContainer/VBoxContainer/PrimarySectionTitleLabel
@onready var primary_block_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/PrimarySectionPanel/MarginContainer/VBoxContainer/PrimaryBlockLabel
@onready var stats_section_title_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/StatsSectionPanel/MarginContainer/VBoxContainer/StatsSectionTitleLabel
@onready var stats_block_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/StatsSectionPanel/MarginContainer/VBoxContainer/StatsBlockLabel
@onready var skill_section_title_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/SkillSectionPanel/MarginContainer/VBoxContainer/SkillSectionTitleLabel
@onready var skill_block_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/SkillSectionPanel/MarginContainer/VBoxContainer/SkillBlockLabel
@onready var tags_section_title_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/TagsSectionPanel/MarginContainer/VBoxContainer/TagsSectionTitleLabel
@onready var tags_block_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/TagsSectionPanel/MarginContainer/VBoxContainer/TagsBlockLabel
@onready var player_sidebar_panel_container: PanelContainer = $PlayerSidebarPanelContainer
@onready var player_sidebar_list: VBoxContainer = $PlayerSidebarPanelContainer/MarginContainer/VBoxContainer/PlayersListVBox
@onready var card_shop_overlay: Control = $CardShopOverlay
@onready var card_shop_title_label: Label = $CardShopOverlay/CenterContainer/ShopPanel/MarginContainer/VBoxContainer/CardShopTitleLabel
@onready var card_shop_subtitle_label: Label = $CardShopOverlay/CenterContainer/ShopPanel/MarginContainer/VBoxContainer/CardShopSubtitleLabel
@onready var card_shop_card_a: SupportCardWidget = $CardShopOverlay/CenterContainer/ShopPanel/MarginContainer/VBoxContainer/CardShopOptionsRow/CardShopOptionCardA
@onready var card_shop_card_b: SupportCardWidget = $CardShopOverlay/CenterContainer/ShopPanel/MarginContainer/VBoxContainer/CardShopOptionsRow/CardShopOptionCardB
@onready var master_promotion_token: MasterPromotionToken = $MasterPromotionToken

var card_shop_option_paths: Array[String] = []
var elimination_overlay: Control = null
var elimination_placement_label: Label = null
var elimination_watch_button: Button = null
var elimination_back_button: Button = null
var final_overlay: Control = null
var final_placement_label: Label = null
var final_ranking_label: Label = null
var final_winner_label: Label = null
var final_stats_label: Label = null
var final_play_again_button: Button = null
var support_sidebar_widgets: Array[SupportCardWidget] = []
var support_sidebar_has_cards: bool = false

func _ready() -> void:
	_ensure_phase8_overlays()
	observer_return_button.text = AppText.text("hud.return_board")
	if observer_return_button != null:
		observer_return_button.pressed.connect(_on_observer_return_button_pressed)
	if card_shop_card_a != null:
		card_shop_card_a.pressed.connect(_on_card_shop_option_pressed.bind(0))
	if card_shop_card_b != null:
		card_shop_card_b.pressed.connect(_on_card_shop_option_pressed.bind(1))
	if master_promotion_token != null:
		master_promotion_token.drag_started.connect(_on_master_promotion_token_drag_started)
		master_promotion_token.drag_moved.connect(_on_master_promotion_token_drag_moved)
		master_promotion_token.drag_released.connect(_on_master_promotion_token_drag_released)
		master_promotion_token.drag_canceled.connect(_on_master_promotion_token_drag_canceled)
	clear_unit_info()
	clear_support_sidebar()
	clear_observer_banner()
	update_player_sidebar([])
	hide_card_shop()
	hide_elimination_screen()
	hide_final_screen()
	hide_master_promotion_token()

func update_status(
	round_number: int,
	player_life: int,
	gold_value: int,
	last_income_total: int,
	state_name: String,
	opponent_name: String,
	master_status_text: String = "",
	progression_feedback_text: String = ""
) -> void:
	round_label.text = AppText.text("hud.round", {"round": round_number})
	player_life_label.text = AppText.text("hud.life", {"value": player_life})
	if not master_status_text.is_empty():
		player_life_label.text += "\n%s" % master_status_text
	if last_income_total > 0:
		gold_label.text = AppText.text("hud.gold_income", {"value": gold_value, "income": last_income_total})
	else:
		gold_label.text = AppText.text("hud.gold", {"value": gold_value})
	state_label.text = AppText.text("hud.state", {"value": state_name})
	if not progression_feedback_text.is_empty():
		state_label.text += "\n%s" % progression_feedback_text
	opponent_label.text = AppText.text("hud.opponent", {"value": opponent_name})

func update_unit_info(unit_state: BattleUnitState) -> void:
	if unit_state == null or unit_state.unit_data == null:
		clear_unit_info()
		return
	info_panel_container.visible = true
	_sync_right_side_panels()
	_set_default_section_titles()

	var title_text: String = unit_state.get_display_name()
	if unit_state.is_master:
		title_text += " [MESTRE]"
	var active_skill: Dictionary = _active_skill_info(unit_state)
	var cost_text: String = "Mana %d" % int(active_skill.get("mana_cost", 0)) if bool(active_skill.get("available", false)) else "Sem ativa"
	var subtitle_text: String = "Raca: %s" % unit_state.get_race_name()

	_set_info_blocks(
		title_text,
		cost_text,
		subtitle_text,
		_join_strings(_build_primary_lines(unit_state), "\n"),
		_join_strings(_build_stats_lines(unit_state), "\n"),
		_join_strings(_build_skill_lines(unit_state), "\n"),
		_join_strings(_build_tag_lines(unit_state), "\n")
	)

func update_card_info(card_data: CardData) -> void:
	if card_data == null:
		clear_unit_info()
		return
	info_panel_container.visible = true
	_sync_right_side_panels()
	_set_default_section_titles()

	var primary_lines: Array[String] = [
		"Tipo: %s" % _support_card_type_name(card_data),
		"Alvo: %s" % _support_target_name(card_data.support_effect_type),
	]
	var stats_lines: Array[String] = _build_support_stats_lines(card_data)
	var skill_lines: Array[String] = [
		"Descricao: %s" % _translated_card_description(card_data),
	]
	var tags_lines: Array[String] = [
		"Tags: CARTA, PREPARO",
		"Uso: %s" % _support_card_usage_text(card_data),
	]

	_set_info_blocks(
		card_data.display_name,
		"Gratis",
		"CARTA | %s" % _support_card_type_name(card_data),
		_join_strings(primary_lines, "\n"),
		_join_strings(stats_lines, "\n"),
		_join_strings(skill_lines, "\n"),
		_join_strings(tags_lines, "\n")
	)

func update_observed_board(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		clear_observer_banner()
		return

	var player_name: String = str(snapshot.get("player_name", AppText.text("match.default_player")))
	var opponent_name: String = str(snapshot.get("opponent_name", ""))
	if opponent_name.is_empty():
		set_observer_banner(AppText.text("hud.observing", {"name": player_name}))
		return
	set_observer_banner(AppText.text("hud.observing_vs", {"name_a": player_name, "name_b": opponent_name}))

func set_observer_banner(text: String) -> void:
	if observer_banner_panel_container == null or observer_banner_label == null:
		return
	var resolved_text: String = text.strip_edges()
	if resolved_text.is_empty():
		clear_observer_banner()
		return
	observer_banner_label.text = resolved_text
	observer_banner_panel_container.visible = true

func clear_observer_banner() -> void:
	if observer_banner_panel_container == null or observer_banner_label == null:
		return
	observer_banner_label.text = AppText.text("hud.observing_empty")
	observer_banner_panel_container.visible = false

func clear_unit_info() -> void:
	info_panel_container.visible = false
	_set_default_section_titles()
	unit_info_title_label.text = AppText.text("hud.unit_info_title")
	unit_info_cost_label.text = AppText.text("hud.unit_info_cost")
	unit_info_subtitle_label.text = AppText.text("hud.unit_info_subtitle")
	primary_block_label.text = "-"
	stats_block_label.text = "-"
	skill_block_label.text = "-"
	tags_block_label.text = "-"
	_sync_right_side_panels()

func clear_support_sidebar() -> void:
	support_sidebar_has_cards = false
	_ensure_support_sidebar_widget_count(0)
	if support_sidebar_title_label != null:
		support_sidebar_title_label.text = AppText.text("hud.supports_title")
	if support_sidebar_subtitle_label != null:
		support_sidebar_subtitle_label.text = AppText.text("hud.supports_subtitle")
	_sync_right_side_panels()

func update_support_sidebar(slot_data: Array[Dictionary], selected_slot_index: int) -> void:
	support_sidebar_has_cards = not slot_data.is_empty()
	_ensure_support_sidebar_widget_count(slot_data.size())
	for index in range(slot_data.size()):
		_update_support_sidebar_card(index, slot_data[index], selected_slot_index)
	_sync_right_side_panels()

func is_over_hud(global_pos: Vector2) -> bool:
	if elimination_overlay != null and elimination_overlay.visible:
		return true
	if final_overlay != null and final_overlay.visible:
		return true
	if card_shop_overlay != null and card_shop_overlay.visible:
		return true
	if master_promotion_token != null and master_promotion_token.visible:
		if master_promotion_token.get_global_rect().has_point(global_pos):
			return true
	if status_panel_container.get_global_rect().has_point(global_pos):
		return true
	if observer_banner_panel_container != null and observer_banner_panel_container.visible:
		if observer_banner_panel_container.get_global_rect().has_point(global_pos):
			return true
	if player_sidebar_panel_container.get_global_rect().has_point(global_pos):
		return true
	if support_sidebar_panel_container != null and support_sidebar_panel_container.visible:
		if support_sidebar_panel_container.get_global_rect().has_point(global_pos):
			return true
	if info_panel_container.visible and info_panel_container.get_global_rect().has_point(global_pos):
		return true
	return false

func is_info_panel_open() -> bool:
	return info_panel_container.visible

func is_card_shop_open() -> bool:
	return card_shop_overlay != null and card_shop_overlay.visible

func show_card_shop(round_number: int, option_entries: Array[Dictionary]) -> void:
	if card_shop_overlay == null:
		return
	card_shop_overlay.visible = true
	card_shop_option_paths.clear()
	card_shop_title_label.text = AppText.text("hud.card_shop_title", {"round": round_number})
	card_shop_subtitle_label.text = AppText.text("hud.card_shop_subtitle")
	_set_card_shop_card(card_shop_card_a, option_entries, 0)
	_set_card_shop_card(card_shop_card_b, option_entries, 1)
	_sync_right_side_panels()

func hide_card_shop() -> void:
	if card_shop_overlay == null:
		return
	card_shop_overlay.visible = false
	card_shop_option_paths.clear()
	if card_shop_card_a != null:
		card_shop_card_a.visible = false
	if card_shop_card_b != null:
		card_shop_card_b.visible = false
	_sync_right_side_panels()

func set_master_promotion_token_state(
	is_visible: bool,
	pending_count: int,
	interaction_enabled: bool,
	instruction_text: String
) -> void:
	if master_promotion_token == null:
		return
	master_promotion_token.set_token_state(
		is_visible,
		pending_count,
		interaction_enabled,
		instruction_text
	)

func set_master_promotion_drag_feedback(drop_valid: bool, hover_text: String = "") -> void:
	if master_promotion_token == null:
		return
	master_promotion_token.set_drag_feedback(drop_valid, hover_text)

func cancel_master_promotion_drag() -> void:
	if master_promotion_token == null:
		return
	master_promotion_token.cancel_drag()

func hide_master_promotion_token() -> void:
	if master_promotion_token == null:
		return
	master_promotion_token.hide_token()

func is_master_promotion_drag_active() -> bool:
	return master_promotion_token != null and master_promotion_token.is_drag_active()

func is_elimination_screen_open() -> bool:
	return elimination_overlay != null and elimination_overlay.visible

func is_final_screen_open() -> bool:
	return final_overlay != null and final_overlay.visible

func show_elimination_screen(placement_text: String) -> void:
	_ensure_phase8_overlays()
	hide_final_screen()
	if elimination_placement_label != null:
		elimination_placement_label.text = AppText.text("hud.placement", {"value": placement_text})
	if elimination_overlay != null:
		elimination_overlay.visible = true

func hide_elimination_screen() -> void:
	if elimination_overlay != null:
		elimination_overlay.visible = false

func show_final_screen(
	placement_text: String,
	ranking_lines: Array[String],
	winner_unit_lines: Array[String],
	total_damage: int,
	winner_name: String
) -> void:
	_ensure_phase8_overlays()
	hide_elimination_screen()
	if final_placement_label != null:
		final_placement_label.text = AppText.text("hud.placement", {"value": placement_text})
	if final_ranking_label != null:
		var ranking_text: String = _join_strings(ranking_lines, "\n")
		if ranking_text.is_empty():
			ranking_text = AppText.text("hud.ranking_unavailable")
		final_ranking_label.text = AppText.text("hud.ranking_full", {"value": ranking_text})
	if final_winner_label != null:
		var winner_text: String = _join_strings(winner_unit_lines, "\n")
		if winner_text.is_empty():
			winner_text = AppText.text("hud.winner_unavailable")
		final_winner_label.text = AppText.text("hud.winner_units", {"name": winner_name, "value": winner_text})
	if final_stats_label != null:
		final_stats_label.text = AppText.text("hud.total_damage", {"value": total_damage})
	if final_overlay != null:
		final_overlay.visible = true

func hide_final_screen() -> void:
	if final_overlay != null:
		final_overlay.visible = false

func _ensure_phase8_overlays() -> void:
	if elimination_overlay != null and final_overlay != null:
		return

	elimination_overlay = _build_fullscreen_overlay("EliminationOverlay")
	var elimination_vbox: VBoxContainer = _build_overlay_panel(elimination_overlay, Vector2(560.0, 250.0))
	elimination_vbox.add_child(_build_overlay_label(AppText.text("hud.eliminated_title"), 24, HORIZONTAL_ALIGNMENT_CENTER, true))
	elimination_placement_label = _build_overlay_label(AppText.text("hud.placement", {"value": "Top -"}), 17, HORIZONTAL_ALIGNMENT_CENTER, true)
	elimination_vbox.add_child(elimination_placement_label)
	elimination_vbox.add_child(_build_overlay_label(AppText.text("hud.eliminated_body"), 12, HORIZONTAL_ALIGNMENT_CENTER, true))
	var elimination_buttons := HBoxContainer.new()
	elimination_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	elimination_buttons.add_theme_constant_override("separation", 10)
	elimination_vbox.add_child(elimination_buttons)
	elimination_watch_button = Button.new()
	elimination_watch_button.text = AppText.text("hud.watch_to_end")
	elimination_watch_button.focus_mode = Control.FOCUS_NONE
	elimination_watch_button.pressed.connect(_on_elimination_watch_button_pressed)
	elimination_buttons.add_child(elimination_watch_button)
	elimination_back_button = Button.new()
	elimination_back_button.text = AppText.text("hud.return_start")
	elimination_back_button.focus_mode = Control.FOCUS_NONE
	elimination_back_button.pressed.connect(_on_elimination_back_button_pressed)
	elimination_buttons.add_child(elimination_back_button)
	add_child(elimination_overlay)

	final_overlay = _build_fullscreen_overlay("FinalOverlay")
	var final_vbox: VBoxContainer = _build_overlay_panel(final_overlay, Vector2(820.0, 520.0))
	final_vbox.add_child(_build_overlay_label(AppText.text("hud.match_end"), 24, HORIZONTAL_ALIGNMENT_CENTER, true))
	final_placement_label = _build_overlay_label(AppText.text("hud.placement", {"value": "Top -"}), 17, HORIZONTAL_ALIGNMENT_CENTER, true)
	final_vbox.add_child(final_placement_label)
	final_ranking_label = _build_overlay_label(AppText.text("hud.ranking_full", {"value": ""}).strip_edges(), 12, HORIZONTAL_ALIGNMENT_LEFT, true)
	final_ranking_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	final_vbox.add_child(final_ranking_label)
	final_winner_label = _build_overlay_label(AppText.text("hud.winner_units", {"name": "-", "value": ""}).strip_edges(), 12, HORIZONTAL_ALIGNMENT_LEFT, true)
	final_winner_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	final_vbox.add_child(final_winner_label)
	final_stats_label = _build_overlay_label(AppText.text("hud.total_damage", {"value": 0}), 12, HORIZONTAL_ALIGNMENT_LEFT, true)
	final_vbox.add_child(final_stats_label)
	final_play_again_button = Button.new()
	final_play_again_button.text = AppText.text("hud.play_again")
	final_play_again_button.focus_mode = Control.FOCUS_NONE
	final_play_again_button.custom_minimum_size = Vector2(0.0, 38.0)
	final_play_again_button.pressed.connect(_on_final_play_again_button_pressed)
	final_vbox.add_child(final_play_again_button)
	add_child(final_overlay)

func _build_fullscreen_overlay(node_name: String) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false

	var dimmer := ColorRect.new()
	dimmer.anchor_right = 1.0
	dimmer.anchor_bottom = 1.0
	dimmer.offset_right = 0.0
	dimmer.offset_bottom = 0.0
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.add_child(dimmer)
	return overlay

func _build_overlay_panel(overlay: Control, minimum_size: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	return vbox

func _build_overlay_label(text_value: String, font_size: int, alignment: HorizontalAlignment, wrap_text: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap_text else TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func update_player_sidebar(entries: Array[Dictionary]) -> void:
	if player_sidebar_list == null:
		return

	for child in player_sidebar_list.get_children():
		player_sidebar_list.remove_child(child)
		child.queue_free()

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Nenhum jogador carregado."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		player_sidebar_list.add_child(empty_label)
		return

	for entry in entries:
		var row_button := Button.new()
		row_button.text = _format_player_sidebar_entry(entry)
		row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_button.custom_minimum_size = Vector2(0.0, 28.0)
		row_button.flat = true
		row_button.focus_mode = Control.FOCUS_NONE
		row_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_button.add_theme_font_size_override("font_size", 12)
		row_button.add_theme_color_override("font_color", _player_sidebar_color(entry))
		row_button.pressed.connect(_on_player_sidebar_button_pressed.bind(str(entry.get("player_id", ""))))
		player_sidebar_list.add_child(row_button)

func _ensure_support_sidebar_widget_count(slot_count: int) -> void:
	while support_sidebar_widgets.size() > slot_count:
		var index := support_sidebar_widgets.size() - 1
		support_sidebar_widgets[index].queue_free()
		support_sidebar_widgets.remove_at(index)

	while support_sidebar_widgets.size() < slot_count:
		var widget := SupportCardWidgetScene.instantiate() as SupportCardWidget
		widget.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		widget.pressed.connect(_on_support_sidebar_card_pressed.bind(support_sidebar_widgets.size()))
		widget.right_clicked.connect(_on_support_sidebar_card_right_clicked.bind(support_sidebar_widgets.size()))
		support_sidebar_cards_vbox.add_child(widget)
		support_sidebar_widgets.append(widget)

func _update_support_sidebar_card(slot_index: int, data: Dictionary, selected_slot_index: int) -> void:
	if slot_index < 0 or slot_index >= support_sidebar_widgets.size():
		return

	var status: String = str(data.get("status", "UNAVAILABLE"))
	var state_kind: String = "ready"
	var state_label: String = AppText.text("deploy.support_available")
	var reason_text: String = str(data.get("reason", ""))
	if status == "AUTO":
		state_kind = "auto"
		state_label = AppText.text("support.footer_auto")
	elif status == "USED":
		state_kind = "used"
		state_label = AppText.text("deploy.support_used")
	elif selected_slot_index == slot_index:
		state_kind = "selected"
		state_label = AppText.text("deploy.support_selected")
	elif status == "READY":
		state_kind = "ready"
		state_label = AppText.text("deploy.support_available")
	else:
		state_kind = "unavailable"
		state_label = AppText.text("deploy.support_unavailable")

	var compact_hint: String = ""
	if state_kind == "unavailable" and not reason_text.is_empty():
		compact_hint = reason_text
	elif state_kind == "auto":
		compact_hint = _auto_support_runtime_hint(data.get("card_data", null) as CardData)

	var view_data: Dictionary = SupportCardVisualsScript.build_view_data(
		data.get("card_data", null) as CardData,
		state_label,
		state_kind,
		true,
		compact_hint
	)
	support_sidebar_widgets[slot_index].configure(view_data)
	support_sidebar_widgets[slot_index].visible = true

func _sync_right_side_panels() -> void:
	if info_panel_container == null or support_sidebar_panel_container == null:
		return
	var can_show_supports: bool = support_sidebar_has_cards and not info_panel_container.visible and not is_card_shop_open()
	support_sidebar_panel_container.visible = can_show_supports

func _set_card_shop_card(widget: SupportCardWidget, option_entries: Array[Dictionary], index: int) -> void:
	if widget == null:
		return
	if index < 0 or index >= option_entries.size():
		widget.visible = false
		return

	var option_entry: Dictionary = option_entries[index]
	var card_data: CardData = option_entry.get("card_data", null)
	var card_path: String = str(option_entry.get("card_path", ""))
	widget.visible = true
	if card_shop_option_paths.size() <= index:
		card_shop_option_paths.resize(index + 1)
	card_shop_option_paths[index] = card_path

	if card_data == null:
		widget.configure(SupportCardVisualsScript.build_view_data(
			null,
			AppText.text("deploy.support_unavailable"),
			"unavailable",
			false
		))
		return

	var view_data: Dictionary = SupportCardVisualsScript.build_view_data(
		card_data,
		AppText.text("hud.click_to_choose"),
		"shop",
		false,
		AppText.text("hud.free_short")
	)
	widget.configure(view_data)

func _set_default_section_titles() -> void:
	primary_section_title_label.text = AppText.text("hud.section_unit")
	stats_section_title_label.text = AppText.text("hud.section_stats")
	skill_section_title_label.text = AppText.text("hud.section_skill")
	tags_section_title_label.text = AppText.text("hud.section_effects")

func _set_info_blocks(
	title_text: String,
	cost_text: String,
	subtitle_text: String,
	primary_text: String,
	stats_text: String,
	skill_text: String,
	tags_text: String
) -> void:
	unit_info_title_label.text = title_text
	unit_info_cost_label.text = cost_text
	unit_info_subtitle_label.text = subtitle_text
	primary_block_label.text = primary_text
	stats_block_label.text = stats_text
	skill_block_label.text = skill_text
	tags_block_label.text = tags_text

func _build_primary_lines(unit_state: BattleUnitState) -> Array[String]:
	var lines: Array[String] = [
		"Raca: %s" % unit_state.get_race_name(),
		"Classe: %s" % unit_state.get_class_name(),
		_format_stat_breakdown_line("Alcance", unit_state.get_attack_range_breakdown()),
	]
	var active_skill: Dictionary = _active_skill_info(unit_state)
	if bool(active_skill.get("available", false)):
		lines.append("Mana para ativar: %d" % int(active_skill.get("mana_cost", 0)))
	else:
		lines.append("Mana para ativar: sem habilidade de mana")
	return lines

func _build_stats_lines(unit_state: BattleUnitState) -> Array[String]:
	return [
		_format_stat_breakdown_line("Vida", unit_state.get_max_hp_breakdown()),
		_format_stat_breakdown_line("ATQ fisico", unit_state.get_physical_attack_breakdown()),
		_format_stat_breakdown_line("ATQ magico", unit_state.get_magic_attack_breakdown()),
		_format_stat_breakdown_line("DEF fisica", unit_state.get_physical_defense_breakdown()),
		_format_stat_breakdown_line("DEF magica", unit_state.get_magic_defense_breakdown()),
	]

func _build_skill_lines(unit_state: BattleUnitState) -> Array[String]:
	var lines: Array[String] = []
	var active_skill: Dictionary = _active_skill_info(unit_state)
	if unit_state.is_master:
		var piece_passive: Dictionary = _piece_passive_info(unit_state)
		lines.append("Passiva de Mestre: %s" % str(piece_passive.get("name", "Sem passiva exclusiva")))
		lines.append(str(piece_passive.get("description", "Esta unidade usa os efeitos base do kit.")))

	if bool(active_skill.get("available", false)):
		lines.append("Ativa: %s" % str(active_skill.get("name", "Habilidade ativa")))
		lines.append("Descricao: %s" % str(active_skill.get("description", "Ativa um efeito especial de combate.")))
		lines.append("Mana para ativar: %d | Alcance da habilidade: %d" % [
			int(active_skill.get("mana_cost", 0)),
			int(active_skill.get("range", 1)),
		])
		var target_text: String = str(active_skill.get("target_text", ""))
		if not target_text.is_empty():
			lines.append("Uso: %s" % target_text)
	else:
		lines.append("Ativa: esta peca nao usa habilidade separada de mana.")

	return lines

func _build_tag_lines(unit_state: BattleUnitState) -> Array[String]:
	var lines: Array[String] = []
	var active_effects: Array[Dictionary] = unit_state.get_active_effect_entries()
	for effect_entry in active_effects:
		lines.append(_format_active_effect_line(effect_entry))
	var support_sources: Array[Dictionary] = unit_state.get_active_support_sources()
	if not support_sources.is_empty():
		var support_parts: Array[String] = []
		for support_entry in support_sources:
			support_parts.append(_format_support_influence_source(support_entry))
		lines.append("Supports ligados: %s" % _join_strings(support_parts))
	if unit_state.has_permanent_stat_bonus():
		lines.append("Bonus permanente: %s" % unit_state.get_permanent_stat_bonus_text())
	if lines.is_empty():
		lines.append("Sem efeitos ativos relevantes no momento.")
	return lines

func _format_active_effect_line(effect_entry: Dictionary) -> String:
	var parts: Array[String] = [
		_effect_kind_label(str(effect_entry.get("kind", "special"))),
		str(effect_entry.get("name", "Efeito")),
	]
	var intensity: String = str(effect_entry.get("intensity", ""))
	if not intensity.is_empty():
		parts.append(intensity)
	var duration_text: String = str(effect_entry.get("duration", ""))
	if not duration_text.is_empty():
		parts.append(duration_text)
	return _join_strings(parts, " | ")

func _effect_kind_label(kind: String) -> String:
	match kind:
		"buff":
			return "BUFF"
		"debuff":
			return "DEBUFF"
		_:
			return "STATUS"

func _format_support_influence_source(source_entry: Dictionary) -> String:
	var source_kind: String = str(source_entry.get("source_kind", "")).strip_edges()
	var source_name: String = str(source_entry.get("source_name", "")).strip_edges()
	if source_kind.is_empty():
		return source_name
	if source_name.is_empty():
		return source_kind
	return "%s | %s" % [source_kind, source_name]

func _format_stat_breakdown_line(label: String, breakdown: Dictionary) -> String:
	var base_value: int = int(breakdown.get("base", 0))
	var bonus_total: int = int(breakdown.get("bonus", 0))
	var penalty_total: int = int(breakdown.get("penalty", 0))
	var suffix: String = ""
	if bonus_total > 0:
		suffix += "+%d" % bonus_total
	if penalty_total > 0:
		suffix += "-%d" % penalty_total
	return "%s: %d%s" % [label, base_value, suffix]

func _build_positive_effect_lines(unit_state: BattleUnitState) -> Array[String]:
	var lines: Array[String] = []
	if unit_state.current_physical_shield > 0:
		lines.append("Escudo fisico %d" % unit_state.current_physical_shield)
	if unit_state.current_magic_shield > 0:
		lines.append("Escudo magico %d" % unit_state.current_magic_shield)
	if unit_state.is_stealthed():
		lines.append("Furtividade")
	if unit_state.get_lifesteal_ratio() > 0.0:
		lines.append("Roubo de vida %d%%" % int(round(unit_state.get_lifesteal_ratio() * 100.0)))
	if unit_state.attack_range_bonus_status > 0:
		lines.append("Alcance +%d" % unit_state.attack_range_bonus_status)
	if unit_state.mana_gain_multiplier_status > 1.0:
		lines.append("Mana +%d%%" % int(round((unit_state.mana_gain_multiplier_status - 1.0) * 100.0)))
	if unit_state.death_mana_ratio_to_master > 0.0:
		lines.append("Pacto de sangue")
	if unit_state.blocked_basic_attack_count > 0:
		lines.append("Bloqueio %d" % unit_state.blocked_basic_attack_count)
	if unit_state.cleave_attacks_remaining > 0:
		lines.append("Cleave %d" % unit_state.cleave_attacks_remaining)
	return lines

func _build_negative_effect_lines(unit_state: BattleUnitState) -> Array[String]:
	var lines: Array[String] = []
	if unit_state.physical_defense_multiplier_status < 1.0:
		lines.append("DEF F %d%%" % int(round(unit_state.physical_defense_multiplier_status * 100.0)))
	if unit_state.magic_defense_multiplier_status < 1.0:
		lines.append("DEF M %d%%" % int(round(unit_state.magic_defense_multiplier_status * 100.0)))
	if unit_state.mana_gain_multiplier_status < 1.0:
		lines.append("Mana %d%%" % int(round(unit_state.mana_gain_multiplier_status * 100.0)))
	if unit_state.action_charge_multiplier_status < 1.0:
		lines.append("Ritmo %d%%" % int(round(unit_state.action_charge_multiplier_status * 100.0)))
	if unit_state.physical_miss_chance_status > 0.0:
		lines.append("Falha F %d%%" % int(round(unit_state.physical_miss_chance_status * 100.0)))
	if unit_state.get_received_physical_damage_multiplier() > 1.0:
		lines.append("Dano F x%.2f" % unit_state.get_received_physical_damage_multiplier())
	if unit_state.has_turn_skip():
		lines.append("Pula %d" % unit_state.skip_turns_remaining)
	if unit_state.is_charmed():
		lines.append("Encantado")
	if unit_state.has_forced_target():
		lines.append("Provocado")
	return lines

func _piece_passive_info(unit_state: BattleUnitState) -> Dictionary:
	if unit_state == null or unit_state.unit_data == null:
		return {
			"name": "Sem passiva exclusiva",
			"description": "Esta unidade joga pelo kit base e pela habilidade ativa.",
		}
	if unit_state.is_summoned_token:
		return {
			"name": "Servo invocado",
			"description": "Unidade temporaria criada por habilidade. Entra perto do Mestre e nao possui ativa propria.",
		}

	match unit_state.unit_data.id:
		"necromancer_master":
			return {
				"name": "Carnificina Ascendente",
				"description": "Sempre que qualquer unidade morre, Mordos fortalece as pecas sobreviventes do proprio time e transforma a luta em snowball.",
			}
		"thrax_master":
			return {
				"name": "Ganancia do Rei",
				"description": "Quanto mais ouro o reino preserva, mais o exercito ganha ataque e defesa fisica, com armadura extra no proprio Thrax.",
			}
		"lady_of_lake_master":
			return {
				"name": "Aguas da Vida",
				"description": "Enquanto viver, a Dama do Lago pulsa curas periodicas no aliado mais ferido. O sustain continua, mas agora exige mais tempo.",
			}
		_:
			return {
				"name": "Sem passiva exclusiva",
				"description": "Esta unidade joga pelo kit base e pela habilidade ativa.",
			}

func _race_passive_info(unit_state: BattleUnitState) -> Dictionary:
	if unit_state == null or unit_state.unit_data == null:
		return {
			"name": "Raca base",
			"description": "Tag tematica sem bonus mecanico.",
		}
	return {
		"name": unit_state.get_race_name(),
		"description": "Tag tematica e de lore. Nao concede bonus de gameplay.",
	}

func _class_passive_info(unit_state: BattleUnitState) -> Dictionary:
	if unit_state == null or unit_state.unit_data == null:
		return {
			"name": "Classe base",
			"description": "Papel tatico da unidade.",
		}
	return {
		"name": unit_state.get_class_name(),
		"description": unit_state.get_class_role_description(),
	}

func _active_skill_info(unit_state: BattleUnitState) -> Dictionary:
	var skill_data: SkillData = null
	if unit_state != null and unit_state.has_master_skill():
		skill_data = unit_state.get_master_skill_data()
	elif unit_state != null and unit_state.has_unit_skill():
		skill_data = unit_state.get_skill_data()

	if skill_data == null:
		return {
			"available": false,
			"name": "",
			"description": "",
			"mana_cost": 0,
			"range": 1,
			"target_text": "",
		}

	var info: Dictionary = {
		"available": true,
		"name": _translated_skill_name(skill_data),
		"description": skill_data.description.strip_edges() if not skill_data.description.strip_edges().is_empty() else "Ativa um efeito especial de combate.",
		"mana_cost": skill_data.mana_cost,
		"range": skill_data.range,
		"target_text": "",
	}

	match skill_data.effect_type:
		GameEnums.SkillEffectType.SUMMON_SKELETONS:
			info.target_text = "Sem alvo manual. Invoca esqueletos em celulas livres proximas ao Mestre."
		GameEnums.SkillEffectType.MANA_SUPPRESS_AURA:
			info.target_text = "Area curta ao redor da propria unidade."
		GameEnums.SkillEffectType.AOE_PHYSICAL_DEFENSE_BREAK:
			info.target_text = "Atinge o alvo atual e inimigos proximos."
		GameEnums.SkillEffectType.HYBRID_STRIKE_MANA_SUPPRESS:
			info.target_text = "Usa o alvo atual de combate."
		GameEnums.SkillEffectType.PHYSICAL_LIFESTEAL_STRIKE:
			info.target_text = "Usa o alvo atual de combate."
		GameEnums.SkillEffectType.MAGIC_AOE_SLOW:
			info.target_text = "Golpe frontal curto com impacto em area pequena."
		GameEnums.SkillEffectType.SELF_EXPLOSION:
			info.target_text = "Dispara ao encher a mana e tambem quando a unidade morre."
		GameEnums.SkillEffectType.EXECUTE_MAGIC_STRIKE:
			info.target_text = "Usa o alvo atual. Em alvo abaixo de 30% de PV, o golpe crita automaticamente."
		GameEnums.SkillEffectType.PHYSICAL_SHIELD_REFLECT:
			info.target_text = "Sem alvo manual. O escudo fica na propria unidade."
		GameEnums.SkillEffectType.SELF_SACRIFICE_MANA_GIFT:
			info.target_text = "Prioriza o Mestre aliado; se ele nao estiver disponivel, usa o aliado mais proximo."
		GameEnums.SkillEffectType.TARGET_MAGIC_DEFENSE_BREAK:
			info.target_text = "Prioriza o inimigo com maior defesa magica."
		GameEnums.SkillEffectType.ALLY_MAGIC_CRIT_GIFT:
			info.target_text = "Prioriza o aliado com maior ataque magico dentro do alcance."
		GameEnums.SkillEffectType.TARGET_HEAVY_SLOW:
			info.target_text = "Prioriza o inimigo com maior ataque fisico."
		GameEnums.SkillEffectType.TARGET_PHYSICAL_VULNERABILITY:
			info.target_text = "Marca o alvo atual para ele receber mais dano fisico."
		GameEnums.SkillEffectType.POUNCE_MAGIC_HUNTER_STUN:
			info.target_text = "Salta no inimigo com maior ataque magico e o atordoa."
		GameEnums.SkillEffectType.SELF_BASIC_ATTACK_BLOCK:
			info.target_text = "Sem alvo manual. Bloqueia os proximos ataques basicos recebidos."
		GameEnums.SkillEffectType.AOE_PHYSICAL_ATTACK_SLOW:
			info.target_text = "Golpe em area que reduz o ritmo de ataque dos inimigos atingidos."
		GameEnums.SkillEffectType.MISSING_HEALTH_PHYSICAL_STRIKE:
			info.target_text = "Usa o alvo atual e escala com o PV perdido do usuario."
		GameEnums.SkillEffectType.SELF_BERSERK_FRENZY:
			info.target_text = "Sem alvo manual. Aumenta o ritmo de ataques, mas remove a defesa fisica."
		GameEnums.SkillEffectType.SELF_CLEAVE_BUFF:
			info.target_text = "Sem alvo manual. Os proximos ataques basicos ganham cleave."
		GameEnums.SkillEffectType.TARGET_PHYSICAL_DEFENSE_BREAK_ZERO:
			info.target_text = "Usa o alvo atual e zera a defesa fisica dele por pouco tempo."
		GameEnums.SkillEffectType.GAIN_NEXT_ROUND_GOLD:
			info.target_text = "Sem alvo manual. Gera ouro para a proxima rodada."
		GameEnums.SkillEffectType.ALLY_HEAL_PERCENT:
			info.target_text = "Prioriza o aliado com menor vida."
		GameEnums.SkillEffectType.ADJACENT_LIFESTEAL_GIFT:
			info.target_text = "Prioriza o aliado adjacente com maior ataque fisico."
		GameEnums.SkillEffectType.ADJACENT_MANA_GIFT:
			info.target_text = "Afeta aliados adjacentes."
		GameEnums.SkillEffectType.MASTER_TAUNT_AURA:
			info.target_text = "Provoca todos os inimigos vivos para focarem o Mestre."
		GameEnums.SkillEffectType.TARGET_MAGIC_BURST_SLOW:
			info.target_text = "Prioriza o inimigo mais forte e reduz muito o ritmo dele."
		GameEnums.SkillEffectType.SLOWED_CRIT_STRIKE:
			info.target_text = "Prioriza inimigos sob Lentidao para garantir critico."
		GameEnums.SkillEffectType.TARGET_MAGIC_DOT_CONTROL:
			info.target_text = "Prioriza o inimigo mais forte para interromper seu ritmo."
		GameEnums.SkillEffectType.SELF_ATTACK_BLOCK_RETALIATE_SLOW:
			info.target_text = "Sem alvo manual. Reforca a propria linha de frente."
		GameEnums.SkillEffectType.ADJACENT_KNOCKBACK:
			info.target_text = "Afeta inimigos adjacentes e pode empurra-los."
		GameEnums.SkillEffectType.LINE_PHYSICAL_DEFENSE_BREAK:
			info.target_text = "Perfura uma linha inimiga e reduz a defesa fisica dos atingidos."
		GameEnums.SkillEffectType.AOE_PHYSICAL_EVASION:
			info.target_text = "Gira sobre o alvo atual e ganha esquiva contra ataques basicos."
		GameEnums.SkillEffectType.TARGET_MAGIC_STUN:
			info.target_text = "Usa o alvo atual e o atordoa por um curto periodo."
		GameEnums.SkillEffectType.CONE_MAGIC_DISPEL:
			info.target_text = "Atinge um cone frontal curto e pode remover buffs positivos."
		GameEnums.SkillEffectType.TARGET_CHARM:
			info.target_text = "Encanta o inimigo mais proximo e o atrai ate a sereia."
		GameEnums.SkillEffectType.ADJACENT_MAGIC_SHIELD:
			info.target_text = "Protege um aliado proximo com escudo contra dano magico."
		GameEnums.SkillEffectType.ADJACENT_CLEANSE:
			info.target_text = "Purifica aliados adjacentes com debuffs."
		GameEnums.SkillEffectType.LINE_HASTE:
			info.target_text = "Acelera o proprio clerigo e aliados ao lado ou atras dele."
		_:
			info.target_text = ""

	return info

func _translated_unit_profile(unit_state: BattleUnitState) -> String:
	if unit_state == null or unit_state.unit_data == null:
		return ""
	return unit_state.unit_data.description.strip_edges()

func _build_support_stats_lines(card_data: CardData) -> Array[String]:
	var stats_lines: Array[String] = []
	if card_data.global_life_heal > 0:
		stats_lines.append("Cura global: +%d de vida" % card_data.global_life_heal)
	if card_data.heal_amount > 0:
		stats_lines.append("Cura de unidade: +%d PV" % card_data.heal_amount)
	if card_data.magic_attack_multiplier > 1.0:
		stats_lines.append("Ataque magico: +%d%%" % _ratio_to_percent_gain(card_data.magic_attack_multiplier))
	if card_data.physical_attack_multiplier > 1.0:
		stats_lines.append("Ataque fisico: +%d%%" % _ratio_to_percent_gain(card_data.physical_attack_multiplier))
	if card_data.physical_defense_multiplier > 1.0:
		stats_lines.append("Defesa fisica: +%d%%" % _ratio_to_percent_gain(card_data.physical_defense_multiplier))
	if card_data.physical_attack_bonus != 0 or card_data.magic_attack_bonus != 0:
		stats_lines.append("Ataque: %+d F | %+d M" % [
			card_data.physical_attack_bonus,
			card_data.magic_attack_bonus,
		])
	if card_data.physical_defense_bonus != 0 or card_data.magic_defense_bonus != 0:
		stats_lines.append("Defesa: %+d F | %+d M" % [
			card_data.physical_defense_bonus,
			card_data.magic_defense_bonus,
		])
	if card_data.stealth_turns > 0:
		stats_lines.append("Furtividade: %d turnos" % card_data.stealth_turns)
	if card_data.physical_miss_chance > 0.0:
		stats_lines.append("Falha fisica: %d%%" % int(round(card_data.physical_miss_chance * 100.0)))
	if card_data.delayed_trigger_max_turn > 0:
		stats_lines.append("Janela de gatilho: turno %d a %d" % [
			card_data.delayed_trigger_min_turn,
			card_data.delayed_trigger_max_turn,
		])
	if card_data.mana_ratio_transfer_on_death > 0.0:
		stats_lines.append("Ao morrer: +%d%% de mana do mestre" % int(round(card_data.mana_ratio_transfer_on_death * 100.0)))
	if card_data.stun_turns > 0:
		stats_lines.append("Atordoamento: %d turnos" % card_data.stun_turns)
	if card_data.mana_gain_multiplier < 1.0:
		stats_lines.append("Ganho de mana: %d%% do normal" % int(round(card_data.mana_gain_multiplier * 100.0)))
	if card_data.mana_gain_multiplier > 1.0:
		stats_lines.append("Ganho de mana: +%d%%" % int(round((card_data.mana_gain_multiplier - 1.0) * 100.0)))
	if card_data.action_charge_multiplier < 1.0:
		stats_lines.append("Ritmo inimigo: %d%%" % int(round(card_data.action_charge_multiplier * 100.0)))
	if card_data.lifesteal_ratio > 0.0:
		stats_lines.append("Roubo de vida: %d%%" % int(round(card_data.lifesteal_ratio * 100.0)))
	if card_data.attack_range_bonus > 0:
		stats_lines.append("Alcance basico: +%d" % card_data.attack_range_bonus)
	if card_data.damage_amount > 0:
		stats_lines.append("Dano base: %d" % card_data.damage_amount)
	if card_data.effect_repeat_count > 0:
		stats_lines.append("Repeticoes: %d" % card_data.effect_repeat_count)
	if card_data.periodic_interval_turns > 0:
		stats_lines.append("Intervalo: %d turnos" % card_data.periodic_interval_turns)
	if card_data.bonus_next_round_gold > 0:
		stats_lines.append("Ouro futuro: +%d" % card_data.bonus_next_round_gold)
	if card_data.tribute_steal_amount > 0:
		stats_lines.append("Tributo: rouba ate %d" % card_data.tribute_steal_amount)
	if not card_data.summon_unit_path.is_empty():
		stats_lines.append("Invocacao condicional: %.0f%% de PV" % (card_data.summon_current_hp_ratio * 100.0))
	if stats_lines.is_empty():
		stats_lines.append("Sem modificadores numericos extras.")
	return stats_lines

func _auto_support_runtime_hint(card_data: CardData) -> String:
	if card_data == null:
		return "Ja entrou ativa no PREP"
	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Campo ativo: aplica cegueira em um turno aleatorio"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Em espera: rende ouro se voce vencer a rodada"
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Em espera: rouba ouro se vencer com dano no Mestre"
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Em espera: reposiciona um inimigo na abertura"
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return "Campo ativo: desacelera o time inimigo na abertura"
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Campo ativo: dano magico periodico em inimigos"
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Em espera: invoca na primeira baixa aliada"
		_:
			return "Ja entrou ativa no PREP"

func _format_player_sidebar_entry(entry: Dictionary) -> String:
	var markers: Array[String] = []
	if bool(entry.get("is_local", false)):
		markers.append("VOCE")
	if bool(entry.get("is_current_opponent", false)):
		markers.append("VS")
	if bool(entry.get("is_observed", false)):
		markers.append("OBS")
	if bool(entry.get("eliminated", false)):
		markers.append("KO")

	var prefix: String = ""
	if not markers.is_empty():
		prefix = "[%s] " % _join_strings(markers, "|")

	return "%s%s - %d PV" % [
		prefix,
		str(entry.get("name", "Jogador")),
		int(entry.get("life", 0)),
	]

func _player_sidebar_color(entry: Dictionary) -> Color:
	if bool(entry.get("eliminated", false)):
		return Color(0.62, 0.62, 0.62, 1.0)
	if bool(entry.get("is_observed", false)):
		return Color(0.58, 1.0, 0.70, 1.0)
	if bool(entry.get("is_local", false)):
		return Color(0.45, 0.88, 1.0, 1.0)
	if bool(entry.get("is_current_opponent", false)):
		return Color(1.0, 0.83, 0.45, 1.0)
	return Color(0.92, 0.92, 0.92, 1.0)

func _on_player_sidebar_button_pressed(player_id: String) -> void:
	player_sidebar_entry_pressed.emit(player_id)

func _on_observer_return_button_pressed() -> void:
	return_to_local_board_pressed.emit()

func _on_card_shop_option_pressed(option_index: int) -> void:
	if option_index < 0 or option_index >= card_shop_option_paths.size():
		return
	var card_path: String = str(card_shop_option_paths[option_index])
	if card_path.is_empty():
		return
	card_shop_option_selected.emit(card_path)

func _on_support_sidebar_card_pressed(slot_index: int) -> void:
	support_sidebar_card_pressed.emit(slot_index)

func _on_support_sidebar_card_right_clicked(slot_index: int) -> void:
	support_sidebar_card_right_clicked.emit(slot_index)

func _on_elimination_watch_button_pressed() -> void:
	elimination_watch_requested.emit()

func _on_elimination_back_button_pressed() -> void:
	elimination_back_requested.emit()

func _on_final_play_again_button_pressed() -> void:
	play_again_requested.emit()

func _on_master_promotion_token_drag_started(screen_pos: Vector2) -> void:
	master_promotion_drag_started.emit(screen_pos)

func _on_master_promotion_token_drag_moved(screen_pos: Vector2) -> void:
	master_promotion_drag_moved.emit(screen_pos)

func _on_master_promotion_token_drag_released(screen_pos: Vector2) -> void:
	master_promotion_drag_released.emit(screen_pos)

func _on_master_promotion_token_drag_canceled() -> void:
	master_promotion_drag_canceled.emit()

func _build_tags(unit_state: BattleUnitState) -> Array[String]:
	var tags: Array[String] = []
	if unit_state.is_master:
		tags.append("MESTRE")
	if unit_state.is_summoned_token:
		tags.append("TOKEN")
	tags.append("RACA")
	tags.append("CLASSE")
	if unit_state.has_master_skill():
		tags.append("HAB. MESTRE")
	if unit_state.has_unit_skill():
		tags.append("HAB. UNIDADE")
	return tags

func _build_round_bonus_text(unit_state: BattleUnitState) -> String:
	var bonuses: Array[String] = []
	if unit_state.bonus_physical_attack != 0:
		bonuses.append("ATQ F %+d" % unit_state.bonus_physical_attack)
	if unit_state.bonus_magic_attack != 0:
		bonuses.append("ATQ M %+d" % unit_state.bonus_magic_attack)
	if unit_state.bonus_physical_defense != 0:
		bonuses.append("DEF F %+d" % unit_state.bonus_physical_defense)
	if unit_state.bonus_magic_defense != 0:
		bonuses.append("DEF M %+d" % unit_state.bonus_magic_defense)
	return _join_strings(bonuses)

func _support_card_type_name(card_data: CardData) -> String:
	if card_data == null:
		return "Suporte"

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Suporte global"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return "Suporte de unidade"
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return "Equipamento magico"
		GameEnums.SupportCardEffectType.START_STEALTH:
			return "Equipamento furtivo"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Feitico de campo"
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return "Suporte de gatilho"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Armadilha de celula"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Feitico de ouro"
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Feitico de pilhagem"
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return "Equipamento defensivo"
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return "Equipamento ofensivo"
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Armadilha de abertura"
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return "Feitico de campo"
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Feitico de campo"
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Invocacao condicional"
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return "Equipamento mistico"
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Equipamento ofensivo"
		_:
			return "Suporte"

func _support_target_name(effect_type: int) -> String:
	match effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Mestre aliado"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.START_STEALTH:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Campo instantaneo"
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Celula inimiga"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Unidade aliada"
		_:
			return "Desconhecido"

func _support_card_usage_text(card_data: CardData) -> String:
	if card_data == null:
		return "Sem dados de uso."
	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Entra ativa automaticamente em todo PREP."
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Entra ativa automaticamente em todo PREP."
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Entra ativa automaticamente em todo PREP."
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Entra ativa automaticamente em todo PREP."
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return "Entra ativa automaticamente em todo PREP."
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Entra ativa automaticamente em todo PREP."
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Entra ativa automaticamente em todo PREP."
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Arme a carta no PREP e escolha uma celula do lado inimigo."
		_:
			return "Arme a carta no PREP e escolha uma unidade aliada."

func _format_card_shop_option_text(card_data: CardData) -> String:
	if card_data == null:
		return "Carta indisponivel"

	return "%s\nGratis | %s\n%s\n\nClique para escolher" % [
		card_data.display_name,
		_support_card_type_name(card_data),
		_translated_card_description(card_data),
	]

func _build_status_text(unit_state: BattleUnitState) -> String:
	var statuses: Array[String] = []
	for effect_entry in unit_state.get_active_effect_entries():
		statuses.append(_format_active_effect_line(effect_entry))
	return _join_strings(statuses)

func _team_name(team_side: int) -> String:
	if team_side == GameEnums.TeamSide.PLAYER:
		return "JOGADOR"
	if team_side == GameEnums.TeamSide.ENEMY:
		return "INIMIGO"
	return "DESCONHECIDO"

func _translated_skill_name(skill_data: SkillData) -> String:
	if skill_data == null:
		return "Sem habilidade"
	return skill_data.display_name if not skill_data.display_name.is_empty() else skill_data.id

func _translated_card_description(card_data: CardData) -> String:
	if card_data == null:
		return ""
	if not card_data.description.is_empty():
		return card_data.description.strip_edges()
	return "Suporte de preparo com efeito especial do deck."

func _ratio_to_percent_gain(multiplier: float) -> int:
	return int(round((multiplier - 1.0) * 100.0))

func _multiplier_to_percent_loss(multiplier: float) -> int:
	return int(round((1.0 - multiplier) * 100.0))

func _join_strings(values: Array[String], separator: String = ", ") -> String:
	var result: String = ""
	for value in values:
		var trimmed_value: String = value.strip_edges()
		if trimmed_value.is_empty():
			continue
		if result.is_empty():
			result = trimmed_value
		else:
			result += separator + trimmed_value
	return result
