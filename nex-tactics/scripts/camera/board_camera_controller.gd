extends Camera2D
class_name BoardCameraController

@export var board_path: NodePath
@export var board_presentation_3d_path: NodePath
@export var self_only_zoom: Vector2 = Vector2(0.92, 0.92)
@export var full_battle_zoom: Vector2 = Vector2(0.88, 0.88)

func get_transition_duration() -> float:
	return BattleConfig.REVEAL_TRANSITION_SECONDS

func snap_to_mode(view_mode: int) -> void:
	position = _target_position_for_mode(view_mode)
	zoom = _target_zoom_for_mode(view_mode)
	var board_presentation_3d: BoardPresentation3D = get_node_or_null(board_presentation_3d_path) as BoardPresentation3D
	if board_presentation_3d != null:
		board_presentation_3d.snap_to_mode(view_mode)

func transition_to_mode(view_mode: int, duration: float = -1.0) -> Tween:
	var resolved_duration: float = duration if duration >= 0.0 else get_transition_duration()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "position", _target_position_for_mode(view_mode), resolved_duration)
	tween.parallel().tween_property(self, "zoom", _target_zoom_for_mode(view_mode), resolved_duration)
	var board_presentation_3d: BoardPresentation3D = get_node_or_null(board_presentation_3d_path) as BoardPresentation3D
	if board_presentation_3d != null:
		board_presentation_3d.transition_to_mode(view_mode, resolved_duration)
	return tween

func _target_position_for_mode(view_mode: int) -> Vector2:
	var board_grid: BoardGrid = get_node_or_null(board_path) as BoardGrid
	if board_grid == null:
		return position

	var board_rect: Rect2 = board_grid.get_board_rect_world()
	if view_mode == GameEnums.BoardViewMode.SELF_ONLY:
		return board_rect.position + (board_rect.size * Vector2(0.5, 0.54))

	return board_rect.position + (board_rect.size * 0.5)

func _target_zoom_for_mode(view_mode: int) -> Vector2:
	if view_mode == GameEnums.BoardViewMode.SELF_ONLY:
		return self_only_zoom
	return full_battle_zoom
