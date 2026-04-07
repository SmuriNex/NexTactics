extends Control
class_name SupportCardWidget

signal pressed
signal right_clicked
signal hovered
signal unhovered

const BASE_BG_COLOR := Color(0.11, 0.12, 0.15, 0.98)
const HOVER_BG_BOOST := Color(0.05, 0.05, 0.05, 0.0)
const DISABLED_BG_COLOR := Color(0.12, 0.12, 0.12, 0.86)
const USED_BG_COLOR := Color(0.10, 0.10, 0.10, 0.92)
const TEXT_DISABLED := Color(0.72, 0.72, 0.72, 1.0)
const TEXT_PRIMARY := Color(0.96, 0.95, 0.92, 1.0)
const TEXT_SECONDARY := Color(0.80, 0.80, 0.84, 1.0)

var state_kind: String = "ready"
var compact_mode: bool = false
var hover_active: bool = false
var accent_color: Color = Color(0.52, 0.52, 0.60, 1.0)
var art_color: Color = Color(0.16, 0.16, 0.20, 1.0)

@onready var card_panel: PanelContainer = $CardPanel
@onready var accent_bar: ColorRect = $CardPanel/MarginContainer/VBoxContainer/AccentBar
@onready var title_label: Label = $CardPanel/MarginContainer/VBoxContainer/HeaderRow/HeaderTextVBox/TitleLabel
@onready var type_label: Label = $CardPanel/MarginContainer/VBoxContainer/HeaderRow/HeaderTextVBox/TypeLabel
@onready var cost_badge_label: Label = $CardPanel/MarginContainer/VBoxContainer/HeaderRow/CostBadgePanel/MarginContainer/CostBadgeLabel
@onready var target_label: Label = $CardPanel/MarginContainer/VBoxContainer/TargetLabel
@onready var art_panel: PanelContainer = $CardPanel/MarginContainer/VBoxContainer/ArtPanel
@onready var art_title_label: Label = $CardPanel/MarginContainer/VBoxContainer/ArtPanel/CenterContainer/ArtVBox/ArtTitleLabel
@onready var art_caption_label: Label = $CardPanel/MarginContainer/VBoxContainer/ArtPanel/CenterContainer/ArtVBox/ArtCaptionLabel
@onready var body_label: Label = $CardPanel/MarginContainer/VBoxContainer/BodyLabel
@onready var footer_panel: PanelContainer = $CardPanel/MarginContainer/VBoxContainer/FooterPanel
@onready var footer_label: Label = $CardPanel/MarginContainer/VBoxContainer/FooterPanel/MarginContainer/FooterLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if card_panel != null:
		card_panel.gui_input.connect(_on_card_panel_gui_input)
		card_panel.mouse_entered.connect(_on_mouse_entered)
		card_panel.mouse_exited.connect(_on_mouse_exited)
		card_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_descendant_mouse_filters(card_panel)
	_apply_visual_state()

func configure(view_data: Dictionary) -> void:
	title_label.text = str(view_data.get("title_text", "Carta"))
	type_label.text = str(view_data.get("type_text", "SUPORTE"))
	cost_badge_label.text = str(view_data.get("cost_text", "--"))
	target_label.text = str(view_data.get("target_text", ""))
	art_title_label.text = str(view_data.get("art_title", "SIGIL"))
	art_caption_label.text = str(view_data.get("art_caption", ""))
	body_label.text = str(view_data.get("description_text", ""))
	footer_label.text = str(view_data.get("footer_text", ""))
	state_kind = str(view_data.get("state_kind", "ready"))
	compact_mode = bool(view_data.get("compact", false))
	accent_color = view_data.get("accent_color", Color(0.52, 0.52, 0.60, 1.0))
	art_color = view_data.get("art_color", Color(0.16, 0.16, 0.20, 1.0))
	_apply_compact_mode()
	_apply_visual_state()

func _gui_input(event: InputEvent) -> void:
	_handle_click_input(event)

func _on_card_panel_gui_input(event: InputEvent) -> void:
	_handle_click_input(event)

func _handle_click_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit()
		accept_event()

func _apply_compact_mode() -> void:
	if compact_mode:
		custom_minimum_size = Vector2(140.0, 158.0)
		title_label.add_theme_font_size_override("font_size", 12)
		type_label.add_theme_font_size_override("font_size", 9)
		target_label.add_theme_font_size_override("font_size", 9)
		body_label.add_theme_font_size_override("font_size", 10)
		body_label.max_lines_visible = 4
		art_title_label.add_theme_font_size_override("font_size", 16)
		art_caption_label.add_theme_font_size_override("font_size", 9)
		cost_badge_label.add_theme_font_size_override("font_size", 10)
		footer_label.add_theme_font_size_override("font_size", 9)
		return

	custom_minimum_size = Vector2(270.0, 332.0)
	title_label.add_theme_font_size_override("font_size", 18)
	type_label.add_theme_font_size_override("font_size", 11)
	target_label.add_theme_font_size_override("font_size", 11)
	body_label.add_theme_font_size_override("font_size", 13)
	body_label.max_lines_visible = 7
	art_title_label.add_theme_font_size_override("font_size", 28)
	art_caption_label.add_theme_font_size_override("font_size", 12)
	cost_badge_label.add_theme_font_size_override("font_size", 12)
	footer_label.add_theme_font_size_override("font_size", 11)

func _apply_visual_state() -> void:
	accent_bar.color = accent_color
	art_panel.add_theme_stylebox_override("panel", _build_art_style())

	var panel_style: StyleBoxFlat = _build_panel_style()
	card_panel.add_theme_stylebox_override("panel", panel_style)
	footer_panel.add_theme_stylebox_override("panel", _build_footer_style())

	var primary_color: Color = TEXT_PRIMARY
	var secondary_color: Color = TEXT_SECONDARY
	if state_kind == "used" or state_kind == "unavailable":
		primary_color = TEXT_DISABLED
		secondary_color = Color(0.62, 0.62, 0.66, 1.0)

	title_label.modulate = primary_color
	cost_badge_label.modulate = primary_color
	type_label.modulate = secondary_color
	target_label.modulate = secondary_color
	body_label.modulate = primary_color
	art_title_label.modulate = primary_color
	art_caption_label.modulate = secondary_color
	footer_label.modulate = primary_color

func _build_panel_style() -> StyleBoxFlat:
	var border_color: Color = accent_color
	var background_color: Color = BASE_BG_COLOR
	var border_width: int = 2
	if state_kind == "selected":
		border_width = 3
		background_color = BASE_BG_COLOR + Color(0.02, 0.06, 0.06, 0.0)
	elif state_kind == "used":
		background_color = USED_BG_COLOR
		border_color = Color(0.42, 0.42, 0.42, 1.0)
	elif state_kind == "unavailable":
		background_color = DISABLED_BG_COLOR
		border_color = Color(0.44, 0.44, 0.48, 1.0)
	elif state_kind == "blocked":
		background_color = Color(0.18, 0.12, 0.12, 0.96)
		border_color = Color(0.76, 0.34, 0.34, 1.0)
	elif state_kind == "shop":
		background_color = BASE_BG_COLOR + Color(0.03, 0.03, 0.05, 0.0)

	if hover_active and state_kind != "used" and state_kind != "unavailable":
		border_width += 1
		background_color += HOVER_BG_BOOST

	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(16)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 3.0)
	return style

func _build_art_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = art_color
	style.border_color = accent_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

func _build_footer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.18)
	style.set_corner_radius_all(8)
	return style

func _on_mouse_entered() -> void:
	hover_active = true
	_apply_visual_state()
	hovered.emit()

func _on_mouse_exited() -> void:
	hover_active = false
	_apply_visual_state()
	unhovered.emit()

func _set_descendant_mouse_filters(root_node: Node) -> void:
	if root_node == null:
		return
	for child in root_node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendant_mouse_filters(child)
