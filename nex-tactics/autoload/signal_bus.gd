extends Node

signal battle_state_changed(new_state: int)
signal match_phase_changed(new_phase: int)
signal board_view_mode_changed(new_mode: int)
signal round_pairings_generated(round_number: int, pairings: Array)
signal unit_spawned(unit_id: String, team: int, cell: Vector2i)
signal unit_died(unit_id: String, team: int)
signal round_started(round_number: int)
signal round_finished(round_number: int)
signal global_life_changed(team: int, value: int)
