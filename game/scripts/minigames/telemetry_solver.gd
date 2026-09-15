## Radio-telemetry model for the Signal Chase minigame (minigame-ideas Batch 2
## item 2): three fixed listening stations, a hand-held Yagi antenna, and a
## collared wolf somewhere in a FIELD_SIZE study area. Pure logic — no
## rendering, no scene tree, no autoloads — so the geometry and the antenna
## model are unit-testable in isolation. `TelemetryMinigame` renders it.
##
## The technique modelled is real ground triangulation: from each station the
## biologist sweeps a directional antenna, reads the receiver's signal-strength
## meter, and records the bearing of the strongest peak. Three bearings cross
## pairwise to give an error polygon; the tighter it is and the closer its
## centroid to the animal, the better the fix. The Yagi's broad main lobe,
## its weaker side lobes, and signal fall-off with distance are all in the
## model because each one produces a mistake a real field crew learns to avoid.
class_name TelemetrySolver
extends RefCounted

## Study area in metres; +x is east, +y is south (screen convention) so the
## plan view draws it directly. Bearings are still true compass bearings.
const FIELD_SIZE := Vector2(4000.0, 3000.0)
const STATION_COUNT := 3

# --- placement constraints (metres / degrees) --------------------------------
## Stations and the collar keep this far inside the field edge so nothing is
## drawn on the border.
const FIELD_MARGIN_M := 200.0
## Minimum distance between any two stations. Close stations give bearings
## that cross at shallow angles from everywhere, which is bad geometry rather
## than an interesting lesson.
const MIN_STATION_SEPARATION_M := 1200.0
## Minimum station-to-collar distance. Standing on top of the animal makes
## the bearing meaningless (and a real crew would just see it).
const MIN_STATION_TARGET_DISTANCE_M := 600.0
## Every pair of true bearing lines must cross at least this steeply, so the
## layout is never fully degenerate. Thin-but-legal geometry is still allowed
## on purpose — it is one of the things the minigame teaches.
const MIN_GEOMETRY_ANGLE_DEG := 10.0
## Rejection-sampling budget before falling back to FALLBACK_STATIONS.
const MAX_PLACEMENT_ATTEMPTS := 2000
## A known-good layout used only if rejection sampling exhausts its budget,
## so `generate()` can never return a degenerate field.
const FALLBACK_STATIONS: Array[Vector2] = [
	Vector2(600.0, 600.0), Vector2(3400.0, 700.0), Vector2(1900.0, 2500.0),
]
const FALLBACK_TARGET := Vector2(2100.0, 1500.0)

# --- antenna model -------------------------------------------------------------
## Main-lobe shape: `pow(cos(offset), MAIN_LOBE_SHARPNESS)`. 5.0 puts the
## half-power points at about ±30°, the beamwidth of a 3-element hand-held
## Yagi — broad enough that a peak bearing is honestly only good to a few
## degrees, which is why field crews bracket it.
const MAIN_LOBE_SHARPNESS := 5.0
## Relative strength of the side lobes, as a fraction of the main lobe. A real
## Yagi has side/back lobes 10-15 dB down; a crew that stops sweeping at the
## first bump it hears has taken a side-lobe bearing.
const SIDE_LOBE_FLOOR := 0.22
## Where the side lobes sit relative to the true bearing, one either side.
const SIDE_LOBE_ANGLE_DEG := 120.0
## How narrow the side lobes are (same `pow(cos)` shaping as the main lobe).
const SIDE_LOBE_SHARPNESS := 12.0
## Distance fall-off: `pow(REFERENCE_DISTANCE_M / d, ATTENUATION_EXPONENT)`,
## capped at 1.0 inside the reference distance. Field strength itself falls
## as 1/d, but a receiver's meter is gain-adjusted and roughly logarithmic,
## so the exponent is deliberately softer than 1 to keep the far station
## readable rather than pinned near zero.
const REFERENCE_DISTANCE_M := 600.0
const ATTENUATION_EXPONENT := 0.6
## Peak-to-peak meter noise (receiver hiss, hand wobble, terrain multipath).
## Small, but enough that the meter is flat for several degrees around the
## peak — which is the real reason a single reading is never trusted.
const NOISE_AMPLITUDE := 0.03
## Meter noise is quantised to this step of antenna angle so a reading is a
## pure function of (seed, station, angle) and never flickers with time.
const NOISE_ANGLE_STEP_DEG := 1.0

# --- fix quality -----------------------------------------------------------------
## Two bearing lines crossing shallower than this are treated as parallel and
## their intersection omitted, rather than dividing by a near-zero determinant
## and reporting a point kilometres off the map.
const MIN_INTERSECT_ANGLE_DEG := 3.0
## `error_metres` (centroid to collar) thresholds for the four bands. A wide
## fix is still a fix — the cozy pillar says it is explained, not failed.
const EXCELLENT_MAX_ERROR_M := 150.0
const GOOD_MAX_ERROR_M := 400.0
const LOOSE_MAX_ERROR_M := 900.0
const BAND_EXCELLENT := "excellent"
const BAND_GOOD := "good"
const BAND_LOOSE := "loose"
const BAND_WIDE := "wide"

# --- diagnosis ---------------------------------------------------------------------
## A bearing this far from the truth can only have come off a side or back
## lobe, not a misread main peak.
const SIDE_LOBE_ERROR_DEG := 60.0
## Bearings crossing shallower than this make a long thin polygon whatever
## the bearing quality — the stations were nearly in line with the animal.
const THIN_GEOMETRY_ANGLE_DEG := 25.0
## A main-lobe bearing worse than this is "off the peak" rather than clean.
const OFF_PEAK_ERROR_DEG := 6.0
const DIAG_CLEAN := "clean"
const DIAG_SIDE_LOBE := "side_lobe"
const DIAG_PARALLEL := "parallel"
const DIAG_THIN_GEOMETRY := "thin_geometry"
const DIAG_OFF_PEAK := "off_peak"

const FULL_CIRCLE_DEG := 360.0
const HALF_CIRCLE_DEG := 180.0

## Station positions in field metres. Read-only by convention; `generate()`
## owns them.
var stations: Array[Vector2] = []
## The collared wolf's true position in field metres. Read-only by convention.
var target := Vector2.ZERO
## The seed the current layout was generated from.
var seed_value: int = 0

# --- generation ------------------------------------------------------------------

## Lay out the field from `seed_value`: three stations at least
## MIN_STATION_SEPARATION_M apart and a collar at least
## MIN_STATION_TARGET_DISTANCE_M from every station, with every pair of true
## bearings crossing at MIN_GEOMETRY_ANGLE_DEG or steeper. Deterministic: the
## same seed always gives the same layout. Uses a local RNG only.
func generate(new_seed: int) -> void:
	seed_value = new_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = new_seed
	stations = []
	target = Vector2.ZERO
	for _attempt: int in range(MAX_PLACEMENT_ATTEMPTS):
		var candidate := _random_point(rng)
		if stations.size() < STATION_COUNT:
			if _far_from_all(candidate, stations, MIN_STATION_SEPARATION_M):
				stations.append(candidate)
			continue
		if not _far_from_all(candidate, stations, MIN_STATION_TARGET_DISTANCE_M):
			continue
		target = candidate
		if _min_pairwise_crossing_angle(_true_bearings()) >= MIN_GEOMETRY_ANGLE_DEG:
			return
		target = Vector2.ZERO
	# Budget exhausted (never observed in practice; here so the field can
	# never be degenerate).
	stations = []
	stations.assign(FALLBACK_STATIONS)
	target = FALLBACK_TARGET

# --- bearings --------------------------------------------------------------------

## The compass bearing from station `station_index` to the collar, in degrees:
## 0 = north, clockwise, normalised to [0, 360).
func true_bearing_from(station_index: int) -> float:
	return bearing_between(stations[station_index], target)

## Compass bearing from `from` to `to` in field coordinates (+y south), in
## degrees, normalised to [0, 360).
static func bearing_between(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return normalize_bearing(rad_to_deg(atan2(d.x, -d.y)))

## Wrap any angle in degrees into [0, 360).
static func normalize_bearing(deg: float) -> float:
	var wrapped := fmod(deg, FULL_CIRCLE_DEG)
	if wrapped < 0.0:
		wrapped += FULL_CIRCLE_DEG
	# fmod can hand back exactly 360.0 for tiny negative inputs.
	if wrapped >= FULL_CIRCLE_DEG:
		wrapped -= FULL_CIRCLE_DEG
	return wrapped

## Signed difference `a - b` in degrees, wrapped to (-180, 180].
static func bearing_difference(a: float, b: float) -> float:
	var diff := fmod(a - b + HALF_CIRCLE_DEG, FULL_CIRCLE_DEG)
	if diff < 0.0:
		diff += FULL_CIRCLE_DEG
	return diff - HALF_CIRCLE_DEG

## Unit vector for a compass bearing in field coordinates (north is -y).
static func bearing_vector(deg: float) -> Vector2:
	var rad := deg_to_rad(deg)
	return Vector2(sin(rad), -cos(rad))

# --- antenna model ----------------------------------------------------------------

## The receiver's meter reading, 0..1, with the antenna at station
## `station_index` pointed at `antenna_deg`. Main lobe plus two side lobes,
## attenuated by distance, plus noise that is a pure function of
## (seed, station, angle to 1°) — the same inputs always give the same reading.
func signal_strength(station_index: int, antenna_deg: float) -> float:
	var offset := bearing_difference(antenna_deg, true_bearing_from(station_index))
	var pattern := antenna_pattern(offset)
	var distance := stations[station_index].distance_to(target)
	var reading := pattern * distance_attenuation(distance) \
			+ _noise(station_index, antenna_deg)
	return clampf(reading, 0.0, 1.0)

## The Yagi's gain pattern, 0..1, at `offset_deg` from its boresight: a
## `pow(cos)` main lobe plus SIDE_LOBE_FLOOR-scaled lobes at
## ±SIDE_LOBE_ANGLE_DEG. Symmetric about zero.
static func antenna_pattern(offset_deg: float) -> float:
	var main_lobe := _lobe(offset_deg, MAIN_LOBE_SHARPNESS)
	var side_lobes := SIDE_LOBE_FLOOR * (
			_lobe(offset_deg - SIDE_LOBE_ANGLE_DEG, SIDE_LOBE_SHARPNESS)
			+ _lobe(offset_deg + SIDE_LOBE_ANGLE_DEG, SIDE_LOBE_SHARPNESS))
	return clampf(main_lobe + side_lobes, 0.0, 1.0)

## Distance fall-off factor, 1.0 inside REFERENCE_DISTANCE_M and decreasing
## as `pow(REFERENCE_DISTANCE_M / distance, ATTENUATION_EXPONENT)` beyond it.
static func distance_attenuation(distance_m: float) -> float:
	if distance_m <= REFERENCE_DISTANCE_M:
		return 1.0
	return pow(REFERENCE_DISTANCE_M / distance_m, ATTENUATION_EXPONENT)

# --- the fix -------------------------------------------------------------------------

## Triangulate from one committed bearing per station. Returns:
##   "intersections": Array[Vector2] — pairwise bearing-line crossings, in
##       field metres, one per station pair that crosses steeply enough;
##   "omitted_pairs": Array — [i, j] station pairs whose lines were within
##       MIN_INTERSECT_ANGLE_DEG of parallel and so contributed no point;
##   "centroid": Vector2 — mean of the intersections (mean of the stations
##       when every pair was omitted, so the result is always finite);
##   "polygon_area": float — area of the error triangle in m², 0.0 when
##       fewer than three intersections exist;
##   "error_metres": float — centroid-to-collar distance;
##   "band": String — one of the BAND_* constants by error_metres.
## Lines, not rays: a bearing taken off a back lobe crosses behind the
## station, and that wrong point belongs in the polygon the player sees.
func fix_from_bearings(bearings: Array[float]) -> Dictionary:
	var intersections: Array[Vector2] = []
	var omitted_pairs: Array = []
	for i: int in range(STATION_COUNT):
		for j: int in range(i + 1, STATION_COUNT):
			var crossing_angle := absf(bearing_difference(bearings[i], bearings[j]))
			crossing_angle = minf(crossing_angle, HALF_CIRCLE_DEG - crossing_angle)
			if crossing_angle < MIN_INTERSECT_ANGLE_DEG:
				omitted_pairs.append([i, j])
				continue
			intersections.append(_intersect_lines(
					stations[i], bearing_vector(bearings[i]),
					stations[j], bearing_vector(bearings[j])))
	var centroid := Vector2.ZERO
	if intersections.is_empty():
		for s: Vector2 in stations:
			centroid += s
		centroid /= float(stations.size())
	else:
		for p: Vector2 in intersections:
			centroid += p
		centroid /= float(intersections.size())
	var area := 0.0
	if intersections.size() == STATION_COUNT:
		area = absf((intersections[1] - intersections[0]).cross(
				intersections[2] - intersections[0])) * 0.5
	var error_metres := centroid.distance_to(target)
	return {
		"intersections": intersections,
		"omitted_pairs": omitted_pairs,
		"centroid": centroid,
		"polygon_area": area,
		"error_metres": error_metres,
		"band": band_for_error(error_metres),
	}

## The quality band for a centroid error in metres.
static func band_for_error(error_metres: float) -> String:
	if error_metres <= EXCELLENT_MAX_ERROR_M:
		return BAND_EXCELLENT
	if error_metres <= GOOD_MAX_ERROR_M:
		return BAND_GOOD
	if error_metres <= LOOSE_MAX_ERROR_M:
		return BAND_LOOSE
	return BAND_WIDE

## Signed error of a committed bearing against the truth for that station,
## in degrees, wrapped to (-180, 180].
func bearing_error_deg(station_index: int, bearing: float) -> float:
	return bearing_difference(bearing, true_bearing_from(station_index))

## Why the fix came out the way it did — one of the DIAG_* keys, most
## instructive cause first: a side-lobe bearing, a near-parallel pair, thin
## station geometry, bearings off the peak, or clean. The UI turns the key
## into the naturalist's note; keeping the rule here keeps it testable.
func diagnose(bearings: Array[float], fix: Dictionary) -> String:
	var worst_error := 0.0
	for i: int in range(STATION_COUNT):
		worst_error = maxf(worst_error, absf(bearing_error_deg(i, bearings[i])))
	if worst_error >= SIDE_LOBE_ERROR_DEG:
		return DIAG_SIDE_LOBE
	var omitted: Array = fix.get("omitted_pairs", [])
	if not omitted.is_empty():
		return DIAG_PARALLEL
	if _min_pairwise_crossing_angle(_true_bearings()) < THIN_GEOMETRY_ANGLE_DEG:
		return DIAG_THIN_GEOMETRY
	if worst_error >= OFF_PEAK_ERROR_DEG:
		return DIAG_OFF_PEAK
	return DIAG_CLEAN

# --- internals -------------------------------------------------------------------------

func _random_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
			rng.randf_range(FIELD_MARGIN_M, FIELD_SIZE.x - FIELD_MARGIN_M),
			rng.randf_range(FIELD_MARGIN_M, FIELD_SIZE.y - FIELD_MARGIN_M))

static func _far_from_all(p: Vector2, others: Array[Vector2], min_distance: float) -> bool:
	for o: Vector2 in others:
		if p.distance_to(o) < min_distance:
			return false
	return true

func _true_bearings() -> Array[float]:
	var out: Array[float] = []
	for i: int in range(stations.size()):
		out.append(true_bearing_from(i))
	return out

## Smallest angle (0..90) at which any two of `bearings` cross as lines.
static func _min_pairwise_crossing_angle(bearings: Array[float]) -> float:
	var smallest := HALF_CIRCLE_DEG
	for i: int in range(bearings.size()):
		for j: int in range(i + 1, bearings.size()):
			var a := absf(bearing_difference(bearings[i], bearings[j]))
			smallest = minf(smallest, minf(a, HALF_CIRCLE_DEG - a))
	return smallest

## `pow(cos(offset), sharpness)` clamped at zero — the back half of the
## pattern contributes nothing rather than going negative or, for odd
## exponents, reflecting.
static func _lobe(offset_deg: float, sharpness: float) -> float:
	var c := cos(deg_to_rad(offset_deg))
	if c <= 0.0:
		return 0.0
	return pow(c, sharpness)

## Deterministic meter noise in [-NOISE_AMPLITUDE, NOISE_AMPLITUDE] from a
## throwaway RNG seeded by (seed, station, quantised angle). No shared stream,
## no clock.
func _noise(station_index: int, antenna_deg: float) -> float:
	var angle_step := int(roundf(normalize_bearing(antenna_deg) / NOISE_ANGLE_STEP_DEG))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed_value, station_index, angle_step))
	return rng.randf_range(-NOISE_AMPLITUDE, NOISE_AMPLITUDE)

## Intersection of the lines p1 + t*d1 and p2 + u*d2. Callers have already
## rejected near-parallel pairs, so the determinant is safely non-zero.
static func _intersect_lines(p1: Vector2, d1: Vector2, p2: Vector2, d2: Vector2) -> Vector2:
	var denom := d1.cross(d2)
	var t := (p2 - p1).cross(d2) / denom
	return p1 + d1 * t
