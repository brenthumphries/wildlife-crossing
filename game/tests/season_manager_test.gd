## Tests for SeasonManager — the clock, the season cycle and `season_changed`
## (test-plan §9). Pure logic: no scene tree, no autoloads.
extends GutTest

const SEASON_TICKS: int = SimulationConstants.DAYS_PER_SEASON * SimulationConstants.TICKS_PER_DAY

var _clock: SeasonManager


func before_each() -> void:
	_clock = SeasonManager.new()
	watch_signals(_clock)

func test_a_new_clock_starts_at_year_1_spring_day_0() -> void:
	assert_eq(_clock.year, 1)
	assert_eq(_clock.season, "spring")
	assert_eq(_clock.day_of_season, 0)

func test_season_length_15_min_at_1x() -> void:
	var ticks: int = int(SimulationConstants.SEASON_REAL_MINUTES * 60.0 / SimulationConstants.SIM_TICK_SECONDS)
	assert_eq(ticks, 9000, "15 minutes at 0.1 s a tick is 9,000 ticks")
	_clock.advance_to(ticks - 1)
	assert_eq(_clock.season, "spring", "still spring on the last tick of the season")
	assert_eq(_clock.day_of_season, SimulationConstants.DAYS_PER_SEASON - 1)
	_clock.advance_to(ticks)
	assert_eq(_clock.season, "summer", "9,000 ticks is exactly one season")
	assert_eq(_clock.day_of_season, 0)
	assert_eq(ticks / SimulationConstants.TICKS_PER_DAY, 90, "and 90 in-game days")

func test_days_advance_from_the_tick_counter() -> void:
	_clock.advance_to(SimulationConstants.TICKS_PER_DAY * 3 + 5)
	assert_eq(_clock.day_of_season, 3)

func test_season_changed_emitted_on_boundary() -> void:
	_clock.advance_to(SEASON_TICKS - 1)
	assert_signal_not_emitted(_clock, "season_changed")
	_clock.advance_to(SEASON_TICKS)
	assert_signal_emit_count(_clock, "season_changed", 1)
	assert_signal_emitted_with_parameters(_clock, "season_changed", ["summer"])
	_clock.advance_to(SEASON_TICKS + 1)
	assert_signal_emit_count(_clock, "season_changed", 1, "once per boundary, not once per tick")

func test_the_cycle_runs_spring_summer_fall_winter_then_the_next_year() -> void:
	var seen: Array[String] = []
	for i in 5:
		_clock.advance_to(SEASON_TICKS * i)
		seen.append("%d %s" % [_clock.year, _clock.season])
	assert_eq(seen, ["1 spring", "1 summer", "1 fall", "1 winter", "2 spring"] as Array[String])
	assert_signal_emit_count(_clock, "season_changed", 4)

func test_a_jump_across_several_seasons_announces_the_season_it_lands_in() -> void:
	_clock.advance_to(SEASON_TICKS * 2)
	assert_signal_emit_count(_clock, "season_changed", 1)
	assert_signal_emitted_with_parameters(_clock, "season_changed", ["fall"])

func test_save_state_is_the_clock_shape() -> void:
	_clock.advance_to(SEASON_TICKS * 5 + SimulationConstants.TICKS_PER_DAY * 12)
	assert_eq(_clock.save_state(), { "year": 2, "season": "summer", "day_of_season": 12 })

func test_restore_returns_a_day_aligned_tick_count_and_announces_nothing() -> void:
	var ticks: int = _clock.restore(2, "summer", 12)
	assert_eq(ticks, (5 * SimulationConstants.DAYS_PER_SEASON + 12) * SimulationConstants.TICKS_PER_DAY)
	assert_eq(ticks % SimulationConstants.TICKS_PER_DAY, 0)
	assert_eq(ticks % (SimulationConstants.TICKS_PER_DAY * 30), 12 * SimulationConstants.TICKS_PER_DAY % (SimulationConstants.TICKS_PER_DAY * 30))
	assert_signal_not_emitted(_clock, "season_changed")
	_clock.advance_to(ticks + 1)
	assert_signal_not_emitted(_clock, "season_changed", "the restored season is not a new one")

func test_restore_of_unusable_values_falls_back_to_the_start() -> void:
	assert_eq(_clock.restore(0, "monsoon", 999), 0)
	assert_eq(_clock.save_state(), { "year": 1, "season": "spring", "day_of_season": 0 })

func test_time_never_runs_backwards_announcing_a_season() -> void:
	_clock.advance_to(SEASON_TICKS)
	_clock.advance_to(0)
	assert_signal_emit_count(_clock, "season_changed", 1)
