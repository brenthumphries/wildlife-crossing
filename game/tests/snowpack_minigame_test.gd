## Tests for SnowpackMinigame, the snow-pit overlay: state transitions, tool reveals, verdict submission and key handling. Snow logic is covered by snowpack_profile_test.
extends GutTest

const SEED := 7

var _m: SnowpackMinigame
var _closed_count := 0
var _verdicts: Array = []

func before_each() -> void:
	TextScale.set_step(0)
	_closed_count = 0
	_verdicts = []
	_m = SnowpackMinigame.new()
	add_child_autofree(_m)
	_m.closed.connect(func() -> void: _closed_count += 1)
	_m.verdict_submitted.connect(
			func(player: SnowpackProfile.Verdict, truth: SnowpackProfile.Verdict) -> void:
				_verdicts.append([player, truth]))

func after_each() -> void:
	TextScale.set_step(0)

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

# --- lifecycle ---------------------------------------------------------------

func test_starts_closed_and_hidden() -> void:
	assert_false(_m.is_open)
	assert_false(_m.visible)

func test_start_opens_with_nothing_revealed() -> void:
	_m.start(SEED)
	assert_true(_m.is_open)
	assert_true(_m.visible)
	assert_false(_m.depth_known)
	assert_false(_m.is_resolved())
	assert_eq(_m.grain_known.size(), _m.profile.layers.size())
	assert_false(_m.grain_known.has(true))
	assert_false(_m.hardness_known.has(true))

func test_close_emits_once_and_hides() -> void:
	_m.start(SEED)
	_m.close()
	_m.close()
	assert_false(_m.is_open)
	assert_false(_m.visible)
	assert_eq(_closed_count, 1)

# --- tools -------------------------------------------------------------------

func test_probe_reveals_depth_only() -> void:
	_m.start(SEED)
	_m.apply_tool_at_depth(0.0)
	assert_true(_m.depth_known)
	assert_false(_m.grain_known.has(true))

func test_crystal_card_reveals_one_layer_grain() -> void:
	_m.start(SEED)
	_m.select_tool(SnowpackMinigame.Tool.CRYSTAL_CARD)
	_m.apply_tool_at_depth(0.0)
	assert_true(_m.grain_known[0])
	assert_false(_m.hardness_known[0])
	assert_false(_m.depth_known)

func test_hardness_test_reveals_one_layer_hardness() -> void:
	_m.start(SEED)
	_m.select_tool(SnowpackMinigame.Tool.HARDNESS_TEST)
	_m.apply_tool_at_depth(0.0)
	assert_true(_m.hardness_known[0])
	assert_false(_m.grain_known[0])

func test_tool_past_the_pit_reveals_nothing() -> void:
	_m.start(SEED)
	_m.select_tool(SnowpackMinigame.Tool.CRYSTAL_CARD)
	_m.apply_tool_at_depth(_m.profile.total_depth_cm() + 1000.0)
	assert_false(_m.grain_known.has(true))

# --- verdict -----------------------------------------------------------------

func test_result_text_is_empty_before_a_verdict() -> void:
	_m.start(SEED)
	assert_eq(_m.result_text(), "")

func test_submit_reveals_everything_and_emits_the_truth() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	assert_true(_m.is_resolved())
	assert_true(_m.depth_known)
	assert_false(_m.grain_known.has(false))
	assert_false(_m.hardness_known.has(false))
	assert_eq(_verdicts.size(), 1)
	assert_eq(_verdicts[0][0], SnowpackProfile.Verdict.VIABLE)
	assert_eq(_verdicts[0][1], _m.profile.evaluate())

func test_second_submit_and_late_tools_are_ignored() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.MARGINAL)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	assert_eq(_verdicts.size(), 1)
	assert_eq(_m.player_verdict, SnowpackProfile.Verdict.MARGINAL)

func test_result_text_names_every_criterion_and_the_denning_note() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.MARGINAL)
	var text := _m.result_text()
	for title: String in SnowpackMinigame.CRITERION_TITLES.values():
		assert_string_contains(text, title)
	assert_string_contains(text, SnowpackMinigame.DENNING_NOTE)

func test_result_text_says_agree_only_when_the_call_matches() -> void:
	_m.start(SEED)
	var truth := _m.profile.evaluate()
	_m.submit_verdict(truth)
	assert_string_contains(_m.result_text(), SnowpackMinigame.AGREE_TEXT)
	_m.start(SEED)
	var wrong: SnowpackProfile.Verdict = SnowpackProfile.Verdict.NOT_VIABLE
	if truth == wrong:
		wrong = SnowpackProfile.Verdict.VIABLE
	_m.submit_verdict(wrong)
	assert_string_contains(_m.result_text(), SnowpackMinigame.DISAGREE_TEXT)

func test_restart_clears_a_resolved_pit() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	_m.start(SEED + 1)
	assert_false(_m.is_resolved())
	assert_false(_m.depth_known)

# --- input -------------------------------------------------------------------

func test_number_keys_select_tools() -> void:
	_m.start(SEED)
	_m._unhandled_input(_key(KEY_2))
	assert_eq(_m.current_tool, SnowpackMinigame.Tool.CRYSTAL_CARD)
	_m._unhandled_input(_key(KEY_3))
	assert_eq(_m.current_tool, SnowpackMinigame.Tool.HARDNESS_TEST)
	_m._unhandled_input(_key(KEY_1))
	assert_eq(_m.current_tool, SnowpackMinigame.Tool.PROBE)

func test_verdict_keys_submit() -> void:
	_m.start(SEED)
	_m._unhandled_input(_key(KEY_N))
	assert_eq(_m.player_verdict, SnowpackProfile.Verdict.NOT_VIABLE)

func test_escape_closes_and_r_restarts() -> void:
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	_m._unhandled_input(_key(KEY_R))
	assert_false(_m.is_resolved())
	_m._unhandled_input(_key(KEY_ESCAPE))
	assert_false(_m.is_open)

func test_keys_are_ignored_while_closed() -> void:
	_m._unhandled_input(_key(KEY_V))
	assert_false(_m.is_resolved())

# --- helpers -----------------------------------------------------------------

func test_ramp_color_hits_both_ends_of_the_data_axis() -> void:
	assert_eq(SnowpackMinigame.ramp_color(0.0), SnowpackMinigame.DATA_AXIS[0])
	# The top end is a lerp, so it lands within float error of the last stop.
	var last: Color = SnowpackMinigame.DATA_AXIS[SnowpackMinigame.DATA_AXIS.size() - 1]
	assert_true(SnowpackMinigame.ramp_color(1.0).is_equal_approx(last))
	assert_eq(SnowpackMinigame.ramp_color(-3.0), SnowpackMinigame.ramp_color(0.0))
	assert_eq(SnowpackMinigame.ramp_color(9.0), SnowpackMinigame.ramp_color(1.0))

# --- text scale --------------------------------------------------------------

func test_label_sizes_follow_the_text_scale_step() -> void:
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		_m.apply_text_scale()
		assert_eq(_m._title_label.get_theme_font_size("font_size"), TextScale.size(TextScale.TITLE))
		assert_eq(_m._controls_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))

func test_label_sizes_reapply_live_on_text_scale_changed() -> void:
	var before: int = _m._controls_label.get_theme_font_size("font_size")
	TextScale.set_step(3)
	assert_eq(_m._controls_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
	assert_ne(_m._controls_label.get_theme_font_size("font_size"), before)

func test_controls_text_fits_the_viewport_at_every_text_scale_step() -> void:
	_m.start(SEED)
	var view := get_viewport().get_visible_rect()
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(view.encloses(_m._controls_label.get_global_rect()),
				"controls text within the viewport at step %d: %s" % [i, _m._controls_label.get_global_rect()])

## The smallest pit worth playing, px: below this the layers are too thin to click.
const MIN_PLAYABLE_PIT_PX := 300.0

func test_pit_and_buttons_are_on_screen_and_usable_at_every_text_scale_step() -> void:
	_m.start(SEED)
	var view := get_viewport().get_visible_rect()
	for i in TextScale.STEPS.size():
		TextScale.set_step(i)
		await get_tree().process_frame
		await get_tree().process_frame
		var pit: Rect2 = _m._pit_rect()
		assert_true(view.encloses(pit), "pit within the viewport at step %d: %s" % [i, pit])
		assert_gt(pit.size.x, MIN_PLAYABLE_PIT_PX, "pit wide enough at step %d" % i)
		assert_gt(pit.size.y, MIN_PLAYABLE_PIT_PX, "pit tall enough at step %d" % i)
		var tool_rect: Rect2 = _m._tool_label.get_global_rect()
		assert_true(view.encloses(tool_rect), "tool line within the viewport at step %d: %s" % [i, tool_rect])
		for verdict: SnowpackProfile.Verdict in _m._verdict_buttons:
			var button: Button = _m._verdict_buttons[verdict]
			assert_true(view.encloses(button.get_global_rect()),
					"%s button within the viewport at step %d: %s" % [button.text, i, button.get_global_rect()])
			assert_false(_m._scroll.get_global_rect().intersects(button.get_global_rect()),
					"%s button is not inside the scrolling pane at step %d" % [button.text, i])
		# Usable: a click in the middle of the pit applies the crystal card.
		_m.select_tool(SnowpackMinigame.Tool.CRYSTAL_CARD)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = pit.get_center()
		_m._gui_input(click)
		assert_true(_m.grain_known.has(true), "a click in the pit reveals a layer at step %d" % i)
		_m.start(SEED)

func test_legend_entries_do_not_overlap_at_every_text_scale_step() -> void:
	_m.start(SEED)
	for step: int in TextScale.STEPS.size():
		TextScale.set_step(step)
		_m.apply_text_scale()
		var rects: Array[Rect2] = _m.legend_entry_rects()
		assert_gt(rects.size(), 1, "the legend lists entries")
		for a: int in rects.size():
			for b: int in range(a + 1, rects.size()):
				assert_false(rects[a].intersects(rects[b]), "legend entries %d and %d overlap at step %d: %s vs %s" % [a, b, step, rects[a], rects[b]])
		var height: float = _m._legend_area.custom_minimum_size.y
		assert_lte(rects[rects.size() - 1].end.y, height, "the hardness line stays inside the legend at step %d" % step)

# --- post-verdict right pane (ATT-186) -----------------------------------------

## Open the minigame at the project's window size, at `step`, and call a verdict; layout settles over two frames.
func _resolved_at_step(step: int) -> void:
	if not _m.get_parent() is Control:
		var window := Control.new()
		window.size = Vector2(WindowFixture.content_size())
		add_child_autofree(window)
		_m.reparent(window)
	TextScale.set_step(step)
	_m.start(SEED)
	_m.submit_verdict(SnowpackProfile.Verdict.VIABLE)
	_m.apply_text_scale()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func test_banner_does_not_overlap_the_date_label_after_a_verdict_at_every_step() -> void:
	for step: int in TextScale.STEPS.size():
		await _resolved_at_step(step)
		var banner: Rect2 = _m._banner_area.get_global_rect()
		var date: Rect2 = _m._date_label.get_global_rect()
		assert_gt(banner.size.y, 0.0, "the banner has height at step %d" % step)
		assert_false(banner.intersects(date), "banner %s overlaps the date label %s at step %d" % [banner, date, step])

func test_banner_text_fits_inside_the_banner_at_every_step() -> void:
	for step: int in TextScale.STEPS.size():
		await _resolved_at_step(step)
		var font: Font = _m.get_theme_default_font()
		var text_h: float = font.get_height(_m._small_px())
		assert_gte(_m._banner_area.size.y, text_h, "banner tall enough for its text at step %d" % step)

func test_legend_entries_stay_clear_and_hardness_wraps_to_the_pane_after_a_verdict_at_every_step() -> void:
	for step: int in TextScale.STEPS.size():
		await _resolved_at_step(step)
		var rects: Array[Rect2] = _m.legend_entry_rects()
		for a: int in rects.size():
			for b: int in range(a + 1, rects.size()):
				assert_false(rects[a].intersects(rects[b]), "legend entries %d and %d overlap at step %d" % [a, b, step])
		var hardness: Rect2 = rects[rects.size() - 1]
		var pane_w: float = _m._scroll.size.x
		assert_lte(hardness.end.x, _m._legend_area.size.x, "hardness line within the legend's width at step %d: %s" % [step, hardness])
		assert_lte(hardness.end.x, pane_w, "hardness line within the pane's width at step %d: %s" % [step, hardness])
		assert_lte(hardness.end.y, _m._legend_area.size.y, "hardness line within the legend's height at step %d: %s" % [step, hardness])

func test_hardness_line_wraps_at_the_largest_step() -> void:
	await _resolved_at_step(TextScale.STEPS.size() - 1)
	var rects: Array[Rect2] = _m.legend_entry_rects()
	var line_h: float = _m.get_theme_default_font().get_height(_m._small_px())
	assert_gt(rects[rects.size() - 1].size.y, line_h * 1.5, "the hardness line takes more than one line at the largest step")

func test_legend_and_banner_are_painted_inside_the_scrolled_column() -> void:
	# Painted on their own placeholders, they scroll and clip with the pane: no second copy at a stale offset.
	assert_true(_m._scroll.is_ancestor_of(_m._legend_area))
	assert_true(_m._scroll.is_ancestor_of(_m._banner_area))
