## Snowpack model for the Snowpack Survey minigame (minigame-ideas Batch 2
## item 5): a snow pit at a candidate wolverine natal-den site, described as
## an ordered stack of layers from the surface down to the ground, and the
## three denning criteria that decide whether the site will hold a den. Pure
## logic — no rendering, no scene tree, no autoloads — so the generator and
## the verdict are unit-testable in isolation. `SnowpackMinigame` renders it.
##
## The vocabulary is the real one. Hand hardness is the international
## five-step field scale (fist, four fingers, one finger, pencil, knife);
## grain types are the IACS classes a snow scientist writes in a pit profile.
## The denning logic encodes what is known about wolverine natal dens: they
## are tunnels and cavities dug in deep snow, they need a weak (faceted or
## depth-hoar) horizon to excavate under a roof that holds its own weight,
## and above all the snow has to still be there when the kits are — which
## is why spring snow persistence, not winter depth, is the limiting factor.
## A melt-freeze signature high in the pack in spring is the site telling
## you it is already going.
class_name SnowpackProfile
extends RefCounted

## Hand hardness, softest to hardest — the ordering is what makes
## `Hardness.PENCIL >= SUPPORT_MIN_HARDNESS` meaningful.
enum Hardness { FIST, FOUR_FINGER, ONE_FINGER, PENCIL, KNIFE }
## Grain type (IACS main classes, restricted to the ones that matter here).
enum Grain { NEW_SNOW, ROUNDED, FACETED, DEPTH_HOAR, MELT_FREEZE_CRUST, ICE_LENS }
enum Verdict { VIABLE, MARGINAL, NOT_VIABLE }

# --- layer dictionary keys ----------------------------------------------------
const KEY_THICKNESS_CM := "thickness_cm"
const KEY_HARDNESS := "hardness"
const KEY_GRAIN := "grain"
const KEY_DENSITY := "density_kg_m3"

# --- criteria keys in `criteria_report()` ---------------------------------------
const CRITERION_DEPTH := "depth"
const CRITERION_STRUCTURE := "structure"
const CRITERION_PERSISTENCE := "persistence"
const REPORT_PASSED := "passed"
const REPORT_DETAIL := "detail"

# --- denning thresholds ---------------------------------------------------------
## Minimum total snow depth for a natal den. Wolverine dens are excavated
## tunnels, commonly reported in snow 1 m deep and more, so a metre is the
## floor rather than the typical value. NEEDS A LITERATURE CHECK: the exact
## floor varies by study and by how the depth was measured.
const DEN_MIN_DEPTH_CM := 100.0
## The roof: a layer at least this hard, and at least this thick, above the
## cavity horizon. Pencil is the softest hand hardness that behaves as a
## slab rather than crumbling. NEEDS A LITERATURE CHECK: the thickness is a
## structural judgement, not a published wolverine figure.
const SUPPORT_MIN_HARDNESS := Hardness.PENCIL
const SUPPORT_MIN_THICKNESS_CM := 10.0
## The cavity horizon: a faceted or depth-hoar layer at least this thick,
## so a tunnel and chamber can be dug out of it under the roof. NEEDS A
## LITERATURE CHECK, same caveat as the roof thickness.
const CAVITY_MIN_THICKNESS_CM := 30.0
## The persistence date, as "MM-DD". Wolverine range tracks snow cover that
## lasts through the denning period, conventionally taken as 15 May
## (Copeland et al. 2010, the "bioclimatic envelope" analysis). A profile
## surveyed on or after this date that still has cold, unmelted snow has
## demonstrated persistence; one surveyed earlier has not yet.
const DENNING_DATE_THRESHOLD := "05-15"
## A melt-freeze crust or ice lens within this depth of the surface is a
## spring melt signature: the pack is cycling through melt and refreeze
## from the top and is on its way out. NEEDS A LITERATURE CHECK: the depth
## is a defensible field heuristic, not a published number.
const MELT_SIGNATURE_DEPTH_CM := 30.0

# --- generator ------------------------------------------------------------------
## The year every generated survey date carries. The site owns its own date;
## there is no calendar system to borrow one from.
const SURVEY_YEAR := 2026
const DATE_MONTH_DAY_OFFSET := 5   # "YYYY-" is five characters
const ISO_DATE_LENGTH := 10
## The scenario families the generator draws from.
enum Scenario { DEEP_SUPPORTIVE, DEEP_MELTING_EARLY, SHALLOW_COLD, THIN_ICE_LENS, DEEP_NO_STRUCTURE }
## Relative draw weights per family. Three of the five families resolve
## MARGINAL, so an even draw would teach "always call it marginal"; these
## weights land the verdicts near one quarter viable, one half marginal,
## one quarter not viable across many seeds.
const SCENARIO_WEIGHTS := {
	Scenario.DEEP_SUPPORTIVE: 0.36,
	Scenario.DEEP_MELTING_EARLY: 0.15,
	Scenario.SHALLOW_COLD: 0.24,
	Scenario.THIN_ICE_LENS: 0.12,
	Scenario.DEEP_NO_STRUCTURE: 0.13,
}
## Survey-date windows, day-of-year style, expressed as (month, day) bounds.
const EARLY_SURVEY_MONTH := 4
const LATE_SURVEY_MONTH := 5
const LATE_SURVEY_MIN_DAY := 15
const SURVEY_MAX_DAY := 28
const SURVEY_MIN_DAY := 1
## Odds that a deep-and-supportive profile is surveyed before the persistence
## date, so the same structure can honestly come back MARGINAL.
const EARLY_SURVEY_CHANCE := 0.3
## Layer-thickness ranges (cm) per role in each scenario.
const SURFACE_NEW_SNOW_MIN_CM := 5.0
const SURFACE_NEW_SNOW_MAX_CM := 20.0
const ROUNDED_LAYER_MIN_CM := 15.0
const ROUNDED_LAYER_MAX_CM := 45.0
const SLAB_MIN_CM := 12.0
const SLAB_MAX_CM := 35.0
const CAVITY_MIN_CM := 35.0
const CAVITY_MAX_CM := 90.0
const SHALLOW_FACET_MIN_CM := 10.0
const SHALLOW_FACET_MAX_CM := 25.0
const SHALLOW_HOAR_MIN_CM := 10.0
const SHALLOW_HOAR_MAX_CM := 30.0
const CRUST_MIN_CM := 2.0
const CRUST_MAX_CM := 6.0
const THIN_LENS_MIN_CM := 0.5
const THIN_LENS_MAX_CM := 3.0
const BASAL_MIN_CM := 10.0
const BASAL_MAX_CM := 30.0
## Density ranges (kg/m³) by grain type — the usual field ranges.
const DENSITY_RANGES := {
	Grain.NEW_SNOW: [50.0, 150.0],
	Grain.ROUNDED: [200.0, 350.0],
	Grain.FACETED: [200.0, 300.0],
	Grain.DEPTH_HOAR: [200.0, 320.0],
	Grain.MELT_FREEZE_CRUST: [350.0, 550.0],
	Grain.ICE_LENS: [700.0, 900.0],
}

## Surface down to ground; each entry is
## `{thickness_cm: float, hardness: Hardness, grain: Grain, density_kg_m3: float}`.
var layers: Array[Dictionary] = []
## ISO date ("YYYY-MM-DD") of the survey. Owned by the site.
var survey_date: String = ""
## The seed the current profile was generated from (0 until `generate()`).
var seed_value: int = 0
## Which scenario family the generator drew, for logs and tests.
var scenario: Scenario = Scenario.DEEP_SUPPORTIVE

# --- generation -----------------------------------------------------------------

## Build a fresh profile from `seed_value` using a local RNG, so the same
## seed always yields the same pit. Draws one of the `Scenario` families so
## the interesting cases — deep and supportive, deep but melting early,
## shallow but cold, a thin ice lens that looks like a roof and is not — all
## turn up, and so all three verdicts are reachable.
func generate(seed_value_in: int) -> void:
	seed_value = seed_value_in
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value_in
	layers = []
	scenario = _pick_scenario(rng)
	match scenario:
		Scenario.DEEP_SUPPORTIVE:
			_add_layer(rng, Grain.NEW_SNOW, Hardness.FIST, SURFACE_NEW_SNOW_MIN_CM, SURFACE_NEW_SNOW_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.FOUR_FINGER, ROUNDED_LAYER_MIN_CM, ROUNDED_LAYER_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, _pick(rng, [Hardness.PENCIL, Hardness.ONE_FINGER]),
					SLAB_MIN_CM, SLAB_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.PENCIL, SLAB_MIN_CM, SLAB_MAX_CM)
			_add_layer(rng, Grain.FACETED, Hardness.FOUR_FINGER, SHALLOW_FACET_MIN_CM, SHALLOW_FACET_MAX_CM)
			_add_layer(rng, Grain.DEPTH_HOAR, Hardness.FIST, CAVITY_MIN_CM, CAVITY_MAX_CM)
			survey_date = _random_date(rng, rng.randf() >= EARLY_SURVEY_CHANCE)
		Scenario.DEEP_MELTING_EARLY:
			_add_layer(rng, Grain.MELT_FREEZE_CRUST, Hardness.KNIFE, CRUST_MIN_CM, CRUST_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.ONE_FINGER, SURFACE_NEW_SNOW_MIN_CM, SURFACE_NEW_SNOW_MAX_CM)
			_add_layer(rng, Grain.MELT_FREEZE_CRUST, Hardness.KNIFE, CRUST_MIN_CM, CRUST_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.PENCIL, SLAB_MIN_CM, SLAB_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.PENCIL, ROUNDED_LAYER_MIN_CM, ROUNDED_LAYER_MAX_CM)
			_add_layer(rng, Grain.DEPTH_HOAR, Hardness.FIST, CAVITY_MIN_CM, CAVITY_MAX_CM)
			survey_date = _random_date(rng, true)
		Scenario.SHALLOW_COLD:
			_add_layer(rng, Grain.NEW_SNOW, Hardness.FIST, SURFACE_NEW_SNOW_MIN_CM, SURFACE_NEW_SNOW_MAX_CM)
			_add_layer(rng, Grain.FACETED, Hardness.FOUR_FINGER, SHALLOW_FACET_MIN_CM, SHALLOW_FACET_MAX_CM)
			_add_layer(rng, Grain.DEPTH_HOAR, Hardness.FIST, SHALLOW_HOAR_MIN_CM, SHALLOW_HOAR_MAX_CM)
			survey_date = _random_date(rng, rng.randf() >= EARLY_SURVEY_CHANCE)
		Scenario.THIN_ICE_LENS:
			_add_layer(rng, Grain.NEW_SNOW, Hardness.FIST, SURFACE_NEW_SNOW_MIN_CM, SURFACE_NEW_SNOW_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.FOUR_FINGER, ROUNDED_LAYER_MIN_CM, ROUNDED_LAYER_MAX_CM)
			_add_layer(rng, Grain.FACETED, Hardness.FOUR_FINGER, SHALLOW_FACET_MIN_CM, SHALLOW_FACET_MAX_CM)
			# A buried rain-on-snow lens: knife hard, and far too thin to be a roof.
			_add_layer(rng, Grain.ICE_LENS, Hardness.KNIFE, THIN_LENS_MIN_CM, THIN_LENS_MAX_CM)
			_add_layer(rng, Grain.DEPTH_HOAR, Hardness.FIST, CAVITY_MIN_CM, CAVITY_MAX_CM)
			_add_layer(rng, Grain.DEPTH_HOAR, Hardness.FOUR_FINGER, BASAL_MIN_CM, BASAL_MAX_CM)
			survey_date = _random_date(rng, true)
		Scenario.DEEP_NO_STRUCTURE:
			# Deep, cold, well-bonded rounded snow all the way down: a fine
			# snowpack with nothing soft enough to tunnel through.
			_add_layer(rng, Grain.NEW_SNOW, Hardness.FIST, SURFACE_NEW_SNOW_MIN_CM, SURFACE_NEW_SNOW_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.ONE_FINGER, ROUNDED_LAYER_MIN_CM, ROUNDED_LAYER_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.PENCIL, ROUNDED_LAYER_MIN_CM, ROUNDED_LAYER_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.PENCIL, ROUNDED_LAYER_MIN_CM, ROUNDED_LAYER_MAX_CM)
			_add_layer(rng, Grain.ROUNDED, Hardness.ONE_FINGER, ROUNDED_LAYER_MIN_CM, ROUNDED_LAYER_MAX_CM)
			survey_date = _random_date(rng, true)

# --- measurements ----------------------------------------------------------------

## Sum of all layer thicknesses, cm.
func total_depth_cm() -> float:
	var total := 0.0
	for layer: Dictionary in layers:
		total += float(layer[KEY_THICKNESS_CM])
	return total

## Depth from the surface to the top of `layers[index]`, cm.
func depth_to_layer_top_cm(index: int) -> float:
	var depth := 0.0
	for i: int in range(mini(index, layers.size())):
		depth += float(layers[i][KEY_THICKNESS_CM])
	return depth

## Index of the layer containing `depth_cm` below the surface, or -1 if the
## depth is outside the pack.
func layer_index_at_depth(depth_cm: float) -> int:
	if depth_cm < 0.0:
		return -1
	var top := 0.0
	for i: int in range(layers.size()):
		var bottom := top + float(layers[i][KEY_THICKNESS_CM])
		if depth_cm < bottom:
			return i
		top = bottom
	return -1

# --- criteria ----------------------------------------------------------------------

## Depth criterion: at least DEN_MIN_DEPTH_CM of snow.
func is_deep_enough() -> bool:
	return total_depth_cm() >= DEN_MIN_DEPTH_CM

## Structure criterion: a roof over a cavity horizon. True when some layer at
## or above SUPPORT_MIN_HARDNESS and at least SUPPORT_MIN_THICKNESS_CM thick
## sits anywhere above a FACETED or DEPTH_HOAR layer at least
## CAVITY_MIN_THICKNESS_CM thick. Order matters: the slab has to be on top.
func has_supporting_structure() -> bool:
	return _supporting_slab_index() >= 0

## Persistence criterion: the survey date is on or after
## DENNING_DATE_THRESHOLD and the pack shows no early-melt signature.
func persists_past_denning_date() -> bool:
	return _is_on_or_after_threshold(survey_date) and not has_melt_signature()

## True when a MELT_FREEZE_CRUST or ICE_LENS begins within
## MELT_SIGNATURE_DEPTH_CM of the surface.
func has_melt_signature() -> bool:
	return _melt_signature_index() >= 0

## VIABLE when all three criteria hold; NOT_VIABLE when depth alone fails;
## MARGINAL otherwise. Shallow snow is disqualifying by itself — there is
## nothing to dig — while a deep pack with a structural or persistence
## problem is a site worth watching rather than writing off.
func evaluate() -> Verdict:
	var deep := is_deep_enough()
	var structure := has_supporting_structure()
	var persists := persists_past_denning_date()
	if deep and structure and persists:
		return Verdict.VIABLE
	if not deep:
		return Verdict.NOT_VIABLE
	return Verdict.MARGINAL

## The three criteria as `{passed: bool, detail: String}` keyed by
## CRITERION_DEPTH / CRITERION_STRUCTURE / CRITERION_PERSISTENCE, so the UI
## can explain the verdict without re-deriving it. `passed` is read from the
## same functions `evaluate()` uses.
func criteria_report() -> Dictionary:
	return {
		CRITERION_DEPTH: {
			REPORT_PASSED: is_deep_enough(),
			REPORT_DETAIL: _depth_detail(),
		},
		CRITERION_STRUCTURE: {
			REPORT_PASSED: has_supporting_structure(),
			REPORT_DETAIL: _structure_detail(),
		},
		CRITERION_PERSISTENCE: {
			REPORT_PASSED: persists_past_denning_date(),
			REPORT_DETAIL: _persistence_detail(),
		},
	}

# --- names --------------------------------------------------------------------------

## Field-book abbreviation for a hand hardness: F, 4F, 1F, P, K.
static func hardness_code(hardness: Hardness) -> String:
	match hardness:
		Hardness.FIST: return "F"
		Hardness.FOUR_FINGER: return "4F"
		Hardness.ONE_FINGER: return "1F"
		Hardness.PENCIL: return "P"
		Hardness.KNIFE: return "K"
	return "?"

## Plain-language hand hardness.
static func hardness_name(hardness: Hardness) -> String:
	match hardness:
		Hardness.FIST: return "fist"
		Hardness.FOUR_FINGER: return "four fingers"
		Hardness.ONE_FINGER: return "one finger"
		Hardness.PENCIL: return "pencil"
		Hardness.KNIFE: return "knife"
	return "unknown"

## Plain-language grain type.
static func grain_name(grain: Grain) -> String:
	match grain:
		Grain.NEW_SNOW: return "new snow"
		Grain.ROUNDED: return "rounded grains"
		Grain.FACETED: return "faceted grains"
		Grain.DEPTH_HOAR: return "depth hoar"
		Grain.MELT_FREEZE_CRUST: return "melt-freeze crust"
		Grain.ICE_LENS: return "ice lens"
	return "unknown"

## Plain-language verdict.
static func verdict_name(verdict: Verdict) -> String:
	match verdict:
		Verdict.VIABLE: return "Viable"
		Verdict.MARGINAL: return "Marginal"
		Verdict.NOT_VIABLE: return "Not viable"
	return "Unknown"

## True for the weak horizons a den can be dug out of.
static func is_cavity_grain(grain: Grain) -> bool:
	return grain == Grain.FACETED or grain == Grain.DEPTH_HOAR

## True for the grain types that mark melt-freeze cycling.
static func is_melt_grain(grain: Grain) -> bool:
	return grain == Grain.MELT_FREEZE_CRUST or grain == Grain.ICE_LENS

# --- internals ------------------------------------------------------------------------

func _add_layer(rng: RandomNumberGenerator, grain: Grain, hardness: Hardness,
		min_cm: float, max_cm: float) -> void:
	var range_kg: Array = DENSITY_RANGES[grain]
	layers.append({
		KEY_THICKNESS_CM: snappedf(rng.randf_range(min_cm, max_cm), 0.5),
		KEY_HARDNESS: hardness,
		KEY_GRAIN: grain,
		KEY_DENSITY: roundf(rng.randf_range(float(range_kg[0]), float(range_kg[1]))),
	})

## Weighted draw over SCENARIO_WEIGHTS. Falls through to the last family
## only if floating-point rounding leaves the roll past every threshold.
func _pick_scenario(rng: RandomNumberGenerator) -> Scenario:
	var total := 0.0
	for weight: float in SCENARIO_WEIGHTS.values():
		total += weight
	var roll := rng.randf() * total
	var last: Scenario = Scenario.DEEP_SUPPORTIVE
	for key: Scenario in SCENARIO_WEIGHTS.keys():
		last = key
		roll -= float(SCENARIO_WEIGHTS[key])
		if roll < 0.0:
			return key
	return last

func _pick(rng: RandomNumberGenerator, options: Array) -> Hardness:
	return options[rng.randi_range(0, options.size() - 1)] as Hardness

## A survey date in SURVEY_YEAR: on or after the persistence threshold when
## `late` is true, otherwise somewhere in April.
func _random_date(rng: RandomNumberGenerator, late: bool) -> String:
	var month := LATE_SURVEY_MONTH if late else EARLY_SURVEY_MONTH
	var day := rng.randi_range(LATE_SURVEY_MIN_DAY if late else SURVEY_MIN_DAY, SURVEY_MAX_DAY)
	return "%04d-%02d-%02d" % [SURVEY_YEAR, month, day]

## Index of the first slab that satisfies the structure criterion, or -1.
func _supporting_slab_index() -> int:
	for i: int in range(layers.size()):
		var slab: Dictionary = layers[i]
		if int(slab[KEY_HARDNESS]) < SUPPORT_MIN_HARDNESS:
			continue
		if float(slab[KEY_THICKNESS_CM]) < SUPPORT_MIN_THICKNESS_CM:
			continue
		for j: int in range(i + 1, layers.size()):
			var below: Dictionary = layers[j]
			if is_cavity_grain(below[KEY_GRAIN]) \
					and float(below[KEY_THICKNESS_CM]) >= CAVITY_MIN_THICKNESS_CM:
				return i
	return -1

## Index of the first melt-form layer starting within MELT_SIGNATURE_DEPTH_CM
## of the surface, or -1.
func _melt_signature_index() -> int:
	var top := 0.0
	for i: int in range(layers.size()):
		if top > MELT_SIGNATURE_DEPTH_CM:
			break
		if is_melt_grain(layers[i][KEY_GRAIN]):
			return i
		top += float(layers[i][KEY_THICKNESS_CM])
	return -1

## Compare the "MM-DD" part of an ISO date against DENNING_DATE_THRESHOLD.
## A malformed date never counts as persisting.
static func _is_on_or_after_threshold(iso_date: String) -> bool:
	if iso_date.length() != ISO_DATE_LENGTH:
		return false
	return iso_date.substr(DATE_MONTH_DAY_OFFSET) >= DENNING_DATE_THRESHOLD

func _depth_detail() -> String:
	var depth := total_depth_cm()
	if depth >= DEN_MIN_DEPTH_CM:
		return "%.0f cm of snow — at least %.0f cm is needed to dig a den." \
				% [depth, DEN_MIN_DEPTH_CM]
	return "Only %.0f cm of snow — a den needs at least %.0f cm." % [depth, DEN_MIN_DEPTH_CM]

func _structure_detail() -> String:
	var slab_index := _supporting_slab_index()
	if slab_index >= 0:
		var slab: Dictionary = layers[slab_index]
		return "A %.0f cm %s-hard %s layer roofs a %s horizon deep enough to tunnel." % [
			float(slab[KEY_THICKNESS_CM]), hardness_name(slab[KEY_HARDNESS]),
			grain_name(slab[KEY_GRAIN]), _cavity_name_below(slab_index)]
	var has_cavity := false
	for layer: Dictionary in layers:
		if is_cavity_grain(layer[KEY_GRAIN]) \
				and float(layer[KEY_THICKNESS_CM]) >= CAVITY_MIN_THICKNESS_CM:
			has_cavity = true
	if has_cavity:
		return "There is a weak horizon to dig in, but nothing pencil-hard and at least " \
				+ "%.0f cm thick above it to hold a roof." % SUPPORT_MIN_THICKNESS_CM
	return "No faceted or depth-hoar horizon of %.0f cm or more to tunnel through." \
			% CAVITY_MIN_THICKNESS_CM

func _cavity_name_below(slab_index: int) -> String:
	for j: int in range(slab_index + 1, layers.size()):
		var below: Dictionary = layers[j]
		if is_cavity_grain(below[KEY_GRAIN]) \
				and float(below[KEY_THICKNESS_CM]) >= CAVITY_MIN_THICKNESS_CM:
			return grain_name(below[KEY_GRAIN])
	return "weak"

func _persistence_detail() -> String:
	var melt_index := _melt_signature_index()
	if melt_index >= 0:
		return "A %s at %.0f cm below the surface on %s — the pack is melting from the top." \
				% [grain_name(layers[melt_index][KEY_GRAIN]),
				depth_to_layer_top_cm(melt_index), survey_date]
	if not _is_on_or_after_threshold(survey_date):
		return "Surveyed %s, before the %s persistence date — cold now, but not yet " \
				% [survey_date, _threshold_label()] + "shown to last."
	return "Cold, unmelted snow on %s, past the %s persistence date." \
			% [survey_date, _threshold_label()]

func _threshold_label() -> String:
	return "%04d-%s" % [SURVEY_YEAR, DENNING_DATE_THRESHOLD]
