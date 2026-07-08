## Location-confirmation panel for crossing selection: shows the selected
## segment, remaining budget, and a one-line connectivity note, with Confirm /
## Cancel actions (crossing-location-selection PRD rules 10–14). Confirm passes
## the exact (segment, sub_area) on to the construction step; Cancel (or a click
## outside the panel — the resolved click-outside decision) returns to
## hover-selection; leaving selection mode closes the panel silently. The budget
## gate is display-only until the Phase 3 economy lands (roadmap).
class_name ConfirmPanel
extends Control

signal confirmed(segment_id: String, sub_area_id: int)
signal cancelled()

const PANEL_MIN_SIZE := Vector2(320.0, 180.0)
const GATE_NOTE_TEXT := "Insufficient budget for any crossing — you can keep browsing locations."

var is_open := false

var _segment: Dictionary = {}
var _panel_box: PanelContainer
var _segment_label: Label
var _budget_label: Label
var _note_label: Label
var _gate_label: Label
var _confirm_button: Button
var _cancel_button: Button
var _can_confirm := false

func _init() -> void:
	_build_ui()
	hide()

## Present the panel for a selected segment record (segments.json shape),
## showing the player's remaining budget. `min_crossing_cost` drives the budget
## gate: below it, Confirm is disabled with an explanatory note (PRD rule 14).
func open(segment: Dictionary, budget: int, min_crossing_cost: int) -> void:
	_segment = segment
	is_open = true
	_can_confirm = budget >= min_crossing_cost
	_segment_label.text = String(segment.get("label", segment.get("id", "?")))
	_budget_label.text = "Budget remaining: $%d" % budget
	_note_label.text = String(segment.get("connectivity_note", ""))
	_gate_label.visible = not _can_confirm
	_confirm_button.disabled = not _can_confirm
	show()

## Whether the budget gate allows confirmation.
func can_confirm() -> bool:
	return _can_confirm

## Commit the selection: emits the exact (segment_id, sub_area_id) for the
## construction step and closes selection (PRD rule 11). No-op when gated.
func confirm() -> bool:
	if not is_open or not _can_confirm:
		return false
	var segment_id := String(_segment["id"])
	var sub_area_id := int(_segment["sub_area_id"])
	close()
	confirmed.emit(segment_id, sub_area_id)
	if is_inside_tree():
		var bus := get_node_or_null("/root/EventBus")
		if bus:
			bus.location_confirmed.emit(segment_id, sub_area_id)
	return true

## Dismiss and return to hover-selection mode; the overlay stays active
## (PRD rule 12). Not the Escape path — that exits selection mode entirely.
func cancel() -> void:
	if not is_open:
		return
	close()
	cancelled.emit()

## Hide without emitting: used when selection mode itself ends (Escape or
## zoom-out), where the controller already owns the exit semantics.
func close() -> void:
	is_open = false
	_segment = {}
	hide()

## Subscribe to a WorldSelectController so the panel can never outlive the
## selection state it belongs to (PRD rule 13).
func attach(controller: WorldSelectController) -> void:
	controller.selection_mode_exited.connect(_on_world_select_controller_selection_mode_exited)
	controller.segment_mode_exited.connect(_on_world_select_controller_segment_mode_exited)

func _on_world_select_controller_selection_mode_exited() -> void:
	close()

func _on_world_select_controller_segment_mode_exited() -> void:
	close()

# A click anywhere outside the panel box closes it, equivalent to Cancel (the
# resolved click-outside decision). Only mouse clicks are captured; keyboard
# and edge-scroll panning pass through untouched.
func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var box := Rect2(_panel_box.position, _panel_box.size)
		if not box.has_point(event.position):
			cancel()
			accept_event()

func _on_confirm_button_pressed() -> void:
	confirm()

func _on_cancel_button_pressed() -> void:
	cancel()

# --- construction ------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP     # catch outside-clicks while open

	_panel_box = PanelContainer.new()
	_panel_box.custom_minimum_size = PANEL_MIN_SIZE
	_panel_box.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel_box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel_box.add_child(column)

	var title := Label.new()
	title.text = "Build a crossing here?"
	column.add_child(title)

	_segment_label = Label.new()
	column.add_child(_segment_label)

	_budget_label = Label.new()
	column.add_child(_budget_label)

	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note_label)

	_gate_label = Label.new()
	_gate_label.text = GATE_NOTE_TEXT
	_gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_label.visible = false
	column.add_child(_gate_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	_confirm_button.pressed.connect(_on_confirm_button_pressed)
	buttons.add_child(_confirm_button)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.pressed.connect(_on_cancel_button_pressed)
	buttons.add_child(_cancel_button)
