## Tests for TimeController: the speed steps, refusal of anything else, and the change signal.
extends GutTest

var _time: TimeController

func before_each() -> void:
	_time = TimeController.new()

func test_starts_at_1x() -> void:
	assert_eq(_time.multiplier, 1.0)
	assert_false(_time.is_paused())

func test_every_step_is_accepted() -> void:
	for step: float in [2.0, 4.0, 0.0, 1.0]:
		assert_true(_time.set_speed(step), "moving to %s changes the speed" % step)
		assert_eq(_time.multiplier, step)

func test_other_values_are_refused() -> void:
	for bad: float in [-1.0, 0.5, 3.0, 8.0]:
		assert_false(_time.set_speed(bad), "%s is not a step" % bad)
		assert_eq(_time.multiplier, 1.0, "a refused value leaves the speed alone")

func test_setting_the_current_speed_is_not_a_change() -> void:
	assert_false(_time.set_speed(1.0))

func test_pause_reports_paused() -> void:
	_time.set_speed(0.0)
	assert_true(_time.is_paused())

func test_change_emits_once_with_the_multiplier() -> void:
	watch_signals(_time)
	_time.set_speed(4.0)
	assert_signal_emit_count(_time, "time_speed_changed", 1)
	assert_signal_emitted_with_parameters(_time, "time_speed_changed", [4.0])

func test_no_signal_for_refused_or_unchanged_speeds() -> void:
	watch_signals(_time)
	_time.set_speed(3.0)
	_time.set_speed(1.0)
	assert_signal_not_emitted(_time, "time_speed_changed")
