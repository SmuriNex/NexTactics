extends RefCounted
class_name RoundFlowState

var round_number: int = 1
var match_phase: int = GameEnums.MatchPhase.LOBBY

func reset() -> void:
	round_number = 1
	match_phase = GameEnums.MatchPhase.LOBBY

func set_round_number(value: int) -> void:
	round_number = maxi(1, value)

func advance_round() -> int:
	round_number = maxi(1, round_number + 1)
	return round_number

func set_match_phase(value: int) -> void:
	match_phase = value
