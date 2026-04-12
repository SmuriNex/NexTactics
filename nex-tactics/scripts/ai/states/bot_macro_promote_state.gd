extends LimboState

func _enter() -> void:
	var agent = get_agent()
	if agent != null and agent.has_method("run_promote_state"):
		agent.run_promote_state()
	dispatch(&"done")
