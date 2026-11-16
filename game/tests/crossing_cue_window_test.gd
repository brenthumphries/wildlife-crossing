## Tests for Main's "+N crossed safely" cue window: a fixed 2-second window, not a debounce (ATT-173).
extends GutTest

const WINDOW: float = SimulationConstants.CROSSING_FEEDBACK_COALESCE_SECONDS
const FRAME: float = 0.25   # exact in binary, so windows divide evenly

var _m: Main

func before_each() -> void:
	_m = Main.new()

func after_each() -> void:
	_m.free()

## Cross once per frame for `seconds`, returning the cue sizes that fired.
func _run_steady(seconds: float) -> Array[int]:
	var cues: Array[int] = []
	var elapsed: float = 0.0
	while elapsed < seconds - 0.0001:
		_m._on_animal_crossed("c", "s")
		var n: int = _m._advance_crossing_window(FRAME)
		if n > 0:
			cues.append(n)
		elapsed += FRAME
	return cues

func test_steady_crossings_fire_one_cue_per_window() -> void:
	var cues: Array[int] = _run_steady(WINDOW * 3.0)
	assert_eq(cues.size(), 3, "one cue per window")
	for n: int in cues:
		assert_eq(n, int(WINDOW / FRAME), "each cue carries only its window's count")

func test_single_crossing_shows_plus_one_after_window() -> void:
	_m._on_animal_crossed("c", "s")
	assert_eq(_m._advance_crossing_window(WINDOW - 0.5), 0, "not yet")
	assert_eq(_m._advance_crossing_window(0.5), 1)
	assert_eq(_m._advance_crossing_window(WINDOW), 0, "nothing left to flush")

func test_first_window_is_not_oversized() -> void:
	var cues: Array[int] = _run_steady(WINDOW)
	assert_eq(cues.size(), 1)
	assert_eq(cues[0], int(WINDOW / FRAME))

func test_load_drops_pending_count() -> void:
	_m._on_animal_crossed("c", "s")
	_m._on_animal_crossed("c", "s")
	_m._reset_crossing_window()
	assert_eq(_m._advance_crossing_window(WINDOW * 2.0), 0)
	_m._on_animal_crossed("c", "s")
	assert_eq(_m._advance_crossing_window(WINDOW), 1, "first window after load counts only new crossings")

func test_pause_leaves_nothing_pending() -> void:
	# While paused the sim emits no crossings but real time still runs, so the
	# open window flushes and nothing is left to appear on resume.
	_m._on_animal_crossed("c", "s")
	assert_eq(_m._advance_crossing_window(WINDOW), 1)
	assert_eq(_m._crossed_pending, 0)
	assert_eq(_m._advance_crossing_window(WINDOW), 0)
