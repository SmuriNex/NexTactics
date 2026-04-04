extends Resource
class_name UnitData

const BATTLE_CONFIG_SCRIPT := preload('res://autoload/battle_config.gd')

@export var id: String = ""
@export var display_name: String = ""
@export var race: int = GameEnums.Race.HUMAN
@export var class_type: int = GameEnums.ClassType.ATTACKER
@export var class_label: String = ""
@export var class_short_label: String = ""
@export var cost: int = 1

func get_effective_cost() -> int:
	return BATTLE_CONFIG_SCRIPT.adjust_unit_cost(cost)

@export var max_hp: int = 10
@export var physical_attack: int = 3
@export var magic_attack: int = 0
@export var physical_defense: int = 1
@export var magic_defense: int = 0
@export var attack_range: int = 1
@export var crit_chance: float = 0.0

@export var mana_max: int = 100
@export var mana_gain_on_attack: int = 10
@export var mana_gain_on_hit: int = 5
@export var skill_data: SkillData
@export var master_skill_data: SkillData

@export var description: String = ""

