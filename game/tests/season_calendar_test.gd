## Tests for SeasonCalendar: the calendar text, the next-migration marker and the ring fills, all scene-free.
extends GutTest

const SEASON_DAYS: int = SimulationConstants.DAYS_PER_SEASON

var _cal: SeasonCalendar

func before_each() -> void:
	TextScale.set_step(0)
	_cal = SeasonCalendar.new()

func after_each() -> void:
	_cal.free()
	TextScale.set_step(0)

func test_season_text_shows_season_year_and_day_counted_from_one() -> void:
	assert_eq(SeasonCalendar.season_text(1, "summer", 34), "Summer · Year 1 · Day 35")
	assert_eq(SeasonCalendar.season_text(3, "spring", 0), "Spring · Year 3 · Day 1")

func test_migration_seasons_follow_the_c37_table_in_cycle_order() -> void:
	var expected: Array[String] = ["spring", "fall"]
	assert_eq(SeasonCalendar.migration_seasons(), expected)

func test_next_migration_from_summer_is_fall_after_the_days_left() -> void:
	var next: Dictionary = SeasonCalendar.next_migration("summer", 10)
	assert_eq(next["season"], "fall")
	assert_eq(next["days"], SEASON_DAYS - 10)

func test_next_migration_from_winter_is_spring_of_the_next_year() -> void:
	var next: Dictionary = SeasonCalendar.next_migration("winter", 0)
	assert_eq(next["season"], "spring")
	assert_eq(next["days"], SEASON_DAYS)

func test_next_migration_is_now_in_a_migration_season() -> void:
	var next: Dictionary = SeasonCalendar.next_migration("fall", 40)
	assert_eq(next["season"], "fall")
	assert_eq(next["days"], 0)

func test_migration_text_counts_down_before_a_season() -> void:
	assert_eq(SeasonCalendar.migration_text("summer", 0), "Next migration: Fall in %d days" % SEASON_DAYS)
	assert_eq(SeasonCalendar.migration_text("summer", SEASON_DAYS - 1), "Next migration: Fall in 1 day")

func test_migration_text_says_now_during_a_migration_season() -> void:
	assert_eq(SeasonCalendar.migration_text("spring", 5), "Migration season now")

func test_ring_fills_past_full_current_partial_later_empty() -> void:
	var fills: Array[float] = SeasonCalendar.ring_fills("fall", SEASON_DAYS / 2)
	assert_eq(fills[0], 1.0)
	assert_eq(fills[1], 1.0)
	assert_almost_eq(fills[2], 0.5, 0.01)
	assert_eq(fills[3], 0.0)

func test_ring_is_empty_at_the_start_of_the_year() -> void:
	var fills: Array[float] = SeasonCalendar.ring_fills("spring", 0)
	for fill in fills:
		assert_eq(fill, 0.0)

func test_set_clock_updates_both_labels() -> void:
	_cal.set_clock(2, "summer", 9)
	assert_eq(_cal._season_label.text, "Summer · Year 2 · Day 10")
	assert_eq(_cal._migration_label.text, "Next migration: Fall in %d days" % (SEASON_DAYS - 9))
	assert_true(_cal._migration_label.visible)

func test_set_clock_follows_a_season_change() -> void:
	_cal.set_clock(1, "summer", 89)
	_cal.set_clock(1, "fall", 0)
	assert_eq(_cal._season_label.text, "Fall · Year 1 · Day 1")
	assert_eq(_cal._migration_label.text, "Migration season now")

func test_text_sizes_come_from_text_scale() -> void:
	TextScale.set_step(2)
	_cal.apply_text_scale()
	assert_eq(_cal._season_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
	assert_eq(_cal._migration_label.get_theme_font_size("font_size"), TextScale.size(TextScale.SMALL))
