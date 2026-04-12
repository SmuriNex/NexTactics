extends GutTest

const BattleUnitStateScript := preload("res://scripts/battle/battle_unit_state.gd")
const UnitDataScript := preload("res://scripts/data/unit_data.gd")


func _make_unit_state() -> BattleUnitState:
	var unit_data: UnitData = UnitDataScript.new()
	unit_data.id = "test_unit"
	unit_data.display_name = "Teste"
	unit_data.class_type = GameEnums.ClassType.ATTACKER
	unit_data.max_hp = 20
	unit_data.physical_attack = 5
	unit_data.magic_attack = 3
	unit_data.physical_defense = 2
	unit_data.magic_defense = 1
	unit_data.attack_range = 1

	return BattleUnitStateScript.new().setup_from_unit_data(
		unit_data,
		GameEnums.TeamSide.PLAYER,
		Vector2i.ZERO
	)


func _find_effect_entry(unit_state: BattleUnitState, effect_key: String) -> Dictionary:
	for effect_entry in unit_state.get_active_effect_entries():
		if str(effect_entry.get("effect_key", "")) == effect_key:
			return effect_entry
	return {}


func test_mana_gain_multiplier_accepts_buff_and_debuff() -> void:
	var unit_state: BattleUnitState = _make_unit_state()

	unit_state.apply_mana_gain_multiplier(1.5, 2)
	assert_eq(unit_state.mana_gain_multiplier_status, 1.5)
	assert_eq(unit_state.mana_gain_modifier_turns, 2)

	unit_state.apply_mana_gain_multiplier(0.0, 1)
	assert_eq(unit_state.mana_gain_multiplier_status, 0.0)
	assert_eq(unit_state.mana_gain_modifier_turns, 2)


func test_active_effect_entries_expose_clear_name_intensity_duration_and_source() -> void:
	var unit_state: BattleUnitState = _make_unit_state()

	unit_state.apply_turn_skip(2)
	unit_state.set_effect_source("turn_skip", "Prisao de Ossos", "support celula", "armadilha na celula")
	unit_state.apply_physical_shield(12, 3)
	unit_state.set_effect_source("physical_shield", "Muralha de Ossos", "support alvo", "escudo imediato")

	var stun_entry: Dictionary = _find_effect_entry(unit_state, "turn_skip")
	var shield_entry: Dictionary = _find_effect_entry(unit_state, "physical_shield")

	assert_eq(str(stun_entry.get("name", "")), "Atordoamento")
	assert_eq(str(stun_entry.get("intensity", "")), "pula a proxima acao")
	assert_eq(str(stun_entry.get("duration", "")), "2t")
	assert_eq(str(stun_entry.get("field_code", "")), "ATO")
	assert_eq(str(stun_entry.get("source_name", "")), "Prisao de Ossos")

	assert_eq(str(shield_entry.get("name", "")), "Escudo fisico")
	assert_eq(str(shield_entry.get("intensity", "")), "12 PV")
	assert_eq(str(shield_entry.get("duration", "")), "3t")
	assert_eq(str(shield_entry.get("source_kind", "")), "support alvo")


func test_field_status_summary_prioritizes_major_effects_and_support_sources_are_deduplicated() -> void:
	var unit_state: BattleUnitState = _make_unit_state()

	unit_state.apply_turn_skip(2)
	unit_state.set_effect_source("turn_skip", "Prisao de Ossos", "support celula")
	unit_state.apply_physical_miss_chance(0.5, 2)
	unit_state.set_effect_source("physical_miss", "Nevoa Cegante", "support global")
	unit_state.add_round_stat_bonus(3, 0, 2, 0)
	unit_state.set_effect_source("round_attack_bonus", "Coro de Guerra", "support alvo", "", "rodada")
	unit_state.set_effect_source("round_defense_bonus", "Coro de Guerra", "support alvo", "", "rodada")

	assert_eq(unit_state.get_field_status_summary(2), "ATO/CEG")

	var support_sources: Array[Dictionary] = unit_state.get_active_support_sources()
	assert_eq(support_sources.size(), 3)
	assert_eq(str(support_sources[0].get("source_name", "")), "Prisao de Ossos")
	assert_eq(str(support_sources[1].get("source_name", "")), "Nevoa Cegante")
	assert_eq(str(support_sources[2].get("source_name", "")), "Coro de Guerra")
