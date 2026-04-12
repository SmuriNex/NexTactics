extends Node

var planner: EnemyPrepPlanner = null
var context: Dictionary = {}
var decision: Dictionary = {}
var completed_states: Array[String] = []
var failed_reason: String = ""

func setup(p_planner: EnemyPrepPlanner, p_context: Dictionary):
	planner = p_planner
	context = p_context.duplicate(true)
	decision = {
		"source": "limboai",
		"completed": false,
		"fallback_used": false,
		"fallback_reason": "",
		"completed_states": [],
		"evaluation": {},
		"formation_plan": {},
		"support_orders": [],
		"selected_support_paths": [],
		"promotion_strategy": "current_executor",
		"promotion_pending_count": int(context.get("pending_promotions", 0)),
		"positioning_mode": "",
	}
	return self

func run_evaluate_state() -> void:
	var current_units: Array = context.get("current_units", [])
	var candidate_entries: Array = context.get("candidate_entries", [])
	var card_entries: Array = context.get("card_entries", [])
	var field_limit: int = int(context.get("field_limit", current_units.size()))
	decision["evaluation"] = {
		"mode": str(context.get("mode", "macro")),
		"field_before": current_units.size(),
		"field_limit": field_limit,
		"has_open_slots": current_units.size() < field_limit,
		"candidate_count": candidate_entries.size(),
		"support_count": card_entries.size(),
		"available_gold": int(context.get("available_gold", context.get("current_gold", 0))),
		"pending_promotions": int(context.get("pending_promotions", 0)),
	}
	_mark_state_completed("EvaluateState")

func run_fill_board_state() -> void:
	if planner == null or not _supports_formation_context():
		_mark_state_completed("FillBoardState")
		return
	decision["formation_plan"] = planner.build_formation_plan(
		context.get("candidate_entries", []),
		context.get("current_units", []),
		int(context.get("available_gold", 0)),
		int(context.get("field_limit", 0)),
		int(context.get("owner_team_side", GameEnums.TeamSide.PLAYER)),
		context.get("master_data", null),
		float(context.get("deck_average_power", 0.0)),
		str(context.get("debug_tag", "bot"))
	)
	if not decision.get("formation_plan", {}).is_empty():
		decision["positioning_mode"] = "planner_layout"
	_mark_state_completed("FillBoardState")

func run_promote_state() -> void:
	var pending_promotions: int = int(context.get("pending_promotions", 0))
	decision["promotion_pending_count"] = pending_promotions
	decision["promotion_strategy"] = "apply_pending" if pending_promotions > 0 else "none_pending"
	_mark_state_completed("PromoteState")

func run_support_state() -> void:
	if planner == null or not _supports_support_context():
		_mark_state_completed("ApplySupportState")
		return
	var support_orders: Array[Dictionary] = planner.build_card_orders(
		context.get("card_entries", []),
		context.get("allied_units", []),
		context.get("enemy_units", []),
		int(context.get("owner_team_side", GameEnums.TeamSide.PLAYER)),
		str(context.get("debug_tag", "bot"))
	)
	decision["support_orders"] = support_orders
	decision["selected_support_paths"] = _build_support_paths_from_orders(support_orders)
	_mark_state_completed("ApplySupportState")

func run_reposition_state() -> void:
	if str(decision.get("positioning_mode", "")).is_empty() and _supports_formation_context():
		decision["positioning_mode"] = "planner_layout"
	_mark_state_completed("RepositionState")

func run_ready_state() -> void:
	decision["completed"] = true
	_mark_state_completed("ReadyState")

func build_result() -> Dictionary:
	decision["completed_states"] = completed_states.duplicate()
	if not failed_reason.is_empty():
		decision["fallback_used"] = true
		decision["fallback_reason"] = failed_reason
	return decision.duplicate(true)

func mark_failure(reason: String) -> void:
	if failed_reason.is_empty():
		failed_reason = reason

func _supports_formation_context() -> bool:
	return context.has("candidate_entries") and context.has("current_units") and context.has("field_limit")

func _supports_support_context() -> bool:
	return context.has("card_entries") and context.has("allied_units") and context.has("enemy_units")

func _mark_state_completed(state_name: String) -> void:
	completed_states.append(state_name)
	decision["completed_states"] = completed_states.duplicate()

func _build_support_paths_from_orders(orders: Array[Dictionary]) -> Array[String]:
	var paths: Array[String] = []
	for order in orders:
		var card_path: String = str(order.get("card_path", ""))
		if card_path.is_empty():
			continue
		paths.append(card_path)
	return paths
