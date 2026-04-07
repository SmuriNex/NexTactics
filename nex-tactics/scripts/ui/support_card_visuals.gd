extends RefCounted
class_name SupportCardVisuals

static func build_view_data(
	card_data: CardData,
	state_label: String,
	state_kind: String,
	compact: bool,
	extra_hint: String = ""
) -> Dictionary:
	if card_data == null:
		return {
			"title_text": "Carta indisponivel",
			"cost_text": "--",
			"type_text": "SUPORTE",
			"target_text": "",
			"art_title": "VAZIO",
			"art_caption": "Sem dados",
			"description_text": "Recurso ausente.",
			"footer_text": state_label,
			"state_kind": state_kind,
			"compact": compact,
			"accent_color": Color(0.42, 0.42, 0.42, 1.0),
			"art_color": Color(0.18, 0.18, 0.18, 1.0),
		}

	var accent_info: Dictionary = _accent_info_for_card(card_data)
	var description_text: String = _description_text(card_data, compact)
	var footer_text: String = state_label.strip_edges()
	if footer_text.is_empty():
		footer_text = _default_footer_text(state_kind)
	if not extra_hint.strip_edges().is_empty() and state_kind != "selected":
		footer_text += " | %s" % extra_hint.strip_edges()

	return {
		"title_text": card_data.display_name,
		"cost_text": "FREE",
		"type_text": _support_card_type_name(card_data).to_upper(),
		"target_text": _support_target_name(card_data.support_effect_type),
		"art_title": str(accent_info.get("art_title", "SIGIL")),
		"art_caption": str(accent_info.get("art_caption", "")),
		"description_text": description_text,
		"footer_text": footer_text,
		"state_kind": state_kind,
		"compact": compact,
		"accent_color": accent_info.get("accent_color", Color(0.42, 0.42, 0.42, 1.0)),
		"art_color": accent_info.get("art_color", Color(0.18, 0.18, 0.18, 1.0)),
	}

static func _description_text(card_data: CardData, compact: bool) -> String:
	var description_text: String = card_data.description.strip_edges()
	if description_text.is_empty():
		description_text = "Suporte de preparo com efeito especial."
	if not compact:
		return description_text
	return _truncate(description_text, 96)

static func _truncate(text_value: String, limit: int) -> String:
	var resolved_text: String = text_value.strip_edges()
	if resolved_text.length() <= limit:
		return resolved_text
	return "%s..." % resolved_text.substr(0, maxi(0, limit - 3))

static func _default_footer_text(state_kind: String) -> String:
	match state_kind:
		"selected":
			return "ARMADA"
		"used":
			return "USADA"
		"unavailable":
			return "INDISPONIVEL"
		_:
			return "DISPONIVEL"

static func _accent_info_for_card(card_data: CardData) -> Dictionary:
	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return _accent_pack("VITAL", "Mestre", Color(0.27, 0.62, 0.44, 1.0), Color(0.10, 0.24, 0.16, 1.0))
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return _accent_pack("BLADE", "Ataque", Color(0.79, 0.34, 0.26, 1.0), Color(0.24, 0.11, 0.09, 1.0))
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return _accent_pack("ARCANE", "Magia", Color(0.35, 0.48, 0.86, 1.0), Color(0.12, 0.15, 0.30, 1.0))
		GameEnums.SupportCardEffectType.START_STEALTH:
			return _accent_pack("SHADE", "Stealth", Color(0.42, 0.42, 0.52, 1.0), Color(0.14, 0.14, 0.18, 1.0))
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return _accent_pack("MIST", "Campo", Color(0.46, 0.64, 0.70, 1.0), Color(0.14, 0.20, 0.24, 1.0))
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return _accent_pack("PACT", "Gatilho", Color(0.62, 0.36, 0.66, 1.0), Color(0.18, 0.10, 0.20, 1.0))
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return _accent_pack("TRAP", "Celula", Color(0.78, 0.52, 0.18, 1.0), Color(0.24, 0.16, 0.08, 1.0))
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return _accent_pack("COIN", "Ouro", Color(0.84, 0.70, 0.24, 1.0), Color(0.28, 0.22, 0.06, 1.0))
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return _accent_pack("TRIB", "Pilhagem", Color(0.74, 0.58, 0.28, 1.0), Color(0.24, 0.18, 0.08, 1.0))
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return _accent_pack("AEGIS", "Defesa", Color(0.28, 0.56, 0.70, 1.0), Color(0.10, 0.18, 0.24, 1.0))
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return _accent_pack("SIGHT", "Alcance", Color(0.74, 0.40, 0.26, 1.0), Color(0.24, 0.12, 0.08, 1.0))
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return _accent_pack("SHIFT", "Abertura", Color(0.22, 0.66, 0.62, 1.0), Color(0.08, 0.22, 0.20, 1.0))
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return _accent_pack("LOCK", "Campo", Color(0.58, 0.46, 0.74, 1.0), Color(0.18, 0.14, 0.24, 1.0))
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return _accent_pack("RIFT", "Campo", Color(0.42, 0.34, 0.82, 1.0), Color(0.14, 0.12, 0.28, 1.0))
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return _accent_pack("RITE", "Invocar", Color(0.58, 0.34, 0.48, 1.0), Color(0.18, 0.10, 0.16, 1.0))
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return _accent_pack("FLOW", "Mana", Color(0.32, 0.58, 0.82, 1.0), Color(0.10, 0.18, 0.30, 1.0))
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return _accent_pack("FANG", "Ofensiva", Color(0.70, 0.24, 0.30, 1.0), Color(0.24, 0.08, 0.10, 1.0))
		_:
			return _accent_pack("SIGIL", "Suporte", Color(0.50, 0.50, 0.58, 1.0), Color(0.16, 0.16, 0.20, 1.0))

static func _accent_pack(art_title: String, art_caption: String, accent_color: Color, art_color: Color) -> Dictionary:
	return {
		"art_title": art_title,
		"art_caption": art_caption,
		"accent_color": accent_color,
		"art_color": art_color,
	}

static func _support_card_type_name(card_data: CardData) -> String:
	if card_data == null:
		return "Suporte"

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Suporte global"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return "Suporte de unidade"
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return "Equipamento magico"
		GameEnums.SupportCardEffectType.START_STEALTH:
			return "Equipamento furtivo"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Feitico de campo"
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return "Suporte de gatilho"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Armadilha de celula"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Feitico de ouro"
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Feitico de pilhagem"
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return "Equipamento defensivo"
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return "Equipamento ofensivo"
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Armadilha de abertura"
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return "Feitico de campo"
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Feitico de campo"
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Invocacao condicional"
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return "Equipamento mistico"
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Equipamento ofensivo"
		_:
			return "Suporte"

static func _support_target_name(effect_type: int) -> String:
	match effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			return "Mestre aliado"
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.START_STEALTH:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return "Campo instantaneo"
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			return "Celula inimiga"
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return "Sem alvo"
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return "Unidade aliada"
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			return "Unidade aliada"
		_:
			return "Desconhecido"
