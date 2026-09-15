## Signal Chase: the radio-telemetry minigame overlay (minigame-ideas Batch 2
## item 2). The player is a field biologist locating a collared gray wolf from
## three fixed listening stations — rotate the Yagi, watch the meter, commit a
## bearing, move to the next station. Three bearings give an error polygon;
## then the truth is revealed and explained. All maths lives in
## `TelemetrySolver`; this script only draws and handles input.
##
## Drawn entirely with `_draw()` primitives and Labels — no scene, art or
## font — following the code-built pattern of `CreditsScreen` and `Hud`.
## Opened by `Main` on TELEMETRY_KEY onto its own CanvasLayer; `Main` treats
## it as modal while `is_open` so nothing leaks into build-mode keys.
class_name TelemetryMinigame
extends BaseScreen

signal closed()
signal fix_completed(band: String, error_metres: float)

# --- tuning ---------------------------------------------------------------------------
## Antenna rotation speed when a direction key is first held, and after
## ROTATE_ACCEL_SECONDS of holding it.
@export var rotate_base_deg_per_sec := 30.0
@export var rotate_max_deg_per_sec := 120.0
@export var rotate_accel_seconds := 1.2
## Shift + direction nudges by this much per press (no auto-repeat).
@export var fine_step_deg := 0.5

# --- palette (art-direction §2) ---------------------------------------------------------
const PARCHMENT := Color("#F3EAD8")
const FOREST_DEEP := Color("#2E4A36")
const FOREST_MID := Color("#4C7A4A")
const ALPINE_ROCK := Color("#8A8E97")
const EARTH := Color("#7A5A3A")
const TEAL := Color("#2E8B8B")
const GOLD := Color("#D8A93C")
const LOCKED_GREY := Color("#6B6E73")
## The orange→teal data axis: the meter fill means "weak/fragmented" to
## "strong/connected", the same thing the ramp means on the connectivity
## overlay.
const DATA_AXIS: Array[Color] = [
	Color("#E08A3C"), Color("#D9A85C"), Color("#8FB07A"), Color("#2E8B8B"),
]
const BACKDROP_COLOR := Color(0.05, 0.08, 0.06, 0.94)
const POLYGON_FILL := Color("#2E8B8B", 0.25)

# --- layout --------------------------------------------------------------------------------
const PANEL_MARGIN := 32.0
const COLUMN_GAP := 24.0
const PLAN_STRETCH := 0.62
const SIDEBAR_STRETCH := 0.38
const SIDEBAR_SEPARATION := 10
const METER_HEIGHT := 26.0
const METER_BORDER := 2.0
const TITLE_FONT_SIZE := 24
const BODY_FONT_SIZE := 14
const PLAN_BORDER_WIDTH := 3.0
const PLAN_PADDING := 24.0
const STATION_RADIUS := 7.0
const ACTIVE_RING_RADIUS := 12.0
const ACTIVE_RING_WIDTH := 2.0
const INTERSECTION_RADIUS := 4.0
const CENTROID_CROSS_HALF := 8.0
const COLLAR_RADIUS := 6.0
const COLLAR_RING_RADIUS := 10.0
const LINE_WIDTH := 2.0
const ANTENNA_RAY_WIDTH := 2.5
const MARKER_LABEL_OFFSET := Vector2(10.0, -10.0)
const LABEL_FONT_SIZE := 13
const SQUARE_METRES_PER_HECTARE := 10000.0

const TITLE_TEXT := "Signal Chase — radio telemetry"
const INTRO_TEXT := "A gray wolf wears a VHF collar somewhere in this valley. " \
		+ "From each of three listening stations, swing the Yagi until the " \
		+ "meter peaks and commit a bearing. Three bearings make a fix."
const CONTROLS_TEXT := "A/D or ←/→ rotate (hold to speed up) · Shift for 0.5° steps · " \
		+ "Enter/Space commit bearing · R new wolf · Esc close"
const BAND_HEADLINES := {
	TelemetrySolver.BAND_EXCELLENT: "Excellent fix",
	TelemetrySolver.BAND_GOOD: "Good fix",
	TelemetrySolver.BAND_LOOSE: "Loose fix",
	TelemetrySolver.BAND_WIDE: "Wide fix",
}
## The naturalist's note, keyed by `TelemetrySolver.diagnose()`. Every entry
## explains; none of them scolds — a wide fix is a lesson, not a loss.
const NATURALIST_NOTES := {
	TelemetrySolver.DIAG_SIDE_LOBE:
		"One bearing came off a side lobe: a Yagi hears a weaker second peak " \
		+ "well away from the true direction, and a single bad bearing throws " \
		+ "the whole polygon. Field crews sweep the full circle and trust only " \
		+ "the strongest peak.",
	TelemetrySolver.DIAG_PARALLEL:
		"Two of your bearings ran almost parallel, so their lines never crossed " \
		+ "usefully and that pair was left out of the polygon. The fix rests on " \
		+ "what remains.",
	TelemetrySolver.DIAG_THIN_GEOMETRY:
		"Your stations sat nearly in line with the wolf, so the bearings crossed " \
		+ "at shallow angles and stretched the polygon long and thin however " \
		+ "carefully you read the meter. Biologists choose stations that see the " \
		+ "animal from well-spread angles.",
	TelemetrySolver.DIAG_OFF_PEAK:
		"Your bearings sat a few degrees off the peak. A Yagi's main lobe is " \
		+ "broad, so crews bracket it — note where the signal falls away on each " \
		+ "side and split the difference.",
	TelemetrySolver.DIAG_CLEAN:
		"Clean work: three well-spread stations and bearings on the peak give a " \
		+ "tight polygon. This is how collared wolves are located from the " \
		+ "ground across the corridor.",
}

var is_open := false
var solver := TelemetrySolver.new()
var antenna_deg := 0.0
var active_station := 0
var bearings: Array[float] = []
var fix: Dictionary = {}

var _seed_value: int = 0
var _debug: Node
var _hold_seconds := 0.0
var _plan_area: Control
var _meter_area: Control
var _title_label: Label
var _intro_label: Label
var _station_label: Label
var _meter_label: Label
var _result_label: Label
var _controls_label: Label

# --- lifecycle -----------------------------------------------------------------------------

## The `Debug` autoload is looked up by path, as `Main` does, so the script
## also parses under `--check-only`, where autoloads are absent.
func _ready() -> void:
	_debug = get_node_or_null("/root/Debug")

func _log(msg: String) -> void:
	if _debug:
		_debug.info(msg)

## Open the minigame on a fresh field generated from `seed_value`. Safe to
## call while already open (R regenerates through it).
func start(seed_value: int) -> void:
	_seed_value = seed_value
	solver.generate(seed_value)
	antenna_deg = 0.0
	active_station = 0
	bearings = []
	fix = {}
	_hold_seconds = 0.0
	is_open = true
	_result_label.text = ""
	_refresh_labels()
	show()
	queue_redraw()
	_log("Signal Chase started (seed %d)." % seed_value)

func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()

## True once all three bearings are committed and the collar is revealed.
func is_resolved() -> bool:
	return not fix.is_empty()

## Turn the antenna by `delta_deg` (negative = anticlockwise).
func rotate_antenna(delta_deg: float) -> void:
	if is_resolved():
		return
	antenna_deg = TelemetrySolver.normalize_bearing(antenna_deg + delta_deg)
	_refresh_labels()
	queue_redraw()

## Commit the current antenna heading as this station's bearing and move on;
## the third commit computes the fix and reveals the collar.
func commit_bearing() -> void:
	if is_resolved():
		return
	bearings.append(antenna_deg)
	_log("Signal Chase: station %d bearing %.1f°." % [active_station + 1, antenna_deg])
	if bearings.size() < TelemetrySolver.STATION_COUNT:
		active_station += 1
		antenna_deg = 0.0
		_hold_seconds = 0.0
	else:
		fix = solver.fix_from_bearings(bearings)
		_result_label.text = result_text()
		_log("Signal Chase: %s, centroid %.0f m from the collar." \
				% [String(fix["band"]), float(fix["error_metres"])])
		fix_completed.emit(String(fix["band"]), float(fix["error_metres"]))
	_refresh_labels()
	queue_redraw()

## The banded result plus the naturalist's note. Public so tests can assert
## the text without a scene tree.
func result_text() -> String:
	if not is_resolved():
		return ""
	var band := String(fix["band"])
	var headline := String(BAND_HEADLINES.get(band, band.capitalize()))
	var area_ha := float(fix["polygon_area"]) / SQUARE_METRES_PER_HECTARE
	var summary := "%s — centroid %.0f m from the collar, error polygon %.1f ha." \
			% [headline, float(fix["error_metres"]), area_ha]
	var omitted: Array = fix.get("omitted_pairs", [])
	if not omitted.is_empty():
		summary += " (%d bearing pair%s too close to parallel to cross.)" \
				% [omitted.size(), "" if omitted.size() == 1 else "s"]
	var note := String(NATURALIST_NOTES[solver.diagnose(bearings, fix)])
	return summary + "\n\n" + note

# --- input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if not (event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_ESCAPE:
			close()
		KEY_R:
			if not key.echo:
				start(_seed_value + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not key.echo:
				commit_bearing()
		KEY_A, KEY_LEFT:
			if key.shift_pressed and not key.echo:
				rotate_antenna(-fine_step_deg)
		KEY_D, KEY_RIGHT:
			if key.shift_pressed and not key.echo:
				rotate_antenna(fine_step_deg)
		_:
			return   # not ours; Main's modal guard still swallows it
	get_viewport().set_input_as_handled()

## Continuous rotation while a direction key is held (without Shift), ramping
## from the base speed to the maximum over ROTATE_ACCEL_SECONDS.
func _process(delta: float) -> void:
	if not is_open or is_resolved():
		return
	if Input.is_key_pressed(KEY_SHIFT):
		return
	var direction := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
	if direction == 0.0:
		_hold_seconds = 0.0
		return
	_hold_seconds += delta
	var ramp := clampf(_hold_seconds / rotate_accel_seconds, 0.0, 1.0)
	var speed := lerpf(rotate_base_deg_per_sec, rotate_max_deg_per_sec, ramp)
	rotate_antenna(direction * speed * delta)

# --- drawing --------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_COLOR)
	if _plan_area == null:
		return
	_draw_plan(_local_rect_of(_plan_area))
	_draw_meter(_local_rect_of(_meter_area))

func _draw_plan(area: Rect2) -> void:
	var inner := area.grow(-PLAN_PADDING)
	var scale := minf(inner.size.x / TelemetrySolver.FIELD_SIZE.x,
			inner.size.y / TelemetrySolver.FIELD_SIZE.y)
	var field_px := TelemetrySolver.FIELD_SIZE * scale
	var origin := inner.position + (inner.size - field_px) * 0.5
	var field_rect := Rect2(origin, field_px)
	draw_rect(field_rect, PARCHMENT)
	draw_rect(field_rect, FOREST_DEEP, false, PLAN_BORDER_WIDTH)
	var font := get_theme_default_font()

	# Committed bearings: a line across the whole field from each station.
	var ray_length := TelemetrySolver.FIELD_SIZE.length() * scale
	for i: int in range(bearings.size()):
		var from := _to_px(solver.stations[i], origin, scale)
		var dir := TelemetrySolver.bearing_vector(bearings[i])
		draw_line(from - dir * ray_length, from + dir * ray_length, EARTH, LINE_WIDTH)

	# The live antenna heading from the active station.
	if not is_resolved():
		var from := _to_px(solver.stations[active_station], origin, scale)
		var dir := TelemetrySolver.bearing_vector(antenna_deg)
		draw_line(from, from + dir * ray_length, GOLD, ANTENNA_RAY_WIDTH)

	# Stations, with the active one ringed.
	for i: int in range(solver.stations.size()):
		var p := _to_px(solver.stations[i], origin, scale)
		draw_circle(p, STATION_RADIUS, FOREST_DEEP)
		if i == active_station and not is_resolved():
			draw_arc(p, ACTIVE_RING_RADIUS, 0.0, TAU, 32, TEAL, ACTIVE_RING_WIDTH)
		draw_string(font, p + MARKER_LABEL_OFFSET, "S%d" % (i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, FOREST_DEEP)

	# Only once the third bearing is in: the error polygon, its centroid and
	# the truth. Before that the wolf stays hidden — that is the whole game.
	if is_resolved():
		var points: Array[Vector2] = fix["intersections"]
		var px_points := PackedVector2Array()
		for p: Vector2 in points:
			px_points.append(_to_px(p, origin, scale))
		if px_points.size() >= 3:
			draw_colored_polygon(px_points, POLYGON_FILL)
			var closed_loop := PackedVector2Array(px_points)
			closed_loop.append(px_points[0])
			draw_polyline(closed_loop, TEAL, LINE_WIDTH)
		for p: Vector2 in px_points:
			draw_circle(p, INTERSECTION_RADIUS, TEAL)
		var centroid: Vector2 = fix["centroid"]
		var c := _to_px(centroid, origin, scale)
		draw_line(c - Vector2(CENTROID_CROSS_HALF, 0.0), c + Vector2(CENTROID_CROSS_HALF, 0.0),
				TEAL, LINE_WIDTH)
		draw_line(c - Vector2(0.0, CENTROID_CROSS_HALF), c + Vector2(0.0, CENTROID_CROSS_HALF),
				TEAL, LINE_WIDTH)
		var t := _to_px(solver.target, origin, scale)
		draw_circle(t, COLLAR_RADIUS, FOREST_MID)
		draw_arc(t, COLLAR_RING_RADIUS, 0.0, TAU, 32, GOLD, ACTIVE_RING_WIDTH)
		draw_string(font, t + MARKER_LABEL_OFFSET, "wolf", HORIZONTAL_ALIGNMENT_LEFT, -1,
				LABEL_FONT_SIZE, FOREST_MID)

func _draw_meter(area: Rect2) -> void:
	draw_rect(area, LOCKED_GREY)
	var strength := 0.0
	if not is_resolved():
		strength = solver.signal_strength(active_station, antenna_deg)
	var fill := area.grow(-METER_BORDER)
	fill.size.x *= strength
	if fill.size.x > 0.0:
		draw_rect(fill, ramp_color(strength))
	draw_rect(area, PARCHMENT, false, METER_BORDER)

## A colour along the orange→teal data axis for `t` in 0..1.
static func ramp_color(t: float) -> Color:
	var clamped := clampf(t, 0.0, 1.0)
	var segments := DATA_AXIS.size() - 1
	var scaled := clamped * float(segments)
	var index := mini(int(floorf(scaled)), segments - 1)
	return DATA_AXIS[index].lerp(DATA_AXIS[index + 1], scaled - float(index))

func _to_px(field_point: Vector2, origin: Vector2, scale: float) -> Vector2:
	return origin + field_point * scale

## A child Control's rect in this Control's own drawing space.
func _local_rect_of(child: Control) -> Rect2:
	var r := child.get_global_rect()
	r.position -= global_position
	return r

func _refresh_labels() -> void:
	if is_resolved():
		_station_label.text = "All three bearings committed. R for a new wolf, Esc to close."
		_meter_label.text = "Signal strength — receiver off"
	else:
		_station_label.text = "Station %d of %d · antenna %.1f°" \
				% [active_station + 1, TelemetrySolver.STATION_COUNT, antenna_deg]
		_meter_label.text = "Signal strength — %d%%" \
				% int(roundf(solver.signal_strength(active_station, antenna_deg) * 100.0))

# --- construction -----------------------------------------------------------------------

func _build_ui() -> void:
	# STOP, as CreditsScreen: this is a modal over live gameplay and clicks must
	# not fall through to segment picking beneath it.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(PANEL_MARGIN))
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(COLUMN_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# The plan view is a placeholder Control: it reserves the space and
	# `_draw()` paints into its rect, so layout stays with the containers.
	_plan_area = Control.new()
	_plan_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plan_area.size_flags_stretch_ratio = PLAN_STRETCH
	_plan_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plan_area.resized.connect(_on_plan_area_resized)
	row.add_child(_plan_area)

	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.size_flags_stretch_ratio = SIDEBAR_STRETCH
	sidebar.add_theme_constant_override("separation", SIDEBAR_SEPARATION)
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sidebar)

	_title_label = _make_label(TITLE_TEXT, TITLE_FONT_SIZE)
	sidebar.add_child(_title_label)
	_intro_label = _make_label(INTRO_TEXT, BODY_FONT_SIZE)
	sidebar.add_child(_intro_label)
	_station_label = _make_label("", BODY_FONT_SIZE)
	sidebar.add_child(_station_label)
	_meter_label = _make_label("", BODY_FONT_SIZE)
	sidebar.add_child(_meter_label)

	_meter_area = Control.new()
	_meter_area.custom_minimum_size = Vector2(0.0, METER_HEIGHT)
	_meter_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_area.resized.connect(_on_plan_area_resized)
	sidebar.add_child(_meter_area)

	_result_label = _make_label("", BODY_FONT_SIZE)
	_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(_result_label)
	_controls_label = _make_label(CONTROLS_TEXT, BODY_FONT_SIZE)
	_controls_label.add_theme_color_override("font_color", ALPINE_ROCK)
	sidebar.add_child(_controls_label)

	hide()

func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PARCHMENT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _on_plan_area_resized() -> void:
	queue_redraw()
