extends RefCounted
class_name BattleUnitState

const TARGET_LOCK_MIN_TURNS := 2
const POSITION_HISTORY_LIMIT := 4

var unit_data: UnitData
var current_hp: int = 0
var current_mana: int = 0
var team_side: int = GameEnums.TeamSide.PLAYER
var coord: Vector2i = Vector2i.ZERO
var home_coord: Vector2i = Vector2i.ZERO
var alive: bool = true
var is_master: bool = false
var actor: UnitActor
var bonus_physical_attack: int = 0
var bonus_magic_attack: int = 0
var bonus_physical_defense: int = 0
var bonus_magic_defense: int = 0
var permanent_bonus_hp: int = 0
var permanent_bonus_physical_attack: int = 0
var permanent_bonus_magic_attack: int = 0
var permanent_bonus_physical_defense: int = 0
var permanent_bonus_magic_defense: int = 0
var deck_passive_physical_attack: int = 0
var deck_passive_magic_attack: int = 0
var deck_passive_physical_defense: int = 0
var deck_passive_magic_defense: int = 0
var synergy_race_count: int = 0
var synergy_tier: int = 0
var synergy_summary: String = ""
var synergy_physical_attack: int = 0
var synergy_magic_attack: int = 0
var synergy_physical_defense: int = 0
var synergy_magic_defense: int = 0
var synergy_crit_bonus: float = 0.0
var synergy_mana_bonus: int = 0
var synergy_undead_sustain_bonus: int = 0
var synergy_action_charge_bonus: int = 0
var action_charge: int = 0
var is_summoned_token: bool = false
var token_expires_end_round: bool = false
var source_unit_id: String = ""
var death_skill_consumed: bool = false
var physical_defense_multiplier_status: float = 1.0
var physical_defense_debuff_turns: int = 0
var magic_defense_multiplier_status: float = 1.0
var magic_defense_debuff_turns: int = 0
var mana_gain_multiplier_status: float = 1.0
var mana_gain_modifier_turns: int = 0
var action_charge_multiplier_status: float = 1.0
var action_charge_modifier_turns: int = 0
var skip_turns_remaining: int = 0
var stealth_turns_remaining: int = 0
var physical_miss_chance_status: float = 0.0
var physical_miss_turns: int = 0
var received_physical_damage_multiplier_status: float = 1.0
var received_physical_damage_turns: int = 0
var current_physical_shield: int = 0
var physical_shield_turns: int = 0
var current_magic_shield: int = 0
var magic_shield_turns: int = 0
var melee_reflect_damage: int = 0
var reflect_turns: int = 0
var melee_attacker_action_multiplier: float = 1.0
var melee_attacker_action_turns: int = 0
var guaranteed_magic_crit_hits: int = 0
var death_mana_ratio_to_master: float = 0.0
var blocked_basic_attack_count: int = 0
var lifesteal_ratio_status: float = 0.0
var lifesteal_turns: int = 0
var attack_range_bonus_status: int = 0
var attack_range_bonus_turns: int = 0
var cleave_attacks_remaining: int = 0
var forced_target_instance_id: int = -1
var forced_target_turns: int = 0
var charm_source_instance_id: int = -1
var charm_turns: int = 0
var current_target: BattleUnitState = null
var target_lock_timer: int = 0
var stuck_counter: int = 0
var last_positions: Array[Vector2i] = []
var last_position: Vector2i = Vector2i(-1, -1)
var previous_position: Vector2i = Vector2i(-1, -1)
var previous_target_key: String = ""
var bounce_counter: int = 0
var retarget_cooldown_turns: int = 0
var last_move_origin: Vector2i = Vector2i(-1, -1)
var last_move_destination: Vector2i = Vector2i(-1, -1)
var last_move_target_key: String = ""
var last_move_type: String = ""
var blocked_target_key: String = ""
var blocked_target_turns: int = 0

func setup_from_unit_data(
	p_unit_data: UnitData,
	p_team_side: int,
	p_coord: Vector2i,
	p_is_master: bool = false,
	p_home_coord: Vector2i = Vector2i(-1, -1)
) -> BattleUnitState:
	unit_data = p_unit_data
	team_side = p_team_side
	coord = p_coord
	home_coord = p_coord if p_home_coord == Vector2i(-1, -1) else p_home_coord
	is_master = p_is_master
	permanent_bonus_hp = 0
	permanent_bonus_physical_attack = 0
	permanent_bonus_magic_attack = 0
	permanent_bonus_physical_defense = 0
	permanent_bonus_magic_defense = 0

	if unit_data != null:
		current_hp = get_max_hp_value()
		current_mana = 0
	else:
		current_hp = 0
		current_mana = 0

	alive = true
	actor = null
	action_charge = 0
	is_summoned_token = false
	token_expires_end_round = false
	source_unit_id = ""
	death_skill_consumed = false
	clear_synergy_modifiers()
	clear_status_effects()
	clear_round_modifiers()
	clear_navigation_memory()
	remember_position_sample(coord)
	return self

func get_display_name() -> String:
	if unit_data == null:
		return "Unit"
	if not unit_data.display_name.is_empty():
		return unit_data.display_name
	return unit_data.id

func get_race_name() -> String:
	if unit_data == null:
		return "Desconhecida"

	match unit_data.race:
		GameEnums.Race.HUMAN:
			return "Humano"
		GameEnums.Race.ELF:
			return "Elfo"
		GameEnums.Race.FAIRY:
			return "Fada"
		GameEnums.Race.OGRE:
			return "Ogro"
		GameEnums.Race.UNDEAD:
			return "Morto-vivo"
		GameEnums.Race.BEAST:
			return "Besta"
		_:
			return "Desconhecida"

func get_race_short_label() -> String:
	if unit_data == null:
		return "UNK"

	match unit_data.race:
		GameEnums.Race.HUMAN:
			return "HUM"
		GameEnums.Race.ELF:
			return "ELF"
		GameEnums.Race.FAIRY:
			return "FAE"
		GameEnums.Race.OGRE:
			return "OGR"
		GameEnums.Race.UNDEAD:
			return "UND"
		GameEnums.Race.BEAST:
			return "BST"
		_:
			return "UNK"

func get_class_name() -> String:
	if unit_data == null:
		return "Unidade"
	if not unit_data.class_label.is_empty():
		return unit_data.class_label

	match unit_data.class_type:
		GameEnums.ClassType.ATTACKER:
			return "Atacante"
		GameEnums.ClassType.TANK:
			return "Tanque"
		GameEnums.ClassType.SNIPER:
			return "Atirador"
		GameEnums.ClassType.SUPPORT:
			return "Suporte"
		GameEnums.ClassType.STEALTH:
			return "Batedor"
		_:
			return "Unidade"

func get_race_passive_description() -> String:
	if unit_data == null:
		return "Tag tematica sem bonus mecanico."
	return "Tag tematica sem bonus mecanico."

func get_class_role_description() -> String:
	if unit_data == null:
		return "Unidade basica."

	match unit_data.class_type:
		GameEnums.ClassType.ATTACKER:
			return "Dano direto."
		GameEnums.ClassType.TANK:
			return "Linha de frente resistente."
		GameEnums.ClassType.SNIPER:
			return "Finaliza a distancia."
		GameEnums.ClassType.SUPPORT:
			return "Utilidade."
		GameEnums.ClassType.STEALTH:
			return "Pressao rapida e fragil."
		_:
			return "Unidade basica."

func get_class_short_label() -> String:
	if unit_data == null:
		return "UNI"
	if not unit_data.class_short_label.is_empty():
		return unit_data.class_short_label

	match unit_data.class_type:
		GameEnums.ClassType.ATTACKER:
			return "ATK"
		GameEnums.ClassType.TANK:
			return "TNK"
		GameEnums.ClassType.SNIPER:
			return "SNP"
		GameEnums.ClassType.SUPPORT:
			return "SUP"
		GameEnums.ClassType.STEALTH:
			return "SCT"
		_:
			return "UNI"

func get_combat_label() -> String:
	return "%s [%s/%s]" % [get_display_name(), get_race_short_label(), get_class_short_label()]

func can_act() -> bool:
	return alive and current_hp > 0 and unit_data != null

func is_tank_unit() -> bool:
	return unit_data != null and unit_data.class_type == GameEnums.ClassType.TANK

func is_attacker_unit() -> bool:
	return unit_data != null and unit_data.class_type == GameEnums.ClassType.ATTACKER

func is_stealth_unit() -> bool:
	return unit_data != null and unit_data.class_type == GameEnums.ClassType.STEALTH

func is_sniper_unit() -> bool:
	return unit_data != null and unit_data.class_type == GameEnums.ClassType.SNIPER

func is_support_unit() -> bool:
	return unit_data != null and unit_data.class_type == GameEnums.ClassType.SUPPORT

func is_ranged_unit() -> bool:
	return unit_data != null and (
		unit_data.class_type == GameEnums.ClassType.SNIPER
		or unit_data.class_type == GameEnums.ClassType.SUPPORT
		or get_attack_range() >= 3
	)

func get_race_attack_bonus() -> int:
	return get_race_physical_attack_bonus() + get_race_magic_attack_bonus()

func get_race_physical_attack_bonus() -> int:
	return 0

func get_race_magic_attack_bonus() -> int:
	return 0

func get_class_attack_bonus() -> int:
	return get_class_physical_attack_bonus() + get_class_magic_attack_bonus()

func get_class_physical_attack_bonus() -> int:
	if unit_data == null:
		return 0
	if is_attacker_unit():
		return 1
	if is_master:
		return 1
	return 0

func get_class_magic_attack_bonus() -> int:
	return 0

func get_physical_attack_value() -> int:
	if unit_data == null:
		return 0
	return unit_data.physical_attack + get_race_physical_attack_bonus() + get_class_physical_attack_bonus() + synergy_physical_attack + bonus_physical_attack + permanent_bonus_physical_attack + deck_passive_physical_attack

func get_magic_attack_value() -> int:
	if unit_data == null:
		return 0
	return unit_data.magic_attack + get_race_magic_attack_bonus() + get_class_magic_attack_bonus() + synergy_magic_attack + bonus_magic_attack + permanent_bonus_magic_attack + deck_passive_magic_attack

func get_attack_value() -> int:
	return get_physical_attack_value() + get_magic_attack_value()

func get_race_defense_bonus() -> int:
	return get_race_physical_defense_bonus() + get_race_magic_defense_bonus()

func get_race_physical_defense_bonus() -> int:
	return 0

func get_race_magic_defense_bonus() -> int:
	return 0

func get_class_defense_bonus() -> int:
	return get_class_physical_defense_bonus() + get_class_magic_defense_bonus()

func get_class_physical_defense_bonus() -> int:
	if unit_data == null:
		return 0
	if is_tank_unit():
		return 2
	if is_master:
		return 1
	return 0

func get_class_magic_defense_bonus() -> int:
	return 0

func get_physical_defense_value() -> int:
	if unit_data == null:
		return 0
	var raw_value: int = unit_data.physical_defense + get_race_physical_defense_bonus() + get_class_physical_defense_bonus() + synergy_physical_defense + bonus_physical_defense + permanent_bonus_physical_defense + deck_passive_physical_defense
	return maxi(0, int(round(float(raw_value) * physical_defense_multiplier_status)))

func get_magic_defense_value() -> int:
	if unit_data == null:
		return 0
	var raw_value: int = unit_data.magic_defense + get_race_magic_defense_bonus() + get_class_magic_defense_bonus() + synergy_magic_defense + bonus_magic_defense + permanent_bonus_magic_defense + deck_passive_magic_defense
	return maxi(0, int(round(float(raw_value) * magic_defense_multiplier_status)))

func get_defense_value() -> int:
	return get_physical_defense_value() + get_magic_defense_value()

func get_base_range_by_class() -> int:
	if unit_data == null:
		return 1

	match unit_data.class_type:
		GameEnums.ClassType.TANK:
			return 1
		GameEnums.ClassType.ATTACKER:
			return 1
		GameEnums.ClassType.SUPPORT:
			return 2
		GameEnums.ClassType.STEALTH:
			return 3
		GameEnums.ClassType.SNIPER:
			return 4
		_:
			return 1

func get_attack_range() -> int:
	if unit_data == null:
		return 1
	var base_range: int = unit_data.attack_range if unit_data.attack_range > 0 else get_base_range_by_class()
	return maxi(1, base_range + attack_range_bonus_status)

func get_race_crit_bonus() -> float:
	return 0.0

func get_crit_chance() -> float:
	if unit_data == null:
		return 0.0
	return clampf(unit_data.crit_chance + get_race_crit_bonus() + synergy_crit_bonus, 0.0, 0.85)

func get_mana_max() -> int:
	if unit_data == null:
		return 0
	return maxi(1, unit_data.mana_max)

func get_max_hp_value() -> int:
	if unit_data == null:
		return 0
	return maxi(1, unit_data.max_hp + permanent_bonus_hp)

func get_race_mana_bonus() -> int:
	return 0

func get_race_action_charge_bonus() -> int:
	return 0

func get_action_charge_gain() -> int:
	var base_value: int = 100 + get_race_action_charge_bonus() + synergy_action_charge_bonus
	return maxi(1, int(round(float(base_value) * action_charge_multiplier_status)))

func gain_action_charge() -> void:
	action_charge += get_action_charge_gain()

func can_take_turn_from_charge() -> bool:
	return action_charge >= 100

func consume_action_charge() -> void:
	action_charge = maxi(0, action_charge - 100)

func refund_action_charge(amount: int) -> void:
	action_charge = maxi(0, action_charge + amount)

func get_class_mana_bonus() -> int:
	if is_support_unit():
		return 2
	return 0

func get_mana_gain_on_attack() -> int:
	if unit_data == null:
		return 0
	var raw_value: int = unit_data.mana_gain_on_attack + get_race_mana_bonus() + get_class_mana_bonus() + synergy_mana_bonus
	return maxi(0, int(round(float(raw_value) * mana_gain_multiplier_status)))

func get_mana_gain_on_hit() -> int:
	if unit_data == null:
		return 0
	var raw_value: int = unit_data.mana_gain_on_hit + get_race_mana_bonus() + synergy_mana_bonus
	return maxi(0, int(round(float(raw_value) * mana_gain_multiplier_status)))

func gain_mana(amount: int) -> int:
	if unit_data == null or amount <= 0 or is_dead():
		return 0

	var before: int = current_mana
	current_mana = clampi(current_mana + amount, 0, get_mana_max())
	return current_mana - before

func spend_mana(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_mana < amount:
		return false

	current_mana -= amount
	return true

func is_master_skill_ready() -> bool:
	return is_master and can_act() and current_mana >= get_mana_max()

func has_master_skill() -> bool:
	return is_master and unit_data != null and unit_data.master_skill_data != null

func get_master_skill_data() -> SkillData:
	if not has_master_skill():
		return null
	return unit_data.master_skill_data

func get_master_skill_name() -> String:
	var skill_data: SkillData = get_master_skill_data()
	if skill_data == null:
		return ""
	if not skill_data.display_name.is_empty():
		return skill_data.display_name
	return skill_data.id

func has_unit_skill() -> bool:
	return unit_data != null and unit_data.skill_data != null and not is_master

func get_skill_data() -> SkillData:
	if not has_unit_skill():
		return null
	return unit_data.skill_data

func get_skill_name() -> String:
	var skill_data: SkillData = get_skill_data()
	if skill_data == null:
		return ""
	if not skill_data.display_name.is_empty():
		return skill_data.display_name
	return skill_data.id

func get_skill_mana_cost() -> int:
	var skill_data: SkillData = get_skill_data()
	if skill_data == null:
		return 0
	return maxi(0, skill_data.mana_cost)

func get_skill_range() -> int:
	var skill_data: SkillData = get_skill_data()
	if skill_data == null:
		return 1
	return maxi(1, skill_data.range)

func is_unit_skill_ready() -> bool:
	return has_unit_skill() and can_act() and current_mana >= get_skill_mana_cost()

func get_undead_lifesteal(did_kill: bool) -> int:
	return 0

func reset_for_new_round() -> void:
	if unit_data == null:
		return

	current_hp = get_max_hp_value()
	current_mana = 0
	action_charge = 0
	alive = true
	clear_synergy_modifiers()
	clear_status_effects()
	clear_round_modifiers()
	clear_navigation_memory()

func clear_round_modifiers() -> void:
	bonus_physical_attack = 0
	bonus_magic_attack = 0
	bonus_physical_defense = 0
	bonus_magic_defense = 0
	clear_deck_passive_modifiers()

func clear_deck_passive_modifiers() -> void:
	deck_passive_physical_attack = 0
	deck_passive_magic_attack = 0
	deck_passive_physical_defense = 0
	deck_passive_magic_defense = 0

func clear_navigation_memory() -> void:
	clear_target_lock()
	stuck_counter = 0
	last_positions.clear()
	last_position = Vector2i(-1, -1)
	previous_position = Vector2i(-1, -1)
	previous_target_key = ""
	bounce_counter = 0
	retarget_cooldown_turns = 0
	last_move_origin = Vector2i(-1, -1)
	last_move_destination = Vector2i(-1, -1)
	last_move_target_key = ""
	last_move_type = ""
	blocked_target_key = ""
	blocked_target_turns = 0

func set_current_target(target: BattleUnitState, lock_turns: int = TARGET_LOCK_MIN_TURNS) -> void:
	if target == current_target:
		target_lock_timer = maxi(target_lock_timer, lock_turns)
		return
	current_target = target
	target_lock_timer = maxi(0, lock_turns) if target != null else 0
	stuck_counter = 0

func clear_target_lock() -> void:
	current_target = null
	target_lock_timer = 0

func has_valid_current_target() -> bool:
	return current_target != null and current_target.can_act()

func remember_position_sample(sample_coord: Vector2i) -> void:
	if sample_coord == Vector2i(-1, -1):
		return
	last_positions.append(sample_coord)
	while last_positions.size() > POSITION_HISTORY_LIMIT:
		last_positions.remove_at(0)

func has_position_loop() -> bool:
	if last_positions.size() >= 3:
		var last_index: int = last_positions.size() - 1
		if last_positions[last_index] == last_positions[last_index - 2] and last_positions[last_index - 1] != last_positions[last_index]:
			return true
	if last_positions.size() >= 4:
		var max_index: int = last_positions.size() - 1
		if (
			last_positions[max_index] == last_positions[max_index - 2]
			and last_positions[max_index - 1] == last_positions[max_index - 3]
			and last_positions[max_index] != last_positions[max_index - 1]
		):
			return true
	return false

func mark_stuck() -> void:
	stuck_counter += 1
	remember_position_sample(coord)

func clear_stuck() -> void:
	stuck_counter = 0

func should_force_retarget(stuck_limit: int) -> bool:
	return stuck_counter > stuck_limit or has_position_loop()

func remember_navigation_move(target_key: String, move_type: String, from_coord: Vector2i, to_coord: Vector2i) -> void:
	var bounced_back: bool = (
		last_move_target_key == target_key
		and last_move_origin == to_coord
		and last_move_destination == from_coord
	)
	previous_position = last_position
	last_position = from_coord
	if bounced_back:
		bounce_counter += 1
		retarget_cooldown_turns = maxi(retarget_cooldown_turns, 2)
	else:
		bounce_counter = maxi(0, bounce_counter - 1)
	if not target_key.is_empty() and target_key != last_move_target_key:
		previous_target_key = last_move_target_key
	last_move_origin = from_coord
	last_move_destination = to_coord
	last_move_target_key = target_key
	last_move_type = move_type
	stuck_counter = 0
	remember_position_sample(to_coord)
	clear_blocked_target()

func remember_blocked_target(target_key: String) -> void:
	if target_key.is_empty():
		clear_blocked_target()
		return
	if blocked_target_key == target_key:
		blocked_target_turns += 1
	else:
		blocked_target_key = target_key
		blocked_target_turns = 1

func clear_blocked_target() -> void:
	blocked_target_key = ""
	blocked_target_turns = 0

func get_blocked_target_penalty(target_key: String) -> int:
	if target_key.is_empty():
		return 0
	if blocked_target_key != target_key or blocked_target_turns < 2:
		return 0
	return 240 + ((blocked_target_turns - 2) * 60)

func get_recent_target_penalty(target_key: String) -> int:
	if target_key.is_empty():
		return 0
	var penalty: int = 0
	if retarget_cooldown_turns > 0 and target_key == last_move_target_key:
		penalty += 320
	if previous_target_key == target_key:
		penalty += 90
	if bounce_counter >= 2 and target_key == last_move_target_key:
		penalty += 180
	return penalty

func has_navigation_loop_pressure() -> bool:
	return bounce_counter >= 2 or blocked_target_turns >= 2

func get_bounce_forbidden_coord(target_key: String) -> Vector2i:
	if target_key.is_empty():
		return Vector2i(-1, -1)
	if target_key != last_move_target_key:
		return Vector2i(-1, -1)
	if coord != last_move_destination:
		return Vector2i(-1, -1)
	if bounce_counter >= 2 and previous_position != Vector2i(-1, -1):
		return previous_position
	if last_move_type != "sidestep" and last_move_type != "fallback":
		return Vector2i(-1, -1)
	return last_move_origin

func add_round_stat_bonus(
	p_physical_attack: int = 0,
	p_magic_attack: int = 0,
	p_physical_defense: int = 0,
	p_magic_defense: int = 0
) -> void:
	bonus_physical_attack += p_physical_attack
	bonus_magic_attack += p_magic_attack
	bonus_physical_defense += p_physical_defense
	bonus_magic_defense += p_magic_defense

func apply_permanent_stat_bonus(
	p_hp_bonus: int = 0,
	p_physical_attack: int = 0,
	p_magic_attack: int = 0,
	p_physical_defense: int = 0,
	p_magic_defense: int = 0
) -> void:
	permanent_bonus_hp += p_hp_bonus
	permanent_bonus_physical_attack += p_physical_attack
	permanent_bonus_magic_attack += p_magic_attack
	permanent_bonus_physical_defense += p_physical_defense
	permanent_bonus_magic_defense += p_magic_defense
	if p_hp_bonus > 0:
		current_hp = mini(get_max_hp_value(), current_hp + p_hp_bonus)

func has_permanent_stat_bonus() -> bool:
	return (
		permanent_bonus_hp != 0
		or permanent_bonus_physical_attack != 0
		or permanent_bonus_magic_attack != 0
		or permanent_bonus_physical_defense != 0
		or permanent_bonus_magic_defense != 0
	)

func get_permanent_stat_bonus_text() -> String:
	var parts: Array[String] = []
	if permanent_bonus_hp != 0:
		parts.append("+%d PV" % permanent_bonus_hp)
	if permanent_bonus_physical_attack != 0:
		parts.append("+%d ATQ F" % permanent_bonus_physical_attack)
	if permanent_bonus_magic_attack != 0:
		parts.append("+%d ATQ M" % permanent_bonus_magic_attack)
	if permanent_bonus_physical_defense != 0:
		parts.append("+%d DEF F" % permanent_bonus_physical_defense)
	if permanent_bonus_magic_defense != 0:
		parts.append("+%d DEF M" % permanent_bonus_magic_defense)
	return _join_strings(parts)

func has_round_stat_bonus() -> bool:
	return (
		bonus_physical_attack != 0
		or bonus_magic_attack != 0
		or bonus_physical_defense != 0
		or bonus_magic_defense != 0
	)

func clear_synergy_modifiers() -> void:
	synergy_race_count = 0
	synergy_tier = 0
	synergy_summary = ""
	synergy_physical_attack = 0
	synergy_magic_attack = 0
	synergy_physical_defense = 0
	synergy_magic_defense = 0
	synergy_crit_bonus = 0.0
	synergy_mana_bonus = 0
	synergy_undead_sustain_bonus = 0
	synergy_action_charge_bonus = 0

func clear_status_effects() -> void:
	death_skill_consumed = false
	physical_defense_multiplier_status = 1.0
	physical_defense_debuff_turns = 0
	magic_defense_multiplier_status = 1.0
	magic_defense_debuff_turns = 0
	mana_gain_multiplier_status = 1.0
	mana_gain_modifier_turns = 0
	action_charge_multiplier_status = 1.0
	action_charge_modifier_turns = 0
	skip_turns_remaining = 0
	stealth_turns_remaining = 0
	physical_miss_chance_status = 0.0
	physical_miss_turns = 0
	received_physical_damage_multiplier_status = 1.0
	received_physical_damage_turns = 0
	current_physical_shield = 0
	physical_shield_turns = 0
	current_magic_shield = 0
	magic_shield_turns = 0
	melee_reflect_damage = 0
	reflect_turns = 0
	melee_attacker_action_multiplier = 1.0
	melee_attacker_action_turns = 0
	guaranteed_magic_crit_hits = 0
	death_mana_ratio_to_master = 0.0
	blocked_basic_attack_count = 0
	lifesteal_ratio_status = 0.0
	lifesteal_turns = 0
	attack_range_bonus_status = 0
	attack_range_bonus_turns = 0
	cleave_attacks_remaining = 0
	forced_target_instance_id = -1
	forced_target_turns = 0
	charm_source_instance_id = -1
	charm_turns = 0

func mark_as_summoned_token(p_source_unit_id: String) -> void:
	is_summoned_token = true
	token_expires_end_round = true
	source_unit_id = p_source_unit_id

func apply_physical_defense_multiplier(multiplier: float, turns: int) -> void:
	physical_defense_multiplier_status = mini(physical_defense_multiplier_status, multiplier)
	physical_defense_debuff_turns = maxi(physical_defense_debuff_turns, turns)

func apply_magic_defense_multiplier(multiplier: float, turns: int) -> void:
	magic_defense_multiplier_status = mini(magic_defense_multiplier_status, multiplier)
	magic_defense_debuff_turns = maxi(magic_defense_debuff_turns, turns)

func apply_mana_gain_multiplier(multiplier: float, turns: int) -> void:
	mana_gain_multiplier_status = mini(mana_gain_multiplier_status, multiplier)
	mana_gain_modifier_turns = maxi(mana_gain_modifier_turns, turns)

func apply_action_charge_multiplier(multiplier: float, turns: int) -> void:
	if multiplier >= 1.0:
		action_charge_multiplier_status = maxf(action_charge_multiplier_status, multiplier)
	else:
		action_charge_multiplier_status = minf(action_charge_multiplier_status, multiplier)
	action_charge_modifier_turns = maxi(action_charge_modifier_turns, turns)

func apply_turn_skip(turns: int) -> void:
	skip_turns_remaining = maxi(skip_turns_remaining, turns)

func apply_stealth(turns: int) -> void:
	stealth_turns_remaining = maxi(stealth_turns_remaining, turns)

func apply_physical_miss_chance(chance: float, turns: int) -> void:
	physical_miss_chance_status = maxf(physical_miss_chance_status, chance)
	physical_miss_turns = maxi(physical_miss_turns, turns)

func apply_received_physical_damage_multiplier(multiplier: float, turns: int) -> void:
	received_physical_damage_multiplier_status = maxf(received_physical_damage_multiplier_status, multiplier)
	received_physical_damage_turns = maxi(received_physical_damage_turns, turns)

func apply_physical_shield(amount: int, turns: int, reflect_damage_amount: int = 0) -> void:
	current_physical_shield = maxi(current_physical_shield, amount)
	physical_shield_turns = maxi(physical_shield_turns, turns)
	melee_reflect_damage = maxi(melee_reflect_damage, reflect_damage_amount)
	reflect_turns = maxi(reflect_turns, turns)

func apply_magic_shield(amount: int, turns: int) -> void:
	current_magic_shield = maxi(current_magic_shield, amount)
	magic_shield_turns = maxi(magic_shield_turns, turns)

func apply_melee_attacker_action_multiplier(multiplier: float, turns: int) -> void:
	melee_attacker_action_multiplier = minf(melee_attacker_action_multiplier, multiplier)
	melee_attacker_action_turns = maxi(melee_attacker_action_turns, turns)

func apply_magic_crit_gift(hit_count: int) -> void:
	guaranteed_magic_crit_hits = maxi(guaranteed_magic_crit_hits, hit_count)

func apply_blood_pact(mana_ratio: float) -> void:
	death_mana_ratio_to_master = maxf(death_mana_ratio_to_master, mana_ratio)

func apply_basic_attack_block(count: int) -> void:
	blocked_basic_attack_count = maxi(blocked_basic_attack_count, count)

func consume_basic_attack_block() -> bool:
	if blocked_basic_attack_count <= 0:
		return false
	blocked_basic_attack_count -= 1
	return true

func apply_lifesteal_ratio(ratio: float, turns: int) -> void:
	lifesteal_ratio_status = maxf(lifesteal_ratio_status, ratio)
	lifesteal_turns = maxi(lifesteal_turns, turns)

func get_lifesteal_ratio() -> float:
	return lifesteal_ratio_status

func apply_attack_range_bonus(bonus: int, turns: int) -> void:
	attack_range_bonus_status = maxi(attack_range_bonus_status, bonus)
	attack_range_bonus_turns = maxi(attack_range_bonus_turns, turns)

func apply_cleave_attacks(count: int) -> void:
	cleave_attacks_remaining = maxi(cleave_attacks_remaining, count)

func has_cleave_attacks() -> bool:
	return cleave_attacks_remaining > 0

func consume_cleave_attack() -> bool:
	if cleave_attacks_remaining <= 0:
		return false
	cleave_attacks_remaining -= 1
	return true

func apply_forced_target(target: BattleUnitState, turns: int) -> void:
	if target == null:
		return
	forced_target_instance_id = target.get_instance_id()
	forced_target_turns = maxi(forced_target_turns, turns)

func apply_charm(source: BattleUnitState, turns: int) -> void:
	if source == null:
		return
	charm_source_instance_id = source.get_instance_id()
	charm_turns = maxi(charm_turns, turns)
	apply_action_charge_multiplier(0.5, turns)

func has_forced_target() -> bool:
	return forced_target_turns > 0 and forced_target_instance_id != -1

func is_forced_target(target: BattleUnitState) -> bool:
	return target != null and has_forced_target() and target.get_instance_id() == forced_target_instance_id

func clear_forced_target() -> void:
	forced_target_instance_id = -1
	forced_target_turns = 0

func is_charmed() -> bool:
	return charm_turns > 0 and charm_source_instance_id != -1

func is_charmed_by(target: BattleUnitState) -> bool:
	return target != null and is_charmed() and target.get_instance_id() == charm_source_instance_id

func clear_charm() -> void:
	charm_source_instance_id = -1
	charm_turns = 0

func has_magic_crit_gift() -> bool:
	return guaranteed_magic_crit_hits > 0

func consume_magic_crit_gift() -> bool:
	if guaranteed_magic_crit_hits <= 0:
		return false
	guaranteed_magic_crit_hits -= 1
	return true

func is_stealthed() -> bool:
	return stealth_turns_remaining > 0

func has_turn_skip() -> bool:
	return skip_turns_remaining > 0

func consume_skip_turn() -> bool:
	if skip_turns_remaining <= 0:
		return false
	skip_turns_remaining -= 1
	return true

func get_physical_miss_chance() -> float:
	return physical_miss_chance_status

func get_received_physical_damage_multiplier() -> float:
	return received_physical_damage_multiplier_status

func absorb_physical_damage(amount: int) -> Dictionary:
	if amount <= 0 or current_physical_shield <= 0:
		return {"remaining": maxi(0, amount), "absorbed": 0}

	var absorbed: int = mini(current_physical_shield, amount)
	current_physical_shield -= absorbed
	return {
		"remaining": maxi(0, amount - absorbed),
		"absorbed": absorbed,
	}

func absorb_magic_damage(amount: int) -> Dictionary:
	if amount <= 0 or current_magic_shield <= 0:
		return {"remaining": maxi(0, amount), "absorbed": 0}

	var absorbed: int = mini(current_magic_shield, amount)
	current_magic_shield -= absorbed
	return {
		"remaining": maxi(0, amount - absorbed),
		"absorbed": absorbed,
	}

func get_melee_reflect_damage() -> int:
	if reflect_turns <= 0:
		return 0
	return melee_reflect_damage

func get_melee_attacker_action_multiplier() -> float:
	if melee_attacker_action_turns <= 0:
		return 1.0
	return melee_attacker_action_multiplier

func clear_negative_effects() -> void:
	physical_defense_multiplier_status = 1.0
	physical_defense_debuff_turns = 0
	magic_defense_multiplier_status = 1.0
	magic_defense_debuff_turns = 0
	if mana_gain_multiplier_status < 1.0:
		mana_gain_multiplier_status = 1.0
		mana_gain_modifier_turns = 0
	if action_charge_multiplier_status < 1.0:
		action_charge_multiplier_status = 1.0
		action_charge_modifier_turns = 0
	skip_turns_remaining = 0
	physical_miss_chance_status = 0.0
	physical_miss_turns = 0
	received_physical_damage_multiplier_status = 1.0
	received_physical_damage_turns = 0
	clear_forced_target()
	clear_charm()

func clear_positive_effects() -> void:
	bonus_physical_attack = 0
	bonus_magic_attack = 0
	bonus_physical_defense = 0
	bonus_magic_defense = 0
	if mana_gain_multiplier_status > 1.0:
		mana_gain_multiplier_status = 1.0
		mana_gain_modifier_turns = 0
	if action_charge_multiplier_status > 1.0:
		action_charge_multiplier_status = 1.0
		action_charge_modifier_turns = 0
	stealth_turns_remaining = 0
	current_physical_shield = 0
	physical_shield_turns = 0
	current_magic_shield = 0
	magic_shield_turns = 0
	melee_reflect_damage = 0
	reflect_turns = 0
	melee_attacker_action_multiplier = 1.0
	melee_attacker_action_turns = 0
	guaranteed_magic_crit_hits = 0
	blocked_basic_attack_count = 0
	lifesteal_ratio_status = 0.0
	lifesteal_turns = 0
	attack_range_bonus_status = 0
	attack_range_bonus_turns = 0
	cleave_attacks_remaining = 0

func advance_turn_effects() -> void:
	if physical_defense_debuff_turns > 0:
		physical_defense_debuff_turns -= 1
		if physical_defense_debuff_turns <= 0:
			physical_defense_multiplier_status = 1.0

	if magic_defense_debuff_turns > 0:
		magic_defense_debuff_turns -= 1
		if magic_defense_debuff_turns <= 0:
			magic_defense_multiplier_status = 1.0

	if mana_gain_modifier_turns > 0:
		mana_gain_modifier_turns -= 1
		if mana_gain_modifier_turns <= 0:
			mana_gain_multiplier_status = 1.0

	if action_charge_modifier_turns > 0:
		action_charge_modifier_turns -= 1
		if action_charge_modifier_turns <= 0:
			action_charge_multiplier_status = 1.0

	if physical_miss_turns > 0:
		physical_miss_turns -= 1
		if physical_miss_turns <= 0:
			physical_miss_chance_status = 0.0

	if received_physical_damage_turns > 0:
		received_physical_damage_turns -= 1
		if received_physical_damage_turns <= 0:
			received_physical_damage_multiplier_status = 1.0

	if physical_shield_turns > 0:
		physical_shield_turns -= 1
		if physical_shield_turns <= 0:
			current_physical_shield = 0

	if magic_shield_turns > 0:
		magic_shield_turns -= 1
		if magic_shield_turns <= 0:
			current_magic_shield = 0

	if reflect_turns > 0:
		reflect_turns -= 1
		if reflect_turns <= 0:
			melee_reflect_damage = 0

	if melee_attacker_action_turns > 0:
		melee_attacker_action_turns -= 1
		if melee_attacker_action_turns <= 0:
			melee_attacker_action_multiplier = 1.0

	if lifesteal_turns > 0:
		lifesteal_turns -= 1
		if lifesteal_turns <= 0:
			lifesteal_ratio_status = 0.0

	if attack_range_bonus_turns > 0:
		attack_range_bonus_turns -= 1
		if attack_range_bonus_turns <= 0:
			attack_range_bonus_status = 0

	if forced_target_turns > 0:
		forced_target_turns -= 1
		if forced_target_turns <= 0:
			clear_forced_target()

	if charm_turns > 0:
		charm_turns -= 1
		if charm_turns <= 0:
			clear_charm()

	if target_lock_timer > 0:
		target_lock_timer -= 1

	if stealth_turns_remaining > 0:
		stealth_turns_remaining -= 1

	if retarget_cooldown_turns > 0:
		retarget_cooldown_turns -= 1

func apply_race_synergy(
	race_count: int,
	tier: int,
	physical_attack_bonus: int = 0,
	magic_attack_bonus: int = 0,
	physical_defense_bonus: int = 0,
	magic_defense_bonus: int = 0,
	crit_bonus: float = 0.0,
	mana_bonus: int = 0,
	undead_sustain_bonus: int = 0,
	action_charge_bonus: int = 0,
	summary_text: String = ""
) -> void:
	synergy_race_count = race_count
	synergy_tier = tier
	synergy_summary = summary_text
	synergy_physical_attack = physical_attack_bonus
	synergy_magic_attack = magic_attack_bonus
	synergy_physical_defense = physical_defense_bonus
	synergy_magic_defense = magic_defense_bonus
	synergy_crit_bonus = crit_bonus
	synergy_mana_bonus = mana_bonus
	synergy_undead_sustain_bonus = undead_sustain_bonus
	synergy_action_charge_bonus = action_charge_bonus

func has_active_race_synergy() -> bool:
	return false

func get_active_race_synergy_text() -> String:
	return "Racas sao apenas tags tematicas."

func _join_strings(values: Array[String], separator: String = ", ") -> String:
	var result: String = ""
	for value in values:
		if result.is_empty():
			result = value
		else:
			result += separator + value
	return result

func heal(amount: int) -> int:
	if unit_data == null or amount <= 0 or is_dead():
		return 0

	var before: int = current_hp
	current_hp = mini(get_max_hp_value(), current_hp + amount)
	return current_hp - before

func take_damage(amount: int) -> int:
	var applied: int = maxi(0, amount)
	current_hp -= applied
	if current_hp <= 0:
		current_hp = 0
		alive = false
	return applied

func is_dead() -> bool:
	return not alive or current_hp <= 0
