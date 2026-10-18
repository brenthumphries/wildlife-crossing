## Tests for Hud (build review C1): the on-screen message channel mirroring
## Debug logging, and the coalesced crossing-cue flash, both faded out over
## time rather than left stuck on screen.
extends GutTest

var _h: Hud

func before_each() -> void:
	TextScale.set_step(0)
	_h = Hud.new()

func after_each() -> void:
	_h.free()
	TextScale.set_step(0)

func test_starts_with_nothing_visible() -> void:
	assert_eq(_h._message_label.modulate.a, 0.0)
	assert_eq(_h._cue_icon.modulate.a, 0.0)
	assert_eq(_h._cue_label.modulate.a, 0.0)

func test_show_message_displays_text_at_full_alpha() -> void:
	_h.show_message("Build mode — click tiles across the corridor.")
	assert_eq(_h._message_label.text, "Build mode — click tiles across the corridor.")
	assert_eq(_h._message_label.modulate.a, 1.0)

func test_message_fades_out_over_its_window() -> void:
	_h.show_message("Overpass complete — the highway is now a safe crossing.")
	_h._process(Hud.MESSAGE_FADE_SECONDS)   # a full window elapses
	assert_eq(_h._message_label.modulate.a, 0.0)

func test_message_partway_through_fade_is_partially_visible() -> void:
	_h.show_message("Sub-area 3 is locked — v0.1.0 is scoped to Bow Valley only.")
	_h._process(Hud.MESSAGE_FADE_SECONDS / 2.0)
	assert_almost_eq(_h._message_label.modulate.a, 0.5, 0.01)

func test_show_crossing_cue_displays_count_and_icon() -> void:
	_h.show_crossing_cue(3)
	assert_eq(_h._cue_label.text, "+3 crossed safely")
	assert_eq(_h._cue_label.modulate.a, 1.0)
	assert_eq(_h._cue_icon.modulate.a, 1.0)

func test_crossing_cue_fades_out_over_its_window() -> void:
	_h.show_crossing_cue(1)
	_h._process(Hud.CUE_FLASH_SECONDS)
	assert_eq(_h._cue_icon.modulate.a, 0.0)
	assert_eq(_h._cue_label.modulate.a, 0.0)

func test_message_and_cue_fade_independently() -> void:
	_h.show_message("Build mode — click tiles across the corridor.")
	_h.show_crossing_cue(2)
	_h._process(Hud.CUE_FLASH_SECONDS)   # cue's shorter window elapses fully
	assert_eq(_h._cue_icon.modulate.a, 0.0, "cue has fully faded")
	assert_true(_h._message_label.modulate.a > 0.0, "message's longer window has not")

func test_budget_label_starts_at_the_starting_budget() -> void:
	assert_eq(_h._budget_label.text, "Budget: $%d" % EconomyConstants.STARTING_BUDGET)
	assert_true(_h._budget_label.visible)

func test_set_budget_updates_the_label() -> void:
	_h.set_budget(1234)
	assert_eq(_h._budget_label.text, "Budget: $1234")

func test_donation_label_hidden_before_any_donation() -> void:
	assert_false(_h._donation_label.visible)

func test_set_last_donation_shows_the_amount() -> void:
	_h.set_last_donation(250)
	assert_true(_h._donation_label.visible)
	assert_eq(_h._donation_label.text, "Last donation: $250")

func test_zero_donation_keeps_the_label_hidden() -> void:
	_h.set_last_donation(250)
	_h.set_last_donation(0)
	assert_false(_h._donation_label.visible)

func test_build_status_hidden_until_set_and_cleared_again() -> void:
	assert_false(_h._build_status_label.visible)
	_h.set_build_status("Build overpass — 2 tile(s) selected, $100 — budget $900")
	assert_true(_h._build_status_label.visible)
	assert_eq(_h._build_status_label.text, "Build overpass — 2 tile(s) selected, $100 — budget $900")
	_h.clear_build_status()
	assert_false(_h._build_status_label.visible)

func test_every_text_lives_in_the_one_stack() -> void:
	for node: Node in [_h._build_status_label, _h._message_label, _h._cue_row,
			_h._budget_label, _h._donation_label]:
		assert_eq(node.get_parent(), _h._stack)
	assert_eq(_h._cue_label.get_parent(), _h._cue_row)
	assert_eq(_h._cue_icon.get_parent(), _h._cue_row)

func test_font_sizes_follow_the_text_scale_step() -> void:
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		_h.apply_text_scale()
		assert_eq(_h._message_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
		assert_eq(_h._budget_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
		assert_eq(_h._donation_label.get_theme_font_size("font_size"), TextScale.size(TextScale.SMALL))
		assert_eq(_h._build_status_label.get_theme_font_size("font_size"), TextScale.size(TextScale.SMALL))

func test_sizes_reapply_live_on_text_scale_changed() -> void:
	add_child(_h)   # _ready connects the EventBus signal
	var before: int = _h._message_label.get_theme_font_size("font_size")
	TextScale.set_step(2)
	assert_eq(_h._message_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
	assert_ne(_h._message_label.get_theme_font_size("font_size"), before)

func test_no_two_visible_elements_overlap_at_any_text_scale_step() -> void:
	_h.show_message("Overpass complete — the highway is now a safe crossing.")
	_h.show_crossing_cue(12)
	_h.set_last_donation(250)
	_h.set_build_status("Build overpass — 3 tile(s) selected, $300 — budget $9000")
	add_child(_h)
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		await get_tree().process_frame
		await get_tree().process_frame
		var elements: Array[Control] = [_h._build_status_label, _h._message_label,
				_h._cue_icon, _h._cue_label, _h._budget_label, _h._donation_label]
		for a in elements.size():
			assert_true(elements[a].visible, "element %d visible at step %d" % [a, i])
			for b in range(a + 1, elements.size()):
				assert_false(elements[a].get_global_rect().intersects(elements[b].get_global_rect()),
						"elements %d and %d overlap at step %d" % [a, b, i])

func test_hint_banner_starts_hidden() -> void:
	assert_false(_h.is_hint_visible())

func test_show_hint_displays_text_and_dismiss_hides_and_signals() -> void:
	watch_signals(_h)
	_h.show_hint("Click tiles across the highway.")
	assert_true(_h.is_hint_visible())
	assert_eq(_h._hint_label.text, "Click tiles across the highway.")
	_h._hint_button.pressed.emit()
	assert_false(_h.is_hint_visible())
	assert_signal_emitted(_h, "hint_dismissed")

func test_hint_banner_never_blocks_the_mouse() -> void:
	assert_eq(_h._hint_panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_h._hint_label.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_hint_banner_follows_text_scale() -> void:
	TextScale.set_step(3)
	_h.apply_text_scale()
	assert_eq(_h._hint_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
	assert_eq(_h._hint_label.custom_minimum_size.x, float(TextScale.size(Hud.HINT_WIDTH_BASE)))
