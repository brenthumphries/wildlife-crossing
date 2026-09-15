## Tests for TelemetrySolver (Signal Chase minigame): deterministic field
## generation, bearing maths, the Yagi meter model, and triangulation. Every
## local is explicitly typed — GUT loads test scripts warnings-as-errors.
extends GutTest

const SEED_A: int = 1234
const SEED_B: int = 98765
const SEED_SWEEP_COUNT: int = 50
const POSITION_TOLERANCE: float = 0.001
const BEARING_TOLERANCE_DEG: float = 0.001
## The meter is deliberately flat for several degrees around the peak and
## carries deterministic noise, so the observed peak may sit a few degrees
## off the truth. This is the tolerance a careful reading can meet.
const PEAK_TOLERANCE_DEG: float = 10.0
const SWEEP_STEP_DEG: float = 1.0
const BAD_BEARING_OFFSET_DEG: float = 25.0
const EXACT_FIX_TOLERANCE_M: float = 1.0
const BAND_ORDER: Array[String] = [
	TelemetrySolver.BAND_EXCELLENT, TelemetrySolver.BAND_GOOD,
	TelemetrySolver.BAND_LOOSE, TelemetrySolver.BAND_WIDE,
]

var _solver: TelemetrySolver

func before_each() -> void:
	_solver = TelemetrySolver.new()
	_solver.generate(SEED_A)

# --- generate() ----------------------------------------------------------------------

func test_generate_is_deterministic_for_the_same_seed() -> void:
	var other: TelemetrySolver = TelemetrySolver.new()
	other.generate(SEED_A)
	assert_eq(other.stations.size(), TelemetrySolver.STATION_COUNT, "three stations")
	for i: int in range(TelemetrySolver.STATION_COUNT):
		assert_almost_eq(other.stations[i].x, _solver.stations[i].x, POSITION_TOLERANCE,
				"station %d x matches" % i)
		assert_almost_eq(other.stations[i].y, _solver.stations[i].y, POSITION_TOLERANCE,
				"station %d y matches" % i)
	assert_almost_eq(other.target.x, _solver.target.x, POSITION_TOLERANCE, "target x matches")
	assert_almost_eq(other.target.y, _solver.target.y, POSITION_TOLERANCE, "target y matches")

func test_generate_differs_between_seeds() -> void:
	var other: TelemetrySolver = TelemetrySolver.new()
	other.generate(SEED_B)
	var any_station_moved: bool = false
	for i: int in range(TelemetrySolver.STATION_COUNT):
		if other.stations[i].distance_to(_solver.stations[i]) > POSITION_TOLERANCE:
			any_station_moved = true
	assert_true(any_station_moved, "a different seed moves at least one station")
	assert_gt(other.target.distance_to(_solver.target), POSITION_TOLERANCE,
			"a different seed moves the collar")

func test_generate_regenerating_replaces_the_previous_layout() -> void:
	_solver.generate(SEED_B)
	assert_eq(_solver.stations.size(), TelemetrySolver.STATION_COUNT,
			"regenerating does not accumulate stations")
	assert_eq(_solver.seed_value, SEED_B, "seed recorded")

func test_generated_geometry_satisfies_constraints_across_many_seeds() -> void:
	for seed_value: int in range(SEED_SWEEP_COUNT):
		var s: TelemetrySolver = TelemetrySolver.new()
		s.generate(seed_value)
		assert_eq(s.stations.size(), TelemetrySolver.STATION_COUNT,
				"seed %d: three stations" % seed_value)
		for i: int in range(TelemetrySolver.STATION_COUNT):
			assert_true(_inside_field(s.stations[i]), "seed %d: station %d inside field" % [seed_value, i])
			assert_gte(s.stations[i].distance_to(s.target),
					TelemetrySolver.MIN_STATION_TARGET_DISTANCE_M,
					"seed %d: station %d far enough from the collar" % [seed_value, i])
			for j: int in range(i + 1, TelemetrySolver.STATION_COUNT):
				assert_gte(s.stations[i].distance_to(s.stations[j]),
						TelemetrySolver.MIN_STATION_SEPARATION_M,
						"seed %d: stations %d and %d far enough apart" % [seed_value, i, j])
		assert_true(_inside_field(s.target), "seed %d: collar inside field" % seed_value)
		var exact: Dictionary = s.fix_from_bearings(_true_bearings(s))
		var omitted: Array = exact["omitted_pairs"]
		assert_eq(omitted.size(), 0, "seed %d: no true-bearing pair is near-parallel" % seed_value)

# --- bearings ----------------------------------------------------------------------------

func test_true_bearing_at_the_four_cardinal_directions() -> void:
	var origin: Vector2 = Vector2(2000.0, 1500.0)
	_solver.stations = [origin, origin, origin]
	_solver.target = origin + Vector2(0.0, -500.0)   # north is -y
	assert_almost_eq(_solver.true_bearing_from(0), 0.0, BEARING_TOLERANCE_DEG, "north is 0")
	_solver.target = origin + Vector2(500.0, 0.0)
	assert_almost_eq(_solver.true_bearing_from(0), 90.0, BEARING_TOLERANCE_DEG, "east is 90")
	_solver.target = origin + Vector2(0.0, 500.0)
	assert_almost_eq(_solver.true_bearing_from(0), 180.0, BEARING_TOLERANCE_DEG, "south is 180")
	_solver.target = origin + Vector2(-500.0, 0.0)
	assert_almost_eq(_solver.true_bearing_from(0), 270.0, BEARING_TOLERANCE_DEG, "west is 270")

func test_true_bearing_is_normalised_to_the_half_open_circle() -> void:
	for seed_value: int in range(SEED_SWEEP_COUNT):
		var s: TelemetrySolver = TelemetrySolver.new()
		s.generate(seed_value)
		for i: int in range(TelemetrySolver.STATION_COUNT):
			var b: float = s.true_bearing_from(i)
			assert_gte(b, 0.0, "bearing not negative")
			assert_lt(b, 360.0, "bearing below 360")

func test_normalize_and_difference_helpers() -> void:
	assert_almost_eq(TelemetrySolver.normalize_bearing(-90.0), 270.0, BEARING_TOLERANCE_DEG, "-90 wraps")
	assert_almost_eq(TelemetrySolver.normalize_bearing(360.0), 0.0, BEARING_TOLERANCE_DEG, "360 wraps to 0")
	assert_almost_eq(TelemetrySolver.normalize_bearing(725.0), 5.0, BEARING_TOLERANCE_DEG, "725 wraps")
	assert_almost_eq(TelemetrySolver.bearing_difference(10.0, 350.0), 20.0, BEARING_TOLERANCE_DEG,
			"difference across north is short way round")
	assert_almost_eq(TelemetrySolver.bearing_difference(350.0, 10.0), -20.0, BEARING_TOLERANCE_DEG,
			"difference is signed")

# --- signal_strength() ---------------------------------------------------------------------

func test_signal_peaks_at_the_true_bearing() -> void:
	for i: int in range(TelemetrySolver.STATION_COUNT):
		var truth: float = _solver.true_bearing_from(i)
		var best_deg: float = 0.0
		var best_strength: float = -1.0
		var deg: float = 0.0
		while deg < 360.0:
			var strength: float = _solver.signal_strength(i, deg)
			if strength > best_strength:
				best_strength = strength
				best_deg = deg
			deg += SWEEP_STEP_DEG
		var miss: float = absf(TelemetrySolver.bearing_difference(best_deg, truth))
		assert_lte(miss, PEAK_TOLERANCE_DEG, "station %d peak within tolerance of the truth" % i)
		assert_gt(_solver.signal_strength(i, truth),
				_solver.signal_strength(i, truth + 90.0), "station %d: on-bearing beats broadside" % i)

func test_signal_is_symmetric_about_the_true_bearing() -> void:
	var tolerance: float = 2.0 * TelemetrySolver.NOISE_AMPLITUDE + 0.01
	for i: int in range(TelemetrySolver.STATION_COUNT):
		var truth: float = _solver.true_bearing_from(i)
		for offset: float in [15.0, 30.0, 60.0, 120.0]:
			var left: float = _solver.signal_strength(i, truth - offset)
			var right: float = _solver.signal_strength(i, truth + offset)
			assert_almost_eq(left, right, tolerance,
					"station %d symmetric at ±%.0f°" % [i, offset])

func test_antenna_pattern_has_side_lobes_and_a_dead_back() -> void:
	assert_almost_eq(TelemetrySolver.antenna_pattern(0.0), 1.0, POSITION_TOLERANCE, "boresight is 1")
	var side: float = TelemetrySolver.antenna_pattern(TelemetrySolver.SIDE_LOBE_ANGLE_DEG)
	assert_almost_eq(side, TelemetrySolver.SIDE_LOBE_FLOOR, POSITION_TOLERANCE,
			"side lobe reads at the floor")
	assert_gt(side, TelemetrySolver.antenna_pattern(90.0), "side lobe beats broadside")
	assert_almost_eq(TelemetrySolver.antenna_pattern(180.0), 0.0, POSITION_TOLERANCE,
			"directly behind reads nothing")

func test_signal_is_deterministic_for_identical_inputs() -> void:
	var other: TelemetrySolver = TelemetrySolver.new()
	other.generate(SEED_A)
	for i: int in range(TelemetrySolver.STATION_COUNT):
		for deg: float in [0.0, 37.5, 212.0, 359.0]:
			assert_eq(_solver.signal_strength(i, deg), _solver.signal_strength(i, deg),
					"same solver, same reading")
			assert_eq(_solver.signal_strength(i, deg), other.signal_strength(i, deg),
					"same seed, same reading")

func test_signal_stays_within_unit_range_across_a_full_sweep() -> void:
	for i: int in range(TelemetrySolver.STATION_COUNT):
		var lowest: float = INF
		var highest: float = -INF
		var deg: float = 0.0
		while deg < 360.0:
			var strength: float = _solver.signal_strength(i, deg)
			lowest = minf(lowest, strength)
			highest = maxf(highest, strength)
			deg += SWEEP_STEP_DEG
		assert_gte(lowest, 0.0, "station %d never below 0" % i)
		assert_lte(highest, 1.0, "station %d never above 1" % i)

func test_distance_attenuation_never_exceeds_one_and_falls_off() -> void:
	assert_eq(TelemetrySolver.distance_attenuation(0.0), 1.0, "at the station")
	assert_eq(TelemetrySolver.distance_attenuation(TelemetrySolver.REFERENCE_DISTANCE_M), 1.0,
			"at the reference distance")
	var near: float = TelemetrySolver.distance_attenuation(1000.0)
	var far: float = TelemetrySolver.distance_attenuation(3000.0)
	assert_lt(near, 1.0, "beyond reference is weaker")
	assert_lt(far, near, "further is weaker still")
	assert_gt(far, 0.0, "never silent")

# --- fix_from_bearings() ---------------------------------------------------------------------

func test_exact_bearings_give_an_excellent_fix_on_the_collar() -> void:
	var fix: Dictionary = _solver.fix_from_bearings(_true_bearings(_solver))
	var intersections: Array[Vector2] = fix["intersections"]
	assert_eq(intersections.size(), 3, "three pairwise intersections")
	assert_almost_eq(float(fix["error_metres"]), 0.0, EXACT_FIX_TOLERANCE_M, "centroid on the collar")
	assert_eq(String(fix["band"]), TelemetrySolver.BAND_EXCELLENT, "excellent band")
	assert_lt(float(fix["polygon_area"]), EXACT_FIX_TOLERANCE_M, "degenerate polygon")
	var centroid: Vector2 = fix["centroid"]
	assert_almost_eq(centroid.x, _solver.target.x, EXACT_FIX_TOLERANCE_M, "centroid x")
	assert_almost_eq(centroid.y, _solver.target.y, EXACT_FIX_TOLERANCE_M, "centroid y")

func test_a_bad_bearing_degrades_the_fix() -> void:
	var exact: Dictionary = _solver.fix_from_bearings(_true_bearings(_solver))
	var bad_bearings: Array[float] = _true_bearings(_solver)
	bad_bearings[1] = TelemetrySolver.normalize_bearing(bad_bearings[1] + BAD_BEARING_OFFSET_DEG)
	var bad: Dictionary = _solver.fix_from_bearings(bad_bearings)
	assert_gt(float(bad["error_metres"]), float(exact["error_metres"]), "error grows")
	assert_gt(float(bad["polygon_area"]), float(exact["polygon_area"]), "polygon opens up")
	assert_gt(BAND_ORDER.find(String(bad["band"])), BAND_ORDER.find(String(exact["band"])),
			"band worsens")

func test_band_thresholds_are_ordered() -> void:
	assert_eq(TelemetrySolver.band_for_error(0.0), TelemetrySolver.BAND_EXCELLENT)
	assert_eq(TelemetrySolver.band_for_error(TelemetrySolver.EXCELLENT_MAX_ERROR_M + 1.0),
			TelemetrySolver.BAND_GOOD)
	assert_eq(TelemetrySolver.band_for_error(TelemetrySolver.GOOD_MAX_ERROR_M + 1.0),
			TelemetrySolver.BAND_LOOSE)
	assert_eq(TelemetrySolver.band_for_error(TelemetrySolver.LOOSE_MAX_ERROR_M + 1.0),
			TelemetrySolver.BAND_WIDE)

func test_near_parallel_bearings_omit_the_pair_without_nan_or_inf() -> void:
	var bearings: Array[float] = _true_bearings(_solver)
	bearings[1] = bearings[0]   # exactly parallel with station 0
	var fix: Dictionary = _solver.fix_from_bearings(bearings)
	var omitted: Array = fix["omitted_pairs"]
	assert_eq(omitted.size(), 1, "one pair omitted")
	assert_eq(omitted[0], [0, 1], "the parallel pair is named")
	var intersections: Array[Vector2] = fix["intersections"]
	assert_eq(intersections.size(), 2, "the other two pairs still cross")
	_assert_finite(fix)

func test_all_parallel_bearings_still_return_a_finite_fix() -> void:
	var bearings: Array[float] = [45.0, 45.0, 45.0 + TelemetrySolver.MIN_INTERSECT_ANGLE_DEG * 0.5]
	var fix: Dictionary = _solver.fix_from_bearings(bearings)
	var omitted: Array = fix["omitted_pairs"]
	assert_eq(omitted.size(), 3, "every pair omitted")
	var intersections: Array[Vector2] = fix["intersections"]
	assert_eq(intersections.size(), 0, "no intersections")
	assert_eq(float(fix["polygon_area"]), 0.0, "no polygon")
	_assert_finite(fix)

func test_antiparallel_bearings_count_as_parallel() -> void:
	var bearings: Array[float] = _true_bearings(_solver)
	bearings[2] = TelemetrySolver.normalize_bearing(bearings[0] + 180.0)
	var fix: Dictionary = _solver.fix_from_bearings(bearings)
	var omitted: Array = fix["omitted_pairs"]
	assert_eq(omitted.size(), 1, "the reversed line is the same line")
	assert_eq(omitted[0], [0, 2], "pair 0-2 omitted")
	_assert_finite(fix)

# --- diagnose() -------------------------------------------------------------------------------

func test_diagnose_names_a_side_lobe_bearing() -> void:
	var bearings: Array[float] = _true_bearings(_solver)
	bearings[0] = TelemetrySolver.normalize_bearing(bearings[0] + TelemetrySolver.SIDE_LOBE_ANGLE_DEG)
	var fix: Dictionary = _solver.fix_from_bearings(bearings)
	assert_eq(_solver.diagnose(bearings, fix), TelemetrySolver.DIAG_SIDE_LOBE)

func test_diagnose_names_a_parallel_pair() -> void:
	var bearings: Array[float] = _true_bearings(_solver)
	bearings[1] = bearings[0]
	var fix: Dictionary = _solver.fix_from_bearings(bearings)
	var verdict: String = _solver.diagnose(bearings, fix)
	# A parallel pair implies one bearing is badly off; either explanation is
	# honest, but a *side-lobe* verdict needs a side-lobe-sized error.
	if absf(_solver.bearing_error_deg(1, bearings[1])) >= TelemetrySolver.SIDE_LOBE_ERROR_DEG:
		assert_eq(verdict, TelemetrySolver.DIAG_SIDE_LOBE)
	else:
		assert_eq(verdict, TelemetrySolver.DIAG_PARALLEL)

func test_diagnose_names_thin_geometry_on_a_hand_built_field() -> void:
	# Three stations along one line with the wolf off the end of it: every
	# pair of true bearings crosses shallowly (but not so shallowly as to be
	# omitted as parallel).
	_solver.stations = [Vector2(500.0, 1500.0), Vector2(1500.0, 1500.0), Vector2(2500.0, 1500.0)]
	_solver.target = Vector2(3600.0, 2100.0)
	var bearings: Array[float] = _true_bearings(_solver)
	var fix: Dictionary = _solver.fix_from_bearings(bearings)
	assert_eq(_solver.diagnose(bearings, fix), TelemetrySolver.DIAG_THIN_GEOMETRY)

func test_diagnose_is_clean_for_exact_bearings_on_a_spread_field() -> void:
	_solver.stations = [Vector2(500.0, 500.0), Vector2(3500.0, 600.0), Vector2(2000.0, 2600.0)]
	_solver.target = Vector2(2000.0, 1300.0)
	var bearings: Array[float] = _true_bearings(_solver)
	var fix: Dictionary = _solver.fix_from_bearings(bearings)
	assert_eq(_solver.diagnose(bearings, fix), TelemetrySolver.DIAG_CLEAN)
	bearings[2] = TelemetrySolver.normalize_bearing(bearings[2] + TelemetrySolver.OFF_PEAK_ERROR_DEG + 1.0)
	fix = _solver.fix_from_bearings(bearings)
	assert_eq(_solver.diagnose(bearings, fix), TelemetrySolver.DIAG_OFF_PEAK, "a few degrees off")

# --- helpers ------------------------------------------------------------------------------------

func _true_bearings(s: TelemetrySolver) -> Array[float]:
	var out: Array[float] = []
	for i: int in range(TelemetrySolver.STATION_COUNT):
		out.append(s.true_bearing_from(i))
	return out

func _inside_field(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 \
			and p.x <= TelemetrySolver.FIELD_SIZE.x and p.y <= TelemetrySolver.FIELD_SIZE.y

func _assert_finite(fix: Dictionary) -> void:
	var centroid: Vector2 = fix["centroid"]
	assert_true(is_finite(centroid.x) and is_finite(centroid.y), "centroid is finite")
	assert_true(is_finite(float(fix["error_metres"])), "error is finite")
	assert_true(is_finite(float(fix["polygon_area"])), "area is finite")
	var intersections: Array[Vector2] = fix["intersections"]
	for p: Vector2 in intersections:
		assert_true(is_finite(p.x) and is_finite(p.y), "intersection is finite")
