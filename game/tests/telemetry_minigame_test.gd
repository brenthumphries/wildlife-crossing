## Tests for TelemetryMinigame, the radio-telemetry overlay: station progression, antenna rotation, fix completion and key handling. Solver maths is covered by telemetry_solver_test.
extends GutTest

const SEED := 11
const FINE_STEP_DEG := 0.5

var _m: TelemetryMinigame
var _closed_count := 0
var _fixes: Array = []

func before_each() -> void:
	TextScale.set_step(0)
	_closed_count = 0
	_fixes = []
	_m = TelemetryMinigame.new()
	add_child_autofree(_m)
	_m.closed.connect(func() -> void: _closed_count += 1)
	_m.fix_completed.connect(
			func(band: String, error_metres: float) -> void:
				_fixes.append([band, error_metres]))

func after_each() -> void:
	TextScale.set_step(0)

func _key(keycode: Key, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.shift_pressed = shift
	return event

func _commit_all() -> void:
	for _i: int in range(TelemetrySolver.STATION_COUNT):
		_m.commit_bearing()

# --- lifecycle ---------------------------------------------------------------

func test_starts_closed_and_hidden() -> void:
	assert_false(_m.is_open)
	assert_false(_m.visible)

func test_start_opens_at_station_one() -> void:
	_m.start(SEED)
	assert_true(_m.is_open)
	assert_true(_m.visible)
	assert_eq(_m.active_station, 0)
	assert_eq(_m.bearings.size(), 0)
	assert_false(_m.is_resolved())

func test_close_emits_once_and_hides() -> void:
	_m.start(SEED)
	_m.close()
	_m.close()
	assert_false(_m.is_open)
	assert_false(_m.visible)
	assert_eq(_closed_count, 1)

# --- antenna -----------------------------------------------------------------

func test_rotate_wraps_into_the_compass_range() -> void:
	_m.start(SEED)
	_m.rotate_antenna(-10.0)
	assert_almost_eq(_m.antenna_deg, 350.0, 0.001)
	_m.rotate_antenna(20.0)
	assert_almost_eq(_m.antenna_deg, 10.0, 0.001)

# --- bearings and fix --------------------------------------------------------

func test_commit_advances_station_and_resets_antenna() -> void:
	_m.start(SEED)
	_m.rotate_antenna(42.0)
	_m.commit_bearing()
	assert_eq(_m.active_station, 1)
	assert_eq(_m.bearings.size(), 1)
	assert_almost_eq(_m.bearings[0], 42.0, 0.001)
	assert_almost_eq(_m.antenna_deg, 0.0, 0.001)
	assert_false(_m.is_resolved())

func test_third_commit_resolves_and_emits_the_fix() -> void:
	_m.start(SEED)
	_commit_all()
	assert_true(_m.is_resolved())
	assert_eq(_fixes.size(), 1)
	assert_eq(_fixes[0][0], String(_m.fix["band"]))

func test_commit_and_rotate_are_ignored_once_resolved() -> void:
	_m.start(SEED)
	_commit_all()
	_m.commit_bearing()
	_m.rotate_antenna(30.0)
	assert_eq(_m.bearings.size(), TelemetrySolver.STATION_COUNT)
	assert_eq(_fixes.size(), 1)
	assert_almost_eq(_m.antenna_deg, 0.0, 0.001)

func test_result_text_is_empty_until_resolved_then_has_headline_and_note() -> void:
	_m.start(SEED)
	assert_eq(_m.result_text(), "")
	_commit_all()
	var text := _m.result_text()
	var band := String(_m.fix["band"])
	assert_string_contains(text, String(TelemetryMinigame.BAND_HEADLINES[band]))
	assert_string_contains(text, String(TelemetryMinigame.NATURALIST_NOTES[_m.solver.diagnose(_m.bearings, _m.fix)]))

func test_restart_clears_a_resolved_fix() -> void:
	_m.start(SEED)
	_commit_all()
	_m.start(SEED + 1)
	assert_false(_m.is_resolved())
	assert_eq(_m.bearings.size(), 0)
	assert_eq(_m.active_station, 0)

# --- input -------------------------------------------------------------------

func test_enter_commits_a_bearing() -> void:
	_m.start(SEED)
	_m._unhandled_input(_key(KEY_ENTER))
	assert_eq(_m.bearings.size(), 1)

func test_shift_arrows_nudge_by_the_fine_step() -> void:
	_m.start(SEED)
	_m._unhandled_input(_key(KEY_D, true))
	assert_almost_eq(_m.antenna_deg, FINE_STEP_DEG, 0.001)
	_m._unhandled_input(_key(KEY_A, true))
	assert_almost_eq(_m.antenna_deg, 0.0, 0.001)

func test_unshifted_arrows_do_not_nudge() -> void:
	_m.start(SEED)
	_m._unhandled_input(_key(KEY_D))
	assert_almost_eq(_m.antenna_deg, 0.0, 0.001)

func test_escape_closes_and_r_restarts() -> void:
	_m.start(SEED)
	_m.commit_bearing()
	_m._unhandled_input(_key(KEY_R))
	assert_eq(_m.bearings.size(), 0)
	_m._unhandled_input(_key(KEY_ESCAPE))
	assert_false(_m.is_open)

func test_keys_are_ignored_while_closed() -> void:
	_m._unhandled_input(_key(KEY_ENTER))
	assert_eq(_m.bearings.size(), 0)

# --- text scale --------------------------------------------------------------

func test_label_sizes_follow_the_text_scale_step() -> void:
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		_m.apply_text_scale()
		assert_eq(_m._title_label.get_theme_font_size("font_size"), TextScale.size(TextScale.TITLE))
		assert_eq(_m._controls_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))

func test_label_sizes_reapply_live_on_text_scale_changed() -> void:
	var before: int = _m._controls_label.get_theme_font_size("font_size")
	TextScale.set_step(3)
	assert_eq(_m._controls_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
	assert_ne(_m._controls_label.get_theme_font_size("font_size"), before)

func test_controls_text_fits_the_viewport_at_every_text_scale_step() -> void:
	_m.start(SEED)
	var view := get_viewport().get_visible_rect()
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(view.encloses(_m._controls_label.get_global_rect()),
				"controls text within the viewport at step %d: %s" % [i, _m._controls_label.get_global_rect()])
