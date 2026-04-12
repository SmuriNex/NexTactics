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
			"title_text": _t("support.empty_title", "Carta indisponível"),
			"cost_text": "--",
			"type_text": _t("support.type_default", "SUPORTE"),
			"target_text": "",
			"art_title": "VAZIO",
			"art_caption": _t("support.empty_caption", "Sem dados"),
			"description_text": _t("support.empty_description", "Recurso ausente."),
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
		"cost_text": _t("support.free_cost", "FREE"),
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
		description_text = _t("support.description_fallback", "Suporte de preparo com efeito especial.")
	if not compact:
		return description_text
	return _truncate(description_text, 52)

static func _truncate(text_value: String, limit: int) -> String:
	var resolved_text: String = text_value.strip_edges()
	if resolved_text.length() <= limit:
		return resolved_text
	return "%s..." % resolved_text.substr(0, maxi(0, limit - 3))

static func _default_footer_text(state_kind: String) -> String:
	match state_kind:
		"selected":
			return _t("support.footer_selected", "ARMADA")
		"auto":
			return _t("support.footer_auto", "ATIVA")
		"used":
			return _t("support.footer_used", "USADA")
		"unavailable":
			return _t("support.footer_unavailable", "INDISPONÍVEL")
		_:
			return _t("support.footer_ready", "DISPONÍVEL")

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
		return _t("support.type_default", "Suporte")
	var app_text := _app_text()
	if app_text != null:
		return app_text.support_type_name(card_data.support_effect_type)
	return _t("support.type_default", "Suporte")

static func _support_target_name(effect_type: int) -> String:
	var app_text := _app_text()
	if app_text != null:
		return app_text.support_target_name(effect_type)
	return "Target"

static func _app_text() -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return (tree as SceneTree).root.get_node_or_null("AppText")
	return null

static func _t(key: String, fallback: String) -> String:
	var app_text := _app_text()
	if app_text != null:
		return app_text.text(key)
	return fallback
