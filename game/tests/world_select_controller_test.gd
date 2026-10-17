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
