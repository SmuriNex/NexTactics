extends CanvasLayer
class_name BattleHUD

signal player_sidebar_entry_pressed(player_id: String)
signal return_to_local_board_pressed
signal card_shop_option_selected(card_path: String)

const OBSERVED_BOARD_EMPTY_CELL := "Â·"

@onready var round_label: Label = $PanelContainer/MarginContainer/VBoxContainer/RoundLabel
@onready var player_life_label: Label = $PanelContainer/MarginContainer/VBoxContainer/PlayerLifeLabel
@onready var gold_label: Label = $PanelContainer/MarginContainer/VBoxContainer/GoldLabel
@onready var state_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StateLabel
@onready var opponent_label: Label = $PanelContainer/MarginContainer/VBoxContainer/OpponentLabel
@onready var status_panel_container: PanelContainer = $PanelContainer
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
@onready var observed_board_section_panel: PanelContainer = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/ObservedBoardSectionPanel
@onready var observed_board_meta_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/ObservedBoardSectionPanel/MarginContainer/VBoxContainer/ObservedBoardMetaLabel
@onready var observed_board_grid: GridContainer = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/ObservedBoardSectionPanel/MarginContainer/VBoxContainer/ObservedBoardGrid
@onready var observed_board_hint_label: Label = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/ObservedBoardSectionPanel/MarginContainer/VBoxContainer/ObservedBoardHintLabel
@onready var observed_board_back_button: Button = $InfoPanelContainer/MarginContainer/InfoScroll/VBoxContainer/ObservedBoardSectionPanel/MarginContainer/VBoxContainer/ObservedBoardBackButton
@onready var player_sidebar_panel_container: PanelContainer = $PlayerSidebarPanelContainer
@onready var player_sidebar_list: VBoxContainer = $PlayerSidebarPanelContainer/MarginContainer/VBoxContainer/PlayersListVBox
@onready var card_shop_overlay: Control = $CardShopOverlay
@onready var card_shop_title_label: Label = $CardShopOverlay/CenterContainer/ShopPanel/MarginContainer/VBoxContainer/CardShopTitleLabel
@onready var card_shop_subtitle_label: Label = $CardShopOverlay/CenterContainer/ShopPanel/MarginContainer/VBoxContainer/CardShopSubtitleLabel
@onready var card_shop_button_a: Button = $CardShopOverlay/CenterContainer/ShopPanel/MarginContainer/VBoxContainer/CardShopOptionsRow/CardShopOptionButtonA
@onready var card_shop_button_b: Button = $CardShopOverlay/CenterContainer/ShopPanel/MarginContainer/VBoxContainer/CardShopOptionsRow/CardShopOptionButtonB

var observed_board_cells: Array[Button] = []
var card_shop_option_paths: Array[String] = []

func _ready() -> void:
	_build_observed_board_cells()
	if observed_board_back_button != null:
		observed_board_back_button.pressed.connect(_on_observed_board_back_button_pressed)
	if card_shop_button_a != null:
		card_shop_button_a.pressed.connect(_on_card_shop_option_button_pressed.bind(0))
	if card_shop_button_b != null:
		card_shop_button_b.pressed.connect(_on_card_shop_option_button_pressed.bind(1))
	clear_unit_info()
	update_player_sidebar([])
	hide_card_shop()

func update_status(
	round_number: int,
	player_life: int,
	gold_value: int,
	state_name: String,
	opponent_name: String
) -> void:
	round_label.text = "RODADA %d" % round_number
	player_life_label.text = "Vida jog.    %d" % player_life
	gold_label.text = "Ouro         %d" % gold_value
	state_label.text = "Estado       %s" % state_name
	opponent_label.text = "Oponente     %s" % opponent_name

func update_unit_info(unit_state: BattleUnitState) -> void:
	if unit_state == null or unit_state.unit_data == null:
		clear_unit_info()
		return
	info_panel_container.visible = true
	_set_default_section_titles()
	_set_observed_board_visible(false)

	var title_text: String = unit_state.get_display_name()
	if unit_state.is_master:
		title_text += " [MESTRE]"
	var cost_text: String = "Custo %d" % unit_state.unit_data.cost
	var subtitle_text: String = "%s | %s | %s" % [
		_team_name(unit_state.team_side),
		unit_state.get_race_name(),
		unit_state.get_class_name(),
	]

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
	_set_default_section_titles()
	_set_observed_board_visible(false)

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
		"Uso: clique para armar e depois escolha o alvo, quando aplicavel.",
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
		clear_unit_info()
		return

	info_panel_container.visible = true
	_set_observed_board_section_titles()
	_set_observed_board_visible(true)
	if observed_board_grid != null:
		observed_board_grid.visible = false
	_set_info_blocks(
		"Observando: %s" % str(snapshot.get("player_name", "Jogador")),
		"%d PV" % int(snapshot.get("life", 0)),
		"Rodada %d | %s" % [
			int(snapshot.get("round_number", 0)),
			str(snapshot.get("phase", "PREPARACAO")),
		],
		_join_strings(_build_observed_primary_lines(snapshot), "\n"),
		_join_strings(_build_observed_stats_lines(snapshot), "\n"),
		_join_strings(_build_observed_result_lines(snapshot), "\n"),
		_join_strings(_build_observed_unit_lines(snapshot), "\n")
	)
	observed_board_meta_label.text = "Mesa viva observada: %s | Vida %d | Fase %s" % [
		str(snapshot.get("player_name", "Jogador")),
		int(snapshot.get("life", 0)),
		str(snapshot.get("phase", "PREPARACAO")),
	]
	observed_board_hint_label.text = "O tabuleiro principal mostra a mesa observada em tempo real. Clique em outro jogador para trocar ou use \"Voltar para meu tabuleiro\"."

func clear_unit_info() -> void:
	info_panel_container.visible = false
	_set_default_section_titles()
	_set_observed_board_visible(false)
	unit_info_title_label.text = "Info da unidade"
	unit_info_cost_label.text = "Custo -"
	unit_info_subtitle_label.text = "Clique com o botao direito em uma unidade ou carta."
	primary_block_label.text = "-"
	stats_block_label.text = "-"
	skill_block_label.text = "-"
	tags_block_label.text = "-"

func is_over_hud(global_pos: Vector2) -> bool:
	if card_shop_overlay != null and card_shop_overlay.visible:
		return true
	if status_panel_container.get_global_rect().has_point(global_pos):
		return true
	if player_sidebar_panel_container.get_global_rect().has_point(global_pos):
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
	card_shop_title_label.text = "LOJA DA PARTIDA - RODADA %d" % round_number
	card_shop_subtitle_label.text = "Escolha 1 carta gratuita. Ela permanece com voce ate o fim da partida."
	_set_card_shop_button(card_shop_button_a, option_entries, 0)
	_set_card_shop_button(card_shop_button_b, option_entries, 1)

func hide_card_shop() -> void:
	if card_shop_overlay == null:
		return
	card_shop_overlay.visible = false
	card_shop_option_paths.clear()

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

func _set_card_shop_button(button: Button, option_entries: Array[Dictionary], index: int) -> void:
	if button == null:
		return
	if index < 0 or index >= option_entries.size():
		button.visible = false
		return

	var option_entry: Dictionary = option_entries[index]
	var card_data: CardData = option_entry.get("card_data", null)
	var card_path: String = str(option_entry.get("card_path", ""))
	button.visible = true
	button.disabled = card_data == null or card_path.is_empty()
	if card_shop_option_paths.size() <= index:
		card_shop_option_paths.resize(index + 1)
	card_shop_option_paths[index] = card_path

	if card_data == null:
		button.text = "Carta indisponivel"
		return

	button.text = _format_card_shop_option_text(card_data)

func _build_observed_board_cells() -> void:
	if observed_board_grid == null:
		return
	for child in observed_board_grid.get_children():
		observed_board_grid.remove_child(child)
		child.queue_free()
	observed_board_cells.clear()

	for _index in range(BattleConfig.BOARD_WIDTH * BattleConfig.BOARD_HEIGHT):
		var cell_button := Button.new()
		cell_button.disabled = true
		cell_button.focus_mode = Control.FOCUS_NONE
		cell_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_button.custom_minimum_size = Vector2(30.0, 24.0)
		cell_button.text = "."
		cell_button.flat = true
		cell_button.add_theme_font_size_override("font_size", 10)
		observed_board_grid.add_child(cell_button)
		observed_board_cells.append(cell_button)

func _set_default_section_titles() -> void:
	primary_section_title_label.text = "VIDA E MANA"
	stats_section_title_label.text = "ATRIBUTOS"
	skill_section_title_label.text = "PASSIVAS E HABILIDADE"
	tags_section_title_label.text = "PERFIL E TAGS"

func _set_observed_board_section_titles() -> void:
	primary_section_title_label.text = "MESA OBSERVADA"
	stats_section_title_label.text = "FORMACAO"
	skill_section_title_label.text = "STATUS DA RODADA"
	tags_section_title_label.text = "AJUDA"

func _set_observed_board_visible(value: bool) -> void:
	if observed_board_section_panel == null:
		return
	observed_board_section_panel.visible = value
	if observed_board_grid != null:
		observed_board_grid.visible = value

func _refresh_observed_board_grid(snapshot: Dictionary) -> void:
	for cell_button in observed_board_cells:
		cell_button.text = "."
		cell_button.tooltip_text = ""
		cell_button.add_theme_color_override("font_color", Color(0.78, 0.78, 0.80, 1.0))

	var snapshot_units: Array = snapshot.get("units", [])
	for unit_variant in snapshot_units:
		var unit_entry: Dictionary = unit_variant
		var coord: Vector2i = unit_entry.get("coord", Vector2i(-1, -1))
		var cell_index: int = coord.y * BattleConfig.BOARD_WIDTH + coord.x
		if cell_index < 0 or cell_index >= observed_board_cells.size():
			continue
		var cell_button: Button = observed_board_cells[cell_index]
		cell_button.text = _abbreviate_unit_name(str(unit_entry.get("display_name", "Unidade")))
		cell_button.tooltip_text = "%s | %s | %s" % [
			str(unit_entry.get("display_name", "Unidade")),
			str(unit_entry.get("race_name", "Raca")),
			str(unit_entry.get("class_label", "Classe")),
		]
		cell_button.add_theme_color_override("font_color", _observed_board_cell_color(unit_entry))

	observed_board_meta_label.text = "Legenda: o preview mostra o estado salvo do board na rodada atual."
	observed_board_hint_label.text = "Clique em outro jogador para trocar a observacao. Clique em \"Voltar para meu tabuleiro\" para fechar o preview."

func _build_observed_primary_lines(snapshot: Dictionary) -> Array[String]:
	var lines: Array[String] = [
		"Vida atual: %d PV" % int(snapshot.get("life", 0)),
		"Fase salva: %s" % str(snapshot.get("phase", "PREPARACAO")),
		"Oponente da mesa: %s" % str(snapshot.get("opponent_name", "Sem oponente")),
		"Ouro da rodada: %d (orcamento %d)" % [
			int(snapshot.get("gold", 0)),
			int(snapshot.get("gold_budget", 0)),
		],
	]
	var table_id: String = str(snapshot.get("table_id", ""))
	if not table_id.is_empty():
		lines.append("Mesa: %s" % table_id)
	return lines

func _build_observed_stats_lines(snapshot: Dictionary) -> Array[String]:
	return [
		"Mestre: %s" % str(snapshot.get("master_name", "Sem mestre")),
		"Pecas em campo: %d" % int(snapshot.get("unit_count", 0)),
		"Unidades alem do mestre: %d" % int(snapshot.get("non_master_count", 0)),
		"Cartas da partida: %d" % int(snapshot.get("owned_card_count", 0)),
		"Nivel do lobby: %d | Streak: %d" % [
			int(snapshot.get("player_level", 1)),
			int(snapshot.get("streak", 0)),
		],
	]

func _build_observed_result_lines(snapshot: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var result_text: String = str(snapshot.get("result_text", ""))
	if result_text.is_empty():
		lines.append("Resultado: rodada ainda em andamento.")
	else:
		lines.append("Resultado: %s" % result_text)
	var card_summary: String = str(snapshot.get("card_summary", ""))
	if not card_summary.is_empty():
		lines.append("Cartas auto-usadas: %s" % card_summary)
	var recent_events: Array = snapshot.get("recent_events", [])
	if not recent_events.is_empty():
		var latest_event: Dictionary = recent_events[recent_events.size() - 1]
		var latest_actor: String = str(latest_event.get("actor", "Mesa"))
		var latest_type: String = str(latest_event.get("type", "evento"))
		lines.append("Evento recente: %s (%s)" % [latest_actor, latest_type])
	return lines

func _build_observed_unit_lines(snapshot: Dictionary) -> Array[String]:
	return [
		"Clique com o botao direito em uma peca do board para abrir a ficha dela.",
		"Use a sidebar para trocar de mesa ou voltar para o seu tabuleiro.",
	]

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
	return [
		"PV: %d / %d" % [unit_state.current_hp, unit_state.unit_data.max_hp],
		"Mana: %d / %d" % [unit_state.current_mana, unit_state.get_mana_max()],
		"Alcance: %d | Critico: %d%%" % [
			unit_state.get_attack_range(),
			int(round(unit_state.get_crit_chance() * 100.0)),
		],
		"Ganho de mana: ataque +%d | dano +%d" % [
			unit_state.get_mana_gain_on_attack(),
			unit_state.get_mana_gain_on_hit(),
		],
	]

func _build_stats_lines(unit_state: BattleUnitState) -> Array[String]:
	return [
		"ATQ total: %d" % unit_state.get_attack_value(),
		"ATQ fisico: %d | ATQ magico: %d" % [
			unit_state.get_physical_attack_value(),
			unit_state.get_magic_attack_value(),
		],
		"DEF total: %d" % unit_state.get_defense_value(),
		"DEF fisica: %d | DEF magica: %d" % [
			unit_state.get_physical_defense_value(),
			unit_state.get_magic_defense_value(),
		],
	]

func _build_skill_lines(unit_state: BattleUnitState) -> Array[String]:
	var lines: Array[String] = []
	var piece_passive: Dictionary = _piece_passive_info(unit_state)
	var race_passive: Dictionary = _race_passive_info(unit_state)
	var class_passive: Dictionary = _class_passive_info(unit_state)
	var active_skill: Dictionary = _active_skill_info(unit_state)

	lines.append("Passiva da peca: %s - %s" % [
		str(piece_passive.get("name", "Sem passiva exclusiva")),
		str(piece_passive.get("description", "Esta unidade usa os efeitos base do kit.")),
	])
	lines.append("Raca: %s - %s" % [
		str(race_passive.get("name", "Raca base")),
		str(race_passive.get("description", "Tag tematica.")),
	])
	lines.append("Papel de classe: %s - %s" % [
		str(class_passive.get("name", "Classe base")),
		str(class_passive.get("description", "Papel tatico da unidade.")),
	])

	if bool(active_skill.get("available", false)):
		lines.append("Ativa: %s" % str(active_skill.get("name", "Habilidade ativa")))
		lines.append("Efeito: %s" % str(active_skill.get("description", "Ativa um efeito especial de combate.")))
		lines.append("Custo de mana: %d | Alcance: %d" % [
			int(active_skill.get("mana_cost", 0)),
			int(active_skill.get("range", 1)),
		])
		var target_text: String = str(active_skill.get("target_text", ""))
		if not target_text.is_empty():
			lines.append("Alvo/condicao: %s" % target_text)
	else:
		lines.append("Ativa: Sem habilidade ativa separada.")
		lines.append("Efeito: esta unidade luta com ataques basicos e passivas.")

	return lines

func _build_tag_lines(unit_state: BattleUnitState) -> Array[String]:
	var lines: Array[String] = []
	var profile_text: String = _translated_unit_profile(unit_state)
	if not profile_text.is_empty():
		lines.append("Perfil: %s" % profile_text)
	if unit_state.has_round_stat_bonus():
		lines.append("Bonus da rodada: %s" % _build_round_bonus_text(unit_state))
	var status_text: String = _build_status_text(unit_state)
	if not status_text.is_empty():
		lines.append("Estado atual: %s" % status_text)
	lines.append("Tags: %s" % _join_strings(_build_tags(unit_state)))
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
				"name": "Colheita de Almas",
				"description": "Quando uma unidade morre, Mordos absorve mana. Mortes inimigas rendem +10 mana e mortes aliadas rendem +12 mana.",
			}
		"thrax_master":
			return {
				"name": "Presenca do Rei",
				"description": "Aliados nas casas adjacentes a Thrax recebem +30% de ataque fisico. Ao encher a mana, ele provoca inimigos proximos para focarem nele.",
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
			info.target_text = "Provoca inimigos proximos para focarem o Mestre."
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
	if card_data.attack_range_bonus > 0:
		stats_lines.append("Alcance basico: +%d" % card_data.attack_range_bonus)
	if card_data.bonus_next_round_gold > 0:
		stats_lines.append("Ouro futuro: +%d" % card_data.bonus_next_round_gold)
	if card_data.tribute_steal_amount > 0:
		stats_lines.append("Tributo: rouba ate %d" % card_data.tribute_steal_amount)
	if stats_lines.is_empty():
		stats_lines.append("Sem modificadores numericos extras.")
	return stats_lines

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

func _on_observed_board_back_button_pressed() -> void:
	return_to_local_board_pressed.emit()

func _on_card_shop_option_button_pressed(option_index: int) -> void:
	if option_index < 0 or option_index >= card_shop_option_paths.size():
		return
	var card_path: String = str(card_shop_option_paths[option_index])
	if card_path.is_empty():
		return
	card_shop_option_selected.emit(card_path)

func _abbreviate_unit_name(display_name: String) -> String:
	var words: PackedStringArray = display_name.strip_edges().split(" ", false)
	if words.is_empty():
		return "."
	if words.size() == 1:
		return words[0].substr(0, mini(2, words[0].length())).to_upper()
	return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()

func _observed_board_cell_color(unit_entry: Dictionary) -> Color:
	if bool(unit_entry.get("is_master", false)):
		return Color(1.0, 0.90, 0.50, 1.0)
	if int(unit_entry.get("team_side", GameEnums.TeamSide.PLAYER)) == GameEnums.TeamSide.ENEMY:
		return Color(1.0, 0.64, 0.60, 1.0)

	var class_label: String = str(unit_entry.get("class_label", "")).to_lower()
	if class_label.contains("tank") or class_label.contains("ogro"):
		return Color(0.62, 0.84, 1.0, 1.0)
	if class_label.contains("support"):
		return Color(0.90, 0.68, 1.0, 1.0)
	if class_label.contains("disrupt"):
		return Color(1.0, 0.72, 0.60, 1.0)
	return Color(0.95, 0.95, 0.95, 1.0)

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
		_:
			return "Desconhecido"

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
	if unit_state.is_summoned_token:
		statuses.append("Token invocado")
	if unit_state.is_stealthed():
		statuses.append("Furtividade")
	if unit_state.current_physical_shield > 0:
		statuses.append("Escudo %d" % unit_state.current_physical_shield)
	if unit_state.get_melee_reflect_damage() > 0:
		statuses.append("Reflexo %d" % unit_state.get_melee_reflect_damage())
	if unit_state.physical_defense_multiplier_status < 1.0:
		statuses.append("DEF F x%.2f" % unit_state.physical_defense_multiplier_status)
	if unit_state.magic_defense_multiplier_status < 1.0:
		statuses.append("DEF M x%.2f" % unit_state.magic_defense_multiplier_status)
	if unit_state.mana_gain_multiplier_status < 1.0:
		statuses.append("Mana x%.2f" % unit_state.mana_gain_multiplier_status)
	if unit_state.physical_miss_chance_status > 0.0:
		statuses.append("Falha F %d%%" % int(round(unit_state.physical_miss_chance_status * 100.0)))
	if unit_state.get_received_physical_damage_multiplier() > 1.0:
		statuses.append("Dano F x%.2f" % unit_state.get_received_physical_damage_multiplier())
	if unit_state.action_charge_multiplier_status != 1.0:
		statuses.append("Ritmo x%.2f" % unit_state.action_charge_multiplier_status)
	if unit_state.has_turn_skip():
		statuses.append("Pula %d" % unit_state.skip_turns_remaining)
	if unit_state.has_magic_crit_gift():
		statuses.append("Critico magico pronto")
	if unit_state.death_mana_ratio_to_master > 0.0:
		statuses.append("Pacto de Sangue %d%%" % int(round(unit_state.death_mana_ratio_to_master * 100.0)))
	if unit_state.blocked_basic_attack_count > 0:
		statuses.append("Bloqueia %d" % unit_state.blocked_basic_attack_count)
	if unit_state.get_lifesteal_ratio() > 0.0:
		statuses.append("Roubo de vida %d%%" % int(round(unit_state.get_lifesteal_ratio() * 100.0)))
	if unit_state.attack_range_bonus_status > 0:
		statuses.append("Alcance +%d" % unit_state.attack_range_bonus_status)
	if unit_state.has_cleave_attacks():
		statuses.append("Cleave %d" % unit_state.cleave_attacks_remaining)
	if unit_state.has_forced_target():
		statuses.append("Provocado")
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

	match card_data.id:
		"demo_field_aid":
			return "Recupera 3 de vida global do seu Mestre durante o PREP."
		"demo_battle_orders":
			return "Aumenta o ataque de uma unidade aliada nesta rodada."
		"book_of_chaos":
			return "A unidade alvo recebe +40% de ataque magico nesta rodada."
		"cloak_of_darkness":
			return "A unidade alvo inicia a batalha em furtividade."
		"blinding_mist":
			return "Uma nevoa atrasada reduz a confiabilidade dos ataques fisicos inimigos."
		"blood_pact":
			return "Quando o aliado marcado morrer, o Mestre ganha 40% da mana maxima."
		"bone_prison":
			return "Se um inimigo iniciar na celula marcada, ele fica preso e para de ganhar mana."
		"toque_de_midas":
			return "Se voce vencer a rodada, recebe ouro extra na proxima fase."
		"saque_de_tributo":
			return "Se voce vencer e causar dano ao Mestre inimigo, rouba ouro futuro dele."
		"armadura_de_guerra":
			return "A unidade alvo recebe +40% de defesa fisica nesta rodada."
		"lanca_de_leonidas":
			return "A unidade alvo recebe +40% de ataque fisico e +1 de alcance basico nesta rodada."
		"tornado":
			return "No inicio do combate, um inimigo aleatorio e puxado para uma casa vazia do seu lado."
		_:
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
