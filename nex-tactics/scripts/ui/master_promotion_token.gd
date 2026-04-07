extends Control
class_name MasterPromotionToken

signal drag_started(screen_pos: Vector2)
signal drag_moved(screen_pos: Vector2)
signal drag_released(screen_pos: Vector2)
signal drag_canceled

const TOKEN_BG_COLOR := Color(0.18, 0.13, 0.06, 0.98)
const TOKEN_BORDER_COLOR := Color(0.98, 0.79, 0.24, 1.0)
const TOKEN_DISABLED_BG_COLOR := Color(0.12, 0.12, 0.12, 0.90)
const TOKEN_DISABLED_BORDER_COLOR := Color(0.42, 0.42, 0.42, 1.0)
const TOKEN_VALID_BG_COLOR := Color(0.10, 0.24, 0.14, 0.98)
const TOKEN_VALID_BORDER_COLOR := Color(0.40, 0.95, 0.54, 1.0)
const TOKEN_INVALID_BG_COLOR := Color(0.28, 0.10, 0.10, 0.98)
const TOKEN_INVALID_BORDER_COLOR := Color(0.96, 0.38, 0.38, 1.0)
const BADGE_BG_COLOR := Color(0.95, 0.86, 0.48, 1.0)
const BADGE_TEXT_COLOR := Color(0.15, 0.10, 0.04, 1.0)
const TEXT_PRIMARY := Color(0.98, 0.96, 0.90, 1.0)
const TEXT_SECONDARY := Color(0.90, 0.84, 0.60, 1.0)
const TEXT_DISABLED := Color(0.72, 0.72, 0.72, 1.0)

var pending_count: int = 0
var interaction_enabled: bool = false
var drag_active: bool = false
var drop_valid: bool = false
var drag_hover_text: String = ""
var rest_hint_text: String = "Arraste"

@onready var rest_token_panel: PanelContainer = $RestTokenPanel
@onready var rest_title_label: Label = $RestTokenPanel/CenterContainer/TokenVBox/TitleLabel
@onready var rest_glyph_label: Label = $RestTokenPanel/CenterContainer/TokenVBox/GlyphLabel
@onready var rest_sub_label: Label = $RestTokenPanel/CenterContainer/TokenVBox/SubLabel
@onready var rest_badge_panel: PanelContainer = $RestBadgePanel
@onready var rest_badge_label: Label = $RestBadgePanel/MarginContainer/CountLabel
@onready var rest_hint_label: Label = $RestHintLabel
@onready var drag_preview: Control = $DragPreview
@onready var drag_token_panel: PanelContainer = $DragPreview/DragTokenPanel
@onready var drag_title_label: Label = $DragPreview/DragTokenPanel/CenterContainer/TokenVBox/TitleLabel
@onready var drag_glyph_label: Label = $DragPreview/DragTokenPanel/CenterContainer/TokenVBox/GlyphLabel
@onready var drag_sub_label: Label = $DragPreview/DragTokenPanel/CenterContainer/TokenVBox/SubLabel
@onready var drag_badge_panel: PanelContainer = $DragPreview/DragBadgePanel
@onready var drag_badge_label: Label = $DragPreview/DragBadgePanel/MarginContainer/CountLabel
@onready var drag_hint_label: Label = $DragPreview/DragHintLabel

func _ready() -> void:
	rest_token_panel.gui_input.connect(_on_rest_token_gui_input)
	rest_token_panel.mouse_default_cursor_shape = Control.CURSOR_DRAG
	drag_preview.top_level = true
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.visible = false
	hide_token()

func set_token_state(is_visible: bool, count: int, can_interact: bool, instruction_text: String) -> void:
	if not is_visible or count <= 0:
		hide_token()
		return

	visible = true
	pending_count = maxi(0, count)
	interaction_enabled = can_interact
	rest_hint_text = instruction_text.strip_edges()
	if rest_hint_text.is_empty():
		rest_hint_text = "Arraste"
	_refresh_rest_token_text()
	_apply_rest_token_style()

func set_drag_feedback(is_valid: bool, hover_text: String = "") -> void:
	drop_valid = is_valid
	drag_hover_text = hover_text.strip_edges()
	if not drag_active:
		return
	_refresh_drag_preview_text()
	_apply_drag_preview_style()

func cancel_drag() -> void:
	if not drag_active:
		_apply_rest_token_style()
		return
	_finish_drag_visual()

func hide_token() -> void:
	drag_active = false
	pending_count = 0
	interaction_enabled = false
	drop_valid = false
	drag_hover_text = ""
	drag_preview.visible = false
	visible = false

func is_drag_active() -> bool:
	return drag_active

func _input(event: InputEvent) -> void:
	if not drag_active:
		return

	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		_update_drag_preview_position(motion_event.position)
		drag_moved.emit(motion_event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			var release_position: Vector2 = mouse_event.position
			_update_drag_preview_position(release_position)
			_finish_drag_visual()
			drag_released.emit(release_position)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			_finish_drag_visual()
			drag_canceled.emit()
			get_viewport().set_input_as_handled()

func _on_rest_token_gui_input(event: InputEvent) -> void:
	if not visible or not interaction_enabled or drag_active:
		return
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_begin_drag(get_viewport().get_mouse_position())
	accept_event()

func _begin_drag(screen_pos: Vector2) -> void:
	drag_active = true
	drop_valid = false
	drag_hover_text = ""
	_refresh_drag_preview_text()
	_apply_drag_preview_style()
	drag_preview.visible = true
	_update_drag_preview_position(screen_pos)
	_apply_rest_token_style()
	drag_started.emit(screen_pos)

func _finish_drag_visual() -> void:
	drag_active = false
	drag_preview.visible = false
	drop_valid = false
	drag_hover_text = ""
	_apply_rest_token_style()

func _update_drag_preview_position(screen_pos: Vector2) -> void:
	if drag_preview == null:
		return
	var preview_size: Vector2 = drag_preview.size
	if preview_size == Vector2.ZERO:
		preview_size = drag_preview.get_combined_minimum_size()
	drag_preview.global_position = screen_pos - preview_size * 0.5

func _refresh_rest_token_text() -> void:
	rest_title_label.text = "MESTRE"
	rest_glyph_label.text = "UP"
	rest_sub_label.text = "PROMO"
	rest_badge_label.text = "x%d" % pending_count
	rest_hint_label.text = rest_hint_text

func _refresh_drag_preview_text() -> void:
	drag_title_label.text = "PROMO"
	drag_glyph_label.text = "UP"
	drag_sub_label.text = "MESTRE"
	drag_badge_label.text = "x%d" % pending_count
	if drop_valid:
		drag_hint_label.text = "Solte em %s" % drag_hover_text if not drag_hover_text.is_empty() else "Solte"
		return
	if not drag_hover_text.is_empty():
		drag_hint_label.text = drag_hover_text
		return
	drag_hint_label.text = "Alvo invalido"

func _apply_rest_token_style() -> void:
	var token_bg: Color = TOKEN_BG_COLOR
	var token_border: Color = TOKEN_BORDER_COLOR
	var text_primary: Color = TEXT_PRIMARY
	var text_secondary: Color = TEXT_SECONDARY
	if not interaction_enabled:
		token_bg = TOKEN_DISABLED_BG_COLOR
		token_border = TOKEN_DISABLED_BORDER_COLOR
		text_primary = TEXT_DISABLED
		text_secondary = TEXT_DISABLED

	rest_token_panel.add_theme_stylebox_override("panel", _build_token_style(token_bg, token_border))
	rest_badge_panel.add_theme_stylebox_override("panel", _build_badge_style())
	rest_title_label.modulate = text_secondary
	rest_glyph_label.modulate = text_primary
	rest_sub_label.modulate = text_primary
	rest_badge_label.modulate = BADGE_TEXT_COLOR
	rest_hint_label.modulate = text_secondary

func _apply_drag_preview_style() -> void:
	var token_bg: Color = TOKEN_INVALID_BG_COLOR
	var token_border: Color = TOKEN_INVALID_BORDER_COLOR
	if drop_valid:
		token_bg = TOKEN_VALID_BG_COLOR
		token_border = TOKEN_VALID_BORDER_COLOR

	drag_token_panel.add_theme_stylebox_override("panel", _build_token_style(token_bg, token_border))
	drag_badge_panel.add_theme_stylebox_override("panel", _build_badge_style())
	drag_title_label.modulate = TEXT_SECONDARY
	drag_glyph_label.modulate = TEXT_PRIMARY
	drag_sub_label.modulate = TEXT_PRIMARY
	drag_badge_label.modulate = BADGE_TEXT_COLOR
	drag_hint_label.modulate = TEXT_PRIMARY

func _build_token_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(48)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

func _build_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_BG_COLOR
	style.border_color = Color(0.38, 0.25, 0.08, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style
