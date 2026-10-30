## Tests for TimeControls: the four buttons, the speed highlight, the Space and 1/2/3 keys, and live text scaling.
extends GutTest

var _t: TimeControls
var _picked: Array[float] = []

func before_each() -> void:
	TextScale.set_step(0)
	_picked = []
	_t = TimeControls.new()
	_t.speed_selected.connect(func(m: float) -> void: _picked.append(m))

func after_each() -> void:
	_t.free()
	TextScale.set_step(0)

func _highlighted() -> Array[float]:
	var on: Array[float] = []
	for step: float in _t._buttons:
		if (_t._buttons[step] as Button).button_pressed:
			on.append(step)
	return on

func test_buttons_are_pause_1x_2x_4x_in_order() -> void:
	var labels: Array[String] = []
	for button: Button in _t._row.get_children():
		labels.append(button.text)
	assert_eq(labels, ["Pause", "1x", "2x", "4x"] as Array[String])

func test_starts_with_1x_highlighted() -> void:
	assert_eq(_highlighted(), [TimeController.SPEED_1X] as Array[float])

func test_each_button_emits_its_speed() -> void:
	for step: float in TimeController.STEPS:
		(_t._buttons[step] as Button).pressed.emit()
	assert_eq(_picked, TimeController.STEPS)

func test_show_speed_moves_the_highlight() -> void:
	_t.show_speed(TimeController.SPEED_4X)
	assert_eq(_highlighted(), [TimeController.SPEED_4X] as Array[float])
	_t.show_speed(TimeController.PAUSED)
	assert_eq(_highlighted(), [TimeController.PAUSED] as Array[float])

func test_show_speed_ignores_an_unknown_value() -> void:
	_t.show_speed(3.0)
	assert_eq(_t.current_speed(), TimeController.SPEED_1X)

func test_clicking_the_current_speed_keeps_it_highlighted() -> void:
	var button: Button = _t._buttons[TimeController.SPEED_1X]
	button.button_pressed = false   # what a click on a lit toggle does
	button.pressed.emit()
	assert_eq(_highlighted(), [TimeController.SPEED_1X] as Array[float])

func test_digit_keys_select_1x_2x_4x() -> void:
	assert_true(_t.handle_key(KEY_1))
	assert_true(_t.handle_key(KEY_2))
	assert_true(_t.handle_key(KEY_3))
	assert_eq(_picked, [1.0, 2.0, 4.0] as Array[float])

func test_keypad_digits_work_too() -> void:
	_t.handle_key(KEY_KP_3)
	assert_eq(_picked, [4.0] as Array[float])

func test_space_pauses_then_resumes_to_the_previous_speed() -> void:
	_t.show_speed(TimeController.SPEED_4X)
	_t.handle_key(KEY_SPACE)
	assert_eq(_picked, [TimeController.PAUSED] as Array[float])
	_t.show_speed(TimeController.PAUSED)
	_t.handle_key(KEY_SPACE)
	assert_eq(_picked, [TimeController.PAUSED, TimeController.SPEED_4X] as Array[float])

func test_space_resumes_to_1x_when_nothing_ran_before_the_pause() -> void:
	_t.show_speed(TimeController.PAUSED)
	assert_eq(_t.speed_for_pause_key(), TimeController.SPEED_1X)

func test_an_unrelated_key_is_not_handled() -> void:
	for key: Key in [KEY_B, KEY_M, KEY_I, KEY_ENTER, KEY_ESCAPE, KEY_4, KEY_0, KEY_F1, KEY_F5]:
		assert_false(_t.handle_key(key), "key %d" % key)
	assert_eq(_picked.size(), 0)

func test_time_keys_do_not_clash_with_main_shortcuts() -> void:
	var taken: Array[Key] = [Main.CREDITS_KEY, Main.QUICKSAVE_KEY, Main.QUICKLOAD_KEY,
			Main.TELEMETRY_KEY, Main.SNOWPACK_KEY, Main.INFO_KEY, KEY_B, KEY_M, KEY_ENTER, KEY_ESCAPE]
	for key: Key in taken:
		assert_eq(TimeControls.speed_for_key(key), TimeControls.NO_SPEED)
		assert_ne(key, TimeControls.PAUSE_KEY)

func test_buttons_never_take_keyboard_focus() -> void:
	for button: Button in _t._row.get_children():
		assert_eq(button.focus_mode, Control.FOCUS_NONE)

func test_font_sizes_follow_text_scale() -> void:
	for step: int in TextScale.STEPS.size():
		TextScale.set_step(step)
		_t.apply_text_scale()
		for button: Button in _t._row.get_children():
			assert_eq(button.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))

func test_hud_hosts_the_controls_and_relays_a_pick() -> void:
	var hud := Hud.new()
	autofree(hud)
	var seen: Array[float] = []
	hud.time_speed_selected.connect(func(m: float) -> void: seen.append(m))
	assert_true(hud.handle_time_key(KEY_2))
	assert_eq(seen, [2.0] as Array[float])
	hud.set_time_speed(TimeController.SPEED_2X)
	assert_eq(hud._time_controls.current_speed(), TimeController.SPEED_2X)
