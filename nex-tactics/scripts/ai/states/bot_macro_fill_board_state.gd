extends LimboState

func _enter() -> void:
	var agent = get_agent()
	if agent != null and agent.has_method("run_fill_board_state"):
		agent.run_fill_board_state()
	dispatch(&"done")
