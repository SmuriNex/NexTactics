extends RefCounted
class_name BattlePrepHelper

# Prep support owned by BattleManager:
# - slot/deploy/support payloads
# - card shop/support prep data
# - prep interaction state transitions and drag feedback
# It does not apply gameplay consequences directly.

func build_deploy_bar_payload(
	player_deploy_pool: Array,
	player_support_pool: Array,
	drag_mode: int,
	drag_mode_deploy_slot: int,
	drag_slot_index: int,
	selected_support_index: int,
	deploy_option_state_cb: Callable,
	support_option_state_cb: Callable
) -> Dictionary:
	var unit_slot_data: Array[Dictionary] = []
	for option in player_deploy_pool:
		unit_slot_data.append(_build_deploy_slot_view_data(option, deploy_option_state_cb))

	var support_slot_data: Array[Dictionary] = []
	for option in player_support_pool:
		support_slot_data.append(_build_support_slot_view_data(option, support_option_state_cb))

	return {
		"unit_slot_data": unit_slot_data,
		"support_slot_data": support_slot_data,
		"dragging_index": drag_slot_index if drag_mode == drag_mode_deploy_slot else -1,
		"selected_support_index": selected_support_index,
	}


func build_deploy_slot_selection_payload(
	index: int,
	pool_size: int,
	option,
	option_state: Dictionary
) -> Dictionary:
	if index < 0 or index >= pool_size:
		return {
			"ok": false,
			"message": "Selecao de deploy bloqueada: slot %d indisponivel (pool=%d)" % [index + 1, pool_size],
		}
	if not bool(option_state.get("available", false)):
		return {
			"ok": false,
			"message": "Selecao de deploy bloqueada: slot %d %s (%s)" % [
				index + 1,
				str(option_state.get("status", "UNAVAILABLE")).to_lower(),
				str(option_state.get("reason", "indisponivel")),
			],
		}
	var unit_id: String = option.unit_data.id if option != null and option.unit_data != null else "unknown_unit"
	var unit_cost: int = option.unit_data.get_effective_cost() if option != null and option.unit_data != null else 0
	return {
		"ok": true,
		"selected_deploy_index": index,
		"unit_id": unit_id,
		"unit_cost": unit_cost,
	}


func build_begin_deploy_drag_payload(
	slot_index: int,
	pool_size: int,
	option,
	option_state: Dictionary,
	drag_mode_deploy_slot: int
) -> Dictionary:
	var selection_payload: Dictionary = build_deploy_slot_selection_payload(
		slot_index,
		pool_size,
		option,
		option_state
	)
	if not bool(selection_payload.get("ok", false)):
		return selection_payload
	selection_payload["drag_mode"] = drag_mode_deploy_slot
	selection_payload["drag_slot_index"] = slot_index
	selection_payload["drag_unit"] = null
	return selection_payload


func build_begin_board_unit_drag_payload(
	unit_state,
	drag_mode_board_unit: int
) -> Dictionary:
	if unit_state == null:
		return {"ok": false}
	return {
		"ok": true,
		"drag_mode": drag_mode_board_unit,
		"drag_slot_index": -1,
		"drag_unit": unit_state,
		"drag_hover_coord": unit_state.coord,
		"drag_drop_reason": "",
		"drag_drop_valid": false,
		"log_label": unit_state.get_combat_label(),
	}


func build_clear_drag_state_payload(
	armed_slot_index: int,
	keep_deploy_selection: bool
) -> Dictionary:
	return {
		"drag_mode": 0,
		"drag_slot_index": -1,
		"drag_unit": null,
		"drag_hover_coord": Vector2i(-1, -1),
		"drag_drop_reason": "",
		"drag_drop_valid": false,
		"selected_deploy_index": armed_slot_index if keep_deploy_selection and armed_slot_index >= 0 else -1,
	}


func build_deploy_drag_feedback_payload(
	screen_over_ui: bool,
	slot_index: int,
	pool_size: int,
	deploy_coord_valid: bool,
	deploy_coord: Vector2i,
	deploy_check: Dictionary
) -> Dictionary:
	var payload: Dictionary = {
		"clear_hover": false,
		"set_hover_coord": false,
		"hover_coord": Vector2i(-1, -1),
		"set_board_hover": false,
		"board_hover_coord": Vector2i(-1, -1),
		"board_hover_valid": false,
		"drag_drop_valid": false,
		"drag_drop_reason": "",
		"set_sell_feedback": true,
		"sell_feedback_over": false,
		"sell_feedback_valid": false,
	}
	if screen_over_ui:
		payload["clear_hover"] = true
		payload["set_hover_coord"] = true
		payload["hover_coord"] = Vector2i(-1, -1)
		payload["drag_drop_reason"] = "solto fora do tabuleiro"
		return payload
	if slot_index < 0 or slot_index >= pool_size:
		payload["clear_hover"] = true
		payload["drag_drop_reason"] = "slot invalido"
		payload["set_sell_feedback"] = false
		return payload
	if not deploy_coord_valid:
		payload["clear_hover"] = true
		payload["set_hover_coord"] = true
		payload["hover_coord"] = Vector2i(-1, -1)
		payload["drag_drop_reason"] = "solto fora do tabuleiro"
		return payload

	payload["set_hover_coord"] = true
	payload["hover_coord"] = deploy_coord
	payload["set_board_hover"] = true
	payload["board_hover_coord"] = deploy_coord
	payload["board_hover_valid"] = bool(deploy_check.get("ok", false))
	payload["drag_drop_valid"] = bool(deploy_check.get("ok", false))
	payload["drag_drop_reason"] = str(deploy_check.get("reason", ""))
	return payload


func build_board_drag_feedback_payload(
	blocked_by_ui: bool,
	over_sell_zone: bool,
	move_coord_valid: bool,
	move_coord: Vector2i,
	move_check: Dictionary,
	sell_check: Dictionary
) -> Dictionary:
	var payload: Dictionary = {
		"clear_hover": false,
		"set_hover_coord": false,
		"hover_coord": Vector2i(-1, -1),
		"set_board_hover": false,
		"board_hover_coord": Vector2i(-1, -1),
		"board_hover_valid": false,
		"drag_drop_valid": false,
		"drag_drop_reason": "",
		"set_sell_feedback": true,
		"sell_feedback_over": over_sell_zone,
		"sell_feedback_valid": bool(sell_check.get("ok", false)) if over_sell_zone else false,
	}
	if blocked_by_ui:
		payload["clear_hover"] = true
		payload["set_hover_coord"] = true
		payload["hover_coord"] = Vector2i(-1, -1)
		payload["drag_drop_reason"] = "solto fora do tabuleiro"
		payload["sell_feedback_over"] = false
		payload["sell_feedback_valid"] = false
		return payload
	if not move_coord_valid:
		payload["clear_hover"] = true
		payload["set_hover_coord"] = true
		payload["hover_coord"] = Vector2i(-1, -1)
		payload["drag_drop_reason"] = "solto fora do tabuleiro"
		return payload

	payload["set_hover_coord"] = true
	payload["hover_coord"] = move_coord
	payload["set_board_hover"] = true
	payload["board_hover_coord"] = move_coord
	payload["board_hover_valid"] = bool(move_check.get("ok", false))
	payload["drag_drop_valid"] = bool(move_check.get("ok", false))
	payload["drag_drop_reason"] = str(move_check.get("reason", ""))
	return payload


func build_finish_deploy_drag_outcome(
	drag_hover_valid: bool,
	drag_drop_valid: bool,
	drag_drop_reason: String,
	slot_index: int,
	pool_size: int,
	option
) -> Dictionary:
	if drag_hover_valid and drag_drop_valid:
		return {"action": "deploy"}
	if drag_hover_valid:
		var blocked_reason: String = drag_drop_reason if not drag_drop_reason.is_empty() else "alvo invalido"
		return {
			"action": "clear",
			"keep_deploy_selection": true,
			"message": "Arraste de deploy bloqueado: %s" % blocked_reason,
		}
	if slot_index >= 0 and slot_index < pool_size and option != null and option.unit_data != null:
		return {
			"action": "clear",
			"keep_deploy_selection": true,
			"message": "Alvo de deploy mantido: clique em uma celula do jogador para posicionar %s" % option.unit_data.display_name,
		}
	return {
		"action": "clear",
		"keep_deploy_selection": true,
	}


func build_finish_board_drag_outcome(
	drag_unit,
	over_sell_zone: bool,
	drag_hover_valid: bool,
	drag_hover_coord: Vector2i,
	move_check: Dictionary
) -> Dictionary:
	if drag_unit == null:
		return {"action": "clear"}
	if over_sell_zone:
		return {"action": "sell"}
	if drag_hover_valid:
		var move_ok: bool = bool(move_check.get("ok", false))
		var move_reason: String = str(move_check.get("reason", ""))
		if move_ok and drag_hover_coord != drag_unit.coord:
			return {"action": "move"}
		if move_reason != "same_cell":
			return {
				"action": "clear",
				"message": "Arraste de unidade cancelado: %s" % move_reason,
			}
	return {"action": "clear"}


func _build_deploy_slot_view_data(option, deploy_option_state_cb: Callable) -> Dictionary:
	var state: Dictionary = deploy_option_state_cb.call(option)
	var unit_name: String = "Unidade desconhecida"
	var unit_cost: int = 0
	if option != null and option.unit_data != null:
		unit_name = option.unit_data.display_name
		unit_cost = option.unit_data.get_effective_cost()

	return {
		"name": unit_name,
		"cost": unit_cost,
		"used": str(state.get("status", "UNAVAILABLE")) == "USED",
		"affordable": bool(state.get("available", false)),
		"status": str(state.get("status", "UNAVAILABLE")),
	}


func _build_support_slot_view_data(option, support_option_state_cb: Callable) -> Dictionary:
	var state: Dictionary = support_option_state_cb.call(option)
	var card_name: String = "Suporte desconhecido"
	var card_data: CardData = null
	if option != null and option.card_data != null:
		card_data = option.card_data
		card_name = option.card_data.display_name

	return {
		"name": card_name,
		"cost": 0,
		"cost_label": "Gratis",
		"used": ["USED", "AUTO"].has(str(state.get("status", "UNAVAILABLE"))),
		"affordable": bool(state.get("available", false)),
		"status": str(state.get("status", "UNAVAILABLE")),
		"reason": str(state.get("reason", "")),
		"card_data": card_data,
	}


func get_player_deploy_option_state(
	current_state: int,
	prep_state: int,
	gold_current: int,
	option,
	has_valid_player_deploy_target_cb: Callable
) -> Dictionary:
	if current_state != prep_state:
		return {"status": "UNAVAILABLE", "reason": "deploy so esta disponivel no PREP", "available": false}
	if option == null or option.unit_data == null:
		return {"status": "UNAVAILABLE", "reason": "dados da unidade ausentes", "available": false}
	if option.used:
		return {"status": "USED", "reason": "slot ja foi usado nesta rodada", "available": false}
	var effective_cost: int = option.unit_data.get_effective_cost()
	if gold_current < effective_cost:
		return {
			"status": "NO GOLD",
			"reason": "custo %d > ouro %d" % [effective_cost, gold_current],
			"available": false,
		}
	if not bool(has_valid_player_deploy_target_cb.call(option)):
		return {"status": "UNAVAILABLE", "reason": "nenhuma celula valida do jogador disponivel", "available": false}
	return {"status": "READY", "reason": "", "available": true}


func get_player_support_option_state(
	current_state: int,
	prep_state: int,
	option,
	has_valid_support_target_cb: Callable
) -> Dictionary:
	if current_state != prep_state:
		return {"status": "UNAVAILABLE", "reason": "supports so estao disponiveis no PREP", "available": false}
	if option == null or option.card_data == null:
		return {"status": "UNAVAILABLE", "reason": "dados do support ausentes", "available": false}
	if option.used:
		return {"status": "USED", "reason": "support ja foi usado nesta rodada", "available": false}
	if not bool(has_valid_support_target_cb.call(option.card_data)):
		return {
			"status": "UNAVAILABLE",
			"reason": "nenhum alvo valido para %s" % option.card_data.display_name,
			"available": false,
		}
	return {"status": "READY", "reason": "", "available": true}


func has_valid_player_deploy_target(
	board_width: int,
	board_height: int,
	can_deploy_option_to_coord_cb: Callable,
	option
) -> bool:
	if option == null or option.unit_data == null:
		return false

	for y in range(board_height):
		for x in range(board_width):
			var coord: Vector2i = Vector2i(x, y)
			if bool(can_deploy_option_to_coord_cb.call(option, coord).get("ok", false)):
				return true
	return false


func has_valid_support_target(
	card_data,
	support_card_is_instant_cb: Callable,
	get_valid_support_target_coords_cb: Callable
) -> bool:
	if card_data == null:
		return false
	if bool(support_card_is_instant_cb.call(card_data)):
		return true
	var valid_coords: Array = get_valid_support_target_coords_cb.call(card_data)
	return not valid_coords.is_empty()


func count_ready_player_deploy_slots(
	player_deploy_pool: Array,
	deploy_option_state_cb: Callable
) -> int:
	var count: int = 0
	for option in player_deploy_pool:
		if bool(deploy_option_state_cb.call(option).get("available", false)):
			count += 1
	return count


func player_has_ready_deploy_slots(
	player_deploy_pool: Array,
	deploy_option_state_cb: Callable
) -> bool:
	return count_ready_player_deploy_slots(player_deploy_pool, deploy_option_state_cb) > 0


func build_support_pool(
	owned_card_paths: Array[String],
	load_card_data_cb: Callable,
	support_option_factory_cb: Callable
) -> Dictionary:
	var support_pool: Array = []
	var invalid_owned_paths: Array[String] = []
	for path in owned_card_paths:
		var card_data = load_card_data_cb.call(path)
		if card_data == null:
			invalid_owned_paths.append(path)
			continue
		var support_option = support_option_factory_cb.call(card_data, path)
		if support_option == null:
			invalid_owned_paths.append(path)
			continue
		support_option.used = false
		support_pool.append(support_option)

	return {
		"support_pool": support_pool,
		"invalid_owned_paths": invalid_owned_paths,
	}


func build_card_shop_option_entries(
	card_paths: Array[String],
	load_card_data_cb: Callable
) -> Array[Dictionary]:
	var option_entries: Array[Dictionary] = []
	for card_path in card_paths:
		var card_data = load_card_data_cb.call(card_path)
		if card_data == null:
			continue
		option_entries.append({
			"card_path": card_path,
			"card_data": card_data,
		})
	return option_entries


func _shuffle_card_offer_paths(source_paths: Array[String], player_seed: int, round_number: int) -> Array[String]:
	var shuffled_paths: Array[String] = source_paths.duplicate()
	if shuffled_paths.size() <= 1:
		return shuffled_paths

	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("local_card_shop|%d|%d" % [player_seed, round_number]))
	for index in range(shuffled_paths.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		if swap_index == index:
			continue
		var current_path: String = shuffled_paths[index]
		shuffled_paths[index] = shuffled_paths[swap_index]
		shuffled_paths[swap_index] = current_path
	return shuffled_paths


func build_local_card_shop_offer_details(
	lobby_manager,
	local_player_id: String,
	round_number: int,
	player_deck,
	selected_deck_path: String,
	local_player,
	load_card_data_cb: Callable
) -> Dictionary:
	var details: Dictionary = lobby_manager.build_card_shop_offer_details(local_player_id, round_number, 2)
	var offer_paths: Array[String] = details.get("offer_paths", []).duplicate()
	if not offer_paths.is_empty():
		return details

	lobby_manager.set_player_deck_path(local_player_id, selected_deck_path, false)
	details = lobby_manager.build_card_shop_offer_details(local_player_id, round_number, 2)
	offer_paths = details.get("offer_paths", []).duplicate()
	if not offer_paths.is_empty():
		details["reason"] = "deck_resynced"
		return details

	if local_player == null or player_deck == null:
		details["reason"] = "missing_local_player_or_player_deck"
		return details

	var player_seed: int = int(local_player.slot_index) if local_player != null else 0
	var fallback_paths: Array[String] = []
	var raw_pool_paths: Array[String] = []
	var valid_pool_paths: Array[String] = []
	var invalid_pool_paths: Array[String] = []
	for card_path in player_deck.card_pool_paths:
		var resolved_path: String = str(card_path)
		if resolved_path.is_empty():
			continue
		if raw_pool_paths.has(resolved_path):
			continue
		raw_pool_paths.append(resolved_path)
		var card_data = load_card_data_cb.call(resolved_path)
		if card_data == null:
			invalid_pool_paths.append(resolved_path)
			continue
		valid_pool_paths.append(resolved_path)
		if local_player.has_owned_card_path(resolved_path):
			continue
		fallback_paths.append(resolved_path)
	fallback_paths = _shuffle_card_offer_paths(fallback_paths, player_seed, round_number)
	raw_pool_paths.sort()
	valid_pool_paths.sort()
	invalid_pool_paths.sort()
	if fallback_paths.size() > 2:
		fallback_paths.resize(2)

	details["offer_paths"] = fallback_paths
	details["available_paths"] = fallback_paths.duplicate()
	details["raw_card_pool_paths"] = raw_pool_paths.duplicate()
	details["valid_card_pool_paths"] = valid_pool_paths.duplicate()
	details["invalid_card_pool_paths"] = invalid_pool_paths.duplicate()
	details["card_pool_paths"] = raw_pool_paths.duplicate()
	details["card_pool_count"] = raw_pool_paths.size()
	details["valid_card_pool_count"] = valid_pool_paths.size()
	if not fallback_paths.is_empty():
		if fallback_paths.size() < 2:
			details["reason"] = "fallback_insufficient_unique_cards"
		else:
			details["reason"] = "fallback_used"
		return details

	details["offer_paths"] = []
	details["available_paths"] = []
	if valid_pool_paths.is_empty():
		details["reason"] = "fallback_no_valid_card_resources"
	else:
		details["reason"] = "fallback_all_unique_cards_owned"
	return details
