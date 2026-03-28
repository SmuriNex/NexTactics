extends Resource
class_name SkillData

@export var id: String = ""
@export var display_name: String = ""
@export var effect_type: int = GameEnums.SkillEffectType.ALLY_HEAL
@export var mana_cost: int = 100
@export var cooldown: float = 0.0
@export var range: int = 1
@export var heal_amount: int = 0
@export var damage_amount: int = 0
@export var physical_power_multiplier: float = 0.0
@export var magic_power_multiplier: float = 0.0
@export var area_radius: int = 0
@export var duration_turns: int = 0
@export var secondary_duration_turns: int = 0
@export var physical_defense_multiplier: float = 1.0
@export var magic_defense_multiplier: float = 1.0
@export var mana_gain_multiplier: float = 1.0
@export var self_health_cost_ratio: float = 0.0
@export var ally_mana_grant_ratio: float = 0.0
@export var damage_heal_ratio: float = 0.0
@export var guaranteed_magic_crit_hits: int = 0
@export var physical_shield_amount: int = 0
@export var reflect_damage: int = 0
@export var turn_skip_count: int = 0
@export var summon_count: int = 0
@export var summon_unit_path: String = ""
@export var summon_stat_ratio: float = 0.0
@export var physical_attack_bonus: int = 0
@export var magic_attack_bonus: int = 0
@export var physical_defense_bonus: int = 0
@export var magic_defense_bonus: int = 0
@export var description: String = ""
