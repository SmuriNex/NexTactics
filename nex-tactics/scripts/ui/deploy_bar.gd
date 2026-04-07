extends CanvasLayer
class_name DeployBar

const SUPPORT_CARD_WIDGET_SCENE := preload("res://scenes/ui/support_card_widget.tscn")
const SupportCardVisualsScript := preload("res://scripts/ui/support_card_visuals.gd")

signal deploy_slot_pressed(slot_index: int)
signal deploy_slot_right_clicked(slot_index: int)
signal support_slot_pressed(slot_index: int)
signal support_slot_right_clicked(slot_index: int)

const UNIT_SLOT_READY_COLOR := Color(0.20, 0.26, 0.34, 0.95)
const UNIT_SLOT_USED_COLOR := Color(0.24, 0.24, 0.24, 0.85)
const UNIT_SLOT_BLOCKED_COLOR := Color(0.34, 0.20, 0.20, 0.90)
const UNIT_SLOT_UNAVAILABLE_COLOR := Color(0.21, 0.22, 0.26, 0.88)
const UNIT_SLOT_DRAGGING_COLOR := Color(0.85, 0.72, 0.28, 0.95)
const SUPPORT_SLOT_READY_COLOR := Color(0.18, 0.34, 0.30, 0.95)
const SUPPORT_SLOT_USED_COLOR := Color(0.24, 0.24, 0.24, 0.85)
const SUPPORT_SLOT_BLOCKED_COLOR := Color(0.34, 0.20, 0.20, 0.90)
const SUPPORT_SLOT_UNAVAILABLE_COLOR := Color(0.20, 0.24, 0.23, 0.88)
const SUPPORT_SLOT_SELECTED_COLOR := Color(0.24, 0.66, 0.58, 0.98)
const SELL_IDLE_COLOR := Color(0.25, 0.18, 0.18, 0.95)
const SELL_VALID_COLOR := Color(0.30, 0.55, 0.30, 0.98)
const SELL_INVALID_COLOR := Color(0.58, 0.24, 0.24, 0.98)

@onready var unit_slots_container: Container = $DeckPanel/MarginContainer/DeckScroll/MainColumn/MainRow/UnitSlotsContainer
@onready var support_slots_container: Container = $DeckPanel/MarginContainer/DeckScroll/MainColumn/SupportRow/SupportSlotsContainer
@onready var sell_zone_panel: PanelContainer = $SellZonePanel
@onready var sell_zone_label: Label = $SellZonePanel/SellZoneLabel
@onready var deck_panel: PanelContainer = $DeckPanel

var unit_slot_panels: Array[PanelContainer] = []
var unit_slot_name_labels: Array[Label] = []
var unit_slot_cost_labels: Array[Label] = []
var unit_slot_status_labels: Array[Label] = []

var support_slot_widgets: Array[SupportCardWidget] = []

func update_unit_slots(slot_data: Array[Dictionary], dragging_slot_index: int) -> void:
    _ensure_slot_count(
        slot_data.size(),
        unit_slots_container,
        unit_slot_panels,
        unit_slot_name_labels,
        unit_slot_cost_labels,
        unit_slot_status_labels,
        false
    )

    for i in range(slot_data.size()):
        _update_slot_visual(
            i,
            slot_data[i],
            dragging_slot_index,
            unit_slot_panels,
            unit_slot_name_labels,
            unit_slot_cost_labels,
            unit_slot_status_labels,
            false
        )

func update_support_slots(slot_data: Array[Dictionary], selected_slot_index: int) -> void:
    _ensure_support_slot_count(slot_data.size())
    for i in range(slot_data.size()):
        _update_support_slot_visual(i, slot_data[i], selected_slot_index)

func set_sell_zone_feedback(active: bool, valid: bool) -> void:
    if not active:
        sell_zone_panel.modulate = SELL_IDLE_COLOR
        sell_zone_label.text = "AREA DE VENDA\nArraste a unidade"
        return

    if valid:
        sell_zone_panel.modulate = SELL_VALID_COLOR
        sell_zone_label.text = "AREA DE VENDA\nSolte para vender"
    else:
        sell_zone_panel.modulate = SELL_INVALID_COLOR
        sell_zone_label.text = "AREA DE VENDA\nInvalido"

func is_over_sell_zone(global_pos: Vector2) -> bool:
    return sell_zone_panel.get_global_rect().has_point(global_pos)

func is_over_unit_slot(global_pos: Vector2) -> bool:
    for panel in unit_slot_panels:
        if panel != null and panel.get_global_rect().has_point(global_pos):
            return true
    return false

func is_over_support_slot(global_pos: Vector2) -> bool:
    for widget in support_slot_widgets:
        if widget != null and widget.get_global_rect().has_point(global_pos):
            return true
    return false

func is_over_any_slot(global_pos: Vector2) -> bool:
    return is_over_unit_slot(global_pos) or is_over_support_slot(global_pos)

func is_over_ui(global_pos: Vector2) -> bool:
    return deck_panel.get_global_rect().has_point(global_pos) or sell_zone_panel.get_global_rect().has_point(global_pos)

func _ensure_slot_count(
    slot_count: int,
    container: Container,
    slot_panels: Array[PanelContainer],
    slot_name_labels: Array[Label],
    slot_cost_labels: Array[Label],
    slot_status_labels: Array[Label],
    is_support: bool
) -> void:
    while slot_panels.size() > slot_count:
        var idx := slot_panels.size() - 1
        slot_panels[idx].queue_free()
        slot_panels.remove_at(idx)
        slot_name_labels.remove_at(idx)
        slot_cost_labels.remove_at(idx)
        slot_status_labels.remove_at(idx)

    while slot_panels.size() < slot_count:
        var panel := PanelContainer.new()
        panel.custom_minimum_size = Vector2(112.0, 44.0) if is_support else Vector2(90.0, 54.0)
        panel.mouse_filter = Control.MOUSE_FILTER_STOP
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if is_support:
            panel.gui_input.connect(_on_support_slot_gui_input.bind(slot_panels.size()))
        else:
            panel.gui_input.connect(_on_unit_slot_gui_input.bind(slot_panels.size()))

        var margin := MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 4)
        margin.add_theme_constant_override("margin_top", 4)
        margin.add_theme_constant_override("margin_right", 4)
        margin.add_theme_constant_override("margin_bottom", 4)

        var vbox := VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 1)

        var name_label := Label.new()
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.add_theme_font_size_override("font_size", 10 if is_support else 9)
        name_label.text = "Slot"
        name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

        var cost_label := Label.new()
        cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cost_label.add_theme_font_size_override("font_size", 9)
        cost_label.text = "Custo: -"
        cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

        var status_label := Label.new()
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        status_label.add_theme_font_size_override("font_size", 8)
        status_label.text = "Estado"
        status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

        vbox.add_child(name_label)
        vbox.add_child(cost_label)
        vbox.add_child(status_label)
        margin.add_child(vbox)
        panel.add_child(margin)
        container.add_child(panel)

        slot_panels.append(panel)
        slot_name_labels.append(name_label)
        slot_cost_labels.append(cost_label)
        slot_status_labels.append(status_label)

func _ensure_support_slot_count(slot_count: int) -> void:
    while support_slot_widgets.size() > slot_count:
        var idx := support_slot_widgets.size() - 1
        support_slot_widgets[idx].queue_free()
        support_slot_widgets.remove_at(idx)

    while support_slot_widgets.size() < slot_count:
        var widget := SUPPORT_CARD_WIDGET_SCENE.instantiate() as SupportCardWidget
        widget.custom_minimum_size = Vector2(136.0, 156.0)
        widget.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        widget.pressed.connect(_on_support_slot_widget_pressed.bind(support_slot_widgets.size()))
        widget.right_clicked.connect(_on_support_slot_widget_right_clicked.bind(support_slot_widgets.size()))
        support_slots_container.add_child(widget)
        support_slot_widgets.append(widget)

func _update_slot_visual(
    slot_index: int,
    data: Dictionary,
    active_slot_index: int,
    slot_panels: Array[PanelContainer],
    slot_name_labels: Array[Label],
    slot_cost_labels: Array[Label],
    slot_status_labels: Array[Label],
    is_support: bool
) -> void:
    var status: String = str(data.get("status", ""))
    var used: bool = bool(data.get("used", false)) or status == "USED"
    var affordable: bool = bool(data.get("affordable", false))
    var display_name: String = str(data.get("name", "Slot"))
    var cost: int = int(data.get("cost", 0))
    var cost_label_text: String = str(data.get("cost_label", ""))

    if status.is_empty():
        if used:
            status = "USED"
        elif affordable:
            status = "READY"
        else:
            status = "NO GOLD"

    if is_support:
        slot_name_labels[slot_index].text = "S%d) %s" % [slot_index + 1, display_name]
    else:
        slot_name_labels[slot_index].text = "%d) %s" % [slot_index + 1, display_name]
    slot_cost_labels[slot_index].text = cost_label_text if not cost_label_text.is_empty() else "Custo: %d" % cost

    if status == "USED":
        slot_status_labels[slot_index].text = "USADO"
        slot_panels[slot_index].modulate = SUPPORT_SLOT_USED_COLOR if is_support else UNIT_SLOT_USED_COLOR
    elif active_slot_index == slot_index:
        slot_status_labels[slot_index].text = "ARMADO" if is_support else "ARRAST."
        slot_panels[slot_index].modulate = SUPPORT_SLOT_SELECTED_COLOR if is_support else UNIT_SLOT_DRAGGING_COLOR
    elif status == "READY":
        slot_status_labels[slot_index].text = "PRONTO"
        slot_panels[slot_index].modulate = SUPPORT_SLOT_READY_COLOR if is_support else UNIT_SLOT_READY_COLOR
    elif status == "NO GOLD":
        slot_status_labels[slot_index].text = "SEM OURO"
        slot_panels[slot_index].modulate = SUPPORT_SLOT_BLOCKED_COLOR if is_support else UNIT_SLOT_BLOCKED_COLOR
    else:
        slot_status_labels[slot_index].text = "INDISP."
        slot_panels[slot_index].modulate = SUPPORT_SLOT_UNAVAILABLE_COLOR if is_support else UNIT_SLOT_UNAVAILABLE_COLOR

func _update_support_slot_visual(slot_index: int, data: Dictionary, selected_slot_index: int) -> void:
    if slot_index < 0 or slot_index >= support_slot_widgets.size():
        return

    var status: String = str(data.get("status", "UNAVAILABLE"))
    var state_kind: String = "ready"
    var state_label: String = "DISPONIVEL"
    var reason_text: String = str(data.get("reason", ""))
    if status == "USED":
        state_kind = "used"
        state_label = "USADA"
    elif selected_slot_index == slot_index:
        state_kind = "selected"
        state_label = "ARMADA"
    elif status == "READY":
        state_kind = "ready"
        state_label = "DISPONIVEL"
    else:
        state_kind = "unavailable"
        state_label = "INDISPONIVEL"

    var compact_hint: String = ""
    if state_kind == "unavailable" and not reason_text.is_empty():
        compact_hint = reason_text

    var view_data: Dictionary = SupportCardVisualsScript.build_view_data(
        data.get("card_data", null) as CardData,
        state_label,
        state_kind,
        true,
        compact_hint
    )
    support_slot_widgets[slot_index].configure(view_data)

func _on_unit_slot_gui_input(event: InputEvent, slot_index: int) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            deploy_slot_pressed.emit(slot_index)
        elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
            deploy_slot_right_clicked.emit(slot_index)

func _on_support_slot_gui_input(event: InputEvent, slot_index: int) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            support_slot_pressed.emit(slot_index)
        elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
            support_slot_right_clicked.emit(slot_index)

func _on_support_slot_widget_pressed(slot_index: int) -> void:
    support_slot_pressed.emit(slot_index)

func _on_support_slot_widget_right_clicked(slot_index: int) -> void:
    support_slot_right_clicked.emit(slot_index)
