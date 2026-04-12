extends RefCounted
class_name MasterProgressionState

const DEFAULT_CONFIG := preload("res://data/progression/master_progression_demo.tres")

var config: MasterProgressionConfig = DEFAULT_CONFIG
var xp_total: int = 0
var level: int = 1
var pending_promotions: int = 0
var consecutive_losses: int = 0
var recovery_active: bool = false
var last_round_xp_breakdown: Dictionary = {}
var unit_promotions: Dictionary = {}

func _init(p_config: MasterProgressionConfig = null) -> void:
	config = p_config if p_config != null else DEFAULT_CONFIG
	reset()

func reset() -> void:
	xp_total = 0
	level = 1
	pending_promotions = 0
	consecutive_losses = 0
	recovery_active = false
	last_round_xp_breakdown = {}
	unit_promotions.clear()
	_resolve_level_from_xp()

func apply_round_result(did_win: bool, did_lose: bool, master_survived: bool) -> Dictionary:
	var level_before: int = level
	var capacity_before: int = get_field_capacity_total()
	var xp_gained: int = maxi(0, config.round_base_xp)
	var recovery_bonus_xp: int = 0
	var recovery_was_active: bool = recovery_active
	var consecutive_losses_before: int = consecutive_losses

	if did_win:
		xp_gained += maxi(0, config.win_bonus_xp)
	if master_survived:
		xp_gained += maxi(0, config.master_survived_bonus_xp)
	if did_lose and recovery_active:
		recovery_bonus_xp = maxi(0, config.recovery_loss_bonus_xp)
		xp_gained += recovery_bonus_xp

	if did_win:
		consecutive_losses = 0
		recovery_active = false
	elif did_lose:
		consecutive_losses += 1
		if consecutive_losses >= maxi(1, config.recovery_activation_loss_streak):
			recovery_active = true
	else:
		consecutive_losses = 0

	xp_total = maxi(0, xp_total + xp_gained)
	_resolve_level_from_xp()

	var levels_gained: Array[int] = []
	var promotions_granted: int = 0
	for next_level in range(level_before + 1, level + 1):
		var rule: MasterLevelRule = config.get_level_rule(next_level)
		levels_gained.append(next_level)
		if rule != null and rule.grants_promotion:
			pending_promotions += 1
			promotions_granted += 1

	last_round_xp_breakdown = {
		"xp_gained": xp_gained,
		"recovery_bonus_xp": recovery_bonus_xp,
		"did_win": did_win,
		"did_lose": did_lose,
		"master_survived": master_survived,
		"level_before": level_before,
		"level_after": level,
		"levels_gained": levels_gained,
		"capacity_before": capacity_before,
		"capacity_after": get_field_capacity_total(),
		"promotions_granted": promotions_granted,
		"pending_promotions": pending_promotions,
		"recovery_was_active": recovery_was_active,
		"recovery_active": recovery_active,
		"consecutive_losses_before": consecutive_losses_before,
		"consecutive_losses_after": consecutive_losses,
		"xp_total": xp_total,
	}
	return last_round_xp_breakdown.duplicate(true)

func apply_unit_promotion(unit_id: String, class_type: int, display_name: String = "") -> Dictionary:
	if pending_promotions <= 0:
		return {"ok": false, "reason": "no_pending_promotion"}
	var resolved_unit_id: String = str(unit_id)
	if resolved_unit_id.is_empty():
		return {"ok": false, "reason": "invalid_unit_id"}

	var rule: MasterPromotionRule = config.get_promotion_rule_for_class_type(class_type)
	if rule == null:
		return {"ok": false, "reason": "missing_rule"}

	var entry: Dictionary = get_unit_promotion_bonus(resolved_unit_id)
	entry["unit_id"] = resolved_unit_id
	entry["display_name"] = display_name
	entry["class_type"] = class_type
	entry["promotion_count"] = int(entry.get("promotion_count", 0)) + 1
	entry["hp_bonus"] = int(entry.get("hp_bonus", 0)) + rule.hp_bonus
	entry["physical_attack_bonus"] = int(entry.get("physical_attack_bonus", 0)) + rule.physical_attack_bonus
	entry["magic_attack_bonus"] = int(entry.get("magic_attack_bonus", 0)) + rule.magic_attack_bonus
	entry["physical_defense_bonus"] = int(entry.get("physical_defense_bonus", 0)) + rule.physical_defense_bonus
	entry["magic_defense_bonus"] = int(entry.get("magic_defense_bonus", 0)) + rule.magic_defense_bonus
	entry["last_rule_label"] = _promotion_label_for_rule(rule)
	unit_promotions[resolved_unit_id] = entry
	pending_promotions = maxi(0, pending_promotions - 1)

	return {
		"ok": true,
		"unit_id": resolved_unit_id,
		"display_name": display_name,
		"class_type": class_type,
		"promotion_label": _promotion_label_for_rule(rule),
		"granted_bonus": rule.build_bonus_dictionary(),
		"total_bonus": entry.duplicate(true),
		"pending_promotions": pending_promotions,
	}

func get_unit_promotion_bonus(unit_id: String) -> Dictionary:
	var resolved_unit_id: String = str(unit_id)
	if resolved_unit_id.is_empty() or not unit_promotions.has(resolved_unit_id):
		return {}
	return (unit_promotions[resolved_unit_id] as Dictionary).duplicate(true)

func get_field_capacity_total() -> int:
	var rule: MasterLevelRule = config.get_level_rule(level)
	return maxi(1, int(rule.field_capacity_total)) if rule != null else 4

func get_field_unit_limit() -> int:
	return maxi(0, get_field_capacity_total() - 1)

func get_current_level_rule() -> MasterLevelRule:
	return config.get_level_rule(level)

func get_next_level_rule() -> MasterLevelRule:
	return config.get_next_level_rule(level)

func has_pending_promotion() -> bool:
	return pending_promotions > 0

func get_pending_promotion_count() -> int:
	return pending_promotions

func build_master_status_text() -> String:
	var next_rule: MasterLevelRule = get_next_level_rule()
	var xp_segment: String = "%d/MAX" % xp_total
	if next_rule != null:
		xp_segment = "%d/%d" % [xp_total, next_rule.xp_total_required]
	var status: String = _text("master.status", "Mestre Nv {level} | XP {xp} | Campo {units}/{capacity}", {
		"level": level,
		"xp": xp_segment,
		"units": get_field_unit_limit(),
		"capacity": get_field_capacity_total(),
	})
	if recovery_active:
		status += " | " + _text("master.recovery", "Recuperação")
	return status

func build_feedback_text() -> String:
	if last_round_xp_breakdown.is_empty():
		return _pending_promotion_text()

	var parts: Array[String] = []
	parts.append(_text("master.xp_gain", "XP +{value}", {"value": int(last_round_xp_breakdown.get("xp_gained", 0))}))
	var recovery_bonus_xp: int = int(last_round_xp_breakdown.get("recovery_bonus_xp", 0))
	if recovery_bonus_xp > 0:
		parts.append(_text("master.recovery_bonus", "Recuperação +{value}", {"value": recovery_bonus_xp}))
	var levels_gained: Array = last_round_xp_breakdown.get("levels_gained", [])
	if not levels_gained.is_empty():
		parts.append(_text("master.level_gain", "Nv {value}", {"value": level}))
	if int(last_round_xp_breakdown.get("capacity_after", 0)) > int(last_round_xp_breakdown.get("capacity_before", 0)):
		parts.append(_text("master.field_gain", "Campo {value}", {"value": get_field_capacity_total()}))
	if int(last_round_xp_breakdown.get("promotions_granted", 0)) > 0:
		parts.append(_text("master.promotion_gain", "Promoção +{value}", {"value": int(last_round_xp_breakdown.get("promotions_granted", 0))}))
	var pending_text: String = _pending_promotion_text()
	if not pending_text.is_empty():
		parts.append(pending_text)
	return " | ".join(parts)

func _pending_promotion_text() -> String:
	if pending_promotions <= 0:
		return ""
	return _text("master.pending_promotion", "Promoção pendente x{value}", {"value": pending_promotions})

func _resolve_level_from_xp() -> void:
	var rule: MasterLevelRule = config.get_rule_for_total_xp(xp_total)
	level = maxi(1, int(rule.level)) if rule != null else 1

func _promotion_label_for_rule(rule: MasterPromotionRule) -> String:
	if rule == null:
		return "Promocao"
	if not rule.label.is_empty():
		return rule.label
	match rule.class_type:
		GameEnums.ClassType.TANK:
			return "Bastiao"
		GameEnums.ClassType.ATTACKER:
			return "Pressao"
		GameEnums.ClassType.SNIPER:
			return "Precisao"
		GameEnums.ClassType.SUPPORT:
			return "Protecao"
		GameEnums.ClassType.STEALTH:
			return "Emboscada"
		_:
			return "Promocao"

func _text(key: String, fallback: String, params: Dictionary = {}) -> String:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var app_text := (tree as SceneTree).root.get_node_or_null("AppText")
		if app_text != null:
			return app_text.text(key, params)
	var resolved: String = fallback
	for param_key in params.keys():
		resolved = resolved.replace("{%s}" % str(param_key), str(params[param_key]))
	return resolved
