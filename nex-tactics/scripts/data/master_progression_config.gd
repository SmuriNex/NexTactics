extends Resource
class_name MasterProgressionConfig

const MasterLevelRuleScript := preload("res://scripts/data/master_level_rule.gd")
const MasterPromotionRuleScript := preload("res://scripts/data/master_promotion_rule.gd")

@export var round_base_xp: int = 1
@export var win_bonus_xp: int = 1
@export var master_survived_bonus_xp: int = 1
@export var recovery_activation_loss_streak: int = 3
@export var recovery_loss_bonus_xp: int = 2
@export var level_rules: Array[MasterLevelRule] = []
@export var promotion_rules: Array[MasterPromotionRule] = []

func get_level_rule(level: int) -> MasterLevelRule:
	var best_rule: MasterLevelRule = null
	for rule in level_rules:
		if rule == null:
			continue
		if rule.level == level:
			return rule
		if rule.level <= level and (best_rule == null or rule.level > best_rule.level):
			best_rule = rule
	if best_rule != null:
		return best_rule
	return _fallback_level_rule()

func get_rule_for_total_xp(total_xp: int) -> MasterLevelRule:
	var best_rule: MasterLevelRule = _fallback_level_rule()
	for rule in level_rules:
		if rule == null:
			continue
		if total_xp < rule.xp_total_required:
			continue
		if best_rule == null or rule.level > best_rule.level:
			best_rule = rule
	return best_rule if best_rule != null else _fallback_level_rule()

func get_next_level_rule(level: int) -> MasterLevelRule:
	var next_rule: MasterLevelRule = null
	for rule in level_rules:
		if rule == null:
			continue
		if rule.level <= level:
			continue
		if next_rule == null or rule.level < next_rule.level:
			next_rule = rule
	return next_rule

func get_max_level() -> int:
	var max_level: int = 1
	for rule in level_rules:
		if rule != null:
			max_level = maxi(max_level, rule.level)
	return max_level

func get_promotion_rule_for_class_type(class_type: int) -> MasterPromotionRule:
	for rule in promotion_rules:
		if rule != null and rule.class_type == class_type:
			return rule
	return null

func _fallback_level_rule() -> MasterLevelRule:
	var fallback_rule: MasterLevelRule = MasterLevelRuleScript.new()
	fallback_rule.level = 1
	fallback_rule.xp_total_required = 0
	fallback_rule.field_capacity_total = 4
	fallback_rule.grants_promotion = false
	return fallback_rule
