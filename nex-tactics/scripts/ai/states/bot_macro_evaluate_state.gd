extends LimboState

func _enter() -> void:
	var agent = get_agent()
	if agent != null and agent.has_method("run_evaluate_state"):
		agent.run_evaluate_state()
	dispatch(&"done")
