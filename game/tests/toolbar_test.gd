## Tests for Toolbar: the Add crossing and Info buttons, their signals, text scaling, anchoring and visibility.
extends GutTest

var _t: Toolbar
var _add_count := 0
var _info_count := 0

func before_each() -> void:
	TextScale.set_step(0)
	_add_count = 0
	_info_count = 0
	_t = Toolbar.new()
	_t.add_crossing_pressed.connect(func() -> void: _add_count += 1)
	_t.info_pressed.connect(func() -> void: _info_count += 1)

func after_each() -> void:
	_t.free()
	TextScale.set_step(0)

func test_buttons_carry_the_expected_labels() -> void:
	assert_eq(_t._add_crossing_button.text, "Add crossing")
	assert_eq(_t._info_button.text, "Info")

func test_add_crossing_button_emits_only_its_signal() -> void:
	_t._add_crossing_button.pressed.emit()
	assert_eq(_add_count, 1)
	assert_eq(_info_count, 0)

func test_info_button_emits_only_its_signal() -> void:
	_t._info_button.pressed.emit()
	assert_eq(_info_count, 1)
	assert_eq(_add_count, 0)

func test_buttons_never_take_keyboard_focus() -> void:
	assert_eq(_t._add_crossing_button.focus_mode, Control.FOCUS_NONE)
	assert_eq(_t._info_button.focus_mode, Control.FOCUS_NONE)

func test_font_sizes_follow_text_scale() -> void:
	for step: int in TextScale.STEPS.size():
		TextScale.set_step(step)
		_t.apply_text_scale()
		var expected := TextScale.size(TextScale.BODY)
		assert_eq(_t._add_crossing_button.get_theme_font_size("font_size"), expected)
		assert_eq(_t._info_button.get_theme_font_size("font_size"), expected)

func test_bar_is_anchored_bottom_left_clear_of_the_hud_stack() -> void:
	var hud := Hud.new()
	autofree(hud)
	assert_eq(_t._bar.anchor_top, 1.0, "toolbar hugs the bottom edge")
	assert_eq(_t._bar.anchor_bottom, 1.0)
	assert_eq(hud._stack.anchor_bottom, 0.0, "HUD stack hugs the top edge")

func test_toolbar_does_not_block_the_world_outside_its_buttons() -> void:
	assert_eq(_t.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_t._bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_visible_when_nothing_else_owns_the_screen() -> void:
	_t.update_visibility(false, false)
	assert_true(_t.visible)

func test_hidden_while_a_modal_is_open() -> void:
	_t.update_visibility(true, false)
	assert_false(_t.visible)

func test_hidden_while_selection_mode_is_active() -> void:
	_t.update_visibility(false, true)
	assert_false(_t.visible)

func test_reappears_when_the_overlay_closes() -> void:
	_t.update_visibility(true, false)
	_t.update_visibility(false, false)
	assert_true(_t.visible)
