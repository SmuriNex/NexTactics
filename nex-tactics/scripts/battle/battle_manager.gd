extends Node
class_name BattleManager

signal hud_update_requested(
	round_number: int,
	player_life: int,
	enemy_life: int,
	energy_value: int,
	state_name: String,
	deploy_selection: String,
	synergy_summary: String,
	round_result_summary: String
)

class DeployOption:
	var unit_data: UnitData
	var unit_path: String
	var team_side: int
	var home_coord: Vector2i
	var is_master: bool = false
	var used: bool = false

	func _init(
		p_unit_data: UnitData,
		p_unit_path: String,
		p_team_side: int,
		p_home_coord: Vector2i,
		p_is_master: bool = false
	) -> void:
		unit_data = p_unit_data
		unit_path = p_unit_path
		team_side = p_team_side
		home_coord = p_home_coord
		is_master = p_is_master

class SupportOption:
	var card_data: CardData
	var card_path: String
	var used: bool = false

	func _init(p_card_data: CardData, p_card_path: String) -> void:
		card_data = p_card_data
		card_path = p_card_path

class RespawnRequest:
	var unit_path: String
	var unit_id: String
	var team_side: int
	var home_coord: Vector2i
	var is_master: bool = false

	func _init(
		p_unit_path: String,
		p_unit_id: String,
		p_team_side: int,
		p_home_coord: Vector2i,
		p_is_master: bool = false
	) -> void:
		unit_path = p_unit_path
		unit_id = p_unit_id
		team_side = p_team_side
		home_coord = p_home_coord
		is_master = p_is_master

const DRAG_MODE_NONE := 0
const DRAG_MODE_DEPLOY_SLOT := 1
const DRAG_MODE_BOARD_UNIT := 2

const ACTION_DELAY_ATTACK_SECONDS := 0.10
const ACTION_DELAY_SKILL_SECONDS := 0.10
const ACTION_DELAY_MOVE_SECONDS := 0.08
const ACTION_DELAY_SKIP_SECONDS := 0.05
const ACTION_DELAY_STUCK_SECONDS := 0.03
const MASTER_SKILL_DAMAGE := 8
const MIN_COMBAT_CHIP_DAMAGE := 1
const SUMMON_NEARBY_RADIUS := 2
const SPAWN_COLUMN_ORDER: Array[int] = [3, 2, 4, 1, 5, 0, 6]
const PLAYER_DECK_PATH := "res://data/decks/necromancer_deck.tres"
const ENEMY_DECK_PATH := "res://data/decks/necromancer_deck.tres"

const SUPPORT_CARD_FIELD_AID_PATH := "res://data/cards/demo_field_aid.tres"
const SUPPORT_CARD_BATTLE_ORDERS_PATH := "res://data/cards/demo_battle_orders.tres"
const LOCAL_PLAYER_ID := "player_1"

const PLAYER_MASTER_COORD := Vector2i(3, BattleConfig.BOARD_HEIGHT - 1)
const ENEMY_MASTER_COORD := Vector2i(3, 0)

var current_state: int = GameEnums.BattleState.SETUP
var current_match_phase: int = GameEnums.MatchPhase.LOBBY
var current_round: int = 0
var energy_current: int = 0
var enemy_energy_current: int = 0
var player_global_life: int = BattleConfig.GLOBAL_LIFE
var enemy_global_life: int = BattleConfig.GLOBAL_LIFE
var prep_time_remaining: float = 0.0
var prep_timer_active: bool = false
var prep_timer_last_display_second: int = -1
var current_board_view_mode: int = GameEnums.BoardViewMode.FULL_BATTLE
var input_locked: bool = false

var runtime_units: Array[BattleUnitState] = []
var selected_prep_unit: BattleUnitState = null
var selected_deploy_index: int = -1
var player_deploy_pool: Array[DeployOption] = []
var enemy_deploy_pool: Array[DeployOption] = []
var player_support_pool: Array[SupportOption] = []
var selected_support_index: int = -1
var _battle_running: bool = false

var drag_mode: int = DRAG_MODE_NONE
var drag_slot_index: int = -1
var drag_unit: BattleUnitState = null
var drag_hover_coord: Vector2i = Vector2i(-1, -1)
var drag_drop_valid: bool = false
var drag_drop_reason: String = ""

var pending_player_respawns: Array[RespawnRequest] = []
var pending_enemy_respawns: Array[RespawnRequest] = []
var refresh_bar_fallbacks: Array[String] = []
var player_units_sold_last_round: Array[String] = []
var inspected_unit: BattleUnitState = null
var inspected_deploy_index: int = -1
var inspected_support_index: int = -1
var current_opponent_player_id: String = ""
var observed_player_id: String = ""
var player_synergy_summary: String = "Nenhuma"
var enemy_synergy_summary: String = "Nenhuma"
var last_round_result_summary: String = "Ult. rodada  -"
var player_deck: DeckData = null
var enemy_deck: DeckData = null
var player_unit_path_registry: Dictionary = {}
var enemy_unit_path_registry: Dictionary = {}
var battle_turn_index: int = 0
var pending_blinding_mist_turn: int = -1
var pending_blinding_mist_team: int = -1
var pending_blinding_mist_duration_turns: int = 2
var pending_blinding_mist_physical_miss_chance: float = 0.5
var bone_prison_coord: Vector2i = Vector2i(-1, -1)
var bone_prison_owner_team: int = GameEnums.TeamSide.PLAYER
var bone_prison_stun_turns: int = 2
var bone_prison_mana_gain_multiplier: float = 0.0

var lobby_manager: LobbyManager = LobbyManager.new()
var round_manager: RoundManager = RoundManager.new()
var board_system: BoardSystem = BoardSystem.new()
var enemy_prep_planner: EnemyPrepPlanner = EnemyPrepPlanner.new()
var race_synergy_system: RaceSynergySystem = RaceSynergySystem.new()
var necromancer_deck_rules: NecromancerDeckRules = NecromancerDeckRules.new()

@onready var board_grid: BoardGrid = $BoardGrid
@onready var board_presentation_3d: BoardPresentation3D = get_node_or_null("BoardPresentation3D") as BoardPresentation3D
@onready var battle_hud = get_node_or_null("BattleHUD")
@onready var deploy_bar: DeployBar = get_node_or_null("DeployBar") as DeployBar
@onready var board_camera_controller: BoardCameraController = get_node_or_null("BoardCameraController") as BoardCameraController

func _get_signal_bus() -> Node:
	return get_node_or_null("/root/SignalBus")

func _ready() -> void:
	randomize()
	set_process(true)

	if not board_grid:
		push_error("BattleManager: BoardGrid node not found.")
		return
	board_system.setup(board_grid, board_presentation_3d)
	board_grid.set_input_enabled(false)

	if battle_hud:
		hud_update_requested.connect(battle_hud.update_status)
		battle_hud.player_sidebar_entry_pressed.connect(_on_player_sidebar_entry_pressed)
		battle_hud.return_to_local_board_pressed.connect(_on_return_to_local_board_pressed)
		battle_hud.clear_unit_info()
	if deploy_bar:
		deploy_bar.deploy_slot_pressed.connect(_on_deploy_slot_pressed)
		deploy_bar.deploy_slot_right_clicked.connect(_on_deploy_slot_right_clicked)
		deploy_bar.support_slot_pressed.connect(_on_support_slot_pressed)
		deploy_bar.support_slot_right_clicked.connect(_on_support_slot_right_clicked)

	start_match()

func _process(delta: float) -> void:
	if current_match_phase != GameEnums.MatchPhase.ROUND_PREP:
		return
	if current_state != GameEnums.BattleState.PREP:
		return
	if not prep_timer_active or _battle_running:
		return

	prep_time_remaining = maxf(0.0, prep_time_remaining - delta)
	var display_seconds: int = int(ceil(prep_time_remaining))
	if display_seconds != prep_timer_last_display_second:
		prep_timer_last_display_second = display_seconds
		_emit_hud_update()

	if prep_time_remaining <= 0.0:
		prep_timer_active = false
		print("PREP timer expired: auto-starting battle with current formation")
		_confirm_start_battle(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			or mouse_event.button_index == MOUSE_BUTTON_RIGHT
		):
			_handle_info_panel_click(mouse_event.position)
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if _handle_board_right_click(mouse_event.position):
				return

	if current_state != GameEnums.BattleState.PREP or input_locked:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_1:
				_select_deploy_slot(0)
			elif key_event.keycode == KEY_2:
				_select_deploy_slot(1)
			elif key_event.keycode == KEY_3:
				_select_deploy_slot(2)
			elif key_event.keycode == KEY_4:
				_select_deploy_slot(3)
			elif key_event.keycode == KEY_5:
				_select_deploy_slot(4)
			elif key_event.keycode == KEY_Q:
				_select_support_slot(0)
			elif key_event.keycode == KEY_W:
				_select_support_slot(1)
			elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_SPACE:
				_confirm_start_battle()
			elif key_event.keycode == KEY_ESCAPE:
				if drag_mode != DRAG_MODE_NONE:
					print("Drag canceled")
					_clear_drag_state()
				elif selected_support_index >= 0:
					print("Support card canceled")
					_clear_support_selection(true)
		return

	if event is InputEventMouseMotion:
		if drag_mode != DRAG_MODE_NONE:
			_update_drag_feedback((event as InputEventMouseMotion).position)
		return

	if event is InputEventMouseButton:
		var prep_mouse_event := event as InputEventMouseButton
		if prep_mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if prep_mouse_event.pressed:
			_handle_left_press(prep_mouse_event.position)
		else:
			_handle_left_release(prep_mouse_event.position)

func _handle_left_press(screen_pos: Vector2) -> void:
	if drag_mode != DRAG_MODE_NONE:
		return
	if _is_screen_over_ui(screen_pos):
		return

	if selected_support_index >= 0:
		var support_coord: Vector2i = _screen_to_board_coord(screen_pos)
		if not board_grid.is_valid_coord(support_coord):
			print("Alvo do support: clique em um alvo valido destacado")
			return
		var support_option: SupportOption = player_support_pool[selected_support_index]
		if support_option != null and _support_card_requires_cell_target(support_option.card_data):
			_try_use_selected_support_on_coord(support_coord)
			return
		if not board_grid.is_coord_visible_in_current_view(support_coord):
			print("Alvo do support: celulas ocultas nao podem ser usadas no PREP")
			return
		var support_target: BattleUnitState = board_grid.get_unit_at(support_coord)
		if support_target != null and not board_grid.is_unit_visible_in_current_view(support_target):
			print("Alvo do support: a unidade inimiga continua oculta durante o PREP")
			return
		_try_use_selected_support_on_target(support_target)
		return

	if selected_deploy_index >= 0:
		var coord_from_click: Vector2i = _screen_to_board_coord(screen_pos)
		if board_grid.is_valid_coord(coord_from_click):
			_try_deploy_selected_at(coord_from_click)
			return

	var coord: Vector2i = _screen_to_board_coord(screen_pos)
	if not board_grid.is_valid_coord(coord):
		return

	var clicked_unit: BattleUnitState = board_grid.get_unit_at(coord)
	if clicked_unit != null and not board_grid.is_unit_visible_in_current_view(clicked_unit):
		return
	if clicked_unit == null:
		return
	if clicked_unit.team_side != GameEnums.TeamSide.PLAYER:
		print("PREP invalido: nao e possivel arrastar unidades inimigas")
		return
	if not clicked_unit.can_act():
		return

	_set_selected_prep_unit(clicked_unit)
	_begin_board_unit_drag(clicked_unit, screen_pos)

func _handle_left_release(screen_pos: Vector2) -> void:
	if drag_mode == DRAG_MODE_DEPLOY_SLOT:
		_finish_deploy_drag(screen_pos)
	elif drag_mode == DRAG_MODE_BOARD_UNIT:
		_finish_board_unit_drag(screen_pos)

func _handle_info_panel_click(screen_pos: Vector2) -> void:
	if not _is_click_over_inspectable_target(screen_pos):
		_clear_inspected_context()

func _is_click_over_inspectable_target(screen_pos: Vector2) -> bool:
	if deploy_bar and deploy_bar.is_over_any_slot(screen_pos):
		return true
	if battle_hud and battle_hud.is_over_hud(screen_pos):
		return true
	if not board_grid:
		return false

	var coord: Vector2i = _screen_to_board_coord(screen_pos)
	if not board_grid.is_valid_coord(coord):
		return false
	if not board_grid.is_coord_visible_in_current_view(coord):
		return false
	var clicked_unit: BattleUnitState = board_grid.get_unit_at(coord)
	return clicked_unit != null and board_grid.is_unit_visible_in_current_view(clicked_unit)

func _handle_board_right_click(screen_pos: Vector2) -> bool:
	if _is_screen_over_ui(screen_pos):
		return false
	if not board_system.is_screen_over_board(screen_pos):
		return false

	var coord: Vector2i = _screen_to_board_coord(screen_pos)
	if not board_grid.is_valid_coord(coord):
		return false
	if not board_grid.is_coord_visible_in_current_view(coord):
		_clear_inspected_context()
		return true

	board_system.set_selected_coord(coord)
	var clicked_unit: BattleUnitState = board_grid.get_unit_at(coord)
	if clicked_unit != null and not board_grid.is_unit_visible_in_current_view(clicked_unit):
		clicked_unit = null
	if clicked_unit != null:
		_on_board_unit_right_clicked(clicked_unit)
	else:
		_on_board_empty_right_clicked()
	return true

func _screen_to_board_coord(screen_pos: Vector2) -> Vector2i:
	return board_system.screen_to_coord(screen_pos)

func _is_screen_over_ui(screen_pos: Vector2) -> bool:
	if deploy_bar != null and deploy_bar.is_over_ui(screen_pos):
		return true
	if battle_hud != null and battle_hud.is_over_hud(screen_pos):
		return true
	return false

func _begin_deploy_drag(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= player_deploy_pool.size():
		print("Selecao de deploy bloqueada: slot %d indisponivel (pool=%d)" % [slot_index + 1, player_deploy_pool.size()])
		return

	var option: DeployOption = player_deploy_pool[slot_index]
	var state: Dictionary = _get_player_deploy_option_state(option)
	if not bool(state.get("available", false)):
		print("Selecao de deploy bloqueada: slot %d %s (%s)" % [
			slot_index + 1,
			str(state.get("status", "UNAVAILABLE")).to_lower(),
			str(state.get("reason", "indisponivel")),
		])
		return

	_clear_support_selection(false)
	drag_mode = DRAG_MODE_DEPLOY_SLOT
	drag_slot_index = slot_index
	drag_unit = null
	selected_deploy_index = slot_index
	_set_selected_prep_unit(null)
	_refresh_deploy_bar()
	_emit_hud_update()

	print("Arraste de deploy iniciado: %s (custo %d)" % [option.unit_data.id, option.unit_data.cost])

func _begin_board_unit_drag(unit_state: BattleUnitState, screen_pos: Vector2) -> void:
	_clear_support_selection(false)
	drag_mode = DRAG_MODE_BOARD_UNIT
	drag_slot_index = -1
	drag_unit = unit_state
	drag_hover_coord = unit_state.coord
	drag_drop_reason = ""
	drag_drop_valid = false
	_refresh_deploy_bar()
	_emit_hud_update()
	_update_drag_feedback(screen_pos)
	print("Arraste de unidade iniciado: %s" % unit_state.get_combat_label())

func _finish_deploy_drag(screen_pos: Vector2) -> void:
	_update_drag_feedback(screen_pos)
	var slot_index: int = drag_slot_index

	if board_grid.is_valid_coord(drag_hover_coord) and drag_drop_valid:
		_deploy_slot_to_coord(drag_slot_index, drag_hover_coord)
		_clear_drag_state()
		return

	if board_grid.is_valid_coord(drag_hover_coord):
		if drag_drop_reason.is_empty():
			drag_drop_reason = "alvo invalido"
		print("Arraste de deploy bloqueado: %s" % drag_drop_reason)
	else:
		var option: DeployOption = null
		if slot_index >= 0 and slot_index < player_deploy_pool.size():
			option = player_deploy_pool[slot_index]
		if option != null:
			print("Alvo de deploy mantido: clique em uma celula do jogador para posicionar %s" % option.unit_data.display_name)

	_clear_drag_state(true)

func _finish_board_unit_drag(screen_pos: Vector2) -> void:
	_update_drag_feedback(screen_pos)

	if drag_unit == null:
		_clear_drag_state()
		return

	if deploy_bar and deploy_bar.is_over_sell_zone(screen_pos):
		_try_sell_unit(drag_unit)
		_clear_drag_state()
		return

	if board_grid.is_valid_coord(drag_hover_coord):
		var move_check: Dictionary = _can_move_unit_to_coord(drag_unit, drag_hover_coord)
		var move_ok: bool = bool(move_check.get("ok", false))
		var move_reason: String = str(move_check.get("reason", ""))

		if move_ok and drag_hover_coord != drag_unit.coord:
			var from_coord: Vector2i = drag_unit.coord
			if board_grid.move_unit(drag_unit, drag_hover_coord):
				print("PREP moveu %s de %s para %s" % [
					drag_unit.get_combat_label(),
					from_coord,
					drag_hover_coord,
				])
		elif move_reason != "same_cell":
			print("Arraste de unidade cancelado: %s" % move_reason)

	_clear_drag_state()

func _clear_drag_state(keep_deploy_selection: bool = false) -> void:
	var armed_slot_index: int = drag_slot_index
	_set_selected_prep_unit(null)
	drag_mode = DRAG_MODE_NONE
	drag_slot_index = -1
	drag_unit = null
	drag_hover_coord = Vector2i(-1, -1)
	drag_drop_reason = ""
	drag_drop_valid = false
	if keep_deploy_selection and armed_slot_index >= 0:
		selected_deploy_index = armed_slot_index
	else:
		selected_deploy_index = -1

	board_grid.clear_drag_hover()
	if deploy_bar:
		deploy_bar.set_sell_zone_feedback(false, false)

	_refresh_deploy_bar()
	_refresh_targeting_preview()
	_emit_hud_update()

func _update_drag_feedback(screen_pos: Vector2) -> void:
	if drag_mode == DRAG_MODE_DEPLOY_SLOT:
		if _is_screen_over_ui(screen_pos):
			board_grid.clear_drag_hover()
			drag_hover_coord = Vector2i(-1, -1)
			drag_drop_valid = false
			drag_drop_reason = "solto fora do tabuleiro"
			if deploy_bar:
				deploy_bar.set_sell_zone_feedback(false, false)
			return
		if drag_slot_index < 0 or drag_slot_index >= player_deploy_pool.size():
			board_grid.clear_drag_hover()
			drag_drop_valid = false
			drag_drop_reason = "slot invalido"
			return

		var deploy_coord: Vector2i = _screen_to_board_coord(screen_pos)
		if not board_grid.is_valid_coord(deploy_coord):
			board_grid.clear_drag_hover()
			drag_hover_coord = Vector2i(-1, -1)
			drag_drop_valid = false
			drag_drop_reason = "solto fora do tabuleiro"
		else:
			var check: Dictionary = _can_deploy_option_to_coord(player_deploy_pool[drag_slot_index], deploy_coord)
			drag_drop_valid = bool(check.get("ok", false))
			drag_drop_reason = str(check.get("reason", ""))
			drag_hover_coord = deploy_coord
			board_grid.set_drag_hover(deploy_coord, true, drag_drop_valid)

		if deploy_bar:
			deploy_bar.set_sell_zone_feedback(false, false)

	elif drag_mode == DRAG_MODE_BOARD_UNIT:
		if _is_screen_over_ui(screen_pos) and not (deploy_bar and deploy_bar.is_over_sell_zone(screen_pos)):
			board_grid.clear_drag_hover()
			drag_hover_coord = Vector2i(-1, -1)
			drag_drop_valid = false
			drag_drop_reason = "solto fora do tabuleiro"
			if deploy_bar:
				deploy_bar.set_sell_zone_feedback(false, false)
			return
		var move_coord: Vector2i = _screen_to_board_coord(screen_pos)
		if not board_grid.is_valid_coord(move_coord):
			board_grid.clear_drag_hover()
			drag_hover_coord = Vector2i(-1, -1)
			drag_drop_valid = false
			drag_drop_reason = "solto fora do tabuleiro"
		else:
			var move_check: Dictionary = _can_move_unit_to_coord(drag_unit, move_coord)
			drag_drop_valid = bool(move_check.get("ok", false))
			drag_drop_reason = str(move_check.get("reason", ""))
			drag_hover_coord = move_coord
			board_grid.set_drag_hover(move_coord, true, drag_drop_valid)

		if deploy_bar:
			var over_sell: bool = deploy_bar.is_over_sell_zone(screen_pos)
			var sell_valid: bool = false
			if over_sell:
				var sell_check: Dictionary = _can_sell_unit(drag_unit)
				sell_valid = bool(sell_check.get("ok", false))
			deploy_bar.set_sell_zone_feedback(over_sell, sell_valid)

func set_state(new_state: int) -> void:
	current_state = new_state
	var signal_bus: Node = _get_signal_bus()
	if signal_bus:
		signal_bus.battle_state_changed.emit(new_state)
	_emit_hud_update()

func _set_match_phase(new_phase: int) -> void:
	current_match_phase = new_phase
	var signal_bus: Node = _get_signal_bus()
	if signal_bus:
		signal_bus.match_phase_changed.emit(new_phase)
	_emit_hud_update()

func _set_input_locked(locked: bool) -> void:
	input_locked = locked
	if board_grid:
		board_grid.set_input_enabled(false)

func _apply_board_view_mode(view_mode: int, immediate: bool = false) -> void:
	current_board_view_mode = view_mode
	if board_grid:
		board_grid.set_view_mode(view_mode, GameEnums.TeamSide.PLAYER)

	if board_camera_controller and immediate:
		board_camera_controller.snap_to_mode(view_mode)

	var signal_bus: Node = _get_signal_bus()
	if signal_bus:
		signal_bus.board_view_mode_changed.emit(view_mode)

func _setup_match_context() -> void:
	lobby_manager.setup_demo_lobby(BattleConfig.LOBBY_PLAYER_COUNT, LOCAL_PLAYER_ID, PLAYER_DECK_PATH)
	round_manager = RoundManager.new()
	_set_match_phase(GameEnums.MatchPhase.LOBBY)
	print("LOBBY ready: %d players | local=%s" % [
		lobby_manager.get_player_ids().size(),
		LOCAL_PLAYER_ID,
	])

func _prepare_round_pairing_for_current_round() -> void:
	var lobby_player_ids: Array[String] = lobby_manager.get_player_ids()
	if lobby_player_ids.is_empty():
		return

	_set_match_phase(GameEnums.MatchPhase.ROUND_PAIRING)
	var pairings: Array[Dictionary] = round_manager.build_pairings(
		lobby_player_ids,
		current_round
	)
	lobby_manager.apply_round_pairings(pairings)
	current_opponent_player_id = round_manager.get_opponent_for_player(LOCAL_PLAYER_ID)
	_sync_lobby_life_values(true)

	var signal_bus: Node = _get_signal_bus()
	if signal_bus:
		signal_bus.round_pairings_generated.emit(current_round, pairings)

	print("ROUND_PAIRING: round=%d opponent=%s" % [
		current_round,
		_current_opponent_display_name(),
	])
	for pairing in pairings:
		print("  pairing table=%d %s vs %s" % [
			int(pairing.get("table_index", -1)),
			str(pairing.get("player_a", "")),
			str(pairing.get("player_b", "")),
		])

func _sync_lobby_life_values(load_from_lobby: bool = false) -> void:
	var local_player: MatchPlayerState = lobby_manager.get_player(LOCAL_PLAYER_ID)
	var opponent_player: MatchPlayerState = lobby_manager.get_player(current_opponent_player_id)

	if load_from_lobby:
		if local_player != null:
			player_global_life = local_player.current_life
			local_player.eliminated = local_player.current_life <= 0
		if opponent_player != null:
			enemy_global_life = opponent_player.current_life
			opponent_player.eliminated = opponent_player.current_life <= 0
		return

	if local_player != null:
		local_player.current_life = player_global_life
		local_player.eliminated = local_player.current_life <= 0
	if opponent_player != null:
		opponent_player.current_life = enemy_global_life
		opponent_player.eliminated = opponent_player.current_life <= 0

func _current_opponent_display_name() -> String:
	var opponent_player: MatchPlayerState = lobby_manager.get_player(current_opponent_player_id)
	if opponent_player != null:
		return opponent_player.display_name
	if current_opponent_player_id.is_empty():
		return "No Pairing"
	return current_opponent_player_id

func _load_active_decks() -> void:
	player_deck = _load_deck_data(PLAYER_DECK_PATH)
	enemy_deck = _load_deck_data(ENEMY_DECK_PATH)
	player_unit_path_registry = _build_unit_path_registry(player_deck)
	enemy_unit_path_registry = _build_unit_path_registry(enemy_deck)
	_log_loaded_deck("PLAYER", player_deck)
	_log_loaded_deck("ENEMY", enemy_deck)

func _load_deck_data(path: String) -> DeckData:
	var loaded: Resource = load(path)
	if loaded is DeckData:
		return loaded as DeckData

	push_error("BattleManager: failed to load DeckData at %s" % path)
	return null

func _build_unit_path_registry(deck_data: DeckData) -> Dictionary:
	var registry: Dictionary = {}
	if deck_data == null:
		return registry

	if not deck_data.master_unit_path.is_empty():
		var master_data: UnitData = _load_unit_data(deck_data.master_unit_path)
		if master_data != null:
			registry[master_data.id] = deck_data.master_unit_path

	for unit_path in deck_data.unit_paths:
		var unit_data: UnitData = _load_unit_data(unit_path)
		if unit_data != null:
			registry[unit_data.id] = unit_path

	return registry

func _master_home_coord(team_side: int) -> Vector2i:
	return PLAYER_MASTER_COORD if team_side == GameEnums.TeamSide.PLAYER else ENEMY_MASTER_COORD

func _default_deploy_home_coord(slot_index: int, team_side: int) -> Vector2i:
	var row_order: Array[int] = []
	if team_side == GameEnums.TeamSide.PLAYER:
		row_order = [BattleConfig.BOARD_HEIGHT - 2, BattleConfig.BOARD_HEIGHT - 1]
	else:
		row_order = [1, 0]

	var row_index: int = slot_index / SPAWN_COLUMN_ORDER.size()
	var column_index: int = slot_index % SPAWN_COLUMN_ORDER.size()
	if row_index >= row_order.size():
		row_index = row_order.size() - 1

	return Vector2i(SPAWN_COLUMN_ORDER[column_index], row_order[row_index])

func start_match() -> void:
	_setup_match_context()
	_load_active_decks()
	current_round = 1
	player_global_life = BattleConfig.GLOBAL_LIFE
	enemy_global_life = BattleConfig.GLOBAL_LIFE
	prep_time_remaining = 0.0
	prep_timer_active = false
	prep_timer_last_display_second = -1
	enemy_energy_current = 0
	current_opponent_player_id = ""
	observed_player_id = ""
	current_board_view_mode = GameEnums.BoardViewMode.FULL_BATTLE
	_set_input_locked(false)
	pending_player_respawns.clear()
	pending_enemy_respawns.clear()
	refresh_bar_fallbacks.clear()
	player_units_sold_last_round.clear()
	player_deploy_pool.clear()
	selected_support_index = -1
	player_support_pool.clear()
	enemy_deploy_pool.clear()
	player_synergy_summary = "Nenhuma"
	enemy_synergy_summary = "Nenhuma"
	last_round_result_summary = "Ult. rodada  -"
	battle_turn_index = 0
	pending_blinding_mist_turn = -1
	pending_blinding_mist_team = -1
	pending_blinding_mist_duration_turns = 2
	pending_blinding_mist_physical_miss_chance = 0.5
	bone_prison_coord = Vector2i(-1, -1)
	bone_prison_stun_turns = 2
	bone_prison_mana_gain_multiplier = 0.0
	_clear_inspected_context()

	set_state(GameEnums.BattleState.SETUP)
	print("Partida iniciada: vida_jogador=%d vida_inimigo=%d" % [player_global_life, enemy_global_life])

	_setup_initial_match_board()
	_start_prep_phase()

func start_battle() -> void:
	set_state(GameEnums.BattleState.BATTLE)
	var signal_bus: Node = _get_signal_bus()
	if signal_bus:
		signal_bus.round_started.emit(current_round)

func end_round() -> void:
	set_state(GameEnums.BattleState.ROUND_END)
	var signal_bus: Node = _get_signal_bus()
	if signal_bus:
		signal_bus.round_finished.emit(current_round)

func _setup_initial_match_board() -> void:
	_clear_all_runtime_units()
	if player_deck != null:
		_spawn_roster_unit(player_deck.master_unit_path, GameEnums.TeamSide.PLAYER, PLAYER_MASTER_COORD, true)
	if enemy_deck != null:
		_spawn_roster_unit(enemy_deck.master_unit_path, GameEnums.TeamSide.ENEMY, ENEMY_MASTER_COORD, true)

func _start_prep_phase() -> void:
	_clear_round_limited_tokens()
	_remove_dead_runtime_units()
	_prepare_round_pairing_for_current_round()
	lobby_manager.build_remote_round_snapshots(current_round, [LOCAL_PLAYER_ID])

	_ensure_missing_master_respawns()
	var respawned_units: Array[String] = _process_pending_respawns()
	var restored_survivors: Array[String] = _restore_survivors_for_new_prep()

	_build_player_deploy_pool()
	_build_enemy_deploy_pool()
	_build_player_support_pool()
	_mark_pool_used_from_living_player_units()
	_mark_pool_used_from_living_enemy_units()

	_battle_running = false
	battle_turn_index = 0
	pending_blinding_mist_turn = -1
	pending_blinding_mist_team = -1
	pending_blinding_mist_duration_turns = 2
	pending_blinding_mist_physical_miss_chance = 0.5
	bone_prison_coord = Vector2i(-1, -1)
	bone_prison_stun_turns = 2
	bone_prison_mana_gain_multiplier = 0.0
	prep_time_remaining = BattleConfig.PREP_DURATION_SECONDS
	prep_timer_active = true
	prep_timer_last_display_second = -1
	energy_current = BattleConfig.STARTING_ENERGY + ((current_round - 1) * BattleConfig.ENERGY_PER_ROUND)
	enemy_energy_current = energy_current
	_clear_inspected_context()
	_clear_drag_state()
	_clear_support_selection(false)
	_apply_board_view_mode(GameEnums.BoardViewMode.SELF_ONLY, true)
	_auto_prepare_enemy_board()
	_refresh_race_synergy_state(true)
	_sync_runtime_board_snapshots(_match_phase_name())
	_refresh_targeting_preview()
	set_state(GameEnums.BattleState.PREP)
	_set_match_phase(GameEnums.MatchPhase.ROUND_PREP)
	_set_input_locked(false)
	_log_player_prep_pool_state()
	_refresh_deploy_bar()
	_refresh_inspected_unit_panel()
	_emit_hud_update()

	_log_round_refresh(restored_survivors, respawned_units)
	print("PREP iniciado: rodada=%d energia=%d vida_jogador=%d vida_inimigo=%d" % [
		current_round,
		energy_current,
		player_global_life,
		enemy_global_life,
	])
	print("PREP inimigo: energia=%d unidades=%d" % [
		enemy_energy_current,
		_count_non_master_units(GameEnums.TeamSide.ENEMY),
	])
	print("Unidades em campo: JOGADOR=%d INIMIGO=%d" % [
		_count_living_team(GameEnums.TeamSide.PLAYER),
		_count_living_team(GameEnums.TeamSide.ENEMY),
	])
	print("Controles do PREP: arraste slots de unidade para deploy, arraste unidades no tabuleiro, use a linha de suportes para armar efeitos, clique nos alvos destacados, ENTER/SPACE inicia a batalha, botao direito abre info")

func _restore_survivors_for_new_prep() -> Array[String]:
	var rebuild_units: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		unit_state.reset_for_new_round()
		rebuild_units.append(unit_state)

	for unit_state in rebuild_units:
		if unit_state.actor != null or board_grid.get_unit_at(unit_state.coord) == unit_state:
			board_grid.remove_unit(unit_state, true, true)

	var restored_units: Array[String] = []
	var player_units: Array[BattleUnitState] = []
	var enemy_units: Array[BattleUnitState] = []
	for unit_state in rebuild_units:
		if unit_state.team_side == GameEnums.TeamSide.PLAYER:
			player_units.append(unit_state)
		else:
			enemy_units.append(unit_state)

	_place_units_for_clean_prep(player_units, restored_units)
	_place_units_for_clean_prep(enemy_units, restored_units)
	return restored_units

func _place_units_for_clean_prep(units_to_place: Array[BattleUnitState], restored_units: Array[String]) -> void:
	units_to_place.sort_custom(_sort_units_for_clean_prep)

	for unit_state in units_to_place:
		if unit_state == null:
			continue

		var target_coord: Vector2i = _resolve_spawn_coord(unit_state.home_coord, unit_state.team_side)
		if not board_grid.is_valid_coord(target_coord):
			if unit_state.team_side == GameEnums.TeamSide.PLAYER and not unit_state.is_master:
				runtime_units.erase(unit_state)
				_append_unique(refresh_bar_fallbacks, unit_state.get_display_name())
			else:
				push_warning("BattleManager: failed to rebuild prep coord for %s" % unit_state.get_combat_label())
			continue

		unit_state.coord = target_coord
		if not board_grid.spawn_unit(unit_state):
			if unit_state.team_side == GameEnums.TeamSide.PLAYER and not unit_state.is_master:
				runtime_units.erase(unit_state)
				_append_unique(refresh_bar_fallbacks, unit_state.get_display_name())
			else:
				push_warning("BattleManager: failed to rebuild prep spawn for %s at %s" % [
					unit_state.get_combat_label(),
					target_coord,
				])
			continue

		restored_units.append("%s@%s(home %s)" % [
			unit_state.get_combat_label(),
			target_coord,
			unit_state.home_coord,
		])

func _sort_units_for_clean_prep(a: BattleUnitState, b: BattleUnitState) -> bool:
	if a == null:
		return false
	if b == null:
		return true
	if a.is_master != b.is_master:
		return a.is_master
	if a.home_coord.y != b.home_coord.y:
		return a.home_coord.y < b.home_coord.y
	if a.home_coord.x != b.home_coord.x:
		return a.home_coord.x < b.home_coord.x
	return a.get_display_name() < b.get_display_name()

func _ensure_missing_master_respawns() -> void:
	if player_deck != null:
		_enqueue_missing_roster_respawn(player_deck.master_unit_path, GameEnums.TeamSide.PLAYER, true)
	if enemy_deck != null:
		_enqueue_missing_roster_respawn(enemy_deck.master_unit_path, GameEnums.TeamSide.ENEMY, true)

func _enqueue_missing_roster_respawn(unit_path: String, team_side: int, is_master: bool = false) -> void:
	var unit_data: UnitData = _load_unit_data(unit_path)
	if unit_data == null:
		return
	if _find_living_unit_by_id(unit_data.id, team_side) != null:
		return
	if _has_pending_respawn(unit_data.id, team_side):
		return

	var request: RespawnRequest = RespawnRequest.new(
		unit_path,
		unit_data.id,
		team_side,
		_master_home_coord(team_side) if is_master else _default_deploy_home_coord(0, team_side),
		is_master
	)
	_enqueue_respawn_request(request)

func _process_pending_respawns() -> Array[String]:
	var respawn_logs: Array[String] = []
	var remaining_player: Array[RespawnRequest] = []
	var remaining_enemy: Array[RespawnRequest] = []

	for request in pending_player_respawns:
		var spawned_state: BattleUnitState = _materialize_respawn_request(request)
		if spawned_state != null:
			respawn_logs.append("%s queued for clean rebuild" % spawned_state.get_combat_label())
		else:
			remaining_player.append(request)

	for request in pending_enemy_respawns:
		var spawned_state: BattleUnitState = _materialize_respawn_request(request)
		if spawned_state != null:
			respawn_logs.append("%s queued for clean rebuild" % spawned_state.get_combat_label())
		else:
			remaining_enemy.append(request)

	pending_player_respawns = remaining_player
	pending_enemy_respawns = remaining_enemy
	return respawn_logs

func _materialize_respawn_request(request: RespawnRequest) -> BattleUnitState:
	if request == null:
		return null

	var existing_unit: BattleUnitState = _find_living_unit_by_id(request.unit_id, request.team_side)
	if existing_unit != null:
		return existing_unit

	var unit_data: UnitData = _load_unit_data(request.unit_path)
	if unit_data == null:
		return null

	var state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
		unit_data,
		request.team_side,
		request.home_coord,
		request.is_master,
		request.home_coord
	)
	runtime_units.append(state)
	return state

func _log_round_refresh(restored_survivors: Array[String], respawned_units: Array[String]) -> void:
	if not restored_survivors.is_empty():
		print("Round refresh restored: %s" % _join_strings(restored_survivors))
		print("Round refresh: formation rebuilt from home coords | HP full | mana reset to 0")

	if not respawned_units.is_empty():
		print("Round refresh repopulated: %s" % _join_strings(respawned_units))

	if not refresh_bar_fallbacks.is_empty():
		print("Returned to deploy bar due to lack of space: %s" % _join_strings(refresh_bar_fallbacks))

	if not player_units_sold_last_round.is_empty():
		print("Pool reset includes previously sold units: %s" % _join_strings(player_units_sold_last_round))

	refresh_bar_fallbacks.clear()
	player_units_sold_last_round.clear()

func _refresh_race_synergy_state(log_changes: bool) -> void:
	var previous_player_summary: String = player_synergy_summary
	var previous_enemy_summary: String = enemy_synergy_summary

	var player_result: Dictionary = race_synergy_system.apply_team_synergies(
		runtime_units,
		GameEnums.TeamSide.PLAYER
	)
	var enemy_result: Dictionary = race_synergy_system.apply_team_synergies(
		runtime_units,
		GameEnums.TeamSide.ENEMY
	)
	player_synergy_summary = str(player_result.get("summary", "Nenhuma"))
	enemy_synergy_summary = str(enemy_result.get("summary", "Nenhuma"))

	if log_changes and player_synergy_summary != previous_player_summary:
		print("Racas do jogador em campo: %s" % player_synergy_summary)
	if log_changes and enemy_synergy_summary != previous_enemy_summary:
		print("Racas do inimigo em campo: %s" % enemy_synergy_summary)

	_refresh_inspected_unit_panel()
	_emit_hud_update()

func _confirm_start_battle(force_auto_start: bool = false) -> void:
	if _battle_running or current_state != GameEnums.BattleState.PREP:
		return
	if input_locked and not force_auto_start:
		return

	var deployed_player_units: int = _count_player_non_master_units()
	if not force_auto_start and deployed_player_units <= 0 and _player_has_ready_deploy_slots():
		print("BATALHA bloqueada: faca deploy de pelo menos uma unidade antes de iniciar (slots_prontos=%d)" % _count_ready_player_deploy_slots())
		return
	if force_auto_start and deployed_player_units <= 0 and _player_has_ready_deploy_slots():
		print("AUTO-START do PREP: seguindo com a formacao atual sem deploy adicional do jogador")
	elif deployed_player_units <= 0:
		print("BATALHA seguindo so com o mestre: nenhum slot de deploy pronto no PREP")

	_set_input_locked(true)
	_commit_player_prep_formation()
	_clear_inspected_context()
	_clear_support_selection(false)
	_clear_drag_state()
	_set_selected_prep_unit(null)
	selected_deploy_index = -1
	prep_timer_active = false
	_battle_running = true
	print("BATALHA confirmada: %s" % ("auto-start do timer" if force_auto_start else "input manual"))
	call_deferred("_start_auto_battle")

func _start_auto_battle() -> void:
	_set_input_locked(true)
	if board_grid:
		board_grid.clear_target_highlights()
	_apply_board_view_mode(GameEnums.BoardViewMode.FULL_BATTLE, false)
	if board_camera_controller:
		var reveal_tween: Tween = board_camera_controller.transition_to_mode(
			GameEnums.BoardViewMode.FULL_BATTLE,
			BattleConfig.REVEAL_TRANSITION_SECONDS
		)
		if reveal_tween != null:
			await reveal_tween.finished
	else:
		await get_tree().create_timer(BattleConfig.REVEAL_TRANSITION_SECONDS).timeout

	_set_input_locked(false)
	_apply_bone_prison_opening()
	_set_match_phase(GameEnums.MatchPhase.ROUND_BATTLE)
	start_battle()
	print("BATALHA iniciada: rodada=%d oponente=%s" % [current_round, _current_opponent_display_name()])
	_run_auto_battle()

func _run_auto_battle() -> void:
	while current_state == GameEnums.BattleState.BATTLE:
		if _is_combat_finished():
			break

		var turn_order: Array[BattleUnitState] = _build_auto_battle_turn_order()
		if turn_order.is_empty():
			break

		for acting_unit in turn_order:
			if current_state != GameEnums.BattleState.BATTLE:
				break
			if _is_combat_finished():
				break
			var turn_result: Dictionary = _process_unit_turn(acting_unit)
			var decision_delay: float = _decision_delay_for_turn_result(turn_result)
			if decision_delay > 0.0:
				await get_tree().create_timer(decision_delay).timeout

	var winner_team: int = _get_winner_team()
	var survivor_count: int = _count_living_team(winner_team)
	_finish_round(winner_team, survivor_count)

func _build_auto_battle_turn_order() -> Array[BattleUnitState]:
	var living_units: Array[BattleUnitState] = []
	var turn_order: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		living_units.append(unit_state)

	if living_units.is_empty():
		return turn_order

	var max_entries: int = maxi(1, living_units.size() * 2)
	for unit_state in living_units:
		unit_state.gain_action_charge()
		while unit_state.can_take_turn_from_charge() and turn_order.size() < max_entries:
			turn_order.append(unit_state)
			unit_state.consume_action_charge()

	if turn_order.is_empty():
		for unit_state in living_units:
			turn_order.append(unit_state)
	return turn_order

func _decision_delay_for_turn_result(turn_result: Dictionary) -> float:
	var outcome: String = str(turn_result.get("outcome", "stuck"))
	match outcome:
		"attack":
			return ACTION_DELAY_ATTACK_SECONDS
		"skill":
			return ACTION_DELAY_SKILL_SECONDS
		"move":
			return ACTION_DELAY_MOVE_SECONDS
		"skip":
			return ACTION_DELAY_SKIP_SECONDS
		_:
			return ACTION_DELAY_STUCK_SECONDS

func _finish_round(winner_team: int, survivor_count: int) -> void:
	var round_winner_label: String = "EMPATE"
	_set_match_phase(GameEnums.MatchPhase.ROUND_RESULT)
	_clear_inspected_context()

	if winner_team == GameEnums.TeamSide.PLAYER:
		round_winner_label = "JOGADOR"
		enemy_global_life = maxi(0, enemy_global_life - survivor_count)
		_emit_global_life_changed(GameEnums.TeamSide.ENEMY, enemy_global_life)
		print("Dano na vida global: INIMIGO -%d" % survivor_count)
	elif winner_team == GameEnums.TeamSide.ENEMY:
		round_winner_label = "INIMIGO"
		player_global_life = maxi(0, player_global_life - survivor_count)
		_emit_global_life_changed(GameEnums.TeamSide.PLAYER, player_global_life)
		print("Dano na vida global: JOGADOR -%d" % survivor_count)

	print("FIM DA RODADA: vencedor=%s sobreviventes=%d dano_na_vida_global=%d" % [
		round_winner_label,
		survivor_count,
		survivor_count,
	])
	print("Vida global: jogador=%d inimigo=%d" % [player_global_life, enemy_global_life])
	if winner_team == GameEnums.TeamSide.PLAYER:
		last_round_result_summary = "Ult. rodada  Vitoria do jogador | Sobreviventes %d | Inimigo -%d de vida" % [
			survivor_count,
			survivor_count,
		]
	elif winner_team == GameEnums.TeamSide.ENEMY:
		last_round_result_summary = "Ult. rodada  Vitoria do inimigo | Sobreviventes %d | Jogador -%d de vida" % [
			survivor_count,
			survivor_count,
		]
	else:
		last_round_result_summary = "Ult. rodada  Empate | Sobreviventes 0 | Sem dano global"
	_emit_hud_update()

	_remove_dead_runtime_units()
	_sync_lobby_life_values(false)
	_sync_runtime_board_snapshots(_match_phase_name())
	var background_results: Array[Dictionary] = lobby_manager.resolve_background_pairings(
		round_manager.get_current_pairings(),
		current_round,
		[LOCAL_PLAYER_ID]
	)
	for result in background_results:
		print("LOBBY background result: %s" % str(result.get("result_text", "resultado resolvido")))
	_emit_hud_update()
	var local_player: MatchPlayerState = lobby_manager.get_player(LOCAL_PLAYER_ID)
	var opponent_player: MatchPlayerState = lobby_manager.get_player(current_opponent_player_id)
	if opponent_player != null and opponent_player.current_life <= 0:
		print("Resultado do lobby: %s foi reduzido a 0 de vida" % opponent_player.display_name)
	if local_player != null and local_player.current_life <= 0:
		print("Resultado do lobby: o jogador local chegou a 0 de vida")
	end_round()
	_battle_running = false

	if _is_match_finished():
		_set_match_phase(GameEnums.MatchPhase.MATCH_END)
		set_state(GameEnums.BattleState.MATCH_END)
		print("FIM DA PARTIDA: vencedor=%s" % _get_match_winner_label())
		return

	current_round += 1
	print("Iniciando proxima rodada: %d" % current_round)
	_start_prep_phase()

func _emit_global_life_changed(team_side: int, value: int) -> void:
	var signal_bus: Node = _get_signal_bus()
	if signal_bus:
		signal_bus.global_life_changed.emit(team_side, value)

func _state_name() -> String:
	if current_state == GameEnums.BattleState.SETUP:
		return "SETUP"
	if current_state == GameEnums.BattleState.PREP:
		return "PREPARACAO"
	if current_state == GameEnums.BattleState.BATTLE:
		return "BATALHA"
	if current_state == GameEnums.BattleState.ROUND_END:
		return "FIM_DA_RODADA"
	if current_state == GameEnums.BattleState.MATCH_END:
		return "FIM_DA_PARTIDA"
	return "DESCONHECIDO"

func _match_phase_name() -> String:
	match current_match_phase:
		GameEnums.MatchPhase.LOBBY:
			return "LOBBY"
		GameEnums.MatchPhase.ROUND_PAIRING:
			return "PAREAMENTO"
		GameEnums.MatchPhase.ROUND_PREP:
			return "PREPARACAO"
		GameEnums.MatchPhase.ROUND_BATTLE:
			return "BATALHA"
		GameEnums.MatchPhase.ROUND_RESULT:
			return "RESULTADO"
		GameEnums.MatchPhase.MATCH_END:
			return "FIM"
		_:
			return "DESCONHECIDO"

func _selection_label() -> String:
	if drag_mode == DRAG_MODE_DEPLOY_SLOT and drag_slot_index >= 0 and drag_slot_index < player_deploy_pool.size():
		return "Arrastando %s" % player_deploy_pool[drag_slot_index].unit_data.display_name
	if drag_mode == DRAG_MODE_BOARD_UNIT and drag_unit != null:
		return "Arrastando %s" % drag_unit.get_combat_label()
	if selected_support_index >= 0 and selected_support_index < player_support_pool.size():
		var support_option: SupportOption = player_support_pool[selected_support_index]
		return "Suporte %s (custo %d, ARMADO)" % [
			support_option.card_data.display_name,
			support_option.card_data.cost,
		]

	if selected_deploy_index < 0 or selected_deploy_index >= player_deploy_pool.size():
		return "Nenhuma"

	var option: DeployOption = player_deploy_pool[selected_deploy_index]
	var status: String = "USADO" if option.used else "PRONTO"
	return "%d:%s (custo %d, %s)" % [
		selected_deploy_index + 1,
		option.unit_data.display_name,
		option.unit_data.cost,
		status,
	]

func _prep_timer_label() -> String:
	if current_match_phase != GameEnums.MatchPhase.ROUND_PREP:
		return "-"
	return "%ds" % int(ceil(prep_time_remaining))

func _hud_focus_label() -> String:
	return "Selecao      %s\nOponente     %s | Preparo %s" % [
		_selection_label(),
		_current_opponent_display_name(),
		_prep_timer_label(),
	]

func _emit_hud_update() -> void:
	_sync_runtime_board_snapshots(_match_phase_name())
	hud_update_requested.emit(
		current_round,
		player_global_life,
		enemy_global_life,
		energy_current,
		"%s / %s" % [_match_phase_name(), _state_name()],
		_hud_focus_label(),
		player_synergy_summary,
		last_round_result_summary
	)
	if battle_hud:
		battle_hud.update_player_sidebar(_build_player_sidebar_entries())
		if not observed_player_id.is_empty():
			var observed_snapshot: Dictionary = lobby_manager.get_board_snapshot(observed_player_id)
			if observed_snapshot.is_empty():
				observed_player_id = ""
				battle_hud.clear_unit_info()
			else:
				battle_hud.update_observed_board(observed_snapshot)

func _build_player_sidebar_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for player_id in lobby_manager.get_player_ids():
		var player_state: MatchPlayerState = lobby_manager.get_player(player_id)
		if player_state == null:
			continue
		entries.append({
			"player_id": player_state.player_id,
			"name": player_state.display_name,
			"life": player_state.current_life,
			"is_local": player_state.player_id == LOCAL_PLAYER_ID,
			"is_current_opponent": player_state.player_id == current_opponent_player_id,
			"is_observed": player_state.player_id == observed_player_id,
			"eliminated": player_state.eliminated,
		})

	entries.sort_custom(_sort_player_sidebar_entries)
	return entries

func _sort_player_sidebar_entries(a: Dictionary, b: Dictionary) -> bool:
	var life_a: int = int(a.get("life", 0))
	var life_b: int = int(b.get("life", 0))
	if life_a != life_b:
		return life_a > life_b

	var eliminated_a: bool = bool(a.get("eliminated", false))
	var eliminated_b: bool = bool(b.get("eliminated", false))
	if eliminated_a != eliminated_b:
		return not eliminated_a

	var local_a: bool = bool(a.get("is_local", false))
	var local_b: bool = bool(b.get("is_local", false))
	if local_a != local_b:
		return local_a

	return str(a.get("name", "")) < str(b.get("name", ""))

func _sync_runtime_board_snapshots(phase_label: String) -> void:
	_store_runtime_board_snapshot(LOCAL_PLAYER_ID, GameEnums.TeamSide.PLAYER, phase_label)
	if not current_opponent_player_id.is_empty():
		_store_runtime_board_snapshot(current_opponent_player_id, GameEnums.TeamSide.ENEMY, phase_label)

func _store_runtime_board_snapshot(player_id: String, team_side: int, phase_label: String) -> void:
	if player_id.is_empty():
		return

	var player_state: MatchPlayerState = lobby_manager.get_player(player_id)
	if player_state == null:
		return

	var units: Array[Dictionary] = []
	var total_power: int = 0
	var master_name: String = "Sem mestre"
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue

		var preview_coord: Vector2i = _coord_for_snapshot_perspective(unit_state.coord, team_side)
		var unit_entry: Dictionary = {
			"unit_id": unit_state.unit_data.id if unit_state.unit_data != null else "",
			"display_name": unit_state.get_display_name(),
			"coord": preview_coord,
			"is_master": unit_state.is_master,
			"class_label": unit_state.get_class_name(),
			"race_name": unit_state.get_race_name(),
			"cost": unit_state.unit_data.cost if unit_state.unit_data != null else 0,
		}
		if unit_state.is_master:
			units.insert(0, unit_entry)
			master_name = unit_state.get_display_name()
		else:
			units.append(unit_entry)
		total_power += _estimate_runtime_unit_power(unit_state)

	var energy_value: int = energy_current if team_side == GameEnums.TeamSide.PLAYER else enemy_energy_current
	var life_value: int = player_global_life if team_side == GameEnums.TeamSide.PLAYER else enemy_global_life
	var snapshot: Dictionary = {
		"player_id": player_id,
		"player_name": player_state.display_name,
		"round_number": current_round,
		"phase": phase_label,
		"life": life_value,
		"energy": BattleConfig.STARTING_ENERGY + ((current_round - 1) * BattleConfig.ENERGY_PER_ROUND),
		"energy_budget": maxi(0, energy_value),
		"units": units,
		"unit_count": units.size(),
		"non_master_count": maxi(0, units.size() - 1),
		"power_rating": total_power,
		"master_name": master_name,
		"summary": _runtime_snapshot_summary(units),
		"result_text": player_state.last_round_result_text,
	}
	lobby_manager.store_board_snapshot(player_id, snapshot)

func _coord_for_snapshot_perspective(coord: Vector2i, team_side: int) -> Vector2i:
	if team_side == GameEnums.TeamSide.ENEMY:
		return Vector2i(coord.x, BattleConfig.BOARD_HEIGHT - 1 - coord.y)
	return coord

func _estimate_runtime_unit_power(unit_state: BattleUnitState) -> int:
	if unit_state == null or unit_state.unit_data == null:
		return 0
	var power: int = 0
	power += unit_state.current_hp * 2
	power += unit_state.get_physical_attack_value() * 5
	power += unit_state.get_magic_attack_value() * 5
	power += unit_state.get_physical_defense_value() * 4
	power += unit_state.get_magic_defense_value() * 4
	power += unit_state.get_attack_range() * 3
	power += int(round(unit_state.get_crit_chance() * 100.0))
	power += unit_state.unit_data.cost * 12
	if unit_state.has_master_skill() or unit_state.has_unit_skill():
		power += 20
	if unit_state.is_master:
		power += 45
	return maxi(1, power)

func _runtime_snapshot_summary(units: Array[Dictionary]) -> String:
	var summary_parts: Array[String] = []
	for unit_entry in units:
		summary_parts.append("%s @ %s" % [
			str(unit_entry.get("display_name", "Unidade")),
			unit_entry.get("coord", Vector2i(-1, -1)),
		])
	return _join_strings(summary_parts)

func _refresh_deploy_bar() -> void:
	if not deploy_bar:
		return

	var unit_slot_data: Array[Dictionary] = []
	for option in player_deploy_pool:
		unit_slot_data.append(_build_deploy_slot_view_data(option))

	var dragging_idx: int = drag_slot_index if drag_mode == DRAG_MODE_DEPLOY_SLOT else -1
	deploy_bar.update_unit_slots(unit_slot_data, dragging_idx)

	var support_slot_data: Array[Dictionary] = []
	for option in player_support_pool:
		support_slot_data.append(_build_support_slot_view_data(option))
	deploy_bar.update_support_slots(support_slot_data, selected_support_index)

func _build_deploy_slot_view_data(option: DeployOption) -> Dictionary:
	var state: Dictionary = _get_player_deploy_option_state(option)
	var unit_name: String = "Unidade desconhecida"
	var unit_cost: int = 0
	if option != null and option.unit_data != null:
		unit_name = option.unit_data.display_name
		unit_cost = option.unit_data.cost

	return {
		"name": unit_name,
		"cost": unit_cost,
		"used": str(state.get("status", "UNAVAILABLE")) == "USED",
		"affordable": bool(state.get("available", false)),
		"status": str(state.get("status", "UNAVAILABLE")),
	}

func _build_support_slot_view_data(option: SupportOption) -> Dictionary:
	var state: Dictionary = _get_player_support_option_state(option)
	var card_name: String = "Suporte desconhecido"
	var card_cost: int = 0
	if option != null and option.card_data != null:
		card_name = option.card_data.display_name
		card_cost = option.card_data.cost

	return {
		"name": card_name,
		"cost": card_cost,
		"used": str(state.get("status", "UNAVAILABLE")) == "USED",
		"affordable": bool(state.get("available", false)),
		"status": str(state.get("status", "UNAVAILABLE")),
	}

func _get_player_deploy_option_state(option: DeployOption) -> Dictionary:
	if current_state != GameEnums.BattleState.PREP:
		return {"status": "UNAVAILABLE", "reason": "deploy so esta disponivel no PREP", "available": false}
	if option == null or option.unit_data == null:
		return {"status": "UNAVAILABLE", "reason": "dados da unidade ausentes", "available": false}
	if option.used:
		return {"status": "USED", "reason": "slot ja foi usado nesta rodada", "available": false}
	if energy_current < option.unit_data.cost:
		return {
			"status": "NO ENERGY",
			"reason": "custo %d > energia %d" % [option.unit_data.cost, energy_current],
			"available": false,
		}
	if not _has_valid_player_deploy_target(option):
		return {"status": "UNAVAILABLE", "reason": "nenhuma celula valida do jogador disponivel", "available": false}
	return {"status": "READY", "reason": "", "available": true}

func _get_player_support_option_state(option: SupportOption) -> Dictionary:
	if current_state != GameEnums.BattleState.PREP:
		return {"status": "UNAVAILABLE", "reason": "supports so estao disponiveis no PREP", "available": false}
	if option == null or option.card_data == null:
		return {"status": "UNAVAILABLE", "reason": "dados do support ausentes", "available": false}
	if option.used:
		return {"status": "USED", "reason": "support ja foi usado nesta rodada", "available": false}
	if energy_current < option.card_data.cost:
		return {
			"status": "NO ENERGY",
			"reason": "custo %d > energia %d" % [option.card_data.cost, energy_current],
			"available": false,
		}
	if not _has_valid_support_target(option.card_data):
		return {
			"status": "UNAVAILABLE",
			"reason": "nenhum alvo valido para %s" % option.card_data.display_name,
			"available": false,
		}
	return {"status": "READY", "reason": "", "available": true}

func _has_valid_player_deploy_target(option: DeployOption) -> bool:
	if board_grid == null or option == null or option.unit_data == null:
		return false

	for y in range(BattleConfig.BOARD_HEIGHT):
		for x in range(BattleConfig.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			if not board_grid.is_coord_in_team_zone(coord, GameEnums.TeamSide.PLAYER):
				continue
			if bool(_can_deploy_option_to_coord(option, coord).get("ok", false)):
				return true
	return false

func _has_valid_support_target(card_data: CardData) -> bool:
	if card_data == null:
		return false
	if _support_card_is_instant(card_data):
		return true
	return not _get_valid_support_target_coords(card_data).is_empty()

func _count_ready_player_deploy_slots() -> int:
	var count: int = 0
	for option in player_deploy_pool:
		if bool(_get_player_deploy_option_state(option).get("available", false)):
			count += 1
	return count

func _player_has_ready_deploy_slots() -> bool:
	return _count_ready_player_deploy_slots() > 0

func _log_loaded_deck(label: String, deck_data: DeckData) -> void:
	if deck_data == null:
		push_warning("BattleManager: %s deck failed to load" % label)
		return

	print("%s deck loaded: id=%s master=%s units=%d supports=%d" % [
		label,
		deck_data.id,
		deck_data.master_unit_path,
		deck_data.unit_paths.size(),
		deck_data.support_card_paths.size(),
	])
	if deck_data.unit_paths.is_empty():
		push_warning("BattleManager: %s deck has no deployable unit paths" % label)
	if deck_data.support_card_paths.is_empty():
		push_warning("BattleManager: %s deck has no support card paths" % label)

func _log_player_prep_pool_state() -> void:
	print("Pool do PREP do jogador: deploy_slots=%d support_slots=%d ready_deploy=%d" % [
		player_deploy_pool.size(),
		player_support_pool.size(),
		_count_ready_player_deploy_slots(),
	])
	if player_deploy_pool.is_empty():
		push_warning("BattleManager: player deploy pool is empty in PREP")
	if player_support_pool.is_empty():
		push_warning("BattleManager: player support pool is empty in PREP")

func _load_unit_data(path: String) -> UnitData:
	var loaded: Resource = load(path)
	if loaded is UnitData:
		return loaded as UnitData

	push_warning("BattleManager: failed to load UnitData at %s" % path)
	return null

func _load_card_data(path: String) -> CardData:
	var loaded: Resource = load(path)
	if loaded is CardData:
		return loaded as CardData

	push_warning("BattleManager: failed to load CardData at %s" % path)
	return null

func _build_player_deploy_pool() -> void:
	player_deploy_pool.clear()
	if player_deck == null:
		return

	for index in range(player_deck.unit_paths.size()):
		var path: String = player_deck.unit_paths[index]
		var unit_data: UnitData = _load_unit_data(path)
		if unit_data != null:
			player_deploy_pool.append(DeployOption.new(
				unit_data,
				path,
				GameEnums.TeamSide.PLAYER,
				_default_deploy_home_coord(index, GameEnums.TeamSide.PLAYER),
				false
			))

func _build_enemy_deploy_pool() -> void:
	enemy_deploy_pool.clear()
	if enemy_deck == null:
		return

	for index in range(enemy_deck.unit_paths.size()):
		var path: String = enemy_deck.unit_paths[index]
		var unit_data: UnitData = _load_unit_data(path)
		if unit_data != null:
			enemy_deploy_pool.append(DeployOption.new(
				unit_data,
				path,
				GameEnums.TeamSide.ENEMY,
				_default_deploy_home_coord(index, GameEnums.TeamSide.ENEMY),
				false
			))

func _build_player_support_pool() -> void:
	player_support_pool.clear()
	if player_deck == null:
		return

	for path in player_deck.support_card_paths:
		var card_data: CardData = _load_card_data(path)
		if card_data != null:
			player_support_pool.append(SupportOption.new(card_data, path))

func _mark_pool_used_from_living_player_units() -> void:
	_mark_pool_used_from_living_team_units(player_deploy_pool, GameEnums.TeamSide.PLAYER)

func _mark_pool_used_from_living_enemy_units() -> void:
	_mark_pool_used_from_living_team_units(enemy_deploy_pool, GameEnums.TeamSide.ENEMY)

func _mark_pool_used_from_living_team_units(deploy_pool: Array[DeployOption], team_side: int) -> void:
	for option in deploy_pool:
		option.used = false

	for unit_state in runtime_units:
		if unit_state == null:
			continue
		if not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state.is_master:
			continue
		_mark_first_pool_slot_used_by_id(deploy_pool, unit_state.unit_data.id)

func _mark_first_pool_slot_used_by_id(deploy_pool: Array[DeployOption], unit_id: String) -> void:
	for option in deploy_pool:
		if option.used:
			continue
		if option.unit_data.id == unit_id:
			option.used = true
			return

func _release_pool_slot_for_unit(unit_id: String) -> void:
	for option in player_deploy_pool:
		if option.unit_data.id == unit_id and option.used:
			option.used = false
			return

func _spawn_roster_unit(
	unit_path: String,
	team_side: int,
	preferred_coord: Vector2i,
	is_master: bool = false,
	home_coord: Vector2i = Vector2i(-1, -1)
) -> BattleUnitState:
	var unit_data: UnitData = _load_unit_data(unit_path)
	if unit_data == null:
		return null

	var resolved_home_coord: Vector2i = home_coord
	if resolved_home_coord == Vector2i(-1, -1):
		resolved_home_coord = preferred_coord if board_grid.is_valid_coord(preferred_coord) else _master_home_coord(team_side)

	var spawn_coord: Vector2i = preferred_coord
	if not board_grid.is_valid_coord(spawn_coord) or not board_grid.is_cell_free(spawn_coord):
		spawn_coord = _resolve_spawn_coord(resolved_home_coord, team_side)
	if not board_grid.is_valid_coord(spawn_coord):
		push_warning("BattleManager: no valid spawn coord for %s" % unit_data.id)
		return null

	var state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
		unit_data,
		team_side,
		spawn_coord,
		is_master,
		resolved_home_coord
	)
	if not board_grid.spawn_unit(state):
		push_warning("BattleManager: failed to spawn %s at %s" % [unit_data.id, spawn_coord])
		return null

	runtime_units.append(state)
	print("Home coord registered: %s -> %s" % [state.get_combat_label(), state.home_coord])
	return state

func _resolve_spawn_coord(preferred_coord: Vector2i, team_side: int) -> Vector2i:
	if board_grid.is_valid_coord(preferred_coord) and board_grid.is_cell_free(preferred_coord):
		return preferred_coord
	var nearest_coord: Vector2i = _find_nearest_free_coord_in_zone(team_side, preferred_coord)
	if board_grid.is_valid_coord(nearest_coord):
		return nearest_coord
	return _find_first_free_coord_in_zone(team_side)

func _find_nearest_free_coord_in_zone(team_side: int, origin_coord: Vector2i) -> Vector2i:
	var best_coord: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1000000
	var best_vertical_delta: int = 1000000
	var best_horizontal_delta: int = 1000000
	var row_start: int = 0
	var row_end: int = BattleConfig.BOARD_HEIGHT

	if team_side == GameEnums.TeamSide.ENEMY:
		row_start = 0
		row_end = BattleConfig.ENEMY_ROWS
	elif team_side == GameEnums.TeamSide.PLAYER:
		row_start = BattleConfig.BOARD_HEIGHT - BattleConfig.PLAYER_ROWS
		row_end = BattleConfig.BOARD_HEIGHT

	for y in range(row_start, row_end):
		for x in range(BattleConfig.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			if not board_grid.is_valid_coord(coord):
				continue
			if not board_grid.is_cell_free(coord):
				continue

			var distance: int = board_grid.distance_between_cells(coord, origin_coord)
			var vertical_delta: int = abs(coord.y - origin_coord.y)
			var horizontal_delta: int = abs(coord.x - origin_coord.x)
			if distance < best_distance:
				best_coord = coord
				best_distance = distance
				best_vertical_delta = vertical_delta
				best_horizontal_delta = horizontal_delta
			elif distance == best_distance:
				if vertical_delta < best_vertical_delta:
					best_coord = coord
					best_vertical_delta = vertical_delta
					best_horizontal_delta = horizontal_delta
				elif vertical_delta == best_vertical_delta and horizontal_delta < best_horizontal_delta:
					best_coord = coord
					best_horizontal_delta = horizontal_delta
				elif vertical_delta == best_vertical_delta and horizontal_delta == best_horizontal_delta:
					if coord.x < best_coord.x or (coord.x == best_coord.x and coord.y < best_coord.y):
						best_coord = coord

	return best_coord

func _find_first_free_coord_in_zone(team_side: int) -> Vector2i:
	if team_side == GameEnums.TeamSide.ENEMY:
		for y in range(BattleConfig.ENEMY_ROWS):
			for x in SPAWN_COLUMN_ORDER:
				var coord := Vector2i(x, y)
				if board_grid.is_valid_coord(coord) and board_grid.is_cell_free(coord):
					return coord
	elif team_side == GameEnums.TeamSide.PLAYER:
		for y in range(BattleConfig.BOARD_HEIGHT - BattleConfig.PLAYER_ROWS, BattleConfig.BOARD_HEIGHT):
			for x in SPAWN_COLUMN_ORDER:
				var coord := Vector2i(x, y)
				if board_grid.is_valid_coord(coord) and board_grid.is_cell_free(coord):
					return coord

	for y in range(BattleConfig.BOARD_HEIGHT):
		for x in SPAWN_COLUMN_ORDER:
			var fallback_coord := Vector2i(x, y)
			if board_grid.is_valid_coord(fallback_coord) and board_grid.is_cell_free(fallback_coord):
				return fallback_coord

	return Vector2i(-1, -1)

func _find_living_unit_by_id(unit_id: String, team_side: int) -> BattleUnitState:
	for unit_state in runtime_units:
		if unit_state == null:
			continue
		if not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state.unit_data == null:
			continue
		if unit_state.unit_data.id == unit_id:
			return unit_state
	return null

func _clear_all_runtime_units() -> void:
	for unit_state in runtime_units:
		if unit_state != null:
			board_grid.remove_unit(unit_state, true)
	runtime_units.clear()

func _remove_dead_runtime_units() -> void:
	var alive_units: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null:
			continue
		if unit_state.can_act():
			alive_units.append(unit_state)
	runtime_units = alive_units

func _on_deploy_slot_pressed(slot_index: int) -> void:
	if current_state != GameEnums.BattleState.PREP:
		return
	_begin_deploy_drag(slot_index)

func _on_deploy_slot_right_clicked(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= player_deploy_pool.size():
		return

	observed_player_id = ""
	inspected_unit = null
	inspected_deploy_index = slot_index
	inspected_support_index = -1
	_refresh_inspected_unit_panel()

func _on_support_slot_pressed(slot_index: int) -> void:
	if current_state != GameEnums.BattleState.PREP:
		return
	_select_support_slot(slot_index)

func _on_support_slot_right_clicked(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= player_support_pool.size():
		return

	observed_player_id = ""
	inspected_unit = null
	inspected_deploy_index = -1
	inspected_support_index = slot_index
	_refresh_inspected_unit_panel()

func _select_deploy_slot(index: int) -> void:
	if index < 0 or index >= player_deploy_pool.size():
		print("Selecao de deploy bloqueada: slot %d indisponivel (pool=%d)" % [index + 1, player_deploy_pool.size()])
		return

	var option: DeployOption = player_deploy_pool[index]
	var state: Dictionary = _get_player_deploy_option_state(option)
	if not bool(state.get("available", false)):
		print("Selecao de deploy bloqueada: slot %d %s (%s)" % [
			index + 1,
			str(state.get("status", "UNAVAILABLE")).to_lower(),
			str(state.get("reason", "indisponivel")),
		])
		return

	_clear_support_selection(false)
	selected_deploy_index = index
	_set_selected_prep_unit(null)
	_refresh_deploy_bar()
	_emit_hud_update()
	print("Deploy selecionado: slot=%d unidade=%s custo=%d energia=%d" % [
		index + 1,
		option.unit_data.id,
		option.unit_data.cost,
		energy_current,
	])

func _select_support_slot(index: int) -> void:
	if drag_mode != DRAG_MODE_NONE:
		print("Selecao de support bloqueada: finalize o arraste atual primeiro")
		return
	if index < 0 or index >= player_support_pool.size():
		print("Selecao de support bloqueada: slot %d indisponivel (pool=%d)" % [index + 1, player_support_pool.size()])
		return

	var option: SupportOption = player_support_pool[index]
	var state: Dictionary = _get_player_support_option_state(option)
	if not bool(state.get("available", false)):
		print("Selecao de support bloqueada: slot %d %s (%s)" % [
			index + 1,
			str(state.get("status", "UNAVAILABLE")).to_lower(),
			str(state.get("reason", "indisponivel")),
		])
		return
	if _support_card_is_instant(option.card_data):
		if _use_instant_support_card(option):
			_refresh_deploy_bar()
			_emit_hud_update()
		return
	var valid_target_count: int = _get_valid_support_target_coords(option.card_data).size()
	if valid_target_count <= 0:
		print("Selecao de support bloqueada: nenhum alvo valido para %s" % option.card_data.display_name)
		return

	if selected_support_index == index:
		print("Selecao de support cancelada: %s" % option.card_data.display_name)
		_clear_support_selection(true)
		return

	selected_support_index = index
	selected_deploy_index = -1
	_set_selected_prep_unit(null)
	_refresh_deploy_bar()
	_refresh_targeting_preview()
	_emit_hud_update()
	print("Support armado: slot=%d carta=%s custo=%d energia=%d" % [
		index + 1,
		option.card_data.display_name,
		option.card_data.cost,
		energy_current,
	])
	print("Alvos de support prontos: %d celulas destacadas" % valid_target_count)

func _support_card_is_instant(card_data: CardData) -> bool:
	return card_data != null and card_data.support_effect_type == GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD

func _support_card_requires_cell_target(card_data: CardData) -> bool:
	return card_data != null and card_data.support_effect_type == GameEnums.SupportCardEffectType.CELL_TRAP_STUN

func _clear_support_selection(refresh_ui: bool) -> void:
	var had_selection: bool = selected_support_index >= 0
	selected_support_index = -1
	if board_grid and had_selection:
		board_grid.clear_target_highlights()
	if refresh_ui:
		_refresh_deploy_bar()
		_emit_hud_update()

func _can_deploy_option_to_coord(option: DeployOption, coord: Vector2i) -> Dictionary:
	if option.used:
		return {"ok": false, "reason": "unidade ja usada nesta rodada"}
	if not board_grid.is_coord_in_team_zone(coord, GameEnums.TeamSide.PLAYER):
		return {"ok": false, "reason": "alvo fora da zona do jogador"}
	if not board_grid.is_cell_free(coord):
		return {"ok": false, "reason": "celula alvo ocupada"}
	if _count_non_master_units(GameEnums.TeamSide.PLAYER) >= BattleConfig.MAX_FIELD_UNITS:
		return {"ok": false, "reason": "limite de unidades do jogador atingido"}
	if energy_current < option.unit_data.cost:
		return {"ok": false, "reason": "energia insuficiente"}
	return {"ok": true, "reason": ""}

func _can_enemy_deploy_option_to_coord(option: DeployOption, coord: Vector2i) -> Dictionary:
	if option.used:
		return {"ok": false, "reason": "unidade inimiga ja usada nesta rodada"}
	if not board_grid.is_coord_in_team_zone(coord, GameEnums.TeamSide.ENEMY):
		return {"ok": false, "reason": "alvo fora da zona inimiga"}
	if not board_grid.is_cell_free(coord):
		return {"ok": false, "reason": "celula alvo ocupada"}
	if _count_non_master_units(GameEnums.TeamSide.ENEMY) >= BattleConfig.MAX_FIELD_UNITS:
		return {"ok": false, "reason": "limite de unidades inimigas atingido"}
	if enemy_energy_current < option.unit_data.cost:
		return {"ok": false, "reason": "energia inimiga insuficiente"}
	return {"ok": true, "reason": ""}

func _deploy_slot_to_coord(slot_index: int, coord: Vector2i) -> bool:
	if slot_index < 0 or slot_index >= player_deploy_pool.size():
		return false

	var option: DeployOption = player_deploy_pool[slot_index]
	var deploy_check: Dictionary = _can_deploy_option_to_coord(option, coord)
	var deploy_ok: bool = bool(deploy_check.get("ok", false))
	var deploy_reason: String = str(deploy_check.get("reason", ""))

	if not deploy_ok:
		print("Deploy bloqueado: %s" % deploy_reason)
		return false

	var state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
		option.unit_data,
		GameEnums.TeamSide.PLAYER,
		coord,
		false,
		coord
	)
	if not board_grid.spawn_unit(state):
		print("Deploy bloqueado: falha ao criar unidade em %s" % coord)
		return false

	runtime_units.append(state)
	option.used = true
	energy_current -= option.unit_data.cost
	_remove_value(player_units_sold_last_round, state.get_combat_label())
	print("Home coord registered: %s -> %s" % [state.get_combat_label(), state.home_coord])

	print("Deploy concluido: %s em %s | energia_restante=%d" % [
		state.get_combat_label(),
		coord,
		energy_current,
	])
	_refresh_race_synergy_state(false)
	_refresh_targeting_preview()
	_refresh_deploy_bar()
	_emit_hud_update()
	_refresh_inspected_unit_panel()
	return true

func _deploy_enemy_slot_to_coord(slot_index: int, coord: Vector2i) -> bool:
	if slot_index < 0 or slot_index >= enemy_deploy_pool.size():
		return false

	var option: DeployOption = enemy_deploy_pool[slot_index]
	var deploy_check: Dictionary = _can_enemy_deploy_option_to_coord(option, coord)
	if not bool(deploy_check.get("ok", false)):
		return false

	var state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
		option.unit_data,
		GameEnums.TeamSide.ENEMY,
		coord,
		false,
		coord
	)
	if not board_grid.spawn_unit(state):
		return false

	runtime_units.append(state)
	option.used = true
	enemy_energy_current -= option.unit_data.cost
	print("Deploy inimigo: %s em %s | energia_inimiga_restante=%d" % [
		state.get_combat_label(),
		coord,
		enemy_energy_current,
	])
	return true

func _auto_prepare_enemy_board() -> void:
	if enemy_deploy_pool.is_empty():
		return

	var deploy_plan: Dictionary = enemy_prep_planner.build_deploy_orders(
		board_grid,
		enemy_deploy_pool,
		enemy_energy_current,
		_count_non_master_units(GameEnums.TeamSide.ENEMY),
		BattleConfig.MAX_FIELD_UNITS,
		current_round
	)
	var deploy_orders: Array[Dictionary] = deploy_plan.get("orders", [])
	var enemy_field_limit: int = int(deploy_plan.get("field_limit", BattleConfig.MAX_FIELD_UNITS))
	var enemy_energy_budget: int = int(deploy_plan.get("energy_budget", enemy_energy_current))
	if bool(deploy_plan.get("fairness_active", false)):
		print("Justica do PREP inimigo ativa: rodada=%d limite_de_campo=%d energia_efetiva=%d" % [
			current_round,
			enemy_field_limit,
			enemy_energy_budget,
		])
	for order in deploy_orders:
		_deploy_enemy_slot_to_coord(
			int(order.get("slot_index", -1)),
			order.get("coord", Vector2i(-1, -1))
		)

	print("PREP automatico do inimigo: %d deploys aplicados" % deploy_orders.size())

func _try_deploy_selected_at(coord: Vector2i) -> void:
	if selected_deploy_index < 0 or selected_deploy_index >= player_deploy_pool.size():
		return
	if _deploy_slot_to_coord(selected_deploy_index, coord):
		selected_deploy_index = -1
	_refresh_deploy_bar()
	_emit_hud_update()

func _try_use_selected_support_on_target(target: BattleUnitState) -> void:
	if selected_support_index < 0 or selected_support_index >= player_support_pool.size():
		return

	var option: SupportOption = player_support_pool[selected_support_index]
	var use_check: Dictionary = _can_use_support_option_on_target(option, target)
	if not bool(use_check.get("ok", false)):
		print("Support bloqueado: %s" % str(use_check.get("reason", "alvo invalido")))
		_refresh_targeting_preview()
		return

	energy_current -= option.card_data.cost
	option.used = true
	_apply_support_card_effect(option.card_data, target)
	print("Support usado: %s em %s | energia_restante=%d" % [
		option.card_data.display_name,
		target.get_combat_label(),
		energy_current,
	])
	selected_support_index = -1
	if board_grid:
		board_grid.clear_target_highlights()
	_refresh_deploy_bar()
	_emit_hud_update()
	_refresh_inspected_unit_panel()

func _try_use_selected_support_on_coord(coord: Vector2i) -> void:
	if selected_support_index < 0 or selected_support_index >= player_support_pool.size():
		return

	var option: SupportOption = player_support_pool[selected_support_index]
	var use_check: Dictionary = _can_use_support_option_on_coord(option, coord)
	if not bool(use_check.get("ok", false)):
		print("Support bloqueado: %s" % str(use_check.get("reason", "alvo invalido")))
		_refresh_targeting_preview()
		return

	energy_current -= option.card_data.cost
	option.used = true
	_apply_support_card_effect_on_coord(option.card_data, coord)
	print("Support usado: %s na celula %s | energia_restante=%d" % [
		option.card_data.display_name,
		coord,
		energy_current,
	])
	selected_support_index = -1
	if board_grid:
		board_grid.clear_target_highlights()
	_refresh_deploy_bar()
	_emit_hud_update()
	_refresh_inspected_unit_panel()

func _use_instant_support_card(option: SupportOption) -> bool:
	if option == null or option.card_data == null:
		return false
	if option.used:
		return false
	if energy_current < option.card_data.cost:
		return false

	energy_current -= option.card_data.cost
	option.used = true
	_apply_instant_support_card_effect(option.card_data)
	print("Support usado: %s | energia_restante=%d" % [
		option.card_data.display_name,
		energy_current,
	])
	return true

func _can_use_support_option_on_target(option: SupportOption, target: BattleUnitState) -> Dictionary:
	if current_state != GameEnums.BattleState.PREP:
		return {"ok": false, "reason": "supports so estao disponiveis no PREP"}
	if option == null or option.card_data == null:
		return {"ok": false, "reason": "support invalido"}
	if option.used:
		return {"ok": false, "reason": "support ja usado nesta rodada"}
	if energy_current < option.card_data.cost:
		return {"ok": false, "reason": "energia insuficiente"}
	if target == null or not target.can_act():
		return {"ok": false, "reason": "selecione um alvo vivo no tabuleiro"}
	if target.team_side != GameEnums.TeamSide.PLAYER:
		return {"ok": false, "reason": "o alvo deve ser uma unidade aliada"}

	match option.card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			if not target.is_master:
				return {"ok": false, "reason": "Field Aid precisa mirar no seu Mestre"}
			if player_global_life >= BattleConfig.GLOBAL_LIFE:
				return {"ok": false, "reason": "a vida global do jogador ja esta cheia"}
			return {"ok": true, "reason": ""}
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			return {"ok": true, "reason": ""}
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			return {"ok": true, "reason": ""}
		GameEnums.SupportCardEffectType.START_STEALTH:
			return {"ok": true, "reason": ""}
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			return {"ok": true, "reason": ""}
		_:
			return {"ok": false, "reason": "efeito de support nao suportado"}

func _can_use_support_option_on_coord(option: SupportOption, coord: Vector2i) -> Dictionary:
	if current_state != GameEnums.BattleState.PREP:
		return {"ok": false, "reason": "supports so estao disponiveis no PREP"}
	if option == null or option.card_data == null:
		return {"ok": false, "reason": "support invalido"}
	if option.used:
		return {"ok": false, "reason": "support ja usado nesta rodada"}
	if energy_current < option.card_data.cost:
		return {"ok": false, "reason": "energia insuficiente"}
	if not board_grid.is_valid_coord(coord):
		return {"ok": false, "reason": "selecione uma celula valida no tabuleiro"}

	match option.card_data.support_effect_type:
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			if not board_grid.is_coord_in_team_zone(coord, GameEnums.TeamSide.ENEMY):
				return {"ok": false, "reason": "Bone Prison precisa mirar no lado inimigo"}
			return {"ok": true, "reason": ""}
		_:
			return {"ok": false, "reason": "efeito de support com celula nao suportado"}

func _apply_support_card_effect(card_data: CardData, target: BattleUnitState) -> void:
	if card_data == null or target == null:
		return

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			var before: int = player_global_life
			player_global_life = mini(BattleConfig.GLOBAL_LIFE, player_global_life + card_data.global_life_heal)
			var healed_life: int = player_global_life - before
			_emit_global_life_changed(GameEnums.TeamSide.PLAYER, player_global_life)
			if target.actor:
				target.actor.on_heal()
			print("EFEITO DE SUPPORT: %s restaurou %d de vida global via %s (Vida do jogador: %d)" % [
				card_data.display_name,
				healed_life,
				target.get_combat_label(),
				player_global_life,
			])
		GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
			target.add_round_stat_bonus(
				card_data.physical_attack_bonus,
				card_data.magic_attack_bonus,
				card_data.physical_defense_bonus,
				card_data.magic_defense_bonus
			)
			if target.actor:
				target.actor.on_buff()
			print("EFEITO DE SUPPORT: %s fortaleceu %s (+%d ATQ F, +%d ATQ M)" % [
				card_data.display_name,
				target.get_combat_label(),
				card_data.physical_attack_bonus,
				card_data.magic_attack_bonus,
			])
		GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
			var magic_bonus: int = int(ceil(float(target.get_magic_attack_value()) * (card_data.magic_attack_multiplier - 1.0)))
			target.add_round_stat_bonus(0, magic_bonus, 0, 0)
			if target.actor:
				target.actor.on_buff()
			print("EFEITO DE SUPPORT: %s ampliou %s (+%d de ataque magico nesta rodada)" % [
				card_data.display_name,
				target.get_combat_label(),
				magic_bonus,
			])
		GameEnums.SupportCardEffectType.START_STEALTH:
			target.apply_stealth(maxi(1, card_data.stealth_turns))
			if target.actor:
				target.actor.on_buff()
			print("EFEITO DE SUPPORT: %s ocultou %s por %d turnos" % [
				card_data.display_name,
				target.get_combat_label(),
				card_data.stealth_turns,
			])
		GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
			target.apply_blood_pact(card_data.mana_ratio_transfer_on_death)
			if target.actor:
				target.actor.on_buff()
			print("EFEITO DE SUPPORT: %s marcou %s com Blood Pact" % [
				card_data.display_name,
				target.get_combat_label(),
			])

	_refresh_actor_state(target)
	_refresh_targeting_preview()

func _apply_support_card_effect_on_coord(card_data: CardData, coord: Vector2i) -> void:
	if card_data == null:
		return

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			bone_prison_coord = coord
			bone_prison_owner_team = GameEnums.TeamSide.PLAYER
			bone_prison_stun_turns = maxi(1, card_data.stun_turns)
			bone_prison_mana_gain_multiplier = clampf(card_data.mana_gain_multiplier, 0.0, 1.0)
			print("EFEITO DE SUPPORT: %s foi armado na celula inimiga %s" % [
				card_data.display_name,
				coord,
			])

func _apply_instant_support_card_effect(card_data: CardData) -> void:
	if card_data == null:
		return

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			pending_blinding_mist_turn = randi_range(
				maxi(1, card_data.delayed_trigger_min_turn),
				maxi(card_data.delayed_trigger_min_turn, card_data.delayed_trigger_max_turn)
			)
			pending_blinding_mist_team = GameEnums.TeamSide.PLAYER
			pending_blinding_mist_duration_turns = maxi(1, card_data.effect_duration_turns)
			pending_blinding_mist_physical_miss_chance = clampf(card_data.physical_miss_chance, 0.0, 1.0)
			print("EFEITO DE SUPPORT: %s sera ativado por volta do turno %d de batalha" % [
				card_data.display_name,
				pending_blinding_mist_turn,
			])

func _refresh_targeting_preview() -> void:
	if not board_grid:
		return
	if selected_support_index < 0 or selected_support_index >= player_support_pool.size():
		board_grid.clear_target_highlights()
		return

	var option: SupportOption = player_support_pool[selected_support_index]
	board_grid.set_target_highlights(_get_valid_support_target_coords(option.card_data))

func _get_valid_support_target_coords(card_data: CardData) -> Array[Vector2i]:
	var valid_coords: Array[Vector2i] = []
	if card_data == null:
		return valid_coords

	if card_data.support_effect_type == GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
		for y in range(BattleConfig.ENEMY_ROWS):
			for x in range(BattleConfig.BOARD_WIDTH):
				var coord := Vector2i(x, y)
				if board_grid.is_valid_coord(coord):
					valid_coords.append(coord)
		return valid_coords

	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != GameEnums.TeamSide.PLAYER:
			continue
		if not board_grid.is_valid_coord(unit_state.coord):
			continue

		match card_data.support_effect_type:
			GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
				if unit_state.is_master and player_global_life < BattleConfig.GLOBAL_LIFE:
					valid_coords.append(unit_state.coord)
			GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
				valid_coords.append(unit_state.coord)
			GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
				valid_coords.append(unit_state.coord)
			GameEnums.SupportCardEffectType.START_STEALTH:
				valid_coords.append(unit_state.coord)
			GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
				valid_coords.append(unit_state.coord)

	return valid_coords

func _can_move_unit_to_coord(unit_state: BattleUnitState, coord: Vector2i) -> Dictionary:
	if unit_state == null:
		return {"ok": false, "reason": "unidade invalida"}
	if unit_state.team_side != GameEnums.TeamSide.PLAYER:
		return {"ok": false, "reason": "nao e possivel mover unidade inimiga"}
	if not board_grid.is_coord_in_player_zone(coord):
		return {"ok": false, "reason": "alvo fora da zona do jogador"}
	if coord == unit_state.coord:
		return {"ok": false, "reason": "same_cell"}
	if not board_grid.is_cell_free(coord):
		return {"ok": false, "reason": "celula alvo ocupada"}
	return {"ok": true, "reason": ""}

func _can_sell_unit(unit_state: BattleUnitState) -> Dictionary:
	if current_state != GameEnums.BattleState.PREP:
		return {"ok": false, "reason": "venda so e permitida no PREP"}
	if unit_state == null:
		return {"ok": false, "reason": "unidade invalida"}
	if unit_state.team_side != GameEnums.TeamSide.PLAYER:
		return {"ok": false, "reason": "nao e possivel vender unidade inimiga"}
	if unit_state.is_master:
		return {"ok": false, "reason": "nao e possivel vender o mestre"}
	return {"ok": true, "reason": ""}

func _try_sell_unit(unit_state: BattleUnitState) -> void:
	var sell_check: Dictionary = _can_sell_unit(unit_state)
	var sell_ok: bool = bool(sell_check.get("ok", false))
	var sell_reason: String = str(sell_check.get("reason", ""))

	if not sell_ok:
		print("Venda bloqueada: %s" % sell_reason)
		return

	var refund: int = unit_state.unit_data.cost / 2
	energy_current += refund
	board_grid.remove_unit(unit_state, true)
	runtime_units.erase(unit_state)
	_release_pool_slot_for_unit(unit_state.unit_data.id)
	_append_unique(player_units_sold_last_round, unit_state.get_combat_label())

	if inspected_unit == unit_state:
		_clear_inspected_context()

	print("Venda concluida: %s por %d de energia | energia_agora=%d" % [
		unit_state.get_combat_label(),
		refund,
		energy_current,
	])
	_refresh_race_synergy_state(false)
	_refresh_targeting_preview()
	_refresh_deploy_bar()
	_emit_hud_update()

func _count_non_master_units(team_side: int) -> int:
	var count: int = 0
	for unit_state in runtime_units:
		if unit_state == null:
			continue
		if not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state.is_master:
			continue
		count += 1
	return count

func _count_player_non_master_units() -> int:
	return _count_non_master_units(GameEnums.TeamSide.PLAYER)

func _clear_round_limited_tokens() -> void:
	var remaining_units: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null:
			continue
		if unit_state.is_summoned_token:
			board_grid.remove_unit(unit_state, true)
			continue
		remaining_units.append(unit_state)
	runtime_units = remaining_units

func _trigger_battle_turn_effects() -> void:
	battle_turn_index += 1
	if pending_blinding_mist_turn > 0 and battle_turn_index == pending_blinding_mist_turn:
		_trigger_blinding_mist()

func _trigger_blinding_mist() -> void:
	if pending_blinding_mist_team < 0:
		return

	var affected_team: int = GameEnums.TeamSide.ENEMY if pending_blinding_mist_team == GameEnums.TeamSide.PLAYER else GameEnums.TeamSide.PLAYER
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != affected_team:
			continue
		unit_state.apply_physical_miss_chance(
			pending_blinding_mist_physical_miss_chance,
			pending_blinding_mist_duration_turns
		)
		_refresh_actor_state(unit_state)

	print("EFEITO DE CAMPO: Blinding Mist atingiu %s unidades do time %d por %d turnos" % [
		_count_living_team(affected_team),
		affected_team,
		pending_blinding_mist_duration_turns,
	])
	pending_blinding_mist_turn = -1
	pending_blinding_mist_team = -1
	pending_blinding_mist_duration_turns = 2
	pending_blinding_mist_physical_miss_chance = 0.5

func _apply_bone_prison_opening() -> void:
	if bone_prison_coord == Vector2i(-1, -1):
		return

	var trapped_unit: BattleUnitState = board_grid.get_unit_at(bone_prison_coord)
	if trapped_unit == null:
		bone_prison_coord = Vector2i(-1, -1)
		return
	if trapped_unit.team_side == bone_prison_owner_team:
		bone_prison_coord = Vector2i(-1, -1)
		return

	trapped_unit.apply_turn_skip(bone_prison_stun_turns)
	trapped_unit.apply_mana_gain_multiplier(
		bone_prison_mana_gain_multiplier,
		bone_prison_stun_turns
	)
	_refresh_actor_state(trapped_unit)
	print("EFEITO DE ARMADILHA: Bone Prison prendeu %s em %s por %d turnos" % [
		trapped_unit.get_combat_label(),
		bone_prison_coord,
		bone_prison_stun_turns,
	])
	bone_prison_coord = Vector2i(-1, -1)
	bone_prison_stun_turns = 2
	bone_prison_mana_gain_multiplier = 0.0

func _get_units_in_radius(center_coord: Vector2i, radius: int, team_filter: int = -1) -> Array[BattleUnitState]:
	var targets: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if team_filter >= 0 and unit_state.team_side != team_filter:
			continue
		if board_grid.distance_between_cells(center_coord, unit_state.coord) <= radius:
			targets.append(unit_state)
	return targets

func _find_enemy_with_highest_magic_defense(team_side: int) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side == team_side:
			continue
		if unit_state.is_stealthed():
			continue
		var defense_value: int = unit_state.get_magic_defense_value()
		if defense_value > best_value:
			best_value = defense_value
			best_target = unit_state
	return best_target

func _find_enemy_with_highest_physical_attack(team_side: int) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side == team_side:
			continue
		if unit_state.is_stealthed():
			continue
		var attack_value: int = unit_state.get_physical_attack_value()
		if attack_value > best_value:
			best_value = attack_value
			best_target = unit_state
	return best_target

func _find_ally_with_highest_magic_attack(team_side: int, exclude_unit: BattleUnitState = null) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state == exclude_unit:
			continue
		var attack_value: int = unit_state.get_magic_attack_value()
		if attack_value > best_value:
			best_value = attack_value
			best_target = unit_state
	return best_target

func _find_ally_prioritize_master(source: BattleUnitState) -> BattleUnitState:
	var best_master: BattleUnitState = null
	var best_master_distance: int = 1000000
	var best_ally: BattleUnitState = null
	var best_distance: int = 1000000

	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side != source.team_side:
			continue
		if candidate == source:
			continue
		var distance: int = board_grid.distance_between_cells(source.coord, candidate.coord)
		if candidate.is_master and distance < best_master_distance:
			best_master = candidate
			best_master_distance = distance
		if distance < best_distance:
			best_ally = candidate
			best_distance = distance

	if best_master != null:
		return best_master
	return best_ally

func _process_unit_turn(acting_unit: BattleUnitState) -> Dictionary:
	var turn_result: Dictionary = {"outcome": "stuck"}
	if acting_unit == null or not acting_unit.can_act():
		return turn_result

	_trigger_battle_turn_effects()
	if current_state != GameEnums.BattleState.BATTLE or acting_unit == null or not acting_unit.can_act():
		return turn_result

	if acting_unit.has_turn_skip():
		acting_unit.consume_skip_turn()
		print("CONTROL: %s skipped a turn" % acting_unit.get_combat_label())
		if acting_unit.can_act():
			acting_unit.advance_turn_effects()
		_refresh_actor_state(acting_unit)
		turn_result["outcome"] = "skip"
		return turn_result

	var acted: bool = false
	var target_key_for_turn: String = ""
	if _try_cast_master_skill(acting_unit):
		acted = true
		turn_result["outcome"] = "skill"
	elif _try_cast_unit_skill(acting_unit):
		acted = true
		turn_result["outcome"] = "skill"
	else:
		var target: BattleUnitState = _find_target_for_unit(acting_unit)
		if target != null:
			target_key_for_turn = _unit_runtime_key(target)
			if _is_target_in_range(acting_unit, target):
				_perform_attack(acting_unit, target)
				turn_result["outcome"] = "attack"
				acted = true
			else:
				acted = _perform_move_towards_target(acting_unit, target)
				if acted:
					turn_result["outcome"] = "move"
				else:
					var fallback_target: BattleUnitState = _find_alternate_target_for_unit(acting_unit, target)
					if fallback_target != null:
						print("UNBLOCK: %s trocou alvo de %s para %s" % [
							acting_unit.get_combat_label(),
							target.get_combat_label(),
							fallback_target.get_combat_label(),
						])
						if _is_target_in_range(acting_unit, fallback_target):
							_perform_attack(acting_unit, fallback_target)
							turn_result["outcome"] = "attack"
							acted = true
						else:
							acted = _perform_move_towards_target(acting_unit, fallback_target)
							if acted:
								turn_result["outcome"] = "move"
				if not acted:
					print("UNBLOCK: %s ficou sem passo valido em direcao a %s" % [
						acting_unit.get_combat_label(),
						target.get_combat_label(),
					])

	if not acted:
		if not target_key_for_turn.is_empty():
			acting_unit.remember_blocked_target(target_key_for_turn)
		print("TURN: %s had no valid action" % acting_unit.get_combat_label())
		acting_unit.refund_action_charge(35)
	else:
		acting_unit.clear_blocked_target()
	if acting_unit.can_act():
		acting_unit.advance_turn_effects()
	_refresh_actor_state(acting_unit)
	return turn_result

func _unit_runtime_key(unit_state: BattleUnitState) -> String:
	if unit_state == null:
		return ""
	return str(unit_state.get_instance_id())

func _resolve_move_plan_for_target(
	acting_unit: BattleUnitState,
	target_coord: Vector2i,
	target_key: String
) -> Dictionary:
	var forbidden_coords: Array[Vector2i] = []
	var bounce_coord: Vector2i = acting_unit.get_bounce_forbidden_coord(target_key)
	if board_grid.is_valid_coord(bounce_coord):
		forbidden_coords.append(bounce_coord)

	var move_plan: Dictionary = board_grid.resolve_step_towards(
		acting_unit.coord,
		target_coord,
		acting_unit.team_side,
		forbidden_coords
	)
	if not forbidden_coords.is_empty():
		move_plan["avoided_coord"] = forbidden_coords[0]
	return move_plan

func _try_cast_unit_skill(acting_unit: BattleUnitState) -> bool:
	if acting_unit == null or current_state != GameEnums.BattleState.BATTLE:
		return false
	if not acting_unit.has_unit_skill():
		return false
	if not acting_unit.is_unit_skill_ready():
		return false

	var skill_data: SkillData = acting_unit.get_skill_data()
	if skill_data == null:
		return false
	var skill_name: String = acting_unit.get_skill_name()

	match skill_data.effect_type:
		GameEnums.SkillEffectType.ALLY_HEAL:
			var heal_target: BattleUnitState = _find_most_injured_ally(acting_unit)
			if heal_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, heal_target.coord, acting_unit.get_skill_range(), heal_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			var healed: int = heal_target.heal(skill_data.heal_amount)
			if heal_target.actor and healed > 0:
				heal_target.actor.on_heal()
			print("UNIT SKILL: %s used %s on %s for %d heal (Mana %d/%d)" % [
				acting_unit.get_combat_label(),
				skill_name,
				heal_target.get_combat_label(),
				healed,
				acting_unit.current_mana,
				acting_unit.get_mana_max(),
			])
			_refresh_actor_state(heal_target)
			return healed > 0
		GameEnums.SkillEffectType.SELF_SACRIFICE_MANA_GIFT:
			var mana_target: BattleUnitState = _find_ally_prioritize_master(acting_unit)
			if mana_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, mana_target.coord, acting_unit.get_skill_range(), mana_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			var self_damage: int = maxi(1, int(round(float(acting_unit.unit_data.max_hp) * skill_data.self_health_cost_ratio)))
			acting_unit.take_damage(self_damage)
			var granted_mana: int = int(round(float(mana_target.get_mana_max()) * skill_data.ally_mana_grant_ratio))
			var mana_gained: int = mana_target.gain_mana(granted_mana)
			if mana_target.actor and mana_gained > 0:
				mana_target.actor.on_buff()
			if acting_unit.actor:
				acting_unit.actor.on_damage()
			print("UNIT SKILL: %s used %s on %s | self_damage=%d mana_granted=%d" % [
				acting_unit.get_combat_label(),
				skill_name,
				mana_target.get_combat_label(),
				self_damage,
				mana_gained,
			])
			_refresh_actor_state(mana_target)
			if acting_unit.is_dead():
				_handle_unit_death(acting_unit)
			return true
		GameEnums.SkillEffectType.TARGET_MAGIC_DEFENSE_BREAK:
			var magic_break_target: BattleUnitState = _find_enemy_with_highest_magic_defense(acting_unit.team_side)
			if magic_break_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, magic_break_target.coord, acting_unit.get_skill_range(), magic_break_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			magic_break_target.apply_magic_defense_multiplier(
				skill_data.magic_defense_multiplier,
				skill_data.duration_turns
			)
			if magic_break_target.actor:
				magic_break_target.actor.on_damage()
			print("UNIT SKILL: %s used %s on %s | MDEF x%.2f for %d turns" % [
				acting_unit.get_combat_label(),
				skill_name,
				magic_break_target.get_combat_label(),
				skill_data.magic_defense_multiplier,
				skill_data.duration_turns,
			])
			_refresh_actor_state(magic_break_target)
			return true
		GameEnums.SkillEffectType.ALLY_MAGIC_CRIT_GIFT:
			var crit_target: BattleUnitState = _find_ally_with_highest_magic_attack(acting_unit.team_side, acting_unit)
			if crit_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, crit_target.coord, acting_unit.get_skill_range(), crit_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			crit_target.apply_magic_crit_gift(maxi(1, skill_data.guaranteed_magic_crit_hits))
			if crit_target.actor:
				crit_target.actor.on_buff()
			print("UNIT SKILL: %s used %s on %s | next magic hit crits" % [
				acting_unit.get_combat_label(),
				skill_name,
				crit_target.get_combat_label(),
			])
			_refresh_actor_state(crit_target)
			return true
		GameEnums.SkillEffectType.TARGET_HEAVY_SLOW:
			var slow_target: BattleUnitState = _find_enemy_with_highest_physical_attack(acting_unit.team_side)
			if slow_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, slow_target.coord, acting_unit.get_skill_range(), slow_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			slow_target.apply_turn_skip(maxi(1, skill_data.turn_skip_count))
			if slow_target.actor:
				slow_target.actor.on_damage()
			print("UNIT SKILL: %s used %s on %s | turn skip %d" % [
				acting_unit.get_combat_label(),
				skill_name,
				slow_target.get_combat_label(),
				maxi(1, skill_data.turn_skip_count),
			])
			_refresh_actor_state(slow_target)
			return true
		GameEnums.SkillEffectType.PHYSICAL_SHIELD_REFLECT:
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			acting_unit.apply_physical_shield(
				skill_data.physical_shield_amount,
				skill_data.duration_turns,
				skill_data.reflect_damage
			)
			if acting_unit.actor:
				acting_unit.actor.on_buff()
			print("UNIT SKILL: %s used %s | shield=%d reflect=%d" % [
				acting_unit.get_combat_label(),
				skill_name,
				skill_data.physical_shield_amount,
				skill_data.reflect_damage,
			])
			return true
		GameEnums.SkillEffectType.MANA_SUPPRESS_AURA:
			var aura_targets: Array[BattleUnitState] = _get_units_in_radius(
				acting_unit.coord,
				maxi(1, skill_data.area_radius),
				GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
			)
			if aura_targets.is_empty():
				return false
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			for target in aura_targets:
				target.apply_mana_gain_multiplier(
					skill_data.mana_gain_multiplier,
					skill_data.duration_turns
				)
				if target.actor:
					target.actor.on_damage()
				_refresh_actor_state(target)
			print("UNIT SKILL: %s used %s | mana suppression on %d enemies" % [
				acting_unit.get_combat_label(),
				skill_name,
				aura_targets.size(),
			])
			return true
		GameEnums.SkillEffectType.AOE_PHYSICAL_DEFENSE_BREAK:
			return _cast_area_damage_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.HYBRID_STRIKE_MANA_SUPPRESS:
			return _cast_hybrid_mana_suppress_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.PHYSICAL_LIFESTEAL_STRIKE:
			return _cast_lifesteal_strike_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.MAGIC_AOE_SLOW:
			return _cast_magic_aoe_slow_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.SELF_EXPLOSION:
			return _cast_self_explosion_skill(acting_unit, skill_data, skill_name, false)
		GameEnums.SkillEffectType.EXECUTE_MAGIC_STRIKE:
			return _cast_execute_magic_skill(acting_unit, skill_data, skill_name)
		_:
			return false

func _find_most_injured_ally(source: BattleUnitState) -> BattleUnitState:
	var best_ally: BattleUnitState = null
	var biggest_missing_hp: int = 0

	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side != source.team_side or candidate == source:
			continue
		if candidate.unit_data == null:
			continue

		var missing_hp: int = candidate.unit_data.max_hp - candidate.current_hp
		if missing_hp > biggest_missing_hp:
			biggest_missing_hp = missing_hp
			best_ally = candidate

	return best_ally

func _move_towards_skill_target_if_needed(
	acting_unit: BattleUnitState,
	target_coord: Vector2i,
	skill_range: int,
	target: BattleUnitState = null
) -> bool:
	if acting_unit == null:
		return false
	var distance: int = board_grid.distance_between_cells(acting_unit.coord, target_coord)
	if distance <= skill_range:
		return false

	var target_key: String = _unit_runtime_key(target)
	var move_plan: Dictionary = _resolve_move_plan_for_target(acting_unit, target_coord, target_key)
	var step_coord: Vector2i = move_plan.get("coord", acting_unit.coord)
	var avoided_coord: Vector2i = move_plan.get("avoided_coord", Vector2i(-1, -1))
	if step_coord == acting_unit.coord and board_grid.is_valid_coord(avoided_coord):
		print("UNBLOCK: %s evitou retornar para %s enquanto buscava angulo de skill" % [
			acting_unit.get_combat_label(),
			avoided_coord,
		])
		return false

	var from_coord: Vector2i = acting_unit.coord
	if step_coord != acting_unit.coord and board_grid.move_unit(acting_unit, step_coord):
		var target_label: String = str(target_coord)
		if target != null:
			target_label = target.get_combat_label()
		var move_type: String = str(move_plan.get("move_type", "advance"))
		acting_unit.remember_navigation_move(target_key, move_type, from_coord, step_coord)
		if move_type == "sidestep":
			print("UNBLOCK: %s reposicionou de lado para alcancar %s" % [
				acting_unit.get_combat_label(),
				target_label,
			])
		elif move_type == "fallback":
			print("UNBLOCK: %s recuou para reabrir caminho ate %s" % [
				acting_unit.get_combat_label(),
				target_label,
			])
		else:
			print("%s moved to reach skill range for %s" % [
				acting_unit.get_combat_label(),
				target_label,
			])
		return true
	return false

func _find_alternate_target_for_unit(source: BattleUnitState, excluded_target: BattleUnitState) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_score: int = 1000000
	for include_stealthed in [false, true]:
		for candidate in runtime_units:
			if candidate == null or not candidate.can_act():
				continue
			if candidate.team_side == source.team_side:
				continue
			if candidate == excluded_target:
				continue
			if not include_stealthed and candidate.is_stealthed():
				continue

			var move_plan: Dictionary = board_grid.resolve_step_towards(source.coord, candidate.coord, source.team_side)
			var step_coord: Vector2i = move_plan.get("coord", source.coord)
			if step_coord == source.coord and not _is_target_in_range(source, candidate):
				continue

			var score: int = _score_target_for_unit(source, candidate)
			if best_target == null or score < best_score:
				best_target = candidate
				best_score = score
		if best_target != null:
			return best_target
	return null

func _find_target_for_unit(source: BattleUnitState) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_score: int = 1000000

	for include_stealthed in [false, true]:
		for candidate in runtime_units:
			if candidate == null:
				continue
			if not candidate.can_act():
				continue
			if candidate.team_side == source.team_side:
				continue
			if not include_stealthed and candidate.is_stealthed():
				continue

			var score: int = _score_target_for_unit(source, candidate)
			if best_target == null or score < best_score:
				best_target = candidate
				best_score = score
		if best_target != null:
			return best_target

	return best_target

func _score_target_for_unit(source: BattleUnitState, candidate: BattleUnitState) -> int:
	var distance: int = board_grid.distance_between_cells(source.coord, candidate.coord)
	var in_range_bonus: int = -90 if distance <= source.get_attack_range() else 0
	var routing_penalty: int = source.get_blocked_target_penalty(_unit_runtime_key(candidate))

	if source.is_tank_unit():
		return distance * 100 + candidate.current_hp * 2 + candidate.get_defense_value() * 8 + in_range_bonus + routing_penalty
	if source.is_attacker_unit():
		return candidate.get_defense_value() * 60 + candidate.current_hp * 8 + distance * 20 + in_range_bonus + routing_penalty
	if source.is_sniper_unit():
		return candidate.current_hp * 45 + candidate.get_defense_value() * 20 + distance * 12 + in_range_bonus + routing_penalty
	if source.is_support_unit():
		return distance * 100 + candidate.current_hp * 4 + routing_penalty
	return distance * 100 + candidate.current_hp * 4 + in_range_bonus + routing_penalty

func _is_target_in_range(attacker: BattleUnitState, target: BattleUnitState) -> bool:
	var distance: int = board_grid.distance_between_cells(attacker.coord, target.coord)
	return distance <= attacker.get_attack_range()

func _perform_move_towards_target(acting_unit: BattleUnitState, target: BattleUnitState) -> bool:
	var target_key: String = _unit_runtime_key(target)
	var move_plan: Dictionary = _resolve_move_plan_for_target(acting_unit, target.coord, target_key)
	var next_coord: Vector2i = move_plan.get("coord", acting_unit.coord)
	var avoided_coord: Vector2i = move_plan.get("avoided_coord", Vector2i(-1, -1))
	if next_coord == acting_unit.coord:
		if board_grid.is_valid_coord(avoided_coord):
			print("UNBLOCK: %s evitou voltar para %s e vai procurar outra rota" % [
				acting_unit.get_combat_label(),
				avoided_coord,
			])
		return false

	var from_coord: Vector2i = acting_unit.coord
	if board_grid.move_unit(acting_unit, next_coord):
		var move_type: String = str(move_plan.get("move_type", "advance"))
		acting_unit.remember_navigation_move(target_key, move_type, from_coord, next_coord)
		if move_type == "sidestep":
			print("UNBLOCK: %s contornou bloqueio e foi para %s" % [
				acting_unit.get_combat_label(),
				next_coord,
			])
		elif move_type == "fallback":
			print("UNBLOCK: %s recuou para reabrir a rota em %s" % [
				acting_unit.get_combat_label(),
				next_coord,
			])
		else:
			print("%s moved to %s" % [acting_unit.get_combat_label(), next_coord])
		return true
	return false

func _perform_attack(attacker: BattleUnitState, target: BattleUnitState) -> void:
	var attack_result: Dictionary = _calculate_attack_result(attacker, target)
	var notes: Array[String] = []
	var apply_result: Dictionary = _apply_damage_result(
		attacker,
		target,
		attack_result,
		"%s atacou %s" % [attacker.get_combat_label(), target.get_combat_label()],
		notes,
		true,
		true,
		true
	)
	var target_died: bool = bool(apply_result.get("target_died", false))
	var lifesteal: int = attacker.get_undead_lifesteal(target_died)
	if lifesteal > 0:
		var healed: int = attacker.heal(lifesteal)
		if healed > 0:
			print("UNDEAD sustain: %s healed %d" % [attacker.get_combat_label(), healed])
			if attacker.actor:
				attacker.actor.on_heal()
			_refresh_actor_state(attacker)

func _calculate_attack_result(attacker: BattleUnitState, target: BattleUnitState) -> Dictionary:
	return _calculate_damage_result(
		attacker,
		target,
		attacker.get_physical_attack_value(),
		attacker.get_magic_attack_value(),
		true,
		false,
		false
	)

func _calculate_damage_result(
	attacker: BattleUnitState,
	target: BattleUnitState,
	raw_physical: int,
	raw_magic: int,
	allow_physical_miss: bool = true,
	force_critical: bool = false,
	force_magic_critical: bool = false
) -> Dictionary:
	var physical_power: int = maxi(0, raw_physical)
	var magic_power: int = maxi(0, raw_magic)
	var critical: bool = force_critical
	if attacker != null and not force_critical:
		critical = randf() <= attacker.get_crit_chance()

	var magic_gift_used: bool = false
	if attacker != null and magic_power > 0 and attacker.has_magic_crit_gift():
		magic_gift_used = attacker.consume_magic_crit_gift()

	var physical_critical: bool = critical
	var magic_critical: bool = critical or force_magic_critical or magic_gift_used
	var physical_multiplier: float = 1.65 if physical_critical else 1.0
	var magic_multiplier: float = 1.65 if magic_critical else 1.0
	var adjusted_physical: int = int(round(float(physical_power) * physical_multiplier))
	var adjusted_magic: int = int(round(float(magic_power) * magic_multiplier))
	var physical_missed: bool = false
	if allow_physical_miss and attacker != null and adjusted_physical > 0:
		if randf() <= attacker.get_physical_miss_chance():
			adjusted_physical = 0
			physical_missed = true

	var final_physical: int = maxi(0, adjusted_physical - target.get_physical_defense_value())
	var absorbed_by_shield: int = 0
	if final_physical > 0:
		var shield_result: Dictionary = target.absorb_physical_damage(final_physical)
		absorbed_by_shield = int(shield_result.get("absorbed", 0))
		final_physical = int(shield_result.get("remaining", 0))
	var final_magic: int = maxi(0, adjusted_magic - target.get_magic_defense_value())
	var chip_damage_applied: bool = false
	if final_physical + final_magic <= 0:
		if adjusted_magic > 0:
			final_magic = MIN_COMBAT_CHIP_DAMAGE
			chip_damage_applied = true
		elif adjusted_physical > 0 and not physical_missed and absorbed_by_shield <= 0:
			final_physical = MIN_COMBAT_CHIP_DAMAGE
			chip_damage_applied = true
	var total_damage: int = final_physical + final_magic

	return {
		"damage": total_damage,
		"physical_damage": final_physical,
		"magic_damage": final_magic,
		"critical": critical,
		"magic_critical_only": magic_critical and not physical_critical,
		"magic_gift_used": magic_gift_used,
		"physical_missed": physical_missed,
		"absorbed_by_shield": absorbed_by_shield,
		"tank_bonus": target.get_class_physical_defense_bonus(),
		"chip_damage_applied": chip_damage_applied,
	}

func _apply_damage_result(
	attacker: BattleUnitState,
	target: BattleUnitState,
	damage_result: Dictionary,
	action_text: String,
	extra_notes: Array[String] = [],
	grant_attack_mana: bool = false,
	grant_hit_mana: bool = true,
	allow_reflect: bool = false
) -> Dictionary:
	var damage: int = int(damage_result.get("damage", 0))
	var physical_damage: int = int(damage_result.get("physical_damage", 0))
	var magic_damage: int = int(damage_result.get("magic_damage", 0))
	var critical: bool = bool(damage_result.get("critical", false))
	var magic_critical_only: bool = bool(damage_result.get("magic_critical_only", false))
	var magic_gift_used: bool = bool(damage_result.get("magic_gift_used", false))
	var physical_missed: bool = bool(damage_result.get("physical_missed", false))
	var absorbed_by_shield: int = int(damage_result.get("absorbed_by_shield", 0))
	var tank_bonus: int = int(damage_result.get("tank_bonus", 0))
	var chip_damage_applied: bool = bool(damage_result.get("chip_damage_applied", false))

	var notes: Array[String] = []
	for note in extra_notes:
		notes.append(note)
	if critical:
		notes.append("CRITICO")
	elif magic_critical_only:
		notes.append("CRITICO MAGICO")
	if magic_gift_used:
		notes.append("Dom do Oraculo")
	if physical_missed:
		notes.append("FALHA FISICA")
	if absorbed_by_shield > 0:
		notes.append("Escudo -%d" % absorbed_by_shield)
	if tank_bonus > 0 and target.is_tank_unit() and physical_damage > 0:
		notes.append("Guarda tanque")
	if chip_damage_applied:
		notes.append("Desgaste minimo")

	target.take_damage(damage)
	if target.actor:
		target.actor.on_damage()

	var combat_log: String = "%s causou %d de dano [F:%d M:%d] (PV: %d)" % [
		action_text,
		damage,
		physical_damage,
		magic_damage,
		target.current_hp,
	]
	if not notes.is_empty():
		combat_log += " | " + _join_strings(notes, ", ")
	print(combat_log)

	var reflected_damage: int = 0
	if allow_reflect and attacker != null and attacker.can_act():
		var is_melee: bool = board_grid.distance_between_cells(attacker.coord, target.coord) <= 1
		if is_melee:
			reflected_damage = target.get_melee_reflect_damage()
			if reflected_damage > 0:
				attacker.take_damage(reflected_damage)
				if attacker.actor:
					attacker.actor.on_damage()
				print("REFLEXO: %s sofreu %d de dano refletido de %s" % [
					attacker.get_combat_label(),
					reflected_damage,
					target.get_combat_label(),
				])
				if attacker.is_dead():
					_handle_unit_death(attacker)

	if grant_attack_mana and attacker != null and attacker.can_act():
		var gained_attack: int = attacker.gain_mana(attacker.get_mana_gain_on_attack())
		if gained_attack > 0:
			_log_mana_gain(attacker, gained_attack, "attack")

	if grant_hit_mana and target != null and target.unit_data != null:
		var gained_hit: int = target.gain_mana(target.get_mana_gain_on_hit())
		if gained_hit > 0:
			_log_mana_gain(target, gained_hit, "hit")

	var target_died: bool = target.is_dead()
	if target_died:
		_handle_unit_death(target)

	_refresh_actor_state(attacker)
	_refresh_actor_state(target)
	return {
		"target_died": target_died,
		"damage": damage,
		"reflected_damage": reflected_damage,
	}

func _apply_post_attack_mana(attacker: BattleUnitState, target: BattleUnitState) -> void:
	var gained_attack: int = attacker.gain_mana(attacker.get_mana_gain_on_attack())
	if gained_attack > 0:
		_log_mana_gain(attacker, gained_attack, "attack")

	var gained_hit: int = target.gain_mana(target.get_mana_gain_on_hit())
	if gained_hit > 0:
		_log_mana_gain(target, gained_hit, "hit")

func _log_mana_gain(unit_state: BattleUnitState, gained: int, reason: String) -> void:
	if unit_state == null or gained <= 0:
		return

	var reason_label: String = "ataque" if reason == "attack" else "dano"
	if unit_state.unit_data != null and unit_state.unit_data.race == GameEnums.Race.FAIRY:
		print("Fluxo de fada: %s +%d mana (%s) -> %d/%d" % [
			unit_state.get_combat_label(),
			gained,
			reason_label,
			unit_state.current_mana,
			unit_state.get_mana_max(),
		])
	elif unit_state.is_master or unit_state.current_mana >= unit_state.get_mana_max():
		print("Mana: %s +%d (%s) -> %d/%d" % [
			unit_state.get_combat_label(),
			gained,
			reason_label,
			unit_state.current_mana,
			unit_state.get_mana_max(),
		])

func _try_cast_master_skill(caster: BattleUnitState) -> bool:
	if caster == null:
		return false
	if current_state != GameEnums.BattleState.BATTLE:
		return false
	if not caster.is_master_skill_ready():
		return false

	if caster.has_master_skill():
		var master_skill: SkillData = caster.get_master_skill_data()
		if master_skill != null and master_skill.effect_type == GameEnums.SkillEffectType.SUMMON_SKELETONS:
			var first_spawn_coord: Vector2i = _resolve_necromancer_summon_coord(caster)
			if not board_grid.is_valid_coord(first_spawn_coord):
				return false
			if not caster.spend_mana(caster.get_mana_max()):
				return false
			if caster.actor:
				caster.actor.on_skill_cast()
			var summon_count: int = _spawn_necromancer_skeletons(caster, master_skill)
			if summon_count <= 0:
				return false
			print("MASTER SKILL: %s used %s and summoned %d Skeletons" % [
				caster.get_combat_label(),
				caster.get_master_skill_name(),
				summon_count,
			])
			_refresh_actor_state(caster)
			return true

	var primary_target: BattleUnitState = _find_target_for_unit(caster)
	if primary_target == null:
		return false

	var mana_cost: int = caster.get_mana_max()
	if not caster.spend_mana(mana_cost):
		return false

	if caster.actor:
		caster.actor.on_skill_cast()

	var impacted_targets: Array[BattleUnitState] = [primary_target]
	for coord in board_grid.get_adjacent_coords(primary_target.coord):
		var adjacent_unit: BattleUnitState = board_grid.get_unit_at(coord)
		if adjacent_unit == null:
			continue
		if not adjacent_unit.can_act():
			continue
		if adjacent_unit.team_side == caster.team_side:
			continue
		if impacted_targets.has(adjacent_unit):
			continue
		impacted_targets.append(adjacent_unit)

	print("MASTER SKILL: %s used Arc Burst (%d targets)" % [
		caster.get_combat_label(),
		impacted_targets.size(),
	])

	for target in impacted_targets:
		if target == null or not target.can_act():
			continue

		target.take_damage(MASTER_SKILL_DAMAGE)
		if target.actor:
			target.actor.on_damage()

		print("  -> %s took %d skill damage (HP: %d)" % [
			target.get_combat_label(),
			MASTER_SKILL_DAMAGE,
			target.current_hp,
		])

		var gained_hit: int = target.gain_mana(target.get_mana_gain_on_hit())
		if gained_hit > 0:
			_log_mana_gain(target, gained_hit, "master_skill_hit")

		if target.is_dead():
			_handle_unit_death(target)
		_refresh_actor_state(target)

	_refresh_actor_state(caster)
	return true

func _handle_unit_death(target: BattleUnitState) -> void:
	if target == null:
		return

	_trigger_bone_kamikaze_death_skill(target)
	_trigger_soul_harvest_on_death(target)
	_resolve_blood_pact_on_death(target)

	if inspected_unit == target:
		_clear_inspected_context()

	var request: RespawnRequest = _build_respawn_request_for_unit(target)
	if request != null:
		_enqueue_respawn_request(request)
		print("Respawn queued: %s home=%s" % [target.get_combat_label(), request.home_coord])

	if target.is_master:
		print("MASTER DOWN: %s queued for next PREP" % target.get_combat_label())
	else:
		print("%s died and was queued for next PREP" % target.get_combat_label())

	board_grid.remove_unit(target)
	_refresh_race_synergy_state(true)

func _find_team_master(team_side: int) -> BattleUnitState:
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side == team_side and unit_state.is_master:
			return unit_state
	return null

func _cast_area_damage_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var primary_target: BattleUnitState = _find_target_for_unit(acting_unit)
	if primary_target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, primary_target.coord, acting_unit.get_skill_range(), primary_target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()

	var impacted_targets: Array[BattleUnitState] = _get_units_in_radius(
		primary_target.coord,
		maxi(0, skill_data.area_radius),
		GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	)
	for target in impacted_targets:
		var result: Dictionary = _calculate_damage_result(
			acting_unit,
			target,
			int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
			int(round(float(acting_unit.get_magic_attack_value()) * skill_data.magic_power_multiplier)),
			true,
			false,
			false
		)
		target.apply_physical_defense_multiplier(
			skill_data.physical_defense_multiplier,
			skill_data.duration_turns
		)
		var notes: Array[String] = ["PDEF x%.2f" % skill_data.physical_defense_multiplier]
		_apply_damage_result(
			acting_unit,
			target,
			result,
			"%s used %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
			notes,
			false,
			true,
			false
		)
	return not impacted_targets.is_empty()

func _cast_hybrid_mana_suppress_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var target: BattleUnitState = _find_target_for_unit(acting_unit)
	if target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, target.coord, acting_unit.get_skill_range(), target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()

	target.apply_mana_gain_multiplier(skill_data.mana_gain_multiplier, skill_data.duration_turns)
	var result: Dictionary = _calculate_damage_result(
		acting_unit,
		target,
		int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)),
		int(round(float(acting_unit.get_magic_attack_value()) * skill_data.magic_power_multiplier)),
		true,
		false,
		false
	)
	var notes: Array[String] = ["Mana x%.2f" % skill_data.mana_gain_multiplier]
	_apply_damage_result(
		acting_unit,
		target,
		result,
		"%s used %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
		notes,
		false,
		true,
		false
	)
	return true

func _cast_lifesteal_strike_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var target: BattleUnitState = _find_target_for_unit(acting_unit)
	if target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, target.coord, acting_unit.get_skill_range(), target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()

	var result: Dictionary = _calculate_damage_result(
		acting_unit,
		target,
		int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
		0,
		true,
		false,
		false
	)
	var apply_result: Dictionary = _apply_damage_result(
		acting_unit,
		target,
		result,
		"%s used %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
		[],
		false,
		true,
		true
	)
	var healed: int = acting_unit.heal(int(round(float(int(apply_result.get("damage", 0))) * skill_data.damage_heal_ratio)))
	if healed > 0:
		if acting_unit.actor:
			acting_unit.actor.on_heal()
		print("UNIT SKILL: %s siphoned %d HP from %s" % [
			acting_unit.get_combat_label(),
			healed,
			target.get_combat_label(),
		])
		_refresh_actor_state(acting_unit)
	return true

func _cast_magic_aoe_slow_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var primary_target: BattleUnitState = _find_target_for_unit(acting_unit)
	if primary_target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, primary_target.coord, acting_unit.get_skill_range(), primary_target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()

	var impacted_targets: Array[BattleUnitState] = _get_units_in_radius(
		primary_target.coord,
		maxi(0, skill_data.area_radius),
		GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	)
	for target in impacted_targets:
		target.apply_turn_skip(maxi(0, skill_data.turn_skip_count))
		var result: Dictionary = _calculate_damage_result(
			acting_unit,
			target,
			0,
			int(round(float(acting_unit.get_magic_attack_value()) * skill_data.magic_power_multiplier)) + skill_data.damage_amount,
			false,
			false,
			false
		)
		var notes: Array[String] = []
		if skill_data.turn_skip_count > 0:
			notes.append("Slow skip %d" % skill_data.turn_skip_count)
		_apply_damage_result(
			acting_unit,
			target,
			result,
			"%s used %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
			notes,
			false,
			true,
			false
		)
	return not impacted_targets.is_empty()

func _cast_self_explosion_skill(
	acting_unit: BattleUnitState,
	skill_data: SkillData,
	skill_name: String,
	triggered_on_death: bool
) -> bool:
	if acting_unit == null:
		return false
	if not triggered_on_death:
		if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
			return false
		if acting_unit.actor:
			acting_unit.actor.on_skill_cast()

	var impacted_targets: Array[BattleUnitState] = _get_units_in_radius(
		acting_unit.coord,
		maxi(0, skill_data.area_radius),
		GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	)
	for target in impacted_targets:
		var result: Dictionary = _calculate_damage_result(
			acting_unit,
			target,
			0,
			int(round(float(acting_unit.get_magic_attack_value()) * skill_data.magic_power_multiplier)) + skill_data.damage_amount,
			false,
			false,
			false
		)
		_apply_damage_result(
			acting_unit,
			target,
			result,
			"%s triggered %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
			["Blast"],
			false,
			true,
			false
		)

	if not triggered_on_death and acting_unit.can_act():
		acting_unit.death_skill_consumed = true
		acting_unit.take_damage(acting_unit.current_hp)
		_handle_unit_death(acting_unit)
	return true

func _cast_execute_magic_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var target: BattleUnitState = _find_target_for_unit(acting_unit)
	if target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, target.coord, acting_unit.get_skill_range(), target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()

	var force_execution_critical: bool = false
	if target.unit_data != null and target.unit_data.max_hp > 0:
		force_execution_critical = float(target.current_hp) / float(target.unit_data.max_hp) <= 0.30

	var result: Dictionary = _calculate_damage_result(
		acting_unit,
		target,
		int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
		int(round(float(acting_unit.get_magic_attack_value()) * skill_data.magic_power_multiplier)),
		false,
		force_execution_critical,
		false
	)
	var notes: Array[String] = []
	if force_execution_critical:
		notes.append("Execution")
	_apply_damage_result(
		acting_unit,
		target,
		result,
		"%s used %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
		notes,
		false,
		true,
		false
	)
	return true

func _spawn_necromancer_skeletons(caster: BattleUnitState, skill_data: SkillData) -> int:
	if skill_data == null or skill_data.summon_unit_path.is_empty():
		return 0
	var template_unit_data: UnitData = _load_unit_data(skill_data.summon_unit_path)
	if template_unit_data == null:
		return 0

	var summon_count: int = maxi(1, skill_data.summon_count)
	var summon_ratio: float = maxf(0.05, skill_data.summon_stat_ratio)
	var total_spawned: int = 0
	for _i in range(summon_count):
		var spawn_coord: Vector2i = _resolve_necromancer_summon_coord(caster)
		if not board_grid.is_valid_coord(spawn_coord):
			break
		var summon_data: UnitData = template_unit_data.duplicate(true) as UnitData
		summon_data.max_hp = maxi(1, int(round(float(caster.unit_data.max_hp) * summon_ratio)))
		summon_data.physical_attack = maxi(1, int(round(float(caster.get_physical_attack_value()) * summon_ratio)))
		summon_data.magic_attack = maxi(0, int(round(float(caster.get_magic_attack_value()) * summon_ratio)))
		summon_data.physical_defense = maxi(0, int(round(float(caster.get_physical_defense_value()) * summon_ratio)))
		summon_data.magic_defense = maxi(0, int(round(float(caster.get_magic_defense_value()) * summon_ratio)))
		summon_data.skill_data = null
		summon_data.master_skill_data = null

		var summon_state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
			summon_data,
			caster.team_side,
			spawn_coord,
			false,
			spawn_coord
		)
		summon_state.mark_as_summoned_token(caster.unit_data.id)
		if not board_grid.spawn_unit(summon_state):
			continue
		runtime_units.append(summon_state)
		total_spawned += 1
		print("SUMMON: %s spawned Skeleton at %s" % [
			caster.get_combat_label(),
			spawn_coord,
		])

	if total_spawned > 0:
		_refresh_race_synergy_state(true)
	return total_spawned

func _resolve_necromancer_summon_coord(caster: BattleUnitState) -> Vector2i:
	if caster == null or board_grid == null or not board_grid.is_valid_coord(caster.coord):
		return Vector2i(-1, -1)

	var adjacent_coord: Vector2i = _find_free_adjacent_coord_near_caster(caster.coord, caster.team_side)
	if board_grid.is_valid_coord(adjacent_coord):
		return adjacent_coord

	var nearby_coord: Vector2i = _find_free_coord_near_origin(caster.coord, caster.team_side, SUMMON_NEARBY_RADIUS)
	if board_grid.is_valid_coord(nearby_coord):
		return nearby_coord

	var broad_fallback: Vector2i = _find_nearest_free_coord_anywhere(caster.coord, caster.team_side)
	if board_grid.is_valid_coord(broad_fallback):
		print("SUMMON fallback: sem espaco proximo ao Necromante em %s, usando celula livre mais proxima %s" % [
			caster.coord,
			broad_fallback,
		])
		return broad_fallback

	var final_fallback: Vector2i = _find_first_free_coord_in_zone(caster.team_side)
	if board_grid.is_valid_coord(final_fallback):
		print("SUMMON fallback: sem espaco perto do Necromante nem ao redor imediato, usando fallback de zona %s" % final_fallback)
	return final_fallback

func _find_free_adjacent_coord_near_caster(origin_coord: Vector2i, team_side: int) -> Vector2i:
	for coord in _get_prioritized_adjacent_coords(origin_coord, team_side):
		if board_grid.is_valid_coord(coord) and board_grid.is_cell_free(coord):
			return coord
	return Vector2i(-1, -1)

func _get_prioritized_adjacent_coords(origin_coord: Vector2i, team_side: int) -> Array[Vector2i]:
	var forward_step: int = -1 if team_side == GameEnums.TeamSide.PLAYER else 1
	var candidates: Array[Vector2i] = [
		Vector2i(origin_coord.x, origin_coord.y + forward_step),
		Vector2i(origin_coord.x - 1, origin_coord.y),
		Vector2i(origin_coord.x + 1, origin_coord.y),
		Vector2i(origin_coord.x, origin_coord.y - forward_step),
	]
	var valid_candidates: Array[Vector2i] = []
	for coord in candidates:
		if board_grid.is_valid_coord(coord):
			valid_candidates.append(coord)
	return valid_candidates

func _find_free_coord_near_origin(origin_coord: Vector2i, team_side: int, max_radius: int) -> Vector2i:
	var best_coord: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1000000
	for y in range(BattleConfig.BOARD_HEIGHT):
		for x in range(BattleConfig.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			if coord == origin_coord:
				continue
			if not board_grid.is_cell_free(coord):
				continue

			var distance: int = board_grid.distance_between_cells(coord, origin_coord)
			if distance <= 1 or distance > max_radius:
				continue

			var score: int = _score_necromancer_summon_coord(coord, origin_coord, team_side)
			if score < best_score:
				best_score = score
				best_coord = coord
	return best_coord

func _find_nearest_free_coord_anywhere(origin_coord: Vector2i, team_side: int) -> Vector2i:
	var best_coord: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1000000
	for y in range(BattleConfig.BOARD_HEIGHT):
		for x in range(BattleConfig.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			if coord == origin_coord:
				continue
			if not board_grid.is_cell_free(coord):
				continue

			var score: int = _score_necromancer_summon_coord(coord, origin_coord, team_side)
			if score < best_score:
				best_score = score
				best_coord = coord
	return best_coord

func _score_necromancer_summon_coord(coord: Vector2i, origin_coord: Vector2i, team_side: int) -> int:
	var distance: int = board_grid.distance_between_cells(coord, origin_coord)
	var forward_progress: int = origin_coord.y - coord.y if team_side == GameEnums.TeamSide.PLAYER else coord.y - origin_coord.y
	var backward_progress: int = coord.y - origin_coord.y if team_side == GameEnums.TeamSide.PLAYER else origin_coord.y - coord.y
	var forward_delta: int = maxi(0, forward_progress)
	var backward_delta: int = maxi(0, backward_progress)
	var horizontal_delta: int = abs(coord.x - origin_coord.x)
	return distance * 100 + backward_delta * 12 + horizontal_delta * 4 - forward_delta

func _trigger_bone_kamikaze_death_skill(target: BattleUnitState) -> void:
	if target == null or target.death_skill_consumed:
		return
	if not necromancer_deck_rules.is_bone_kamikaze(target):
		return
	var skill_data: SkillData = target.get_skill_data()
	if skill_data == null or skill_data.effect_type != GameEnums.SkillEffectType.SELF_EXPLOSION:
		return
	target.death_skill_consumed = true
	_cast_self_explosion_skill(target, skill_data, target.get_skill_name(), true)

func _trigger_soul_harvest_on_death(dead_unit: BattleUnitState) -> void:
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if not necromancer_deck_rules.is_necromancer_master(unit_state):
			continue
		var mana_gain: int = 10
		if dead_unit.team_side == unit_state.team_side:
			mana_gain = 12
		var gained: int = unit_state.gain_mana(mana_gain)
		if gained > 0:
			print("SOUL HARVEST: %s gained +%d mana from %s" % [
				unit_state.get_combat_label(),
				gained,
				dead_unit.get_combat_label(),
			])
			_refresh_actor_state(unit_state)

func _resolve_blood_pact_on_death(dead_unit: BattleUnitState) -> void:
	if dead_unit == null or dead_unit.death_mana_ratio_to_master <= 0.0:
		return
	var master: BattleUnitState = _find_team_master(dead_unit.team_side)
	if master == null or not master.can_act():
		return
	var mana_gain: int = int(round(float(master.get_mana_max()) * dead_unit.death_mana_ratio_to_master))
	var gained: int = master.gain_mana(mana_gain)
	if gained > 0:
		print("BLOOD PACT: %s gained +%d mana from %s" % [
			master.get_combat_label(),
			gained,
			dead_unit.get_combat_label(),
		])
		_refresh_actor_state(master)

func _build_respawn_request_for_unit(unit_state: BattleUnitState) -> RespawnRequest:
	if unit_state == null or unit_state.unit_data == null:
		return null
	if unit_state.is_summoned_token:
		return null

	var unit_path: String = _get_unit_path_by_id(unit_state.unit_data.id, unit_state.team_side)
	if unit_path.is_empty():
		return null

	return RespawnRequest.new(
		unit_path,
		unit_state.unit_data.id,
		unit_state.team_side,
		unit_state.home_coord,
		unit_state.is_master
	)

func _enqueue_respawn_request(request: RespawnRequest) -> void:
	if request == null:
		return
	if _has_pending_respawn(request.unit_id, request.team_side):
		return

	if request.team_side == GameEnums.TeamSide.PLAYER:
		pending_player_respawns.append(request)
	else:
		pending_enemy_respawns.append(request)

func _has_pending_respawn(unit_id: String, team_side: int) -> bool:
	var queue: Array[RespawnRequest] = pending_player_respawns if team_side == GameEnums.TeamSide.PLAYER else pending_enemy_respawns
	for request in queue:
		if request.unit_id == unit_id:
			return true
	return false

func _get_unit_path_by_id(unit_id: String, team_side: int) -> String:
	var registry: Dictionary = player_unit_path_registry if team_side == GameEnums.TeamSide.PLAYER else enemy_unit_path_registry
	if registry.has(unit_id):
		return str(registry[unit_id])
	return ""

func _get_display_name_for_path(unit_path: String) -> String:
	var unit_data: UnitData = _load_unit_data(unit_path)
	if unit_data != null:
		return unit_data.display_name
	return unit_path

func _refresh_actor_state(unit_state: BattleUnitState) -> void:
	if unit_state != null and unit_state.actor != null:
		unit_state.actor.refresh_from_state()
		if battle_hud != null and battle_hud.is_info_panel_open():
			unit_state.actor.set_overlay_suppressed(true)
	_refresh_inspected_unit_panel()

func _clear_inspected_context() -> void:
	inspected_unit = null
	inspected_deploy_index = -1
	inspected_support_index = -1
	observed_player_id = ""
	if board_grid:
		board_grid.clear_selection()
	if battle_hud:
		battle_hud.clear_unit_info()
	_sync_world_overlay_focus()

func _commit_player_prep_formation() -> void:
	var committed_units: Array[String] = []
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != GameEnums.TeamSide.PLAYER:
			continue
		if not board_grid.is_valid_coord(unit_state.coord):
			continue
		if board_grid.get_unit_at(unit_state.coord) != unit_state:
			continue

		if unit_state.home_coord != unit_state.coord:
			committed_units.append("%s %s->%s" % [
				unit_state.get_display_name(),
				unit_state.home_coord,
				unit_state.coord,
			])
		unit_state.home_coord = unit_state.coord

	if committed_units.is_empty():
		print("PREP formation locked: %d player units anchored" % _count_living_team(GameEnums.TeamSide.PLAYER))
	else:
		print("PREP formation locked: %s" % _join_strings(committed_units))

func _refresh_inspected_unit_panel() -> void:
	if not battle_hud:
		return

	if inspected_unit != null:
		if inspected_unit.is_dead() and inspected_unit.actor == null:
			inspected_unit = null
		else:
			battle_hud.update_unit_info(inspected_unit)
			_sync_world_overlay_focus()
			return

	if inspected_deploy_index >= 0 and inspected_deploy_index < player_deploy_pool.size():
		var option: DeployOption = player_deploy_pool[inspected_deploy_index]
		var preview_state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
			option.unit_data,
			option.team_side,
			option.home_coord,
			option.is_master,
			option.home_coord
		)
		battle_hud.update_unit_info(preview_state)
		_sync_world_overlay_focus()
		return

	if inspected_support_index >= 0 and inspected_support_index < player_support_pool.size():
		var support_option: SupportOption = player_support_pool[inspected_support_index]
		battle_hud.update_card_info(support_option.card_data)
		_sync_world_overlay_focus()
		return

	inspected_deploy_index = -1
	inspected_support_index = -1
	if not observed_player_id.is_empty():
		var observed_snapshot: Dictionary = lobby_manager.get_board_snapshot(observed_player_id)
		if not observed_snapshot.is_empty():
			battle_hud.update_observed_board(observed_snapshot)
			_sync_world_overlay_focus()
			return
	battle_hud.clear_unit_info()
	_sync_world_overlay_focus()

func _sync_world_overlay_focus() -> void:
	var suppress_overlays: bool = battle_hud != null and battle_hud.is_info_panel_open()
	for unit_state in runtime_units:
		if unit_state == null or unit_state.actor == null:
			continue
		unit_state.actor.set_overlay_suppressed(suppress_overlays)

func _on_board_unit_right_clicked(unit_state: BattleUnitState) -> void:
	observed_player_id = ""
	inspected_unit = unit_state
	inspected_deploy_index = -1
	inspected_support_index = -1
	_refresh_inspected_unit_panel()

func _on_board_empty_right_clicked() -> void:
	_clear_inspected_context()

func _on_player_sidebar_entry_pressed(player_id: String) -> void:
	if player_id.is_empty() or player_id == LOCAL_PLAYER_ID:
		_clear_observed_board_preview()
		return

	if observed_player_id == player_id:
		_clear_observed_board_preview()
		return

	var observed_snapshot: Dictionary = lobby_manager.get_board_snapshot(player_id)
	if observed_snapshot.is_empty():
		lobby_manager.build_remote_round_snapshots(current_round, [LOCAL_PLAYER_ID])
		observed_snapshot = lobby_manager.get_board_snapshot(player_id)
		if observed_snapshot.is_empty():
			print("OBSERVE: snapshot indisponivel para %s" % player_id)
			return

	observed_player_id = player_id
	inspected_unit = null
	inspected_deploy_index = -1
	inspected_support_index = -1
	if battle_hud:
		battle_hud.update_observed_board(observed_snapshot)
	_sync_world_overlay_focus()
	_emit_hud_update()
	print("OBSERVE: visualizando tabuleiro salvo de %s" % str(observed_snapshot.get("player_name", player_id)))

func _on_return_to_local_board_pressed() -> void:
	_clear_observed_board_preview()

func _clear_observed_board_preview() -> void:
	if observed_player_id.is_empty():
		return
	observed_player_id = ""
	if battle_hud:
		battle_hud.clear_unit_info()
	_sync_world_overlay_focus()
	_emit_hud_update()

func _append_unique(target_array: Array[String], value: String) -> void:
	if not target_array.has(value):
		target_array.append(value)

func _remove_value(target_array: Array[String], value: String) -> void:
	var value_index: int = target_array.find(value)
	if value_index >= 0:
		target_array.remove_at(value_index)

func _join_strings(values: Array[String], separator: String = ", ") -> String:
	var result: String = ""
	for value in values:
		if result.is_empty():
			result = value
		else:
			result += separator + value
	return result

func _count_living_team(team_side: int) -> int:
	var count: int = 0
	if team_side < 0:
		return 0

	for unit_state in runtime_units:
		if unit_state != null and unit_state.can_act() and unit_state.team_side == team_side:
			count += 1
	return count

func _has_living_team(team_side: int) -> bool:
	return _count_living_team(team_side) > 0

func _is_combat_finished() -> bool:
	var player_alive: bool = _has_living_team(GameEnums.TeamSide.PLAYER)
	var enemy_alive: bool = _has_living_team(GameEnums.TeamSide.ENEMY)
	return not player_alive or not enemy_alive

func _get_winner_team() -> int:
	var player_alive: bool = _has_living_team(GameEnums.TeamSide.PLAYER)
	var enemy_alive: bool = _has_living_team(GameEnums.TeamSide.ENEMY)

	if player_alive and not enemy_alive:
		return GameEnums.TeamSide.PLAYER
	if enemy_alive and not player_alive:
		return GameEnums.TeamSide.ENEMY
	return -1

func _is_match_finished() -> bool:
	var local_player: MatchPlayerState = lobby_manager.get_player(LOCAL_PLAYER_ID)
	if local_player != null and local_player.current_life <= 0:
		return true

	for player_id in lobby_manager.get_player_ids():
		if player_id == LOCAL_PLAYER_ID:
			continue
		var player_state: MatchPlayerState = lobby_manager.get_player(player_id)
		if player_state != null and player_state.current_life > 0:
			return false
	return true

func _get_match_winner_label() -> String:
	var local_player: MatchPlayerState = lobby_manager.get_player(LOCAL_PLAYER_ID)
	if local_player != null and local_player.current_life <= 0:
		return "LOBBY"

	for player_id in lobby_manager.get_player_ids():
		if player_id == LOCAL_PLAYER_ID:
			continue
		var player_state: MatchPlayerState = lobby_manager.get_player(player_id)
		if player_state != null and player_state.current_life > 0:
			return "NONE"

	if player_global_life > 0:
		return "PLAYER"
	return "NONE"

func _set_selected_prep_unit(new_selection: BattleUnitState) -> void:
	if selected_prep_unit != null and selected_prep_unit.actor != null:
		selected_prep_unit.actor.set_selected(false)

	selected_prep_unit = new_selection

	if selected_prep_unit != null and selected_prep_unit.actor != null:
		selected_prep_unit.actor.set_selected(true)
