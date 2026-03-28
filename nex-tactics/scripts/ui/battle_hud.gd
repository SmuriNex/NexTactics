extends CanvasLayer
class_name BattleHUD

signal player_sidebar_entry_pressed(player_id: String)
signal return_to_local_board_pressed

const OBSERVED_BOARD_EMPTY_CELL := "·"

@onready var round_label: Label = $PanelContainer/MarginContainer/VBoxContainer/RoundLabel
@onready var player_life_label: Label = $PanelContainer/MarginContainer/VBoxContainer/PlayerLifeLabel
@onready var enemy_life_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EnemyLifeLabel
@onready var energy_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EnergyLabel
@onready var state_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StateLabel
@onready var selected_deploy_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SelectedDeployLabel
@onready var synergy_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SynergyLabel
@onready var round_result_label: Label = $PanelContainer/MarginContainer/VBoxContainer/RoundResultLabel
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

var observed_board_cells: Array[Button] = []

func _ready() -> void:
	_build_observed_board_cells()
	if observed_board_back_button != null:
		observed_board_back_button.pressed.connect(_on_observed_board_back_button_pressed)
	clear_unit_info()
	update_player_sidebar([])

func update_status(
	round_number: int,
	player_life: int,
	enemy_life: int,
	energy_value: int,
	state_name: String,
	deploy_selection: String,
	synergy_summary: String,
	round_result_summary: String
) -> void:
	round_label.text = "RODADA %d" % round_number
	player_life_label.text = "Vida jog.    %d" % player_life
	enemy_life_label.text = "Vida inim.   %d" % enemy_life
	energy_label.text = "Energia      %d" % energy_value
	state_label.text = "Estado       %s" % state_name
	selected_deploy_label.text = deploy_selection
	synergy_label.text = "Racas campo  %s" % synergy_summary
	round_result_label.text = round_result_summary

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
		"Tags: SUPORTE, PREPARO",
		"Uso: clique para armar e depois escolha o alvo, quando aplicavel.",
	]

	_set_info_blocks(
		card_data.display_name,
		"Custo %d" % card_data.cost,
		"SUPORTE | %s" % _support_card_type_name(card_data),
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
	_set_info_blocks(
		"Tabuleiro: %s" % str(snapshot.get("player_name", "Jogador")),
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
	_refresh_observed_board_grid(snapshot)

func clear_unit_info() -> void:
	info_panel_container.visible = false
	_set_default_section_titles()
	_set_observed_board_visible(false)
	unit_info_title_label.text = "Info da unidade"
	unit_info_cost_label.text = "Custo -"
	unit_info_subtitle_label.text = "Clique com o botao direito em uma unidade ou suporte."
	primary_block_label.text = "-"
	stats_block_label.text = "-"
	skill_block_label.text = "-"
	tags_block_label.text = "-"

func is_over_hud(global_pos: Vector2) -> bool:
	if status_panel_container.get_global_rect().has_point(global_pos):
		return true
	if player_sidebar_panel_container.get_global_rect().has_point(global_pos):
		return true
	if info_panel_container.visible and info_panel_container.get_global_rect().has_point(global_pos):
		return true
	return false

func is_info_panel_open() -> bool:
	return info_panel_container.visible

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
	primary_section_title_label.text = "VISAO GERAL"
	stats_section_title_label.text = "FORMACAO"
	skill_section_title_label.text = "RESOLUCAO DA RODADA"
	tags_section_title_label.text = "LISTA DE PECAS"

func _set_observed_board_visible(value: bool) -> void:
	if observed_board_section_panel == null:
		return
	observed_board_section_panel.visible = value

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
	return [
		"Vida atual: %d PV" % int(snapshot.get("life", 0)),
		"Fase salva: %s" % str(snapshot.get("phase", "PREPARACAO")),
		"Energia da rodada: %d (orcamento %d)" % [
			int(snapshot.get("energy", 0)),
			int(snapshot.get("energy_budget", 0)),
		],
	]

func _build_observed_stats_lines(snapshot: Dictionary) -> Array[String]:
	return [
		"Mestre: %s" % str(snapshot.get("master_name", "Sem mestre")),
		"Pecas em campo: %d" % int(snapshot.get("unit_count", 0)),
		"Unidades alem do mestre: %d" % int(snapshot.get("non_master_count", 0)),
		"Forca estimada: %d" % int(snapshot.get("power_rating", 0)),
	]

func _build_observed_result_lines(snapshot: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var result_text: String = str(snapshot.get("result_text", ""))
	if result_text.is_empty():
		lines.append("Resultado salvo: ainda sem resolucao final desta rodada.")
	else:
		lines.append("Resultado salvo: %s" % result_text)
	var summary_text: String = str(snapshot.get("summary", ""))
	if not summary_text.is_empty():
		lines.append("Resumo: %s" % summary_text)
	return lines

func _build_observed_unit_lines(snapshot: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var snapshot_units: Array = snapshot.get("units", [])
	for unit_variant in snapshot_units:
		var unit_entry: Dictionary = unit_variant
		lines.append("%s [%s] @ %s" % [
			str(unit_entry.get("display_name", "Unidade")),
			str(unit_entry.get("class_label", "Classe")),
			unit_entry.get("coord", Vector2i(-1, -1)),
		])
	if lines.is_empty():
		lines.append("Sem pecas visiveis neste snapshot.")
	return lines

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
				"description": "Quando uma unidade morre, o Rei Necromante absorve mana. Mortes inimigas rendem +10 mana e mortes aliadas rendem +12 mana.",
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
		_:
			return "Desconhecido"

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
	if unit_state.has_turn_skip():
		statuses.append("Pula %d" % unit_state.skip_turns_remaining)
	if unit_state.has_magic_crit_gift():
		statuses.append("Critico magico pronto")
	if unit_state.death_mana_ratio_to_master > 0.0:
		statuses.append("Pacto de Sangue %d%%" % int(round(unit_state.death_mana_ratio_to_master * 100.0)))
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
