## Tests for WorldSelectController: selection-mode lifecycle, world→segment
## zoom hysteresis (16/12 px flat-to-flat), locked sub-area gating, unlock
## reflection, and Escape exit (crossing-location-selection PRD P0; roadmap
## Phase 2; ADR 0013).
extends GutTest

const ACTIVATE_PX := float(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX)
const DEACTIVATE_PX := float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX)

const SUB_AREAS := {
	7: { "id": 7, "name": "Central Canadian Rockies", "starts_unlocked": true,
		"card_image": "res://assets/sprites/world_map_bow_valley.png" },
	8: { "id": 8, "name": "Peace River Break", "starts_unlocked": false },
	9: { "id": 9, "name": "Muskwa–Kechika", "starts_unlocked": false, "card_image": null },
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

# --- card art (roadmap decision logged 2026-09-15, data-schemas.md §4) ---

func test_card_image_path_returns_the_configured_resource_path() -> void:
	assert_eq(_c.card_image_path(7), "res://assets/sprites/world_map_bow_valley.png")

func test_card_image_path_is_empty_for_explicit_json_null() -> void:
	assert_eq(_c.card_image_path(9), "", "JSON null must not stringify to \"<null>\"")

func test_card_image_path_is_empty_for_unknown_sub_area() -> void:
	assert_eq(_c.card_image_path(99), "")

func test_bow_valley_card_art_resolves_to_a_loadable_texture() -> void:
	var texture: Texture2D = load(_c.card_image_path(7))
	assert_not_null(texture, "world_map_bow_valley.png must be importable at its data path")

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

func test_registry_data_gives_bow_valley_its_card_art() -> void:
	var c := _controller_from_real_data()
	assert_eq(c.card_image_path(7), "res://assets/sprites/world_map_bow_valley.png")
	assert_eq(c.card_image_path(1), "", "sub-areas without art still stringify JSON null to \"\"")
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
# the opaque card grid. World view still swallows clicks; segment mode (ADR 0021)
# hands a left click to its owner as `segment_clicked`, resolved on the live camera.

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

func test_left_click_in_segment_mode_emits_segment_clicked() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT, "precondition: segment mode")
	var clicks: Array = []
	_c.segment_clicked.connect(func(at: Vector2) -> void: clicks.append(at))
	var ev := _mouse_button(MOUSE_BUTTON_LEFT)
	ev.position = Vector2(300.0, 200.0)
	_c._gui_input(ev)
	assert_eq(clicks, [Vector2(300.0, 200.0)], "the click is handed to the owner, in screen pixels")
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT, "a click does not change mode")

func test_left_click_in_world_view_is_swallowed() -> void:
	_c.enter_selection_mode()
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD, "precondition: world view")
	var clicks: Array = []
	_c.segment_clicked.connect(func(at: Vector2) -> void: clicks.append(at))
	var before: int = _events.size()
	_c._gui_input(_mouse_button(MOUSE_BUTTON_LEFT))
	assert_eq(clicks.size(), 0, "world view is look-only: no pick is requested")
	assert_eq(_events.size(), before, "and nothing else happens")

func test_right_click_in_segment_mode_is_swallowed() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	var clicks: Array = []
	_c.segment_clicked.connect(func(at: Vector2) -> void: clicks.append(at))
	_c._gui_input(_mouse_button(MOUSE_BUTTON_RIGHT))
	assert_eq(clicks.size(), 0, "only the left button picks")

func test_scroll_wheel_still_zooms_through_gui_input() -> void:
	_c.enter_selection_mode()
	var start: float = _c.zoom
	_c._gui_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP))
	assert_gt(_c.zoom, start, "wheel-up still zooms in after the mouse_filter change")
	var zoomed: float = _c.zoom
	_c._gui_input(_mouse_button(MOUSE_BUTTON_WHEEL_DOWN))
	assert_lt(_c.zoom, zoomed, "wheel-down still zooms out")

# --- trackpad zoom (V16, 2026-10-18) ---
#
# A Mac trackpad reports two-finger scroll as a pan gesture and pinch as a magnify
# gesture, never as wheel buttons. Godot's macOS pan delta.y is positive for
# scroll-down, so a negative delta zooms in, matching WHEEL_UP. Synthetic events
# prove the mapping, not the hardware; the real trackpad is checked by hand.

const PAN_STEP := WorldSelectController.PAN_DELTA_PER_STEP
const MAGNIFY_STEP := WorldSelectController.ZOOM_STEP * 1.01   # a hair over one step, clear of float rounding

func _pan(delta_y: float) -> InputEventPanGesture:
	var ev := InputEventPanGesture.new()
	ev.delta = Vector2(0.0, delta_y)
	return ev

func _magnify(factor: float) -> InputEventMagnifyGesture:
	var ev := InputEventMagnifyGesture.new()
	ev.factor = factor
	return ev

# Enter selection mode at a zoom with room to move both ways, in world or segment mode.
func _enter_mid_zoom(segment: bool) -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX if segment else DEACTIVATE_PX - 4.0)
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT if segment else WorldSelectController.Mode.WORLD,
			"precondition: starting mode")

func test_pan_up_zooms_in_like_wheel_up_in_both_modes() -> void:
	for segment: bool in [false, true]:
		_c.free()
		before_each()
		_enter_mid_zoom(segment)
		var start: float = _c.zoom
		_c._gui_input(_pan(-PAN_STEP))
		assert_almost_eq(_c.zoom, start * WorldSelectController.ZOOM_STEP, 0.0001,
				"one step of upward pan zooms in by ZOOM_STEP (segment=%s)" % segment)

func test_pan_down_zooms_out_like_wheel_down_in_both_modes() -> void:
	for segment: bool in [false, true]:
		_c.free()
		before_each()
		_enter_mid_zoom(segment)
		var start: float = _c.zoom
		_c._gui_input(_pan(PAN_STEP))
		assert_almost_eq(_c.zoom, start / WorldSelectController.ZOOM_STEP, 0.0001,
				"one step of downward pan zooms out by ZOOM_STEP (segment=%s)" % segment)

func test_small_pan_deltas_accumulate_into_whole_steps() -> void:
	_enter_mid_zoom(true)
	var start: float = _c.zoom
	var slice := PAN_STEP / 4.0
	for _i: int in 3:
		_c._gui_input(_pan(-slice))
	assert_eq(_c.zoom, start, "three quarters of a step moves nothing")
	_c._gui_input(_pan(-slice))
	assert_almost_eq(_c.zoom, start * WorldSelectController.ZOOM_STEP, 0.0001,
			"the fourth slice completes one step")
	for _i: int in 4:
		_c._gui_input(_pan(-slice))
	assert_almost_eq(_c.zoom, start * pow(WorldSelectController.ZOOM_STEP, 2.0), 0.0001,
			"four more slices make exactly one more step")

func test_one_large_swipe_is_a_few_steps_not_dozens() -> void:
	_enter_mid_zoom(false)
	var start: float = _c.zoom
	var total_delta := 0.0
	while total_delta < 3.0 * PAN_STEP:   # 3 steps of travel, streamed as tiny events
		_c._gui_input(_pan(-0.1))
		total_delta += 0.1
	var steps := roundi(log(_c.zoom / start) / log(WorldSelectController.ZOOM_STEP))
	assert_between(steps, 2, 3, "about three steps for three steps of travel")

func test_pan_that_reverses_drops_the_leftover_of_the_old_direction() -> void:
	_enter_mid_zoom(true)
	var start: float = _c.zoom
	_c._gui_input(_pan(-PAN_STEP * 0.75))
	_c._gui_input(_pan(PAN_STEP * 0.5))
	assert_eq(_c.zoom, start, "half a step the other way is still only half a step")

func test_pan_steps_function_is_pure_and_signed() -> void:
	assert_eq(WorldSelectController.pan_zoom_steps(0.0), 0)
	assert_eq(WorldSelectController.pan_zoom_steps(-PAN_STEP), 1, "negative delta zooms in")
	assert_eq(WorldSelectController.pan_zoom_steps(PAN_STEP), -1, "positive delta zooms out")
	assert_eq(WorldSelectController.pan_zoom_steps(-PAN_STEP * 2.9), 2, "part-steps truncate")
	assert_eq(WorldSelectController.pan_zoom_steps(PAN_STEP * 2.9), -2)

func test_magnify_above_one_zooms_in_in_both_modes() -> void:
	for segment: bool in [false, true]:
		_c.free()
		before_each()
		_enter_mid_zoom(segment)
		var start: float = _c.zoom
		_c._gui_input(_magnify(MAGNIFY_STEP))
		assert_almost_eq(_c.zoom, start * WorldSelectController.ZOOM_STEP, 0.0001,
				"fingers apart zoom in (segment=%s)" % segment)

func test_magnify_below_one_zooms_out_in_both_modes() -> void:
	for segment: bool in [false, true]:
		_c.free()
		before_each()
		_enter_mid_zoom(segment)
		var start: float = _c.zoom
		_c._gui_input(_magnify(1.0 / MAGNIFY_STEP))
		assert_almost_eq(_c.zoom, start / WorldSelectController.ZOOM_STEP, 0.0001,
				"fingers together zoom out (segment=%s)" % segment)

func test_small_magnify_factors_accumulate_and_a_factor_of_one_does_nothing() -> void:
	_enter_mid_zoom(true)
	var start: float = _c.zoom
	_c._gui_input(_magnify(1.0))
	assert_eq(_c.zoom, start, "factor 1.0 is no gesture")
	for _i: int in 5:
		_c._gui_input(_magnify(1.04))   # 1.04^5 is about 1.22, just short of one step
	assert_eq(_c.zoom, start, "a pinch short of one step moves nothing")
	_c._gui_input(_magnify(1.04))       # 1.04^6 is about 1.27
	assert_almost_eq(_c.zoom, start * WorldSelectController.ZOOM_STEP, 0.0001)

func test_gestures_are_ignored_while_inactive() -> void:
	var start: float = _c.zoom
	_c._gui_input(_pan(-PAN_STEP * 5.0))
	_c._gui_input(_magnify(MAGNIFY_STEP * 2.0))
	assert_eq(_c.mode, WorldSelectController.Mode.INACTIVE)
	assert_eq(_c.zoom, start, "an inactive controller never zooms")
	_c.enter_selection_mode()
	assert_eq(_c.zoom, WorldSelectController.ZOOM_MIN, "and holds no stale gesture travel after entering")
	_c._gui_input(_pan(PAN_STEP * 0.5))
	assert_eq(_c.zoom, WorldSelectController.ZOOM_MIN)

func test_gesture_zoom_drives_the_camera_in_segment_mode() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_c._gui_input(_pan(-PAN_STEP))
	assert_almost_eq(_camera_tile_px(), _c.tile_px(), 0.001, "pan zoom reaches the world")
	_c._gui_input(_magnify(MAGNIFY_STEP))
	assert_almost_eq(_camera_tile_px(), _c.tile_px(), 0.001, "pinch zoom reaches the world")
	_free_camera()

func test_wheel_still_zooms_by_one_step_after_gestures() -> void:
	_enter_mid_zoom(false)
	_c._gui_input(_pan(-PAN_STEP * 0.5))   # leaves half a step pending
	var start: float = _c.zoom
	_c._gui_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP))
	assert_almost_eq(_c.zoom, start * WorldSelectController.ZOOM_STEP, 0.0001)

# --- live world at segment zoom (ADR 0021) ---
#
# Segment mode used to draw an opaque card grid over the world. Now the cards
# fade out across the 12–16 px hysteresis band, the controller drives the world
# camera so the live world shows at the controller's own tile size, and leaving
# restores the camera the player had.

const PLAYER_CAMERA_POSITION := Vector2(321.0, 117.0)
const PLAYER_CAMERA_ZOOM := Vector2(2.0, 2.0)
const SUB_AREA_CENTRE := Vector2(400.0, 250.0)

var _camera: Camera2D

func _attach_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = PLAYER_CAMERA_POSITION
	_camera.zoom = PLAYER_CAMERA_ZOOM
	_c.attach_world_camera(_camera,
			func(id: int) -> Vector2: return SUB_AREA_CENTRE + Vector2(float(id), 0.0))

func _free_camera() -> void:
	_camera.free()
	_camera = null

# On-screen flat-to-flat tile size of the live world through the camera.
func _camera_tile_px() -> float:
	return WorldRenderer.TILE_FLAT_TO_FLAT_PX * _camera.zoom.x

func _assert_player_camera_restored() -> void:
	assert_eq(_camera.position, PLAYER_CAMERA_POSITION, "player's camera position restored")
	assert_eq(_camera.zoom, PLAYER_CAMERA_ZOOM, "player's camera zoom restored")

func test_segment_mode_draws_no_backdrop_or_cards() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	assert_eq(_c.mode, WorldSelectController.Mode.SEGMENT, "precondition: segment mode")
	assert_eq(_c.world_reveal(), 1.0, "the live world is fully revealed")
	assert_eq(_c.card_layer_alpha(), 0.0, "no opaque backdrop and no card grid")

func test_world_view_draws_the_cards_fully_opaque() -> void:
	_c.enter_selection_mode()
	assert_eq(_c.card_layer_alpha(), 1.0, "full-Y2Y view is the card grid")
	assert_eq(_c.world_reveal(), 0.0)

func test_cards_give_way_across_the_hysteresis_band() -> void:
	_c.enter_selection_mode()
	_zoom_to_px(DEACTIVATE_PX)
	assert_eq(_c.card_layer_alpha(), 1.0, "band start: still all cards")
	_zoom_to_px((ACTIVATE_PX + DEACTIVATE_PX) / 2.0)
	assert_almost_eq(_c.card_layer_alpha(), 0.5, 0.001, "mid-band: half faded")
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD, "still world mode inside the band")
	_zoom_to_px(ACTIVATE_PX)
	assert_eq(_c.card_layer_alpha(), 0.0, "band end: the live world only")

func test_crossing_the_band_raises_no_prompt_or_extra_event() -> void:
	_c.enter_selection_mode()
	_events.clear()
	for px: float in [DEACTIVATE_PX, 13.0, 14.0, 15.0, ACTIVATE_PX]:
		_zoom_to_px(px)
	assert_eq(_events, ["segment_on:7"],
			"the only thing between world view and segment mode is the mode change itself")

func test_locked_focus_never_reveals_the_world() -> void:
	_c.enter_selection_mode()
	_c.set_focused_sub_area(8)
	_zoom_to_px(ACTIVATE_PX)
	assert_eq(_c.world_reveal(), 0.0, "clamped at the boundary, the cards stay up")
	assert_eq(_c.card_layer_alpha(), 1.0)

func test_card_layer_is_not_drawn_while_inactive() -> void:
	assert_eq(_c.card_layer_alpha(), 0.0)

func test_segment_zoom_drives_the_world_camera() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_assert_player_camera_restored()   # world view leaves the camera alone
	_zoom_to_px(ACTIVATE_PX)
	assert_almost_eq(_camera_tile_px(), _c.tile_px(), 0.001,
			"on-screen tile size matches the controller's tile_px")
	assert_eq(_camera.position, SUB_AREA_CENTRE + Vector2(7.0, 0.0),
			"centred on the focused sub-area")
	_c.zoom_in()
	assert_almost_eq(_camera_tile_px(), _c.tile_px(), 0.001, "follows further zoom")
	_free_camera()

func test_camera_is_driven_inside_the_band_as_the_cards_fade() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_zoom_to_px((ACTIVATE_PX + DEACTIVATE_PX) / 2.0)
	assert_almost_eq(_camera_tile_px(), _c.tile_px(), 0.001,
			"the world behind the fading cards is already at the controller's scale")
	_free_camera()

func test_zooming_out_of_segment_mode_restores_the_player_camera() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_zoom_to_px(DEACTIVATE_PX - 0.1)
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD, "precondition: back to world view")
	_assert_player_camera_restored()
	_free_camera()

func test_escape_restores_the_player_camera() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_c.zoom_in()
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	_c._unhandled_input(ev)
	_assert_player_camera_restored()
	_free_camera()

func test_confirm_hand_off_restores_the_player_camera() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_c.exit_selection_mode(false)   # the confirm → construction path
	_assert_player_camera_restored()
	_free_camera()

func test_focusing_a_locked_area_restores_the_player_camera() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_c.set_focused_sub_area(9)
	_assert_player_camera_restored()
	_free_camera()

func test_camera_restore_is_exact_after_a_second_visit() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_zoom_to_px(DEACTIVATE_PX - 0.1)
	_zoom_to_px(ACTIVATE_PX)
	_c.exit_selection_mode()
	_assert_player_camera_restored()   # the driven framing is never saved as the player's
	_free_camera()

func test_scroll_wheel_zoom_drives_the_camera_in_segment_mode() -> void:
	_attach_camera()
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)
	_c._gui_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP))
	assert_almost_eq(_camera_tile_px(), _c.tile_px(), 0.001, "wheel zoom reaches the world")
	_free_camera()

# --- segment hover highlight (PRD rules 8-9) ---

const HOVER_ROAD := { "id": "road", "tiles": [[0, 0], [1, 0]] }
const HOVER_MEADOW := { "id": "meadow", "tiles": [[5, 5], [6, 5]] }
const HOVER_DANGEROUS_TILES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]

# Hover over `HOVER_ROAD` at x < 100, `HOVER_MEADOW` at x < 200, else nothing.
func _attach_hover_picker() -> void:
	_c.attach_hover_picker(
			func(at: Vector2) -> Dictionary:
				if at.x < 100.0:
					return HOVER_ROAD
				return HOVER_MEADOW if at.x < 200.0 else {},
			func(coord: Vector2i) -> bool: return HOVER_DANGEROUS_TILES.has(coord))

func _enter_segment_mode_with_picker() -> void:
	_attach_hover_picker()
	_c.enter_selection_mode()
	_zoom_to_px(ACTIVATE_PX)

func _motion(at: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	return ev

func test_hover_highlights_dangerous_only() -> void:
	_enter_segment_mode_with_picker()
	var changes: Array = []
	_c.hover_highlight_changed.connect(func(tiles: Array) -> void: changes.append(tiles.size()))
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	assert_eq(_c.hover_tiles, HOVER_DANGEROUS_TILES, "a dangerous segment's tiles are highlighted")
	_c._gui_input(_motion(Vector2(150.0, 0.0)))
	assert_eq(_c.hover_tiles.size(), 0, "a segment of plain terrain highlights nothing")
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	_c._gui_input(_motion(Vector2(300.0, 0.0)))
	assert_eq(_c.hover_tiles.size(), 0, "no segment under the cursor highlights nothing")
	assert_eq(changes, [2, 0, 2, 0], "the signal fires on change only")

func test_hover_does_nothing_in_world_view() -> void:
	_attach_hover_picker()
	_c.enter_selection_mode()
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	assert_eq(_c.hover_tiles.size(), 0, "world view has no segment highlight")

func test_hover_clears_on_leaving_segment_mode() -> void:
	_enter_segment_mode_with_picker()
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	_zoom_to_px(DEACTIVATE_PX - 1.0)
	assert_eq(_c.mode, WorldSelectController.Mode.WORLD, "precondition: left segment mode")
	assert_eq(_c.hover_tiles.size(), 0, "the highlight clears on exit from segment mode")

func test_hover_clears_on_escape() -> void:
	_enter_segment_mode_with_picker()
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	_c._unhandled_input(ev)
	assert_eq(_c.hover_tiles.size(), 0, "Escape clears the highlight")

# --- hover tooltip (cached connectivity label) ---

const TOOLTIP_LABEL := "High fragmentation"

func _attach_label_source() -> Array:
	var reads: Array = []
	_c.attach_hover_label(func(segment_id: String) -> String:
		reads.append(segment_id)
		return TOOLTIP_LABEL)
	return reads

func test_tooltip_label_shows_for_highlighted_segment() -> void:
	_enter_segment_mode_with_picker()
	_attach_label_source()
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	assert_eq(_c.hover_label, TOOLTIP_LABEL)

func test_tooltip_absent_when_nothing_highlighted() -> void:
	_enter_segment_mode_with_picker()
	var reads := _attach_label_source()
	_c._gui_input(_motion(Vector2(150.0, 0.0)))
	assert_eq(_c.hover_label, "", "plain terrain has no tooltip")
	_c._gui_input(_motion(Vector2(300.0, 0.0)))
	assert_eq(_c.hover_label, "", "no segment has no tooltip")
	assert_eq(reads.size(), 0, "the label source is only read for a highlighted segment")

func test_tooltip_absent_without_label_source_or_score() -> void:
	_enter_segment_mode_with_picker()
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	assert_eq(_c.hover_label, "", "no label source attached")
	_c.attach_hover_label(func(_id: String) -> String: return "")
	_c._gui_input(_motion(Vector2(60.0, 0.0)))
	assert_eq(_c.hover_label, "", "an unscored segment shows no tooltip")

func test_tooltip_reads_label_for_the_segment_id() -> void:
	_enter_segment_mode_with_picker()
	var reads := _attach_label_source()
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	assert_eq(reads, ["road"])

func test_tooltip_clears_with_the_highlight() -> void:
	_enter_segment_mode_with_picker()
	_attach_label_source()
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	_c._gui_input(_motion(Vector2(300.0, 0.0)))
	assert_eq(_c.hover_label, "", "moving off the segment drops the tooltip")
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	_zoom_to_px(DEACTIVATE_PX - 1.0)
	assert_eq(_c.hover_label, "", "leaving segment mode drops the tooltip")
	_enter_segment_mode_again()
	_c._gui_input(_motion(Vector2(50.0, 0.0)))
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	_c._unhandled_input(ev)
	assert_eq(_c.hover_label, "", "Escape drops the tooltip")

func _enter_segment_mode_again() -> void:
	_zoom_to_px(ACTIVATE_PX)

func test_tooltip_uses_text_scale_sizes() -> void:
	assert_eq(WorldSelectController.tooltip_font_size(), TextScale.size(TextScale.SMALL))
	TextScale.set_step(TextScale.STEPS.size() - 1)
	assert_eq(WorldSelectController.tooltip_font_size(), TextScale.size(TextScale.SMALL),
			"follows the live step")
	assert_gt(WorldSelectController.tooltip_font_size(), TextScale.SMALL)
	TextScale.set_step(0)

func test_tooltip_rect_follows_cursor_and_stays_on_screen() -> void:
	_enter_segment_mode_with_picker()
	_attach_label_source()
	_c.size = Vector2(400.0, 300.0)
	var text := Vector2(100.0, 20.0)
	assert_eq(_c.tooltip_rect(text), Rect2(), "no label, no rect")
	_c._gui_input(_motion(Vector2(50.0, 40.0)))
	var rect := _c.tooltip_rect(text)
	assert_eq(rect.position, Vector2(50.0, 40.0) + WorldSelectController.TOOLTIP_OFFSET)
	assert_eq(rect.size, text + WorldSelectController.TOOLTIP_PADDING * 2.0)
	_c._gui_input(_motion(Vector2(95.0, 290.0)))
	rect = _c.tooltip_rect(text)
	assert_true(Rect2(Vector2.ZERO, _c.size).encloses(rect), "clamped inside the control")

func test_hover_colour_is_distinct_from_overlay_and_ghosts() -> void:
	var taken: Array[Color] = [
		ConnectivityOverlay.COLOR_FRAGMENTED, ConnectivityOverlay.COLOR_CONNECTED,
		WorldRenderer.COLOR_BUILD_CHOSEN, WorldRenderer.COLOR_BUILD_HOVER_VALID,
		WorldRenderer.COLOR_BUILD_HOVER_INVALID, WorldRenderer.COLOR_HOTSPOT,
		WorldRenderer.COLOR_COMPLETED_CROSSING]
	for other: Color in taken:
		assert_false(WorldRenderer.COLOR_SEGMENT_HOVER.is_equal_approx(other))
