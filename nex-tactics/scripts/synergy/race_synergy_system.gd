extends RefCounted
class_name RaceSynergySystem

func apply_team_synergies(units: Array[BattleUnitState], team_side: int) -> Dictionary:
	var team_units: Array[BattleUnitState] = []
	var race_counts: Dictionary = {}

	for unit_state in units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		team_units.append(unit_state)
		if unit_state.unit_data == null:
			continue
		var race: int = unit_state.unit_data.race
		race_counts[race] = int(race_counts.get(race, 0)) + 1

	for unit_state in team_units:
		unit_state.clear_synergy_modifiers()

	var active_entries: Array[Dictionary] = []
	var ordered_races: Array[int] = [
		GameEnums.Race.HUMAN,
		GameEnums.Race.ELF,
		GameEnums.Race.FAIRY,
		GameEnums.Race.OGRE,
		GameEnums.Race.UNDEAD,
		GameEnums.Race.BEAST,
	]

	for race in ordered_races:
		var count: int = int(race_counts.get(race, 0))
		if count <= 0:
			continue
		active_entries.append({
			"race": race,
			"count": count,
			"tier": 0,
			"summary": "%s x%d" % [_race_name(race), count],
		})

	var summary: String = "Nenhuma"
	if not active_entries.is_empty():
		var labels: Array[String] = []
		for entry in active_entries:
			labels.append(str(entry.get("summary", "")))
		summary = _join_strings(labels, " | ")

	return {
		"team_side": team_side,
		"active_entries": active_entries,
		"summary": summary,
	}

func _race_name(race: int) -> String:
	match race:
		GameEnums.Race.HUMAN:
			return "Humano"
		GameEnums.Race.ELF:
			return "Elfo"
		GameEnums.Race.FAIRY:
			return "Fada"
		GameEnums.Race.OGRE:
			return "Ogro"
		GameEnums.Race.UNDEAD:
			return "Morto-vivo"
		GameEnums.Race.BEAST:
			return "Besta"
		_:
			return "Desconhecida"

func _join_strings(values: Array[String], separator: String = ", ") -> String:
	var result: String = ""
	for value in values:
		if result.is_empty():
			result = value
		else:
			result += separator + value
	return result
