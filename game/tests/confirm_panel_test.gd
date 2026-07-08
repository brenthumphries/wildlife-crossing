## Tests for ConfirmPanel: open/display, confirm passing the exact
## (segment, sub_area) to the construction step, the budget gate (display,
## PRD rule 14), cancel semantics, click-outside-cancels, and closure when
## selection mode ends (crossing-location-selection PRD rules 10–14).
extends GutTest

const SEGMENT := {
	"id": "s7_trans_canada_bow_a",
	"sub_area_id": 7,
	"label": "Trans-Canada Hwy, Bow Valley sector A",
	"connectivity_note": "Splits two forest patches; a full span reconnects them.",
}

const SUB_AREAS := {
	7: { "id": 7, "name": "Central Canadian Rockies", "starts_unlocked": true },
}

var _p: ConfirmPanel
var _c: WorldSelectController
var _confirmed: Array = []
var _cancelled := 0

func before_each() -> void:
	_p = ConfirmPanel.new()
	_confirmed = []
	_cancelled = 0
	_p.confirmed.connect(
			func(id: String, sub: int) -> void: _confirmed.append([id, sub]))
	_p.cancelled.connect(func() -> void: _cancelled += 1)

func after_each() -> void:
	_p.free()
	if _c != null:
		_c.free()
		_c = null

# --- open / display (PRD rule 10) ---------------------------------------------

func test_starts_closed_and_hidden() -> void:
	assert_false(_p.is_open)
	assert_false(_p.visible)

func test_open_shows_segment_budget_and_note() -> void:
	_p.open(SEGMENT, 50000, 0)
	assert_true(_p.is_open)
	assert_true(_p.visible)
	assert_eq(_p._segment_label.text, "Trans-Canada Hwy, Bow Valley sector A",
			"human-readable segment label (P1)")
	assert_string_contains(_p._budget_label.text, "50000", "current budget shown")
	assert_string_contains(_p._note_label.text, "Splits two forest patches")

func test_open_falls_back_to_segment_id_without_label() -> void:
	_p.open({ "id": "s9_x", "sub_area_id": 9 }, 100, 0)
	assert_eq(_p._segment_label.text, "s9_x")

# --- confirm → construction (PRD rule 11) --------------------------------------

func test_confirm_passes_exact_segment_and_sub_area() -> void:
	_p.open(SEGMENT, 50000, 0)
	assert_true(_p.confirm())
	assert_eq(_confirmed, [["s7_trans_canada_bow_a", 7]],
			"construction step receives the right (segment, sub_area)")
	assert_false(_p.is_open, "panel closes on confirm")

func test_confirm_when_closed_is_a_noop() -> void:
	assert_false(_p.confirm())
	assert_eq(_confirmed.size(), 0)

# --- budget gate (PRD rule 14; display-only until Phase 3) ---------------------

func test_sufficient_budget_enables_confirm() -> void:
	_p.open(SEGMENT, 5000, 5000)
	assert_true(_p.can_confirm(), "budget equal to min cost passes the gate")
	assert_false(_p._confirm_button.disabled)
	assert_false(_p._gate_label.visible)

func test_insufficient_budget_disables_confirm_with_note() -> void:
	_p.open(SEGMENT, 0, 5000)
	assert_false(_p.can_confirm())
	assert_true(_p._confirm_button.disabled, "Confirm is non-interactive")
	assert_true(_p._gate_label.visible, "an explanatory note is visible")
	assert_false(_p.confirm(), "gated confirm does nothing")
	assert_eq(_confirmed.size(), 0)
	assert_true(_p.is_open, "the player can keep browsing")

func test_zero_min_cost_never_gates() -> void:
	_p.open(SEGMENT, 0, 0)
	assert_true(_p.can_confirm(), "Phase 2 display default: gate does not trip")

# --- cancel (PRD rule 12) -------------------------------------------------------

func test_cancel_closes_and_emits_cancelled_only() -> void:
	_p.open(SEGMENT, 50000, 0)
	_p.cancel()
	assert_false(_p.is_open)
	assert_eq(_cancelled, 1)
	assert_eq(_confirmed.size(), 0)

func test_click_outside_the_panel_box_cancels() -> void:
	_p.open(SEGMENT, 50000, 0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(-10000.0, -10000.0)   # far outside the panel box
	_p._gui_input(ev)
	assert_false(_p.is_open, "click outside closes the panel")
	assert_eq(_cancelled, 1, "equivalent to Cancel")

# --- closure with selection mode (PRD rule 13) ----------------------------------

func _open_via_controller() -> void:
	_c = WorldSelectController.new()
	_c.setup(SUB_AREAS)
	_p.attach(_c)
	_c.enter_selection_mode()
	_c.set_zoom(float(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX)
			/ WorldSelectController.BASE_TILE_FLAT_TO_FLAT_PX)
	_p.open(SEGMENT, 50000, 0)

func test_escape_exit_closes_panel_silently() -> void:
	_open_via_controller()
	_c.exit_selection_mode()   # the Escape path
	assert_false(_p.is_open)
	assert_eq(_cancelled, 0, "no cancel semantics — the controller owns the exit")
	assert_eq(_confirmed.size(), 0, "no crossing is initiated")

func test_zooming_out_of_segment_mode_closes_panel() -> void:
	_open_via_controller()
	_c.set_zoom((float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX) - 0.1)
			/ WorldSelectController.BASE_TILE_FLAT_TO_FLAT_PX)
	assert_false(_p.is_open)
