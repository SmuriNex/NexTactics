extends Node
class_name BattleManager

signal hud_update_requested(
	round_number: int,
	player_life: int,
	gold_value: int,
	last_income_total: int,
	state_name: String,
	opponent_name: String
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

const ACTION_DELAY_ATTACK_SECONDS := BattleConfig.ACTION_DELAY_ATTACK_SECONDS
const ACTION_DELAY_SKILL_SECONDS := BattleConfig.ACTION_DELAY_SKILL_SECONDS
const ACTION_DELAY_MOVE_SECONDS := BattleConfig.ACTION_DELAY_MOVE_SECONDS
const ACTION_DELAY_SKIP_SECONDS := BattleConfig.ACTION_DELAY_SKIP_SECONDS
const ACTION_DELAY_STUCK_SECONDS := BattleConfig.ACTION_DELAY_STUCK_SECONDS
const MASTER_SKILL_DAMAGE := 8
const MIN_COMBAT_CHIP_DAMAGE := 1
const SUMMON_NEARBY_RADIUS := 2
const THRAX_GOLD_ATTACK_RATIO := 0.01
const THRAX_CLEAVE_DAMAGE_RATIO := 0.65
const MORDOS_SOUL_STAT_RATIO_PER_STACK := 0.03
const DAMA_PASSIVE_HEAL_RATIO := 0.35
const DAMA_PASSIVE_MIN_HEAL := 2
const SPAWN_COLUMN_ORDER: Array[int] = [3, 2, 4, 1, 5, 0, 6]
const LOCAL_COMBAT_MAX_ACTIONS := 240
const LOCAL_LOOP_BOUNCE_THRESHOLD := 2
const TARGET_STUCK_RETARGET_LIMIT := 3
const TARGET_LOCK_REFRESH_TURNS := 2
const ROUND_RESULT_SYNC_TIMEOUT_SECONDS := 18.0

const SUPPORT_CARD_FIELD_AID_PATH := "res://data/cards/demo_field_aid.tres"
const SUPPORT_CARD_BATTLE_ORDERS_PATH := "res://data/cards/demo_battle_orders.tres"
const LOCAL_PLAYER_ID := "player_1"

const PLAYER_MASTER_COORD := Vector2i(3, BattleConfig.BOARD_HEIGHT - 1)
const ENEMY_MASTER_COORD := Vector2i(3, 0)

var round_flow: RoundFlowState = RoundFlowState.new()
var observer_state: ObserverState = ObserverState.new()
var _player_runtime_life_fallback: int = BattleConfig.GLOBAL_LIFE
var _enemy_runtime_life_fallback: int = BattleConfig.GLOBAL_LIFE
var _player_runtime_gold_fallback: int = 0
var _enemy_runtime_gold_fallback: int = 0

var current_state: int = GameEnums.BattleState.SETUP
var current_match_phase: int:
	get:
		return round_flow.match_phase
	set(value):
		round_flow.set_match_phase(value)
var current_round: int:
	get:
		return round_flow.round_number
	set(value):
		round_flow.set_round_number(value)
var gold_current: int:
	get:
		return _get_runtime_team_gold(GameEnums.TeamSide.PLAYER)
	set(value):
		_set_runtime_team_gold(GameEnums.TeamSide.PLAYER, value)
var enemy_gold_current: int:
	get:
		return _get_runtime_team_gold(GameEnums.TeamSide.ENEMY)
	set(value):
		_set_runtime_team_gold(GameEnums.TeamSide.ENEMY, value)
var player_global_life: int:
	get:
		return _get_runtime_team_life(GameEnums.TeamSide.PLAYER)
	set(value):
		_set_runtime_team_life(GameEnums.TeamSide.PLAYER, value)
var enemy_global_life: int:
	get:
		return _get_runtime_team_life(GameEnums.TeamSide.ENEMY)
	set(value):
		_set_runtime_team_life(GameEnums.TeamSide.ENEMY, value)
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
var card_shop_open: bool:
	get:
		var shop_state: ShopState = _local_shop_state()
		return shop_state != null and shop_state.ui_open
	set(value):
		var shop_state: ShopState = _local_shop_state()
		if shop_state != null:
			shop_state.ui_open = value
var pending_card_shop_paths: Array[String]:
	get:
		var shop_state: ShopState = _local_shop_state()
		return shop_state.pending_offer_paths if shop_state != null else []
	set(value):
		var shop_state: ShopState = _local_shop_state()
		if shop_state != null:
			shop_state.pending_offer_paths = value.duplicate()

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
var pending_player_bonus_gold_on_win: int = 0
var pending_enemy_bonus_gold_on_win: int = 0
var pending_player_tribute_steal_on_win: int = 0
var pending_enemy_tribute_steal_on_win: int = 0
var pending_player_opening_reposition: bool = false
var pending_enemy_opening_reposition: bool = false
var bone_prison_coord: Vector2i = Vector2i(-1, -1)
var bone_prison_owner_team: int = GameEnums.TeamSide.PLAYER
var bone_prison_stun_turns: int = 2
var bone_prison_mana_gain_multiplier: float = 0.0
var mordos_soul_counts: Dictionary = {}
var periodic_magic_field_states: Dictionary = {}
var opening_action_slow_states: Dictionary = {}
var first_ally_death_summon_states: Dictionary = {}
var first_combat_death_resolved: bool = false
var local_combat_actions_taken: int = 0
var local_combat_failsafe_triggered: bool = false
var local_combat_failsafe_reason: String = ""
var awaiting_remote_round_settlement: bool = false
var remote_round_settlement_elapsed: float = 0.0
var remote_round_settlement_last_second: int = -1
var local_elimination_prompt_active: bool = false
var local_post_elimination_observer_enabled: bool = false

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
	if not GameData.has_selected_deck():
		call_deferred("_redirect_to_deck_select")
		return

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
		battle_hud.card_shop_option_selected.connect(_on_card_shop_option_selected)
		battle_hud.elimination_watch_requested.connect(_on_elimination_watch_requested)
		battle_hud.elimination_back_requested.connect(_on_elimination_back_requested)
		battle_hud.play_again_requested.connect(_on_play_again_requested)
		battle_hud.clear_unit_info()
	if deploy_bar:
		deploy_bar.deploy_slot_pressed.connect(_on_deploy_slot_pressed)
		deploy_bar.deploy_slot_right_clicked.connect(_on_deploy_slot_right_clicked)
		deploy_bar.support_slot_pressed.connect(_on_support_slot_pressed)
		deploy_bar.support_slot_right_clicked.connect(_on_support_slot_right_clicked)

	start_match()

func _redirect_to_deck_select() -> void:
	get_tree().change_scene_to_file(GameData.DECK_SELECT_SCENE_PATH)

func _process(delta: float) -> void:
	var observed_player_id: String = observer_state.observed_player_id if observer_state.is_remote_view() else ""
	var remote_tables_changed: bool = lobby_manager.update_live_tables(delta, observed_player_id)
	if remote_tables_changed:
		if observer_state.is_remote_view():
			_refresh_observer_binding_if_needed(true)
		_emit_hud_update()

	if awaiting_remote_round_settlement:
		_update_remote_round_settlement(delta)

	if current_match_phase != GameEnums.MatchPhase.ROUND_PREP:
		return
	if current_state != GameEnums.BattleState.PREP:
		return
	if not prep_timer_active or _battle_running:
		return
	if card_shop_open:
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

	if event is InputEventKey:
		var global_key_event := event as InputEventKey
		if global_key_event.pressed and not global_key_event.echo:
			if global_key_event.keycode == KEY_ESCAPE and _is_observer_mode_active():
				_return_to_local_board()
				return

	if current_state != GameEnums.BattleState.PREP or input_locked:
		return
	if card_shop_open:
		return
	if _is_observer_mode_active():
		if event is InputEventKey:
			var blocked_key_event := event as InputEventKey
			if blocked_key_event.pressed and not blocked_key_event.echo:
				match blocked_key_event.keycode:
					KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
						_block_observer_input("deploy_hotkey")
					KEY_Q, KEY_W:
						_block_observer_input("use_card")
					KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
						_block_observer_input("start_battle")
		elif event is InputEventMouseButton:
			var blocked_mouse_event := event as InputEventMouseButton
			if blocked_mouse_event.button_index == MOUSE_BUTTON_LEFT and blocked_mouse_event.pressed:
				if deploy_bar != null and deploy_bar.is_over_ui(blocked_mouse_event.position):
					_block_observer_input("deploy_unit")
				elif not _is_screen_over_ui(blocked_mouse_event.position):
					_block_observer_input("board_interaction")
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
	if _block_observer_input("board_interaction"):
		return
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
	if _block_observer_input("board_interaction"):
		return
	if drag_mode == DRAG_MODE_DEPLOY_SLOT:
		_finish_deploy_drag(screen_pos)
	elif drag_mode == DRAG_MODE_BOARD_UNIT:
		_finish_board_unit_drag(screen_pos)

func _handle_info_panel_click(screen_pos: Vector2) -> void:
	if not _is_click_over_inspectable_target(screen_pos):
		if _is_observer_mode_active():
			inspected_unit = null
			inspected_deploy_index = -1
			inspected_support_index = -1
			_refresh_inspected_unit_panel()
			return
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
	if _is_observer_mode_active():
		return board_grid.get_observed_unit_at(coord) != null
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
	if _is_observer_mode_active():
		var observed_unit: BattleUnitState = board_grid.get_observed_unit_at(coord)
		if observed_unit != null:
			_on_observed_board_unit_right_clicked(observed_unit)
		else:
			_refresh_inspected_unit_panel()
		return true
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

func _is_observer_mode_active() -> bool:
	return observer_state.is_remote_view() or (board_grid != null and board_grid.is_observer_mode_active())

func _block_observer_input(action: String) -> bool:
	if battle_hud != null and (battle_hud.is_elimination_screen_open() or battle_hud.is_final_screen_open()):
		print("OBSERVER blocked_input action=%s" % action)
		return true
	if _is_post_elimination_observer_mode():
		print("OBSERVER blocked_input action=%s" % action)
		return true
	if not _is_observer_mode_active():
		return false
	print("OBSERVER blocked_input action=%s" % action)
	return true

func _is_local_player_active() -> bool:
	var local_player: MatchPlayerState = _local_player_state()
	return local_player != null and not local_player.eliminated

func _has_local_combat_this_round() -> bool:
	return _is_local_player_active() and not current_opponent_player_id.is_empty()

func _is_post_elimination_observer_mode() -> bool:
	return local_post_elimination_observer_enabled and not _is_local_player_active()

func _placement_text(placement: int) -> String:
	return "Top %d" % maxi(1, placement)

func _clear_runtime_team_units(team_side: int) -> void:
	var kept_units: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null:
			continue
		if unit_state.team_side == team_side:
			unit_state.clear_navigation_memory()
			board_grid.remove_unit(unit_state, true, true)
			continue
		kept_units.append(unit_state)
	runtime_units = kept_units

func _build_match_ranking_lines() -> Array[String]:
	var ranking_lines: Array[String] = []
	for ranking_entry in lobby_manager.get_match_ranking_entries():
		var placement_value: int = int(ranking_entry.get("placement", 0))
		if placement_value <= 0:
			continue
		ranking_lines.append("Top %d - %s" % [
			placement_value,
			str(ranking_entry.get("player_name", "Jogador")),
		])
	return ranking_lines

func _bind_first_available_observer_target() -> void:
	if not _is_post_elimination_observer_mode():
		return
	if observer_state.is_remote_view():
		var current_runtime: Dictionary = lobby_manager.get_observed_runtime(observer_state.observed_player_id)
		if not current_runtime.is_empty():
			_bind_observed_runtime(observer_state.observed_player_id, current_runtime)
			return

	for player_id in lobby_manager.get_active_player_ids():
		if player_id == LOCAL_PLAYER_ID:
			continue
		if lobby_manager.get_table_id_for_player(player_id).is_empty():
			continue
		var observed_runtime: Dictionary = lobby_manager.get_observed_runtime(player_id)
		if observed_runtime.is_empty():
			continue
		_bind_observed_runtime(player_id, observed_runtime)
		_emit_hud_update()
		return

func _show_local_elimination_screen() -> void:
	var local_player: MatchPlayerState = _local_player_state()
	if local_player == null:
		return
	local_elimination_prompt_active = true
	prep_timer_active = false
	card_shop_open = false
	_set_input_locked(false)
	if battle_hud != null:
		battle_hud.hide_card_shop()
		battle_hud.show_elimination_screen(_placement_text(local_player.placement))
	_emit_hud_update()
	print("LOCAL_ELIMINATION placement=%s" % _placement_text(local_player.placement))

func _show_match_final_screen() -> void:
	var local_player: MatchPlayerState = _local_player_state()
	var placement_value: int = local_player.placement if local_player != null and local_player.placement > 0 else 1
	var ranking_lines: Array[String] = _build_match_ranking_lines()
	var winner_id: String = lobby_manager.get_match_winner_id()
	var winner_state: MatchPlayerState = lobby_manager.get_match_winner()
	var winner_name: String = winner_state.display_name if winner_state != null else winner_id
	var winner_units: Array[String] = lobby_manager.get_final_board_unit_names(winner_id)
	var total_damage: int = local_player.total_damage_dealt if local_player != null else 0

	local_elimination_prompt_active = false
	prep_timer_active = false
	card_shop_open = false
	awaiting_remote_round_settlement = false
	remote_round_settlement_elapsed = 0.0
	remote_round_settlement_last_second = -1
	_battle_running = false
	observer_state.reset()
	if board_grid:
		board_grid.clear_observed_runtime()
	if battle_hud != null:
		battle_hud.hide_elimination_screen()
		battle_hud.hide_card_shop()
		battle_hud.clear_observer_banner()
		battle_hud.show_final_screen(_placement_text(placement_value), ranking_lines, winner_units, total_damage, winner_name)
	_set_match_phase(GameEnums.MatchPhase.MATCH_END)
	set_state(GameEnums.BattleState.MATCH_END)
	_set_input_locked(false)
	_emit_hud_update()
	print("FIM DA PARTIDA: vencedor=%s" % winner_name)

func _on_elimination_watch_requested() -> void:
	local_elimination_prompt_active = false
	local_post_elimination_observer_enabled = true
	if battle_hud != null:
		battle_hud.hide_elimination_screen()
	if lobby_manager.is_match_finished():
		_show_match_final_screen()
		return
	current_round += 1
	print("OBSERVER after elimination: round=%d" % current_round)
	_start_prep_phase()

func _on_elimination_back_requested() -> void:
	if battle_hud != null:
		battle_hud.hide_elimination_screen()
	_redirect_to_deck_select()

func _on_play_again_requested() -> void:
	if battle_hud != null:
		battle_hud.hide_final_screen()
	_redirect_to_deck_select()

func _begin_deploy_drag(slot_index: int) -> void:
	if _block_observer_input("deploy_unit"):
		return
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

	print("Arraste de deploy iniciado: %s (custo %d)" % [option.unit_data.id, option.unit_data.get_effective_cost()])

func _begin_board_unit_drag(unit_state: BattleUnitState, screen_pos: Vector2) -> void:
	if _block_observer_input("move_unit"):
		return
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
	if _block_observer_input("deploy_unit"):
		return
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
	if _block_observer_input("move_unit"):
		return
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
				if drag_unit.team_side == GameEnums.TeamSide.PLAYER:
					drag_unit.home_coord = drag_hover_coord
					_record_persistent_formation_unit(drag_unit)
					if drag_unit.is_master:
						_set_persistent_master_home_coord(drag_unit.team_side, drag_hover_coord)
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
	lobby_manager.setup_demo_lobby(
		BattleConfig.LOBBY_PLAYER_COUNT,
		LOCAL_PLAYER_ID,
		""
	)
	lobby_manager.set_player_deck_path(LOCAL_PLAYER_ID, _selected_player_deck_path())
	lobby_manager.assign_demo_bot_decks(
		GameData.get_bot_cycle_deck_ids(GameData.get_selected_deck_id()),
		LOCAL_PLAYER_ID
	)
	round_manager = RoundManager.new()
	_set_match_phase(GameEnums.MatchPhase.LOBBY)
	print("LOBBY ready: %d players | local=%s" % [
		lobby_manager.get_player_ids().size(),
		LOCAL_PLAYER_ID,
	])

func _sync_runtime_gold_from_match_state() -> void:
	var local_player: MatchPlayerState = _local_player_state()
	if local_player != null:
		gold_current = local_player.current_gold
	else:
		_player_runtime_gold_fallback = 0

	var opponent_player: MatchPlayerState = _get_player_state_for_team(GameEnums.TeamSide.ENEMY)
	if opponent_player != null:
		enemy_gold_current = opponent_player.current_gold
	else:
		_enemy_runtime_gold_fallback = 0

func _prepare_round_pairing_for_current_round() -> void:
	var active_player_ids: Array[String] = lobby_manager.get_active_player_ids()
	if active_player_ids.is_empty():
		current_opponent_player_id = ""
		return

	lobby_manager.set_player_deck_path(LOCAL_PLAYER_ID, _selected_player_deck_path(), false)
	_set_match_phase(GameEnums.MatchPhase.ROUND_PAIRING)
	var pairings: Array[Dictionary] = round_manager.build_pairings(
		active_player_ids,
		current_round
	)
	lobby_manager.apply_round_pairings(pairings)
	var bye_entries: Array[Dictionary] = lobby_manager.apply_technical_byes(round_manager.get_current_bye_player_ids(), current_round)
	var granted_cards: Array[Dictionary] = lobby_manager.grant_periodic_cards_for_round(current_round, [LOCAL_PLAYER_ID])
	current_opponent_player_id = round_manager.get_opponent_for_player(LOCAL_PLAYER_ID)
	_sync_lobby_life_values(true)

	var signal_bus: Node = _get_signal_bus()
	if signal_bus:
		signal_bus.round_pairings_generated.emit(current_round, pairings)

	print("ROUND_PAIRING: round=%d opponent=%s" % [
		current_round,
		_current_opponent_display_name(),
	])
	for grant_entry in granted_cards:
		print("LOJA do lobby: %s recebeu %s" % [
			str(grant_entry.get("player_name", "Jogador")),
			str(grant_entry.get("card_name", "Carta")),
		])
	for bye_entry in bye_entries:
		print("  bye tecnico: %s" % str(bye_entry.get("player_name", "Jogador")))
	for pairing in pairings:
		print("  pairing table=%d %s vs %s" % [
			int(pairing.get("table_index", -1)),
			str(pairing.get("player_a", "")),
			str(pairing.get("player_b", "")),
		])
	var live_table_exclusions: Array[String] = []
	if _has_local_combat_this_round():
		live_table_exclusions.append(LOCAL_PLAYER_ID)
	lobby_manager.prepare_live_tables_for_round(pairings, current_round, live_table_exclusions)

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
	if not _is_local_player_active():
		return "Observer do lobby" if local_post_elimination_observer_enabled else "Jogador eliminado"
	if round_manager != null and round_manager.has_bye_for_player(LOCAL_PLAYER_ID):
		return "Bye tecnico"
	if _should_hide_next_opponent_in_prep():
		return "Aguardando pareamento" if current_opponent_player_id.is_empty() else "???"
	var opponent_player: MatchPlayerState = lobby_manager.get_player(current_opponent_player_id)
	if opponent_player != null:
		return opponent_player.display_name
	if current_opponent_player_id.is_empty():
		return "Sem combate"
	return current_opponent_player_id

func _should_hide_next_opponent_in_prep() -> bool:
	return current_match_phase == GameEnums.MatchPhase.ROUND_PAIRING or current_match_phase == GameEnums.MatchPhase.ROUND_PREP

func _local_player_state() -> MatchPlayerState:
	return lobby_manager.get_player(LOCAL_PLAYER_ID)

func _get_player_state_for_team(team_side: int) -> MatchPlayerState:
	if team_side == GameEnums.TeamSide.PLAYER:
		return _local_player_state()
	return lobby_manager.get_player(current_opponent_player_id)

func _get_runtime_team_life(team_side: int) -> int:
	var player_state: MatchPlayerState = _get_player_state_for_team(team_side)
	if player_state != null:
		return player_state.current_life
	return _player_runtime_life_fallback if team_side == GameEnums.TeamSide.PLAYER else _enemy_runtime_life_fallback

func _set_runtime_team_life(team_side: int, value: int) -> void:
	var normalized_value: int = clampi(value, 0, BattleConfig.GLOBAL_LIFE)
	var player_state: MatchPlayerState = _get_player_state_for_team(team_side)
	if player_state != null:
		player_state.current_life = normalized_value
		player_state.eliminated = normalized_value <= 0
	if team_side == GameEnums.TeamSide.PLAYER:
		_player_runtime_life_fallback = normalized_value
	else:
		_enemy_runtime_life_fallback = normalized_value

func _get_runtime_team_gold(team_side: int) -> int:
	var player_state: MatchPlayerState = _get_player_state_for_team(team_side)
	if player_state != null:
		return maxi(0, player_state.current_gold)
	return _player_runtime_gold_fallback if team_side == GameEnums.TeamSide.PLAYER else _enemy_runtime_gold_fallback

func _set_runtime_team_gold(team_side: int, value: int) -> void:
	var normalized_value: int = maxi(0, value)
	var player_state: MatchPlayerState = _get_player_state_for_team(team_side)
	if player_state != null:
		normalized_value = player_state.set_current_gold_capped(normalized_value, "runtime_team_gold")
	if team_side == GameEnums.TeamSide.PLAYER:
		_player_runtime_gold_fallback = normalized_value
	else:
		_enemy_runtime_gold_fallback = normalized_value
	if board_grid != null and not runtime_units.is_empty():
		_refresh_deck_passive_state(false)

func _local_shop_state() -> ShopState:
	var local_player: MatchPlayerState = _local_player_state()
	if local_player == null:
		return null
	return local_player.shop_state

func _get_mordos_souls(team_side: int) -> int:
	return int(mordos_soul_counts.get(team_side, 0))

func _add_mordos_souls(team_side: int, amount: int) -> int:
	var updated_value: int = maxi(0, _get_mordos_souls(team_side) + amount)
	mordos_soul_counts[team_side] = updated_value
	return updated_value

func _get_team_formation_state(team_side: int) -> FormationState:
	var player_state: MatchPlayerState = _get_player_state_for_team(team_side)
	if player_state == null:
		return null
	return player_state.formation_state

func _record_persistent_formation_unit(unit_state: BattleUnitState) -> void:
	if unit_state == null or unit_state.unit_data == null:
		return
	var formation_state: FormationState = _get_team_formation_state(unit_state.team_side)
	if formation_state == null:
		return
	var unit_path: String = unit_state.unit_data.resource_path
	if unit_path.is_empty():
		unit_path = _get_unit_path_by_id(unit_state.unit_data.id, unit_state.team_side)
	formation_state.register_unit(
		unit_state.unit_data.id,
		unit_path,
		unit_state.home_coord,
		unit_state.is_master
	)

func _remove_persistent_formation_unit(unit_state: BattleUnitState) -> void:
	if unit_state == null or unit_state.unit_data == null or unit_state.is_master:
		return
	var formation_state: FormationState = _get_team_formation_state(unit_state.team_side)
	if formation_state == null:
		return
	formation_state.remove_unit(unit_state.unit_data.id)

func _reset_round_card_effect_state() -> void:
	pending_player_bonus_gold_on_win = 0
	pending_enemy_bonus_gold_on_win = 0
	pending_player_tribute_steal_on_win = 0
	pending_enemy_tribute_steal_on_win = 0
	pending_player_opening_reposition = false
	pending_enemy_opening_reposition = false

func _reset_runtime_deck_effect_state() -> void:
	battle_turn_index = 0
	pending_blinding_mist_turn = -1
	pending_blinding_mist_team = -1
	pending_blinding_mist_duration_turns = 2
	pending_blinding_mist_physical_miss_chance = 0.5
	bone_prison_coord = Vector2i(-1, -1)
	bone_prison_stun_turns = 2
	bone_prison_mana_gain_multiplier = 0.0
	mordos_soul_counts.clear()
	periodic_magic_field_states.clear()
	opening_action_slow_states.clear()
	first_ally_death_summon_states.clear()
	first_combat_death_resolved = false
	_reset_round_card_effect_state()

func _selected_player_deck_path() -> String:
	return GameData.get_selected_deck_path()

func _default_enemy_deck_path() -> String:
	return GameData.get_default_opponent_deck_path()

func _load_active_decks() -> void:
	player_deck = _load_deck_for_player(LOCAL_PLAYER_ID, GameData.get_selected_deck_id())
	enemy_deck = _load_deck_for_player(current_opponent_player_id, GameData.get_default_opponent_deck_id())
	player_unit_path_registry = _build_unit_path_registry(player_deck)
	enemy_unit_path_registry = _build_unit_path_registry(enemy_deck)
	_log_loaded_deck("PLAYER", player_deck)
	_log_loaded_deck("ENEMY", enemy_deck)

func _load_deck_for_player(player_id: String, fallback_deck_id: String) -> DeckData:
	var deck_path: String = ""
	if not player_id.is_empty():
		var player_state: MatchPlayerState = lobby_manager.get_player(player_id)
		if player_state != null:
			deck_path = player_state.deck_path
	if deck_path.is_empty():
		deck_path = GameData.get_deck_path(fallback_deck_id)
	return _load_deck_data(deck_path)

func _load_mordos_deck() -> DeckData:
	return _load_deck_data(GameData.get_deck_path(GameData.DECK_ID_MORDOS))

func _load_thrax_deck() -> DeckData:
	return _load_deck_data(GameData.get_deck_path(GameData.DECK_ID_THRAX))

func _sync_runtime_masters_with_active_decks() -> void:
	_sync_team_master_with_deck(GameEnums.TeamSide.PLAYER, player_deck, PLAYER_MASTER_COORD)
	_sync_team_master_with_deck(GameEnums.TeamSide.ENEMY, enemy_deck, ENEMY_MASTER_COORD)

func _sync_team_master_with_deck(team_side: int, deck_data: DeckData, fallback_coord: Vector2i) -> void:
	if deck_data == null or deck_data.master_data_path.is_empty():
		return
	var expected_master_data: UnitData = _load_unit_data(deck_data.master_data_path)
	if expected_master_data == null:
		return
	var current_master: BattleUnitState = _find_team_master_any_state(team_side)
	if current_master != null and current_master.unit_data != null and current_master.unit_data.id == expected_master_data.id:
		_set_persistent_master_home_coord(team_side, current_master.home_coord)
		return
	var pending_home_coord: Vector2i = _get_pending_respawn_home_coord(expected_master_data.id, team_side)
	if board_grid.is_valid_coord(pending_home_coord):
		_set_persistent_master_home_coord(team_side, pending_home_coord)
		return
	if current_master != null:
		board_grid.remove_unit(current_master, true, true)
		runtime_units.erase(current_master)
	var master_home_coord: Vector2i = _get_persistent_master_home_coord(team_side)
	if not board_grid.is_valid_coord(master_home_coord):
		master_home_coord = fallback_coord
	_spawn_roster_unit(deck_data.master_data_path, team_side, master_home_coord, true, master_home_coord)
	_refresh_race_synergy_state(false)

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

	if not deck_data.master_data_path.is_empty():
		var master_data: UnitData = _load_unit_data(deck_data.master_data_path)
		if master_data != null:
			registry[master_data.id] = deck_data.master_data_path

	for unit_path in deck_data.unit_pool_paths:
		var unit_data: UnitData = _load_unit_data(unit_path)
		if unit_data != null:
			registry[unit_data.id] = unit_path

	return registry

func _master_home_coord(team_side: int) -> Vector2i:
	return PLAYER_MASTER_COORD if team_side == GameEnums.TeamSide.PLAYER else ENEMY_MASTER_COORD

func _get_persistent_master_home_coord(team_side: int) -> Vector2i:
	var formation_state: FormationState = _get_team_formation_state(team_side)
	if formation_state == null:
		return _master_home_coord(team_side)
	return formation_state.get_master_coord(_master_home_coord(team_side))

func _set_persistent_master_home_coord(team_side: int, coord: Vector2i) -> void:
	if not board_grid.is_valid_coord(coord):
		return
	var formation_state: FormationState = _get_team_formation_state(team_side)
	if formation_state == null:
		return

	var master_state: BattleUnitState = _find_team_master(team_side)
	if master_state != null and master_state.unit_data != null:
		formation_state.register_unit(
			master_state.unit_data.id,
			master_state.unit_data.resource_path,
			coord,
			true
		)
		return

	var deck_data: DeckData = player_deck if team_side == GameEnums.TeamSide.PLAYER else enemy_deck
	if deck_data == null:
		return
	var master_data: UnitData = _load_unit_data(deck_data.master_data_path)
	if master_data == null:
		return
	formation_state.register_unit(
		master_data.id,
		deck_data.master_data_path,
		coord,
		true
	)

func _get_pending_respawn_home_coord(unit_id: String, team_side: int) -> Vector2i:
	var queue: Array[RespawnRequest] = pending_player_respawns if team_side == GameEnums.TeamSide.PLAYER else pending_enemy_respawns
	for request in queue:
		if request.unit_id == unit_id and board_grid.is_valid_coord(request.home_coord):
			return request.home_coord
	return Vector2i(-1, -1)

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
	lobby_manager.initialize_match_economy()
	_load_active_decks()
	round_flow.reset()
	observer_state.reset()
	current_round = 1
	player_global_life = BattleConfig.GLOBAL_LIFE
	enemy_global_life = BattleConfig.GLOBAL_LIFE
	_player_runtime_gold_fallback = 0
	prep_time_remaining = 0.0
	prep_timer_active = false
	prep_timer_last_display_second = -1
	_enemy_runtime_gold_fallback = 0
	current_opponent_player_id = ""
	awaiting_remote_round_settlement = false
	remote_round_settlement_elapsed = 0.0
	remote_round_settlement_last_second = -1
	local_elimination_prompt_active = false
	local_post_elimination_observer_enabled = false
	local_combat_actions_taken = 0
	local_combat_failsafe_triggered = false
	local_combat_failsafe_reason = ""
	card_shop_open = false
	if battle_hud:
		battle_hud.hide_card_shop()
		battle_hud.hide_elimination_screen()
		battle_hud.hide_final_screen()
	var start_shop_state: ShopState = _local_shop_state()
	if start_shop_state != null:
		start_shop_state.clear_offer()
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
	_reset_runtime_deck_effect_state()
	var local_player: MatchPlayerState = _local_player_state()
	if local_player != null:
		local_player.formation_state.clear()
		local_player.shop_state.clear_offer()
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
		_spawn_roster_unit(player_deck.master_data_path, GameEnums.TeamSide.PLAYER, PLAYER_MASTER_COORD, true)
	if enemy_deck != null:
		_spawn_roster_unit(enemy_deck.master_data_path, GameEnums.TeamSide.ENEMY, ENEMY_MASTER_COORD, true)

func _start_prep_phase() -> void:
	card_shop_open = false
	var prep_shop_state: ShopState = _local_shop_state()
	if prep_shop_state != null:
		prep_shop_state.clear_offer()
	if battle_hud:
		battle_hud.hide_card_shop()
	awaiting_remote_round_settlement = false
	remote_round_settlement_elapsed = 0.0
	remote_round_settlement_last_second = -1
	_reset_local_combat_runtime()
	_clear_round_limited_tokens()
	_remove_dead_runtime_units()
	lobby_manager.apply_round_income_for_prep(current_round)
	_prepare_round_pairing_for_current_round()
	_sync_runtime_gold_from_match_state()
	_load_active_decks()
	var local_player_active: bool = _is_local_player_active()
	var local_has_combat: bool = _has_local_combat_this_round()
	if not local_has_combat:
		enemy_deck = null
		enemy_unit_path_registry.clear()
	_sync_runtime_masters_with_active_decks()
	_reset_round_card_effect_state()

	_ensure_missing_master_respawns()
	var respawned_units: Array[String] = _process_pending_respawns()
	var restored_survivors: Array[String] = _restore_survivors_for_new_prep()

	if not local_has_combat:
		_clear_runtime_team_units(GameEnums.TeamSide.ENEMY)

	player_deploy_pool.clear()
	enemy_deploy_pool.clear()
	player_support_pool.clear()
	selected_support_index = -1
	if local_player_active:
		_build_player_deploy_pool()
		_build_player_support_pool()
		_mark_pool_used_from_living_player_units()
	if local_has_combat:
		_build_enemy_deploy_pool()
		_mark_pool_used_from_living_enemy_units()

	_battle_running = false
	_reset_runtime_deck_effect_state()
	prep_time_remaining = BattleConfig.PREP_DURATION_SECONDS if local_player_active and not _is_post_elimination_observer_mode() else 0.0
	prep_timer_active = local_player_active and not _is_post_elimination_observer_mode()
	prep_timer_last_display_second = -1
	_clear_inspected_context()
	_clear_drag_state()
	_clear_support_selection(false)
	_apply_board_view_mode(GameEnums.BoardViewMode.SELF_ONLY, true)
	if local_has_combat:
		_auto_prepare_enemy_board()
		_auto_use_enemy_support_cards()
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
	if local_player_active:
		try_open_card_shop_for_round(current_round)
	if _is_post_elimination_observer_mode():
		call_deferred("_start_remote_only_round")

	_log_round_refresh(restored_survivors, respawned_units)
	print("ROUND_PREP entered: rodada=%d ouro=%d vida_jogador=%d vida_inimigo=%d" % [
		current_round,
		gold_current,
		player_global_life,
		enemy_global_life,
	])
	print("PREP inimigo: ouro=%d unidades=%d" % [
		enemy_gold_current,
		_count_non_master_units(GameEnums.TeamSide.ENEMY),
	])
	print("Unidades em campo: JOGADOR=%d INIMIGO=%d" % [
		_count_living_team(GameEnums.TeamSide.PLAYER),
		_count_living_team(GameEnums.TeamSide.ENEMY),
	])
	print("Controles do PREP: arraste slots de unidade para deploy, arraste unidades no tabuleiro, use a linha de cartas para armar efeitos, clique nos alvos destacados, ENTER/SPACE inicia a batalha, botao direito abre info")

func _restore_survivors_for_new_prep() -> Array[String]:
	var rebuild_units: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null or unit_state.unit_data == null:
			continue
		if unit_state.is_summoned_token:
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
				_remove_persistent_formation_unit(unit_state)
				_append_unique(refresh_bar_fallbacks, unit_state.get_display_name())
			else:
				push_warning("BattleManager: failed to rebuild prep coord for %s" % unit_state.get_combat_label())
			continue

		unit_state.coord = target_coord
		unit_state.remember_position_sample(target_coord)
		if not board_grid.spawn_unit(unit_state):
			if unit_state.team_side == GameEnums.TeamSide.PLAYER and not unit_state.is_master:
				runtime_units.erase(unit_state)
				_remove_persistent_formation_unit(unit_state)
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
		_enqueue_missing_roster_respawn(player_deck.master_data_path, GameEnums.TeamSide.PLAYER, true)
	if enemy_deck != null:
		_enqueue_missing_roster_respawn(enemy_deck.master_data_path, GameEnums.TeamSide.ENEMY, true)

func _enqueue_missing_roster_respawn(unit_path: String, team_side: int, is_master: bool = false) -> void:
	var unit_data: UnitData = _load_unit_data(unit_path)
	if unit_data == null:
		return
	if _find_runtime_unit_by_id(unit_data.id, team_side) != null:
		return
	if _has_pending_respawn(unit_data.id, team_side):
		return

	var request: RespawnRequest = RespawnRequest.new(
		unit_path,
		unit_data.id,
		team_side,
		_get_persistent_master_home_coord(team_side) if is_master else _default_deploy_home_coord(0, team_side),
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

	var existing_unit: BattleUnitState = _find_runtime_unit_by_id(request.unit_id, request.team_side)
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
	if request.is_master:
		_set_persistent_master_home_coord(request.team_side, request.home_coord)
	_record_persistent_formation_unit(state)
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

	_refresh_deck_passive_state(log_changes)
	_refresh_inspected_unit_panel()
	_emit_hud_update()

func _refresh_deck_passive_state(log_changes: bool) -> void:
	var player_passive_units: Array[String] = []
	var enemy_passive_units: Array[String] = []

	for unit_state in runtime_units:
		if unit_state == null:
			continue
		unit_state.clear_deck_passive_modifiers()

	if board_grid == null:
		return

	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.unit_data == null or unit_state.unit_data.id != "thrax_master":
			continue
		var team_gold: int = _get_runtime_team_gold(unit_state.team_side)
		for ally in runtime_units:
			if ally == null or not ally.can_act():
				continue
			if ally.team_side != unit_state.team_side:
				continue
			var base_attack: int = ally.unit_data.physical_attack + ally.get_race_physical_attack_bonus() + ally.get_class_physical_attack_bonus() + ally.synergy_physical_attack + ally.bonus_physical_attack
			var gold_bonus: int = int(round(float(maxi(0, base_attack)) * float(team_gold) * THRAX_GOLD_ATTACK_RATIO))
			if team_gold > 0 and gold_bonus <= 0 and base_attack > 0:
				gold_bonus = 1
			ally.deck_passive_physical_attack = maxi(ally.deck_passive_physical_attack, gold_bonus)
			if gold_bonus <= 0:
				continue
			var label: String = "%s (+%d ATQ F | %d ouro)" % [ally.get_display_name(), gold_bonus, team_gold]
			if ally.team_side == GameEnums.TeamSide.PLAYER:
				player_passive_units.append(label)
			else:
				enemy_passive_units.append(label)

	for unit_state in runtime_units:
		if unit_state == null:
			continue
		_refresh_actor_state(unit_state)

	if log_changes and not player_passive_units.is_empty():
		print("Ganancia do Rei (jogador): %s" % _join_strings(player_passive_units))
	if log_changes and not enemy_passive_units.is_empty():
		print("Ganancia do Rei (inimigo): %s" % _join_strings(enemy_passive_units))

func _confirm_start_battle(force_auto_start: bool = false) -> void:
	if _battle_running or current_state != GameEnums.BattleState.PREP:
		return
	if _is_observer_mode_active() and not force_auto_start:
		_block_observer_input("start_battle")
		return
	if card_shop_open:
		return
	if input_locked and not force_auto_start:
		return

	var local_has_combat: bool = _has_local_combat_this_round()
	var deployed_player_units: int = _count_player_non_master_units()
	if not force_auto_start and deployed_player_units <= 0 and _player_has_ready_deploy_slots():
		print("BATALHA bloqueada: faca deploy de pelo menos uma unidade antes de iniciar (slots_prontos=%d)" % _count_ready_player_deploy_slots())
		return
	if force_auto_start and deployed_player_units <= 0 and _player_has_ready_deploy_slots():
		print("AUTO-START do PREP: seguindo com a formacao atual sem deploy adicional do jogador")
	elif deployed_player_units <= 0:
		print("BATALHA seguindo so com o mestre: nenhum slot de deploy pronto no PREP")

	_set_input_locked(true)
	card_shop_open = false
	var battle_shop_state: ShopState = _local_shop_state()
	if battle_shop_state != null:
		battle_shop_state.clear_offer()
	if battle_hud:
		battle_hud.hide_card_shop()
	_commit_player_prep_formation()
	_clear_inspected_context()
	_clear_support_selection(false)
	_clear_drag_state()
	_set_selected_prep_unit(null)
	selected_deploy_index = -1
	prep_timer_active = false
	_battle_running = local_has_combat
	_reset_local_combat_runtime()
	if not local_has_combat:
		print("BATALHA remota confirmada: %s" % ("auto-start do timer" if force_auto_start else "input manual"))
		call_deferred("_start_remote_only_round")
		return
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
	if lobby_manager.begin_live_tables_battle(current_round):
		_emit_hud_update()
	_apply_bone_prison_opening()
	_apply_opening_reposition_effects()
	_set_match_phase(GameEnums.MatchPhase.ROUND_BATTLE)
	start_battle()
	print("BATALHA iniciada: rodada=%d oponente=%s" % [current_round, _current_opponent_display_name()])
	_run_auto_battle()

func _start_remote_only_round() -> void:
	if current_match_phase == GameEnums.MatchPhase.MATCH_END:
		return
	_set_input_locked(false)
	if board_grid:
		board_grid.clear_target_highlights()
	if battle_hud != null:
		battle_hud.hide_card_shop()
	if lobby_manager.begin_live_tables_battle(current_round):
		_emit_hud_update()
	_set_match_phase(GameEnums.MatchPhase.ROUND_BATTLE)
	start_battle()
	_battle_running = false
	awaiting_remote_round_settlement = lobby_manager.has_active_live_tables(current_round)
	remote_round_settlement_elapsed = 0.0
	remote_round_settlement_last_second = -1
	if _is_post_elimination_observer_mode():
		_bind_first_available_observer_target()
	if not awaiting_remote_round_settlement:
		_finalize_round_after_remote_tables()
		return
	print("ROUND_BATTLE remoto: rodada=%d local_combat=%s observer=%s" % [
		current_round,
		"sim" if _has_local_combat_this_round() else "nao",
		"sim" if _is_post_elimination_observer_mode() else "nao",
	])

func _run_auto_battle() -> void:
	while current_state == GameEnums.BattleState.BATTLE:
		if local_combat_actions_taken >= LOCAL_COMBAT_MAX_ACTIONS:
			if not _is_combat_finished():
				local_combat_failsafe_triggered = true
				local_combat_failsafe_reason = "local_action_cap"
				print("FAILSAFE: combate local atingiu o limite rigido de acoes=%d" % LOCAL_COMBAT_MAX_ACTIONS)
			break
		if _is_combat_finished():
			break

		var turn_order: Array[BattleUnitState] = _build_auto_battle_turn_order()
		if turn_order.is_empty():
			break

		for acting_unit in turn_order:
			if current_state != GameEnums.BattleState.BATTLE:
				break
			if local_combat_actions_taken >= LOCAL_COMBAT_MAX_ACTIONS:
				if not _is_combat_finished():
					local_combat_failsafe_triggered = true
					local_combat_failsafe_reason = "local_action_cap"
					print("FAILSAFE: combate local atingiu o limite rigido de acoes=%d" % LOCAL_COMBAT_MAX_ACTIONS)
				break
			if _is_combat_finished():
				break
			var turn_result: Dictionary = _process_unit_turn(acting_unit)
			var decision_delay: float = _decision_delay_for_turn_result(turn_result)
			if decision_delay > 0.0:
				await get_tree().create_timer(decision_delay).timeout

	var winner_team: int = _get_winner_team()
	var survivor_count: int = _count_living_team(winner_team)
	if local_combat_failsafe_triggered:
		var failsafe_outcome: Dictionary = _resolve_local_combat_failsafe_outcome()
		winner_team = int(failsafe_outcome.get("winner_team", -1))
		survivor_count = int(failsafe_outcome.get("survivor_count", 0))
		print("FAILSAFE outcome: winner=%s survivors=%d player_alive=%d enemy_alive=%d player_hp=%d enemy_hp=%d" % [
			_team_result_label(winner_team),
			survivor_count,
			int(failsafe_outcome.get("player_survivors", 0)),
			int(failsafe_outcome.get("enemy_survivors", 0)),
			int(failsafe_outcome.get("player_hp_total", 0)),
			int(failsafe_outcome.get("enemy_hp_total", 0)),
		])
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
		"wait":
			return ACTION_DELAY_SKIP_SECONDS
		"retarget":
			return ACTION_DELAY_STUCK_SECONDS
		_:
			return ACTION_DELAY_STUCK_SECONDS

func _reset_local_combat_runtime() -> void:
	local_combat_actions_taken = 0
	local_combat_failsafe_triggered = false
	local_combat_failsafe_reason = ""

func _team_hp_total(team_side: int) -> int:
	var total_hp: int = 0
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		total_hp += unit_state.current_hp
	return total_hp

func _team_result_label(team_side: int) -> String:
	if team_side == GameEnums.TeamSide.PLAYER:
		return "PLAYER"
	if team_side == GameEnums.TeamSide.ENEMY:
		return "ENEMY"
	return "DRAW"

func _resolve_local_combat_failsafe_outcome() -> Dictionary:
	var player_survivors: int = _count_living_team(GameEnums.TeamSide.PLAYER)
	var enemy_survivors: int = _count_living_team(GameEnums.TeamSide.ENEMY)
	var player_hp_total: int = _team_hp_total(GameEnums.TeamSide.PLAYER)
	var enemy_hp_total: int = _team_hp_total(GameEnums.TeamSide.ENEMY)
	var winner_team: int = -1
	var survivor_count: int = 0

	if player_survivors != enemy_survivors:
		winner_team = GameEnums.TeamSide.PLAYER if player_survivors > enemy_survivors else GameEnums.TeamSide.ENEMY
	elif player_hp_total != enemy_hp_total:
		winner_team = GameEnums.TeamSide.PLAYER if player_hp_total > enemy_hp_total else GameEnums.TeamSide.ENEMY

	if winner_team == GameEnums.TeamSide.PLAYER:
		survivor_count = player_survivors
	elif winner_team == GameEnums.TeamSide.ENEMY:
		survivor_count = enemy_survivors

	return {
		"winner_team": winner_team,
		"survivor_count": survivor_count,
		"player_survivors": player_survivors,
		"enemy_survivors": enemy_survivors,
		"player_hp_total": player_hp_total,
		"enemy_hp_total": enemy_hp_total,
		"reason": local_combat_failsafe_reason,
	}

func _finish_round(winner_team: int, survivor_count: int) -> void:
	var round_winner_label: String = "EMPATE"
	var damage_value: int = 0
	_set_match_phase(GameEnums.MatchPhase.ROUND_RESULT)
	_clear_inspected_context()

	if winner_team == GameEnums.TeamSide.PLAYER or winner_team == GameEnums.TeamSide.ENEMY:
		var winner_id: String = LOCAL_PLAYER_ID if winner_team == GameEnums.TeamSide.PLAYER else current_opponent_player_id
		var loser_id: String = current_opponent_player_id if winner_team == GameEnums.TeamSide.PLAYER else LOCAL_PLAYER_ID
		damage_value = BattleConfig.calculate_post_combat_damage({
			"winner_id": winner_id,
			"loser_id": loser_id,
		}, current_round, {
			"survivors": survivor_count,
		})
		var resolution: Dictionary = lobby_manager.apply_post_combat_damage(winner_id, loser_id, damage_value, current_round, false)
		damage_value = int(resolution.get("damage", damage_value))
		_sync_lobby_life_values(true)

	if winner_team == GameEnums.TeamSide.PLAYER:
		round_winner_label = "JOGADOR"
		_emit_global_life_changed(GameEnums.TeamSide.ENEMY, enemy_global_life)
		print("Dano na vida global: INIMIGO -%d" % damage_value)
	elif winner_team == GameEnums.TeamSide.ENEMY:
		round_winner_label = "INIMIGO"
		_emit_global_life_changed(GameEnums.TeamSide.PLAYER, player_global_life)
		print("Dano na vida global: JOGADOR -%d" % damage_value)

	print("FIM DA RODADA: vencedor=%s sobreviventes=%d dano_na_vida_global=%d" % [
		round_winner_label,
		survivor_count,
		damage_value,
	])
	if local_combat_failsafe_triggered:
		print("FAILSAFE: round_finished_by=%s" % local_combat_failsafe_reason)
	print("Vida global: jogador=%d inimigo=%d" % [player_global_life, enemy_global_life])
	if winner_team == GameEnums.TeamSide.PLAYER:
		last_round_result_summary = "Ult. rodada  Vitoria do jogador | Sobreviventes %d | Inimigo -%d de vida" % [
			survivor_count,
			damage_value,
		]
	elif winner_team == GameEnums.TeamSide.ENEMY:
		last_round_result_summary = "Ult. rodada  Vitoria do inimigo | Sobreviventes %d | Jogador -%d de vida" % [
			survivor_count,
			damage_value,
		]
	else:
		last_round_result_summary = "Ult. rodada  Empate | Sobreviventes 0 | Sem dano global"
	if local_combat_failsafe_triggered:
		last_round_result_summary += " | Failsafe"
	_emit_hud_update()

	_resolve_local_round_reward_cards(winner_team, damage_value)
	_remove_dead_runtime_units()
	_sync_lobby_life_values(false)
	_record_local_round_result(winner_team, damage_value)
	_sync_runtime_board_snapshots(_match_phase_name())
	_emit_hud_update()
	var local_player: MatchPlayerState = lobby_manager.get_player(LOCAL_PLAYER_ID)
	var opponent_player: MatchPlayerState = lobby_manager.get_player(current_opponent_player_id)
	if opponent_player != null and opponent_player.current_life <= 0:
		print("Resultado do lobby: %s foi reduzido a 0 de vida" % opponent_player.display_name)
	if local_player != null and local_player.current_life <= 0:
		print("Resultado do lobby: o jogador local chegou a 0 de vida")
	end_round()
	_battle_running = false
	awaiting_remote_round_settlement = lobby_manager.has_active_live_tables(current_round)
	remote_round_settlement_elapsed = 0.0
	remote_round_settlement_last_second = -1
	if awaiting_remote_round_settlement:
		var phase_counts: Dictionary = lobby_manager.count_live_table_phases(current_round)
		print("ROUND_RESULT: aguardando mesas vivas | prep=%d battle=%d result=%d" % [
			int(phase_counts.get("PREPARACAO", 0)),
			int(phase_counts.get("BATALHA", 0)),
			int(phase_counts.get("RESULTADO", 0)),
		])
		return
	_finalize_round_after_remote_tables()

func _update_remote_round_settlement(delta: float) -> void:
	if not awaiting_remote_round_settlement:
		return
	if lobby_manager.are_live_tables_resolved(current_round):
		awaiting_remote_round_settlement = false
		print("ROUND_RESULT: mesas vivas concluídas para a rodada %d" % current_round)
		_finalize_round_after_remote_tables()
		return

	remote_round_settlement_elapsed += delta
	var elapsed_second: int = int(floor(remote_round_settlement_elapsed))
	if elapsed_second != remote_round_settlement_last_second:
		remote_round_settlement_last_second = elapsed_second
		var phase_counts: Dictionary = lobby_manager.count_live_table_phases(current_round)
		print("ROUND_RESULT: aguardando mesas vivas | t=%ds | prep=%d battle=%d result=%d" % [
			elapsed_second,
			int(phase_counts.get("PREPARACAO", 0)),
			int(phase_counts.get("BATALHA", 0)),
			int(phase_counts.get("RESULTADO", 0)),
		])

	if remote_round_settlement_elapsed < ROUND_RESULT_SYNC_TIMEOUT_SECONDS:
		return

	print("FAILSAFE: mesas vivas excederam %.1fs | forçando encerramento da rodada %d" % [
		ROUND_RESULT_SYNC_TIMEOUT_SECONDS,
		current_round,
	])
	var background_results: Array[Dictionary] = lobby_manager.force_finish_live_tables(current_round)
	for result in background_results:
		print("LIVE_TABLE forced_result: %s" % str(result.get("result_text", "resultado resolvido")))
	awaiting_remote_round_settlement = false
	_finalize_round_after_remote_tables()

func _finalize_round_after_remote_tables() -> void:
	lobby_manager.process_eliminations_for_life_threshold(current_round)
	lobby_manager.finalize_match_if_needed(current_round)
	if current_state != GameEnums.BattleState.ROUND_END:
		end_round()
	if _is_match_finished():
		_show_match_final_screen()
		return
	var local_player: MatchPlayerState = _local_player_state()
	if local_player != null and local_player.eliminated and not local_post_elimination_observer_enabled:
		_show_local_elimination_screen()
		return

	current_round += 1
	print("Iniciando proxima rodada: %d" % current_round)
	_start_prep_phase()

func _resolve_local_round_reward_cards(winner_team: int, survivor_count: int) -> void:
	var won_round: bool = winner_team == GameEnums.TeamSide.PLAYER or winner_team == GameEnums.TeamSide.ENEMY
	if not won_round:
		return
	var winner_state: MatchPlayerState = _get_player_state_for_team(winner_team)
	var loser_team: int = GameEnums.TeamSide.ENEMY if winner_team == GameEnums.TeamSide.PLAYER else GameEnums.TeamSide.PLAYER
	var loser_state: MatchPlayerState = _get_player_state_for_team(loser_team)
	if winner_state == null:
		return

	var gained_lines: Array[String] = []
	var pending_bonus_gold: int = pending_player_bonus_gold_on_win if winner_team == GameEnums.TeamSide.PLAYER else pending_enemy_bonus_gold_on_win
	if pending_bonus_gold > 0:
		winner_state.add_bonus_next_round_gold(pending_bonus_gold)
		gained_lines.append("+%d ouro futuro" % pending_bonus_gold)
		print("OURO: %s ganhou +%d de ouro futuro" % [
			winner_state.display_name,
			pending_bonus_gold,
		])

	var pending_tribute_steal: int = pending_player_tribute_steal_on_win if winner_team == GameEnums.TeamSide.PLAYER else pending_enemy_tribute_steal_on_win
	if pending_tribute_steal > 0 and survivor_count > 0 and loser_state != null and loser_state.bonus_next_round_gold > 0:
		var stolen: int = mini(loser_state.bonus_next_round_gold, pending_tribute_steal)
		loser_state.bonus_next_round_gold -= stolen
		winner_state.add_bonus_next_round_gold(stolen)
		gained_lines.append("tributo %+d" % stolen)
		print("TRIBUTO: %s roubou %d de ouro futuro de %s" % [
			winner_state.display_name,
			stolen,
			loser_state.display_name,
		])

	if not gained_lines.is_empty():
		last_round_result_summary += " | " + _join_strings(gained_lines)

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

func _emit_hud_update() -> void:
	_sync_runtime_board_snapshots(_match_phase_name())
	var local_player: MatchPlayerState = _local_player_state()
	hud_update_requested.emit(
		current_round,
		player_global_life,
		gold_current,
		local_player.last_income_total if local_player != null else 0,
		"%s / %s" % [_match_phase_name(), _state_name()],
		_current_opponent_display_name()
	)
	if battle_hud:
		battle_hud.update_player_sidebar(_build_player_sidebar_entries())

func _build_player_sidebar_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var hide_current_opponent: bool = _should_hide_next_opponent_in_prep()
	for player_id in lobby_manager.get_player_ids():
		var player_state: MatchPlayerState = lobby_manager.get_player(player_id)
		if player_state == null:
			continue
		entries.append({
			"player_id": player_state.player_id,
			"name": player_state.display_name,
			"life": player_state.current_life,
			"is_local": player_state.player_id == LOCAL_PLAYER_ID,
			"is_current_opponent": not hide_current_opponent and player_state.player_id == current_opponent_player_id,
			"is_observed": observer_state.is_remote_view() and player_state.player_id == observer_state.observed_player_id,
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
	var opponent_master_name: String = "Sem mestre"
	var non_master_count: int = 0
	var enemy_unit_count: int = 0
	var opponent_player_id: String = LOCAL_PLAYER_ID if team_side == GameEnums.TeamSide.ENEMY else current_opponent_player_id
	var opponent_player: MatchPlayerState = lobby_manager.get_player(opponent_player_id)
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue

		var preview_coord: Vector2i = _coord_for_snapshot_perspective(unit_state.coord, team_side)
		var relative_team_side: int = GameEnums.TeamSide.PLAYER if unit_state.team_side == team_side else GameEnums.TeamSide.ENEMY
		var unit_path: String = ""
		if unit_state.unit_data != null and not unit_state.unit_data.resource_path.is_empty():
			unit_path = unit_state.unit_data.resource_path
		var unit_entry: Dictionary = {
			"unit_id": unit_state.unit_data.id if unit_state.unit_data != null else "",
			"unit_path": unit_path,
			"display_name": unit_state.get_display_name(),
			"coord": preview_coord,
			"team_side": relative_team_side,
			"is_master": unit_state.is_master,
			"class_label": unit_state.get_class_name(),
			"race_name": unit_state.get_race_name(),
			"cost": unit_state.unit_data.get_effective_cost() if unit_state.unit_data != null else 0,
			"current_hp": unit_state.current_hp,
			"max_hp": unit_state.unit_data.max_hp if unit_state.unit_data != null else 0,
			"current_mana": unit_state.current_mana,
			"mana_max": unit_state.get_mana_max(),
			"physical_attack": unit_state.get_physical_attack_value(),
			"magic_attack": unit_state.get_magic_attack_value(),
			"physical_defense": unit_state.get_physical_defense_value(),
			"magic_defense": unit_state.get_magic_defense_value(),
			"attack_range": unit_state.get_attack_range(),
			"crit_chance": unit_state.get_crit_chance(),
			"mana_gain_on_attack": unit_state.get_mana_gain_on_attack(),
			"mana_gain_on_hit": unit_state.get_mana_gain_on_hit(),
		}
		if unit_state.is_master and relative_team_side == GameEnums.TeamSide.PLAYER:
			units.insert(0, unit_entry)
			master_name = unit_state.get_display_name()
		elif unit_state.is_master and relative_team_side == GameEnums.TeamSide.ENEMY:
			units.append(unit_entry)
			opponent_master_name = unit_state.get_display_name()
		else:
			units.append(unit_entry)
			if relative_team_side == GameEnums.TeamSide.PLAYER:
				non_master_count += 1
			else:
				enemy_unit_count += 1
		total_power += _estimate_runtime_unit_power(unit_state)

	var gold_value: int = gold_current if team_side == GameEnums.TeamSide.PLAYER else enemy_gold_current
	var life_value: int = player_global_life if team_side == GameEnums.TeamSide.PLAYER else enemy_global_life
	var snapshot: Dictionary = {
		"player_id": player_id,
		"player_name": player_state.display_name,
		"opponent_id": opponent_player_id,
		"opponent_name": opponent_player.display_name if opponent_player != null else "Sem oponente",
		"round_number": current_round,
		"phase": phase_label,
		"life": life_value,
		"gold": gold_value,
		"gold_budget": maxi(0, gold_value),
		"units": units,
		"unit_count": units.size(),
		"non_master_count": non_master_count,
		"enemy_unit_count": enemy_unit_count,
		"power_rating": total_power,
		"master_name": master_name,
		"opponent_master_name": opponent_master_name,
		"owned_card_count": player_state.get_owned_card_paths().size(),
		"owned_card_names": _card_names_from_paths(player_state.get_owned_card_paths()),
		"summary": _runtime_snapshot_summary(units),
		"result_text": player_state.last_round_result_text,
	}
	lobby_manager.store_board_snapshot(player_id, snapshot)

func _coord_for_snapshot_perspective(coord: Vector2i, team_side: int) -> Vector2i:
	if team_side == GameEnums.TeamSide.ENEMY:
		return Vector2i(coord.x, BattleConfig.BOARD_HEIGHT - 1 - coord.y)
	return coord

func _card_names_from_paths(card_paths: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for card_path in card_paths:
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		names.append(card_data.display_name)
	return names

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
	power += unit_state.unit_data.get_effective_cost() * 12
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
		unit_cost = option.unit_data.get_effective_cost()

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
	if option != null and option.card_data != null:
		card_name = option.card_data.display_name

	return {
		"name": card_name,
		"cost": 0,
		"cost_label": "Gratis",
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
	var effective_cost: int = option.unit_data.get_effective_cost()
	if gold_current < effective_cost:
		return {
			"status": "NO GOLD",
			"reason": "custo %d > ouro %d" % [effective_cost, gold_current],
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
		deck_data.master_data_path,
		deck_data.unit_pool_paths.size(),
		deck_data.card_pool_paths.size(),
	])
	if deck_data.unit_pool_paths.is_empty():
		push_warning("BattleManager: %s deck has no deployable unit paths" % label)
	if deck_data.card_pool_paths.is_empty():
		push_warning("BattleManager: %s deck has no card pool paths" % label)

func _log_player_prep_pool_state() -> void:
	print("Pool do PREP do jogador: deploy_slots=%d card_slots=%d ready_deploy=%d" % [
		player_deploy_pool.size(),
		player_support_pool.size(),
		_count_ready_player_deploy_slots(),
	])
	if player_deploy_pool.is_empty():
		push_warning("BattleManager: player deploy pool is empty in PREP")

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

	for index in range(player_deck.unit_pool_paths.size()):
		var path: String = player_deck.unit_pool_paths[index]
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

	for index in range(enemy_deck.unit_pool_paths.size()):
		var path: String = enemy_deck.unit_pool_paths[index]
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
	var local_player: MatchPlayerState = lobby_manager.get_player(LOCAL_PLAYER_ID)
	if local_player == null:
		return

	var invalid_owned_paths: Array[String] = []
	for path in local_player.get_owned_card_paths():
		var card_data: CardData = _load_card_data(path)
		if card_data == null:
			invalid_owned_paths.append(path)
			continue
		var support_option: SupportOption = SupportOption.new(card_data, path)
		support_option.used = false
		player_support_pool.append(support_option)

	if not invalid_owned_paths.is_empty():
		print("SHOP_DEBUG invalid_owned_cards=[%s]" % _join_strings(invalid_owned_paths))

func try_open_card_shop_for_round(round_number: int) -> bool:
	if round_number <= 0:
		print("SHOP_CANCEL reason=invalid_round round=%d" % round_number)
		return false
	if round_number % 3 != 0:
		print("SHOP_CANCEL reason=round_not_multiple_of_3 round=%d" % round_number)
		return false

	var local_player: MatchPlayerState = _local_player_state()
	if local_player == null:
		print("SHOP_CANCEL reason=missing_local_player round=%d" % round_number)
		return false
	if local_player.eliminated:
		print("SHOP_CANCEL reason=local_eliminated round=%d" % round_number)
		return false
	if local_player.last_shop_round_claimed >= round_number:
		print("SHOP_CANCEL reason=already_resolved round=%d" % round_number)
		return false

	var shop_state: ShopState = _local_shop_state()
	if shop_state == null:
		print("SHOP_CANCEL reason=missing_shop_state round=%d" % round_number)
		return false

	var shop_details: Dictionary = _build_local_card_shop_offer_details(round_number)
	var offer_paths: Array[String] = shop_details.get("offer_paths", []).duplicate()
	if offer_paths.size() > 2:
		offer_paths.resize(2)
	var deck_path: String = str(shop_details.get("deck_path", ""))
	var raw_pool_paths: Array[String] = shop_details.get("raw_card_pool_paths", shop_details.get("card_pool_paths", [])).duplicate()
	var valid_pool_paths: Array[String] = shop_details.get("valid_card_pool_paths", []).duplicate()
	var invalid_pool_paths: Array[String] = shop_details.get("invalid_card_pool_paths", []).duplicate()
	print("SHOP_DEBUG deck=%s raw_pool=[%s]" % [deck_path, _join_strings(raw_pool_paths)])
	print("SHOP_DEBUG valid_cards=[%s]" % _join_strings(valid_pool_paths))
	print("SHOP_DEBUG invalid_cards=[%s]" % _join_strings(invalid_pool_paths))
	print("SHOP_DEBUG owned_cards=[%s]" % _join_strings(shop_details.get("owned_paths", [])))
	print("SHOP_DEBUG final_offer=[%s]" % _join_strings(offer_paths))
	if offer_paths.is_empty():
		print("SHOP_CANCEL reason=%s round=%d deck=%s raw_pool=[%s] valid_cards=[%s]" % [
			str(shop_details.get("reason", "empty_offer")),
			round_number,
			deck_path,
			_join_strings(raw_pool_paths),
			_join_strings(valid_pool_paths),
		])
		return false

	shop_state.begin_offer(round_number, offer_paths)
	card_shop_open = true
	selected_support_index = -1
	selected_deploy_index = -1
	_clear_drag_state()
	_clear_support_selection(false)
	_set_input_locked(true)

	var option_entries: Array[Dictionary] = []
	for card_path in pending_card_shop_paths:
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		option_entries.append({
			"card_path": card_path,
			"card_data": card_data,
		})

	if option_entries.is_empty():
		card_shop_open = false
		shop_state.clear_offer()
		_set_input_locked(false)
		print("SHOP_CANCEL reason=invalid_card_resources round=%d deck=%s final_offer=[%s]" % [
			round_number,
			deck_path,
			_join_strings(offer_paths),
		])
		return false

	if battle_hud:
		battle_hud.show_card_shop(round_number, option_entries)
	else:
		_on_card_shop_option_selected(str(option_entries[0].get("card_path", "")))
		return true

	_refresh_deploy_bar()
	_emit_hud_update()
	print("SHOP_OPEN round=%d options=[%s]" % [
		round_number,
		_join_strings(pending_card_shop_paths),
	])
	print("SHOP_INVENTORY player_cards=[%s]" % _join_strings(local_player.get_owned_card_paths()))
	return true

func _on_card_shop_option_selected(card_path: String) -> void:
	if not card_shop_open:
		return
	if card_path.is_empty():
		return
	if not pending_card_shop_paths.has(card_path):
		return

	var local_player: MatchPlayerState = lobby_manager.get_player(LOCAL_PLAYER_ID)
	if local_player == null:
		return

	var added_from_lobby: bool = lobby_manager.add_owned_card_to_player(LOCAL_PLAYER_ID, card_path)
	local_player.last_shop_round_claimed = current_round
	card_shop_open = false
	var shop_state: ShopState = _local_shop_state()
	if shop_state != null:
		shop_state.clear_offer()
	_set_input_locked(false)
	if battle_hud:
		battle_hud.hide_card_shop()

	_build_player_support_pool()
	_refresh_deploy_bar()
	_emit_hud_update()

	var chosen_card: CardData = _load_card_data(card_path)
	print("SHOP_CHOICE player=%s card=%s" % [
		local_player.player_id,
		chosen_card.display_name if chosen_card != null else card_path,
	])
	print("SHOP_INVENTORY player_cards=[%s]" % _join_strings(local_player.get_owned_card_paths()))
	if not added_from_lobby:
		print("SHOP: carta ja existia no inventario da partida")

func _build_local_card_shop_offer_details(round_number: int) -> Dictionary:
	var details: Dictionary = lobby_manager.build_card_shop_offer_details(LOCAL_PLAYER_ID, round_number, 2)
	var offer_paths: Array[String] = details.get("offer_paths", []).duplicate()
	if not offer_paths.is_empty():
		return details

	lobby_manager.set_player_deck_path(LOCAL_PLAYER_ID, _selected_player_deck_path(), false)
	details = lobby_manager.build_card_shop_offer_details(LOCAL_PLAYER_ID, round_number, 2)
	offer_paths = details.get("offer_paths", []).duplicate()
	if not offer_paths.is_empty():
		details["reason"] = "deck_resynced"
		return details

	var local_player: MatchPlayerState = _local_player_state()
	if local_player == null or player_deck == null:
		details["reason"] = "missing_local_player_or_player_deck"
		return details

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
		var card_data: CardData = _load_card_data(resolved_path)
		if card_data == null:
			invalid_pool_paths.append(resolved_path)
			continue
		valid_pool_paths.append(resolved_path)
		if local_player.has_owned_card_path(resolved_path):
			continue
		fallback_paths.append(resolved_path)
	fallback_paths.sort()
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

	if valid_pool_paths.size() > 2:
		valid_pool_paths.resize(2)
	details["offer_paths"] = valid_pool_paths
	details["available_paths"] = valid_pool_paths.duplicate()
	if valid_pool_paths.is_empty():
		details["reason"] = "fallback_no_valid_card_resources"
	elif valid_pool_paths.size() < 2:
		details["reason"] = "fallback_reused_owned_valid_cards_partial"
	else:
		details["reason"] = "fallback_reused_owned_valid_cards"
	return details

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
		if is_master:
			resolved_home_coord = _get_persistent_master_home_coord(team_side)
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

	if is_master:
		_set_persistent_master_home_coord(team_side, resolved_home_coord)
	_record_persistent_formation_unit(state)
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

func _find_runtime_unit_by_id(unit_id: String, team_side: int) -> BattleUnitState:
	for unit_state in runtime_units:
		if unit_state == null or unit_state.unit_data == null:
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state.is_summoned_token:
			continue
		if unit_state.unit_data.id == unit_id:
			return unit_state
	return null

func _clear_all_runtime_units() -> void:
	for unit_state in runtime_units:
		if unit_state != null:
			unit_state.clear_navigation_memory()
			board_grid.remove_unit(unit_state, true)
	runtime_units.clear()

func _remove_dead_runtime_units() -> void:
	var alive_units: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null:
			continue
		if unit_state.is_summoned_token and unit_state.is_dead():
			continue
		alive_units.append(unit_state)
	runtime_units = alive_units

func _on_deploy_slot_pressed(slot_index: int) -> void:
	if current_state != GameEnums.BattleState.PREP:
		return
	if card_shop_open:
		return
	if _block_observer_input("deploy_unit"):
		return
	_begin_deploy_drag(slot_index)

func _on_deploy_slot_right_clicked(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= player_deploy_pool.size():
		return

	_exit_observer_mode_if_needed(false)
	inspected_unit = null
	inspected_deploy_index = slot_index
	inspected_support_index = -1
	_refresh_inspected_unit_panel()

func _on_support_slot_pressed(slot_index: int) -> void:
	if current_state != GameEnums.BattleState.PREP:
		return
	if card_shop_open:
		return
	if _block_observer_input("use_card"):
		return
	_select_support_slot(slot_index)

func _on_support_slot_right_clicked(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= player_support_pool.size():
		return

	_exit_observer_mode_if_needed(false)
	inspected_unit = null
	inspected_deploy_index = -1
	inspected_support_index = slot_index
	_refresh_inspected_unit_panel()

func _select_deploy_slot(index: int) -> void:
	if card_shop_open:
		return
	if _block_observer_input("deploy_hotkey"):
		return
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
	print("Deploy selecionado: slot=%d unidade=%s custo=%d ouro=%d" % [
		index + 1,
		option.unit_data.id,
		option.unit_data.get_effective_cost(),
		gold_current,
	])

func _select_support_slot(index: int) -> void:
	if card_shop_open:
		return
	if _block_observer_input("use_card"):
		return
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
	print("Support armado: slot=%d carta=%s gratis ouro=%d" % [
		index + 1,
		option.card_data.display_name,
		gold_current,
	])
	print("Alvos de support prontos: %d celulas destacadas" % valid_target_count)

func _support_card_is_instant(card_data: CardData) -> bool:
	if card_data == null:
		return false
	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			return true
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			return true
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			return true
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			return true
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			return true
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			return true
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			return true
		_:
			return false

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
	var effective_cost: int = option.unit_data.get_effective_cost()
	if gold_current < effective_cost:
		return {"ok": false, "reason": "ouro insuficiente"}
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
	var effective_cost: int = option.unit_data.get_effective_cost()
	if enemy_gold_current < effective_cost:
		return {"ok": false, "reason": "ouro inimigo insuficiente"}
	return {"ok": true, "reason": ""}

func _deploy_slot_to_coord(slot_index: int, coord: Vector2i) -> bool:
	if _block_observer_input("buy_unit"):
		return false
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
	var deployed_cost: int = option.unit_data.get_effective_cost()
	gold_current -= deployed_cost
	_remove_value(player_units_sold_last_round, state.get_combat_label())
	_record_persistent_formation_unit(state)
	print("Home coord registered: %s -> %s" % [state.get_combat_label(), state.home_coord])

	print("Deploy concluido: %s em %s | ouro_restante=%d" % [
		state.get_combat_label(),
		coord,
		gold_current,
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
	var deployed_cost: int = option.unit_data.get_effective_cost()
	enemy_gold_current -= deployed_cost
	_record_persistent_formation_unit(state)
	print("Deploy inimigo: %s em %s | ouro_inimigo_restante=%d" % [
		state.get_combat_label(),
		coord,
		enemy_gold_current,
	])
	return true

func _auto_prepare_enemy_board() -> void:
	if enemy_deploy_pool.is_empty():
		return

	var deploy_plan: Dictionary = enemy_prep_planner.build_deploy_orders(
		board_grid,
		enemy_deploy_pool,
		enemy_gold_current,
		_count_non_master_units(GameEnums.TeamSide.ENEMY),
		BattleConfig.MAX_FIELD_UNITS,
		current_round
	)
	var deploy_orders: Array[Dictionary] = deploy_plan.get("orders", [])
	var enemy_field_limit: int = int(deploy_plan.get("field_limit", BattleConfig.MAX_FIELD_UNITS))
	var enemy_gold_budget: int = int(deploy_plan.get("gold_budget", enemy_gold_current))
	if bool(deploy_plan.get("fairness_active", false)):
		print("Justica do PREP inimigo ativa: rodada=%d limite_de_campo=%d ouro_efetivo=%d" % [
			current_round,
			enemy_field_limit,
			enemy_gold_budget,
		])
	for order in deploy_orders:
		_deploy_enemy_slot_to_coord(
			int(order.get("slot_index", -1)),
			order.get("coord", Vector2i(-1, -1))
		)

	print("PREP automatico do inimigo: %d deploys aplicados" % deploy_orders.size())

func _auto_use_enemy_support_cards() -> void:
	var opponent_state: MatchPlayerState = lobby_manager.get_player(current_opponent_player_id)
	if opponent_state == null:
		return

	var card_entries: Array[Dictionary] = []
	for card_path in opponent_state.get_owned_card_paths():
		var card_data: CardData = _load_card_data(card_path)
		if card_data == null:
			continue
		card_entries.append({
			"card_data": card_data,
			"card_path": card_path,
		})

	if card_entries.is_empty():
		return

	var allied_units: Array[Dictionary] = _build_bot_card_unit_entries(GameEnums.TeamSide.ENEMY)
	var enemy_units: Array[Dictionary] = _build_bot_card_unit_entries(GameEnums.TeamSide.PLAYER)
	var debug_tag: String = current_opponent_player_id if not current_opponent_player_id.is_empty() else "enemy_local"
	var card_orders: Array[Dictionary] = enemy_prep_planner.build_card_orders(
		card_entries,
		allied_units,
		enemy_units,
		GameEnums.TeamSide.ENEMY,
		debug_tag
	)
	for order in card_orders:
		var card_data: CardData = order.get("card_data", null)
		if card_data == null:
			continue
		var target_type: String = str(order.get("target_type", ""))
		if target_type == "instant":
			_apply_instant_support_card_effect_for_team(card_data, GameEnums.TeamSide.ENEMY)
			print("PREP inimigo usou support instantaneo gratis: %s" % card_data.display_name)
			continue
		if target_type == "coord":
			var target_coord: Vector2i = order.get("target_coord", Vector2i(-1, -1))
			if not board_grid.is_valid_coord(target_coord):
				continue
			_apply_support_card_effect_on_coord_for_team(card_data, target_coord, GameEnums.TeamSide.ENEMY)
			print("PREP inimigo usou support de celula gratis: %s em %s" % [
				card_data.display_name,
				target_coord,
			])
			continue
		var target_unit: BattleUnitState = _find_runtime_unit_for_team_coord(
			GameEnums.TeamSide.ENEMY,
			order.get("target_coord", Vector2i(-1, -1))
		)
		if target_unit == null:
			continue
		_apply_support_card_effect_for_team(card_data, target_unit, GameEnums.TeamSide.ENEMY)
		print("PREP inimigo usou support gratis: %s em %s" % [
			card_data.display_name,
			target_unit.get_combat_label(),
		])

func _build_bot_card_unit_entries(team_side: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act() or unit_state.team_side != team_side:
			continue
		if unit_state.unit_data == null:
			continue
		entries.append({
			"unit_data": unit_state.unit_data,
			"unit_id": unit_state.unit_data.id,
			"display_name": unit_state.get_display_name(),
			"race": unit_state.unit_data.race,
			"class_type": unit_state.unit_data.class_type,
			"cost": unit_state.unit_data.get_effective_cost(),
			"coord": unit_state.coord,
			"team_side": team_side,
			"is_master": unit_state.is_master,
			"attack_range": unit_state.get_attack_range(),
			"physical_attack": unit_state.get_physical_attack_value(),
			"magic_attack": unit_state.get_magic_attack_value(),
			"physical_defense": unit_state.get_physical_defense_value(),
			"magic_defense": unit_state.get_magic_defense_value(),
			"max_hp": unit_state.unit_data.max_hp,
			"current_hp": unit_state.current_hp,
		})
	return entries

func _find_runtime_unit_for_team_coord(team_side: int, target_coord: Vector2i) -> BattleUnitState:
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act() or unit_state.team_side != team_side:
			continue
		if unit_state.coord == target_coord:
			return unit_state
	return null

func _auto_pick_support_target_for_team(card_data: CardData, owner_team_side: int) -> BattleUnitState:
	if card_data == null:
		return null
	var best_target: BattleUnitState = null
	var best_score: int = -100000
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != owner_team_side:
			continue
		var score: int = unit_state.current_hp
		match card_data.support_effect_type:
			GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
				if unit_state.is_master:
					return unit_state
				continue
			GameEnums.SupportCardEffectType.UNIT_ATTACK_BUFF:
				score += unit_state.get_physical_attack_value() * 10
			GameEnums.SupportCardEffectType.MAGIC_ATTACK_MULTIPLIER:
				score += unit_state.get_magic_attack_value() * 12
			GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
				score += unit_state.get_magic_attack_value() * 10
				score += unit_state.get_mana_max() * 3
			GameEnums.SupportCardEffectType.START_STEALTH:
				score += unit_state.get_physical_attack_value() * 9
				if unit_state.is_master:
					score -= 25
			GameEnums.SupportCardEffectType.DEATH_MANA_PACT:
				if unit_state.unit_data != null:
					score += unit_state.unit_data.max_hp * 4
				if unit_state.is_master:
					score -= 18
			GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
				score += unit_state.get_physical_defense_value() * 10
			GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
				score += unit_state.get_physical_attack_value() * 12
			GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
				score += unit_state.get_physical_attack_value() * 14
			_:
				score += unit_state.get_attack_value() * 4
		if best_target == null or score > best_score:
			best_target = unit_state
			best_score = score
	return best_target

func _auto_pick_support_coord_for_team(card_data: CardData, owner_team_side: int) -> Vector2i:
	if card_data == null:
		return Vector2i(-1, -1)
	var target_team_side: int = GameEnums.TeamSide.PLAYER if owner_team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	var best_target: BattleUnitState = null
	var best_score: int = -100000
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != target_team_side:
			continue
		var score: int = unit_state.get_attack_value() * 10 + unit_state.current_hp
		if best_target == null or score > best_score:
			best_target = unit_state
			best_score = score
	if best_target != null:
		return best_target.coord
	return Vector2i(-1, -1)

func _try_deploy_selected_at(coord: Vector2i) -> void:
	if _block_observer_input("deploy_unit"):
		return
	if selected_deploy_index < 0 or selected_deploy_index >= player_deploy_pool.size():
		return
	if _deploy_slot_to_coord(selected_deploy_index, coord):
		selected_deploy_index = -1
	_refresh_deploy_bar()
	_emit_hud_update()

func _try_use_selected_support_on_target(target: BattleUnitState) -> void:
	if _block_observer_input("use_card"):
		return
	if selected_support_index < 0 or selected_support_index >= player_support_pool.size():
		return

	var option: SupportOption = player_support_pool[selected_support_index]
	var use_check: Dictionary = _can_use_support_option_on_target(option, target)
	if not bool(use_check.get("ok", false)):
		print("Support bloqueado: %s" % str(use_check.get("reason", "alvo invalido")))
		_refresh_targeting_preview()
		return

	option.used = true
	_apply_support_card_effect(option.card_data, target)
	print("Support usado gratis: %s em %s" % [
		option.card_data.display_name,
		target.get_combat_label(),
	])
	selected_support_index = -1
	if board_grid:
		board_grid.clear_target_highlights()
	_refresh_deploy_bar()
	_emit_hud_update()
	_refresh_inspected_unit_panel()

func _try_use_selected_support_on_coord(coord: Vector2i) -> void:
	if _block_observer_input("use_card"):
		return
	if selected_support_index < 0 or selected_support_index >= player_support_pool.size():
		return

	var option: SupportOption = player_support_pool[selected_support_index]
	var use_check: Dictionary = _can_use_support_option_on_coord(option, coord)
	if not bool(use_check.get("ok", false)):
		print("Support bloqueado: %s" % str(use_check.get("reason", "alvo invalido")))
		_refresh_targeting_preview()
		return

	option.used = true
	_apply_support_card_effect_on_coord(option.card_data, coord)
	print("Support usado gratis: %s na celula %s" % [
		option.card_data.display_name,
		coord,
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

	option.used = true
	_apply_instant_support_card_effect(option.card_data)
	print("Support usado gratis: %s" % option.card_data.display_name)
	return true

func _can_use_support_option_on_target(option: SupportOption, target: BattleUnitState) -> Dictionary:
	if current_state != GameEnums.BattleState.PREP:
		return {"ok": false, "reason": "supports so estao disponiveis no PREP"}
	if option == null or option.card_data == null:
		return {"ok": false, "reason": "support invalido"}
	if option.used:
		return {"ok": false, "reason": "support ja usado nesta rodada"}
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
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			return {"ok": true, "reason": ""}
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			return {"ok": true, "reason": ""}
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			return {"ok": true, "reason": ""}
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
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
	if not board_grid.is_valid_coord(coord):
		return {"ok": false, "reason": "selecione uma celula valida no tabuleiro"}

	match option.card_data.support_effect_type:
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			if not board_grid.is_coord_in_team_zone(coord, GameEnums.TeamSide.ENEMY):
				return {"ok": false, "reason": "Prisao de Ossos precisa mirar no lado inimigo"}
			return {"ok": true, "reason": ""}
		_:
			return {"ok": false, "reason": "efeito de support com celula nao suportado"}

func _apply_support_card_effect(card_data: CardData, target: BattleUnitState) -> void:
	_apply_support_card_effect_for_team(card_data, target, GameEnums.TeamSide.PLAYER)

func _apply_support_card_effect_for_team(card_data: CardData, target: BattleUnitState, owner_team_side: int) -> void:
	if card_data == null or target == null:
		return

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.PLAYER_LIFE_HEAL:
			var before: int = player_global_life if owner_team_side == GameEnums.TeamSide.PLAYER else enemy_global_life
			if owner_team_side == GameEnums.TeamSide.PLAYER:
				player_global_life = mini(BattleConfig.GLOBAL_LIFE, player_global_life + card_data.global_life_heal)
			else:
				enemy_global_life = mini(BattleConfig.GLOBAL_LIFE, enemy_global_life + card_data.global_life_heal)
			var current_life: int = player_global_life if owner_team_side == GameEnums.TeamSide.PLAYER else enemy_global_life
			var healed_life: int = current_life - before
			_emit_global_life_changed(owner_team_side, current_life)
			if target.actor:
				target.actor.on_heal()
			print("EFEITO DE SUPPORT: %s restaurou %d de vida global via %s (Vida atual: %d)" % [
				card_data.display_name,
				healed_life,
				target.get_combat_label(),
				current_life,
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
		GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
			var defense_bonus: int = int(ceil(float(target.get_physical_defense_value()) * (card_data.physical_defense_multiplier - 1.0)))
			target.add_round_stat_bonus(0, 0, defense_bonus, 0)
			if target.actor:
				target.actor.on_buff()
			print("EFEITO DE SUPPORT: %s reforcou %s (+%d DEF F nesta rodada)" % [
				card_data.display_name,
				target.get_combat_label(),
				defense_bonus,
			])
		GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
			var attack_bonus: int = int(ceil(float(target.get_physical_attack_value()) * (card_data.physical_attack_multiplier - 1.0)))
			target.add_round_stat_bonus(attack_bonus, 0, 0, 0)
			target.apply_attack_range_bonus(maxi(0, card_data.attack_range_bonus), maxi(1, card_data.effect_duration_turns))
			if target.actor:
				target.actor.on_buff()
			print("EFEITO DE SUPPORT: %s armou %s (+%d ATQ F, +%d alcance)" % [
				card_data.display_name,
				target.get_combat_label(),
				attack_bonus,
				card_data.attack_range_bonus,
			])
		GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
			target.apply_mana_gain_multiplier(
				maxf(1.0, card_data.mana_gain_multiplier),
				maxi(1, card_data.effect_duration_turns)
			)
			if target.actor:
				target.actor.on_buff()
			print("EFEITO DE SUPPORT: %s acelerou a mana de %s (x%.2f por %d turnos)" % [
				card_data.display_name,
				target.get_combat_label(),
				maxf(1.0, card_data.mana_gain_multiplier),
				maxi(1, card_data.effect_duration_turns),
			])
		GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
			target.apply_lifesteal_ratio(
				maxf(0.0, card_data.lifesteal_ratio),
				maxi(1, card_data.effect_duration_turns)
			)
			if target.actor:
				target.actor.on_buff()
			print("EFEITO DE SUPPORT: %s concedeu roubo de vida a %s (%d%% por %d turnos)" % [
				card_data.display_name,
				target.get_combat_label(),
				int(round(maxf(0.0, card_data.lifesteal_ratio) * 100.0)),
				maxi(1, card_data.effect_duration_turns),
			])

	_refresh_actor_state(target)
	_refresh_targeting_preview()

func _apply_support_card_effect_on_coord(card_data: CardData, coord: Vector2i) -> void:
	_apply_support_card_effect_on_coord_for_team(card_data, coord, GameEnums.TeamSide.PLAYER)

func _apply_support_card_effect_on_coord_for_team(card_data: CardData, coord: Vector2i, owner_team_side: int) -> void:
	if card_data == null:
		return

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.CELL_TRAP_STUN:
			bone_prison_coord = coord
			bone_prison_owner_team = owner_team_side
			bone_prison_stun_turns = maxi(1, card_data.stun_turns)
			bone_prison_mana_gain_multiplier = clampf(card_data.mana_gain_multiplier, 0.0, 1.0)
			print("EFEITO DE SUPPORT: %s foi armado na celula inimiga %s" % [
				card_data.display_name,
				coord,
			])

func _apply_instant_support_card_effect(card_data: CardData) -> void:
	_apply_instant_support_card_effect_for_team(card_data, GameEnums.TeamSide.PLAYER)

func _apply_instant_support_card_effect_for_team(card_data: CardData, owner_team_side: int) -> void:
	if card_data == null:
		return

	match card_data.support_effect_type:
		GameEnums.SupportCardEffectType.DELAYED_BLIND_FIELD:
			pending_blinding_mist_turn = randi_range(
				maxi(1, card_data.delayed_trigger_min_turn),
				maxi(card_data.delayed_trigger_min_turn, card_data.delayed_trigger_max_turn)
			)
			pending_blinding_mist_team = owner_team_side
			pending_blinding_mist_duration_turns = maxi(1, card_data.effect_duration_turns)
			pending_blinding_mist_physical_miss_chance = clampf(card_data.physical_miss_chance, 0.0, 1.0)
			print("EFEITO DE SUPPORT: %s sera ativado por volta do turno %d de batalha" % [
				card_data.display_name,
				pending_blinding_mist_turn,
			])
		GameEnums.SupportCardEffectType.CONDITIONAL_NEXT_ROUND_GOLD:
			if owner_team_side == GameEnums.TeamSide.PLAYER:
				pending_player_bonus_gold_on_win = maxi(pending_player_bonus_gold_on_win, card_data.bonus_next_round_gold)
			else:
				pending_enemy_bonus_gold_on_win = maxi(pending_enemy_bonus_gold_on_win, card_data.bonus_next_round_gold)
			print("EFEITO DE SUPPORT: %s ficou aguardando vitoria para render +%d de ouro" % [
				card_data.display_name,
				card_data.bonus_next_round_gold,
			])
		GameEnums.SupportCardEffectType.CONDITIONAL_TRIBUTE_STEAL:
			if owner_team_side == GameEnums.TeamSide.PLAYER:
				pending_player_tribute_steal_on_win = maxi(pending_player_tribute_steal_on_win, card_data.tribute_steal_amount)
			else:
				pending_enemy_tribute_steal_on_win = maxi(pending_enemy_tribute_steal_on_win, card_data.tribute_steal_amount)
			print("EFEITO DE SUPPORT: %s ficou aguardando vitoria com dano ao Mestre para tributar %d" % [
				card_data.display_name,
				card_data.tribute_steal_amount,
			])
		GameEnums.SupportCardEffectType.OPENING_REPOSITION:
			if owner_team_side == GameEnums.TeamSide.PLAYER:
				pending_player_opening_reposition = true
			else:
				pending_enemy_opening_reposition = true
			print("EFEITO DE SUPPORT: %s vai reposicionar um inimigo no inicio do combate" % card_data.display_name)
		GameEnums.SupportCardEffectType.OPENING_ACTION_SLOW_FIELD:
			opening_action_slow_states[owner_team_side] = {
				"multiplier": clampf(card_data.action_charge_multiplier, 0.1, 1.0),
				"duration_turns": maxi(1, card_data.effect_duration_turns),
				"card_name": card_data.display_name,
			}
			print("EFEITO DE SUPPORT: %s vai reduzir o ritmo inicial do time inimigo" % card_data.display_name)
		GameEnums.SupportCardEffectType.PERIODIC_RANDOM_MAGIC_FIELD:
			periodic_magic_field_states[owner_team_side] = {
				"interval_turns": maxi(1, card_data.periodic_interval_turns),
				"next_trigger_turn": maxi(1, card_data.periodic_interval_turns),
				"remaining_triggers": maxi(1, card_data.effect_repeat_count),
				"damage_amount": maxi(1, card_data.damage_amount),
				"card_name": card_data.display_name,
			}
			print("EFEITO DE SUPPORT: %s vai disparar dano periodico no campo inimigo" % card_data.display_name)
		GameEnums.SupportCardEffectType.CONDITIONAL_SUMMON_ON_FIRST_ALLY_DEATH:
			if not card_data.summon_unit_path.is_empty():
				first_ally_death_summon_states[owner_team_side] = {
					"unit_path": card_data.summon_unit_path,
					"hp_ratio": clampf(card_data.summon_current_hp_ratio, 0.1, 1.0),
					"card_name": card_data.display_name,
				}
				print("EFEITO DE SUPPORT: %s ficou aguardando a primeira baixa aliada" % card_data.display_name)

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
			GameEnums.SupportCardEffectType.PHYSICAL_DEFENSE_RATIO_BUFF:
				valid_coords.append(unit_state.coord)
			GameEnums.SupportCardEffectType.PHYSICAL_ATTACK_RANGE_BUFF:
				valid_coords.append(unit_state.coord)
			GameEnums.SupportCardEffectType.UNIT_MANA_REGEN_BUFF:
				valid_coords.append(unit_state.coord)
			GameEnums.SupportCardEffectType.UNIT_LIFESTEAL_GIFT:
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
	if _block_observer_input("sell_unit"):
		return
	var sell_check: Dictionary = _can_sell_unit(unit_state)
	var sell_ok: bool = bool(sell_check.get("ok", false))
	var sell_reason: String = str(sell_check.get("reason", ""))

	if not sell_ok:
		print("Venda bloqueada: %s" % sell_reason)
		return

	var refund: int = unit_state.unit_data.get_effective_cost() / 2
	gold_current += refund
	board_grid.remove_unit(unit_state, true)
	runtime_units.erase(unit_state)
	_remove_persistent_formation_unit(unit_state)
	_release_pool_slot_for_unit(unit_state.unit_data.id)
	_append_unique(player_units_sold_last_round, unit_state.get_combat_label())

	if inspected_unit == unit_state:
		_clear_inspected_context()

	print("Venda concluida: %s por %d de ouro | ouro_agora=%d" % [
		unit_state.get_combat_label(),
		refund,
		gold_current,
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
			_clear_target_locks_for_unit(unit_state)
			board_grid.remove_unit(unit_state, true)
			continue
		remaining_units.append(unit_state)
	runtime_units = remaining_units

func _trigger_battle_turn_effects() -> void:
	battle_turn_index += 1
	if pending_blinding_mist_turn > 0 and battle_turn_index == pending_blinding_mist_turn:
		_trigger_blinding_mist()
	_trigger_periodic_magic_fields()
	_trigger_dama_passive_heals()

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

	print("EFEITO DE CAMPO: Nevoa Cegante atingiu %s unidades do time %d por %d turnos" % [
		_count_living_team(affected_team),
		affected_team,
		pending_blinding_mist_duration_turns,
	])
	pending_blinding_mist_turn = -1
	pending_blinding_mist_team = -1
	pending_blinding_mist_duration_turns = 2
	pending_blinding_mist_physical_miss_chance = 0.5

func _trigger_periodic_magic_fields() -> void:
	var expired_team_sides: Array[int] = []
	for team_side_variant in periodic_magic_field_states.keys():
		var owner_team_side: int = int(team_side_variant)
		var field_state: Dictionary = periodic_magic_field_states.get(owner_team_side, {})
		if field_state.is_empty():
			expired_team_sides.append(owner_team_side)
			continue
		var next_trigger_turn: int = int(field_state.get("next_trigger_turn", 0))
		if next_trigger_turn <= 0 or battle_turn_index < next_trigger_turn:
			continue
		var target_team_side: int = GameEnums.TeamSide.ENEMY if owner_team_side == GameEnums.TeamSide.PLAYER else GameEnums.TeamSide.PLAYER
		var enemy_units: Array[BattleUnitState] = []
		for unit_state in runtime_units:
			if unit_state == null or not unit_state.can_act():
				continue
			if unit_state.team_side != target_team_side:
				continue
			enemy_units.append(unit_state)
		if enemy_units.is_empty():
			expired_team_sides.append(owner_team_side)
			continue
		var target: BattleUnitState = enemy_units[randi() % enemy_units.size()]
		var damage_value: int = maxi(1, int(field_state.get("damage_amount", 1)))
		target.take_damage(damage_value)
		if target.actor:
			target.actor.on_damage()
		print("EFEITO DE CAMPO: %s atingiu %s por %d de dano magico" % [
			str(field_state.get("card_name", "Campo magico")),
			target.get_combat_label(),
			damage_value,
		])
		_refresh_actor_state(target)
		if target.is_dead():
			_handle_unit_death(target)
		var remaining_triggers: int = maxi(0, int(field_state.get("remaining_triggers", 0)) - 1)
		if remaining_triggers <= 0:
			expired_team_sides.append(owner_team_side)
			continue
		field_state["remaining_triggers"] = remaining_triggers
		field_state["next_trigger_turn"] = battle_turn_index + maxi(1, int(field_state.get("interval_turns", 1)))
		periodic_magic_field_states[owner_team_side] = field_state
	for team_side in expired_team_sides:
		periodic_magic_field_states.erase(team_side)

func _trigger_dama_passive_heals() -> void:
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.unit_data == null or unit_state.unit_data.id != "lady_of_lake_master":
			continue
		var heal_target: BattleUnitState = _find_most_injured_ally(unit_state, true)
		if heal_target == null:
			continue
		var heal_amount: int = maxi(DAMA_PASSIVE_MIN_HEAL, int(round(float(unit_state.get_magic_attack_value()) * DAMA_PASSIVE_HEAL_RATIO)))
		var healed: int = heal_target.heal(heal_amount)
		if healed <= 0:
			continue
		if heal_target.actor:
			heal_target.actor.on_heal()
		print("AGUAS DA VIDA: %s curou %s em %d PV" % [
			unit_state.get_combat_label(),
			heal_target.get_combat_label(),
			healed,
		])
		_refresh_actor_state(heal_target)

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
	print("EFEITO DE ARMADILHA: Prisao de Ossos prendeu %s em %s por %d turnos" % [
		trapped_unit.get_combat_label(),
		bone_prison_coord,
		bone_prison_stun_turns,
	])
	bone_prison_coord = Vector2i(-1, -1)
	bone_prison_stun_turns = 2
	bone_prison_mana_gain_multiplier = 0.0

func _apply_opening_reposition_effects() -> void:
	if pending_player_opening_reposition:
		_trigger_opening_reposition_for_team(GameEnums.TeamSide.PLAYER)
	if pending_enemy_opening_reposition:
		_trigger_opening_reposition_for_team(GameEnums.TeamSide.ENEMY)
	pending_player_opening_reposition = false
	pending_enemy_opening_reposition = false
	_apply_opening_action_slow_effects()

func _apply_opening_action_slow_effects() -> void:
	for team_side_variant in opening_action_slow_states.keys():
		_trigger_opening_action_slow_for_team(int(team_side_variant))
	opening_action_slow_states.clear()

func _trigger_opening_action_slow_for_team(owner_team_side: int) -> void:
	var effect_state: Dictionary = opening_action_slow_states.get(owner_team_side, {})
	if effect_state.is_empty():
		return
	var target_team_side: int = GameEnums.TeamSide.ENEMY if owner_team_side == GameEnums.TeamSide.PLAYER else GameEnums.TeamSide.PLAYER
	var multiplier: float = clampf(float(effect_state.get("multiplier", 1.0)), 0.1, 1.0)
	var duration_turns: int = maxi(1, int(effect_state.get("duration_turns", 1)))
	var affected_count: int = 0
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != target_team_side:
			continue
		unit_state.apply_action_charge_multiplier(multiplier, duration_turns)
		_refresh_actor_state(unit_state)
		affected_count += 1
	if affected_count > 0:
		print("EFEITO DE CAMPO: %s reduziu o ritmo de %d inimigos para %.0f%% por %d turnos" % [
			str(effect_state.get("card_name", "Agua Fria")),
			affected_count,
			multiplier * 100.0,
			duration_turns,
		])

func _trigger_opening_reposition_for_team(owner_team_side: int) -> void:
	var target_team_side: int = GameEnums.TeamSide.ENEMY if owner_team_side == GameEnums.TeamSide.PLAYER else GameEnums.TeamSide.PLAYER
	var target_candidates: Array[BattleUnitState] = []
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != target_team_side:
			continue
		if unit_state.is_master:
			continue
		target_candidates.append(unit_state)
	if target_candidates.is_empty():
		return

	var target: BattleUnitState = target_candidates[randi() % target_candidates.size()]
	var destination: Vector2i = _find_random_free_coord_for_team(owner_team_side)
	if not board_grid.is_valid_coord(destination):
		return
	if board_grid.move_unit(target, destination):
		print("TORNADO: %s foi arrastado para %s" % [
			target.get_combat_label(),
			destination,
		])
		_refresh_race_synergy_state(false)

func _find_random_free_coord_for_team(team_side: int) -> Vector2i:
	var free_coords: Array[Vector2i] = []
	for y in range(BattleConfig.BOARD_HEIGHT):
		for x in range(BattleConfig.BOARD_WIDTH):
			var coord := Vector2i(x, y)
			if not board_grid.is_valid_coord(coord):
				continue
			if not board_grid.is_coord_in_team_zone(coord, team_side):
				continue
			if not board_grid.is_cell_free(coord):
				continue
			free_coords.append(coord)
	if free_coords.is_empty():
		return Vector2i(-1, -1)
	return free_coords[randi() % free_coords.size()]

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

func _find_enemy_with_highest_magic_attack(team_side: int) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side == team_side:
			continue
		if unit_state.is_stealthed():
			continue
		var attack_value: int = unit_state.get_magic_attack_value()
		if attack_value > best_value:
			best_value = attack_value
			best_target = unit_state
	return best_target

func _find_strongest_enemy_for_team(team_side: int) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side == team_side:
			continue
		if unit_state.is_stealthed():
			continue
		var power_value: int = unit_state.get_attack_value() + unit_state.get_defense_value() + unit_state.current_hp
		if power_value > best_value:
			best_value = power_value
			best_target = unit_state
	return best_target

func _find_ally_with_highest_physical_attack(team_side: int, exclude_unit: BattleUnitState = null) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state == exclude_unit:
			continue
		var attack_value: int = unit_state.get_physical_attack_value()
		if attack_value > best_value:
			best_value = attack_value
			best_target = unit_state
	return best_target

func _find_adjacent_ally_with_highest_physical_attack(source: BattleUnitState) -> BattleUnitState:
	if source == null or board_grid == null:
		return null
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for coord in board_grid.get_adjacent_coords(source.coord):
		var ally: BattleUnitState = board_grid.get_unit_at(coord)
		if ally == null or not ally.can_act():
			continue
		if ally.team_side != source.team_side or ally == source:
			continue
		var attack_value: int = ally.get_physical_attack_value()
		if attack_value > best_value:
			best_value = attack_value
			best_target = ally
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

func _find_best_adjacent_coord_to_target(target: BattleUnitState, moving_team_side: int, reference_coord: Vector2i) -> Vector2i:
	if target == null or board_grid == null:
		return Vector2i(-1, -1)
	var best_coord: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1000000
	for coord in board_grid.get_adjacent_coords(target.coord):
		if not board_grid.is_cell_free(coord):
			continue
		var score: int = board_grid.distance_between_cells(coord, reference_coord)
		if moving_team_side == GameEnums.TeamSide.PLAYER:
			score += maxi(0, coord.y - target.coord.y) * 10
		else:
			score += maxi(0, target.coord.y - coord.y) * 10
		if score < best_score:
			best_score = score
			best_coord = coord
	return best_coord

func _grant_team_next_round_gold(team_side: int, amount: int, source_label: String) -> void:
	if amount <= 0:
		return
	var player_state: MatchPlayerState = _get_player_state_for_team(team_side)
	if player_state == null:
		return
	player_state.add_bonus_next_round_gold(amount)
	print("OURO: %s garantiu +%d de ouro futuro via %s" % [
		player_state.display_name,
		amount,
		source_label,
	])

func _record_local_round_result(winner_team: int, damage_value: int) -> void:
	var local_player: MatchPlayerState = _local_player_state()
	var opponent_player: MatchPlayerState = lobby_manager.get_player(current_opponent_player_id)
	if local_player == null:
		return

	var opponent_name: String = opponent_player.display_name if opponent_player != null else _current_opponent_display_name()
	var local_result_text: String = "Empate contra %s" % opponent_name
	var opponent_result_text: String = "Empate contra %s" % local_player.display_name
	var local_damage_taken: int = 0
	var opponent_damage_taken: int = 0

	if winner_team == GameEnums.TeamSide.PLAYER:
		local_result_text = "%s venceu %s e causou %d de dano" % [
			local_player.display_name,
			opponent_name,
			damage_value,
		]
		opponent_result_text = "%s perdeu para %s e sofreu %d de dano" % [
			opponent_name,
			local_player.display_name,
			damage_value,
		]
		opponent_damage_taken = damage_value
	elif winner_team == GameEnums.TeamSide.ENEMY:
		local_result_text = "%s perdeu para %s e sofreu %d de dano" % [
			local_player.display_name,
			opponent_name,
			damage_value,
		]
		opponent_result_text = "%s venceu %s e causou %d de dano" % [
			opponent_name,
			local_player.display_name,
			damage_value,
		]
		local_damage_taken = damage_value

	local_player.record_round_result(current_round, local_result_text, winner_team == GameEnums.TeamSide.PLAYER, local_damage_taken)
	local_player.eliminated = local_player.current_life <= 0
	local_player.set_round_phase("RESULTADO")
	if opponent_player != null:
		opponent_player.record_round_result(current_round, opponent_result_text, winner_team == GameEnums.TeamSide.ENEMY, opponent_damage_taken)
		opponent_player.eliminated = opponent_player.current_life <= 0
		opponent_player.set_round_phase("RESULTADO")

func _process_unit_turn(acting_unit: BattleUnitState) -> Dictionary:
	var turn_result: Dictionary = {"outcome": "stuck"}
	if acting_unit == null or not acting_unit.can_act():
		return turn_result
	local_combat_actions_taken += 1

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

	var target_lock_turns: int = _get_target_lock_turns_for_unit(acting_unit)
	var charm_source: BattleUnitState = _resolve_charm_source_for_unit(acting_unit)
	if charm_source != null:
		acting_unit.set_current_target(charm_source, target_lock_turns)
		if not _is_target_in_range(acting_unit, charm_source):
			if _perform_move_towards_target(acting_unit, charm_source):
				acting_unit.clear_stuck()
				acting_unit.clear_blocked_target()
				acting_unit.advance_turn_effects()
				_refresh_actor_state(acting_unit)
				turn_result["outcome"] = "move"
				return turn_result
		print("CHARM: %s foi atraido por %s e perdeu a acao ofensiva" % [
			acting_unit.get_combat_label(),
			charm_source.get_combat_label(),
		])
		acting_unit.advance_turn_effects()
		_refresh_actor_state(acting_unit)
		turn_result["outcome"] = "charmed"
		return turn_result

	var acted: bool = false
	if _try_cast_master_skill(acting_unit):
		_log_tactical_debug("SKILL_CAST", [
			"unit=%s" % acting_unit.get_display_name(),
			"skill=%s" % acting_unit.get_master_skill_name(),
		])
		acted = true
		turn_result["outcome"] = "skill"
	elif _try_cast_unit_skill(acting_unit):
		_log_tactical_debug("SKILL_CAST", [
			"unit=%s" % acting_unit.get_display_name(),
			"skill=%s" % acting_unit.get_skill_name(),
		])
		acted = true
		turn_result["outcome"] = "skill"
	else:
		if acting_unit.should_force_retarget(TARGET_STUCK_RETARGET_LIMIT):
			var previous_target: BattleUnitState = acting_unit.current_target
			var previous_target_key: String = _unit_runtime_key(previous_target)
			var stuck_before_retarget: int = acting_unit.stuck_counter
			if not previous_target_key.is_empty():
				acting_unit.remember_blocked_target(previous_target_key)
			acting_unit.clear_target_lock()
			var replacement_target: BattleUnitState = _find_target_for_unit(acting_unit)
			if replacement_target != null and replacement_target != previous_target:
				acting_unit.set_current_target(replacement_target, target_lock_turns)
				_log_tactical_debug("RETARGET", [
					"reason=stuck",
					"unit=%s" % acting_unit.get_display_name(),
					"from=%s" % (previous_target.get_display_name() if previous_target != null else ""),
					"to=%s" % replacement_target.get_display_name(),
					"stuck=%d" % stuck_before_retarget,
				])
				acting_unit.clear_stuck()
				turn_result["outcome"] = "retarget"
			else:
				acting_unit.mark_stuck()
				_log_wait_debug(acting_unit, "retarget_pending", previous_target)
				turn_result["outcome"] = "wait"
		else:
			var target: BattleUnitState = _resolve_locked_target_for_unit(acting_unit)
			if target == null:
				acting_unit.mark_stuck()
				_log_wait_debug(acting_unit, "missing_target")
				turn_result["outcome"] = "wait"
			else:
				var target_key_for_turn: String = _unit_runtime_key(target)
				acting_unit.set_current_target(target, target_lock_turns)
				if _is_target_in_range(acting_unit, target):
					_perform_attack(acting_unit, target)
					turn_result["outcome"] = "attack"
					acted = true
				else:
					acted = _perform_move_towards_target(acting_unit, target)
					if acted:
						turn_result["outcome"] = "move"
					else:
						acting_unit.remember_blocked_target(target_key_for_turn)
						acting_unit.mark_stuck()
						if acting_unit.should_force_retarget(TARGET_STUCK_RETARGET_LIMIT):
							print("ANTI_LOOP: %s marcou %s para retarget no proximo turno | stuck=%d bounce=%d" % [
								acting_unit.get_combat_label(),
								target.get_combat_label(),
								acting_unit.stuck_counter,
								acting_unit.bounce_counter,
							])
						else:
							_log_wait_debug(acting_unit, "path_blocked", target)
						turn_result["outcome"] = "wait"

	if acted:
		acting_unit.clear_stuck()
		acting_unit.clear_blocked_target()
	elif turn_result["outcome"] == "wait":
		acting_unit.refund_action_charge(35)
	elif turn_result["outcome"] == "retarget":
		acting_unit.refund_action_charge(20)
	else:
		print("TURN: %s had no valid action" % acting_unit.get_combat_label())
		acting_unit.mark_stuck()
		acting_unit.refund_action_charge(35)

	if acting_unit.can_act():
		acting_unit.advance_turn_effects()
	_refresh_actor_state(acting_unit)
	return turn_result

func _resolve_locked_target_for_unit(acting_unit: BattleUnitState) -> BattleUnitState:
	if acting_unit == null:
		return null

	var previous_target: BattleUnitState = acting_unit.current_target
	var forced_target: BattleUnitState = _resolve_forced_target_for_unit(acting_unit)
	if forced_target != null:
		acting_unit.set_current_target(forced_target, _get_target_lock_turns_for_unit(acting_unit))
		_log_target_resolution(acting_unit, forced_target, previous_target, "forced")
		return forced_target

	if acting_unit.has_valid_current_target() and acting_unit.current_target.team_side != acting_unit.team_side:
		return acting_unit.current_target

	acting_unit.clear_target_lock()
	var new_target: BattleUnitState = _find_target_for_unit(acting_unit)
	if new_target != null:
		acting_unit.set_current_target(new_target, _get_target_lock_turns_for_unit(acting_unit))
		_log_target_resolution(acting_unit, new_target, previous_target, "reacquire")
	return new_target

func _resolve_charm_source_for_unit(source: BattleUnitState) -> BattleUnitState:
	if source == null or not source.is_charmed():
		return null
	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if source.is_charmed_by(candidate):
			return candidate
	source.clear_charm()
	return null

func _unit_runtime_key(unit_state: BattleUnitState) -> String:
	if unit_state == null:
		return ""
	return str(unit_state.get_instance_id())

func _log_tactical_debug(tag: String, parts: Array[String]) -> void:
	var message: String = tag
	for part in parts:
		if part.is_empty():
			continue
		message += " " + part
	print(message)

func _log_target_resolution(
	source: BattleUnitState,
	new_target: BattleUnitState,
	previous_target: BattleUnitState,
	reason: String
) -> void:
	if source == null or new_target == null:
		return
	if previous_target == null:
		_log_tactical_debug("TARGET_ACQUIRED", [
			"unit=%s" % source.get_display_name(),
			"target=%s" % new_target.get_display_name(),
			"reason=%s" % reason,
		])
	elif previous_target != new_target:
		_log_tactical_debug("TARGET_SWITCH", [
			"unit=%s" % source.get_display_name(),
			"from=%s" % previous_target.get_display_name(),
			"to=%s" % new_target.get_display_name(),
			"reason=%s" % reason,
		])

func _log_wait_debug(source: BattleUnitState, reason: String, target: BattleUnitState = null) -> void:
	if source == null:
		return
	var parts: Array[String] = [
		"unit=%s" % source.get_display_name(),
		"reason=%s" % reason,
	]
	if target != null:
		parts.append("target=%s" % target.get_display_name())
	parts.append("stuck=%d" % source.stuck_counter)
	parts.append("lock=%d" % source.target_lock_timer)
	_log_tactical_debug("WAIT", parts)

func _get_target_lock_turns_for_unit(unit_state: BattleUnitState) -> int:
	if unit_state == null:
		return TARGET_LOCK_REFRESH_TURNS
	if unit_state.is_tank_unit() or unit_state.is_stealth_unit():
		return TARGET_LOCK_REFRESH_TURNS + 1
	return TARGET_LOCK_REFRESH_TURNS

func _find_ally_with_highest_attack_value(team_side: int, exclude_unit: BattleUnitState = null) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_value: int = -1
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state == exclude_unit:
			continue
		var attack_value: int = unit_state.get_attack_value()
		if attack_value > best_value:
			best_value = attack_value
			best_target = unit_state
	return best_target

func _find_support_priority_ally(source: BattleUnitState) -> BattleUnitState:
	if source == null:
		return null
	var injured_ally: BattleUnitState = _find_most_injured_ally(source, false)
	if injured_ally != null and injured_ally.unit_data != null and injured_ally.current_hp < injured_ally.unit_data.max_hp:
		return injured_ally
	return _find_ally_with_highest_attack_value(source.team_side, source)

func _get_backline_depth_for_targeting(attacker_team_side: int, coord: Vector2i) -> int:
	if attacker_team_side == GameEnums.TeamSide.PLAYER:
		return BattleConfig.BOARD_HEIGHT - coord.y
	return coord.y + 1

func _get_nearest_enemy_distance_from_coord(team_side: int, coord: Vector2i) -> int:
	var best_distance: int = 1000000
	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side == team_side:
			continue
		var distance: int = board_grid.distance_between_cells(coord, candidate.coord)
		if distance < best_distance:
			best_distance = distance
	return best_distance

func _get_tactical_move_type(acting_unit: BattleUnitState) -> String:
	if acting_unit == null:
		return "advance"
	if acting_unit.is_support_unit():
		return "support"
	if acting_unit.is_stealth_unit():
		return "flank"
	if acting_unit.is_sniper_unit():
		return "kite"
	return "advance"

func _score_tactical_goal_coord(
	acting_unit: BattleUnitState,
	target: BattleUnitState,
	candidate_coord: Vector2i,
	path_length: int
) -> int:
	var path_cost: int = maxi(0, path_length - 1) * 18
	var distance_to_target: int = board_grid.distance_between_cells(candidate_coord, target.coord)
	var nearest_enemy_distance: int = _get_nearest_enemy_distance_from_coord(acting_unit.team_side, candidate_coord)
	if acting_unit.is_support_unit():
		var anchor_ally: BattleUnitState = _find_support_priority_ally(acting_unit)
		var ally_distance: int = 0 if anchor_ally == null else board_grid.distance_between_cells(candidate_coord, anchor_ally.coord)
		var pressure_penalty: int = 0 if nearest_enemy_distance >= 2 else 500 + ((2 - nearest_enemy_distance) * 250)
		return pressure_penalty + ally_distance * 40 + path_cost + distance_to_target * 5
	if acting_unit.is_sniper_unit():
		var range_gap: int = abs(distance_to_target - acting_unit.get_attack_range())
		var pressure_penalty: int = 0 if nearest_enemy_distance >= 2 else 420 + ((2 - nearest_enemy_distance) * 220)
		return range_gap * 180 + pressure_penalty + path_cost
	if acting_unit.is_stealth_unit():
		var backline_depth: int = _get_backline_depth_for_targeting(acting_unit.team_side, candidate_coord)
		var lateral_offset: int = abs(candidate_coord.x - target.coord.x)
		return path_cost + distance_to_target * 20 - (backline_depth * 80) - (lateral_offset * 35)
	return path_cost + distance_to_target * 10

func _find_tactical_goal_coord_for_target(
	acting_unit: BattleUnitState,
	target: BattleUnitState,
	desired_range: int,
	forbidden_coords: Array[Vector2i]
) -> Vector2i:
	if acting_unit == null or target == null:
		return Vector2i(-1, -1)
	if not acting_unit.is_support_unit() and not acting_unit.is_stealth_unit() and not acting_unit.is_sniper_unit():
		return Vector2i(-1, -1)

	var best_coord: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1000000
	for cell_key in board_grid.cells.keys():
		var candidate_coord: Vector2i = cell_key
		if not board_grid.is_valid_coord(candidate_coord):
			continue
		if board_grid.distance_between_cells(candidate_coord, target.coord) > desired_range:
			continue
		if forbidden_coords.has(candidate_coord):
			continue
		if candidate_coord != acting_unit.coord and not board_grid.is_cell_free(candidate_coord):
			continue
		var path: Array[Vector2i] = []
		if candidate_coord == acting_unit.coord:
			path.append(acting_unit.coord)
		else:
			path = board_grid.find_path_bfs(acting_unit.coord, candidate_coord, forbidden_coords, false)
		if path.is_empty():
			continue
		var score: int = _score_tactical_goal_coord(acting_unit, target, candidate_coord, path.size())
		if best_coord == Vector2i(-1, -1) or score < best_score:
			best_coord = candidate_coord
			best_score = score
	return best_coord

func _resolve_move_plan_for_target(
	acting_unit: BattleUnitState,
	target_coord: Vector2i,
	target_key: String,
	desired_range: int = 1,
	target_unit: BattleUnitState = null
) -> Dictionary:
	var forbidden_coords: Array[Vector2i] = []
	var bounce_coord: Vector2i = acting_unit.get_bounce_forbidden_coord(target_key)
	if board_grid.is_valid_coord(bounce_coord):
		forbidden_coords.append(bounce_coord)

	if target_unit != null and target_unit.team_side != acting_unit.team_side:
		var tactical_goal: Vector2i = _find_tactical_goal_coord_for_target(acting_unit, target_unit, desired_range, forbidden_coords)
		if board_grid.is_valid_coord(tactical_goal):
			var tactical_path: Array[Vector2i] = []
			if tactical_goal == acting_unit.coord:
				tactical_path.append(acting_unit.coord)
			else:
				tactical_path = board_grid.find_path_bfs(acting_unit.coord, tactical_goal, forbidden_coords, false)
			if tactical_path.size() >= 2:
				return {
					"coord": tactical_path[1],
					"move_type": _get_tactical_move_type(acting_unit),
					"avoided_coord": bounce_coord,
					"path": tactical_path,
				}

	var path: Array[Vector2i] = board_grid.find_path_to_attack_range(
		acting_unit.coord,
		target_coord,
		desired_range,
		forbidden_coords
	)
	if path.size() >= 2:
		return {
			"coord": path[1],
			"move_type": "advance",
			"avoided_coord": bounce_coord,
			"path": path,
		}

	return {
		"coord": acting_unit.coord,
		"move_type": "wait",
		"avoided_coord": bounce_coord,
		"path": path,
	}

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
		GameEnums.SkillEffectType.TARGET_PHYSICAL_VULNERABILITY:
			var marked_target: BattleUnitState = _find_target_for_unit(acting_unit)
			if marked_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, marked_target.coord, acting_unit.get_skill_range(), marked_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			marked_target.apply_received_physical_damage_multiplier(
				maxf(1.0, skill_data.received_physical_damage_multiplier),
				maxi(1, skill_data.duration_turns)
			)
			if marked_target.actor:
				marked_target.actor.on_damage()
			print("UNIT SKILL: %s marcou %s | dano fisico recebido x%.2f" % [
				acting_unit.get_combat_label(),
				marked_target.get_combat_label(),
				skill_data.received_physical_damage_multiplier,
			])
			_refresh_actor_state(marked_target)
			return true
		GameEnums.SkillEffectType.POUNCE_MAGIC_HUNTER_STUN:
			var pounce_target: BattleUnitState = _find_enemy_with_highest_magic_attack(acting_unit.team_side)
			if pounce_target == null:
				return false
			var pounce_distance: int = board_grid.distance_between_cells(acting_unit.coord, pounce_target.coord)
			if pounce_distance > acting_unit.get_skill_range():
				var landing_coord: Vector2i = _find_best_adjacent_coord_to_target(pounce_target, acting_unit.team_side, acting_unit.coord)
				if board_grid.is_valid_coord(landing_coord) and board_grid.move_unit(acting_unit, landing_coord):
					_refresh_race_synergy_state(false)
				elif _move_towards_skill_target_if_needed(acting_unit, pounce_target.coord, acting_unit.get_skill_range(), pounce_target):
					return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			pounce_target.apply_turn_skip(maxi(1, skill_data.turn_skip_count))
			var pounce_result: Dictionary = _calculate_damage_result(
				acting_unit,
				pounce_target,
				int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
				0,
				true,
				false,
				false
			)
			_apply_damage_result(
				acting_unit,
				pounce_target,
				pounce_result,
				"%s saltou com %s em %s" % [acting_unit.get_combat_label(), skill_name, pounce_target.get_combat_label()],
				["Atordoado"],
				false,
				true,
				true
			)
			return true
		GameEnums.SkillEffectType.SELF_BASIC_ATTACK_BLOCK:
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			acting_unit.apply_basic_attack_block(maxi(1, skill_data.blocked_basic_attack_count))
			if acting_unit.actor:
				acting_unit.actor.on_buff()
			print("UNIT SKILL: %s ergueu defesa total para %d ataques basicos" % [
				acting_unit.get_combat_label(),
				maxi(1, skill_data.blocked_basic_attack_count),
			])
			_refresh_actor_state(acting_unit)
			return true
		GameEnums.SkillEffectType.AOE_PHYSICAL_ATTACK_SLOW:
			var slam_target: BattleUnitState = _find_target_for_unit(acting_unit)
			if slam_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, slam_target.coord, acting_unit.get_skill_range(), slam_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			var slam_targets: Array[BattleUnitState] = _get_units_in_radius(
				slam_target.coord,
				maxi(0, skill_data.area_radius),
				GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
			)
			for target in slam_targets:
				target.apply_action_charge_multiplier(
					clampf(skill_data.action_charge_multiplier, 0.1, 3.0),
					maxi(1, skill_data.duration_turns)
				)
				var slam_result: Dictionary = _calculate_damage_result(
					acting_unit,
					target,
					int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
					0,
					true,
					false,
					false
				)
				_apply_damage_result(
					acting_unit,
					target,
					slam_result,
					"%s abalou %s com %s" % [acting_unit.get_combat_label(), target.get_combat_label(), skill_name],
					["Velocidade %.0f%%" % (skill_data.action_charge_multiplier * 100.0)],
					false,
					true,
					false
				)
			return not slam_targets.is_empty()
		GameEnums.SkillEffectType.MISSING_HEALTH_PHYSICAL_STRIKE:
			var bloody_target: BattleUnitState = _find_target_for_unit(acting_unit)
			if bloody_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, bloody_target.coord, acting_unit.get_skill_range(), bloody_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			var missing_ratio: float = 0.0
			if acting_unit.unit_data != null and acting_unit.unit_data.max_hp > 0:
				missing_ratio = 1.0 - (float(acting_unit.current_hp) / float(acting_unit.unit_data.max_hp))
			var bloody_multiplier: float = skill_data.physical_power_multiplier + missing_ratio
			var bloody_result: Dictionary = _calculate_damage_result(
				acting_unit,
				bloody_target,
				int(round(float(acting_unit.get_physical_attack_value()) * bloody_multiplier)) + skill_data.damage_amount,
				0,
				true,
				false,
				false
			)
			_apply_damage_result(
				acting_unit,
				bloody_target,
				bloody_result,
				"%s disparou %s em %s" % [acting_unit.get_combat_label(), skill_name, bloody_target.get_combat_label()],
				["PV perdido %.0f%%" % (missing_ratio * 100.0)],
				false,
				true,
				true
			)
			return true
		GameEnums.SkillEffectType.SELF_BERSERK_FRENZY:
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			acting_unit.apply_action_charge_multiplier(
				maxf(1.0, skill_data.action_charge_multiplier),
				maxi(1, skill_data.duration_turns)
			)
			acting_unit.apply_physical_defense_multiplier(
				maxf(0.0, skill_data.physical_defense_multiplier),
				maxi(1, skill_data.duration_turns)
			)
			if acting_unit.actor:
				acting_unit.actor.on_buff()
			print("UNIT SKILL: %s entrou em furia | carga x%.2f, defesa fisica x%.2f" % [
				acting_unit.get_combat_label(),
				skill_data.action_charge_multiplier,
				skill_data.physical_defense_multiplier,
			])
			_refresh_actor_state(acting_unit)
			return true
		GameEnums.SkillEffectType.SELF_CLEAVE_BUFF:
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			acting_unit.apply_cleave_attacks(maxi(1, skill_data.cleave_attack_count))
			if acting_unit.actor:
				acting_unit.actor.on_buff()
			print("UNIT SKILL: %s ganhou cleave nos proximos %d ataques" % [
				acting_unit.get_combat_label(),
				maxi(1, skill_data.cleave_attack_count),
			])
			_refresh_actor_state(acting_unit)
			return true
		GameEnums.SkillEffectType.TARGET_PHYSICAL_DEFENSE_BREAK_ZERO:
			var rend_target: BattleUnitState = _find_target_for_unit(acting_unit)
			if rend_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, rend_target.coord, acting_unit.get_skill_range(), rend_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			rend_target.apply_physical_defense_multiplier(
				skill_data.physical_defense_multiplier,
				maxi(1, skill_data.duration_turns)
			)
			var rend_result: Dictionary = _calculate_damage_result(
				acting_unit,
				rend_target,
				int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
				0,
				true,
				false,
				false
			)
			_apply_damage_result(
				acting_unit,
				rend_target,
				rend_result,
				"%s esmagou %s com %s" % [acting_unit.get_combat_label(), rend_target.get_combat_label(), skill_name],
				["DEF F zerada"],
				false,
				true,
				true
			)
			return true
		GameEnums.SkillEffectType.GAIN_NEXT_ROUND_GOLD:
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			_grant_team_next_round_gold(
				acting_unit.team_side,
				maxi(1, skill_data.gold_gain),
				skill_name
			)
			if acting_unit.actor:
				acting_unit.actor.on_buff()
			return true
		GameEnums.SkillEffectType.ALLY_HEAL_PERCENT:
			var ratio_heal_target: BattleUnitState = _find_most_injured_ally(acting_unit)
			if ratio_heal_target == null:
				return false
			if _move_towards_skill_target_if_needed(acting_unit, ratio_heal_target.coord, acting_unit.get_skill_range(), ratio_heal_target):
				return true
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			var ratio_heal_amount: int = int(round(float(ratio_heal_target.unit_data.max_hp) * skill_data.heal_ratio))
			var ratio_healed: int = ratio_heal_target.heal(maxi(1, ratio_heal_amount))
			if ratio_heal_target.actor and ratio_healed > 0:
				ratio_heal_target.actor.on_heal()
			print("UNIT SKILL: %s curou %s em %d PV" % [
				acting_unit.get_combat_label(),
				ratio_heal_target.get_combat_label(),
				ratio_healed,
			])
			_refresh_actor_state(ratio_heal_target)
			return ratio_healed > 0
		GameEnums.SkillEffectType.ADJACENT_LIFESTEAL_GIFT:
			var lifesteal_target: BattleUnitState = _find_adjacent_ally_with_highest_physical_attack(acting_unit)
			if lifesteal_target == null:
				var fallback_ally: BattleUnitState = _find_ally_with_highest_physical_attack(acting_unit.team_side, acting_unit)
				if fallback_ally == null:
					return false
				if _move_towards_skill_target_if_needed(acting_unit, fallback_ally.coord, 1, fallback_ally):
					return true
				lifesteal_target = _find_adjacent_ally_with_highest_physical_attack(acting_unit)
				if lifesteal_target == null:
					return false
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			lifesteal_target.apply_lifesteal_ratio(
				maxf(0.0, skill_data.lifesteal_ratio),
				maxi(1, skill_data.duration_turns)
			)
			if lifesteal_target.actor:
				lifesteal_target.actor.on_buff()
			print("UNIT SKILL: %s aqueceu o sangue de %s" % [
				acting_unit.get_combat_label(),
				lifesteal_target.get_combat_label(),
			])
			_refresh_actor_state(lifesteal_target)
			return true
		GameEnums.SkillEffectType.ADJACENT_MANA_GIFT:
			var mana_targets: Array[BattleUnitState] = []
			for target in _get_units_in_radius(acting_unit.coord, 1, acting_unit.team_side):
				if target == acting_unit:
					continue
				mana_targets.append(target)
			if mana_targets.is_empty():
				return false
			if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
				return false
			if acting_unit.actor:
				acting_unit.actor.on_skill_cast()
			for mana_target in mana_targets:
				var mana_gain: int = int(round(float(mana_target.get_mana_max()) * skill_data.ally_mana_grant_ratio))
				mana_target.gain_mana(maxi(1, mana_gain))
				if mana_target.actor:
					mana_target.actor.on_buff()
				_refresh_actor_state(mana_target)
			print("UNIT SKILL: %s acelerou %d aliados com %s" % [
				acting_unit.get_combat_label(),
				mana_targets.size(),
				skill_name,
			])
			return true
		GameEnums.SkillEffectType.SLOWED_CRIT_STRIKE:
			return _cast_slowed_crit_strike_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.TARGET_MAGIC_DOT_CONTROL:
			return _cast_target_magic_dot_control_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.SELF_ATTACK_BLOCK_RETALIATE_SLOW:
			return _cast_self_block_retaliate_slow_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.ADJACENT_KNOCKBACK:
			return _cast_adjacent_knockback_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.LINE_PHYSICAL_DEFENSE_BREAK:
			return _cast_line_physical_defense_break_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.AOE_PHYSICAL_EVASION:
			return _cast_aoe_physical_evasion_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.TARGET_MAGIC_STUN:
			return _cast_target_magic_stun_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.CONE_MAGIC_DISPEL:
			return _cast_cone_magic_dispel_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.TARGET_CHARM:
			return _cast_target_charm_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.ADJACENT_MAGIC_SHIELD:
			return _cast_adjacent_magic_shield_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.ADJACENT_CLEANSE:
			return _cast_adjacent_cleanse_skill(acting_unit, skill_data, skill_name)
		GameEnums.SkillEffectType.LINE_HASTE:
			return _cast_line_haste_skill(acting_unit, skill_data, skill_name)
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

func _find_most_injured_ally(source: BattleUnitState, allow_self_as_fallback: bool = false) -> BattleUnitState:
	var best_ally: BattleUnitState = null
	var biggest_missing_hp: int = 0

	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side != source.team_side:
			continue
		if candidate == source and not allow_self_as_fallback:
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
	var move_plan: Dictionary = _resolve_move_plan_for_target(
		acting_unit,
		target_coord,
		target_key,
		skill_range,
		target
	)
	var step_coord: Vector2i = move_plan.get("coord", acting_unit.coord)
	var avoided_coord: Vector2i = move_plan.get("avoided_coord", Vector2i(-1, -1))
	if step_coord == acting_unit.coord and board_grid.is_valid_coord(avoided_coord):
		print("UNBLOCK: %s evitou retornar para %s enquanto buscava angulo de skill" % [
			acting_unit.get_combat_label(),
			avoided_coord,
		])
		acting_unit.remember_blocked_target(target_key)
		acting_unit.mark_stuck()
		return true
	if step_coord == acting_unit.coord:
		var target_label_wait: String = str(target_coord)
		if target != null:
			target_label_wait = target.get_combat_label()
		print("WAIT: %s aguardando caminho de skill para %s" % [
			acting_unit.get_combat_label(),
			target_label_wait,
		])
		acting_unit.remember_blocked_target(target_key)
		acting_unit.mark_stuck()
		return true

	var from_coord: Vector2i = acting_unit.coord
	if step_coord != acting_unit.coord and board_grid.move_unit(acting_unit, step_coord):
		var target_label: String = str(target_coord)
		if target != null:
			target_label = target.get_combat_label()
		var move_type: String = str(move_plan.get("move_type", "advance"))
		acting_unit.remember_navigation_move(target_key, move_type, from_coord, step_coord)
		_refresh_race_synergy_state(false)
		print("%s moved to reach skill range for %s" % [
			acting_unit.get_combat_label(),
			target_label,
		])
		return true
	return false

func _find_closest_enemy(source: BattleUnitState) -> BattleUnitState:
	if source == null:
		return null
	var best_target: BattleUnitState = null
	var best_distance: int = 1000000
	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side == source.team_side:
			continue
		if candidate.is_stealthed():
			continue
		var distance: int = board_grid.distance_between_cells(source.coord, candidate.coord)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

func _find_slowed_enemy(team_side: int) -> BattleUnitState:
	var best_target: BattleUnitState = null
	var best_score: int = -1
	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side == team_side:
			continue
		if candidate.action_charge_multiplier_status >= 1.0 and not candidate.has_turn_skip():
			continue
		var score: int = candidate.get_attack_value() + candidate.current_hp
		if score > best_score:
			best_score = score
			best_target = candidate
	return best_target

func _build_line_targets(source: BattleUnitState, target: BattleUnitState, max_steps: int, target_team_side: int) -> Array[BattleUnitState]:
	var line_targets: Array[BattleUnitState] = []
	if source == null or target == null:
		return line_targets
	var delta: Vector2i = target.coord - source.coord
	var step: Vector2i = Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		step = Vector2i(signi(delta.x), 0)
	else:
		step = Vector2i(0, signi(delta.y))
	if step == Vector2i.ZERO:
		step = Vector2i(0, -1 if source.team_side == GameEnums.TeamSide.PLAYER else 1)
	var cursor: Vector2i = source.coord
	for _step in range(maxi(1, max_steps)):
		cursor += step
		if not board_grid.is_valid_coord(cursor):
			break
		var candidate: BattleUnitState = board_grid.get_unit_at(cursor)
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side != target_team_side:
			continue
		line_targets.append(candidate)
	return line_targets

func _build_cone_targets(source: BattleUnitState, primary_target: BattleUnitState, radius: int, target_team_side: int) -> Array[BattleUnitState]:
	var cone_targets: Array[BattleUnitState] = []
	if source == null or primary_target == null:
		return cone_targets
	for candidate in _get_units_in_radius(primary_target.coord, maxi(0, radius), target_team_side):
		var candidate_delta: Vector2i = candidate.coord - source.coord
		var primary_delta: Vector2i = primary_target.coord - source.coord
		var is_forward: bool = false
		if abs(primary_delta.x) >= abs(primary_delta.y):
			is_forward = signi(candidate_delta.x) == signi(primary_delta.x)
		else:
			is_forward = signi(candidate_delta.y) == signi(primary_delta.y)
		if not is_forward and candidate != primary_target:
			continue
		if not cone_targets.has(candidate):
			cone_targets.append(candidate)
	return cone_targets

func _try_knockback_target(target: BattleUnitState, source: BattleUnitState, distance: int) -> bool:
	if target == null or source == null:
		return false
	var delta: Vector2i = target.coord - source.coord
	var step: Vector2i = Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		step = Vector2i(signi(delta.x), 0)
	else:
		step = Vector2i(0, signi(delta.y))
	if step == Vector2i.ZERO:
		step = Vector2i(0, 1 if target.team_side == GameEnums.TeamSide.PLAYER else -1)
	var final_coord: Vector2i = target.coord
	for _step in range(maxi(1, distance)):
		var next_coord: Vector2i = final_coord + step
		if not board_grid.is_valid_coord(next_coord) or not board_grid.is_cell_free(next_coord):
			break
		final_coord = next_coord
	if final_coord == target.coord:
		return false
	return board_grid.move_unit(target, final_coord)

func _get_wind_haste_targets(source: BattleUnitState) -> Array[BattleUnitState]:
	var targets: Array[BattleUnitState] = []
	if source == null:
		return targets
	targets.append(source)
	var back_step: int = 1 if source.team_side == GameEnums.TeamSide.PLAYER else -1
	var candidate_coords: Array[Vector2i] = [
		Vector2i(source.coord.x - 1, source.coord.y),
		Vector2i(source.coord.x + 1, source.coord.y),
		Vector2i(source.coord.x, source.coord.y + back_step),
	]
	for coord in candidate_coords:
		if not board_grid.is_valid_coord(coord):
			continue
		var candidate: BattleUnitState = board_grid.get_unit_at(coord)
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side != source.team_side:
			continue
		if not targets.has(candidate):
			targets.append(candidate)
	return targets

func _unit_has_negative_status(unit_state: BattleUnitState) -> bool:
	if unit_state == null:
		return false
	return (
		unit_state.physical_defense_multiplier_status < 1.0
		or unit_state.magic_defense_multiplier_status < 1.0
		or unit_state.mana_gain_multiplier_status < 1.0
		or unit_state.action_charge_multiplier_status < 1.0
		or unit_state.has_turn_skip()
		or unit_state.physical_miss_chance_status > 0.0
		or unit_state.get_received_physical_damage_multiplier() > 1.0
		or unit_state.has_forced_target()
		or unit_state.is_charmed()
	)

func _find_ally_with_negative_status(source: BattleUnitState) -> BattleUnitState:
	if source == null:
		return null
	var best_target: BattleUnitState = null
	var best_distance: int = 1000000
	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side != source.team_side or candidate == source:
			continue
		if not _unit_has_negative_status(candidate):
			continue
		var distance: int = board_grid.distance_between_cells(source.coord, candidate.coord)
		if distance < best_distance:
			best_distance = distance
			best_target = candidate
	return best_target

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

			var move_plan: Dictionary = _resolve_move_plan_for_target(
				source,
				candidate.coord,
				_unit_runtime_key(candidate),
				source.get_attack_range(),
				candidate
			)
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
	var forced_target: BattleUnitState = _resolve_forced_target_for_unit(source)
	if forced_target != null:
		return forced_target

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

func _resolve_forced_target_for_unit(source: BattleUnitState) -> BattleUnitState:
	if source == null or not source.has_forced_target():
		return null
	for candidate in runtime_units:
		if candidate == null or not candidate.can_act():
			continue
		if candidate.team_side == source.team_side:
			continue
		if source.is_forced_target(candidate):
			return candidate
	source.clear_forced_target()
	return null

func _score_target_for_unit(source: BattleUnitState, candidate: BattleUnitState) -> int:
	var distance: int = board_grid.distance_between_cells(source.coord, candidate.coord)
	var target_key: String = _unit_runtime_key(candidate)
	var routing_penalty: int = source.get_blocked_target_penalty(target_key) + source.get_recent_target_penalty(target_key)
	var score: int = distance * 100 + candidate.current_hp * 4

	if source.is_tank_unit():
		score = distance * 1000 + candidate.current_hp * 8 + candidate.get_defense_value() * 4
	elif source.is_attacker_unit():
		if distance <= source.get_attack_range():
			score = candidate.current_hp * 100 + distance * 10 + candidate.get_defense_value() * 4
		else:
			score = 100000 + distance * 100 + candidate.current_hp * 6 + candidate.get_defense_value() * 3
	elif source.is_support_unit():
		var anchor_ally: BattleUnitState = _find_support_priority_ally(source)
		var anchor_distance: int = 0 if anchor_ally == null else board_grid.distance_between_cells(anchor_ally.coord, candidate.coord)
		score = anchor_distance * 700 + distance * 100 + candidate.current_hp * 4
	elif source.is_stealth_unit():
		var role_bucket: int = 2
		if candidate.is_support_unit():
			role_bucket = 0
		elif candidate.is_ranged_unit():
			role_bucket = 1
		var backline_bonus: int = _get_backline_depth_for_targeting(source.team_side, candidate.coord)
		score = role_bucket * 100000 + candidate.current_hp * 120 + candidate.get_defense_value() * 10 - (distance * 25) - (backline_bonus * 120)
	elif source.is_sniper_unit():
		if distance <= source.get_attack_range():
			score = -(distance * 1000) + candidate.current_hp * 20 + candidate.get_defense_value() * 5
		else:
			score = 50000 - (distance * 500) + candidate.current_hp * 20 + candidate.get_defense_value() * 5

	return score + routing_penalty

func _is_target_in_range(attacker: BattleUnitState, target: BattleUnitState) -> bool:
	var distance: int = board_grid.distance_between_cells(attacker.coord, target.coord)
	return distance <= attacker.get_attack_range()

func _perform_move_towards_target(acting_unit: BattleUnitState, target: BattleUnitState) -> bool:
	var target_key: String = _unit_runtime_key(target)
	var move_plan: Dictionary = _resolve_move_plan_for_target(
		acting_unit,
		target.coord,
		target_key,
		acting_unit.get_attack_range(),
		target
	)
	var next_coord: Vector2i = move_plan.get("coord", acting_unit.coord)
	var avoided_coord: Vector2i = move_plan.get("avoided_coord", Vector2i(-1, -1))
	var move_type: String = str(move_plan.get("move_type", "wait"))
	if next_coord == acting_unit.coord:
		if board_grid.is_valid_coord(avoided_coord):
			print("ANTI_LOOP: %s evitou voltar para %s enquanto perseguia %s" % [
				acting_unit.get_combat_label(),
				avoided_coord,
				target.get_combat_label(),
			])
		else:
			_log_wait_debug(acting_unit, "path_blocked", target)
		return false

	var from_coord: Vector2i = acting_unit.coord
	if board_grid.move_unit(acting_unit, next_coord):
		acting_unit.remember_navigation_move(target_key, move_type, from_coord, next_coord)
		_refresh_race_synergy_state(false)
		if acting_unit.bounce_counter >= LOCAL_LOOP_BOUNCE_THRESHOLD:
			print("ANTI_LOOP: %s detectou oscilacao recente | bounce=%d target=%s" % [
				acting_unit.get_combat_label(),
				acting_unit.bounce_counter,
				target.get_combat_label(),
			])
		print("MOVE unit=%s type=%s from=%s to=%s target=%s" % [
			acting_unit.get_display_name(),
			move_type,
			from_coord,
			next_coord,
			target.get_display_name(),
		])
		return true
	return false

func _perform_attack(attacker: BattleUnitState, target: BattleUnitState) -> void:
	if target.consume_basic_attack_block():
		print("ATAQUE BLOQUEADO: %s teve o golpe anulado por %s" % [
			attacker.get_combat_label(),
			target.get_combat_label(),
		])
		if target.actor:
			target.actor.on_buff()
		if attacker.can_act():
			var gained_attack: int = attacker.gain_mana(attacker.get_mana_gain_on_attack())
			if gained_attack > 0:
				_log_mana_gain(attacker, gained_attack, "attack")
		_refresh_actor_state(attacker)
		_refresh_actor_state(target)
		return

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

	if attacker.has_cleave_attacks():
		attacker.consume_cleave_attack()
		_perform_cleave_attack(attacker, target)

func _perform_cleave_attack(attacker: BattleUnitState, primary_target: BattleUnitState) -> void:
	if attacker == null or primary_target == null or board_grid == null:
		return

	for coord in board_grid.get_adjacent_coords(primary_target.coord):
		var splash_target: BattleUnitState = board_grid.get_unit_at(coord)
		if splash_target == null or not splash_target.can_act():
			continue
		if splash_target.team_side == attacker.team_side:
			continue
		if splash_target == primary_target:
			continue
		var splash_result: Dictionary = _calculate_damage_result(
			attacker,
			splash_target,
			int(round(float(attacker.get_physical_attack_value()) * THRAX_CLEAVE_DAMAGE_RATIO)),
			0,
			true,
			false,
			false
		)
		_apply_damage_result(
			attacker,
			splash_target,
			splash_result,
			"%s espalhou cleave em %s" % [attacker.get_combat_label(), splash_target.get_combat_label()],
			["Cleave"],
			false,
			true,
			false
		)

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
	final_physical = int(round(float(final_physical) * target.get_received_physical_damage_multiplier()))
	var absorbed_by_shield: int = 0
	if final_physical > 0:
		var shield_result: Dictionary = target.absorb_physical_damage(final_physical)
		absorbed_by_shield = int(shield_result.get("absorbed", 0))
		final_physical = int(shield_result.get("remaining", 0))
	var final_magic: int = maxi(0, adjusted_magic - target.get_magic_defense_value())
	var absorbed_by_magic_shield: int = 0
	if final_magic > 0:
		var magic_shield_result: Dictionary = target.absorb_magic_damage(final_magic)
		absorbed_by_magic_shield = int(magic_shield_result.get("absorbed", 0))
		final_magic = int(magic_shield_result.get("remaining", 0))
	var chip_damage_applied: bool = false
	if final_physical + final_magic <= 0:
		if adjusted_magic > 0 and absorbed_by_magic_shield <= 0:
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
		"absorbed_by_magic_shield": absorbed_by_magic_shield,
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
	var absorbed_by_magic_shield: int = int(damage_result.get("absorbed_by_magic_shield", 0))
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
	if absorbed_by_magic_shield > 0:
		notes.append("Escudo magico -%d" % absorbed_by_magic_shield)
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
			var retaliate_multiplier: float = target.get_melee_attacker_action_multiplier()
			if retaliate_multiplier < 1.0 and attacker.can_act():
				attacker.apply_action_charge_multiplier(retaliate_multiplier, maxi(1, target.melee_attacker_action_turns))
				_refresh_actor_state(attacker)
				print("RESSACA GELADA: %s teve o ritmo reduzido para %.0f%% ao atacar %s" % [
					attacker.get_combat_label(),
					retaliate_multiplier * 100.0,
					target.get_combat_label(),
				])

	if grant_attack_mana and attacker != null and attacker.can_act():
		var gained_attack: int = attacker.gain_mana(attacker.get_mana_gain_on_attack())
		if gained_attack > 0:
			_log_mana_gain(attacker, gained_attack, "attack")

	if attacker != null and attacker.can_act() and damage > 0:
		var status_lifesteal_ratio: float = attacker.get_lifesteal_ratio()
		if status_lifesteal_ratio > 0.0:
			var healed_from_status: int = attacker.heal(int(round(float(damage) * status_lifesteal_ratio)))
			if healed_from_status > 0:
				if attacker.actor:
					attacker.actor.on_heal()
				print("ROUBO DE VIDA: %s recuperou %d PV" % [
					attacker.get_combat_label(),
					healed_from_status,
				])
				_refresh_actor_state(attacker)

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
		if master_skill != null and master_skill.effect_type == GameEnums.SkillEffectType.MASTER_TAUNT_AURA:
			var taunted_targets: Array[BattleUnitState] = _get_units_in_radius(
				caster.coord,
				maxi(1, master_skill.area_radius),
				GameEnums.TeamSide.PLAYER if caster.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
			)
			if taunted_targets.is_empty():
				return false
			if not caster.spend_mana(caster.get_mana_max()):
				return false
			if caster.actor:
				caster.actor.on_skill_cast()
			for target in taunted_targets:
				target.apply_forced_target(caster, maxi(1, master_skill.duration_turns))
				if target.actor:
					target.actor.on_damage()
				_refresh_actor_state(target)
			print("MASTER SKILL: %s usou %s e provocou %d inimigos" % [
				caster.get_combat_label(),
				caster.get_master_skill_name(),
				taunted_targets.size(),
			])
			_refresh_actor_state(caster)
			return true
		if master_skill != null and master_skill.effect_type == GameEnums.SkillEffectType.TARGET_MAGIC_BURST_SLOW:
			var burst_target: BattleUnitState = _find_strongest_enemy_for_team(caster.team_side)
			if burst_target == null:
				return false
			if _move_towards_skill_target_if_needed(caster, burst_target.coord, maxi(1, master_skill.range), burst_target):
				return true
			if not caster.spend_mana(caster.get_mana_max()):
				return false
			if caster.actor:
				caster.actor.on_skill_cast()
			var burst_result: Dictionary = _calculate_damage_result(
				caster,
				burst_target,
				0,
				master_skill.damage_amount + int(round(float(caster.get_magic_attack_value()) * master_skill.magic_power_multiplier)),
				false,
				false,
				false
			)
			_apply_damage_result(
				caster,
				burst_target,
				burst_result,
				"%s used %s on %s" % [caster.get_combat_label(), caster.get_master_skill_name(), burst_target.get_combat_label()],
				[
					"Lentidao %.0f%%" % (clampf(master_skill.action_charge_multiplier, 0.1, 1.0) * 100.0),
				],
				false,
				true,
				false
			)
			burst_target.apply_action_charge_multiplier(
				clampf(master_skill.action_charge_multiplier, 0.1, 1.0),
				maxi(1, master_skill.duration_turns)
			)
			_refresh_actor_state(burst_target)
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
	_resolve_first_ally_death_summon(target)

	if inspected_unit == target:
		_clear_inspected_context()

	target.clear_target_lock()
	_clear_target_locks_for_unit(target)

	if target.is_summoned_token:
		print("TOKEN cleanup: %s removido do runtime local" % target.get_combat_label())
		board_grid.remove_unit(target, true)
		runtime_units.erase(target)
		_refresh_race_synergy_state(true)
		return

	if target.is_master:
		print("MASTER DOWN: %s vai reconstruir no proximo PREP em %s" % [
			target.get_combat_label(),
			_get_persistent_master_home_coord(target.team_side),
		])
	else:
		print("%s died and will rebuild from home coord %s" % [
			target.get_combat_label(),
			target.home_coord,
		])

	board_grid.remove_unit(target)
	_refresh_race_synergy_state(true)

func _clear_target_locks_for_unit(target: BattleUnitState) -> void:
	if target == null:
		return
	for unit_state in runtime_units:
		if unit_state == null:
			continue
		if unit_state.current_target == target:
			unit_state.clear_target_lock()

func _team_has_live_unit_id(team_side: int, unit_id: String) -> bool:
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side != team_side:
			continue
		if unit_state.unit_data != null and unit_state.unit_data.id == unit_id:
			return true
	return false

func _resolve_first_ally_death_summon(dead_unit: BattleUnitState) -> void:
	if dead_unit == null or first_combat_death_resolved:
		return
	first_combat_death_resolved = true
	var summon_state: Dictionary = first_ally_death_summon_states.get(dead_unit.team_side, {})
	first_ally_death_summon_states.clear()
	if summon_state.is_empty():
		return
	var summon_unit_path: String = str(summon_state.get("unit_path", ""))
	var summon_unit_data: UnitData = _load_unit_data(summon_unit_path)
	if summon_unit_data == null:
		return
	if _team_has_live_unit_id(dead_unit.team_side, summon_unit_data.id):
		return
	var summon_coord: Vector2i = _resolve_summon_coord_near_origin(dead_unit.coord, dead_unit.team_side)
	if not board_grid.is_valid_coord(summon_coord):
		return
	var summon_source: BattleUnitState = _find_team_master_any_state(dead_unit.team_side)
	var summon_state_unit: BattleUnitState = _spawn_summoned_unit_from_path(
		summon_unit_path,
		dead_unit.team_side,
		summon_coord,
		summon_source if summon_source != null else dead_unit,
		1.0,
		float(summon_state.get("hp_ratio", 1.0)),
		false
	)
	if summon_state_unit == null:
		return
	print("CANTO DA SEREIA: %s invocou %s com %d/%d PV" % [
		str(summon_state.get("card_name", "Canto da Sereia")),
		summon_state_unit.get_combat_label(),
		summon_state_unit.current_hp,
		summon_state_unit.unit_data.max_hp,
	])
	_refresh_race_synergy_state(true)

func _find_team_master(team_side: int) -> BattleUnitState:
	for unit_state in runtime_units:
		if unit_state == null or not unit_state.can_act():
			continue
		if unit_state.team_side == team_side and unit_state.is_master:
			return unit_state
	return null

func _find_team_master_any_state(team_side: int) -> BattleUnitState:
	for unit_state in runtime_units:
		if unit_state == null or unit_state.unit_data == null:
			continue
		if unit_state.team_side == team_side and unit_state.is_master:
			return unit_state
	return null

func _cast_slowed_crit_strike_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var target: BattleUnitState = _find_slowed_enemy(acting_unit.team_side)
	if target == null:
		target = _find_target_for_unit(acting_unit)
	if target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, target.coord, acting_unit.get_skill_range(), target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	var force_critical: bool = target.action_charge_multiplier_status < 1.0 or target.has_turn_skip()
	var result: Dictionary = _calculate_damage_result(
		acting_unit,
		target,
		int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
		0,
		true,
		force_critical,
		false
	)
	var notes: Array[String] = []
	if force_critical:
		notes.append("Alvo lento")
	_apply_damage_result(
		acting_unit,
		target,
		result,
		"%s used %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
		notes,
		false,
		true,
		true
	)
	return true

func _cast_target_magic_dot_control_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var target: BattleUnitState = _find_strongest_enemy_for_team(acting_unit.team_side)
	if target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, target.coord, acting_unit.get_skill_range(), target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	target.apply_turn_skip(maxi(1, skill_data.turn_skip_count))
	target.apply_action_charge_multiplier(clampf(skill_data.action_charge_multiplier, 0.1, 1.0), maxi(1, skill_data.duration_turns))
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
		"%s used %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
		["Capsula de agua"],
		false,
		true,
		false
	)
	return true

func _cast_self_block_retaliate_slow_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	acting_unit.apply_basic_attack_block(maxi(1, skill_data.blocked_basic_attack_count))
	acting_unit.apply_melee_attacker_action_multiplier(
		clampf(skill_data.retaliate_action_charge_multiplier, 0.1, 1.0),
		maxi(1, skill_data.retaliate_duration_turns)
	)
	if acting_unit.actor:
		acting_unit.actor.on_buff()
	print("UNIT SKILL: %s usou %s | bloqueios=%d lentidao corpo a corpo %.0f%%" % [
		acting_unit.get_combat_label(),
		skill_name,
		maxi(1, skill_data.blocked_basic_attack_count),
		clampf(skill_data.retaliate_action_charge_multiplier, 0.1, 1.0) * 100.0,
	])
	_refresh_actor_state(acting_unit)
	return true

func _cast_adjacent_knockback_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var targets: Array[BattleUnitState] = _get_units_in_radius(
		acting_unit.coord,
		1,
		GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	)
	if targets.is_empty():
		return false
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	var moved_any_target: bool = false
	for target in targets:
		target.apply_turn_skip(maxi(1, skill_data.turn_skip_count))
		var result: Dictionary = _calculate_damage_result(
			acting_unit,
			target,
			int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
			0,
			true,
			false,
			false
		)
		_apply_damage_result(
			acting_unit,
			target,
			result,
			"%s usou %s em %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
			["Empurrao"],
			false,
			true,
			false
		)
		if target.can_act() and _try_knockback_target(target, acting_unit, maxi(1, skill_data.knockback_distance)):
			moved_any_target = true
			print("KNOCKBACK: %s foi empurrado para %s" % [target.get_combat_label(), target.coord])
			_refresh_actor_state(target)
	if moved_any_target:
		_refresh_race_synergy_state(false)
	return true

func _cast_line_physical_defense_break_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var primary_target: BattleUnitState = _find_target_for_unit(acting_unit)
	if primary_target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, primary_target.coord, acting_unit.get_skill_range(), primary_target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	var targets: Array[BattleUnitState] = _build_line_targets(
		acting_unit,
		primary_target,
		maxi(1, skill_data.area_radius),
		GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	)
	if targets.is_empty():
		targets.append(primary_target)
	for target in targets:
		target.apply_physical_defense_multiplier(skill_data.physical_defense_multiplier, maxi(1, skill_data.duration_turns))
		var result: Dictionary = _calculate_damage_result(
			acting_unit,
			target,
			int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
			0,
			true,
			false,
			false
		)
		_apply_damage_result(
			acting_unit,
			target,
			result,
			"%s disparou %s em %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
			["DEF F x%.2f" % skill_data.physical_defense_multiplier],
			false,
			true,
			false
		)
	return true

func _cast_aoe_physical_evasion_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var primary_target: BattleUnitState = _find_target_for_unit(acting_unit)
	if primary_target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, primary_target.coord, acting_unit.get_skill_range(), primary_target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	acting_unit.apply_basic_attack_block(maxi(1, skill_data.blocked_basic_attack_count))
	var targets: Array[BattleUnitState] = _get_units_in_radius(
		primary_target.coord,
		maxi(0, skill_data.area_radius),
		GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	)
	for target in targets:
		var result: Dictionary = _calculate_damage_result(
			acting_unit,
			target,
			int(round(float(acting_unit.get_physical_attack_value()) * skill_data.physical_power_multiplier)) + skill_data.damage_amount,
			0,
			true,
			false,
			false
		)
		_apply_damage_result(
			acting_unit,
			target,
			result,
			"%s girou %s em %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
			["Esquiva de basicos"],
			false,
			true,
			false
		)
	_refresh_actor_state(acting_unit)
	return not targets.is_empty()

func _cast_target_magic_stun_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var target: BattleUnitState = _find_target_for_unit(acting_unit)
	if target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, target.coord, acting_unit.get_skill_range(), target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	target.apply_turn_skip(maxi(1, skill_data.turn_skip_count))
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
		"%s used %s on %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
		["Atordoado"],
		false,
		true,
		false
	)
	return true

func _cast_cone_magic_dispel_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var primary_target: BattleUnitState = _find_target_for_unit(acting_unit)
	if primary_target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, primary_target.coord, acting_unit.get_skill_range(), primary_target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	var targets: Array[BattleUnitState] = _build_cone_targets(
		acting_unit,
		primary_target,
		maxi(0, skill_data.area_radius),
		GameEnums.TeamSide.PLAYER if acting_unit.team_side == GameEnums.TeamSide.ENEMY else GameEnums.TeamSide.ENEMY
	)
	for target in targets:
		if skill_data.remove_positive_buffs:
			target.clear_positive_effects()
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
		if skill_data.remove_positive_buffs:
			notes.append("Dissipa buffs")
		_apply_damage_result(
			acting_unit,
			target,
			result,
			"%s liberou %s em %s" % [acting_unit.get_combat_label(), skill_name, target.get_combat_label()],
			notes,
			false,
			true,
			false
		)
	return not targets.is_empty()

func _cast_target_charm_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var target: BattleUnitState = _find_closest_enemy(acting_unit)
	if target == null:
		return false
	if _move_towards_skill_target_if_needed(acting_unit, target.coord, acting_unit.get_skill_range(), target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	target.apply_charm(acting_unit, maxi(1, skill_data.duration_turns))
	if target.actor:
		target.actor.on_damage()
	print("UNIT SKILL: %s encantou %s com %s" % [
		acting_unit.get_combat_label(),
		target.get_combat_label(),
		skill_name,
	])
	_refresh_actor_state(target)
	return true

func _cast_adjacent_magic_shield_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var shield_target: BattleUnitState = _find_most_injured_ally(acting_unit, true)
	if shield_target == null:
		shield_target = acting_unit
	if shield_target != acting_unit and _move_towards_skill_target_if_needed(acting_unit, shield_target.coord, 1, shield_target):
		return true
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	shield_target.apply_magic_shield(maxi(1, skill_data.magic_shield_amount), maxi(1, skill_data.duration_turns))
	if shield_target.actor:
		shield_target.actor.on_buff()
	print("UNIT SKILL: %s protegeu %s com %s (%d escudo magico)" % [
		acting_unit.get_combat_label(),
		shield_target.get_combat_label(),
		skill_name,
		maxi(1, skill_data.magic_shield_amount),
	])
	_refresh_actor_state(shield_target)
	return true

func _cast_adjacent_cleanse_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var cleanse_anchor: BattleUnitState = _find_ally_with_negative_status(acting_unit)
	if cleanse_anchor != null and _move_towards_skill_target_if_needed(acting_unit, cleanse_anchor.coord, 1, cleanse_anchor):
		return true
	var cleanse_targets: Array[BattleUnitState] = []
	for target in _get_units_in_radius(acting_unit.coord, 1, acting_unit.team_side):
		if target == acting_unit:
			continue
		if _unit_has_negative_status(target):
			cleanse_targets.append(target)
	if cleanse_targets.is_empty():
		return false
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	for target in cleanse_targets:
		target.clear_negative_effects()
		if target.actor:
			target.actor.on_buff()
		_refresh_actor_state(target)
	print("UNIT SKILL: %s purificou %d aliados com %s" % [
		acting_unit.get_combat_label(),
		cleanse_targets.size(),
		skill_name,
	])
	return true

func _cast_line_haste_skill(acting_unit: BattleUnitState, skill_data: SkillData, skill_name: String) -> bool:
	var haste_targets: Array[BattleUnitState] = _get_wind_haste_targets(acting_unit)
	if haste_targets.is_empty():
		return false
	if not acting_unit.spend_mana(acting_unit.get_skill_mana_cost()):
		return false
	if acting_unit.actor:
		acting_unit.actor.on_skill_cast()
	for target in haste_targets:
		target.apply_action_charge_multiplier(maxf(1.0, skill_data.action_charge_multiplier), maxi(1, skill_data.duration_turns))
		if target.actor:
			target.actor.on_buff()
		_refresh_actor_state(target)
	print("UNIT SKILL: %s acelerou %d aliados com %s" % [
		acting_unit.get_combat_label(),
		haste_targets.size(),
		skill_name,
	])
	return true

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

func _spawn_summoned_unit_from_path(
	unit_path: String,
	team_side: int,
	spawn_coord: Vector2i,
	source_unit: BattleUnitState = null,
	stat_scale: float = 1.0,
	current_hp_ratio: float = 1.0,
	clear_skills: bool = false
) -> BattleUnitState:
	if unit_path.is_empty() or not board_grid.is_valid_coord(spawn_coord):
		return null
	var template_unit_data: UnitData = _load_unit_data(unit_path)
	if template_unit_data == null:
		return null

	var summon_data: UnitData = template_unit_data.duplicate(true) as UnitData
	if summon_data == null:
		return null
	if stat_scale != 1.0:
		summon_data.max_hp = maxi(1, int(round(float(summon_data.max_hp) * stat_scale)))
		summon_data.physical_attack = maxi(0, int(round(float(summon_data.physical_attack) * stat_scale)))
		summon_data.magic_attack = maxi(0, int(round(float(summon_data.magic_attack) * stat_scale)))
		summon_data.physical_defense = maxi(0, int(round(float(summon_data.physical_defense) * stat_scale)))
		summon_data.magic_defense = maxi(0, int(round(float(summon_data.magic_defense) * stat_scale)))
	if clear_skills:
		summon_data.skill_data = null
		summon_data.master_skill_data = null

	var summon_state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
		summon_data,
		team_side,
		spawn_coord,
		false,
		spawn_coord
	)
	summon_state.current_hp = clampi(
		maxi(1, int(round(float(summon_state.unit_data.max_hp) * clampf(current_hp_ratio, 0.1, 1.0)))),
		1,
		summon_state.unit_data.max_hp
	)
	var source_unit_id: String = summon_state.unit_data.id
	if source_unit != null and source_unit.unit_data != null:
		source_unit_id = source_unit.unit_data.id
	summon_state.mark_as_summoned_token(source_unit_id)
	if not board_grid.spawn_unit(summon_state):
		return null
	runtime_units.append(summon_state)
	return summon_state

func _spawn_necromancer_skeletons(caster: BattleUnitState, skill_data: SkillData) -> int:
	if skill_data == null or skill_data.summon_unit_path.is_empty():
		return 0

	var summon_count: int = maxi(1, skill_data.summon_count)
	var summon_ratio: float = maxf(
		0.05,
		skill_data.summon_stat_ratio + (float(_get_mordos_souls(caster.team_side)) * MORDOS_SOUL_STAT_RATIO_PER_STACK)
	)
	var total_spawned: int = 0
	for _i in range(summon_count):
		var spawn_coord: Vector2i = _resolve_necromancer_summon_coord(caster)
		if not board_grid.is_valid_coord(spawn_coord):
			break
		var summon_state: BattleUnitState = _spawn_summoned_unit_from_path(
			skill_data.summon_unit_path,
			caster.team_side,
			spawn_coord,
			caster,
			summon_ratio,
			1.0,
			true
		)
		if summon_state == null:
			continue
		summon_state.unit_data.max_hp = maxi(1, int(round(float(caster.unit_data.max_hp) * summon_ratio)))
		summon_state.unit_data.physical_attack = maxi(1, int(round(float(caster.get_physical_attack_value()) * summon_ratio)))
		summon_state.unit_data.magic_attack = maxi(0, int(round(float(caster.get_magic_attack_value()) * summon_ratio)))
		summon_state.unit_data.physical_defense = maxi(0, int(round(float(caster.get_physical_defense_value()) * summon_ratio)))
		summon_state.unit_data.magic_defense = maxi(0, int(round(float(caster.get_magic_defense_value()) * summon_ratio)))
		summon_state.current_hp = summon_state.unit_data.max_hp
		total_spawned += 1
		print("SUMMON: %s invocou Esqueleto em %s (almas=%d ratio=%.2f)" % [
			caster.get_combat_label(),
			spawn_coord,
			_get_mordos_souls(caster.team_side),
			summon_ratio,
		])

	if total_spawned > 0:
		_refresh_race_synergy_state(true)
	return total_spawned

func _resolve_necromancer_summon_coord(caster: BattleUnitState) -> Vector2i:
	if caster == null or board_grid == null or not board_grid.is_valid_coord(caster.coord):
		return Vector2i(-1, -1)
	return _resolve_summon_coord_near_origin(caster.coord, caster.team_side, "Mordos")

func _resolve_summon_coord_near_origin(origin_coord: Vector2i, team_side: int, source_label: String = "invocacao") -> Vector2i:
	if board_grid == null or not board_grid.is_valid_coord(origin_coord):
		return Vector2i(-1, -1)

	var adjacent_coord: Vector2i = _find_free_adjacent_coord_near_caster(origin_coord, team_side)
	if board_grid.is_valid_coord(adjacent_coord):
		return adjacent_coord

	var nearby_coord: Vector2i = _find_free_coord_near_origin(origin_coord, team_side, SUMMON_NEARBY_RADIUS)
	if board_grid.is_valid_coord(nearby_coord):
		return nearby_coord

	var broad_fallback: Vector2i = _find_nearest_free_coord_anywhere(origin_coord, team_side)
	if board_grid.is_valid_coord(broad_fallback):
		print("SUMMON fallback: sem espaco perto de %s em %s, usando celula livre mais proxima %s" % [
			source_label,
			origin_coord,
			broad_fallback,
		])
		return broad_fallback

	var final_fallback: Vector2i = _find_first_free_coord_in_zone(team_side)
	if board_grid.is_valid_coord(final_fallback):
		print("SUMMON fallback: sem espaco perto de %s nem ao redor imediato, usando fallback de zona %s" % [source_label, final_fallback])
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
		var soul_count: int = _add_mordos_souls(unit_state.team_side, 1)
		print("COLHEITA DE ALMAS: %s chegou a %d almas apos a morte de %s" % [
			unit_state.get_combat_label(),
			soul_count,
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
		_refresh_actor_state(master )

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
		_get_persistent_master_home_coord(unit_state.team_side) if unit_state.is_master else unit_state.home_coord,
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
	if board_grid:
		board_grid.clear_selection()
	if observer_state.is_remote_view():
		if battle_hud:
			battle_hud.clear_unit_info()
		_refresh_observer_binding_if_needed(false)
	else:
		_apply_local_board_view_for_phase()
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
		_record_persistent_formation_unit(unit_state)
		if unit_state.is_master:
			_set_persistent_master_home_coord(unit_state.team_side, unit_state.coord)

	if committed_units.is_empty():
		print("FORMATION lock: %d player units anchored" % _count_living_team(GameEnums.TeamSide.PLAYER))
	else:
		print("FORMATION lock: %s" % _join_strings(committed_units))

func _refresh_inspected_unit_panel() -> void:
	if not battle_hud:
		return

	if inspected_unit != null:
		if inspected_unit.is_dead() and inspected_unit.actor == null:
			inspected_unit = null
		elif observer_state.is_remote_view() and board_grid != null and not board_grid.is_observed_unit_visible_in_current_view(inspected_unit):
			inspected_unit = null
		else:
			var display_unit: BattleUnitState = inspected_unit
			if observer_state.is_remote_view():
				display_unit = _build_observed_unit_preview(inspected_unit)
			if display_unit == null:
				inspected_unit = null
			else:
				battle_hud.update_unit_info(display_unit)
				_sync_world_overlay_focus()
				return
			_sync_world_overlay_focus()

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
	if observer_state.is_remote_view():
		battle_hud.clear_unit_info()
		_sync_world_overlay_focus()
		return
	battle_hud.clear_unit_info()
	_sync_world_overlay_focus()

func _build_observed_unit_preview(source_unit: BattleUnitState) -> BattleUnitState:
	if source_unit == null or source_unit.unit_data == null or board_grid == null:
		return null
	var display_coord: Vector2i = board_grid.get_observed_display_coord(source_unit)
	var display_team_side: int = board_grid.get_observed_display_team_side(source_unit)
	var preview_state: BattleUnitState = BattleUnitState.new().setup_from_unit_data(
		source_unit.unit_data,
		display_team_side,
		display_coord,
		source_unit.is_master,
		display_coord
	)
	_copy_observed_unit_preview_runtime(source_unit, preview_state)
	return preview_state

func _copy_observed_unit_preview_runtime(source_unit: BattleUnitState, preview_state: BattleUnitState) -> void:
	if source_unit == null or preview_state == null:
		return
	preview_state.current_hp = source_unit.current_hp
	preview_state.current_mana = source_unit.current_mana
	preview_state.alive = source_unit.alive
	preview_state.home_coord = preview_state.coord
	preview_state.bonus_physical_attack = source_unit.bonus_physical_attack
	preview_state.bonus_magic_attack = source_unit.bonus_magic_attack
	preview_state.bonus_physical_defense = source_unit.bonus_physical_defense
	preview_state.bonus_magic_defense = source_unit.bonus_magic_defense
	preview_state.deck_passive_physical_attack = source_unit.deck_passive_physical_attack
	preview_state.deck_passive_magic_attack = source_unit.deck_passive_magic_attack
	preview_state.deck_passive_physical_defense = source_unit.deck_passive_physical_defense
	preview_state.deck_passive_magic_defense = source_unit.deck_passive_magic_defense
	preview_state.synergy_race_count = source_unit.synergy_race_count
	preview_state.synergy_tier = source_unit.synergy_tier
	preview_state.synergy_summary = source_unit.synergy_summary
	preview_state.synergy_physical_attack = source_unit.synergy_physical_attack
	preview_state.synergy_magic_attack = source_unit.synergy_magic_attack
	preview_state.synergy_physical_defense = source_unit.synergy_physical_defense
	preview_state.synergy_magic_defense = source_unit.synergy_magic_defense
	preview_state.synergy_crit_bonus = source_unit.synergy_crit_bonus
	preview_state.synergy_mana_bonus = source_unit.synergy_mana_bonus
	preview_state.synergy_undead_sustain_bonus = source_unit.synergy_undead_sustain_bonus
	preview_state.synergy_action_charge_bonus = source_unit.synergy_action_charge_bonus
	preview_state.action_charge = source_unit.action_charge
	preview_state.is_summoned_token = source_unit.is_summoned_token
	preview_state.token_expires_end_round = source_unit.token_expires_end_round
	preview_state.source_unit_id = source_unit.source_unit_id
	preview_state.death_skill_consumed = source_unit.death_skill_consumed
	preview_state.physical_defense_multiplier_status = source_unit.physical_defense_multiplier_status
	preview_state.physical_defense_debuff_turns = source_unit.physical_defense_debuff_turns
	preview_state.magic_defense_multiplier_status = source_unit.magic_defense_multiplier_status
	preview_state.magic_defense_debuff_turns = source_unit.magic_defense_debuff_turns
	preview_state.mana_gain_multiplier_status = source_unit.mana_gain_multiplier_status
	preview_state.mana_gain_modifier_turns = source_unit.mana_gain_modifier_turns
	preview_state.action_charge_multiplier_status = source_unit.action_charge_multiplier_status
	preview_state.action_charge_modifier_turns = source_unit.action_charge_modifier_turns
	preview_state.skip_turns_remaining = source_unit.skip_turns_remaining
	preview_state.stealth_turns_remaining = source_unit.stealth_turns_remaining
	preview_state.physical_miss_chance_status = source_unit.physical_miss_chance_status
	preview_state.physical_miss_turns = source_unit.physical_miss_turns
	preview_state.received_physical_damage_multiplier_status = source_unit.received_physical_damage_multiplier_status
	preview_state.received_physical_damage_turns = source_unit.received_physical_damage_turns
	preview_state.current_physical_shield = source_unit.current_physical_shield
	preview_state.physical_shield_turns = source_unit.physical_shield_turns
	preview_state.current_magic_shield = source_unit.current_magic_shield
	preview_state.magic_shield_turns = source_unit.magic_shield_turns
	preview_state.melee_reflect_damage = source_unit.melee_reflect_damage
	preview_state.reflect_turns = source_unit.reflect_turns
	preview_state.melee_attacker_action_multiplier = source_unit.melee_attacker_action_multiplier
	preview_state.melee_attacker_action_turns = source_unit.melee_attacker_action_turns
	preview_state.guaranteed_magic_crit_hits = source_unit.guaranteed_magic_crit_hits
	preview_state.death_mana_ratio_to_master = source_unit.death_mana_ratio_to_master
	preview_state.blocked_basic_attack_count = source_unit.blocked_basic_attack_count
	preview_state.lifesteal_ratio_status = source_unit.lifesteal_ratio_status
	preview_state.lifesteal_turns = source_unit.lifesteal_turns
	preview_state.attack_range_bonus_status = source_unit.attack_range_bonus_status
	preview_state.attack_range_bonus_turns = source_unit.attack_range_bonus_turns
	preview_state.cleave_attacks_remaining = source_unit.cleave_attacks_remaining
	preview_state.forced_target_instance_id = source_unit.forced_target_instance_id
	preview_state.forced_target_turns = source_unit.forced_target_turns
	preview_state.charm_source_instance_id = source_unit.charm_source_instance_id
	preview_state.charm_turns = source_unit.charm_turns

func _sync_world_overlay_focus() -> void:
	var suppress_overlays: bool = battle_hud != null and battle_hud.is_info_panel_open()
	for unit_state in runtime_units:
		if unit_state == null or unit_state.actor == null:
			continue
		unit_state.actor.set_overlay_suppressed(suppress_overlays)
	if board_grid:
		board_grid.set_observed_overlay_suppressed(suppress_overlays)

func _on_board_unit_right_clicked(unit_state: BattleUnitState) -> void:
	_exit_observer_mode_if_needed(false)
	inspected_unit = unit_state
	inspected_deploy_index = -1
	inspected_support_index = -1
	_refresh_inspected_unit_panel()

func _on_observed_board_unit_right_clicked(unit_state: BattleUnitState) -> void:
	inspected_unit = unit_state
	inspected_deploy_index = -1
	inspected_support_index = -1
	_refresh_inspected_unit_panel()

func _on_board_empty_right_clicked() -> void:
	_clear_inspected_context()

func _on_player_sidebar_entry_pressed(player_id: String) -> void:
	if card_shop_open:
		return
	if player_id.is_empty() or player_id == LOCAL_PLAYER_ID:
		_return_to_local_board()
		return

	if observer_state.is_remote_view() and observer_state.observed_player_id == player_id:
		_return_to_local_board()
		return

	var observed_runtime: Dictionary = lobby_manager.get_observed_runtime(player_id)
	if observed_runtime.is_empty():
		print("OBSERVER: mesa indisponivel para %s" % player_id)
		return

	_clear_drag_state()
	_clear_support_selection(false)
	selected_deploy_index = -1
	_bind_observed_runtime(player_id, observed_runtime)
	_emit_hud_update()
	print("OBSERVER bind player=%s table=%s" % [
		player_id,
		str(observed_runtime.get("table_id", "")),
	])

func _on_return_to_local_board_pressed() -> void:
	_return_to_local_board()

func _return_to_local_board() -> void:
	if not observer_state.is_remote_view() and not _is_observer_mode_active():
		return
	observer_state.begin_return_to_local()
	inspected_unit = null
	inspected_deploy_index = -1
	inspected_support_index = -1
	if board_grid:
		board_grid.clear_selection()
		board_grid.clear_observed_runtime()
	_apply_local_board_view_for_phase()
	if battle_hud:
		battle_hud.clear_unit_info()
		battle_hud.clear_observer_banner()
	_sync_world_overlay_focus()
	_emit_hud_update()
	observer_state.finish_return_to_local()
	print("OBSERVER return_to_local")

func _bind_observed_runtime(requested_player_id: String, observed_runtime: Dictionary) -> void:
	if observed_runtime.is_empty():
		return
	var target_player_id: String = str(observed_runtime.get("player_id", requested_player_id))
	if target_player_id.is_empty():
		print("OBSERVER: runtime sem player_id, troca ignorada")
		return
	var observed_table_id: String = str(observed_runtime.get("table_id", ""))
	if observed_table_id.is_empty():
		print("OBSERVER: runtime sem table_id, troca ignorada")
		return
	var rebind_required: bool = observed_table_id != observer_state.observed_table_id
	observer_state.enter_remote_view(target_player_id, observed_table_id)
	inspected_unit = null
	inspected_deploy_index = -1
	inspected_support_index = -1
	if battle_hud:
		battle_hud.clear_unit_info()
	if board_grid:
		board_grid.clear_selection()
		var observed_units: Array[BattleUnitState] = observed_runtime.get("unit_states", [])
		var viewer_team_side: int = int(observed_runtime.get("viewer_team_side", GameEnums.TeamSide.PLAYER))
		if rebind_required or not board_grid.is_observer_mode_active():
			board_grid.bind_observed_runtime(observed_units, viewer_team_side)
		else:
			board_grid.refresh_observed_runtime(false, viewer_team_side)
	_apply_observer_board_view_mode(observed_runtime)
	_refresh_observer_banner(observed_runtime)
	_sync_world_overlay_focus()

func _refresh_observer_binding_if_needed(animate: bool = false) -> void:
	if not observer_state.is_remote_view():
		return
	var observed_runtime: Dictionary = lobby_manager.get_observed_runtime(observer_state.observed_player_id)
	if observed_runtime.is_empty():
		_return_to_local_board()
		return
	var observed_table_id: String = str(observed_runtime.get("table_id", ""))
	if observed_table_id != observer_state.observed_table_id:
		_bind_observed_runtime(observer_state.observed_player_id, observed_runtime)
		return
	if board_grid:
		var viewer_team_side: int = int(observed_runtime.get("viewer_team_side", GameEnums.TeamSide.PLAYER))
		if not board_grid.is_observer_mode_active():
			board_grid.bind_observed_runtime(observed_runtime.get("unit_states", []), viewer_team_side)
		else:
			board_grid.refresh_observed_runtime(animate, viewer_team_side)
	_refresh_observer_banner(observed_runtime)
	if inspected_unit != null:
		_refresh_inspected_unit_panel()
	_apply_observer_board_view_mode(observed_runtime)

func _refresh_observer_banner(observed_runtime: Dictionary) -> void:
	if battle_hud == null:
		return
	if observed_runtime.is_empty():
		battle_hud.clear_observer_banner()
		return
	var phase_name: String = str(observed_runtime.get("phase", "PREPARACAO"))
	if phase_name == "PREPARACAO":
		var observed_player_name: String = str(observed_runtime.get("player_name", "Jogador"))
		battle_hud.set_observer_banner("OBSERVANDO: %s" % observed_player_name)
		return
	var table_player_a_name: String = str(observed_runtime.get("table_player_a_name", "Jogador A"))
	var table_player_b_name: String = str(observed_runtime.get("table_player_b_name", "Jogador B"))
	if table_player_b_name.is_empty():
		battle_hud.set_observer_banner("OBSERVANDO: %s" % table_player_a_name)
		return
	battle_hud.set_observer_banner("OBSERVANDO: %s vs %s" % [table_player_a_name, table_player_b_name])

func _apply_observer_board_view_mode(observed_runtime: Dictionary) -> void:
	if observed_runtime.is_empty():
		return
	var phase_name: String = str(observed_runtime.get("phase", "PREPARACAO"))
	var observer_view_mode: int = GameEnums.BoardViewMode.SELF_ONLY if phase_name == "PREPARACAO" else GameEnums.BoardViewMode.FULL_BATTLE
	_apply_board_view_mode(observer_view_mode, true)

func _exit_observer_mode_if_needed(clear_hud: bool) -> void:
	if not observer_state.is_remote_view() and not _is_observer_mode_active():
		return
	_return_to_local_board()
	if clear_hud and battle_hud and not observer_state.is_remote_view():
		battle_hud.clear_unit_info()

func _apply_local_board_view_for_phase() -> void:
	var target_view_mode: int = GameEnums.BoardViewMode.SELF_ONLY if current_state == GameEnums.BattleState.PREP else GameEnums.BoardViewMode.FULL_BATTLE
	_apply_board_view_mode(target_view_mode, true)

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
	lobby_manager.finalize_match_if_needed(current_round)
	return lobby_manager.is_match_finished()

func _get_match_winner_label() -> String:
	var winner_state: MatchPlayerState = lobby_manager.get_match_winner()
	if winner_state != null:
		return winner_state.display_name
	return "NONE"

func _set_selected_prep_unit(new_selection: BattleUnitState) -> void:
	if selected_prep_unit != null and selected_prep_unit.actor != null:
		selected_prep_unit.actor.set_selected(false)

	selected_prep_unit = new_selection

	if selected_prep_unit != null and selected_prep_unit.actor != null:
		selected_prep_unit.actor.set_selected(true)
