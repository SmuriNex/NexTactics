extends Resource
class_name MasterPromotionRule

@export var class_type: int = GameEnums.ClassType.ATTACKER
@export var label: String = ""
@export var hp_bonus: int = 0
@export var physical_attack_bonus: int = 0
@export var magic_attack_bonus: int = 0
@export var physical_defense_bonus: int = 0
@export var magic_defense_bonus: int = 0

func build_bonus_dictionary() -> Dictionary:
	return {
		"hp_bonus": hp_bonus,
		"physical_attack_bonus": physical_attack_bonus,
		"magic_attack_bonus": magic_attack_bonus,
		"physical_defense_bonus": physical_defense_bonus,
		"magic_defense_bonus": magic_defense_bonus,
	}
