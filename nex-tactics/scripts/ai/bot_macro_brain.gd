extends RefCounted
class_name BotMacroBrain

const MAX_HSM_STEPS := 8

const BotMacroAgentScript := preload("res://scripts/ai/bot_macro_agent.gd")
const EvaluateStateScript := preload("res://scripts/ai/states/bot_macro_evaluate_state.gd")
const FillBoardStateScript := preload("res://scripts/ai/states/bot_macro_fill_board_state.gd")
const PromoteStateScript := preload("res://scripts/ai/states/bot_macro_promote_state.gd")
const ApplySupportStateScript := preload("res://scripts/ai/states/bot_macro_apply_support_state.gd")
const RepositionStateScript := preload("res://scripts/ai/states/bot_macro_reposition_state.gd")
const ReadyStateScript := preload("res://scripts/ai/states/bot_macro_ready_state.gd")

var planner: EnemyPrepPlanner = null

func setup(p_planner: EnemyPrepPlanner) -> BotMacroBrain:
	planner = p_planner
	return self

func build_decision(context: Dictionary) -> Dictionary:
	if planner == null:
		return _fallback_decision(context, "missing_planner")
	if not _can_use_limboai():
		return _fallback_decision(context, "limbo_unavailable")

	var agent = BotMacroAgentScript.new().setup(planner, context)
	var hsm: LimboHSM = LimboHSM.new()
	agent.add_child(hsm)

	var evaluate_state: LimboState = EvaluateStateScript.new()
	var fill_state: LimboState = FillBoardStateScript.new()
	var promote_state: LimboState = PromoteStateScript.new()
	var support_state: LimboState = ApplySupportStateScript.new()
	var reposition_state: LimboState = RepositionStateScript.new()
	var ready_state: LimboState = ReadyStateScript.new()

	evaluate_state.name = "EvaluateState"
	fill_state.name = "FillBoardState"
	promote_state.name = "PromoteState"
	support_state.name = "ApplySupportState"
	reposition_state.name = "RepositionState"
	ready_state.name = "ReadyState"

	hsm.add_child(evaluate_state)
	hsm.add_child(fill_state)
	hsm.add_child(promote_state)
	hsm.add_child(support_state)
	hsm.add_child(reposition_state)
	hsm.add_child(ready_state)

	hsm.add_transition(evaluate_state, fill_state, &"done")
	hsm.add_transition(fill_state, promote_state, &"done")
	hsm.add_transition(promote_state, support_state, &"done")
	hsm.add_transition(support_state, reposition_state, &"done")
	hsm.add_transition(reposition_state, ready_state, &"done")

	hsm.initialize(agent)
	hsm.set_active(true)

	var safety_steps: int = 0
	while hsm.get_active_state() != ready_state and safety_steps < MAX_HSM_STEPS:
		hsm.update(0.0)
		safety_steps += 1

	var result: Dictionary = agent.build_result()
	var reached_ready_state: bool = hsm.get_active_state() == ready_state
	agent.free()
	if not reached_ready_state:
		return _merge_fallback(result, context, "limbo_incomplete")
	return result

func _can_use_limboai() -> bool:
	return ClassDB.class_exists(&"LimboHSM") and ClassDB.class_exists(&"LimboState")

func _merge_fallback(partial_result: Dictionary, context: Dictionary, reason: String) -> Dictionary:
	var fallback: Dictionary = _fallback_decision(context, reason)
	fallback["limbo_attempted"] = true
	fallback["limbo_partial_states"] = partial_result.get("completed_states", [])
	return fallback

func _fallback_decision(context: Dictionary, reason: String) -> Dictionary:
	var result: Dictionary = {
		"source": "legacy_fallback",
		"completed": true,
		"fallback_used": true,
		"fallback_reason": reason,
		"completed_states": [],
		"evaluation": _build_basic_evaluation(context),
		"formation_plan": {},
		"support_orders": [],
		"selected_support_paths": [],
		"promotion_strategy": "current_executor",
		"promotion_pending_count": int(context.get("pending_promotions", 0)),
		"positioning_mode": "",
	}
	if _supports_formation_context(context):
		result["formation_plan"] = planner.build_formation_plan(
			context.get("candidate_entries", []),
			context.get("current_units", []),
			int(context.get("available_gold", 0)),
			int(context.get("field_limit", 0)),
			int(context.get("owner_team_side", GameEnums.TeamSide.PLAYER)),
			context.get("master_data", null),
			float(context.get("deck_average_power", 0.0)),
			str(context.get("debug_tag", "bot"))
		)
		if not result.get("formation_plan", {}).is_empty():
			result["positioning_mode"] = "planner_layout"
	if _supports_support_context(context):
		var support_orders: Array[Dictionary] = planner.build_card_orders(
			context.get("card_entries", []),
			context.get("allied_units", []),
			context.get("enemy_units", []),
			int(context.get("owner_team_side", GameEnums.TeamSide.PLAYER)),
			str(context.get("debug_tag", "bot"))
		)
		result["support_orders"] = support_orders
		result["selected_support_paths"] = _build_support_paths_from_orders(support_orders)
	return result

func _supports_formation_context(context: Dictionary) -> bool:
	return context.has("candidate_entries") and context.has("current_units") and context.has("field_limit")

func _supports_support_context(context: Dictionary) -> bool:
	return context.has("card_entries") and context.has("allied_units") and context.has("enemy_units")

func _build_basic_evaluation(context: Dictionary) -> Dictionary:
	var current_units: Array = context.get("current_units", [])
	var candidate_entries: Array = context.get("candidate_entries", [])
	var card_entries: Array = context.get("card_entries", [])
	return {
		"mode": str(context.get("mode", "macro")),
		"field_before": current_units.size(),
		"field_limit": int(context.get("field_limit", current_units.size())),
		"has_open_slots": current_units.size() < int(context.get("field_limit", current_units.size())),
		"candidate_count": candidate_entries.size(),
		"support_count": card_entries.size(),
		"available_gold": int(context.get("available_gold", context.get("current_gold", 0))),
		"pending_promotions": int(context.get("pending_promotions", 0)),
	}

func _build_support_paths_from_orders(orders: Array[Dictionary]) -> Array[String]:
	var paths: Array[String] = []
	for order in orders:
		var card_path: String = str(order.get("card_path", ""))
		if card_path.is_empty():
			continue
		paths.append(card_path)
	return paths
