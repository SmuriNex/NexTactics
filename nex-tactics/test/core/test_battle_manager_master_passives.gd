extends GutTest

const BattleManagerScript := preload("res://scripts/battle/battle_manager.gd")
const BattleUnitStateScript := preload("res://scripts/battle/battle_unit_state.gd")
const UnitDataScript := preload("res://scripts/data/unit_data.gd")


func _make_unit_state(
	unit_id: String,
	class_type: int,
	max_hp: int,
	magic_attack: int,
	current_hp: int,
	is_master: bool = false
) -> BattleUnitState:
	var unit_data: UnitData = UnitDataScript.new()
	unit_data.id = unit_id
	unit_data.display_name = unit_id
	unit_data.class_type = class_type
	unit_data.max_hp = max_hp
	unit_data.physical_attack = 2
	unit_data.magic_attack = magic_attack
	unit_data.physical_defense = 2
	unit_data.magic_defense = 2
	unit_data.attack_range = 2

	var unit_state: BattleUnitState = BattleUnitStateScript.new().setup_from_unit_data(
		unit_data,
		GameEnums.TeamSide.PLAYER,
		Vector2i.ZERO,
		is_master
	)
	unit_state.current_hp = current_hp
	return unit_state


func test_lady_passive_heal_now_respects_turn_interval() -> void:
	var battle_manager: BattleManager = BattleManagerScript.new()
	var lady: BattleUnitState = _make_unit_state(
		"lady_of_lake_master",
		GameEnums.ClassType.SUPPORT,
		24,
		10,
		24,
		true
	)
	var ally: BattleUnitState = _make_unit_state(
		"injured_ally",
		GameEnums.ClassType.ATTACKER,
		20,
		0,
		10
	)
	battle_manager.runtime_units = [lady, ally]

	battle_manager.battle_turn_index = 1
	battle_manager._trigger_dama_passive_heals()
	assert_eq(ally.current_hp, 10, "A primeira cura da Dama nao deve sair imediatamente.")

	battle_manager.battle_turn_index = 2
	battle_manager._trigger_dama_passive_heals()
	assert_gt(ally.current_hp, 10, "A cura deve acontecer quando o intervalo minimo for alcancado.")

	var hp_after_first_heal: int = ally.current_hp
	ally.current_hp = hp_after_first_heal - 4

	battle_manager.battle_turn_index = 3
	battle_manager._trigger_dama_passive_heals()
	assert_eq(ally.current_hp, hp_after_first_heal - 4, "A cura nao deve repetir em turnos consecutivos.")

	battle_manager.battle_turn_index = 4
	battle_manager._trigger_dama_passive_heals()
	assert_gt(ally.current_hp, hp_after_first_heal - 4, "A proxima cura deve voltar apenas apos o novo intervalo.")
