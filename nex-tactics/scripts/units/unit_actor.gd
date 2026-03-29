extends Node2D
class_name UnitActor

const PLAYER_COLOR := Color(0.22, 0.62, 0.98, 0.95)
const ENEMY_COLOR := Color(0.94, 0.35, 0.35, 0.95)
const OUTLINE_COLOR := Color(0.08, 0.08, 0.08, 1.0)
const MASTER_OUTLINE_COLOR := Color(0.98, 0.86, 0.25, 1.0)
const SELECTED_OUTLINE_COLOR := Color(0.98, 0.98, 0.50, 1.0)
const HP_BAR_BG := Color(0.12, 0.12, 0.12, 0.9)
const HP_BAR_FILL := Color(0.26, 0.9, 0.35, 0.95)
const MANA_BAR_BG := Color(0.12, 0.12, 0.12, 0.9)
const MANA_BAR_FILL := Color(0.34, 0.66, 1.0, 0.95)
const DEAD_TINT := Color(0.35, 0.35, 0.35, 0.8)
const DAMAGE_FLASH_TINT := Color(1.0, 0.82, 0.82, 1.0)
const SKILL_CAST_TINT := Color(0.98, 0.92, 0.55, 1.0)
const HEAL_FLASH_TINT := Color(0.68, 1.0, 0.72, 1.0)
const BUFF_FLASH_TINT := Color(0.72, 0.9, 1.0, 1.0)

var state: BattleUnitState
var cell_size: float = 64.0
var is_selected: bool = false
var use_3d_presentation: bool = false
var board_presentation_3d: BoardPresentation3D
var visual_3d: UnitVisual3D
var visual_death_started: bool = false
var screen_anchor_visible: bool = true
var overlay_visual_scale: float = 1.0
var overlay_suppressed: bool = false

@onready var name_label: Label = $NameLabel
@onready var tag_label: Label = $TagLabel
@onready var hp_label: Label = $HpLabel
@onready var mana_label: Label = $ManaLabel

func setup(
	p_state: BattleUnitState,
	p_cell_size: float,
	p_board_presentation_3d: BoardPresentation3D = null
) -> void:
	state = p_state
	cell_size = p_cell_size
	board_presentation_3d = p_board_presentation_3d
	use_3d_presentation = board_presentation_3d != null
	if board_presentation_3d != null:
		visual_3d = board_presentation_3d.create_unit_visual(state)
		visual_3d.visible = visible
	set_process(use_3d_presentation)
	_configure_labels()
	_refresh_visual()
	_update_3d_overlay_anchor()

func refresh_from_state() -> void:
	_refresh_visual()

func update_from_grid_coord(grid_coord: Vector2i, p_cell_size: float = -1.0, animate: bool = true) -> void:
	if p_cell_size > 0.0:
		cell_size = p_cell_size

	var target_position: Vector2 = Vector2(grid_coord.x + 0.5, grid_coord.y + 0.5) * cell_size
	if not use_3d_presentation and animate:
		var move_tween := create_tween()
		move_tween.tween_property(self, "position", target_position, BattleConfig.UNIT_MOVE_TWEEN_SECONDS)
	else:
		position = target_position

	if state != null:
		state.coord = grid_coord

	if visual_3d != null:
		visual_3d.move_to_coord(grid_coord, animate)

	_refresh_visual()
	_update_3d_overlay_anchor()

func _get_unit_name() -> String:
	if state == null:
		return "Unit"

	var base_name: String = state.get_display_name()
	if state.is_master:
		return "[M] " + base_name
	return base_name

func _short_unit_name() -> String:
	var full_name: String = _get_unit_name()
	if full_name.length() <= 12:
		return full_name
	return full_name.substr(0, 12)

func _team_color() -> Color:
	if state != null and state.team_side == GameEnums.TeamSide.ENEMY:
		return ENEMY_COLOR
	return PLAYER_COLOR

func _race_color() -> Color:
	if state == null or state.unit_data == null:
		return Color.WHITE

	match state.unit_data.race:
		GameEnums.Race.HUMAN:
			return Color(0.96, 0.85, 0.44, 1.0)
		GameEnums.Race.ELF:
			return Color(0.44, 0.96, 0.70, 1.0)
		GameEnums.Race.FAIRY:
			return Color(0.48, 0.92, 1.0, 1.0)
		GameEnums.Race.OGRE:
			return Color(0.82, 0.48, 0.22, 1.0)
		GameEnums.Race.UNDEAD:
			return Color(0.58, 0.88, 0.48, 1.0)
		GameEnums.Race.BEAST:
			return Color(0.92, 0.42, 0.30, 1.0)
		_:
			return Color.WHITE

func _configure_labels() -> void:
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.clip_text = true
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.clip_text = true
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.clip_text = true
	mana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_apply_overlay_layout(overlay_visual_scale)

func _refresh_visual() -> void:
	name = _get_unit_name()
	name_label.text = _short_unit_name()

	if state != null:
		tag_label.text = "%s %s" % [state.get_race_short_label(), state.get_class_short_label()]
		if state.is_dead():
			hp_label.text = "KO"
			mana_label.text = "MN 0"
			modulate = DEAD_TINT
		else:
			var hp_max: int = maxi(1, state.unit_data.max_hp)
			var mana_max: int = maxi(1, state.get_mana_max())
			hp_label.text = "PV %d/%d" % [state.current_hp, hp_max]
			mana_label.text = "MN %d/%d" % [state.current_mana, mana_max]
			modulate = Color.WHITE
	else:
		tag_label.text = ""
		hp_label.text = "PV 0"
		mana_label.text = "MN 0"
		modulate = Color.WHITE

	queue_redraw()
	if visual_3d != null:
		visual_3d.refresh_from_state()

func _process(_delta: float) -> void:
	if use_3d_presentation:
		_update_3d_overlay_anchor()

func on_damage() -> void:
	_refresh_visual()
	if visual_3d != null:
		visual_3d.on_damage()
	modulate = DAMAGE_FLASH_TINT
	scale = Vector2(1.14, 1.14)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, BattleConfig.UNIT_IMPACT_COLOR_SECONDS)
	tween.tween_property(self, "scale", Vector2.ONE, BattleConfig.UNIT_IMPACT_RECOVER_SECONDS)

func on_skill_cast() -> void:
	if visual_3d != null:
		visual_3d.on_skill_cast()
	modulate = SKILL_CAST_TINT
	scale = Vector2(1.2, 1.2)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, BattleConfig.UNIT_EFFECT_COLOR_SECONDS)
	tween.tween_property(self, "scale", Vector2.ONE, BattleConfig.UNIT_EFFECT_RECOVER_SECONDS)

func on_heal() -> void:
	_refresh_visual()
	if visual_3d != null:
		visual_3d.on_heal()
	modulate = HEAL_FLASH_TINT
	scale = Vector2(1.08, 1.08)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, BattleConfig.UNIT_EFFECT_COLOR_SECONDS)
	tween.tween_property(self, "scale", Vector2.ONE, BattleConfig.UNIT_EFFECT_RECOVER_SECONDS)

func on_buff() -> void:
	_refresh_visual()
	if visual_3d != null:
		visual_3d.on_buff()
	modulate = BUFF_FLASH_TINT
	scale = Vector2(1.1, 1.1)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, BattleConfig.UNIT_EFFECT_COLOR_SECONDS)
	tween.tween_property(self, "scale", Vector2.ONE, BattleConfig.UNIT_EFFECT_RECOVER_SECONDS)

func on_death() -> void:
	_refresh_visual()
	visual_death_started = true
	if visual_3d != null:
		visual_3d.on_death()
	scale = Vector2(0.84, 0.84)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, BattleConfig.UNIT_DEATH_FADE_SECONDS)
	tween.finished.connect(queue_free)

func set_selected(value: bool) -> void:
	is_selected = value
	if visual_3d != null:
		visual_3d.set_selected(value)
	queue_redraw()

func set_overlay_suppressed(value: bool) -> void:
	if overlay_suppressed == value:
		return
	overlay_suppressed = value
	_set_overlay_labels_visible(screen_anchor_visible)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visual_3d != null:
		visual_3d.visible = visible

func _exit_tree() -> void:
	if visual_3d != null and not visual_death_started:
		visual_3d.queue_free()
		visual_3d = null

func _draw() -> void:
	if use_3d_presentation and (not screen_anchor_visible or overlay_suppressed):
		return

	var body_scale: float = overlay_visual_scale if use_3d_presentation else 1.0
	var body_size: float = cell_size * (0.62 if state != null and state.is_master else 0.55) * body_scale
	var body_rect := Rect2(Vector2(-body_size * 0.5, -body_size * 0.5), Vector2(body_size, body_size))
	var accent_height: float = 8.0

	if not use_3d_presentation:
		draw_rect(body_rect, _team_color(), true)
		draw_rect(Rect2(body_rect.position, Vector2(body_rect.size.x, accent_height)), _race_color(), true)

		var outline_color: Color = MASTER_OUTLINE_COLOR if state != null and state.is_master else OUTLINE_COLOR
		var outline_width: float = 3.0 if state != null and state.is_master else 2.0
		if is_selected:
			outline_color = SELECTED_OUTLINE_COLOR
			outline_width = 4.0
		draw_rect(body_rect, outline_color, false, outline_width)

	var hp_max: int = 1
	var hp_current: int = 0
	var mana_max: int = 1
	var mana_current: int = 0
	if state != null and state.unit_data != null:
		hp_max = maxi(state.unit_data.max_hp, 1)
		hp_current = clampi(state.current_hp, 0, hp_max)
		mana_max = maxi(state.get_mana_max(), 1)
		mana_current = clampi(state.current_mana, 0, mana_max)

	var hp_ratio: float = float(hp_current) / float(hp_max)
	var mana_ratio: float = float(mana_current) / float(mana_max)
	var bar_width: float = body_size * (0.92 if use_3d_presentation else 1.0)
	var bar_height: float = 6.0
	var hp_bar_pos := Vector2(-bar_width * 0.5, -body_size * 0.5 - 12.0)
	var mana_bar_pos := Vector2(-bar_width * 0.5, -body_size * 0.5 - 4.0)

	draw_rect(Rect2(hp_bar_pos, Vector2(bar_width, bar_height)), HP_BAR_BG, true)
	draw_rect(Rect2(hp_bar_pos, Vector2(bar_width * hp_ratio, bar_height)), HP_BAR_FILL, true)
	draw_rect(Rect2(mana_bar_pos, Vector2(bar_width, bar_height)), MANA_BAR_BG, true)
	draw_rect(Rect2(mana_bar_pos, Vector2(bar_width * mana_ratio, bar_height)), MANA_BAR_FILL, true)

func _update_3d_overlay_anchor() -> void:
	if not use_3d_presentation or board_presentation_3d == null or visual_3d == null:
		screen_anchor_visible = true
		_set_overlay_scale(1.0)
		_set_overlay_labels_visible(true)
		return

	var parent_canvas: CanvasItem = get_parent() as CanvasItem
	if parent_canvas == null:
		return

	var projection: Dictionary = board_presentation_3d.project_world_to_screen(
		visual_3d.get_overlay_anchor_world_position()
	)
	var anchor_visible: bool = bool(projection.get("visible", false))
	if screen_anchor_visible != anchor_visible:
		screen_anchor_visible = anchor_visible
		_set_overlay_labels_visible(anchor_visible)
		queue_redraw()

	if not anchor_visible:
		return

	var screen_position: Vector2 = projection.get("screen_position", Vector2.ZERO)
	position = parent_canvas.get_global_transform_with_canvas().affine_inverse() * screen_position

	var base_projection: Dictionary = board_presentation_3d.project_world_to_screen(
		visual_3d.get_overlay_base_world_position()
	)
	var top_projection: Dictionary = board_presentation_3d.project_world_to_screen(
		visual_3d.get_overlay_top_world_position()
	)
	if bool(base_projection.get("visible", false)) and bool(top_projection.get("visible", false)):
		var base_position: Vector2 = base_projection.get("screen_position", screen_position)
		var top_position: Vector2 = top_projection.get("screen_position", screen_position)
		var projected_height: float = absf(base_position.y - top_position.y)
		var target_scale: float = clampf(projected_height / 46.0, 0.82, 1.18)
		_set_overlay_scale(target_scale)

func _set_overlay_labels_visible(value: bool) -> void:
	var final_value: bool = value and not overlay_suppressed
	name_label.visible = final_value
	tag_label.visible = final_value
	hp_label.visible = final_value
	mana_label.visible = final_value

func _set_overlay_scale(value: float) -> void:
	var clamped_value: float = clampf(value, 0.82, 1.18)
	if is_equal_approx(overlay_visual_scale, clamped_value):
		return
	overlay_visual_scale = clamped_value
	_apply_overlay_layout(overlay_visual_scale)
	queue_redraw()

func _apply_overlay_layout(layout_scale: float) -> void:
	if use_3d_presentation:
		var ui_scale: float = clampf(layout_scale, 0.82, 1.18)
		name_label.position = Vector2(-34.0 * ui_scale, 4.0 * ui_scale)
		name_label.size = Vector2(68.0 * ui_scale, 12.0 * ui_scale)
		name_label.add_theme_font_size_override("font_size", maxi(9, int(round(10.0 * ui_scale))))

		tag_label.position = Vector2(-34.0 * ui_scale, 16.0 * ui_scale)
		tag_label.size = Vector2(68.0 * ui_scale, 12.0 * ui_scale)
		tag_label.add_theme_font_size_override("font_size", maxi(7, int(round(8.0 * ui_scale))))

		hp_label.position = Vector2(-28.0 * ui_scale, -40.0 * ui_scale)
		hp_label.size = Vector2(56.0 * ui_scale, 10.0 * ui_scale)
		hp_label.add_theme_font_size_override("font_size", maxi(7, int(round(8.0 * ui_scale))))

		mana_label.position = Vector2(-28.0 * ui_scale, -52.0 * ui_scale)
		mana_label.size = Vector2(56.0 * ui_scale, 10.0 * ui_scale)
		mana_label.add_theme_font_size_override("font_size", maxi(7, int(round(8.0 * ui_scale))))
		return

	name_label.position = Vector2(-28.0, 18.0)
	name_label.size = Vector2(56.0, 12.0)
	name_label.add_theme_font_size_override("font_size", 9)

	tag_label.position = Vector2(-28.0, 30.0)
	tag_label.size = Vector2(56.0, 12.0)
	tag_label.add_theme_font_size_override("font_size", 8)

	hp_label.position = Vector2(-24.0, -34.0)
	hp_label.size = Vector2(48.0, 10.0)
	hp_label.add_theme_font_size_override("font_size", 8)

	mana_label.position = Vector2(-24.0, -46.0)
	mana_label.size = Vector2(48.0, 10.0)
	mana_label.add_theme_font_size_override("font_size", 8)
