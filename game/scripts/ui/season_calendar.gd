## The always-on season calendar: season, year and day, a four-segment ring of the year's progress, and the next migration season.
class_name SeasonCalendar
extends BaseScreen

const RING_BASE_SIZE := 40.0   # ring edge in px at text-scale step 1.0; scaled with the text
const RING_WIDTH_FRACTION := 0.18   # arc thickness as a share of the ring's edge
const RING_GAP_RADIANS := 0.12   # visible gap between the four segments
const RING_POINTS := 24   # polyline points per segment arc
const ROW_SEPARATION := 8
const TRACK_COLOR := Color(1, 1, 1, 0.18)
const FILL_COLOR := Color(0.95, 0.85, 0.45)
const MIGRATION_TRACK_COLOR := Color(0.35, 0.85, 0.55, 0.4)
const MIGRATION_FILL_COLOR := Color(0.35, 0.85, 0.55)
const MIGRATION_TEXT_COLOR := Color(0.35, 0.85, 0.55)

var _row: HBoxContainer
var _ring: Control
var _season_label: Label
var _migration_label: Label
var _year: int = SeasonManager.FIRST_YEAR
var _season: String = SeasonManager.SPRING
var _day: int = 0

## The calendar line: season, year and day, e.g. "Summer · Year 1 · Day 35".
## `day_of_season` counts from 0 in the clock; the player sees it from 1.
static func season_text(year: int, season: String, day_of_season: int) -> String:
	return "%s · Year %d · Day %d" % [season.capitalize(), year, day_of_season + 1]

## Every season some species migrates in, in cycle order (the C37 table).
static func migration_seasons() -> Array[String]:
	var found: Array[String] = []
	for season_name in SeasonManager.SEASONS:
		for pattern in SimulationConstants.MIGRATION_SEASONS:
			var list: Array = SimulationConstants.MIGRATION_SEASONS[pattern]
			if list.has(season_name) and not found.has(season_name):
				found.append(season_name)
	return found

## The next migration season as { "season": String, "days": int }, `days` being
## the whole days until it begins (0 while it is the current season). Empty if
## no species migrates.
static func next_migration(season: String, day_of_season: int) -> Dictionary:
	var migrating := migration_seasons()
	var here := SeasonManager.SEASONS.find(season)
	if migrating.is_empty() or here < 0:
		return {}
	if migrating.has(season):
		return { "season": season, "days": 0 }
	var count := SeasonManager.SEASONS.size()
	for offset in range(1, count + 1):
		var candidate: String = SeasonManager.SEASONS[(here + offset) % count]
		if migrating.has(candidate):
			var days := SimulationConstants.DAYS_PER_SEASON - day_of_season \
					+ (offset - 1) * SimulationConstants.DAYS_PER_SEASON
			return { "season": candidate, "days": days }
	return {}

## The migration line: "Migration season now", "Next migration: Fall in 56 days",
## or "" when no species migrates.
static func migration_text(season: String, day_of_season: int) -> String:
	var next := next_migration(season, day_of_season)
	if next.is_empty():
		return ""
	var days: int = next["days"]
	if days == 0:
		return "Migration season now"
	return "Next migration: %s in %d %s" % [String(next["season"]).capitalize(), days,
			"day" if days == 1 else "days"]

## How full each of the four ring segments is, 0.0 to 1.0: past seasons full,
## the current one by its day, later ones empty.
static func ring_fills(season: String, day_of_season: int) -> Array[float]:
	var fills: Array[float] = []
	var here := SeasonManager.SEASONS.find(season)
	for i in SeasonManager.SEASONS.size():
		if i < here:
			fills.append(1.0)
		elif i == here:
			fills.append(clampf(float(day_of_season) / SimulationConstants.DAYS_PER_SEASON, 0.0, 1.0))
		else:
			fills.append(0.0)
	return fills

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", ROW_SEPARATION)
	add_child(_row)

	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_row.add_child(_ring)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(column)

	_season_label = Label.new()
	column.add_child(_season_label)

	_migration_label = Label.new()
	_migration_label.add_theme_color_override("font_color", MIGRATION_TEXT_COLOR)
	column.add_child(_migration_label)

	set_clock(_year, _season, _day)
	apply_text_scale()

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.text_scale_changed.connect(_on_event_bus_text_scale_changed)

## Show the clock; call on `season_changed` and whenever the day moves; a repeat of the
## clock already shown does nothing.
func set_clock(year: int, season: String, day_of_season: int) -> void:
	if year == _year and season == _season and day_of_season == _day and not _season_label.text.is_empty():
		return
	_year = year
	_season = season
	_day = day_of_season
	_season_label.text = season_text(year, season, day_of_season)
	_migration_label.text = migration_text(season, day_of_season)
	_migration_label.visible = not _migration_label.text.is_empty()
	_ring.queue_redraw()

## Re-size the texts and the ring from TextScale's current step.
func apply_text_scale() -> void:
	_season_label.add_theme_font_size_override("font_size", TextScale.size(TextScale.BODY))
	_migration_label.add_theme_font_size_override("font_size", TextScale.size(TextScale.SMALL))
	_ring.custom_minimum_size = Vector2.ONE * TextScale.size(roundi(RING_BASE_SIZE))
	# A plain Control does not size to its children, so a parent container
	# only reserves the row's height and width if we say so.
	custom_minimum_size = _row.get_combined_minimum_size()

func _on_event_bus_text_scale_changed(_factor: float) -> void:
	apply_text_scale()

# Four arcs from 12 o'clock, clockwise, one per season. Each has a dim track
# (green where some species migrates) and a bright fill for the days passed.
func _draw_ring() -> void:
	var edge := _ring.size.x
	var width := edge * RING_WIDTH_FRACTION
	var radius := (edge - width) / 2.0
	var center := _ring.size / 2.0
	var migrating := migration_seasons()
	var fills := ring_fills(_season, _day)
	var quarter := TAU / SeasonManager.SEASONS.size()
	for i in SeasonManager.SEASONS.size():
		var start := -PI / 2.0 + i * quarter + RING_GAP_RADIANS / 2.0
		var span := quarter - RING_GAP_RADIANS
		var is_migration := migrating.has(SeasonManager.SEASONS[i])
		_ring.draw_arc(center, radius, start, start + span, RING_POINTS,
				MIGRATION_TRACK_COLOR if is_migration else TRACK_COLOR, width)
		if fills[i] > 0.0:
			_ring.draw_arc(center, radius, start, start + span * fills[i], RING_POINTS,
					MIGRATION_FILL_COLOR if is_migration else FILL_COLOR, width)
