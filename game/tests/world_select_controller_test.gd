## Tests for WorldSelectController: selection-mode lifecycle, world→segment
## zoom hysteresis (16/12 px flat-to-flat), locked sub-area gating, unlock
## reflection, and Escape exit (crossing-location-selection PRD P0; roadmap
## Phase 2; ADR 0013).
extends GutTest

const ACTIVATE_PX := float(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX)
const DEACTIVATE_PX := float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX)

const SUB_AREAS := {
	7: { "id": 7, "name": "Central Canadian Rockies", "starts_unlocked": true },
	8: { "id": 8, "name": "Peace River Break", "starts_unlocked": false },
	9: { "id": 9, "name": "Muskwa–Kechika", "starts_unlocked": false },
}

var _c: WorldSelectController
var _events: Array = []

func before_each() -> void:
	_c = WorldSelectController.new()
	_c.setup(SUB_AREAS)
	_events = []
	_c.selection_mode_entered.connect(func() -> void: _events.append("entered"))
	_c.selection_mode_exited.connect(func() -> void: _events.append("exited"))
	_c.segment_mode_entered.connect(
			func(id: int) -> void: _events.append("segment_on:%d" % id))
	_c.segment_mode_exited.connect(func() -> void: _events.append("segment_off"))
	_c.zoom_blocked.connect(func(id: int) -> void: _events.append("blocked:%d" % id))
	_c.sub_area_focused.connect(func(id: int) -> void: _events.append("focused:%d" % id))

func after_each() -> void:
	_c.free()

# Zoom so the on-screen tile size equals `px` (flat-to-flat).
func _zoom_to_px(px: float) -> void:
	_c.set_zoom(px / WorldSelectController.BASE_TILE_FLAT_TO_FLAT_PX)

# --- lifecycle ---

func test_starts_inactive() -> void:
	assert_eq(_c.mode, WorldSelectController.Mode.INACTIVE)

func test_enter_selection_mode_opens_world_view() -> void:
	_c.enter_selection_mode()
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD, "opens at world view")
	assert_eq(_c.zoom, WorldSelectController.ZOOM_MIN, "resets to full-Y2Y zoom")
	assert_has(_events, "entered")

func test_enter_is_idempotent_while_active() -> void:
	_c.enter_selection_mode()
	_c.enter_selection_mode()
	assert_eq(_events.count("entered"), 1, "re-entering while active is a no-op")

func test_exit_when_inactive_is_a_noop() -> void:
	_c.exit_selection_mode()
	assert_eq(_events.size(), 0)

func test_exit_from_segment_mode_leaves_entirely() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_c.exit_selection_mode()
	assert_eq(_c.mode, WorldSelectController.Mode.INACTIVE)
	assert_has(_events, "segment_off", "segment mode is torn down on exit")
	assert_has(_events, "exited")

func test_escape_key_exits_selection_mode() -> void:
	_c.enter_selection_mode()
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	_c._unhandled_input(ev)
	assert_eq(_c.mode, WorldSelectController.Mode.INACTIVE, "Escape exits from any state")

# --- lock state from data ---

func test_setup_derives_lock_state_from_starts_unlocked() -> void:
	assert_true(_c.is_sub_area_unlocked(7), "tutorial sub-area starts unlocked")
	assert_false(_c.is_sub_area_unlocked(8))
	assert_false(_c.is_sub_area_unlocked(99), "unknown ids are locked")

func test_default_focus_is_first_unlocked_sub_area() -> void:
	assert_eq(_c.focused_sub_area_id, 7)

# --- lock state from registry-parsed data (regression, 2026-09-02) ---
#
# SUB_AREAS above is hand-built with int keys. Production data arrives through
# SpeciesRegistry, where `JSON.parse_string` returns every number as a float —
# the difference the windowed build walk of 2026-09-02 found and which 237 green
# tests could not see. These feed real registry output through `setup()`.

const REGISTRY_SCRIPT := preload("res://scripts/systems/species_registry.gd")

func _controller_from_real_data() -> WorldSelectController:
	var reg := REGISTRY_SCRIPT.new()
	reg.load_all()
	var c := WorldSelectController.new()
	c.setup(reg.sub_areas)
	reg.free()
	return c

func test_registry_data_unlocks_the_tutorial_sub_area() -> void:
	var c := _controller_from_real_data()
	assert_true(c.is_sub_area_unlocked(7),
			"sub-area 7 is unlocked from res://data/ — every card drew locked " \
			+ "while the registry keyed sub_areas by float")
	assert_eq(c.focused_sub_area_id, 7,
			"focus lands on the unlocked sub-area rather than falling to ids[0]")
	c.free()

func test_registry_data_leaves_the_other_sub_areas_locked() -> void:
	var c := _controller_from_real_data()
	assert_false(c.is_sub_area_unlocked(1), "sub-area 1 stays locked")
	assert_false(c.is_sub_area_unlocked(12), "sub-area 12 stays locked")
	c.free()

# --- zoom hysteresis (PRD resolved threshold: activate ≥16 px, deactivate <12 px) ---

func test_zoom_to_activate_threshold_enters_segment_mode() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT)
	assert_has(_events, "segment_on:7")

func test_below_activate_threshold_stays_in_world_mode() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX - 0.1)
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD)

func test_world_mode_does_not_activate_inside_hysteresis_band() -> void:
	_c.enter_selection_mode()
	_zoom_to_px((ACTIVATE_PX + DEACTIVATE_PX) / 2.0)
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD,
			"12–16 px band never activates on the way in")

func test_segment_mode_survives_hysteresis_band() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_zoom_to_px((ACTIVATE_PX + DEACTIVATE_PX) / 2.0)
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT,
			"12–16 px band never deactivates on the way out")
	assert_does_not_have(_events, "segment_off")

func test_below_deactivate_threshold_exits_segment_mode() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_zoom_to_px(DEACTIVATE_PX - 0.1)
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD)
	assert_has(_events, "segment_off")

func test_zoom_is_clamped_to_global_limits() -> void:
	_c.enter_selection_mode()
	_c.set_zoom(99.0)
	assert_eq(_c.zoom, WorldSelectController.ZOOM_MAX)
	_c.set_zoom(0.0001)
	assert_eq(_c.zoom, WorldSelectController.ZOOM_MIN)

func test_set_zoom_is_ignored_while_inactive() -> void:
	_c.set_zoom(1.0)
	assert_eq(_c.zoom, WorldSelectController.ZOOM_MIN, "no zoom outside selection mode")

# --- locked sub-area gating (PRD rule 5) ---

func test_locked_sub_area_blocks_zoom_at_boundary() -> void:
	_c.enter_selection_mode()
	_c.set_focused_sub_area(8)
	_zoom_to_px(ACTIVATE_PX)
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD, "segment mode unreachable")
	assert_lte(_c.tile_px(), DEACTIVATE_PX, "zoom clamped at the sub-area boundary")
	assert_has(_events, "blocked:8")

func test_unlocking_allows_segment_mode() -> void:
	_c.enter_selection_mode()
	_c.set_focused_sub_area(8)
	_c.unlock_sub_area(8)
	_zoom_to_px(ACTIVATE_PX)
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT)
	assert_has(_events, "segment_on:8")

func test_focusing_a_locked_area_at_segment_zoom_exits_segment_mode() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_c.set_focused_sub_area(9)
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD)
	assert_has(_events, "segment_off")
	assert_lte(_c.tile_px(), DEACTIVATE_PX, "zoom re-clamped against the locked focus")

func test_focus_change_emits_and_ignores_unknown_ids() -> void:
	_c.enter_selection_mode()
	_c.set_focused_sub_area(8)
	assert_has(_events, "focused:8")
	_c.set_focused_sub_area(99)
	assert_eq(_c.focused_sub_area_id, 8, "unknown sub-area ids are ignored")

# --- look-only map screen (roadmap Phase 2, decision logged 2026-08-06) ---
#
# Regression cover for the blind world-map click found by the 2026-08-04 build
# review. The scene used to be MOUSE_FILTER_IGNORE, so clicks fell through to
# Main._try_select_segment() and resolved against the world camera hidden under
# the opaque card grid. These three tests are the guard on that staying fixed.

func _mouse_button(button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev

func test_world_select_map_scene_stops_mouse_events() -> void:
	var scene: PackedScene = load("res://scenes/ui/WorldSelectMap.tscn")
	assert_not_null(scene, "WorldSelectMap.tscn loads")
	var node: Control = scene.instantiate()
	assert_eq(node.mouse_filter, Control.MOUSE_FILTER_STOP,
			"the map screen must consume its own clicks — MOUSE_FILTER_IGNORE " \
			+ "lets them fall through to the world camera underneath")
	node.free()

func test_left_click_in_segment_mode_selects_nothing() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT, "precondition: segment mode")
	var before: int = _events.size()
	_c._gui_input(_mouse_button(MOUSE_BUTTON_LEFT))
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT, "a click does not change mode")
	assert_eq(_events.size(), before,
			"a click on the look-only map emits nothing — no segment is picked")

func test_scroll_wheel_still_zooms_through_gui_input() -> void:
	_c.enter_selection_mode()
	var start: float = _c.zoom
	_c._gui_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP))
	assert_gt(_c.zoom, start, "wheel-up still zooms in after the mouse_filter change")
	var zoomed: float = _c.zoom
	_c._gui_input(_mouse_button(MOUSE_BUTTON_WHEEL_DOWN))
	assert_lt(_c.zoom, zoomed, "wheel-down still zooms out")
