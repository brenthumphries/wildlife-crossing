## Tests for SnowpackProfile (Snowpack Survey minigame): deterministic pit
## generation, the three denning criteria against hand-built profiles, the
## verdict branches, and the criteria report's agreement with the criterion
## functions. Every local is explicitly typed — GUT loads test scripts
## warnings-as-errors and an inferred Variant drops the whole file.
extends GutTest

const SEED_A: int = 4242
const SEED_B: int = 777
const SEED_SWEEP_COUNT: int = 120
const THICKNESS_TOLERANCE_CM: float = 0.001
## A date safely past the persistence threshold, and one safely before it.
const LATE_DATE: String = "2026-05-20"
const EARLY_DATE: String = "2026-04-10"
const ON_THRESHOLD_DATE: String = "2026-" + SnowpackProfile.DENNING_DATE_THRESHOLD
## Layer sizes that clear (or miss) the structural thresholds by a margin.
const THICK_SLAB_CM: float = SnowpackProfile.SUPPORT_MIN_THICKNESS_CM + 10.0
const THIN_SLAB_CM: float = SnowpackProfile.SUPPORT_MIN_THICKNESS_CM - 5.0
const DEEP_HOAR_CM: float = SnowpackProfile.CAVITY_MIN_THICKNESS_CM + 40.0
const SHALLOW_TOTAL_CM: float = SnowpackProfile.DEN_MIN_DEPTH_CM - 30.0
const FILLER_CM: float = 40.0
const NEAR_SURFACE_CRUST_CM: float = 3.0
const DENSITY_ROUNDED: float = 280.0
const DENSITY_HOAR: float = 250.0
const DENSITY_CRUST: float = 450.0
const DENSITY_NEW: float = 90.0
const CRITERIA_COUNT: int = 3

var _profile: SnowpackProfile

func before_each() -> void:
	_profile = SnowpackProfile.new()
	_profile.generate(SEED_A)

# --- helpers ----------------------------------------------------------------------------

func _layer(thickness_cm: float, hardness: SnowpackProfile.Hardness,
		grain: SnowpackProfile.Grain, density: float) -> Dictionary:
	return {
		SnowpackProfile.KEY_THICKNESS_CM: thickness_cm,
		SnowpackProfile.KEY_HARDNESS: hardness,
		SnowpackProfile.KEY_GRAIN: grain,
		SnowpackProfile.KEY_DENSITY: density,
	}

func _hand_built(layers: Array[Dictionary], date: String) -> SnowpackProfile:
	var p: SnowpackProfile = SnowpackProfile.new()
	p.layers = layers
	p.survey_date = date
	return p

## A pencil slab over deep depth hoar, deep enough overall: the textbook den.
func _viable_layers() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		_layer(FILLER_CM, SnowpackProfile.Hardness.FOUR_FINGER, SnowpackProfile.Grain.ROUNDED,
				DENSITY_ROUNDED),
		_layer(THICK_SLAB_CM, SnowpackProfile.Hardness.PENCIL, SnowpackProfile.Grain.ROUNDED,
				DENSITY_ROUNDED),
		_layer(DEEP_HOAR_CM, SnowpackProfile.Hardness.FIST, SnowpackProfile.Grain.DEPTH_HOAR,
				DENSITY_HOAR),
	]
	return out

# --- generate() ----------------------------------------------------------------------

func test_generate_is_deterministic_for_the_same_seed() -> void:
	var other: SnowpackProfile = SnowpackProfile.new()
	other.generate(SEED_A)
	assert_eq(other.layers.size(), _profile.layers.size(), "same layer count")
	assert_eq(other.survey_date, _profile.survey_date, "same survey date")
	for i: int in range(_profile.layers.size()):
		var a: Dictionary = _profile.layers[i]
		var b: Dictionary = other.layers[i]
		assert_almost_eq(float(b[SnowpackProfile.KEY_THICKNESS_CM]),
				float(a[SnowpackProfile.KEY_THICKNESS_CM]), THICKNESS_TOLERANCE_CM,
				"layer %d thickness matches" % i)
		assert_eq(int(b[SnowpackProfile.KEY_HARDNESS]), int(a[SnowpackProfile.KEY_HARDNESS]),
				"layer %d hardness matches" % i)
		assert_eq(int(b[SnowpackProfile.KEY_GRAIN]), int(a[SnowpackProfile.KEY_GRAIN]),
				"layer %d grain matches" % i)
		assert_almost_eq(float(b[SnowpackProfile.KEY_DENSITY]),
				float(a[SnowpackProfile.KEY_DENSITY]), THICKNESS_TOLERANCE_CM,
				"layer %d density matches" % i)

func test_generate_differs_between_seeds() -> void:
	var other: SnowpackProfile = SnowpackProfile.new()
	other.generate(SEED_B)
	var differs: bool = other.layers.size() != _profile.layers.size() \
			or other.survey_date != _profile.survey_date
	if not differs:
		for i: int in range(_profile.layers.size()):
			var a: Dictionary = _profile.layers[i]
			var b: Dictionary = other.layers[i]
			if absf(float(a[SnowpackProfile.KEY_THICKNESS_CM])
					- float(b[SnowpackProfile.KEY_THICKNESS_CM])) > THICKNESS_TOLERANCE_CM:
				differs = true
	assert_true(differs, "a different seed produces a different pit")

func test_generate_regenerating_replaces_the_previous_layers() -> void:
	var fresh: SnowpackProfile = SnowpackProfile.new()
	fresh.generate(SEED_B)
	_profile.generate(SEED_B)
	assert_eq(_profile.layers.size(), fresh.layers.size(), "layers are replaced, not accumulated")
	assert_eq(_profile.seed_value, SEED_B, "seed recorded")

func test_generated_profiles_are_well_formed_across_many_seeds() -> void:
	for seed_value: int in range(SEED_SWEEP_COUNT):
		var p: SnowpackProfile = SnowpackProfile.new()
		p.generate(seed_value)
		assert_gt(p.layers.size(), 0, "seed %d: layers non-empty" % seed_value)
		assert_eq(p.survey_date.length(), SnowpackProfile.ISO_DATE_LENGTH,
				"seed %d: ISO survey date" % seed_value)
		var sum: float = 0.0
		for layer: Dictionary in p.layers:
			var thickness: float = float(layer[SnowpackProfile.KEY_THICKNESS_CM])
			var density: float = float(layer[SnowpackProfile.KEY_DENSITY])
			assert_gt(thickness, 0.0, "seed %d: positive thickness" % seed_value)
			assert_gt(density, 0.0, "seed %d: positive density" % seed_value)
			sum += thickness
		assert_almost_eq(p.total_depth_cm(), sum, THICKNESS_TOLERANCE_CM,
				"seed %d: total depth is the sum of thicknesses" % seed_value)

func test_generator_produces_all_three_verdicts() -> void:
	var seen: Dictionary = {}
	for seed_value: int in range(SEED_SWEEP_COUNT):
		var p: SnowpackProfile = SnowpackProfile.new()
		p.generate(seed_value)
		seen[p.evaluate()] = true
	assert_true(seen.has(SnowpackProfile.Verdict.VIABLE), "some seed is VIABLE")
	assert_true(seen.has(SnowpackProfile.Verdict.MARGINAL), "some seed is MARGINAL")
	assert_true(seen.has(SnowpackProfile.Verdict.NOT_VIABLE), "some seed is NOT_VIABLE")

func test_generator_reaches_every_scenario_family() -> void:
	var seen: Dictionary = {}
	for seed_value: int in range(SEED_SWEEP_COUNT):
		var p: SnowpackProfile = SnowpackProfile.new()
		p.generate(seed_value)
		seen[p.scenario] = true
	assert_eq(seen.size(), SnowpackProfile.Scenario.size(), "every scenario family drawn")

# --- depth helpers ----------------------------------------------------------------------

func test_layer_index_at_depth_walks_the_stack() -> void:
	var p: SnowpackProfile = _hand_built(_viable_layers(), LATE_DATE)
	assert_eq(p.layer_index_at_depth(0.0), 0, "surface is the first layer")
	assert_eq(p.layer_index_at_depth(FILLER_CM + 1.0), 1, "just under the first boundary")
	assert_eq(p.layer_index_at_depth(p.total_depth_cm() - 1.0), 2, "near the ground")
	assert_eq(p.layer_index_at_depth(p.total_depth_cm() + 1.0), -1, "below the ground")
	assert_eq(p.layer_index_at_depth(-1.0), -1, "above the surface")
	assert_almost_eq(p.depth_to_layer_top_cm(2), FILLER_CM + THICK_SLAB_CM,
			THICKNESS_TOLERANCE_CM, "depth to the third layer's top")

# --- has_supporting_structure() ---------------------------------------------------------

func test_supporting_structure_true_for_pencil_slab_over_deep_depth_hoar() -> void:
	var p: SnowpackProfile = _hand_built(_viable_layers(), LATE_DATE)
	assert_true(p.has_supporting_structure())

func test_supporting_structure_false_when_slab_too_thin() -> void:
	var layers: Array[Dictionary] = [
		_layer(THIN_SLAB_CM, SnowpackProfile.Hardness.PENCIL, SnowpackProfile.Grain.ROUNDED,
				DENSITY_ROUNDED),
		_layer(DEEP_HOAR_CM, SnowpackProfile.Hardness.FIST, SnowpackProfile.Grain.DEPTH_HOAR,
				DENSITY_HOAR),
	]
	var p: SnowpackProfile = _hand_built(layers, LATE_DATE)
	assert_false(p.has_supporting_structure())

func test_supporting_structure_false_when_slab_too_soft() -> void:
	var layers: Array[Dictionary] = [
		_layer(THICK_SLAB_CM, SnowpackProfile.Hardness.ONE_FINGER, SnowpackProfile.Grain.ROUNDED,
				DENSITY_ROUNDED),
		_layer(DEEP_HOAR_CM, SnowpackProfile.Hardness.FIST, SnowpackProfile.Grain.DEPTH_HOAR,
				DENSITY_HOAR),
	]
	var p: SnowpackProfile = _hand_built(layers, LATE_DATE)
	assert_false(p.has_supporting_structure())

func test_supporting_structure_false_when_slab_is_below_the_depth_hoar() -> void:
	var layers: Array[Dictionary] = [
		_layer(DEEP_HOAR_CM, SnowpackProfile.Hardness.FIST, SnowpackProfile.Grain.DEPTH_HOAR,
				DENSITY_HOAR),
		_layer(THICK_SLAB_CM, SnowpackProfile.Hardness.PENCIL, SnowpackProfile.Grain.ROUNDED,
				DENSITY_ROUNDED),
	]
	var p: SnowpackProfile = _hand_built(layers, LATE_DATE)
	assert_false(p.has_supporting_structure(), "a slab under the hoar is a floor, not a roof")

func test_supporting_structure_accepts_faceted_cavity_horizon() -> void:
	var layers: Array[Dictionary] = [
		_layer(THICK_SLAB_CM, SnowpackProfile.Hardness.KNIFE,
				SnowpackProfile.Grain.MELT_FREEZE_CRUST, DENSITY_CRUST),
		_layer(DEEP_HOAR_CM, SnowpackProfile.Hardness.FOUR_FINGER, SnowpackProfile.Grain.FACETED,
				DENSITY_HOAR),
	]
	var p: SnowpackProfile = _hand_built(layers, LATE_DATE)
	assert_true(p.has_supporting_structure())

# --- persists_past_denning_date() -------------------------------------------------------

func test_persistence_false_before_the_threshold_date() -> void:
	var p: SnowpackProfile = _hand_built(_viable_layers(), EARLY_DATE)
	assert_false(p.persists_past_denning_date())

func test_persistence_false_on_threshold_with_near_surface_crust() -> void:
	var layers: Array[Dictionary] = [
		_layer(NEAR_SURFACE_CRUST_CM, SnowpackProfile.Hardness.KNIFE,
				SnowpackProfile.Grain.MELT_FREEZE_CRUST, DENSITY_CRUST),
	]
	layers.append_array(_viable_layers())
	var p: SnowpackProfile = _hand_built(layers, ON_THRESHOLD_DATE)
	assert_true(p.has_melt_signature(), "the crust is a melt signature")
	assert_false(p.persists_past_denning_date())

func test_persistence_true_on_threshold_with_cold_profile() -> void:
	var p: SnowpackProfile = _hand_built(_viable_layers(), ON_THRESHOLD_DATE)
	assert_false(p.has_melt_signature())
	assert_true(p.persists_past_denning_date())

func test_persistence_ignores_a_melt_form_buried_below_the_signature_depth() -> void:
	var layers: Array[Dictionary] = _viable_layers()
	layers.append(_layer(NEAR_SURFACE_CRUST_CM, SnowpackProfile.Hardness.KNIFE,
			SnowpackProfile.Grain.ICE_LENS, DENSITY_CRUST))
	var p: SnowpackProfile = _hand_built(layers, LATE_DATE)
	assert_false(p.has_melt_signature(), "a lens at the ground is old weather, not spring")
	assert_true(p.persists_past_denning_date())

func test_persistence_false_for_malformed_date() -> void:
	var p: SnowpackProfile = _hand_built(_viable_layers(), "May 20")
	assert_false(p.persists_past_denning_date())

# --- evaluate() -------------------------------------------------------------------------

func test_evaluate_viable_when_all_criteria_hold() -> void:
	var p: SnowpackProfile = _hand_built(_viable_layers(), LATE_DATE)
	assert_true(p.is_deep_enough(), "precondition: deep")
	assert_eq(p.evaluate(), SnowpackProfile.Verdict.VIABLE)

func test_evaluate_not_viable_when_shallow() -> void:
	var layers: Array[Dictionary] = [
		_layer(SHALLOW_TOTAL_CM, SnowpackProfile.Hardness.FIST, SnowpackProfile.Grain.DEPTH_HOAR,
				DENSITY_HOAR),
	]
	var p: SnowpackProfile = _hand_built(layers, LATE_DATE)
	assert_eq(p.evaluate(), SnowpackProfile.Verdict.NOT_VIABLE)

func test_evaluate_marginal_when_deep_but_melting() -> void:
	var layers: Array[Dictionary] = [
		_layer(NEAR_SURFACE_CRUST_CM, SnowpackProfile.Hardness.KNIFE,
				SnowpackProfile.Grain.MELT_FREEZE_CRUST, DENSITY_CRUST),
	]
	layers.append_array(_viable_layers())
	var p: SnowpackProfile = _hand_built(layers, LATE_DATE)
	assert_true(p.is_deep_enough(), "precondition: deep")
	assert_true(p.has_supporting_structure(), "precondition: structure")
	assert_eq(p.evaluate(), SnowpackProfile.Verdict.MARGINAL)

func test_evaluate_marginal_when_deep_but_no_structure() -> void:
	var layers: Array[Dictionary] = [
		_layer(FILLER_CM, SnowpackProfile.Hardness.FIST, SnowpackProfile.Grain.NEW_SNOW, DENSITY_NEW),
		_layer(FILLER_CM, SnowpackProfile.Hardness.ONE_FINGER, SnowpackProfile.Grain.ROUNDED,
				DENSITY_ROUNDED),
		_layer(FILLER_CM, SnowpackProfile.Hardness.ONE_FINGER, SnowpackProfile.Grain.ROUNDED,
				DENSITY_ROUNDED),
	]
	var p: SnowpackProfile = _hand_built(layers, LATE_DATE)
	assert_true(p.is_deep_enough(), "precondition: deep")
	assert_eq(p.evaluate(), SnowpackProfile.Verdict.MARGINAL)

# --- criteria_report() ------------------------------------------------------------------

func test_criteria_report_has_exactly_three_entries_with_details() -> void:
	var report: Dictionary = _profile.criteria_report()
	assert_eq(report.size(), CRITERIA_COUNT)
	for key: String in [SnowpackProfile.CRITERION_DEPTH, SnowpackProfile.CRITERION_STRUCTURE,
			SnowpackProfile.CRITERION_PERSISTENCE]:
		assert_true(report.has(key), "report has %s" % key)
		var entry: Dictionary = report[key]
		assert_true(entry.has(SnowpackProfile.REPORT_PASSED), "%s has passed" % key)
		assert_true(entry.has(SnowpackProfile.REPORT_DETAIL), "%s has detail" % key)
		assert_gt(String(entry[SnowpackProfile.REPORT_DETAIL]).length(), 0,
				"%s detail is not empty" % key)

func test_criteria_report_flags_agree_with_criterion_functions_across_seeds() -> void:
	for seed_value: int in range(SEED_SWEEP_COUNT):
		var p: SnowpackProfile = SnowpackProfile.new()
		p.generate(seed_value)
		var report: Dictionary = p.criteria_report()
		var depth: Dictionary = report[SnowpackProfile.CRITERION_DEPTH]
		var structure: Dictionary = report[SnowpackProfile.CRITERION_STRUCTURE]
		var persistence: Dictionary = report[SnowpackProfile.CRITERION_PERSISTENCE]
		assert_eq(bool(depth[SnowpackProfile.REPORT_PASSED]), p.is_deep_enough(),
				"seed %d: depth flag agrees" % seed_value)
		assert_eq(bool(structure[SnowpackProfile.REPORT_PASSED]), p.has_supporting_structure(),
				"seed %d: structure flag agrees" % seed_value)
		assert_eq(bool(persistence[SnowpackProfile.REPORT_PASSED]),
				p.persists_past_denning_date(), "seed %d: persistence flag agrees" % seed_value)
		var all_pass: bool = bool(depth[SnowpackProfile.REPORT_PASSED]) \
				and bool(structure[SnowpackProfile.REPORT_PASSED]) \
				and bool(persistence[SnowpackProfile.REPORT_PASSED])
		assert_eq(p.evaluate() == SnowpackProfile.Verdict.VIABLE, all_pass,
				"seed %d: VIABLE exactly when every flag passes" % seed_value)

# --- names ---------------------------------------------------------------------------------

func test_hardness_codes_are_the_field_book_abbreviations() -> void:
	assert_eq(SnowpackProfile.hardness_code(SnowpackProfile.Hardness.FIST), "F")
	assert_eq(SnowpackProfile.hardness_code(SnowpackProfile.Hardness.FOUR_FINGER), "4F")
	assert_eq(SnowpackProfile.hardness_code(SnowpackProfile.Hardness.ONE_FINGER), "1F")
	assert_eq(SnowpackProfile.hardness_code(SnowpackProfile.Hardness.PENCIL), "P")
	assert_eq(SnowpackProfile.hardness_code(SnowpackProfile.Hardness.KNIFE), "K")

func test_hardness_scale_orders_soft_to_hard() -> void:
	assert_lt(SnowpackProfile.Hardness.FIST, SnowpackProfile.Hardness.FOUR_FINGER)
	assert_lt(SnowpackProfile.Hardness.FOUR_FINGER, SnowpackProfile.Hardness.ONE_FINGER)
	assert_lt(SnowpackProfile.Hardness.ONE_FINGER, SnowpackProfile.Hardness.PENCIL)
	assert_lt(SnowpackProfile.Hardness.PENCIL, SnowpackProfile.Hardness.KNIFE)
