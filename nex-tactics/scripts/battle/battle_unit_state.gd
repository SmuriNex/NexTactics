extends RefCounted
class_name BattleUnitState

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
var skip_turns_remaining: int = 0
var stealth_turns_remaining: int = 0
var physical_miss_chance_status: float = 0.0
var physical_miss_turns: int = 0
var current_physical_shield: int = 0
var physical_shield_turns: int = 0
var melee_reflect_damage: int = 0
var reflect_turns: int = 0
var guaranteed_magic_crit_hits: int = 0
var death_mana_ratio_to_master: float = 0.0
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

	if unit_data != null:
		current_hp = unit_data.max_hp
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

func is_sniper_unit() -> bool:
	return unit_data != null and (
		unit_data.class_type == GameEnums.ClassType.SNIPER
		or unit_data.class_type == GameEnums.ClassType.STEALTH
	)

func is_support_unit() -> bool:
	return unit_data != null and unit_data.class_type == GameEnums.ClassType.SUPPORT

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
	return unit_data.physical_attack + get_race_physical_attack_bonus() + get_class_physical_attack_bonus() + synergy_physical_attack + bonus_physical_attack

func get_magic_attack_value() -> int:
	if unit_data == null:
		return 0
	return unit_data.magic_attack + get_race_magic_attack_bonus() + get_class_magic_attack_bonus() + synergy_magic_attack + bonus_magic_attack

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
	var raw_value: int = unit_data.physical_defense + get_race_physical_defense_bonus() + get_class_physical_defense_bonus() + synergy_physical_defense + bonus_physical_defense
	return maxi(0, int(round(float(raw_value) * physical_defense_multiplier_status)))

func get_magic_defense_value() -> int:
	if unit_data == null:
		return 0
	var raw_value: int = unit_data.magic_defense + get_race_magic_defense_bonus() + get_class_magic_defense_bonus() + synergy_magic_defense + bonus_magic_defense
	return maxi(0, int(round(float(raw_value) * magic_defense_multiplier_status)))

func get_defense_value() -> int:
	return get_physical_defense_value() + get_magic_defense_value()

func get_class_range_bonus() -> int:
	if is_sniper_unit():
		return 1
	return 0

func get_attack_range() -> int:
	if unit_data == null:
		return 1
	return maxi(1, unit_data.attack_range + get_class_range_bonus())

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

func get_race_mana_bonus() -> int:
	return 0

func get_race_action_charge_bonus() -> int:
	return 0

func get_action_charge_gain() -> int:
	return 100 + get_race_action_charge_bonus() + synergy_action_charge_bonus

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

	current_hp = unit_data.max_hp
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

func clear_navigation_memory() -> void:
	last_move_origin = Vector2i(-1, -1)
	last_move_destination = Vector2i(-1, -1)
	last_move_target_key = ""
	last_move_type = ""
	blocked_target_key = ""
	blocked_target_turns = 0

func remember_navigation_move(target_key: String, move_type: String, from_coord: Vector2i, to_coord: Vector2i) -> void:
	last_move_origin = from_coord
	last_move_destination = to_coord
	last_move_target_key = target_key
	last_move_type = move_type
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

func get_bounce_forbidden_coord(target_key: String) -> Vector2i:
	if target_key.is_empty():
		return Vector2i(-1, -1)
	if target_key != last_move_target_key:
		return Vector2i(-1, -1)
	if coord != last_move_destination:
		return Vector2i(-1, -1)
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
	skip_turns_remaining = 0
	stealth_turns_remaining = 0
	physical_miss_chance_status = 0.0
	physical_miss_turns = 0
	current_physical_shield = 0
	physical_shield_turns = 0
	melee_reflect_damage = 0
	reflect_turns = 0
	guaranteed_magic_crit_hits = 0
	death_mana_ratio_to_master = 0.0

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

func apply_turn_skip(turns: int) -> void:
	skip_turns_remaining = maxi(skip_turns_remaining, turns)

func apply_stealth(turns: int) -> void:
	stealth_turns_remaining = maxi(stealth_turns_remaining, turns)

func apply_physical_miss_chance(chance: float, turns: int) -> void:
	physical_miss_chance_status = maxf(physical_miss_chance_status, chance)
	physical_miss_turns = maxi(physical_miss_turns, turns)

func apply_physical_shield(amount: int, turns: int, reflect_damage_amount: int = 0) -> void:
	current_physical_shield = maxi(current_physical_shield, amount)
	physical_shield_turns = maxi(physical_shield_turns, turns)
	melee_reflect_damage = maxi(melee_reflect_damage, reflect_damage_amount)
	reflect_turns = maxi(reflect_turns, turns)

func apply_magic_crit_gift(hit_count: int) -> void:
	guaranteed_magic_crit_hits = maxi(guaranteed_magic_crit_hits, hit_count)

func apply_blood_pact(mana_ratio: float) -> void:
	death_mana_ratio_to_master = maxf(death_mana_ratio_to_master, mana_ratio)

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

func absorb_physical_damage(amount: int) -> Dictionary:
	if amount <= 0 or current_physical_shield <= 0:
		return {"remaining": maxi(0, amount), "absorbed": 0}

	var absorbed: int = mini(current_physical_shield, amount)
	current_physical_shield -= absorbed
	return {
		"remaining": maxi(0, amount - absorbed),
		"absorbed": absorbed,
	}

func get_melee_reflect_damage() -> int:
	if reflect_turns <= 0:
		return 0
	return melee_reflect_damage

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

	if physical_miss_turns > 0:
		physical_miss_turns -= 1
		if physical_miss_turns <= 0:
			physical_miss_chance_status = 0.0

	if physical_shield_turns > 0:
		physical_shield_turns -= 1
		if physical_shield_turns <= 0:
			current_physical_shield = 0

	if reflect_turns > 0:
		reflect_turns -= 1
		if reflect_turns <= 0:
			melee_reflect_damage = 0

	if stealth_turns_remaining > 0:
		stealth_turns_remaining -= 1

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
	current_hp = mini(unit_data.max_hp, current_hp + amount)
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
