## The game clock: turns the Simulation tick counter into days, seasons and years, and announces each season boundary.
class_name SeasonManager
extends RefCounted

## Emitted once per boundary, after the tick that crossed it has finished moving
## things, so one tick's movement always sees one season (architecture §4).
signal season_changed(new_season: String)

const SPRING := "spring"
const SUMMER := "summer"
const FALL := "fall"
const WINTER := "winter"
## The cycle in order; the year ends when winter does.
const SEASONS: Array[String] = [SPRING, SUMMER, FALL, WINTER]
const FIRST_YEAR := 1

var year: int = FIRST_YEAR
var season: String = SPRING
var day_of_season: int = 0

var _season_index: int = 0

## Whether `name` is one of the four seasons.
static func is_season(name: String) -> bool:
	return SEASONS.has(name)

## Whether a species is away from the world in `season`: its `seasonal_pattern`
## lists that season in `SimulationConstants.ABSENCE_SEASONS`. A record with no
## pattern, or a pattern the table does not know, is never absent.
static func is_absent(species: Dictionary, season_name: String) -> bool:
	var seasons: Array = SimulationConstants.ABSENCE_SEASONS.get(String(species.get("seasonal_pattern", "")), [])
	return seasons.has(season_name)

## Move the clock to `ticks` simulation ticks since year 1 spring day 0. Emits
## `season_changed` once if that crossed a boundary; staying put or going back
## announces nothing.
func advance_to(ticks: int) -> void:
	var day: int = maxi(0, ticks) / SimulationConstants.TICKS_PER_DAY
	var seasons_elapsed: int = day / SimulationConstants.DAYS_PER_SEASON
	var new_index: int = seasons_elapsed % SEASONS.size()
	var changed: bool = seasons_elapsed > absolute_season()
	year = FIRST_YEAR + seasons_elapsed / SEASONS.size()
	_season_index = new_index
	season = SEASONS[new_index]
	day_of_season = day % SimulationConstants.DAYS_PER_SEASON
	if changed:
		season_changed.emit(season)

## Set the clock from a save, silently. An unknown season, a year below 1 or a
## day outside the season take their start-of-game values (omit-means-default,
## ADR 0014). Returns the tick count the Simulation should resume from, which
## sits on a day boundary and so keeps the 30-day month aligned.
func restore(saved_year: int, saved_season: String, saved_day: int) -> int:
	year = maxi(saved_year, FIRST_YEAR)
	_season_index = maxi(SEASONS.find(saved_season), 0)
	season = SEASONS[_season_index]
	day_of_season = saved_day if saved_day >= 0 and saved_day < SimulationConstants.DAYS_PER_SEASON else 0
	return elapsed_days() * SimulationConstants.TICKS_PER_DAY

## Whole in-game days since year 1 spring day 0.
func elapsed_days() -> int:
	return absolute_season() * SimulationConstants.DAYS_PER_SEASON + day_of_season

## Seasons since year 1 spring day 0.
func absolute_season() -> int:
	return (year - FIRST_YEAR) * SEASONS.size() + _season_index

## The clock in the §14 `clock` shape (without `time_speed`, which the TimeController owns).
func save_state() -> Dictionary:
	return { "year": year, "season": season, "day_of_season": day_of_season }
